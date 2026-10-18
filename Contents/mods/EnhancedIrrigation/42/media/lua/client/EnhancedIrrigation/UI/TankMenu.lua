-- The right-click options of tanks and Tank Stands: Set Barrel on Stand and Take Barrel Down on a
-- stand, and on any tank Plumb to Tank, with a submenu of the tanks in reach, and Unplumb, with a
-- submenu of the pipe buried from it. The floor where a plumbed tank stood also offers Unplumb, so
-- pipe whose tanks are both gone is found where it was laid. Each option is greyed out saying why
-- when its job would be refused (StandJobs, LinkJobs).

require "ISUI/ISWorldObjectContextMenu"
require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Materials"
require "EnhancedIrrigation/UI/Needs"
require "EnhancedIrrigation/Tanks"
require "EnhancedIrrigation/Stands"
require "EnhancedIrrigation/StandJobs"
require "EnhancedIrrigation/Links"
require "EnhancedIrrigation/LinkJobs"
require "EnhancedIrrigation/TimedActions/EnhancedIrrigationAction"

EnhancedIrrigation = EnhancedIrrigation or {}
local TankMenu = {}
EnhancedIrrigation.TankMenu = TankMenu

local Needs, Tanks, Stands = EnhancedIrrigation.Needs, EnhancedIrrigation.Tanks, EnhancedIrrigation.Stands
local StandJobs, Links, LinkJobs = EnhancedIrrigation.StandJobs, EnhancedIrrigation.Links, EnhancedIrrigation.LinkJobs
local Action = EnhancedIrrigationAction

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

--- How Unplumb names the buried pipe from the square `here` to the square `there`: by the tank at
--- its far end, or as pipe to an empty spot when that square is loaded with no tank on it.
function TankMenu.linkLabel(here, there)
    local square = getCell():getGridSquare(there.x, there.y, there.z)
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
local function showLink(option, character, job, tank, with)
    Needs.show(option, LinkJobs.needs(character, job, tank, with), LinkJobs.blocker(character, job, tank, with))
end

local function addPlumbOptions(context, playerNum, character, tank)
    local here = EnhancedIrrigation.squareOf(tank)
    local name = getText("ContextMenu_EnhancedIrrigation_PlumbToTank")
    local tools = EnhancedIrrigation.Materials.needs(character, LinkJobs.PLUMB_TOOLS)
    if EnhancedIrrigation.firstUnmet(tools) then
        Needs.show(context:addOption(name), tools)
        return
    end
    local submenu = Needs.addSubMenu(context, name)
    local listed = 0
    for _, entry in ipairs(Links.tanksInReach(tank)) do
        if not Links.find(here, entry.at) then
            local with = Links.encode(entry.at)
            local option = submenu:addOption(TankMenu.tankLabel(here, entry.at), playerNum, Action.queue, "link",
                LinkJobs.PLUMB, tank, with)
            showLink(option, character, LinkJobs.PLUMB, tank, with)
            listed = listed + 1
        end
    end
    if listed == 0 then
        submenu:addOption(getText("ContextMenu_EnhancedIrrigation_NoTankInReach")).notAvailable = true
    end
end

-- Unplumb at `object`, a tank or the floor of a square a tank stood on: a submenu of the pipe buried
-- from its square.
local function addUnplumbOptions(context, playerNum, character, object)
    local here = EnhancedIrrigation.squareOf(object)
    local links = Links.linksAt(here)
    if #links == 0 then return end
    local submenu = Needs.addSubMenu(context, getText("ContextMenu_EnhancedIrrigation_Unplumb"))
    for _, link in ipairs(links) do
        local there = Links.otherEnd(link, here)
        local with = Links.encode(there)
        local option = submenu:addOption(TankMenu.linkLabel(here, there), playerNum, Action.queue, "link",
            LinkJobs.UNPLUMB, object, with)
        showLink(option, character, LinkJobs.UNPLUMB, object, with)
    end
end

-- The floor of the first right-clicked square with no tank on it that buried pipe runs from, or nil.
local function bareEnd(worldobjects)
    for _, clicked in ipairs(worldobjects) do
        local square = clicked:getSquare()
        local floor = square and square:getFloor()
        if floor and not Tanks.tankOn(square) and #Links.linksAt(EnhancedIrrigation.squareOf(floor)) > 0 then
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
        addPlumbOptions(context, playerNum, character, tank)
        addUnplumbOptions(context, playerNum, character, tank)
    elseif floor then
        addUnplumbOptions(context, playerNum, character, floor)
    end
end

Events.OnFillWorldObjectContextMenu.Add(TankMenu.onFill)

return TankMenu
