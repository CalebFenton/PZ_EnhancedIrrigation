-- EnhancedIrrigation is the mod's one global table; its other globals are names the game looks up
-- itself. Every file that adds to the table creates it first if no file has yet, so files may load
-- in any order.

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

--- Whether the chunk of the square x, y, z is loaded on this side. Above the ground a loaded chunk
--- has squares only where something stands and around it (IsoChunk.loadInWorldStreamerThread), so
--- a missing square there says nothing of whether it is loaded.
function EnhancedIrrigation.chunkLoaded(x, y, z)
    return getCell():getChunkForGridSquare(x, y, z) ~= nil
end

--- Whether the chunks of the square x, y, z and the eight around it are loaded (chunkLoaded).
function EnhancedIrrigation.loadedAround(x, y, z)
    for dx = -1, 1 do
        for dy = -1, 1 do
            if not EnhancedIrrigation.chunkLoaded(x + dx, y + dy, z) then
                return false
            end
        end
    end
    return true
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
-- run while unloaded, so it is long enough for drying and frost to catch up; tanks settle sooner.
EnhancedIrrigation.LONGEST_PASS = 24 * 7

--- The game hours since `holder.lastHour`, at most LONGEST_PASS, and none the first time; stamps
--- `holder.lastHour` with now, so the next pass counts from here.
function EnhancedIrrigation.hoursSince(holder)
    local now = EnhancedIrrigation.now()
    local hours = math.min(EnhancedIrrigation.LONGEST_PASS, now - (holder.lastHour or now))
    holder.lastHour = now
    return hours
end

--- Whether `object` is still in the world, rather than a copy left behind by a removal or a
--- chunk reload.
function EnhancedIrrigation.onSquare(object)
    return object ~= nil and object:getObjectIndex() ~= -1
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

return EnhancedIrrigation
