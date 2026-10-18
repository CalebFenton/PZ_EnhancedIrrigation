-- Development only, not published. The test library's settings, which the client and the
-- server both read (dev/harness/docs/adopting.md).

require "PZHarness/Fixtures"

PZHarness.registerTests({
    hour = 10,
    -- The perks the mod's jobs read: each test gets their levels back. Farming gates the plant
    -- info's soil line; Woodwork builds the Tank Stand and teaches both recipes; MetalWelding
    -- teaches Plumb to Tank.
    perks = { Perks.Farming, Perks.Woodwork, Perks.MetalWelding },
    sandbox = "EnhancedIrrigation",
    recipePrefix = "EnhancedIrrigation_",
})
