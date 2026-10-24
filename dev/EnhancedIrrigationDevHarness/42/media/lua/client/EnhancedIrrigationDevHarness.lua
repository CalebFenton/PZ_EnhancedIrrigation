-- Development only, not published. dev/run-debug-client.sh loads it with the shared harness mod,
-- which runs the registered modes in the debug scenario and then quits; the script reads the
-- result from console.txt.
require "PZHarness/Runner"
require "EnhancedIrrigation/Debug/EnhancedIrrigationDebugScenario"
local Art = require "EnhancedIrrigationDevArt"
local Promo = require "EnhancedIrrigationDevPromo"

PZHarness.register({
    scenario = "EnhancedIrrigationScenario",
    prefix = "irrigation_",
    modes = {
        -- They wait on the lighting, the zoom and the UI rather than on frame counts, so they draw
        -- uncapped, and they shoot a clear day.
        art = { uncapped = true, clearWeather = true, fastUI = true, run = function(_, done) Art.capture(done) end },
        promo = { uncapped = true, clearWeather = true, fastUI = true, run = Promo.capture },
    },
})
