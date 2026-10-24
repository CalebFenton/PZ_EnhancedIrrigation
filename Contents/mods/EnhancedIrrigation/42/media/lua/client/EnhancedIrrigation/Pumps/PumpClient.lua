-- The client's side of pumps: the system that receives each pump's summary (Pumps.summaryOf reads
-- it), and the hum of each Pump House that runs. A pump holds no container and nothing unsaved, so
-- its copies need nothing set up.

require "EnhancedIrrigation/ClientObjects"
require "EnhancedIrrigation/Pumps/Pumps"
require "EnhancedIrrigation/SquareSounds"

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

-- The running Pump House's loop (Sounds.txt).
PumpClient.RUNNING_SOUND = "EnhancedIrrigationPumpHouseRunning"

--- Whether this client plays the running loop of the Pump House at x, y, z.
PumpClient.isHumming = EnhancedIrrigation.SquareSounds.follow({
    owner = Pumps,
    isOn = function(summary) return summary.running end,
    sound = PumpClient.RUNNING_SOUND,
    looped = true,
})

return PumpClient
