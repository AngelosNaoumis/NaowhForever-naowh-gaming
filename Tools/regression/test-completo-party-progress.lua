-- Run with Lua 5.1 from the repository root: Share Quest Progress. Off, it registers nothing; on, it says the quests in
-- your log and each objective's count to your party, then only what changed, never in combat or a raid, in messages
-- the channel takes; it takes a party member's, checked, and gives each one's progress on an objective by its place.
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local ME, BOB = "Player-1-00000001", "Player-1-00000002"
local settings = { enabled = true, partyProgress = false }
local changed = {}
local S = { Get = function(key) return settings[key] end, OnChange = function(fn) changed[#changed + 1] = fn end }
local ns = { Apply = function() end, Shared = { Places = { SameMap = function(id) return id end } },
    CompletoQuestData = {}, Completo = { Settings = S, Quests = { Hidden = function() return false end } },
    SenderIs = function(sender, _, guid) return sender == "Bob" and guid == BOB end }
function ns.OnApply(fn) local was = ns.Apply ns.Apply = function(...) was(...) fn(...) end end

local log, objectives = {}, {}
local said, prefixes, timers = {}, {}, {}
local refuse = false
local frames = {}
local combat, lockdown, group, raid = false, false, true, false
local party = { BOB }
local env = setmetatable({
    _G = { NaowhForever = ns },
    C_QuestLog = {
        GetNumQuestLogEntries = function() return #log end,
        GetQuestIDForLogIndex = function(i) return log[i] end,
        GetQuestObjectives = function(id) return objectives[id] end,
    },
    C_ChatInfo = {
        SendAddonMessage = function(prefix, msg, channel)
            if refuse then return 9 end
            said[#said + 1] = { prefix, msg, channel }
            return 0
        end,
        RegisterAddonMessagePrefix = function(prefix) prefixes[#prefixes + 1] = prefix end,
        InChatMessagingLockdown = function() return lockdown end,
    },
    C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end },
    IsInGroup = function(category) return group and category == nil end,
    IsInRaid = function() return raid end,
    InCombatLockdown = function() return combat end,
    LE_PARTY_CATEGORY_INSTANCE = 2,
    Enum = { SendAddonMessageResult = { Success = 0 } },
    UnitGUID = function(unit)
        if unit == "player" then return ME end
        return party[tonumber(unit:match("%d+"))]
    end,
    Ambiguate = function(name) return name end,
    issecretvalue = function(v) return v == "SECRET" end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    CreateFrame = function()
        local f = { events = {} }
        function f:RegisterEvent(e) self.events[e] = true end
        function f:UnregisterAllEvents() self.events = {} end
        function f:SetScript(_, fn) self.OnEvent = fn end
        frames[#frames + 1] = f
        return f
    end,
}, { __index = _G })
for _, path in ipairs({ "NaowhForever_Discovery/QuestList/Objectives.lua", "NaowhForever_Discovery/QuestList/Party.lua" }) do
    local chunk = assert(loadstring(Read(path)))
    setfenv(chunk, env)
    chunk()
end
local P = ns.Completo.Party
local boot = frames[1]
boot.OnEvent(boot)
Check(#prefixes == 0 and #frames == 1, "off: no prefix, no events")

local function RunTimers()
    local list = timers
    timers = {}
    for _, fn in ipairs(list) do fn() end
end

local function Objective(kind, have, need) return { type = kind, numFulfilled = have, numRequired = need } end
log = { 33, 0, 46 }
objectives[33] = { Objective("item", 2, 8) }
objectives[46] = { Objective("monster", 3, 10), Objective("item", 0, 4) }
settings.partyProgress = true
changed[1]("partyProgress")
local events = frames[2]
Check(prefixes[1] == "NaowhQuests" and events.events.CHAT_MSG_ADDON and events.events.QUEST_LOG_UPDATE,
    "on: its prefix, and it listens")
Check(#said == 0, "nothing said at once")
RunTimers()
Check(said[1][2] == "1 ? " .. ME and said[1][3] == "PARTY", "it asks the party for theirs")
local body = said[2][2]
Check(body:sub(1, #ME + 3) == "1 " .. ME .. " " and body:find("33:i2/8", 1, true) and body:find("46:o3/10,i0/4", 1, true),
    "then says each quest and its objectives' counts")

said = {}
objectives[33] = { Objective("item", 3, 8) }
events.OnEvent(events, "QUEST_LOG_UPDATE")
events.OnEvent(events, "QUEST_LOG_UPDATE")
RunTimers()
Check(#said == 1 and said[1][2] == "1 " .. ME .. " 33:i3/8", "then only what changed, once for a burst")

said = {}
log = { 46 }
events.OnEvent(events, "QUEST_REMOVED")
RunTimers()
Check(said[1][2] == "1 " .. ME .. " 33:-", "a quest gone from the log is said gone")

said = {}
combat = true
objectives[46][1] = Objective("monster", 4, 10)
events.OnEvent(events, "QUEST_LOG_UPDATE")
RunTimers()
Check(#said == 0, "nothing in combat")
combat = false
events.OnEvent(events, "PLAYER_REGEN_ENABLED")
RunTimers()
Check(#said == 1 and said[1][2]:find("46:o4/10", 1, true), "said once combat ends")

said = {}
raid = true
objectives[46][1] = Objective("monster", 5, 10)
events.OnEvent(events, "QUEST_LOG_UPDATE")
RunTimers()
Check(#said == 0, "nothing in a raid")
raid = false

said = {}
events.OnEvent(events, "GROUP_ROSTER_UPDATE")
RunTimers()
Check(#said == 0, "a roster change with no one new says nothing")

said = {}
refuse = true
objectives[46][1] = Objective("monster", 6, 10)
events.OnEvent(events, "QUEST_LOG_UPDATE")
RunTimers()
refuse = false
RunTimers()
Check(#said == 1 and said[1][2]:find("46:o6/10", 1, true), "a message the channel refused is said again")

said = {}
log = {}
for q = 1000, 1034 do
    log[#log + 1] = q
    objectives[q] = { Objective("monster", 1, 10), Objective("item", 2, 6), Objective("item", 3, 9) }
end
events.OnEvent(events, "CHAT_MSG_ADDON", "NaowhQuests", "1 ? " .. BOB, "PARTY", "Bob")
RunTimers()
local longest = 0
for _, s in ipairs(said) do longest = math.max(longest, #s[2]) end
Check(#said > 3 and longest <= 255, "a long log goes in several messages the channel takes")

local seen
local function Seen(name, objective) seen = { name, objective.numFulfilled, objective.numRequired } end
local function From(sender, msg, channel)
    events.OnEvent(events, "CHAT_MSG_ADDON", "NaowhQuests", msg, channel or "PARTY", sender)
end
From("Bob", "1 " .. BOB .. " 46:o4/10,i1/4;33:i8/8")
seen = nil
P.Progress(46, 1, true, Seen)
Check(seen and seen[1] == "Bob" and seen[2] == 1 and seen[3] == 4, "a member's progress, by the objective's place")
seen = nil
P.Progress(46, 1, false, Seen)
Check(seen and seen[2] == 4, "kills apart from items")
seen = nil
P.Progress(33, 1, true, Seen)
Check(seen == nil, "nothing for an objective they have done")

From("Eve", "1 " .. BOB .. " 47:o1/10")
From("SECRET", "1 " .. BOB .. " 47:o1/10")
From("Bob", "1 " .. BOB .. " 47:o1/10", "GUILD")
From("Bob", "1 " .. BOB .. " 47:o1/99999")
seen = nil
P.Progress(47, 1, false, Seen)
Check(seen == nil, "not from someone else, a secret, another channel, nor past its bounds")
From("Bob", "1 " .. ME .. " 47:o1/10")
P.Progress(47, 1, false, Seen)
Check(seen == nil, "nor one that says it is you")

From("Bob", "1 " .. BOB .. " 48:o1/10;46:-;49:o1/99999")
seen = nil
P.Progress(48, 1, false, Seen)
Check(seen == nil, "a message with one bad entry is taken not at all")
P.Progress(46, 1, true, Seen)
Check(seen and seen[2] == 1, "so what it says gone is still there")

From("Bob", "1 " .. BOB .. " 46:-")
seen = nil
P.Progress(46, 1, true, Seen)
Check(seen == nil, "a quest they say gone is gone")

said = {}
From("Bob", "1 ? " .. BOB)
RunTimers()
Check(#said > 0, "asked, it says the whole log again")
said = {}
From("Bob", "1 ? " .. ME)
From("Eve", "1 ? " .. BOB)
RunTimers()
Check(#said == 0, "its own ask echoed back, or one from someone else, is not answered")

From("Bob", "1 " .. BOB .. " 46:o4/10")
party = {}
events.OnEvent(events, "GROUP_ROSTER_UPDATE")
seen = nil
P.Progress(46, 1, false, Seen)
Check(seen == nil, "a member who leaves is forgotten")

party = { BOB }
events.OnEvent(events, "GROUP_ROSTER_UPDATE")
said = {}
RunTimers()
Check(#said > 0 and said[1][2] == "1 ? " .. ME, "someone joining: it asks, and says its log")

said = {}
events.OnEvent(events, "QUEST_LOG_UPDATE")
settings.partyProgress = false
changed[1]("partyProgress")
RunTimers()
Check(next(events.events) == nil and #said == 0, "turned off: listens to nothing, and a send already queued says nothing")

print(("test-completo-party-progress: %d checks passed"):format(checks))
