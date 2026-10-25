-- The right-click options of fixtures (sinks, baths, showers, toilets, washers): Plumb to Tank, with
-- a submenu of the tanks in reach, until the fixture is plumbed, then Unplumb. Vanilla's own Plumb,
-- on a fixture under a barrel one storey up, makes the same link (Plumb Above) while the
-- PlumbingKeepsTaint option is on, and goes from the menu once the fixture is plumbed. A washer
-- with a buffer gets back the on/off switch vanilla only gives a fixture without one.

require "ISUI/ISWorldObjectContextMenu"
require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Tanks"
require "EnhancedIrrigation/Links/Links"
require "EnhancedIrrigation/Links/LinkJobs"
require "EnhancedIrrigation/Fixtures/Fixtures"
require "EnhancedIrrigation/Appliances/Appliances"
require "EnhancedIrrigation/UI/Needs"
require "EnhancedIrrigation/UI/JobOptions"
require "EnhancedIrrigation/UI/LinkMenu"
require "EnhancedIrrigation/TimedActions/EnhancedIrrigationAction"

EnhancedIrrigation = EnhancedIrrigation or {}
local FixtureMenu = {}
EnhancedIrrigation.FixtureMenu = FixtureMenu

local Needs, Tanks, Links = EnhancedIrrigation.Needs, EnhancedIrrigation.Tanks, EnhancedIrrigation.Links
local LinkJobs, Fixtures, LinkMenu = EnhancedIrrigation.LinkJobs, EnhancedIrrigation.Fixtures, EnhancedIrrigation.LinkMenu

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
local function removeVanillaPlumb(context)
    for _, option in ipairs(context.options) do
        if EnhancedIrrigation.JobOptions.handlerOf(option) == ISWorldObjectContextMenu.onPlumbItem then
            context:removeOptionByName(option.name)
            return
        end
    end
end

-- The washer's switch ------------------------------------------------------------------------------

-- Turn On or Off for a washer with a buffer, as vanilla offers it on one drawing the town's water
-- (ISWorldObjectContextMenuLogic.toggleClothingWasher): greyed out without power or water, or with
-- its pump salvaged. A washer-dryer keeps vanilla's own switch, which the menu gives it either way.
local function addWasherSwitch(context, playerNum, worldobjects, washer)
    if not (instanceof(washer, "IsoClothingWasher") and washer:getContainer() and washer:getFluidContainer()) then
        return
    end
    local key = washer:isActivated() and "ContextMenu_Turn_Off" or "ContextMenu_Turn_On"
    local option = context:addGetUpOption(getText(key), worldobjects, ISWorldObjectContextMenu.onToggleClothingWasher,
        washer, playerNum)
    -- ApplianceMenu greys a stripped appliance's switches, but its handler, loaded first by name,
    -- runs before this one adds this switch.
    if EnhancedIrrigation.Appliances.refusesSwitchOn(washer) then
        Needs.refuse(option, "Tooltip_EnhancedIrrigation_PumpSalvaged")
    elseif not washer:getContainer():isPowered() then
        Needs.refuse(option, "IGUI_RadioRequiresPowerNearby")
    elseif washer:getFluidAmount() <= 0 then
        Needs.refuse(option, "IGUI_RequiresWaterSupply")
    end
end

-- Plumb to Tank and Unplumb ------------------------------------------------------------------------

-- A plumbed fixture offers Unplumb, its pipe found there even with its tank gone; any other offers
-- Plumb to Tank.
local function addLinkOptions(context, playerNum, character, fixture)
    if Links.roleAt(EnhancedIrrigation.squareOf(fixture), "fixture") then
        LinkMenu.addUnplumbOptions(context, playerNum, character, fixture)
        return
    end
    LinkMenu.addPlumbOptions(context, playerNum, character, fixture, {
        nameKey = "ContextMenu_EnhancedIrrigation_PlumbToTank",
        job = LinkJobs.PLUMB_FIXTURE,
        blocker = function(at) return (LinkJobs.fixtureBlocker(fixture, Links.encode(at))) end,
        noneKey = "ContextMenu_EnhancedIrrigation_NoTankForEnd",
    })
end

EnhancedIrrigation.JobOptions.onWorldMenu(Fixtures.isFixture, function(context, playerNum, character, fixture, worldobjects)
    if Links.roleAt(EnhancedIrrigation.squareOf(fixture), "fixture") then
        removeVanillaPlumb(context)
    end
    addWasherSwitch(context, playerNum, worldobjects, fixture)
    addLinkOptions(context, playerNum, character, fixture)
end)

return FixtureMenu
