--[[
    Commands.lua
    Chat command handlers for LootAppraiser Reloaded
]]

local LA = select(2, ...)

local Commands = {}
LA.Commands = Commands

local private = {}

--[[
    Register all chat commands
    Called during addon initialization
]]
function Commands.Register()
    LA.Debug.Log("Commands.Register()")
    
    -- Register /lahistory command
    LA:RegisterChatCommand("lahistory", private.HandleHistoryCommand)
end

--[[
    Handle /lahistory command
    Usage:
        /lahistory - Open history UI
        /lahistory reset - Reset all session history
        /lahistory export - Export all sessions to CSV
        /lahistory save - Save current session to history
]]
function private.HandleHistoryCommand(input)
    LA.Debug.Log("HandleHistoryCommand: " .. tostring(input))
    
    local args = {}
    for word in (input or ""):gmatch("%S+") do
        table.insert(args, word:lower())
    end
    
    local subcommand = args[1]
    
    if not subcommand or subcommand == "" then
        -- Open history UI
        LA.SessionHistoryUI.Show()
        
    elseif subcommand == "reset" then
        -- Confirm and reset all sessions
        private.ConfirmReset()
        
    elseif subcommand == "export" then
        -- Export all sessions
        private.ExportAll()
        
    elseif subcommand == "save" then
        -- Save current session
        if LA.Session.IsRunning() then
            LA.SessionHistory.SaveCurrentSession()
        else
            LA:Print("No active session to save.")
        end
        
    elseif subcommand == "help" then
        private.ShowHelp()
        
    else
        LA:Print("Unknown subcommand: " .. subcommand)
        private.ShowHelp()
    end
end

--[[
    Show help for /lahistory command
]]
function private.ShowHelp()
    LA:Print("|cffffd100LootAppraiser Reloaded - Session History Commands:|r")
    LA:Print("  |cff00ff00/lahistory|r - Open session history window")
    LA:Print("  |cff00ff00/lahistory save|r - Save current session to history")
    LA:Print("  |cff00ff00/lahistory export|r - Export all sessions to CSV")
    LA:Print("  |cff00ff00/lahistory reset|r - Reset all session history")
    LA:Print("  |cff00ff00/lahistory help|r - Show this help")
end

--[[
    Confirm and reset all sessions
]]
function private.ConfirmReset()
    StaticPopupDialogs["LA_RESET_ALL_SESSIONS"] = {
        text = "|cffff0000Warning!|r\n\nThis will permanently delete ALL session history.\n\nAre you sure you want to continue?",
        button1 = "Yes, Reset All",
        button2 = "Cancel",
        OnAccept = function()
            local count = LA.SessionHistory.ResetAllSessions()
            LA:Print("Session history reset. Deleted " .. count .. " session(s).")
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3
    }
    StaticPopup_Show("LA_RESET_ALL_SESSIONS")
end

--[[
    Export all sessions to CSV
]]
function private.ExportAll()
    local csv, err = LA.SessionHistory.ExportAllSessionsToCSV()
    
    if not csv then
        LA:Print("Export failed: " .. (err or "No sessions to export"))
        return
    end
    
    -- Show export dialog
    local AceGUI = LibStub("AceGUI-3.0")
    
    local exportFrame = AceGUI:Create("Frame")
    exportFrame:SetTitle("Export All Sessions")
    exportFrame:SetWidth(600)
    exportFrame:SetHeight(400)
    exportFrame:SetLayout("Fill")
    
    local editBox = AceGUI:Create("MultiLineEditBox")
    editBox:SetLabel("CSV Data (select all and copy with Ctrl+C):")
    editBox:SetText(csv)
    editBox:SetFullWidth(true)
    editBox:SetFullHeight(true)
    editBox:DisableButton(true)
    exportFrame:AddChild(editBox)
    
    -- Select all text when focused
    editBox.editBox:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
    end)
    
    -- Focus and select all
    C_Timer.After(0.1, function()
        editBox:SetFocus()
        editBox.editBox:HighlightText()
    end)
    
    local sessionCount = LA.SessionHistory.GetSessionCount()
    LA:Print("Exported " .. sessionCount .. " session(s) to CSV. Select all and copy (Ctrl+A, Ctrl+C)")
end
