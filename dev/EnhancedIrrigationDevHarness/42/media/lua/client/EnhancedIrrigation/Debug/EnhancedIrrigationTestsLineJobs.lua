require "EnhancedIrrigation/Debug/EnhancedIrrigationTestLib"
require "EnhancedIrrigation/Sprites"
require "EnhancedIrrigation/Pipes"
require "EnhancedIrrigation/Lines/Lines"
require "EnhancedIrrigation/Lines/LineJobs"
require "EnhancedIrrigation/UI/LineMenu"

-- The jobs at a laid line tile, played from its right-click menu: drilling, fitting a tap, patching,
-- draining, taking up and smashing.

local T = EnhancedIrrigationTest
local expect, expectNear = T.expect, T.expectNear
local expectOffered, expectRefused = T.expectOffered, T.expectRefused
local Sprites, Pipes, Lines = EnhancedIrrigation.Sprites, EnhancedIrrigation.Pipes, EnhancedIrrigation.Lines
local LineJobs, LineMenu = EnhancedIrrigation.LineJobs, EnhancedIrrigation.LineMenu

local POINTS = 0.05
local TANK_LITRES = 100

-- Helpers -------------------------------------------------------------------------------------------

-- Queues the server's view of `handles` into self.reads[label].tiles, once `done(tiles)` holds or
-- the wait runs out, for what an action's complete() does after this client's perform().
local function readUntil(self, handles, label, done)
    T.readUntil(self, "lines.read", { tiles = T.tiles(handles) }, label, function(reply) return done(reply.tiles) end)
end

local function recordOf(self, label, i)
    local tiles = self.reads[label] and self.reads[label].tiles
    return tiles and tiles[i] and tiles[i].record
end

-- Holes ---------------------------------------------------------------------------------------------

-- Notes in self.drills[label] how many Drill Holes options the line tile at `handle` offers, and
-- uses the option as useJob does.
local function useDrill(self, handle, label, choose)
    self.drills = self.drills or {}
    T.useOption(self, function() return T.lineObject(handle) end, label, function(context)
        local count = 0
        T.findOption(context, context, function(option)
            if option.onSelect == EnhancedIrrigationAction.queue and option.param2 == LineJobs.DRILL then
                count = count + 1
            end
            return false
        end)
        self.drills[label] = count
        return T.jobOption(context, "line", LineJobs.DRILL)
    end, choose)
end

-- An awl gets into soft pipe but not iron or clay, which its one Drill Holes option says, and never
-- splits it, even on a sure roll; a hand drill gets into iron; a holed tile offers no more drilling.
-- Catches a tool gate that lets the wrong tool through, an awl that splits pipe as a punch does, a
-- menu with an option per tool, or re-drilling.
T.test("irrigation_lines_drill_holes_tool_gate", {
    instant = true,
    run = function(self)
        local rows = T.row(self, 3)
        if not rows then return end
        local iron, clay, plastic = rows[1][1], rows[1][2], rows[1][3]
        self.tiles = { iron, clay, plastic }
        iron.material, clay.material, plastic.material = "iron", "clay", "plastic"
        T.placeLine(self, self.tiles)
        T.give(self, "awl", { { type = "Base.Awl" } })
        T.goNextTo(self, clay.square)
        useDrill(self, iron, "awl on iron", false)
        useDrill(self, clay, "awl on clay", false)
        -- A sure split for any tool that may split plastic.
        T.server(self, "lines.pinRoll", {})
        useDrill(self, plastic, "awl on plastic", true)
        T.waitForLines(self, { plastic }, "this client's summary of the awl's hole", function(summary) return summary.holed end)
        T.give(self, "drill", { { type = "Base.HandDrill" } })
        useDrill(self, iron, "hand drill on iron", true)
        T.waitForLines(self, { iron }, "this client's summary of the drill's hole", function(summary) return summary.holed end)
        useDrill(self, plastic, "holed plastic", false)
        T.readLines(self, self.tiles, "drilled")
    end,
    validate = function(self)
        expectRefused(self, "awl on iron", "Tooltip_EnhancedIrrigation_NoHoleMaker")
        expectRefused(self, "awl on clay", "Tooltip_EnhancedIrrigation_NoHoleMaker")
        expectOffered(self, "awl on plastic")
        expectOffered(self, "hand drill on iron")
        expect(self.drills["hand drill on iron"] == 1, "carrying an awl and a hand drill, the menu has "
            .. tostring(self.drills["hand drill on iron"]) .. " Drill Holes options")
        expect(not self.menu["holed plastic"].found, "a holed tile still offers Drill Holes")
        local drilled = self.reads.drilled.tiles
        expect(drilled[1].record.holed and drilled[3].record.holed, "the server has the iron or the plastic tile unholed")
        expect(not drilled[2].record.holed, "the clay tile was holed")
        expect(not drilled[3].record.cracked, "the awl split the plastic tile")
        local described = LineMenu.describe(T.lineSummary(self.tiles[3]))
        expect(described:find(getText("IGUI_EnhancedIrrigation_Holed"), 1, true) ~= nil,
            "the menu doesn't say the tile is holed: " .. described)
    end,
})

-- A hammer drives nails through plastic, which the menu warns may split it, and here it does.
-- Catches nails not being used up, the hammer being taken, or a punch that never cracks.
T.test("irrigation_lines_hammer_and_nail_can_crack_plastic", {
    instant = true,
    run = function(self)
        local rows = T.row(self, 1)
        if not rows then return end
        local tile = rows[1][1]
        self.nails = 10
        for _, tool in ipairs(LineJobs.HOLE_TOOLS) do
            for _, material in ipairs(tool.materials) do
                if material.item == "Base.Nails" then
                    self.need = material.need
                end
            end
        end
        T.placeLine(self, { tile }, "plastic")
        T.give(self, "tools", { { type = "Base.Hammer" }, { type = "Base.Nails", count = self.nails } })
        T.goNextTo(self, tile.square)
        T.server(self, "lines.pinRoll", {})
        useDrill(self, tile, "nail", true)
        T.waitForLines(self, { tile }, "this client's summary of the nailed tile", function(summary)
            return summary.holed and summary.cracked
        end)
        T.count(self, "left", { "Base.Nails", "Base.Hammer" })
    end,
    validate = function(self)
        expectOffered(self, "nail")
        local tooltip = self.menu.nail.tooltip
        expect(tooltip:find(getText("Tooltip_EnhancedIrrigation_MayCrack"), 1, true) ~= nil,
            "the tooltip doesn't warn the nail may split plastic: " .. tooltip)
        local left = self.counts.left["Base.Nails"] or 0
        expect(left == self.nails - self.need, "drilling left " .. left .. " of " .. self.nails .. " nails, not "
            .. (self.nails - self.need))
        expect(self.counts.left["Base.Hammer"] == 1, "drilling took the hammer")
    end,
})

-- Taps ---------------------------------------------------------------------------------------------

-- Fit Tap wants a tank reaching the tile a storey above the line: under a well, whose water stands
-- underground, and beside a barrel on the ground it's refused, saying so; beside a barrel on a stand
-- it fits with a length of the tile's own pipe, whatever else is carried, and shows the riser on
-- both sides. Catches a well or a ground barrel taken for head, or the wrong pipe taken.
T.test("irrigation_lines_fit_tap_needs_a_tank_a_storey_up", {
    instant = true,
    run = function(self)
        local rows = T.row(self, 3)
        if not rows then return end
        local west, tile, east = rows[1][1], rows[1][2], rows[1][3]
        T.placeLine(self, { tile }, "lead")
        T.placeTank(self, tile, "wellAbove")
        T.give(self, "tools", { { type = "Base.PipeWrench" }, { type = Pipes.KINDS.iron.item },
            { type = Pipes.KINDS.lead.item } })
        T.goNextTo(self, tile.square)
        T.useLineJob(self, tile, LineJobs.TAP, "under a well", false)
        T.placeTank(self, west, "ground", TANK_LITRES)
        T.useLineJob(self, tile, LineJobs.TAP, "beside a ground barrel", false)
        T.placeTank(self, east, "raised", 0)
        T.useLineJob(self, tile, LineJobs.TAP, "beside a raised barrel", true)
        readUntil(self, { tile }, "tapped", function(tiles) return tiles[1].record.tap == true end)
        T.waitFor(self, function() return T.hasOverlay(T.overlaysOf(T.lineObject(tile)), Sprites.TAP) end,
            "this client's copy of the tap's riser")
        T.count(self, "left", { Pipes.KINDS.iron.item, Pipes.KINDS.lead.item, "Base.PipeWrench" })
    end,
    validate = function(self)
        expectRefused(self, "under a well", "Tooltip_EnhancedIrrigation_NoPressure")
        expectRefused(self, "beside a ground barrel", "Tooltip_EnhancedIrrigation_NoPressure")
        expectOffered(self, "beside a raised barrel")
        local record = recordOf(self, "tapped", 1)
        expect(record.tap and record.tapMaterial == "lead", "the tap fitted: " .. tostring(record.tap) .. ", of "
            .. tostring(record.tapMaterial) .. " pipe, not the lead tile's own")
        expect(T.hasOverlay(self.reads.tapped.tiles[1].overlays, Sprites.TAP), "the server shows no riser")
        local iron, lead = Pipes.KINDS.iron.item, Pipes.KINDS.lead.item
        expect(self.counts.left[lead] == 0, "the tap took no lead pipe")
        expect(self.counts.left[iron] == 1, "the tap on lead pipe took iron pipe")
        expect(self.counts.left["Base.PipeWrench"] == 1, "the tap took the pipe wrench")
    end,
})

-- Upkeep --------------------------------------------------------------------------------------------

-- Tape over a crack makes the tile whole: it no longer says cracked, and taken up it gives back its
-- pipe like any other. Catches a patch that leaves the tile cracked, or scrap.
T.test("irrigation_lines_patch_crack", {
    instant = true,
    run = function(self)
        local rows = T.row(self, 1)
        if not rows then return end
        local tile = rows[1][1]
        tile.fields = { cracked = true }
        T.placeLine(self, { tile }, "plastic")
        T.give(self, "tape", { { type = "Base.DuctTape" } })
        T.goNextTo(self, tile.square)
        T.step(function() self.usesBefore = self.items.tape[1]:getCurrentUses() end)
        T.useLineJob(self, tile, LineJobs.PATCH, "patch", true)
        readUntil(self, { tile }, "patched", function(tiles) return not tiles[1].record.cracked end)
        T.waitFor(self, function() return self.items.tape[1]:getCurrentUses() < self.usesBefore end, "this client's tape, used")
        T.waitForLines(self, { tile }, "this client's summary of the patch", function(summary) return not summary.cracked end)
        T.step(function() self.described = LineMenu.describe(T.lineSummary(tile)) end)
        T.useLineJob(self, tile, LineJobs.TAKE_UP, "take up", true)
        T.waitFor(self, function() return T.lineObject(tile) == nil end, "this client to lose the taken-up tile")
        T.count(self, "back", { Pipes.KINDS.plastic.item })
    end,
    validate = function(self)
        expectOffered(self, "patch")
        expect(not recordOf(self, "patched", 1).cracked, "the patch left the tile cracked")
        local used = self.usesBefore - self.items.tape[1]:getCurrentUses()
        expect(used == Pipes.GLUE.uses, "the patch took " .. used .. " uses of tape, not " .. Pipes.GLUE.uses)
        expect(self.described:find(getText("IGUI_EnhancedIrrigation_Cracked"), 1, true) == nil,
            "the menu still says the patched tile is cracked: " .. self.described)
        expectOffered(self, "take up")
        local plastic = Pipes.KINDS.plastic
        expect(self.counts.back[plastic.item] == plastic.perLength, "the patched tile gave back "
            .. tostring(self.counts.back[plastic.item]) .. " plastic pipe, not " .. plastic.perLength)
    end,
})

-- Draining from a middle tile empties the whole line onto the ground there: that tile's soil shows
-- wet, and no tile's soil soaks. Catches a drain limited to an end, one that leaves water standing,
-- or one that rots a bed.
T.test("irrigation_lines_drain_from_the_middle", {
    instant = true,
    run = function(self)
        local rows = T.row(self, 3)
        if not rows then return end
        self.tiles = rows[1]
        for _, tile in ipairs(self.tiles) do
            tile.fields = { full = true }
        end
        T.placeLine(self, self.tiles, "lead")
        T.goNextTo(self, self.tiles[2].square)
        T.useLineJob(self, self.tiles[2], LineJobs.DRAIN, "drain the middle", true)
        readUntil(self, self.tiles, "drained", function(tiles)
            for _, tile in ipairs(tiles) do
                if tile.record.full then
                    return false
                end
            end
            return true
        end)
        T.waitFor(self, function()
            return T.lineSprite(self.tiles[2]) == Sprites.pipe("lead", true, Sprites.EAST + Sprites.WEST)
        end, "this client's copy of the drained tile, wet")
    end,
    validate = function(self)
        expectOffered(self, "drain the middle")
        local shapes = { Sprites.EAST, Sprites.EAST + Sprites.WEST, Sprites.WEST }
        for i, tile in ipairs(self.reads.drained.tiles) do
            expect(not tile.record.full, "tile " .. i .. " is still full")
            expectNear("tile " .. i .. "'s soak", tile.record.soak, 0, POINTS)
            local wet = i == 2
            expect(tile.record.wet == wet, "the server shows tile " .. i .. (wet and " dry" or " wet"))
            expect(T.lineSprite(self.tiles[i]) == Sprites.pipe("lead", wet, shapes[i]),
                "this client shows tile " .. i .. " as " .. tostring(T.lineSprite(self.tiles[i])))
        end
    end,
})

-- Taking up gives back what the tile took unless it is scrap: the tap tile its length and the tap's,
-- a cracked tile nothing, a whole one its length, a clay tile both its segments. What's left
-- reshapes. Catches scrap given back, the tap's pipe lost, or a clay segment kept.
T.test("irrigation_lines_take_up_returns_items", {
    instant = true,
    run = function(self)
        local rows = T.row(self, 4)
        if not rows then return end
        local tapTile, cracked, clay, whole = rows[1][1], rows[1][2], rows[1][3], rows[1][4]
        self.tiles = rows[1]
        tapTile.fields = T.tapped({ tapMaterial = "iron" })
        cracked.fields = { cracked = true }
        tapTile.material, cracked.material, clay.material, whole.material = "iron", "iron", "clay", "iron"
        T.placeLine(self, self.tiles)
        T.goNextTo(self, tapTile.square)
        T.useLineJob(self, tapTile, LineJobs.TAKE_UP, "take up the tap", true)
        T.waitFor(self, function() return T.lineObject(tapTile) == nil end, "this client to lose the tap tile")
        T.waitFor(self, function() return T.lineSprite(cracked) == Sprites.pipe("iron", false, Sprites.EAST) end,
            "this client's copy of the cracked tile, reshaped")
        for _, tile in ipairs({ cracked, clay, whole }) do
            T.goNextTo(self, tile.square)
            T.useLineJob(self, tile, LineJobs.TAKE_UP, "take up the " .. tile.material, true)
            T.waitFor(self, function() return T.lineObject(tile) == nil end, "this client to lose a taken-up tile")
        end
        T.readLines(self, self.tiles, "gone")
        T.count(self, "back", { Pipes.KINDS.iron.item, Pipes.KINDS.clay.item })
    end,
    validate = function(self)
        expectOffered(self, "take up the tap")
        local iron, clay = Pipes.KINDS.iron, Pipes.KINDS.clay
        -- The tap tile's length, its tap's and the whole tile's.
        local ironWanted = 3 * iron.perLength
        expect(self.counts.back[iron.item] == ironWanted, "the iron tiles gave back "
            .. tostring(self.counts.back[iron.item]) .. " iron pipe, not " .. ironWanted)
        expect(self.counts.back[clay.item] == clay.perLength, "the clay tile gave back "
            .. tostring(self.counts.back[clay.item]) .. " segments, not " .. clay.perLength)
        for i, tile in ipairs(self.reads.gone.tiles) do
            expect(tile.record == nil and tile.sprite == nil, "tile " .. i .. " is still there")
        end
    end,
})

-- An iron pipe laid worn comes back from Take Up as worn as it went in. Catches laying and taking
-- up a weapon mending it.
T.test("irrigation_lines_take_up_keeps_the_pipes_condition", {
    instant = true,
    run = function(self)
        local rows = T.row(self, 1)
        if not rows then return end
        local tile = rows[1][1]
        T.trackLines(self, { tile })
        T.placeTank(self, tile, "above", 0)
        self.worn = math.floor(instanceItem(Pipes.KINDS.iron.item):getConditionMax() / 2)
        T.give(self, "pipe", { { type = Pipes.KINDS.iron.item, condition = self.worn }, { type = "Base.PipeWrench" } })
        T.goNextTo(self, tile.square)
        T.step(function()
            local cursor = T.layCursor(self, "iron")
            T.face(tile.square)
            cursor:tryBuild(tile.x, tile.y, tile.z)
        end)
        T.waitForLines(self, { tile }, "this client's copy of the laid tile")
        T.useLineJob(self, tile, LineJobs.TAKE_UP, "take up", true)
        T.waitFor(self, function()
            self.back = T.player():getInventory():getFirstTypeRecurse(Pipes.KINDS.iron.item)
            return self.back ~= nil
        end, "this client's copy of the pipe taken up")
    end,
    validate = function(self)
        expectOffered(self, "take up")
        expect(self.back:getCondition() == self.worn, "the pipe came back at condition " .. self.back:getCondition()
            .. ", laid at " .. self.worn)
    end,
})

-- A sledgehammer smashes a line tile as it smashes any object, through vanilla's Destroy cursor
-- and action: the tile's record goes with it, tap and all, and its neighbours reshape. Catches a
-- record outliving its tile, or neighbours still drawn joined to nothing.
T.test("irrigation_lines_sledgehammer_reshapes_neighbours", {
    instant = true,
    run = function(self)
        local rows = T.row(self, 3)
        if not rows then return end
        local west, middle, east = rows[1][1], rows[1][2], rows[1][3]
        self.tiles = { west, middle, east }
        middle.fields = T.tapped()
        T.placeLine(self, self.tiles, "iron")
        T.give(self, "sledge", { { type = "Base.Sledgehammer" } })
        T.goNextTo(self, middle.square)
        -- The cursor lists what it can smash on the square it hovers, once the character sees it.
        T.waitFor(self, function()
            self.cursor = self.cursor or ISDestroyCursor:new(T.player(), false, self.items.sledge[1])
            self.cursor:isValid(middle.square)
            for i, object in ipairs(self.cursor:getObjectList()) do
                if Lines.isLine(object) then
                    self.cursor.objectIndex = i
                    return true
                end
            end
            return false
        end, "the Destroy cursor offering the line tile")
        T.step(function() self.cursor:create(middle.x, middle.y, middle.z) end)
        T.waitFor(self, function() return T.lineObject(middle) == nil end, "this client to lose the smashed tile")
        T.waitFor(self, function()
            return T.shapeOf(T.lineSprite(west)) == 0 and T.shapeOf(T.lineSprite(east)) == 0
        end, "this client's copies of the neighbours, reshaped")
        T.readLines(self, self.tiles, "after")
    end,
    validate = function(self)
        local after = self.reads.after.tiles
        expect(after[2].record == nil and after[2].sprite == nil, "the smashed tile is still there")
        for _, i in ipairs({ 1, 3 }) do
            local tile = after[i]
            expect(T.shapeOf(tile.sprite) == 0, "the server shapes neighbour " .. i .. " "
                .. tostring(T.shapeOf(tile.sprite)) .. ", not alone")
            expect(tile.record and tile.record.tiles == 1 and not tile.record.tap,
                "neighbour " .. i .. " is still in a line, or tapped")
        end
    end,
})

-- Taking up the middle of a line parts it on the authority in the same pass, before any client
-- hears the tile went: each end is then a line of one. Catches the authority walking a line
-- through single player's client copy of the taken tile, which a flow or a drain would then run
-- as a record. A multiplayer server keeps no client copies, so there it passes either way.
T.test("irrigation_lines_take_up_parts_the_line_at_once", {
    instant = true,
    run = function(self)
        local rows = T.row(self, 3)
        if not rows then return end
        self.tiles = rows[1]
        T.placeLine(self, self.tiles, "iron")
        T.read(self, "lines.perform", T.at(self.tiles[2], { job = LineJobs.TAKE_UP, tiles = T.tiles(self.tiles) }),
            "taken")
    end,
    validate = function(self)
        local taken = self.reads.taken
        expect(taken.done and taken.tiles[2].record == nil, "the server didn't take up the middle tile")
        for _, i in ipairs({ 1, 3 }) do
            local record = taken.tiles[i].record
            expect(record and record.tiles == 1, "end " .. i .. " is in a line of "
                .. tostring(record and record.tiles) .. " tiles, not 1")
        end
    end,
})
