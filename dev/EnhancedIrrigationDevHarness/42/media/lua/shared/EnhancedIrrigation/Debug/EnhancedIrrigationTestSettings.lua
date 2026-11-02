-- Development only, not published. The test library's settings, which the client and the
-- server both read (dev/harness/docs/adopting.md). Shared Lua loads before the mod's server Lua,
-- so the hooks look those modules up when they run.

require "PZHarness/Fixtures"
local Chance = require "cf_commonlib/Chance"

PZHarness.registerTests({
    hour = 10,
    -- Farming, which the plant info's soil line reads, and every skill the mod's recipes and
    -- builds require, so a test that changes one leaves the next its starting level.
    perks = { Perks.Farming, Perks.Woodwork, Perks.MetalWelding, Perks.Masonry, Perks.Pottery,
        Perks.Electricity },
    sandbox = "EnhancedIrrigation",
    recipePrefix = "EnhancedIrrigation_",
    remove = function(object)
        if isClient() then
            return false
        end
        -- A link the test made would outlive the thing at its end.
        local Server = require "EnhancedIrrigation/Debug/EnhancedIrrigationTestServer"
        if Server.isPlaced(object) then
            Server.unlinkAt(object:getX(), object:getY(), object:getZ())
        end
        -- With its record, and its neighbours reshaped.
        local EI = EnhancedIrrigation
        if EI.Lines.isLine(object) then
            EI.LineSystem.remove(object)
            return true
        end
        return false
    end,
    chance = function() return Chance end,
    records = {
        line = { owner = function() return EnhancedIrrigation.Lines end },
        pump = { owner = function() return EnhancedIrrigation.Pumps end },
        treatment = { owner = function() return EnhancedIrrigation.Treatment end },
    },
    jobAction = function() return EnhancedIrrigationAction end,
})
