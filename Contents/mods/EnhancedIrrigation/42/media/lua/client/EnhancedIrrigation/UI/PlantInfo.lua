-- Vanilla's plant info window (ISFarmingInfo) gains a "Soil" line below its own when a garden line
-- or a sprinkler has wetted the soil under the plant, read from the line tiles' summaries. Wrapped,
-- not replaced: vanilla's render runs first and sizes the window for its lines, then this adds one.

require "Farming/ISUI/ISFarmingInfo"
require "EnhancedIrrigation/Lines/Sprinklers"

EnhancedIrrigation = EnhancedIrrigation or {}
local PlantInfo = {}
EnhancedIrrigation.PlantInfo = PlantInfo

local Sprinklers = EnhancedIrrigation.Sprinklers

-- Reading wet soil takes the eye vanilla asks before it colours the water level (ISFarmingInfo).
PlantInfo.FARMING_LEVEL = 2

-- Vanilla's margins: text starts this far in, and the window ends this far below its last line.
local LEFT = 13
local RIGHT = 17
local BOTTOM = 8

--- The IG_UI key of the soil word under `plant` (Sprinklers.soilKeyAt), or nil when dry.
function PlantInfo.soilKeyOf(plant)
    local square = plant:getSquare()
    return square and Sprinklers.soilKeyAt(square:getX(), square:getY(), square:getZ()) or nil
end

local vanillaRender = ISFarmingInfo.render

function ISFarmingInfo:render()
    vanillaRender(self)
    -- Vanilla drew nothing and left the window's height as it was, which this line would add to again.
    if not self:isPlantValid() or not self.plant:isAlive() then
        return
    end
    if CFarmingSystem.instance:getXp(self.character) < PlantInfo.FARMING_LEVEL then
        return
    end
    local key = PlantInfo.soilKeyOf(self.plant)
    if not key then
        return
    end
    local y = self:getHeight() - BOTTOM
    -- Vanilla's lines name UIFont.Normal, which build 42 lacks, so they get the default font.
    local fontHeight = getTextManager():getFontHeight(UIFont.Small)
    self:drawText(getText("IGUI_EnhancedIrrigation_Soil") .. " :", LEFT, y, 1, 1, 1, 1, UIFont.Small)
    self:drawTextRight(getText(key), self.width - RIGHT, y, 1, 1, 1, 1, UIFont.Small)
    self:setHeightAndParentHeight(y + fontHeight + 2 + BOTTOM)
end

return PlantInfo
