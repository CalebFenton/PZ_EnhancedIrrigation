-- The right-click options of tanks and Tank Stands: Set Barrel on Stand and Take Barrel Down on a
-- stand, and on any tank Plumb to Tank, with a submenu of the tanks in reach, and Unplumb, with a
-- submenu of the pipe buried from it, to tanks and fixtures. The floor where a plumbed tank stood
-- also offers Unplumb, so pipe whose tanks are both gone is found where it was laid. Each option is
-- greyed out saying why when its job would be refused (StandJobs, LinkJobs). A fixture's own
-- options are FixtureMenu.lua's.

require "ISUI/ISWorldObjectContextMenu"
require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Materials"
require "EnhancedIrrigation/UI/Needs"
require "EnhancedIrrigation/Pipes"
require "EnhancedIrrigation/Tanks"
require "EnhancedIrrigation/Stands"
require "EnhancedIrrigation/StandJobs"
require "EnhancedIrrigation/Links"
require "EnhancedIrrigation/LinkJobs"
require "EnhancedIrrigation/Fixtures"
require "EnhancedIrrigation/TimedActions/EnhancedIrrigationAction"

EnhancedIrrigation = EnhancedIrrigation or {}
local TankMenu = {}
EnhancedIrrigation.TankMenu = TankMenu

local Needs, Tanks, Stands = EnhancedIrrigation.Needs, EnhancedIrrigation.Tanks, EnhancedIrrigation.Stands
local StandJobs, Links, LinkJobs = EnhancedIrrigation.StandJobs, EnhancedIrrigation.Links, EnhancedIrrigation.LinkJobs
local Pipes, Fixtures, Action = EnhancedIrrigation.Pipes, EnhancedIrrigation.Fixtures, EnhancedIrrigationAction

-- Compass points counter-clockwise from east, as an angle with north up (y grows southward).
local DIRECTIONS = { "E", "NE", "N", "NW", "W", "SW", "S", "SE" }

--- Which way the square `there` lies from `here`, in words: a compass point, or above or below.
function TankMenu.direction(here, there)
    local dx, dy = there.x - here.x, there.y - here.y
    if dx == 0 and dy == 0 then
        return getText(there.z > here.z and "IGUI_EnhancedIrrigation_Above" or "IGUI_EnhancedIrrigation_Below")
    end
    local sector = math.floor((math.atan2(-dy, dx) + math.pi / 8) / (math.pi / 4)) % 8
    return getText("IGUI_EnhancedIrrigation_Direction_" .. DIRECTIONS[sector + 1])
end

--- How the menu names the tank on the square `there`, seen from the square `here`: what it is,
--- how far and which way, and its level; just how far and which way when it isn't loaded here.
function TankMenu.tankLabel(here, there)
    local tank = Tanks.tankAt(there.x, there.y, there.z)
    local distance, direction = Links.distance(here, there), TankMenu.direction(here, there)
    if not tank then
        return getText("ContextMenu_EnhancedIrrigation_TankOutOfSight", distance, direction)
    end
    return getText("ContextMenu_EnhancedIrrigation_TankThere", tank:getFluidContainer():getTranslatedContainerName(),
        distance, direction, Tanks.levelOf(tank))
end

--- The name the game gives `fixture` ("Sink", "Bath"), as its own menus name it.
function TankMenu.fixtureName(fixture)
    local props = fixture:getSprite():getProperties()
    local name = props:get("CustomName")
    if not name then
        return ""
    end
    local group = props:get("GroupName")
    return Translator.getMoveableDisplayName(group and (group .. " " .. name) or name)
end

--- How Unplumb names the buried pipe from the square `here` to the square `there`: by the tank or
--- fixture at its far end, or as pipe to an empty spot when that square is loaded with neither.
function TankMenu.linkLabel(here, there)
    local square = getCell():getGridSquare(there.x, there.y, there.z)
    local fixture = Fixtures.fixtureOn(square)
    if fixture then
        return getText("ContextMenu_EnhancedIrrigation_PlumbedTo", getText("ContextMenu_EnhancedIrrigation_FixtureThere",
            TankMenu.fixtureName(fixture), Links.distance(here, there), TankMenu.direction(here, there)))
    end
    if square and not Tanks.tankOn(square) then
        return getText("ContextMenu_EnhancedIrrigation_BuriedPipeToEmpty", Links.distance(here, there),
            TankMenu.direction(here, there))
    end
    return getText("ContextMenu_EnhancedIrrigation_PlumbedTo", TankMenu.tankLabel(here, there))
end

local function addStandOptions(context, playerNum, character, object)
    if Stands.isStand(object) then
        local carried = Stands.barrelsCarried(character)
        local name = getText("ContextMenu_EnhancedIrrigation_SetBarrel")
        if #carried > 1 then
            local submenu = Needs.addSubMenu(context, name)
            for _, entry in ipairs(carried) do
                local option = submenu:addOption(entry.item:getDisplayName(), playerNum, Action.queue, "stand",
                    StandJobs.SET_BARREL, object, entry.item)
                Needs.refuse(option, StandJobs.refusal(character, StandJobs.SET_BARREL, object, entry.item))
            end
        else
            local barrel = carried[1] and carried[1].item
            local option = context:addOption(name, playerNum, Action.queue, "stand", StandJobs.SET_BARREL, object, barrel)
            Needs.refuse(option, StandJobs.refusal(character, StandJobs.SET_BARREL, object, barrel))
        end
    elseif Stands.isRaised(object) then
        local option = context:addOption(getText("ContextMenu_EnhancedIrrigation_TakeBarrelDown"), playerNum, Action.queue,
            "stand", StandJobs.TAKE_DOWN, object)
        Needs.refuse(option, StandJobs.refusal(character, StandJobs.TAKE_DOWN, object))
    end
end

-- A link job's option, greyed out as LinkJobs refuses it.
function TankMenu.showLink(option, character, job, object, with)
    Needs.show(option, LinkJobs.needs(character, job, object, with), LinkJobs.blocker(character, job, object, with))
end

--- Plumb to Tank at `object` (a tank, or a fixture): a submenu of the tanks in reach, each with a
--- submenu of the pipe the character carries to lay to it, as Lay Line lists it, greyed out with
--- what the run takes. `spec`: `job`, the LinkJobs job each pipe queues; `skip(at)`, which tanks to
--- leave out; `refusal(at)`, a Tooltip key greying a tank out before its pipe is listed, or nil;
--- `noneKey`, what the submenu says when it lists none.
function TankMenu.addPlumbOptions(context, playerNum, character, object, spec)
    local here = EnhancedIrrigation.squareOf(object)
    local name = getText("ContextMenu_EnhancedIrrigation_PlumbToTank")
    local tools = EnhancedIrrigation.Materials.needs(character, LinkJobs.PLUMB_TOOLS)
    if EnhancedIrrigation.firstUnmet(tools) then
        Needs.show(context:addOption(name), tools)
        return
    end
    local submenu = Needs.addSubMenu(context, name)
    local kinds = Pipes.kindsCarried(character)
    local listed = 0
    for _, entry in ipairs(Links.tanksInReach(object)) do
        if not spec.skip(entry.at) then
            local label = TankMenu.tankLabel(here, entry.at)
            local refusal = spec.refusal(entry.at) or (#kinds == 0 and "Tooltip_EnhancedIrrigation_NoPipe") or nil
            if refusal then
                Needs.refuse(submenu:addOption(label), refusal)
            else
                local pipes = Needs.addSubMenu(submenu, label)
                for _, kind in ipairs(kinds) do
                    local with = Links.encode(entry.at, kind)
                    local option = pipes:addOption(getItemNameFromFullType(Pipes.KINDS[kind].item), playerNum,
                        Action.queue, "link", spec.job, object, with)
                    TankMenu.showLink(option, character, spec.job, object, with)
                end
            end
            listed = listed + 1
        end
    end
    if listed == 0 then
        submenu:addOption(getText(spec.noneKey)).notAvailable = true
    end
end

--- Unplumb at `object`, a tank, a fixture, or the floor of a square one stood on: a submenu of the
--- pipe buried from its square.
function TankMenu.addUnplumbOptions(context, playerNum, character, object)
    local here = EnhancedIrrigation.squareOf(object)
    local links = Links.linksAt(here)
    if #links == 0 then return end
    local submenu = Needs.addSubMenu(context, getText("ContextMenu_EnhancedIrrigation_Unplumb"))
    for _, link in ipairs(links) do
        local there = Links.otherEnd(link, here)
        local with = Links.encode(there)
        local option = submenu:addOption(TankMenu.linkLabel(here, there), playerNum, Action.queue, "link",
            LinkJobs.UNPLUMB, object, with)
        TankMenu.showLink(option, character, LinkJobs.UNPLUMB, object, with)
    end
end

-- The floor of the first right-clicked square with no tank or fixture on it that buried pipe runs
-- from, or nil. A fixture offers its own Unplumb (FixtureMenu.lua).
local function bareEnd(worldobjects)
    for _, clicked in ipairs(worldobjects) do
        local square = clicked:getSquare()
        local floor = square and square:getFloor()
        if floor and not Tanks.tankOn(square) and not Fixtures.fixtureOn(square)
                and #Links.linksAt(EnhancedIrrigation.squareOf(floor)) > 0 then
            return floor
        end
    end
    return nil
end

function TankMenu.onFill(playerNum, context, worldobjects, test)
    local character = getSpecificPlayer(playerNum)
    if not character or character:getVehicle() then return end
    local stand = Needs.findClicked(worldobjects, function(object)
        return Stands.isStand(object) or Stands.isRaised(object)
    end)
    local tank = Needs.findClicked(worldobjects, Tanks.isTank)
    local floor = not tank and bareEnd(worldobjects)
    if not (stand or tank or floor) then return end
    if test then return ISWorldObjectContextMenu.setTest() end
    if stand then
        addStandOptions(context, playerNum, character, stand)
    end
    if tank then
        local here = EnhancedIrrigation.squareOf(tank)
        TankMenu.addPlumbOptions(context, playerNum, character, tank, {
            job = LinkJobs.PLUMB,
            skip = function(at) return Links.find(here, at) ~= nil end,
            refusal = function() return nil end,
            noneKey = "ContextMenu_EnhancedIrrigation_NoTankInReach",
        })
        TankMenu.addUnplumbOptions(context, playerNum, character, tank)
    elseif floor then
        TankMenu.addUnplumbOptions(context, playerNum, character, floor)
    end
end

Events.OnFillWorldObjectContextMenu.Add(TankMenu.onFill)

return TankMenu
