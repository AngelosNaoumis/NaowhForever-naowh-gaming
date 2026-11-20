-- NameplateIcons.lua: Quest Nameplates, a quest icon over the nameplate of each creature an objective in your log still needs.
local ns = _G.NaowhForever

local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit
local GetLogIndexForQuestID = C_QuestLog.GetLogIndexForQuestID
local GetQuestObjectives = C_QuestLog.GetQuestObjectives
local IsComplete = C_QuestLog.IsComplete
local IsFailed = C_QuestLog.IsFailed

local Completo = ns.Completo
local S = Completo.Settings
local Q = Completo.Quests
local Objectives = Completo.Objectives
local D = ns.CompletoQuestData

local CREATURE, VEHICLE = "Creature", "Vehicle"
local STEP = 3
local ATLAS = "questobjective"
local ICON_SIZE = 20
local ICON_GAP = 2
local EVENTS = { "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "QUEST_LOG_UPDATE", "QUEST_REMOVED" }
local NONE = {}

local events
local npcs, plates, icons = {}, {}, {}

local function On()
    return S.Get("enabled") and S.Get("nameplateQuests")
end

local function NpcID(unit)
    local guid = UnitGUID(unit)
    if issecretvalue(guid) or type(guid) ~= "string" then return nil end
    local kind, _, _, _, _, entry = strsplit("-", guid)
    if kind ~= CREATURE and kind ~= VEHICLE then return nil end
    return tonumber(entry)
end

local function Needed(npc)
    local list = D.Creatures[npc]
    if not list then return false end
    for i = 1, #list, STEP do
        local quest = list[i]
        if GetLogIndexForQuestID(quest) and not IsComplete(quest) and not IsFailed(quest) and not Q.Hidden(quest) then
            local _, done = Objectives.Progress(GetQuestObjectives(quest) or NONE, list[i + 1], list[i + 2] == 1)
            if not done then return true end
        end
    end
    return false
end

local function Icon(plate)
    local icon = icons[plate]
    if icon then return icon end
    icon = CreateFrame("Frame", nil, plate)
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("BOTTOM", plate, "TOP", 0, ICON_GAP)
    icon.texture = icon:CreateTexture(nil, "OVERLAY")
    icon.texture:SetAllPoints()
    icon.texture:SetAtlas(ATLAS)
    icons[plate] = icon
    return icon
end

local function Paint(unit)
    local plate, npc = plates[unit], npcs[unit]
    if not plate then return end
    if npc and Needed(npc) then
        Icon(plate):Show()
    elseif icons[plate] then
        icons[plate]:Hide()
    end
end

local function Add(unit)
    local plate = GetNamePlateForUnit(unit)
    if not plate or plate:IsForbidden() then return end
    plates[unit], npcs[unit] = plate, NpcID(unit)
    Paint(unit)
end

local function Remove(unit)
    local plate = plates[unit]
    if plate and icons[plate] then icons[plate]:Hide() end
    plates[unit], npcs[unit] = nil, nil
end

local function PaintAll()
    for unit in pairs(plates) do Paint(unit) end
end

local function OnEvent(_, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
        Add(unit)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        Remove(unit)
    else
        PaintAll()
    end
end

local function Apply()
    for unit in pairs(plates) do Remove(unit) end
    if not On() then
        if events then events:UnregisterAllEvents() end
        return
    end
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
    end
    for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
        local unit = plate.namePlateUnitToken
        if unit then Add(unit) end
    end
end

S.OnChange(function(key)
    if key == "enabled" or key == "nameplateQuests" then Apply() end
end)
hooksecurefunc(Q, "SetHidden", PaintAll)
hooksecurefunc(Q, "ShowHidden", PaintAll)
ns.OnApply(Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    Apply()
end)
