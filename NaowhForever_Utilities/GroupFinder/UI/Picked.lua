-- Picked.lua: the panel's Picked Group view: everyone in the group picked in the game's list, its leader's card and note, and applying to it (ns.GroupFinder.UI.Picked).
local ns = _G.NaowhForever

local GF = ns.GroupFinder
if not GF then return end
local Card, Comms, Listings, Filter, Browse, Tally = GF.Card, GF.Comms, GF.Listings, GF.Filter, GF.Browse, GF.Tally
local UI = GF.UI
local St = UI.Style
local T = ns.THEME
local S = GF.Settings
local Style = ns.Shared.Style

local SLOTS = 5
local KV_ROWS = 4
local SECONDS_PER_MINUTE = 60
local TEXT_PICK = ns.L("Or pick any group in the game's list to see who is in it.")
local TEXT_APPS_HEAD = "Your applications"
local TEXT_NO_APPS = ns.L("You have not applied to a group yet.")
local TEXT_NEED_YOU = "Groups that need you"
local TEXT_NONE_NEED = ns.L("No group in your last search has an open spot for your roles.")
local TEXT_WITH = ns.L("%s with %s")
local TEXT_NEEDS_LINE = ns.L("%s  |  %s")
local TEXT_BACK = "Back"
local TEXT_SHORT_INVITED = ns.L("Invited")
local TEXT_SHORT_DECLINED = ns.L("Declined")
local TEXT_SHORT_RECEIVED = ns.L("Received %s")
local TEXT_SHORT_SENDING = ns.L("Sending")
local TEXT_SUB = ns.L("%s  |  %s  |  listed %s")
local TEXT_JUST_NOW = ns.L("just now")
local TEXT_AGO = ns.L("%dm ago")
local TEXT_LEVELS = ns.L("Levels %d-%d")
local TEXT_GROUP = ns.L("Group %d/%d")
local TEXT_NEEDS = ns.L("needs %s")
local NEED_ICON = "|A:%s:0:0|ax%d"
local TEXT_FULL = ns.L("full")
local TEXT_HAS = ns.L("Has %s")
local TEXT_HAS_NONE = ns.L("No Bloodlust or Battle res yet")
local TEXT_BLOODLUST = ns.L("Bloodlust")
local TEXT_BATTLE_RES = ns.L("Battle res")
local TEXT_AND = ns.L(" and ")
local TEXT_NO_CARD = ns.L("%s does not run Naowh Forever, so there is no Gear Score or note. Ask to Join whispers them.")
local TEXT_ASK = "Ask to Join"
local TEXT_ASK_AGAIN = "Ask Again"
local TEXT_ASK_KICKER = "Ask to Join whispers"
local TEXT_ASKED = ns.L("You asked %s %s.")
local TEXT_WAITING = ns.L("Asking %s for their card...")
local TEXT_IN_DUNGEON = ns.L("In this dungeon")
local TEXT_QUESTS = ns.L("Quests in log")
local TEXT_BIS = ns.L("BiS items")
local TEXT_ZONE = ns.L("Zone")
local TEXT_FIRST = ns.L("First time")
local TEXT_KILLS = ns.L("%d boss kills")
local TEXT_KILL = ns.L("1 boss kill")
local TEXT_QUEST_COUNT = ns.L("%d in log, %d needed")
local TEXT_UNKNOWN = ns.L("Not shared")
local TEXT_MIN = ns.L("Minimum Gear Score %.1f")
local TEXT_YOURS = ns.L("yours %.1f")
local TEXT_APPLY_AS = "Apply as"
local TEXT_NOTE_HINT = "Note to the leader (kept for next time)"
local TEXT_APPLY = "Apply"
local TEXT_WITHDRAW = "Withdraw"
local TEXT_SENDING = ns.L("Sending your card...")
local TEXT_RECEIVED = ns.L("%s has your card.")
local TEXT_INVITED = ns.L("%s invited you as %s. Accept in the game's invite box.")
local TEXT_DECLINED = ns.L("%s declined your application.")
local TEXT_LEFT = ns.L("%s left")
local TEXT_DELISTED = ns.L("This group was delisted.")
local TEXT_COUNT = ns.L("%d/%d")
local TEXT_NO_ROLE = ns.L("Pick at least one role to apply as.")
local TEXT_COULD_NOT = ns.L("Group Finder: could not apply (%s). Try again in a moment.")
local TEXT_INFO = ns.L("%s %d")

local Picked = {}
UI.Picked = Picked

local view
local ranked = {}

local function DungeonName(entry)
    local activity = entry.activity and Listings.Activity(entry.activity)
    return activity and activity.name or ""
end

local function Ago(seconds)
    if seconds < SECONDS_PER_MINUTE then return TEXT_JUST_NOW end
    return TEXT_AGO:format(math.floor(seconds / SECONDS_PER_MINUTE))
end

local function Left(record)
    local seconds = math.max(0, math.floor(record.deadline - GetTime()))
    return TEXT_LEFT:format(("%d:%02d"):format(math.floor(seconds / SECONDS_PER_MINUTE), seconds % SECONDS_PER_MINUTE))
end

local function ApplyRoles()
    return Filter.MyRoles()
end

function Picked.Apply(entry)
    if not (entry and entry.leader and Comms.CardOf(entry.leader)) then return end
    local roles = ApplyRoles()
    if roles == 0 then return ns.Print(TEXT_NO_ROLE) end
    local id, why = Browse.Apply(entry.leader, entry.dungeon, roles, S.Get("applyNote"))
    if not id then ns.Print(TEXT_COULD_NOT:format(tostring(why))) end
end

function Picked.CanAsk(entry)
    return entry ~= nil and entry.leader ~= nil and not entry.delisted and not entry.mine
        and not Filter.Solo(entry) and Comms.CardOf(entry.leader) == nil
end

function Picked.CanApply(entry)
    return entry ~= nil and entry.leader ~= nil and not entry.delisted and not entry.mine and not Filter.Solo(entry)
        and Comms.CardOf(entry.leader) ~= nil and Comms.SentTo(entry.leader) == nil
end

local function Withdraw()
    local record = view.entry and view.entry.leader and Comms.SentTo(view.entry.leader)
    if record and Comms.Withdraw(record.id) then
        Tally.Add("withdrawn")
        GF.Fire("applied")
    end
end

local function ToggleRole(role)
    local roles = ApplyRoles()
    roles = Card.Has(roles, role) and roles - role or roles + role
    S.Set("applyRoles", roles)
    Picked.Refresh()
end

local function Preview(line)
    Picked.preview = line.id
    Picked.Refresh()
    UI.Panel.Refresh()
end

local function HomeLine()
    local line = CreateFrame("Button", nil, view)
    line.hover = ns.Solid(line, "BACKGROUND", T.fg, 0)
    line.hover:SetAllPoints()
    line.left = ns.Font(line, St.LINE_SIZE)
    line.left:SetPoint("TOPLEFT", St.GAP, -St.GAP)
    line.left:SetPoint("RIGHT", -St.COUNTER_ROOM * 2, 0)
    line.left:SetJustifyH("LEFT")
    line.left:SetWordWrap(false)
    line.right = ns.Font(line, St.SUB_SIZE)
    line.right:SetPoint("TOPRIGHT", -St.GAP, -St.GAP)
    line.sub = ns.Font(line, St.SUB_SIZE, nil, T.muted)
    line.sub:SetPoint("TOPLEFT", line.left, "BOTTOMLEFT", 0, -St.ROW_LINE_GAP)
    line.sub:SetPoint("RIGHT", -St.GAP, 0)
    line.sub:SetJustifyH("LEFT")
    line.sub:SetWordWrap(false)
    line:SetScript("OnEnter", function() line.hover:SetAlpha(St.HOME_HOVER) end)
    line:SetScript("OnLeave", function() line.hover:SetAlpha(0) end)
    line:SetScript("OnClick", Preview)
    return line
end

local function Art(parent)
    local art = CreateFrame("Frame", nil, parent)
    art.texture = art:CreateTexture(nil, "BACKGROUND")
    art.texture:SetAllPoints()
    art.texture:SetTexCoord(unpack(St.ART_COORDS))
    local shade = art:CreateTexture(nil, "BORDER")
    shade:SetAllPoints()
    shade:SetColorTexture(1, 1, 1, 1)
    shade:SetGradient("VERTICAL", CreateColor(T.bg.r, T.bg.g, T.bg.b, St.ART_SHADE_BOTTOM),
        CreateColor(T.bg.r, T.bg.g, T.bg.b, St.ART_SHADE_TOP))
    ns.Border(art, Style.BORDER_RGB)
    art.sub = ns.Font(art, St.SUB_SIZE, nil, T.fg)
    art.sub:SetPoint("BOTTOMLEFT", St.ART_PAD, St.ART_PAD)
    art.sub:SetPoint("RIGHT", -St.ART_PAD, 0)
    art.sub:SetJustifyH("LEFT")
    art.title = ns.Font(art, St.HEAD_SIZE, "OUTLINE", nil, true)
    art.title:SetPoint("BOTTOMLEFT", art.sub, "TOPLEFT", 0, St.ROW_LINE_GAP)
    art.title:SetPoint("RIGHT", -St.ART_PAD, 0)
    art.title:SetJustifyH("LEFT")
    return art
end

local function Build(parent)
    view = CreateFrame("Frame", nil, parent)
    view.stack = UI.Stack(view)
    view.empty = UI.Wrapped(view, St.LINE_SIZE, T.muted)
    view.empty:SetText(TEXT_PICK)
    view.yoursKicker = UI.Kicker(view, TEXT_APPS_HEAD)
    view.needKicker = UI.Kicker(view, TEXT_NEED_YOU)
    view.noApps = UI.Wrapped(view, St.SUB_SIZE, T.muted)
    view.noNeed = UI.Wrapped(view, St.SUB_SIZE, T.muted)
    view.homeLines = {}
    view.art = Art(view)
    view.back = ns.Shared.Parts.Link(view, function()
        Picked.preview = nil
        Picked.Refresh()
        UI.Panel.Refresh()
    end, true)
    ns.Shared.Parts.SetLink(view.back, TEXT_BACK)
    ns.Shared.Parts.FlipLink(view.back)
    view.title = ns.Font(view, St.HEAD_SIZE, nil, nil, true)
    view.title:SetJustifyH("LEFT")
    view.sub = ns.Font(view, St.SUB_SIZE, nil, T.muted)
    view.sub:SetJustifyH("LEFT")
    view.note = CreateFrame("Frame", nil, view)
    view.note.edge = ns.Solid(view.note, "ARTWORK", T.line, 1)
    view.note.edge:SetPoint("TOPLEFT")
    view.note.edge:SetPoint("BOTTOMLEFT")
    view.note.edge:SetWidth(St.NOTE_EDGE)
    view.note.text = UI.Wrapped(view.note, St.LINE_SIZE)
    view.note.text:SetPoint("TOPLEFT", St.NOTE_PAD, 0)
    view.note.text:SetPoint("RIGHT")
    view.groupHead = CreateFrame("Frame", nil, view)
    view.groupKicker = UI.Kicker(view.groupHead)
    view.groupKicker:SetPoint("LEFT")
    view.needs = ns.Font(view.groupHead, St.SUB_SIZE, nil, T.muted)
    view.needs:SetPoint("RIGHT")
    view.lines = {}
    for i = 1, SLOTS do view.lines[i] = UI.MemberLine(view) end
    view.has = ns.Font(view, St.SUB_SIZE)
    view.has:SetJustifyH("LEFT")
    view.card = CreateFrame("Frame", nil, view)
    ns.Solid(view.card, "BACKGROUND", T.fg, Style.WINDOW_CARD_FILL):SetAllPoints()
    ns.Border(view.card, Style.BORDER_RGB)
    view.cardName = ns.Font(view.card, St.LINE_SIZE)
    view.cardName:SetPoint("TOPLEFT", St.CARD_PAD, -St.CARD_PAD)
    view.cardScore = ns.Font(view.card, St.SCORE_SIZE)
    view.cardScore:SetPoint("TOPRIGHT", -St.CARD_PAD, -St.CARD_PAD)
    view.cardText = UI.Wrapped(view.card, St.SUB_SIZE, T.muted)
    view.cardText:SetPoint("TOPLEFT", St.CARD_PAD, -St.CARD_PAD)
    view.cardText:SetPoint("RIGHT", -St.CARD_PAD, 0)
    view.keys, view.values = {}, {}
    for i = 1, KV_ROWS do
        local key = ns.Font(view.card, St.SUB_SIZE, nil, T.muted)
        key:SetPoint("TOPLEFT", view.cardName, "BOTTOMLEFT", 0, -St.GAP - (i - 1) * St.LINE_H)
        local value = ns.Font(view.card, St.SUB_SIZE)
        value:SetPoint("TOP", key, "TOP")
        value:SetPoint("RIGHT", -St.CARD_PAD, 0)
        view.keys[i], view.values[i] = key, value
    end
    view.min = CreateFrame("Frame", nil, view)
    view.minText = ns.Font(view.min, St.SUB_SIZE, nil, T.muted)
    view.minText:SetPoint("LEFT")
    view.minYours = ns.Font(view.min, St.SUB_SIZE)
    view.minYours:SetPoint("RIGHT")
    view.applyKicker = UI.Kicker(view, TEXT_APPLY_AS)
    view.roleRow = CreateFrame("Frame", nil, view)
    view.roles = {}
    for i, role in ipairs(UI.ROLES) do
        local button = ns.Button(view.roleRow, UI.ROLE_LABEL[role], St.ROLE_BUTTON, St.BUTTON_H,
            function() ToggleRole(role) end)
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetAtlas(St.ROLE_MICRO[role])
        button.icon:SetSize(St.SQUARE_ICON, St.SQUARE_ICON)
        button.icon:SetPoint("RIGHT", button.label, "LEFT", -St.GAP / 2, 0)
        button.role = role
        view.roles[i] = button
    end
    view.noteBox = UI.EditLine(view, TEXT_NOTE_HINT, Card.NOTE_MAX, function(text)
        if view.filling then return end
        S.Set("applyNote", Card.CleanNote(text))
        view.counter:SetText(TEXT_COUNT:format(#text, Card.NOTE_MAX))
    end)
    view.counter = ns.Font(view.noteBox, St.SUB_SIZE, nil, T.muted)
    view.counter:SetPoint("RIGHT", view.noteBox, "RIGHT", -St.COUNTER_ROOM / 2, 0)
    view.buttons = CreateFrame("Frame", nil, view)
    view.apply = ns.PrimaryButton(ns.Button(view.buttons, TEXT_APPLY, St.APPLY_W, St.BUTTON_H,
        function() Picked.Apply(view.entry) end))
    view.apply:SetPoint("LEFT")
    view.state = UI.Wrapped(view, St.LINE_SIZE)
    view.withdraw = ns.Button(view, TEXT_WITHDRAW, St.APPLY_W, St.BUTTON_H, Withdraw)
    view.askKicker = UI.Kicker(view, TEXT_ASK_KICKER)
    view.askText = UI.Wrapped(view, St.SUB_SIZE)
    view.ask = ns.PrimaryButton(ns.Button(view, TEXT_ASK, St.APPLY_W, St.BUTTON_H, function()
        GF.Whispers.Ask(view.entry)
    end))
    view.asked = UI.Wrapped(view, St.SUB_SIZE, T.muted)
    return view
end

local function HideAll()
    for _, region in ipairs({ view.empty, view.title, view.sub, view.note, view.groupHead, view.has, view.card,
        view.min, view.applyKicker, view.roleRow, view.noteBox, view.buttons, view.state, view.withdraw,
        view.askKicker, view.askText, view.ask, view.asked,
        view.yoursKicker, view.needKicker, view.noApps, view.noNeed, view.art, view.back }) do
        region:Hide()
    end
    for i = 1, SLOTS do view.lines[i]:Hide() end
    for _, line in ipairs(view.homeLines) do line:Hide() end
end

local function Members(entry, stack)
    local n = 0
    for m = 1, entry.nMembers do
        local member = entry.members[m]
        n = n + 1
        local className = member.class and LOCALIZED_CLASS_NAMES_MALE[member.class]
        local info = className and TEXT_INFO:format(className, member.level or 0) or ""
        UI.PaintMember(view.lines[n], UI.RoleOf(member.roles) or Card.DAMAGE, member.name or "?", member.class, info,
            member.leader)
        stack:Put(view.lines[n], St.MEMBER_H, 0)
    end
    for _, role in ipairs(UI.ROLES) do
        for _ = 1, Filter.Open(entry, role) do
            if n < SLOTS then
                n = n + 1
                UI.PaintMember(view.lines[n], role, nil)
                stack:Put(view.lines[n], St.MEMBER_H, 0)
            end
        end
    end
end

local function NeedsText(entry)
    local parts = {}
    for _, role in ipairs(UI.ROLES) do
        local open = Filter.Open(entry, role)
        if open > 0 then parts[#parts + 1] = NEED_ICON:format(St.ROLE_MICRO[role], open) end
    end
    if #parts == 0 then return TEXT_FULL end
    return TEXT_NEEDS:format(table.concat(parts, " "))
end

local function HasText(entry)
    local lust, res = Filter.HasClass(entry, "SHAMAN"), Filter.HasClass(entry, "DRUID")
    if not (lust or res) then return TEXT_HAS_NONE, T.muted end
    local what = lust and res and (TEXT_BLOODLUST .. TEXT_AND .. TEXT_BATTLE_RES) or lust and TEXT_BLOODLUST
        or TEXT_BATTLE_RES
    return TEXT_HAS:format(what), Style.TIP_RGB
end

local function KillsText(card)
    if not card.hasKills then return TEXT_FIRST end
    local total = 0
    for i = 1, card.nKills do total = total + card.kills[i] end
    if total == 0 then return TEXT_FIRST end
    if total == 1 then return TEXT_KILL end
    return TEXT_KILLS:format(total)
end

local function LeaderCard(entry, card, stack)
    for i = 1, KV_ROWS do
        view.keys[i]:Hide()
        view.values[i]:Hide()
    end
    if not card then
        view.cardName:Hide()
        view.cardScore:Hide()
        local _, waiting = Browse.CardOf(entry.leader)
        view.cardText:SetText((waiting and TEXT_WAITING or TEXT_NO_CARD):format(entry.leader))
        view.cardText:Show()
        stack:Put(view.card, math.ceil(view.cardText:GetStringHeight()) + 2 * St.CARD_PAD, St.PANEL_GAP)
        return
    end
    view.cardText:Hide()
    local leader
    for m = 1, entry.nMembers do
        if entry.members[m].leader then leader = entry.members[m] end
    end
    local color = UI.ClassColor(leader and leader.class)
    view.cardName:SetText(entry.leader)
    view.cardName:SetTextColor(color.r, color.g, color.b)
    view.cardName:Show()
    view.cardScore:SetText(card.score and UI.Score(card.score, card.level) or "")
    view.cardScore:Show()
    local zone = leader and leader.zone
    local rows = {
        { TEXT_IN_DUNGEON, card.dungeon and KillsText(card) or TEXT_UNKNOWN },
        { TEXT_QUESTS, card.hasQuests and TEXT_QUEST_COUNT:format(card.nHave, card.nNeed) or TEXT_UNKNOWN },
        { TEXT_BIS, card.bisTotal and (card.bisHave .. "/" .. card.bisTotal) or TEXT_UNKNOWN },
        { TEXT_ZONE, zone or TEXT_UNKNOWN },
    }
    for i, row in ipairs(rows) do
        view.keys[i]:SetText(row[1])
        view.values[i]:SetText(row[2])
        view.keys[i]:Show()
        view.values[i]:Show()
    end
    stack:Put(view.card, St.CARD_PAD * 2 + St.LINE_H + KV_ROWS * St.LINE_H, St.PANEL_GAP)
end

local function MinLine(card, stack)
    local group = card and card.group
    if not (group and group.min > 0) then return end
    view.minText:SetText(TEXT_MIN:format(group.min / UI.TENTHS))
    local mine = ns.NaowhScore.Unit("player")
    local low = not mine or mine * UI.TENTHS < group.min
    view.minYours:SetText(mine and TEXT_YOURS:format(mine) or "")
    local c = low and Style.RED_RGB or Style.HAVE_RGB
    view.minYours:SetTextColor(c.r, c.g, c.b)
    stack:Put(view.min, St.LINE_H, St.PANEL_GAP)
end

local function ApplyBox(entry, stack)
    local record = entry.leader and Comms.SentTo(entry.leader)
    if entry.delisted and not record then
        view.state:SetText(TEXT_DELISTED)
        view.state:SetTextColor(T.muted.r, T.muted.g, T.muted.b)
        stack:Text(view.state)
        return
    end
    if record then
        local text, color
        if record.declined then
            text, color = TEXT_DECLINED:format(entry.leader), Style.RED_RGB
        elseif record.invitedAs then
            text, color = TEXT_INVITED:format(entry.leader, UI.ROLE_WORD[record.invitedAs]), Style.HAVE_RGB
        elseif record.acked then
            text, color = TEXT_RECEIVED:format(entry.leader) .. "  " .. Left(record), Style.HAVE_RGB
        else
            text, color = TEXT_SENDING .. "  " .. Left(record), T.muted
        end
        view.state:SetText(text)
        view.state:SetTextColor(color.r, color.g, color.b)
        stack:Text(view.state)
        if not (record.declined or record.invitedAs) then stack:Put(view.withdraw, St.BUTTON_H, 0) end
        view.withdraw:SetWidth(St.APPLY_W)
        return
    end
    if not Comms.CardOf(entry.leader) then
        if not Picked.CanAsk(entry) then return end
        stack:Put(view.askKicker, St.KICKER_SIZE + 2, St.GAP)
        view.askText:SetText(GF.Whispers.Fill(S.Get("askMessage"), DungeonName(entry)))
        stack:Text(view.askText)
        local at = GF.Whispers.AskedAt(entry.leader)
        ns.SetButtonText(view.ask, at and TEXT_ASK_AGAIN or TEXT_ASK)
        stack:Put(view.ask, St.BUTTON_H, St.GAP)
        view.ask:SetWidth(St.APPLY_W)
        if at then
            view.asked:SetText(TEXT_ASKED:format(entry.leader, Ago(GetTime() - at)))
            stack:Text(view.asked)
        end
        return
    end
    stack:Put(view.applyKicker, St.KICKER_SIZE + 2, St.GAP)
    local roles = ApplyRoles()
    local w = math.floor((view:GetWidth() - 2 * St.GAP) / #view.roles)
    for i, button in ipairs(view.roles) do
        button:SetSize(w, St.BUTTON_H)
        button:ClearAllPoints()
        button:SetPoint("LEFT", view.roleRow, "LEFT", (i - 1) * (w + St.GAP), 0)
        local on = Card.Has(roles, button.role)
        UI.Pick(button, on)
        button.icon:SetDesaturated(not on)
    end
    stack:Put(view.roleRow, St.BUTTON_H, St.GAP)
    view.filling = true
    view.noteBox:SetText(S.Get("applyNote"))
    view.filling = false
    view.counter:SetText(TEXT_COUNT:format(#S.Get("applyNote"), Card.NOTE_MAX))
    stack:Put(view.noteBox, St.EDIT_H, St.GAP)
    stack:Put(view.buttons, St.BUTTON_H, 0)
end

local function ShortState(record)
    if record.declined then return TEXT_SHORT_DECLINED, Style.RED_RGB end
    if record.invitedAs then return TEXT_SHORT_INVITED, Style.HAVE_RGB end
    if record.acked then return TEXT_SHORT_RECEIVED:format(Left(record):match("^(%S+)")), Style.HAVE_RGB end
    return TEXT_SHORT_SENDING, T.muted
end

local function LeaderListing(name)
    for i = 1, Listings.n do
        local entry = Listings.entries[i]
        if entry.leader and Comms.Key(entry.leader) == Comms.Key(name) then return entry end
    end
end

local function Line(n, stack)
    local line = view.homeLines[n] or HomeLine()
    view.homeLines[n] = line
    stack:Put(line, St.HOME_LINE_H, 0)
    return line
end

local function Needs(entry, roles)
    local open = 0
    for _, role in ipairs(UI.ROLES) do
        if Card.Has(roles, role) then open = open + Filter.Open(entry, role) end
    end
    return open
end

local function ByFit(a, b)
    if a.fitCard ~= b.fitCard then return a.fitCard end
    if a.fitScore ~= b.fitScore then return a.fitScore > b.fitScore end
    return a.age < b.age
end

local function Home(stack)
    Listings.Read()
    local n = 0
    stack:Put(view.yoursKicker, St.KICKER_SIZE + 2, St.GAP)
    local sent = Comms.Sent()
    for i = 1, math.min(#sent, St.HOME_SHOWN) do
        local record = sent[i]
        n = n + 1
        local line = Line(n, stack)
        local entry = LeaderListing(record.name)
        line.id = entry and entry.id
        line:SetEnabled(entry ~= nil)
        local J = ns.Journal
        local dungeon = record.dungeon and J and J.Get(record.dungeon)
        line.left:SetText(TEXT_WITH:format(dungeon and dungeon.name or (entry and DungeonName(entry)) or "",
            Ambiguate(record.name, "none")))
        local text, color = ShortState(record)
        line.right:SetText(text)
        line.right:SetTextColor(color.r, color.g, color.b)
        line.sub:SetText(record.acked and not record.declined and not record.invitedAs and Left(record) or "")
    end
    if #sent == 0 then
        view.noApps:SetText(TEXT_NO_APPS)
        stack:Text(view.noApps)
    end
    stack:Space(St.PANEL_GAP)
    stack:Put(view.needKicker, St.KICKER_SIZE + 2, St.GAP)
    local roles = ApplyRoles()
    wipe(ranked)
    for i = 1, Listings.n do
        local entry = Listings.entries[i]
        if not (entry.mine or entry.delisted or Filter.Solo(entry)) and entry.leader and not Comms.SentTo(entry.leader)
            and Needs(entry, roles) > 0 and Filter.Pass(entry) then
            local card = Comms.CardOf(entry.leader)
            entry.fitCard, entry.fitScore = card ~= nil, card and card.score or 0
            ranked[#ranked + 1] = entry
        end
    end
    table.sort(ranked, ByFit)
    for i = 1, math.min(#ranked, St.HOME_SHOWN) do
        local entry = ranked[i]
        n = n + 1
        local line = Line(n, stack)
        line.id = entry.id
        line:SetEnabled(true)
        line.left:SetText(DungeonName(entry))
        local card = Comms.CardOf(entry.leader)
        if card and card.score then
            local c = UI.ScoreColor(card.score, card.level)
            line.right:SetText(("%.1f"):format(card.score / UI.TENTHS))
            line.right:SetTextColor(c.r, c.g, c.b)
        else
            line.right:SetText("")
        end
        line.sub:SetText(TEXT_NEEDS_LINE:format(Ambiguate(entry.leader, "none"), NeedsText(entry)))
    end
    if #ranked == 0 then
        view.noNeed:SetText(TEXT_NONE_NEED)
        stack:Text(view.noNeed)
    end
    stack:Space(St.PANEL_GAP)
    stack:Text(view.empty)
end

local function Current()
    local entry = UI.Selected()
    if entry then
        Picked.preview = nil
        return entry
    end
    if Picked.preview then
        entry = Listings.ById(Picked.preview)
        if not entry then Picked.preview = nil end
        return entry, true
    end
end

local function Head(entry, stack, previewing)
    local activity = entry.activity and Listings.Activity(entry.activity)
    local levels = activity and TEXT_LEVELS:format(activity.min, activity.max) or ""
    local style = entry.style and UI.STYLES[entry.style] or ""
    local sub = TEXT_SUB:format(levels, style, Ago(entry.age))
    if previewing then stack:Put(view.back, St.LINE_H, St.GAP) end
    local J = ns.Journal
    local painting = entry.dungeon and J and J.Paintings and J.Paintings[entry.dungeon]
    if painting then
        view.art.texture:SetTexture(painting[1])
        view.art.title:SetText(activity and activity.name or "")
        view.art.sub:SetText(sub)
        stack:Put(view.art, St.ART_H, St.PANEL_GAP)
        return activity
    end
    view.title:SetText(activity and activity.name or "")
    stack:Text(view.title, 2)
    view.sub:SetText(sub)
    stack:Text(view.sub, St.PANEL_GAP)
    return activity
end

function Picked.Refresh()
    if not (view and view:IsShown()) then return end
    HideAll()
    local stack = view.stack
    stack:Reset()
    local entry, previewing = Current()
    view.entry = entry
    if not entry then
        Home(stack)
        return stack:Finish()
    end
    local activity = Head(entry, stack, previewing)
    local card = entry.leader and Comms.CardOf(entry.leader)
    local group = card and card.group
    if group and group.note ~= "" then
        view.note.text:SetText(group.note)
        stack:Put(view.note, math.ceil(view.note.text:GetStringHeight()), St.PANEL_GAP)
    end
    view.groupKicker:SetText(TEXT_GROUP:format(entry.numMembers, activity and activity.size or SLOTS))
    view.needs:SetText(NeedsText(entry))
    stack:Put(view.groupHead, St.KICKER_SIZE + 2, St.GAP)
    Members(entry, stack)
    stack:Space(St.GAP)
    local text, color = HasText(entry)
    view.has:SetText(text)
    view.has:SetTextColor(color.r, color.g, color.b)
    stack:Text(view.has, St.PANEL_GAP)
    if entry.leader then LeaderCard(entry, card, stack) end
    MinLine(card, stack)
    ApplyBox(entry, stack)
    return stack:Finish()
end

function Picked.Build(parent)
    return Build(parent)
end
