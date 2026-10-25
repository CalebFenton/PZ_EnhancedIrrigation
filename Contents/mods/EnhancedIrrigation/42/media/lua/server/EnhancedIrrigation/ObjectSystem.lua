-- The mod's records and systems on cf_commonlib's ObjectSystem: the record class every feature's
-- derives from, and the mod's names, load priority and longest pass for each system.

if isClient() then return end

local LibObjectSystem = require "cf_commonlib/ObjectSystem"
require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Sprites"

EnhancedIrrigation = EnhancedIrrigation or {}
local ObjectSystem = {}
EnhancedIrrigation.ObjectSystem = ObjectSystem

--- The base of the mod's records (cf_commonlib's ObjectSystem.Object). Its class name stays the
--- mod's own, as saves keep it.
local Object = LibObjectSystem.Object:derive("EnhancedIrrigation_Object")
ObjectSystem.Object = Object

--- The record's row of its owner's ENTITIES, by the entity name it keeps in `unit`, so it knows
--- its numbers unloaded too; nil for a record of no entity.
function Object:spec()
    return self.unit and self.luaSystem.owner.ENTITIES[self.unit]
end

--- Defines and registers a feature's system (cf_commonlib's ObjectSystem.define) as
--- EnhancedIrrigation_<spec.name>System. `spec`: name, sprites, owner (its shared module:
--- SYSTEM_NAME, the accessors of GlobalObjects.addAccessors and, for an entity's records,
--- ENTITIES), Object (its record class), isObject(isoObject). Returns the class.
function ObjectSystem.define(spec)
    return LibObjectSystem.define({
        prefix = "EnhancedIrrigation_",
        name = spec.name,
        owner = spec.owner,
        Object = spec.Object,
        isObject = spec.isObject,
        sprites = spec.sprites,
        loadPriority = EnhancedIrrigation.Sprites.LOAD_PRIORITY,
        longestPass = EnhancedIrrigation.LONGEST_PASS,
    })
end

return ObjectSystem
