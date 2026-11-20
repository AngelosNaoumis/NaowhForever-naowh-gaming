-- Tally.lua: how this character's applications went: joined, declined, withdrawn and unanswered (ns.GroupFinder.Tally).
local ns = _G.NaowhForever

local GF = ns.GroupFinder
if not GF then return end

local KEY = "groupFinderTally"
local KINDS = { "joined", "declined", "withdrawn", "expired" }

local Tally = { KINDS = KINDS }
GF.Tally = Tally

local empty = {}

function Tally.Counts()
    return ns.Shared.CharacterData(KEY) or empty
end

local function Add(kind)
    local counts = ns.Shared.CharacterData(KEY, true)
    if not counts then return end
    counts[kind] = (counts[kind] or 0) + 1
    GF.Fire("tally")
end
Tally.Add = Add

GF.Listen("joined", function() Add("joined") end)
GF.Listen("declined", function() Add("declined") end)
GF.Listen("expired", function(record)
    if not (record.declined or record.joined) then Add("expired") end
end)
