-- Run with Lua 5.1 from the repository root: the Quest List's objective pins. Each unfinished objective of a
-- quest in your log is pinned where its sources are, matched to the game's objectives by its place among its
-- kind (items apart from kills); a finished one is not, and a done quest gets only its hand-in. A kill whose
-- place is not known stays pinned until every kill of its quest is done. Spots of two quests at one place
-- share a pin, and only the shown maps are read. Asked for, a creature's way adds dots of its own along it.
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local CREATURE, OBJECT = 1, 2
local WESTFALL, ELWYNN = 1436, 1429
local D = {
    HandIns = {
        [10] = { "Salma Saldean", WESTFALL, 56.4, 30.4 },
        [20] = { "Gryan Stoutmantle", WESTFALL, 56.2, 47.4 },
        [30] = { "Marshal Dughan", ELWYNN, 42.1, 65.9 },
    },
    Objectives = {
        [10] = {
            { 1, 1, { CREATURE, "Fleshripper", WESTFALL, 40, 40 } },
            { 2, 1, { CREATURE, "Murloc", WESTFALL, 30, 30 }, { OBJECT, "Crate", WESTFALL, 31, 31 } },
        },
        [20] = {
            { 2, 0, { CREATURE, "Defias Pathstalker", WESTFALL, 50, 70 } },
            { 1, 0, { CREATURE, "Defias Highwayman", WESTFALL, 45, 78, 40, 40 } },
        },
        [40] = { { 0, 0, { CREATURE, "Harvest Watcher", WESTFALL, 60, 60 } } },
        [50] = { { 0, 0, { CREATURE, "Gnoll", WESTFALL, 61, 61 } } },
        [30] = { { 1, 1, { CREATURE, "Kobold", ELWYNN, 60, 50 } } },
    },
}

local log, objectives, complete, failed, watched = {}, {}, {}, {}, {}
local ns = { L = dofile("Tools/regression/locale_stub.lua").L, CompletoQuestData = D,
    Shared = { Places = { SameMap = function(id) return id end } } }
local hidden = {}
ns.Completo = { Quests = { Hidden = function(id) return hidden[id] == true end } }
local env = setmetatable({
    _G = { NaowhForever = ns },
    C_QuestLog = {
        GetNumQuestLogEntries = function() return #log end,
        GetQuestIDForLogIndex = function(i) return log[i] end,
        GetQuestObjectives = function(id) return objectives[id] end,
        GetQuestWatchType = function(id) return watched[id] end,
        IsComplete = function(id) return complete[id] == true end,
        IsFailed = function(id) return failed[id] == true end,
    },
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
}, { __index = _G })
local chunk = assert(loadstring(Read("NaowhForever_Discovery/QuestList/Objectives.lua")))
setfenv(chunk, env)
chunk()
local O = ns.Completo.Objectives.List()

local function Names(spots)
    local seen = {}
    for _, spot in ipairs(spots) do
        for _, line in ipairs(spot.lines) do seen[line.source] = (seen[line.source] or 0) + 1 end
    end
    return seen
end

local function Item(text, finished) return { text = text, type = "item", finished = finished } end
local function Kill(text, finished) return { text = text, type = "monster", finished = finished } end

log = { 10 }
objectives[10] = { Kill("Talk to someone", false), Item("Vulture Meat: 0/3", false), Item("Murloc Eye: 3/3", true) }
local seen = Names(O:ForMaps({ WESTFALL }))
Check(seen["Fleshripper"] == 1, "the first item objective is the first item in the log, past a kill before it")
Check(seen["Murloc"] == nil and seen["Crate"] == nil, "a finished item objective has no pins, from any source")
local spot = O:ForMaps({ WESTFALL })[1]
Check(spot.lines[1].text == "Vulture Meat: 0/3" and spot.lines[1].item == true, "a pin knows its objective's text")
Check(spot.map == WESTFALL and spot.x == 40 and spot.y == 40 and not spot.handIn, "and where it is")

objectives[10] = { Item("Vulture Meat: 0/3", false), Item("Murloc Eye: 1/3", false) }
seen = Names(O:ForMaps({ WESTFALL }))
Check(seen["Murloc"] == 1 and seen["Crate"] == 1, "every source of an unfinished objective is pinned")
Check(#O:ForMaps({ ELWYNN }) == 0, "only the shown maps are read")

complete[10] = true
local spots = O:ForMaps({ WESTFALL })
Check(#spots == 1 and spots[1].handIn and spots[1].lines[1].source == "Salma Saldean",
    "a done quest has only its hand-in")
complete[10] = nil

log = { 20 }
objectives[20] = { Kill("Defias Highwayman slain: 15/15", true), Kill("Defias Pathstalker slain: 2/5", false) }
seen = Names(O:ForMaps({ WESTFALL }))
Check(seen["Defias Pathstalker"] == 1 and seen["Defias Highwayman"] == nil,
    "kills are matched by their place in the quest, not the data's order")

log = { 40 }
objectives[40] = { Kill("Harvest Watcher slain: 3/20", false) }
Check(Names(O:ForMaps({ WESTFALL }))["Harvest Watcher"] == 1, "a quest's only kill is its kill, place known or not")
objectives[40] = { Kill("Harvest Watcher slain: 20/20", true) }
Check(#O:ForMaps({ WESTFALL }) == 0, "and is put away once done")

log = { 50 }
objectives[50] = { Kill("Gnoll slain: 5/5", true), Kill("Gnoll Brute slain: 1/5", false) }
Check(Names(O:ForMaps({ WESTFALL }))["Gnoll"] == 1, "a kill whose place is not known stays while any kill is left")
objectives[50] = { Kill("Gnoll slain: 5/5", true), Kill("Gnoll Brute slain: 5/5", true) }
Check(#O:ForMaps({ WESTFALL }) == 0, "and goes once every kill is done")

log = { 10, 20 }
objectives[10] = { Item("Vulture Meat: 0/3", false), Item("Murloc Eye: 3/3", true) }
objectives[20] = { Kill("Defias Highwayman slain: 0/15", false), Kill("Defias Pathstalker slain: 5/5", true) }
local shared
for _, s in ipairs(O:ForMaps({ WESTFALL })) do
    if s.x == 40 and s.y == 40 then shared = s end
end
Check(shared and #shared.lines == 2 and shared.lines[1].quest ~= shared.lines[2].quest,
    "two quests' spots at one place share a pin")

watched[20] = 1
seen = Names(O:ForMaps({ WESTFALL }, true))
Check(seen["Fleshripper"] == nil and seen["Defias Highwayman"] == 2, "Tracked Quests Only leaves the others out")

hidden[20] = true
Check(Names(O:ForMaps({ WESTFALL }))["Defias Highwayman"] == nil, "a hidden quest has no pins")
hidden[20] = nil

failed[20] = true
Check(Names(O:ForMaps({ WESTFALL }))["Defias Highwayman"] == nil, "a failed quest has no pins")
failed[20] = nil

log = { 0, 30 }
objectives[30] = { Item("Candle: 0/8", false) }
Check(Names(O:ForMaps({ ELWYNN }))["Kobold"] == 1, "a log header is skipped")
log = { 99 }
Check(#O:ForMaps({ WESTFALL }) == 0, "a quest the data does not know has no pins")


log = { 30 }
objectives[30] = { Item("Candle: 0/8", false) }
local other = ns.Completo.Objectives.List()
local mine = O:ForMaps({ ELWYNN })
local first = mine[1]
other:ForMaps({ WESTFALL })
Check(mine[1] == first and first.lines[1].source == "Kobold", "each list keeps its own spots: another's redraw leaves them")

D.Paths = { [30] = { { 1, 1, "Kobold", ELWYNN, 60, 50, 62, 52 }, { 2, 1, "Kobold", ELWYNN, 70, 70, 71, 71 } } }
Check(#O:ForMaps({ ELWYNN }) == 1, "no way dots unless asked")
local dots = 0
for _, s in ipairs(O:ForMaps({ ELWYNN }, false, true)) do
    if s.path then
        dots = dots + 1
        Check(s.lines[1].source == "Kobold" and s.lines[1].place == 1 and s.lines[1].text == "Candle: 0/8",
            "a dot names its creature and objective")
    end
end
Check(dots == 2, "asked, the objective's way is dots of its own, one at the pin's spot too; another objective's are not")
objectives[30][1].finished = true
Check(#O:ForMaps({ ELWYNN }, false, true) == 0, "and they go once the objective is done")

-- The pins: off registers nothing and adds no map provider; on, a hand-in is the game's ?, an objective its
-- objective mark, at Objective Pin Size, and a click toggles a waypoint to the spot.
local settings = { enabled = true, mapObjectives = false, mapObjectivePinSize = 24 }
ns.Completo.Settings = { Get = function(key) return settings[key] end, Set = function() end }
ns.Completo.Style = { GOLD_RGB = { r = 1, g = 1, b = 0 }, Hint = function() return 1, 1, 1 end }
ns.Completo.C = { PERCENT = 100 }
ns.Completo.Party = { Progress = function() end }
ns.Shared.OpenMap = dofile("Tools/regression/shared_openmap.lua")
ns.Shared.ScalePin = function() end
ns.Shared.PinClicks = function() end
ns.Apply = function() end
function ns.OnApply(fn) local was = ns.Apply ns.Apply = function(...) was(...) fn(...) end end
local providers, frames, waypoint = 0, {}, nil
ns.ToggleWaypoint = function(title, mapID, x, y) waypoint = { title, mapID, x, y } end
local acquired = 0
local map = { IsShown = function() return true end, GetMapID = function() return WESTFALL end,
    AddDataProvider = function() providers = providers + 1 end, RemoveAllPinsByTemplate = function() end,
    AcquirePin = function() acquired = acquired + 1 end }
env.WorldMapFrame = map
env.CreateFromMixins = function() return { GetMap = function() return map end } end
env.MapCanvasPinMixin, env.MapCanvasDataProviderMixin = {}, {}
env.hooksecurefunc = function() end
env.CreateFrame = function()
    local f = { events = {} }
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterAllEvents() self.events = {} end
    function f:SetScript(name, fn) self[name] = fn end
    frames[#frames + 1] = f
    return f
end
local ui = assert(loadstring(Read("NaowhForever_Discovery/QuestList/UI/ObjectivePins.lua")))
setfenv(ui, env)
ui()
frames[1].OnEvent(frames[1])
Check(providers == 0 and #frames == 1, "off: no map provider and no event frame")
log = { 10, 30 }
settings.mapObjectives = true
ns.Apply()
Check(providers == 1 and frames[2].events.QUEST_LOG_UPDATE, "on: the provider is added and follows the quest log")
Check(acquired == 1, "and pins the shown map's spots only: the Elwynn quest's are left out")
settings.mapObjectives = false
ns.Apply()
Check(next(frames[2].events) == nil, "turned off again, it listens to nothing")

local Pin = env.NaowhForeverQuestObjectivePinMixin
local function Placed(entry)
    local pin = setmetatable({ Icon = { SetAtlas = function(self, atlas) self.atlas = atlas end,
        SetAlpha = function(self, alpha) self.alpha = alpha end } }, { __index = Pin })
    function pin:SetSize(w) self.size = w end
    function pin:SetPosition() end
    function pin:UseFrameLevelType(level) self.level = level end
    pin:OnAcquired(entry, 0.5, 0.5)
    return pin
end
local hand = Placed({ map = WESTFALL, x = 56.2, y = 47.4, handIn = true, lines = { { source = "Gryan" } } })
Check(hand.Icon.atlas == "questturnin" and hand.size == 24, "a hand-in is the game's ?, at Objective Pin Size")
local drop = Placed({ map = WESTFALL, x = 40, y = 40, lines = { { source = "Murloc", item = true, kind = 1 } } })
Check(drop.Icon.atlas == "questobjective", "an objective is the game's objective mark")
drop:OnClick("LeftButton")
Check(waypoint[2] == WESTFALL and waypoint[3] == 40 and waypoint[4] == 40, "a click is a waypoint to the spot")
Check(waypoint[1] == ("Dropped by %s"):format("Murloc"), "named for what drops the item")
local dot = Placed({ map = WESTFALL, x = 41, y = 41, path = true, lines = { { source = "Murloc", item = true, kind = 1 } } })
Check(dot.size < 24 and dot.Icon.alpha < 1 and drop.Icon.alpha == 1, "a way's dot is smaller and fainter than a pin")
Check(dot.level ~= drop.level, "and lies below the pins, so a pin under a dot keeps its hover")

print(("test-completo-objective-pins: %d checks passed"):format(checks))
