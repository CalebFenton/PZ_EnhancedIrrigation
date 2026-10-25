-- Development only. What the --art and --promo modes and the Enhanced Irrigation QA scenario need
-- besides the harness's staging (PZHarness/Stage.lua, PZHarness/StageLots.lua): sowing crops, and
-- the values they share. The mod's tiles are built through EnhancedIrrigationDebugBuild.lua.

local Stage = {}

Stage.VANILLA_WELL = "camping_01_16"
-- Water points of a crop just watered.
Stage.WATERED = 100
-- Fuel enough that a fire burns at its full light radius through every shot: the clock's jump to
-- a night shot burns the hours it skips (IsoFireplace.update counts world hours).
Stage.BOILER_FUEL = 48 * 60

--- A new sprinkler's record fields, as Set Sprinkler fits one.
function Stage.newSprinkler()
    return { condition = 100, ceiling = 100 }
end

--- A crop sown on `square`, then grown to `stage` at full health and `water` water points, its tile
--- set as the farming system's growth sets it. Returns what is missing, or nil. Single player
--- only: SFarmingSystem is the authority's.
function Stage.plant(square, seed, stage, water)
    local farming = SFarmingSystem.instance
    farming:plow(square)
    local crop = farming:getLuaObjectOnSquare(square)
    if not crop then
        return "the plowed furrow's record at " .. square:getX() .. "," .. square:getY()
    end
    crop:seed(seed)
    crop.nbOfGrow = stage
    crop.health = 100
    crop.waterLvl = water
    crop.mildewLvl = 0
    crop:setSpriteName(farming_vegetableconf.getSpriteName(crop))
    crop:saveData()
end

return Stage
