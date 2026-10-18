-- The client's side of garden lines: the system that receives each tile's summary
-- (EnhancedIrrigation.Lines.stateAt reads it). A line tile is a plain object with nothing unsaved
-- and no container, so the copies need no setting up.

require "EnhancedIrrigation/ClientObjects"
require "EnhancedIrrigation/Sprites"
require "EnhancedIrrigation/Lines"

local Lines = EnhancedIrrigation.Lines

local function nothingToAdopt() end

EnhancedIrrigation.ClientObjects.define({
    name = "Line",
    owner = Lines,
    isObject = Lines.isLine,
    sprites = EnhancedIrrigation.Sprites.pipeNames(),
    adoptCopy = nothingToAdopt,
    adoptContainer = nothingToAdopt,
})
