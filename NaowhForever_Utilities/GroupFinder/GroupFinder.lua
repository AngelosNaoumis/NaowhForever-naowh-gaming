-- GroupFinder.lua: the Group Finder's settings (ns.GroupFinderSettings), its module table (ns.GroupFinder) and the listeners its files tell each other through.
local ns = _G.NaowhForever

local BIS_ADDON = "NaowhForever_BiS"

local F = ns.FEATURES.groupFinder

local S = ns.UI.ModuleSettings("groupFinder", {
    enabled = F.enabled,
    autoRole = F.autoRole,
    shareScore = true,
    shareKills = true,
    shareQuests = true,
    shareBis = true,
    hideDeclined = false,
    applySound = false,
    panelOpen = true,
    applyNote = "",
    applyRoles = 0,
    filters = false,
    presets = false,
    askMessage = "Hi! I am a %spec% %class%, level %level%. Inv please",
    inviteWhisper = false,
    inviteMessage = "Hey! Want to join %dungeon%?",
})
ns.GroupFinderSettings = S

if not (ns.FEATURE_GROUP_FINDER and C_AddOns.IsAddOnLoaded(BIS_ADDON)) then return end

local GF = { Settings = S, PREFIX = "NaowhLFG", PAGE = "Group Finder/Settings" }
ns.GroupFinder = GF

local listeners = {}

function GF.On()
    return S.Get("enabled") == true
end

function GF.Listen(what, fn)
    local list = listeners[what]
    if not list then
        list = {}
        listeners[what] = list
    end
    list[#list + 1] = fn
end

function GF.Fire(what, a, b, c, d)
    local list = listeners[what]
    if not list then return end
    for i = 1, #list do list[i](a, b, c, d) end
end
