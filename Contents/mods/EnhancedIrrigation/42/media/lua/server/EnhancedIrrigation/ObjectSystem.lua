-- The authority's side of the features kept in a Global Object System: a system per feature that
-- saves each object's record with the world and sends every client its summary, and a base for the
-- records. Each side reads them through the accessors of GlobalObjects.addAccessors.

if isClient() then return end

require "Map/SGlobalObjectSystem"
require "Map/SGlobalObject"
require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Sprites"
require "EnhancedIrrigation/Jobs"

EnhancedIrrigation = EnhancedIrrigation or {}
local ObjectSystem = {}
EnhancedIrrigation.ObjectSystem = ObjectSystem

local Sprites = EnhancedIrrigation.Sprites

-- Records ------------------------------------------------------------------------------------------

--- The base of a feature's records. A record is its global object's table, so the fields its
--- class's SAVED_FIELDS names are saved with the world. A class defines advance(hours), what the
--- time does to it; afterChange(), which shows and tells what changed; and buildSummary(), what
--- every client keeps of it. A class whose time can't be told while parts of it are unloaded
--- overrides catchUp() to wait for them.
local Object = SGlobalObject:derive("EnhancedIrrigation_Object")
ObjectSystem.Object = Object

--- Advances the record by the game hours since it last caught up.
function Object:catchUp()
    self:advance(EnhancedIrrigation.hoursSince(self))
end

function Object:update()
    self:catchUp()
    self:afterChange()
end

--- Whether the record is still its system's: removing its object takes the record away and clears
--- its x, y, z.
function Object:isCurrent()
    return self.x ~= nil and self.luaSystem:getLuaObjectAt(self.x, self.y, self.z) == self
end

--- Sends the clients the summary, if it changed.
function Object:sendSummary()
    local summary = self:buildSummary()
    if not EnhancedIrrigation.sameValue(summary, self.summary) then
        self.summary = summary
        self:updateOnClient()
    end
end

-- Systems -------------------------------------------------------------------------------------------

--- Defines and registers a feature's system. `spec`: name (the class is
--- EnhancedIrrigation_<name>System), sprites (its tiles' names, for the load hook), owner (its
--- shared module: SYSTEM_NAME and the accessors of GlobalObjects.addAccessors), Object (its record
--- class), isObject(isoObject). Returns the class.
function ObjectSystem.define(spec)
    local System = SGlobalObjectSystem:derive("EnhancedIrrigation_" .. spec.name .. "System")

    function System:new()
        return SGlobalObjectSystem.new(self, spec.owner.SYSTEM_NAME)
    end

    function System:initSystem()
        spec.owner.serverSystem = self
        self.system:setObjectModDataKeys(spec.Object.SAVED_FIELDS)
        self.system:setObjectSyncKeys({ "summary" })
    end

    -- The summary isn't saved; each record gets it before any client connects.
    function System:initLuaObjects()
        SGlobalObjectSystem.initLuaObjects(self)
        for i = 1, self:getLuaObjectCount() do
            local record = self:getLuaObjectByIndex(i)
            record.summary = record:buildSummary()
        end
    end

    function System:isValidIsoObject(isoObject)
        return spec.isObject(isoObject)
    end

    function System:newLuaObject(globalObject)
        return spec.Object:new(self, globalObject)
    end

    -- Every record, loaded or not, each ten minutes; a pass removes none.
    local function updateAll()
        local self = System.instance
        for i = 1, self:getLuaObjectCount() do
            self:getLuaObjectByIndex(i):update()
        end
    end

    local function load(isoObject)
        if spec.isObject(isoObject) then
            System.instance:loadIsoObject(isoObject)
        end
    end
    for _, name in ipairs(spec.sprites) do
        MapObjects.OnLoadWithSprite(name, load, Sprites.LOAD_PRIORITY)
    end
    Events.EveryTenMinutes.Add(updateAll)
    SGlobalObjectSystem.RegisterSystemClass(System)
    return System
end

--- Does `job` at `object` with `with` for `character` on the authority (Jobs.perform of `jobs`,
--- run by `DO`), on `record` as time has left it, then shows and tells what changed, unless the
--- job took the record away. `record` is nil for a job that makes one. Returns whether it was done.
function ObjectSystem.perform(jobs, DO, character, job, object, with, record)
    if record then
        record:catchUp()
    end
    local done = EnhancedIrrigation.Jobs.perform(jobs, DO, character, job, object, with)
    if record and record:isCurrent() then
        record:afterChange()
    end
    return done
end

--- The last item the build of `params` (an entity's OnCreate) consumed for which `matches(item)`
--- holds, or nil: the build menu's chosen inputs.
function ObjectSystem.consumedItem(params, matches)
    local found = nil
    local used = params.craftRecipeData and params.craftRecipeData:getAllConsumedItems()
    for i = 0, (used and used:size() or 0) - 1 do
        if matches(used:get(i)) then
            found = used:get(i)
        end
    end
    return found
end

-- Tiles -------------------------------------------------------------------------------------------

--- Shows `wanted` (a list of sprite names, in drawing order) as the overlays of the kind
--- `isKind(name)` tells on `isoObject`, and sends the tile on when that changes it. Authority only.
function ObjectSystem.showOverlays(isoObject, isKind, wanted)
    local attached = isoObject:getAttachedAnimSprite()
    local count = attached and attached:size() or 0
    local shown = {}
    for i = 0, count - 1 do
        local name = attached:get(i):getName()
        if isKind(name) then
            table.insert(shown, name)
        end
    end
    if EnhancedIrrigation.sameValue(shown, wanted) then return end
    for i = count - 1, 0, -1 do
        if isKind(attached:get(i):getName()) then
            isoObject:RemoveAttachedAnim(i)
        end
    end
    for _, name in ipairs(wanted) do
        isoObject:addAttachedAnimSpriteByName(name)
    end
    isoObject:transmitUpdatedSpriteToClients()
end

--- Shows `isoObject` as the tile `spriteName` and sends the change on, if it isn't already.
--- Authority only.
function ObjectSystem.showSprite(isoObject, spriteName)
    local sprite = isoObject:getSprite()
    if sprite and sprite:getName() == spriteName then return end
    -- The tile's own sprite, with its properties; setSprite(name) would make a bare texture.
    isoObject:setSprite(getSprite(spriteName))
    isoObject:transmitUpdatedSpriteToClients()
end

return ObjectSystem
