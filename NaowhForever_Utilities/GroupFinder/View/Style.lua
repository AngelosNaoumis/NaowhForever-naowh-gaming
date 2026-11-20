-- Style.lua: the Group Finder's look on and beside the game's group finder, and the words its views share (ns.GroupFinder.UI).
local ns = _G.NaowhForever

local GF = ns.GroupFinder
if not GF then return end
local Card = GF.Card
local T = ns.THEME
local Shared = ns.Shared.Style

local UI = {}
GF.UI = UI
local St = setmetatable({
    SQUARE = 22,
    SQUARE_GAP = 2,
    SQUARE_FILL = 0.6,
    SQUARE_ICON = 12,
    ROW_ICON = 15,
    CROWN = 12,
    CROWN_OUT = 6,
    ROW_RIGHT = 8,
    ROW_TOP = 7,
    ROW_LINE_GAP = 2,
    ROW_STATUS_SIZE = 10,
    PILL_SIZE = 9,
    PILL_GAP = 3,
    ROW_RAISE = 2,
    DIM_ALPHA = 0.35,
    ROLE_BUTTON = 22,
    ART_H = 92,
    ART_PAD = 8,
    ART_COORDS = { 10 / 256, 164 / 256, 10 / 128, 86 / 128 },
    ART_SHADE_TOP = 0.05,
    ART_SHADE_BOTTOM = 0.92,
    HOME_LINE_H = 36,
    HOME_SHOWN = 4,
    HOME_HOVER = 0.06,
    APPLY_W = 109,
    APPLY_H = 28,
    APPLY_BOTTOM = 16,
    PANEL_W = 330,
    PANEL_OUT = 48,
    PANEL_HEADER = 44,
    PANEL_PAD = 12,
    PANEL_GAP = 12,
    PANEL_TABS_H = 24,
    PANEL_FOOT_H = 56,
    PANEL_FOOT_LISTING_H = 34,
    LOGO = 24,
    TITLE_SIZE = 14,
    HEAD_SIZE = 16,
    KICKER_SIZE = 10,
    LINE_SIZE = 12,
    SUB_SIZE = 11,
    SCORE_SIZE = 15,
    LINE_H = 18,
    MEMBER_H = 18,
    ROLE_ICON = 14,
    CARD_PAD = 8,
    NOTE_EDGE = 2,
    NOTE_PAD = 8,
    BUTTON_H = 24,
    SMALL_BUTTON_H = 20,
    CHIP_H = 22,
    CHIP_PAD = 8,
    CHIP_GAP = 4,
    STEP_W = 20,
    STEP_VALUE_W = 36,
    TOGGLE_W = 30,
    TOGGLE_H = 16,
    EDIT_H = 22,
    BAR_H = 14,
    BAR_TEXT_SIZE = 9,
    APPLICANT_GAP = 8,
    APPLICANT_BAND = 3,
    APPLICANT_BUTTON_W = 62,
    CLASS_ICON = 18,
    TAB_OUT = 2,
    PICKED_ALPHA = 1,
    COUNTER_ROOM = 44,
    ROLE_COLORS = { [Card.TANK] = T.accentSoft, [Card.HEALER] = Shared.HAVE_RGB, [Card.DAMAGE] = Shared.RED_RGB },
    TALLY_COLORS = { joined = Shared.HAVE_RGB, declined = Shared.RED_RGB, withdrawn = T.muted,
        expired = Shared.WARN_RGB },
    ROLE_MICRO = { [Card.TANK] = "UI-LFG-RoleIcon-Tank-Micro-GroupFinder",
        [Card.HEALER] = "UI-LFG-RoleIcon-Healer-Micro-GroupFinder",
        [Card.DAMAGE] = "UI-LFG-RoleIcon-DPS-Micro-GroupFinder" },
    CROWN_ATLAS = "groupfinder-icon-leader",
    EMPTY_ATLAS = "groupfinder-icon-emptyslot",
}, { __index = ns.Shared.Style })
UI.Style = St

UI.ROLES = { Card.TANK, Card.HEALER, Card.DAMAGE }
UI.TENTHS = 10
UI.ROLE_LABEL = { [Card.TANK] = ns.L("Tank"), [Card.HEALER] = ns.L("Healer"), [Card.DAMAGE] = ns.L("Damage") }
UI.ROLE_WORD = { [Card.TANK] = ns.L("tank"), [Card.HEALER] = ns.L("healer"), [Card.DAMAGE] = ns.L("damage") }
UI.STYLES = { GROUP_FINDER_GENERAL_PLAYSTYLE1, GROUP_FINDER_GENERAL_PLAYSTYLE2, GROUP_FINDER_GENERAL_PLAYSTYLE3,
    GROUP_FINDER_GENERAL_PLAYSTYLE4 }

function UI.Kicker(parent, text)
    local kicker = ns.Font(parent, St.KICKER_SIZE, nil, T.accentSoft)
    kicker:SetText(text and ns.L(text) or "")
    return kicker
end

function UI.Pick(button, on)
    local edge = on and T.accent or T.line
    button._rest = edge
    button._border:SetColor(edge.r, edge.g, edge.b, 1)
    local color = on and T.fg or T.muted
    button.label:SetTextColor(color.r, color.g, color.b)
end

function UI.ClassColor(class)
    local color = class and RAID_CLASS_COLORS[class]
    return color or T.fg
end

local scoreColors = {}

function UI.ScoreColor(tenths, level)
    local share = ns.NaowhScore.Grade(tenths / UI.TENTHS, level)
    if not share then return T.fg end
    local code = ns.NaowhScore.Code(share)
    local color = scoreColors[code]
    if not color then
        color = { r = tonumber(code:sub(5, 6), 16) / 255, g = tonumber(code:sub(7, 8), 16) / 255,
            b = tonumber(code:sub(9, 10), 16) / 255 }
        scoreColors[code] = color
    end
    return color
end

function UI.Score(tenths, level)
    return ns.NaowhScore.Colored(tenths / UI.TENTHS, level)
end

function UI.RoleOf(bits)
    for _, role in ipairs(UI.ROLES) do
        if Card.Has(bits, role) then return role end
    end
end

function UI.RoleButton(parent, role, onClick)
    local button = ns.Button(parent, "", St.ROLE_BUTTON, St.ROLE_BUTTON, onClick)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAtlas(St.ROLE_MICRO[role])
    button.icon:SetSize(St.SQUARE_ICON, St.SQUARE_ICON)
    button.icon:SetPoint("CENTER")
    button.role = role
    ns.Tooltip(button, UI.ROLE_LABEL[role])
    return button
end

function UI.PaintRole(button, on)
    UI.Pick(button, on)
    button.icon:SetDesaturated(not on)
    button.icon:SetAlpha(on and 1 or St.DIM_ALPHA)
end

function UI.Check(parent, text, get, set)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(St.TOGGLE_H)
    row.toggle = ns.UI.BuildToggleControl(row, nil, get, set, St.TOGGLE_W, St.TOGGLE_H)
    row.toggle:SetPoint("LEFT")
    row.label = ns.Font(row, St.LINE_SIZE)
    row.label:SetPoint("LEFT", row.toggle, "RIGHT", St.GAP, 0)
    row.label:SetText(ns.L(text))
    return row
end
