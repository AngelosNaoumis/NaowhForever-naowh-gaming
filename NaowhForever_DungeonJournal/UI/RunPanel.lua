-- RunPanel.lua: Run Panel: the run you are in, live: time, gold, XP, trash, each boss's split against your best, and its summary at the end (J.RunPanel).
local ns = _G.NaowhForever

local T = ns.THEME
local J = ns.Journal
local S = J.Settings
local Runs = J.Runs
local Loot = J.Loot
local Quests = J.Quests
local Team = J.Team
local Parts = ns.Shared.Parts
local VP = J.View.Parts
local St = J.Style

local WIDTH = 290
local MIN_MAX_H, SCREEN_SHARE = 420, 0.7
local PLACE = { "RIGHT", "RIGHT", -60, 0 }
local SETTINGS_PAGE = "Dungeon Journal/Journal"
local SETTINGS_CARD = "runPanel"
local TICK_SECONDS = 1
local NEXT_FRAME = 0
local MINUTE = J.C.SECONDS_PER_MINUTE
local GOLD = 10000
local SILVER = 100
local BUTTON_GAP = 4
local LABEL_SIZE, VALUE_SIZE, SUB_SIZE, NAME_SIZE, PILL_SIZE = St.TINY_SIZE, 16, 11, 13, 10
local BIG_SIZE = 26
local LINE_GAP, BLOCK_GAP, CELL_GAP = 2, 8, 6
local STATS_H = LABEL_SIZE + VALUE_SIZE + SUB_SIZE + LINE_GAP * 3
local PIP_W, PIP_H, PIP_GAP, PIP_DROP = 5, 8, 2, 1
local BAR_H = 6
local ROW_H, FACE, FACE_GAP, TICK = 38, 30, 8, 12
local TICK_OUT = 3
local DIM = 0.45
local PILL_GAP = 4
local STRIP_H, STRIP_FACE, STRIP_GAP = 24, 20, 8
local STRIP_FACES_GAP = 3
local SPLIT_H, SPLIT_NAME_W, SPLIT_DELTA_W, LANE_H = 17, 104, 44, 7
local BEST_MARK_W, BEST_MARK_OUT = 1, 2
local LOOT_H, LOOT_ICON = 22, 18
local ACTION_H = 22
local ICON_DROP = 1
local LANE_ALPHA = 0.25
local RING = 1
local BIS_PICK = 1
local RATE_AFTER = 120
local REDRAW_DELAY = 0.2
local THOUSAND = 1000
local REALM = "%-.*"

local TEXT_TITLE_TIP = ns.L("Run Panel")
local TEXT_TITLE_HINT = ns.L("Click to open the Journal's runs.")
local TEXT_SETTINGS_TIP = ns.L("Run Panel settings")
local TEXT_SETTINGS_HINT = ns.L("Opens the Run Panel's settings.")
local TEXT_COMPACT = ns.L("Compact")
local TEXT_FULL = ns.L("Full panel")
local TEXT_LOCKOUTS = ns.L("%d of %d instances this hour")
local TEXT_NEXT_FREE = ns.L("next in %dm")
local TEXT_TIME = ns.L("TIME")
local TEXT_GOLD = ns.L("GOLD")
local TEXT_XP = ns.L("XP")
local TEXT_DEATHS = ns.L("DEATHS")
local TEXT_VS_BEST = ns.L("%s vs best")
local TEXT_BEST = ns.L("best %s")
local TEXT_PER_HOUR = ns.L("%s / hr")
local TEXT_XP_PER_HOUR = ns.L("%.1fk / hr")
local TEXT_TRASH = ns.L("Trash")
local TEXT_OF = ns.L("%d / %d")
local TEXT_NEXT = ns.L("Next")
local TEXT_BIS = ns.L("BiS")
local TEXT_QUEST = ns.L("Quest")
local TEXT_GOT = ns.L("Got %s")
local TEXT_FOOT = ns.L("%s Deaths %s   %s Outside %s   %s Need won %s of %s")
local TEXT_NEW_BEST = ns.L("New best, %s faster")
local TEXT_FIRST = ns.L("First finished run")
local TEXT_BEST_WAS = ns.L("Best %s")
local TEXT_SPLITS = ns.L("SPLITS AGAINST YOUR BEST")
local TEXT_YOU_GOT = ns.L("YOU GOT")
local TEXT_NOTHING_GOT = ns.L("No loot this run.")
local TEXT_OUTSIDE = ns.L("outside %s")
local TEXT_OPEN = ns.L("Open in Journal")
local TEXT_HIDE = ns.L("Hide")
local TEXT_NEED_WON = ns.L("Need won")
local TEXT_NEED_LOST = ns.L("Need lost to %s")
local TEXT_AND = ns.L("%s, %s")
local TEXT_CLICK_BOSS = ns.L("Click to open it in the Journal.")
local TEXT_NOTHING = ns.L("Nothing left on your lists.")
local TEXT_PANEL_OFF = ns.L("The Run Panel is off. Turn it on in /nf, Dungeon Journal, Journal.")
local TEXT_NO_RUN = ns.L("No run going. The Run Panel shows inside a dungeon.")
local TEXT_DELTA = "%s%s"
local TEXT_MINUS, TEXT_PLUS = "-", "+"
local TEXT_NONE = "-"
local TEXT_ICON = "|T%s:0|t %s"

local panel, body
local shown, mode
local closedFor
local ticker
local bosses = {}
local rows, faces, splits, loots = {}, {}, {}, {}
local rolls = {}
local pending
local Draw

local RunPanel = {}
J.RunPanel = RunPanel

local function Scale()
    return ns.UIScale() * (S.Get("runScale") or 1)
end

local function MaxH()
    local screen = (UIParent:GetHeight() or 0) * SCREEN_SHARE / Scale()
    return math.max(MIN_MAX_H, math.floor(screen))
end

local function SavePosition(point, relativePoint, x, y)
    ns.AccountSettings().journalRunPanel = { point, relativePoint, x, y }
end

local function LoadPosition()
    local saved = ns.AccountSettings().journalRunPanel
    if type(saved) == "table" then return saved[1], saved[2], saved[3], saved[4] end
end

local function Opacity()
    return S.Get("runAlpha") or 1
end

local function Paint(fs, color)
    fs:SetTextColor(color.r, color.g, color.b)
end

local function Text(size, color, justify)
    local fs = ns.Font(body, size, nil, color or T.fg)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

local function Delta(seconds)
    local sign = seconds <= 0 and TEXT_MINUS or TEXT_PLUS
    return TEXT_DELTA:format(sign, VP.FightLength(math.abs(seconds)))
end

local function DeltaColor(seconds)
    return seconds <= 0 and St.HAVE_RGB or St.RED_RGB
end

local function Money(copper)
    if copper >= GOLD then copper = copper - copper % SILVER end
    return Parts.Coins(copper)
end

local function Rate(amount, seconds, xp)
    if seconds < RATE_AFTER then return TEXT_NONE end
    local rate = Runs.PerHour(amount, seconds)
    if xp then return TEXT_XP_PER_HOUR:format(rate / THOUSAND) end
    return TEXT_PER_HOUR:format(Money(rate))
end

local function Ring(parent, size)
    local ring = VP.BossFace(parent, size + RING * 2)
    ring:SetDrawLayer("BACKGROUND")
    ring:Show()
    return ring
end

local function SetRing(ring, color)
    ring:SetColorTexture(color.r, color.g, color.b, 1)
end

local function Bosses(dungeon)
    wipe(bosses)
    for _, wing in ipairs(dungeon.wings) do
        for _, boss in ipairs(wing.bosses) do
            if Runs.Counts(boss) then bosses[#bosses + 1] = boss end
        end
    end
    return bosses
end

local function NextBoss(run)
    for i = 1, #bosses do
        if not Runs.Split(run, bosses[i]) then return bosses[i] end
    end
end

local function LastKill(run)
    local last, at
    for i = 1, #bosses do
        local split = Runs.Split(run, bosses[i])
        if split and (not at or split > at) then last, at = bosses[i], split end
    end
    return last, at
end

local function MissingBis(boss)
    if not (boss.loot and Loot.BisOn()) then return nil end
    for i = 1, #boss.loot do
        if Loot.Missing(boss.loot[i]) then return boss.loot[i] end
    end
end

local function QuestFor(boss)
    local ids = boss.npc and J.BossQuests[boss.npc]
    for i = 1, ids and #ids or 0 do
        local quest = Quests.ByID(ids[i])
        if quest and Quests.ForMe(quest) and Quests.Kind(quest) == "active" then return quest end
    end
end

local function GotFrom(run, boss)
    for i = 1, #run.loot do
        if run.loot[i].boss == boss.english then return run.loot[i] end
    end
end

local function Me()
    local name = UnitName("player")
    return name and not issecretvalue(name) and (name:gsub(REALM, ""))
end

local function RollNote(item)
    local me = Me()
    Team.ReadRolls(item.rolls, rolls)
    for i = 1, #rolls do
        local roll = rolls[i]
        if roll.winner then
            if roll.name == me then return roll.state <= Enum.EncounterLootDropRollState.NeedOffSpec and TEXT_NEED_WON or nil end
            return TEXT_NEED_LOST:format(roll.name)
        end
    end
end

local function LootNote(item)
    local bis = Loot.BisOn() and Loot.Rank(item.id) == BIS_PICK and TEXT_BIS or nil
    local roll = item.rolls and RollNote(item)
    if bis and roll then return TEXT_AND:format(bis, roll) end
    return bis or roll or ""
end

local function Cell(i)
    local cells = panel.cells
    local cell = cells[i]
    if cell then return cell end
    cell = { label = Text(LABEL_SIZE, T.muted), value = Text(VALUE_SIZE), sub = Text(SUB_SIZE, T.muted) }
    cells[i] = cell
    return cell
end

local function PlaceCells(y, count)
    local w = (body:GetWidth() - CELL_GAP * (count - 1)) / count
    for i = 1, count do
        local cell = Cell(i)
        local x = (i - 1) * (w + CELL_GAP)
        cell.label:SetPoint("TOPLEFT", x, -y)
        cell.value:SetPoint("TOPLEFT", cell.label, "BOTTOMLEFT", 0, -LINE_GAP)
        cell.sub:SetPoint("TOPLEFT", cell.value, "BOTTOMLEFT", 0, -LINE_GAP)
        for _, fs in pairs(cell) do
            fs:SetWidth(w)
            fs:Show()
        end
    end
    return y + STATS_H
end

local function SetCell(i, label, value, sub, subColor)
    local cell = Cell(i)
    cell.label:SetText(label)
    cell.value:SetText(value)
    cell.sub:SetText(sub or "")
    Paint(cell.sub, subColor or T.muted)
end

local function Pips(count, cap)
    local pips = panel.pips
    for i = 1, math.max(cap, #pips) do
        local pip = pips[i]
        if not pip and i <= cap then
            pip = body:CreateTexture(nil, "ARTWORK")
            pip:SetSize(PIP_W, PIP_H)
            pips[i] = pip
        end
        if pip then
            local color = i <= count and T.accent or T.grey
            pip:SetColorTexture(color.r, color.g, color.b, 1)
            pip:ClearAllPoints()
            pip:SetPoint("TOPLEFT", (i - 1) * (PIP_W + PIP_GAP), -PIP_DROP)
            pip:SetShown(i <= cap)
        end
    end
    return cap * (PIP_W + PIP_GAP)
end

local function Lockouts(y)
    local tracker = ns.InstanceTracker
    local lock = panel.lock
    for _, pip in ipairs(panel.pips) do pip:Hide() end
    if not (tracker and tracker.Enabled()) then
        lock:Hide()
        return y
    end
    local count, cap, frees = tracker.Hour()
    local x = Pips(count, cap)
    local text = TEXT_LOCKOUTS:format(count, cap)
    if count > 0 and frees > 0 then text = TEXT_AND:format(text, TEXT_NEXT_FREE:format(math.ceil(frees / MINUTE))) end
    lock:SetPoint("TOPLEFT", x + PIP_GAP, -y)
    lock:SetText(text)
    lock:Show()
    return y + SUB_SIZE + BLOCK_GAP
end

local function Trash(run, y)
    local total = Runs.TrashTotal(run.dungeon)
    panel.trashLabel:SetPoint("TOPLEFT", 0, -y)
    panel.trashLabel:Show()
    panel.trashCount:SetPoint("TOPRIGHT", 0, -y)
    panel.trashCount:SetText(total and TEXT_OF:format(run.trash, total) or tostring(run.trash))
    panel.trashCount:Show()
    y = y + SUB_SIZE + LINE_GAP * 2
    local bar = panel.trashBar
    bar:SetShown(total ~= nil)
    if not total then return y + BLOCK_GAP end
    bar:SetPoint("TOPLEFT", 0, -y)
    bar:SetPoint("RIGHT")
    bar:SetProgress(run.trash / total)
    return y + BAR_H + BLOCK_GAP
end

local function BossEnter(row)
    row.hover:Show()
    local boss = row.boss
    if not Parts.Tip(row, "ANCHOR_LEFT") then return end
    GameTooltip:SetText(boss.name, 1, 1, 1)
    local any = false
    for i = 1, boss.loot and Loot.BisOn() and #boss.loot or 0 do
        local id = boss.loot[i]
        if Loot.Missing(id) then
            local icon = C_Item.GetItemIconByID(id)
            GameTooltip:AddLine(TEXT_ICON:format(icon, Loot.Name(id) or ""), St.BIS_RGB.r, St.BIS_RGB.g, St.BIS_RGB.b)
            any = true
        end
    end
    local quest = QuestFor(boss)
    if quest then
        GameTooltip:AddLine(TEXT_ICON:format(St.BANG, Quests.Name(quest)), St.CARRIED_RGB.r, St.CARRIED_RGB.g, St.CARRIED_RGB.b)
        any = true
    end
    if not any then GameTooltip:AddLine(TEXT_NOTHING, T.muted.r, T.muted.g, T.muted.b) end
    GameTooltip:AddLine(TEXT_CLICK_BOSS, T.accentSoft.r, T.accentSoft.g, T.accentSoft.b)
    GameTooltip:Show()
end

local function BossLeave(row)
    row.hover:Hide()
    GameTooltip:Hide()
end

local function BossClick(row)
    J.OpenBossPage(J.Get(shown.dungeon), row.boss)
end

local function Tag(row, i)
    local pill = row.pills[i]
    if pill then return pill end
    pill = Parts.Pill(row, PILL_SIZE, T.muted)
    row.pills[i] = pill
    return pill
end

local function AddTag(row, count, text, color)
    count = count + 1
    local pill = Tag(row, count)
    Parts.ColorPill(pill, color)
    Parts.SetPill(pill, text)
    pill:ClearAllPoints()
    if count == 1 then
        pill:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -LINE_GAP)
    else
        pill:SetPoint("LEFT", row.pills[count - 1], "RIGHT", PILL_GAP, 0)
    end
    pill:Show()
    return count
end

local function SetTags(row, run, boss, killed)
    local count = 0
    if killed then
        local item = GotFrom(run, boss)
        if item then count = AddTag(row, count, TEXT_GOT:format(Loot.Name(item.id) or ""), T.muted) end
    else
        if MissingBis(boss) then count = AddTag(row, count, TEXT_BIS, St.BIS_RGB) end
        if QuestFor(boss) then count = AddTag(row, count, TEXT_QUEST, St.CARRIED_RGB) end
    end
    for i = count + 1, #row.pills do row.pills[i]:Hide() end
    return count > 0
end

local function Row(i)
    local row = rows[i]
    if row then return row end
    row = CreateFrame("Button", nil, body)
    row:SetHeight(ROW_H)
    row.hover = ns.Solid(row, "BACKGROUND", T.fg, St.ROW_HOVER)
    row.hover:SetAllPoints()
    row.hover:Hide()
    row.face = VP.BossFace(row, FACE)
    row.face:SetPoint("LEFT", RING, 0)
    row.ring = Ring(row, FACE)
    row.ring:SetPoint("CENTER", row.face)
    row.tick = row:CreateTexture(nil, "OVERLAY")
    row.tick:SetTexture(St.TICK)
    row.tick:SetSize(TICK, TICK)
    row.tick:SetVertexColor(St.HAVE_RGB.r, St.HAVE_RGB.g, St.HAVE_RGB.b)
    row.tick:SetPoint("BOTTOMRIGHT", row.face, "BOTTOMRIGHT", TICK_OUT, -TICK_OUT)
    row.name = ns.Font(row, NAME_SIZE, nil, T.fg)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.when = ns.Font(row, SUB_SIZE + 1, nil, T.fg)
    row.when:SetJustifyH("RIGHT")
    row.delta = ns.Font(row, SUB_SIZE, nil, T.muted)
    row.delta:SetJustifyH("RIGHT")
    row.when:SetPoint("TOPRIGHT", 0, -BLOCK_GAP)
    row.delta:SetPoint("TOPRIGHT", row.when, "BOTTOMRIGHT", 0, -LINE_GAP)
    row.pills = {}
    row:SetScript("OnEnter", BossEnter)
    row:SetScript("OnLeave", BossLeave)
    row:SetScript("OnClick", BossClick)
    rows[i] = row
    return row
end

local function FillRow(row, run, boss, next)
    local split = Runs.Split(run, boss)
    local best = Runs.BestSplit(run.dungeon, boss, run)
    row.boss = boss
    VP.SetBossFace(row.face, boss, true)
    row.face:SetDesaturated(split ~= nil)
    local shade = split and DIM or 1
    row.face:SetVertexColor(shade, shade, shade)
    row.tick:SetShown(split ~= nil)
    SetRing(row.ring, boss == next and T.accent or T.grey)
    row.name:SetText(boss.name)
    Paint(row.name, split and T.muted or T.fg)
    row.when:SetText("")
    row.delta:SetText("")
    if split then
        row.when:SetText(VP.FightLength(split))
        Paint(row.when, T.fg)
        if best then
            row.delta:SetText(Delta(split - best))
            Paint(row.delta, DeltaColor(split - best))
        end
    elseif boss == next then
        row.when:SetText(TEXT_NEXT)
        Paint(row.when, T.accentSoft)
        if best then
            row.delta:SetText(TEXT_BEST:format(VP.FightLength(best)))
            Paint(row.delta, T.muted)
        end
    end
    local tagged = SetTags(row, run, boss, split ~= nil)
    row.name:ClearAllPoints()
    row.name:SetPoint(tagged and "TOPLEFT" or "LEFT", row.face, tagged and "TOPRIGHT" or "RIGHT", FACE_GAP, tagged and -LINE_GAP or 0)
    row.name:SetPoint("RIGHT", row.when, "LEFT", -FACE_GAP, 0)
end

local function BossRows(run, y)
    local next = NextBoss(run)
    for i = 1, #bosses do
        local row = Row(i)
        FillRow(row, run, bosses[i], next)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetPoint("RIGHT")
        row:Show()
        y = y + ROW_H
    end
    for i = #bosses + 1, #rows do rows[i]:Hide() end
    return y + BLOCK_GAP
end

local function Footer(run, y)
    local foot = panel.foot
    foot:SetPoint("TOPLEFT", 0, -y)
    foot:SetPoint("RIGHT")
    foot:SetText(TEXT_FOOT:format(Parts.Inline(St.SKULL, T.muted, ICON_DROP), run.deaths,
        Parts.Inline(St.CLOCK, T.muted, ICON_DROP), VP.FightLength(run.out),
        Parts.Inline(St.BAG, T.muted, ICON_DROP), run.needWon, run.needWon + run.needLost))
    foot:Show()
    return y + SUB_SIZE + LINE_GAP
end

local function LiveStats(run)
    local elapsed = Runs.Elapsed(run)
    local last, at = LastKill(run)
    local best = last and Runs.BestSplit(run.dungeon, last, run)
    if best then
        SetCell(1, TEXT_TIME, VP.FightLength(elapsed), TEXT_VS_BEST:format(Delta(at - best)), DeltaColor(at - best))
    else
        local bestTime = Runs.BestTime(run.dungeon, nil, run)
        SetCell(1, TEXT_TIME, VP.FightLength(elapsed), bestTime and TEXT_BEST:format(VP.FightLength(bestTime)) or nil)
    end
    SetCell(2, TEXT_GOLD, Money(run.copper), Rate(run.copper, elapsed))
    SetCell(3, TEXT_XP, BreakUpLargeNumbers(run.xp), Rate(run.xp, elapsed, true))
end

local function CompactTime(run)
    local last, at = LastKill(run)
    local best = last and Runs.BestSplit(run.dungeon, last, run)
    panel.stripTime:SetText(VP.FightLength(Runs.Elapsed(run)))
    panel.stripDelta:SetText(best and Delta(at - best) or "")
    if best then Paint(panel.stripDelta, DeltaColor(at - best)) end
end

local function Tick()
    if not (panel and panel:IsShown() and shown) or shown.done then return end
    if mode == "compact" then
        local before = panel.stripTime:GetText()
        CompactTime(shown)
        if #(before or "") ~= #panel.stripTime:GetText() then Draw(shown) end
        return
    end
    LiveStats(shown)
end

local function StopTicker()
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
end

local function HideAll()
    for _, region in ipairs(panel.regions) do region:Hide() end
    for _, cell in pairs(panel.cells) do
        for _, fs in pairs(cell) do fs:Hide() end
    end
    for _, pip in ipairs(panel.pips) do pip:Hide() end
    for _, list in ipairs({ rows, faces, splits, loots }) do
        for _, part in ipairs(list) do part:Hide() end
    end
end

local function Redraw()
    pending = false
    if shown and panel:IsShown() then Draw(shown) end
end

local function Fit(height)
    if panel:Fit(height) then C_Timer.After(NEXT_FRAME, Redraw) end
end

local function DrawFull(run)
    panel:SetTrackerWidth(WIDTH)
    local y = Lockouts(0)
    y = PlaceCells(y, 3) + BLOCK_GAP
    LiveStats(run)
    y = Trash(run, y)
    y = BossRows(run, y)
    return Footer(run, y)
end

local function Face(i)
    local face = faces[i]
    if face then return face end
    face = CreateFrame("Frame", nil, body)
    face:SetSize(STRIP_FACE, STRIP_FACE)
    face.texture = VP.BossFace(face, STRIP_FACE)
    face.texture:SetPoint("CENTER")
    face.ring = Ring(face, STRIP_FACE)
    face.ring:SetPoint("CENTER")
    face.tick = face:CreateTexture(nil, "OVERLAY")
    face.tick:SetTexture(St.TICK)
    face.tick:SetSize(TICK, TICK)
    face.tick:SetPoint("CENTER")
    faces[i] = face
    return face
end

local function PlaceStrip(fs, x, gap)
    fs:ClearAllPoints()
    fs:SetPoint("LEFT", body, "TOPLEFT", x, -STRIP_H / 2)
    fs:Show()
    return x + math.ceil(fs:GetStringWidth()) + gap
end

local function DrawCompact(run)
    local next = NextBoss(run)
    CompactTime(run)
    local x = PlaceStrip(panel.stripTime, 0, STRIP_GAP)
    local delta = panel.stripDelta:GetText()
    if delta and delta ~= "" then x = PlaceStrip(panel.stripDelta, x, STRIP_GAP) end
    panel.stripGold:SetText(Money(run.copper))
    x = PlaceStrip(panel.stripGold, x, STRIP_GAP)
    for i, boss in ipairs(bosses) do
        local face = Face(i)
        local killed = Runs.Split(run, boss) ~= nil
        VP.SetBossFace(face.texture, boss, true)
        face.texture:SetDesaturated(killed)
        local shade = killed and DIM or 1
        face.texture:SetVertexColor(shade, shade, shade)
        face.tick:SetShown(killed)
        local ring = boss == next and T.accent or not killed and (MissingBis(boss) or QuestFor(boss)) and St.BIS_RGB or T.grey
        SetRing(face.ring, ring)
        face:ClearAllPoints()
        face:SetPoint("LEFT", body, "TOPLEFT", x, -STRIP_H / 2)
        face:Show()
        x = x + STRIP_FACE + STRIP_FACES_GAP
    end
    x = x + STRIP_GAP - STRIP_FACES_GAP
    local total = Runs.TrashTotal(run.dungeon)
    panel.stripTrash:SetText(total and TEXT_OF:format(run.trash, total) or tostring(run.trash))
    x = PlaceStrip(panel.stripTrash, x, 0)
    panel:SetTrackerWidth(math.max(x, 1) + St.PANEL_PAD * 2)
    return STRIP_H
end

local function Split(i)
    local split = splits[i]
    if split then return split end
    split = CreateFrame("Frame", nil, body)
    split:SetHeight(SPLIT_H)
    split.name = ns.Font(split, SUB_SIZE, nil, T.fg)
    split.name:SetJustifyH("LEFT")
    split.name:SetWordWrap(false)
    split.name:SetPoint("LEFT")
    split.name:SetWidth(SPLIT_NAME_W)
    split.delta = ns.Font(split, SUB_SIZE, nil, T.muted)
    split.delta:SetJustifyH("RIGHT")
    split.delta:SetPoint("RIGHT")
    split.delta:SetWidth(SPLIT_DELTA_W)
    split.lane = ns.Solid(split, "BACKGROUND", T.line, LANE_ALPHA)
    split.lane:SetPoint("LEFT", SPLIT_NAME_W + CELL_GAP, 0)
    split.lane:SetPoint("RIGHT", -SPLIT_DELTA_W - CELL_GAP, 0)
    split.lane:SetHeight(LANE_H)
    split.fill = ns.Solid(split, "ARTWORK", T.accent, 1)
    split.fill:SetHeight(LANE_H)
    split.best = ns.Solid(split, "OVERLAY", T.fg, 1)
    split.best:SetSize(BEST_MARK_W, LANE_H + BEST_MARK_OUT * 2)
    splits[i] = split
    return split
end

local function LootRow(i)
    local row = loots[i]
    if row then return row end
    row = CreateFrame("Frame", nil, body)
    row:SetHeight(LOOT_H)
    row.icon = Parts.ItemIcon(row, LOOT_ICON)
    row.icon:SetPoint("LEFT")
    row.note = ns.Font(row, SUB_SIZE, nil, T.muted)
    row.note:SetJustifyH("RIGHT")
    row.note:SetPoint("RIGHT")
    row.name = ns.Font(row, SUB_SIZE + 1, nil, T.fg)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.name:SetPoint("LEFT", row.icon, "RIGHT", CELL_GAP, 0)
    row.name:SetPoint("RIGHT", row.note, "LEFT", -CELL_GAP, 0)
    loots[i] = row
    return row
end

local function Heading(fs, text, y)
    fs:SetText(text)
    fs:SetPoint("TOPLEFT", 0, -y)
    fs:Show()
    return y + LABEL_SIZE + LINE_GAP * 2
end

local function DrawSplits(run, y)
    local scale = math.max(run.done, Runs.BestTime(run.dungeon, run.wing, run) or 0, 1)
    local laneW = body:GetWidth() - SPLIT_NAME_W - SPLIT_DELTA_W - CELL_GAP * 2
    local n, from = 0, 0
    for _, boss in ipairs(bosses) do
        local at = Runs.Split(run, boss)
        if at then
            n = n + 1
            local split = Split(n)
            local best = Runs.BestSplit(run.dungeon, boss, run)
            split.name:SetText(boss.name)
            split.fill:ClearAllPoints()
            split.fill:SetPoint("LEFT", split.lane, "LEFT", math.min(from, at) / scale * laneW, 0)
            split.fill:SetWidth(math.max(1, math.abs(at - from) / scale * laneW))
            split.best:ClearAllPoints()
            split.best:SetPoint("CENTER", split.lane, "LEFT", (best or at) / scale * laneW, 0)
            split.best:SetShown(best ~= nil)
            split.delta:SetText(best and Delta(at - best) or "")
            if best then Paint(split.delta, DeltaColor(at - best)) end
            split:ClearAllPoints()
            split:SetPoint("TOPLEFT", 0, -y)
            split:SetPoint("RIGHT")
            split:Show()
            y = y + SPLIT_H
            from = at
        end
    end
    return y + BLOCK_GAP
end

local function DrawLoot(run, y)
    if #run.loot == 0 then
        panel.noLoot:SetPoint("TOPLEFT", 0, -y)
        panel.noLoot:Show()
        return y + SUB_SIZE + BLOCK_GAP
    end
    for i, item in ipairs(run.loot) do
        local row = LootRow(i)
        row.icon.texture:SetTexture(C_Item.GetItemIconByID(item.id))
        row.name:SetText(item.link)
        row.note:SetText(LootNote(item))
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetPoint("RIGHT")
        row:Show()
        y = y + LOOT_H
    end
    return y + BLOCK_GAP
end

local function DrawDone(run)
    panel:SetTrackerWidth(WIDTH)
    local was = Runs.BestTime(run.dungeon, run.wing, run)
    local big = panel.big
    big:SetText(VP.FightLength(run.done))
    big:SetPoint("TOP", 0, 0)
    big:Show()
    local pill = panel.best
    if not run.partial and (not was or run.done < was) then
        Parts.ColorPill(pill, St.HAVE_RGB)
        Parts.SetPill(pill, was and TEXT_NEW_BEST:format(VP.FightLength(was - run.done)) or TEXT_FIRST)
    elseif was then
        Parts.ColorPill(pill, T.muted)
        Parts.SetPill(pill, TEXT_BEST_WAS:format(VP.FightLength(was)))
    end
    pill:SetPoint("TOP", big, "BOTTOM", 0, -LINE_GAP)
    pill:SetShown(was ~= nil or not run.partial)
    local y = BIG_SIZE + PILL_SIZE + LINE_GAP * 4 + BLOCK_GAP
    y = PlaceCells(y, 3) + BLOCK_GAP
    SetCell(1, TEXT_GOLD, Money(run.copper), Rate(run.copper, run.done))
    SetCell(2, TEXT_XP, BreakUpLargeNumbers(run.xp), Rate(run.xp, run.done, true))
    SetCell(3, TEXT_DEATHS, tostring(run.deaths), TEXT_OUTSIDE:format(VP.FightLength(run.out)))
    y = Heading(panel.splitsHead, TEXT_SPLITS, y)
    y = DrawSplits(run, y)
    y = Heading(panel.lootHead, TEXT_YOU_GOT, y)
    y = DrawLoot(run, y)
    panel.open:SetPoint("TOPLEFT", 0, -y)
    panel.open:SetPoint("RIGHT", body, "CENTER", -BUTTON_GAP / 2, 0)
    panel.hide:SetPoint("TOPLEFT", body, "TOP", BUTTON_GAP / 2, -y)
    panel.hide:SetPoint("RIGHT")
    panel.open:Show()
    panel.hide:Show()
    return y + ACTION_H
end

function Draw(run)
    shown = run
    local dungeon = J.Get(run.dungeon)
    if not dungeon then return end
    Bosses(dungeon)
    panel.title:SetText(dungeon.name)
    panel.compact.tip = S.Get("runCompact") and TEXT_FULL or TEXT_COMPACT
    mode = run.done and "done" or S.Get("runCompact") and "compact" or "full"
    panel.compact:SetShown(mode ~= "done")
    HideAll()
    local height
    if mode == "done" then
        height = DrawDone(run)
    elseif mode == "compact" then
        height = DrawCompact(run)
    else
        height = DrawFull(run)
    end
    body:SetHeight(math.max(height, 1))
    Fit(height)
    if run.done then
        StopTicker()
    elseif not ticker then
        ticker = C_Timer.NewTicker(TICK_SECONDS, Tick)
    end
end

local function Closed()
    if shown then closedFor = shown.start end
    StopTicker()
    panel:Hide()
end

local function OpenRun()
    if shown then J.OpenRun(shown) end
end

local function ToggleCompact()
    S.Set("runCompact", not S.Get("runCompact"))
end

local function NewBody(scroll)
    body = CreateFrame("Frame", nil, scroll)
    return body
end

local function Regions()
    panel.regions = {}
    local function Keep(region)
        panel.regions[#panel.regions + 1] = region
        return region
    end
    panel.lock = Keep(Text(SUB_SIZE, T.muted))
    panel.trashLabel = Keep(Text(SUB_SIZE, T.muted))
    panel.trashLabel:SetText(TEXT_TRASH)
    panel.trashCount = Keep(Text(SUB_SIZE, T.fg, "RIGHT"))
    panel.trashBar = Keep(Parts.ProgressLine(body, BAR_H))
    panel.foot = Keep(Text(SUB_SIZE, T.muted))
    panel.stripTime = Keep(Text(VALUE_SIZE))
    panel.stripDelta = Keep(Text(SUB_SIZE))
    panel.stripGold = Keep(Text(SUB_SIZE + 1))
    panel.stripTrash = Keep(Text(SUB_SIZE, T.muted))
    panel.big = Keep(Text(BIG_SIZE, T.fg, "CENTER"))
    panel.best = Keep(Parts.Pill(body, PILL_SIZE, St.HAVE_RGB))
    panel.splitsHead = Keep(Text(LABEL_SIZE, T.muted))
    panel.lootHead = Keep(Text(LABEL_SIZE, T.muted))
    panel.noLoot = Keep(Text(SUB_SIZE, T.muted))
    panel.noLoot:SetText(TEXT_NOTHING_GOT)
    panel.open = Keep(ns.Button(body, TEXT_OPEN, 1, ACTION_H, OpenRun))
    ns.AccentBorder(panel.open)
    panel.hide = Keep(ns.Button(body, TEXT_HIDE, 1, ACTION_H, Closed))
    panel.cells, panel.pips = {}, {}
end

local function Build()
    panel = Parts.TrackerPanel("", {
        width = WIDTH, titleRoom = St.ACTION + BUTTON_GAP, maxHeight = MaxH,
        onTitle = OpenRun, titleTip = TEXT_TITLE_TIP, titleHint = TEXT_TITLE_HINT,
        newBody = NewBody,
        settings = { page = SETTINGS_PAGE, card = SETTINGS_CARD, tip = TEXT_SETTINGS_TIP, hint = TEXT_SETTINGS_HINT },
        opacity = Opacity, onClose = Closed,
        load = LoadPosition, save = SavePosition, place = PLACE,
    })
    panel.compact = Parts.IconButton(panel, ToggleCompact, ns.Shared.Style.ARROW, 0, TEXT_COMPACT)
    panel.compact:SetPoint("RIGHT", panel.close, "LEFT", -BUTTON_GAP, 0)
    panel:SetScript("OnHide", StopTicker)
    Regions()
end

local function Show(run)
    if not panel then Build() end
    panel:SetScale(Scale())
    panel:Paint()
    if not panel:IsShown() then
        panel:Place()
        panel:Show()
    end
    Draw(run)
end

local function OnRuns(kind)
    local run = Runs.Open()
    if not (run and Runs.On() and Runs.Inside()) then
        if panel then panel:Hide() end
        shown = nil
        return
    end
    if kind == "done" then closedFor = nil end
    if closedFor == run.start then return end
    if kind == "stats" and panel and panel:IsShown() and shown == run then
        if not pending then
            pending = true
            C_Timer.After(REDRAW_DELAY, Redraw)
        end
        return
    end
    Show(run)
end

local function OnSettingChanged(key)
    if not panel then return end
    if key == "runAlpha" then
        panel:Paint()
    elseif key == "runScale" then
        panel:SetScale(Scale())
    elseif key == "runCompact" and shown and panel:IsShown() then
        Draw(shown)
    end
end

function RunPanel.IsShown()
    return panel ~= nil and panel:IsShown()
end

function ns.ToggleRunPanel()
    if not Runs.On() then return ns.Print(TEXT_PANEL_OFF) end
    local run = Runs.Open()
    if not (run and Runs.Inside()) then return ns.Print(TEXT_NO_RUN) end
    if panel and panel:IsShown() then return Closed() end
    closedFor = nil
    Show(run)
end

Runs.OnChange(OnRuns)
S.OnChange(OnSettingChanged)
