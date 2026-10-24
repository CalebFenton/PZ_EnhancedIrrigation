require "EnhancedIrrigation/Debug/EnhancedIrrigationTestLib"
require "TimedActions/ISReadABook"
require "ISUI/ISInventoryPaneContextMenu"
require "Entity/ISEntityUI"

-- How the character learns the mod's recipes, the build-menu ones (the Tank Stand, the Barrel and
-- Brick Filters, setting up a Filter Crock and the two Boilers), the crock's wheel and kiln
-- recipes, and Plumb to Tank (knowledge with nothing to craft, Recipes.txt), and where the pamphlet
-- that teaches some of them turns up. Reading and researching go through vanilla's actions, levels
-- through the authority's XP award, which fires LevelPerk; the lists are vanilla's own windows and
-- menus. Each side's copy of the character is checked: the authority's decides the builds and the
-- plumbing, this client's the menus. EnhancedIrrigationTestServerLearning.lua holds the server's
-- half.

local T = EnhancedIrrigationTest
local test, expect = T.test, T.expect

local PAMPHLET = "EnhancedIrrigation.CisternsForKentucky"
local STAND, PLUMB = "EnhancedIrrigation_TankStand", "EnhancedIrrigation_PlumbToTank"
local CROCK = { "EnhancedIrrigation_ShapeFilterCrock", "EnhancedIrrigation_FireFilterCrock",
    "EnhancedIrrigation_FilterCrock" }
local BOILERS = { "EnhancedIrrigation_BoilerStone", "EnhancedIrrigation_BoilerWelded" }
local BUILDS = { STAND, "EnhancedIrrigation_BarrelFilter", "EnhancedIrrigation_BrickFilter", CROCK[3], BOILERS[1], BOILERS[2] }
local PAMPHLET_RECIPES = { STAND, BUILDS[2], BUILDS[3], PLUMB }
local RECIPES = { STAND, BUILDS[2], BUILDS[3], PLUMB, CROCK[1], CROCK[2], CROCK[3], BOILERS[1], BOILERS[2] }

-- Each of `names` marked true.
local function marked(names)
    local set = {}
    for _, name in ipairs(names) do
        set[name] = true
    end
    return set
end

-- Knowledge ---------------------------------------------------------------------------------------

-- Which of RECIPES this client's copy of the character knows.
local function knownHere()
    local known, p = {}, T.player()
    for _, name in ipairs(RECIPES) do
        known[name] = p:isRecipeActuallyKnown(name)
    end
    return known
end

-- Queues waits until the authority and then this client know each recipe `expected` marks true
-- (a multiplayer server sends what it taught), and leaves what each side knows in self.known.
local function awaitKnown(self, expected)
    local function knowsAll(known)
        for name, want in pairs(expected) do
            if want and not (known and known[name]) then
                return false
            end
        end
        return true
    end
    T.serverUntil(self, "learning.known", { names = RECIPES }, function(reply) return knowsAll(reply and reply.known) end)
    for name, want in pairs(expected) do
        if want then
            T.waitFor(self, function() return knownHere()[name] end, "this client's copy of the character knowing " .. name)
        end
    end
    T.step(function()
        self.known = { server = self.server["learning.known"].known, client = knownHere() }
    end)
end

-- Expects each side to know exactly the recipes `expected` marks true, of RECIPES, after `what`.
local function expectKnown(self, what, expected)
    for side, known in pairs(self.known or {}) do
        for _, name in ipairs(RECIPES) do
            local want = expected[name] == true
            expect(known[name] == want, what .. (want and " did not teach " or " taught ") .. name .. " on the " .. side)
        end
    end
end

-- Reading the pamphlet through vanilla's action teaches its recipes, on the authority too, whose
-- copy the builds and the plumbing ask, and not the crock's, which are a potter's.
test("irrigation_learning_reading_the_pamphlet_teaches_its_recipes", {
    instant = true,
    run = function(self)
        T.knowRecipes(self, RECIPES, false)
        T.give(self, "pamphlet", { { type = PAMPHLET } })
        -- A title read within the literature cooldown teaches nothing (ISReadABook:complete), and
        -- every copy shares its title, so a rerun in the same world would read nothing.
        T.server(self, "learning.forgetLiterature", { type = PAMPHLET })
        T.step(function()
            local p, item = T.player(), self.items.pamphlet[1]
            local title = item:getModData().literatureTitle
            if title then
                p:getReadLiterature():remove(title)
            end
            ISTimedActionQueue.add(ISReadABook:new(p, item))
        end)
        awaitKnown(self, marked(PAMPHLET_RECIPES))
    end,
    validate = function(self)
        expectKnown(self, "reading Cisterns for Kentucky", marked(PAMPHLET_RECIPES))
    end,
})

-- A potter at the research level of Shape Filter Crock (two-thirds of its Pottery 4) right-clicks a
-- Clay Jar, which vanilla's script doesn't make researchable, and Research teaches the crock's
-- three recipes, on both sides, and nothing else. Catches the jar's research added on one side
-- only, or not at all.
test("irrigation_learning_researching_a_clay_jar_teaches_the_crock", {
    instant = true,
    hour = 12,
    run = function(self)
        T.knowRecipes(self, RECIPES, false)
        T.setPerk(self, Perks.Pottery, 3)
        T.give(self, "jar", { { type = "Base.ClayJar" } })
        T.step(function()
            local context = ISInventoryPaneContextMenu.createMenu(0, true, { self.items.jar[1] }, 0, 0)
            if not T.need(self, type(context) == "table" and context, "the Clay Jar's right-click menu") then return end
            local research = T.findNamed(context, context, getText("ContextMenu_ResearchCraft"))
            self.offered = T.offered(research)
            if self.offered then
                T.choose(research)
            end
            context:hideAndChildren()
        end)
        awaitKnown(self, marked(CROCK))
    end,
    validate = function(self)
        expect(self.offered, "the Clay Jar's menu offers no Research")
        expectKnown(self, "researching a Clay Jar", marked(CROCK))
    end,
})

-- A character at the research level of both boilers (two-thirds of each one's skill: Masonry for
-- the stone firebox, MetalWelding for the welded) researches a Metal Drum, which vanilla's script
-- doesn't make researchable, and learns both boilers, on both sides, and nothing else. Catches the
-- drum's research added on one side only, or not at all.
test("irrigation_learning_researching_a_metal_drum_teaches_the_boilers", {
    instant = true,
    hour = 12,
    run = function(self)
        T.knowRecipes(self, RECIPES, false)
        T.setPerk(self, Perks.Masonry, 1)
        T.setPerk(self, Perks.MetalWelding, 2)
        T.give(self, "drum", { { type = "Base.MetalDrum" } })
        T.step(function()
            local context = ISInventoryPaneContextMenu.createMenu(0, true, { self.items.drum[1] }, 0, 0)
            if not T.need(self, type(context) == "table" and context, "the Metal Drum's right-click menu") then return end
            local research = T.findNamed(context, context, getText("ContextMenu_ResearchCraft"))
            self.offered = T.offered(research)
            if self.offered then
                T.choose(research)
            end
            context:hideAndChildren()
        end)
        awaitKnown(self, marked(BOILERS))
    end,
    validate = function(self)
        expect(self.offered, "the Metal Drum's menu offers no Research")
        expectKnown(self, "researching a Metal Drum", marked(BOILERS))
    end,
})

-- The AutoLearn skills of the recipe `name` as { perk = perk id, level }, in `any` and `all`.
local function autoLearnOf(name)
    local recipe = getScriptManager():getCraftRecipe(name)
    local skills = { any = {}, all = {} }
    if not recipe then return skills end
    for i = 0, recipe:getAutoLearnAnySkillCount() - 1 do
        local skill = recipe:getAutoLearnAnySkill(i)
        table.insert(skills.any, { perk = skill:getPerk():getId(), level = skill:getLevel() })
    end
    for i = 0, recipe:getAutoLearnAllSkillCount() - 1 do
        local skill = recipe:getAutoLearnAllSkill(i)
        table.insert(skills.all, { perk = skill:getPerk():getId(), level = skill:getLevel() })
    end
    return skills
end

-- Which of RECIPES a character with `perk` at `level` and every other perk at 0 has the AutoLearn
-- skills of, as their scripts state them.
local function earnedAt(perk, level)
    local function meets(skill)
        return skill.level <= (skill.perk == perk and level or 0)
    end
    local earned = {}
    for _, name in ipairs(RECIPES) do
        local skills = autoLearnOf(name)
        for _, skill in ipairs(skills.any) do
            earned[name] = earned[name] or meets(skill)
        end
        if #skills.all > 0 then
            local all = true
            for _, skill in ipairs(skills.all) do
                all = all and meets(skill)
            end
            earned[name] = earned[name] or all
        end
    end
    return earned
end

-- Every perk and level RECIPES name in their AutoLearn skills, once each, and the highest.
local function autoLearnLevels()
    local rows, seen, highest = {}, {}, nil
    for _, name in ipairs(RECIPES) do
        local skills = autoLearnOf(name)
        for _, list in ipairs({ skills.any, skills.all }) do
            for _, skill in ipairs(list) do
                local key = skill.perk .. skill.level
                if not seen[key] then
                    seen[key] = true
                    table.insert(rows, skill)
                    if not highest or skill.level > highest.level then
                        highest = skill
                    end
                end
            end
        end
    end
    return rows, highest
end

-- Each perk at 0 but `perk`, which is at `level`.
local function levelsWith(rows, perk, level)
    local levels = {}
    for _, row in ipairs(rows) do
        levels[row.perk] = 0
    end
    levels[perk] = level
    return levels
end

-- For each perk and level the recipes' AutoLearn skills name, a character who knows none of them
-- levels that perk up to that level, every other at 0, and then knows exactly the recipes whose
-- AutoLearn it meets, on both sides: vanilla's AutoLearn teaches Plumb to Tank, a craftRecipe, and
-- the mod's LevelPerk hook the builds, since vanilla's skips build recipes. Catches a recipe taught
-- a level early or never, or taught on one side only.
test("irrigation_learning_level_up_teaches_at_the_auto_learn_level", {
    timeoutSeconds = 90,
    run = function(self)
        local rows = autoLearnLevels()
        if not T.need(self, #rows > 0, "an AutoLearn skill on " .. table.concat(RECIPES, " or ")) then return end
        self.rows, self.results = rows, {}
        T.knowRecipes(self, RECIPES, false)
        for i, row in ipairs(rows) do
            -- Each row starts knowing none; knowRecipes puts back what was known before the test.
            T.step(function() PZHarness.Fixtures.forgetRecipes(T.player(), RECIPES) end)
            T.server(self, "learning.levelUp", { perk = row.perk, levels = levelsWith(rows, row.perk, row.level - 1),
                names = RECIPES, forget = RECIPES })
            awaitKnown(self, earnedAt(row.perk, row.level))
            T.step(function()
                self.results[i] = { up = self.server["learning.levelUp"] or {}, known = self.known }
            end)
        end
    end,
    validate = function(self)
        for i, row in ipairs(self.rows or {}) do
            local result = self.results[i] or {}
            local up, what = result.up or {}, row.perk .. " " .. row.level
            expect(up.before == row.level - 1 and up.after == row.level, row.perk .. " went from " .. tostring(up.before)
                .. " to " .. tostring(up.after) .. ", expected " .. (row.level - 1) .. " to " .. row.level)
            self.known = result.known
            expectKnown(self, what, earnedAt(row.perk, row.level))
        end
    end,
})

-- A character who reached the highest AutoLearn level before the mod was added joins a server: the
-- client asks the server to catch up as it enters the world (Recipes.lua's OnCreatePlayer), and the
-- server, which runs no check of its own on a join, teaches what that level earns and tells the
-- client. Catches a joining character left without recipes the server then refuses to use.
test("irrigation_learning_joining_server_catches_up_earned_recipes", {
    mpOnly = "single player has one copy of the character, which IsoWorld.init's own check covers",
    run = function(self)
        local rows, highest = autoLearnLevels()
        if not T.need(self, highest, "an AutoLearn skill on " .. table.concat(RECIPES, " or ")) then return end
        self.highest = highest
        T.knowRecipes(self, RECIPES, false)
        T.server(self, "learning.setLevels", { levels = levelsWith(rows, highest.perk, highest.level), names = RECIPES })
        T.step(function()
            local Recipes = EnhancedIrrigation.Recipes
            sendClientCommand(T.player(), Recipes.COMMAND_MODULE, Recipes.CATCH_UP, {})
        end)
        awaitKnown(self, earnedAt(highest.perk, highest.level))
    end,
    validate = function(self)
        local before = self.server["learning.setLevels"] or {}
        local knewAny = not before.known
        for _, name in ipairs(RECIPES) do
            knewAny = knewAny or before.known[name] == true
        end
        expect(not knewAny, "setting the levels alone taught the server a recipe, so the catch-up is untested")
        local highest = self.highest
        expectKnown(self, "joining at " .. highest.perk .. " " .. highest.level, earnedAt(highest.perk, highest.level))
    end,
})

-- Lists ---------------------------------------------------------------------------------------------

-- The panel field `field` (handCraftPanel, BuildPanel) of the open entity window that has one.
local function openPanel(field)
    ISEntityUI.EnsurePlayers()
    for _, playerWindows in pairs(ISEntityUI.players) do
        for _, entry in pairs(playerWindows.windows or {}) do
            if entry.instance and entry.instance[field] then
                return entry.instance[field]
            end
        end
    end
    return nil
end

-- The recipe names `panel` shows, by its list (list mode) and its tiles (grid mode), and how many
-- each shows; the mode is switched as its button does, and put back.
local function shownBy(panel)
    local recipes = panel.recipesPanel
    local wasList = recipes.recipeListMode
    local shown, counts = { list = {}, grid = {} }, { list = 0, grid = 0 }
    panel:setRecipeListMode(true)
    for _, entry in ipairs(recipes.recipeListPanel.recipeListPanel.items) do
        if entry.item then
            shown.list[entry.item:getName()] = true
            counts.list = counts.list + 1
        end
    end
    panel:setRecipeListMode(false)
    local tiles = recipes.recipeIconPanel.dataList
    for i = 0, tiles:size() - 1 do
        shown.grid[tiles:get(i):getName()] = true
    end
    counts.grid = tiles:size()
    panel:setRecipeListMode(wasList)
    return shown, counts
end

-- Whether the window's logic, before its list drops what OnAddToMenu refuses, holds `name`.
local function logicHolds(panel, name)
    local all = panel.logic:getRecipeList():getAllRecipes()
    for i = 0, all:size() - 1 do
        if all:get(i):getName() == name then
            return true
        end
    end
    return false
end

-- Expects `name` (not) shown, by `shown` (from shownBy), in both modes of the window `where`.
local function expectShown(shown, name, want, where)
    for mode, names in pairs(shown or {}) do
        expect((names[name] == true) == want, where .. (want and " doesn't show " or " shows ") .. name .. " in " .. mode .. " mode")
    end
end

-- The crafting window lists every recipe ("*", as its button and the magazines' recipe lists open
-- it) but never Plumb to Tank: not by default, not searched for by name, not with every recipe
-- shown. Its logic does hold it, so OnAddToMenu is what keeps it out.
test("irrigation_learning_plumb_to_tank_in_no_crafting_list", {
    run = function(self)
        T.knowRecipes(self, RECIPES, true)
        T.defer(self, function() ISEntityUI.CloseWindows() end)
        T.step(function()
            ISEntityUI.OpenHandcraftWindow(T.player(), nil, "*")
            local panel = openPanel("handCraftPanel")
            if not T.need(self, panel, "the crafting window") then return end
            self.default, self.counts = shownBy(panel)
            -- As typing in its search box does (ISWidgetRecipeFilterPanel.onTextChange).
            panel:setRecipeFilter(Translator.getRecipeName(PLUMB), nil)
            self.searched = shownBy(panel)
            self.logicHad = logicHolds(panel, PLUMB)
            -- Its "show all recipes" box, searched again.
            panel:setSeeAllRecipe(true)
            panel:setRecipeFilter(Translator.getRecipeName(PLUMB), nil)
            self.all = shownBy(panel)
            self.logicHadAll = logicHolds(panel, PLUMB)
        end)
    end,
    validate = function(self)
        -- An empty list would show nothing to drop.
        for mode, count in pairs(self.counts or {}) do
            expect(count > 0, "the crafting window shows no recipe in " .. mode .. " mode")
        end
        expectShown(self.default, PLUMB, false, "the crafting window")
        expectShown(self.searched, PLUMB, false, "the crafting window searched for it")
        expectShown(self.all, PLUMB, false, "the crafting window showing every recipe")
        expect(self.logicHad or self.logicHadAll, "the crafting window's search never found Plumb to Tank to drop")
    end,
})

-- The build menu shows each build to a character who knows it, the Tank Stand searched for too,
-- and never Plumb to Tank.
test("irrigation_learning_build_menu_shows_the_builds_not_plumbing", {
    run = function(self)
        T.knowRecipes(self, RECIPES, true)
        T.defer(self, function() ISEntityUI.CloseWindows() end)
        T.step(function()
            ISEntityUI.OpenBuildWindow(T.player(), nil, "*")
            local panel = openPanel("BuildPanel")
            if not T.need(self, panel, "the build window") then return end
            self.default = shownBy(panel)
            panel:setRecipeFilter(Translator.getRecipeName(STAND), nil)
            self.searched = shownBy(panel)
        end)
    end,
    validate = function(self)
        for _, name in ipairs(BUILDS) do
            expectShown(self.default, name, true, "the build menu")
        end
        expectShown(self.searched, STAND, true, "the build menu searched for it")
        expectShown(self.default, PLUMB, false, "the build menu")
    end,
})

-- The pamphlet's own recipe list (its right-click "Show Known Recipes") names Plumb to Tank, and
-- picking it opens the crafting window on it, which can't craft it, then or once the window has
-- refreshed as it does when the inventory changes (ISHandCraftPanel:update, drawDirty).
test("irrigation_learning_pamphlet_recipe_list_cannot_craft_plumbing", {
    run = function(self)
        T.knowRecipes(self, RECIPES, true)
        T.defer(self, function() ISEntityUI.CloseWindows() end)
        T.give(self, "pamphlet", { { type = PAMPHLET } })
        local function craftable()
            local panel = openPanel("handCraftPanel")
            local recipe = panel and panel.logic:getRecipe()
            if not (recipe and recipe:getName() == PLUMB) then
                return false
            end
            -- What the window's craft button does (ISWidgetHandCraftControl:startHandcraft);
            -- not queued, so a craft it would start never runs.
            return panel.logic:canPerformCurrentRecipe() or ISEntityUI.HandcraftStart(T.player(), panel.logic, false, false) ~= nil
        end
        T.step(function()
            local context = ISInventoryPaneContextMenu.createMenu(0, true, { self.items.pamphlet[1] }, 0, 0)
            if not T.need(self, type(context) == "table" and context, "the pamphlet's right-click menu") then return end
            local plumb = T.findNamed(context, context, Translator.getRecipeName(PLUMB))
            self.listsStand = T.findNamed(context, context, Translator.getRecipeName(STAND)) ~= nil
            self.listsPlumb = plumb ~= nil
            if plumb then
                T.choose(plumb)
            end
            context:hideAndChildren()
            self.opened = openPanel("handCraftPanel") ~= nil
            self.craftableAtOnce = craftable()
        end)
        T.step(function() ISHandCraftPanel.drawDirty = true end)
        T.waitFor(self, function() return not ISHandCraftPanel.drawDirty end, "the crafting window to refresh")
        T.step(function() self.craftableLater = craftable() end)
    end,
    validate = function(self)
        expect(self.listsStand and self.listsPlumb, "the pamphlet's recipe list doesn't name both recipes")
        expect(not self.listsPlumb or self.opened, "picking Plumb to Tank in the pamphlet's list opened no crafting window")
        expect(not self.craftableAtOnce, "the crafting window the pamphlet opened can craft Plumb to Tank")
        expect(not self.craftableLater, "the crafting window the pamphlet opened can craft Plumb to Tank once refreshed")
    end,
})

-- Loot ----------------------------------------------------------------------------------------------

local function expectNoFailures(answer)
    for _, failure in ipairs(answer and answer.failures or { "the check never answered" }) do
        expect(false, failure)
    end
end

-- The pamphlet sits once in each list Distributions.lua names, as loaded and at each PamphletLoot
-- value, at its weight times the option, and nowhere at 0.
test("irrigation_loot_pamphlet_in_its_lists_scaled_by_the_option", {
    run = function(self) T.server(self, "learning.lootLists", { multipliers = { 2.5, 0, 1 } }) end,
    validate = function(self) expectNoFailures(self.server["learning.lootLists"]) end,
})

-- Each of those lists hands the pamphlet out through the game's own roll.
test("irrigation_loot_pamphlet_rolls_from_each_list", {
    run = function(self) T.server(self, "learning.lootRolls", { fills = 100 }) end,
    validate = function(self) expectNoFailures(self.server["learning.lootRolls"]) end,
})
