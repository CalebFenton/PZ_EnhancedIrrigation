-- Hooks of the mod's recipes. Shared: the crafting window that reads OnAddToMenu is the client's,
-- and every side reads its own scripts and learns by level (RecipeLearning).

local RecipeLearning = require "cf_commonlib/RecipeLearning"

EnhancedIrrigation = EnhancedIrrigation or {}
local Recipes = {}
EnhancedIrrigation.Recipes = Recipes

-- The mod's craftRecipes and build recipes are learned by their AutoLearn skills, which vanilla
-- checks for no build recipe.
RecipeLearning.register("EnhancedIrrigation_")

-- Vanilla items that teach the mod's recipes when researched, by full type: what a player who
-- handles one could work out from it. A vanilla item's script can't be edited in place, so the
-- recipes are added to its ResearchableRecipes as the mod loads (addResearch).
Recipes.RESEARCH = {
    -- A potter who studies a jar sees how to throw a porous one.
    ["Base.ClayJar"] = { "EnhancedIrrigation_ShapeFilterCrock", "EnhancedIrrigation_FireFilterCrock",
        "EnhancedIrrigation_FilterCrock" },
    -- A drum is half a boiler: whoever studies one sees how to set it over a fire, in brick or plate,
    -- as far as their skill reaches.
    ["Base.MetalDrum"] = { "EnhancedIrrigation_BoilerStone", "EnhancedIrrigation_BoilerWelded" },
}

--- Adds RESEARCH to the vanilla items' scripts through their own parser (Item.DoParam), which keeps
--- only recipes that need learning, as a script's own list does. Each side reads its own scripts,
--- and loads them before its Lua, so this runs as the file loads.
local function addResearch()
    for fullType, names in pairs(Recipes.RESEARCH) do
        local item = getScriptManager():getItem(fullType)
        if item then
            item:DoParam("ResearchableRecipes", table.concat(names, ";"))
        end
    end
end

addResearch()

-- OnAddToMenu of the knowledge-only recipes: no crafting window lists them. The window looks the
-- hook up with one rawget on the globals (callLuaBool), so it needs a plain global name.
function EnhancedIrrigation_NeverInMenu()
    return false
end

return Recipes
