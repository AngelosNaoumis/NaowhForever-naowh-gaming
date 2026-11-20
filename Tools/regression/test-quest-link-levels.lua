-- Run with Lua 5.1 from the repository root: Quest Levels in Chat. Off, it filters no chat; on, a quest link said in
-- chat reads "[level] title", the rest of the message as it was; a link with no level, one that has its level
-- already, a secret message and a message with no quest link pass as they are.
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local settings = { enabled = true, questLinkLevels = false }
local filters, boot = {}, nil
local ns = { QoLSettings = { Get = function(key) return settings[key] end, Set = function() end }, Apply = function() end,
    Shared = { Settings = { Page = function() return { Card = function() end } end } } }
function ns.OnApply(fn) local was = ns.Apply ns.Apply = function(...) was(...) fn(...) end end
local env = setmetatable({
    _G = { NaowhForever = ns },
    ChatFrameUtil = {
        AddMessageEventFilter = function(event, fn) filters[event] = fn end,
        RemoveMessageEventFilter = function(event) filters[event] = nil end,
    },
    issecretvalue = function(v) return v == "SECRET" end,
    hooksecurefunc = function() end,
    CreateFrame = function()
        local f = {}
        function f:RegisterEvent() end
        function f:SetScript(_, fn) self.OnEvent = fn end
        boot = f
        return f
    end,
}, { __index = _G })
local chunk = assert(loadstring(Read("NaowhForever_QoL/Questing/QuestLinks.lua")))
setfenv(chunk, env)
chunk()
boot.OnEvent(boot)
Check(next(filters) == nil, "off: no chat filter")

settings.questLinkLevels = true
ns.Apply()
local party = filters.CHAT_MSG_PARTY
Check(party and filters.CHAT_MSG_GUILD and filters.CHAT_MSG_WHISPER, "on: party, guild and whispers are filtered")

local link = "|cffffff00|Hquest:33:5:0|h[Wolves Across the Border]|h|r"
local hide, msg, author = party(nil, "CHAT_MSG_PARTY", "need help with " .. link .. "?", "Bob")
Check(hide == false and msg == "need help with |cffffff00|Hquest:33:5:0|h[[5] Wolves Across the Border]|h|r?",
    "a quest link reads its level")
Check(author == "Bob", "the rest of the event passes on")
Check(select(2, party(nil, "CHAT_MSG_PARTY", link .. " and " .. "|Hquest:46:10|h[Bounty on Murlocs]|h")) ==
    "|cffffff00|Hquest:33:5:0|h[[5] Wolves Across the Border]|h|r and |Hquest:46:10|h[[10] Bounty on Murlocs]|h",
    "every link in a message")
Check(select(2, party(nil, "CHAT_MSG_PARTY", "|Hquest:12:-1|h[Scaling]|h")) == "|Hquest:12:-1|h[Scaling]|h",
    "a link with no level is left as it is")
Check(select(2, party(nil, "CHAT_MSG_PARTY", "|Hquest:33:5|h[[5] Wolves]|h")) == "|Hquest:33:5|h[[5] Wolves]|h",
    "and one that has its level already")
Check(party(nil, "CHAT_MSG_PARTY", "SECRET") == false and select("#", party(nil, "CHAT_MSG_PARTY", "SECRET")) == 1,
    "a secret message is not read")
Check(select("#", party(nil, "CHAT_MSG_PARTY", "no links here")) == 1, "nor one with no quest link")

settings.questLinkLevels = false
ns.Apply()
Check(next(filters) == nil, "turned off: every filter removed")

print(("test-quest-link-levels: %d checks passed"):format(checks))
