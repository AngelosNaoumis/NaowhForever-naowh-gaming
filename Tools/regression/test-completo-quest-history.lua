-- Run with Lua 5.1 from the repository root: Quest History. Off, it listens to nothing and hooks nothing; on, it keeps
-- each quest taken, handed in (with its experience and money) and dropped, with its title and level then, and each
-- level reached, per character, the latest KEEP of them, and tells its listeners.
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local settings = { enabled = true, history = false }
local changed = {}
local S = { Get = function(key) return settings[key] end, OnChange = function(fn) changed[#changed + 1] = fn end }
local account = {}
local ns = { AccountSettings = function() return account end, Apply = function() end,
    Completo = { Settings = S, CharKey = function() return "Me-Realm" end } }
function ns.OnApply(fn) local was = ns.Apply ns.Apply = function(...) was(...) fn(...) end end

local frames, hooks = {}, {}
local titles = { [33] = "Wolves Across the Border", [46] = "Bounty on Murlocs" }
local levels = { [33] = 5, [46] = 10 }
local abandoning
local now = 1000
local env = setmetatable({
    _G = { NaowhForever = ns },
    time = function() return now end,
    C_QuestLog = {
        GetTitleForQuestID = function(id) return titles[id] end,
        GetQuestDifficultyLevel = function(id) return levels[id] end,
        GetAbandonQuest = function() return abandoning end,
        SetAbandonQuest = function() end,
        AbandonQuest = function() end,
    },
    hooksecurefunc = function(t, name, fn) hooks[name] = fn; hooks[#hooks + 1] = t end,
    CreateFrame = function()
        local f = { events = {} }
        function f:RegisterEvent(e) self.events[e] = true end
        function f:UnregisterAllEvents() self.events = {} end
        function f:SetScript(_, fn) self.OnEvent = fn end
        frames[#frames + 1] = f
        return f
    end,
}, { __index = _G })
local chunk = assert(loadstring(Read("NaowhForever_Discovery/QuestList/History.lua")))
setfenv(chunk, env)
chunk()
local H = ns.Completo.History
frames[1].OnEvent(frames[1])
Check(#frames == 1 and next(hooks) == nil, "off: no event frame, no hooks")

local told = 0
H.OnChange(function() told = told + 1 end)
settings.history = true
changed[1]("history")
local events = frames[2]
Check(events.events.QUEST_ACCEPTED and events.events.QUEST_TURNED_IN and events.events.PLAYER_LEVEL_UP,
    "on: listens for quests taken and handed in, and levels")
Check(hooks.SetAbandonQuest and hooks.AbandonQuest and hooks[1] == env.C_QuestLog, "and hooks the quest log's abandon")

events.OnEvent(events, "QUEST_ACCEPTED", 33)
now = 2000
events.OnEvent(events, "QUEST_TURNED_IN", 33, 450, 75)
events.OnEvent(events, "PLAYER_LEVEL_UP", 6)
local list = H.List()
Check(#list == 3 and told == 3, "three entries, each told")
local taken, handed, level = list[1], list[2], list[3]
Check(taken[H.KIND] == H.TAKEN and taken[H.ID] == 33 and taken[H.TITLE] == "Wolves Across the Border"
    and taken[H.AT_LEVEL] == 5 and taken[H.WHEN] == 1000, "a quest taken: its title and level then, and when")
Check(handed[H.KIND] == H.HANDED_IN and handed[H.XP] == 450 and handed[H.MONEY] == 75 and handed[H.WHEN] == 2000,
    "a quest handed in: its experience and money")
Check(level[H.KIND] == H.LEVEL and level[H.ID] == 6, "a level reached")

events.OnEvent(events, "QUEST_ACCEPTED", 46)
abandoning = 46
hooks.SetAbandonQuest()
abandoning = nil
hooks.AbandonQuest()
Check(list[5][H.KIND] == H.DROPPED and list[5][H.ID] == 46 and list[5][H.TITLE] == "Bounty on Murlocs",
    "a dropped quest is the one the abandon was set for")
hooks.AbandonQuest()
Check(#list == 5, "an abandon with none set keeps nothing")
Check(account.completoHistory["Me-Realm"] == list, "kept per character")

for _ = 1, 5000 do events.OnEvent(events, "PLAYER_LEVEL_UP", 7) end
Check(#list == 5000 and list[1][H.KIND] == H.LEVEL, "only the latest 5000 are kept")

settings.history = false
changed[1]("history")
Check(next(events.events) == nil, "turned off: listens to nothing")
abandoning = 33
hooks.SetAbandonQuest()
hooks.AbandonQuest()
Check(#list == 5000 and list[#list][H.KIND] == H.LEVEL, "and the hooks keep nothing")

print(("test-completo-quest-history: %d checks passed"):format(checks))
