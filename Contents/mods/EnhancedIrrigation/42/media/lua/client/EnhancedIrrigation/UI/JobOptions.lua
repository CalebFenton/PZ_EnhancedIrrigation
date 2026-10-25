-- The right-click option of a job (EnhancedIrrigationAction), greyed out as its job module would
-- refuse it, so the menu, the action's start() and the authority can't disagree; the world menu's
-- hook for an object's options; and how the menus read an option of vanilla's.

require "ISUI/ISWorldObjectContextMenu"
require "EnhancedIrrigation/UI/Needs"
require "EnhancedIrrigation/TimedActions/EnhancedIrrigationAction"

EnhancedIrrigation = EnhancedIrrigation or {}
local JobOptions = {}
EnhancedIrrigation.JobOptions = JobOptions

local Needs = EnhancedIrrigation.Needs
local Action = EnhancedIrrigationAction

--- Adds to `menu` the option `label` that queues `job` of `feature` at `object` with `with`, greyed
--- out with what it lacks or why it is refused. Returns the option.
function JobOptions.add(menu, playerNum, character, feature, label, job, object, with)
    local jobs = Action.jobsOf(feature)
    local option = menu:addOption(label, playerNum, Action.queue, feature, job, object, with)
    Needs.show(option, jobs.needs(character, job, object, with), jobs.blocker(character, job, object, with))
    return option
end

--- Adds `job` done with an item carried: a submenu `label` with an option for each of `items`,
--- named `nameOf(item)` (its display name without) and showing it. With none carried, the job's own
--- option without an item, which its blocker refuses saying what to carry.
function JobOptions.addEach(menu, playerNum, character, feature, label, job, object, items, nameOf)
    if #items == 0 then
        JobOptions.add(menu, playerNum, character, feature, label, job, object)
        return
    end
    local submenu = Needs.addSubMenu(menu, label)
    for _, item in ipairs(items) do
        local name = nameOf and nameOf(item) or item:getDisplayName()
        JobOptions.add(submenu, playerNum, character, feature, name, job, object, item).itemForTexture = item
    end
end

--- The first item of each of `fullTypes` that `character` carries, bags included, in that order;
--- with `keep(fullType)`, of those it accepts only.
function JobOptions.firstOfEach(character, fullTypes, keep)
    local inventory, found = character:getInventory(), {}
    for _, fullType in ipairs(fullTypes) do
        local item = (not keep or keep(fullType)) and inventory:getFirstTypeRecurse(fullType)
        if item then
            table.insert(found, item)
        end
    end
    return found
end

--- Fills the world's right-click menu for the first clicked object `isObject(object)` accepts:
--- `fill(context, playerNum, character, object, worldobjects)`. Nothing for a character in a
--- vehicle; the game's test pass only learns there is something.
function JobOptions.onWorldMenu(isObject, fill)
    Events.OnFillWorldObjectContextMenu.Add(function(playerNum, context, worldobjects, test)
        local character = getSpecificPlayer(playerNum)
        if not character or character:getVehicle() then return end
        local object = Needs.findClicked(worldobjects, isObject)
        if not object then return end
        if test then return ISWorldObjectContextMenu.setTest() end
        fill(context, playerNum, character, object, worldobjects)
    end)
end

--- The function choosing `option` calls, as the menus find vanilla's own options: a get-up option
--- (ISContextMenu.addGetUpOption) selects onGetUpAndThen with the handler as its first parameter.
function JobOptions.handlerOf(option)
    return option.onSelect == ISContextMenu.onGetUpAndThen and option.param1 or option.onSelect
end

return JobOptions
