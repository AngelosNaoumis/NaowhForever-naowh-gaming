-- Run with Lua 5.1 from the repository root: Quest Tooltips. Off, it adds no tooltip hook; on, a creature a quest in
-- your log needs names that quest and its objective while it is still to do, once per quest; it adds nothing where
-- the game's tooltip shows quest lines already, nor for a secret GUID, a player, a done or hidden quest. An object, by its
-- GUID or ID, and an item, by its ID, name theirs the same way.
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local QUEST_OBJECTIVE, QUEST_TITLE = 8, 17
local settings = { enabled = true, unitTips = false }
local changed = {}
local S = { Get = function(key) return settings[key] end, OnChange = function(fn) changed[#changed + 1] = fn end }
local inLog, complete, hidden, objectives = {}, {}, {}, {}
local partyOn = false
local ns = { Apply = function() end, Shared = { Places = { SameMap = function(id) return id end } },
    CompletoQuestData = {
        Creatures = { [69] = { 33, 1, 1 }, [6] = { 33, 1, 1, 34, 0, 0 } },
        Objects = { [1722] = { 35, 2, 0 } }, Items = { [769] = { 33, 1, 1 } } },
    Completo = { Settings = S, Style = { GOLD_RGB = { r = 1, g = 0.8, b = 0 }, Hint = function() return 1, 1, 1 end },
        Quests = { Hidden = function(id) return hidden[id] == true end, Title = function() return nil end },
        Party = { Progress = function(quest, _, _, fn)
            if partyOn and quest == 34 then fn("Bob", { numFulfilled = 7, numRequired = 10 }) end
        end } } }
function ns.OnApply(fn) local was = ns.Apply ns.Apply = function(...) was(...) fn(...) end end

local postCalls = {}
local lines, shown = {}, 0
local tooltip = { IsForbidden = function() return false end, AddLine = function(_, text) lines[#lines + 1] = text end,
    Show = function() shown = shown + 1 end }
local env = setmetatable({
    _G = { NaowhForever = ns },
    GameTooltip = tooltip,
    Enum = { TooltipDataLineType = { QuestObjective = QUEST_OBJECTIVE, QuestTitle = QUEST_TITLE },
        TooltipDataType = { Item = 0, Unit = 2, Object = 4 } },
    TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) postCalls[kind] = fn end },
    issecretvalue = function(v) return v == "SECRET" end,
    strsplit = function(sep, text)
        local out = {}
        for part in (text .. sep):gmatch("(.-)" .. sep) do out[#out + 1] = part end
        return unpack(out)
    end,
    C_QuestLog = {
        GetLogIndexForQuestID = function(id) return inLog[id] and 1 or nil end,
        GetQuestObjectives = function(id) return objectives[id] end,
        GetTitleForQuestID = function(id) return "Quest " .. id end,
        IsComplete = function(id) return complete[id] == true end,
    },
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    CreateFrame = function()
        local f = {}
        function f:RegisterEvent() end
        function f:UnregisterAllEvents() end
        function f:SetScript(_, fn) self.OnEvent = fn end
        ns.boot = f
        return f
    end,
}, { __index = _G })
local objectivesChunk = assert(loadstring(Read("NaowhForever_Discovery/QuestList/Objectives.lua")))
setfenv(objectivesChunk, env)
objectivesChunk()
local chunk = assert(loadstring(Read("NaowhForever_Discovery/QuestList/UI/UnitTips.lua")))
setfenv(chunk, env)
chunk()
ns.boot.OnEvent(ns.boot)
Check(next(postCalls) == nil, "off: no tooltip hook")

settings.unitTips = true
changed[1]("unitTips")
Check(postCalls[2] and postCalls[4] and postCalls[0], "on: a unit, an object and an item tooltip hook")

local function Tip(guid, data, kind)
    lines, shown = {}, 0
    data = data or {}
    data.guid = guid
    postCalls[kind or 2](tooltip, data)
    return table.concat(lines, "\n")
end
local WOLF, KOBOLD = "Creature-0-1-0-12-69-0000000001", "Creature-0-1-0-12-6-0000000002"

inLog[33] = true
objectives[33] = { { text = "Tough Wolf Meat: 2/8", type = "item", finished = false } }
Check(Tip(WOLF) == "Quest 33\n  - Tough Wolf Meat: 2/8" and shown == 1, "a wolf names the quest and its meat")
objectives[33][1].finished = true
Check(Tip(WOLF) == "", "not once the meat is all in")
objectives[33][1].finished = false

inLog[34] = true
objectives[34] = { { text = "Kobold Vermin slain: 3/10", type = "monster", finished = false } }
Check(Tip(KOBOLD) == "Quest 33\n  - Tough Wolf Meat: 2/8\nQuest 34\n  - Kobold Vermin slain: 3/10",
    "a creature two quests need names both, each once")

Check(Tip(KOBOLD, { lines = { { type = QUEST_TITLE } } }) == "", "the game's own quest lines are left alone")
partyOn = true
Check(Tip(KOBOLD, { lines = { { type = QUEST_TITLE } } }) == "Quest 34\n  Bob: 7/10",
    "but a party member's progress is still added under them")
partyOn = false
Check(Tip("SECRET") == "" and Tip("Player-1-0000001") == "", "a secret GUID or a player adds nothing")
complete[34], hidden[33] = true, true
Check(Tip(KOBOLD) == "", "a done or hidden quest adds nothing")
complete[34], hidden[33] = nil, nil
inLog[33], inLog[34] = nil, nil
Check(Tip(KOBOLD) == "" and shown == 0, "nor a quest not in your log")

inLog[33], inLog[35] = true, true
objectives[35] = { { text = "Ball and chain 1", type = "object", finished = true },
    { text = "Ball and chain 2", type = "object", finished = false } }
Check(Tip("GameObject-0-1-0-12-1722-0000000003", nil, 4) == "Quest 35\n  - Ball and chain 2",
    "an object names its quest and the objective it is, by its place")
Check(Tip(nil, { id = 1722 }, 4) == "Quest 35\n  - Ball and chain 2", "an object with no GUID, by its ID")
Check(Tip("Creature-0-1-0-12-1722-0000000003", nil, 4) == "", "a creature's GUID on an object tooltip is not an object")
Check(Tip(nil, { id = 769 }, 0) == "Quest 33\n  - Tough Wolf Meat: 2/8", "an item names the quest it is collected for")
Check(Tip(nil, { id = 770 }, 0) == "" and Tip(nil, { id = "SECRET" }, 0) == "", "nothing for another item or a secret ID")
inLog[35] = nil

settings.unitTips = false
inLog[33] = true
Check(Tip(WOLF) == "", "off again: the hook stays but adds nothing")

print(("test-completo-unit-tips: %d checks passed"):format(checks))
