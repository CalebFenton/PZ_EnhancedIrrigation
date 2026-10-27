-- The client's side of treatment units: the system that receives each unit's summary. A unit's
-- basin is a FluidContainer the engine syncs itself, with nothing unsaved to set up on the copies.

local ClientObjects = require "cf_commonlib/ClientObjects"
require "EnhancedIrrigation/Sprites"
require "EnhancedIrrigation/Treatment/Treatment"

local Treatment = EnhancedIrrigation.Treatment

ClientObjects.define(Treatment)
