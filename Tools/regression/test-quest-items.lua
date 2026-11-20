-- Run with Lua 5.1 from the repository root: Quest Item Info (NaowhForever_QoL/Questing/QuestItems.lua).
-- An item in your bags named by a quest's item objective, and an item that starts a quest, are linked to that
-- quest and named on its tooltip. A learning pass reads bags and the log without a new table per slot or entry,
-- and objective progress (QUEST_LOG_UPDATE) is heard only for the first fill and after an accept.
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end
local Measure = dofile("Tools/regression/measure.lua")(check)

local function Noop() end
local events, timers, tooltipHook = nil, {}, nil
local registered = {}

local frameMethods = {
    SetScript = function(f, name, fn) f[name] = fn end,
    RegisterEvent = function(f, event) if f == events then registered[event] = true end end,
    UnregisterEvent = function(f, event) if f == events then registered[event] = nil end end,
    UnregisterAllEvents = function(f) if f == events then registered = {} end end,
}
local frameMeta = { __index = function(_, k) return frameMethods[k] or Noop end }
local made = 0
local function CreateFrame()
    local f = setmetatable({}, frameMeta)
    made = made + 1
    if made == 2 then events = f end
    return f
end

local PELT, LETTER, ROCK = 100, 200, 300
local bags = { [0] = { PELT, LETTER, ROCK } }
local names = { [PELT] = "Wolf Pelt", [LETTER] = "Sealed Letter", [ROCK] = "Rock" }
local WOLVES, LETTER_QUEST = 501, 502
local quests = { WOLVES }
local objectives = { [WOLVES] = { { "Wolf Pelt: 2/5", "item" }, { "Wolf slain: 1/8", "monster" } } }

local settings = { enabled = true, questItemInfo = true }
local account = {}
local ns
ns = {
    QoLSettings = { Get = function(k) return settings[k] end, Set = Noop },
    Shared = { Style = { HAVE_RGB = { r = 0, g = 1, b = 0 } },
        Settings = { Page = function() return { Card = Noop } end } },
    THEME = { muted = { r = 1, g = 1, b = 1 } },
    L = function(s) return s end,
    AccountSettings = function() return account end,
    OnApply = function(fn) ns.Apply = fn end,
}

local env = setmetatable({
    NaowhForever = ns,
    CreateFrame = CreateFrame,
    hooksecurefunc = Noop,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    GetTime = function() return 100 end,
    NUM_BAG_SLOTS = 0,
    ItemLocation = { CreateEmpty = function() return { SetBagAndSlot = Noop } end },
    C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end },
    Enum = { TooltipDataType = { Item = 0 } },
    TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) tooltipHook = fn end },
    C_Item = {
        GetItemNameByID = function(id) return names[id] end,
        GetStackCount = function() return 1 end,
        GetItemInfoInstant = function() return nil end,
    },
    C_Container = {
        GetContainerNumSlots = function(bag) return bags[bag] and #bags[bag] or 0 end,
        GetContainerItemID = function(bag, slot) return bags[bag][slot] end,
        GetContainerItemQuestInfo = function(bag, slot)
            if bags[bag][slot] == LETTER then return { isQuestItem = true, questID = LETTER_QUEST, isActive = false } end
            return { isQuestItem = false }
        end,
    },
    C_QuestLog = {
        IsOnQuest = function(q) return q == WOLVES end,
        IsQuestFlaggedCompleted = function() return false end,
        GetTitleForQuestID = function(q) return q == WOLVES and "Wolf Hunt" or "A Letter" end,
        GetNumQuestLogEntries = function() return #quests end,
        GetQuestIDForLogIndex = function(i) return quests[i] end,
        GetNumQuestObjectives = function(q) return #objectives[q] end,
    },
    GetQuestObjectiveInfo = function(q, i) return objectives[q][i][1], objectives[q][i][2], false end,
    GetQuestLogSpecialItemInfo = function() return nil end,
}, { __index = _G })
env._G = env

Load({ "NaowhForever_QoL/Questing/QuestItems.lua" }, env)

local function RunTimers()
    while #timers > 0 do table.remove(timers, 1)() end
end

ns.Apply()
RunTimers()
check("listens for the first quest log fill", registered.QUEST_LOG_UPDATE)

local store = account.questItemLinks
check("the objective's item is linked to its quest", store.links[PELT] and store.links[PELT][WOLVES] == "Wolf Hunt")
check("a starter item is kept with its quest", store.starts[LETTER] and store.starts[LETTER][1] == LETTER_QUEST)
check("an unrelated item gets no link", store.links[ROCK] == nil and store.starts[ROCK] == nil)

local lines = {}
local tooltip = { AddLine = function(_, text) lines[#lines + 1] = text end }
tooltipHook(tooltip, { id = PELT })
check("the tooltip names the quest", lines[1] == "Quest: Wolf Hunt (in your log)")

events.OnEvent(events, "QUEST_LOG_UPDATE")
check("objective progress stops being heard after the first fill", not registered.QUEST_LOG_UPDATE)
events.OnEvent(events, "QUEST_ACCEPTED", WOLVES)
check("an accept listens for the log fill that follows", registered.QUEST_LOG_UPDATE)
RunTimers()

Measure("a learning pass", 1, function()
    events.OnEvent(events, "BAG_UPDATE_DELAYED")
    RunTimers()
end)

print("quest items: " .. checks .. " checks passed")
