-- Run with Lua 5.1 from the repository root: Minimap Node Tooltips (NodeScan.lua, UI/NodeTooltip.lua).
-- Hovering a herb or vein on the minimap adds the skill it needs to the game's tooltip: red below it, then
-- in its skill-up colour, a gear bonus counting. The tooltip's text is a secret value, so the node is found
-- by where the cursor is: the herb and vein spawn under it in Glimmer's spot list, as Glimmer's minimap
-- pins place them, only the kinds being tracked. Ores sharing a spawn each get a named line. It never
-- drives the minimap's soft cursor, as Forever stopped answering a probe away from the real cursor. Without
-- Quality of Life it adds nothing. Switched off it adds nothing and listens to nothing, and on a client
-- whose node names are not English it stays off. The data table matches Glimmer's herbs and veins, name
-- for name and skill for skill.
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Noop() end
local locale = "enUS"
local tooltipHook, setHook, boot
local hooks, softCursorCalls = 0, 0
local frames = {}
local clock = 0

local frameMethods = {
    SetScript = function(f, name, fn) f[name] = fn end,
    RegisterEvent = function(f, event)
        f.events[event] = true
        if event == "PLAYER_LOGIN" then boot = f end
    end,
    UnregisterAllEvents = function(f) f.events = {} end,
}
local frameMeta = { __index = function(_, k) return frameMethods[k] or Noop end }

local function CreateFrame()
    local f = setmetatable({ events = {} }, frameMeta)
    frames[#frames + 1] = f
    return f
end

local world = { x = 500, y = 500, cont = 0, radius = 100, rotate = false, facing = 0 }
local cursor = { x = 100, y = 100 }
local Minimap = {
    GetWidth = function() return 200 end,
    GetHeight = function() return 200 end,
    GetCenter = function() return 100, 100 end,
    GetEffectiveScale = function() return 1 end,
    SetUsingSoftCursor = function() softCursorCalls = softCursorCalls + 1 end,
    UpdateMouseoverAtPoint = function() softCursorCalls = softCursorCalls + 1 end,
}

local function Vector(x, y) return { GetXY = function() return x, y end } end

local tracking = { herb = true, ore = true }
local TRACK_SPELL = { 2383, 2580 }
local TRACK_KIND = { "herb", "ore" }

local profession = { herb = nil, ore = 50, oreBonus = 0 }
local settings = { enabled = true, nodeIcons = true }
local RED = { r = 1, g = 0.3, b = 0.3 }
local ORANGE, YELLOW = { r = 1, g = 0.5, b = 0.25 }, { r = 1, g = 1, b = 0 }

local glimmer = {
    C = { SPOT_SCALE = 1000 },
    NODES = {
        [1618] = { "herb", 1, "Peacebloom" },
        [1731] = { "ore", 1, "Copper Vein" },
        [1732] = { "ore", 65, "Tin Vein" },
        [1733] = { "ore", 75, "Silver Vein" },
        [1734] = { "ore", 155, "Gold Vein" },
        [1735] = { "ore", 125, "Iron Deposit" },
        [2843] = { "chest", 0, "Battered Chest" },
    },
    Spots = { Load = function() return true end },
}
local spots = {
    [1] = {
        1732, 520, 500,
        1731, 500, 470,
        1733, 460, 500, 1734, 460, 500,
        1735, 460, 500,
        1618, 500, 540,
        2843, 530, 530,
        1732, 900, 900,
    },
}

local ns = {
    L = dofile("Tools/regression/locale_stub.lua").L,
    Apply = Noop,
    Shared = { Places = { SameMap = function(mapID) return mapID end } },
    Professions = {
        Settings = { Get = function(k) return settings[k] end, Set = Noop },
        Style = {
            RED_RGB = RED,
            DIFFICULTY_RGB = { [0] = ORANGE, [1] = YELLOW, [2] = { r = 0.25, g = 0.75, b = 0.25 },
                [3] = { r = 0.55, g = 0.55, b = 0.55 } },
        },
    },
}
function ns.OnApply(fn) local was = ns.Apply ns.Apply = function(...) was(...) fn(...) end end

local env = setmetatable({
    NaowhForever = ns,
    Minimap = Minimap,
    CreateFrame = CreateFrame,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    issecretvalue = function() return false end,
    GetLocale = function() return locale end,
    GetTime = function() clock = clock + 1; return clock end,
    GetCursorPosition = function() return cursor.x, cursor.y end,
    GetPlayerFacing = function() return world.facing end,
    UnitPosition = function() return world.x, world.y, 0, world.cont end,
    CreateVector2D = Vector,
    C_Map = {
        GetBestMapForUnit = function() return 1 end,
        GetWorldPosFromMapPos = function(_, v)
            local x, y = v.GetXY()
            return 0, Vector(x * 1000, y * 1000)
        end,
        GetMapWorldSize = function() return 1000, 1000 end,
    },
    C_Minimap = {
        GetViewRadius = function() return world.radius end,
        GetNumTrackingTypes = function() return #TRACK_SPELL end,
        GetTrackingInfo = function(i) return { spellID = TRACK_SPELL[i], active = tracking[TRACK_KIND[i]] } end,
    },
    C_CVar = { GetCVarBool = function() return world.rotate end },
    GetProfessions = function() return profession.ore and 1 or nil, profession.herb and 2 or nil end,
    GetProfessionInfo = function(index)
        if index == 1 then return "Mining", nil, profession.ore, 300, nil, nil, 186, profession.oreBonus end
        return "Herbalism", nil, profession.herb, 300, nil, nil, 182, 0
    end,
    Enum = { TooltipDataType = { MinimapMouseover = 22 } },
    TooltipDataProcessor = { AddTooltipPostCall = function(_, fn)
        hooks = hooks + 1
        tooltipHook = fn
    end },
    hooksecurefunc = function(target, name, fn)
        if target == ns.Professions.Settings and name == "Set" then setHook = fn end
    end,
}, { __index = _G })
env._G = env

Load({
    "NaowhForever_Professions/Constants.lua",
    "NaowhForever_Professions/Data/GatherNodes.lua",
    "NaowhForever_Professions/NodeScan.lua",
    "NaowhForever_Professions/UI/NodeTooltip.lua",
}, env)

local function Events()
    for _, f in ipairs(frames) do
        if f ~= boot and f.events.SKILL_LINES_CHANGED then return f end
    end
end

boot.OnEvent(boot, "PLAYER_LOGIN")
local events = Events()
check("logging in with it on hooks the minimap tooltip", tooltipHook ~= nil and hooks == 1)
check("and listens for skill changes", events ~= nil and events.events.PLAYER_ENTERING_WORLD == true)

local tooltip = { added = {}, shown = 0 }
function tooltip.AddLine(self, text, r, g, b) self.added[#self.added + 1] = { text = text, r = r, g = g, b = b } end
function tooltip.Show(self) self.shown = self.shown + 1 end
env.GameTooltip = tooltip

local function Hover(east, north)
    cursor.x, cursor.y = 100 + east, 100 + north
    tooltip.added, tooltip.shown = {}, 0
    tooltipHook(tooltip, { lines = { { leftText = "<secret>" } } })
    return tooltip.added
end

local function Is(line, c) return line ~= nil and line.r == c.r and line.g == c.g and line.b == c.b end

ns.Glimmer, ns.GlimmerSpots = glimmer, spots

local added = Hover(20, 0)
check("hovering Tin Vein says the Mining it needs", added[1] and added[1].text == "Requires Mining 65")
check("in red, as Mining 50 is too low", Is(added[1], RED))
check("and the tooltip is redrawn to fit it", tooltip.shown == 1)
check("a few pixels off still finds it", (Hover(24, 3)[1] or {}).text == "Requires Mining 65")

added = Hover(0, 30)
check("north on the minimap is north on the map: Copper Vein", added[1] and added[1].text == "Requires Mining 1")
check("Copper Vein (1) at Mining 50 is yellow", Is(added[1], YELLOW))

profession.oreBonus = 20
events.OnEvent(events, "SKILL_LINES_CHANGED")
check("a Mining bonus counts: Tin Vein (65) is orange at 50 plus 20", Is(Hover(20, 0)[1], ORANGE))
profession.oreBonus = 0
events.OnEvent(events, "SKILL_LINES_CHANGED")

added = Hover(-40, 0)
check("ores sharing a spawn each name their own need", #added == 3
    and added[1].text == "Silver Vein: Requires Mining 75"
    and added[2].text == "Gold Vein: Requires Mining 155"
    and added[3].text == "Iron Deposit: Requires Mining 125")

added = Hover(0, -40)
check("Peacebloom says the Herbalism it needs", #added == 1 and added[1].text == "Requires Herbalism 1")
check("in red with no Herbalism", Is(added[1], RED))
tracking.herb = false
check("not tracking herbs, a herb spawn names nothing", #Hover(0, -40) == 0)
check("while veins still do", #Hover(20, 0) == 1)
tracking.herb = true

check("a chest spawn names nothing", #Hover(30, -30) == 0)
check("an empty spot of the minimap adds nothing", #Hover(-10, 60) == 0 and tooltip.shown == 0)

world.rotate, world.facing = true, math.pi / 2
added = Hover(0, -20)
check("a rotating minimap turns with the player: Tin Vein, facing west, is below", #added == 1
    and added[1].text == "Requires Mining 65")
world.rotate, world.facing = false, 0

world.radius = 50
check("zoomed in, Tin Vein is twice as far from the centre", (Hover(40, 0)[1] or {}).text == "Requires Mining 65")
world.radius = 100

world.cont = 1
check("on another continent than the zone's map nothing is named", #Hover(20, 0) == 0)
world.cont = 0
check("it never drives the minimap's soft cursor", softCursorCalls == 0)

ns.Glimmer, ns.GlimmerSpots = nil, nil
check("without Quality of Life's spots nothing is named, without an error", #Hover(20, 0) == 0)
ns.Glimmer, ns.GlimmerSpots = glimmer, spots

settings.nodeIcons = false
setHook("nodeIcons")
check("turning it off stops every event", next(events.events) == nil)
check("and the tooltip line", #Hover(20, 0) == 0)
settings.nodeIcons = true
setHook("nodeIcons")
check("turning it on again listens again", events.events.SKILL_LINES_CHANGED == true)
check("without hooking the tooltip twice", hooks == 1)
check("and the line is back", #Hover(20, 0) == 1)

settings.enabled = false
setHook("enabled")
check("Professions off: no events", next(events.events) == nil)
check("and no tooltip line", #Hover(20, 0) == 0)
settings.enabled = true
setHook("enabled")

locale = "deDE"
tooltipHook = nil
local built = #frames
Load({ "NaowhForever_Professions/NodeScan.lua", "NaowhForever_Professions/UI/NodeTooltip.lua" }, env)
boot.OnEvent(boot, "PLAYER_LOGIN")
check("a German client cannot read the English node names", ns.Professions.NodeScan.Usable() == false)
check("so even switched on it hooks nothing", tooltipHook == nil)
check("and builds nothing past its login frame", #frames == built + 1)
locale = "enGB"
check("a British client reads them", ns.Professions.NodeScan.Usable() == true)

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"); f:close()
    return s
end

local nodes = ns.Professions.GatherNodes
for name, node in pairs(nodes) do
    check(name .. " is a herb or vein", node[1] == "herb" or node[1] == "ore")
    check(name .. " needs a skill", type(node[2]) == "number" and node[2] >= 1)
    check(name .. " has an item or none", node[3] == nil or type(node[3]) == "number")
end
local glimmerNodes = Read("NaowhForever_QoL/Glimmer/Data/Nodes.lua")
local listed = 0
for kind, need, name in glimmerNodes:gmatch('{ "(%a+)", (%d+), "([^"]+)" }') do
    if kind == "herb" or kind == "ore" then
        listed = listed + 1
        check(name .. " from Glimmer is in GatherNodes", nodes[name] ~= nil)
        check(name .. " needs the same skill as in Glimmer", nodes[name][2] == tonumber(need)
            and nodes[name][1] == kind)
    end
end
check("Glimmer's herbs and veins were read", listed > 50)
check("Glimmer's spots are scaled as the tooltip reads them",
    Read("NaowhForever_QoL/Glimmer/Constants.lua"):find("SPOT_SCALE = 1000,", 1, true) ~= nil)

local features = Read("Core/Features.lua")
check("Minimap Node Tooltips is off by default", features:find("\n%s*nodeIcons = false,") ~= nil)

print(("test-node-tooltip: %d checks passed"):format(checks))
