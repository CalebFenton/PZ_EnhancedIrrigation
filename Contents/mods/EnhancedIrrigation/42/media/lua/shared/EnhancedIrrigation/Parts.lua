-- The ceiling of a part's condition, the most a repair brings it back to: lower on a home-made part,
-- which falls short of a bought one, and lowered by each mend, as vanilla's repairs fall short. An
-- item carries its ceiling in its modData, and a record that holds the part keeps it.

require "EnhancedIrrigation/Utilities"

EnhancedIrrigation = EnhancedIrrigation or {}
local Parts = {}
EnhancedIrrigation.Parts = Parts

-- A part's condition new, its ceiling while it carries no lower one; and the item modData key of a
-- lower ceiling.
local CONDITION = 100
Parts.CEILING_KEY = "EnhancedIrrigation_ceiling"

function Parts.ceilingOf(item)
    return item:getModData()[Parts.CEILING_KEY] or CONDITION
end

--- Gives `item` the ceiling `ceiling`, which travels with it.
function Parts.setCeiling(item, ceiling)
    item:getModData()[Parts.CEILING_KEY] = ceiling < CONDITION and ceiling or nil
end

--- For a craft recipe's OnCreate: makes the item `craftRecipeData` created at `ceiling`, its
--- condition and its ceiling both.
function Parts.made(craftRecipeData, ceiling)
    local item = craftRecipeData:getFirstCreatedItem()
    Parts.setCeiling(item, ceiling)
    item:setCondition(ceiling)
    item:syncItemFields()
end

--- What a mend that costs `loss` of the ceiling `ceiling` restores a part to, and leaves its ceiling
--- at.
function Parts.restores(ceiling, loss)
    return ceiling - loss
end

--- Why a mend costing `loss` is refused for a part at `condition` of `ceiling`: `wornKey` when it
--- would restore nothing, `soundKey` when the part already stands at what it would restore; else
--- nil.
function Parts.mendRefusal(condition, ceiling, loss, wornKey, soundKey)
    local restores = Parts.restores(ceiling, loss)
    if restores <= 0 then
        return wornKey
    end
    return condition >= restores and soundKey or nil
end

return Parts
