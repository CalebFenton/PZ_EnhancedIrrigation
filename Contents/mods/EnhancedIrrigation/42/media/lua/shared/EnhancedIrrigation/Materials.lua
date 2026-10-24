-- What a job takes of the character, written once as data (a materials list) and read two ways:
-- as needs, which the menu shows and the refusal checks (EnhancedIrrigation.firstUnmet), and, on
-- the authority, as what the job uses up. Reading both from one list keeps them from disagreeing.
--
-- A material is one of:
--   { tool = "TAG", item = fullType }         a working tool with an ItemTag, `item` naming it in
--                                             the tooltip
--   { tags = { "TAG", ... }, uses = n,        n uses of drainables with any of the ItemTags, or of
--     labelKey = key }                        any of the types `types = { fullType, ... }` names,
--                                             as a joint takes glue or tape; `labelKey` names them
--   { item = fullType, need = n }             items of a type, taken; `keep` needs it but takes
--                                             nothing
--   { recipe = name }                         a craftRecipe the character knows
--   { skill = "Perk", level = n }             the skill (a Perks name) at n or above, as a
--                                             recipe's SkillRequired; takes nothing

require "EnhancedIrrigation/Utilities"

EnhancedIrrigation = EnhancedIrrigation or {}
local Materials = {}
EnhancedIrrigation.Materials = Materials

local function addDrainables(list, seen, items)
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if not seen[item] and instanceof(item, "DrainableComboItem") and item:getCurrentUses() > 0
                and not item:isBroken() then
            seen[item] = true
            table.insert(list, item)
        end
    end
end

-- The drainables `material` names (its `tags` or `types`) the character carries, unbroken and not
-- used up, fullest first.
local function drainablesOf(character, material)
    local list, seen = {}, {}
    local inventory = character:getInventory()
    for _, tag in ipairs(material.tags or {}) do
        addDrainables(list, seen, inventory:getAllTagRecurse(ItemTag[tag], ArrayList.new()))
    end
    for _, fullType in ipairs(material.types or {}) do
        addDrainables(list, seen, inventory:getAllTypeRecurse(fullType))
    end
    table.sort(list, function(a, b) return a:getCurrentUses() > b:getCurrentUses() end)
    return list
end

-- Whether `material` is uses of drainables rather than items or a tool.
local function isDrainable(material)
    return material.tags ~= nil or material.types ~= nil
end

-- Whether the job uses up the items `material` names.
local function takes(material)
    return material.item ~= nil and not material.keep and not material.tool
end

-- The items `material` takes of `inventory`, as Materials.consume takes them.
local function itemsTaken(inventory, material)
    return inventory:getSomeTypeRecurse(material.item, material.need or 1)
end

local function haveOf(character, material)
    if material.recipe then
        return character:isRecipeActuallyKnown(material.recipe) and 1 or 0
    elseif material.skill then
        return character:getPerkLevel(Perks[material.skill])
    elseif material.tool then
        return Materials.workingTool(character, ItemTag[material.tool]) and 1 or 0
    elseif isDrainable(material) then
        local uses = 0
        for _, item in ipairs(drainablesOf(character, material)) do
            uses = uses + item:getCurrentUses()
        end
        return uses
    end
    return character:getInventory():getCountTypeRecurse(material.item)
end

--- What `list` takes of `character`, as needs (EnhancedIrrigation.firstUnmet,
--- EnhancedIrrigation.Needs).
function Materials.needs(character, list)
    local needs = {}
    for _, material in ipairs(list) do
        local need = { have = haveOf(character, material), need = material.uses or material.need or material.level or 1 }
        if material.recipe then
            need.recipe = getScriptManager():getCraftRecipe(material.recipe)
        elseif material.skill then
            need.perk = Perks[material.skill]
        elseif material.tool then
            need.tool, need.item = material.tool, material.item
        elseif isDrainable(material) then
            -- A key, not the text: the server reads needs too and has no IG_UI translations.
            need.labelKey = material.labelKey
        else
            need.item = material.item
        end
        table.insert(needs, need)
    end
    return needs
end

--- The conditions of the items `list` would take of `character`, one each in the order taken:
--- what laid pipe keeps, so taking it out gives each item back as worn as it went in.
function Materials.conditions(character, list)
    local inventory, conditions = character:getInventory(), {}
    for _, material in ipairs(list) do
        if takes(material) then
            local items = itemsTaken(inventory, material)
            for i = 0, items:size() - 1 do
                table.insert(conditions, items:get(i):getCondition())
            end
        end
    end
    return conditions
end

local function useDrainables(character, material, count)
    local left = count
    for _, item in ipairs(drainablesOf(character, material)) do
        while left > 0 and item:getCurrentUses() > 0 do
            item:UseAndSync()
            left = left - 1
        end
        if left <= 0 then
            return
        end
    end
end

--- Takes from `character` what `list` uses up, once its needs were checked. Authority only.
function Materials.consume(character, list)
    local inventory = character:getInventory()
    for _, material in ipairs(list) do
        if isDrainable(material) then
            useDrainables(character, material, material.uses)
        elseif takes(material) then
            local items = itemsTaken(inventory, material)
            for i = 0, items:size() - 1 do
                Materials.takeItem(character, items:get(i))
            end
        end
    end
end

--- Takes `item` from `character`: out of their hands and out of the container that holds it, and
--- tells the clients. Authority only.
function Materials.takeItem(character, item)
    character:removeFromHands(item)
    local container = item:getContainer()
    if container then
        container:Remove(item)
        sendRemoveItemFromContainer(container, item)
    end
end

--- Gives `character` `count` (default 1) of `itemOrType`, an item or a full type, dropping on
--- their square what doesn't fit (Actions.addOrDropItem, which also syncs). Authority only.
function Materials.giveItems(character, itemOrType, count)
    for _ = 1, count or 1 do
        local item = type(itemOrType) == "string" and instanceItem(itemOrType) or itemOrType
        Actions.addOrDropItem(character, item)
    end
end

local function notBroken(item)
    return not item:isBroken()
end

-- The screwdriver the jobs at pumps and appliances take, as Pipes.WRENCH is the plumbing jobs'.
Materials.SCREWDRIVER = { tool = "SCREWDRIVER", item = "Base.Screwdriver" }

--- The first working tool with `tag` (an ItemTag value) `character` carries, bags included, or nil.
function Materials.workingTool(character, tag)
    return character:getInventory():getFirstTagEvalRecurse(tag, notBroken)
end

--- A job row's `equip` (EnhancedIrrigationAction) holding the tool the material `tool` names.
function Materials.holds(tool)
    return function(character)
        return Materials.workingTool(character, ItemTag[tool.tool])
    end
end

-- A job's needs are a list of what it takes of the character, each { have, need } with what it
-- names: `labelKey` (an IG_UI key) for drainable uses, `tool` (an ItemTag field) and `item` for a
-- tool, `item` (a full type) for an item counted by type, `recipe` for a recipe to know (have 1
-- when known). The same list refuses the job and tells the menu what it lacks, so the two can't
-- disagree.

--- The first of `needs` the character is short of, or nil when they have them all.
function EnhancedIrrigation.firstUnmet(needs)
    for _, need in ipairs(needs) do
        if need.have < need.need then
            return need
        end
    end
    return nil
end

return Materials
