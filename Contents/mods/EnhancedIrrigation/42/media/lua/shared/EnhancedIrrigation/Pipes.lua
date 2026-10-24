-- The pipe the mod lays and plumbs with. Plastic, lead and clay are pipe vanilla's recipes hardly
-- want; iron is contested, an input to about 25 vanilla recipes and a weapon besides. Each length
-- is joined to the next with what holds that material; threaded iron and soft lead need only the
-- pipe wrench.

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Materials"
require "EnhancedIrrigation/Sprites"

EnhancedIrrigation = EnhancedIrrigation or {}
local Pipes = {}
EnhancedIrrigation.Pipes = Pipes

Pipes.WRENCH = { tool = "PIPE_WRENCH", item = "Base.PipeWrench" }
-- What holds plastic, which also patches a crack in any pipe: glue, epoxy or duct tape. Named by
-- type, since the game's glue and tape tags also take wood glue and adhesive tape, which hold no
-- water.
Pipes.GLUE = {
    types = { "Base.Glue", "Base.Epoxy", "Base.DuctTape" }, uses = 1, labelKey = "IGUI_EnhancedIrrigation_GlueOrTape",
}

-- Each material's frostPerHour is the cracks a winter a 24-tile line left full outdoors should
-- expect, spread over the line's tile-hours of hard freeze in a winter of the game's own climate
-- (docs/research.md): target cracks / (tiles x hard-freeze hours). Rare in flexible plastic and
-- ductile lead, more often in rigid iron and in fired clay, whose saturated pores crack as they
-- freeze. Drip lines left full crack in a freeze, fittings and thin walls first
-- (dripworks.com/blog/how-to-winterize-your-drip-irrigation-system); draining one keeps it whole.
local WINTER_TILE_HOURS = 24 * 600

-- Each material: `item` and `perLength`, what one length of pipe is, and what taking it out gives
-- back; `joint`, the material each length's joint takes, or nil, used up for good; `wrench`, its
-- lengths are joined with the pipe wrench alone, which laying it needs; `frostPerHour`, the chance
-- an hour that a full length splits in a hard freeze (Lines.HARD_FREEZE_CELSIUS); `punchCracks`,
-- whether a punched hole may split it; `hardness`, which hole tools get into it (LineJobs.HOLE_TOOLS
-- reach).
Pipes.KINDS = {
    plastic = {
        item = "Base.Pipe", perLength = 1, joint = Pipes.GLUE,
        frostPerHour = 0.3 / WINTER_TILE_HOURS, punchCracks = true, hardness = 1,
    },
    iron = {
        item = "Base.MetalPipe", perLength = 1, wrench = true, frostPerHour = 1.5 / WINTER_TILE_HOURS, hardness = 3,
    },
    lead = {
        item = "Base.LeadPipe", perLength = 1, wrench = true, frostPerHour = 0.5 / WINTER_TILE_HOURS, hardness = 1,
    },
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
    local joint = spec.joint
    if joint then
        table.insert(list, { tags = joint.tags, types = joint.types, uses = lengths, labelKey = joint.labelKey })
    end
    return list
end

--- The materials list of laying `lengths` tiles of `kind`'s line: its pipe and joints, and the pipe
--- wrench where that is the joint. Fit Tap and Plumb to Tank take the wrench for any pipe.
function Pipes.layMaterials(kind, lengths)
    local list = Pipes.materials(kind, lengths)
    if Pipes.KINDS[kind].wrench then
        table.insert(list, 1, Pipes.WRENCH)
    end
    return list
end

--- The kinds `character` carries any pipe of, in menu order.
function Pipes.kindsCarried(character)
    local kinds = {}
    for _, kind in ipairs(Pipes.ORDER) do
        if character:getInventory():getCountTypeRecurse(Pipes.KINDS[kind].item) > 0 then
            table.insert(kinds, kind)
        end
    end
    return kinds
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
        EnhancedIrrigation.Materials.giveItems(character, item)
    end
end

return Pipes
