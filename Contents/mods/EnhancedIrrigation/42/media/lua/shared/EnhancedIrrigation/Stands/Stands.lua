-- The Tank Stand, and the rain barrels set on it. A barrel goes up as the moveable vanilla gives
-- when it is picked up, which vanilla allows only while it is empty; on the stand it becomes one
-- tile and entity of stand and barrel together, a tank a storey higher than the floor
-- (EnhancedIrrigation.Tanks). Its lid opens and closes the vanilla way: ISOpenCloseLid swaps the
-- entity named with and without "Closed", which these names follow. Taking it down gives back
-- the same vanilla moveable.

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Sprites"
require "EnhancedIrrigation/Tanks"

EnhancedIrrigation = EnhancedIrrigation or {}
local Stands = {}
EnhancedIrrigation.Stands = Stands

local Sprites = EnhancedIrrigation.Sprites

-- The empty stand's entity, which the build menu builds.
Stands.STAND_ENTITY = "EnhancedIrrigation_TankStand"

-- Each barrel a stand takes: `barrel`, the vanilla tile the barrel stands as on the ground;
-- `entity` and `sprite`, the stand with that barrel on it. Picking the barrel up gives a Moveable
-- made as `item` ("Moveables." .. barrel: vanilla's barrel tiles have no CustomItem, so
-- ISMoveableSpriteProps:instanceItem names it after the tile), but the item it makes is typed
-- "Base." .. barrel (InventoryItemFactory.CreateItem, Moveable.load), so a carried barrel is known
-- by the tile it was picked up from (getWorldSprite), not by its type.
Stands.BARRELS = {
    { barrel = "carpentry_02_122", entity = "EnhancedIrrigation_RaisedBarrel", sprite = Sprites.RAISED_BARREL },
    { barrel = "carpentry_02_126", entity = "EnhancedIrrigation_RaisedBarrelClosed", sprite = Sprites.RAISED_BARREL_CLOSED },
    { barrel = "carpentry_02_124", entity = "EnhancedIrrigation_RaisedBarrel_Tarp", sprite = Sprites.RAISED_BARREL_TARP },
    { barrel = "carpentry_02_127", entity = "EnhancedIrrigation_RaisedBarrel_TarpClosed",
        sprite = Sprites.RAISED_BARREL_TARP_CLOSED },
}

local BY_ENTITY, BY_TILE = {}, {}
for _, spec in ipairs(Stands.BARRELS) do
    spec.item = "Moveables." .. spec.barrel
    BY_ENTITY[spec.entity] = spec
    BY_TILE[spec.barrel] = spec
    EnhancedIrrigation.Tanks.ENTITIES[spec.entity] = { raised = true }
end

--- Whether `isoObject` is an empty Tank Stand.
function Stands.isStand(isoObject)
    return EnhancedIrrigation.entityName(isoObject) == Stands.STAND_ENTITY
end

--- The BARRELS entry of the raised barrel `isoObject`, or nil for anything else.
function Stands.raisedSpec(isoObject)
    return EnhancedIrrigation.entitySpec(isoObject, BY_ENTITY)
end

function Stands.isRaised(isoObject)
    return Stands.raisedSpec(isoObject) ~= nil
end

--- The BARRELS entry of the barrel moveable `item`, or nil for any other item.
function Stands.barrelSpec(item)
    return item and instanceof(item, "Moveable") and BY_TILE[item:getWorldSprite()] or nil
end

--- Whether the barrel moveable `item` holds nothing. Vanilla's pickup moves the barrel's water
--- container onto the item (GameEntityFactory.TransferComponents), and refuses while it holds
--- anything, so a barrel goes up empty and is filled where it stands.
function Stands.isEmptyBarrel(item)
    local fluid = item:getFluidContainer()
    return fluid == nil or fluid:isEmpty()
end

--- The barrel moveables `character` carries, bags included, one of each kind, an empty one where
--- there is one: a list in BARRELS order of { spec, item }.
function Stands.barrelsCarried(character)
    local found = {}
    local inventory = character:getInventory()
    for _, spec in ipairs(Stands.BARRELS) do
        local items = inventory:getAllEvalRecurse(function(item)
            return Stands.barrelSpec(item) == spec
        end, ArrayList.new())
        local pick
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            if not pick or (Stands.isEmptyBarrel(item) and not Stands.isEmptyBarrel(pick)) then
                pick = item
            end
        end
        if pick then
            table.insert(found, { spec = spec, item = pick })
        end
    end
    return found
end

return Stands
