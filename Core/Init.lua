local LA = select(2, ...)

local Init = {}
LA.Init = Init

local private = {}

--[[------------------------------------------------------------------------
    Initialize the SavedVariables databases
--------------------------------------------------------------------------]]
function Init.InitDB()
    LA.Debug.Log("InitDB")

    -- Main addon database
    LA.db = LibStub:GetLibrary("AceDB-3.0"):New("LootAppraiserReloadedDB",
                                                LA.CONST.DB_DEFAULTS, true)

    -- Loot tracking database
    LALoot = LibStub("AceDB-3.0"):New("LALootDB", LA.CONST.DB_LOOT, true)
end

--[[------------------------------------------------------------------------
    Get a value from the profile DB with defaults fallback
    Supports optional "TSM_REQUIRED" flag
--------------------------------------------------------------------------]]
function LA.GetFromDb(grp, key, ...)
    local tsmRequired
    for i = 1, select('#', ...) do
        local opt = select(i, ...)
        if opt == nil then
            -- do nothing
        elseif opt == "TSM_REQUIRED" then
            tsmRequired = true
        end
    end

    if tsmRequired and not LA.TSM.IsTSMLoaded() then return false end

    if LA.db.profile[grp][key] == nil then
        LA.db.profile[grp][key] = LA.CONST.DB_DEFAULTS.profile[grp][key]
    end
    return LA.db.profile[grp][key]
end
