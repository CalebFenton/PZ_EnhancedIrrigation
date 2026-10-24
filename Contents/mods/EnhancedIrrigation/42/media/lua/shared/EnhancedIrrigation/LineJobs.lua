-- The hands-on jobs at a garden line: laying a tile, drilling holes, fitting the tap, patching a
-- crack, draining, setting and taking a sprinkler, fitting, setting and taking off a tap's valve,
-- and taking the pipe up, done on the authority by server/EnhancedIrrigation/Lines/LineSystem.lua.
-- Running water from the tap is Taps.lua's, from a valve Valves.lua's, and from a pump Pumps.lua's.

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Materials"
require "EnhancedIrrigation/Jobs"
require "EnhancedIrrigation/Pipes"
require "EnhancedIrrigation/Tanks"
require "EnhancedIrrigation/Lines"
require "EnhancedIrrigation/Pumps"
require "EnhancedIrrigation/Sprinklers"
require "EnhancedIrrigation/Valves"
require "EnhancedIrrigation/Taps"

EnhancedIrrigation = EnhancedIrrigation or {}
local LineJobs = {}
EnhancedIrrigation.LineJobs = LineJobs

local Lines = EnhancedIrrigation.Lines
local Tanks = EnhancedIrrigation.Tanks
local Pipes = EnhancedIrrigation.Pipes
local Materials = EnhancedIrrigation.Materials
local Pumps, Sprinklers, Valves = EnhancedIrrigation.Pumps, EnhancedIrrigation.Sprinklers, EnhancedIrrigation.Valves
local Taps = EnhancedIrrigation.Taps

LineJobs.LAY = "LayLine"
LineJobs.DRILL = "DrillHoles"
LineJobs.TAP = "FitTap"
LineJobs.PATCH = "PatchCrack"
LineJobs.DRAIN = "DrainLine"
LineJobs.TAKE_UP = "TakeUpPipe"
LineJobs.SET_SPRINKLER = "SetSprinkler"
LineJobs.TAKE_SPRINKLER = "TakeSprinkler"
LineJobs.FIT_VALVE = "FitValve"
LineJobs.TAKE_VALVE = "TakeValve"
LineJobs.WIND_VALVE = "WindValve"
LineJobs.SET_VALVE_TIMER = "SetValveTimer"

-- How long winding or setting a valve takes: a turn of a knob, as long as a Pump House's switch.
LineJobs.VALVE_MINUTES = 1

local function firstTagged(tag)
    return function(character)
        return character:getInventory():getFirstTagEvalRecurse(ItemTag[tag], EnhancedIrrigation.notBroken)
    end
end

local function firstOfType(fullType)
    return function(character)
        return character:getInventory():getFirstTypeRecurse(fullType)
    end
end

-- What makes a hole, in the order Drill Holes picks among those carried: the tools that cut before
-- the ones that punch. `reach`: the hardest pipe it gets into (Pipes.KINDS hardness). `punches`: it
-- may split brittle pipe (LineJobs.mayCrack). `materials`: what it takes, the tool itself first.
-- `hold`: the item held while drilling.
LineJobs.HOLE_TOOLS = {
    { reach = 3, hold = firstTagged("DRILL_METAL"), materials = { { tool = "DRILL_METAL", item = "Base.HandDrill" } } },
    { reach = 2, hold = firstOfType("Base.OldDrill"), materials = { { item = "Base.OldDrill", keep = true } } },
    { reach = 1, hold = firstTagged("AWL"), materials = { { tool = "AWL", item = "Base.Awl" } } },
    { reach = 2, punches = true, hold = firstOfType("Base.StoneDrill"), materials = { { item = "Base.StoneDrill", keep = true } } },
    -- One nail is driven through and pulled out bent.
    {
        reach = 2, punches = true, hold = firstTagged("HAMMER"),
        materials = { { tool = "HAMMER", item = "Base.Hammer" }, { item = "Base.Nails", need = 1 } },
    },
}

--- The first of HOLE_TOOLS that `character` carries and that gets into `material`'s pipe, or nil.
function LineJobs.holeTool(character, material)
    local hardness = Pipes.KINDS[material].hardness
    for _, tool in ipairs(LineJobs.HOLE_TOOLS) do
        if tool.reach >= hardness and Materials.needs(character, { tool.materials[1] })[1].have > 0 then
            return tool
        end
    end
    return nil
end

--- Whether a hole made with `tool` (of HOLE_TOOLS) may split `material`'s pipe.
function LineJobs.mayCrack(tool, material)
    return tool.punches == true and Pipes.KINDS[material].punchCracks == true
end

local function holeToolAt(character, object)
    local state = Lines.stateOf(object)
    return state and LineJobs.holeTool(character, state.material)
end

local holdWrench = firstTagged("PIPE_WRENCH")

-- Draining lets the line's water out where it's opened: longer lines take longer.
local DRAIN_MINUTES = 2
local DRAIN_TILES_A_MINUTE = 5

local function drainMinutes(object)
    return DRAIN_MINUTES + #Lines.component(object:getX(), object:getY(), object:getZ()) / DRAIN_TILES_A_MINUTE
end

-- Whether a pump stands in the 3x3 around x, y, z, on its floor: where its outlet can start a line.
local function pumpBeside(x, y, z)
    for dx = -1, 1 do
        for dy = -1, 1 do
            if Pumps.pumpAt(x + dx, y + dy, z) then
                return true
            end
        end
    end
    return false
end

--- Why a line tile can't go on `square`, a Tooltip key, or nil. `pending(x, y, z)`, if given, says
--- which squares already have a tile queued to be laid, which count as line for adjacency. Line
--- behind a wall (Lines.joins) neither touches nor joins it.
function LineJobs.layBlocker(square, pending)
    if not Lines.canTakeLine(square) then
        return "Tooltip_EnhancedIrrigation_CantLayHere"
    end
    local x, y, z = square:getX(), square:getY(), square:getZ()
    local touches, fed, seen = false, 0, {}
    for _, step in ipairs(Lines.STEPS) do
        local nx, ny = x + step.dx, y + step.dy
        local joins = Lines.joins(x, y, z, step)
        if joins and Lines.stateAt(nx, ny, z) then
            touches = true
            if not seen[EnhancedIrrigation.squareKey(nx, ny, z)] then
                local tiles = Lines.component(nx, ny, z)
                for _, tile in ipairs(tiles) do
                    seen[EnhancedIrrigation.squareKey(tile.x, tile.y, z)] = true
                end
                if Lines.tapIn(tiles) or Pumps.pumpFeeding(tiles) then
                    fed = fed + 1
                end
            end
        elseif joins and pending and pending(nx, ny, z) then
            touches = true
        end
    end
    if not touches and #Tanks.tanksReaching(x, y, z) == 0 and not pumpBeside(x, y, z) then
        return "Tooltip_EnhancedIrrigation_NoTankReach"
    end
    -- A pump's outlet stays buried where its tile was taken up, and feeds a tile laid back there.
    if Pumps.pumpFeeding({ { x = x, y = y, z = z } }) then
        fed = fed + 1
    end
    -- One line takes one tap or one pump: two would each run every outlet on it.
    if fed >= 2 then
        return "Tooltip_EnhancedIrrigation_JoinsTwoFeeds"
    end
    return nil
end

-- A row's blocker for a job at a line tile: refuses where there is none, else asks
-- `check(character, object, state)` with the tile as Lines.stateAt knows it.
local function atLine(check)
    return function(character, object)
        local state = Lines.stateOf(object)
        if not state then
            return "Tooltip_EnhancedIrrigation_NoLine"
        end
        return check(character, object, state)
    end
end

-- Whether `item` is a Lawn Sprinkler `character` carries.
local function carriesSprinkler(character, item)
    return instanceof(item, "InventoryItem") and item:getFullType() == Sprinklers.ITEM
        and character:getInventory():containsRecursive(item)
end

-- Whether `item` is a valve (Valves.ITEMS) `character` carries.
local function carriesValve(character, item)
    return instanceof(item, "InventoryItem") and Valves.kindOf(item:getFullType()) ~= nil
        and character:getInventory():containsRecursive(item)
end

-- Why a job at a tap's valve of `kind` ("windup" or "timer") can't be done at `object`, a Tooltip
-- key, or nil: it's no line tile, or has no such valve.
local function valveBlocker(object, kind)
    local state = Lines.stateOf(object)
    if not state then
        return "Tooltip_EnhancedIrrigation_NoLine"
    end
    if not (state.valve and Valves.kindOf(state.valve.item) == kind) then
        return "Tooltip_EnhancedIrrigation_NoValveHere"
    end
    return nil
end

-- Lay's `with` is the pipe kind, Set Sprinkler's the sprinkler carried, Fit Valve's the valve
-- carried, Wind Valve's its minutes and Set Valve Timer's its setting (Valves.decodeWind and
-- decodeTimer); the others' is nil.
LineJobs.JOBS = {
    [LineJobs.LAY] = {
        minutes = 3,
        equip = function(character, floor, kind)
            return Pipes.KINDS[kind] and Pipes.KINDS[kind].wrench and holdWrench(character) or nil
        end,
        blocker = function(character, floor, kind)
            if not Pipes.KINDS[kind] then
                return "Tooltip_EnhancedIrrigation_CantLayHere"
            end
            return LineJobs.layBlocker(floor:getSquare())
        end,
        materials = function(character, floor, kind)
            return Pipes.KINDS[kind] and Pipes.layMaterials(kind, 1) or {}
        end,
    },
    [LineJobs.DRILL] = {
        minutes = 2,
        equip = function(character, object)
            local tool = holeToolAt(character, object)
            return tool and tool.hold(character)
        end,
        blocker = atLine(function(character, object, state)
            if state.holed then
                return "Tooltip_EnhancedIrrigation_AlreadyHoled"
            end
            return not LineJobs.holeTool(character, state.material) and "Tooltip_EnhancedIrrigation_NoHoleMaker" or nil
        end),
        materials = function(character, object)
            local tool = holeToolAt(character, object)
            return tool and tool.materials or {}
        end,
    },
    [LineJobs.TAP] = {
        minutes = 10, sound = "RepairWithWrench", equip = holdWrench,
        blocker = atLine(function(character, object, state)
            local x, y, z = object:getX(), object:getY(), object:getZ()
            if state.sprinkler then
                return "Tooltip_EnhancedIrrigation_TapAndSprinkler"
            end
            local tiles = Lines.component(x, y, z)
            if Lines.tapIn(tiles) then
                return "Tooltip_EnhancedIrrigation_LineHasTap"
            end
            -- One line takes a tap or a pump, not both, so a pump never pushes against a tank.
            if Pumps.pumpFeeding(tiles) then
                return "Tooltip_EnhancedIrrigation_LinePumped"
            end
            return #Tanks.pushingAt(x, y, z) == 0 and "Tooltip_EnhancedIrrigation_NoPressure" or nil
        end),
        materials = function(character, object)
            local list = { Pipes.WRENCH }
            local state = Lines.stateOf(object)
            for _, material in ipairs(state and Pipes.materials(state.material, 1) or {}) do
                table.insert(list, material)
            end
            return list
        end,
    },
    [LineJobs.PATCH] = {
        minutes = 3,
        blocker = atLine(function(character, object, state)
            return not state.cracked and "Tooltip_EnhancedIrrigation_NotCracked" or nil
        end),
        materials = { Pipes.GLUE },
    },
    [LineJobs.DRAIN] = {
        minutes = drainMinutes, sound = "WaterCrops",
        blocker = atLine(function(character, object)
            local full = false
            for _, tile in ipairs(Lines.component(object:getX(), object:getY(), object:getZ())) do
                -- Its pump or its tap's valve holds it, as a character holds a tap
                -- (LineSystem.showRunning, ValveSystem.lua).
                if tile.state.running or tile.state.valveOpen then
                    return "Tooltip_EnhancedIrrigation_LineRunning"
                end
                full = full or tile.state.full
            end
            return not full and "Tooltip_EnhancedIrrigation_LineEmpty" or nil
        end),
    },
    [LineJobs.TAKE_UP] = {
        minutes = 3,
        blocker = atLine(function() return nil end),
    },
    -- The sprinkler goes on as it is, its item taken by the job itself, being that one item rather
    -- than any of its type. A tap's riser takes the tile's fitting.
    [LineJobs.SET_SPRINKLER] = {
        minutes = 5, sound = "RepairWithWrench", equip = holdWrench,
        blocker = function(character, object, item)
            local state = Lines.stateOf(object)
            if not state then
                return "Tooltip_EnhancedIrrigation_NoLine"
            end
            if state.tap then
                return "Tooltip_EnhancedIrrigation_TapAndSprinkler"
            end
            if state.sprinkler then
                return "Tooltip_EnhancedIrrigation_HasSprinkler"
            end
            return not carriesSprinkler(character, item) and "Tooltip_EnhancedIrrigation_NoSprinkler" or nil
        end,
        materials = { Pipes.WRENCH },
    },
    [LineJobs.TAKE_SPRINKLER] = {
        minutes = 3, sound = "RepairWithWrench", equip = holdWrench,
        blocker = atLine(function(character, object, state)
            return not state.sprinkler and "Tooltip_EnhancedIrrigation_NoSprinklerHere" or nil
        end),
        materials = { Pipes.WRENCH },
    },
    -- A hose-end valve screws onto the tap's spout. It goes on as the item carried, taken by the
    -- job itself.
    [LineJobs.FIT_VALVE] = {
        minutes = 5, sound = "RepairWithWrench", equip = holdWrench,
        blocker = function(character, object, item)
            local state = Lines.stateOf(object)
            if not state then
                return "Tooltip_EnhancedIrrigation_NoLine"
            end
            if not state.tap then
                return "Tooltip_EnhancedIrrigation_NoTap"
            end
            if state.valve then
                return "Tooltip_EnhancedIrrigation_HasValve"
            end
            return not carriesValve(character, item) and "Tooltip_EnhancedIrrigation_NoValve" or nil
        end,
        materials = { Pipes.WRENCH },
    },
    [LineJobs.TAKE_VALVE] = {
        minutes = 3, sound = "RepairWithWrench", equip = holdWrench,
        blocker = atLine(function(character, object, state)
            return not state.valve and "Tooltip_EnhancedIrrigation_NoValveHere" or nil
        end),
        materials = { Pipes.WRENCH },
    },
    -- Winding it down to nothing shuts it whatever the tap; winding it up needs a tap that would
    -- run: nobody holding it, and a tank to feed it.
    [LineJobs.WIND_VALVE] = {
        minutes = LineJobs.VALVE_MINUTES, position = "Mid",
        blocker = function(character, object, with)
            local refusal = valveBlocker(object, "windup")
            if refusal then
                return refusal
            end
            local minutes = Valves.decodeWind(with)
            if not minutes then
                return "Tooltip_EnhancedIrrigation_UnknownJob"
            end
            if minutes == 0 then
                return nil
            end
            if Lines.stateOf(object).heldBy then
                return "Tooltip_EnhancedIrrigation_TapInUse"
            end
            local _, noTank = Taps.tankFor(object)
            return noTank
        end,
    },
    [LineJobs.SET_VALVE_TIMER] = {
        minutes = LineJobs.VALVE_MINUTES, position = "Mid",
        blocker = function(character, object, with)
            return valveBlocker(object, "timer")
                or (not Valves.decodeTimer(with) and "Tooltip_EnhancedIrrigation_UnknownJob" or nil)
        end,
    },
}

EnhancedIrrigation.Jobs.define(LineJobs)

return LineJobs
