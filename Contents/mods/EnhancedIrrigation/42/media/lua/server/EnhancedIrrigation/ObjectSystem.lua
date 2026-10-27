-- The record class every feature's records derive from, on cf_commonlib's ObjectSystem. Each
-- feature's system is cf_commonlib's ObjectSystem.define of its declared owner.

if isClient() then return end

local LibObjectSystem = require "cf_commonlib/ObjectSystem"
require "EnhancedIrrigation/Utilities"

EnhancedIrrigation = EnhancedIrrigation or {}
local ObjectSystem = {}
EnhancedIrrigation.ObjectSystem = ObjectSystem

--- The base of the mod's records (cf_commonlib's ObjectSystem.Object). Its class name stays the
--- mod's own, as saves keep it.
local Object = LibObjectSystem.Object:derive(EnhancedIrrigation.CLASS_PREFIX .. "Object")
ObjectSystem.Object = Object

--- The record's row of its owner's ENTITIES, by the entity name it keeps in `unit`, so it knows
--- its numbers unloaded too; nil for a record of no entity.
function Object:spec()
    return self.unit and self.luaSystem.owner.ENTITIES[self.unit]
end

return ObjectSystem
