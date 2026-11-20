-- Run with Lua 5.1 from the repository root: Chat Zones reads Battle.net friends without rescanning
-- the whole list on every BN_FRIEND_INFO_CHANGED. An event naming a friend reads that friend
-- alone; one without an index, a friend coming online or the list changing size queue a single
-- full read, which does nothing once Chat Zones is off; remembering a player again reuses their entry.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local source = Read(arg[1] or "NaowhForever_QoL/Interface/ChatZones.lua")
local first = assert(source:find("local PREFIX = ", 1, true))
local last = assert(source:find('\nevents:SetScript("OnEvent", OnEvent)', first, true))
local chunk = source:sub(first, last) .. "return OnEvent, known"

local FRIENDS = 100
local reads, timers, on = 0, {}, true
local function Account(i)
    reads = reads + 1
    return { bnetAccountID = i, accountName = "Friend" .. i, gameAccountInfo = {
        isOnline = true, clientProgram = i % 2 == 0 and "WoW" or "App", wowProjectID = 1,
        characterName = "Hero" .. i, areaName = "Zone" .. (i % 7), characterLevel = 20 + i % 40 } }
end
local env = {
    ns = { L = function(s) return s end, QoLConstants = { SECONDS_PER_MINUTE = 60 } },
    S = { Get = function() return on end },
    CreateFrame = function() return {} end,
    C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end },
    C_BattleNet = { GetFriendAccountInfo = Account },
    C_FriendList = { GetNumFriends = function() return 0 end },
    BNGetNumFriends = function() return FRIENDS end,
    BNET_CLIENT_WOW = "WoW", WOW_PROJECT_ID = 1,
    GetTime = function() return 100 end,
    Ambiguate = function(name) return name end,
}
local fn = assert(loadstring(chunk))
setfenv(fn, setmetatable(env, { __index = _G }))
local OnEvent, known = fn()

OnEvent(nil, "BN_FRIEND_INFO_CHANGED", 42)
check("an event naming a friend reads that friend alone", reads == 1 and known.Hero42.zone == "Zone0")
check("and queues no full read", #timers == 0)

local entry = known.Hero42
OnEvent(nil, "BN_FRIEND_INFO_CHANGED", 42)
check("remembering a player again reuses their entry", known.Hero42 == entry)

reads = 0
OnEvent(nil, "BN_FRIEND_INFO_CHANGED")
OnEvent(nil, "BN_FRIEND_INFO_CHANGED")
OnEvent(nil, "FRIENDLIST_UPDATE")
check("events without an index queue one full read between them", #timers == 1 and reads == 0)
timers[1]()
check("the full read reads every friend once", reads == FRIENDS and known.Hero100 ~= nil)
OnEvent(nil, "BN_FRIEND_INFO_CHANGED")
check("after it runs, the next one queues again", #timers == 2)
timers[2]()

reads = 0
OnEvent(nil, "BN_FRIEND_ACCOUNT_ONLINE", 7)
OnEvent(nil, "BN_FRIEND_LIST_SIZE_CHANGED", 7)
check("a friend coming online or the list changing size queues one full read", #timers == 3)
timers[3]()
check("which reads every friend", reads == FRIENDS)

reads = 0
OnEvent(nil, "BN_FRIEND_INFO_CHANGED")
on = false
timers[4]()
check("a queued read does nothing once Chat Zones is off", reads == 0)

print(("test-chat-zones-friends: %d checks passed"):format(checks))
