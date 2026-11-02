require "PZHarness/ServerFixtures"
require "PZHarness/Fixtures"
require "PZHarness/ServerChecks"
require "PZHarness/Loot"

-- Development only, not published. Loot tables are checked here because only the authority fills
-- them (Distributions.lua leaves a multiplayer client out). A --stay rerun loads this file again,
-- so it only registers handlers.

local handler = PZHarness.serverHandler
local Fixtures = PZHarness.Fixtures

-- Forgets that the character read the title (modData literatureTitle) of its carried `args.type`,
-- whose cooldown would make reading it again teach nothing (ISReadABook:complete).
handler("learning.forgetLiterature", function(player, args)
    local item = player:getInventory():getFirstTypeRecurse(args.type)
    local title = PZHarness.need(item and item:getModData().literatureTitle,
        "a titled " .. tostring(args.type) .. " in the character's inventory on the server")
    player:getReadLiterature():remove(title)
    return {}
end)

-- Loot ----------------------------------------------------------------------------------------------

-- The server's Distributions, once it has an entry for each item the player guide's Loot table
-- promises, so a dropped entry fails rather than leaving the item unfindable.
local function distributions(expect)
    local mod = EnhancedIrrigation
    local D = mod and mod.Distributions
    if not expect(D ~= nil, "EnhancedIrrigation.Distributions did not load on the authority") then
        return nil
    end
    local listed = {}
    for _, loot in ipairs(D.LOOT) do
        listed[loot.fullType] = true
    end
    for _, item in ipairs({ D.PAMPHLET, mod.Pumps.UTILITY_PUMP, mod.Sprinklers.ITEM, mod.Valves.SPRINKLER_TIMER,
            mod.Valves.WATER_VALVE }) do
        expect(listed[item], "Distributions.LOOT has no " .. item)
    end
    return D
end

-- Saves the sandbox options of Distributions.LOOT; returns the function that sets one and applies
-- it as a load with that value does, and the one that puts the save's options and loot back
-- (PZHarness.Fixtures.saveOptions says when it runs).
local function lootOptionSetter(D, defer)
    local names = {}
    for _, loot in ipairs(D.LOOT) do
        table.insert(names, loot.option)
    end
    local restore = Fixtures.saveOptions(defer, names, function()
        D.apply()
        ItemPickerJava.Parse()
    end)
    return function(option, value)
        SandboxVars.EnhancedIrrigation[option] = value
        D.apply()
    end, restore
end

-- The ProceduralDistributions list a Distributions.LOOT entry names ("proc:<list>").
local function procName(entry)
    return string.match(entry[2], "^proc:(.+)$")
end

-- Every list each item of Distributions.LOOT goes into is one a room picks from, and holds the item
-- once, at its weight times the save's value of its option, since the merge at load. Each of
-- `args.multipliers` in turn, applied over the one before as a load with that value applies it,
-- scales every weight, and at 0 the item is in no loot list at all, since a zero weight still
-- spawns through the zombie density bonus.
PZHarness.checkHandler("learning.lootLists", function(expect, expectNear, _, args, defer)
    local D = distributions(expect)
    if not D then
        return
    end
    local function checkAt(loot, multiplier, label)
        for _, entry in ipairs(loot.entries) do
            local name, weight = procName(entry), entry[1]
            local list = ProceduralDistributions.list[name]
            local where = label .. ": " .. loot.fullType .. " in " .. name
            if expect(list ~= nil and list.items ~= nil, where .. ": no such list") then
                local count, got = Fixtures.countPairs(list.items, loot.fullType)
                if multiplier == 0 then
                    expect(count == 0, where .. " " .. count .. " times")
                elseif expect(count == 1, where .. " " .. count .. " times") then
                    expectNear(where .. " weight", got, weight * multiplier)
                end
            end
        end
        if multiplier == 0 then
            PZHarness.Loot.forEachItemsList(function(items, path)
                expect(Fixtures.countPairs(items, loot.fullType) == 0, label .. ": " .. loot.fullType .. " is still in " .. path)
            end)
        end
    end
    -- Every item as loaded before any option changes, since items share an option.
    local users = PZHarness.Loot.procListUsers()
    for _, loot in ipairs(D.LOOT) do
        checkAt(loot, SandboxVars.EnhancedIrrigation[loot.option], "as loaded")
        for _, entry in ipairs(loot.entries) do
            local name = procName(entry)
            local user = users[name]
            if expect(user ~= nil, name .. ": no room picks it") then
                expect(ItemPickerJava.getItemContainer(user.room, user.container, name, false) ~= nil,
                    name .. ": the game never parsed " .. user.room .. "." .. user.container .. " -> " .. name)
            end
        end
    end
    local set, restore = lootOptionSetter(D, defer)
    for _, loot in ipairs(D.LOOT) do
        for _, multiplier in ipairs(args.multipliers) do
            set(loot.option, multiplier)
            checkAt(loot, multiplier, "at " .. loot.option .. " " .. multiplier)
        end
    end
    restore()
end)
