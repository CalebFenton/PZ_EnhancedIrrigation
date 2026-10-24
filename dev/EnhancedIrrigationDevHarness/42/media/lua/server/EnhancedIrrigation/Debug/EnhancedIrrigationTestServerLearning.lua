require "PZHarness/ServerFixtures"
require "PZHarness/Fixtures"
require "PZHarness/Checks"

-- Development only, not published. The server's half of EnhancedIrrigationTestsLearning.lua: the
-- authority's copy of the character's recipes and skills, and its loot tables, which only the
-- authority fills (Distributions.lua leaves a multiplayer client out). A --stay rerun loads this
-- file again, so it only registers handlers.

local handler = PZHarness.serverHandler
local Fixtures = PZHarness.Fixtures

-- `names` as a set of whether the character knows each.
local function knownOf(player, names)
    local known = {}
    for _, name in ipairs(names) do
        known[name] = player:isRecipeActuallyKnown(name)
    end
    return known
end

-- Whether the character knows each of `args.names`, in `known` by name.
handler("learning.known", function(player, args)
    return { known = knownOf(player, args.names) }
end)

-- Forgets that the character read the title (modData literatureTitle) of its carried `args.type`,
-- whose cooldown would make reading it again teach nothing (ISReadABook:complete).
handler("learning.forgetLiterature", function(player, args)
    local item = player:getInventory():getFirstTypeRecurse(args.type)
    local title = item and item:getModData().literatureTitle
    if not title then
        return nil, "a titled " .. tostring(args.type) .. " in the character's inventory on the server"
    end
    player:getReadLiterature():remove(title)
    return {}
end)

-- Forgets `args.forget`, if given, sets the levels `args.levels` (perk id -> level), each at the XP
-- that starts it, then awards the XP that takes `args.perk` one level up, as the authority awards a
-- timed action's XP: the game levels the perk up and fires LevelPerk. The perks setting puts the
-- levels back when the test ends, recipes.know the recipes. Answers the level before and after, and
-- whether the character then knows `args.names`.
handler("learning.levelUp", function(player, args)
    if args.forget then
        Fixtures.forgetRecipes(player, args.forget)
    end
    Fixtures.setPerkLevels(player, args.levels)
    local perk = Perks.FromString(args.perk)
    local before = player:getPerkLevel(perk)
    local next = PerkFactory.getPerk(perk):getTotalXpForLevel(before + 1)
    addXpNoMultiplier(player, perk, next - player:getXp():getXP(perk) + 1)
    return { before = before, after = player:getPerkLevel(perk), known = knownOf(player, args.names) }
end)

-- Sets the levels `args.levels` (perk id -> level) with no level up, so no LevelPerk teaches
-- anything: a character who earned them before the mod was added. Put back when the test ends.
handler("learning.setLevels", function(player, args)
    Fixtures.setPerkLevels(player, args.levels)
    return { known = knownOf(player, args.names) }
end)

-- Loot ----------------------------------------------------------------------------------------------

local function distributions(expect)
    local D = EnhancedIrrigation and EnhancedIrrigation.Distributions
    return expect(D ~= nil, "EnhancedIrrigation.Distributions did not load on the authority") and D
end

-- The first room and container type whose procList picks each ProceduralDistributions list.
local function procListUsers()
    local users = {}
    for roomName, room in pairs(SuburbsDistributions) do
        if type(room) == "table" and room.rolls == nil then
            for containerType, containerTable in pairs(room) do
                if type(containerTable) == "table" and type(containerTable.procList) == "table" then
                    for _, choice in ipairs(containerTable.procList) do
                        if choice.name and not users[choice.name] then
                            users[choice.name] = { room = roomName, container = containerType }
                        end
                    end
                end
            end
        end
    end
    return users
end

-- Calls fn(items, path) for every items list of every room, bag, procedural and vehicle table.
local function forEachItemsList(fn)
    local seen = {}
    local function walk(t, path, depth)
        if seen[t] or depth > 6 then
            return
        end
        seen[t] = true
        if type(t.items) == "table" then
            fn(t.items, path)
        end
        for key, value in pairs(t) do
            if type(value) == "table" and key ~= "items" and key ~= "procList" then
                walk(value, path .. "." .. tostring(key), depth + 1)
            end
        end
    end
    walk(SuburbsDistributions, "SuburbsDistributions", 0)
    walk(ProceduralDistributions.list, "ProceduralDistributions", 0)
    walk(VehicleDistributions, "VehicleDistributions", 0)
end

-- The entry of Distributions.LOOT for the item `fullType`, or nil, failing.
local function lootOf(D, fullType, expect)
    for _, loot in ipairs(D.LOOT) do
        if loot.item == fullType then
            return loot
        end
    end
    expect(false, "Distributions.LOOT has no " .. tostring(fullType))
    return nil
end

-- Sets `loot`'s sandbox option to `value` and applies it, as a load with that option does; returns
-- the function that puts the save's option and loot back, deferred too in case the check throws.
local function withLootOption(D, loot, defer)
    local options = SandboxVars.EnhancedIrrigation
    local saved = options[loot.option]
    local restored = false
    local function restore()
        if restored then return end
        restored = true
        options[loot.option] = saved
        D.apply()
        ItemPickerJava.Parse()
    end
    defer(restore)
    return function(value)
        options[loot.option] = value
        D.apply()
    end, restore
end

-- Every list the item `args.item` goes into is one a room picks from, and holds the item once, at
-- its weight times the save's value of its option, since the merge at load. Each of
-- `args.multipliers` scales every weight, applied twice as a second load applies it; at 0 the item
-- is in no loot list at all, since a zero weight still spawns through the zombie density bonus.
handler("learning.lootLists", function(player, args, defer)
    local expect, expectNear, failures = PZHarness.Checks.new()
    local D = distributions(expect)
    local loot = D and lootOf(D, args.item, expect)
    if not loot then
        return { failures = failures }
    end
    local users = procListUsers()
    local function checkAt(multiplier, label)
        for _, entry in ipairs(loot.lists) do
            local name, weight = entry[1], entry[2]
            local list = ProceduralDistributions.list[name]
            local where = label .. ": " .. loot.item .. " in " .. name
            if expect(list ~= nil and list.items ~= nil, where .. ": no such list") then
                local count, got = Fixtures.countPairs(list.items, loot.item)
                if multiplier == 0 then
                    expect(count == 0, where .. " " .. count .. " times")
                elseif expect(count == 1, where .. " " .. count .. " times") then
                    expectNear(where .. " weight", got, weight * multiplier)
                end
            end
            local user = users[name]
            if expect(user ~= nil, name .. ": no room picks it") then
                expect(ItemPickerJava.getItemContainer(user.room, user.container, name, false) ~= nil,
                    name .. ": the game never parsed " .. user.room .. "." .. user.container .. " -> " .. name)
            end
        end
        if multiplier == 0 then
            forEachItemsList(function(items, path)
                expect(Fixtures.countPairs(items, loot.item) == 0, label .. ": " .. loot.item .. " is still in " .. path)
            end)
        end
    end
    checkAt(SandboxVars.EnhancedIrrigation[loot.option], "as loaded")
    local set, restore = withLootOption(D, loot, defer)
    for _, multiplier in ipairs(args.multipliers) do
        set(multiplier)
        set(multiplier)
        checkAt(multiplier, "at " .. loot.option .. " " .. multiplier)
    end
    restore()
    return { failures = failures }
end)

-- Takes the container's items off the cell's processed items, where ItemContainer.AddItem puts
-- every new item: hundreds of fills in one frame would pile up there.
local function forgetItems(container, processItems)
    local items = container:getItems()
    for i = 0, items:size() - 1 do
        processItems:remove(items:get(i))
    end
end

-- Each list of the item `args.item` hands it out through the game's own roll of a container that
-- picks it (ItemPickerJava.rollItem), within `args.fills` fills, with its option and the loot
-- rarity option of its kind, `args.rarity`, at their highest, so the rarest weight spawns about one
-- fill in four.
handler("learning.lootRolls", function(player, args, defer)
    local expect, _, failures = PZHarness.Checks.new()
    local D = distributions(expect)
    local loot = D and lootOf(D, args.item, expect)
    if not loot then
        return { failures = failures }
    end
    local rarity = getSandboxOptions():getOptionByName(args.rarity)
    local savedRarity = rarity:getValue()
    -- In debug mode ItemPickInfo logs every roll into a container that isn't on a square.
    local generalLog = DebugType.General:getLogSeverity()
    local function restoreLoot()
        DebugType.General:setLogSeverity(generalLog)
        rarity:setValue(savedRarity)
        ItemPickerJava.InitSandboxLootSettings()
    end
    defer(restoreLoot)
    local set, restore = withLootOption(D, loot, defer)
    set(4)
    ItemPickerJava.Parse()
    -- The rarity options' highest value (SandboxOptions).
    rarity:setValue(4)
    ItemPickerJava.InitSandboxLootSettings()
    DebugType.General:setLogSeverity(LogSeverity.Off)
    local users = procListUsers()
    local container = ItemContainer.new("crate", nil, nil)
    local processItems = getCell():getProcessItems()
    for _, entry in ipairs(loot.lists) do
        local name = entry[1]
        local user = users[name]
        local list = user and ItemPickerJava.getItemContainer(user.room, user.container, name, false)
        if expect(list ~= nil, name .. ": no parsed list to roll") then
            local found = false
            for _ = 1, args.fills do
                container:removeAllItems()
                ItemPickerJava.rollItem(list, container, true, nil, nil)
                found = container:getFirstTypeRecurse(loot.item) ~= nil
                forgetItems(container, processItems)
                if found then
                    break
                end
            end
            container:removeAllItems()
            expect(found, name .. " never handed out " .. loot.item .. " in " .. args.fills .. " fills")
        end
    end
    restoreLoot()
    restore()
    return { failures = failures }
end)
