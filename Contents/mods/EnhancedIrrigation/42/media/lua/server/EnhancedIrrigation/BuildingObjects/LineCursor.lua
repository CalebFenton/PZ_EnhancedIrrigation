-- The Lay Line cursor: each valid click queues one Lay job, and the cursor stays for the next, as
-- vanilla's ISShovelGroundCursor does. Squares already queued count as line, so a run
-- can be clicked out tile by tile before the first is laid. It lives with the server's Lua, as
-- vanilla's cursors do, because its base class does: client files load first and couldn't derive
-- from it. Every side loads it; only a client uses it.

require "BuildingObjects/ISBuildingObject"
require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Sprites"
require "EnhancedIrrigation/Materials"
require "EnhancedIrrigation/Pipes"
require "EnhancedIrrigation/Lines"
require "EnhancedIrrigation/LineJobs"
require "EnhancedIrrigation/TimedActions/EnhancedIrrigationAction"

EnhancedIrrigation = EnhancedIrrigation or {}

local Sprites = EnhancedIrrigation.Sprites
local Lines = EnhancedIrrigation.Lines
local LineJobs = EnhancedIrrigation.LineJobs
local Pipes = EnhancedIrrigation.Pipes

local LineCursor = ISBuildingObject:derive("EnhancedIrrigation_LineCursor")
EnhancedIrrigation.LineCursor = LineCursor

-- How opaque the ghost is, as vanilla's ground cursors draw theirs.
local GHOST_ALPHA = 0.8
-- How long, in real milliseconds, the cursor keeps the hovered square's refusal: isValid and render
-- ask for it every frame, and it walks the neighbours' whole lines and the inventory.
local REFUSAL_MS = 250

local key = EnhancedIrrigation.squareKey

-- Whether x, y, z already has a tile queued by this cursor and not yet laid. A queue emptied
-- without laying it (the character stopped, or the job was refused) forgets every one.
function LineCursor:isPending(x, y, z)
    local square = self.pending[key(x, y, z)]
    if not square then
        return false
    end
    if not ISTimedActionQueue.hasActionType(self.character, "EnhancedIrrigationAction") then
        self.pending = {}
        return false
    end
    if Lines.lineOn(square) then
        self.pending[key(x, y, z)] = nil
        return false
    end
    return true
end

function LineCursor:pendingCount()
    local count = 0
    for _, square in pairs(self.pending) do
        if self:isPending(square:getX(), square:getY(), square:getZ()) then
            count = count + 1
        end
    end
    return count
end

--- Why a tile can't be laid on `square` now, a Tooltip key, or nil: the square, its neighbours and
--- tanks, and the pipe for it and every tile queued before it.
function LineCursor:refusal(square)
    if not square or self:isPending(square:getX(), square:getY(), square:getZ()) then
        return "Tooltip_EnhancedIrrigation_CantLayHere"
    end
    local blocker = LineJobs.layBlocker(square, function(px, py, pz) return self:isPending(px, py, pz) end)
    local needs = EnhancedIrrigation.Materials.needs(self.character, Pipes.layMaterials(self.kind, self:pendingCount() + 1))
    return EnhancedIrrigation.refusal(blocker, needs)
end

-- The line tiles this side knows, which a tile laid or taken up anywhere changes.
local function lineCount()
    local system = Lines.clientSystem
    return system and system.system:getObjectCount() or 0
end

-- LineCursor:refusal for the hovered `square`, asked again only when the square, the tiles queued
-- or the line tiles known change, or REFUSAL_MS after it last was: what else it reads (tanks, the
-- inventory, a tap) shows within that.
function LineCursor:hoverRefusal(square)
    local cache, now = self.refusalCache, getTimestampMs()
    local pending, lines = self:pendingCount(), lineCount()
    if cache.square ~= square or cache.pending ~= pending or cache.lines ~= lines or now - cache.atMs >= REFUSAL_MS then
        cache.refusal = self:refusal(square)
        cache.square, cache.pending, cache.lines, cache.atMs = square, pending, lines, now
    end
    return cache.refusal
end

function LineCursor:isValid(square)
    return self:hoverRefusal(square) == nil
end

function LineCursor:render(x, y, z, square)
    local isLineAt = function(lx, ly, lz)
        return Lines.stateAt(lx, ly, lz) ~= nil or Lines.lineAt(lx, ly, lz) ~= nil or self:isPending(lx, ly, lz)
    end
    local name = Sprites.pipe(self.kind, false, Lines.shapeAt(x, y, z, isLineAt))
    if not self.ghost then
        self.ghost = IsoSprite.new()
    end
    if self.ghostName ~= name then
        self.ghost:LoadSingleTexture(name)
        self.ghostName = name
    end
    local colour = self:isValid(square) and getCore():getGoodHighlitedColor() or getCore():getBadHighlitedColor()
    self.ghost:RenderGhostTileColor(x, y, z, colour:getR(), colour:getG(), colour:getB(), GHOST_ALPHA)
end

-- One click: the job walks the character there and lays the tile (EnhancedIrrigationAction).
function LineCursor:create(x, y, z, north, sprite)
    local square = getCell():getGridSquare(x, y, z)
    local floor = square and square:getFloor()
    if not floor then
        return
    end
    self.pending[key(x, y, z)] = square
    EnhancedIrrigationAction.queue(self.player, "line", LineJobs.LAY, floor, self.kind)
end

--- A cursor laying `kind` pipe for `character`.
function LineCursor:new(character, kind)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o:init()
    local sprite = Sprites.pipe(kind, false, 0)
    o:setSprite(sprite)
    o:setNorthSprite(sprite)
    o.character = character
    o.player = character:getPlayerNum()
    o.kind = kind
    o.pending = {}
    o.refusalCache = { atMs = -math.huge }
    o.noNeedHammer = true
    o.skipBuildAction = true
    -- The job walks there itself (EnhancedIrrigationAction.queue).
    o.skipWalk2 = true
    return o
end

function LineCursor.start(playerNum, kind)
    local character = getSpecificPlayer(playerNum)
    getCell():setDrag(LineCursor:new(character, kind), playerNum)
end

return LineCursor
