local LA = select(2, ...)

local SessionHistory = {}
LA.SessionHistory = SessionHistory

local AceGUI = LibStub("AceGUI-3.0")

-- Lua APIs
local pairs, ipairs, table, time, date, tostring, tonumber, floor =
    pairs, ipairs, table, time, date, tostring, tonumber, floor

-- WoW APIs
local GetMapInfo, GetBestMapForUnit, GetUnitName, GetRealmName =
    C_Map.GetMapInfo, C_Map.GetBestMapForUnit, GetUnitName, GetRealmName

local private = {
    historyUI = nil,
    currentSessionData = nil -- Tracks loot during active session
}

-- Initialize session history system
function SessionHistory.Initialize()
    LA.Debug.Log("SessionHistory.Initialize")
    
    -- Ensure LALootDB exists and has proper structure
    if not LALoot then
        LA.Debug.Log("LALoot not initialized yet")
        return
    end
    
    -- Migrate from old schema if needed
    SessionHistory.MigrateDB()
    
    -- Initialize sessions array if needed
    if not LALoot.global.sessions then
        LALoot.global.sessions = {}
    end
    if not LALoot.global.nextSessionID then
        LALoot.global.nextSessionID = 1
    end
    
    -- Initialize current session loot tracking
    private.currentSessionData = {
        loot = {}
    }
end

-- Migrate database from old format to new format
function SessionHistory.MigrateDB()
    if not LALoot or not LALoot.global then return end
    
    local dbVersion = LALoot.global.dbVersion or 1
    
    if dbVersion < 2 then
        LA.Debug.Log("Migrating LALootDB from v1 to v2")
        
        -- Initialize new structure
        if not LALoot.global.sessions then
            LALoot.global.sessions = {}
        end
        if not LALoot.global.nextSessionID then
            LALoot.global.nextSessionID = 1
        end
        
        -- Update version
        LALoot.global.dbVersion = 2
        
        LA:Print("Session history database initialized.")
    end
end

-- Start tracking a new session (called when session starts)
function SessionHistory.StartTracking()
    LA.Debug.Log("SessionHistory.StartTracking")
    
    if not LALoot or not LALoot.global then
        SessionHistory.Initialize()
    end
    
    private.currentSessionData = {
        loot = {}
    }
end

-- Add loot item to current session tracking
function SessionHistory.AddLootItem(itemID, itemLink, quantity, value)
    if not private.currentSessionData then
        private.currentSessionData = { loot = {} }
    end
    
    table.insert(private.currentSessionData.loot, {
        itemID = itemID,
        itemLink = itemLink,
        quantity = quantity,
        value = value,
        time = time()
    })
end

-- Save current session to history (called when session ends/resets)
function SessionHistory.SaveSession()
    LA.Debug.Log("SessionHistory.SaveSession")
    
    if not LALoot or not LALoot.global then
        LA.Debug.Log("LALoot not available, cannot save session")
        return
    end
    
    local currentSession = LA.Session.GetCurrentSession()
    if not currentSession then
        LA.Debug.Log("No current session to save")
        return
    end
    
    -- Only save if there's actual data (loot, value, or kills)
    local totalValue = currentSession.liv or 0
    local itemCount = 0
    if private.currentSessionData and private.currentSessionData.loot then
        itemCount = #private.currentSessionData.loot
    end
    local totalKills = currentSession.totalKills or 0
    
    if totalValue == 0 and itemCount == 0 and totalKills == 0 then
        LA.Debug.Log("Session has no data (no loot, no value, no kills), not saving")
        return
    end
    
    -- Get zone info
    local mapID = currentSession.mapID or GetBestMapForUnit("player")
    local zoneInfo = GetMapInfo(mapID)
    local zoneName = zoneInfo and zoneInfo.name or "Unknown"
    
    -- Calculate duration
    local startTime = currentSession.start or time()
    local endTime = time()
    local pauseTime = LA.Session.GetSessionPause() or 0
    local duration = endTime - startTime - pauseTime
    
    -- Check if this session was already saved (same startTime = same session)
    local existingIndex = nil
    local existingRecord = nil
    for i, s in ipairs(LALoot.global.sessions) do
        if s.startTime == startTime then
            existingIndex = i
            existingRecord = s
            break
        end
    end
    
    -- Determine session ID (reuse existing or allocate new)
    local sessionID
    if existingRecord then
        sessionID = existingRecord.id
    else
        sessionID = LALoot.global.nextSessionID or 1
    end
    
    -- Create session record (preserve custom name if user renamed it)
    local sessionRecord = {
        id = sessionID,
        name = (existingRecord and existingRecord.name) or ("Session " .. sessionID),
        startTime = startTime,
        endTime = endTime,
        duration = duration,
        zoneName = zoneName,
        zone = zoneName, -- Keep for backwards compatibility
        mapID = mapID,
        player = currentSession.player or (GetUnitName("player", true) .. "-" .. GetRealmName()),
        totalValue = totalValue,
        totalValueGroup = currentSession.livGroup or 0,
        itemCount = itemCount,
        noteworthyCount = LA.Util.tablelength(currentSession.noteworthyItems or {}),
        currencyLooted = currentSession.currencyLooted or 0,
        vendorSales = currentSession.vendorSoldCurrencyUI or 0,
        settings = {
            priceSource = currentSession.settings and currentSession.settings.priceSource or "Unknown",
            qualityFilter = currentSession.settings and currentSession.settings.qualityFilter or "1"
        },
        priceSource = currentSession.settings and currentSession.settings.priceSource or "Unknown",
        qualityFilter = currentSession.settings and currentSession.settings.qualityFilter or "1",
        loot = private.currentSessionData and private.currentSessionData.loot or {},
        kills = currentSession.kills or {},
        totalKills = currentSession.totalKills or 0,
        uniqueKills = currentSession.uniqueKills or 0
    }
    
    -- Update existing or add new session
    if existingIndex then
        LALoot.global.sessions[existingIndex] = sessionRecord
        LA.Debug.Log("Session updated with ID: " .. sessionID)
    else
        table.insert(LALoot.global.sessions, sessionRecord)
        LALoot.global.nextSessionID = sessionID + 1
        LA.Debug.Log("Session saved with ID: " .. sessionID)
    end
    
    -- Reset current session data
    private.currentSessionData = { loot = {} }
end

-- Get all sessions
function SessionHistory.GetAllSessions()
    if not LALoot or not LALoot.global or not LALoot.global.sessions then
        return {}
    end
    return LALoot.global.sessions
end

-- Get session by ID
function SessionHistory.GetSession(sessionID)
    local sessions = SessionHistory.GetAllSessions()
    for _, session in ipairs(sessions) do
        if session.id == sessionID then
            return session
        end
    end
    return nil
end

-- Rename a session
function SessionHistory.RenameSession(sessionID, newName)
    local sessions = SessionHistory.GetAllSessions()
    for _, session in ipairs(sessions) do
        if session.id == sessionID then
            session.name = newName
            LA:Print("Session renamed to: " .. newName)
            return true
        end
    end
    return false
end

-- Delete a session
function SessionHistory.DeleteSession(sessionID)
    if not LALoot or not LALoot.global or not LALoot.global.sessions then
        return false
    end
    
    for i, session in ipairs(LALoot.global.sessions) do
        if session.id == sessionID then
            table.remove(LALoot.global.sessions, i)
            LA:Print("Session deleted: " .. (session.name or "Session " .. sessionID))
            return true
        end
    end
    return false
end

-- Reset all session history
function SessionHistory.ResetAll()
    if not LALoot or not LALoot.global then
        LA:Print("No session history to reset.")
        return
    end
    
    local count = #(LALoot.global.sessions or {})
    LALoot.global.sessions = {}
    LALoot.global.nextSessionID = 1
    
    LA:Print("Session history reset. " .. count .. " session(s) deleted.")
end

-- Export a single session to CSV
function SessionHistory.ExportSessionCSV(sessionID)
    local session = SessionHistory.GetSession(sessionID)
    if not session then
        LA:Print("Session not found: " .. tostring(sessionID))
        return nil
    end
    
    return SessionHistory.GenerateCSV({session})
end

-- Export all sessions to CSV
function SessionHistory.ExportAllCSV()
    local sessions = SessionHistory.GetAllSessions()
    if #sessions == 0 then
        LA:Print("No sessions to export.")
        return nil
    end
    
    return SessionHistory.GenerateCSV(sessions)
end

-- Generate CSV string from sessions (unified export: session data + kill details)
function SessionHistory.GenerateCSV(sessions)
    local lines = {}
    
    -- Header
    table.insert(lines, "Session ID,Session Name,Start Time,End Time,Duration (min),Zone,Player,Total Value (gold),Item Count,Noteworthy Count,Currency Looted (gold),Vendor Sales (gold),Total Kills,Unique NPCs,Kill Details,Price Source,Quality Filter")
    
    for _, session in ipairs(sessions) do
        local startDate = date("%Y-%m-%d %H:%M:%S", session.startTime)
        local endDate = date("%Y-%m-%d %H:%M:%S", session.endTime)
        local durationMin = floor((session.duration or 0) / 60)
        local totalGold = floor((session.totalValue or 0) / 10000)
        local currencyGold = floor((session.currencyLooted or 0) / 10000)
        local vendorGold = floor((session.vendorSales or 0) / 10000)
        
        -- Escape commas and quotes in name
        local name = (session.name or ""):gsub('"', '""')
        if name:find(",") or name:find('"') then
            name = '"' .. name .. '"'
        end
        
        -- Build kill details string: "NpcName x3 | OtherNpc x7 | ..."
        local killDetails = ""
        local kills = session.kills
        if kills and next(kills) then
            local sorted = {}
            for npcID, data in pairs(kills) do
                sorted[#sorted + 1] = { name = data.name, count = data.count }
            end
            table.sort(sorted, function(a, b) return a.count > b.count end)
            
            local parts = {}
            for _, entry in ipairs(sorted) do
                parts[#parts + 1] = (entry.name or "Unknown") .. " x" .. entry.count
            end
            killDetails = table.concat(parts, " | ")
        end
        -- Wrap in quotes since it may contain special chars
        killDetails = '"' .. killDetails:gsub('"', '""') .. '"'
        
        local line = string.format('%d,%s,%s,%s,%d,%s,%s,%d,%d,%d,%d,%d,%d,%d,%s,%s,%s',
            session.id or 0,
            name,
            startDate,
            endDate,
            durationMin,
            (session.zone or "Unknown"):gsub(",", ";"),
            (session.player or "Unknown"):gsub(",", ";"),
            totalGold,
            session.itemCount or 0,
            session.noteworthyCount or 0,
            currencyGold,
            vendorGold,
            session.totalKills or 0,
            session.uniqueKills or 0,
            killDetails,
            (session.priceSource or "Unknown"):gsub(",", ";"),
            session.qualityFilter or "1"
        )
        
        table.insert(lines, line)
    end
    
    return table.concat(lines, "\n")
end

-- Show export popup with CSV data
function SessionHistory.ShowExportPopup(csvData)
    if not csvData then return end
    
    local frame = AceGUI:Create("Frame")
    frame:SetTitle("Export Session History")
    frame:SetStatusText("Select all and copy (Ctrl+A, Ctrl+C)")
    frame:SetLayout("Fill")
    frame:SetWidth(600)
    frame:SetHeight(400)
    frame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)
    
    local editBox = AceGUI:Create("MultiLineEditBox")
    editBox:SetLabel("")
    editBox:SetText(csvData)
    editBox:SetFullWidth(true)
    editBox:SetFullHeight(true)
    editBox:DisableButton(true)
    frame:AddChild(editBox)
    
    -- Focus and select all
    editBox:SetFocus()
end

-- Show rename popup
function SessionHistory.ShowRenamePopup(sessionID, currentName, callback)
    local frame = AceGUI:Create("Frame")
    frame:SetTitle("Rename Session")
    frame:SetLayout("Flow")
    frame:SetWidth(300)
    frame:SetHeight(120)
    frame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)
    
    local editBox = AceGUI:Create("EditBox")
    editBox:SetLabel("Session Name:")
    editBox:SetText(currentName)
    editBox:SetFullWidth(true)
    editBox:SetCallback("OnEnterPressed", function(widget, event, text)
        if text and text ~= "" then
            SessionHistory.RenameSession(sessionID, text)
            if callback then callback() end
        end
        frame:Release()
    end)
    frame:AddChild(editBox)
    
    editBox:SetFocus()
end

-- Show session history window
function SessionHistory.ShowHistoryWindow()
    LA.Debug.Log("SessionHistory.ShowHistoryWindow")
    
    if private.historyUI then
        private.historyUI:Show()
        SessionHistory.RefreshHistoryList()
        return
    end
    
    private.historyUI = AceGUI:Create("Frame")
    private.historyUI:SetTitle("Session History")
    private.historyUI:SetStatusText("Left-click to rename | Right-click to export as CSV")
    private.historyUI:SetLayout("Fill")
    private.historyUI:SetWidth(500)
    private.historyUI:SetHeight(400)
    private.historyUI:SetStatusTable(LA.db.profile.sessionHistoryUI)
    private.historyUI:SetCallback("OnClose", function(widget) 
        widget:Hide()
    end)
    
    -- Create scroll frame
    local scrollContainer = AceGUI:Create("SimpleGroup")
    scrollContainer:SetFullWidth(true)
    scrollContainer:SetFullHeight(true)
    scrollContainer:SetLayout("Fill")
    private.historyUI:AddChild(scrollContainer)
    
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("List")
    scrollContainer:AddChild(scroll)
    
    private.historyUI.scroll = scroll
    
    SessionHistory.RefreshHistoryList()
    
    private.historyUI:Show()
end

-- Refresh the history list
function SessionHistory.RefreshHistoryList()
    if not private.historyUI or not private.historyUI.scroll then return end
    
    local scroll = private.historyUI.scroll
    scroll:ReleaseChildren()
    
    local sessions = SessionHistory.GetAllSessions()
    
    if #sessions == 0 then
        local label = AceGUI:Create("Label")
        label:SetText("No sessions recorded yet.")
        label:SetFullWidth(true)
        scroll:AddChild(label)
        return
    end
    
    -- Sort sessions by startTime descending (newest first)
    local sortedSessions = {}
    for _, session in ipairs(sessions) do
        table.insert(sortedSessions, session)
    end
    table.sort(sortedSessions, function(a, b)
        return (a.startTime or 0) > (b.startTime or 0)
    end)
    
    -- Add session rows
    for _, session in ipairs(sortedSessions) do
        local row = AceGUI:Create("InteractiveLabel")
        
        local dateStr = date("%Y-%m-%d %H:%M", session.startTime)
        local durationMin = floor((session.duration or 0) / 60)
        local totalGold = floor((session.totalValue or 0) / 10000)
        
        local text = string.format("|cFFFFD700%s|r - %s (%dm) - |cFFFFD700%dg|r - %d items",
            session.name or ("Session " .. session.id),
            dateStr,
            durationMin,
            totalGold,
            session.itemCount or 0
        )
        
        row:SetText(text)
        row:SetFullWidth(true)
        row:SetHighlight("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        
        -- Left-click to rename
        row:SetCallback("OnClick", function(widget, event, button)
            if button == "LeftButton" then
                SessionHistory.ShowRenamePopup(session.id, session.name or ("Session " .. session.id), function()
                    SessionHistory.RefreshHistoryList()
                end)
            elseif button == "RightButton" then
                local csv = SessionHistory.ExportSessionCSV(session.id)
                if csv then
                    SessionHistory.ShowExportPopup(csv)
                end
            end
        end)
        
        scroll:AddChild(row)
    end
end

-- Slash command handler for /lahistory
function SessionHistory.HandleCommand(input)
    local cmd = input and input:lower() or ""
    
    if cmd == "reset" then
        -- Confirm reset
        StaticPopupDialogs["LA_HISTORY_RESET_CONFIRM"] = {
            text = "Are you sure you want to delete ALL session history? This cannot be undone.",
            button1 = "Yes",
            button2 = "No",
            OnAccept = function()
                SessionHistory.ResetAll()
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
        }
        StaticPopup_Show("LA_HISTORY_RESET_CONFIRM")
    elseif cmd == "export" then
        local csv = SessionHistory.ExportAllCSV()
        if csv then
            SessionHistory.ShowExportPopup(csv)
        end
    elseif cmd == "" or cmd == "show" then
        SessionHistory.ShowHistoryWindow()
    else
        LA:Print("Usage: /lahistory [show|reset|export]")
        LA:Print("  show - Open session history window (default)")
        LA:Print("  reset - Delete all session history")
        LA:Print("  export - Export all sessions as CSV")
    end
end

-- ============================================
-- Aliases and helper functions for SessionHistoryUI.lua compatibility
-- ============================================

-- Alias for SaveSession (UI calls SaveCurrentSession)
function SessionHistory.SaveCurrentSession()
    return SessionHistory.SaveSession()
end

-- Alias for ResetAll (returns count)
function SessionHistory.ResetAllSessions()
    if not LALoot or not LALoot.global then
        return 0
    end
    local count = #(LALoot.global.sessions or {})
    LALoot.global.sessions = {}
    LALoot.global.nextSessionID = 1
    return count
end

-- Get session count
function SessionHistory.GetSessionCount()
    if not LALoot or not LALoot.global or not LALoot.global.sessions then
        return 0
    end
    return #LALoot.global.sessions
end

-- Get display name for a session
function SessionHistory.GetSessionDisplayName(session)
    if session.name and session.name ~= "" then
        return session.name
    end
    return date("%Y-%m-%d %H:%M", session.startTime or 0) .. " - " .. (session.zone or session.zoneName or "Unknown")
end

-- Format duration in human readable form
function SessionHistory.FormatDuration(seconds)
    seconds = seconds or 0
    local hours = floor(seconds / 3600)
    local mins = floor((seconds % 3600) / 60)
    local secs = seconds % 60
    
    if hours > 0 then
        return string.format("%dh %dm", hours, mins)
    elseif mins > 0 then
        return string.format("%dm %ds", mins, secs)
    else
        return string.format("%ds", secs)
    end
end

-- Format value in gold
function SessionHistory.FormatValue(copper)
    copper = copper or 0
    local gold = floor(copper / 10000)
    local silver = floor((copper % 10000) / 100)
    
    if gold > 0 then
        return string.format("%dg %ds", gold, silver)
    elseif silver > 0 then
        return string.format("%ds %dc", silver, copper % 100)
    else
        return string.format("%dc", copper)
    end
end

-- Export session to CSV (UI version)
function SessionHistory.ExportSessionToCSV(sessionID)
    local session = SessionHistory.GetSession(sessionID)
    if not session then
        return nil, "Session not found"
    end
    return SessionHistory.GenerateCSV({session}), nil
end

-- Export all sessions to CSV (UI version)
function SessionHistory.ExportAllSessionsToCSV()
    local sessions = SessionHistory.GetAllSessions()
    if #sessions == 0 then
        return nil, "No sessions to export"
    end
    return SessionHistory.GenerateCSV(sessions), nil
end