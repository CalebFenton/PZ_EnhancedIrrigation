require "TimedActions/ISBaseTimedAction"
require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/TimedActions/EnhancedIrrigationAction"

-- An action with no end of its own, modelled on vanilla's open-ended ISAddWaterToTrough: the
-- character holds its target (Holds.lua) until they stop or walk off, or the authority stops it.
-- The authority runs it for the world time gone by, on a timed event the multiplayer server raises
-- itself (emulateAnimEvent), or from update() in single player, and once more as it ends.
--
-- Each action derived from it is a global with its own Type and its own new(character, <target>),
-- the parameter named as the target's field: the server finds the class by its Type
-- (NetTimedAction.parse) and rebuilds the action from the parameter names of the class's new
-- (NetTimedAction.set). It defines target(); isTarget(object); refusal(), a Tooltip key or nil;
-- hold(), whether it holds the target now; runFor(hours), on the authority, the Tooltip key of
-- why it stops or nil; playSounds(), through keepPlaying; LOOT_POSITION; RUN_EVENT; and HEAVY for
-- heavy work.
EnhancedIrrigationHeldAction = EnhancedIrrigationHeldAction or ISBaseTimedAction:derive("EnhancedIrrigationHeldAction")

local Action = EnhancedIrrigationHeldAction

-- How often, in real milliseconds, the multiplayer server runs the action: often enough that what
-- stops it (a tank dry or full) stops the character soon after. Read as each action starts.
Action.RUN_MS = 1000
-- How often, in game minutes, single player runs it.
Action.RUN_MINUTES = 1

-- The work stops at the authority. The client hears of it as the action's end.
function Action:finish()
    if isServer() then
        self.netAction:forceComplete()
    else
        self:forceComplete()
    end
end

-- Runs it for the world time since the last run (`lastHour`, set once it opens). Authority only.
function Action:run()
    local hours = EnhancedIrrigation.hoursSince(self)
    if self.finished then
        return
    end
    EnhancedIrrigation.Holds.renew(self)
    if self:runFor(hours) then
        self.finished = true
        self:finish()
    end
end

-- Whether the character still stands at the target: what isValid() checks, which the server never
-- calls, so the authority asks this itself before it opens and before each run.
function Action:atTarget()
    return EnhancedIrrigationAction.withinReach(self.character, self:target(), EnhancedIrrigationAction.REACH)
end

-- Opens it, holding the target; the time counts from here. Returns whether it opened. Authority
-- only.
function Action:open()
    if not (self:atTarget() and not self:refusal() and self:hold()) then
        return false
    end
    self.lastHour = EnhancedIrrigation.now()
    return true
end

-- The character let go, whatever ended the action: the last stretch runs, and the target is free
-- for the next. Authority only.
function Action:letGo()
    if self.lastHour and not self.finished then
        self:run()
    end
    self.finished = true
    EnhancedIrrigation.Holds.release(self)
end

-- The target held runs; a character who walked off let go of it. Authority only.
function Action:runHeld()
    if self.finished then
        return
    end
    if self:atTarget() then
        self:run()
    else
        self.finished = true
        self:finish()
    end
end

function Action:isValid()
    local target = self:target()
    return EnhancedIrrigation.onSquare(target) and self:isTarget(target) and self:atTarget()
end

function Action:waitToStart()
    self.character:faceThisObject(self:target())
    return self.character:shouldBeTurning()
end

-- Starts the sound `name` again once it ends.
function Action:keepPlaying(name)
    local id = self.sounds[name]
    if not (id and self.character:getEmitter():isPlaying(id)) then
        self.sounds[name] = self.character:playSound(name)
    end
end

function Action:stopSounds()
    for _, id in pairs(self.sounds or {}) do
        if self.character:getEmitter():isPlaying(id) then
            self.character:stopOrTriggerSound(id)
        end
    end
    self.sounds = nil
end

function Action:update()
    self.character:faceThisObject(self:target())
    if self.HEAVY then
        self.character:setMetabolicTarget(Metabolics.HeavyWork)
    end
    if self.sounds then
        self:playSounds()
    end
    if not isClient() and self.lastHour and not self.finished
            and (EnhancedIrrigation.now() - self.lastHour) * 60 >= self.RUN_MINUTES then
        self:runHeld()
    end
end

function Action:start()
    if not isClient() and not self:open() then
        self:forceStop()
        return
    end
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", self.LOOT_POSITION)
    self.sounds = {}
    self:playSounds()
end

-- The server never calls isValid() or start(), so it checks the target and the character itself
-- before it opens.
function Action:serverStart()
    if not self:open() then
        self.finished = true
        self.netAction:forceComplete()
        return
    end
    emulateAnimEvent(self.netAction, self.RUN_MS, self.RUN_EVENT, nil)
end

function Action:animEvent(event, parameter)
    if isServer() and event == self.RUN_EVENT then
        self:runHeld()
    end
end

function Action:serverStop()
    self:letGo()
end

function Action:stop()
    self:stopSounds()
    if not isClient() then
        self:letGo()
    end
    ISBaseTimedAction.stop(self)
end

function Action:perform()
    self:stopSounds()
    ISBaseTimedAction.perform(self)
end

function Action:complete()
    self:letGo()
    return true
end

function Action:getDuration()
    return -1
end

--- Walks `playerNum`'s character to `target` and queues the action class `self` there. Client
--- only.
function Action:queueAt(playerNum, target)
    local character = getSpecificPlayer(playerNum)
    if luautils.walkAdj(character, target:getSquare(), true) then
        ISTimedActionQueue.add(self:new(character, target))
    end
end

return Action
