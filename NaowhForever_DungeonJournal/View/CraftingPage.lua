-- CraftingPage.lua: the Crafting page: its picks, then every recipe of the picked profession that fits them, with its skill and source.
local ns = _G.NaowhForever

local GetItemInfoInstant = C_Item.GetItemInfoInstant

local J = ns.Journal
local Crafting = J.Crafting
local ViewMixin = J.View.Mixin
local St = J.Style
local SECTION_SPACE, PLACE_DOT = St.SECTION_SPACE, St.PLACE_DOT

local INFO_EQUIP = 4
local MAX_SHOWN = 100
local SIDE_W, SIDE_GAP = 236, 18
local PROFESSIONS_ADDON = "NaowhForever_Professions"

local TEXT_TITLE = ns.L("Crafting")
local TEXT_RECIPES = ns.L("Recipes")
local TEXT_OFF = ns.L("Turn on Professions to browse every profession's recipes here.")
local TEXT_TURN_ON = ns.L("Turn On Professions")
local TEXT_NONE = ns.L("No recipes fit what you picked.")
local TEXT_FIRST = ns.L("The first %d of %d. Pick more to narrow it down.")
local TEXT_SKILL = ns.L("Skill %d")
local SOURCE_TAG = { trainer = ns.L("Trainer"), teacher = ns.L("Trainer"), vendor = ns.L("Vendor"), drop = ns.L("Drop"),
    quest = ns.L("Quest"), unknown = ns.L("Unknown") }

local function Where(entry)
    local where = entry.where
    if not where then
        local equip = entry.what == "gear" and select(INFO_EQUIP, GetItemInfoInstant(entry.item))
        local slot = equip and _G[equip]
        where = (slot and slot .. PLACE_DOT or "") .. TEXT_SKILL:format(entry.skill)
            .. PLACE_DOT .. (SOURCE_TAG[entry.source] or SOURCE_TAG.unknown)
        entry.where = where
    end
    return where
end

function ViewMixin:DrawRecipes(n)
    if n == 0 then self:Note(TEXT_NONE) end
    local found = self.found
    for i = 1, math.min(n, MAX_SHOWN) do
        local entry = found[i]
        local id = entry.item
        if id then
            self:Add("item", id, nil, self:ItemRank(id), self:ItemUpgrade(id), nil, Where(entry))
        else
            self:Add("ability", entry.spell, Where(entry))
        end
    end
    if n > MAX_SHOWN then self:Note(TEXT_FIRST:format(MAX_SHOWN, n)) end
end

function ViewMixin:DrawCraftingAside(groups)
    local width = self:GetWidth()
    local mainX, mainW = SIDE_W + SIDE_GAP, width - SIDE_W - SIDE_GAP
    self:Column(0, SIDE_W, 0)
    for _, group in ipairs(groups) do self:Add("finderPicks", group) end
    local sideBottom = self.cursor
    self:Column(mainX, mainW, 0)
    local n = Crafting.Collect(self.found)
    self:Section(TEXT_RECIPES, n)
    self:DrawRecipes(n)
    self:Column(0, width, math.max(sideBottom, self.cursor))
    self:Finish()
end

function ViewMixin:DrawCrafting()
    self:Begin()
    self.crafting, self.striped = true, true
    if not Crafting.Available() then
        self:NeedsModule(TEXT_TITLE, TEXT_OFF, PROFESSIONS_ADDON, TEXT_TURN_ON)
        return self:Finish()
    end
    local groups = Crafting.Groups()
    if self.finderAside then return self:DrawCraftingAside(groups) end
    self:Section(TEXT_TITLE)
    for _, group in ipairs(groups) do self:Add("finderPicks", group) end
    self:Space(SECTION_SPACE)
    local n = Crafting.Collect(self.found)
    self:Section(TEXT_RECIPES, n)
    self:DrawRecipes(n)
    self:Finish()
end
