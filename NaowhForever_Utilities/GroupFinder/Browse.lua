-- Browse.lua: the Browse rules: each listing's leader asked once for their card after a search, what is known of them, and applying (ns.GroupFinder.Browse).
local ns = _G.NaowhForever

local GF = ns.GroupFinder
if not GF then return end
local Comms, Listings = GF.Comms, GF.Listings
local S = GF.Settings

local ASK_AGAIN = 300
local KNOWN_MAX = 200

local Browse = { ASK_AGAIN = ASK_AGAIN }
GF.Browse = Browse

local asked, without, nAsked = {}, {}, 0

local function Remember(key, now)
    if not asked[key] then
        if nAsked >= KNOWN_MAX then
            wipe(asked)
            wipe(without)
            nAsked = 0
        end
        nAsked = nAsked + 1
    end
    asked[key] = now
end

function Browse.Ask()
    local now = GetTime()
    for i = 1, Listings.n do
        local entry = Listings.entries[i]
        local leader = entry.leader
        if leader and not entry.delisted and not Comms.IsMe(leader) and not Comms.CardOf(leader) then
            local key = Comms.Key(leader)
            local at = asked[key]
            if not at or now - at > ASK_AGAIN then
                if not Comms.Ping(leader, entry.dungeon) then return end
                without[key] = nil
                Remember(key, now)
            end
        end
    end
end

function Browse.Apply(leader, dungeonKey, roles, note)
    local id = Comms.Apply(leader, dungeonKey, roles, note)
    GF.Fire("applied")
    return id
end

function Browse.CardOf(leader)
    local card = Comms.CardOf(leader)
    if card then return card, false end
    local key = Comms.Key(leader)
    return nil, asked[key] ~= nil and not without[key]
end

local function NoCard(ping)
    local key = Comms.Key(ping.name)
    if asked[key] then without[key] = true end
end

local function OnListings(failed)
    if failed then return end
    Listings.Read()
    Browse.Ask()
end

GF.Listen("listings", OnListings)
GF.Listen("noreply", NoCard)
GF.Listen("offline", NoCard)

S.OnChange(function(key)
    if key == "enabled" and not GF.On() then
        wipe(asked)
        wipe(without)
        nAsked = 0
    end
end)
