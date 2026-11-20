-- Run with Lua 5.1 from the repository root: the Quest List's holiday quests. The holidays on now are read from
-- the game's calendar for today, whatever month the calendar shows, and one starting or ending today is on only
-- after it starts and until it ends. A holiday's quest is "Only during its holiday" and has no ! while its holiday
-- is off, and counts toward no zone; the Darkmoon Faire's quest givers stand where the Faire on now is. Then the
-- shipped data's holidays.
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local HALLOWS_END, FAIRE_ELWYNN, FAIRE_MULGORE, LUNAR = 324, 263, 264, 327
local ELWYNN, MULGORE = 1429, 1412

local now = { year = 2026, month = 10, monthDay = 20, hour = 12, minute = 0 }
local shown = { year = 2026, month = 10 }
local days, asked, opens, lockdown = {}, {}, 0, false
local function Time(hour, minute) return { hour = hour, minute = minute } end
local function Holiday(id, sequence, start, finish)
    return { eventID = id, calendarType = "HOLIDAY", sequenceType = sequence, startTime = start or Time(0, 0),
        endTime = finish or Time(23, 59) }
end

local ns = { AccountSettings = function() return {} end, Completo = { CharKey = function() return "Me-Realm" end },
    Shared = { Places = dofile("Tools/regression/shared_places.lua") } }
local env = setmetatable({
    _G = { NaowhForever = ns },
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    C_DateAndTime = { GetCurrentCalendarTime = function() return now end },
    C_ChatInfo = { InChatMessagingLockdown = function() return lockdown end },
    C_Calendar = {
        OpenCalendar = function() opens = opens + 1 end,
        GetMonthInfo = function() return shown end,
        GetNumDayEvents = function(offset, day) asked[#asked + 1] = { offset, day }; return #days end,
        GetDayEvent = function(_, _, i) return days[i] end,
    },
    UnitFactionGroup = function() return "Alliance" end,
    UnitRace = function() return "Human", "Human", 1 end,
    UnitClass = function() return "Warrior", "WARRIOR", 1 end,
    UnitLevel = function() return 30 end,
    GetProfessions = function() end,
    C_SpellBook = { IsSpellKnown = function() return false end },
    C_Reputation = { GetFactionDataByID = function() end },
    C_QuestLog = {
        GetAllCompletedQuestIDs = function() return {} end,
        GetLogIndexForQuestID = function() return nil end,
        GetNumQuestLogEntries = function() return 0 end,
    },
}, { __index = _G })

local holidays = assert(loadstring(Read("NaowhForever_Discovery/QuestList/Holidays.lua")))
setfenv(holidays, env)
holidays()
local H = ns.Completo.Holidays

days = { Holiday(HALLOWS_END, "ONGOING"), { eventID = 9, calendarType = "GUILD_EVENT" } }
H.Read()
Check(H.On(HALLOWS_END) and not H.On(9), "a holiday on today is on; a guild event is no holiday")
Check(opens == 1 and asked[1][1] == 0 and asked[1][2] == 20, "the calendar is opened once, and today is read")
H.Read()
Check(opens == 1, "and not opened again")

shown = { year = 2026, month = 11 }
H.Read()
Check(asked[#asked][1] == -1, "a calendar showing next month still reads today")
shown = { year = 2027, month = 1 }
H.Read()
Check(asked[#asked][1] == -3, "across a year too")
shown = { year = 2026, month = 10 }

days = { Holiday(HALLOWS_END, "START", Time(13, 0)) }
H.Read()
Check(not H.On(HALLOWS_END), "a holiday starting at one is not on at noon")
now.hour = 14
H.Read()
Check(H.On(HALLOWS_END), "and is at two")
days = { Holiday(HALLOWS_END, "END", nil, Time(13, 0)) }
H.Read()
Check(not H.On(HALLOWS_END), "one ending at one is off at two")
days = { Holiday(FAIRE_MULGORE, "", Time(10, 0), Time(18, 0)) }
H.Read()
Check(H.On(FAIRE_MULGORE), "a holiday of one day is on between its start and end")
lockdown, days = true, {}
H.Read()
Check(H.On(FAIRE_MULGORE), "in chat lockdown the calendar is not read and the last holidays stay on")
lockdown, days = false, { Holiday(FAIRE_MULGORE, "", Time(10, 0), Time(18, 0)) }
now.hour = 20
H.Read()
Check(not H.On(FAIRE_MULGORE), "and off after its end")
now.hour = 12

local function Quest(name, map, x, y) return { name, 20, 1, 3, 0, 0, map, x, y, "Giver" } end
ns.CompletoQuestData = {
    Zones = { { map = ELWYNN, name = "Elwynn Forest", quests = { 1, 2, 3 } } },
    Quests = { [1] = Quest("Kobold Camp Cleanup", ELWYNN, 40, 50), [2] = Quest("Hallow's End Treats", ELWYNN, 42, 66),
        [3] = Quest("Carnival Boots", ELWYNN, 43.4, 70.6) },
    Repeatable = {}, Dungeon = {}, Requires = {}, Chains = {},
    Events = { [2] = { HALLOWS_END }, [3] = { FAIRE_ELWYNN, FAIRE_MULGORE } },
    Holidays = { [HALLOWS_END] = "Hallow's End", [FAIRE_ELWYNN] = "Darkmoon Faire", [FAIRE_MULGORE] = "Darkmoon Faire" },
    FaireSpots = { [3] = { [FAIRE_ELWYNN] = { ELWYNN, 43.4, 70.6 }, [FAIRE_MULGORE] = { MULGORE, 36.2, 35.2 } } },
}
local quests = assert(loadstring(Read("NaowhForever_Discovery/QuestList/Quests.lua")))
setfenv(quests, env)
quests()
local Q = ns.Completo.Quests

local function Pinned(mapID)
    local seen = {}
    for _, giver in ipairs(Q.Givers(mapID, true, false)) do
        for _, id in ipairs(giver.quests) do seen[id] = { giver.x, giver.y } end
    end
    return seen
end

days = {}
Q.Refresh()
local seen = Pinned(ELWYNN)
Check(Q.State(2) == "event" and Q.State(3) == "event" and Q.State(1) == "open", "off season: only during its holiday")
Check(seen[1] and not seen[2] and not seen[3], "and no ! for it")
local n, total = Q.ZoneProgress(ns.CompletoQuestData.Zones[1])
Check(n == 0 and total == 1, "a holiday's quests count toward no zone")
Check(Q.Holiday(2) == "Hallow's End" and Q.Holiday(1) == nil, "a holiday's quest names its holiday")

days = { Holiday(HALLOWS_END, "ONGOING") }
Q.Refresh()
Check(Q.State(2) == "open" and Pinned(ELWYNN)[2], "while it is on, its quest is open and its giver has a !")

days = { Holiday(FAIRE_MULGORE, "ONGOING") }
Q.Refresh()
seen = Pinned(MULGORE)
Check(seen[3] and seen[3][1] == 36.2 and seen[3][2] == 35.2, "the Faire in Mulgore: its giver stands there")
Check(not Pinned(ELWYNN)[3], "and not in Elwynn")
local map = Q.Spot(3)
Check(map == MULGORE, "its waypoint goes there too")
days = { Holiday(FAIRE_ELWYNN, "ONGOING") }
Q.Refresh()
Check(Pinned(ELWYNN)[3] and not Pinned(MULGORE)[3], "the Faire in Elwynn: in Elwynn")

local real = setmetatable({ _G = { NaowhForever = { CompletoQuestData = {} } } }, { __index = _G })
local data = assert(loadstring(Read("NaowhForever_DiscoveryData/Quests.lua")))
setfenv(data, real)
data()
local D = real._G.NaowhForever.CompletoQuestData
Check(D.Events[1657][1] == HALLOWS_END and D.Events[8619][1] == LUNAR, "Stinking Up Southshore and the Elders' quests")
Check(D.Events[7881][1] == FAIRE_ELWYNN and D.Events[7881][2] == FAIRE_MULGORE and D.FaireSpots[7881][FAIRE_MULGORE][1] == MULGORE,
    "Carnival Boots: either Faire, and its giver in Mulgore when it is there")
Check(D.Events[7905] and D.Events[172][1] == 201 and D.Events[8193][1] == 301,
    "the hand-kept groups: the Faire's heralds, Children's Week and the Fishing Extravaganza")
Check(D.Quests[8811] == nil and D.Quests[9085] == nil, "the War Effort and the Scourge Invasion have no holiday, so stay out")
Check(D.Holidays[HALLOWS_END] == "Hallow's End" and D.Holidays[LUNAR] == "Lunar Festival", "each holiday's name")

print(("test-completo-quest-holidays: %d checks passed"):format(checks))
