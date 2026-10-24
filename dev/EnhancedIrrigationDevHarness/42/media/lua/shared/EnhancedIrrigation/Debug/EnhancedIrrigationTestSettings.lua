-- Development only, not published. The test library's settings, which the client and the
-- server both read (dev/harness/docs/adopting.md).

require "PZHarness/Fixtures"

PZHarness.registerTests({
    hour = 10,
    -- Farming, which the plant info's soil line reads, and every skill the mod's recipes and
    -- builds require: each test gets their levels back.
    perks = { Perks.Farming, Perks.Woodwork, Perks.MetalWelding, Perks.Masonry, Perks.Pottery,
        Perks.Electricity },
    sandbox = "EnhancedIrrigation",
    recipePrefix = "EnhancedIrrigation_",
    -- The pottery wheel T.placeBench sets down for the crock's tests is one tile of vanilla's
    -- two-tile wheel. The game's safe removal looks for its other tile, finds none and removes
    -- nothing, so it goes by the plain removal.
    remove = function(object)
        local script = object:getEntityScript()
        if not (script and script:getName() == "Pottery_Wheel") then
            return false
        end
        object:getSquare():transmitRemoveItemFromSquare(object, false)
        return true
    end,
})
