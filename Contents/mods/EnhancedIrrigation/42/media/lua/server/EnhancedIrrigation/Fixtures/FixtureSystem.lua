-- The authority's side of plumbed fixtures: giving a fixture its buffer, refilling it from its tank
-- as the links run, holding back its vanilla reserve while it's plumbed, and taking fixtures that
-- vanilla plumbed off the rooftop route, whose water always comes out clean, onto the mod's
-- (docs/design.md, Fixtures).

if isClient() then return end

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Sprites"
require "EnhancedIrrigation/Tanks"
require "EnhancedIrrigation/Links/Links"
require "EnhancedIrrigation/Fixtures/Fixtures"

EnhancedIrrigation = EnhancedIrrigation or {}
local FixtureSystem = {}
EnhancedIrrigation.FixtureSystem = FixtureSystem

local Fixtures, Tanks, Links = EnhancedIrrigation.Fixtures, EnhancedIrrigation.Tanks, EnhancedIrrigation.Links

--- `fixture`'s buffer, given it first if it has none: an empty FluidContainer of its reserve's
--- size. The engine serves the fixture's drink, fill, wash and washer from it, taint and all, once
--- the town's water stops (IsoObject.isWaterInfinite comes first). Vanilla's rooftop plumbing
--- goes, so with its reserve held back the buffer is all it has after the shutoff. A buffer stays
--- once given: a client copy is told of a container added (IsoObject.syncFluidContainerSend),
--- never of one taken away.
function FixtureSystem.ensureBuffer(fixture)
    local buffer = fixture:getFluidContainer()
    if buffer then
        return buffer
    end
    buffer = ComponentType.FluidContainer:CreateComponent()
    buffer:setCapacity(Fixtures.capacityOf(fixture))
    GameEntityFactory.AddComponent(fixture, true, buffer)
    if fixture:getUsesExternalWaterSource() then
        fixture:setUsesExternalWaterSource(false)
        fixture:sendObjectChange(IsoObjectChange.USES_EXTERNAL_WATER_SOURCE, { value = false })
    end
    fixture:sync()
    return buffer
end

-- Empties `fixture`'s buffer while the town's water runs to it. The engine reads a buffer's taint
-- before the town's water (IsoObject.isTaintedWater), so water poured into it would have the
-- town's read as tainted.
local function standBy(fixture)
    local buffer = fixture:getFluidContainer()
    if buffer and buffer:getAmount() > 0 then
        buffer:Empty()
        fixture:sync()
    end
end

-- Holds back `fixture`'s vanilla reserve, which the engine would serve clean once its buffer ran
-- dry. Returns the litres held, for the link to give back on Unplumb, or nil with none.
local function holdReserve(fixture)
    local reserve = Fixtures.reserveOf(fixture)
    if reserve <= 0 then
        return nil
    end
    fixture:getModData().waterAmount = 0
    fixture:transmitModData()
    return reserve
end

--- Gives the fixture of `link`, being unplumbed, back the reserve plumbing held, so
--- it has what vanilla would give. A fixture gone from the square takes nothing.
function FixtureSystem.giveBackReserve(link)
    local at = Links.ends(link)
    local fixture = link.reserve and Fixtures.fixtureAt(at.x, at.y, at.z)
    if fixture then
        fixture:getModData().waterAmount = link.reserve
        fixture:transmitModData()
    end
end

-- Fills `fixture`'s buffer from `tank` by up to `litres` (Links.carry). Syncs the fixture, not the
-- tank. Returns whether any moved.
local function fill(tank, fixture, litres)
    if not Links.carry(tank:getFluidContainer(), FixtureSystem.ensureBuffer(fixture), litres) then
        return false
    end
    fixture:sync()
    return true
end

--- Refills the buffer of the fixture plumbed by `link` from its tank for `hours`, while both are
--- loaded, the tank stands high enough to push, and the town's water no longer runs to it.
--- Returns the tank when any water moved.
function FixtureSystem.refill(link, hours)
    local at, tankAt = Links.ends(link)
    local fixture = Fixtures.fixtureAt(at.x, at.y, at.z)
    if fixture and Fixtures.townWaterRuns(fixture) then
        standBy(fixture)
        return nil
    end
    local tank = Tanks.tankAt(tankAt.x, tankAt.y, tankAt.z)
    if tank and fixture and Tanks.hasPressureFor(tank, at.z)
            and fill(tank, fixture, Fixtures.REFILL_RATE * hours) then
        return tank
    end
    return nil
end

--- Plumbs `fixture` to `tank` with `material` pipe in `lengths` lengths (none for vanilla's
--- Plumb), whose items were at `conditions`: the link, the buffer, and a first fill as the pipe goes
--- in full, unless the town's water runs to it.
function FixtureSystem.plumb(fixture, tank, material, lengths, conditions)
    FixtureSystem.ensureBuffer(fixture)
    local link = EnhancedIrrigation.LinkSystem.instance:addLink(EnhancedIrrigation.squareOf(fixture),
        EnhancedIrrigation.squareOf(tank), material, lengths, conditions, "fixture")
    link.reserve = holdReserve(fixture)
    if not Fixtures.townWaterRuns(fixture) and fill(tank, fixture, Fixtures.capacityOf(fixture)) then
        tank:sync()
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
    if Tanks.isTank(tank) and not Links.roleAt(EnhancedIrrigation.squareOf(fixture), "fixture") then
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
