-- The client's side of pumps: the system that receives each pump's summary, and the hum of each
-- Pump House that runs. A pump holds no container and nothing unsaved, so its copies need nothing
-- set up.

local ClientObjects = require "cf_commonlib/ClientObjects"
require "EnhancedIrrigation/Sprites"
require "EnhancedIrrigation/Pumps/Pumps"
require "EnhancedIrrigation/SquareSounds"

local Pumps = EnhancedIrrigation.Pumps

local PumpClient = {}
EnhancedIrrigation.PumpClient = PumpClient

local function nothingToAdopt() end

ClientObjects.define({
    prefix = "EnhancedIrrigation_",
    name = "Pump",
    owner = Pumps,
    isObject = Pumps.isPump,
    sprites = Pumps.SPRITES,
    adoptCopy = nothingToAdopt,
    adoptContainer = nothingToAdopt,
    loadPriority = EnhancedIrrigation.Sprites.LOAD_PRIORITY,
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
