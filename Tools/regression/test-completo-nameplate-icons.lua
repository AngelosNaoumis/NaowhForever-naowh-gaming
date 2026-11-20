-- Run with Lua 5.1 from the repository root: Quest Nameplates. Off, it listens to nothing; on, a creature's nameplate
-- gets the quest icon while an objective in your log still needs it, and loses it once that is done, the quest is
-- hidden, failed or handed in, or the nameplate goes; a secret GUID, a player or a forbidden nameplate gets none.
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local settings = { enabled = true, nameplateQuests = false }
local changed = {}
local S = { Get = function(key) return settings[key] end, OnChange = function(fn) changed[#changed + 1] = fn end }
local inLog, complete, failed, hidden, objectives = {}, {}, {}, {}, {}
local Q = { Hidden = function(id) return hidden[id] == true end }
function Q.SetHidden(id, on) hidden[id] = on or nil end
function Q.ShowHidden() for id in pairs(hidden) do hidden[id] = nil end end
local ns = { Apply = function() end, Shared = { Places = { SameMap = function(id) return id end } },
    CompletoQuestData = { Creatures = { [69] = { 33, 1, 1 }, [6] = { 34, 0, 0 } } },
    Completo = { Settings = S, Quests = Q } }
function ns.OnApply(fn) local was = ns.Apply ns.Apply = function(...) was(...) fn(...) end end

local frames = {}
local function Frame(parent)
    local f = { parent = parent, events = {}, shown = true }
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterAllEvents() self.events = {} end
    function f:SetScript(_, fn) self.OnEvent = fn end
    function f:SetSize() end
    function f:SetPoint() end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:IsShown() return self.shown end
    function f:CreateTexture()
        return { SetAllPoints = function() end, SetAtlas = function(t, atlas) t.atlas = atlas end }
    end
    frames[#frames + 1] = f
    return f
end

local guids, plates = {}, {}
local function Plate(unit, guid, forbidden)
    local plate = { namePlateUnitToken = unit, IsForbidden = function() return forbidden == true end }
    plates[unit], guids[unit] = plate, guid
    return plate
end
local env = setmetatable({
    _G = { NaowhForever = ns },
    C_NamePlate = {
        GetNamePlateForUnit = function(unit) return plates[unit] end,
        GetNamePlates = function()
            local list = {}
            for _, plate in pairs(plates) do list[#list + 1] = plate end
            return list
        end,
    },
    C_QuestLog = {
        GetLogIndexForQuestID = function(id) return inLog[id] and 1 or nil end,
        GetQuestObjectives = function(id) return objectives[id] end,
        IsComplete = function(id) return complete[id] == true end,
        IsFailed = function(id) return failed[id] == true end,
    },
    UnitGUID = function(unit) return guids[unit] end,
    hooksecurefunc = function(t, name, post)
        local was = t[name]
        t[name] = function(...) was(...) post(...) end
    end,
    issecretvalue = function(v) return v == "SECRET" end,
    strsplit = function(sep, text)
        local out = {}
        for part in (text .. sep):gmatch("(.-)" .. sep) do out[#out + 1] = part end
        return unpack(out)
    end,
    CreateFrame = function(_, _, parent) return Frame(parent) end,
}, { __index = _G })
for _, path in ipairs({ "NaowhForever_Discovery/QuestList/Objectives.lua",
    "NaowhForever_Discovery/QuestList/UI/NameplateIcons.lua" }) do
    local chunk = assert(loadstring(Read(path)))
    setfenv(chunk, env)
    chunk()
end
local boot = frames[1]
boot.OnEvent(boot)
Check(#frames == 1, "off: no event frame, no icons")

local function IconOn(plate)
    for _, f in ipairs(frames) do
        if f.parent == plate then return f.shown end
    end
    return false
end

local WOLF, KOBOLD = "Creature-0-1-0-12-69-0000000001", "Creature-0-1-0-12-6-0000000002"
inLog[33] = true
objectives[33] = { { text = "Tough Wolf Meat: 2/8", type = "item", finished = false } }
local early = Plate("nameplate1", WOLF)
settings.nameplateQuests = true
changed[1]("nameplateQuests")
local events = frames[2]
Check(events.events.NAME_PLATE_UNIT_ADDED and events.events.QUEST_LOG_UPDATE, "on: it listens")
Check(IconOn(early), "a nameplate already shown is marked when it turns on")

local kobold = Plate("nameplate2", KOBOLD)
events.OnEvent(events, "NAME_PLATE_UNIT_ADDED", "nameplate2")
Check(not IconOn(kobold), "not a creature for a quest you do not have")
inLog[34] = true
objectives[34] = { { text = "Kobold Vermin slain: 3/10", type = "monster", finished = false } }
events.OnEvent(events, "QUEST_LOG_UPDATE")
Check(IconOn(kobold), "marked once the quest is in your log")

objectives[33][1].finished = true
events.OnEvent(events, "QUEST_LOG_UPDATE")
Check(not IconOn(early), "the icon goes once its objective is done")
objectives[33][1].finished = false
hidden[34] = true
events.OnEvent(events, "QUEST_LOG_UPDATE")
Check(not IconOn(kobold), "nor for a hidden quest")
hidden[34] = nil
Q.SetHidden(34, true)
Check(not IconOn(kobold), "hiding a quest takes its icons off at once")
Q.ShowHidden()
Check(IconOn(kobold), "and showing it again puts them back")
failed[34] = true
events.OnEvent(events, "QUEST_LOG_UPDATE")
Check(not IconOn(kobold), "nor for a failed quest")
failed[34] = nil
complete[34] = true
events.OnEvent(events, "QUEST_LOG_UPDATE")
Check(not IconOn(kobold), "nor one ready to hand in")
complete[34] = nil

local secret = Plate("nameplate3", "SECRET")
events.OnEvent(events, "NAME_PLATE_UNIT_ADDED", "nameplate3")
local player = Plate("nameplate4", "Player-1-00000001")
events.OnEvent(events, "NAME_PLATE_UNIT_ADDED", "nameplate4")
local forbidden = Plate("nameplate5", WOLF, true)
events.OnEvent(events, "NAME_PLATE_UNIT_ADDED", "nameplate5")
Check(not IconOn(secret) and not IconOn(player) and not IconOn(forbidden),
    "a secret GUID, a player or a forbidden nameplate gets none")

events.OnEvent(events, "QUEST_LOG_UPDATE")
Check(IconOn(early), "the wolf is marked again")
events.OnEvent(events, "NAME_PLATE_UNIT_REMOVED", "nameplate1")
Check(not IconOn(early), "a nameplate that goes loses its icon")
local count = #frames
plates.nameplate1, guids.nameplate1 = early, KOBOLD
events.OnEvent(events, "NAME_PLATE_UNIT_ADDED", "nameplate1")
Check(IconOn(early) and #frames == count, "a reused nameplate reuses its icon for its new creature")

settings.nameplateQuests = false
changed[1]("nameplateQuests")
Check(next(events.events) == nil and not IconOn(early) and not IconOn(kobold), "turned off: no events, no icons")

print(("test-completo-nameplate-icons: %d checks passed"):format(checks))
