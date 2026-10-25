require "EnhancedIrrigation/Debug/EnhancedIrrigationTestLibLines"
require "EnhancedIrrigation/Sprites"
require "EnhancedIrrigation/Lines/Lines"
require "EnhancedIrrigation/UI/PlantInfo"

-- The plant info's soil line and the soil word in a line tile's summary that it reads: crops on
-- line tiles of set soaks, the plant info windows opened as Plant Info opens them and drawn.

local T = EnhancedIrrigationTest
local expect = T.expect
local Sprites, Lines, PlantInfo = EnhancedIrrigation.Sprites, EnhancedIrrigation.Lines, EnhancedIrrigation.PlantInfo

-- Waits for the UI to draw a few times: it draws at its own rate, slower than the game's frames
-- in a test run, and the plant info sizes itself only as it draws.
local function uiDraws(self, what)
    T.step(function()
        if not self.draws then
            local count = function() self.draws = self.draws + 1 end
            Events.OnPostUIDraw.Add(count)
            T.defer(self, function() Events.OnPostUIDraw.Remove(count) end)
        end
        self.draws = 0
    end)
    T.waitFor(self, function() return self.draws >= 3 end, what)
end

local function heights(self)
    return { self.windows[1].farmingPanel:getHeight(), self.windows[2].farmingPanel:getHeight() }
end

-- This client's soil word under each crop on `tiles`, in self.keys. Called in a step.
local function soilKeys(self, tiles)
    self.keys = {}
    for i, tile in ipairs(tiles) do
        local plant = CFarmingSystem.instance:getLuaObjectOnSquare(tile.square)
        if not T.need(self, plant, "this client's crop on tile " .. i) then return false end
        self.keys[i] = PlantInfo.soilKeyOf(plant)
    end
    return true
end

-- With PlantInfo.FARMING_LEVEL the plant info names wet soil under the crop, one line taller than a
-- dry crop's; below it, the wet crop's info looks like a dry one's. Four crops on a line whose soil
-- is damp, soaked, waterlogged and dry. Catches a wrong word, or the line shown to the unskilled.
T.test("irrigation_plant_info_names_the_soil", {
    run = function(self)
        local rows = T.row(self, 4, { indoors = true })
        if not rows then return end
        self.tiles = rows[1]
        -- Well inside each band, so the minutes before the read don't dry one into the next.
        local soaks = { (Lines.DAMP + Lines.SOAKED) / 2, (Lines.SOAKED + Lines.WATERLOGGED) / 2, Lines.WATERLOGGED + 1, 0 }
        for i, tile in ipairs(self.tiles) do
            tile.fields = { soak = soaks[i] }
        end
        T.placeLine(self, self.tiles, "plastic")
        T.plant(self, self.tiles, Lines.PLANT_FULL / 2)
        T.goNextTo(self, self.tiles[3].square)
        T.setPerk(self, Perks.Farming, PlantInfo.FARMING_LEVEL - 1)
        T.step(function()
            if not soilKeys(self, self.tiles) then return end
            self.windows = {}
            -- The waterlogged crop's and the dry one's.
            for i, tileIndex in ipairs({ 3, 4 }) do
                local plant = CFarmingSystem.instance:getLuaObjectOnSquare(self.tiles[tileIndex].square)
                local window = ISFarmingWindow:new(100 + 340 * (i - 1), 100, 320, 240, T.player(), plant)
                window:initialise()
                window:addToUIManager()
                window:setVisible(true)
                self.windows[i] = window
                T.defer(self, function() window:removeFromUIManager() end)
            end
        end)
        uiDraws(self, "the plant info windows to draw")
        T.step(function()
            self.unskilled = heights(self)
            T.setPerk(self, Perks.Farming, PlantInfo.FARMING_LEVEL)
        end)
        uiDraws(self, "the plant info windows to draw for the skilled")
        T.step(function() self.skilled = heights(self) end)
    end,
    validate = function(self)
        local want = { "IGUI_EnhancedIrrigation_Damp", "IGUI_EnhancedIrrigation_Soaked",
            "IGUI_EnhancedIrrigation_Waterlogged" }
        for i, wanted in ipairs(want) do
            expect(self.keys[i] == wanted, "soil under tile " .. i .. ": " .. tostring(self.keys[i]) .. ", not " .. wanted)
        end
        expect(self.keys[4] == nil, "dry soil is named " .. tostring(self.keys[4]))
        local level = PlantInfo.FARMING_LEVEL
        expect(self.skilled[1] > self.skilled[2], "with Agriculture " .. level .. " the wet crop's info is "
            .. self.skilled[1] .. " tall and the dry one's " .. self.skilled[2] .. ": no soil line")
        expect(self.unskilled[1] == self.unskilled[2], "below Agriculture " .. level .. " the wet crop's info is "
            .. self.unskilled[1] .. " tall and the dry one's " .. self.unskilled[2])
    end,
})

-- The soil word comes from the same soak the roots and the wet look read, not a rounded copy: soil
-- just past waterlogged says Waterlogged and its crop loses health; soil just short of damp says
-- nothing and looks dry. Catches a rounded soak naming soil Soaked while its roots rot, or Damp
-- while it looks dry.
T.test("irrigation_plant_info_soil_word_agrees_with_the_roots", {
    run = function(self)
        local rows = T.row(self, 2, { indoors = true })
        if not rows then return end
        local logged, dry = rows[1][1], rows[1][2]
        self.tiles = { logged, dry }
        -- Within rounding of each threshold, on the side the rules read.
        logged.fields = { soak = Lines.WATERLOGGED + 0.4 }
        dry.fields = { soak = Lines.DAMP - 0.4 }
        T.placeLine(self, self.tiles, "plastic")
        T.plant(self, self.tiles, Lines.PLANT_FULL / 2)
        T.step(function()
            if not soilKeys(self, self.tiles) then return end
            self.drySprite = T.lineSprite(dry)
        end)
        T.read(self, "lines.age", { tiles = T.tiles({ logged }), hours = 1 }, "aged")
    end,
    validate = function(self)
        expect(self.keys[1] == "IGUI_EnhancedIrrigation_Waterlogged", "soil just past waterlogged is named "
            .. tostring(self.keys[1]))
        local before, after = self.reads.aged.before[1], self.reads.aged.tiles[1]
        expect(before.record.soak > Lines.WATERLOGGED, "the soil dried out of waterlogged before it aged: "
            .. before.record.soak)
        expect(after.plant.health < before.plant.health, "the crop under soil named Waterlogged lost no health")
        expect(self.keys[2] == nil, "soil just short of damp is named " .. tostring(self.keys[2]))
        local want = Sprites.pipe("plastic", false, Sprites.WEST)
        expect(self.drySprite == want, "soil just short of damp shows as " .. tostring(self.drySprite) .. ", not " .. want)
    end,
})
