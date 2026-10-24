-- Garden lines on the right-click menu: "Lay Line" on the ground, by the pipe the character
-- carries, which starts the Lay Line cursor; and on a line tile one "Garden Line" submenu with what
-- the tile is and every job it takes, greyed out saying why when LineJobs refuses it.

require "ISUI/ISWorldObjectContextMenu"
require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Materials"
require "EnhancedIrrigation/Pipes"
require "EnhancedIrrigation/Lines"
require "EnhancedIrrigation/LineJobs"
require "EnhancedIrrigation/Taps"
require "EnhancedIrrigation/Sprinklers"
require "EnhancedIrrigation/UI/Needs"
require "EnhancedIrrigation/TimedActions/EnhancedIrrigationAction"
require "EnhancedIrrigation/TimedActions/EnhancedIrrigationWaterAction"

EnhancedIrrigation = EnhancedIrrigation or {}
local LineMenu = {}
EnhancedIrrigation.LineMenu = LineMenu

local Lines = EnhancedIrrigation.Lines
local LineJobs = EnhancedIrrigation.LineJobs
local Taps = EnhancedIrrigation.Taps
local Pipes = EnhancedIrrigation.Pipes
local Needs = EnhancedIrrigation.Needs
local Materials = EnhancedIrrigation.Materials

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
    if state.sprinkler then
        table.insert(parts, getText("IGUI_EnhancedIrrigation_WithSprinkler"))
    end
    if state.running then
        table.insert(parts, getText("IGUI_EnhancedIrrigation_LineRunning"))
    end
    return getText("IGUI_EnhancedIrrigation_Pipe_" .. state.material) .. ": " .. table.concat(parts, ", ")
end

-- Options -------------------------------------------------------------------------------------------

local function addJob(menu, playerNum, character, nameKey, job, object, with)
    local option = menu:addOption(getText(nameKey), playerNum, EnhancedIrrigationAction.queue, "line", job, object, with)
    Needs.show(option, LineJobs.needs(character, job, object, with), LineJobs.blocker(character, job, object, with))
    return option
end

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

-- Set Sprinkler sets the one carried in the best condition; a tile with one offers Take Sprinkler.
local function addSprinkler(menu, playerNum, character, line, state)
    if state.sprinkler then
        addJob(menu, playerNum, character, "ContextMenu_EnhancedIrrigation_TakeSprinkler", LineJobs.TAKE_SPRINKLER, line)
        return
    end
    local option = addJob(menu, playerNum, character, "ContextMenu_EnhancedIrrigation_SetSprinkler",
        LineJobs.SET_SPRINKLER, line, bestSprinkler(character))
    option.itemForTexture = bestSprinkler(character)
end

-- Drill Holes uses the first tool carried that gets into the pipe (LineJobs.holeTool), which its
-- needs name; one that punches warns that it may split brittle pipe.
local function addDrill(menu, playerNum, character, line, state)
    local option = addJob(menu, playerNum, character, "ContextMenu_EnhancedIrrigation_DrillHoles", LineJobs.DRILL, line)
    local tool = LineJobs.holeTool(character, state.material)
    if tool and option.toolTip and LineJobs.mayCrack(tool, state.material) then
        option.toolTip.description = option.toolTip.description .. " " .. getText("Tooltip_EnhancedIrrigation_MayCrack")
    end
end

local function addLineOptions(context, playerNum, character, line, state)
    local menu = Needs.addSubMenu(context, getText("ContextMenu_EnhancedIrrigation_GardenLine"))
    menu:addOption(LineMenu.describe(state)).notAvailable = true
    if state.tap then
        local water = menu:addOption(getText("ContextMenu_EnhancedIrrigation_WaterFromTank"), playerNum,
            EnhancedIrrigationWaterAction.queue, line)
        Needs.refuse(water, Taps.blocker(line, character))
    else
        addJob(menu, playerNum, character, "ContextMenu_EnhancedIrrigation_FitTap", LineJobs.TAP, line)
    end
    if not state.holed then
        addDrill(menu, playerNum, character, line, state)
    end
    if state.cracked then
        addJob(menu, playerNum, character, "ContextMenu_EnhancedIrrigation_PatchCrack", LineJobs.PATCH, line)
    end
    addJob(menu, playerNum, character, "ContextMenu_EnhancedIrrigation_DrainLine", LineJobs.DRAIN, line)
    addSprinkler(menu, playerNum, character, line, state)
    addJob(menu, playerNum, character, "ContextMenu_EnhancedIrrigation_TakeUpPipe", LineJobs.TAKE_UP, line)
end

-- The cursor lives with the server's Lua, which loads after this file, so it's looked up here.
local function addLay(context, playerNum, character, kinds)
    local menu = Needs.addSubMenu(context, getText("ContextMenu_EnhancedIrrigation_LayLine"))
    for _, kind in ipairs(kinds) do
        local option = menu:addOption(getItemNameFromFullType(Pipes.KINDS[kind].item), playerNum,
            EnhancedIrrigation.LineCursor.start, kind)
        Needs.show(option, Materials.needs(character, Pipes.layMaterials(kind, 1)))
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

function LineMenu.onFill(playerNum, context, worldobjects, test)
    local character = getSpecificPlayer(playerNum)
    if not character or character:getVehicle() then
        return
    end
    local line = Needs.findClicked(worldobjects, Lines.isLine)
    local state = line and Lines.stateOf(line)
    local kinds = Pipes.kindsCarried(character)
    local square = clickedFloorSquare(worldobjects)
    if not state and not (square and #kinds > 0) then
        return
    end
    if test then
        return ISWorldObjectContextMenu.setTest()
    end
    if state then
        addLineOptions(context, playerNum, character, line, state)
    end
    if square and #kinds > 0 then
        addLay(context, playerNum, character, kinds)
    end
end

Events.OnFillWorldObjectContextMenu.Add(LineMenu.onFill)

return LineMenu
