--[[
    KillTracker.lua
    Tracks NPC kills during a session via the combat log (PARTY_KILL sub-event).

    Data is stored in the session table under "kills":
        kills = {
            ["npcID"] = { name = "Kobold Miner", count = 3 },
            ...
        }
    And summary counters:
        totalKills      = total NPCs killed this session
        uniqueKills     = unique NPC types killed this session
]]

local LA = select(2, ...)

local KillTracker = {}
LA.KillTracker = KillTracker

local private = {}

-- Lua APIs
local pairs, tostring, tonumber, select, strsplit, bit =
    pairs, tostring, tonumber, select, strsplit, bit

-- WoW APIs
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local COMBATLOG_OBJECT_TYPE_NPC = COMBATLOG_OBJECT_TYPE_NPC or 0x00000800
local COMBATLOG_OBJECT_CONTROL_NPC = COMBATLOG_OBJECT_CONTROL_NPC or 0x00000200

--[[------------------------------------------------------------------------
    Extract NPC ID from a creature GUID
    Format: "Creature-0-XXXX-XXXX-XXXX-NPCID-XXXX"
    Also handles "Vehicle-0-..." GUIDs which share the same format
--------------------------------------------------------------------------]]
function KillTracker.ExtractNpcID(guid)
    if not guid then return nil end

    local guidType = strsplit("-", guid)
    if guidType ~= "Creature" and guidType ~= "Vehicle" then
        return nil
    end

    local npcID = select(6, strsplit("-", guid))
    return npcID -- string form; callers can tonumber() if needed
end

--[[------------------------------------------------------------------------
    COMBAT_LOG_EVENT_UNFILTERED handler
    We only care about PARTY_KILL sub-events targeting NPCs
--------------------------------------------------------------------------]]
function KillTracker.OnCombatLogEvent()
    if not LA.Session.IsRunning() then return end

    local _, subEvent, _, sourceGUID, sourceName, sourceFlags,
          _, destGUID, destName, destFlags = CombatLogGetCurrentEventInfo()

    if subEvent ~= "PARTY_KILL" then return end

    -- Make sure the destination is an NPC (not a player, pet, etc.)
    if not destGUID or not destName then return end
    if not private.IsNPC(destGUID, destFlags) then return end

    local npcID = KillTracker.ExtractNpcID(destGUID)
    if not npcID then return end

    LA.Debug.Log("KillTracker: PARTY_KILL  npcID=%s  name=%s", tostring(npcID), tostring(destName))

    private.RecordKill(npcID, destName)
end

--[[------------------------------------------------------------------------
    Check whether a GUID/flags combo represents an NPC
--------------------------------------------------------------------------]]
function private.IsNPC(guid, flags)
    -- GUID-based check (most reliable)
    local guidType = strsplit("-", guid)
    if guidType == "Creature" or guidType == "Vehicle" then
        return true
    end

    -- Flag-based fallback
    if flags and bit.band(flags, COMBATLOG_OBJECT_TYPE_NPC) > 0 then
        return true
    end

    return false
end

--[[------------------------------------------------------------------------
    Record a kill into the current session data
--------------------------------------------------------------------------]]
function private.RecordKill(npcID, npcName)
    -- Ensure the kills table exists on the session
    local kills = LA.Session.GetCurrentSession("kills")
    if not kills then
        kills = {}
        LA.Session.SetCurrentSession("kills", kills)
    end

    local entry = kills[npcID]
    if entry then
        entry.count = entry.count + 1
    else
        kills[npcID] = { name = npcName, count = 1 }
    end

    -- Update summary counters
    private.UpdateCounters(kills)
end

--[[------------------------------------------------------------------------
    Recompute the totalKills / uniqueKills summary counters
--------------------------------------------------------------------------]]
function private.UpdateCounters(kills)
    local total, unique = 0, 0
    for _, data in pairs(kills) do
        total = total + data.count
        unique = unique + 1
    end

    LA.Session.SetCurrentSession("totalKills", total)
    LA.Session.SetCurrentSession("uniqueKills", unique)

    LA.Debug.Log("KillTracker: totalKills=%d  uniqueKills=%d", total, unique)
end

--[[------------------------------------------------------------------------
    Public accessors
--------------------------------------------------------------------------]]
function KillTracker.GetTotalKills()
    return LA.Session.GetCurrentSession("totalKills") or 0
end

function KillTracker.GetUniqueKills()
    return LA.Session.GetCurrentSession("uniqueKills") or 0
end

function KillTracker.GetKills()
    return LA.Session.GetCurrentSession("kills") or {}
end

--[[------------------------------------------------------------------------
    Get kills sorted by count (descending) — useful for display
    Returns: array of { npcID, name, count }
--------------------------------------------------------------------------]]
function KillTracker.GetSortedKills()
    local kills = KillTracker.GetKills()
    local sorted = {}

    for npcID, data in pairs(kills) do
        sorted[#sorted + 1] = {
            npcID = npcID,
            name  = data.name,
            count = data.count,
        }
    end

    table.sort(sorted, function(a, b) return a.count > b.count end)
    return sorted
end

--[[------------------------------------------------------------------------
    Generate a formatted chat summary of kills
--------------------------------------------------------------------------]]
function KillTracker.PrintSummary()
    local total  = KillTracker.GetTotalKills()
    local unique = KillTracker.GetUniqueKills()

    if total == 0 then
        LA:Print("No kills recorded this session.")
        return
    end

    LA:Print(string.format("|cffffd100Kill Summary:|r  %d total kills  (%d unique NPCs)", total, unique))

    local sorted = KillTracker.GetSortedKills()
    for _, entry in ipairs(sorted) do
        LA:Print(string.format("   %s  x%d", entry.name, entry.count))
    end
end

--[[------------------------------------------------------------------------
    Generate CSV rows for kills within a session
    Returns a string with header + data rows, or nil if no kills
--------------------------------------------------------------------------]]
function KillTracker.GenerateKillsCSV(kills)
    if not kills or next(kills) == nil then return nil end

    local lines = {}
    table.insert(lines, "NPC ID,NPC Name,Kill Count")

    -- Sort by count descending for readability
    local sorted = {}
    for npcID, data in pairs(kills) do
        sorted[#sorted + 1] = { npcID = npcID, name = data.name, count = data.count }
    end
    table.sort(sorted, function(a, b) return a.count > b.count end)

    for _, entry in ipairs(sorted) do
        local name = (entry.name or "Unknown"):gsub(",", ";"):gsub('"', '""')
        table.insert(lines, string.format('%s,%s,%d', entry.npcID, name, entry.count))
    end

    return table.concat(lines, "\n")
end
