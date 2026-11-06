-- Garden lines on the right-click menu: Lay Line on the ground, by the pipe the character carries,
-- and on a line tile one submenu with what the tile is and the jobs it takes.

require "EnhancedIrrigation/Utilities"
local Items = require "cf_commonlib/Items"
local Materials = require "cf_commonlib/Materials"
local Needs = require "cf_commonlib/Needs"
local JobOptions = require "cf_commonlib/JobOptions"
require "EnhancedIrrigation/Pipes"
require "EnhancedIrrigation/Lines/Lines"
require "EnhancedIrrigation/Lines/LineJobs"
require "EnhancedIrrigation/Lines/Sprinklers"
require "EnhancedIrrigation/Valves"
require "EnhancedIrrigation/UI/ValveUI"
require "EnhancedIrrigation/TimedActions/EnhancedIrrigationAction"
require "EnhancedIrrigation/TimedActions/EnhancedIrrigationWaterAction"

EnhancedIrrigation = EnhancedIrrigation or {}
local LineMenu = {}
EnhancedIrrigation.LineMenu = LineMenu

local Lines = EnhancedIrrigation.Lines
local LineJobs = EnhancedIrrigation.LineJobs
local Pipes = EnhancedIrrigation.Pipes
local Valves, ValveUI = EnhancedIrrigation.Valves, EnhancedIrrigation.ValveUI

-- What a tile is ------------------------------------------------------------------------------------

function LineMenu.describe(state)
    local holes = state.holed and "IGUI_EnhancedIrrigation_Holed" or "IGUI_EnhancedIrrigation_NoHoles"
    local parts = { getText(holes) }
    if state.cracked then
        table.insert(parts, getText("IGUI_EnhancedIrrigation_Cracked"))
    end
    if state.full then
        table.insert(parts, getText("IGUI_EnhancedIrrigation_Full"))
    end
    if state.tap then
        table.insert(parts, getText("IGUI_EnhancedIrrigation_Tapped"))
    end
    if state.valve then
        table.insert(parts, Valves.describe(state.valve))
    end
    if state.sprinkler then
        table.insert(parts, getText("IGUI_EnhancedIrrigation_WithSprinkler"))
    end
    if state.running or state.valveOpen then
        table.insert(parts, getText("IGUI_EnhancedIrrigation_LineRunning"))
    end
    return getText("IGUI_EnhancedIrrigation_LabelValue", getText("IGUI_EnhancedIrrigation_Pipe_" .. state.material),
        table.concat(parts, ", "))
end

-- Options -------------------------------------------------------------------------------------------

-- The Lawn Sprinkler carried in the best condition, or nil.
local function bestSprinkler(character)
    local items = character:getInventory():getAllTypeRecurse(EnhancedIrrigation.Sprinklers.ITEM)
    local best = nil
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if not best or item:getCondition() > best:getCondition() then
            best = item
        end
    end
    return best
end

local function addSprinkler(menu, playerNum, character, line, state)
    if state.sprinkler then
        JobOptions.add(menu, playerNum, LineJobs, LineJobs.TAKE_SPRINKLER, line)
        return
    end
    local sprinkler = bestSprinkler(character)
    local option = JobOptions.add(menu, playerNum, LineJobs, LineJobs.SET_SPRINKLER, line, sprinkler)
    option.itemForTexture = sprinkler
end

-- Drill Holes uses the first tool carried that gets into the pipe (LineJobs.holeTool), which its
-- needs name; one that punches warns that it may split brittle pipe.
local function addDrill(menu, playerNum, character, line, state)
    local option = JobOptions.add(menu, playerNum, LineJobs, LineJobs.DRILL, line)
    local tool = LineJobs.holeTool(character, state.material)
    if tool and option.toolTip and LineJobs.mayCrack(tool, state.material) then
        option.toolTip.description = option.toolTip.description .. " " .. getText("Tooltip_EnhancedIrrigation_MayCrack")
    end
end

--- The panel of the valve on the tap tile `line` as it stands now; nil once the valve is gone.
function LineMenu.valvePanel(line)
    local state = Lines.stateOf(line)
    local valve = state and state.valve
    local job = valve and (Valves.kindOf(valve.item) == "windup" and LineJobs.WIND_VALVE or LineJobs.SET_TIMER)
    return ValveUI.specOf(valve, line, "line", job)
end

--- Walks `character` to the tap tile `line` and opens its valve's panel there (ValveUI).
function LineMenu.openValve(character, line)
    ValveUI.walkAndOpen(character, line, function() return LineMenu.valvePanel(line) end)
end

local function addValve(menu, playerNum, character, line, state)
    if state.valve then
        local windUp = Valves.kindOf(state.valve.item) == "windup"
        local name = windUp and "ContextMenu_EnhancedIrrigation_WindValve" or "ContextMenu_EnhancedIrrigation_SetTimer"
        menu:addOption(getText(name), character, LineMenu.openValve, line)
        JobOptions.add(menu, playerNum, LineJobs, LineJobs.TAKE_OFF_VALVE, line)
        return
    end
    JobOptions.addEach(menu, playerNum, LineJobs, LineJobs.FIT_VALVE, line, Items.firstOfEach(character, Valves.ORDER))
end

local function addLineOptions(context, playerNum, character, line, state)
    local menu = JobOptions.addSubMenu(context, getText("ContextMenu_EnhancedIrrigation_GardenLine"))
    menu:addOption(LineMenu.describe(state)).notAvailable = true
    if state.tap then
        local water = menu:addOption(getText("ContextMenu_EnhancedIrrigation_WaterFromTank"), playerNum,
            EnhancedIrrigationWaterAction.queue, line)
        Needs.refuse(water, LineJobs.refusal(character, LineJobs.WATER, line))
        addValve(menu, playerNum, character, line, state)
    else
        JobOptions.add(menu, playerNum, LineJobs, LineJobs.TAP, line)
    end
    if not state.holed then
        addDrill(menu, playerNum, character, line, state)
    end
    if state.cracked then
        JobOptions.add(menu, playerNum, LineJobs, LineJobs.PATCH, line)
    end
    JobOptions.add(menu, playerNum, LineJobs, LineJobs.DRAIN, line)
    addSprinkler(menu, playerNum, character, line, state)
    JobOptions.add(menu, playerNum, LineJobs, LineJobs.TAKE_UP, line)
end

-- The cursor lives with the server's Lua, which loads after this file, so it's looked up here.
local function addLay(context, playerNum, character, materials)
    local menu = JobOptions.addSubMenu(context, getText("ContextMenu_EnhancedIrrigation_LayLine"))
    for _, material in ipairs(materials) do
        local option = menu:addOption(getItemNameFromFullType(Pipes.MATERIALS[material].item), playerNum,
            EnhancedIrrigation.LineCursor.start, material)
        Needs.show(option, Materials.needs(character, Pipes.layMaterials(material, 1)))
    end
end

local function clickedFloorSquare(worldobjects)
    for _, clicked in ipairs(worldobjects) do
        local square = clicked:getSquare()
        if square and square:getFloor() then
            return square
        end
    end
    return nil
end

-- What a click offers garden-line options for: the line tile clicked, with its state, and the pipe
-- carried to lay when a floor was clicked.
local function clickedLine(worldobjects, character)
    local line = JobOptions.findClicked(worldobjects, Lines.isLine)
    local state = line and Lines.stateOf(line)
    local materials = Pipes.materialsCarried(character)
    local lays = clickedFloorSquare(worldobjects) ~= nil and #materials > 0
    if not (state or lays) then
        return nil
    end
    return { line = line, state = state, materials = lays and materials or nil }
end

LineMenu.onFill = JobOptions.onWorldMenu(clickedLine, function(context, playerNum, character, clicked)
    if clicked.state then
        addLineOptions(context, playerNum, character, clicked.line, clicked.state)
    end
    if clicked.materials then
        addLay(context, playerNum, character, clicked.materials)
    end
end)

return LineMenu
