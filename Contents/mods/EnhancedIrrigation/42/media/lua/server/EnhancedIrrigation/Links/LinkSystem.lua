-- The authority's side of the tank links (shared/EnhancedIrrigation/Links.lua): a Global Object
-- System with no objects, used for what it saves with the world (its own modData keys) and sends
-- the clients (its initial state on connect, then a command on each change). Every ten minutes
-- water finds its level through each link with a tank loaded at both ends. A link is buried pipe,
-- run through walls and under floors as vanilla's plumbing is, so it never freezes or wears: unlike
-- a garden line it has nothing to age. Nor does it go with a tank: taken down, picked up or
-- smashed, the tank leaves the pipe in the ground, and one set on that square again is on it.

if isClient() then return end

require "Map/SGlobalObjectSystem"
require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Materials"
require "EnhancedIrrigation/Jobs"
require "EnhancedIrrigation/Pipes"
require "EnhancedIrrigation/Tanks"
require "EnhancedIrrigation/Links"
require "EnhancedIrrigation/LinkJobs"

EnhancedIrrigation = EnhancedIrrigation or {}
local LinkSystem = SGlobalObjectSystem:derive("EnhancedIrrigation_LinkSystem")
EnhancedIrrigation.LinkSystem = LinkSystem

local Links, LinkJobs, Pipes, Tanks = EnhancedIrrigation.Links, EnhancedIrrigation.LinkJobs, EnhancedIrrigation.Pipes,
    EnhancedIrrigation.Tanks
local Materials = EnhancedIrrigation.Materials

-- Litres an hour a link carries at most: a pipe under a barrel's head passes a few litres a
-- minute, so a full raised barrel fills an empty one beside it in under two hours, and two
-- barrels on one floor level out in under one.
LinkSystem.LINK_RATE = 360
-- A flow smaller than this isn't worth a sync to every client.
local LEAST_LITRES = 0.01

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

function LinkSystem:addLink(a, b, kind, lengths, conditions)
    table.insert(self.links, {
        a = { x = a.x, y = a.y, z = a.z }, b = { x = b.x, y = b.y, z = b.z }, kind = kind, lengths = lengths,
        conditions = conditions,
    })
    self:sendLinks()
end

function LinkSystem:removeLink(link)
    for i, entry in ipairs(self.links) do
        if entry == link then
            table.remove(self.links, i)
            self:sendLinks()
            return
        end
    end
end

-- Jobs -----------------------------------------------------------------------------------------

-- What each job does at `object` toward the square `with` names. Returns whether it was done.
local DO = {
    [LinkJobs.PLUMB] = function(character, tank, with, materials)
        local kind, lengths = LinkJobs.pipeFor(tank, with)
        local other = Links.decode(with)
        LinkSystem.instance:addLink(EnhancedIrrigation.squareOf(tank), other, kind, lengths,
            Materials.conditions(character, materials))
        return true
    end,
    -- Every length comes back as it went in; the joints and the time are what plumbing cost.
    [LinkJobs.UNPLUMB] = function(character, object, with)
        local link = Links.find(EnhancedIrrigation.squareOf(object), Links.decode(with))
        LinkSystem.instance:removeLink(link)
        Pipes.giveBack(character, link.kind, link.lengths, link.conditions)
        return true
    end,
}

--- Does `job` at `object` (a tank, or for Unplumb the floor of a bare end) toward the square `with`
--- names for `character` on the authority (Jobs.perform). Returns whether it was done.
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
    litres = math.min(litres, LinkSystem.LINK_RATE * hours)
    if litres < LEAST_LITRES then
        return false
    end
    -- The mixture moves, taint and all.
    FluidContainer.Transfer(from, to, litres)
    return true
end

--- Moves water through every link with a tank at both ends, as `hours` of flow. A link with an end
--- unloaded, or whose tank has gone from it, waits.
function LinkSystem:pass(hours)
    local changed = {}
    for _, link in ipairs(self.links) do
        local tankA, tankB = Tanks.tankAt(link.a.x, link.a.y, link.a.z), Tanks.tankAt(link.b.x, link.b.y, link.b.z)
        if tankA and tankB and flow(tankA, tankB, hours) then
            changed[tankA], changed[tankB] = true, true
        end
    end
    for tank in pairs(changed) do
        Tanks.sync(tank)
    end
end

local function everyTenMinutes()
    local self = LinkSystem.instance
    local hours = EnhancedIrrigation.catchUp(self)
    if hours > 0 then
        self:pass(hours)
    end
end

Events.EveryTenMinutes.Add(everyTenMinutes)
SGlobalObjectSystem.RegisterSystemClass(LinkSystem)

return LinkSystem
