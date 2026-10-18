-- What a job takes of the character, written once as data (a materials list) and read two ways:
-- as needs, which the menu shows and the refusal checks (EnhancedIrrigation.firstUnmet), and, on
-- the authority, as what the job uses up. Reading both from one list keeps them from disagreeing.
--
-- A material is one of:
--   { tool = "TAG", item = fullType }         a working tool with an ItemTag, `item` naming it in
--                                             the tooltip
--   { tags = { "TAG", ... }, uses = n,        n uses of drainables with any of the ItemTags, as a
--     labelKey = key }                        joint takes glue or tape; `labelKey` names them
--   { item = fullType, need = n }             items of a type, taken; `keep` needs it but takes
--                                             nothing
--   { recipe = name }                         a craftRecipe the character knows

require "EnhancedIrrigation/Utilities"

EnhancedIrrigation = EnhancedIrrigation or {}
local Materials = {}
EnhancedIrrigation.Materials = Materials

-- The drainables with any of `tags` the character carries, unbroken and not used up, fullest first.
local function drainablesTagged(character, tags)
    local list, seen = {}, {}
    local inventory = character:getInventory()
    for _, tag in ipairs(tags) do
        local items = inventory:getAllTagRecurse(ItemTag[tag], ArrayList.new())
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            if not seen[item] and instanceof(item, "DrainableComboItem") and item:getCurrentUses() > 0
                    and not item:isBroken() then
                seen[item] = true
                table.insert(list, item)
            end
        end
    end
    table.sort(list, function(a, b) return a:getCurrentUses() > b:getCurrentUses() end)
    return list
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
    elseif material.tool then
        return EnhancedIrrigation.hasWorkingTool(character, ItemTag[material.tool]) and 1 or 0
    elseif material.tags then
        local uses = 0
        for _, item in ipairs(drainablesTagged(character, material.tags)) do
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
        local need = { have = haveOf(character, material), need = material.uses or material.need or 1 }
        if material.recipe then
            need.recipe = getScriptManager():getCraftRecipe(material.recipe)
        elseif material.tool then
            need.tool, need.item = material.tool, material.item
        elseif material.tags then
            -- A key, not the text: the server reads needs too and has no IG_UI translations.
            need.labelKey = material.labelKey
        else
            need.item = material.item
        end
        table.insert(needs, need)
    end
    return needs
end

--- The lowest condition of the items `list` would take of `character`, or nil when it takes none:
--- what laid pipe keeps, so taking it out gives it back as worn as it went in.
function Materials.lowestCondition(character, list)
    local inventory, lowest = character:getInventory(), nil
    for _, material in ipairs(list) do
        if takes(material) then
            local items = itemsTaken(inventory, material)
            for i = 0, items:size() - 1 do
                local condition = items:get(i):getCondition()
                lowest = lowest and math.min(lowest, condition) or condition
            end
        end
    end
    return lowest
end

local function useTagged(character, tags, count)
    local left = count
    for _, item in ipairs(drainablesTagged(character, tags)) do
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
        if material.tags then
            useTagged(character, material.tags, material.uses)
        elseif takes(material) then
            local items = itemsTaken(inventory, material)
            for i = 0, items:size() - 1 do
                EnhancedIrrigation.takeItem(character, items:get(i))
            end
        end
    end
end

return Materials
