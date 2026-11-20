-- Run with Lua 5.1 from the repository root: the Dungeon Journal's Rare Alert
-- (NaowhForever_DungeonJournal/UI/RareAlert.lua). A rare of the dungeon you are in is seen on its
-- nameplate, as your target or under the mouse; a secret GUID or a dead rare is skipped; it alerts
-- once a run; the chime backs off and stops; the Target button is a secure macro set up only out of
-- combat; and nothing is made or listened to while the alert is off.
local count = 0
local function Case(name, fn) fn(); count = count + 1; print("PASS " .. name) end

local RARE, BOSS, OTHER = 3586, 644, 9999
local SECRET = {}

local function Guid(npc)
    return "Creature-0-1-36-1-" .. npc .. "-0000000001"
end

local Frame = {}
Frame.__index = Frame

local function NewFrame(seen, template)
    local f = setmetatable({ scripts = {}, hooks = {}, events = {}, attributes = {}, shown = true,
        template = template, level = 1, strata = "MEDIUM" }, Frame)
    seen.frames[#seen.frames + 1] = f
    return f
end

function Frame:SetScript(name, fn) self.scripts[name] = fn end
function Frame:HookScript(name, fn)
    self.hooks[name] = self.hooks[name] or {}
    table.insert(self.hooks[name], fn)
end
function Frame:Fire(name, ...)
    if self.scripts[name] then self.scripts[name](self, ...) end
    for _, fn in ipairs(self.hooks[name] or {}) do fn(self, ...) end
end
function Frame:RegisterEvent(event) self.events[event] = true end
function Frame:UnregisterEvent(event) self.events[event] = nil end
function Frame:UnregisterAllEvents() self.events = {} end
function Frame:Show()
    if self.shown then return end
    self.shown = true
    self:Fire("OnShow")
end
function Frame:Hide()
    if not self.shown then return end
    self.shown = false
    self:Fire("OnHide")
end
function Frame:IsShown() return self.shown end
function Frame:ClearAllPoints() self.point = nil end
function Frame:SetPoint(...) self.point = { ... } end
function Frame:SetSize(w, h) self.w, self.h = w, h end
function Frame:SetFrameLevel(level) self.level = level end
function Frame:GetFrameLevel() return self.level end
function Frame:SetFrameStrata(strata) self.strata = strata end
function Frame:GetFrameStrata() return self.strata end
function Frame:RegisterForClicks(...) self.clicks = { ... } end
function Frame:SetAttribute(key, value) self.attributes[key] = value end
function Frame:GetEffectiveScale() return 1 end
function Frame:GetLeft() return 100 end
function Frame:GetBottom() return 200 end
function Frame:GetWidth() return 100 end
function Frame:GetHeight() return 26 end
function Frame:Cancel() self.cancelled = true end

-- opts: on (Rare Alert), journal (the Journal), inside (in the Deadmines), run (the run's start),
-- sound, raid, leader. Returns the seen state and a function firing an event at the alert's frame.
local function Fixture(opts)
    opts = opts or {}
    local seen = { frames = {}, sounds = 0, timers = {}, filled = {}, shows = 0 }
    seen.units, seen.secret, seen.dead, seen.combat = {}, {}, {}, false
    seen.run = opts.run or 1000
    local values = { enabled = opts.journal ~= false, rareAlert = opts.on ~= false,
        rareAlertSound = opts.sound ~= false }
    local listeners, applied = {}, {}
    local S = {
        Get = function(key) return values[key] end,
        Set = function(key, value)
            values[key] = value
            for _, fn in ipairs(listeners) do fn(key, value) end
        end,
        OnChange = function(fn) listeners[#listeners + 1] = fn end,
    }
    local deadmines = { key = "Deadmines", wings = { { bosses = {
        { npc = BOSS, name = "Rhahk'Zor" },
        { npc = RARE, name = "Miner Johnson", model = 556, rare = true },
    } } } }
    local Parts = {
        Toast = function(spec)
            local toast = NewFrame(seen)
            toast.shown, toast.spec = false, spec
            toast.buttons = { NewFrame(seen), NewFrame(seen) }
            toast.icons = { {} }
            seen.toast = toast
            return toast
        end,
        FillToast = function(toast, title, line, faces)
            seen.filled = { title = title, line = line, faces = faces }
        end,
        ShowToast = function(toast)
            seen.shows = seen.shows + 1
            if toast.spec.on() then toast:Show() end
        end,
    }
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L,
        THEME = { fg = {} },
        Solid = function() return { SetAllPoints = function() end } end,
        Shared = { Parts = Parts },
        Apply = function() end,
        Journal = {
            Settings = S,
            Kills = { RunStart = function() return seen.run end },
            Current = function() if opts.inside ~= false then return { deadmines } end end,
        },
    }
    local J = ns.Journal
    function J.NpcID(guid)
        local kind, _, _, _, _, id = strsplit("-", guid)
        if kind == "Creature" then return tonumber(id) end
    end
    local env = setmetatable({
        _G = { NaowhForever = ns },
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
        CreateFrame = function(_, _, _, template) return NewFrame(seen, template) end,
        UIParent = NewFrame(seen),
        hooksecurefunc = function(t, key, fn) applied[#applied + 1] = fn; assert(t[key]) end,
        issecretvalue = function(v) return v == SECRET end,
        UnitGUID = function(unit)
            if seen.secret[unit] then return SECRET end
            return seen.units[unit] and Guid(seen.units[unit])
        end,
        UnitName = function(unit) return seen.units[unit] and "Miner Johnson" end,
        UnitIsDead = function(unit) return seen.dead[unit] == true end,
        IsInRaid = function() return opts.raid == true end,
        UnitIsGroupLeader = function() return opts.leader == true end,
        UnitIsGroupAssistant = function() return false end,
        InCombatLockdown = function() return seen.combat end,
        SOUNDKIT = { MAP_PING = 3175 },
        PlaySound = function() seen.sounds = seen.sounds + 1 end,
        C_Timer = { NewTimer = function(delay, fn)
            local timer = setmetatable({ delay = delay, fn = fn }, Frame)
            seen.timers[#seen.timers + 1] = timer
            return timer
        end },
        SetPortraitTextureFromCreatureDisplayID = function(texture, model) texture.model = model end,
        strsplit = function(sep, text)
            local out = {}
            for part in (text .. sep):gmatch("(.-)%" .. sep) do out[#out + 1] = part end
            return unpack(out)
        end,
    }, { __index = _G })
    function ns.OnApply(fn) env.hooksecurefunc(ns, "Apply", fn) end
    setfenv(J.NpcID, env)
    local chunk = assert(loadfile("NaowhForever_DungeonJournal/UI/RareAlert.lua"))
    setfenv(chunk, env)
    chunk()
    for _, fn in ipairs(applied) do fn() end
    local function Events()
        for _, f in ipairs(seen.frames) do
            if f.scripts.OnEvent then return f end
        end
    end
    local function Fire(event, ...)
        local f = Events()
        if f and f.events[event] then f.scripts.OnEvent(f, event, ...) end
    end
    local function Cover()
        for _, f in ipairs(seen.frames) do
            if f.template == "SecureActionButtonTemplate" then return f end
        end
    end
    return seen, Fire, Events, S, Cover, ns
end

local function See(seen, Fire, unit, npc)
    seen.units[unit] = npc
    if unit == "target" then
        Fire("PLAYER_TARGET_CHANGED")
    elseif unit == "mouseover" then
        Fire("UPDATE_MOUSEOVER_UNIT")
    else
        Fire("NAME_PLATE_UNIT_ADDED", unit)
    end
end

Case("off: nothing is made or listened to", function()
    local seen, _, _, S = Fixture({ on = false })
    assert(#seen.frames == 1, "only the test's UIParent")
    S.Set("enabled", false)
    assert(#seen.frames == 1)
end)

Case("the Journal off: nothing is made either", function()
    local seen = Fixture({ journal = false })
    assert(#seen.frames == 1)
end)

Case("on outside a dungeon: only the loading screen is listened for", function()
    local _, _, Events = Fixture({ inside = false })
    local events = Events().events
    assert(events.PLAYER_ENTERING_WORLD)
    assert(not events.NAME_PLATE_UNIT_ADDED and not events.PLAYER_TARGET_CHANGED and not events.UPDATE_MOUSEOVER_UNIT)
end)

Case("turned off again: every event goes", function()
    local _, _, Events, S = Fixture()
    assert(Events().events.NAME_PLATE_UNIT_ADDED)
    S.Set("rareAlert", false)
    assert(next(Events().events) == nil)
end)

Case("a rare's nameplate alerts: name, portrait, chime", function()
    local seen, Fire = Fixture()
    See(seen, Fire, "nameplate3", RARE)
    assert(seen.toast and seen.toast:IsShown())
    assert(seen.filled.title == "Miner Johnson")
    assert(seen.toast.icons[1].model == 556)
    assert(seen.sounds == 1)
end)

Case("a rare as your target or under the mouse alerts", function()
    local seen, Fire = Fixture()
    See(seen, Fire, "target", RARE)
    assert(seen.shows == 1 and seen.sounds == 1)
    assert(#seen.timers == 1 and seen.timers[1].cancelled, "already targeted: one chime, no repeat")
    local seen2, Fire2 = Fixture()
    See(seen2, Fire2, "mouseover", RARE)
    assert(seen2.shows == 1 and seen2.sounds == 1 and #seen2.timers == 1)
end)

Case("Discovery's rare alert is told which rares this one covers here", function()
    local seen, _, _, S, _, ns = Fixture()
    assert(ns.JournalRareHere(RARE) and not ns.JournalRareHere(OTHER))
    seen.run = nil
    assert(not ns.JournalRareHere(RARE), "no run yet: this one will not alert, so Discovery's may")
    seen.run = 1000
    S.Set("rareAlert", false)
    assert(not ns.JournalRareHere(RARE))
end)

Case("a boss or a creature not in the dungeon does not alert", function()
    local seen, Fire = Fixture()
    See(seen, Fire, "nameplate1", BOSS)
    See(seen, Fire, "nameplate2", OTHER)
    assert(seen.shows == 0 and seen.sounds == 0)
end)

Case("a secret GUID is skipped without an error", function()
    local seen, Fire = Fixture()
    seen.secret.nameplate1 = true
    See(seen, Fire, "nameplate1", RARE)
    assert(seen.shows == 0)
end)

Case("a dead rare does not alert", function()
    local seen, Fire = Fixture()
    seen.dead.nameplate1 = true
    See(seen, Fire, "nameplate1", RARE)
    assert(seen.shows == 0)
end)

Case("once a run, again the next run", function()
    local seen, Fire = Fixture()
    See(seen, Fire, "nameplate1", RARE)
    Fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
    assert(not seen.toast:IsShown(), "gone with its nameplate")
    See(seen, Fire, "nameplate2", RARE)
    See(seen, Fire, "mouseover", RARE)
    assert(seen.shows == 1)
    seen.run = 2000
    Fire("NAME_PLATE_UNIT_REMOVED", "nameplate2")
    See(seen, Fire, "nameplate4", RARE)
    assert(seen.shows == 2)
end)

Case("the chime backs off and stops", function()
    local seen, Fire = Fixture()
    See(seen, Fire, "nameplate1", RARE)
    local delays = {}
    while seen.timers[#delays + 1] do
        local timer = seen.timers[#delays + 1]
        delays[#delays + 1] = timer.delay
        timer.fn()
    end
    assert(table.concat(delays, ",") == "4,8,16", table.concat(delays, ","))
    assert(seen.sounds == 4)
end)

Case("no chime with its sound off", function()
    local seen, Fire = Fixture({ sound = false })
    See(seen, Fire, "nameplate1", RARE)
    assert(seen.shows == 1 and seen.sounds == 0 and #seen.timers == 0)
end)

Case("targeting the rare ends the alert", function()
    local seen, Fire = Fixture()
    See(seen, Fire, "nameplate1", RARE)
    See(seen, Fire, "target", RARE)
    assert(seen.timers[1].cancelled and not seen.toast:IsShown())
end)

Case("the Target button: a secure macro that targets and marks", function()
    local seen, Fire, _, _, Cover = Fixture()
    See(seen, Fire, "nameplate1", RARE)
    local cover = Cover()
    assert(cover and cover:IsShown())
    local macro = cover.attributes.macrotext
    assert(macro:find("/targetexact Miner Johnson", 1, true) and macro:find("/tm [exists] !8", 1, true), macro)
    assert(cover.attributes.type == "macro")
    cover.scripts.PostClick(cover, "LeftButton", true)
    assert(seen.toast:IsShown(), "the press does nothing yet")
    cover.scripts.PostClick(cover, "LeftButton", false)
    assert(not seen.toast:IsShown() and not cover:IsShown())
end)

Case("no skull in a raid without lead or assist", function()
    local seen, Fire, _, _, Cover = Fixture({ raid = true })
    See(seen, Fire, "nameplate1", RARE)
    assert(not Cover().attributes.macrotext:find("/tm", 1, true))
end)

Case("combat: the button waits and the toast says so", function()
    local seen, Fire, _, _, Cover = Fixture()
    See(seen, Fire, "nameplate1", RARE)
    Fire("PLAYER_REGEN_DISABLED")
    seen.combat = true
    assert(not Cover():IsShown())
    assert(seen.filled.line:find("Leave combat", 1, true))
    seen.combat = false
    Fire("PLAYER_REGEN_ENABLED")
    assert(Cover():IsShown() and not seen.filled.line:find("Leave combat", 1, true))
end)

Case("seen in combat: no secure button is made until it ends", function()
    local seen, Fire, _, _, Cover = Fixture()
    seen.combat = true
    See(seen, Fire, "nameplate1", RARE)
    assert(seen.toast:IsShown() and Cover() == nil)
    assert(seen.filled.line:find("Leave combat", 1, true))
    seen.combat = false
    Fire("PLAYER_REGEN_ENABLED")
    assert(Cover() and Cover():IsShown())
end)

print("test-journal-rare-alert: " .. count .. " cases passed")
