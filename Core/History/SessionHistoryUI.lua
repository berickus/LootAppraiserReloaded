local LA = select(2, ...)

local SessionHistoryUI = {}
LA.SessionHistoryUI = SessionHistoryUI

local private = {HISTORY_UI = nil, selectedSession = nil, sessionWidgets = {}}

local LibStub = LibStub
local AceGUI = LibStub("AceGUI-3.0")

-- Lua APIs
local pairs, ipairs, tostring, date, floor, table, sort = pairs, ipairs,
                                                          tostring, date, floor,
                                                          table, sort

-- WoW APIs
local GameTooltip, StaticPopupDialogs, StaticPopup_Show, PlaySound =
    GameTooltip, StaticPopupDialogs, StaticPopup_Show, PlaySound

--[[
    Show the Session History window
]]
function SessionHistoryUI.Show()
    LA.Debug.Log("SessionHistoryUI.Show()")

    if private.HISTORY_UI then
        private.RefreshSessionList()
        private.HISTORY_UI:Show()
        return
    end

    private.CreateUI()
end

--[[
    Hide the Session History window
]]
function SessionHistoryUI.Hide()
    if private.HISTORY_UI then private.HISTORY_UI:Hide() end
end

--[[
    Toggle the Session History window
]]
function SessionHistoryUI.Toggle()
    if private.HISTORY_UI and private.HISTORY_UI:IsShown() then
        SessionHistoryUI.Hide()
    else
        SessionHistoryUI.Show()
    end
end

--[[
    Create the main UI
]]
function private.CreateUI()
    LA.Debug.Log("SessionHistoryUI: Creating UI")

    -- Main frame
    private.HISTORY_UI = AceGUI:Create("Frame")
    private.HISTORY_UI:SetTitle(LA.CONST.METADATA.NAME .. " - Session History")
    private.HISTORY_UI:SetLayout("Flow")
    private.HISTORY_UI:SetWidth(600)
    private.HISTORY_UI:SetHeight(450)
    private.HISTORY_UI:EnableResize(true)
    private.HISTORY_UI.frame:SetClampedToScreen(true)

    private.HISTORY_UI:SetCallback("OnClose", function(widget)
        -- Don't release, just hide
        private.HISTORY_UI:Hide()
    end)

    -- Button container (put buttons ABOVE the scroll so they always show)
    local buttonGroup = AceGUI:Create("SimpleGroup")
    buttonGroup:SetFullWidth(true)
    buttonGroup:SetLayout("Flow")
    private.HISTORY_UI:AddChild(buttonGroup)

    -- Export All button
    local btnExportAll = AceGUI:Create("Button")
    btnExportAll:SetText("Export All")
    btnExportAll:SetWidth(120)
    btnExportAll:SetCallback("OnClick",
                             function() private.ExportAllSessions() end)
    btnExportAll:SetCallback("OnEnter", function(widget)
        GameTooltip:SetOwner(widget.frame, "ANCHOR_TOP")
        GameTooltip:AddLine("Export All Sessions")
        GameTooltip:AddLine(
            "|cffffffffExport all session data (loot, kills, gold) to JSON|r")
        GameTooltip:Show()
    end)
    btnExportAll:SetCallback("OnLeave", function() GameTooltip:Hide() end)
    buttonGroup:AddChild(btnExportAll)

    -- Refresh button
    local btnRefresh = AceGUI:Create("Button")
    btnRefresh:SetText("Refresh")
    btnRefresh:SetWidth(100)
    btnRefresh:SetCallback("OnClick",
                           function() private.RefreshSessionList() end)
    buttonGroup:AddChild(btnRefresh)

    -- Save Current Session button
    local btnSaveCurrent = AceGUI:Create("Button")
    btnSaveCurrent:SetText("Save Current")
    btnSaveCurrent:SetWidth(120)
    btnSaveCurrent:SetCallback("OnClick", function()
        if LA.Session.IsRunning() then
            LA.SessionHistory.SaveCurrentSession()
            private.RefreshSessionList()
        else
            LA:Print("No active session to save.")
        end
    end)
    btnSaveCurrent:SetCallback("OnEnter", function(widget)
        GameTooltip:SetOwner(widget.frame, "ANCHOR_TOP")
        GameTooltip:AddLine("Save Current Session")
        GameTooltip:AddLine(
            "|cffffffffSave the current active session to history|r")
        GameTooltip:Show()
    end)
    btnSaveCurrent:SetCallback("OnLeave", function() GameTooltip:Hide() end)
    buttonGroup:AddChild(btnSaveCurrent)

    -- Session count label
    local countLabel = AceGUI:Create("Label")
    countLabel:SetText("")
    countLabel:SetWidth(150)
    buttonGroup:AddChild(countLabel)
    private.HISTORY_UI:SetUserData("countLabel", countLabel)

    -- Info label
    local infoLabel = AceGUI:Create("Label")
    infoLabel:SetText("|cffaaaaaa" ..
                          "Left-click to rename | Right-click to export JSON" ..
                          "|r")
    infoLabel:SetFullWidth(true)
    private.HISTORY_UI:AddChild(infoLabel)

    -- Scroll frame for session list (fills remaining space)
    local scrollContainer = AceGUI:Create("SimpleGroup")
    scrollContainer:SetFullWidth(true)
    scrollContainer:SetFullHeight(true)
    scrollContainer:SetLayout("Fill")
    private.HISTORY_UI:AddChild(scrollContainer)

    local scrollFrame = AceGUI:Create("ScrollFrame")
    scrollFrame:SetLayout("List")
    scrollContainer:AddChild(scrollFrame)

    private.HISTORY_UI:SetUserData("scrollFrame", scrollFrame)

    -- Populate the list
    private.RefreshSessionList()

    private.HISTORY_UI:Show()
end

--[[
    Refresh the session list
]]
function private.RefreshSessionList()
    LA.Debug.Log("SessionHistoryUI: Refreshing session list")

    if not private.HISTORY_UI then return end

    local scrollFrame = private.HISTORY_UI:GetUserData("scrollFrame")
    if not scrollFrame then return end

    -- Clear existing widgets
    scrollFrame:ReleaseChildren()
    private.sessionWidgets = {}

    -- Get sessions
    local sessions = LA.SessionHistory.GetAllSessions()

    -- Sort by start time, newest first
    local sortedSessions = {}
    for i, session in ipairs(sessions) do
        table.insert(sortedSessions, session)
    end
    sort(sortedSessions,
         function(a, b) return (a.startTime or 0) > (b.startTime or 0) end)

    -- Update count label
    local countLabel = private.HISTORY_UI:GetUserData("countLabel")
    if countLabel then
        countLabel:SetText("|cffffffff" .. #sortedSessions .. " session(s)|r")
    end

    -- Create widgets for each session
    for i, session in ipairs(sortedSessions) do
        private.CreateSessionRow(scrollFrame, session, i)
    end

    if #sortedSessions == 0 then
        local emptyLabel = AceGUI:Create("Label")
        emptyLabel:SetText("|cffaaaaaa" ..
                               "No sessions recorded yet. Sessions will appear here after you farm!" ..
                               "|r")
        emptyLabel:SetFullWidth(true)
        scrollFrame:AddChild(emptyLabel)
    end
end

--[[
    Create a row for a session
]]
function private.CreateSessionRow(parent, session, index)
    -- Session row container
    local rowGroup = AceGUI:Create("SimpleGroup")
    rowGroup:SetFullWidth(true)
    rowGroup:SetLayout("Flow")
    rowGroup:SetHeight(50)
    parent:AddChild(rowGroup)

    -- Alternate row colors
    local bgAlpha = (index % 2 == 0) and 0.1 or 0.05

    -- Session name/date
    local displayName = LA.SessionHistory.GetSessionDisplayName(session)

    local nameLabel = AceGUI:Create("InteractiveLabel")
    nameLabel:SetText("|cffffd100" .. displayName .. "|r")
    nameLabel:SetWidth(250)
    nameLabel:SetCallback("OnClick", function(widget, event, button)
        if button == "LeftButton" then
            private.ShowRenameDialog(session)
        elseif button == "RightButton" then
            private.ExportSingleSession(session)
        end
    end)
    nameLabel:SetCallback("OnEnter", function(widget)
        private.ShowSessionTooltip(widget, session)
    end)
    nameLabel:SetCallback("OnLeave", function() GameTooltip:Hide() end)
    rowGroup:AddChild(nameLabel)

    -- Duration
    local duration = LA.SessionHistory.FormatDuration(session.duration)
    local durationLabel = AceGUI:Create("Label")
    durationLabel:SetText("|cffffffff" .. duration .. "|r")
    durationLabel:SetWidth(80)
    rowGroup:AddChild(durationLabel)

    -- Total value
    local valueStr = LA.SessionHistory.FormatValue(session.totalValue)
    local valueLabel = AceGUI:Create("Label")
    valueLabel:SetText("|cffffd700" .. valueStr .. "|r")
    valueLabel:SetWidth(120)
    rowGroup:AddChild(valueLabel)

    -- Delete button
    local deleteBtn = AceGUI:Create("Button")
    deleteBtn:SetText("X")
    deleteBtn:SetWidth(45)
    deleteBtn:SetCallback("OnClick",
                          function() private.ConfirmDeleteSession(session) end)
    deleteBtn:SetCallback("OnEnter", function(widget)
        GameTooltip:SetOwner(widget.frame, "ANCHOR_TOP")
        GameTooltip:AddLine("Delete Session")
        GameTooltip:AddLine("|cff00ff00Click to delete this session|r")
        GameTooltip:Show()
    end)
    deleteBtn:SetCallback("OnLeave", function() GameTooltip:Hide() end)
    rowGroup:AddChild(deleteBtn)

    -- Store widget reference
    private.sessionWidgets[session.id] = rowGroup
end

--[[
    Show tooltip for a session
]]
function private.ShowSessionTooltip(widget, session)
    GameTooltip:SetOwner(widget.frame, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()

    GameTooltip:AddLine(LA.SessionHistory.GetSessionDisplayName(session))
    GameTooltip:AddLine(" ")

    -- Date/time info
    local startDate = date("%Y-%m-%d %H:%M:%S", session.startTime or 0)
    local endDate = date("%Y-%m-%d %H:%M:%S", session.endTime or 0)
    GameTooltip:AddDoubleLine("Started:", "|cffffffff" .. startDate .. "|r")
    GameTooltip:AddDoubleLine("Ended:", "|cffffffff" .. endDate .. "|r")
    GameTooltip:AddDoubleLine("Duration:", "|cffffffff" ..
                                  LA.SessionHistory
                                      .FormatDuration(session.duration) .. "|r")

    GameTooltip:AddLine(" ")

    -- Location info
    GameTooltip:AddDoubleLine("Zone:", "|cffffffff" ..
                                  (session.zoneName or "Unknown") .. "|r")
    GameTooltip:AddDoubleLine("Character:", "|cffffffff" ..
                                  (session.player or "Unknown") .. "|r")

    GameTooltip:AddLine(" ")

    -- Value info
    GameTooltip:AddDoubleLine("Total Value:", "|cffffd700" ..
                                  LA.SessionHistory
                                      .FormatValue(session.totalValue) .. "|r")
    if session.totalValueGroup and session.totalValueGroup > 0 then
        GameTooltip:AddDoubleLine("Group Value:", "|cffffd700" ..
                                      LA.SessionHistory
                                          .FormatValue(session.totalValueGroup) ..
                                      "|r")
    end
    if session.vendorSales and session.vendorSales > 0 then
        GameTooltip:AddDoubleLine("Vendor Sales:", "|cffffd700" ..
                                      LA.SessionHistory
                                          .FormatValue(session.vendorSales) ..
                                      "|r")
    end
    GameTooltip:AddDoubleLine("Item Count:",
                              "|cffffffff" .. (session.itemCount or 0) .. "|r")

    -- Kill stats
    local totalKills = session.totalKills or 0
    local uniqueKills = session.uniqueKills or 0
    if totalKills > 0 then
        GameTooltip:AddDoubleLine("Total Kills:",
                                  "|cffff4444" .. totalKills .. "|r")
        GameTooltip:AddDoubleLine("Unique NPCs:",
                                  "|cffff4444" .. uniqueKills .. "|r")

        -- Show top 5 killed NPCs
        local kills = session.kills
        if kills and next(kills) then
            local sorted = {}
            for npcID, data in pairs(kills) do
                sorted[#sorted + 1] = {name = data.name, count = data.count}
            end
            table.sort(sorted, function(a, b)
                return a.count > b.count
            end)

            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("|cffff8040Top Kills:|r")
            local maxShow = math.min(#sorted, 5)
            for i = 1, maxShow do
                GameTooltip:AddDoubleLine("  " .. sorted[i].name,
                                          "|cffffffff" .. "x" .. sorted[i].count ..
                                              "|r")
            end
            if #sorted > maxShow then
                GameTooltip:AddLine("  |cffaaaaaa..." .. (#sorted - maxShow) ..
                                        " more|r")
            end
        end
    end

    -- Settings
    if session.settings then
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Price Source:", "|cffaaaaaa" ..
                                      (session.settings.priceSource or "N/A") ..
                                      "|r")
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cff00ff00Left-click to rename|r")
    GameTooltip:AddLine("|cff00ff00Right-click to export JSON|r")

    GameTooltip:Show()
end

--[[
    Show rename dialog
]]
function private.ShowRenameDialog(session)
    LA.Debug.Log("SessionHistoryUI: Showing rename dialog for session " ..
                     session.id)

    -- Create a simple input dialog using AceGUI
    local renameFrame = AceGUI:Create("Frame")
    renameFrame:SetTitle("Rename Session")
    renameFrame:SetWidth(400)
    renameFrame:SetHeight(150)
    renameFrame:SetLayout("Flow")
    renameFrame:EnableResize(false)

    local currentName = session.name or
                            LA.SessionHistory.GetSessionDisplayName(session)

    local label = AceGUI:Create("Label")
    label:SetText("Enter a new name for this session:")
    label:SetFullWidth(true)
    renameFrame:AddChild(label)

    local editBox = AceGUI:Create("EditBox")
    editBox:SetText(currentName)
    editBox:SetFullWidth(true)
    editBox:SetCallback("OnEnterPressed", function(widget, event, text)
        if text and text ~= "" then
            LA.SessionHistory.RenameSession(session.id, text)
            LA:Print("Session renamed to: " .. text)
            private.RefreshSessionList()
        end
        renameFrame:Release()
    end)
    renameFrame:AddChild(editBox)

    local buttonGroup = AceGUI:Create("SimpleGroup")
    buttonGroup:SetFullWidth(true)
    buttonGroup:SetLayout("Flow")
    renameFrame:AddChild(buttonGroup)

    local btnSave = AceGUI:Create("Button")
    btnSave:SetText("Save")
    btnSave:SetWidth(100)
    btnSave:SetCallback("OnClick", function()
        local text = editBox:GetText()
        if text and text ~= "" then
            LA.SessionHistory.RenameSession(session.id, text)
            LA:Print("Session renamed to: " .. text)
            private.RefreshSessionList()
        end
        renameFrame:Release()
    end)
    buttonGroup:AddChild(btnSave)

    local btnCancel = AceGUI:Create("Button")
    btnCancel:SetText("Cancel")
    btnCancel:SetWidth(100)
    btnCancel:SetCallback("OnClick", function() renameFrame:Release() end)
    buttonGroup:AddChild(btnCancel)

    -- Focus the edit box
    editBox:SetFocus()
end

--[[
    Confirm and delete a session
]]
function private.ConfirmDeleteSession(session)
    local displayName = LA.SessionHistory.GetSessionDisplayName(session)

    StaticPopupDialogs["LA_DELETE_SESSION"] = {
        text = "Are you sure you want to delete this session?\n\n|cffffd100" ..
            displayName .. "|r",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            LA.SessionHistory.DeleteSession(session.id)
            LA:Print("Session deleted: " .. displayName)
            private.RefreshSessionList()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3
    }
    local popup = StaticPopup_Show("LA_DELETE_SESSION")
    if popup then popup:SetFrameStrata("FULLSCREEN_DIALOG") end
end

--[[
    Export a single session to JSON
]]
function private.ExportSingleSession(session)
    local json, err = LA.SessionHistory.ExportSessionToJSON(session.id)

    if not json then
        LA:Print("Export failed: " .. (err or "Unknown error"))
        return
    end

    private.ShowExportDialog(json,
                             LA.SessionHistory.GetSessionDisplayName(session))
end

--[[
    Export all sessions to JSON
]]
function private.ExportAllSessions()
    local json, err = LA.SessionHistory.ExportAllSessionsToJSON()

    if not json then
        LA:Print("Export failed: " .. (err or "No sessions to export"))
        return
    end

    private.ShowExportDialog(json, "All Sessions")
end

--[[
    Show export dialog with copyable text
]]
function private.ShowExportDialog(json, title)
    local exportFrame = AceGUI:Create("Frame")
    exportFrame:SetTitle("Export: " .. title)
    exportFrame:SetWidth(600)
    exportFrame:SetHeight(400)
    exportFrame:SetLayout("Fill")

    local editBox = AceGUI:Create("MultiLineEditBox")
    editBox:SetLabel("JSON Data (select all and copy with Ctrl+C):")
    editBox:SetText(json)
    editBox:SetFullWidth(true)
    editBox:SetFullHeight(true)
    editBox:DisableButton(true)
    exportFrame:AddChild(editBox)

    -- Select all text when focused
    editBox.editBox:SetScript("OnEditFocusGained",
                              function(self) self:HighlightText() end)

    -- Focus and select all
    C_Timer.After(0.1, function()
        editBox:SetFocus()
        editBox.editBox:HighlightText()
    end)

    LA:Print("JSON export ready. Select all and copy (Ctrl+A, Ctrl+C)")
end
