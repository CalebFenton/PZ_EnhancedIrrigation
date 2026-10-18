require "EnhancedIrrigation/Debug/EnhancedIrrigationTestLib"
require "EnhancedIrrigation/Tanks"
require "EnhancedIrrigation/Links"

-- Development only, not published. Fixtures of the tank tests (EnhancedIrrigationTestsTanks.lua),
-- added to EnhancedIrrigationTest; the tanks themselves are T.placeTank's
-- (EnhancedIrrigationTestLib.lua). The server handlers (EnhancedIrrigationTestServerTanks.lua)
-- read and drive stands, tanks and links by square. ISBuildIsoEntity is server Lua, which loads
-- after this file, so T.buildFromMenu reaches it at call time rather than through a require.

local T = EnhancedIrrigationTest
local Links, Tanks = EnhancedIrrigation.Links, EnhancedIrrigation.Tanks

--- This client's copy of the object drawn as `sprite` (the handle's own unless given) on the
--- handle's square, or nil.
function T.tankCopy(handle, sprite)
    return T.objectWithSprite(getSquare(handle.x, handle.y, handle.z), sprite or handle.sprite)
end

--- The links this client knows of with an end on the handle's square.
function T.clientLinks(handle)
    return Links.linksAt(T.at(handle))
end

--- This client's level of the tank on the handle's square, or nil without one.
function T.clientLevel(handle)
    local tank = Tanks.tankOn(getSquare(handle.x, handle.y, handle.z))
    return tank and Tanks.levelOf(tank) or nil
end

-- The build menu entry of `entity` (a game entity script's full name), or nil.
local function buildEntry(entity)
    local script = getScriptManager():getGameEntityScript(entity)
    local spriteConfig = script and script:getComponentScriptFor(ComponentType.SpriteConfig)
    local infos = SpriteConfigManager.GetObjectInfoList()
    for i = 0, infos:size() - 1 do
        if spriteConfig and infos:get(i):getScript() == spriteConfig then
            return infos:get(i)
        end
    end
    return nil
end

--- Queues building `entity` (a full name) from the build menu at `handle`, through the build
--- menu's own path (ISBuildIsoEntity, ISBuildAction): the character gets the recipe's skill levels
--- and knowledge and exactly its inputs, and the build waits for this client's copy of the tile
--- `sprite`. Whether the build menu could build it lands in self.canBuild and self.validSquare.
--- Returns the built tile's handle, or nil.
function T.buildFromMenu(self, entity, handle, sprite)
    local info = T.need(self, buildEntry(entity), "the build menu entry of " .. entity)
    local recipe = info and info:getRecipe() and info:getRecipe():getCraftRecipe()
    if not T.need(self, recipe, "the build recipe of " .. entity) then return nil end
    local built = T.at(handle, { square = handle.square, sprite = sprite })
    for i = 0, recipe:getRequiredSkillCount() - 1 do
        local skill = recipe:getRequiredSkill(i)
        T.setPerk(self, skill:getPerk(), skill:getLevel())
    end
    T.knowRecipes(self, { recipe:getName() }, true)
    local inputs, unmatched = T.recipeInputs(recipe)
    if not T.need(self, #unmatched == 0, "an item for " .. table.concat(unmatched, "; ")) then return nil end
    T.give(self, "materials", inputs)
    T.server(self, "tanks.track", T.at(handle))
    T.step(function()
        local player = T.player()
        T.standNextTo(handle.square)
        local build = ISBuildIsoEntity:new(player, info, 1, ISInventoryPaneContextMenu.getContainers(player))
        -- What the build panel does before the cursor can build (ISBuildPanel): the player number
        -- the drag sets (IsoCell.setDrag), and the recipe's inputs picked from what is carried.
        build.player = player:getPlayerNum()
        build.buildPanelLogic:refresh()
        build.buildPanelLogic:autoPopulateInputs()
        self.canBuild = build.buildPanelLogic:canPerformCurrentRecipe()
        self.validSquare = build:isValid(handle.square)
        build:tryBuild(handle.x, handle.y, handle.z)
    end)
    T.waitFor(self, function() return T.tankCopy(built) ~= nil end, "this client's copy of the built " .. entity)
    return built
end

return T
