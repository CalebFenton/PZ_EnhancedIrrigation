require "EnhancedIrrigation/Debug/EnhancedIrrigationTestLibLines"
require "EnhancedIrrigation/Debug/EnhancedIrrigationTestLibPumps"
require "EnhancedIrrigation/Sprites"
require "EnhancedIrrigation/Lines/Lines"
require "EnhancedIrrigation/Lines/LineJobs"
require "EnhancedIrrigation/Pumps/Pumps"

-- Laying a garden line with the Lay Line cursor: what each tile costs, where a line may start, which
-- lines may join, and the walls that part them.

local T = EnhancedIrrigationTest
local expect, expectNear, expectEqual, expectOffered = T.expect, T.expectNear, T.expectEqual, T.expectOffered
local Sprites, Lines = EnhancedIrrigation.Sprites, EnhancedIrrigation.Lines
local LineJobs, Tanks = EnhancedIrrigation.LineJobs, EnhancedIrrigation.Tanks

-- The door frame of vanilla's house wall on a square's west edge (T.WALL_WEST).
local DOOR_FRAME_WEST = "walls_exterior_house_01_10"

-- Laying -------------------------------------------------------------------------------------------

-- Three iron lengths laid with the cursor from the ground's menu, the first beside a tank on the
-- floor above: each tile costs a length, and each joins its neighbours, so the row draws as one
-- pipe. Iron is joined with the pipe wrench, so without one the cursor and the authority refuse it.
-- Catches a free tile, shapes that don't meet, or iron laid bare-handed.
T.test("irrigation_lines_lay_costs_and_shapes", {
    instant = true,
    run = function(self)
        local rows = T.row(self, 3)
        if not rows then return end
        local tiles = rows[1]
        self.tiles = tiles
        for _, tile in ipairs(tiles) do
            T.trackSquare(self, tile)
        end
        T.placeTank(self, tiles[1], "above", 0)
        T.give(self, "pipes", { { type = "Base.MetalPipe", count = #tiles } })
        T.goNextTo(self, tiles[2].square)
        T.step(function()
            self.noWrench = T.layCursor(self, "iron"):refusal(tiles[1].square)
            getCell():setDrag(nil, T.player():getPlayerNum())
        end)
        T.job(self, "line", LineJobs.LAY, tiles[1], "iron", "no wrench", { floor = true, reads = T.lineReads(tiles) })
        T.give(self, "wrench", { { type = "Base.PipeWrench" } })
        T.step(function()
            local context = T.need(self, T.worldMenu(tiles[1].square:getFloor()), "a world menu on the ground")
            if not context then return end
            local lay = T.findOption(context, function(option)
                return option.onSelect == EnhancedIrrigation.LineCursor.start and option.param1 == "iron"
            end)
            T.chooseOption(self, "lay", lay)
            context:hideAndChildren()
            local cursor = T.layCursor(self, "iron", true)
            if not T.need(self, cursor and cursor.material == "iron" and cursor, "the Lay Line cursor for iron pipe") then
                return
            end
            self.cursor, self.valid = cursor, {}
        end)
        for i, tile in ipairs(tiles) do
            T.step(function()
                T.face(tile.square)
                self.valid[i] = self.cursor:isValid(tile.square)
                self.cursor:tryBuild(tile.x, tile.y, tile.z)
            end)
            T.waitForLines(self, { tile }, "this client's copy of laid tile " .. i)
        end
        T.readLines(self, tiles, "laid")
        T.count(self, "left", { "Base.MetalPipe" })
    end,
    validate = function(self)
        expectEqual("laying iron without a pipe wrench's refusal", self.noWrench, "Tooltip_EnhancedIrrigation_Short")
        local noWrench = self.reads["no wrench"]
        expect(noWrench.ok == false and noWrench.after.state.tiles[1].record == nil,
            "the server laid iron without a pipe wrench")
        expectOffered(self, "lay")
        local shapes = { Sprites.EAST, Sprites.EAST + Sprites.WEST, Sprites.WEST }
        for i, tile in ipairs(self.tiles) do
            expect(self.valid and self.valid[i], "the cursor refused tile " .. i)
            local want = Sprites.pipe("iron", false, shapes[i])
            local read = self.reads.laid.tiles[i]
            expect(read.record and read.record.material == "iron", "tile " .. i .. " has no iron record")
            expectEqual("the server's sprite of tile " .. i, read.sprite, want)
            expectEqual("this client's sprite of tile " .. i, T.lineSprite(tile), want)
        end
        expectEqual("iron pipe left", T.counted(self, "Base.MetalPipe"), 0)
    end,
})

-- A plastic length takes one use of glue for its joint; wood glue and adhesive tape hold no water,
-- so they don't make one. Catches a joint that's free, one that empties the glue, or one of tape.
T.test("irrigation_lines_lay_plastic_uses_a_joint", {
    instant = true,
    run = function(self)
        local rows = T.row(self, 1)
        if not rows then return end
        local tile = rows[1][1]
        self.tile = tile
        T.trackSquare(self, tile)
        T.placeTank(self, tile, "above", 0)
        T.give(self, "weak joints", { { type = "Base.Woodglue" }, { type = "Base.Scotchtape" } })
        T.give(self, "pipes", { { type = "Base.Pipe" } })
        T.goNextTo(self, tile.square)
        T.step(function()
            self.cursor = T.layCursor(self, "plastic")
            self.weakJoint = self.cursor:refusal(tile.square)
        end)
        T.give(self, "joint", { { type = "Base.Glue" } })
        T.step(function()
            self.usesBefore = self.items.joint[1]:getCurrentUses()
            self.valid = self.cursor:refusal(tile.square) == nil
            self.cursor:tryBuild(tile.x, tile.y, tile.z)
        end)
        T.waitForLines(self, { tile }, "this client's copy of the plastic tile")
        T.waitFor(self, function() return self.items.joint[1]:getCurrentUses() < self.usesBefore end,
            "this client's glue, used")
        T.count(self, "left", { "Base.Pipe" })
    end,
    validate = function(self)
        expectEqual("a wood glue and adhesive tape joint's refusal", self.weakJoint, "Tooltip_EnhancedIrrigation_Short")
        expect(self.valid, "the cursor refused a tile beside a tank")
        expectEqual("uses of glue the joint used", self.usesBefore - self.items.joint[1]:getCurrentUses(), 1)
        expect(T.counted(self, "Base.Pipe") == 0, "laying left the plastic pipe")
        expect(T.recordSummary(self.tile).material == "plastic", "the tile isn't plastic")
    end,
})

-- The first tile of a line must be in a tank's reach; the next ones need only touch the line.
-- Catches lines laid anywhere, or every tile asked for a tank.
T.test("irrigation_lines_first_tile_needs_a_tank", {
    instant = true,
    run = function(self)
        local rows = T.row(self, 3, { minDistance = 2 })
        if not rows then return end
        local tiles = rows[1]
        T.give(self, "pipes", { { type = "Base.MetalPipe", count = #tiles }, { type = "Base.PipeWrench" } })
        T.step(function()
            if not T.need(self, #Tanks.tanksReaching(tiles[1].x, tiles[1].y, tiles[1].z) == 0,
                    "squares out of every tank's reach") then
                return
            end
            self.cursor = T.layCursor(self, "iron")
            self.alone = self.cursor:refusal(tiles[1].square)
        end)
        T.placeLine(self, { tiles[2] }, "iron")
        T.step(function()
            self.besideLine = self.cursor:refusal(tiles[1].square)
            self.besideLineEast = self.cursor:refusal(tiles[3].square)
        end)
    end,
    validate = function(self)
        expectEqual("a tile far from tanks and lines' refusal", self.alone, "Tooltip_EnhancedIrrigation_NoTankReach")
        expectEqual("a tile beside a line's refusal", self.besideLine, nil)
        expectEqual("a tile east of a line's refusal", self.besideLineEast, nil)
    end,
})

-- A tile between two tapped lines would make one line with two taps: the cursor refuses it and so
-- does the authority on its own, laying nothing. Once the second tap's tile is taken up and an
-- untapped one laid there, the same lay joins them, so the authority refused for the taps. Catches
-- the refusal only on the client, or a join refused for one tap.
T.test("irrigation_lines_merging_two_tapped_lines_refused", {
    instant = true,
    run = function(self)
        local rows = T.row(self, 3)
        if not rows then return end
        local tiles = rows[1]
        self.size = #tiles
        for _, tile in ipairs(tiles) do
            T.trackSquare(self, tile)
        end
        tiles[1].fields = T.tapped()
        tiles[3].fields = T.tapped()
        T.placeLine(self, { tiles[1], tiles[3] }, "iron")
        T.give(self, "pipes", { { type = "Base.MetalPipe" }, { type = "Base.PipeWrench" } })
        T.goNextTo(self, tiles[2].square)
        T.step(function()
            self.cursor = T.layCursor(self, "iron")
            self.twoTaps = self.cursor:refusal(tiles[2].square)
        end)
        local lay = { floor = true, reads = T.lineReads(tiles) }
        T.job(self, "line", LineJobs.LAY, tiles[2], "iron", "two taps", lay)
        T.useLineJob(self, tiles[3], LineJobs.TAKE_UP, "take up the tap", true)
        T.waitFor(self, function() return T.lineObject(tiles[3]) == nil end, "this client to lose the taken-up tap")
        tiles[3].fields = nil
        T.placeLine(self, { tiles[3] }, "iron")
        T.waitForLines(self, { tiles[3] }, "this client's copy of the untapped line", function(summary) return not summary.tap end)
        T.step(function() self.oneTap = self.cursor:refusal(tiles[2].square) end)
        T.job(self, "line", LineJobs.LAY, tiles[2], "iron", "one tap", lay)
    end,
    validate = function(self)
        expectEqual("a tile between two taps' refusal", self.twoTaps, "Tooltip_EnhancedIrrigation_JoinsTwoFeeds")
        local twoTaps, oneTap = self.reads["two taps"], self.reads["one tap"]
        expect(twoTaps.ok == false and twoTaps.after.state.tiles[2].record == nil, "the server laid a tile between two taps")
        expectEqual("a tile between a tapped and an untapped line's refusal", self.oneTap, nil)
        expectOffered(self, "take up the tap")
        local joined = oneTap.after.state.tiles[2].record
        expect(oneTap.ok and joined and joined.tiles == self.size,
            "the server didn't lay the tile joining a tapped and an untapped line")
    end,
})

-- A pump's outlet can start a line as a tank can: the first tile goes on beside a pump with no tank
-- in reach, on the cursor and the authority alike, but not two squares off it. Catches a pump that
-- can't start the line it would feed, or one that starts lines anywhere.
T.test("irrigation_lines_first_tile_beside_a_pump", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 1, 0 }, { 2, 0 } }, { bare = true, minDistance = 2 })
        if not spots then return end
        local pump, beside, far = spots[1], spots[2], spots[3]
        T.trackSquare(self, beside)
        T.trackSquare(self, far)
        T.give(self, "pipes", { { type = "Base.MetalPipe" }, { type = "Base.PipeWrench" } })
        T.placePump(self, pump, T.IRON)
        T.goNextTo(self, beside.square)
        T.step(function()
            if not T.need(self, #Tanks.tanksReaching(beside.x, beside.y, beside.z) == 0
                    and #Tanks.tanksReaching(far.x, far.y, far.z) == 0, "squares out of every tank's reach") then
                return
            end
            local cursor = T.layCursor(self, "iron")
            self.beside, self.far = cursor:refusal(beside.square), cursor:refusal(far.square)
        end)
        T.job(self, "line", LineJobs.LAY, beside, "iron", "laid", { floor = true, reads = T.lineReads({ beside }) })
    end,
    validate = function(self)
        expectEqual("a first tile beside a pump's refusal", self.beside, nil)
        expectEqual("a first tile two squares off a pump's refusal", self.far, "Tooltip_EnhancedIrrigation_NoTankReach")
        local laid = self.reads.laid
        expect(laid.ok and laid.after.state.tiles[1].record ~= nil, "the server didn't lay the first tile beside the pump")
    end,
})

-- A line takes a tap or a pump, not both: a tile between a tapped line and one a pump feeds is
-- refused on the cursor and by the authority, laying nothing. Catches a tank and a pump pushing
-- into one line.
T.test("irrigation_lines_merging_a_tapped_and_a_pumped_line_refused", {
    instant = true,
    run = function(self)
        local rows = T.row(self, 3)
        if not rows then return end
        local spots = T.layout(self, { { 0, 0 } }, { bare = true })
        if not spots then return end
        local tiles = rows[1]
        for _, tile in ipairs(tiles) do
            T.trackSquare(self, tile)
        end
        tiles[1].fields = T.tapped()
        T.placeLine(self, { tiles[1], tiles[3] }, "iron")
        T.placePump(self, spots[1], T.IRON)
        T.linkPump(self, spots[1], tiles[3])
        T.give(self, "pipes", { { type = "Base.MetalPipe" }, { type = "Base.PipeWrench" } })
        T.goNextTo(self, tiles[2].square)
        T.step(function() self.refusal = T.layCursor(self, "iron"):refusal(tiles[2].square) end)
        T.job(self, "line", LineJobs.LAY, tiles[2], "iron", "forced", { floor = true, reads = T.lineReads(tiles) })
    end,
    validate = function(self)
        expectEqual("a tile between a tap and a pump's refusal", self.refusal, "Tooltip_EnhancedIrrigation_JoinsTwoFeeds")
        local forced = self.reads.forced
        expect(forced.ok == false and forced.after.state.tiles[2].record == nil,
            "the server laid a tile between a tap and a pump")
    end,
})

-- Taking up the pumped tile leaves its outlet buried. It doesn't feed an adjacent line, which
-- can take a tap; laying the missing tile back would join both feeds and must be refused.
-- Catches an empty neighbor mistaken for component membership, or a lost buried outlet.
T.test("irrigation_lines_laying_on_a_pumps_outlet_beside_a_tap_refused", {
    instant = true,
    run = function(self)
        local rows = T.row(self, 2)
        if not rows then return end
        local spots = T.layout(self, { { 0, 0 } }, { bare = true })
        if not spots then return end
        local tiles = rows[1]
        for _, tile in ipairs(tiles) do
            T.trackSquare(self, tile)
        end
        T.placeLine(self, { tiles[2] }, "iron")
        T.placePump(self, spots[1], T.IRON)
        T.linkPump(self, spots[1], tiles[2])
        T.goNextTo(self, tiles[2].square)
        T.useLineJob(self, tiles[2], LineJobs.TAKE_UP, "take up", true)
        T.waitFor(self, function() return T.lineObject(tiles[2]) == nil end, "this client to lose the taken-up tile")
        T.placeLine(self, { tiles[1] }, "iron")
        T.placeTank(self, tiles[1], "above", T.TANK_LITRES)
        T.give(self, "pipes", { { type = "Base.MetalPipe", count = 2 }, { type = "Base.PipeWrench" } })
        T.goNextTo(self, tiles[1].square)
        T.useLineJob(self, tiles[1], LineJobs.TAP, "fit tap", true)
        T.waitForLines(self, { tiles[1] }, "this client's fitted tap", function(summary) return summary.tap end)
        T.step(function()
            self.outlet = EnhancedIrrigation.Links.roleAt(T.at(spots[1]), "pump")
            self.refusal = T.layCursor(self, "iron"):refusal(tiles[2].square)
        end)
        T.job(self, "line", LineJobs.LAY, tiles[2], "iron", "forced", { floor = true, reads = T.lineReads(tiles) })
    end,
    validate = function(self)
        expectOffered(self, "take up")
        expectOffered(self, "fit tap")
        expect(self.outlet ~= nil, "taking up the pump's tile took its outlet")
        expectEqual("a tile on a pump's outlet beside a tap's refusal", self.refusal, "Tooltip_EnhancedIrrigation_JoinsTwoFeeds")
        local forced = self.reads.forced
        expect(forced.ok == false and forced.after.state.tiles[2].record == nil,
            "the server laid a tile on a pump's outlet beside a tap")
    end,
})

-- A wall parts line on either side of it: laying beside line behind a wall finds nothing to join,
-- their shapes don't meet and the crop behind the wall gets none of the water. A door frame is no
-- wall, so a line enters a greenhouse by its door. Catches a wall check missing from laying, the
-- shapes or the flow.
T.test("irrigation_lines_walls_part_lines_doorways_join", {
    instant = true,
    run = function(self)
        local rows = T.row(self, 3, { minDistance = 2 })
        if not rows then return end
        local behind, inside, doorway = rows[1][1], rows[1][2], rows[1][3]
        self.tiles = { behind, inside, doorway }
        -- The wall stands on the middle square's west edge, the door frame on the east square's.
        T.placeTile(self, inside.square, T.WALL_WEST)
        T.placeTile(self, doorway.square, DOOR_FRAME_WEST)
        T.placeLine(self, { inside }, "iron", { holed = true })
        T.give(self, "pipes", { { type = "Base.MetalPipe", count = 2 }, { type = "Base.PipeWrench" } })
        T.step(function()
            for _, tile in ipairs(self.tiles) do
                if not T.need(self, #Tanks.tanksReaching(tile.x, tile.y, tile.z) == 0,
                        "squares out of every tank's reach") then
                    return
                end
            end
            local cursor = T.layCursor(self, "iron")
            self.behindWall = cursor:refusal(behind.square)
            self.throughDoorway = cursor:refusal(doorway.square)
        end)
        T.placeTank(self, doorway, "above", T.TANK_LITRES)
        behind.fields = { holed = true }
        doorway.fields = T.tapped()
        T.placeLine(self, { behind, doorway }, "iron")
        T.plant(self, { behind, inside }, 0)
        T.flow(self, doorway, 1, self.tiles, "hour")
    end,
    validate = function(self)
        expectEqual("a tile beside line behind a wall's refusal", self.behindWall, "Tooltip_EnhancedIrrigation_NoTankReach")
        expectEqual("a tile beside line through a door frame's refusal", self.throughDoorway, nil)
        local hour = self.reads.hour
        if not expect(hour.drawn, "the line didn't run: " .. tostring(hour.stopped)) then return end
        local names = { "behind the wall", "inside", "in the doorway" }
        local wanted = { 0, Sprites.EAST, Sprites.WEST }
        for i, tile in ipairs(hour.tiles) do
            expectEqual("the shape of the tile " .. names[i], T.shapeOf(tile.sprite), wanted[i])
        end
        -- The tank stands a storey over the line: one storey of head.
        expectNear("the crop inside's water", hour.tiles[2].plant.water, Lines.HOLE_RATE * Lines.POINTS_PER_LITRE, T.CROP_POINTS)
        expectNear("the crop behind the wall's water", hour.tiles[1].plant.water, 0, T.CROP_POINTS)
    end,
})
