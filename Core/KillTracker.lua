--[[
    KillTracker.lua
    NPC kill tracking with version-aware strategy:

    CLASSIC:  COMBAT_LOG_EVENT_UNFILTERED → PARTY_KILL sub-event
              Full access to combat log data.

    RETAIL (12.0+):  CLEU is fully blocked (RegisterEvent is protected).
              Instead we use:
        1. TryTrackFromLoot() - Called from Events.OnChatMsgLoot each time
           an item is looted. Scans ALL loot slots via GetLootSourceInfo()
           to collect every unique creature GUID — this is critical for
           AoE looting where one loot window contains items from multiple
           corpses. Also tries UnitGUID("npc") as a fast path.
        2. LOOT_READY - Backup event, calls the same scan logic.
        3. PLAYER_REGEN_ENABLED - When leaving combat, check target and
           mouseover for dead NPCs (catches un-looted kills).

    Data stored in session:
        kills = { ["npcID"] = { name = "Kobold Miner", count = 3 }, ... }
        totalKills, uniqueKills
]]

local LA = select(2, ...)

local KillTracker = {}
LA.KillTracker = KillTracker

local private = {}

-- Lua APIs
local pairs, tostring, tonumber, select, strsplit, bit, pcall, type =
    pairs, tostring, tonumber, select, strsplit, bit, pcall, type

-- WoW APIs
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local GetLootSourceInfo = GetLootSourceInfo
local GetNumLootItems = GetNumLootItems
local UnitName = UnitName
local UnitGUID = UnitGUID
local UnitIsDead = UnitIsDead
local UnitCreatureType = UnitCreatureType
local UnitExists = UnitExists
local GetTime = GetTime

local COMBATLOG_OBJECT_TYPE_NPC = COMBATLOG_OBJECT_TYPE_NPC or 0x00000800

--[[------------------------------------------------------------------------
    Dedup tracking: prevent counting the same mob twice
    Key = GUID, Value = GetTime() timestamp
    Entries expire after DEDUP_WINDOW seconds.
--------------------------------------------------------------------------]]
local recentKills = {}
local DEDUP_WINDOW = 120

--[[------------------------------------------------------------------------
    Extract NPC ID from a creature GUID
    Format: "Creature-0-XXXX-XXXX-XXXX-NPCID-XXXX"
--------------------------------------------------------------------------]]
function KillTracker.ExtractNpcID(guid)
    if not guid or type(guid) ~= "string" then return nil end

    local guidType = strsplit("-", guid)
    if guidType ~= "Creature" and guidType ~= "Vehicle" then
        return nil
    end

    return select(6, strsplit("-", guid))
end

--[[------------------------------------------------------------------------
    Dedup helpers
--------------------------------------------------------------------------]]
function private.PurgeExpiredDedup()
    local now = GetTime()
    for guid, timestamp in pairs(recentKills) do
        if (now - timestamp) > DEDUP_WINDOW then
            recentKills[guid] = nil
        end
    end
end

function private.AlreadyCounted(guid)
    return guid and recentKills[guid] ~= nil
end

function private.MarkCounted(guid)
    if guid then recentKills[guid] = GetTime() end
end

--[[------------------------------------------------------------------------
    Safe pcall wrapper: returns the result or nil
    Guards against secret values in 12.0+
--------------------------------------------------------------------------]]
function private.SafeCall(func, ...)
    local ok, result = pcall(func, ...)
    if ok and result then
        local t = type(result)
        if t == "string" or t == "number" or t == "boolean" then
            return result
        end
    end
    return nil
end

--[[========================================================================
    CLASSIC: COMBAT_LOG_EVENT_UNFILTERED → PARTY_KILL
========================================================================--]]
function KillTracker.OnCombatLogEvent()
    if not LA.Session.IsRunning() then return end

    local _, subEvent, _, sourceGUID, sourceName, sourceFlags,
          _, destGUID, destName, destFlags = CombatLogGetCurrentEventInfo()

    if subEvent ~= "PARTY_KILL" then return end
    if not destGUID or not destName then return end
    if not private.IsNPC(destGUID, destFlags) then return end

    local npcID = KillTracker.ExtractNpcID(destGUID)
    if not npcID then return end
    if private.AlreadyCounted(destGUID) then return end

    LA.Debug.Log("KillTracker: PARTY_KILL (CLEU)  npcID=%s  name=%s",
        tostring(npcID), tostring(destName))

    private.MarkCounted(destGUID)
    private.RecordKill(npcID, destName)
end

--[[========================================================================
    RETAIL PATH 1: TryTrackFromLoot()
    Called from Events.OnChatMsgLoot — the most reliable hook since
    CHAT_MSG_LOOT always fires when you loot something.

    CRITICAL FOR AoE LOOTING:
    When AoE looting multiple corpses, WoW combines all items into one
    loot window. Each loot slot has a different source GUID (the corpse
    it came from). We MUST scan ALL loot slots to find every unique
    creature GUID, not just stop at the first one found.

    UnitGUID("npc") only points to the one corpse you right-clicked,
    so we use it as a supplement, not as an early-exit.
========================================================================--]]
function KillTracker.TryTrackFromLoot()
    if not LA.Session.IsRunning() then return end

    private.PurgeExpiredDedup()

    local killsFound = 0

    -- Track which GUIDs we've processed this call (not same as recentKills)
    local processedThisCall = {}

    -- 1) Try UnitGUID("npc") — the corpse you right-clicked to loot
    local npcGuid = private.SafeCall(UnitGUID, "npc")
    local npcName = private.SafeCall(UnitName, "npc")

    LA.Debug.Log("KillTracker: TryTrackFromLoot  UnitGUID('npc')='%s'  UnitName('npc')='%s'",
        tostring(npcGuid), tostring(npcName))

    if npcGuid and type(npcGuid) == "string" then
        processedThisCall[npcGuid] = true
        local npcID = KillTracker.ExtractNpcID(npcGuid)
        if npcID and not private.AlreadyCounted(npcGuid) then
            local name = (npcName and type(npcName) == "string" and npcName ~= "")
                and npcName or ("NPC-" .. npcID)
            LA.Debug.Log("KillTracker: >> KILL from loot (npc unit)  npcID=%s  name=%s",
                tostring(npcID), name)
            private.MarkCounted(npcGuid)
            private.RecordKill(npcID, name)
            killsFound = killsFound + 1
        end
    end

    -- 2) Scan ALL loot slots via GetLootSourceInfo
    --    This is how we catch the other 4 corpses in a 5-mob AoE pull
    if GetLootSourceInfo then
        local okNum, numSlots = pcall(GetNumLootItems)
        if okNum and numSlots then
            numSlots = tonumber(numSlots) or 0
            LA.Debug.Log("KillTracker: Scanning %d loot slots for AoE sources", numSlots)

            for slot = 1, numSlots do
                local ok, sourceGUID = pcall(GetLootSourceInfo, slot)
                if ok and sourceGUID and type(sourceGUID) == "string"
                   and not processedThisCall[sourceGUID] then
                    processedThisCall[sourceGUID] = true

                    local npcID = KillTracker.ExtractNpcID(sourceGUID)
                    if npcID and not private.AlreadyCounted(sourceGUID) then
                        -- We can't get the name per-corpse from GetLootSourceInfo,
                        -- so use UnitName("npc") if same type, else fallback to NPC-ID
                        local name
                        if npcName and type(npcName) == "string" and npcName ~= "" then
                            name = npcName
                        else
                            name = "NPC-" .. npcID
                        end
                        LA.Debug.Log("KillTracker: >> KILL from AoE loot slot %d  npcID=%s  name=%s  guid=%s",
                            slot, tostring(npcID), name, sourceGUID)
                        private.MarkCounted(sourceGUID)
                        private.RecordKill(npcID, name)
                        killsFound = killsFound + 1
                    end
                end
            end
        end
    end

    -- 3) Fallback: try target if we found nothing above
    if killsFound == 0 then
        local guid = private.SafeCall(UnitGUID, "target")
        local name = private.SafeCall(UnitName, "target")
        local isDead = private.SafeCall(UnitIsDead, "target")

        if guid and isDead and type(guid) == "string" then
            local npcID = KillTracker.ExtractNpcID(guid)
            if npcID and not private.AlreadyCounted(guid) then
                local npcNameFinal = (name and type(name) == "string" and name ~= "")
                    and name or ("NPC-" .. npcID)
                LA.Debug.Log("KillTracker: >> KILL from loot (target fallback)  npcID=%s  name=%s",
                    tostring(npcID), npcNameFinal)
                private.MarkCounted(guid)
                private.RecordKill(npcID, npcNameFinal)
                killsFound = killsFound + 1
            end
        end
    end

    if killsFound == 0 then
        LA.Debug.Log("KillTracker: TryTrackFromLoot — could not identify kill source")
    else
        LA.Debug.Log("KillTracker: TryTrackFromLoot — recorded %d kill(s)", killsFound)
    end
end

--[[========================================================================
    RETAIL PATH 2: LOOT_READY (backup — may or may not fire)
========================================================================--]]
function KillTracker.OnLootReady()
    LA.Debug.Log("KillTracker: >>> LOOT_READY fired")
    KillTracker.TryTrackFromLoot()
end

--[[========================================================================
    RETAIL PATH 3: PLAYER_REGEN_ENABLED (leaving combat)
    Check target and mouseover for dead NPCs.
========================================================================--]]
function KillTracker.OnRegenEnabled()
    LA.Debug.Log("KillTracker: >>> PLAYER_REGEN_ENABLED fired")
    if not LA.Session.IsRunning() then return end

    private.PurgeExpiredDedup()

    private.TryCountDeadUnit("target")
    private.TryCountDeadUnit("mouseover")
end

function private.TryCountDeadUnit(unit)
    local exists = private.SafeCall(UnitExists, unit)
    if not exists then return end

    local isDead = private.SafeCall(UnitIsDead, unit)
    if not isDead then return end

    local guid = private.SafeCall(UnitGUID, unit)
    if not guid or type(guid) ~= "string" then return end
    if private.AlreadyCounted(guid) then return end

    local npcID = KillTracker.ExtractNpcID(guid)
    if not npcID then return end

    -- Verify creature, not player
    local creatureType = private.SafeCall(UnitCreatureType, unit)
    if not creatureType then return end

    local name = private.SafeCall(UnitName, unit)
    local npcName = (name and type(name) == "string") and name or ("NPC-" .. npcID)

    LA.Debug.Log("KillTracker: >> KILL from regen (dead %s)  npcID=%s  name=%s",
        unit, tostring(npcID), npcName)

    private.MarkCounted(guid)
    private.RecordKill(npcID, npcName)
end

--[[------------------------------------------------------------------------
    Check whether a GUID/flags combo represents an NPC
--------------------------------------------------------------------------]]
function private.IsNPC(guid, flags)
    if type(guid) == "string" then
        local guidType = strsplit("-", guid)
        if guidType == "Creature" or guidType == "Vehicle" then
            return true
        end
    end
    if flags and type(flags) == "number" and bit.band(flags, COMBATLOG_OBJECT_TYPE_NPC) > 0 then
        return true
    end
    return false
end

--[[------------------------------------------------------------------------
    Record a kill
--------------------------------------------------------------------------]]
function private.RecordKill(npcID, npcName)
    local kills = LA.Session.GetCurrentSession("kills")
    if not kills then
        kills = {}
        LA.Session.SetCurrentSession("kills", kills)
    end

    local entry = kills[npcID]
    if entry then
        entry.count = entry.count + 1
        if npcName and not npcName:match("^NPC%-") and entry.name:match("^NPC%-") then
            entry.name = npcName
        end
    else
        kills[npcID] = { name = npcName or ("NPC-" .. npcID), count = 1 }
    end

    private.UpdateCounters(kills)

    LA.Debug.Log("KillTracker: >> RECORDED  npcID=%s  name=%s  count=%d  | total=%d  unique=%d",
        tostring(npcID), tostring(npcName),
        kills[npcID].count,
        LA.Session.GetCurrentSession("totalKills") or 0,
        LA.Session.GetCurrentSession("uniqueKills") or 0)
end

--[[------------------------------------------------------------------------
    Update counters
--------------------------------------------------------------------------]]
function private.UpdateCounters(kills)
    local total, unique = 0, 0
    for _, data in pairs(kills) do
        total = total + data.count
        unique = unique + 1
    end
    LA.Session.SetCurrentSession("totalKills", total)
    LA.Session.SetCurrentSession("uniqueKills", unique)
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

function KillTracker.GetSortedKills()
    local kills = KillTracker.GetKills()
    local sorted = {}
    for npcID, data in pairs(kills) do
        sorted[#sorted + 1] = { npcID = npcID, name = data.name, count = data.count }
    end
    table.sort(sorted, function(a, b) return a.count > b.count end)
    return sorted
end

function KillTracker.PrintSummary()
    local total  = KillTracker.GetTotalKills()
    local unique = KillTracker.GetUniqueKills()

    if total == 0 then
        LA:Print("No kills recorded this session.")
        return
    end

    LA:Print(string.format("|cffffd100Kill Summary:|r  %d total kills  (%d unique NPCs)",
        total, unique))

    local sorted = KillTracker.GetSortedKills()
    for _, entry in ipairs(sorted) do
        LA:Print(string.format("   %s  x%d", entry.name, entry.count))
    end
end

function KillTracker.GenerateKillsCSV(kills)
    if not kills or next(kills) == nil then return nil end

    local lines = { "NPC ID,NPC Name,Kill Count" }
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

function KillTracker.ResetCLEUState()
    recentKills = {}
    LA.Debug.Log("KillTracker: State reset for new session")
end