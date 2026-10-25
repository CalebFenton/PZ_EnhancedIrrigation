require "EnhancedIrrigation/Debug/EnhancedIrrigationTestLib"
require "EnhancedIrrigation/Recipes"
require "EnhancedIrrigation/Links/LinkJobs"
require "TimedActions/ISReadABook"
require "ISUI/ISInventoryPaneContextMenu"
require "Entity/ISEntityUI"

-- Plumb to Tank is knowledge with nothing to craft, so no crafting list may show it. Reading and
-- researching go through vanilla's actions, levels through the authority's XP award, which fires
-- LevelPerk; the lists are vanilla's own windows and menus. Each side's copy of the character is
-- checked: the authority's decides the builds and the plumbing, this client's the menus.

local T = EnhancedIrrigationTest
local test, expect = T.test, T.expect
local Recipes, LinkJobs = EnhancedIrrigation.Recipes, EnhancedIrrigation.LinkJobs

local PAMPHLET = "EnhancedIrrigation.CisternsForKentucky"
local PLUMB = LinkJobs.RECIPE
local CROCK, BOILERS = Recipes.RESEARCH["Base.ClayJar"], Recipes.RESEARCH["Base.MetalDrum"]

-- Every recipe of the mod, craftRecipe or build, that a character has to learn, as the scripts
-- state them: what each test expects known or not. Named here, not by the recipePrefix setting,
-- which may register after this file loads.
local RECIPES = T.learnableRecipeNames("EnhancedIrrigation_")

-- The pamphlet's LearnedRecipes, as its script states them.
local PAMPHLET_RECIPES = {}
do
    local pamphlet = getScriptManager():getItem(PAMPHLET)
    local learned = pamphlet and pamphlet:getLearnedRecipes()
    for i = 0, (learned and learned:size() or 0) - 1 do
        table.insert(PAMPHLET_RECIPES, learned:get(i))
    end
end

-- Each of `names` marked true.
local function marked(names)
    local set = {}
    for _, name in ipairs(names) do
        set[name] = true
    end
    return set
end

-- Knowledge ---------------------------------------------------------------------------------------

-- Reading the pamphlet through vanilla's action teaches its recipes, on the authority too, whose
-- copy the builds and the plumbing ask, and none of the mod's others.
test("irrigation_learning_reading_the_pamphlet_teaches_its_recipes", {
    instant = true,
    run = function(self)
        if not T.need(self, #PAMPHLET_RECIPES > 0, "the LearnedRecipes of " .. PAMPHLET) then return end
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
        T.waitForKnown(self, RECIPES, marked(PAMPHLET_RECIPES))
    end,
    validate = function(self)
        T.expectKnown(self, RECIPES, "reading Cisterns for Kentucky", marked(PAMPHLET_RECIPES))
    end,
})

-- Queues giving the character a `fullType`, as self.items[label], and choosing Research from its
-- right-click menu, noting in self.offered whether the menu offered it; `name` names the item.
local function research(self, label, fullType, name)
    T.give(self, label, { { type = fullType } })
    T.step(function()
        local context = T.inventoryMenu(self.items[label][1])
        if not T.need(self, context, "the " .. name .. "'s right-click menu") then return end
        local option = T.findNamed(context, getText("ContextMenu_ResearchCraft"))
        self.offered = T.offered(option)
        if self.offered then
            T.choose(option)
        end
        context:hideAndChildren()
    end)
end

-- A potter at the research level of Shape Filter Crock right-clicks a Clay Jar, which vanilla's
-- script doesn't make researchable, and Research teaches the crock's three recipes, on both sides,
-- and nothing else. Catches the jar's research added on one side only, or not at all.
test("irrigation_learning_researching_a_clay_jar_teaches_the_crock", {
    instant = true,
    hour = 12,
    run = function(self)
        T.knowRecipes(self, RECIPES, false)
        T.setPerk(self, Perks.Pottery, 3)
        research(self, "jar", "Base.ClayJar", "Clay Jar")
        T.waitForKnown(self, RECIPES, marked(CROCK))
    end,
    validate = function(self)
        expect(self.offered, "the Clay Jar's menu offers no Research")
        T.expectKnown(self, RECIPES, "researching a Clay Jar", marked(CROCK))
    end,
})

-- A character at the research level of both boilers (Masonry for the stone firebox, MetalWelding
-- for the welded) researches a Metal Drum, which vanilla's script doesn't make researchable, and
-- learns both boilers, on both sides, and nothing else. Catches the drum's research added on one
-- side only, or not at all.
test("irrigation_learning_researching_a_metal_drum_teaches_the_boilers", {
    instant = true,
    hour = 12,
    run = function(self)
        T.knowRecipes(self, RECIPES, false)
        T.setPerk(self, Perks.Masonry, 1)
        T.setPerk(self, Perks.MetalWelding, 2)
        research(self, "drum", "Base.MetalDrum", "Metal Drum")
        T.waitForKnown(self, RECIPES, marked(BOILERS))
    end,
    validate = function(self)
        expect(self.offered, "the Metal Drum's menu offers no Research")
        T.expectKnown(self, RECIPES, "researching a Metal Drum", marked(BOILERS))
    end,
})

-- For each perk and level the recipes' AutoLearn skills name, a character who knows none of them
-- levels that perk up to that level, every other at 0, and then knows exactly the recipes whose
-- AutoLearn it meets, on both sides: vanilla's AutoLearn teaches Plumb to Tank, a craftRecipe, and
-- the mod's LevelPerk hook the builds, since vanilla's skips build recipes. Catches a recipe taught
-- a level early or never, or taught on one side only.
test("irrigation_learning_level_up_teaches_at_the_auto_learn_level", {
    timeoutSeconds = 135,
    run = function(self)
        local rows = T.autoLearnLevels(RECIPES)
        if not T.need(self, #rows > 0, "an AutoLearn skill on " .. table.concat(RECIPES, " or ")) then return end
        self.rows, self.results = rows, {}
        for i, row in ipairs(rows) do
            -- Each row starts knowing none; the end of the test puts back what was known before.
            T.knowRecipes(self, RECIPES, false)
            T.levelUp(self, row.perk, T.autoLearnLevelsWith(rows, row.perk, row.level - 1))
            T.waitForKnown(self, RECIPES, T.autoLearnedAt(RECIPES, row.perk, row.level))
            T.step(function()
                self.results[i] = { up = self.server["PZHarness.levelUp"] or {}, known = self.known }
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
            T.expectKnown(self, RECIPES, what, T.autoLearnedAt(RECIPES, row.perk, row.level))
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
        local rows, highest = T.autoLearnLevels(RECIPES)
        if not T.need(self, highest, "an AutoLearn skill on " .. table.concat(RECIPES, " or ")) then return end
        self.highest = highest
        T.knowRecipes(self, RECIPES, false)
        T.setLevelsQuietly(self, T.autoLearnLevelsWith(rows, highest.perk, highest.level), RECIPES)
        T.step(function() sendClientCommand(T.player(), Recipes.COMMAND_MODULE, Recipes.CATCH_UP, {}) end)
        T.waitForKnown(self, RECIPES, T.autoLearnedAt(RECIPES, highest.perk, highest.level))
    end,
    validate = function(self)
        local before = self.server["PZHarness.setLevelsQuietly"] or {}
        local knewAny = not before.known
        for _, name in ipairs(RECIPES) do
            knewAny = knewAny or before.known[name] == true
        end
        expect(not knewAny, "setting the levels alone taught the server a recipe, so the catch-up is untested")
        local highest = self.highest
        T.expectKnown(self, RECIPES, "joining at " .. highest.perk .. " " .. highest.level,
            T.autoLearnedAt(RECIPES, highest.perk, highest.level))
    end,
})

-- Lists ---------------------------------------------------------------------------------------------

-- The panel field `field` (handCraftPanel) of the open entity window that has one.
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

-- The pamphlet's own recipe list (its right-click "Show Known Recipes") names each recipe it
-- teaches, and picking Plumb to Tank opens the crafting window on it, which can't craft it, then or
-- once the window has refreshed as it does when the inventory changes (ISHandCraftPanel:update,
-- drawDirty).
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
            local context = T.inventoryMenu(self.items.pamphlet[1])
            if not T.need(self, context, "the pamphlet's right-click menu") then return end
            local plumb = T.findNamed(context, Translator.getRecipeName(PLUMB))
            self.unlisted = {}
            for _, name in ipairs(PAMPHLET_RECIPES) do
                if not T.findNamed(context, Translator.getRecipeName(name)) then
                    table.insert(self.unlisted, name)
                end
            end
            self.listsPlumb = plumb ~= nil
            if plumb then
                T.choose(plumb)
            end
            context:hideAndChildren()
            self.opened = openPanel("handCraftPanel") ~= nil
            self.craftableAtOnce = craftable()
        end)
        T.step(function()
            -- The window refreshes only once its throttle (updateTimer, ten UI updates for a long
            -- recipe list) has run down; zeroed, it refreshes on its next update.
            local panel = openPanel("handCraftPanel")
            if panel then panel.updateTimer = 0 end
            ISHandCraftPanel.drawDirty = true
        end)
        T.waitFor(self, function() return not ISHandCraftPanel.drawDirty end, "the crafting window to refresh")
        T.step(function() self.craftableLater = craftable() end)
    end,
    validate = function(self)
        expect(self.unlisted and #self.unlisted == 0,
            "the pamphlet's recipe list doesn't name " .. table.concat(self.unlisted or PAMPHLET_RECIPES, ", "))
        expect(self.listsPlumb, "the pamphlet's recipe list doesn't name " .. PLUMB)
        expect(not self.listsPlumb or self.opened, "picking Plumb to Tank in the pamphlet's list opened no crafting window")
        expect(not self.craftableAtOnce, "the crafting window the pamphlet opened can craft Plumb to Tank")
        expect(not self.craftableLater, "the crafting window the pamphlet opened can craft Plumb to Tank once refreshed")
    end,
})

-- Loot ----------------------------------------------------------------------------------------------

-- Each item of the server's Distributions.LOOT sits once in each list it names for the item, as
-- loaded and at each value of its option, at its weight times the option, and nowhere at 0.
T.serverCheck("irrigation_loot_items_in_their_lists_scaled_by_the_option", "learning.lootLists",
    { multipliers = { 2.5, 0, 1 } })

-- Each of those lists hands its item out through the game's own roll.
T.serverCheck("irrigation_loot_items_roll_from_each_list", "learning.lootRolls", { fills = 100 })
