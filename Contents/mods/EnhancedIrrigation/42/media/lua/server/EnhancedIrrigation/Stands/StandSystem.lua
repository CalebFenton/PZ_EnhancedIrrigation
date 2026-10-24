-- The authority's side of the Tank Stand jobs: setting a barrel on a stand and taking it down swap
-- the object on the square, as vanilla's lid action swaps a barrel (ISOpenCloseLid:complete): the
-- old object goes, and a new one of the other entity comes in its place, sent whole to the clients
-- (IsoGridSquare.addWorkstationEntity), keeping the old one's health.

if isClient() then return end

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Materials"
require "EnhancedIrrigation/Sprites"
require "EnhancedIrrigation/Jobs"
require "EnhancedIrrigation/Stands/Stands"
require "EnhancedIrrigation/Stands/StandJobs"

EnhancedIrrigation = EnhancedIrrigation or {}
local StandSystem = {}
EnhancedIrrigation.StandSystem = StandSystem

local Sprites, Stands, StandJobs = EnhancedIrrigation.Sprites, EnhancedIrrigation.Stands, EnhancedIrrigation.StandJobs

-- Replaces `object` with a new object of the entity `entity` on the tile `sprite`, as hurt as the
-- old one was. Returns the new object.
local function replace(object, entity, sprite)
    local square = object:getSquare()
    local health, maxHealth = object:getHealth(), object:getMaxHealth()
    square:transmitRemoveItemFromSquare(object)
    local replacement = square:addWorkstationEntity(entity, sprite)
    replacement:setMaxHealth(maxHealth)
    replacement:setHealth(health)
    return replacement
end

--- The barrel moveable vanilla's pickup would give for the barrel of `spec` (a Stands.BARRELS
--- entry): the item named after its tile (ISMoveableSpriteProps:instanceItem, which reads the
--- tile's name and weight), carrying the components a new barrel of that tile has, which pickup
--- moves from the barrel onto the item and placing it moves back (GameEntityFactory
--- .TransferComponents). The water container among them is empty.
function StandSystem.barrelItem(spec, square)
    local item = instanceItem(spec.item)
    local fresh = IsoThumpable.new(getCell(), square, spec.barrel, false, nil)
    GameEntityFactory.CreateIsoObjectEntity(fresh, EnhancedIrrigation.tileEntity(spec.barrel), true)
    GameEntityFactory.TransferComponents(fresh, item)
    return item
end

-- What each job does at the stand `object`; Set Barrel's `with` is the barrel.
local DO = {
    [StandJobs.SET_BARREL] = function(character, stand, barrel)
        local spec = Stands.barrelSpec(barrel)
        EnhancedIrrigation.Materials.takeItem(character, barrel)
        replace(stand, spec.entity, spec.sprite)
    end,
    [StandJobs.TAKE_DOWN] = function(character, raised)
        local spec = Stands.raisedSpec(raised)
        local item = StandSystem.barrelItem(spec, raised:getSquare())
        replace(raised, Stands.STAND_ENTITY, Sprites.STAND)
        EnhancedIrrigation.Materials.giveItems(character, item)
    end,
}

--- Does `job` at `object` for `character` on the authority (Jobs.perform). Returns whether
--- it was done.
function StandSystem.perform(character, job, object, with)
    return EnhancedIrrigation.Jobs.perform(StandJobs, DO, character, job, object, with)
end

return StandSystem
