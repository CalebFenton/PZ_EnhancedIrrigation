-- The one shape every feature's hands-on jobs take (StandJobs, LinkJobs, LineJobs), so the menu,
-- the action's start() and the authority read the same refusal and can't disagree.

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Materials"

EnhancedIrrigation = EnhancedIrrigation or {}
local Jobs = {}
EnhancedIrrigation.Jobs = Jobs

local Materials = EnhancedIrrigation.Materials

-- Only a client that made up a job of its own asks for one no module has.
local UNKNOWN_JOB = "Tooltip_EnhancedIrrigation_UnknownJob"

--- Why a job is refused: its `blocker` (a Tooltip key) if any, else Short while any of `needs` is
--- unmet, else nil.
function Jobs.refusal(blocker, needs)
    if blocker then
        return blocker
    end
    return EnhancedIrrigation.firstUnmet(needs) and "Tooltip_EnhancedIrrigation_Short" or nil
end

--- Adds to the job module `Module` what the menu, the action's start() and the authority read of
--- its jobs. Beside how the job looks (EnhancedIrrigationAction), each row of Module.JOBS has
--- `blocker(character, object, with)`, what refuses it beside its materials (a Tooltip key or nil),
--- and `materials`, what it takes: a list, or a function(character, object, with) of one, which must
--- answer for any object, refused or not; absent when it takes nothing. Adds Module.blocker,
--- Module.materials, Module.needs and Module.refusal, each (character, job, object, with).
function Jobs.define(Module)
    function Module.blocker(character, job, object, with)
        local row = Module.JOBS[job]
        if not row then
            return UNKNOWN_JOB
        end
        return row.blocker and row.blocker(character, object, with) or nil
    end

    function Module.materials(character, job, object, with)
        local materials = Module.JOBS[job] and Module.JOBS[job].materials
        if type(materials) == "function" then
            return materials(character, object, with)
        end
        return materials or {}
    end

    function Module.needs(character, job, object, with)
        return Materials.needs(character, Module.materials(character, job, object, with))
    end

    function Module.refusal(character, job, object, with)
        return Jobs.refusal(Module.blocker(character, job, object, with),
            Module.needs(character, job, object, with))
    end
end

--- Does `job` of `Module` (Jobs.define) on the authority once its timed action has finished: checks
--- it again, does it (`DO[job](character, object, with, materials)`, which returns whether it was
--- done), and only then uses up the materials, read before the job changed anything. Returns
--- whether it was done.
function Jobs.perform(Module, DO, character, job, object, with)
    if Module.refusal(character, job, object, with) then
        return false
    end
    local materials = Module.materials(character, job, object, with)
    if not DO[job](character, object, with, materials) then
        return false
    end
    Materials.consume(character, materials)
    return true
end

return Jobs
