-- Run with Lua 5.1 from the repository root: the Restock Reminder counts food and drink filed under
-- Consumable: Food & Drink, and Forever's own cooking filed under Consumable: Other when its spell is
-- Food or Drink. Other consumables and raw fish (Trade Goods) are not counted. Items that restore health and
-- mana in one, such as the Enriched Manna Biscuit, count as food and as drink, and Forever's teas as drink.
local f = assert(io.open(arg[1] or "NaowhForever_QoL/Loot/Restock.lua", "rb"))
local source = f:read("*a"):gsub("\r\n", "\n"); f:close()
local function Slice(a, b)
    local first = assert(source:find(a, 1, true))
    return source:sub(first, assert(source:find(b, first + #a, true)) - 1)
end

-- Classes, subclasses, required levels and spell names from Forever's Item, ItemSparse and
-- SpellName tables (build 1.60.1.70862). OTHER_ITEM and the two greys are synthetic; a grey's
-- fifth field is its sell price.
local JERKY, PROWLER_STEAK, LEMONADE, WATER, RAW_SNAPPER, OTHER_ITEM = 117, 238637, 23161, 159, 6289, 900001
local BISCUIT, ROYAL_TEA = 13724, 249866
local GREY, GREY_NO_VALUE = 900002, 900003
local ITEMS = {
    [GREY] = { 15, 0, 1, nil, 12 },
    [GREY_NO_VALUE] = { 15, 0, 1, nil, 0 },
    [JERKY] = { 0, 5, 1, "Food" },
    [PROWLER_STEAK] = { 0, 8, 55, "Food" },
    [LEMONADE] = { 0, 8, 45, "Drink" },
    [WATER] = { 0, 5, 1, "Drink" },
    [RAW_SNAPPER] = { 7, 8, 5, "Food" },
    [OTHER_ITEM] = { 0, 8, 1, "Something Else" },
    [BISCUIT] = { 0, 5, 45, "Enriched Manna Biscuit" },
    [ROYAL_TEA] = { 0, 5, 5, "Nutritious Drink" },
}
local SPELLS = { [433] = "Food", [430] = "Drink", [1249920] = "Nutritious Drink" }

-- A bag slot is { itemID, count, quality (default 1), hasNoValue }.
local function Scan(bag, settings, uncached)
    local requests, infoReads = {}, 0
    local env = setmetatable({
        ItemLocation = { CreateEmpty = function()
            return { SetBagAndSlot = function(self, _, slot) self.slot = slot end }
        end },
        PLAIN_BAG = 0, SELL_PRICE = 11, MAX_LEVEL = 60, NUM_BAG_SLOTS = 0,
        Enum = { ItemQuality = { Poor = 0 } },
        S = { Get = function(key) return (settings or {})[key] end },
        RequestItem = function(id) requests[#requests + 1] = id end,
        ns = { IsFoodAndDrink = function(id) return id == BISCUIT end },
        C_Spell = { GetSpellName = function(id) return SPELLS[id] end },
        C_Item = {
            GetItemInfoInstant = function(id)
                return id, nil, nil, nil, nil, ITEMS[id][1], ITEMS[id][2]
            end,
            GetItemInfo = function(id)
                if uncached and uncached[id] then return end
                return nil, nil, nil, nil, ITEMS[id][3], nil, nil, nil, nil, nil, ITEMS[id][5] or 1
            end,
            GetItemSpell = function(id)
                if uncached and uncached[id] then return end
                return ITEMS[id][4]
            end,
            GetStackCount = function(at) return bag[at.slot][2] end,
            GetItemQuality = function(at) return bag[at.slot][3] or 1 end,
        },
        C_Container = {
            GetContainerNumFreeSlots = function() return 10, 0 end,
            GetContainerNumSlots = function() return #bag end,
            GetContainerItemID = function(_, slot) return bag[slot][1] end,
            GetContainerItemInfo = function(_, slot)
                infoReads = infoReads + 1
                return { itemID = bag[slot][1], stackCount = bag[slot][2], quality = bag[slot][3] or 1,
                    hasNoValue = bag[slot][4] or false }
            end,
        },
    }, { __index = _G })
    local code = Slice("local FOOD_CLASS", "\nlocal PLAIN_BAG") .. "\n"
        .. Slice("local function FoodLevel(", "\nlocal function ReagentLines(")
        .. "\nreturn ScanBags"
    local chunk = assert(loadstring(code)); setfenv(chunk, env)
    local ScanBags = chunk()
    local food, junk, _, drink = ScanBags()
    return food, drink, requests, junk, infoReads, ScanBags
end

local count = 0
local function Case(name, fn) fn(); count = count + 1; print("PASS " .. name) end

Case("Food & Drink items count as food or drink, as before", function()
    local food, drink = Scan({ { JERKY, 12 }, { WATER, 7 } })
    assert(food == 12 and drink == 7)
end)
Case("Forever's cooking filed under Other counts by its Food or Drink spell", function()
    local food, drink = Scan({ { PROWLER_STEAK, 15 }, { LEMONADE, 4 }, { JERKY, 2 } })
    assert(food == 17 and drink == 4)
end)
Case("other Other consumables and raw fish are not food", function()
    local food, drink = Scan({ { OTHER_ITEM, 20 }, { RAW_SNAPPER, 20 } })
    assert(food == 0 and drink == 0)
end)
Case("the required-level range applies to Other food too", function()
    local food = Scan({ { PROWLER_STEAK, 15 }, { JERKY, 3 } }, { restockFoodMaxLevel = 50 })
    assert(food == 3)
end)
Case("uncached Other food is requested and counted once it loads", function()
    local bag = { { PROWLER_STEAK, 15 } }
    local food, _, requests = Scan(bag, nil, { [PROWLER_STEAK] = true })
    assert(food == 0 and #requests == 1 and requests[1] == PROWLER_STEAK)
    assert(Scan(bag) == 15)
end)
Case("the Enriched Manna Biscuit counts as food and as drink", function()
    local food, drink = Scan({ { BISCUIT, 20 }, { JERKY, 3 }, { WATER, 5 } })
    assert(food == 23 and drink == 25)
end)
Case("Forever's teas count as drink, not food", function()
    local food, drink = Scan({ { ROYAL_TEA, 10 }, { JERKY, 3 } })
    assert(food == 3 and drink == 10)
end)
Case("grey items with a sell price count as junk; greys without one and other items do not", function()
    local bag = { { GREY, 1, 0 }, { GREY_NO_VALUE, 1, 0, true }, { JERKY, 5 } }
    local _, _, _, junk, infoReads = Scan(bag, { restockVendor = true })
    assert(junk == 1)
    assert(infoReads == 0, "the sell price comes from the item's data, not a slot table")
end)
Case("an uncached grey falls back to the slot's no-value flag", function()
    local bag = { { GREY, 1, 0 }, { GREY_NO_VALUE, 1, 0, true } }
    local _, _, _, junk, infoReads = Scan(bag, { restockVendor = true }, { [GREY] = true, [GREY_NO_VALUE] = true })
    assert(junk == 1 and infoReads == 2)
end)
Case("with Junk & Full Bags off, greys are not looked at", function()
    local _, _, _, junk, infoReads = Scan({ { GREY, 1, 0 } }, {}, { [GREY] = true })
    assert(junk == 0 and infoReads == 0)
end)
Case("a scan of bags without junk leaves no garbage", function()
    local bag = {}
    for i = 1, 96 do bag[i] = { i % 2 == 0 and JERKY or WATER, 5 } end
    local ScanBags = select(6, Scan(bag, {}))
    local RUNS = 500
    collectgarbage("collect")
    collectgarbage("stop")
    local before = collectgarbage("count")
    for _ = 1, RUNS do ScanBags() end
    local grown = collectgarbage("count") - before
    collectgarbage("restart")
    assert(grown / RUNS < 0.05, ("%.2f KB per scan"):format(grown / RUNS))
end)
print(count .. " total restock food regressions passed")
