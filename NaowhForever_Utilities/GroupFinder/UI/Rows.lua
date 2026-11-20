-- Rows.lua: our part of each row in the game's Browse list: the group's members as five squares, the leader's Gear Score and your application, and the rows your filters leave out dimmed (ns.GroupFinder.UI.Rows).
local ns = _G.NaowhForever

local GF = ns.GroupFinder
if not GF then return end
local Card, Comms, Listings, Filter = GF.Card, GF.Comms, GF.Listings, GF.Filter
local UI = GF.UI
local St = UI.Style
local T = ns.THEME
local Parts = ns.Shared.Parts

local SLOTS = 5
local GROUP_MIN = 2
local TEXT_APPLIED = ns.L("Applied")
local TEXT_RECEIVED = ns.L("Received")
local TEXT_DECLINED = ns.L("Declined")
local TEXT_INVITED = ns.L("Invited")
local TEXT_MIN = ns.L("min %.1f")
local TEXT_ASKED = ns.L("Asked")
local TEXT_NF = "NF"
local TEXT_NF_TIP = ns.L("This leader runs Naowh Forever: you can apply with your card.")

local Rows = {}
UI.Rows = Rows

local decors = {}
local used = {}
local hooked = false

local function NewSquare(parent)
    local square = CreateFrame("Frame", nil, parent)
    square:SetSize(St.SQUARE, St.SQUARE)
    square.fill = ns.Solid(square, "BACKGROUND", T.fg, St.SQUARE_FILL)
    square.fill:SetAllPoints()
    square.edge = ns.Border(square, T.line)
    square.icon = square:CreateTexture(nil, "ARTWORK")
    square.icon:SetSize(St.ROW_ICON, St.ROW_ICON)
    square.icon:SetPoint("CENTER")
    square.crown = square:CreateTexture(nil, "OVERLAY")
    square.crown:SetAtlas(St.CROWN_ATLAS)
    square.crown:SetSize(St.CROWN, St.CROWN)
    square.crown:SetPoint("CENTER", square, "TOP", 0, 0)
    return square
end

local function Build(row)
    local decor = CreateFrame("Frame", nil, row)
    decor:SetAllPoints()
    decor:SetFrameLevel(row:GetFrameLevel() + St.ROW_RAISE)
    decor.squares = {}
    local x = -St.ROW_RIGHT
    for i = SLOTS, 1, -1 do
        local square = NewSquare(decor)
        square:SetPoint("TOPRIGHT", decor, "TOPRIGHT", x, -St.ROW_TOP)
        decor.squares[i] = square
        x = x - St.SQUARE - St.SQUARE_GAP
    end
    decor.status = Parts.Pill(decor, St.PILL_SIZE, T.muted)
    decor.score = Parts.Pill(decor, St.PILL_SIZE, T.fg)
    decor.nf = Parts.Pill(decor, St.PILL_SIZE, T.accent)
    Parts.SetPill(decor.nf, TEXT_NF)
    ns.Tooltip(decor.nf, TEXT_NF_TIP)
    decor.range = ns.Font(decor, St.ROW_STATUS_SIZE)
    decor.line = { decor.status, decor.score, decor.nf, decor.range }
    decors[row] = decor
    return decor
end

local function PaintMember(square, member, role)
    local color = UI.ClassColor(member and member.class)
    square.fill:SetColorTexture(color.r, color.g, color.b, St.SQUARE_FILL)
    square.edge:SetColor(color.r, color.g, color.b, 1)
    square.icon:SetAtlas(St.ROLE_MICRO[role])
    square.icon:SetDesaturated(false)
    square.icon:SetAlpha(1)
    square.crown:SetShown(member ~= nil and member.leader)
    square:Show()
end

local function PaintOpen(square, role)
    square.fill:SetColorTexture(0, 0, 0, 0)
    square.edge:SetColor(T.line.r, T.line.g, T.line.b, 1)
    square.icon:SetAtlas(St.ROLE_MICRO[role])
    square.icon:SetDesaturated(true)
    square.icon:SetAlpha(St.DIM_ALPHA)
    square.crown:Hide()
    square:Show()
end

local function TakeMember(entry, role)
    local fallback
    for m = 1, entry.nMembers do
        local member = entry.members[m]
        if not used[m] then
            if Card.Has(member.roles, role) then
                used[m] = true
                return member
            end
            fallback = fallback or m
        end
    end
    if fallback then
        used[fallback] = true
        return entry.members[fallback]
    end
end

local function PaintSquares(decor, entry)
    wipe(used)
    local n = 0
    for _, role in ipairs(UI.ROLES) do
        for _ = 1, entry[GF.Group.NEED_KEY[role]] do
            if n < SLOTS then
                n = n + 1
                PaintMember(decor.squares[n], TakeMember(entry, role), role)
            end
        end
    end
    for _, role in ipairs(UI.ROLES) do
        for _ = 1, Filter.Open(entry, role) do
            if n < SLOTS then
                n = n + 1
                PaintOpen(decor.squares[n], role)
            end
        end
    end
    for i = n + 1, SLOTS do decor.squares[i]:Hide() end
end

local function HideSquares(decor)
    for i = 1, SLOTS do decor.squares[i]:Hide() end
end

local function Status(entry, card)
    local record = entry.leader and Comms.SentTo(entry.leader)
    if record then
        if record.declined then return TEXT_DECLINED, ns.Shared.Style.RED_RGB end
        if record.invitedAs then return TEXT_INVITED, ns.Shared.Style.HAVE_RGB end
        if record.acked then return TEXT_RECEIVED, ns.Shared.Style.HAVE_RGB end
        return TEXT_APPLIED, T.muted
    end
    if entry.leader and GF.Whispers.AskedAt(entry.leader) then return TEXT_ASKED, T.accentSoft end
    local group = card and card.group
    local mine = ns.NaowhScore.Unit("player")
    if group and group.min > 0 and mine and mine * UI.TENTHS < group.min then
        return TEXT_MIN:format(group.min / UI.TENTHS), ns.Shared.Style.RED_RGB
    end
    return "", T.muted
end

local function PlaceLine(decor)
    local last
    for _, part in ipairs(decor.line) do
        if part:IsShown() then
            part:ClearAllPoints()
            if last then
                part:SetPoint("RIGHT", last, "LEFT", -St.PILL_GAP, 0)
            else
                part:SetPoint("TOPRIGHT", decor.squares[SLOTS], "BOTTOMRIGHT", 0, -St.ROW_LINE_GAP)
            end
            last = part
        end
    end
end

local function SetPill(pill, text, color)
    pill:SetShown(text ~= "")
    if text == "" then return end
    Parts.ColorPill(pill, color)
    Parts.SetPill(pill, text)
end

local function Range(decor, activity)
    if not (activity and activity.min > 0) then
        decor.range:Hide()
        return
    end
    local mine = UnitLevel("player")
    local level = mine < activity.min and activity.min or mine > activity.max and activity.max or mine
    local color = GetQuestDifficultyColor(level)
    decor.range:SetText(activity.min == activity.max and tostring(activity.min) or (activity.min .. "-" .. activity.max))
    decor.range:SetTextColor(color.r, color.g, color.b)
    decor.range:Show()
end

local function Restore(row, decor)
    decor:Hide()
    row.DataDisplay:SetAlpha(1)
    row:SetAlpha(1)
end

local function Decorate(row)
    local decor = decors[row]
    local entry = GF.On() and row.resultID and Listings.ById(row.resultID)
    if not entry or entry.mine then
        if decor then Restore(row, decor) end
        return
    end
    decor = decor or Build(row)
    decor:Show()
    local activity = entry.activity and Listings.Activity(entry.activity)
    if entry.numMembers >= GROUP_MIN and activity and activity.size <= SLOTS then
        PaintSquares(decor, entry)
        row.DataDisplay:SetAlpha(0)
    else
        HideSquares(decor)
        row.DataDisplay:SetAlpha(1)
    end
    local card = entry.leader and Comms.CardOf(entry.leader)
    decor.nf:SetShown(card ~= nil)
    if card and card.score then
        SetPill(decor.score, ("%.1f"):format(card.score / UI.TENTHS), UI.ScoreColor(card.score, card.level))
    else
        decor.score:Hide()
    end
    SetPill(decor.status, Status(entry, card))
    Range(decor, activity)
    PlaceLine(decor)
    row:SetAlpha(Filter.Pass(entry) and 1 or St.DIM_ALPHA)
end

function Rows.Refresh()
    LFGBrowseFrame.ScrollBox:ForEachFrame(Decorate)
end

function Rows.Hook()
    if hooked then return end
    hooked = true
    hooksecurefunc("LFGBrowseSearchEntry_Update", Decorate)
end

for _, what in ipairs({ "card", "filter", "received", "declined", "invitedAs", "applied", "group", "asked" }) do
    GF.Listen(what, function()
        if hooked then Rows.Refresh() end
    end)
end
