--[[
    LootAppraiserReloaded.lua
    Main addon bootstrap - wires together all modules via AceAddon lifecycle
    
    The actual logic lives in Core/ submodules:
        Core/API.lua            - Public API and module registration
        Core/Init.lua           - Database initialization and GetFromDb
        Core/MinimapIcon.lua    - DataBroker, minimap icon, addon compartment
        Core/PriceSources.lua   - Price source management and item value lookups
        Core/Events.lua         - WoW event handlers
        Core/LootProcessing.lua - Core loot item processing and notifications
        Core/Merchant.lua       - Vendor: sell grays, auto-repair
]] local LA = select(2, ...)

local AceGUI = LibStub("AceGUI-3.0")

-- Global loot manager object (used by LootManager.lua)
LOOTMANAGER = {}
LOOTMANAGER["ZoneLoc"] = ""
LOOTMANAGER["Player"] = ""
LOOTMANAGER["LootSession"] = ""
LOOTMANAGER["LootedItems"] = ""

--[[------------------------------------------------------------------------
    AceAddon-3.0: OnInitialize
--------------------------------------------------------------------------]]
function LA:OnInitialize()
    LA.Init.InitDB()

    LA.Debug.Log("LA:OnInitialize()")

    LA:SetSinkStorage(LA.db.profile.notification.sink)

    -- Set up minimap icon and data broker
    LA.MinimapIcon.SetupMinimapIcon()
    LA.MinimapIcon.SetupAddonCompartment()
    LA.MinimapIcon.SetupDataBroker()
end

--[[------------------------------------------------------------------------
    AceAddon-3.0: OnEnable
--------------------------------------------------------------------------]]
function LA:OnEnable()
    LA.PriceSources.Prepare()

    -- Register chat commands
    LA:RegisterChatCommand("la", function(input)
        if input == "freset" then LA.UI.ResetFrames() end
        if not LA.Session.IsRunning() then LA.Session.Start(true) end
        LA.UI.ShowMainWindow(true)
    end)
    LA:RegisterChatCommand("lal", function()
        if not LA.Session.IsRunning() then LA.Session.Start(false) end
        LA.UI.ShowLiteWindow()
    end)
    LA:RegisterChatCommand("laa", function()
        if not LA.Session.IsRunning() then LA.Session.Start(true) end
        LA.UI.ShowLastNoteworthyItemWindow()
    end)
    LA:RegisterChatCommand("lade", function()
        LA:Print(tostring(LA.GetFromDb("pricesource", "useDisenchantValue",
                                       "TSM_REQUIRED")))
    end)
    LA:RegisterChatCommand("laconfig", function()
        Settings.OpenToCategory(LA.CONST.METADATA.NAME)
        SettingsPanel.AddOnsTab:Click()
    end)
    LA.Commands.Register()

    -- Register events
    LA:RegisterEvent("CHAT_MSG_SYSTEM", LA.Events.OnResetInfoEvent)
    LA:RegisterEvent("CHAT_MSG_ADDON", LA.Events.OnChatMsgAddon)
    LA:RegisterEvent("CHAT_MSG_LOOT", LA.Events.OnChatMsgLoot)
    LA:RegisterEvent("CHAT_MSG_MONEY", LA.Events.OnChatMsgMoney)

    if LA.Util.IsModern then
        LA:RegisterEvent("TRADE_SKILL_ITEM_CRAFTED_RESULT",
                         LA.Events.OnTradeSkillCrafted)
    end

    if LA.Util.IsClassic then
        -- Kill tracking via combat log
        LA:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED",
                         LA.KillTracker.OnCombatLogEvent)
    end

    -- Register addon message prefix for group loot
    C_ChatInfo.RegisterAddonMessagePrefix(LA.CONST.PARTYLOOT_MSGPREFIX)

    -- Merchant events
    LA:RegisterEvent("MERCHANT_SHOW", LA.Merchant.OnShow)
    LA:RegisterEvent("MERCHANT_CLOSED", LA.Merchant.OnClose)
end

--[[------------------------------------------------------------------------
    Start session dialog (AceGUI - legacy prompt)
--------------------------------------------------------------------------]]
function LA:ShowStartSessionDialog()
    -- Auto-start
    if LA.GetFromDb("general", "autoStartLA") == true then
        LA.Debug.Log("auto-start LA enabled")
        LA.Session.Start(showMainUI)
        return
    end

    -- Suppressed
    if LA.GetFromDb("general", "surpressSessionStartDialog") == true then
        return
    end

    if START_SESSION_PROMPT then return end

    local openLootAppraiserReloaded = true

    START_SESSION_PROMPT = AceGUI:Create("Frame")
    START_SESSION_PROMPT:SetStatusTable(self.db.profile.startSessionPromptUI)
    START_SESSION_PROMPT:SetLayout("Flow")
    START_SESSION_PROMPT:SetTitle(
        "Would you like to start a LootAppraiser Reloaded session?")
    START_SESSION_PROMPT:SetPoint("CENTER")
    START_SESSION_PROMPT:SetWidth(250)
    START_SESSION_PROMPT:SetHeight(115)
    START_SESSION_PROMPT:EnableResize(false)
    START_SESSION_PROMPT:SetCallback("OnClose", function(widget)
        AceGUI:Release(widget)
        START_SESSION_PROMPT = nil
    end)

    local btnYes = AceGUI:Create("Button")
    btnYes:SetPoint("CENTER")
    btnYes:SetAutoWidth(true)
    btnYes:SetText("Yes ")
    btnYes:SetCallback("OnClick", function()
        LA:StartSession(openLootAppraiserReloaded)
        START_SESSION_PROMPT:Release()
        START_SESSION_PROMPT = nil
    end)
    START_SESSION_PROMPT:AddChild(btnYes)

    local btnNo = AceGUI:Create("Button")
    btnNo:SetPoint("CENTER")
    btnNo:SetAutoWidth(true)
    btnNo:SetText("No ")
    btnNo:SetCallback("OnClick", function()
        local curValue = LA.GetFromDb("general", "surpressSessionStartDialog")
        LA.db.profile.general.surpressSessionStartDialog = curValue
        START_SESSION_PROMPT:Release()
        START_SESSION_PROMPT = true
    end)
    START_SESSION_PROMPT:AddChild(btnNo)

    local checkboxOpenWindow = AceGUI:Create("CheckBox")
    checkboxOpenWindow:SetValue(openLootAppraiserReloaded)
    checkboxOpenWindow:SetLabel(" Open LootAppraiser Reloaded window")
    checkboxOpenWindow:SetCallback("OnValueChanged", function(value)
        openLootAppraiserReloaded = value.checked
    end)
    START_SESSION_PROMPT:AddChild(checkboxOpenWindow)

    START_SESSION_PROMPT.statustext:Hide()
end

--[[------------------------------------------------------------------------
    Legacy compatibility wrappers
    These maintain backward compatibility with older code and modules
--------------------------------------------------------------------------]]
LA.METADATA = {
    VERSION = "2018." ..
        (LA.CONST and LA.CONST.METADATA and LA.CONST.METADATA.VERSION or "0")
}
LA.QUALITY_FILTER = LA.CONST and LA.CONST.QUALITY_FILTER
LA.PRICE_SOURCE = LA.CONST and LA.CONST.PRICE_SOURCE

function LA:tablelength(t) return LA.Util.tablelength(t) end
function LA:print_r(t) LA.Debug.TableToString(t) end
function LA:D(msg, ...) LA.Debug.Log(msg, ...) end
function LA:getCurrentSession() return LA.Session.GetCurrentSession() end
function LA:StartSession(showMainUI) LA.Session.Start(showMainUI) end
function LA:ShowMainWindow(showMainUI) LA.UI.ShowMainWindow(showMainUI) end
function LA:NewSession() LA.Session.New() end
function LA:pauseSession() LA.Session.Pause() end
function LA:refreshStatusText() LA.UI.RefreshStatusText() end
