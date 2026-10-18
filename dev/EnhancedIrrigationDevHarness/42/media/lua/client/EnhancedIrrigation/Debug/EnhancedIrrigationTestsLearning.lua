require "EnhancedIrrigation/Debug/EnhancedIrrigationTestLib"
require "TimedActions/ISReadABook"
require "ISUI/ISInventoryPaneContextMenu"
require "Entity/ISEntityUI"

-- How the character learns the mod's two recipes, the Tank Stand (a build-menu recipe) and Plumb to
-- Tank (knowledge with nothing to craft, Recipes.txt), and where the pamphlet that teaches them
-- turns up. Reading goes through vanilla's read action, levels through the authority's XP award,
-- which fires LevelPerk; the lists are vanilla's own windows and menus. Each side's copy of the
-- character is checked: the authority's decides the build and the plumbing, this client's the
-- menus. EnhancedIrrigationTestServerLearning.lua holds the server's half.

local T = EnhancedIrrigationTest
local test, expect = T.test, T.expect

local PAMPHLET = "EnhancedIrrigation.CisternsForKentucky"
local STAND, PLUMB = "EnhancedIrrigation_TankStand", "EnhancedIrrigation_PlumbToTank"
local BOTH = { STAND, PLUMB }

-- Knowledge ---------------------------------------------------------------------------------------

-- Which of BOTH this client's copy of the character knows.
local function knownHere()
    local known, p = {}, T.player()
    for _, name in ipairs(BOTH) do
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
    T.serverUntil(self, "learning.known", { names = BOTH }, function(reply) return knowsAll(reply and reply.known) end)
    for name, want in pairs(expected) do
        if want then
            T.waitFor(self, function() return knownHere()[name] end, "this client's copy of the character knowing " .. name)
        end
    end
    T.step(function()
        self.known = { server = self.server["learning.known"].known, client = knownHere() }
    end)
end

-- Expects each side to know exactly the recipes `expected` marks true, of BOTH, after `what`.
local function expectKnown(self, what, expected)
    for side, known in pairs(self.known or {}) do
        for _, name in ipairs(BOTH) do
            local want = expected[name] == true
            expect(known[name] == want, what .. (want and " did not teach " or " taught ") .. name .. " on the " .. side)
        end
    end
end

-- Reading the pamphlet through vanilla's action teaches both recipes, on the authority too, whose
-- copy the build and the plumbing ask.
test("irrigation_learning_reading_the_pamphlet_teaches_both_recipes", {
    instant = true,
    run = function(self)
        T.knowRecipes(self, BOTH, false)
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
        awaitKnown(self, { [STAND] = true, [PLUMB] = true })
    end,
    validate = function(self)
        expectKnown(self, "reading Cisterns for Kentucky", { [STAND] = true, [PLUMB] = true })
    end,
})

-- A character who knows neither recipe levels `perk` from `from` to the next level, the other
-- perk at `others`, and then knows exactly `expected`: Plumb to Tank from Woodwork 4 or
-- MetalWelding 3 (vanilla's AutoLearn of its craftRecipe), the stand from Woodwork 5 (the mod's
-- LevelPerk hook, since vanilla's AutoLearn skips build recipes).
local LEVEL_UPS = {
    { "woodwork_4_teaches_plumb_to_tank_not_the_stand", "Woodwork", 3, { MetalWelding = 0 }, { [PLUMB] = true } },
    { "woodwork_5_teaches_the_stand", "Woodwork", 4, { MetalWelding = 0 }, { [PLUMB] = true, [STAND] = true } },
    { "metal_welding_3_alone_teaches_plumb_to_tank", "MetalWelding", 2, { Woodwork = 0 }, { [PLUMB] = true } },
}
for _, row in ipairs(LEVEL_UPS) do
    local behavior, perk, from, others, expected = row[1], row[2], row[3], row[4], row[5]
    test("irrigation_learning_level_up_" .. behavior, {
        run = function(self)
            T.knowRecipes(self, BOTH, false)
            local levels = { [perk] = from }
            for id, level in pairs(others) do
                levels[id] = level
            end
            T.server(self, "learning.levelUp", { perk = perk, levels = levels, names = BOTH })
            awaitKnown(self, expected)
        end,
        validate = function(self)
            local up = self.server["learning.levelUp"] or {}
            expect(up.before == from and up.after == from + 1,
                perk .. " went from " .. tostring(up.before) .. " to " .. tostring(up.after) .. ", expected " .. from .. " to " .. from + 1)
            expectKnown(self, perk .. " " .. from + 1, expected)
        end,
    })
end

-- A character who reached Woodwork 5 before the mod was added joins a server: the client asks the
-- server to catch up as it enters the world (Recipes.lua's OnCreatePlayer), and the server, which
-- runs no check of its own on a join, teaches both and tells the client.
test("irrigation_learning_joining_server_catches_up_earned_recipes", {
    mpOnly = "single player has one copy of the character, which IsoWorld.init's own check covers",
    run = function(self)
        T.knowRecipes(self, BOTH, false)
        T.server(self, "learning.setLevels", { levels = { Woodwork = 5, MetalWelding = 0 }, names = BOTH })
        T.step(function()
            local Recipes = EnhancedIrrigation.Recipes
            sendClientCommand(T.player(), Recipes.COMMAND_MODULE, Recipes.CATCH_UP, {})
        end)
        awaitKnown(self, { [STAND] = true, [PLUMB] = true })
    end,
    validate = function(self)
        local before = self.server["learning.setLevels"] or {}
        expect(before.known and not before.known[STAND] and not before.known[PLUMB],
            "setting the levels alone taught the server a recipe, so the catch-up is untested")
        expectKnown(self, "joining at Woodwork 5", { [STAND] = true, [PLUMB] = true })
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
        T.knowRecipes(self, BOTH, true)
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

-- The build menu shows the Tank Stand to a character who knows it, searched for too, and never
-- Plumb to Tank.
test("irrigation_learning_build_menu_shows_the_stand_not_plumbing", {
    run = function(self)
        T.knowRecipes(self, BOTH, true)
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
        expectShown(self.default, STAND, true, "the build menu")
        expectShown(self.searched, STAND, true, "the build menu searched for it")
        expectShown(self.default, PLUMB, false, "the build menu")
    end,
})

-- The pamphlet's own recipe list (its right-click "Show Known Recipes") names Plumb to Tank, and
-- picking it opens the crafting window on it, which can't craft it, then or once the window has
-- refreshed as it does when the inventory changes (ISHandCraftPanel:update, drawDirty).
test("irrigation_learning_pamphlet_recipe_list_cannot_craft_plumbing", {
    run = function(self)
        T.knowRecipes(self, BOTH, true)
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
