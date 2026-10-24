-- The client's side of pumps: the system that receives each pump's summary (Pumps.summaryOf reads
-- it). A pump holds no container and nothing unsaved, so its copies need nothing set up.

require "EnhancedIrrigation/ClientObjects"
require "EnhancedIrrigation/Pumps"

local Pumps = EnhancedIrrigation.Pumps

local function nothingToAdopt() end

EnhancedIrrigation.ClientObjects.define({
    name = "Pump",
    owner = Pumps,
    isObject = Pumps.isPump,
    sprites = Pumps.SPRITES,
    adoptCopy = nothingToAdopt,
    adoptContainer = nothingToAdopt,
})
