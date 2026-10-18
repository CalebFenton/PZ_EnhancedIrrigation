-- The jobs that plumb one tank to another and take the pipe out again, done on the authority by
-- server/EnhancedIrrigation/Links/LinkSystem.lua. A job's `with` names the other tank's square
-- (Links.encode).

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Jobs"
require "EnhancedIrrigation/Pipes"
require "EnhancedIrrigation/Tanks"
require "EnhancedIrrigation/Links"

EnhancedIrrigation = EnhancedIrrigation or {}
local LinkJobs = {}
EnhancedIrrigation.LinkJobs = LinkJobs

local Links, Pipes, Tanks = EnhancedIrrigation.Links, EnhancedIrrigation.Pipes, EnhancedIrrigation.Tanks

LinkJobs.PLUMB = "PlumbToTank"
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

--- The pipe `character` would plumb `tank` to the square `with` names with: its kind
--- (Pipes.kindFor) and lengths.
function LinkJobs.pipeFor(character, tank, with)
    local lengths = Links.lengthsFor(runTiles(tank, with))
    return Pipes.kindFor(character, lengths), lengths
end

-- The squares of `tank` and of the other tank `with` names, or nil when the tank is gone or `with`
-- names no other square.
local function endsOf(tank, with)
    local other = Links.decode(with)
    if not (other and Tanks.isTank(tank)) then
        return nil
    end
    local here = EnhancedIrrigation.squareOf(tank)
    if EnhancedIrrigation.sameSquare(here, other) then
        return nil
    end
    return here, other
end

LinkJobs.JOBS = {
    [LinkJobs.PLUMB] = {
        minutes = function(tank, with) return Links.minutesFor(runTiles(tank, with)) end,
        position = "Mid", sound = "RepairWithWrench", equip = pipeWrench,
        blocker = function(character, tank, with)
            local here, other = endsOf(tank, with)
            if not (here and Tanks.tankAt(other.x, other.y, other.z)) then
                return "Tooltip_EnhancedIrrigation_TankGone"
            end
            if Links.distance(here, other) > Links.MAX_TILES then
                return "Tooltip_EnhancedIrrigation_OutOfReach"
            end
            return Links.find(here, other) and "Tooltip_EnhancedIrrigation_AlreadyPlumbed" or nil
        end,
        materials = function(character, tank, with)
            local list = {}
            for _, material in ipairs(LinkJobs.PLUMB_TOOLS) do
                table.insert(list, material)
            end
            for _, material in ipairs(Pipes.materials(LinkJobs.pipeFor(character, tank, with))) do
                table.insert(list, material)
            end
            return list
        end,
    },
    [LinkJobs.UNPLUMB] = {
        minutes = 10, position = "Mid", sound = "RepairWithWrench", equip = pipeWrench,
        blocker = function(character, tank, with)
            local here, other = endsOf(tank, with)
            if not here then
                return "Tooltip_EnhancedIrrigation_TankGone"
            end
            return not Links.find(here, other) and "Tooltip_EnhancedIrrigation_NotPlumbed" or nil
        end,
        materials = { Pipes.WRENCH },
    },
}

EnhancedIrrigation.Jobs.define(LinkJobs)

return LinkJobs
