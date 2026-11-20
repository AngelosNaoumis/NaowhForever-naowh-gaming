-- Run with Lua 5.1 from the repository root: Trade Spam Filter. Off, it adds no chat filter; on, it hides
-- portal, guild, boost and repeated spam from strangers, and leaves questions, group posts and trusted players alone.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local TRADE, GENERAL, LFG = 2, 1, 26
local BASE_NAMES = { [TRADE] = "Trade", [GENERAL] = "General", [LFG] = "LookingForGroup" }
local values = { enabled = true, tradeFilter = false, tradeFilterPortals = true, tradeFilterGuilds = true,
    tradeFilterBoosts = true, tradeFilterRepeats = true, tradeFilterRepeatMinutes = 5, tradeFilterWords = "",
    tradeFilterOthers = false, tradeFilterAllow = "" }
local S = {}
function S.Get(key) return values[key] end
function S.Set(key, value) values[key] = value end

local function Hook(owner, name, after)
    local before = owner[name]
    owner[name] = function(...)
        before(...)
        after(...)
    end
end

local card
local ns = {
    QoLSettings = S,
    QoLConstants = { SECONDS_PER_MINUTE = 60 },
    L = function(s) return s end,
    Apply = function() end,
    Print = function() end,
    Color = function(_, s) return s end,
    Shared = { Settings = {
        Group = function(name) return { group = name } end,
        Page = function() return { Card = function(_, c) card = c end } end,
    } },
}
function ns.OnApply(fn) Hook(ns, "Apply", fn) end

local filter
local now, party, friends, guild = 0, {}, {}, {}
local env = setmetatable({
    NaowhForever = ns,
    CreateFrame = function() return { RegisterEvent = function() end, SetScript = function() end } end,
    hooksecurefunc = Hook,
    ChatFrameUtil = {
        AddMessageEventFilter = function(_, fn) filter = fn end,
        RemoveMessageEventFilter = function() filter = nil end,
    },
    Ambiguate = function(name) return (name:gsub("%-.*", "")) end,
    UnitName = function() return "Me" end,
    UnitInParty = function(name) return party[name] end,
    UnitInRaid = function() return false end,
    C_FriendList = { IsFriend = function(guid) return friends[guid] end },
    C_BattleNet = { GetGameAccountInfoByGUID = function() end },
    IsInGuild = function() return true end,
    C_GuildInfo = { MemberExistsByName = function(name) return guild[name] end },
    GetTime = function() return now end,
    date = function() return "12:00" end,
    strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end end,
    DEFAULT_CHAT_FRAME = { AddMessage = function() end },
}, { __index = _G })
env._G = env
local fn = assert(loadstring(Read("NaowhForever_QoL/Interface/TradeFilter.lua"), "TradeFilter"))
setfenv(fn, env)
fn()

local line = 0
local function Hidden(msg, author, channel, guid)
    line = line + 1
    channel = channel or TRADE
    return filter(nil, "CHAT_MSG_CHANNEL", msg, author or "Stranger-Realm", "", "", "", "",
        channel, 0, BASE_NAMES[channel], 0, line, guid or "Player-1")
end

check("the card turns on with tradeFilter", card.switch == "tradeFilter")
ns.Apply()
check("off, no chat filter is added", filter == nil)
S.Set("tradeFilter", true)
ns.Apply()
check("on, the channel filter is added", filter ~= nil)

local HIDE = {
    "WTS portals to all cities, 1g",
    "summons to BRD, 5g, whisper me",
    "<Nihil> is recruiting all classes for Molten Core",
    "Friendly guild <Hearth> welcomes all levels, join our discord",
    "ginv anyone?",
    "WTS UBRS carry, cheap",
    "boosting deadmines 10g",
    "buy cheap gold at www.example",
}
for _, msg in ipairs(HIDE) do check("hidden: " .. msg, Hidden(msg)) end

local SHOW = {
    "does anyone know if Nihil is a good guild?",
    "looking for a guild to level with",
    "LF guild, 60 mage",
    "any social guild around?",
    "join us for UBRS, need tank",
    "what's the sum of 2+2",
    "LFM strat, have summons",
    "WTS [Silken Thread] 4s each",
}
for _, msg in ipairs(SHOW) do check("shown: " .. msg, not Hidden(msg)) end

check("the Dark Portal is not a portal for sale", not Hidden("how do i get to the dark portal?"))
check("but a port beside it still is", Hidden("at the dark portal, WTS port to Shattrath"))

S.Set("tradeFilterOthers", true)
check("Also General and LFG hides there too", Hidden("WTS portals to all cities", nil, GENERAL))
check("and an LFG post with summons still shows", not Hidden("LF2M UBRS have summons", nil, LFG))
S.Set("tradeFilterOthers", false)
check("off, General is left alone", not Hidden("WTS portals to all cities", nil, GENERAL))

party.Buddy, friends["Player-2"], guild.Mate = true, true, true
check("a party member is never hidden", not Hidden("WTS portals", "Buddy-Realm"))
check("nor a friend", not Hidden("WTS portals", "Pal-Realm", nil, "Player-2"))
check("nor a guild member", not Hidden("WTS portals", "Mate-Realm"))
S.Set("tradeFilterAllow", "Seller")
check("nor a name on Never Hide", not Hidden("WTS portals", "Seller-Realm"))

S.Set("tradeFilterWords", "mats, crafting")
check("Your Own Words hides a line with one of them", Hidden("WTB mats for my alt"))

check("a message seen once shows", not Hidden("WTB Linen Cloth, 20 stacks"))
now = 60
check("the same again inside the window is hidden", Hidden("WTB Linen Cloth, 20 stacks"))
check("from someone else it shows", not Hidden("WTB Linen Cloth, 20 stacks", "Other-Realm"))
now = 60 + 6 * 60
check("after the window it shows again", not Hidden("WTB Linen Cloth, 20 stacks"))

local id = line
check("a line hidden in one chat frame", Hidden("WTS portals"))
line = id
check("is hidden in the next without a second look", Hidden("WTS portals"))

S.Set("tradeFilter", false)
check("turning it off removes the filter", filter == nil)

print(("trade filter: %d checks passed"):format(checks))
