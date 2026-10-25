require "EnhancedIrrigation/Debug/EnhancedIrrigationTestLibLines"
require "EnhancedIrrigation/Sprites"
require "EnhancedIrrigation/Links/Links"
require "EnhancedIrrigation/Pumps/Pumps"

-- Development only, not published. The pump and Pump House helpers of the mod's test library
-- (EnhancedIrrigationTestLib).

local T = EnhancedIrrigationTest

local Sprites = EnhancedIrrigation.Sprites
local Links = EnhancedIrrigation.Links
local Pumps = EnhancedIrrigation.Pumps

-- The hand pumps, the Pump Houses, and the seal the tests fit a hand pump with.
T.WOODEN, T.IRON = "EnhancedIrrigation_WoodenHandPump", "EnhancedIrrigation_IronHandPump"
T.WOOD, T.METAL = "EnhancedIrrigation_PumpHouseWood", "EnhancedIrrigation_PumpHouseMetal"
T.LEATHER = "Base.LeatherStrips"

-- The tile of each pump entity.
T.PUMP_SPRITES = {
    [T.WOODEN] = Sprites.WOODEN_HAND_PUMP,
    [T.IRON] = Sprites.IRON_HAND_PUMP,
    [T.WOOD] = Sprites.PUMP_HOUSE_WOOD,
    [T.METAL] = Sprites.PUMP_HOUSE_METAL,
}

--- This client's summary of the pump at `handle`, or nil.
function T.pumpSummary(handle)
    local copy = T.copyOf(handle)
    return copy and Pumps.summaryOf(copy)
end

--- Queues a wait until this client's summary of the pump at `handle` satisfies `holds(summary)`.
function T.waitForPumpSummary(self, handle, holds, what)
    T.waitFor(self, function()
        local summary = T.pumpSummary(handle)
        return summary ~= nil and holds(summary)
    end, what)
end

--- Queues placing the pump `entity` (a T.PUMP_SPRITES key) at `handle`, with `with.part` fitted
--- as Fit Pump fits it ({ type, condition, ceiling, fraction }) and `with.fields` on its record, if
--- given, and a wait for this client's copy and its summary, with the seal of `with.fields` if
--- given. Returns its handle, with `spec` (Pumps.ENTITIES, nil for a Pump House).
function T.placePump(self, handle, entity, with)
    local pump = { x = handle.x, y = handle.y, z = handle.z, sprite = T.PUMP_SPRITES[entity],
        spec = Pumps.ENTITIES[entity], square = handle.square }
    local seal = with and with.fields and with.fields.seal
    T.server(self, "pumps.place", T.at(pump, { sprite = pump.sprite, part = with and with.part,
        fields = with and with.fields }))
    T.waitForPumpSummary(self, pump, function(summary) return seal == nil or summary.seal == seal end,
        "this client's copy of the " .. entity)
    return pump
end

--- Queues plumbing the outlet of the pump at `pump` to the tank or line tile at `into` on the
--- server, and a wait for this client to know of the link.
function T.linkPump(self, pump, into)
    T.server(self, "pumps.link", T.at(pump, { tank = T.at(into) }))
    T.waitFor(self, function() return Links.roleAt(T.at(pump), "pump") ~= nil end,
        "this client's copy of the pump's outlet")
end

--- Queues the pump `entity` at spots[1], placed with `with` (T.placePump), its source at spots[2]:
--- a T.TANKS `opts.source` (a well unless given) holding `opts.sourceLitres`; and its outlet
--- plumbed to `opts.into`, a tank or line tile already there, or else to a T.TANKS `opts.tank` (a
--- lidded raised barrel unless given) at spots[3] holding `opts.litres`. Returns the pump's, the
--- outlet's and the source's handles.
function T.plumbedPump(self, spots, entity, with, opts)
    opts = opts or {}
    local pump = T.placePump(self, spots[1], entity, with)
    local source = T.placeTank(self, spots[2], opts.source or "well", opts.sourceLitres)
    local into = opts.into or T.placeTank(self, spots[3], opts.tank or "raisedLidded", opts.litres)
    T.linkPump(self, pump, into)
    return pump, into, source
end

--- Queues a holed iron line on `tiles` with a dry crop on each (T.holedLine), and the pump `entity`
--- at spots[1] plumbed to its first tile, its source at spots[2] as T.plumbedPump has it with
--- `opts`. Returns the pump's and the source's handles.
function T.pumpedLine(self, tiles, spots, entity, with, opts)
    T.holedLine(self, tiles, "iron")
    local into = { into = tiles[1] }
    for key, value in pairs(opts or {}) do
        into[key] = value
    end
    local pump, _, source = T.plumbedPump(self, spots, entity, with, into)
    return pump, source
end

--- The args of a pump handler at `pump`, with `extra`'s: the tank, well and generator handles and
--- the crop squares (`squares`) to read, and the `hours`, `fields`, `hoursAgo` and `water` to set.
function T.pumpAt(pump, extra)
    extra = extra or {}
    return T.at(pump, {
        tank = extra.tank and T.at(extra.tank) or nil,
        well = extra.well and T.at(extra.well) or nil,
        generator = extra.generator and T.at(extra.generator) or nil,
        squares = extra.squares and T.tiles(extra.squares) or nil,
        hours = extra.hours,
        fields = extra.fields,
        hoursAgo = extra.hoursAgo,
        water = extra.water,
    })
end

--- Queues the server's view of the pump (pumps.state), with what `extra` reads (T.pumpAt), into
--- self.reads[label].
function T.readPump(self, pump, label, extra)
    T.read(self, "pumps.state", T.pumpAt(pump, extra), label)
end

--- Queues reads of the pump as T.readPump until `done(state)` holds.
function T.readPumpUntil(self, pump, label, done, extra)
    T.readUntil(self, "pumps.state", T.pumpAt(pump, extra), label, done)
end

--- Queues the character working the pump for each of `hours` on the server (pumps.run), with what
--- `extra` reads, into self.reads[label] ({ before, steps }).
function T.runPump(self, pump, label, hours, extra)
    local args = T.pumpAt(pump, extra)
    args.hours = hours
    T.read(self, "pumps.run", args, label)
end

-- Pump Houses ---------------------------------------------------------------------------------------

--- What a house is placed with: `part` (a full type) fitted as Fit Pump fits it, from an item new but
--- for what `item` gives ({ condition, ceiling, fraction } of a point past its condition), then
--- `fields` set on its record.
function T.pumpHouseFitted(part, fields, item)
    local fitting = { type = part }
    for key, value in pairs(item or {}) do
        fitting[key] = value
    end
    return { part = fitting, fields = fields }
end

--- Queues the house's ten-minute pass on the server (pumps.update), `extra.hoursAgo` hours after its
--- last, with `extra.fields` set first and the crops on `extra.squares` set to `extra.water`, into
--- self.reads[label] ({ now, before, after }).
function T.updatePumpHouse(self, house, label, extra)
    T.read(self, "pumps.update", T.pumpAt(house, extra), label)
end

--- The litres `part` lifts in `hours`.
function T.pumpLifts(part, hours)
    return Pumps.perHour(Pumps.PARTS[part]) * hours
end

return T
