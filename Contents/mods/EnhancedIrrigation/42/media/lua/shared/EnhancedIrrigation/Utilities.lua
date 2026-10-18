-- Helpers that several of the mod's modules share.
--
-- EnhancedIrrigation is the mod's one global table. The other globals are the ones the game looks
-- up by name: the timed action classes (EnhancedIrrigation*Action) and the recipes' OnAddToMenu
-- hook (EnhancedIrrigation_NeverInMenu, Recipes.lua). Every file that adds to the table creates it
-- first if no file has yet, so files may load in any order.

EnhancedIrrigation = EnhancedIrrigation or {}

--- The first object on `square` for which `matches(object)` is true, or nil. Takes a nil square.
function EnhancedIrrigation.findObjectOn(square, matches)
    local objects = square and square:getObjects()
    for i = 0, (objects and objects:size() or 0) - 1 do
        local object = objects:get(i)
        if matches(object) then
            return object
        end
    end
    return nil
end

--- Takes `item` from `character`: out of their hands and out of the container that holds it, and
--- tells the clients. Authority only.
function EnhancedIrrigation.takeItem(character, item)
    character:removeFromHands(item)
    local container = item:getContainer()
    if container then
        container:Remove(item)
        sendRemoveItemFromContainer(container, item)
    end
end

--- Gives `character` `count` (default 1) of `itemOrType`, an item or a full type, dropping on
--- their square what doesn't fit (Actions.addOrDropItem, which also syncs). Authority only.
function EnhancedIrrigation.giveItems(character, itemOrType, count)
    for _ = 1, count or 1 do
        local item = type(itemOrType) == "string" and instanceItem(itemOrType) or itemOrType
        Actions.addOrDropItem(character, item)
    end
end

function EnhancedIrrigation.notBroken(item)
    return not item:isBroken()
end

--- Whether `character` carries a working tool with `tag` (an ItemTag value), bags included.
function EnhancedIrrigation.hasWorkingTool(character, tag)
    return character:getInventory():containsTagEvalRecurse(tag, EnhancedIrrigation.notBroken)
end

function EnhancedIrrigation.round(value, places)
    local scale = 10 ^ (places or 0)
    return math.floor(value * scale + 0.5) / scale
end

--- The key of the square x, y, z in a table, and how a job's `with` names a square: a string, which
--- a multiplayer action's arguments can carry.
function EnhancedIrrigation.squareKey(x, y, z)
    return x .. "," .. y .. "," .. z
end

--- The square { x, y, z } of `isoObject`.
function EnhancedIrrigation.squareOf(isoObject)
    return { x = isoObject:getX(), y = isoObject:getY(), z = isoObject:getZ() }
end

function EnhancedIrrigation.sameSquare(p, q)
    return p.x == q.x and p.y == q.y and p.z == q.z
end

--- Whether two values are the same, tables by what they hold, at any depth. Summaries compare
--- so, to send only what changed.
function EnhancedIrrigation.sameValue(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then
        return a == b
    end
    for key, value in pairs(a) do
        if not EnhancedIrrigation.sameValue(value, b[key]) then
            return false
        end
    end
    for key in pairs(b) do
        if a[key] == nil then
            return false
        end
    end
    return true
end

--- The world's clock in game hours, which every elapsed time in the mod is measured on, so a pass
--- comes out the same at any game speed or tick rate.
function EnhancedIrrigation.now()
    return getGameTime():getWorldAgeHours()
end

-- A pass longer than this (a save loaded after the clock jumped) counts as this long. Line records
-- run while unloaded, so a week away is a week of drying and frost; tanks settle long before.
EnhancedIrrigation.LONGEST_PASS = 24 * 7

--- The game hours since `holder.lastHour`, at most LONGEST_PASS, and none the first time; stamps
--- `holder.lastHour` with now, so the next pass counts from here.
function EnhancedIrrigation.catchUp(holder)
    local now = EnhancedIrrigation.now()
    local hours = math.min(EnhancedIrrigation.LONGEST_PASS, now - (holder.lastHour or now))
    holder.lastHour = now
    return hours
end

--- An action advances by GameTime.getMultiplier() each tick (BaseAction.update), and in the same
--- tick the clock advances getMultiplier() / (2 * minutesPerDay) in-game minutes (GameTime.update),
--- so one in-game minute is 2 * minutesPerDay units at any frame rate or game speed.
function EnhancedIrrigation.unitsPerMinute()
    return 2 * getGameTime():getMinutesPerDay()
end

--- Whether `object` is still in the world, rather than a copy left behind by a removal or a
--- chunk reload.
function EnhancedIrrigation.onSquare(object)
    return object ~= nil and object:getObjectIndex() ~= -1
end

--- Whether `character` stands within `reach` squares on each axis of the middle of `target`'s
--- square, on its level: where the menu walked them for a job there (luautils.walkAdj), with room
--- for drift and a client's lag. The authority checks it before doing a job.
function EnhancedIrrigation.withinReach(character, target, reach)
    local square = target:getSquare()
    return square ~= nil and math.abs(character:getX() - (square:getX() + 0.5)) <= reach
        and math.abs(character:getY() - (square:getY() + 0.5)) <= reach
        and math.abs(character:getZ() - square:getZ()) < 1
end

--- Shows `wanted` (a list of sprite names, in drawing order) as the overlays of the kind
--- `isKind(name)` tells on `isoObject`, and sends the tile on when that changes it. Authority only.
function EnhancedIrrigation.showOverlays(isoObject, isKind, wanted)
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

--- Shows `wanted` (a sprite name, or nil for none) as the one overlay of the kind `isKind(name)`
--- tells on `isoObject`, as showOverlays does.
function EnhancedIrrigation.showOverlay(isoObject, isKind, wanted)
    EnhancedIrrigation.showOverlays(isoObject, isKind, wanted and { wanted } or {})
end

--- Shows `isoObject` as the tile `spriteName` and sends the change on, if it isn't already.
--- Authority only.
function EnhancedIrrigation.showSprite(isoObject, spriteName)
    local sprite = isoObject:getSprite()
    if sprite and sprite:getName() == spriteName then return end
    -- The tile's own sprite, with its properties; setSprite(name) would make a bare texture.
    isoObject:setSprite(getSprite(spriteName))
    isoObject:transmitUpdatedSpriteToClients()
end

--- The game entity script whose SpriteConfig names the tile `spriteName`, or nil: what an object
--- on that tile is, found as vanilla's MORainCollectorBarrel finds it.
function EnhancedIrrigation.tileEntity(spriteName)
    local info = SpriteConfigManager.getObjectInfoFromSprite(spriteName)
    return info and info:getScript():getParent()
end

--- The name of `isoObject`'s entity script ("RainCollectorRound"), or nil for a plain object.
function EnhancedIrrigation.entityName(isoObject)
    local script = isoObject and isoObject.getEntityScript and isoObject:getEntityScript()
    return script and script:getName() or nil
end

-- A job's needs are a list of what it takes of the character, each { have, need } with what it
-- names: `labelKey` (an IG_UI key) for drainable uses, `tool` (an ItemTag field) and `item` for a
-- tool, `item` (a full type) for an item counted by type, `recipe` for a recipe to know (have 1
-- when known). The same list refuses the job and tells the menu what it lacks, so the two can't
-- disagree (EnhancedIrrigation.Materials).

--- The first of `needs` the character is short of, or nil when they have them all.
function EnhancedIrrigation.firstUnmet(needs)
    for _, need in ipairs(needs) do
        if need.have < need.need then
            return need
        end
    end
    return nil
end

--- Why a job is refused: its `blocker` (a Tooltip key) if any, else Short while any of `needs` is
--- unmet, else nil.
function EnhancedIrrigation.refusal(blocker, needs)
    if blocker then
        return blocker
    end
    return EnhancedIrrigation.firstUnmet(needs) and "Tooltip_EnhancedIrrigation_Short" or nil
end

return EnhancedIrrigation
