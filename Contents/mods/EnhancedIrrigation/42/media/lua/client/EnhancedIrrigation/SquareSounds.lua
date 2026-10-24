-- Sounds every client plays for itself at the squares whose summary says so, as vanilla's washer
-- plays its own (ClothingWasherLogic.updateSound): the authority only sends the summary.

require "EnhancedIrrigation/Utilities"

EnhancedIrrigation = EnhancedIrrigation or {}
local SquareSounds = {}
EnhancedIrrigation.SquareSounds = SquareSounds

-- How often, in real milliseconds, this client looks for sounds to start or stop: soon enough that
-- a Pump House's hum follows its switch.
SquareSounds.CHECK_MS = 200

local followers = {}

--- Plays `spec.sound` at the middle of each square where a client record of `spec.owner` (a
--- module with a clientSystem) has a summary for which `spec.isOn(summary)` holds and the square is
--- loaded here, and stops it there once either isn't so. A `looped` sound starts once; any other is
--- played again once it ends. Returns isPlaying(x, y, z), whether this client plays it at x, y, z.
function SquareSounds.follow(spec)
    -- By square key: { emitter, id }.
    local playing = {}
    table.insert(followers, { spec = spec, playing = playing })
    return function(x, y, z)
        local sound = playing[EnhancedIrrigation.squareKey(x, y, z)]
        return sound ~= nil and sound.emitter:isPlaying(sound.id)
    end
end

local function start(spec, x, y, z)
    -- A free emitter goes back to the pool once its sound ends, so each sound takes one.
    local emitter = getWorld():getFreeEmitter(x + 0.5, y + 0.5, z)
    if spec.looped then
        return { emitter = emitter, id = emitter:playSoundLoopedImpl(spec.sound) }
    end
    return { emitter = emitter, id = emitter:playSound(spec.sound) }
end

local function update(follower)
    local spec, playing = follower.spec, follower.playing
    local system = spec.owner.clientSystem
    local wanted = {}
    for i = 1, system and system:getLuaObjectCount() or 0 do
        local record = system:getLuaObjectByIndex(i)
        local summary = record.summary
        if summary and spec.isOn(summary) and getCell():getGridSquare(record.x, record.y, record.z) then
            local key = EnhancedIrrigation.squareKey(record.x, record.y, record.z)
            wanted[key] = true
            local sound = playing[key]
            if not sound or not (spec.looped or sound.emitter:isPlaying(sound.id)) then
                playing[key] = start(spec, record.x, record.y, record.z)
            end
        end
    end
    for key, sound in pairs(playing) do
        if not wanted[key] then
            sound.emitter:stopSound(sound.id)
            playing[key] = nil
        end
    end
end

local checkedMs = 0
Events.OnTick.Add(function()
    local now = getTimestampMs()
    if now - checkedMs >= SquareSounds.CHECK_MS then
        checkedMs = now
        for _, follower in ipairs(followers) do
            update(follower)
        end
    end
end)

return SquareSounds
