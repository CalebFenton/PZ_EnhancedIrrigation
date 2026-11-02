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
--- record, and a wait for this client's copy and its summary. Returns its handle, of kind
--- "treatment", with `spec`.
function T.placeUnit(self, handle, entity, opts)
    opts = opts or {}
    local up = opts.up or 0
    local unit = { x = handle.x, y = handle.y, z = handle.z + up, kind = "treatment",
        sprite = T.TREATMENT_SPRITES[entity], spec = Treatment.ENTITIES[entity], square = up == 0 and handle.square or nil }
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
    local unit = T.buildTile(self, "Base." .. entity, T.TREATMENT_SPRITES[entity], prefer, "treatment")
    if not unit then return nil end
    unit.spec = Treatment.ENTITIES[entity]
    T.readUnitUntil(self, unit, "built", function(state) return state.record ~= nil end)
    T.waitFor(self, function() return Treatment.summaryOf(T.copyOf(unit)) ~= nil end,
        "this client's summary of the built " .. entity)
    T.readMenu(self, function() return T.copyOf(unit) end, "built")
    return unit
end

--- Expects what T.buildUnit read: the unit `entity`, with its record and nothing in its head or
--- its basin.
function T.expectBuiltUnit(self, entity)
    local built = self.reads.built
    T.expectEqual("the entity the build menu built", built.entity, entity)
    T.expect(built.record and built.record.head == 0, "the built " .. entity .. " has no record, or water in its head")
    T.expect(built.basin and built.basin.litres == 0, "the built " .. entity .. "'s basin isn't empty")
end

function T.readUnitUntil(self, unit, label, done)
    T.readUntil(self, "treatment.state", T.at(unit), label, done)
end

-- Queues `fields` set on the unit's record and a run of each of `hours`, with the tank's state if
-- given, into self.reads[label] ({ before, steps }).
function T.runUnit(self, unit, label, hours, fields, tank)
    T.read(self, "treatment.run", T.at(unit, { hours = hours, fields = fields, tank = tank and T.at(tank) }), label)
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
    T.waitForSummary(self, unit, function() return math.abs(T.clientBasin(unit).basin.litres - litres) < T.LITRES end,
        "this client's copy of the filled basin")
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

-- What a player gets from a unit: vanilla's Fill draws the basin into a carried bucket, which holds
-- the water as the unit made it, and vanilla's menu offers no pour into the basin though the
-- character carries water, as the basin is input-locked. Catches a basin vanilla's menu can't
-- reach, one it can pour into past the sand, the clay or the fire, or a taint lost or made up on
-- the way out. The crock's basin holds no more than a bucket, so that bucket starts part full: a
-- Fill that empties its source ends in an invalid action on a multiplayer client, which clears
-- the queue.
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
            -- Water carried, which vanilla would offer to pour into an unlocked basin; full, so
            -- vanilla's Fill lists only the bucket.
            T.fillCarried(self, "Base.WaterBottle", "Water", 10)
            if case.inBucket > 0 then
                T.fillCarried(self, "Base.Bucket", "Water", case.inBucket)
            end
            T.goNextTo(self, spots[1].square)
            T.step(function()
                local copy = T.copyOf(self.unit)
                local context = T.need(self, copy and T.worldMenu(copy), "a world menu for the unit")
                if not context then return end
                self.pour = T.findNamed(context, getText("ContextMenu_AddFluidFromItem")) ~= nil
                T.chooseOption(self, "fill", T.optionRunning(context, ISWorldObjectContextMenu.onTakeWater))
                context:hideAndChildren()
            end)
            T.readUnitUntil(self, self.unit, "drawn", function(state) return state.basin.litres < case.litres - 1 end)
            T.readCarried(self, { "Base.Bucket" }, nil, "bucket")
        end,
        validate = function(self)
            T.expect(not self.pour, "the menu offers vanilla's pour into the basin")
            T.expectOffered(self, "fill")
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
