require "EnhancedIrrigation/Debug/EnhancedIrrigationTestLibLines"
require "EnhancedIrrigation/Sprites"
require "EnhancedIrrigation/Lines/Lines"
require "EnhancedIrrigation/Lines/LineJobs"
require "EnhancedIrrigation/Valves"
require "EnhancedIrrigation/UI/LineMenu"
require "EnhancedIrrigation/UI/ValveUI"

-- A valve's hours are run on the server by winding its clock back (valves.age), so the clock
-- doesn't decide the sums.

local T = EnhancedIrrigationTest
local expect, expectNear = T.expect, T.expectNear
local Sprites, Lines, LineJobs = EnhancedIrrigation.Sprites, EnhancedIrrigation.Lines, EnhancedIrrigation.LineJobs
local Valves, LineMenu, ValveUI = EnhancedIrrigation.Valves, EnhancedIrrigation.LineMenu, EnhancedIrrigation.ValveUI

-- A holed tile's plant points a minute from a tank one storey up (Lines.HOLE_RATE, push 1).
local POINTS_A_MINUTE = Lines.HOLE_RATE * Lines.POINTS_PER_LITRE / 60

-- A tapped line ------------------------------------------------------------------------------------

--- Queues a raised barrel holding T.TANK_LITRES, the holed tap tile beside it and a second holed
--- tile past that, a dry crop on each (T.holedLine), and the character beside the tap. Returns
--- { tap, tank, crops }, or nil when there is no room. `opts` as T.row's.
local function tappedLine(self, opts)
    local rows = T.row(self, 3, opts)
    if not rows then return nil end
    local beside, tap, far = rows[1][1], rows[1][2], rows[1][3]
    local tank = T.placeTank(self, beside, "raised", T.TANK_LITRES)
    tap.fields = T.tapped({ holed = true })
    T.holedLine(self, { tap, far }, "plastic")
    T.goNextTo(self, tap.square)
    return { tap = tap, tank = tank, crops = { tap, far } }
end

--- Queues putting the valve `item` on the line's tap as Fit Valve leaves it.
local function placeValve(self, line, item)
    T.server(self, "valves.place", T.at(line.tap, { item = item }))
    T.waitForLines(self, { line.tap }, "this client's copy of the tap with its valve", function(summary)
        return summary.valve ~= nil and summary.valve.item == item
    end)
end

--- Queues opening the valve's panel from the tap's menu (Wind Valve or Set Timer), which walks the
--- character over and opens it there, then `set(panel)` and its button, as a player sets it and
--- clicks.
local function setFromPanel(self, line, label, set)
    T.useOption(self, function() return T.lineObject(line.tap) end, label, T.running(LineMenu.openValve), true)
    T.waitFor(self, function() return ValveUI.instances[T.player():getPlayerNum()] ~= nil end, "the valve's panel")
    T.step(function()
        local panel = ValveUI.instances[T.player():getPlayerNum()]
        set(panel)
        panel:update()
        self.panelBlocker = panel.blocker
        panel:onClick(panel.ok)
    end)
end

--- Queues the valve's clock wound back `hours` and its pass run on the server, into self.reads[label].
local function age(self, line, hours, label)
    T.read(self, "valves.age", T.at(line.tap, { hours = hours, tiles = T.tiles(line.crops), tank = T.at(line.tank) }), label)
end

--- Expects the crops of the reply `read` (valves.age) watered for `minutes` from the tap, and the
--- tank down by what they took.
local function expectWatered(read, minutes, what)
    for i, water in ipairs(read.crops) do
        expectNear(what .. ": crop " .. i .. "'s water", water, POINTS_A_MINUTE * minutes, T.CROP_POINTS)
    end
    expectNear(what .. ": the tank's water", read.litres,
        T.TANK_LITRES - #read.crops * Lines.HOLE_RATE * minutes / 60, T.FINE_LITRES)
end

-- Fitting and taking off ---------------------------------------------------------------------------

-- At a tap, Fit Valve is greyed out saying it needs a valve until one is carried; then it fits the
-- Wind-up Valve carried, which shows on the tap and is gone from the inventory, and Take Off Valve
-- gives it back. Catches a valve that never reaches the record, one fitted twice from one item, or
-- one lost taking it off.
T.test("irrigation_valves_fit_and_take_off", {
    instant = true,
    run = function(self)
        local line = tappedLine(self)
        if not line then return end
        T.give(self, "tools", { { type = "Base.PipeWrench" } })
        T.useLineJob(self, line.tap, LineJobs.FIT_VALVE, "none", false)
        T.give(self, "valve", { { type = Valves.WIND_UP } })
        T.useLineJob(self, line.tap, LineJobs.FIT_VALVE, "fit", true)
        T.readUntil(self, "valves.read", T.at(line.tap), "fitted", function(reply) return reply.valve.item ~= nil end)
        T.readLines(self, { line.tap }, "shown")
        T.readCarried(self, { Valves.WIND_UP }, nil, "carriedFitted")
        T.useLineJob(self, line.tap, LineJobs.TAKE_OFF_VALVE, "takeOff", true)
        T.readUntil(self, "valves.read", T.at(line.tap), "off", function(reply) return reply.valve.item == nil end)
        T.readCarried(self, { Valves.WIND_UP }, nil, "carriedOff")
    end,
    validate = function(self)
        T.expectOptionRefused(self, "none", "Tooltip_EnhancedIrrigation_NoValve")
        T.expectOffered(self, "fit")
        expect(self.reads.fitted.valve.item == Valves.WIND_UP, "the tap's valve is " .. tostring(self.reads.fitted.valve.item))
        local overlays = self.reads.shown.tiles[1].overlays or {}
        expect(T.hasOverlay(overlays, Sprites.TAP_VALVES[Valves.WIND_UP]), "the tap shows no valve: "
            .. table.concat(overlays, ", "))
        expect(#T.carriedItems(self, Valves.WIND_UP, "carriedFitted") == 0, "the fitted valve is still carried")
        T.expectOffered(self, "takeOff")
        expect(self.reads.off.valve.item == nil, "the tap still has its " .. tostring(self.reads.off.valve.item) .. " after Take Off Valve")
        local off = #T.carriedItems(self, Valves.WIND_UP, "carriedOff")
        expect(off == 1, "Take Off Valve gave back " .. off .. " valves")
    end,
})

-- Take Up Pipe on a tap with a valve gives the valve back with the pipe. Catches a valve lost with
-- its tile.
T.test("irrigation_valves_take_up_gives_the_valve_back", {
    instant = true,
    run = function(self)
        local line = tappedLine(self)
        if not line then return end
        placeValve(self, line, Valves.TIMER)
        T.useLineJob(self, line.tap, LineJobs.TAKE_UP, "takeUp", true)
        T.waitFor(self, function() return T.lineObject(line.tap) == nil end, "this client to see the tap taken up")
        T.readCarried(self, { Valves.TIMER })
    end,
    validate = function(self)
        T.expectOffered(self, "takeUp")
        local back = #T.carriedItems(self, Valves.TIMER)
        expect(back == 1, "Take Up Pipe gave back " .. back .. " Timer Valves")
    end,
})

-- The Wind-up Valve ---------------------------------------------------------------------------------

-- Wound for 10 minutes from its panel, the Wind-up Valve runs the line, which says so, and Water
-- from Tank is refused meanwhile; its hours gone by, every holed tile got 10 minutes of the tap's
-- water, the tank gave as much, and the valve has shut and run down. Catches a valve that runs
-- longer or shorter than wound, one that never shuts, or a tap two can run at once.
T.test("irrigation_valves_wind_up_runs_its_minutes_and_shuts", {
    instant = true,
    run = function(self)
        local line = tappedLine(self)
        if not line then return end
        placeValve(self, line, Valves.WIND_UP)
        setFromPanel(self, line, "wind", function(panel) panel.knob:setKnobPosition(10) end)
        T.readUntil(self, "valves.read", T.at(line.tap), "wound", function(reply) return reply.valve.untilHour ~= nil end)
        T.waitForLines(self, { line.tap }, "this client's copy of the tap running", function(summary)
            return summary.valveOpen
        end)
        T.useWater(self, line.tap, "water", false)
        age(self, line, 1, "ran")
        T.waitForLines(self, { line.tap }, "this client's copy of the tap shut", function(summary)
            return not summary.valveOpen and summary.valve and summary.valve.untilHour == nil
        end)
    end,
    validate = function(self)
        expect(self.panelBlocker == nil, "the panel refused winding: " .. tostring(self.panelBlocker))
        local wound = self.reads.wound.valve
        expectNear("the minutes wound", (wound.untilHour - wound.now) * 60, 10, 1)
        T.expectOptionRefused(self, "water", "Tooltip_EnhancedIrrigation_ValveRunning")
        expectWatered(self.reads.ran, 10, "wound for 10 minutes")
        expect(not self.reads.ran.valve.open, "the run-down valve still runs the line")
    end,
})

-- Timers --------------------------------------------------------------------------------------------

-- The opening hour an hour before the hour now, so a window set to it has opened and shut.
local function anHourAgo()
    return (math.floor(getGameTime():getTimeOfDay()) - 1) % 24
end

--- Queues the timer `item` fitted to the tap of an indoor line, with the grid on or off as
--- `powered`, set from its panel to open an hour before the hour now for 30 minutes, then an hour
--- and a half gone by, into self.reads.ran. The span starts half an hour before the window, so a
--- window an hour late is open now and one an hour early falls before the span.
local function runTimer(self, item, powered)
    T.setGrid(self, powered)
    local line = tappedLine(self, { indoors = true })
    if not line then return end
    placeValve(self, line, item)
    self.start = anHourAgo()
    setFromPanel(self, line, "set", function(panel)
        -- Stepped up to it, as a player clicks the hour's ^.
        for _ = 1, (self.start - panel.hour) % 24 do
            panel:onClick(panel.hourUp)
        end
        panel.knob:setKnobPosition(30)
    end)
    T.readUntil(self, "valves.read", T.at(line.tap), "set", function(reply) return reply.valve.minutes == 30 end)
    age(self, line, 1.5, "ran")
end

--- Expects the panel's setting to have reached the valve.
local function expectSet(self)
    expect(self.panelBlocker == nil, "the panel refused the setting: " .. tostring(self.panelBlocker))
    local set = self.reads.set.valve
    expect(set.start == self.start, "the timer starts at " .. tostring(set.start) .. ", not " .. self.start)
    expect(set.minutes == 30, "the timer runs " .. tostring(set.minutes) .. " minutes")
end

for _, case in ipairs({ { name = "timer", item = Valves.TIMER }, { name = "sprinkler_timer", item = Valves.SPRINKLER_TIMER } }) do
    -- Set from its panel on a tap the grid powers indoors: every holed tile got the window's 30
    -- minutes of water and the tank gave as much, and it isn't open now. Catches a window at the
    -- wrong hour or of the wrong length, a timer that runs outside it, or an item that isn't a timer.
    T.test("irrigation_valves_" .. case.name .. "_opens_in_its_window", {
        instant = true,
        run = function(self) runTimer(self, case.item, true) end,
        validate = function(self)
            expectSet(self)
            expectWatered(self.reads.ran, 30, "half an hour's window")
            expect(not self.reads.ran.valve.open, "the timer is open outside its window")
        end,
    })

    -- The same with the grid off and no generator: its window goes by and no water runs. Catches a
    -- timer that needs no power.
    T.test("irrigation_valves_" .. case.name .. "_needs_power", {
        instant = true,
        run = function(self) runTimer(self, case.item, false) end,
        validate = function(self)
            expectSet(self)
            expectWatered(self.reads.ran, 0, "an unpowered window")
        end,
    })
end
