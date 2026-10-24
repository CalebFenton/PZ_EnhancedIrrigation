-- The jobs that plumb a tank to another tank, to a fixture, to a treatment unit's inlet or outlet
-- or to a pump's outlet, and take the pipe out again, done on the authority by
-- server/EnhancedIrrigation/Links/LinkSystem.lua. A job's `with` names the square of the link's
-- other end and, for Plumb, the pipe the player chose to lay (Links.encode). Plumb works at a tank;
-- Plumb Fixture and vanilla's Plumb (Plumb Above) at a fixture, toward its tank; Plumb Inlet and
-- Plumb Outlet at a unit, toward the tank it draws from or fills; Plumb Pump at a pump, toward the
-- tank it fills or a tile of the garden line it feeds; Unplumb at either end, or at the floor of an
-- end whose tank, fixture, unit or pump is gone, as the buried pipe stays (Links.lua).

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Jobs"
require "EnhancedIrrigation/Pipes"
require "EnhancedIrrigation/Tanks"
require "EnhancedIrrigation/Links/Links"
require "EnhancedIrrigation/Lines/Lines"
require "EnhancedIrrigation/Fixtures/Fixtures"
require "EnhancedIrrigation/Treatment/Treatment"
require "EnhancedIrrigation/Pumps/Pumps"
require "EnhancedIrrigation/Pumps/PumpJobs"

EnhancedIrrigation = EnhancedIrrigation or {}
local LinkJobs = {}
EnhancedIrrigation.LinkJobs = LinkJobs

local Links, Pipes, Tanks = EnhancedIrrigation.Links, EnhancedIrrigation.Pipes, EnhancedIrrigation.Tanks
local Lines = EnhancedIrrigation.Lines
local Fixtures, Treatment = EnhancedIrrigation.Fixtures, EnhancedIrrigation.Treatment
local Pumps, PumpJobs = EnhancedIrrigation.Pumps, EnhancedIrrigation.PumpJobs

LinkJobs.PLUMB = "PlumbToTank"
LinkJobs.PLUMB_FIXTURE = "PlumbFixture"
-- Vanilla's Plumb, which needs no pipe and no learning: a fixture to the tank straight above it.
LinkJobs.PLUMB_ABOVE = "PlumbAbove"
LinkJobs.PLUMB_INLET = "PlumbInlet"
LinkJobs.PLUMB_OUTLET = "PlumbOutlet"
LinkJobs.PLUMB_PUMP = "PlumbPump"
LinkJobs.UNPLUMB = "Unplumb"

-- The knowledge recipe the pamphlet teaches; it is never crafted, only known.
LinkJobs.RECIPE = "EnhancedIrrigation_PlumbToTank"

-- What Plumb takes before the pipe, which the menu checks before it lists the tanks in reach.
LinkJobs.PLUMB_TOOLS = { Pipes.WRENCH, { recipe = LinkJobs.RECIPE } }

local function pipeWrench(character)
    return character:getInventory():getFirstTagEvalRecurse(ItemTag.PIPE_WRENCH, EnhancedIrrigation.notBroken)
end

-- The tiles of pipe from `tank` to the square `with` names, 0 when it names none.
local function runTiles(tank, with)
    local other = Links.decode(with)
    return other and Links.distance(EnhancedIrrigation.squareOf(tank), other) or 0
end

--- The pipe Plumb lays from `tank` to the square `with` names: the kind `with` names, or nil, and
--- the lengths the run takes.
function LinkJobs.pipeFor(tank, with)
    local _, kind = Links.decode(with)
    return Pipes.KINDS[kind] and kind or nil, Links.lengthsFor(runTiles(tank, with))
end

-- The square `object` stands on and the square `with` names, or nil when `with` names no other
-- square.
local function endsOf(object, with)
    local other = Links.decode(with)
    if not other then
        return nil
    end
    local here = EnhancedIrrigation.squareOf(object)
    if EnhancedIrrigation.sameSquare(here, other) then
        return nil
    end
    return here, other
end

-- What Plumb and Plumb Fixture take: the wrench, the knowledge, and the pipe the run needs.
local function plumbMaterials(character, object, with)
    local list = {}
    for _, material in ipairs(LinkJobs.PLUMB_TOOLS) do
        table.insert(list, material)
    end
    local kind, lengths = LinkJobs.pipeFor(object, with)
    for _, material in ipairs(kind and Pipes.materials(kind, lengths) or {}) do
        table.insert(list, material)
    end
    return list
end

--- Why the fixture `fixture` can't be plumbed to the tank on the square `with` names, as far as
--- both ends go, a Tooltip key, or nil; and the two squares.
function LinkJobs.fixtureBlocker(fixture, with)
    local here, other = endsOf(fixture, with)
    if not (here and Fixtures.isFixture(fixture)) then
        return "Tooltip_EnhancedIrrigation_UnknownJob"
    end
    local tank = Tanks.tankAt(other.x, other.y, other.z)
    if not tank then
        return "Tooltip_EnhancedIrrigation_TankGone"
    end
    if Fixtures.linkAt(here) then
        return "Tooltip_EnhancedIrrigation_FixturePlumbed"
    end
    -- A fixture is an outlet: its tank must push, as a tap's must.
    if not Tanks.hasPressureFor(tank, here.z) then
        return "Tooltip_EnhancedIrrigation_FixtureNoPressure"
    end
    return nil, here, other
end

-- Each end a unit's pipe can be: the Tooltip key saying the unit has that end plumbed already, and
-- the one saying the tank stands where water can't run that way (design, Tanks and height).
local UNIT_ENDS = {
    inlet = { plumbed = "Tooltip_EnhancedIrrigation_InletPlumbed", wrongLevel = "Tooltip_EnhancedIrrigation_InletTankTooLow" },
    outlet = { plumbed = "Tooltip_EnhancedIrrigation_OutletPlumbed", wrongLevel = "Tooltip_EnhancedIrrigation_OutletTankTooHigh" },
}

--- Whether water runs between a tank at `tankLevel` and a unit at `unitLevel` through the unit's
--- `role` end: into its head from a tank at least level with it, out of its basin into a tank no
--- higher.
function LinkJobs.runsFor(role, tankLevel, unitLevel)
    if role == "inlet" then
        return tankLevel >= unitLevel
    end
    return unitLevel >= tankLevel
end

--- Why the unit `unit`'s `role` end ("inlet" or "outlet") can't be plumbed to the tank on the square
--- `with` names, as far as both ends go, a Tooltip key, or nil; and the two squares.
function LinkJobs.unitBlocker(unit, with, role)
    local here, other = endsOf(unit, with)
    local spec = Treatment.specOf(unit)
    if not (here and spec and spec.plumbed and Treatment.isUnit(unit) and UNIT_ENDS[role]) then
        return "Tooltip_EnhancedIrrigation_UnknownJob"
    end
    local tank = Tanks.tankAt(other.x, other.y, other.z)
    if not tank then
        return "Tooltip_EnhancedIrrigation_TankGone"
    end
    if Treatment.linkOf(here, role) then
        return UNIT_ENDS[role].plumbed
    end
    if Links.find(here, other) then
        return "Tooltip_EnhancedIrrigation_AlreadyPlumbed"
    end
    if not LinkJobs.runsFor(role, Tanks.levelOf(tank), Treatment.levelOf(unit)) then
        return UNIT_ENDS[role].wrongLevel
    end
    return nil, here, other
end

--- Why the pump `pump`'s outlet can't be plumbed to the tank or line tile on the square `with`
--- names, as far as both ends go, a Tooltip key, or nil; and the two squares. A pump fills a tank up
--- to its lift above its floor, whatever the filling rule says (Pumps.lifts), and feeds a line no
--- higher; a line takes a tap or a pump, not both, and one pump. A Pump House's lift is its part's,
--- so it is plumbed once one is fitted.
function LinkJobs.pumpBlocker(pump, with)
    local here, other = endsOf(pump, with)
    if not (here and Pumps.isPump(pump)) then
        return "Tooltip_EnhancedIrrigation_UnknownJob"
    end
    local spec = Pumps.liftingSpec(pump)
    if not spec then
        return "Tooltip_EnhancedIrrigation_NoPumpFitted"
    end
    local into = Tanks.tankAt(other.x, other.y, other.z) or Lines.lineAt(other.x, other.y, other.z)
    if not into then
        return "Tooltip_EnhancedIrrigation_TankGone"
    end
    if Pumps.outletOf(here) then
        return "Tooltip_EnhancedIrrigation_OutletPlumbed"
    end
    if Links.find(here, other) then
        return "Tooltip_EnhancedIrrigation_AlreadyPlumbed"
    end
    if Lines.isLine(into) then
        local tiles = Lines.component(other.x, other.y, other.z)
        if Lines.tapIn(tiles) then
            return "Tooltip_EnhancedIrrigation_LineHasTap"
        end
        if Pumps.pumpFeeding(tiles) then
            return "Tooltip_EnhancedIrrigation_LinePumped"
        end
    end
    if not Pumps.lifts(spec, PumpJobs.levelOf(into), here.z) then
        return PumpJobs.LIFT_KEYS[spec.lift]
    end
    return nil, here, other
end

-- The row of a plumbing job at a unit or pump toward the tank `with` names, refused as
-- `blocker(object, with)` refuses it as far as both ends go: Plumb Fixture's.
local function plumbJobFor(blocker)
    return {
        minutes = function(object, with) return Links.minutesFor(runTiles(object, with)) end,
        position = "Mid", sound = "RepairWithWrench", equip = pipeWrench,
        blocker = function(character, object, with)
            local refusal, here, other = blocker(object, with)
            if refusal then
                return refusal
            end
            if Links.distance(here, other) > Links.MAX_TILES then
                return "Tooltip_EnhancedIrrigation_OutOfReach"
            end
            return not LinkJobs.pipeFor(object, with) and "Tooltip_EnhancedIrrigation_UnknownJob" or nil
        end,
        materials = plumbMaterials,
    }
end

-- The row of Plumb Inlet or Plumb Outlet, toward a unit's `role` end.
local function unitPlumbJob(role)
    return plumbJobFor(function(unit, with) return LinkJobs.unitBlocker(unit, with, role) end)
end

LinkJobs.JOBS = {
    [LinkJobs.PLUMB] = {
        minutes = function(tank, with) return Links.minutesFor(runTiles(tank, with)) end,
        position = "Mid", sound = "RepairWithWrench", equip = pipeWrench,
        blocker = function(character, tank, with)
            local here, other = endsOf(tank, with)
            if not (here and Tanks.isTank(tank) and Tanks.tankAt(other.x, other.y, other.z)) then
                return "Tooltip_EnhancedIrrigation_TankGone"
            end
            if Links.distance(here, other) > Links.MAX_TILES then
                return "Tooltip_EnhancedIrrigation_OutOfReach"
            end
            if Links.find(here, other) then
                return "Tooltip_EnhancedIrrigation_AlreadyPlumbed"
            end
            -- Only a client that made up a job asks for pipe no kind has.
            return not LinkJobs.pipeFor(tank, with) and "Tooltip_EnhancedIrrigation_UnknownJob" or nil
        end,
        materials = plumbMaterials,
    },
    [LinkJobs.PLUMB_FIXTURE] = {
        minutes = function(fixture, with) return Links.minutesFor(runTiles(fixture, with)) end,
        position = "Mid", sound = "RepairWithWrench", equip = pipeWrench,
        blocker = function(character, fixture, with)
            local blocker, here, other = LinkJobs.fixtureBlocker(fixture, with)
            if blocker then
                return blocker
            end
            if Links.distance(here, other) > Links.MAX_TILES then
                return "Tooltip_EnhancedIrrigation_OutOfReach"
            end
            return not LinkJobs.pipeFor(fixture, with) and "Tooltip_EnhancedIrrigation_UnknownJob" or nil
        end,
        materials = plumbMaterials,
    },
    -- The pipe of vanilla's plumbing runs up through the ceiling; like vanilla's it takes none.
    [LinkJobs.PLUMB_ABOVE] = {
        minutes = Links.BASE_MINUTES, position = "Mid", sound = "RepairWithWrench", equip = pipeWrench,
        blocker = function(character, fixture, with)
            if not Fixtures.plumbingKeepsTaint() then
                return "Tooltip_EnhancedIrrigation_UnknownJob"
            end
            local blocker, here, other = LinkJobs.fixtureBlocker(fixture, with)
            if blocker then
                return blocker
            end
            return not Fixtures.isAbove(here, other) and "Tooltip_EnhancedIrrigation_OutOfReach" or nil
        end,
        materials = { Pipes.WRENCH },
    },
    [LinkJobs.PLUMB_INLET] = unitPlumbJob("inlet"),
    [LinkJobs.PLUMB_OUTLET] = unitPlumbJob("outlet"),
    [LinkJobs.PLUMB_PUMP] = plumbJobFor(LinkJobs.pumpBlocker),
    [LinkJobs.UNPLUMB] = {
        minutes = 10, position = "Mid", sound = "RepairWithWrench", equip = pipeWrench,
        blocker = function(character, object, with)
            local here, other = endsOf(object, with)
            return not (here and Links.find(here, other)) and "Tooltip_EnhancedIrrigation_NotPlumbed" or nil
        end,
        materials = { Pipes.WRENCH },
    },
}

EnhancedIrrigation.Jobs.define(LinkJobs)

return LinkJobs
