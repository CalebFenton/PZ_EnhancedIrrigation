-- The jobs that lay buried pipe between a tank and another tank, a fixture, a treatment unit's end
-- or a pump's outlet, and take it out again, done on the authority by LinkSystem. A job's `with`
-- names the square of the link's other end and, for a job that lays pipe, the pipe the player
-- chose (Links.encode). Unplumb also works at the floor of an end whose object is gone, as the
-- buried pipe stays.

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Materials"
require "EnhancedIrrigation/Jobs"
require "EnhancedIrrigation/Pipes"
require "EnhancedIrrigation/Tanks"
require "EnhancedIrrigation/Links/Links"
require "EnhancedIrrigation/Lines/Lines"
require "EnhancedIrrigation/Fixtures/Fixtures"
require "EnhancedIrrigation/Treatment/Treatment"
require "EnhancedIrrigation/Pumps/Pumps"

EnhancedIrrigation = EnhancedIrrigation or {}
local LinkJobs = {}
EnhancedIrrigation.LinkJobs = LinkJobs

local Jobs = EnhancedIrrigation.Jobs
local Links, Pipes, Tanks = EnhancedIrrigation.Links, EnhancedIrrigation.Pipes, EnhancedIrrigation.Tanks
local Lines = EnhancedIrrigation.Lines
local Fixtures, Treatment = EnhancedIrrigation.Fixtures, EnhancedIrrigation.Treatment
local Pumps = EnhancedIrrigation.Pumps

LinkJobs.PLUMB = "PlumbToTank"
LinkJobs.PLUMB_FIXTURE = "PlumbFixture"
-- Vanilla's Plumb, which needs no pipe and no learning: a fixture to a tank where vanilla's plumbing
-- looks for its water.
LinkJobs.PLUMB_ABOVE = "PlumbAbove"
LinkJobs.PLUMB_INLET = "PlumbInlet"
LinkJobs.PLUMB_OUTLET = "PlumbOutlet"
LinkJobs.PLUMB_PUMP = "PlumbPump"
LinkJobs.UNPLUMB = "Unplumb"

-- The knowledge recipe the pamphlet teaches; it is never crafted, only known.
LinkJobs.RECIPE = "EnhancedIrrigation_PlumbToTank"

-- What Plumb takes before the pipe, which the menu checks before it lists the tanks in reach.
LinkJobs.PLUMB_TOOLS = { Pipes.WRENCH, { recipe = LinkJobs.RECIPE } }

local holdWrench = EnhancedIrrigation.Materials.holds(Pipes.WRENCH)

-- The tiles of pipe from `tank` to the square `with` names, 0 when it names none.
local function runTiles(tank, with)
    local other = Links.decode(with)
    return other and Links.distance(EnhancedIrrigation.squareOf(tank), other) or 0
end

--- The pipe Plumb lays from `tank` to the square `with` names: the material `with` names, or nil,
--- and the lengths the run takes.
function LinkJobs.pipeFor(tank, with)
    local _, material = Links.decode(with)
    return Pipes.MATERIALS[material] and material or nil, Links.lengthsFor(runTiles(tank, with))
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

-- What a job that lays pipe takes: the wrench, the knowledge, and the pipe the run needs.
local function plumbMaterials(character, object, with)
    local material, lengths = LinkJobs.pipeFor(object, with)
    return material and Pipes.materials(material, lengths, LinkJobs.PLUMB_TOOLS) or LinkJobs.PLUMB_TOOLS
end

-- The Tooltip key saying an object has its end of each role plumbed already (Links.roleAt).
local PLUMBED = {
    fixture = "Tooltip_EnhancedIrrigation_FixturePlumbed",
    inlet = "Tooltip_EnhancedIrrigation_InletPlumbed",
    outlet = "Tooltip_EnhancedIrrigation_OutletPlumbed",
    pump = "Tooltip_EnhancedIrrigation_OutletPlumbed",
}

--- Why the fixture `fixture` can't be plumbed to the tank on the square `with` names, as far as
--- both ends go, a Tooltip key, or nil; and the two squares.
function LinkJobs.fixtureBlocker(fixture, with)
    local here, other = endsOf(fixture, with)
    if not (here and Fixtures.isFixture(fixture)) then
        return Jobs.UNKNOWN
    end
    local tank = Tanks.tankAt(other.x, other.y, other.z)
    if not tank then
        return "Tooltip_EnhancedIrrigation_TankGone"
    end
    if Links.roleAt(here, "fixture") then
        return PLUMBED.fixture
    end
    -- A fixture is an outlet: its tank must push, as a tap's must.
    if not Tanks.hasPressureFor(tank, here.z) then
        return "Tooltip_EnhancedIrrigation_FixtureNoPressure"
    end
    return nil, here, other
end

-- The Tooltip key saying the tank stands where water can't run through each end of a unit's pipe.
local WRONG_LEVEL = {
    inlet = "Tooltip_EnhancedIrrigation_InletTankTooLow",
    outlet = "Tooltip_EnhancedIrrigation_OutletTankTooHigh",
}

--- Why the unit `unit`'s `role` end ("inlet" or "outlet") can't be plumbed to the tank on the square
--- `with` names, as far as both ends go, a Tooltip key, or nil; and the two squares.
function LinkJobs.unitBlocker(unit, with, role)
    local here, other = endsOf(unit, with)
    local spec = Treatment.specOf(unit)
    if not (here and spec and spec.plumbed and Treatment.isUnit(unit) and WRONG_LEVEL[role]) then
        return Jobs.UNKNOWN
    end
    local tank = Tanks.tankAt(other.x, other.y, other.z)
    if not tank then
        return "Tooltip_EnhancedIrrigation_TankGone"
    end
    if Links.roleAt(here, role) then
        return PLUMBED[role]
    end
    if Links.find(here, other) then
        return "Tooltip_EnhancedIrrigation_AlreadyPlumbed"
    end
    if not Treatment.runsFor(role, tank, unit) then
        return WRONG_LEVEL[role]
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
        return Jobs.UNKNOWN
    end
    local spec = Pumps.liftingSpec(pump)
    if not spec then
        return "Tooltip_EnhancedIrrigation_NoPumpFitted"
    end
    local into = Tanks.tankAt(other.x, other.y, other.z) or Lines.lineAt(other.x, other.y, other.z)
    if not into then
        return "Tooltip_EnhancedIrrigation_TankGone"
    end
    if Links.roleAt(here, "pump") then
        return PLUMBED.pump
    end
    if Links.find(here, other) then
        return "Tooltip_EnhancedIrrigation_AlreadyPlumbed"
    end
    local taken = Lines.isLine(into) and Lines.FEED_TAKEN[Lines.feedOf(Lines.component(other.x, other.y, other.z))]
    if taken then
        return taken
    end
    if not Pumps.lifts(spec, Tanks.levelOf(into), here.z) then
        return Pumps.LIFT_KEYS[spec.lift]
    end
    return nil, here, other
end

-- Why the tank `tank` can't be plumbed to the tank on the square `with` names, as far as both ends
-- go, a Tooltip key, or nil; and the two squares.
local function tankBlocker(tank, with)
    local here, other = endsOf(tank, with)
    if not (here and Tanks.isTank(tank) and Tanks.tankAt(other.x, other.y, other.z)) then
        return "Tooltip_EnhancedIrrigation_TankGone"
    end
    if Links.find(here, other) then
        return "Tooltip_EnhancedIrrigation_AlreadyPlumbed"
    end
    return nil, here, other
end

-- The row of a plumbing job toward the square `with` names, refused as `endsBlocker(object, with)`
-- refuses it as far as both ends go, then by the run's length and the pipe `with` names, which
-- only a client that made up a job leaves out.
local function plumbJobFor(endsBlocker)
    return {
        minutes = function(object, with) return Links.minutesFor(runTiles(object, with)) end,
        position = "Mid", sound = "RepairWithWrench", equip = holdWrench,
        blocker = function(character, object, with)
            local blocker, here, other = endsBlocker(object, with)
            if blocker then
                return blocker
            end
            if Links.distance(here, other) > Links.MAX_TILES then
                return "Tooltip_EnhancedIrrigation_OutOfReach"
            end
            return not LinkJobs.pipeFor(object, with) and Jobs.UNKNOWN or nil
        end,
        materials = plumbMaterials,
    }
end

-- The row of Plumb Inlet or Plumb Outlet, toward a unit's `role` end.
local function unitPlumbJob(role)
    return plumbJobFor(function(unit, with) return LinkJobs.unitBlocker(unit, with, role) end)
end

-- Whether the square `at` is where vanilla's plumbing looks for `fixture`'s water
-- (IsoObject.FindExternalWaterSource): on the floor above, within a tile of any cell of the
-- fixture's sprite grid, or of its own square `here` without one. Which tank there vanilla prefers
-- shifts with what each holds, so it is the menu's choice, not a condition of the job.
local function isAbove(fixture, here, at)
    if at.z ~= here.z + 1 then
        return false
    end
    local grid, sprite = fixture:getSpriteGrid(), fixture:getSprite()
    local x, y, width, height = here.x, here.y, 1, 1
    if grid then
        x, y = here.x - grid:getSpriteGridPosX(sprite), here.y - grid:getSpriteGridPosY(sprite)
        width, height = grid:getWidth(), grid:getHeight()
    end
    return at.x >= x - 1 and at.x <= x + width and at.y >= y - 1 and at.y <= y + height
end

LinkJobs.JOBS = {
    [LinkJobs.PLUMB] = plumbJobFor(tankBlocker),
    [LinkJobs.PLUMB_FIXTURE] = plumbJobFor(LinkJobs.fixtureBlocker),
    -- The pipe of vanilla's plumbing runs up through the ceiling; like vanilla's it takes none.
    [LinkJobs.PLUMB_ABOVE] = {
        minutes = Links.BASE_MINUTES, position = "Mid", sound = "RepairWithWrench", equip = holdWrench,
        blocker = function(character, fixture, with)
            if not Fixtures.plumbingKeepsTaint() then
                return Jobs.UNKNOWN
            end
            local blocker, here, other = LinkJobs.fixtureBlocker(fixture, with)
            if blocker then
                return blocker
            end
            return not isAbove(fixture, here, other) and "Tooltip_EnhancedIrrigation_OutOfReach" or nil
        end,
        materials = { Pipes.WRENCH },
    },
    [LinkJobs.PLUMB_INLET] = unitPlumbJob("inlet"),
    [LinkJobs.PLUMB_OUTLET] = unitPlumbJob("outlet"),
    [LinkJobs.PLUMB_PUMP] = plumbJobFor(LinkJobs.pumpBlocker),
    [LinkJobs.UNPLUMB] = {
        minutes = 10, position = "Mid", sound = "RepairWithWrench", equip = holdWrench,
        blocker = function(character, object, with)
            local here, other = endsOf(object, with)
            return not (here and Links.find(here, other)) and "Tooltip_EnhancedIrrigation_NotPlumbed" or nil
        end,
        materials = { Pipes.WRENCH },
    },
}

Jobs.define(LinkJobs)

return LinkJobs
