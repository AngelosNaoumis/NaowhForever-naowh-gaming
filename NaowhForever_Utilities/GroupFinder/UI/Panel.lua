-- Panel.lua: our panel docked to the right of the game's group finder, the Apply button we add to its Browse screen, and when they show (ns.GroupFinder.UI.Panel).
local ns = _G.NaowhForever

local GF = ns.GroupFinder
if not GF then return end
local Listings, Tally = GF.Listings, GF.Tally
local UI = GF.UI
local St = UI.Style
local T = ns.THEME
local S = GF.Settings
local Parts = ns.Shared.Parts
local Style = ns.Shared.Style

local FINDER = "Blizzard_GroupFinder_VanillaStyle"
local TAB_GROUP, TAB_FILTERS, TAB_WHISPERS, TAB_LISTING = "group", "filters", "whispers", "listing"
local TEXT_TITLE = ns.L("Naowh Forever")
local TEXT_BROWSE = ns.L("Group Finder extras")
local TEXT_LISTING = ns.L("Your group")
local TEXT_HIDE = ns.L("Hide this panel")
local TEXT_SHOW = ns.L("Show the Naowh Forever panel")
local TEXT_APPLY = "Apply"
local TEXT_ASK = "Ask to Join"
local TEXT_UNREAD = " (%d)"
local TEXT_AUTO_ROLE = "Set my role when I join a group"
local TEXT_SOUND = "Sound when someone applies"
local TEXT_TALLY = ns.L("Your applications")
local TEXT_TALLY_TIP = ns.L("Joined %d, declined %d, withdrawn %d, no answer %d")
local TEXT_TALLY_NONE = ns.L("None yet")
local WHISPERS_TAB = { key = TAB_WHISPERS, label = "Whispers" }
local BROWSE_TABS = { { key = TAB_GROUP, label = "Picked Group" }, { key = TAB_FILTERS, label = "Filters" }, WHISPERS_TAB }
local LISTING_TABS = { { key = TAB_LISTING, label = "Your Group" }, WHISPERS_TAB }

local Panel = {}
UI.Panel = Panel

local panel, sideTab, applyButton
local built, hooked, queued = false, false, false
local mode
local picked = { browse = TAB_GROUP, listing = TAB_LISTING }

function UI.Selected()
    local selection = LFGBrowseFrame.selectionBehavior
    if not selection:HasSelection() then return nil end
    local node = selection:GetSelectedElementData()[1]
    local id = node and node.data and node.data.resultID
    return id and Listings.ById(id)
end

local function Header()
    local head = CreateFrame("Frame", nil, panel)
    head:SetPoint("TOPLEFT")
    head:SetPoint("TOPRIGHT")
    head:SetHeight(St.PANEL_HEADER)
    ns.Solid(head, "BACKGROUND", T.panel, 1):SetAllPoints()
    local rule = ns.Solid(head, "ARTWORK", Style.BORDER_RGB, 1)
    rule:SetPoint("BOTTOMLEFT")
    rule:SetPoint("BOTTOMRIGHT")
    ns.Hairline(rule, "h")
    local logo = head:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(Style.LOGO_SMALL)
    logo:SetSize(St.LOGO, St.LOGO)
    logo:SetPoint("LEFT", St.PANEL_PAD, 0)
    local title = ns.Font(head, St.TITLE_SIZE, nil, nil, true)
    title:SetPoint("TOPLEFT", logo, "TOPRIGHT", St.GAP, 0)
    title:SetText(TEXT_TITLE)
    panel.sub = ns.Font(head, St.SUB_SIZE, nil, T.muted)
    panel.sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -St.ROW_LINE_GAP)
    local hide = Parts.IconButton(head, function() S.Set("panelOpen", false) end, Style.CROSS, 0, TEXT_HIDE)
    hide:SetPoint("RIGHT", -St.PANEL_PAD, 0)
end

local function TallyBar(parent)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(St.BAR_H)
    bar.segments = {}
    for i, kind in ipairs(Tally.KINDS) do
        local color = St.TALLY_COLORS[kind]
        local segment = bar:CreateTexture(nil, "ARTWORK")
        segment:SetColorTexture(color.r, color.g, color.b, 1)
        segment.text = ns.Font(bar, St.BAR_TEXT_SIZE, nil, T.bg)
        segment.text:SetPoint("CENTER", segment)
        bar.segments[i] = segment
    end
    bar.edge = ns.Border(bar, Style.BORDER_RGB)
    bar.none = ns.Font(bar, St.SUB_SIZE, nil, T.muted)
    bar.none:SetPoint("LEFT")
    bar.none:SetText(TEXT_TALLY_NONE)
    ns.Tooltip(bar, TEXT_TALLY, function()
        local c = Tally.Counts()
        return TEXT_TALLY_TIP:format(c.joined or 0, c.declined or 0, c.withdrawn or 0, c.expired or 0)
    end)
    return bar
end

local function PaintTally(bar)
    local counts = Tally.Counts()
    local total = 0
    for _, kind in ipairs(Tally.KINDS) do total = total + (counts[kind] or 0) end
    bar.none:SetShown(total == 0)
    bar.edge._frame:SetShown(total > 0)
    local width, x = bar:GetWidth(), 0
    for i, kind in ipairs(Tally.KINDS) do
        local segment, n = bar.segments[i], counts[kind] or 0
        local w = total > 0 and width * n / total or 0
        segment:ClearAllPoints()
        segment:SetPoint("TOPLEFT", bar, "TOPLEFT", x, 0)
        segment:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", x, 0)
        segment:SetWidth(math.max(w, 1))
        segment:SetShown(n > 0)
        segment.text:SetText(n > 0 and n or "")
        x = x + w
    end
end

local function Footer()
    local foot = CreateFrame("Frame", nil, panel)
    foot:SetPoint("BOTTOMLEFT")
    foot:SetPoint("BOTTOMRIGHT")
    ns.Solid(foot, "BACKGROUND", T.panel, 1):SetAllPoints()
    local rule = ns.Solid(foot, "ARTWORK", Style.BORDER_RGB, 1)
    rule:SetPoint("TOPLEFT")
    rule:SetPoint("TOPRIGHT")
    ns.Hairline(rule, "h")
    foot.autoRole = UI.Check(foot, TEXT_AUTO_ROLE, function() return S.Get("autoRole") end,
        function(v) S.Set("autoRole", v) end)
    foot.autoRole:SetPoint("TOPLEFT", St.PANEL_PAD, -St.PANEL_PAD)
    foot.autoRole:SetPoint("RIGHT", -St.PANEL_PAD, 0)
    foot.tallyLabel = ns.Font(foot, St.SUB_SIZE, nil, T.muted)
    foot.tallyLabel:SetText(TEXT_TALLY)
    foot.tallyLabel:SetPoint("TOPLEFT", foot.autoRole, "BOTTOMLEFT", 0, -St.GAP)
    foot.tally = TallyBar(foot)
    foot.tally:SetPoint("LEFT", foot.tallyLabel, "RIGHT", St.GAP, 0)
    foot.tally:SetPoint("RIGHT", -St.PANEL_PAD, 0)
    foot.sound = UI.Check(foot, TEXT_SOUND, function() return S.Get("applySound") end,
        function(v) S.Set("applySound", v) end)
    foot.sound:SetPoint("TOPLEFT", St.PANEL_PAD, -St.PANEL_PAD)
    foot.sound:SetPoint("RIGHT", -St.PANEL_PAD, 0)
    panel.foot = foot
end

local function PickTab(key)
    if mode then picked[mode] = key end
    Panel.Refresh()
end

local function BuildPanel()
    panel = CreateFrame("Frame", nil, LFGParentFrame)
    panel:SetWidth(St.PANEL_W)
    panel:SetPoint("TOPLEFT", LFGParentFrame, "TOPRIGHT", St.PANEL_OUT, 0)
    panel:SetPoint("BOTTOMLEFT", LFGParentFrame, "BOTTOMRIGHT", St.PANEL_OUT, 0)
    panel:EnableMouse(true)
    ns.Solid(panel, "BACKGROUND", T.bg, 1):SetAllPoints()
    ns.Border(panel, Style.BORDER_RGB)
    Header()
    Footer()
    local inner = St.PANEL_W - 2 * St.PANEL_PAD
    panel.tabs = Parts.Tabs(panel, inner, BROWSE_TABS, PickTab)
    panel.tabs:SetPoint("TOPLEFT", St.PANEL_PAD, -(St.PANEL_HEADER + St.PANEL_PAD))
    panel.scroll = ns.UI.SlimScroll(panel)
    panel.child = CreateFrame("Frame", nil, panel.scroll)
    panel.child:SetWidth(inner - Style.SCROLLBAR)
    panel.scroll:SetScrollChild(panel.child)
    panel.picked = UI.Picked.Build(panel.child)
    panel.filters = UI.Filters.Build(panel.child)
    panel.listing = UI.Listing.Build(panel.child)
    panel.whispers = UI.WhispersView.Build(panel.child)
    panel.views = { [TAB_GROUP] = panel.picked, [TAB_FILTERS] = panel.filters, [TAB_LISTING] = panel.listing,
        [TAB_WHISPERS] = panel.whispers }
    panel.refresh = { [TAB_GROUP] = UI.Picked.Refresh, [TAB_FILTERS] = UI.Filters.Refresh,
        [TAB_LISTING] = UI.Listing.Refresh, [TAB_WHISPERS] = UI.WhispersView.Refresh }
    for _, view in pairs(panel.views) do
        view:SetPoint("TOPLEFT")
        view:SetWidth(inner - Style.SCROLLBAR)
        view:Hide()
    end
end

local function BuildSideTab()
    sideTab = CreateFrame("Button", nil, LFGParentFrame)
    sideTab:SetSize(St.PANEL_OUT - St.TAB_OUT, St.PANEL_OUT - St.TAB_OUT)
    sideTab:SetPoint("TOPLEFT", LFGParentFrame.WhoListingTab, "BOTTOMLEFT", 0, -St.TAB_OUT)
    ns.Solid(sideTab, "BACKGROUND", T.panel, 1):SetAllPoints()
    ns.Border(sideTab, Style.BORDER_RGB)
    local logo = sideTab:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(Style.LOGO_SMALL)
    logo:SetSize(St.LOGO, St.LOGO)
    logo:SetPoint("CENTER")
    sideTab:SetScript("OnClick", function() S.Set("panelOpen", true) end)
    ns.Tooltip(sideTab, TEXT_SHOW)
end

local function BuildApply()
    applyButton = CreateFrame("Button", nil, LFGBrowseFrame, "UIPanelButtonTemplate")
    applyButton:SetSize(St.APPLY_W, St.APPLY_H)
    applyButton:SetText(ns.L(TEXT_APPLY))
    applyButton:SetPoint("BOTTOM", 0, St.APPLY_BOTTOM)
    applyButton:SetScript("OnClick", function()
        local entry = UI.Selected()
        if UI.Picked.CanApply(entry) then
            UI.Picked.Apply(entry)
        elseif UI.Picked.CanAsk(entry) then
            GF.Whispers.Ask(entry)
        end
    end)
    LFGBrowseFrame.GroupInviteButton:HookScript("OnClick", function()
        local entry = UI.Selected()
        if entry and entry.leader and GF.Filter.Solo(entry) then GF.Whispers.Invited(entry.leader) end
    end)
end

local function PaintApply()
    local entry = UI.Selected()
    local apply = UI.Picked.CanApply(entry)
    applyButton:SetText(ns.L((apply or not UI.Picked.CanAsk(entry)) and TEXT_APPLY or TEXT_ASK))
    applyButton:SetEnabled(apply or UI.Picked.CanAsk(entry))
end

local function Mode()
    if not LFGParentFrame:IsShown() then return nil end
    if LFGBrowseFrame:IsShown() then return "browse" end
    if LFGListingFrame:IsShown() then return "listing" end
end

local function Draw()
    if not built then return end
    local on = GF.On()
    applyButton:SetShown(on)
    mode = on and Mode() or nil
    local open = mode ~= nil and S.Get("panelOpen")
    panel:SetShown(open)
    sideTab:SetShown(mode ~= nil and not S.Get("panelOpen"))
    if on then
        PaintApply()
    end
    if not open then return end
    local browse = mode == "browse"
    panel.sub:SetText(browse and TEXT_BROWSE or TEXT_LISTING)
    local tab = picked[mode]
    if tab == TAB_WHISPERS then GF.Whispers.Seen() end
    WHISPERS_TAB.note = GF.Whispers.unread > 0 and TEXT_UNREAD:format(GF.Whispers.unread) or nil
    Parts.SetTabs(panel.tabs, browse and BROWSE_TABS or LISTING_TABS)
    Parts.PaintTabs(panel.tabs, tab)
    local foot = panel.foot
    foot.autoRole:SetShown(browse)
    foot.tallyLabel:SetShown(browse)
    foot.tally:SetShown(browse)
    foot.sound:SetShown(not browse)
    foot:SetHeight(browse and St.PANEL_FOOT_H or St.PANEL_FOOT_LISTING_H)
    foot.autoRole.toggle._refreshValue()
    foot.sound.toggle._refreshValue()
    if browse then PaintTally(foot.tally) end
    local top = St.PANEL_HEADER + St.PANEL_PAD + St.PANEL_TABS_H + St.PANEL_PAD
    panel.scroll:ClearAllPoints()
    panel.scroll:SetPoint("TOPLEFT", St.PANEL_PAD, -top)
    panel.scroll:SetPoint("BOTTOMRIGHT", foot, "TOPRIGHT", -St.PANEL_PAD, St.PANEL_PAD)
    local show = panel.views[tab]
    for _, view in pairs(panel.views) do view:SetShown(view == show) end
    local height = panel.refresh[tab]()
    show:SetHeight(math.max(1, height or 1))
    panel.child:SetHeight(math.max(1, height or 1))
end

local function Drawn()
    queued = false
    Draw()
end

function Panel.Refresh()
    if queued then return end
    queued = true
    C_Timer.After(0, Drawn)
end

local function Install()
    if hooked then return end
    hooked = true
    BuildPanel()
    BuildSideTab()
    BuildApply()
    built = true
    UI.Rows.Hook()
    LFGParentFrame:HookScript("OnShow", Panel.Refresh)
    for _, frame in ipairs({ LFGBrowseFrame, LFGListingFrame }) do
        frame:HookScript("OnShow", Panel.Refresh)
        frame:HookScript("OnHide", Panel.Refresh)
    end
    hooksecurefunc(LFGBrowseFrame, "UpdateButtonState", Panel.Refresh)
    Panel.Refresh()
    UI.Rows.Refresh()
end

local function OnNewApplicant()
    if S.Get("applySound") then PlaySound(SOUNDKIT.IG_PLAYER_INVITE) end
end

local function Sync()
    if not GF.On() then
        if built then
            Panel.Refresh()
            UI.Rows.Refresh()
        end
        return
    end
    EventUtil.ContinueOnAddOnLoaded(FINDER, Install)
end

for _, what in ipairs({ "card", "applied", "received", "declined", "invitedAs", "listing", "listings", "filter",
    "group", "applicant", "applicantExpired", "withdrawn", "tally", "noreply", "offline", "whispers", "asked" }) do
    GF.Listen(what, Panel.Refresh)
end
GF.Listen("newApplicant", OnNewApplicant)

S.OnChange(function(key)
    if key == "enabled" then
        Sync()
    elseif key == "panelOpen" or key == "autoRole" or key == "applySound" or key == "hideDeclined" then
        Panel.Refresh()
    end
end)
ns.OnApply(Sync)
