-- Listed in the SCENARIOS panel on the main menu when the game runs with -debug
-- (DebugScenarios.lua). Starts a zombie-free world in Muldraugh, among houses, since fixtures and
-- vanilla plumbing work only in a room.
debugScenarios = debugScenarios or {}

debugScenarios.EnhancedIrrigationScenario = {
    name = "Enhanced Irrigation",
    startLoc = { x = 10835, y = 10144, z = 0 }, -- DebugScenarios requires a start location
    onStart = function()
        getGameTime():setTimeOfDay(10)
    end,
}
