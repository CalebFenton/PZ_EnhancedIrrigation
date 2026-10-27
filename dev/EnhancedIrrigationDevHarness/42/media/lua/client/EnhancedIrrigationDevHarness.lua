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
        -- They wait on the lighting, the zoom and the UI rather than on frame counts, and they
        -- shoot a clear day.
        art = { capture = true, run = Art.capture },
        promo = { capture = true, run = Promo.capture },
    },
})
