-- Water running through a garden line: what its source gives, and what each outlet does with its
-- share. A tapped line runs from the tank its tap draws on for the time Water from Tank holds the
-- tap open; a pumped line from its pump while that runs, which alone pushes hard enough to work a
-- sprinkler.
--
-- A source is { push, perHour, pumped, holds, draw(litres) }: the head it gives every outlet (as
-- storeys of a tank's), the most litres an hour it gives (none for a tank, which gives what its
-- outlets ask), whether a pump drives it, whether it holds water, and the draw that takes up to
-- `litres` from it and answers the litres it gave.

if isClient() then return end

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Tanks"
require "EnhancedIrrigation/Lines/Lines"
require "EnhancedIrrigation/Lines/Sprinklers"
require "EnhancedIrrigation/Lines/Plants"
require "EnhancedIrrigation/Pumps/Pumps"

EnhancedIrrigation = EnhancedIrrigation or {}
local Flow = {}
EnhancedIrrigation.Flow = Flow

local Lines, Tanks, Sprinklers = EnhancedIrrigation.Lines, EnhancedIrrigation.Tanks, EnhancedIrrigation.Sprinklers
local Plants = EnhancedIrrigation.Plants

--- The source of a line tapped on floor `z` from `tank`: the square root of its head (Torricelli),
--- as much as its outlets ask while it holds water, sent to the clients when drawn on.
function Flow.fromTank(tank, z)
    return {
        push = math.sqrt(Tanks.levelOf(tank) - z),
        holds = Tanks.litres(tank) > 0,
        draw = function(litres) return Tanks.take(tank, litres) end,
    }
end

--- The source of a line a pump lifting by `spec` (a row of Pumps.ENTITIES or PARTS) drives: the
--- push and rate of `spec`, and `draw(litres)`, which lifts what the line asks and returns the
--- litres lifted.
function Flow.fromPump(spec, draw)
    return { push = spec.push, perHour = EnhancedIrrigation.Pumps.perHour(spec), pumped = true, holds = true, draw = draw }
end

-- Litres an hour out of the tile `record` from `source`: what its holes give its square, what a
-- crack lets out, and what its sprinkler throws, which only a pump drives. 0 for each where none.
local function ratesOf(record, source)
    local holes = record.holed and Lines.HOLE_RATE * source.push or 0
    local crack = record.cracked and Lines.CRACK_RATE * source.push or 0
    local spray = source.pumped and record.sprinkler and Sprinklers.RATE or 0
    return holes, crack, spray
end

-- The outlets of the line of `tiles` from `source`, and the litres an hour they ask together.
local function outletsOf(tiles, source)
    local outlets, asked = {}, 0
    for _, tile in ipairs(tiles) do
        local holes, crack, spray = ratesOf(tile.state, source)
        if holes + crack + spray > 0 then
            table.insert(outlets, { record = tile.state, holes = holes, crack = crack, spray = spray })
            asked = asked + holes + crack + spray
        end
    end
    return outlets, asked
end

-- The litres an hour `source` gives of `asked`: all of it, or as much as its pump lifts.
local function given(source, asked)
    return source.perHour and math.min(asked, source.perHour) or asked
end

--- The litres an hour the line through the tile `record` takes from `source` while it runs.
function Flow.takesPerHour(record, source)
    local _, asked = outletsOf(Lines.component(record.x, record.y, record.z), source)
    return given(source, asked)
end

-- Gives `litres` to the plant on `record`'s square up to full, the rest to the soil.
local function deliver(record, litres)
    local points = litres * Lines.POINTS_PER_LITRE
    record:addSoak(points - Plants.water(record.x, record.y, record.z, points))
end

-- Throws `litres` from the sprinkler on `record`'s tile: what the air and the paths don't take falls
-- evenly over its squares, each plant taking it up to full and the soil the rest: a line tile's
-- soil on its own record, any other square's on the record keeping its soak. Notes in `touched`
-- the line records it soaked.
local function spray(record, litres, touched)
    local squares = Sprinklers.squaresOf(record.x, record.y, record.z, Lines.recordAt)
    local points = litres * (1 - Sprinklers.LOST) * Lines.POINTS_PER_LITRE / #squares
    for _, square in ipairs(squares) do
        local rest = points - Plants.water(square.x, square.y, record.z, points)
        local line = Lines.recordAt(square.x, square.y, record.z)
        if line then
            line:addSoak(rest)
            touched[line] = true
        else
            touched[record:addSprinklerSoak(square.x, square.y, rest)] = true
        end
    end
end

--- Runs the line through the tile `record` from `source` for `hours` game hours. Its outlets ask
--- their rates together, as much of it as the source gives; a source that gives less than they ask
--- gives each the same fraction of what it asked. The caller checks the source first. Authority
--- only. Returns the litres drawn.
function Flow.run(record, source, hours)
    local tiles = Lines.component(record.x, record.y, record.z)
    for _, tile in ipairs(tiles) do
        tile.state:catchUp()
    end
    local outlets, asked = outletsOf(tiles, source)
    local demand = given(source, asked) * math.max(0, hours)
    local drawn = demand > 0 and source.draw(demand) or 0
    -- A line that takes nothing still fills: water stands in it to the last joint.
    local filled = drawn > 0 or (demand == 0 and hours > 0 and source.holds)
    local touched = {}
    if drawn > 0 then
        local share = drawn / (asked * hours)
        local wetUntil = EnhancedIrrigation.now() + Lines.WET_HOURS
        for _, outlet in ipairs(outlets) do
            deliver(outlet.record, outlet.holes * hours * share)
            if outlet.spray > 0 then
                spray(outlet.record, outlet.spray * hours * share, touched)
            end
            outlet.record.wetUntil = wetUntil
        end
    end
    for _, tile in ipairs(tiles) do
        if filled then
            tile.state.full = true
        end
        touched[tile.state] = nil
        tile.state:afterChange()
    end
    -- Another line's tiles the spray soaked.
    for other in pairs(touched) do
        other:afterChange()
    end
    return drawn
end

return Flow
