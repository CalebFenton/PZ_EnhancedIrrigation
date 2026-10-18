require "PZHarness/Fixtures"

-- Development only, not published. Phase 1 of docs/design.md: before any fixture code is written,
-- prove in the running game that a plumbed fixture can hold its tank's water in a FluidContainer
-- of its own. This file is what the mod would do to a fixture, in the smallest form that shows
-- whether the engine keeps that water through vanilla's menus, actions, save and reload, and
-- multiplayer. The probe tests (EnhancedIrrigationTestsProbe.lua) and their server half
-- (EnhancedIrrigationTestServerProbe.lua) use it; the real fixture code replaces all three.

EnhancedIrrigationProbe = EnhancedIrrigationProbe or {}
local Probe = EnhancedIrrigationProbe

-- A white bathroom sink: vanilla flags it waterPiped, so in a room before the water shut-off it
-- gives the town's endless clean water unless its modData says canBeWaterPiped.
Probe.SINK = "fixtures_sinks_01_0"
-- Vanilla's wooden rain collector, an IsoThumpable entity with a FluidContainer: what
-- IsoObject.FindExternalWaterSource looks for on the storey above a plumbed fixture.
Probe.TANK_SPRITE = "carpentry_02_54"
Probe.TANK_ENTITY = "Base.RainCollector"
-- The reserve of a vanilla sink.
Probe.SINK_LITRES = 20

function Probe.find(x, y, z, sprite)
    local square = getCell():getGridSquare(x, y, z)
    return square and PZHarness.Fixtures.objectWithSprite(square, sprite) or nil
end

-- What vanilla's menus and actions read off a fixture, as plain values the server can send.
function Probe.describe(object)
    local fluid = object:getFluidContainer()
    return {
        buffer = fluid ~= nil,
        amount = object:getFluidAmount(),
        capacity = object:getFluidCapacity(),
        bufferAmount = fluid and fluid:getAmount() or 0,
        tainted = object:isTaintedWater(),
        hasWater = object:hasWater(),
        fluidName = object:getFluidUiName(),
        canBeWaterPiped = object:getModData().canBeWaterPiped == true,
        external = object:getUsesExternalWaterSource(),
    }
end

-- Gives `fixture` a FluidContainer of `capacity` litres holding `litres` of water, tainted or not,
-- and marks it canBeWaterPiped, which turns off vanilla's endless and reserve water
-- (IsoObject.isWaterInfinite, isUnmovedPipedWaterSource) so the container is all it has. Vanilla's
-- debug command addWaterContainer adds a component the same way. On a server, sync() sends the
-- container to the clients (IsoObject.syncFluidContainerSend), which add it to their copies.
function Probe.addBuffer(fixture, capacity, litres, tainted)
    local container = ComponentType.FluidContainer:CreateComponent()
    container:setCapacity(capacity)
    if litres > 0 then
        container:addFluid(tainted and FluidType.TaintedWater or FluidType.Water, litres)
    end
    GameEntityFactory.AddComponent(fixture, true, container)
    fixture:getModData().canBeWaterPiped = true
    fixture:transmitModData()
    fixture:sync()
    return container
end

-- Takes a fixture off vanilla's rooftop plumbing and gives it a buffer filled from the tank it
-- drew on, so its water keeps the tank's taint. Returns false while the tank isn't found.
function Probe.convert(fixture)
    local tank = fixture:FindExternalWaterSource()
    local tankFluid = tank and tank:getFluidContainer()
    if not tankFluid then
        return false
    end
    fixture:setUsesExternalWaterSource(false)
    fixture:sendObjectChange(IsoObjectChange.USES_EXTERNAL_WATER_SOURCE, { value = false })
    local buffer = Probe.addBuffer(fixture, Probe.SINK_LITRES, 0, false)
    tankFluid:transferTo(buffer, math.min(Probe.SINK_LITRES, tankFluid:getAmount()))
    fixture:sync()
    tank:sync()
    return true
end

return Probe
