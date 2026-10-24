require "EnhancedIrrigation/Debug/EnhancedIrrigationTestLib"
require "ISUI/ISWorldObjectContextMenu"
require "EnhancedIrrigation/Sprites"
require "EnhancedIrrigation/Links/Links"
require "EnhancedIrrigation/Links/LinkJobs"
require "EnhancedIrrigation/Lines/Lines"
require "EnhancedIrrigation/Lines/LineJobs"
require "EnhancedIrrigation/Pumps/Pumps"
require "EnhancedIrrigation/Pumps/PumpJobs"
require "EnhancedIrrigation/UI/LinkMenu"
require "EnhancedIrrigation/UI/PumpMenu"
require "EnhancedIrrigation/UI/LineMenu"
require "EnhancedIrrigation/TimedActions/EnhancedIrrigationPumpAction"

-- The hand pumps: building them from the build menu, plumbing the outlet within the pump's lift,
-- working the handle until the tank is full or the character is exhausted, the water each source
-- gives (a well's clean and endless, a barrel's with its taint, a river's tainted), the seal
-- wearing through and replaced, a worn-out pump smashed, and a pump's outlet plumbed to a garden
-- line, which it drives while worked. Pumps are placed, read and worked for set hours by server
-- handlers, so the clock doesn't decide the sums; the Pump action itself runs at a raised clock
-- speed.

local T = EnhancedIrrigationTest
local expect, expectNear = T.expect, T.expectNear
local Sprites, Links, LinkJobs = EnhancedIrrigation.Sprites, EnhancedIrrigation.Links, EnhancedIrrigation.LinkJobs
local Lines, LineJobs = EnhancedIrrigation.Lines, EnhancedIrrigation.LineJobs
local Pumps, PumpJobs, LinkMenu = EnhancedIrrigation.Pumps, EnhancedIrrigation.PumpJobs, EnhancedIrrigation.LinkMenu

local LITRES = 0.05
local WOODEN, IRON = "EnhancedIrrigation_WoodenHandPump", "EnhancedIrrigation_IronHandPump"
local SPRITES = { [WOODEN] = Sprites.WOODEN_HAND_PUMP, [IRON] = Sprites.IRON_HAND_PUMP }
local LEATHER, PLUNGER = "Base.LeatherStrips", "Base.Plunger"
-- What vanilla's Leather Strips leave once used (their ReplaceOnUse), which a seal must not.
local DIRTY_LEATHER = "Base.LeatherStripsDirty"
-- A raised barrel's water: vanilla's round rain barrel's.
local BARREL_LITRES = 600
-- The clock's speed while the handle is worked, so the tank fills in a moment.
local PUMP_SPEED = 100
-- How often, in real milliseconds, the multiplayer server runs a worked pump in these tests: a
-- frame or two, where the mod's second would be most of a test's time.
local RUN_MS = 20
-- An hour's minutes, as the record's sums take them.
local MINUTE = 1 / 60

-- Pumps -------------------------------------------------------------------------------------------------

local function copyOf(pump)
    return T.objectWithSprite(getSquare(pump.x, pump.y, pump.z), pump.sprite)
end

local function summaryOf(pump)
    local copy = copyOf(pump)
    return copy and Pumps.summaryOf(copy)
end

--- Queues placing the pump `entity` at `handle` with `fields` on its record, and a wait for this
--- client's copy and its summary. Returns its handle, with `spec`.
local function placePump(self, handle, entity, fields)
    local pump = { x = handle.x, y = handle.y, z = handle.z, sprite = SPRITES[entity], spec = Pumps.UNITS[entity],
        square = handle.square }
    T.server(self, "pumps.place", T.at(pump, { sprite = pump.sprite, fields = fields }))
    T.waitFor(self, function() return summaryOf(pump) ~= nil end, "this client's copy of the " .. entity)
    return pump
end

-- Queues the server's view of the pump, with `extra` args (tank, well), into self.reads[label].
local function read(self, pump, label, extra)
    T.read(self, "pumps.state", T.at(pump, extra), label)
end

local function readUntil(self, pump, label, done, extra)
    T.readUntil(self, "pumps.state", T.at(pump, extra), label, done)
end

-- Queues plumbing the pump's outlet to `tank` on the server, with `fields` set on its record, and a
-- wait for this client to know of the link and to have the summary.
local function link(self, pump, tank, fields)
    T.server(self, "pumps.link", T.at(pump, { tank = T.at(tank), fields = fields }))
    T.waitFor(self, function()
        local summary = summaryOf(pump)
        return Pumps.outletOf(T.at(pump)) ~= nil and summary ~= nil
            and (not (fields and fields.seal) or summary.seal == fields.seal)
    end, "this client's copy of the pump's outlet")
end

-- Queues working the pump for each of `hours` on the server, with `fields` set first and the
-- `tank`'s state, into self.reads[label] ({ before, steps }).
local function run(self, pump, label, hours, fields, tank)
    T.read(self, "pumps.run", T.at(pump, { hours = hours, fields = fields, tank = tank and T.at(tank) }), label)
end

-- Queues a wait until this client's summary of the pump satisfies `holds(summary)`.
local function waitForSummary(self, pump, holds, what)
    T.waitFor(self, function()
        local summary = summaryOf(pump)
        return summary ~= nil and holds(summary)
    end, what)
end

local function useMenu(self, pump, label, find, choose)
    T.goNextTo(self, pump.square)
    T.useOption(self, function() return copyOf(pump) end, label, find, choose)
end

local function pumpOption(context)
    return T.findOption(context, context, function(option)
        return option.onSelect == EnhancedIrrigationPumpAction.queue
    end)
end

local function job(id, with)
    return function(context) return T.jobOption(context, "pump", id, with) end
end

local function linkJob(id, with)
    return function(context) return T.jobOption(context, "link", id, with) end
end

-- The option of the submenu named by `nameKey` in `context` naming `label`, or nil.
local function inSubmenu(context, nameKey, label)
    local parent = T.findNamed(context, context, getText(nameKey))
    local sub = parent and parent.subOption and context:getSubMenu(parent.subOption)
    return sub and T.findNamed(context, sub, label) or nil
end

-- Queues the names of every option in the pump's menu into self.names[label].
local function readMenu(self, pump, label)
    self.names = self.names or {}
    T.step(function()
        local copy = copyOf(pump)
        local context = T.need(self, copy and T.worldMenu(copy), "a world menu for " .. label)
        if not context then return end
        local names = {}
        T.findOption(context, context, function(option)
            table.insert(names, option.name)
            return false
        end)
        self.names[label] = names
        context:hideAndChildren()
    end)
end

-- Expects a line of the menu self.names[label] read to list `word` whole among the words of the
-- pump's status line.
local function expectWord(self, label, word)
    local found = false
    for _, name in ipairs(self.names and self.names[label] or {}) do
        for part in (name .. ", "):gmatch("(.-), ") do
            found = found or part == word
        end
    end
    expect(found, label .. ": the menu's status doesn't list " .. word)
end

-- How near this client's endurance comes to what the server set, a frame or two of rest later.
local ENDURANCE_SLACK = 0.01
-- The fatigue the tests' character works the pump at, and vanilla's slowest Endurance Regen
-- (EndRegen): standing still gives endurance back per frame scaled by the clock's speed, which on
-- a multiplayer server at the tests' speed outpaces the world hours it counts and so the work's
-- cost; a tired character with slow regen gets a fraction of it back (IsoPlayer.updateEndurance).
local FATIGUE = 0.9
local END_REGEN = 5

-- Queues the character's endurance set to `value`, tired and slow to rest, on both sides until
-- the test ends.
local function setEndurance(self, value)
    T.setSandbox(self, "EndRegen", END_REGEN)
    T.server(self, "pumps.endurance", { value = value, fatigue = FATIGUE })
    -- Near, not exact: standing still gives some back before this client looks.
    T.waitFor(self, function()
        return math.abs(T.player():getStats():get(CharacterStat.ENDURANCE) - value) < ENDURANCE_SLACK
    end, "this client's copy of the endurance set")
end

-- Makes the multiplayer server run Pump actions started from now every RUN_MS, and the clock run at
-- PUMP_SPEED, until the test ends.
local function quickRuns(self)
    T.setMultiplier(self, PUMP_SPEED)
    T.server(self, "pumps.runEvery", { ms = RUN_MS })
end

-- Building ----------------------------------------------------------------------------------------------

-- The build menu builds each pump from its recipe on a bare square, with its record at once, the
-- seal the build took fitted new: this client's menu reads it, the body new, nothing to draw and no
-- outlet. The seal goes in whole, leather leaving no dirty strips. Catches a recipe the build menu
-- can't build, a pump without its record or with the wrong seal, or a seal handed back used.
for _, case in ipairs({ { entity = WOODEN, name = "wooden", seal = LEATHER }, { entity = IRON, name = "iron", seal = "Base.TirePiece" } }) do
    T.test("irrigation_pumps_" .. case.name .. "_built_from_build_menu", {
        instant = true,
        run = function(self)
            local spots = T.layout(self, { { 0, 0 } }, { bare = true })
            if not spots then return end
            self.pump = T.buildFromMenu(self, "Base." .. case.entity, spots[1], SPRITES[case.entity], { case.seal })
            if not self.pump then return end
            readUntil(self, self.pump, "built", function(state) return state.record ~= nil end)
            T.count(self, "left", { case.seal, DIRTY_LEATHER, "Base.RubberHose" })
            waitForSummary(self, self.pump, function(summary) return summary.seal == case.seal end,
                "this client's summary of the built pump")
            readMenu(self, self.pump, "built")
        end,
        validate = function(self)
            local built = self.reads.built
            expect(built.entity == case.entity, "the build menu built " .. tostring(built.entity))
            local record = built.record
            if not expect(record, "the built pump has no record") then return end
            expect(record.seal == case.seal and record.sealWear == 0, "the built pump's seal is "
                .. tostring(record.seal) .. " worn " .. tostring(record.sealWear) .. ", not a new " .. case.seal)
            expect(record.condition == Pumps.BODY_CONDITION, "the built pump's condition is " .. tostring(record.condition))
            local left = self.counts.left
            for _, fullType in ipairs({ case.seal, DIRTY_LEATHER, "Base.RubberHose" }) do
                expect(left[fullType] == 0, "building left " .. tostring(left[fullType]) .. " " .. fullType)
            end
            expectWord(self, "built", getText("IGUI_EnhancedIrrigation_NoWaterToDraw"))
            expectWord(self, "built", getText("IGUI_EnhancedIrrigation_Seal", 100))
            expectWord(self, "built", getText("IGUI_EnhancedIrrigation_PumpCondition", Pumps.BODY_CONDITION))
            expectWord(self, "built", getText("IGUI_EnhancedIrrigation_NoOutlet"))
        end,
    })
end

-- Pumping ------------------------------------------------------------------------------------------------

-- What the tank by the well has room for: a few minutes of the wooden pump.
local ROOM = 24

-- Plumb Outlet from the wooden pump's menu to a lidded raised barrel beside it, a storey up, then
-- Pump: the handle worked lifts the well's water into the barrel until it is full, and the action
-- stops itself there. The water is clean, the well's own container untouched, the seal and body
-- worn by what was lifted, and the character tired on both sides; Pump is then greyed out saying
-- the tank is full. Catches water made or lost, the well's container drawn down, a pump that runs
-- on into a full tank, or work that costs nothing.
T.test("irrigation_pumps_well_fills_a_raised_barrel_until_full", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 1, 0 }, { 0, 1 } }, { bare = true })
        if not spots then return end
        self.pump = placePump(self, spots[1], WOODEN, { seal = LEATHER })
        self.well = T.placeTank(self, spots[2], "well")
        self.tank = T.placeTank(self, spots[3], "raisedLidded", BARREL_LITRES - ROOM)
        T.knowRecipes(self, { LinkJobs.RECIPE }, true)
        T.give(self, "tools", { { type = "Base.PipeWrench" }, { type = "Base.MetalPipe" } })
        useMenu(self, self.pump, "outlet", linkJob(LinkJobs.PLUMB_PUMP, Links.encode(T.at(self.tank), "iron")), true)
        readUntil(self, self.pump, "plumbed", function(state) return state.outlet end)
        T.waitFor(self, function() return Pumps.outletOf(T.at(self.pump)) ~= nil end, "this client's copy of the outlet")
        -- Full, as rest can't add to it before the work starts.
        self.endurance = 1
        setEndurance(self, self.endurance)
        read(self, self.pump, "before", { well = T.at(self.well) })
        quickRuns(self)
        -- The least this client's endurance falls to as the work goes on: standing still gives it
        -- back at the raised speed as soon as the work stops.
        T.step(function()
            self.clientEndurance = self.endurance
            T.onTick(self, function()
                self.clientEndurance = math.min(self.clientEndurance, T.player():getStats():get(CharacterStat.ENDURANCE))
            end)
        end)
        -- The worked pump holds the queue until it stops itself; one that never stops would run the
        -- test out of time.
        useMenu(self, self.pump, "pump", pumpOption, true)
        read(self, self.pump, "after", { tank = T.at(self.tank), well = T.at(self.well) })
        T.waitFor(self, function()
            local copy = T.tankCopy(self.tank)
            return copy ~= nil and copy:getFluidContainer():getAmount() > BARREL_LITRES - LITRES
        end, "this client's copy of the full barrel")
        T.useOption(self, function() return copyOf(self.pump) end, "full", pumpOption, false)
    end,
    validate = function(self)
        T.expectOffered(self, "outlet")
        T.expectOffered(self, "pump")
        local before, after = self.reads.before, self.reads.after
        expectNear("the barrel's water", after.tank.litres, BARREL_LITRES, LITRES)
        expect(not after.tank.tainted, "the well's water came out tainted")
        expect(before.wellLitres ~= nil and after.wellLitres == before.wellLitres, "the well's own container went from "
            .. tostring(before.wellLitres) .. " to " .. tostring(after.wellLitres))
        local spec = self.pump.spec
        expectNear("the seal's wear", after.record.sealWear, ROOM, LITRES)
        expectNear("the pump's condition", after.record.condition, Pumps.BODY_CONDITION - ROOM / spec.wearLitres, 0.001)
        expect(after.endurance < self.endurance, "pumping left the server's endurance at " .. after.endurance)
        expect(self.clientEndurance < self.endurance, "pumping left this client's endurance at " .. self.clientEndurance)
        T.expectRefused(self, "full", "Tooltip_EnhancedIrrigation_OutletFull")
    end,
})

-- Endurance the character is left with past the Exhausted mark: less than a minute's work.
local LAST_ENDURANCE = Pumps.ENDURANCE_PER_HOUR * MINUTE / 2

-- The handle worked by a character nearly exhausted stops once they are, with the tank far from
-- full; an exhausted character's Pump is greyed out saying so. Standing still gives endurance back
-- at once, so the menu is read with the character set well past the mark. Catches a character
-- working on past exhaustion.
T.test("irrigation_pumps_stop_when_the_character_is_exhausted", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 1, 0 }, { 0, 1 } }, { bare = true })
        if not spots then return end
        self.pump = placePump(self, spots[1], IRON, { seal = LEATHER })
        T.placeTank(self, spots[2], "well")
        self.tank = T.placeTank(self, spots[3], "raisedLidded")
        link(self, self.pump, self.tank)
        setEndurance(self, Pumps.EXHAUSTED + LAST_ENDURANCE)
        quickRuns(self)
        useMenu(self, self.pump, "pump", pumpOption, true)
        read(self, self.pump, "after", { tank = T.at(self.tank) })
        setEndurance(self, Pumps.EXHAUSTED / 2)
        T.useOption(self, function() return copyOf(self.pump) end, "tired", pumpOption, false)
    end,
    validate = function(self)
        T.expectOffered(self, "pump")
        local after = self.reads.after
        expect(after.endurance <= Pumps.EXHAUSTED, "the pump stopped with the endurance at " .. after.endurance)
        expect(after.tank.litres > 0 and after.tank.litres < BARREL_LITRES / 2, "the exhausted character lifted "
            .. after.tank.litres .. " L")
        T.expectRefused(self, "tired", "Tooltip_EnhancedIrrigation_Exhausted")
    end,
})

-- The stand-in for another player who holds a pump in these tests.
local OTHER = "EnhancedIrrigationTestOther"

-- Queues working the pump for a character whose client doesn't check that it may: the action's
-- isValid always passes, so only the authority's own check can stop it.
local function pumpUnchecked(self, pump)
    T.step(function()
        local copy = copyOf(pump)
        if not T.need(self, copy, "this client's copy of the pump") then return end
        local action = EnhancedIrrigationPumpAction:new(T.player(), copy)
        action.isValid = function() return true end
        ISTimedActionQueue.add(action)
    end)
end

-- Another player holding the pump greys this character's Pump out saying someone is at it, and the
-- authority refuses an unchecked one, lifting nothing; once their silent hold lapses, this
-- character's Pump holds it while it runs and lets go when it stops. Catches two characters at one
-- handle lifting twice the rate, or a hold that outlives its work.
T.test("irrigation_pumps_one_worker_per_pump", {
    instant = true,
    mpOnly = "a hold lapses only on a multiplayer server, and single player's own refusal of the unchecked action stops the test's queue",
    timeoutSeconds = 120,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 1, 0 }, { 0, 1 } }, { bare = true })
        if not spots then return end
        self.pump = placePump(self, spots[1], IRON, { seal = LEATHER })
        T.placeTank(self, spots[2], "well")
        self.tank = T.placeTank(self, spots[3], "raisedLidded", BARREL_LITRES - ROOM)
        link(self, self.pump, self.tank)
        T.read(self, "pumps.hold", T.at(self.pump, { as = OTHER }), "other")
        waitForSummary(self, self.pump, function(summary) return summary.heldBy == OTHER end,
            "this client's summary of the pump another player holds")
        T.goNextTo(self, self.pump.square)
        T.useOption(self, function() return copyOf(self.pump) end, "while held", pumpOption, false)
        pumpUnchecked(self, self.pump)
        read(self, self.pump, "refused", { tank = T.at(self.tank) })
        -- The other player's action has been silent too long.
        T.server(self, "pumps.lapseHold", T.at(self.pump))
        quickRuns(self)
        waitForSummary(self, self.pump, function(summary) return summary.heldBy == nil end,
            "this client's summary of the pump, freed")
        T.step(function()
            T.onTick(self, function()
                local summary = summaryOf(self.pump)
                if summary and summary.heldBy == T.player():getUsername() then
                    self.heldByMe = true
                end
            end)
        end)
        -- The worked pump holds the queue until it stops itself at the full tank.
        useMenu(self, self.pump, "freed", pumpOption, true)
        read(self, self.pump, "let go", { tank = T.at(self.tank) })
    end,
    validate = function(self)
        expect(self.reads.other.held, "the other player couldn't hold the free pump")
        T.expectRefused(self, "while held", "Tooltip_EnhancedIrrigation_PumpInUse")
        expectNear("the tank's water while another player held the pump", self.reads.refused.tank.litres,
            BARREL_LITRES - ROOM, LITRES)
        T.expectOffered(self, "freed")
        expect(self.heldByMe, "the pump wasn't held for this character while it ran")
        local after = self.reads["let go"]
        expectNear("the tank once this character's work stopped", after.tank.litres, BARREL_LITRES, LITRES)
        expect(after.summary.heldBy == nil, "the pump is still held by " .. tostring(after.summary.heldBy)
            .. " after this character's work stopped")
    end,
})

-- Sources -----------------------------------------------------------------------------------------------

-- Litres in the tainted barrel beside the iron pump: more than a minute's lift, less than an hour's.
local SOURCE_LITRES = 50

-- The iron pump beside a barrel of tainted water, its menu naming the barrel as its source, lifts a
-- minute's rate of it into a lidded tank, taint and all, the barrel down by as much; an hour more
-- lifts the rest and stops with nothing to draw. Catches the taint dropped, water made, or a dry
-- barrel still pumped.
T.test("irrigation_pumps_tainted_barrel_carries_its_taint", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 1, 0 }, { 0, 1 } }, { bare = true })
        if not spots then return end
        self.pump = placePump(self, spots[1], IRON, { seal = LEATHER })
        self.source = T.placeTank(self, spots[2], "ground", SOURCE_LITRES, true)
        self.tank = T.placeTank(self, spots[3], "lidded")
        link(self, self.pump, self.tank)
        T.goNextTo(self, self.pump.square)
        readMenu(self, self.pump, "source")
        T.step(function()
            self.sourceName = T.tankCopy(self.source):getFluidContainer():getTranslatedContainerName()
        end)
        run(self, self.pump, "ran", { MINUTE, 1 }, nil, self.tank)
    end,
    validate = function(self)
        expectWord(self, "source", self.sourceName)
        local rate = self.pump.spec.rate
        local ran = self.reads.ran
        local minute, hour = ran.steps[1], ran.steps[2]
        expectNear("the tank after a minute", minute.tank.litres, rate, LITRES)
        expect(minute.tank.tainted, "the barrel's tainted water came out clean")
        expectNear("the barrel after a minute", minute.source.litres, SOURCE_LITRES - rate, LITRES)
        expectNear("the tank after the barrel ran dry", hour.tank.litres, SOURCE_LITRES, LITRES)
        expect(hour.source and hour.source.dry, "the emptied barrel isn't the pump's dry source")
        expect(hour.stopped == "Tooltip_EnhancedIrrigation_NoWaterToDraw", "the pump stopped for "
            .. tostring(hour.stopped))
    end,
})

-- A square of river water two tiles from the iron pump, in its hose's reach, with no well or tank
-- beside it but its outlet's: the menu names the river, and a minute's work lifts the pump's rate,
-- tainted, into the tank. Catches a hose that can't find the river, or river water that comes out
-- clean.
T.test("irrigation_pumps_river_intake_gives_tainted_water", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 1, 0 }, { -2, 0 } }, { bare = true })
        if not spots then return end
        self.river = spots[3]
        T.read(self, "pumps.water", T.at(self.river), "water")
        T.waitFor(self, function()
            return getSquare(self.river.x, self.river.y, self.river.z):getProperties():has(IsoFlagType.water)
        end, "this client's copy of the river square")
        self.pump = placePump(self, spots[1], IRON, { seal = LEATHER })
        self.tank = T.placeTank(self, spots[2], "lidded")
        link(self, self.pump, self.tank)
        T.goNextTo(self, self.pump.square)
        readMenu(self, self.pump, "river")
        run(self, self.pump, "ran", { MINUTE }, nil, self.tank)
    end,
    validate = function(self)
        expect(self.reads.water.water, "the server's square isn't water")
        expectWord(self, "river", getText("IGUI_EnhancedIrrigation_SourceRiver"))
        local step = self.reads.ran.steps[1]
        local intake = step.record.intake
        expect(intake and intake.x == self.river.x and intake.y == self.river.y, "the hose drinks at "
            .. (intake and intake.x .. "," .. intake.y or "nothing"))
        expectNear("the tank after a minute", step.tank.litres, self.pump.spec.rate, LITRES)
        expect(step.tank.tainted, "the river's water came out clean")
    end,
})

-- Lift -------------------------------------------------------------------------------------------------

-- A raised barrel on the storey above, two storeys up: the wooden pump's Plumb Outlet greys it out
-- saying how high it lifts, and the server refuses it too; the iron pump's plumbs it. Catches water
-- lifted past a pump's reach, or a pump that can't fill what it should.
T.test("irrigation_pumps_lift_refuses_a_tank_too_high_for_wood", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 2, 0 }, { 1, 1 } }, { bare = true })
        if not spots then return end
        self.wooden = placePump(self, spots[1], WOODEN, { seal = LEATHER })
        self.iron = placePump(self, spots[2], IRON, { seal = LEATHER })
        self.tank = T.placeTank(self, spots[3], "raisedAbove")
        T.knowRecipes(self, { LinkJobs.RECIPE }, true)
        T.give(self, "tools", { { type = "Base.PipeWrench" }, { type = "Base.MetalPipe", count = 2 } })
        useMenu(self, self.wooden, "wooden", function(context)
            return inSubmenu(context, "ContextMenu_EnhancedIrrigation_PlumbOutlet",
                LinkMenu.tankLabel(T.at(self.wooden), T.at(self.tank)))
        end, false)
        T.read(self, "tanks.perform", T.at(self.wooden, { feature = "link", job = LinkJobs.PLUMB_PUMP,
            with = Links.encode(T.at(self.tank), "iron") }), "forced")
        useMenu(self, self.iron, "iron", linkJob(LinkJobs.PLUMB_PUMP, Links.encode(T.at(self.tank), "iron")), true)
        readUntil(self, self.iron, "plumbed", function(state) return state.outlet end)
    end,
    validate = function(self)
        T.expectRefused(self, "wooden", Pumps.LIFT_KEYS[Pumps.UNITS[WOODEN].lift])
        local forced = self.reads.forced
        expect(forced.done == false and forced.links == 0, "the server plumbed the wooden pump two storeys up")
        T.expectOffered(self, "iron")
        expect(self.reads.plumbed.outlet, "the iron pump's outlet isn't plumbed")
    end,
})

-- Lines ------------------------------------------------------------------------------------------------

-- The option of `context` that plumbs the pump's outlet to a tile of `tiles` with iron pipe, or nil.
local function plumbToLine(context, tiles)
    return T.findOption(context, context, function(option)
        local at, kind = Links.decode(option.param4)
        if not (option.onSelect == EnhancedIrrigationAction.queue and option.param2 == LinkJobs.PLUMB_PUMP and kind == "iron") then
            return false
        end
        for _, tile in ipairs(tiles) do
            if EnhancedIrrigation.sameSquare(at, tile) then
                return true
            end
        end
        return false
    end)
end

-- Plumb Outlet from the wooden pump's menu lists the garden lines in its reach beside its tanks: a
-- tapped line greyed out saying it has a tap, which the server refuses too, and an untapped one,
-- which it plumbs with iron pipe. The pump's menu then says it feeds a line, Unplumb names the line,
-- and the line's Fit Tap is greyed out saying a pump feeds it. Catches a line no pump can feed, or
-- one fed by a tap and a pump both.
T.test("irrigation_pumps_plumb_outlet_to_a_line", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 1, 0 } }, { bare = true })
        if not spots then return end
        -- Two lines a square apart: an untapped one of two tiles, and a tapped one.
        local rows = T.row(self, 4)
        if not rows then return end
        local untapped, tapped = { rows[1][1], rows[1][2] }, rows[1][4]
        self.untapped = untapped
        tapped.fields = T.tapped()
        T.placeLine(self, { untapped[1], untapped[2], tapped }, "iron")
        self.pump = placePump(self, spots[1], WOODEN, { seal = LEATHER })
        T.placeTank(self, spots[2], "well")
        T.knowRecipes(self, { LinkJobs.RECIPE }, true)
        T.give(self, "tools", { { type = "Base.PipeWrench" }, { type = "Base.MetalPipe", count = 4 } })
        useMenu(self, self.pump, "tapped", function(context)
            return inSubmenu(context, "ContextMenu_EnhancedIrrigation_PlumbOutlet",
                LinkMenu.lineLabel(T.at(self.pump), T.at(tapped)))
        end, false)
        T.read(self, "tanks.perform", T.at(self.pump, { feature = "link", job = LinkJobs.PLUMB_PUMP,
            with = Links.encode(T.at(tapped), "iron") }), "forced")
        useMenu(self, self.pump, "untapped", function(context) return plumbToLine(context, untapped) end, true)
        readUntil(self, self.pump, "plumbed", function(state) return state.outlet end)
        T.waitFor(self, function() return Pumps.outletOf(T.at(self.pump)) ~= nil end, "this client's copy of the outlet")
        readMenu(self, self.pump, "plumbed")
        T.step(function()
            local b = Pumps.outletEnd(T.at(self.pump))
            self.unplumbLabel = LinkMenu.linkLabel(T.at(self.pump), b)
        end)
        T.useOption(self, function() return copyOf(self.pump) end, "unplumb", function(context)
            return T.findNamed(context, context, self.unplumbLabel)
        end, false)
        T.goNextTo(self, untapped[2].square)
        T.useOption(self, function() return T.lineObject(untapped[2]) end, "fit tap", function(context)
            return T.jobOption(context, "line", LineJobs.TAP)
        end, false)
    end,
    validate = function(self)
        T.expectRefused(self, "tapped", "Tooltip_EnhancedIrrigation_LineHasTap")
        local forced = self.reads.forced
        expect(forced.done == false and forced.links == 0, "the server plumbed the pump to a tapped line")
        T.expectOffered(self, "untapped")
        expectWord(self, "plumbed", getText("IGUI_EnhancedIrrigation_OutletToLine"))
        T.expectOffered(self, "unplumb")
        T.expectRefused(self, "fit tap", "Tooltip_EnhancedIrrigation_LinePumped")
    end,
})

-- Half an hour's work, the time the pumped-line tests run their pumps for.
local HALF_HOUR = 0.5

-- Queues the wooden pump at `spots[1]` over a well at `spots[2]`, its outlet plumbed to the first of
-- two holed line tiles in a row with dry crops on them. Returns the pump and the tiles.
local function pumpedLine(self, spots, fields)
    local rows = T.row(self, 2)
    if not rows then return nil end
    local tiles = rows[1]
    for _, tile in ipairs(tiles) do
        tile.fields = { holed = true }
    end
    T.placeLine(self, tiles, "iron")
    T.plant(self, tiles[1], 0)
    T.plant(self, tiles[2], 0)
    local pump = placePump(self, spots[1], WOODEN)
    T.placeTank(self, spots[2], "well")
    link(self, pump, tiles[1], fields)
    return pump, tiles
end

-- Half an hour's work at a wooden pump feeding a line of two holed tiles pushes each hole's water
-- out at the pump's push, filling each crop by that, and wears the seal and the body by only what
-- the holes took. Worked from its menu, the line shows as running on this client while the
-- character works and stops once they are exhausted. Catches a pumped line run at a tank's head, a
-- pump worn by its whole rate, or a line that runs on unworked.
T.test("irrigation_pumps_hand_pump_drives_its_line", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 1, 0 } }, { bare = true })
        if not spots then return end
        self.pump, self.tiles = pumpedLine(self, spots, { seal = LEATHER })
        if not self.pump then return end
        T.read(self, "sprinklers.pump", T.at(self.pump, { hours = { HALF_HOUR }, squares = T.tiles(self.tiles) }), "half")
        setEndurance(self, Pumps.EXHAUSTED + LAST_ENDURANCE)
        quickRuns(self)
        T.step(function()
            T.onTick(self, function()
                local summary = T.lineSummary(self.tiles[2])
                self.sawRunning = self.sawRunning or (summary and summary.running)
            end)
        end)
        -- The worked pump holds the queue until the character is exhausted.
        useMenu(self, self.pump, "pump", pumpOption, true)
        T.waitForLines(self, self.tiles, "this client's copy of the line, stopped", function(summary)
            return not summary.running
        end)
    end,
    validate = function(self)
        local half = self.reads.half
        local push = Pumps.UNITS[WOODEN].push
        local each = Lines.HOLE_RATE * push * HALF_HOUR
        for i = 1, 2 do
            expectNear("crop " .. i .. "'s water", half.after.squares[i].water - half.before.squares[i].water,
                each * Lines.POINTS_PER_LITRE, 0.05)
        end
        local before, after = half.before.pump, half.after.pump
        expectNear("the seal's wear", after.sealWear - before.sealWear, 2 * each, LITRES)
        expectNear("the pump's wear", before.condition - after.condition, 2 * each / Pumps.UNITS[WOODEN].wearLitres, 0.0001)
        T.expectOffered(self, "pump")
        expect(self.sawRunning, "this client never saw the line run while the pump was worked")
    end,
})

-- Wear ---------------------------------------------------------------------------------------------------

-- Litres the worn plunger cup has left: less than a minute's lift, and not a whole float, so what
-- the well hands over can fall a hair short of it.
local SEAL_LEFT = 5.1

-- A plunger cup with a few litres left lifts those and no more, and the pump stops: its menu says
-- the seal is worn out and greys Pump out. Replace Seal with Leather Strips, then with a Plunger,
-- each from the submenu of the seals carried and a screwdriver, fits each new and uses it up whole:
-- no dirty strips, no plunger left. Catches a seal that lifts past its litres, a worn one that
-- still lifts, or a seal handed back or left behind used.
T.test("irrigation_pumps_seal_wears_out_and_is_replaced", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 1, 0 }, { 0, 1 } }, { bare = true })
        if not spots then return end
        self.pump = placePump(self, spots[1], IRON)
        T.placeTank(self, spots[2], "well")
        self.tank = T.placeTank(self, spots[3], "lidded")
        link(self, self.pump, self.tank, { seal = PLUNGER, sealWear = Pumps.sealLitres(PLUNGER) - SEAL_LEFT })
        run(self, self.pump, "worn", { MINUTE }, nil, self.tank)
        waitForSummary(self, self.pump, function(summary) return summary.sealWorn end, "this client's summary of the worn seal")
        T.goNextTo(self, self.pump.square)
        readMenu(self, self.pump, "worn")
        T.useOption(self, function() return copyOf(self.pump) end, "pump", pumpOption, false)
        T.give(self, "seals", { { type = "Base.Screwdriver" }, { type = LEATHER }, { type = PLUNGER } })
        T.step(function() self.leather, self.plunger = self.items.seals[2], self.items.seals[3] end)
        useMenu(self, self.pump, "leather", function(context)
            return T.jobOption(context, "pump", PumpJobs.REPLACE_SEAL, self.leather)
        end, true)
        readUntil(self, self.pump, "leathered", function(state) return state.record.seal == LEATHER end)
        useMenu(self, self.pump, "plunger", function(context)
            return T.jobOption(context, "pump", PumpJobs.REPLACE_SEAL, self.plunger)
        end, true)
        readUntil(self, self.pump, "replaced", function(state) return state.record.seal == PLUNGER end)
        T.count(self, "left", { LEATHER, DIRTY_LEATHER, PLUNGER, "Base.Screwdriver" })
        waitForSummary(self, self.pump, function(summary) return summary.seal == PLUNGER and not summary.sealWorn end,
            "this client's summary of the new seal")
        readMenu(self, self.pump, "new")
    end,
    validate = function(self)
        local worn = self.reads.worn.steps[1]
        expectNear("the tank after the seal's last litres", worn.tank.litres, SEAL_LEFT, LITRES)
        expect(worn.stopped == "Tooltip_EnhancedIrrigation_SealWornOut", "the pump stopped for " .. tostring(worn.stopped))
        expectWord(self, "worn", getText("IGUI_EnhancedIrrigation_SealWornOut"))
        T.expectRefused(self, "pump", "Tooltip_EnhancedIrrigation_SealWornOut")
        T.expectOffered(self, "leather")
        T.expectOffered(self, "plunger")
        local leathered, replaced = self.reads.leathered.record, self.reads.replaced.record
        expect(leathered.seal == LEATHER and leathered.sealWear == 0, "the leather went in as "
            .. tostring(leathered.seal) .. " worn " .. tostring(leathered.sealWear))
        expect(replaced.seal == PLUNGER and replaced.sealWear == 0, "the plunger went in as "
            .. tostring(replaced.seal) .. " worn " .. tostring(replaced.sealWear))
        local left = self.counts.left
        for _, fullType in ipairs({ LEATHER, DIRTY_LEATHER, PLUNGER }) do
            expect(left[fullType] == 0, "Replace Seal left " .. tostring(left[fullType]) .. " " .. fullType)
        end
        expect(left["Base.Screwdriver"] == 1, "Replace Seal took the screwdriver")
        expectWord(self, "new", getText("IGUI_EnhancedIrrigation_Seal", 100))
    end,
})

-- The body's condition the worn wooden pump has left: a few litres of its wearLitres of lift, not a
-- whole float, so what the well hands over can fall a hair short of it.
local BODY_LEFT = 0.017

-- A wooden pump with its last few litres of condition left lifts them and is worn out: its menu says
-- so and greys Pump out. A sledgehammer smashes it through vanilla's Destroy cursor and action, and
-- its record goes with it. Catches a pump that never wears out, one that works on worn out, or a
-- record outliving its pump.
T.test("irrigation_pumps_worn_out_pump_smashed_with_its_record", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 1, 0 }, { 0, 1 } }, { bare = true })
        if not spots then return end
        self.pump = placePump(self, spots[1], WOODEN)
        T.placeTank(self, spots[2], "well")
        self.tank = T.placeTank(self, spots[3], "raisedLidded")
        link(self, self.pump, self.tank, { seal = LEATHER, condition = BODY_LEFT })
        run(self, self.pump, "worn", { 1 }, nil, self.tank)
        waitForSummary(self, self.pump, function(summary) return summary.wornOut end, "this client's summary of the worn pump")
        T.goNextTo(self, self.pump.square)
        readMenu(self, self.pump, "worn")
        T.useOption(self, function() return copyOf(self.pump) end, "pump", pumpOption, false)
        T.give(self, "sledge", { { type = "Base.Sledgehammer" } })
        -- The cursor lists what it can smash on the square it hovers, once the character sees it.
        T.waitFor(self, function()
            self.cursor = self.cursor or ISDestroyCursor:new(T.player(), false, self.items.sledge[1])
            self.cursor:isValid(self.pump.square)
            for i, object in ipairs(self.cursor:getObjectList()) do
                if Pumps.isPump(object) then
                    self.cursor.objectIndex = i
                    return true
                end
            end
            return false
        end, "the Destroy cursor offering the pump")
        T.step(function() self.cursor:create(self.pump.x, self.pump.y, self.pump.z) end)
        T.waitFor(self, function() return copyOf(self.pump) == nil end, "this client to lose the smashed pump")
        read(self, self.pump, "smashed")
    end,
    validate = function(self)
        local worn = self.reads.worn.steps[1]
        expectNear("the tank after the body's last litres", worn.tank.litres, BODY_LEFT * self.pump.spec.wearLitres, LITRES)
        expect(worn.stopped == "Tooltip_EnhancedIrrigation_PumpWornOut", "the pump stopped for " .. tostring(worn.stopped))
        expectWord(self, "worn", getText("IGUI_EnhancedIrrigation_PumpWornOut"))
        T.expectRefused(self, "pump", "Tooltip_EnhancedIrrigation_PumpWornOut")
        local smashed = self.reads.smashed
        expect(not smashed.found and smashed.record == nil, "the smashed pump or its record is still there")
    end,
})
