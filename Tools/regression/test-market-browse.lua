-- Run with Lua 5.1 from the repository root: the full window's own auction house search, beside Buy and Shopping List.
-- A name and Enter, or a category from the menu (never the WoW Token's), runs the search through Searches; nothing is
-- sent for an empty name in All Categories. What the auction house finds lists cheapest first, grows as you scroll
-- near the end, and a row picked asks for its listings, once the game knows whether it is a commodity. Its listings
-- are Sell's, with Buy on them but no price to take and no "Your price" mark; a purchase there is passed back to the
-- page that showed it, with whose list it was for. Put away, it stops listening and asks again on its next showing.
-- However many it finds, only the rows in view are built, and a frame's worth of item names draws it once.
-- A price scan's pages are not a search of yours: they clear the list and stay out of it.
local Page = dofile("Tools/regression/market_sell_page.lua")
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local LINEN, POLE, SILK, NEW = 2589, 6256, 4306, 7777
local function Category(name, subs, token)
    return { name = name, subCategories = subs, HasFlag = function(_, flag) return token and flag == "WOW_TOKEN_FLAG" end }
end
local t = Page.Setup({ categories = { Category("Trade Goods", { Category("Herbs"), Category("Cloth") }),
    Category("WoW Token", nil, true) },
    keyInfo = { [LINEN] = { itemName = "Linen Cloth", quality = 1, isCommodity = true, iconFileID = 11 },
        [POLE] = { itemName = "Fishing Pole", quality = 1, isCommodity = false, iconFileID = 12 },
        [SILK] = { itemName = "Silk Cloth", quality = 1, isCommodity = true } } })
local env, ns, M = t.env, t.ns, t.M

local ran, search, picker = {}, nil, nil
M.Searches = { Run = function(s) ran[#ran + 1] = s end }
local sortedBy = "lowest"
M.Columns = {
    New = function() return {} end,
    Current = function() return sortedBy end,
    Add = function() end,
    Sort = function(_, list) table.sort(list, function(a, b) return a.minPrice < b.minPrice end) end,
}
ns.Lower = string.lower
ns.UI.BuildDropdownControl = function(parent, _, _, values, _, get)
    picker = t.Frame("Button", parent)
    picker._refreshLabel = function() picker.label = values[get()] end
    return picker
end
ns.Shared.Parts.SearchBox = function(parent)
    search = t.Frame("EditBox", parent)
    return search
end
local fonts = {}
local font = ns.Font
ns.Font = function(...)
    local f = font(...)
    fonts[#fonts + 1] = f
    return f
end
local VIEW_H = 280
local scrolls = {}
local slim = ns.UI.SlimScroll
ns.UI.SlimScroll = function(...)
    local f = slim(...)
    f.height, f.at = VIEW_H, 0
    function f:GetVerticalScroll() return self.at end
    function f:SetVerticalScroll(at) self.at = at end
    scrolls[#scrolls + 1] = f
    return f
end
env.ITEM_QUALITY_COLORS = { [1] = { r = 1, g = 1, b = 1 } }
env.C_AuctionHouse.GetItemKeySampleLink = function() end
env.C_AuctionHouse.GetItemKeyRequiredLevel = function() return 0 end
Load({ "NaowhForever_Market/Results.lua", "NaowhForever_Market/View/Browse.lua" }, env)
local Browse = M.Browse

local bought = {}
local page = t.Frame("Frame")
local column = t.Frame("Frame", page)
Browse.Attach(page, column, function(entry, count) bought[#bought + 1] = { entry = entry, count = count } end)
check("shown, it listens for what the auction house finds and for item names", t.Listening(
    "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED") and t.Listening("ITEM_KEY_ITEM_INFO_RECEIVED")
    and t.Listening("COMMODITY_SEARCH_RESULTS_UPDATED"))

local function Notes()
    local found = {}
    for _, f in ipairs(fonts) do
        if f.shown and f.text then found[f.text] = true end
    end
    return found
end
check("before a search it says how to search", Notes()["Type a name and press Enter, or pick a category."])
local chart = t.charts[#t.charts]
check("with nothing picked there is no price chart", chart and not chart.shown)

search.scripts.OnEnterPressed(search)
check("an empty name in All Categories sends nothing", #ran == 0)
search.text = "linen"
search.scripts.OnEnterPressed(search)
check("a name and Enter runs it through Searches", #ran == 1 and ran[1].text == "linen" and ran[1].cat == nil)
check("and says it is searching", Notes()["Searching"])

local items = {}
local menu = {}
function menu.CreateRadio(_, text, _, onPick, key)
    items[#items + 1] = { text = text, key = key, pick = function() onPick(key) end }
end
function menu.CreateButton(_, text)
    items[#items + 1] = { text = text, sub = true }
    return menu
end
function menu.CreateDivider() end
check("the category menu starts on All Categories", picker.label == "All Categories")
picker._menuFill(menu)
local herbs, token
for _, item in ipairs(items) do
    if item.text == "Herbs" then herbs = item end
    if item.text == "WoW Token" then token = item end
end
check("it offers the auction house's categories, not the WoW Token", herbs and not token)
herbs.pick()
check("a category picked runs the search in it", #ran == 2 and ran[2].text == "linen" and ran[2].cat[1] == 1
    and ran[2].cat[2] == 1 and #ran[2].cat == 2)
check("and names it on the menu", picker.label == "Trade Goods / Herbs")

local function Key(id) return env.C_AuctionHouse.MakeItemKey(id) end
t.browse = { { itemKey = Key(LINEN), minPrice = 50, totalQuantity = 200 },
    { itemKey = Key(POLE), minPrice = 30, totalQuantity = 1 } }
t.Fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
local function Rows()
    local found = {}
    for _, f in ipairs(t.frames) do
        if f.shown and rawget(f, "itemKey") and rawget(f, "lowest") then found[#found + 1] = f end
    end
    table.sort(found, function(a, b) return a.y < b.y end)
    return found
end
local rows = Rows()
check("what it finds lists cheapest first", #rows == 2 and rows[1].itemKey.itemID == POLE
    and rows[2].itemKey.itemID == LINEN)
check("by name, lowest price and how many are listed", rows[2].name.text == "Linen Cloth" and rows[2].lowest.text == "50"
    and rows[2].listed.text == "200")
check("and the hint goes", not Notes()["Searching"])

local scroll
for _, f in ipairs(scrolls) do
    if f.scripts.OnVerticalScroll then scroll = f end
end
function scroll.GetVerticalScrollRange() return 0 end
t.full = false
scroll.scripts.OnVerticalScroll(scroll, 0)
scroll.scripts.OnVerticalScroll(scroll, 0)
check("scrolled near the end, it asks once for more", t.more == 1)
t.Fire("AUCTION_HOUSE_BROWSE_RESULTS_ADDED", { { itemKey = Key(SILK), minPrice = 10, totalQuantity = 5 } })
rows = Rows()
check("which joins the list", #rows == 3 and rows[1].itemKey.itemID == SILK)
scroll.scripts.OnVerticalScroll(scroll, 0)
check("and it may ask again", t.more == 2)
t.full = true

local searches = #t.searches
rows[3].scripts.OnClick(rows[3])
check("a row picked asks for its listings, as a commodity", #t.searches == searches + 1
    and t.searches[#t.searches].key.itemID == LINEN)
check("and is marked", Rows()[3].picked.shown and not Rows()[1].picked.shown)
check("and its price chart shows beside its listings", chart.shown and chart.item == LINEN)
t.results.commodity[LINEN] = { { unitPrice = 40, quantity = 3, numOwnerItems = 0 },
    { unitPrice = 45, quantity = 10, numOwnerItems = 0 } }
t.Fire("COMMODITY_SEARCH_RESULTS_UPDATED", LINEN)
local lines = t.Lines()
check("its listings show under the list", #lines == 2 and lines[1].price.text == "40")
local mark
for _, f in ipairs(fonts) do
    if f.text == "Your price" then mark = f.parent end
end
check("with no Your price mark, as there is no price of yours", mark and not mark.shown)
t.Hover(lines[1])
check("hovered, a listing offers Buy but no price to take", lines[1].buy and lines[1].buy.shown
    and t.tips[1] ~= "Click to take this price.")
lines[1].scripts.OnClick(lines[1], "LeftButton")
check("and a click on it takes nothing", #t.purchases == 0)

lines[1].buy.click()
check("Buy on the cheapest asks how many, up to what is listed there, starting at one", #t.prompts == 1
    and t.prompts[1].title == "Buy how many? Up to 3, cheapest first." and t.prompts[1].text == "1")
t.prompts[1].accept("3")
check("then asks the game for the price", #t.purchases == 1 and t.purchases[1].step == "start"
    and t.purchases[1].quantity == 3 and t.purchases[1].unitPrice == 40)
t.Fire("COMMODITY_PRICE_UPDATED", 40, 120)
check("and asks before it buys", #t.confirms > 0)
t.confirms[#t.confirms].yes()
t.Fire("COMMODITY_PURCHASE_SUCCEEDED")
check("bought, the page that showed it hears what and how many", #bought == 1 and bought[1].entry.itemID == LINEN
    and bought[1].entry.commodity and bought[1].count == 3 and bought[1].entry.owner == nil)

Browse.PickItem(LINEN, "Player-2", "Zed")
check("picked for an alt's list, a purchase says whose", (function()
    t.results.commodity[LINEN] = { { unitPrice = 40, quantity = 1, numOwnerItems = 0 } }
    t.Fire("COMMODITY_SEARCH_RESULTS_UPDATED", LINEN)
    lines = t.Lines()
    t.Hover(lines[1])
    lines[1].buy.click()
    t.Fire("COMMODITY_PRICE_UPDATED", 40, 40)
    t.confirms[#t.confirms].yes()
    t.Fire("COMMODITY_PURCHASE_SUCCEEDED")
    return #bought == 2 and bought[2].entry.owner == "Player-2" and bought[2].entry.who == "Zed"
end)())

searches = #t.searches
Browse.PickItem(NEW)
check("an item the game has not named yet waits before it asks", #t.searches == searches)
t.keyInfo[NEW] = { itemName = "New Sword", quality = 1, isCommodity = false }
t.Fire("ITEM_KEY_ITEM_INFO_RECEIVED", NEW)
check("then asks for its listings by its key, as an item", #t.searches == searches + 1
    and t.searches[#t.searches].key.itemID == NEW)

local many = {}
for i = 1, 3000 do many[i] = { itemKey = Key(LINEN), minPrice = i, totalQuantity = 1 } end
t.browse = many
local built = #t.frames
t.Fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
rows = Rows()
check("thousands found build only the rows in view", #rows == 11 and #t.frames - built < 100
    and rows[1].lowest.text == "1" and rows[1].y == 0)
scroll.at = 28 * 2000
scroll.scripts.OnVerticalScroll(scroll, scroll.at)
rows = Rows()
check("and scrolled, the same rows show what is there", #rows == 11 and rows[1].lowest.text == "2001"
    and rows[1].y == 28 * 2000 and #t.frames - built < 100)
local sorts = 0
local sort = M.Columns.Sort
M.Columns.Sort = function(...)
    sorts = sorts + 1
    return sort(...)
end
t.RunTimers()
sorts = 0
t.keyInfo[LINEN].itemName = "Linen"
for _ = 1, 500 do t.Fire("ITEM_KEY_ITEM_INFO_RECEIVED", LINEN) end
check("item names wait for the next frame", #t.timers == 1 and Rows()[1].name.text == "Linen Cloth")
t.RunTimers()
check("then name the rows in view, with no sorting by price", sorts == 0 and Rows()[1].name.text == "Linen")
sortedBy = "item"
for _ = 1, 500 do t.Fire("ITEM_KEY_ITEM_INFO_RECEIVED", LINEN) end
t.RunTimers()
check("sorted by name, a frame's worth of them sorts the list once", sorts == 1)
sortedBy = "lowest"
M.Columns.Sort = sort

local scan = true
ns.AuctionScanBrowsed = function() return scan end
t.Fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
check("a price scan's first page clears the list back to the hint", #Rows() == 0
    and Notes()["Type a name and press Enter, or pick a category."])
t.Fire("AUCTION_HOUSE_BROWSE_RESULTS_ADDED", { { itemKey = Key(SILK), minPrice = 10, totalQuantity = 5 } })
t.more, t.full = 0, false
scroll.scripts.OnVerticalScroll(scroll, 0)
check("its later pages stay out, and scrolling asks for no more of it", #Rows() == 0 and t.more == 0)
t.full = true
search.text = "silk"
search.scripts.OnEnterPressed(search)
t.Fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
check("a search of yours a scan replaces stops saying it is searching", not Notes()["Searching"])
scan = false
scroll.at = 0
t.browse = { { itemKey = Key(POLE), minPrice = 30, totalQuantity = 1 } }
t.Fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
check("and the next search of yours lists again", #Rows() == 1)

Browse.Detach()
check("put away, it stops listening", not t.Listening("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
    and not t.Listening("ITEM_KEY_ITEM_INFO_RECEIVED") and not t.Listening("COMMODITY_SEARCH_RESULTS_UPDATED"))
searches = #t.searches
Browse.Attach(page, column)
check("and shown again, asks again for what was picked", #t.searches == searches + 1
    and t.searches[#t.searches].key.itemID == NEW)

print(("market browse: %d checks passed"):format(checks))
