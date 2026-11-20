local file = assert(io.open("NaowhForever_QoL/Combat/PetTracker.lua", "rb"))
local source = file:read("*a"):gsub("\r\n", "\n"); file:close()
local first = assert(source:find("local function ShouldHavePet()", 1, true))
local last = assert(source:find("local function Update()", first, true))
local known, hasPet, passive = { [688] = true }, false, false
local env = {
 class = "WARLOCK", SUMMON_IMP = 688, DEMONIC_PACT = 425464, sacrificed = false,
 S = { Get = function() return true end },
 C_SpellBook = { IsSpellKnown = function(id) return known[id] == true end },
 UnitIsDeadOrGhost = function() return false end,
 UnitOnTaxi = function() return false end,
 UnitAffectingCombat = function() return true end,
 IsInInstance = function() return true end,
 UnitExists = function() return hasPet end,
 PetHasActionBar = function() return true end,
 NUM_PET_ACTION_SLOTS = 1,
 GetPetActionInfo = function() return "PET_MODE_PASSIVE", nil, nil, passive end,
}
local chunk = assert(loadstring(source:sub(first, last - 1) .. "return Warning"))
setfenv(chunk, env)
local warning = chunk()
assert(warning() == "petMissingText", "warlock without a pet must be warned")
env.sacrificed = true
assert(warning() == nil, "a sacrificed demon must not count as missing")
known[425464] = true
assert(warning() == "petMissingText", "Demonic Pact warlock without a demon must be warned")
hasPet, passive = true, true
assert(warning() == "petPassiveText", "Demonic Pact warlock must still get the passive warning")
passive = false
local key, low = warning()
assert(key == "petLowHealthText" and low, "Demonic Pact warlock must still get the low health warning")
print("5 pet tracker sacrifice checks passed")
