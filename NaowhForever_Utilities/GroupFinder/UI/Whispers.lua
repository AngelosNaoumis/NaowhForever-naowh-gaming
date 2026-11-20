-- Whispers.lua: the panel's Whispers view: the whispers you received, newest first, each with Invite and Remove (ns.GroupFinder.UI.WhispersView).
local ns = _G.NaowhForever

local GF = ns.GroupFinder
if not GF then return end
local Whispers = GF.Whispers
local UI = GF.UI
local St = UI.Style
local T = ns.THEME
local Style = ns.Shared.Style
local Parts = ns.Shared.Parts

local SHOWN_MAX = 30
local SECONDS_PER_MINUTE, MINUTES_PER_HOUR = 60, 60
local TEXT_HEAD = "Messages from players"
local TEXT_CLEAR = "Clear"
local TEXT_NONE = ns.L("No whispers yet. Whispers you receive while the Group Finder is on show here.")
local TEXT_INVITE = "Invite"
local TEXT_REMOVE = "Remove"
local TEXT_NOW = ns.L("just now")
local TEXT_MINUTES = ns.L("%dm ago")
local TEXT_HOURS = ns.L("%dh ago")
local TEXT_MORE = ns.L("%d older whispers are kept but not shown.")

local View = {}
UI.WhispersView = View

local view

local function Ago(at)
    local minutes = math.floor((time() - at) / SECONDS_PER_MINUTE)
    if minutes < 1 then return TEXT_NOW end
    if minutes < MINUTES_PER_HOUR then return TEXT_MINUTES:format(minutes) end
    return TEXT_HOURS:format(math.floor(minutes / MINUTES_PER_HOUR))
end

local function NewLine()
    local line = CreateFrame("Frame", nil, view)
    ns.Solid(line, "BACKGROUND", T.fg, Style.WINDOW_CARD_FILL):SetAllPoints()
    ns.Border(line, Style.BORDER_RGB)
    line.name = ns.Font(line, St.LINE_SIZE)
    line.name:SetPoint("TOPLEFT", St.CARD_PAD, -St.CARD_PAD)
    line.when = ns.Font(line, St.SUB_SIZE, nil, T.muted)
    line.when:SetPoint("TOPRIGHT", -St.CARD_PAD, -St.CARD_PAD)
    line.text = UI.Wrapped(line, St.LINE_SIZE)
    line.text:SetPoint("TOPLEFT", line.name, "BOTTOMLEFT", 0, -St.ROW_LINE_GAP)
    line.text:SetPoint("RIGHT", -St.CARD_PAD, 0)
    line.remove = Parts.Link(line, function() Whispers.Remove(line.record) end)
    Parts.SetLink(line.remove, TEXT_REMOVE)
    line.remove:SetPoint("BOTTOMRIGHT", -St.CARD_PAD, St.CARD_PAD)
    line.invite = Parts.Link(line, function() C_PartyInfo.InviteUnit(line.record.name) end)
    Parts.SetLink(line.invite, TEXT_INVITE)
    line.invite:SetPoint("RIGHT", line.remove, "LEFT", -St.PANEL_GAP, 0)
    return line
end

local function Paint(line, record)
    line.record = record
    local color = UI.ClassColor(record.class)
    line.name:SetText(Ambiguate(record.name, "none"))
    line.name:SetTextColor(color.r, color.g, color.b)
    line.when:SetText(Ago(record.at))
    line.text:SetText(record.text)
    return St.CARD_PAD * 2 + St.LINE_H + math.ceil(line.text:GetStringHeight()) + St.GAP + St.LINE_H
end

local function Build(parent)
    view = CreateFrame("Frame", nil, parent)
    view.stack = UI.Stack(view)
    view.head = CreateFrame("Frame", nil, view)
    UI.Kicker(view.head, TEXT_HEAD):SetPoint("LEFT")
    view.clear = Parts.Link(view.head, Whispers.Clear)
    Parts.SetLink(view.clear, TEXT_CLEAR)
    view.clear:SetPoint("RIGHT")
    view.empty = UI.Wrapped(view, St.LINE_SIZE, T.muted)
    view.empty:SetText(TEXT_NONE)
    view.more = UI.Wrapped(view, St.SUB_SIZE, T.muted)
    view.lines = {}
    return view
end

function View.Refresh()
    if not (view and view:IsShown()) then return end
    local stack = view.stack
    stack:Reset()
    view.empty:Hide()
    view.more:Hide()
    for _, line in ipairs(view.lines) do line:Hide() end
    local log = Whispers.log
    view.clear:SetShown(#log > 0)
    stack:Put(view.head, St.KICKER_SIZE + 2, St.GAP)
    if #log == 0 then
        stack:Text(view.empty)
        return stack:Finish()
    end
    for i = 1, math.min(#log, SHOWN_MAX) do
        local line = view.lines[i] or NewLine()
        view.lines[i] = line
        stack:Put(line, Paint(line, log[i]), St.APPLICANT_GAP)
    end
    if #log > SHOWN_MAX then
        view.more:SetText(TEXT_MORE:format(#log - SHOWN_MAX))
        stack:Text(view.more)
    end
    return stack:Finish()
end

function View.Build(parent)
    return Build(parent)
end
