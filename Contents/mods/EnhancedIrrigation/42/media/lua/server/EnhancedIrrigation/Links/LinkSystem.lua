-- The authority's side of the links (shared/EnhancedIrrigation/Links/Links.lua): a Global Object System
-- with no objects, used for what it saves with the world (its own modData keys) and sends the
-- clients (its initial state on connect, then a command on each change). Every ten minutes water
-- finds its level through each link between two tanks loaded at both ends, each plumbed fixture's
-- tank refills its buffer, and each treatment unit's outlet empties its basin; its inlet fills its
-- head in the unit's own time (TreatmentObject.advance), which catches up the time the unit was
-- unloaded, and a pump's outlet carries what the pump lifts as it lifts it (PumpSystem.pump). A
-- link is buried pipe, run through walls and under floors as vanilla's plumbing is, so it never
-- freezes or wears: unlike a garden line it has nothing to age. Nor does it go with a tank,
-- fixture, unit or pump: taken down, picked up or smashed, it leaves the pipe in the ground, and
-- one set on that square again is on it.

if isClient() then return end

require "Map/SGlobalObjectSystem"
require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Materials"
require "EnhancedIrrigation/Jobs"
require "EnhancedIrrigation/Pipes"
require "EnhancedIrrigation/Tanks"
require "EnhancedIrrigation/Links/Links"
require "EnhancedIrrigation/Links/LinkJobs"
require "EnhancedIrrigation/Fixtures/Fixtures"
require "EnhancedIrrigation/Fixtures/FixtureSystem"
require "EnhancedIrrigation/Treatment/TreatmentSystem"
require "EnhancedIrrigation/Lines/LineSystem"

EnhancedIrrigation = EnhancedIrrigation or {}
local LinkSystem = SGlobalObjectSystem:derive("EnhancedIrrigation_LinkSystem")
EnhancedIrrigation.LinkSystem = LinkSystem

local Links, LinkJobs, Pipes, Tanks = EnhancedIrrigation.Links, EnhancedIrrigation.LinkJobs, EnhancedIrrigation.Pipes,
    EnhancedIrrigation.Tanks
local Materials, Fixtures, FixtureSystem = EnhancedIrrigation.Materials, EnhancedIrrigation.Fixtures,
    EnhancedIrrigation.FixtureSystem
local TreatmentSystem = EnhancedIrrigation.TreatmentSystem

-- What the system saves with the world (its modData keys): `links`, the list; `lastHour`, when
-- water last moved, so a pass moves what the time since allows however often the event fires.
local SAVED_KEYS = { "links", "lastHour" }

function LinkSystem:new()
    return SGlobalObjectSystem.new(self, Links.SYSTEM_NAME)
end

function LinkSystem:initSystem()
    Links.serverSystem = self
    self.system:setModDataKeys(SAVED_KEYS)
    self.links = self.links or {}
    -- Counts the lists sent, so a client keeps the newest when two arrive out of order. Not saved:
    -- a client connects to a fresh server with its initial state, which carries the count.
    self.version = 0
end

-- A client that connects gets the list with the system (CGlobalObjects.registerSystem); single
-- player's client gets it the same way.
function LinkSystem:getInitialStateForClient()
    return { links = self.links, version = self.version }
end

function LinkSystem:isValidIsoObject(isoObject)
    return false
end

-- Commands -------------------------------------------------------------------------------------

-- Tells every client the whole list, which is short.
function LinkSystem:sendLinks()
    self.version = self.version + 1
    self:sendCommand("links", { links = self.links, version = self.version })
end

--- Adds the link from the square `at` to the square `other` (Links.new): with `role`, `at` is that
--- role's object. `kind` pipe in `lengths` lengths whose items were at `conditions`, none for
--- vanilla's Plumb. Returns the link.
function LinkSystem:addLink(at, other, kind, lengths, conditions, role)
    local link = Links.new(at, other, role)
    link.kind, link.lengths, link.conditions = kind, lengths, conditions
    table.insert(self.links, link)
    self:sendLinks()
    return link
end

-- A pump's line no longer runs once its outlet is gone.
function LinkSystem:removeLink(link)
    for i, entry in ipairs(self.links) do
        if entry == link then
            table.remove(self.links, i)
            self:sendLinks()
            local _, line = Links.ends(link)
            if link.pump and EnhancedIrrigation.Lines.recordAt(line.x, line.y, line.z) then
                EnhancedIrrigation.LineSystem.showRunning(line.x, line.y, line.z, false)
            end
            return
        end
    end
end

-- Jobs -----------------------------------------------------------------------------------------

-- Lays the pipe a job's `with` names from `object` to the square it names, as a link of `role`.
local function layPipe(role)
    return function(character, object, with, materials)
        local kind, lengths = LinkJobs.pipeFor(object, with)
        LinkSystem.instance:addLink(EnhancedIrrigation.squareOf(object), Links.decode(with), kind, lengths,
            Materials.conditions(character, materials), role)
    end
end

-- What each job does at `object` toward the square `with` names.
local DO = {
    [LinkJobs.PLUMB] = layPipe(nil),
    -- The tank the fixture's pipe runs to, as LinkJobs.fixtureBlocker found it before the job.
    [LinkJobs.PLUMB_FIXTURE] = function(character, fixture, with, materials)
        local kind, lengths = LinkJobs.pipeFor(fixture, with)
        local other = Links.decode(with)
        FixtureSystem.plumb(fixture, Tanks.tankAt(other.x, other.y, other.z), kind, lengths,
            Materials.conditions(character, materials))
    end,
    [LinkJobs.PLUMB_ABOVE] = function(character, fixture, with)
        local other = Links.decode(with)
        FixtureSystem.plumb(fixture, Tanks.tankAt(other.x, other.y, other.z), nil, 0, nil)
    end,
    [LinkJobs.PLUMB_INLET] = layPipe("inlet"),
    [LinkJobs.PLUMB_OUTLET] = layPipe("outlet"),
    [LinkJobs.PLUMB_PUMP] = layPipe("pump"),
    -- Every length comes back as it went in; the joints and the time are what plumbing cost.
    [LinkJobs.UNPLUMB] = function(character, object, with)
        local link = Links.find(EnhancedIrrigation.squareOf(object), Links.decode(with))
        LinkSystem.instance:removeLink(link)
        if link.kind then
            Pipes.giveBack(character, link.kind, link.lengths, link.conditions)
        end
        if link.fixture then
            FixtureSystem.giveBackReserve(link)
        end
    end,
}

--- Does `job` at `object` (a tank, a fixture, a unit, a pump, or for Unplumb the floor of a bare
--- end) toward the square `with` names for `character` on the authority (Jobs.perform). Returns
--- whether it was done.
function LinkSystem.perform(character, job, object, with)
    return EnhancedIrrigation.Jobs.perform(LinkJobs, DO, character, job, object, with)
end

-- Flow ------------------------------------------------------------------------------------------

-- Litres to move from `from` to `to` (FluidContainers) toward equal fill, the two on one level.
local function levelling(from, to)
    local a, b = from:getAmount(), to:getAmount()
    local ca, cb = from:getCapacity(), to:getCapacity()
    return (a * cb - b * ca) / (ca + cb)
end

-- Moves water between the linked `tankA` and `tankB` for `hours`. Returns whether any moved.
local function flow(tankA, tankB, hours)
    local levelA, levelB = Tanks.levelOf(tankA), Tanks.levelOf(tankB)
    local fluidA, fluidB = tankA:getFluidContainer(), tankB:getFluidContainer()
    local from, to, litres
    if levelA == levelB then
        if fluidA:getFilledRatio() >= fluidB:getFilledRatio() then
            from, to = fluidA, fluidB
        else
            from, to = fluidB, fluidA
        end
        litres = levelling(from, to)
    else
        -- Water fills the lower tank from the higher, as far as it has room.
        if levelA > levelB then
            from, to = fluidA, fluidB
        else
            from, to = fluidB, fluidA
        end
        litres = math.min(from:getAmount(), to:getFreeCapacity())
    end
    litres = math.min(litres, Links.RATE * hours)
    if litres < Links.LEAST_FLOW then
        return false
    end
    -- The mixture moves, taint and all.
    FluidContainer.Transfer(from, to, litres)
    return true
end

-- Refills the buffer of the fixture plumbed by `link` from its tank for `hours`, while both are
-- loaded and the tank stands high enough to push, and the town's water no longer runs to it.
-- Returns the tank when any water moved.
local function refill(link, hours)
    local fixture = Fixtures.fixtureAt(link.b.x, link.b.y, link.b.z)
    if fixture and Fixtures.townWaterRuns(fixture) then
        FixtureSystem.standBy(fixture)
        return nil
    end
    local tank = Tanks.tankAt(link.a.x, link.a.y, link.a.z)
    if tank and fixture and Tanks.hasPressureFor(tank, link.b.z)
            and FixtureSystem.fill(tank, fixture, Fixtures.REFILL_RATE * hours) then
        return tank
    end
    return nil
end

--- Moves water through every link with both ends loaded, as `hours` of flow: between two tanks,
--- from a tank into a fixture's buffer, or out of a unit's basin into a tank. A link with an end
--- unloaded, or gone from it, waits; an inlet runs in its unit's time (TreatmentObject.advance),
--- and a pump's outlet in its pump's, so neither can carry one gap's water twice.
function LinkSystem:pass(hours)
    local changed = {}
    for _, link in ipairs(self.links) do
        local tank
        if link.fixture then
            tank = refill(link, hours)
        elseif link.outlet then
            tank = TreatmentSystem.drain(link, Links.RATE * hours)
        elseif not (link.inlet or link.pump) then
            local tankA, tankB = Tanks.tankAt(link.a.x, link.a.y, link.a.z), Tanks.tankAt(link.b.x, link.b.y, link.b.z)
            if tankA and tankB and flow(tankA, tankB, hours) then
                changed[tankA], changed[tankB] = true, true
            end
        end
        if tank then
            changed[tank] = true
        end
    end
    for tank in pairs(changed) do
        Tanks.sync(tank)
    end
end

local function everyTenMinutes()
    local self = LinkSystem.instance
    local hours = EnhancedIrrigation.hoursSince(self)
    if hours > 0 then
        self:pass(hours)
    end
end

Events.EveryTenMinutes.Add(everyTenMinutes)
SGlobalObjectSystem.RegisterSystemClass(LinkSystem)

return LinkSystem
