-- Group.lua: your group while it is listed in Forever's group finder: what Naowh Forever players are told about it, and its applicants invited or declined (ns.GroupFinder.Group).
local ns = _G.NaowhForever

local GF = ns.GroupFinder
if not GF then return end
local Card, Comms = GF.Card, GF.Comms
local S = GF.Settings

local EVENTS = { "LFG_LIST_ACTIVE_ENTRY_UPDATE", "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED" }
local PARTY_UNITS = 4
local ROLE_ORDER = { Card.TANK, Card.HEALER, Card.DAMAGE }
local NEED_KEY = { [Card.TANK] = "tanks", [Card.HEALER] = "healers", [Card.DAMAGE] = "damage" }
local TEXT_DECLINE_LATER = ns.L("Too many whispers are waiting to be sent. Try Decline again in a moment.")

local Group = { min = 0, tanks = 1, healers = 1, damage = 3, note = "", NEED_KEY = NEED_KEY }
GF.Group = Group

local frame, on = nil, false
local party = {}

function Group.Listed()
    return C_LFGList.HasActiveEntryInfo()
end

function Group.CanEdit()
    return not IsInGroup(LE_PARTY_CATEGORY_HOME) or UnitIsGroupLeader("player", LE_PARTY_CATEGORY_HOME)
end

function Group.Answering()
    return Group.Listed() and Group.CanEdit()
end

function Group.Info()
    if Group.Listed() then return Group end
end

function Group.Changed()
    GF.Fire("group")
end

function Group.Needs(role)
    return Group[NEED_KEY[role]]
end

function Group.Pick(record)
    local roles = record.card.roles
    if record.as and Card.Has(roles, record.as) then return record.as end
    for _, role in ipairs(ROLE_ORDER) do
        if Card.Has(roles, role) and Group.Open(role, record) > 0 then return role end
    end
    for _, role in ipairs(ROLE_ORDER) do
        if Card.Has(roles, role) then return role end
    end
end

function Group.Open(role, except)
    local open = Group.Needs(role)
    for _, record in ipairs(Comms.applicants) do
        if record ~= except and record.invited and record.as == role then open = open - 1 end
    end
    return open
end

function Group.Fits(record)
    local role = Group.Pick(record)
    return role ~= nil and Group.Open(role, record) > 0, role
end

function Group.Invite(record)
    if record.invited or not (Group.Answering() and Comms.HasApplicant(record)) then return false end
    local fits, role = Group.Fits(record)
    if not fits then return false end
    Comms.TellRole(record, role)
    C_PartyInfo.InviteUnit(record.name)
    record.invited, record.as = true, role
    GF.Fire("applicant", record)
    GF.Fire("group")
    return true
end

function Group.Decline(record)
    if not (Group.Answering() and Comms.HasApplicant(record)) then return false end
    if not Comms.Decline(record.name) then
        ns.Print(TEXT_DECLINE_LATER)
        return false
    end
    GF.Fire("applicant")
    return true
end

local function Joined()
    wipe(party)
    for i = 1, PARTY_UNITS do
        local name = GetUnitName("party" .. i, true)
        if type(name) == "string" and not issecretvalue(name) then party[Comms.Key(name)] = true end
    end
    for i = #Comms.applicants, 1, -1 do
        local record = Comms.applicants[i]
        if record.invited and party[Comms.Key(record.name)] then
            local key = NEED_KEY[record.as]
            if Group[key] > 0 then Group[key] = Group[key] - 1 end
            Comms.Remove(record)
        end
    end
end

local function OnEvent(_, event)
    if event == "GROUP_ROSTER_UPDATE" then Joined() end
    GF.Fire("group")
end

local function Sync()
    local want = GF.On()
    if want == on then return end
    on = want
    if want then
        if not frame then
            frame = CreateFrame("Frame")
            frame:SetScript("OnEvent", OnEvent)
        end
        for _, event in ipairs(EVENTS) do frame:RegisterEvent(event) end
    else
        frame:UnregisterAllEvents()
    end
end

S.OnChange(function(key)
    if key == "enabled" then Sync() end
end)
ns.OnApply(Sync)
