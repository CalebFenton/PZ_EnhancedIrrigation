-- Tanks plumbed to each other ("Plumb to Tank"): a pipe run out of sight, as vanilla's plumbing
-- runs, between two tanks, through which water finds its level every ten minutes. A link is kept
-- by the two tanks' squares, not on the tanks: the vanilla lid swap replaces a barrel's object and
-- drops its modData, and the tank on the square stays the link's end. The pipe stays buried when a
-- tank leaves its square, and carries water again once a tank stands there. The authority keeps
-- the links in its system, which sends every client the list.
--
-- A link is { a = { x, y, z }, b = { x, y, z }, kind, lengths, conditions }: its ends, the pipe in
-- it (a key of EnhancedIrrigation.Pipes.KINDS and how many lengths), all of which Unplumb gives
-- back, and the condition of each item of that pipe as it went in (Materials.conditions). A link
-- plumbing a fixture, a treatment unit's inlet or outlet, or a pump has that role (ROLE_END) set
-- true; one between two tanks has none.

require "EnhancedIrrigation/Utilities"

EnhancedIrrigation = EnhancedIrrigation or {}
local Links = {}
EnhancedIrrigation.Links = Links

Links.SYSTEM_NAME = "enhanced_irrigation_link"

-- How far apart, in tiles, two plumbed tanks may stand: well past vanilla plumbing's one square,
-- short of a generator's twenty, so tanks plumb across a yard but not across a farm.
Links.MAX_TILES = 10
-- A storey counts as this many tiles of pipe: down the stand or wall and back out.
Links.TILES_PER_STOREY = 2
-- Tiles one length of pipe covers.
Links.TILES_PER_LENGTH = 3
-- Minutes of wrench work at the tanks, and per tile of pipe run between them.
Links.BASE_MINUTES = 10
Links.MINUTES_PER_TILE = 3
-- Litres an hour a link carries at most: a pipe under a barrel's head passes a few litres a
-- minute.
Links.RATE = 360

-- Which end of a link each role's object stands at; the other end is the tank it draws on or fills,
-- or for a pump the tank or garden line tile it lifts into. Saved links keep these ends.
local ROLE_END = { fixture = "b", inlet = "b", outlet = "a", pump = "a" }

--- The tiles of pipe between the squares `a` and `b` ({ x, y, z }): the straight run across,
--- rounded up, and the storeys between them.
function Links.distance(a, b)
    local dx, dy = b.x - a.x, b.y - a.y
    return math.ceil(math.sqrt(dx * dx + dy * dy)) + Links.TILES_PER_STOREY * math.abs(b.z - a.z)
end

function Links.lengthsFor(distance)
    return math.ceil(distance / Links.TILES_PER_LENGTH)
end

--- The game minutes plumbing a run of `distance` tiles takes.
function Links.minutesFor(distance)
    return Links.BASE_MINUTES + Links.MINUTES_PER_TILE * distance
end

--- The square `at`, and for Plumb the pipe `kind` chosen, as a job's `with`: a string, which a
--- multiplayer action's arguments can carry.
function Links.encode(at, kind)
    local key = EnhancedIrrigation.squareKey(at.x, at.y, at.z)
    return kind and key .. "," .. kind or key
end

--- The square { x, y, z } and the pipe kind, or nil without one, that a job's `with` names; nil
--- when it names no square.
function Links.decode(with)
    if type(with) ~= "string" then
        return nil
    end
    local x, y, z, rest = with:match("^(-?%d+),(-?%d+),(-?%d+)(.*)$")
    local kind = rest and rest:match("^,(%a+)$")
    if not x or (rest ~= "" and not kind) then
        return nil
    end
    return { x = tonumber(x), y = tonumber(y), z = tonumber(z) }, kind
end

--- Every link as this side knows it: on the authority its own list, which a job may have changed
--- since the clients last heard, else the list the server last sent.
function Links.all()
    local system = not isClient() and Links.serverSystem or Links.clientSystem
    return system and system.links or {}
end

--- A new link from the square `at` to the square `other`, as plain ends: with `role`, `at` is that
--- role's object and `other` the far end; without, two tanks.
function Links.new(at, other, role)
    local link = { a = { x = at.x, y = at.y, z = at.z }, b = { x = other.x, y = other.y, z = other.z } }
    if role then
        link[role] = true
        if ROLE_END[role] == "b" then
            link.a, link.b = link.b, link.a
        end
    end
    return link
end

--- The role of `link`, a key of ROLE_END, or nil between two tanks.
function Links.roleOf(link)
    for role in pairs(ROLE_END) do
        if link[role] then
            return role
        end
    end
    return nil
end

--- The squares of `link`'s ends: its role's object's, then the far end's; between two tanks, a then b.
function Links.ends(link)
    if ROLE_END[Links.roleOf(link)] == "b" then
        return link.b, link.a
    end
    return link.a, link.b
end

--- The link of `role` whose object stands on the square `at` ({ x, y, z }), or nil.
function Links.roleAt(at, role)
    local side = ROLE_END[role]
    for _, link in ipairs(Links.all()) do
        if link[role] and EnhancedIrrigation.sameSquare(link[side], at) then
            return link
        end
    end
    return nil
end

--- The other end of `link` from the square `at`, or nil when `at` is neither end.
function Links.otherEnd(link, at)
    if EnhancedIrrigation.sameSquare(link.a, at) then
        return link.b
    elseif EnhancedIrrigation.sameSquare(link.b, at) then
        return link.a
    end
    return nil
end

--- The links with an end on the square `at`, in the order they were made.
function Links.linksAt(at)
    local found = {}
    for _, link in ipairs(Links.all()) do
        if Links.otherEnd(link, at) then
            table.insert(found, link)
        end
    end
    return found
end

--- The link between the squares `p` and `q`, either way round, or nil.
function Links.find(p, q)
    for _, link in ipairs(Links.all()) do
        local other = Links.otherEnd(link, p)
        if other and EnhancedIrrigation.sameSquare(other, q) then
            return link
        end
    end
    return nil
end

--- What `find(x, y, z)` finds within plumbing reach of `object`, loaded on this side, nearest
--- first, each { found, at, distance }: with Tanks.tankAt, the tanks it can be plumbed to, linked
--- ones too (the menu says so).
function Links.inReach(object, find)
    local here = EnhancedIrrigation.squareOf(object)
    local found = {}
    local storeys = math.floor(Links.MAX_TILES / Links.TILES_PER_STOREY)
    for dz = -storeys, storeys do
        local across = Links.MAX_TILES - Links.TILES_PER_STOREY * math.abs(dz)
        for dx = -across, across do
            for dy = -across, across do
                local at = { x = here.x + dx, y = here.y + dy, z = here.z + dz }
                if not EnhancedIrrigation.sameSquare(at, here) and Links.distance(here, at) <= Links.MAX_TILES then
                    local other = find(at.x, at.y, at.z)
                    if other then
                        table.insert(found, { found = other, at = at, distance = Links.distance(here, at) })
                    end
                end
            end
        end
    end
    table.sort(found, function(p, q) return p.distance < q.distance end)
    return found
end

return Links
