-- QuestItems.lua: Quest Item Info: an item's tooltip names the quests it is for, and whether each is handed in.
-- Links are learned while a quest is in your log (its item objectives, its usable item, the quest an item starts, the
-- items it hands you on accepting) and kept account-wide, so an item left after the hand-in still names its quest.
-- An item with no learned quest gets no line: the game abandons a quest whose given item is destroyed, so guessing
-- "not needed" is never safe.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local St = ns.Shared.Style
local T = ns.THEME

local IsOnQuest = C_QuestLog.IsOnQuest
local IsDone = C_QuestLog.IsQuestFlaggedCompleted
local GetTitle = C_QuestLog.GetTitleForQuestID
local GetSpecialItem = _G.GetQuestLogSpecialItemInfo

local PAGE = "QoL/Loot & Items"
local ORDER = 16
local KEYS = { enabled = true, questItemInfo = true }
local STORE = "questItemLinks"
local LAST_BAG = NUM_BAG_SLOTS or 4
local LEARN_DELAY = 0.5
local GIVEN_WINDOW = 5
local LOG_RGB = { r = 1, g = 0.82, b = 0 }
local FREE_RGB = St.HAVE_RGB

local TEXT_FOR = ns.L("Quest: %s")
local TEXT_STARTS = ns.L("Starts: %s")
local TEXT_IN_LOG = ns.L(" (in your log)")
local TEXT_DONE = ns.L(" (handed in)")
local TEXT_NOT_TAKEN = ns.L(" (not in your log)")
local TEXT_FREE = ns.L("Every quest it is known for is handed in")

local events, pending, accepted, acceptedAt
local bagNames, bagStarts, bagCounts, lastCounts = {}, {}, {}, nil
local notStarter = {}
local here = ItemLocation:CreateEmpty()

local function On()
    return S.Get("enabled") and S.Get("questItemInfo")
end

local function Store()
    local account = ns.AccountSettings()
    if type(account[STORE]) ~= "table" then account[STORE] = { links = {}, starts = {} } end
    local store = account[STORE]
    store.links = type(store.links) == "table" and store.links or {}
    store.starts = type(store.starts) == "table" and store.starts or {}
    return store
end

local function Link(itemID, questID, name)
    local links = Store().links
    local quests = links[itemID] or {}
    links[itemID] = quests
    quests[questID] = name or quests[questID] or true
end

local function ReadBags()
    wipe(bagNames)
    wipe(bagStarts)
    wipe(bagCounts)
    local starts = Store().starts
    for bag = 0, LAST_BAG do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local id = C_Container.GetContainerItemID(bag, slot)
            if id then
                here:SetBagAndSlot(bag, slot)
                bagCounts[id] = (bagCounts[id] or 0) + (C_Item.GetStackCount(here) or 1)
                local name = C_Item.GetItemNameByID(id)
                if name and name ~= "" then bagNames[name] = id end
                if not (notStarter[id] or type(starts[id]) == "table" and starts[id][2]) then
                    local quest = C_Container.GetContainerItemQuestInfo(bag, slot)
                    if quest and quest.questID then bagStarts[id] = quest.questID else notStarter[id] = true end
                end
            end
        end
    end
end

local function LearnObjectives(questID)
    for i = 1, C_QuestLog.GetNumQuestObjectives(questID) do
        local text, kind = GetQuestObjectiveInfo(questID, i, false)
        if kind == "item" and text and text ~= "" then
            for name, id in pairs(bagNames) do
                if text:find(name, 1, true) then Link(id, questID, GetTitle(questID)) end
            end
        end
    end
end

local function LearnSpecial(index, questID)
    if not GetSpecialItem then return end
    local link = GetSpecialItem(index)
    local id = link and C_Item.GetItemInfoInstant(link)
    if id then Link(id, questID, GetTitle(questID)) end
end

local function LearnStarts()
    local starts = Store().starts
    for id, questID in pairs(bagStarts) do
        starts[id] = { questID, GetTitle(questID) }
    end
end

local function LearnGiven()
    if accepted and lastCounts and GetTime() - acceptedAt <= GIVEN_WINDOW then
        for id, count in pairs(bagCounts) do
            if count > (lastCounts[id] or 0) then Link(id, accepted, GetTitle(accepted)) end
        end
    end
    lastCounts = lastCounts or {}
    wipe(lastCounts)
    for id, count in pairs(bagCounts) do lastCounts[id] = count end
end

local function Learn()
    pending = false
    if not On() then return end
    ReadBags()
    LearnGiven()
    LearnStarts()
    for index = 1, C_QuestLog.GetNumQuestLogEntries() do
        local questID = C_QuestLog.GetQuestIDForLogIndex(index)
        if questID and questID > 0 then
            LearnObjectives(questID)
            LearnSpecial(index, questID)
        end
    end
end

local function LearnSoon()
    if pending then return end
    pending = true
    C_Timer.After(LEARN_DELAY, Learn)
end

local function OnEvent(_, event, ...)
    if event == "QUEST_ACCEPTED" then
        local first, second = ...
        accepted, acceptedAt = second or first, GetTime()
        events:RegisterEvent("QUEST_LOG_UPDATE")
    elseif event == "QUEST_LOG_UPDATE" then
        events:UnregisterEvent("QUEST_LOG_UPDATE")
    end
    LearnSoon()
end

local function QuestName(questID, saved)
    return GetTitle(questID) or (type(saved) == "string" and saved) or tostring(questID)
end

local function QuestLine(tooltip, format, questID, saved)
    local name = QuestName(questID, saved)
    if IsOnQuest(questID) then
        tooltip:AddLine(format:format(name) .. TEXT_IN_LOG, LOG_RGB.r, LOG_RGB.g, LOG_RGB.b)
        return true
    elseif IsDone(questID) then
        tooltip:AddLine(format:format(name) .. TEXT_DONE, T.muted.r, T.muted.g, T.muted.b)
        return false
    end
    tooltip:AddLine(format:format(name) .. TEXT_NOT_TAKEN, T.muted.r, T.muted.g, T.muted.b)
    return true
end

local function OnItemTooltip(tooltip, data)
    if not On() then return end
    local id = data and data.id
    if not id or (issecretvalue and issecretvalue(id)) then return end
    local store = Store()
    local quests, start = store.links[id], store.starts[id]
    if not (quests or start) then return end
    local known, needed = false, false
    if type(start) == "table" and start[1] then
        known = true
        needed = QuestLine(tooltip, TEXT_STARTS, start[1], start[2]) or needed
    end
    for questID, saved in pairs(quests or {}) do
        known = true
        needed = QuestLine(tooltip, TEXT_FOR, questID, saved) or needed
    end
    if known and not needed then tooltip:AddLine(TEXT_FREE, FREE_RGB.r, FREE_RGB.g, FREE_RGB.b) end
end

local function Apply()
    if not On() then
        if events then events:UnregisterAllEvents() end
        return
    end
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItemTooltip)
    end
    events:RegisterEvent("QUEST_LOG_UPDATE")
    events:RegisterEvent("BAG_UPDATE_DELAYED")
    events:RegisterEvent("QUEST_ACCEPTED")
    LearnSoon()
end

local function OnSettingChanged(key)
    if KEYS[key] then Apply() end
end

hooksecurefunc(S, "Set", OnSettingChanged)
ns.OnApply(Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

ns.Shared.Settings.Page(PAGE, S):Card({
    id = "questItems", name = "Quest Items", order = ORDER, into = "lootTrade",
    rows = {
        { key = "questItemInfo", label = "Quest Item Info", toggle = true,
          help = "Quest item tooltips name the quests they are for and whether each is handed in." },
    },
})
