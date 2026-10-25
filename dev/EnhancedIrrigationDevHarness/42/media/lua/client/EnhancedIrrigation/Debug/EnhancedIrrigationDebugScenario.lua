require "PZHarness/TestLib"
local QA = require "EnhancedIrrigationDevQA"
local HarnessQA = require "PZHarness/QA"

-- Listed in the SCENARIOS panel on the main menu when the game runs with -debug
-- (DebugScenarios.lua). Starts a zombie-free world in Muldraugh, among houses, since fixtures and
-- vanilla plumbing work only in a room. A work table beside the start, set down before any test
-- so the leak checks take it as the world's, is the surface the table crafts use.
debugScenarios = debugScenarios or {}

debugScenarios.EnhancedIrrigationScenario = {
    name = "Enhanced Irrigation",
    startLoc = { x = 10835, y = 10144, z = 0 }, -- DebugScenarios requires a start location
    onStart = function()
        getGameTime():setTimeOfDay(10)
        PZHarness.Test.placeWorkTable(getPlayer())
    end,
}

-- Listed beside it, to play through the mod by hand: crops, tanks and everything the mod's jobs
-- take laid out on a farm, for a character nothing sees or hurts (EnhancedIrrigationDevQA.lua).
debugScenarios.EnhancedIrrigationQAScenario = HarnessQA.scenario("Enhanced Irrigation QA", QA.START, QA.setup)
