-- The plumbing options tanks, fixtures, treatment units and pumps share, and those of tanks: Plumb
-- to Tank and Unplumb. The floor where a plumbed tank stood, or a pump's line tile, also offers
-- Unplumb, so pipe whose tanks are both gone is found where it was laid.

require "ISUI/ISWorldObjectContextMenu"
require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Materials"
require "EnhancedIrrigation/UI/Needs"
require "EnhancedIrrigation/Pipes"
require "EnhancedIrrigation/Tanks"
require "EnhancedIrrigation/Links/Links"
require "EnhancedIrrigation/Links/LinkJobs"
require "EnhancedIrrigation/Fixtures/Fixtures"
require "EnhancedIrrigation/Treatment/Treatment"
require "EnhancedIrrigation/Pumps/Pumps"
require "EnhancedIrrigation/Lines/Lines"
require "EnhancedIrrigation/UI/JobOptions"
-- Registers its menu first, so a raised barrel lists its stand's options above its plumbing.
require "EnhancedIrrigation/UI/StandMenu"

EnhancedIrrigation = EnhancedIrrigation or {}
local LinkMenu = {}
EnhancedIrrigation.LinkMenu = LinkMenu

local Needs, Tanks, Links = EnhancedIrrigation.Needs, EnhancedIrrigation.Tanks, EnhancedIrrigation.Links
local LinkJobs, Pipes, Fixtures = EnhancedIrrigation.LinkJobs, EnhancedIrrigation.Pipes, EnhancedIrrigation.Fixtures
local Treatment, Pumps, Lines = EnhancedIrrigation.Treatment, EnhancedIrrigation.Pumps, EnhancedIrrigation.Lines
local JobOptions = EnhancedIrrigation.JobOptions

-- Compass points counter-clockwise from east, as an angle with north up (y grows southward).
local DIRECTIONS = { "E", "NE", "N", "NW", "W", "SW", "S", "SE" }

--- Which way the square `there` lies from `here`, in words: a compass point, or above or below.
function LinkMenu.direction(here, there)
    local dx, dy = there.x - here.x, there.y - here.y
    if dx == 0 and dy == 0 then
        return getText(there.z > here.z and "IGUI_EnhancedIrrigation_Above" or "IGUI_EnhancedIrrigation_Below")
    end
    -- Shifted a turn first: the game's Lua keeps the dividend's sign in %, so a square to the south
    -- would give a negative sector.
    local sector = (math.floor((math.atan2(-dy, dx) + math.pi / 8) / (math.pi / 4)) + 8) % 8
    return getText("IGUI_EnhancedIrrigation_Direction_" .. DIRECTIONS[sector + 1])
end

--- How the menu names the tank on the square `there`, seen from the square `here`: what it is,
--- how far and which way, and its level; just how far and which way when it isn't loaded here.
function LinkMenu.tankLabel(here, there)
    local tank = Tanks.tankAt(there.x, there.y, there.z)
    local distance, direction = Links.distance(here, there), LinkMenu.direction(here, there)
    if not tank then
        return getText("ContextMenu_EnhancedIrrigation_TankOutOfSight", distance, direction)
    end
    return getText("ContextMenu_EnhancedIrrigation_TankThere", tank:getFluidContainer():getTranslatedContainerName(),
        distance, direction, Tanks.levelOf(tank))
end

--- How the menu names the garden line whose tile is on the square `there`, seen from `here`.
function LinkMenu.lineLabel(here, there)
    return getText("ContextMenu_EnhancedIrrigation_LineThere", Links.distance(here, there), LinkMenu.direction(here, there))
end

--- The name the game gives `object` ("Sink", "Bath", "Barrel Filter"), a fixture, a unit or a
--- pump, as vanilla's menus name it (IsoObject.getTileName); "" for an object with neither a
--- tile name nor a name of its own.
function LinkMenu.objectName(object)
    return object:getTileName() or ""
end

--- How Unplumb names the buried pipe from the square `here` to the square `there`: by the tank,
--- fixture, unit, pump or line at its far end, or as pipe to an empty spot when that square is
--- loaded with none of them.
function LinkMenu.linkLabel(here, there)
    local square = getCell():getGridSquare(there.x, there.y, there.z)
    local object = Fixtures.fixtureOn(square) or Treatment.unitOn(square) or Pumps.pumpOn(square)
    if object then
        return getText("ContextMenu_EnhancedIrrigation_PlumbedTo", getText("ContextMenu_EnhancedIrrigation_FixtureThere",
            LinkMenu.objectName(object), Links.distance(here, there), LinkMenu.direction(here, there)))
    end
    if Lines.lineOn(square) then
        return getText("ContextMenu_EnhancedIrrigation_PlumbedTo", LinkMenu.lineLabel(here, there))
    end
    if square and not Tanks.tankOn(square) then
        return getText("ContextMenu_EnhancedIrrigation_BuriedPipeToEmpty", Links.distance(here, there),
            LinkMenu.direction(here, there))
    end
    return getText("ContextMenu_EnhancedIrrigation_PlumbedTo", LinkMenu.tankLabel(here, there))
end

--- A plumbing option at `object` (a tank, a fixture, a unit or a pump): a submenu of the tanks in
--- reach, and with `spec.lines` the garden lines too, each by its nearest tile, each with a submenu
--- of the pipe the character carries to lay to it, as Lay Line lists it, greyed out with what the
--- run takes. `spec`: `nameKey`, the option's ContextMenu key; `job`, the LinkJobs job each pipe
--- queues; `skip(at)`, which tanks to leave out; `refusal(at)`, a Tooltip key greying a tank or line
--- out before its pipe is listed, or nil; `noneKey`, what the submenu says when it lists none.
function LinkMenu.addPlumbOptions(context, playerNum, character, object, spec)
    local here = EnhancedIrrigation.squareOf(object)
    local name = getText(spec.nameKey)
    local tools = EnhancedIrrigation.Materials.needs(character, LinkJobs.PLUMB_TOOLS)
    if EnhancedIrrigation.firstUnmet(tools) then
        Needs.show(context:addOption(name), tools)
        return
    end
    local submenu = Needs.addSubMenu(context, name)
    local kinds = Pipes.kindsCarried(character)
    local ends = {}
    for _, entry in ipairs(Links.inReach(object, Tanks.tankAt)) do
        if not spec.skip(entry.at) then
            table.insert(ends, { at = entry.at, distance = entry.distance, label = LinkMenu.tankLabel(here, entry.at) })
        end
    end
    for _, entry in ipairs(spec.lines and Pumps.linesInReach(object) or {}) do
        table.insert(ends, { at = entry.at, distance = entry.distance, label = LinkMenu.lineLabel(here, entry.at) })
    end
    table.sort(ends, function(p, q) return p.distance < q.distance end)
    for _, entry in ipairs(ends) do
        local refusal = spec.refusal(entry.at) or (#kinds == 0 and "Tooltip_EnhancedIrrigation_NoPipe") or nil
        if refusal then
            Needs.refuse(submenu:addOption(entry.label), refusal)
        else
            local pipes = Needs.addSubMenu(submenu, entry.label)
            for _, kind in ipairs(kinds) do
                local with = Links.encode(entry.at, kind)
                JobOptions.add(pipes, playerNum, character, "link", getItemNameFromFullType(Pipes.KINDS[kind].item),
                    spec.job, object, with)
            end
        end
    end
    if #ends == 0 then
        submenu:addOption(getText(spec.noneKey)).notAvailable = true
    end
end

--- Unplumb at `object`, a tank, a fixture, a unit, or the floor of a square one stood on: a submenu
--- of the pipe buried from its square.
function LinkMenu.addUnplumbOptions(context, playerNum, character, object)
    local here = EnhancedIrrigation.squareOf(object)
    local links = Links.linksAt(here)
    if #links == 0 then return end
    local submenu = Needs.addSubMenu(context, getText("ContextMenu_EnhancedIrrigation_Unplumb"))
    for _, link in ipairs(links) do
        local there = Links.otherEnd(link, here)
        local with = Links.encode(there)
        JobOptions.add(submenu, playerNum, character, "link", LinkMenu.linkLabel(here, there), LinkJobs.UNPLUMB,
            object, with)
    end
end

-- The floor of the first right-clicked square with no tank, fixture, unit or pump on it that buried
-- pipe runs from, or nil: those offer their own Unplumb.
local function bareEnd(worldobjects)
    for _, clicked in ipairs(worldobjects) do
        local square = clicked:getSquare()
        local floor = square and square:getFloor()
        if floor and not Tanks.tankOn(square) and not Fixtures.fixtureOn(square) and not Treatment.unitOn(square)
                and not Pumps.pumpOn(square) and #Links.linksAt(EnhancedIrrigation.squareOf(floor)) > 0 then
            return floor
        end
    end
    return nil
end

function LinkMenu.onFill(playerNum, context, worldobjects, test)
    local character = getSpecificPlayer(playerNum)
    if not character or character:getVehicle() then return end
    local tank = Needs.findClicked(worldobjects, Tanks.isTank)
    local floor = not tank and bareEnd(worldobjects)
    if not (tank or floor) then return end
    if test then return ISWorldObjectContextMenu.setTest() end
    if tank then
        local here = EnhancedIrrigation.squareOf(tank)
        LinkMenu.addPlumbOptions(context, playerNum, character, tank, {
            nameKey = "ContextMenu_EnhancedIrrigation_PlumbToTank",
            job = LinkJobs.PLUMB,
            skip = function(at) return Links.find(here, at) ~= nil end,
            refusal = function() return nil end,
            noneKey = "ContextMenu_EnhancedIrrigation_NoTankInReach",
        })
        LinkMenu.addUnplumbOptions(context, playerNum, character, tank)
    elseif floor then
        LinkMenu.addUnplumbOptions(context, playerNum, character, floor)
    end
end

Events.OnFillWorldObjectContextMenu.Add(LinkMenu.onFill)

return LinkMenu
