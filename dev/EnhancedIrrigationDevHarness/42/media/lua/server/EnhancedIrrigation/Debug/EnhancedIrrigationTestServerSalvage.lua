require "PZHarness/ServerHandlers"
require "PZHarness/Fixtures"
local Server = require "EnhancedIrrigation/Debug/EnhancedIrrigationTestServer"

-- Development only, not published. Only registers handlers, so a --stay rerun loads it again.

local handler = PZHarness.serverHandler

local EI = EnhancedIrrigation

-- The appliance drawn as `args.sprite` at x, y, z: whether it runs and whether its pump is gone;
-- nothing without one.
handler("appliances.state", function(_, args)
    local square = Server.squareAt(args)
    local appliance = square and PZHarness.Fixtures.objectWithSprite(square, args.sprite)
    if not appliance then
        return {}
    end
    local switched = instanceof(appliance, "IsoCombinationWasherDryer") or instanceof(appliance, "IsoClothingWasher")
    return { activated = switched and appliance:isActivated() or false, stripped = EI.Appliances.isStripped(appliance) }
end)

-- Runs vanilla's switch of the washer or washer-dryer drawn as `args.sprite` at x, y, z on the
-- authority, as its action's complete() does once a client asks (ISToggleClothingWasher,
-- ISToggleComboWasherDryer), whatever the client checked; a washer-dryer set to `args.mode`
-- ("washer" or "dryer") first, as ISSetComboWasherDryerMode does. Answers whether it runs after and
-- whether a washer-dryer is set to dry. A refused action on a multiplayer client would clear the
-- test's queue, so the switch is run here rather than queued.
handler("appliances.toggle", function(player, args)
    local square = Server.squareAt(args)
    local washer = square and PZHarness.Fixtures.objectWithSprite(square, args.sprite)
    if not washer then
        return nil, "the washer at " .. args.x .. "," .. args.y
    end
    local combo = instanceof(washer, "IsoCombinationWasherDryer")
    if combo then
        if args.mode then
            ISSetComboWasherDryerMode:new(player, washer, args.mode):complete()
        end
        ISToggleComboWasherDryer:new(player, washer):complete()
    else
        ISToggleClothingWasher:new(player, washer):complete()
    end
    return { activated = washer:isActivated(), dryer = combo and washer:isModeDryer() }
end)
