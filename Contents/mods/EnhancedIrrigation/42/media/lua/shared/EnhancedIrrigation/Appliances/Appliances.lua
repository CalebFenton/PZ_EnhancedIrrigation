-- Washing machines, washer-dryers and dishwashers as the source of an Appliance Pump
-- (ApplianceJobs' Salvage Pump), and what salvaging does to them: a stripped appliance is marked in
-- its modData's movableData, the one part of it vanilla carries through a pick-up and put-down
-- (ISMoveableSpriteProps), and won't switch on again. Vanilla's switches are timed actions whose
-- complete() runs on the authority, which never asks isValid() in multiplayer, so both are guarded
-- here, on every side.

require "TimedActions/ISToggleClothingWasher"
require "TimedActions/ISToggleComboWasherDryer"

EnhancedIrrigation = EnhancedIrrigation or {}
local Appliances = {}
EnhancedIrrigation.Appliances = Appliances

-- The tiles of the appliances with a pump inside: vanilla's washer-dryers and washers
-- (appliances_laundry_01_0..7) and dishwashers (appliances_cooking_01_72..79). Dryers have none.
Appliances.SPRITES = {}
for i = 0, 7 do
    Appliances.SPRITES["appliances_laundry_01_" .. i] = true
    Appliances.SPRITES["appliances_cooking_01_" .. (72 + i)] = true
end

-- The key of the stripped mark in an appliance's movableData.
Appliances.STRIPPED = "EnhancedIrrigation_stripped"

--- Whether `object` is an appliance with a pump inside, stripped or not.
function Appliances.hasPumpTile(object)
    local sprite = object:getSprite()
    return sprite ~= nil and Appliances.SPRITES[sprite:getName()] == true
end

--- Whether `object`'s pump has been salvaged.
function Appliances.isStripped(object)
    local movable = object:getModData().movableData
    return type(movable) == "table" and movable[Appliances.STRIPPED] == true
end

--- Marks `object` stripped, switched off if it was running, and tells the clients. Authority only.
function Appliances.strip(object)
    local modData = object:getModData()
    modData.movableData = type(modData.movableData) == "table" and modData.movableData or {}
    modData.movableData[Appliances.STRIPPED] = true
    object:transmitModData()
    local combo = instanceof(object, "IsoCombinationWasherDryer")
    if (combo or instanceof(object, "IsoClothingWasher")) and object:isActivated() then
        object:setActivated(false)
        -- A washer-dryer carries its switch as the change of the mode it is in, and ignores the
        -- other's (ISToggleComboWasherDryer).
        object:sendObjectChange((combo and object:isModeDryer()) and IsoObjectChange.DRYER_STATE
            or IsoObjectChange.WASHER_STATE)
    end
end

--- Whether a switch on `object` would turn a stripped appliance on, which it can't.
function Appliances.refusesSwitchOn(object)
    return object ~= nil and not object:isActivated() and Appliances.isStripped(object)
end

-- Vanilla's switches -----------------------------------------------------------------------------------

local function guard(Action)
    local isValid, complete = Action.isValid, Action.complete
    function Action:isValid()
        return not Appliances.refusesSwitchOn(self.object) and isValid(self)
    end
    function Action:complete()
        if Appliances.refusesSwitchOn(self.object) then
            return false
        end
        return complete(self)
    end
end

guard(ISToggleClothingWasher)
guard(ISToggleComboWasherDryer)

return Appliances
