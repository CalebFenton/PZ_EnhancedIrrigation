-- The client's side of pumps: the system that receives each pump's summary (Pumps.summaryOf reads
-- it), and the hum of each Pump House that runs, which every client plays for itself from the
-- summary, as vanilla's washer plays its own (ClothingWasherLogic.updateSound). A pump holds no
-- container and nothing unsaved, so its copies need nothing set up.

require "EnhancedIrrigation/ClientObjects"
require "EnhancedIrrigation/Pumps/Pumps"

local Pumps = EnhancedIrrigation.Pumps

local PumpClient = {}
EnhancedIrrigation.PumpClient = PumpClient

local function nothingToAdopt() end

EnhancedIrrigation.ClientObjects.define({
    name = "Pump",
    owner = Pumps,
    isObject = Pumps.isPump,
    sprites = Pumps.SPRITES,
    adoptCopy = nothingToAdopt,
    adoptContainer = nothingToAdopt,
})

-- The running Pump House's loop (Sounds.txt), and how often, in real milliseconds, this client
-- looks for houses that started or stopped, or whose square loaded or went.
PumpClient.RUNNING_SOUND = "EnhancedIrrigationPumpHouseRunning"
PumpClient.CHECK_MS = 200

-- The loops playing, by square key: { emitter, id }.
local playing = {}

--- Whether this client plays the running loop of the Pump House at x, y, z.
function PumpClient.isHumming(x, y, z)
    local loop = playing[EnhancedIrrigation.squareKey(x, y, z)]
    return loop ~= nil and loop.emitter:isPlaying(loop.id)
end

-- Starts the loop of each Pump House whose summary says it runs and whose square is loaded here,
-- and stops every other.
local function updateLoops()
    local system = Pumps.clientSystem
    local wanted = {}
    for i = 1, system and system:getLuaObjectCount() or 0 do
        local record = system:getLuaObjectByIndex(i)
        local summary = record.summary
        if summary and summary.running and getCell():getGridSquare(record.x, record.y, record.z) then
            local key = EnhancedIrrigation.squareKey(record.x, record.y, record.z)
            wanted[key] = true
            if not playing[key] then
                local emitter = getWorld():getFreeEmitter(record.x + 0.5, record.y + 0.5, record.z)
                playing[key] = { emitter = emitter, id = emitter:playSoundLoopedImpl(PumpClient.RUNNING_SOUND) }
            end
        end
    end
    for key, loop in pairs(playing) do
        if not wanted[key] then
            loop.emitter:stopSound(loop.id)
            playing[key] = nil
        end
    end
end

local checkedMs = 0
Events.OnTick.Add(function()
    local now = getTimestampMs()
    if now - checkedMs >= PumpClient.CHECK_MS then
        checkedMs = now
        updateLoops()
    end
end)

return PumpClient
