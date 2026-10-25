-- The client's side of garden lines: the system that receives each tile's summary, and the water
-- running at each tap whose valve runs it. A line tile is a plain object with nothing unsaved and
-- no container, so the copies need no setting up.

local ClientObjects = require "cf_commonlib/ClientObjects"
require "EnhancedIrrigation/Sprites"
require "EnhancedIrrigation/Lines/Lines"
require "EnhancedIrrigation/Lines/Taps"
require "EnhancedIrrigation/SquareSounds"

local Lines = EnhancedIrrigation.Lines

local LineClient = {}
EnhancedIrrigation.LineClient = LineClient

local function nothingToAdopt() end

ClientObjects.define({
    prefix = "EnhancedIrrigation_",
    name = "Line",
    owner = Lines,
    isObject = Lines.isLine,
    sprites = EnhancedIrrigation.Sprites.pipeNames(),
    adoptCopy = nothingToAdopt,
    adoptContainer = nothingToAdopt,
    loadPriority = EnhancedIrrigation.Sprites.LOAD_PRIORITY,
})

--- Whether this client plays the running water of the valve on the tap at x, y, z.
LineClient.isRunningWater = EnhancedIrrigation.SquareSounds.follow({
    owner = Lines,
    isOn = function(summary) return summary.valveOpen end,
    sound = EnhancedIrrigation.Taps.SOUND,
})

return LineClient
