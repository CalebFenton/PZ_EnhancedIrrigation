-- Development only, not published. The test library's settings, which the client and the
-- server both read (dev/harness/docs/adopting.md).

require "PZHarness/Fixtures"

PZHarness.registerTests({
    hour = 10,
    -- The perks the mod reads, for the plant info's soil line and the recipes' skills: each test
    -- gets their levels back.
    perks = { Perks.Farming, Perks.Woodwork, Perks.MetalWelding },
    sandbox = "EnhancedIrrigation",
    recipePrefix = "EnhancedIrrigation_",
})
