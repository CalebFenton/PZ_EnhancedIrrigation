require "TimedActions/ISBaseTimedAction"
require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Tanks"
require "EnhancedIrrigation/Stands"
require "EnhancedIrrigation/StandJobs"
require "EnhancedIrrigation/LinkJobs"
require "EnhancedIrrigation/Fixtures"
require "EnhancedIrrigation/Lines"
require "EnhancedIrrigation/LineJobs"
require "EnhancedIrrigation/Treatment"
require "EnhancedIrrigation/TreatmentJobs"

-- Every hands-on job of fixed length at one of the mod's objects (StandJobs, LinkJobs, LineJobs,
-- TreatmentJobs).
-- In multiplayer the client runs start() and perform() and the server rebuilds the action from
-- new()'s parameters and runs complete(), which does the job; single player runs both. A global,
-- as the server finds the class by its Type (NetTimedAction.parse).
EnhancedIrrigationAction = EnhancedIrrigationAction or ISBaseTimedAction:derive("EnhancedIrrigationAction")

local Action = EnhancedIrrigationAction
local Stands, LineJobs, Treatment = EnhancedIrrigation.Stands, EnhancedIrrigation.LineJobs, EnhancedIrrigation.Treatment

-- Each feature: isTarget(object), the objects it works at; jobs, its job module
-- (Jobs.define), whose JOBS[job] rows also say how long the job takes and how it looks;
-- perform(character, job, object, with), which does the job on the authority and returns whether
-- it was done, looked up when a job completes, since server files load after shared ones.
-- A JOBS row: minutes (a number, or function(object, with, character)); anim and position (the loot
-- animation low down when absent); heavy (heavy work while it lasts); sound, played while it lasts,
-- and doneSound, when it's done; equip(character, object, with), which picks the tool to hold while
-- the job is done.
local FEATURES = {
    stand = {
        isTarget = function(object) return Stands.isStand(object) or Stands.isRaised(object) end,
        jobs = EnhancedIrrigation.StandJobs,
        perform = function(...) return EnhancedIrrigation.StandSystem.perform(...) end,
    },
    -- Plumbing works at a tank, a fixture or a treatment unit; Unplumb also at the floor of an end
    -- whose tank, fixture or unit is gone.
    link = {
        isTarget = function(object)
            return EnhancedIrrigation.Tanks.isTank(object) or EnhancedIrrigation.Fixtures.isFixture(object)
                or Treatment.isUnit(object) or EnhancedIrrigation.isFloor(object)
        end,
        jobs = EnhancedIrrigation.LinkJobs,
        perform = function(...) return EnhancedIrrigation.LinkSystem.perform(...) end,
    },
    line = {
        isTarget = function(object) return EnhancedIrrigation.Lines.isLine(object) or EnhancedIrrigation.isFloor(object) end,
        jobs = LineJobs,
        perform = function(...) return EnhancedIrrigation.LineSystem.perform(...) end,
    },
    treatment = {
        isTarget = Treatment.isUnit,
        jobs = EnhancedIrrigation.TreatmentJobs,
        perform = function(...) return EnhancedIrrigation.TreatmentSystem.perform(...) end,
    },
}

-- How far from the middle of the object's square, on each axis in squares, the character may work
-- at it: what luautils.walkAdj counts as there, and a little for drift and a client's lag.
Action.REACH = 2.6

local function rowOf(feature, job)
    return FEATURES[feature].jobs.JOBS[job]
end

-- Whether `with` is an inventory item the character works with, rather than a world object.
local function isItem(with)
    return with ~= nil and instanceof(with, "InventoryItem")
end

function Action:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    local minutes = rowOf(self.feature, self.job).minutes
    if type(minutes) == "function" then
        minutes = minutes(self.object, self.with, self.character)
    end
    return minutes * EnhancedIrrigation.unitsPerMinute()
end

function Action:isValid()
    -- Past here the item may already be gone: complete() can sync the item it used before the
    -- server's word that the action is done arrives.
    if self.action and self.action:getJobDelta() >= 0.9 then
        return true
    end
    if not (EnhancedIrrigation.onSquare(self.object) and FEATURES[self.feature].isTarget(self.object)) then
        return false
    end
    if isItem(self.with) and not self.character:getInventory():containsRecursive(self.with) then
        return false
    end
    return EnhancedIrrigation.withinReach(self.character, self.object, Action.REACH)
end

function Action:waitToStart()
    self.character:faceThisObject(self.object)
    return self.character:shouldBeTurning()
end

function Action:update()
    self.character:faceThisObject(self.object)
    if rowOf(self.feature, self.job).heavy then
        self.character:setMetabolicTarget(Metabolics.HeavyWork)
    end
end

function Action:start()
    if not isClient() and FEATURES[self.feature].jobs.refusal(self.character, self.job, self.object, self.with) then
        self:forceStop()
        return
    end
    if isClient() and isItem(self.with) then
        self.with = self.character:getInventory():getItemWithIDRecursiv(self.with:getID())
    end
    local row = rowOf(self.feature, self.job)
    self:setActionAnim(row.anim or "Loot")
    if row.position or not row.anim then
        self.character:SetVariable("LootPosition", row.position or "Low")
    end
    if row.sound then
        self.sound = self.character:playSound(row.sound)
    end
end

function Action:stopSound()
    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:stopOrTriggerSound(self.sound)
    end
end

function Action:stop()
    self:stopSound()
    ISBaseTimedAction.stop(self)
end

function Action:perform()
    self:stopSound()
    local doneSound = rowOf(self.feature, self.job).doneSound
    if doneSound then
        self.character:playSound(doneSound)
    end
    ISInventoryPage.renderDirty = true
    ISBaseTimedAction.perform(self)
end

-- The server never calls isValid(), so the performer checks the job again; this checks that the
-- character is at the object, which NetTimedAction doesn't.
function Action:complete()
    if not EnhancedIrrigation.onSquare(self.object)
            or (isServer() and not EnhancedIrrigation.withinReach(self.character, self.object, Action.REACH)) then
        return false
    end
    return FEATURES[self.feature].perform(self.character, self.job, self.object, self.with)
end

-- Parameter names match the fields: the multiplayer server rebuilds the action by passing them to
-- new() in order (NetTimedAction). `feature` is a key of FEATURES and `job` one of its jobs;
-- `object` the object worked at; `with` what the job works with, if anything: an inventory item
-- (the barrel set on a stand) or a string the job reads (a pipe material, a tank's square).
function Action:new(character, feature, job, object, with)
    local o = ISBaseTimedAction.new(self, character)
    o.feature = feature
    o.job = job
    o.object = object
    o.with = with
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = o:getDuration()
    return o
end

--- Walks `playerNum`'s character over to `object` and queues `job` there, holding the tool the
--- job's `equip` picks, if any. Client only.
function Action.queue(playerNum, feature, job, object, with)
    local character = getSpecificPlayer(playerNum)
    if not luautils.walkAdj(character, object:getSquare(), true) then
        return
    end
    local equip = rowOf(feature, job).equip
    local tool = equip and equip(character, object, with)
    if tool then
        ISWorldObjectContextMenu.equip(character, character:getPrimaryHandItem(), tool, true, false)
    end
    ISTimedActionQueue.add(Action:new(character, feature, job, object, with))
end

return Action
