require "EnhancedIrrigation/Debug/EnhancedIrrigationTestLib"
require "EnhancedIrrigation/Sprites"
require "EnhancedIrrigation/Treatment/Treatment"

-- Development only, not published. The treatment unit helpers of the mod's test library
-- (EnhancedIrrigationTestLib): the sand filters, the Filter Crock and the Boilers.

local T = EnhancedIrrigationTest

local Sprites = EnhancedIrrigation.Sprites
local Treatment = EnhancedIrrigation.Treatment

-- The tile of each treatment unit entity: the sand filters, the Filter Crock and the Boilers.
T.TREATMENT_SPRITES = { EnhancedIrrigation_BarrelFilter = Sprites.BARREL_FILTER,
    EnhancedIrrigation_BrickFilter = Sprites.BRICK_FILTER, EnhancedIrrigation_FilterCrock = Sprites.FILTER_CROCK,
    EnhancedIrrigation_BoilerStone = Sprites.BOILER_STONE, EnhancedIrrigation_BoilerWelded = Sprites.BOILER_WELDED }

--- Queues placing the unit `entity` at `handle` (up `opts.up` storeys), with `opts.fields` on its
--- record, and a wait for this client's copy and its summary. Returns its handle, with `spec`.
function T.placeUnit(self, handle, entity, opts)
    opts = opts or {}
    local up = opts.up or 0
    local unit = { x = handle.x, y = handle.y, z = handle.z + up, sprite = T.TREATMENT_SPRITES[entity],
        spec = Treatment.ENTITIES[entity], square = up == 0 and handle.square or nil }
    T.server(self, "treatment.place", T.at(unit, { sprite = unit.sprite, fields = opts.fields }))
    T.waitFor(self, function()
        unit.square = getSquare(unit.x, unit.y, unit.z)
        local copy = T.copyOf(unit)
        return copy ~= nil and Treatment.summaryOf(copy) ~= nil
    end, "this client's copy of the " .. entity)
    return unit
end

--- Queues building the unit `entity` from the build menu (T.buildTile, each input the first of
--- `prefer` it takes), a read of its state once its record is made into self.reads.built, a wait
--- for this client's summary, and the names of its menu into self.names.built. Returns its handle,
--- with `spec`, or nil.
function T.buildUnit(self, entity, prefer)
    local unit = T.buildTile(self, "Base." .. entity, T.TREATMENT_SPRITES[entity], prefer)
    if not unit then return nil end
    unit.spec = Treatment.ENTITIES[entity]
    T.readUnitUntil(self, unit, "built", function(state) return state.record ~= nil end)
    T.waitFor(self, function() return Treatment.summaryOf(T.copyOf(unit)) ~= nil end,
        "this client's summary of the built " .. entity)
    T.readMenu(self, function() return T.copyOf(unit) end, "built")
    return unit
end

--- Expects what T.buildUnit read: the unit `entity`, with its record, nothing in its head and its
--- basin empty and locked.
function T.expectBuiltUnit(self, entity)
    local built = self.reads.built
    T.expect(built.entity == entity, "the build menu built " .. tostring(built.entity))
    T.expect(built.record and built.record.head == 0, "the built " .. entity .. " has no record, or water in its head")
    T.expect(built.basin and built.basin.litres == 0 and built.basin.locked,
        "the built " .. entity .. "'s basin isn't empty and locked")
end

function T.readUnitUntil(self, unit, label, done, tank)
    T.readUntil(self, "treatment.state", T.at(unit, { tank = tank and T.at(tank) }), label, done)
end

-- Queues `fields` set on the unit's record and a run of each of `hours`, with the tank's state if
-- given, into self.reads[label] ({ before, steps }).
function T.runUnit(self, unit, label, hours, fields, tank)
    T.read(self, "treatment.run", T.at(unit, { hours = hours, fields = fields, tank = tank and T.at(tank) }), label)
end

-- Queues a wait until this client's copy of the unit holds `litres` in its basin, if given, and its
-- summary satisfies `holds(summary)`, if given.
function T.waitForUnitCopy(self, unit, litres, holds, what)
    T.waitFor(self, function()
        local copy = T.copyOf(unit)
        local summary = copy and Treatment.summaryOf(copy)
        return summary ~= nil and (not litres or math.abs(copy:getFluidContainer():getAmount() - litres) < T.LITRES)
            and (not holds or holds(summary))
    end, what)
end

-- Queues a wait until this client's summary of the unit agrees on `key` with the server's in
-- self.reads[label] (a state, an update's `after` or a run's last step), so a menu read after it
-- shows what the server answered.
function T.waitForUnitServer(self, unit, label, key)
    T.waitFor(self, function()
        local read = self.reads and self.reads[label]
        local state = read and (read.after or read.steps and read.steps[#read.steps] or read)
        local summary = Treatment.summaryOf(T.copyOf(unit))
        return state ~= nil and state.summary ~= nil and summary ~= nil and summary[key] == state.summary[key]
    end, "this client's summary of " .. label)
end

-- Queues the boiler's fire set on the authority (treatment.fire: `fuel` minutes if given, lit or
-- not) and a wait for this client's copy to show it, as vanilla's own fire actions leave it.
function T.setFire(self, unit, lit, fuel)
    T.server(self, "treatment.fire", T.at(unit, { lit = lit, fuel = fuel }))
    T.waitFor(self, function()
        local copy = T.copyOf(unit)
        return copy ~= nil and copy:isLit() == lit
    end, "this client's copy of the boiler " .. (lit and "lit" or "out"))
end

-- Fuel for the tests' fires, in minutes: longer than any test runs one.
T.FUEL = 600

-- Queues `litres` of raw water, tainted if `tainted`, set in the unit's head and treated into its
-- basin by the hours its rate takes (self.reads.filled), a boiler lit for them and put out after,
-- then a wait for this client's copy of the basin. A sand filter's film is grown for clean water
-- and new for tainted, so its basin holds the water as it was.
function T.fillBasin(self, unit, litres, tainted)
    local spec = unit.spec
    local fields, hours = { head = litres, headTainted = tainted == true }, litres / spec.rate
    if spec.kind == "sand" then
        fields.ripeHours = tainted and 0 or Treatment.RIPE_HOURS
    elseif spec.kind == "boiler" then
        -- A cold drum passes nothing until it is hot.
        hours = hours + Treatment.HOT_HOURS
        T.setFire(self, unit, true, T.FUEL)
    end
    T.runUnit(self, unit, "filled", { hours }, fields)
    if spec.kind == "boiler" then
        T.setFire(self, unit, false)
    end
    T.waitForUnitCopy(self, unit, litres, nil, "this client's copy of the filled basin")
end

function T.expectBasin(who, state, litres, tainted)
    if not T.expect(state and state.basin, who .. ": no unit") then return end
    T.expectNear(who .. ": the basin's water", state.basin.litres, litres, T.LITRES)
    if litres > 0 then
        T.expect(state.basin.tainted == tainted, who .. ": the basin's water is " .. (state.basin.tainted and "tainted" or "clean"))
    end
end

-- This client's copy's basin as the state T.expectBasin reads.
function T.clientBasin(unit)
    local copy = T.copyOf(unit)
    local basin = copy and copy:getFluidContainer()
    return basin and { basin = { litres = basin:getAmount(), tainted = basin:isTainted() } } or nil
end

-- The basin offers vanilla's Drink, Fill and Empty, but no pour into it, though the character
-- carries water; a bucket filled from it holds its water as it was. A Barrel Filter's basin holds
-- tainted water, and Drink warns of it; a crock's or a boiler's, clean, and Drink doesn't; the
-- boiler is a vanilla fireplace, whose fire menu stands beside the fluid menu. Catches a basin
-- vanilla can't reach, one it can pour into past the sand, the clay or the fire, or a taint lost or
-- made up. The crock's bucket holds no more than the one carried, so that one starts part full: a
-- Fill that empties its source ends in an invalid action on a multiplayer client, which clears the
-- queue.
--
-- `case`: the test's `name`, the unit's `entity`, the `litres` its basin is filled with and whether
-- they are `tainted`, and the litres already `inBucket`.
function T.vanillaBasinTest(case)
    T.test(case.name, {
        instant = true,
        run = function(self)
            local spots = T.layout(self, { { 0, 0 } }, { bare = true })
            if not spots then return end
            self.unit = T.placeUnit(self, spots[1], case.entity)
            T.fillBasin(self, self.unit, case.litres, case.tainted)
            T.give(self, "items", { { type = "Base.Bucket" }, { type = "Base.WaterBottle" } })
            -- Full, so vanilla's Fill lists only the bucket.
            T.fillCarried(self, "Base.WaterBottle", "Water", 10)
            if case.inBucket > 0 then
                T.fillCarried(self, "Base.Bucket", "Water", case.inBucket)
            end
            T.goNextTo(self, spots[1].square)
            T.step(function()
                local copy = T.copyOf(self.unit)
                local context = T.need(self, copy and T.worldMenu(copy), "a world menu for the unit")
                if not context then return end
                local drink = T.optionRunning(context, ISWorldObjectContextMenu.onDrink)
                local fill = T.optionRunning(context, ISWorldObjectContextMenu.onTakeWater)
                self.drink, self.drinkTooltip = T.offered(drink), T.tooltipOf(drink)
                self.fill = T.offered(fill)
                self.empty = T.offered(T.optionRunning(context, ISWorldObjectContextMenu.onFluidEmpty))
                self.pour = T.findNamed(context, getText("ContextMenu_AddFluidFromItem")) ~= nil
                if fill then
                    T.choose(fill)
                end
                context:hideAndChildren()
            end)
            T.readUnitUntil(self, self.unit, "drawn", function(state) return state.basin.litres < case.litres - 1 end)
            T.readCarried(self, { "Base.Bucket" }, nil, "bucket")
        end,
        validate = function(self)
            T.expect(self.drink, "the menu offers no Drink")
            local warns = self.drinkTooltip:find(getText("Tooltip_item_TaintedWater"), 1, true) ~= nil
            T.expect(warns == case.tainted, "Drink's tooltip " .. (warns and "warns" or "doesn't warn")
                .. " of tainted water: " .. self.drinkTooltip)
            T.expect(self.fill, "the menu offers no Fill for the bucket")
            T.expect(self.empty, "the menu offers no Empty")
            T.expect(not self.pour, "the menu offers vanilla's pour into the basin")
            local bucket = T.carriedFirst(self, "Base.Bucket", "bucket")
            T.expect(bucket.litres > case.inBucket + 1, "Fill took nothing from the basin")
            T.expectNear("the basin and bucket", self.reads.drawn.basin.litres + bucket.litres, case.litres + case.inBucket,
                T.LITRES)
            T.expect(bucket.tainted == case.tainted, "the bucket filled from the basin holds "
                .. (bucket.tainted and "tainted" or "clean") .. " water")
        end,
    })
end

return T
