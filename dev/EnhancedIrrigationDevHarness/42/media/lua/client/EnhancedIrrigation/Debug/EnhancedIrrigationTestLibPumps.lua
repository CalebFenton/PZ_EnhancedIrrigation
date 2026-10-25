require "EnhancedIrrigation/Debug/EnhancedIrrigationTestLib"
require "EnhancedIrrigation/Sprites"
require "EnhancedIrrigation/Links/Links"
require "EnhancedIrrigation/Pumps/Pumps"

-- Development only, not published. The pump and Pump House helpers of the mod's test library
-- (EnhancedIrrigationTestLib).

local T = EnhancedIrrigationTest

local Sprites = EnhancedIrrigation.Sprites
local Pumps = EnhancedIrrigation.Pumps

-- The tile of each pump entity: the hand pumps and the Pump Houses.
T.PUMP_SPRITES = {
    EnhancedIrrigation_WoodenHandPump = Sprites.WOODEN_HAND_PUMP,
    EnhancedIrrigation_IronHandPump = Sprites.IRON_HAND_PUMP,
    EnhancedIrrigation_PumpHouseWood = Sprites.PUMP_HOUSE_WOOD,
    EnhancedIrrigation_PumpHouseMetal = Sprites.PUMP_HOUSE_METAL,
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
--- given, and a wait for this client's copy and its summary. Returns its handle, with `spec`
--- (Pumps.ENTITIES, nil for a Pump House).
function T.placePump(self, handle, entity, with)
    local pump = { x = handle.x, y = handle.y, z = handle.z, sprite = T.PUMP_SPRITES[entity],
        spec = Pumps.ENTITIES[entity], square = handle.square }
    T.server(self, "pumps.place", T.at(pump, { sprite = pump.sprite, part = with and with.part,
        fields = with and with.fields }))
    T.waitFor(self, function() return T.pumpSummary(pump) ~= nil end, "this client's copy of the " .. entity)
    return pump
end

--- Queues plumbing the outlet of the pump at `pump` to the tank or line tile at `tank` on the
--- server, with `fields` set on its record, and a wait for this client to know of the link and,
--- when `fields.seal` is given, for its summary to have that seal.
function T.linkPump(self, pump, tank, fields)
    T.server(self, "pumps.link", T.at(pump, { tank = T.at(tank), fields = fields }))
    T.waitFor(self, function()
        if EnhancedIrrigation.Links.roleAt(T.at(pump), "pump") == nil then
            return false
        end
        local summary = fields and fields.seal and T.pumpSummary(pump)
        return not (fields and fields.seal) or (summary and summary.seal == fields.seal)
    end, "this client's copy of the pump's outlet")
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

--- The args of a server handler at the house, with the tank, generator and crop squares to read.
function T.pumpHouseAt(house, extra)
    return T.at(house, {
        tank = extra and extra.tank and T.at(extra.tank) or nil,
        generator = extra and extra.generator and T.at(extra.generator) or nil,
        squares = extra and extra.squares and T.tiles(extra.squares) or nil,
        water = extra and extra.water,
        hoursAgo = extra and extra.hoursAgo,
        fields = extra and extra.fields,
    })
end

--- Queues the house's ten-minute pass on the server, `extra.hoursAgo` hours after its last, with
--- `extra.fields` set first and the crops on `extra.squares` set to `extra.water`, into
--- self.reads[label] ({ now, before, after }).
function T.updatePumpHouse(self, house, label, extra)
    T.read(self, "pumpHouse.update", T.pumpHouseAt(house, extra), label)
end

function T.readPumpHouseUntil(self, house, label, done)
    T.readUntil(self, "pumpHouse.state", T.pumpHouseAt(house), label, done)
end

--- The litres `part` lifts in `hours`.
function T.pumpLifts(part, hours)
    return Pumps.perHour(Pumps.PARTS[part]) * hours
end

return T
