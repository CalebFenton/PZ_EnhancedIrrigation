-- The authority's side of plumbed fixtures (shared/EnhancedIrrigation/Fixtures.lua): giving a
-- fixture its buffer, filling it from its tank, and taking fixtures that vanilla plumbed off the
-- rooftop route, whose water always comes out clean, onto the mod's (docs/design.md, Fixtures).
-- The links themselves are the LinkSystem's, which refills each buffer as it runs its links.

if isClient() then return end

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Sprites"
require "EnhancedIrrigation/Tanks"
require "EnhancedIrrigation/Fixtures"

EnhancedIrrigation = EnhancedIrrigation or {}
local FixtureSystem = {}
EnhancedIrrigation.FixtureSystem = FixtureSystem

local Fixtures, Tanks = EnhancedIrrigation.Fixtures, EnhancedIrrigation.Tanks

-- A fill smaller than this isn't worth a sync to every client.
local LEAST_LITRES = 0.01

--- `fixture`'s buffer, given it first if it has none: an empty FluidContainer of its reserve's
--- size, which the engine then serves its drink, fill, wash and washer from, taint and all.
--- canBeWaterPiped turns off the town's water and vanilla's reserve (IsoObject.isWaterInfinite,
--- isUnmovedPipedWaterSource), and vanilla's rooftop plumbing goes, so the buffer is all it has: cut
--- in to a tank, a fixture holds only that tank's water. A buffer stays once given: a client copy
--- is told of a container added (IsoObject.syncFluidContainerSend), never of one taken away.
function FixtureSystem.ensureBuffer(fixture)
    local buffer = fixture:getFluidContainer()
    if buffer then
        return buffer
    end
    buffer = ComponentType.FluidContainer:CreateComponent()
    buffer:setCapacity(Fixtures.capacityOf(fixture))
    GameEntityFactory.AddComponent(fixture, true, buffer)
    fixture:getModData().canBeWaterPiped = true
    if fixture:getUsesExternalWaterSource() then
        fixture:setUsesExternalWaterSource(false)
        fixture:sendObjectChange(IsoObjectChange.USES_EXTERNAL_WATER_SOURCE, { value = false })
    end
    fixture:transmitModData()
    fixture:sync()
    return buffer
end

--- Fills `fixture`'s buffer from `tank` by up to `litres`, as far as the buffer has room and the
--- tank has water; the mixture moves, taint and all. Syncs the fixture, not the tank. Returns
--- whether any moved.
function FixtureSystem.fill(tank, fixture, litres)
    local buffer = FixtureSystem.ensureBuffer(fixture)
    local tankFluid = tank:getFluidContainer()
    local moved = math.min(litres, buffer:getFreeCapacity(), tankFluid:getAmount())
    if moved < LEAST_LITRES then
        return false
    end
    FluidContainer.Transfer(tankFluid, buffer, moved)
    fixture:sync()
    return true
end

--- Plumbs `fixture` to `tank` with `kind` pipe in `lengths` lengths (none for vanilla's Plumb), whose
--- items were at `conditions`: the link, the buffer, and a first fill, as the pipe goes in full.
function FixtureSystem.plumb(fixture, tank, kind, lengths, conditions)
    EnhancedIrrigation.LinkSystem.instance:addLink(EnhancedIrrigation.squareOf(tank),
        EnhancedIrrigation.squareOf(fixture), kind, lengths, conditions, true)
    if FixtureSystem.fill(tank, fixture, Fixtures.capacityOf(fixture)) then
        Tanks.sync(tank)
    else
        FixtureSystem.ensureBuffer(fixture)
    end
end

--- Takes `fixture` off vanilla's rooftop plumbing onto a link to the same tank, when the
--- PlumbingKeepsTaint option says so and its source is a tank of the mod's. Returns false while
--- vanilla finds no source, which a storey still loading can hide; true once there is nothing
--- more to do.
function FixtureSystem.convert(fixture)
    if not (Fixtures.plumbingKeepsTaint() and fixture:getUsesExternalWaterSource()) then
        return true
    end
    local tank = fixture:FindExternalWaterSource()
    if not tank then
        return false
    end
    -- Another mod's store stays on vanilla's route, which is all it knows.
    if Tanks.isTank(tank) and not Fixtures.linkAt(EnhancedIrrigation.squareOf(fixture)) then
        FixtureSystem.plumb(fixture, tank, nil, 0, nil)
    end
    return true
end

-- Converting as chunks load ----------------------------------------------------------------------

-- The base game's waterPiped tiles (docs/research.md, Fixture tiles): washers and washer-dryers,
-- toilets, baths, the shower and sinks. A fixture of another mod's tiles isn't converted, and keeps
-- vanilla's plumbing until plumbed again.
local FIXTURE_TILES = {
    { "appliances_laundry_01_", 0, 7 },
    { "fixtures_bathroom_01_", 0, 7 },
    { "fixtures_bathroom_01_", 24, 27 },
    { "fixtures_bathroom_01_", 32, 33 },
    { "fixtures_sinks_01_", 0, 25 },
    { "fixtures_sinks_01_", 28, 35 },
}

-- A fixture whose source vanilla never finds stays on its plumbing rather than being tried forever.
local TRIES = 60

local pending = {}

local function queuePlumbed(fixture)
    if fixture:getUsesExternalWaterSource() then
        table.insert(pending, { fixture = fixture, tries = 0 })
    end
end

-- Tried a tick after loading and on, since the storey above, with the tank, may not be in the cell
-- yet while the chunk's squares are still loading (IsoChunk.doLoadGridsquare).
local function convertPending()
    if #pending == 0 then
        return
    end
    local waiting = {}
    for _, entry in ipairs(pending) do
        entry.tries = entry.tries + 1
        if EnhancedIrrigation.onSquare(entry.fixture) and not FixtureSystem.convert(entry.fixture)
                and entry.tries < TRIES then
            table.insert(waiting, entry)
        end
    end
    pending = waiting
end

for _, range in ipairs(FIXTURE_TILES) do
    for i = range[2], range[3] do
        MapObjects.OnLoadWithSprite(range[1] .. i, queuePlumbed, EnhancedIrrigation.Sprites.LOAD_PRIORITY)
    end
end
Events.OnTick.Add(convertPending)

return FixtureSystem
