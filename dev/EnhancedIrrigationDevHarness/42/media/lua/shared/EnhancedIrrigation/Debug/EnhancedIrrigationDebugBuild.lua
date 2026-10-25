-- Development only, not published. Building one of the mod's tiles as the build menu builds it,
-- for the --art and --promo staging and the QA scenario on the client and the test server's
-- handlers alike; neither side can load the other's files.

require "EnhancedIrrigation/Utilities"

local Build = {}

-- Litres that fill any tank: the fluid container takes no more than it has room for.
Build.FULL = math.huge

--- The object of the tile `sprite` on `square` as the build menu builds one
--- (ISBuildIsoEntity:setInfo): a thumpable with the entity that owns the tile, holding `litres` of
--- water (tainted when `tainted`), without its OnCreate and unsent to the clients. Returns it, or
--- nil and what is missing.
function Build.tile(square, sprite, litres, tainted)
    local script = EnhancedIrrigation.tileEntity(sprite)
    if not script then
        return nil, "the entity of the tile " .. tostring(sprite)
    end
    local thumpable = IsoThumpable.new(getCell(), square, sprite, false, nil)
    GameEntityFactory.CreateIsoObjectEntity(thumpable, script, true)
    if (litres or 0) > 0 then
        thumpable:getFluidContainer():addFluid(tainted and FluidType.TaintedWater or FluidType.Water, litres)
    end
    square:AddSpecialObject(thumpable)
    return thumpable
end

return Build
