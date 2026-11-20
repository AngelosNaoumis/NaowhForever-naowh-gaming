-- Run with Lua 5.1 from the repository root: Quest Reward Sell Price (NaowhForever_QoL/Loot/QuestSellPrice.lua).
-- A quest reward's tooltip, in the quest log or at the quest giver, gets the game's Sell Price line: the item's
-- sell price times the reward's count. Other item tooltips, items without a price, shopping tooltips and tooltips
-- that already have the line get nothing. Off by default, it hooks no tooltip until it is switched on.
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Noop() end
local frames, hooks = {}, 0
local tooltipHook, setHook, boot, card

local frameMethods = {
    SetScript = function(f, name, fn) f[name] = fn end,
    RegisterEvent = function(f, event)
        if event == "PLAYER_LOGIN" then boot = f end
    end,
}
local frameMeta = { __index = function(_, k) return frameMethods[k] or Noop end }

local function CreateFrame()
    local f = setmetatable({}, frameMeta)
    frames[#frames + 1] = f
    return f
end

local settings = { enabled = true, questSellPrice = false }
local S = { Get = function(k) return settings[k] end, Set = Noop }
local ns = {
    QoLSettings = S,
    Apply = Noop,
    Shared = {
        Settings = { Page = function(page)
            return { Card = function(_, spec) spec.page = page; card = spec end }
        end },
    },
}
function ns.OnApply(fn) local was = ns.Apply ns.Apply = function(...) was(...) fn(...) end end

local SWORD, POTION, QUEST_ITEM = 100, 200, 300
local prices = { [SWORD] = 1234, [POTION] = 25, [QUEST_ITEM] = 0 }
local counts = { reward = { [1] = 1, [2] = 5 }, choice = { [1] = 1, [2] = 3 } }
local SELL_LINE = 11

local secret = {}
local env = setmetatable({
    NaowhForever = ns,
    CreateFrame = CreateFrame,
    issecretvalue = function(value) return value == secret end,
    C_Item = { GetItemInfo = function(id)
        local price = prices[id]
        if price == nil then return nil end
        return "Item", "link", 1, 1, 1, "Armor", "Misc", 1, "", 1, price
    end },
    GetQuestItemInfo = function(kind, index) return "Item", 1, counts[kind][index] end,
    GetQuestLogChoiceInfo = function(index) return "Item", 1, counts.choice[index] end,
    GetQuestLogRewardInfo = function(index) return "Item", 1, counts.reward[index] end,
    Enum = { TooltipDataType = { Item = 0 }, TooltipDataLineType = { SellPrice = SELL_LINE } },
    TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn)
        if kind == 0 then
            hooks = hooks + 1
            tooltipHook = fn
        end
    end },
    hooksecurefunc = function(target, name, fn)
        if target == S and name == "Set" then setHook = fn end
    end,
}, { __index = _G })
env._G = env

local added
env.GameTooltip_OnTooltipAddMoney = function(_, cost, maxCost) added[#added + 1] = { cost = cost, max = maxCost } end

Load({ "NaowhForever_QoL/Loot/QuestSellPrice.lua" }, env)

local tooltip = {}
function tooltip.GetProcessingTooltipInfo(self) return self.info end

local function Hover(getter, args, data, shopping)
    added = {}
    tooltip.info = getter and { getterName = getter, getterArgs = args } or nil
    tooltip.isShopping = shopping
    if tooltipHook then tooltipHook(tooltip, data) end
    return added
end

local function Item(id, lines) return { id = id, lines = lines or {} } end

check("its card joins the Loot & Items card", card and card.page == "QoL/Loot & Items" and card.into == "lootTrade")
local row = card.rows[1]
check("as one toggle on questSellPrice", #card.rows == 1 and row.key == "questSellPrice" and row.toggle)
check("with one short sentence of help", #row.help < 100 and not row.help:find("%.%s"))

boot.OnEvent(boot, "PLAYER_LOGIN")
check("logging in with it off hooks no tooltip", tooltipHook == nil and hooks == 0)
check("and builds nothing past its login frame", #frames == 1)

settings.questSellPrice = true
setHook("questSellPrice")
check("switching it on hooks item tooltips once", hooks == 1 and tooltipHook ~= nil)

local got = Hover("GetQuestLogItem", { "reward", 1 }, Item(SWORD))
check("a quest log reward shows its sell price", #got == 1 and got[1].cost == 1234 and got[1].max == nil)
got = Hover("GetQuestLogItem", { "reward", 2 }, Item(POTION))
check("a stack of five shows five times the price", #got == 1 and got[1].cost == 125)
got = Hover("GetQuestLogItem", { "choice", 2 }, Item(POTION))
check("a quest log choice reads the choice's count", #got == 1 and got[1].cost == 75)
got = Hover("GetQuestItem", { "choice", 1 }, Item(SWORD))
check("a quest giver's reward shows it too", #got == 1 and got[1].cost == 1234)
got = Hover("GetQuestItem", { "reward", 2 }, Item(POTION))
check("with the giver's count", #got == 1 and got[1].cost == 125)

check("a bag item gets nothing", #Hover("GetBagItem", { 0, 1 }, Item(SWORD)) == 0)
check("nor a tooltip with no info", #Hover(nil, nil, Item(SWORD)) == 0)
check("nor an item with no sell price", #Hover("GetQuestLogItem", { "reward", 1 }, Item(QUEST_ITEM)) == 0)
check("nor an item not loaded yet", #Hover("GetQuestLogItem", { "reward", 1 }, Item(999)) == 0)
check("nor a secret ID", #Hover("GetQuestLogItem", { "reward", 1 }, Item(secret)) == 0)
check("nor a shopping tooltip", #Hover("GetQuestLogItem", { "reward", 1 }, Item(SWORD), true) == 0)
check("nor one that already has the game's line",
    #Hover("GetQuestLogItem", { "reward", 1 }, Item(SWORD, { { type = 1 }, { type = SELL_LINE } })) == 0)

settings.questSellPrice = false
setHook("questSellPrice")
check("switching it off adds nothing", #Hover("GetQuestLogItem", { "reward", 1 }, Item(SWORD)) == 0)
settings.questSellPrice = true
setHook("questSellPrice")
check("switching it on again does not hook twice", hooks == 1)
settings.enabled = false
setHook("enabled")
check("QoL off adds nothing", #Hover("GetQuestLogItem", { "reward", 1 }, Item(SWORD)) == 0)

local f = assert(io.open("Core/Features.lua", "rb"))
local features = f:read("*a"); f:close()
check("Quest Reward Sell Price is off by default", features:find("\n%s*questSellPrice = false,") ~= nil)

print(("test-quest-sell-price: %d checks passed"):format(checks))
