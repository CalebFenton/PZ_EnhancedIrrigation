-- The client's side of treatment units: the system that receives each unit's summary
-- (Treatment.summaryOf reads it). A unit's basin is a FluidContainer the engine syncs itself, with
-- nothing unsaved to set up on the copies.

require "EnhancedIrrigation/ClientObjects"
require "EnhancedIrrigation/Treatment"

local Treatment = EnhancedIrrigation.Treatment

local function nothingToAdopt() end

EnhancedIrrigation.ClientObjects.define({
    name = "Treatment",
    owner = Treatment,
    isObject = Treatment.isUnit,
    sprites = Treatment.SPRITES,
    adoptCopy = nothingToAdopt,
    adoptContainer = nothingToAdopt,
})
