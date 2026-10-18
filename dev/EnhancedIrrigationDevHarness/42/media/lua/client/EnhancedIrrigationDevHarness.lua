-- Development only, not published; dev/run-debug-client.sh loads it with the shared harness mod
-- (dev/harness), which runs the modes it registers here in the Enhanced Irrigation debug scenario
-- and then quits the game. With --test it runs every irrigation_* test; with --art,
-- EnhancedIrrigationDevArt stages the tiles and saves screenshots of them, then prints
-- "EIArt DONE". The script reads the result from console.txt.
require "PZHarness/Runner"
require "EnhancedIrrigation/Debug/EnhancedIrrigationDebugScenario"
local Art = require "EnhancedIrrigationDevArt"

PZHarness.register({
    scenario = "EnhancedIrrigationScenario",
    prefix = "irrigation_",
    modes = {
        -- It waits on the lighting, the zoom and the UI rather than on frame counts, so it draws
        -- uncapped, and it shoots a clear day.
        art = { uncapped = true, clearWeather = true, fastUI = true, run = function(_, done) Art.capture(done) end },
    },
})
