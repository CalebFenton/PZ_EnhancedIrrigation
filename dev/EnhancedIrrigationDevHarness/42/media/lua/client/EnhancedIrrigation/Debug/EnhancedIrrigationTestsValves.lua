require "EnhancedIrrigation/Debug/EnhancedIrrigationTestLib"
require "ISUI/ISInventoryPaneContextMenu"
require "EnhancedIrrigation/Valves"

-- The valves and timers (Valves.lua, Make Wind-up Valve and Make Timer Valve in Recipes.txt):
-- making each, and learning the Timer Valve by researching what it is made from or sold as.

local T = EnhancedIrrigationTest
local expect = T.expect
local Valves = EnhancedIrrigation.Valves

local WIND_UP_RECIPE = "EnhancedIrrigation_MakeWindUpValve"
local TIMER_RECIPE = "EnhancedIrrigation_MakeTimerValve"

-- Making and learning -------------------------------------------------------------------------------

-- Queues the craft of `name` at the work table the scenario sets beside the start, by a character
-- with its skills and exactly a craft's inputs, from the first item of `from`, counting `counted`
-- after.
local function craft(self, name, from, counted)
    local recipe = T.need(self, getScriptManager():getCraftRecipe(name), "the recipe " .. name)
    if not recipe then return end
    T.placeWorkTable(T.player())
    for i = 0, recipe:getRequiredSkillCount() - 1 do
        local skill = recipe:getRequiredSkill(i)
        T.setPerk(self, skill:getPerk(), skill:getLevel())
    end
    local inputs, unmatched = T.recipeInputs(recipe, { "Base.Screwdriver", "Base.Pliers", "Base.PipeWrench" })
    if not T.need(self, #unmatched == 0, "an item for " .. table.concat(unmatched, "; ")) then return end
    T.give(self, "inputs", inputs)
    T.step(function()
        local item = T.need(self, T.player():getInventory():getFirstTypeRecurse(from), "a " .. from)
        if not item then return end
        T.startCraft(self, recipe, item)
        T.count(self, "craft", counted, { dropped = true })
    end)
end

-- Expects the craft to have made one `made`, used up each of `used` and kept each of `kept`.
local function expectCraft(self, made, used, kept)
    local craft = self.counts.craft or {}
    expect(craft[made] == 1, "the craft made " .. tostring(craft[made]) .. " " .. made)
    for _, fullType in ipairs(used) do
        expect(craft[fullType] == 0, "the craft left " .. tostring(craft[fullType]) .. " " .. fullType)
    end
    for _, fullType in ipairs(kept) do
        expect(craft[fullType] == 1, "the craft took the " .. fullType)
    end
end

-- A character who knows no recipe and has no skill makes a Wind-up Valve at a table from a kitchen
-- timer, two screws and a rubber hose, keeping the screwdriver. Catches a recipe the game won't
-- craft for anyone, or one that keeps its parts or eats its tool.
T.test("irrigation_valves_make_wind_up_valve", {
    instant = true,
    run = function(self)
        T.knowRecipes(self, { WIND_UP_RECIPE }, false)
        craft(self, WIND_UP_RECIPE, "Base.Timer",
            { Valves.WIND_UP, "Base.Timer", "Base.Screws", "Base.RubberHose", "Base.Screwdriver" })
    end,
    validate = function(self)
        expectCraft(self, Valves.WIND_UP, { "Base.Timer", "Base.Screws", "Base.RubberHose" }, { "Base.Screwdriver" })
    end,
})

-- Make Timer Valve at a table, with Electricity 2 and the knowledge, makes a Timer Valve from an
-- alarm clock, a Water Valve, two wires and scrap electronics, keeping the screwdriver, pliers and
-- Pipe Wrench. Catches a recipe the game won't craft, or one that keeps its parts or eats a tool.
T.test("irrigation_valves_make_timer_valve", {
    instant = true,
    run = function(self)
        T.knowRecipes(self, { TIMER_RECIPE }, true)
        craft(self, TIMER_RECIPE, Valves.WATER_VALVE, { Valves.TIMER, "Base.AlarmClock2", Valves.WATER_VALVE,
            "Base.ElectricWire", "Base.ElectronicsScrap", "Base.Screwdriver", "Base.Pliers", "Base.PipeWrench" })
    end,
    validate = function(self)
        expectCraft(self, Valves.TIMER, { "Base.AlarmClock2", Valves.WATER_VALVE, "Base.ElectricWire", "Base.ElectronicsScrap" },
            { "Base.Screwdriver", "Base.Pliers", "Base.PipeWrench" })
    end,
})

-- At the research level of Make Timer Valve, researching a Water Valve or a Sprinkler Timer teaches
-- it on both sides. Catches an item that teaches nothing, or teaches on one side only.
for _, case in ipairs({ { name = "water_valve", item = Valves.WATER_VALVE }, { name = "sprinkler_timer", item = Valves.SPRINKLER_TIMER } }) do
    T.test("irrigation_valves_researching_a_" .. case.name .. "_teaches_the_timer_valve", {
        instant = true,
        hour = 12,
        run = function(self)
            T.knowRecipes(self, { TIMER_RECIPE }, false)
            T.setPerk(self, Perks.Electricity, getScriptManager():getCraftRecipe(TIMER_RECIPE):getResearchSkillLevel())
            T.give(self, "item", { { type = case.item } })
            T.step(function()
                local context = ISInventoryPaneContextMenu.createMenu(0, true, { self.items.item[1] }, 0, 0)
                if not T.need(self, type(context) == "table" and context, "the item's right-click menu") then return end
                local research = T.findNamed(context, context, getText("ContextMenu_ResearchCraft"))
                self.offered = T.offered(research)
                if self.offered then
                    T.choose(research)
                end
                context:hideAndChildren()
            end)
            T.serverUntil(self, "learning.known", { names = { TIMER_RECIPE } }, function(reply)
                return reply and reply.known and reply.known[TIMER_RECIPE]
            end)
            T.waitFor(self, function() return T.player():isRecipeActuallyKnown(TIMER_RECIPE) end,
                "this client's copy of the character knowing " .. TIMER_RECIPE)
        end,
        validate = function(self)
            expect(self.offered, "the " .. case.item .. "'s menu offers no Research")
            local known = self.server["learning.known"] and self.server["learning.known"].known
            expect(known and known[TIMER_RECIPE], "researching it didn't teach the server " .. TIMER_RECIPE)
            expect(T.player():isRecipeActuallyKnown(TIMER_RECIPE), "researching it didn't teach this client " .. TIMER_RECIPE)
        end,
    })
end
