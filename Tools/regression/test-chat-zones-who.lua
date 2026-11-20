-- Run with Lua 5.1 from the repository root: Chat Zones reads /who lines from system chat. ruRU's
-- who formats use positional specifiers (%3$d), which once broke the pattern with "invalid capture
-- index" on every system line that held a player link. The Russian text is transliterated to ASCII.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local source = Read("NaowhForever_QoL/Interface/ChatZones.lua")

local function Load(whoFormat, guildFormat)
    local values = { enabled = true, chatZones = true, chatZonesChat = true, chatZonesLevel = true,
        chatZonesMaxAge = 15 }
    local S = {}
    function S.Get(key) return values[key] end
    function S.Set(key, value) values[key] = value end
    local ns = {
        QoLSettings = S,
        QoLConstants = { SECONDS_PER_MINUTE = 60 },
        L = function(s) return s end,
        Color = function(_, s) return s end,
        GamepadStandDown = function() return false end,
        Apply = function() end,
        Shared = { Settings = {
            Group = function(name) return { group = name } end,
            Page = function() return { Card = function() end } end,
        } },
    }
    function ns.OnApply(fn) local was = ns.Apply ns.Apply = function(...) was(...) fn(...) end end

    local filters, frames = {}, {}
    local env = setmetatable({
        NaowhForever = ns,
        WHO_LIST_FORMAT = whoFormat,
        WHO_LIST_GUILD_FORMAT = guildFormat,
        CreateFrame = function()
            local frame = { events = {} }
            function frame:RegisterEvent(event) self.events[event] = true end
            function frame:UnregisterEvent(event) self.events[event] = nil end
            function frame:UnregisterAllEvents() end
            function frame:SetScript(_, fn) self.script = fn end
            frames[#frames + 1] = frame
            return frame
        end,
        hooksecurefunc = function() end,
        ChatFrameUtil = {
            AddMessageEventFilter = function(event, fn) filters[event] = fn end,
            RemoveMessageEventFilter = function(event) filters[event] = nil end,
        },
        EventRegistry = { RegisterCallback = function() end, UnregisterCallback = function() end },
        C_ChatInfo = { RegisterAddonMessagePrefix = function() end },
        C_LFGList = { GetSearchResultPlayerInfo = function() end },
        C_FriendList = { GetNumFriends = function() return 0 end },
        BNGetNumFriends = function() return 0 end,
        GetNumGroupMembers = function() return 0 end,
        IsInGuild = function() return false end,
        GetTime = function() return 100 end,
        Ambiguate = function(name) return name end,
        UnitName = function() return "Me" end,
        wipe = function(t) for k in pairs(t) do t[k] = nil end end,
    }, { __index = _G })
    env._G = env
    local fn = assert(loadstring(source, "ChatZones"))
    setfenv(fn, env)
    fn()
    ns.Apply()

    local frame = frames[1]
    local function System(msg) frame.script(frame, "CHAT_MSG_SYSTEM", msg) end
    local function Tagged(name)
        local _, msg = filters.CHAT_MSG_CHANNEL(nil, "CHAT_MSG_CHANNEL", "hi", name)
        return msg
    end
    return System, Tagged
end

local System, Tagged = Load("|Hplayer:%s|h[%s]|h: Level %d %s %s - %s",
    "|Hplayer:%s|h[%s]|h: Level %d %s %s <%s> - %s")
System("|Hplayer:Anna|h[Anna]|h: Level 42 Human Mage - Elwynn Forest")
check("an enUS who line tags the player with zone and level", Tagged("Anna") == "[Elwynn Forest 42] hi")
System("|Hplayer:Bram|h[Bram]|h: Level 17 Dwarf Hunter <Ironforge Rifles> - Dun Morogh")
check("an enUS guild who line does too", Tagged("Bram") == "[Dun Morogh 17] hi")

System, Tagged = Load("|Hplayer:%1$s|h[%2$s]|h:  |3-6(%4$s), |3-6(%5$s) %3$d-go urovnya - %6$s",
    "|Hplayer:%1$s|h[%2$s]|h: |3-6(%4$s), |3-6(%5$s) %3$d-go urovnya <%6$s> - %7$s")
System("|Hplayer:Teren Voidblade|h[Teren Voidblade]|h predlagaet vam prisoedinitsya k gruppe.")
check("a ruRU system line with a player link no longer errors", true)
System("|Hplayer:Igor|h[Igor]|h:  |3-6(Chelovek), |3-6(Mag) 42-go urovnya - Elvinnskiy les")
check("a ruRU who line reads level and zone from their positions", Tagged("Igor") == "[Elvinnskiy les 42] hi")
System("|Hplayer:Oleg|h[Oleg]|h: |3-6(Dvorf), |3-6(Okhotnik) 17-go urovnya <Strelki> - Dun Morog")
check("a ruRU guild who line does too", Tagged("Oleg") == "[Dun Morog 17] hi")

print(("chat zones who: %d checks passed"):format(checks))
