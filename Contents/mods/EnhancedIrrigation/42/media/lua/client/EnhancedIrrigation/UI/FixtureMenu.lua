-- The right-click options of fixtures (sinks, baths, showers, toilets, washers): Plumb to Tank, with
-- a submenu of the tanks in reach, until the fixture is plumbed, then Unplumb. Vanilla's own Plumb,
-- on a fixture under a barrel one storey up, makes the same link (Plumb Above) while the
-- PlumbingKeepsTaint option is on, and goes from the menu once the fixture is plumbed. A washer
-- with a buffer gets back the on/off switch vanilla only gives a fixture without one.

require "ISUI/ISWorldObjectContextMenu"
require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Tanks"
require "EnhancedIrrigation/Links"
require "EnhancedIrrigation/LinkJobs"
require "EnhancedIrrigation/Fixtures"
require "EnhancedIrrigation/UI/Needs"
require "EnhancedIrrigation/UI/TankMenu"
require "EnhancedIrrigation/TimedActions/EnhancedIrrigationAction"

EnhancedIrrigation = EnhancedIrrigation or {}
local FixtureMenu = {}
EnhancedIrrigation.FixtureMenu = FixtureMenu

local Needs, Tanks, Links = EnhancedIrrigation.Needs, EnhancedIrrigation.Tanks, EnhancedIrrigation.Links
local LinkJobs, Fixtures, TankMenu = EnhancedIrrigation.LinkJobs, EnhancedIrrigation.Fixtures, EnhancedIrrigation.TankMenu

-- Vanilla's Plumb ----------------------------------------------------------------------------------

-- The Java menu calls vanilla's Plumb by this name (ISWorldObjectContextMenuLogic.doWaterPipeMenu),
-- so replacing the function routes it here.
local vanillaPlumb = ISWorldObjectContextMenu.onPlumbItem

--- Plumbs `fixture` to the tank vanilla's plumbing would draw on, with the mod's link, which keeps
--- the tank's taint; a store that isn't one of the mod's tanks, or the option off, keeps vanilla's.
function FixtureMenu.onPlumbItem(worldobjects, playerNum, fixture)
    local source = Fixtures.plumbingKeepsTaint() and fixture:FindExternalWaterSource()
    if source and Tanks.isTank(source) then
        EnhancedIrrigationAction.queue(playerNum, "link", LinkJobs.PLUMB_ABOVE, fixture,
            Links.encode(EnhancedIrrigation.squareOf(source)))
        return
    end
    vanillaPlumb(worldobjects, playerNum, fixture)
end

ISWorldObjectContextMenu.onPlumbItem = FixtureMenu.onPlumbItem

-- Takes vanilla's Plumb out of `context`: on a plumbed fixture under a barrel it would plumb again.
-- A get-up option carries the handler as its first parameter.
local function removeVanillaPlumb(context)
    for _, option in ipairs(context.options) do
        if option.onSelect == ISWorldObjectContextMenu.onPlumbItem or option.param1 == ISWorldObjectContextMenu.onPlumbItem then
            context:removeOptionByName(option.name)
            return
        end
    end
end

-- The washer's switch ------------------------------------------------------------------------------

-- Turn On or Off for a washer with a buffer, as vanilla offers it on one drawing the town's water
-- (ISWorldObjectContextMenuLogic.toggleClothingWasher): greyed out without power or water. A
-- washer-dryer keeps vanilla's own switch, which the menu gives it either way.
local function addWasherSwitch(context, playerNum, worldobjects, washer)
    if not (instanceof(washer, "IsoClothingWasher") and washer:getContainer() and washer:getFluidContainer()) then
        return
    end
    local key = washer:isActivated() and "ContextMenu_Turn_Off" or "ContextMenu_Turn_On"
    local option = context:addGetUpOption(getText(key), worldobjects, ISWorldObjectContextMenu.onToggleClothingWasher,
        washer, playerNum)
    if not washer:getContainer():isPowered() then
        Needs.refuse(option, "IGUI_RadioRequiresPowerNearby")
    elseif washer:getFluidAmount() <= 0 then
        Needs.refuse(option, "IGUI_RequiresWaterSupply")
    end
end

-- Plumb to Tank and Unplumb ------------------------------------------------------------------------

-- A plumbed fixture offers Unplumb, its pipe found there even with its tank gone; any other offers
-- Plumb to Tank.
local function addLinkOptions(context, playerNum, character, fixture)
    if Fixtures.linkAt(EnhancedIrrigation.squareOf(fixture)) then
        TankMenu.addUnplumbOptions(context, playerNum, character, fixture)
        return
    end
    TankMenu.addPlumbOptions(context, playerNum, character, fixture, {
        job = LinkJobs.PLUMB_FIXTURE,
        skip = function() return false end,
        refusal = function(at) return (LinkJobs.fixtureBlocker(fixture, Links.encode(at))) end,
        noneKey = "ContextMenu_EnhancedIrrigation_NoTankForFixture",
    })
end

function FixtureMenu.onFill(playerNum, context, worldobjects, test)
    local character = getSpecificPlayer(playerNum)
    if not character or character:getVehicle() then return end
    local fixture = Needs.findClicked(worldobjects, Fixtures.isFixture)
    if not fixture then return end
    if test then return ISWorldObjectContextMenu.setTest() end
    if Fixtures.linkAt(EnhancedIrrigation.squareOf(fixture)) then
        removeVanillaPlumb(context)
    end
    addWasherSwitch(context, playerNum, worldobjects, fixture)
    addLinkOptions(context, playerNum, character, fixture)
end

Events.OnFillWorldObjectContextMenu.Add(FixtureMenu.onFill)

return FixtureMenu
