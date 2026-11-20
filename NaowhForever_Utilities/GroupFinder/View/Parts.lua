-- Parts.lua: the small parts the Group Finder panel's views are made of: a stack laid out top to bottom, member lines, steppers, chips and an edit line (ns.GroupFinder.UI).
local ns = _G.NaowhForever

local GF = ns.GroupFinder
if not GF then return end
local UI = GF.UI
local St = UI.Style
local T = ns.THEME

local Stack = {}
Stack.__index = Stack

function UI.Stack(child)
    return setmetatable({ child = child, y = 0 }, Stack)
end

function Stack:Reset()
    self.y = 0
end

function Stack:Put(region, height, gap, indent)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", self.child, "TOPLEFT", indent or 0, -self.y)
    region:SetPoint("RIGHT", self.child, "RIGHT")
    if region.SetHeight and height then region:SetHeight(height) end
    region:Show()
    self.y = self.y + height + (gap or St.GAP)
end

function Stack:Text(font, gap)
    font:ClearAllPoints()
    font:SetPoint("TOPLEFT", self.child, "TOPLEFT", 0, -self.y)
    font:SetPoint("RIGHT", self.child, "RIGHT")
    font:Show()
    self.y = self.y + math.ceil(font:GetStringHeight()) + (gap or St.GAP)
end

function Stack:Space(gap)
    self.y = self.y + gap
end

function Stack:Finish()
    self.child:SetHeight(math.max(1, self.y))
    return self.y
end

function UI.Wrapped(parent, size, color)
    local font = ns.Font(parent, size or St.LINE_SIZE, nil, color)
    font:SetJustifyH("LEFT")
    font:SetJustifyV("TOP")
    font:SetWordWrap(true)
    return font
end

function UI.MemberLine(parent)
    local line = CreateFrame("Frame", nil, parent)
    line:SetHeight(St.MEMBER_H)
    line.icon = line:CreateTexture(nil, "ARTWORK")
    line.icon:SetSize(St.ROLE_ICON, St.ROLE_ICON)
    line.icon:SetPoint("LEFT")
    line.name = ns.Font(line, St.LINE_SIZE)
    line.name:SetPoint("LEFT", line.icon, "RIGHT", St.GAP, 0)
    line.crown = line:CreateTexture(nil, "ARTWORK")
    line.crown:SetAtlas(St.CROWN_ATLAS)
    line.crown:SetSize(St.CROWN, St.CROWN)
    line.crown:SetPoint("LEFT", line.name, "RIGHT", St.GAP / 2, 0)
    line.info = ns.Font(line, St.SUB_SIZE, nil, T.muted)
    line.info:SetPoint("RIGHT")
    return line
end

function UI.PaintMember(line, role, name, class, info, leader)
    line.icon:SetAtlas(St.ROLE_MICRO[role])
    line.icon:SetDesaturated(name == nil)
    line.icon:SetAlpha(name and 1 or St.DIM_ALPHA)
    local color = name and UI.ClassColor(class) or T.muted
    line.name:SetText(name or ns.L("Open: %s", UI.ROLE_WORD[role]))
    line.name:SetTextColor(color.r, color.g, color.b)
    line.crown:SetShown(leader == true)
    line.info:SetText(info or "")
end

function UI.Stepper(parent, label, get, set, step, low, high, format)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(St.SMALL_BUTTON_H)
    row.label = ns.Font(row, St.LINE_SIZE)
    row.label:SetPoint("LEFT")
    row.label:SetText(label and ns.L(label) or "")
    local plus = ns.Button(row, "+", St.STEP_W, St.SMALL_BUTTON_H)
    plus:SetPoint("RIGHT")
    row.value = ns.Font(row, St.LINE_SIZE)
    row.value:SetWidth(St.STEP_VALUE_W)
    row.value:SetPoint("RIGHT", plus, "LEFT", 0, 0)
    local minus = ns.Button(row, "-", St.STEP_W, St.SMALL_BUTTON_H)
    minus:SetPoint("RIGHT", row.value, "LEFT", 0, 0)
    function row.Refresh()
        row.value:SetText(format and format:format(get()) or tostring(get()))
    end
    local function Move(dir)
        local v = get() + dir * step
        if v < low or v > high then return end
        set(v)
        row.Refresh()
    end
    plus._onClick = function() Move(1) end
    minus._onClick = function() Move(-1) end
    row.Refresh()
    return row
end

function UI.Chip(parent, onClick)
    local chip = ns.Button(parent, "", St.CHIP_H, St.CHIP_H, onClick)
    return chip
end

function UI.SetChip(chip, text, state)
    chip.label:SetText(text)
    chip:SetWidth(math.ceil(chip.label:GetStringWidth()) + 2 * St.CHIP_PAD)
    local Style = ns.Shared.Style
    local edge, color
    if state == GF.Filter.HAS then
        edge, color = T.accent, T.fg
    elseif state == GF.Filter.LACKS then
        edge, color = Style.RED_RGB, Style.RED_RGB
    else
        edge, color = T.line, T.muted
    end
    chip._rest = edge
    chip._border:SetColor(edge.r, edge.g, edge.b, 1)
    chip.label:SetTextColor(color.r, color.g, color.b)
end

function UI.Flow(parent, chips, width)
    local x, y = 0, 0
    for _, chip in ipairs(chips) do
        if chip:IsShown() then
            local w = chip:GetWidth()
            if x > 0 and x + w > width then
                x, y = 0, y + St.CHIP_H + St.CHIP_GAP
            end
            chip:ClearAllPoints()
            chip:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
            x = x + w + St.CHIP_GAP
        end
    end
    local height = y + St.CHIP_H
    parent:SetHeight(height)
    return height
end

function UI.EditLine(parent, hint, max, onChange)
    local box = ns.NewSearchBox(parent, hint, onChange)
    box:SetMaxLetters(max)
    box:SetHeight(St.EDIT_H)
    return box
end
