require "EnhancedIrrigation/Debug/EnhancedIrrigationTestLib"
require "EnhancedIrrigation/Appliances/ApplianceJobs"
require "EnhancedIrrigation/UI/ApplianceMenu"

-- Salvage Pump from a washing machine or washer-dryer: the part and valve it gives, and the
-- appliance stopped for good.

local T = EnhancedIrrigationTest
local expect = T.expect
local ApplianceJobs = EnhancedIrrigation.ApplianceJobs

local APPLIANCE = EnhancedIrrigation.Pumps.APPLIANCE_PUMP
-- A washing machine, as vanilla's tile makes one (IsoClothingWasher), and a washer-dryer
-- (IsoCombinationWasherDryer).
local WASHER, COMBO = "appliances_laundry_01_4", "appliances_laundry_01_0"

-- Salvage Pump -----------------------------------------------------------------------------------------

-- The appliance drawn as `sprite` at `appliance` as the server has it, into self.reads[label].
local function readWasher(self, appliance, label, done, sprite)
    T.readUntil(self, "appliances.state", T.at(appliance, { sprite = sprite or WASHER }), label, done)
end

-- Queues vanilla's Turn On or Off of the washer drawn as `sprite` at `appliance`, run on the
-- authority as its action's complete() does, whatever the client checked, into self.reads[label];
-- a washer-dryer set to `mode` first.
local function toggle(self, appliance, label, sprite, mode)
    T.read(self, "appliances.toggle", T.at(appliance, { sprite = sprite or WASHER, mode = mode }), label)
end

-- A washing machine indoors on the grid with water in it runs once switched on. Salvage Pump from
-- its menu, with Electricity 2, the knowledge, a screwdriver and pliers, gives an Appliance Pump in
-- the salvaged range of condition and a Water Valve and stops the washer; its Turn On is then greyed
-- out saying the pump is gone, the server won't switch it on, and a second Salvage Pump is refused.
-- Catches a washer that runs with no pump, a pump salvaged twice, or no valve for a Timer Valve.
T.test("irrigation_salvage_washer_gives_a_part_and_stops_it", {
    instant = true,
    run = function(self)
        T.setGrid(self, true)
        local spots = T.layout(self, { { 0, 0 } }, { bare = true, indoors = true })
        if not spots then return end
        self.washer = { x = spots[1].x, y = spots[1].y, z = spots[1].z, square = spots[1].square }
        T.server(self, "fixtures.place", T.at(self.washer, { sprite = WASHER, washer = true, buffer = { litres = 20 } }))
        T.waitFor(self, function() return T.objectWithSprite(self.washer.square, WASHER) ~= nil end,
            "this client's copy of the washer")
        T.goNextTo(self, self.washer.square)
        toggle(self, self.washer, "running")
        T.knowRecipes(self, { ApplianceJobs.RECIPE }, true)
        T.setPerk(self, Perks.Electricity, 2)
        T.give(self, "tools", { { type = "Base.Screwdriver" }, { type = "Base.Pliers" } })
        local function washer() return T.objectWithSprite(getSquare(self.washer.x, self.washer.y, self.washer.z), WASHER) end
        T.useOption(self, washer, "salvage", function(context)
            return T.jobOption(context, "appliance", ApplianceJobs.SALVAGE_PUMP)
        end, true)
        readWasher(self, self.washer, "salvaged", function(state) return state.stripped end)
        T.read(self, "items.carried", { type = APPLIANCE }, "part")
        T.read(self, "items.carried", { type = EnhancedIrrigation.Valves.WATER_VALVE }, "valve")
        T.waitFor(self, function()
            local copy = washer()
            return copy ~= nil and EnhancedIrrigation.Appliances.isStripped(copy)
        end, "this client's copy of the stripped washer")
        T.useOption(self, washer, "on", function(context)
            return T.findNamed(context, context, getText("ContextMenu_Turn_On"))
        end, false)
        toggle(self, self.washer, "forced")
        T.useOption(self, washer, "again", function(context)
            return T.jobOption(context, "appliance", ApplianceJobs.SALVAGE_PUMP)
        end, false)
    end,
    validate = function(self)
        expect(self.reads.running.activated, "the washer never ran")
        T.expectOffered(self, "salvage")
        expect(not self.reads.salvaged.activated, "the stripped washer still runs")
        local items = self.reads.part.items
        local least, most = ApplianceJobs.SALVAGED_CONDITION[1], ApplianceJobs.SALVAGED_CONDITION[2]
        expect(#items == 1 and items[1].condition >= least and items[1].condition <= most,
            "Salvage Pump gave " .. #items .. " pumps" .. (items[1] and " at " .. items[1].condition or ""))
        expect(#self.reads.valve.items == 1, "Salvage Pump gave " .. #self.reads.valve.items .. " Water Valves")
        T.expectRefused(self, "on", "Tooltip_EnhancedIrrigation_PumpSalvaged")
        expect(not self.reads.forced.activated, "the server switched the stripped washer on")
        T.expectRefused(self, "again", "Tooltip_EnhancedIrrigation_PumpSalvaged")
    end,
})

-- A washer-dryer indoors on the grid, set to dry and switched on, stops on this client too once
-- its pump is salvaged: in dryer mode vanilla carries its switch as the dryer's change, which the
-- washer's leaves alone. Catches a stripped washer-dryer the server stopped but every client still
-- runs.
T.test("irrigation_salvage_drying_combo_stops_it", {
    instant = true,
    run = function(self)
        T.setGrid(self, true)
        local spots = T.layout(self, { { 0, 0 } }, { bare = true, indoors = true })
        if not spots then return end
        self.combo = { x = spots[1].x, y = spots[1].y, z = spots[1].z, square = spots[1].square }
        local function combo() return T.objectWithSprite(getSquare(self.combo.x, self.combo.y, self.combo.z), COMBO) end
        T.server(self, "fixtures.place", T.at(self.combo, { sprite = COMBO, combo = true }))
        T.waitFor(self, function() return combo() ~= nil end, "this client's copy of the washer-dryer")
        T.goNextTo(self, self.combo.square)
        toggle(self, self.combo, "drying", COMBO, "dryer")
        T.waitFor(self, function()
            local copy = combo()
            return copy ~= nil and copy:isModeDryer() and copy:isActivated()
        end, "this client's copy of the washer-dryer drying")
        T.knowRecipes(self, { ApplianceJobs.RECIPE }, true)
        T.setPerk(self, Perks.Electricity, 2)
        T.give(self, "tools", { { type = "Base.Screwdriver" }, { type = "Base.Pliers" } })
        T.useOption(self, combo, "salvage", function(context)
            return T.jobOption(context, "appliance", ApplianceJobs.SALVAGE_PUMP)
        end, true)
        readWasher(self, self.combo, "salvaged", function(state) return state.stripped end, COMBO)
        T.waitFor(self, function()
            local copy = combo()
            return copy ~= nil and EnhancedIrrigation.Appliances.isStripped(copy)
        end, "this client's copy of the stripped washer-dryer")
        -- The change follows the mark, which the server sent first.
        T.waitFor(self, function()
            local copy = combo()
            return copy ~= nil and not copy:isActivated()
        end, "this client's copy of the stripped washer-dryer to stop")
    end,
    validate = function(self)
        local drying = self.reads.drying
        expect(drying.activated and drying.dryer, "the washer-dryer never dried")
        T.expectOffered(self, "salvage")
        expect(not self.reads.salvaged.activated, "the server's stripped washer-dryer still runs")
    end,
})
