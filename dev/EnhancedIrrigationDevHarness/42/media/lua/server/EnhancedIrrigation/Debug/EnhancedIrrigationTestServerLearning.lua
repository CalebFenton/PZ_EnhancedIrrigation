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
    local title = item and item:getModData().literatureTitle
    if not title then
        return nil, "a titled " .. tostring(args.type) .. " in the character's inventory on the server"
    end
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
        listed[loot.item] = true
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

-- Every list each item of Distributions.LOOT goes into is one a room picks from, and holds the item
-- once, at its weight times the save's value of its option, since the merge at load. Each of
-- `args.multipliers` scales every weight, applied twice as a second load applies it; at 0 the item
-- is in no loot list at all, since a zero weight still spawns through the zombie density bonus.
PZHarness.checkHandler("learning.lootLists", function(expect, expectNear, _, args, defer)
    local D = distributions(expect)
    if not D then
        return
    end
    local users = PZHarness.Loot.procListUsers()
    local function checkAt(loot, multiplier, label)
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
            PZHarness.Loot.forEachItemsList(function(items, path)
                expect(Fixtures.countPairs(items, loot.item) == 0, label .. ": " .. loot.item .. " is still in " .. path)
            end)
        end
    end
    -- Every item as loaded before any option changes, since items share an option.
    for _, loot in ipairs(D.LOOT) do
        checkAt(loot, SandboxVars.EnhancedIrrigation[loot.option], "as loaded")
    end
    local set, restore = lootOptionSetter(D, defer)
    for _, loot in ipairs(D.LOOT) do
        for _, multiplier in ipairs(args.multipliers) do
            set(loot.option, multiplier)
            set(loot.option, multiplier)
            checkAt(loot, multiplier, "at " .. loot.option .. " " .. multiplier)
        end
    end
    restore()
end)

-- The highest value of the item's option and of the loot rarity options (SandboxOptions).
local HIGHEST = 4

-- Each list of each item of Distributions.LOOT hands the item out through the game's own roll of a
-- container that picks it (ItemPickerJava.rollItem), within `args.fills` fills, with the item's
-- option and the loot rarity option of its kind at their highest.
PZHarness.checkHandler("learning.lootRolls", function(expect, _, _, args, defer)
    local Loot = PZHarness.Loot
    local D = distributions(expect)
    if not D then
        return
    end
    local rarities = {}
    for _, loot in ipairs(D.LOOT) do
        local name, option = Loot.rarityOf(loot.item)
        if expect(name ~= nil, loot.item .. ": no loot rarity option for its loot type " .. tostring(option)) then
            rarities[name] = HIGHEST
        end
    end
    local set, restore = lootOptionSetter(D, defer)
    for _, loot in ipairs(D.LOOT) do
        set(loot.option, HIGHEST)
    end
    ItemPickerJava.Parse()
    local users = Loot.procListUsers()
    local container = ItemContainer.new("crate", nil, nil)
    Loot.withMeasureOptions(rarities, function()
        for _, loot in ipairs(D.LOOT) do
            local function holdsItem(filled)
                return filled:getFirstTypeRecurse(loot.item) ~= nil
            end
            for _, entry in ipairs(loot.lists) do
                local name = entry[1]
                local list = Loot.proceduralList(name, users)
                if expect(list ~= nil, name .. ": no parsed list to roll") then
                    local fill, found = Loot.rollFill(list), false
                    for _ = 1, args.fills do
                        found = Loot.fillOnce(fill, container, holdsItem)
                        if found then
                            break
                        end
                    end
                    expect(found, name .. " never handed out " .. loot.item .. " in " .. args.fills .. " fills")
                end
            end
        end
    end)
    restore()
end)
