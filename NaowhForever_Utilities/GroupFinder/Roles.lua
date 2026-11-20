-- Roles.lua: your group role set by itself when you join a group: the role its leader invited you as, else the one role you applied as, else your one saved role (ns.GroupFinder.Roles).
local ns = _G.NaowhForever

local GF = ns.GroupFinder
if not GF then return end
local Card, Comms = GF.Card, GF.Comms
local S = GF.Settings

local PARTY_UNITS = 4
local JOIN_TRIES = 5
local ROLE_NAME = { [Card.TANK] = "TANK", [Card.HEALER] = "HEALER", [Card.DAMAGE] = "DAMAGER" }
local SINGLE = { [Card.TANK] = true, [Card.HEALER] = true, [Card.DAMAGE] = true }

local Roles = {}
GF.Roles = Roles

local frame, on, grouped, pending, tries = nil, false, false, nil, 0

local function LeaderName()
    for i = 1, PARTY_UNITS do
        local unit = "party" .. i
        local leads = UnitIsGroupLeader(unit)
        if not issecretvalue(leads) and leads then
            local name = GetUnitName(unit, true)
            if type(name) == "string" and not issecretvalue(name) then return name end
        end
    end
end

function Roles.For(record)
    if record and record.invitedAs then return record.invitedAs end
    if record and SINGLE[record.roles] then return record.roles end
    local saved = Card.SavedRoles()
    if SINGLE[saved] then return saved end
end

local function Apply(role)
    if InCombatLockdown() then
        pending = role
        frame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    pending = nil
    local name = ROLE_NAME[role]
    local current = UnitGroupRolesAssigned("player")
    if issecretvalue(current) or current == name then return end
    UnitSetRole("player", name)
end

local function OnJoin()
    local leader = LeaderName()
    tries = tries + 1
    if not leader and tries < JOIN_TRIES then return false end
    local record = leader and Comms.SentTo(leader)
    if record then
        record.joined = true
        GF.Fire("joined", record)
    end
    if S.Get("autoRole") then
        local role = Roles.For(record)
        if role then Apply(role) end
    end
    return true
end

local function OnEvent(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        frame:UnregisterEvent(event)
        if pending and IsInGroup() then Apply(pending) end
        return
    end
    local now = IsInGroup(LE_PARTY_CATEGORY_HOME)
    if not now then
        grouped, tries = false, 0
        return
    end
    if grouped then return end
    grouped = UnitIsGroupLeader("player", LE_PARTY_CATEGORY_HOME) or OnJoin()
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
        grouped = IsInGroup(LE_PARTY_CATEGORY_HOME)
        frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    else
        frame:UnregisterAllEvents()
        pending = nil
    end
end

S.OnChange(function(key)
    if key == "enabled" then Sync() end
end)
ns.OnApply(Sync)
