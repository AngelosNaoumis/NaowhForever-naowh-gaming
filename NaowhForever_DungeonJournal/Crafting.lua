-- Crafting.lua: the Crafting page's rules: every profession's recipes from the Professions module, its picks and what fits them (J.Crafting).
local ns = _G.NaowhForever

local GetItemInfoInstant = C_Item.GetItemInfoInstant
local GetSpellName = C_Spell.GetSpellName

local J = ns.Journal

local WEAPON, ARMOR, CONSUMABLE = 2, 4, 0
local ENCHANTING = 333
local SKILL_LINE = 7
local SKILL_BANDS = { { 1, 74 }, { 75, 149 }, { 150, 224 }, { 225 } }
local BAND_LABEL, TOP_BAND_LABEL = "%d-%d", "%d+"

local GROUPS = {
    { title = ns.L("Profession"), hint = ns.L("Lists one profession's recipes."), picks = {} },
    { title = ns.L("Makes"), hint = ns.L("Lists the recipes that make any one you pick."), picks = {
        { label = ns.L("Gear"), what = "gear" },
        { label = ns.L("Consumables"), what = "consumable" },
        { label = ns.L("Enchants"), what = "enchant" },
        { label = ns.L("Other"), what = "other" },
    } },
    { title = ns.L("Skill"), hint = ns.L("Lists the recipes that need any of these skill levels."), picks = {} },
}
local PROFESSION, WHAT, SKILL = GROUPS[1], GROUPS[2], GROUPS[3]

for _, band in ipairs(SKILL_BANDS) do
    local label = band[2] and BAND_LABEL:format(band[1], band[2]) or TOP_BAND_LABEL:format(band[1])
    SKILL.picks[#SKILL.picks + 1] = { label = label, low = band[1], high = band[2] or math.huge }
end

local picked = {}
local entries = {}
local professionsRead = false

local function ByName(a, b)
    return a.label < b.label
end

local function BySkill(a, b)
    if a.skill ~= b.skill then return a.skill < b.skill end
    return a.order < b.order
end

local function Choose(group)
    wipe(group.chosen)
    for _, pick in ipairs(group.picks) do
        if picked[pick] then group.chosen[#group.chosen + 1] = pick end
    end
end

local function YourProfession()
    for _, index in pairs({ GetProfessions() }) do
        local line = select(SKILL_LINE, GetProfessionInfo(index))
        for _, pick in ipairs(PROFESSION.picks) do
            if pick.line == line then return pick end
        end
    end
    return PROFESSION.picks[1]
end

local function ReadProfessions()
    professionsRead = true
    local picks = PROFESSION.picks
    for line, data in pairs(ns.RecipeData) do
        local name = data.recipes and #data.recipes > 0 and GetSpellName(data.skillSpell)
        if name then picks[#picks + 1] = { label = name, line = line, group = PROFESSION } end
    end
    table.sort(picks, ByName)
    local first = YourProfession()
    if first then
        picked[first] = true
        Choose(PROFESSION)
    end
end

local function WhatOf(line, recipe)
    if not recipe.item then return line == ENCHANTING and "enchant" or "other" end
    local _, _, _, equip, _, class = GetItemInfoInstant(recipe.item)
    if (class == WEAPON or class == ARMOR) and equip and equip ~= "" then return "gear" end
    if class == CONSUMABLE then return "consumable" end
    return "other"
end

local function Entries(line)
    local list = entries[line]
    if list then return list end
    list = {}
    for i, recipe in ipairs(ns.RecipeData[line].recipes) do
        list[i] = { spell = recipe.spell, item = recipe.item, skill = recipe.skill or 0, source = recipe.source,
            what = WhatOf(line, recipe), order = i }
    end
    table.sort(list, BySkill)
    entries[line] = list
    return list
end

local function Fits(group, entry)
    local chosen = group.chosen
    if #chosen == 0 then return true end
    for i = 1, #chosen do
        local pick = chosen[i]
        if pick.what == entry.what or pick.low and entry.skill >= pick.low and entry.skill <= pick.high then
            return true
        end
    end
    return false
end

for _, group in ipairs(GROUPS) do
    group.chosen = {}
    for _, pick in ipairs(group.picks) do pick.group = group end
end

local Crafting = { GROUPS = GROUPS }
J.Crafting = Crafting
for _, group in ipairs(GROUPS) do group.rules = Crafting end

function Crafting.Available()
    return ns.RecipeData ~= nil
end

function Crafting.Groups()
    if not professionsRead then ReadProfessions() end
    return GROUPS
end

function Crafting.Label(pick)
    return pick.label
end

function Crafting.Picked(pick)
    return picked[pick] == true
end

function Crafting.Toggle(pick)
    local group = pick.group
    if group == PROFESSION then
        for _, each in ipairs(group.picks) do picked[each] = nil end
        picked[pick] = true
    else
        picked[pick] = not picked[pick] or nil
    end
    Choose(group)
end

function Crafting.Profession()
    return PROFESSION.chosen[1]
end

function Crafting.Collect(out)
    wipe(out)
    local profession = Crafting.Profession()
    if not profession then return 0 end
    local n = 0
    for _, entry in ipairs(Entries(profession.line)) do
        if Fits(WHAT, entry) and Fits(SKILL, entry) then
            n = n + 1
            out[n] = entry
        end
    end
    return n
end
