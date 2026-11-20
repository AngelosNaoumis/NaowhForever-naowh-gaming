-- Run with Lua 5.1 from the repository root: Crafting Profit and the rows under it stay off, saying
-- "Turn on Quality of Life", while that module's Auction Prices are not loaded.
local checks = 0
local function Check(label, value) assert(value, label); checks = checks + 1 end

local function Noop() end
local settings = { enabled = true, craftProfit = true, craftProfitList = true, craftROI = true }
local cards = {}
local ns = {
    L = function(text) return text end,
    GamepadWhy = Noop,
    GamepadStandDown = function() return false end,
    Professions = {
        Settings = { Get = function(key) return settings[key] end },
        NodeScan = { Usable = function() return false end },
    },
    Shared = {
        Style = { HUD_TEXT_RANGE = { 8, 24, 1 } },
        Settings = {
            Group = function() return {} end,
            Look = function() return {} end,
            Page = function() return { Card = function(_, card) cards[card.id] = card end, Window = Noop } end,
        },
    },
}
_G.NaowhForever = ns
dofile("NaowhForever_Professions/UI/SettingsPage.lua")

local rows = {}
for _, row in ipairs(cards.buying.rows) do
    if row.key then rows[row.key] = row end
end
local profit, list, roi = rows.craftProfit, rows.craftProfitList, rows.craftROI

Check("without Quality of Life, Crafting Profit is off", not profit.needs())
Check("and says to turn on Quality of Life", profit.why() == "Turn on Quality of Life")
Check("Profit in Recipe List is off too, though saved on", not list.needs())
Check("and so is Show ROI", not roi.needs())

ns.AuctionPrice = Noop
Check("with Quality of Life, Crafting Profit can be turned on", profit.needs())
Check("and the rows under it follow it", list.needs() and roi.needs())

settings.enabled = false
Check("with Professions off, Crafting Profit says to turn on Professions",
    not profit.needs() and profit.why() == "Turn on Professions")

print(("test-profession-profit-needs-qol: %d checks passed"):format(checks))
