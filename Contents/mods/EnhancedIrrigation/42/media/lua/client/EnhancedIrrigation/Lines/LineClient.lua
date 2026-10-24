-- The client's side of garden lines: the system that receives each tile's summary
-- (EnhancedIrrigation.Lines.stateAt reads it), and the water running at each tap whose valve runs
-- it, which every client plays for itself from the summary, as it plays a Pump House's hum
-- (PumpClient.lua). A line tile is a plain object with nothing unsaved and no container, so the
-- copies need no setting up.

require "EnhancedIrrigation/ClientObjects"
require "EnhancedIrrigation/Sprites"
require "EnhancedIrrigation/Lines"

local Lines = EnhancedIrrigation.Lines

local LineClient = {}
EnhancedIrrigation.LineClient = LineClient

local function nothingToAdopt() end

EnhancedIrrigation.ClientObjects.define({
    name = "Line",
    owner = Lines,
    isObject = Lines.isLine,
    sprites = EnhancedIrrigation.Sprites.pipeNames(),
    adoptCopy = nothingToAdopt,
    adoptContainer = nothingToAdopt,
})

-- The sound of water running from a tap: the one a held tap plays (EnhancedIrrigationWaterAction),
-- a long clip played again while the valve stays open; and how often, in real milliseconds, this
-- client looks for valves that opened or shut, or whose square loaded or went.
LineClient.VALVE_SOUND = "WaterCrops"
LineClient.CHECK_MS = 500

-- The sounds playing, by square key: { emitter, id }.
local playing = {}

--- Whether this client plays the running water of the valve on the tap at x, y, z.
function LineClient.isRunningWater(x, y, z)
    local sound = playing[EnhancedIrrigation.squareKey(x, y, z)]
    return sound ~= nil and sound.emitter:isPlaying(sound.id)
end

-- Plays the water of each tap whose summary says its valve runs it and whose square is loaded here,
-- again once the clip ends, and stops every other.
local function updateSounds()
    local system = Lines.clientSystem
    local wanted = {}
    for i = 1, system and system:getLuaObjectCount() or 0 do
        local record = system:getLuaObjectByIndex(i)
        local summary = record.summary
        if summary and summary.valveOpen and getCell():getGridSquare(record.x, record.y, record.z) then
            local key = EnhancedIrrigation.squareKey(record.x, record.y, record.z)
            wanted[key] = true
            local sound = playing[key]
            if not (sound and sound.emitter:isPlaying(sound.id)) then
                -- A free emitter goes back to the pool once its sound ends, so each clip takes one.
                local emitter = getWorld():getFreeEmitter(record.x + 0.5, record.y + 0.5, record.z)
                playing[key] = { emitter = emitter, id = emitter:playSound(LineClient.VALVE_SOUND) }
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
    if now - checkedMs >= LineClient.CHECK_MS then
        checkedMs = now
        updateSounds()
    end
end)

return LineClient
