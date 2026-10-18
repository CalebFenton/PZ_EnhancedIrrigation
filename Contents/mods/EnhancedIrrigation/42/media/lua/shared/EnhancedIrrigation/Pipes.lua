-- The pipe the mod lays and plumbs with: Plastic, Iron and Lead Pipe, and fired Clay Pipe Segments,
-- two to a length. Plastic, lead and clay are pipe vanilla's recipes hardly want; iron is
-- contested, an input to about 25 vanilla recipes and a weapon besides. Each length is joined to the
-- next with what holds that material: glue, epoxy or tape for plastic, cement for clay, the pipe
-- wrench alone for threaded iron and soft lead.

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Sprites"
require "EnhancedIrrigation/Materials"

EnhancedIrrigation = EnhancedIrrigation or {}
local Pipes = {}
EnhancedIrrigation.Pipes = Pipes

local Materials = EnhancedIrrigation.Materials

Pipes.WRENCH = { tool = "PIPE_WRENCH", item = "Base.PipeWrench" }
-- What holds plastic: one use patches a crack in any pipe, and each length's joint takes one
-- (Pipes.materials).
Pipes.GLUE = { tags = { "GLUE", "EPOXY", "TAPE" }, uses = 1, labelKey = "IGUI_EnhancedIrrigation_GlueOrTape" }

-- Each material's frostPerHour is the cracks a winter a 24-tile line left full outdoors should
-- expect, spread over the line's tile-hours of hard freeze in a winter of the game's own climate
-- (docs/research.md): target cracks / (tiles x hard-freeze hours). Rare in flexible plastic and
-- ductile lead, more often in rigid iron and in fired clay, whose saturated pores crack as they
-- freeze. Drip lines left full crack in a freeze, fittings and thin walls first
-- (dripworks.com/blog/how-to-winterize-your-drip-irrigation-system); draining one keeps it whole.
local WINTER_TILE_HOURS = 24 * 600

-- Each material: `item` and `perLength`, what one length of pipe is, and what taking it out gives
-- back; `joint`, the material each length's joint takes, or nil, used up for good; `frostPerHour`,
-- the chance an hour that a full length splits in a hard freeze (Lines.HARD_FREEZE_CELSIUS);
-- `punchCracks`, whether a punched hole may split it; `hardness`, which hole tools get into it
-- (LineJobs.HOLE_TOOLS reach).
Pipes.KINDS = {
    plastic = {
        item = "Base.Pipe", perLength = 1, joint = Pipes.GLUE,
        frostPerHour = 0.3 / WINTER_TILE_HOURS, punchCracks = true, hardness = 1,
    },
    iron = { item = "Base.MetalPipe", perLength = 1, frostPerHour = 1.5 / WINTER_TILE_HOURS, hardness = 3 },
    lead = { item = "Base.LeadPipe", perLength = 1, frostPerHour = 0.5 / WINTER_TILE_HOURS, hardness = 1 },
    clay = {
        item = "Base.ClayPipeSegment", perLength = 2,
        joint = { tags = { "CONCRETE" }, labelKey = "IGUI_EnhancedIrrigation_Cement" },
        frostPerHour = 3 / WINTER_TILE_HOURS, punchCracks = true, hardness = 2,
    },
}
-- The order the menu offers them in: the tiles' order.
Pipes.ORDER = EnhancedIrrigation.Sprites.PIPE_MATERIALS

--- The materials list (EnhancedIrrigation.Materials) of `lengths` lengths of `kind`'s pipe, each
--- with its joint.
function Pipes.materials(kind, lengths)
    local spec = Pipes.KINDS[kind]
    local list = { { item = spec.item, need = spec.perLength * lengths } }
    if spec.joint then
        table.insert(list, { tags = spec.joint.tags, uses = lengths, labelKey = spec.joint.labelKey })
    end
    return list
end

--- The kind a job of `lengths` lengths would use for `character`: the first, in menu order, of
--- which they carry enough with its joints, else, for the menu to list what is short, the one they
--- carry most pipe of. Returns the kind and whether they carry enough.
function Pipes.kindFor(character, lengths)
    for _, kind in ipairs(Pipes.ORDER) do
        if not EnhancedIrrigation.firstUnmet(Materials.needs(character, Pipes.materials(kind, lengths))) then
            return kind, true
        end
    end
    local best, most = Pipes.ORDER[1], 0
    local inventory = character:getInventory()
    for _, kind in ipairs(Pipes.ORDER) do
        local spec = Pipes.KINDS[kind]
        local have = inventory:getCountTypeRecurse(spec.item) / spec.perLength
        if have > most then
            best, most = kind, have
        end
    end
    return best, false
end

--- Gives `character` back `lengths` lengths of `kind`'s pipe taken out: every item they took, the
--- i-th at `conditions[i]` (Materials.conditions), new where the list has none. Authority only.
function Pipes.giveBack(character, kind, lengths, conditions)
    local spec = Pipes.KINDS[kind]
    for i = 1, spec.perLength * lengths do
        local item = instanceItem(spec.item)
        local condition = conditions and conditions[i]
        if condition then
            item:setCondition(math.min(condition, item:getConditionMax()))
        end
        EnhancedIrrigation.giveItems(character, item)
    end
end

return Pipes
