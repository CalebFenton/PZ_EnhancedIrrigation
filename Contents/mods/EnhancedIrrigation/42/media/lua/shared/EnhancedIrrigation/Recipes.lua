-- Hooks of the mod's recipes (media/scripts/EnhancedIrrigation/Recipes.txt and Entities.txt).
-- Shared: the crafting window that reads OnAddToMenu is the client's, and vanilla's own AutoLearn
-- check runs wherever LevelPerk fires (server/XpSystem/XpUpdate.lua, which every side loads).

EnhancedIrrigation = EnhancedIrrigation or {}
local Recipes = {}
EnhancedIrrigation.Recipes = Recipes

-- The mod's recipes with AutoLearnAny or AutoLearnAll. Vanilla's AutoLearn check
-- (ScriptManager.checkAutoLearn) walks only the craftRecipe scripts, which hold no entity's recipe,
-- so the build recipes' AutoLearn never teaches anything unless the mod asks for it. Plumb to Tank,
-- Salvage Pump, Make Utility Pump, Make Pipe Sprinkler and the crock's wheel and kiln recipes are
-- craftRecipes vanilla checks too; they are here so that a level up that teaches them reaches the
-- client whichever LevelPerk hook runs first.
Recipes.AUTO_LEARN = {
    "EnhancedIrrigation_TankStand", "EnhancedIrrigation_BarrelFilter", "EnhancedIrrigation_BrickFilter",
    "EnhancedIrrigation_PlumbToTank", "EnhancedIrrigation_ShapeFilterCrock", "EnhancedIrrigation_FireFilterCrock",
    "EnhancedIrrigation_FilterCrock", "EnhancedIrrigation_BoilerStone", "EnhancedIrrigation_BoilerWelded",
    "EnhancedIrrigation_WoodenHandPump", "EnhancedIrrigation_IronHandPump", "EnhancedIrrigation_SalvagePump",
    "EnhancedIrrigation_MakeUtilityPump", "EnhancedIrrigation_MakePipeSprinkler",
}

-- Vanilla items that teach the mod's recipes when researched, by full type: what a player who
-- handles one could work out from it. A vanilla item's script can't be edited in place, so the
-- recipes are added to its ResearchableRecipes as the mod loads (Recipes.addResearch).
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
function Recipes.addResearch()
    local scripts = getScriptManager()
    for fullType, names in pairs(Recipes.RESEARCH) do
        local item = scripts:getItem(fullType)
        if item then
            item:DoParam("ResearchableRecipes", table.concat(names, ";"))
        end
    end
end

Recipes.addResearch()

-- The packet field of sendSyncPlayerFields that sends the known recipes (SyncPlayerFieldsPacket).
local SYNC_RECIPES = 1

-- The client command that asks the server to catch a joining character up (Recipes.catchUp).
Recipes.COMMAND_MODULE = "EnhancedIrrigation"
Recipes.CATCH_UP = "catchUpRecipes"

-- Whether `recipe` lists `perk` at `level` among its AutoLearn skills: the level up to it is the one
-- that can teach the recipe.
local function autoLearnsAt(recipe, perk, level)
    for i = 0, recipe:getAutoLearnAnySkillCount() - 1 do
        local skill = recipe:getAutoLearnAnySkill(i)
        if skill:getPerk() == perk and skill:getLevel() == level then
            return true
        end
    end
    for i = 0, recipe:getAutoLearnAllSkillCount() - 1 do
        local skill = recipe:getAutoLearnAllSkill(i)
        if skill:getPerk() == perk and skill:getLevel() == level then
            return true
        end
    end
    return false
end

--- Teaches `character` each of AUTO_LEARN whose AutoLearn skills it has, through the recipe's own
--- check, so the Inventive trait counts as it does for vanilla's recipes. After a level up of
--- `perk` to `level` on a multiplayer server that could have taught one, sends the client its
--- known recipes: the server's level up teaches only its own copy of the character, since the
--- client's copy gets the new level in PlayerXpPacket, which fires no LevelPerk, and learnRecipe
--- sends nothing (ISResearchRecipe sends what it taught the same way).
---@param character IsoGameCharacter
---@param perk PerkFactory.Perk?
---@param level integer?
function Recipes.autoLearn(character, perk, level)
    local scripts = getScriptManager()
    local taught = false
    for _, name in ipairs(Recipes.AUTO_LEARN) do
        local recipe = scripts:getCraftRecipe(name)
        if recipe then
            recipe:checkAutoLearnAnySkills(character)
            recipe:checkAutoLearnAllSkills(character)
            taught = taught or (perk ~= nil and character:isRecipeActuallyKnown(name) and autoLearnsAt(recipe, perk, level))
        end
    end
    if taught and isServer() then
        sendSyncPlayerFields(character, SYNC_RECIPES)
    end
end

local function knownCount(character)
    local count = 0
    for _, name in ipairs(Recipes.AUTO_LEARN) do
        if character:isRecipeActuallyKnown(name) then
            count = count + 1
        end
    end
    return count
end

--- Teaches `character` what its levels already earn, and on a multiplayer server sends its client
--- what that changed. A server runs no check of its own when a player joins (IsoWorld.init checks
--- the local player only, and no event marks a join on the server), so a character who earned a
--- recipe before the mod was added would otherwise know it only on its client, and the server
--- would refuse the build. The client asks for this as it enters the world; the server judges by
--- its own copy's levels.
function Recipes.catchUp(character)
    local before = knownCount(character)
    Recipes.autoLearn(character)
    if isServer() and knownCount(character) ~= before then
        sendSyncPlayerFields(character, SYNC_RECIPES)
    end
end

-- OnAddToMenu of the knowledge-only recipes: no crafting window lists them. The window looks the
-- hook up with one rawget on the globals (callLuaBool), so it needs a plain global name.
function EnhancedIrrigation_NeverInMenu()
    return false
end

-- When vanilla checks its own AutoLearn: on every level up (XpUpdate.levelPerk) and when the
-- local player enters the world (IsoWorld.init), here OnCreatePlayer, which on a multiplayer client
-- also asks the server to catch up.
Events.LevelPerk.Add(function(character, perk, level)
    Recipes.autoLearn(character, perk, level)
end)
Events.OnCreatePlayer.Add(function(playerNum)
    local character = getSpecificPlayer(playerNum)
    Recipes.autoLearn(character)
    if isClient() then
        sendClientCommand(character, Recipes.COMMAND_MODULE, Recipes.CATCH_UP, {})
    end
end)
Events.OnClientCommand.Add(function(module, command, player)
    if module == Recipes.COMMAND_MODULE and command == Recipes.CATCH_UP then
        Recipes.catchUp(player)
    end
end)

return Recipes
