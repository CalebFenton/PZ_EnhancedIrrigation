-- EnhancedIrrigation is the mod's one global table; its other globals are names the game looks up
-- itself. Every file that adds to the table creates it first if no file has yet, so files may load
-- in any order.

EnhancedIrrigation = EnhancedIrrigation or {}

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

--- The world's clock in game hours, which every elapsed time in the mod is measured on, so a pass
--- comes out the same at any game speed or tick rate.
function EnhancedIrrigation.now()
    return getGameTime():getWorldAgeHours()
end

-- A pass longer than this (a save loaded after the clock jumped) counts as this long
-- (Clock.hoursSince). Line records run while unloaded, so it is long enough for drying and frost to
-- catch up; tanks settle sooner.
EnhancedIrrigation.LONGEST_PASS = 24 * 7

--- The refusals every job module gives (Jobs.define): `unknown`, of a job no row has or a `with`
--- no menu offers, which only a client that made one up asks for; `short`, while a need is unmet.
EnhancedIrrigation.JOB_REFUSALS = {
    unknown = "Tooltip_EnhancedIrrigation_UnknownJob",
    short = "Tooltip_EnhancedIrrigation_Short",
}

--- The name of `isoObject`'s entity script ("RainCollectorRound"), or nil for a plain object.
function EnhancedIrrigation.entityName(isoObject)
    local script = isoObject and isoObject.getEntityScript and isoObject:getEntityScript()
    return script and script:getName() or nil
end

--- The row of `byEntity` (a table by entity script name) for `isoObject`'s entity, or nil.
function EnhancedIrrigation.entitySpec(isoObject, byEntity)
    local name = EnhancedIrrigation.entityName(isoObject)
    return name and byEntity[name] or nil
end

return EnhancedIrrigation
