local LA = select(2, ...)

local UI = {}
LA.UI = UI

local private = {
    MAIN_UI = nil,
    LITE_UI = nil,
    TIMER_UI = nil,
    TIMER_UI_TAB = nil,
    LAST_NOTEWOTHYITEM_UI = nil,
    --        START_SESSION_PROMPT = nil
}
UI.b1 = nil -- private


local LibStub = LibStub
local LibToast = LibStub("LibToast-1.0")
local AceGUI = LibStub("AceGUI-3.0")
--local AceEvent = LibStub("AceEvent-3.0")

--AceEvent:Embed(UI)


-- wow api
local GetItemQualityColor, CreateFrame, UIFrameFadeOut, UIFrameFadeIn, IsShiftKeyDown, PlaySound, GameTooltip, GetBestMapForUnit, GetMapInfo, ResetInstances, IsInGroup, SendChatMessage, GetMerchantNumItems, GetMerchantItemInfo, GetContainerNumSlots, GetContainerItemLink, UseContainerItem, GetContainerItemID, PickupContainerItem, DeleteCursorItem, SecondsToTime =
GetItemQualityColor, CreateFrame, UIFrameFadeOut, UIFrameFadeIn, IsShiftKeyDown, PlaySound, GameTooltip, C_Map.GetBestMapForUnit, C_Map.GetMapInfo, ResetInstances, IsInGroup, SendChatMessage, GetMerchantNumItems, GetMerchantItemInfo, GetContainerNumSlots, GetContainerItemLink, UseContainerItem, GetContainerItemID, PickupContainerItem, DeleteCursorItem, SecondsToTime
local _G = _G

-- lua api
local pairs, tostring, string, time, table, select, date, sort, floor, tinsert =
pairs, tostring, string, time, table, select, date, sort, floor, table.insert


-- define toast template
LibToast:Register("LootAppraiser",
    function(toast, text, iconTexture, qualityID, amountGained, itemValue, source)
        local _, _, _, hex = GetItemQualityColor(qualityID)

        toast:SetFormattedTitle("|c%s%s|r %s", hex, text, amountGained and _G.PARENS_TEMPLATE:format(amountGained) or "")

        if source then
              -- party loot
              --LA:Print("party loot toast")
              toast:SetFormattedText("|cFF2DA6ED%s|r\n|cFFFFFFFF%s|r", source, itemValue)
        else
            toast:SetFormattedText("|cFFFFFFFF%s|r", itemValue)   
        end

        if iconTexture then
            toast:SetIconTexture(iconTexture)
        end
    end
)


-- the timer ui
local timerUItotal = 0
function UI.ShowTimerWindow()
    LA.Debug.Log("ShowTimerWindow")

    if private.TIMER_UI then
        private.TIMER_UI:Show()
        return
    end

    private.TIMER_UI = AceGUI:Create("LALiteWindow")
    private.TIMER_UI:Hide()

    private.TIMER_UI:SetTitle("|cffffffff" .. date("!%X", 0) .. "|r")
    private.TIMER_UI:SetStatusTable(LA.db.profile.timerUI)
    private.TIMER_UI:SetWidth(110)
    private.TIMER_UI:SetHeight(30)
    private.TIMER_UI.frame:SetScript("OnUpdate",
        function(event, elapsed)
            timerUItotal = timerUItotal + elapsed
            if timerUItotal >= 1 then
                UI.RefreshUIs()
                timerUItotal = 0
            end
        end
    )

    -- tab --
    private.TIMER_UI_TAB = CreateFrame("Frame", nil, private.TIMER_UI.frame)
    private.TIMER_UI_TAB.prevMouseIsOver = false
    private.TIMER_UI_TAB:SetSize(104, 47)
    private.TIMER_UI_TAB:SetPoint("BOTTOMLEFT", private.TIMER_UI.frame, "BOTTOMLEFT", 3, 3)
    private.TIMER_UI_TAB:SetScript("OnUpdate",
        function(self)
            if self.prevMouseIsOver then
                if ( not self:IsMouseOver() ) then
                    UIFrameFadeOut(private.TIMER_UI_TAB, CHAT_FRAME_FADE_TIME)
                    self.prevMouseIsOver = false
                end
            else
                if self:IsMouseOver() then
                    UIFrameFadeIn(private.TIMER_UI_TAB, CHAT_FRAME_FADE_TIME)
                    self.prevMouseIsOver = true
                end
            end
        end
    )
    UIFrameFadeOut(private.TIMER_UI_TAB, CHAT_FRAME_FADE_TIME);

    local l1 = private.TIMER_UI_TAB:CreateTexture(nil, "BACKGROUND")
    l1:SetTexture([[Interface\ChatFrame\ChatFrameTab]])
    l1:SetSize(7, 24)
    l1:SetPoint("TOPLEFT", private.TIMER_UI_TAB, "TOPLEFT", 26, 0)
    l1:SetTexCoord(0.03125, 0.140625, 0.28125, 1.0)

    local l2 = private.TIMER_UI_TAB:CreateTexture(nil, "BACKGROUND")
    l2:SetTexture([[Interface\ChatFrame\ChatFrameTab]])
    l2:SetSize(31, 24)
    l2:SetPoint("LEFT", l1, "RIGHT")
    l2:SetTexCoord(0.140625, 0.859375, 0.28125, 1.0)

    local l3 = private.TIMER_UI_TAB:CreateTexture(nil, "BACKGROUND")
    l3:SetTexture([[Interface\ChatFrame\ChatFrameTab]])
    l3:SetSize(7, 24)
    l3:SetPoint("LEFT", l2, "RIGHT")
    l3:SetTexCoord(0.859375, 0.96875, 0.28125, 1.0)

    LA.UI.b1 = CreateFrame("Button", nil, private.TIMER_UI_TAB)
    LA.UI.b1:SetSize(20, 20)
    if LA.Session.GetPauseStart() then
        LA.UI.b1:SetNormalTexture([[Interface\Buttons\UI-SpellbookIcon-NextPage-Up]])
    else
        LA.UI.b1:SetNormalTexture([[Interface\TimeManager\PauseButton]])
    end
    LA.UI.b1:SetHighlightTexture([[Interface\Buttons\UI-Common-MouseHilight]], "ADD")
    LA.UI.b1:SetPoint("BOTTOMLEFT", l1, "BOTTOMLEFT", 4, 1)
    LA.UI.b1:SetScript("OnClick",
        function (self)
            --LA.Debug.Log("  LA.UI.b1")
            if LA.Session.GetPauseStart() then
                LA.UI.b1:SetNormalTexture([[Interface\Buttons\UI-SpellbookIcon-NextPage-Up]])
--                private.OnBtnStartSessionClick()
                LA.Session.Restart()
            else
                LA.UI.b1:SetNormalTexture([[Interface\TimeManager\PauseButton]])
                --private.OnBtnStopSessionClick()
                LA.Session.Pause()
            end
        end
    )

    local b2 = CreateFrame("Button", nil, private.TIMER_UI_TAB)
    b2:SetSize(20, 20)
    b2:SetNormalTexture([[Interface\TimeManager\ResetButton]])
    b2:SetHighlightTexture([[Interface\Buttons\UI-Common-MouseHilight]], "ADD")
    b2:SetPoint("LEFT", LA.UI.b1, "RIGHT", -2, 0)
    b2:SetScript("OnClick",
        function (self)
            --LA.Debug.Log("  b2")
            LA.Session.New()
        end
    )

    private.TIMER_UI:Show()
end

-- the last noteworthy item ui
function UI.ShowLastNoteworthyItemWindow()
    LA.Debug.Log("ShowLastNoteworthyItemWindow")


    if private.LAST_NOTEWOTHYITEM_UI then
        private.LAST_NOTEWOTHYITEM_UI:Show()
        return
    end

    private.LAST_NOTEWOTHYITEM_UI = AceGUI:Create("LALiteWindow")
    private.LAST_NOTEWOTHYITEM_UI:Hide()
    private.LAST_NOTEWOTHYITEM_UI:SetStatusTable(LA.db.profile.lastNotewothyItemUI)
    private.LAST_NOTEWOTHYITEM_UI:SetWidth(350)
    private.LAST_NOTEWOTHYITEM_UI:SetHeight(30)
    private.LAST_NOTEWOTHYITEM_UI:SetTitle("Gold Alert Threshold")
    private.LAST_NOTEWOTHYITEM_UI:Show()
	
end

-- the lite ui
function UI.ShowLiteWindow()
    LA.Debug.Log("ShowLiteWindow")


    if private.LITE_UI then
        private.LITE_UI:Show()
        return
    end

    private.LITE_UI = AceGUI:Create("LALiteWindow")
    private.LITE_UI:Hide()
    private.LITE_UI:SetStatusTable(LA.db.profile.liteUI)
    private.LITE_UI:SetWidth(150)
    private.LITE_UI:SetHeight(30)
    --private.LITE_UI:EnableResize(false)
    local totalItemValue = LA.Session.GetCurrentSession("liv") or 0
    private.LITE_UI:SetTitle("|cffffffff" .. LA.Util.MoneyToString(totalItemValue) .. "|r")
    private.LITE_UI:Show()
    local totalItemValue = LA.Session.GetCurrentSession("liv") or 0
end


function pickupDragMovement()
	LA.Debug.Log("dragging in progress")
end


-- the main ui
local additionalButtonHeight = 0
local mainUItotal = 0
function UI.ShowMainWindow(showMainUI)
    LA.Debug.Log("ShowMainWindow")

    if private.MAIN_UI and showMainUI then
        private.MAIN_UI:Show()				

        if LA.GetFromDb("display", "enableLootAppraiserLite") then
            LA.UI.ShowLiteWindow()
        end

        if LA.GetFromDb("display", "enableLastNoteworthyItemUI") then
            LA.UI.ShowLastNoteworthyItemWindow()
        end

        if LA.GetFromDb("display", "enableLootAppraiserTimerUI") then
            LA.UI.ShowTimerWindow()
        end
		
		--code here to detect if button is enabled/disabled
		return
    end


    --private.MAIN_UI = AceGUI:Create("Window")
	private.MAIN_UI = AceGUI:Create("Frame")
    private.MAIN_UI:Hide()
    private.MAIN_UI:SetStatusTable(LA.db.profile.mainUI)
    private.MAIN_UI:SetTitle(LA.CONST.METADATA.NAME .. " " .. LA.CONST.METADATA.VERSION .. ": Make Farming Sexy!")
    private.MAIN_UI:SetLayout("Flow")
    private.MAIN_UI:SetWidth(450)   --changed from 410 to support ElvUI.
	private.MAIN_UI:EnableResize(false)
    private.MAIN_UI.frame:SetClampedToScreen(true)


	
    private.MAIN_UI.frame:SetScript("OnUpdate",
        function(event, elapsed)
            mainUItotal = mainUItotal + elapsed
            if mainUItotal >= 1 then
                UI.RefreshUIs()
                mainUItotal = 0

                -- set text
                local buttonresetInstance = private.MAIN_UI:GetUserData("button_resetInstance")
                if buttonresetInstance then
                    private.resetInfo = private.resetInfo or {}

                    buttonresetInstance:SetText("Reset Instances (" .. LA.Util.tablelength(private.resetInfo) .. "/9)")
                end
            end
        end
    )
	

	
    private.MAIN_UI:SetCallback("OnClose",
        function(widget, event)
            --LA.Debug.Log("Session ended")
        end
    )



    -- START: statustext
    --local statusbg = CreateFrame("Button", nil, private.MAIN_UI.frame)
	
	--added to support 9.0 version and changes to Frames 10.14.2020
	local statusbg = CreateFrame("Button", nil, private.MAIN_UI.frame, BackdropTemplateMixin and "BackdropTemplate" or nil)	
	statusbg:SetPoint("BOTTOMLEFT", private.MAIN_UI.frame, "BOTTOMLEFT", 5, 3)
    statusbg:SetPoint("BOTTOMRIGHT", private.MAIN_UI.frame, "BOTTOMRIGHT", -2, 3)
    statusbg:SetHeight(0)
	statusbg:SetBackdrop({
    bgFile = "Interface\\PaperDollInfoFrame\\UI-GearManager-Title-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 32, edgeSize = 16,
    insets = { left = 3, right = 3, top = 5, bottom = 3 }
	
    })

	statusbg:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
	statusbg:SetBackdropBorderColor(0.4, 0.4, 0.4, x)    


	local statustext = statusbg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statustext:SetPoint("TOPLEFT", 7, -2)
    statustext:SetPoint("BOTTOMRIGHT", -7, 2)
    statustext:SetHeight(20)
    statustext:SetJustifyH("LEFT")
    statustext:SetText("")
    private.MAIN_UI:SetUserData("data_statustext", statustext)


    UI.RefreshStatusText()
    -- START: statustext

    -- loot collected list --
    local backdrop = {
        --bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
		--edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 2,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    }

    local lootCollectedContainer = AceGUI:Create("SimpleGroup")
    lootCollectedContainer:SetFullWidth(true)
    lootCollectedContainer:SetHeight(150)
    lootCollectedContainer:SetLayout("Fill")
    --lootCollectedContainer.frame:SetBackdrop(backdrop)
	--lootCollectedContainer.frame:SetBackdrop(backdrop)
    --lootCollectedContainer.frame:SetBackdropColor(0, 0, 0)
    --lootCollectedContainer.frame:SetBackdropBorderColor(0.4, 0.4, 0.4)

    local lootCollectedUI = AceGUI:Create("ScrollFrame")
    lootCollectedUI:SetLayout("Flow")
    lootCollectedContainer:AddChild(lootCollectedUI)
    private.MAIN_UI:AddChild(lootCollectedContainer)

    private.MAIN_UI:SetUserData("data_lootCollectedContainer", lootCollectedContainer)
    private.MAIN_UI:SetUserData("data_lootCollected", lootCollectedUI)

    --addSpacer(MAIN_UI)

    local dataContainer = AceGUI:Create("SimpleGroup")
    dataContainer:SetLayout("flow")
    dataContainer:SetFullWidth(true)
    private.MAIN_UI:AddChild(dataContainer)

    private.MAIN_UI:SetUserData("data_container", dataContainer)


    -- data rows
    LA.UI.PrepareDataContainer(private.MAIN_UI)
    private.AddSpacer(private.MAIN_UI)



	-- button sell trash --
    local showSellTrashBtn = LA.GetFromDb("display", "showSellTrashBtn")
		if showSellTrashBtn == false then
			LA.Debug.Log("Show Sell Trash Button = disabled")
		else
			local BUTTON_SELLTRASH = AceGUI:Create("Button")
			BUTTON_SELLTRASH:SetAutoWidth(true)
			BUTTON_SELLTRASH:SetText("Sell Trash")
			BUTTON_SELLTRASH:SetCallback("OnClick", function()
			private.OnBtnSellTrashClick()
			end)

    private.MAIN_UI:AddChild(BUTTON_SELLTRASH)
		end
	-- button trash grays --
    local showDetroyTrashBtn = LA.GetFromDb("display", "showDetroyTrashBtn")
		if showDetroyTrashBtn == false then
			LA.Debug.Log("Show Delete Trash Button = disabled")
		else
			local BUTTON_DESTROYTRASH = AceGUI:Create("Button")
			BUTTON_DESTROYTRASH:SetAutoWidth(true)
			BUTTON_DESTROYTRASH:SetText("Destroy Trash")
			BUTTON_DESTROYTRASH:SetCallback("OnClick", function()
			private.OnBtnDestroyTrashClick()
			end)
			private.MAIN_UI:AddChild(BUTTON_DESTROYTRASH)
	end
	
    -- button new session --
    local BUTTON_NEWSESSION = AceGUI:Create("Button")
    BUTTON_NEWSESSION:SetAutoWidth(true)
    BUTTON_NEWSESSION:SetText("New Session")
    BUTTON_NEWSESSION:SetCallback("OnClick", function()
        if IsShiftKeyDown() then
            LA.Session.New()
        else
            PlaySound(SOUNDKIT.UI_TOYBOX_TABS, "master");
        end
    end)
    BUTTON_NEWSESSION:SetCallback("OnEnter",
        function()
            -- prepare tooltip
            GameTooltip:ClearLines()
            GameTooltip:SetOwner(private.MAIN_UI.frame, "ANCHOR_CURSOR")  -- LootAppraiser.GUI is the AceGUI-Frame but we need the real frame
            GameTooltip:AddLine("New Session")
            GameTooltip:AddLine("|cffffffffHold 'shift' and click the|r")
            GameTooltip:AddLine("|cffffffffbutton to start a new session|r")
            GameTooltip:Show()
        end
    )
    BUTTON_NEWSESSION:SetCallback("OnLeave",
        function()
            GameTooltip:Hide()
        end
    )
    private.MAIN_UI:AddChild(BUTTON_NEWSESSION)

    -- button stop session --
    local buttonStopSession = AceGUI:Create("Button")
    buttonStopSession:SetAutoWidth(true)
    if LA.Session.IsRunning() then
        buttonStopSession:SetText("Stop")
        buttonStopSession:SetCallback("OnClick", function()
            --private.OnBtnStopSessionClick()
            LA.Session.Pause()
        end)
    else
        buttonStopSession:SetText("Restart")
        buttonStopSession:SetCallback("OnClick", function()
--            private.OnBtnStartSessionClick()
            LA.Session.Restart()
        end)
    end
    private.MAIN_UI:AddChild(buttonStopSession)

    private.MAIN_UI:SetUserData("button_stopSession", buttonStopSession)

    -- button reset instances --
    if LA.GetFromDb("display", "showResetInstanceButton") then
        private.resetInfo = private.resetInfo or {}

	
			local buttonResetInstance = AceGUI:Create("Button")
			buttonResetInstance:SetAutoWidth(true)
			buttonResetInstance:SetText("Reset Instances (" .. LA.Util.tablelength(private.resetInfo) .. "/9)") -- add lockouts
			buttonResetInstance:SetCallback("OnClick",
            function()
                private.OnBtnResetInstancesClick()
            end
			)
			buttonResetInstance:SetCallback("OnEnter",
            function()
                -- remove old entries
                local copy = {}
                for k, data in pairs(private.resetInfo) do
                    if data.endTime >= time() then
                        copy[k] = data
                    end
                end

                private.resetInfo = copy

                -- sort list
                sort(private.resetInfo,
                    function(a, b)
					LA.Debug.Log("ResetInstance a: " .. tostring(a))
					LA.Debug.Log("ResetInstance b: " .. tostring(b))
                        return a.endTime < b.endTime
                    end
                )

                -- prepare tooltip
                GameTooltip:ClearLines()
                GameTooltip:SetOwner(private.MAIN_UI.frame, "ANCHOR_CURSOR")  -- LootAppraiser.GUI is the AceGUI-Frame but we need the real frame

                GameTooltip:AddLine("Instance lockouts")
                if LA.Util.tablelength(private.resetInfo) > 0 then
                    for k, data in pairs(private.resetInfo) do
                        GameTooltip:AddDoubleLine("|cffffffff" .. data.instanceName .. "|r", "|cffffffff" .. date("!%X", data.endTime - time()) .. "|r")
                    end
                else
                    GameTooltip:AddLine("|cffffffffNone|r")
                end

                GameTooltip:Show()
            end
        )
			buttonResetInstance:SetCallback("OnLeave",
            function()
                GameTooltip:Hide()
            end
        )
        private.MAIN_UI:AddChild(buttonResetInstance)

        private.MAIN_UI:SetUserData("button_resetInstance", buttonResetInstance)

        additionalButtonHeight = 25
	
	end

    -- adjust height
    local baseHeight = 112

    local rowCount = LA.db.profile.display.lootedItemListRowCount or 5
    local listHeight = rowCount * 15

    local dataContainerHeight = dataContainer.frame:GetHeight()

    private.MAIN_UI:SetHeight(baseHeight + listHeight + additionalButtonHeight + dataContainerHeight)

    if showMainUI then
        private.MAIN_UI:Show()

        if LA.GetFromDb("display", "enableLootAppraiserLite") then
            LA.UI.ShowLiteWindow()
        end

        if LA.GetFromDb("display", "enableLastNoteworthyItemUI") then
            LA.UI.ShowLastNoteworthyItemWindow()
        end

        if LA.GetFromDb("display", "enableLootAppraiserTimerUI") then
            LA.UI.ShowTimerWindow()
        end
    end
end

-- prepare the data container with the current configuration
function UI.PrepareDataContainer(parent)
    LA.Debug.Log("prepareDataContainer")

    if not LA.Session.GetCurrentSession() then return end

    if not parent then parent = private.MAIN_UI end

    -- release data container widgets
    local dataContainer = parent:GetUserData("data_container")
    if dataContainer then
        dataContainer:ReleaseChildren()
    end

    -- resize
    local lootCollectedContainerUI = private.MAIN_UI:GetUserData("data_lootCollectedContainer")
    if lootCollectedContainerUI then
        local rowCount = LA.db.profile.display.lootedItemListRowCount or 5
        lootCollectedContainerUI:SetHeight(rowCount * 15)
    end

    -- prepare data container with current rows

    -- zone and session duration
    local labelWidth = 209
    local valueWidth = 166

    local grp = AceGUI:Create("SimpleGroup")
    grp:SetLayout("flow")
    grp:SetFullWidth(true)
    dataContainer:AddChild(grp)

    -- add zone...
    local currentMapID = GetBestMapForUnit("player")
    local zoneInfo = GetMapInfo(currentMapID)
    zoneInfo = zoneInfo and zoneInfo.name

    local valueZone = AceGUI:Create("LALabel")
    valueZone:SetWordWrap(false)
    valueZone:SetText(zoneInfo)
    valueZone:SetWidth(labelWidth) -- TODO
    valueZone:SetJustifyH("LEFT")
    grp:AddChild(valueZone)
    parent:SetUserData("data_zone", valueZone)

    -- ...and session duration
    local sessionDuration = AceGUI:Create("LALabel")
    sessionDuration:SetText("not running")
    sessionDuration:SetWidth(valueWidth) -- TODO
    sessionDuration:SetJustifyH("RIGHT")
    grp:AddChild(sessionDuration)
    parent:SetUserData("data_sessionDuration", sessionDuration)

    -- ...looted item value (with liv/h)
    local totalItemValue = LA.Session.GetCurrentSession("liv") or 0
    local livValue = LA.Util.MoneyToString(totalItemValue)
    if LA.GetFromDb("display", "showXXXLootedItemValuePerHour") then
        livValue = livValue .. " (0|cffffd100|r g/h)"
    end

    local lootedItemValue = private.DefineRowForFrame(dataContainer, "showLootedItemValue", "Looted Item Value:", livValue)
    parent:SetUserData("data_lootedItemValue", lootedItemValue)

---------------------------------------------------------------------	
-- Added vendor sales from gray items
---------------------------------------------------------------------
	-- ...vendor sales value
    local formattedTotalLootedCurrency2 = LA.Util.MoneyToString(LA.Session.GetCurrentSession("vendorSoldCurrencyUI") or 0)
    local lootedVendorUI = private.DefineRowForFrame(dataContainer, "showValueSoldToVendor", "Gray Vendor Sales: ", formattedTotalLootedCurrency2)
    parent:SetUserData("data_vendorSoldCurrency", lootedVendorUI)

---------------------------------------------------------------------
---------------------------------------------------------------------	
	
    -- ...looted currency
    local formattedTotalLootedCurrency = LA.Util.MoneyToString(LA.Session.GetCurrentSession("totalLootedCurrency") or 0)
    local lootedCurrencyUI = private.DefineRowForFrame(dataContainer, "showCurrencyLooted", "Currency Looted:", formattedTotalLootedCurrency)
    parent:SetUserData("data_lootedCurrency", lootedCurrencyUI)

    -- ...looted item counter
    local lootedItemCounterUI = private.DefineRowForFrame(dataContainer, "showItemsLooted", "Items Looted:", LA.Session.GetCurrentSession("lootedItemCounter") or 0)
    parent:SetUserData("data_lootedItemCounter", lootedItemCounterUI)

    -- ...noteworthy item counter
    local noteworthyItemCounterUI = private.DefineRowForFrame(dataContainer, "showNoteworthyItems", "Noteworthy Items:", LA.Session.GetCurrentSession("noteworthyItemCounter") or 0)
    parent:SetUserData("data_noteworthyItemCounter", noteworthyItemCounterUI)
    -- group loot

    -- ...looted item value (with liv/h)
    local totalItemValueGroup = LA.Session.GetCurrentSession("livGroup") or 0
    local livValueGroup = LA.Util.MoneyToString(totalItemValueGroup)
    if LA.GetFromDb("display", "showLootedItemValueGroupPerHour") then
        livValueGroup = livValueGroup .. " (0|cffffd100|r g/h)"
    end

    local lootedItemValueGroupUI = private.DefineRowForFrame(dataContainer, "showLootedItemValueGroup", "|cFF2DA6EDGroup:|r Looted Item Value:", livValueGroup)
    parent:SetUserData("data_lootedItemValueGroup", lootedItemValueGroupUI)

    -- and re-layout
    private.MAIN_UI:DoLayout()

    -- adjust height
    local baseHeight = 112

    local rowCount = LA.db.profile.display.lootedItemListRowCount or 5
    local listHeight = rowCount * 15

    local dataContainerHeight = dataContainer.frame:GetHeight()

    private.MAIN_UI:SetHeight(baseHeight + listHeight + additionalButtonHeight + dataContainerHeight)
end

-- refresh the status bar with the current settings
function UI.RefreshStatusText()
    if private.MAIN_UI ~= nil then
        -- prepare status text
        local priceSourceAsText = LA.availablePriceSources[LA.db.profile.pricesource.source] or "undefined"    
		local preparedText = LA.CONST.QUALITY_FILTER[tostring(LA.GetFromDb("notification", "qualityFilter"))] 						-- filter
		preparedText = preparedText .. "|cffffffff | " .. priceSourceAsText or tostring(LA.db.profile.pricesource.source)	-- price source
        private.MAIN_UI:SetStatusText(preparedText)
    end
end

-- refresh the main ui
function UI.RefreshUIs()
    --LA.Debug.Log("refreshUIs")

    -- session duration
    local sessionDurationUI = private.MAIN_UI:GetUserData("data_sessionDuration")
    if LA.Session.IsRunning() then
        local offset = LA.Session.GetPauseStart() or time()
        local delta = offset - LA.Session.GetCurrentSession("start") - LA.Session.GetSessionPause()

        -- don't show seconds
        local noSeconds = false
        if delta > 3600 then
            noSeconds = true
        end

        if LA.Session.GetPauseStart() then
            if time() % 2 == 0 then
                sessionDurationUI:SetText(" " .. SecondsToTime(delta, noSeconds, false))
            else
                sessionDurationUI:SetText(" ")
            end
        else
            sessionDurationUI:SetText(" " .. SecondsToTime(delta, noSeconds, false))
        end

        -- timer ui
        if private.TIMER_UI then
            if LA.Session.GetPauseStart() then
                if time() % 2 == 0 then
                    private.TIMER_UI:SetTitle("|cffffffff" .. date("!%X", delta) .. "|r")
                else
                    private.TIMER_UI:SetTitle(" ")
                end
            else
                private.TIMER_UI:SetTitle("|cffffffff" .. date("!%X", delta) .. "|r")
            end
        end
    else
        sessionDurationUI:SetText("not running")

        if private.TIMER_UI then
            private.TIMER_UI:SetTitle("|cffffffff" .. date("!%X", 0) .. "|r")
        end
    end

    -- zone info
    local zoneUI = private.MAIN_UI:GetUserData("data_zone")
    if zoneUI then
        -- current zone
        local currentMapID = GetBestMapForUnit("player")
        if currentMapID then
            local zoneInfo = GetMapInfo(currentMapID)
            zoneInfo = zoneInfo and zoneInfo.name

            zoneUI:SetText(zoneInfo)
        end
    end

    -- looted item value
    local lootedItemValueUI = private.MAIN_UI:GetUserData("data_lootedItemValue")
    if LA.GetFromDb("display", "showLootedItemValue") and lootedItemValueUI then
        local totalItemValue = LA.Session.GetCurrentSession("liv") or 0
        local livValue = LA.Util.MoneyToString(totalItemValue)
        if LA.GetFromDb("display", "showXXXLootedItemValuePerHour") then
            livValue = livValue .. " (" .. private.CalcLootedItemValuePerHour("liv") .. "|cffffd100|r g/h)"
        end

        -- add to main ui
        lootedItemValueUI:SetText(livValue)
    end

    -- currency looted
    local currencyLootedUI = private.MAIN_UI:GetUserData("data_lootedCurrency")
    if LA.GetFromDb("display", "showCurrencyLooted") == true and currencyLootedUI then
        -- format the total looted currency and add to main ui
        local formattedValue = LA.Util.MoneyToString(LA.Session.GetCurrentSession("totalLootedCurrency") or 0)
        currencyLootedUI:SetText(formattedValue)
    end



    -- vendor sold grays
    local currencyLootedUI2 = private.MAIN_UI:GetUserData("data_vendorSoldCurrency")
    if LA.GetFromDb("display", "showValueSoldToVendor") == true and currencyLootedUI2 then
        -- format the total looted currency and add to main ui
        local formattedValue2 = LA.Util.MoneyToString(LA.Session.GetCurrentSession("vendorSoldCurrencyUI") or 0)
        currencyLootedUI2:SetText(formattedValue2)
    end
	
	
    -- vendor sold grays
    --local vendorSoldCurrencyUI = private.MAIN_UI:GetUserData("vendorSoldCurrencyUI")
--	local currentVendorSales = LA.Session.GetCurrentSession("vendorSoldCurrencyUI") or 0)
    --if LA.GetFromDb("display", "showValueSoldToVendor") then

    -- format the total looted currency and add to main ui
      --  local formattedValue = LA.Util.MoneyToString(LA.Session.GetCurrentSession("vendorSoldCurrencyUI") or 0)
        --vendorSoldCurrencyUI:SetText(formattedValue)
    --end

	
	
	

    -- looted item counter
    local lootedItemCounterUI = private.MAIN_UI:GetUserData("data_lootedItemCounter")
    if LA.GetFromDb("display", "showItemsLooted") and lootedItemCounterUI then
        -- add to main ui
        lootedItemCounterUI:SetText(LA.Session.GetCurrentSession("lootedItemCounter") or 0)
    end

    -- noteworthy item counter
    local noteworthyItemCounterUI = private.MAIN_UI:GetUserData("data_noteworthyItemCounter")
    if LA.GetFromDb("display", "showNoteworthyItems") and noteworthyItemCounterUI then
        -- add to main ui
        noteworthyItemCounterUI:SetText(LA.Session.GetCurrentSession("noteworthyItemCounter") or 0)
    end

    -- group: looted item value
    local lootedItemValueGroupUI = private.MAIN_UI:GetUserData("data_lootedItemValueGroup")
    if LA.GetFromDb("display", "showLootedItemValueGroup") and lootedItemValueGroupUI then
        local totalItemValueGroup = LA.Session.GetCurrentSession("livGroup") or 0
        local livValueGroup = LA.Util.MoneyToString(totalItemValueGroup)
        if LA.GetFromDb("display", "showLootedItemValueGroupPerHour") then
            livValueGroup = livValueGroup .. " (" .. private.CalcLootedItemValuePerHour("livGroup") .. "|cffffd100|r g/h)"
        end

        -- add to main ui
        lootedItemValueGroupUI:SetText(livValueGroup)
    end

    -- looted item value (on lite ui)
	if UI.LITE_UI then
		local totalItemValue = LA.Session.GetCurrentSession("liv") or 0
		--private.LITE_UI:SetTitle("|cffffffff" .. LA.Util.MoneyToString(totalItemValue or 0) .. "|r")
		private.LITE_UI:SetTitle("|cffffffff" .. LA.Util.MoneyToString(totalItemValue or 0) .. "|r")
		
		
	end
	
	
	--[[
    if LA.GetFromDb("display", "enableLootAppraiserLite") then
        if private.LITE_UI then
            local totalItemValue = LA.Session.GetCurrentSession("liv") or 0
            private.LITE_UI:SetTitle(LA.Util.MoneyToString(totalItemValue))
        end
    end
	--]]

    -- main ui: button 'stop' session
    local buttonStopSessionUI = private.MAIN_UI:GetUserData("button_stopSession")
    if buttonStopSessionUI then
        if LA.Session.IsPaused() then
            buttonStopSessionUI:SetText("Restart")
            buttonStopSessionUI:SetCallback("OnClick", function()
                LA.Session.Restart()
            end)
        else
            buttonStopSessionUI:SetText("Stop")
            buttonStopSessionUI:SetCallback("OnClick", function()
                LA.Session.Pause()
            end)
        end
    end

    -- timer ui: button 'stop' session
    if LA.UI.b1 then
--        LA.Debug.Log("#### IsPaused=%s", tostring(LA.Session.IsPaused()))
        if LA.Session.IsPaused() then
            LA.UI.b1:SetNormalTexture([[Interface\Buttons\UI-SpellbookIcon-NextPage-Up]])
            LA.UI.b1:SetScript("OnClick", function()
                LA.Session.Restart()
            end)
        else
            LA.UI.b1:SetNormalTexture([[Interface\TimeManager\PauseButton]])
            LA.UI.b1:SetScript("OnClick", function()
                LA.Session.Pause()
            end)
        end
    end
end

function UI.AddToResetInfo(data)
    if not private.MAIN_UI then return end

    private.resetInfo = private.resetInfo or {}

    tinsert(private.resetInfo, data)

    local buttonresetInstance = private.MAIN_UI:GetUserData("button_resetInstance")
    if buttonresetInstance then
        buttonresetInstance:SetText("Reset Instances (" .. LA.Util.tablelength(private.resetInfo) .. "/9)") -- add lockouts
    end
end

function UI.UpdateLastNoteworthyItemUI(itemLink, quantity, singleItemValue, formattedValue)

	if private.LAST_NOTEWOTHYITEM_UI then
        local qtyValue = 0
		if tonumber(quantity) > 1 then
			qtyValue = tonumber(singleItemValue) * tonumber(quantity)
			local formattedItemValue = LA.Util.MoneyToString(qtyValue) or 0
			private.LAST_NOTEWOTHYITEM_UI:SetTitle(itemLink .. "|cffffffff x" .. quantity .. ": " .. formattedItemValue .. "|r")				
		else
			private.LAST_NOTEWOTHYITEM_UI:SetTitle(itemLink .. "|cffffffff x" .. quantity .. ": " .. formattedValue .. "|r")
		end

    end

end

function UI.UpdateLiteWindowUI(formattedValue)
	if private.LITE_UI then
	    local totalItemValue = LA.Session.GetCurrentSession("liv") or 0
		--LA.Debug.Log("LIV: " .. tostring(totalItemValue))
		private.LITE_UI:SetTitle("|cffffffff" .. LA.Util.MoneyToString(totalItemValue) .. "|r")
		LA.Debug.Log("Updating LA Lite value: " .. tostring(totalItemValue))
    end
end

-- add a given item to the top of the loot colletced list
function UI.AddItem2LootCollectedList(itemID, link, quantity, marketValue, noteworthyItemFound, source, disenchanted)
    --LA.Debug.Log("addItem2LootCollectedList(itemID=" .. itemID .. ", link=" .. tostring(link) .. ", quantity=" .. quantity .. ")")

    if source and not LA.GetFromDb("display", "addGroupDropsToLootedItemList") then
        return
    end

    -- prepare text
    local formattedItemValue = LA.Util.MoneyToString(marketValue) or 0
    local preparedText = " " .. link .. " x" .. quantity .. ": " .. formattedItemValue

	--Updated to support quantity
	if tonumber(quantity) > 1 then
		local qtyFormattedItemValue = 0
		qtyFormattedItemValue = marketValue * tonumber(quantity)
		formattedItemValue = LA.Util.MoneyToString(qtyFormattedItemValue) or 0
		preparedText = " " .. link .. " x" .. quantity .. ": " .. formattedItemValue
	end

    -- append (de) at the end for disenchant value indicator if selected
    if disenchanted then
        preparedText = preparedText .. " (de)"
    end

    -- append source
    if source then
        preparedText = preparedText .. " (|cFF2DA6ED" .. source .. "|r)"
    end

    -- item / link
    local LABEL = AceGUI:Create("InteractiveLabel")
    LABEL.frame:Hide()
    LABEL:SetText(preparedText)
    LABEL.label:SetJustifyH("LEFT")
    LABEL:SetWidth(350)
    LABEL:SetCallback("OnEnter",
        function()
            GameTooltip:SetOwner(private.MAIN_UI.frame, "ANCHOR_CURSOR")  -- LootAppraiser.GUI is the AceGUI-Frame but we need the real frame
            GameTooltip:SetHyperlink(link)
            GameTooltip:Show()
        end
    )
    LABEL:SetCallback("OnLeave",
        function()
            GameTooltip:Hide()
        end
    )

    LA.Debug.Log("  " .. tostring(itemID) .. ": add entry to list " .. preparedText)

    local lootCollectedUI = private.MAIN_UI:GetUserData("data_lootCollected")
    local lootCollectedLastEntryUI = private.MAIN_UI:GetUserData("data_lootCollected_lastEntry")
    if lootCollectedLastEntryUI then
        lootCollectedUI:AddChild(LABEL, lootCollectedLastEntryUI)
    else
        lootCollectedUI:AddChild(LABEL)
    end

    -- rember the created entry to add the next entry before this -> reverse list with newest entry on top
    private.MAIN_UI:SetUserData("data_lootCollected_lastEntry", LABEL)
end

function UI.ClearLootCollectedList()
		local lootCollectedUI = private.MAIN_UI:GetUserData("data_lootCollected")
		if lootCollectedUI then
			lootCollectedUI:ReleaseChildren()
		end
		private.MAIN_UI:SetUserData("data_lootCollected_lastEntry", nil)
end

function UI.ClearLastNoteworthyItemUI()

    if private.LAST_NOTEWOTHYITEM_UI then
        private.LAST_NOTEWOTHYITEM_UI:SetTitle("Gold Alert Threshold")
    end
end

-- resets all loot appraiser frames
function UI.ResetFrames()
    LA.Debug.Log("reset frames")

    local parentHeight = UIParent:GetHeight()
	LA.Debug.Log("ParentHeight: " .. parentHeight)
    LA.db.profile.lastNotewothyItemUI = { ["height"] = 30, ["top"] = (parentHeight-100), ["left"] = 50, ["width"] = 350, }

    if private.LAST_NOTEWOTHYITEM_UI then
        private.LAST_NOTEWOTHYITEM_UI:ApplyStatus()
    end

    LA.db.profile.liteUI = { ["height"] = 30, ["top"] = (parentHeight-135), ["left"] = 50, ["width"] = 150, }
    if private.LITE_UI then
        private.LITE_UI:ApplyStatus()
    end
	
    LA.db.profile.timerUI = { ["height"] = 30, ["top"] = (parentHeight-135), ["left"] = 290, ["width"] = 110, }
    if private.TIMER_UI then
        private.TIMER_UI:ApplyStatus()
    end

	LA.db.profile.mainUI.top = parentHeight-170
    LA.db.profile.mainUI.left = 50

	
    if private.MAIN_UI then
		private.MAIN_UI:ApplyStatus()
    end
end


-- Event handler for button 'reset instances'
function private.OnBtnResetInstancesClick()
    ResetInstances()

    -- if in a party - send party msg for awareness --
    local inInstanceGroup = IsInGroup(LE_PARTY_CATEGORY_INSTANCE)
    local inInstanceGroupRealm = IsInGroup(LE_PARTY_CATEGORY_HOME)
    if inInstanceGroup or inInstanceGroupRealm then
        SendChatMessage("Instances have been reset.","PARTY", nil)
    end

    --LA.Debug.TableToString(LA.ResetInfo)
end

-- Event handler for button 'sell trash'
-- function private.OnBtnSellTrashClick()
--     --Validate whether there is an NPC open and how many items sold
--     local itemCounter = 0

--     for n = 1, GetMerchantNumItems() do
--         local merchantItemName = select(1, GetMerchantItemInfo(n))
--         itemCounter = itemCounter + 1
--     end

--     --If not vendor open (unable to count vendor items) alert to go to merchant
--     if itemCounter == 0 then
--         LA:Print("Travel to a vendor first to sell your items.")
--         return
--     end

--     local itemsSold = 0
--     for bag=0, NUM_BAG_SLOTS do
--         for slot=1, C_Container.GetContainerNumSlots(bag) do
--             -- first: we sell all grays
--             local link = C_Container.GetContainerItemLink(bag, slot)
--             if link and link:find("ff9d9d9d") then			--Poor = ff9d9d9d
--                 C_Container.UseContainerItem(bag, slot)
--                 itemsSold = itemsSold + 1
--             end

--             --second: sell items in TSM group
--             if LA.GetFromDb("sellTrash", "tsmGroupEnabled", "TSM_REQUIRED") then
--                 local id = C_Container.GetContainerItemID(bag, slot)
--                 --if id and LA:isItemInList(id, trashItems) then
--                 if id and LA.TSM.IsItemInGroup(id, LA.GetFromDb("sellTrash", "tsmGroup")) then
--                     --LA.Debug.Log("  id=" .. id .. ", found=" .. tostring(trashItems["i:" .. id]) .. ", link=" .. link)
--                     C_Container.UseContainerItem(bag, slot)
--                     itemsSold = itemsSold + 1
--                 end
--             end
--         end
--     end

--     if itemsSold == 0 then
--         LA:Print("No items sold.")
--     else
--         LA:Print(tostring(itemsSold) .. " item(s) sold") --for " .. LA.Util.MoneyToString(moneyEarned))
--     end
-- end


function private.OnBtnSellTrashClick()

    local merchantitems = GetMerchantNumItems()     --check if vendor is open first
    if merchantitems > 0 then
        --toggle already checked - proceed with finding gray items and selling
        --Search for gray items in bags
        local totalItemValueOfGrays = 0			--value holder for total currency sold
        local rarityCounter = 0					--counter for rarity items

        for bag = 0, NUM_BAG_SLOTS do
            --get details about each item in slot
            for slot = 1, C_Container.GetContainerNumSlots(bag) do
                local itemLink = C_Container.GetContainerItemLink(bag, slot)
                --if an itemLink is available

                if itemLink ~= nil then
                    local _, _, itemID = strfind(itemLink, "item:(%d+):")
                    if itemID == nil then
                        LA.Debug.Log("No itemID found for " .. itemLink .. " in bag slot " .. bag)
                    else
                        local name, _, rarity, _, _, _, _, _, _ = GetItemInfo(itemID)
                        local itemInfo = GetItemInfo(itemID)
                        local currentItemValue = private.GetItemValue(itemID, "VendorSell") or 0

                        --enumerate how many of the same item for multiplier
                        local iStackCount = GetItemCount(itemInfo)
                        if iStackCount > 1 then
                            currentItemValue = currentItemValue * iStackCount
                        end


                        --detect if rarity of 0 (poor gray item)
                        if rarity == 0 and currentItemValue ~= 0 then		--added currentItemValue


                        -- --second: sell items in TSM group
                        -- if LA.GetFromDb("sellTrash", "tsmGroupEnabled", "TSM_REQUIRED") then
                        --     local id = C_Container.GetContainerItemID(bag, slot)
                        --     --if id and LA:isItemInList(id, trashItems) then
                        --     if id and LA.TSM.IsItemInGroup(id, LA.GetFromDb("sellTrash", "tsmGroup")) then
                        --         --LA.Debug.Log("  id=" .. id .. ", found=" .. tostring(trashItems["i:" .. id]) .. ", link=" .. link)
                        --         C_Container.UseContainerItem(bag, slot)
                        --         --itemsSold = itemsSold + 1
                        --     end
                        -- end


                            rarityCounter = rarityCounter + 1
                            LA.Debug.Log("selling gray item: " .. itemLink .. " x" .. iStackCount .. ": " .. GetCoinTextureString(currentItemValue))
                            totalItemValueOfGrays = totalItemValueOfGrays + currentItemValue
                            --output to player
                            --if Verbose is enabled, then only show the total and don't do an output of the sale per item
                            if LA.db.profile.general.sellGrayItemsToVendorVerbose == true then

                            else
                                LA:Print("Selling " .. itemLink .. " x" .. iStackCount .. ": " .. GetCoinTextureString(currentItemValue))
                            end
                            local id = C_Container.GetContainerItemID(bag, slot)
                            if id and LA.TSM.IsItemInGroup(id, LA.GetFromDb("sellTrash", "tsmGroup")) then
                                --LA.Debug.Log("  id=" .. id .. ", found=" .. tostring(trashItems["i:" .. id]) .. ", link=" .. link)
                                C_Container.UseContainerItem(bag, slot)
                            else
                                C_Container.UseContainerItem(bag, slot)		--perform selling of item
                            end
                        end
                    end
                end
                slot = slot + 1
            end
        end

    ---------------------------------------------------------------------
    -- Update Vendor Sales on UI
    ---------------------------------------------------------------------
        if LA.GetFromDb("display", "showValueSoldToVendor") == true then
            local formattedTotalVendorSoldCurrency = LA.Session.GetCurrentSession("vendorSoldCurrencyUI") or 0
            local totalSoldValue = formattedTotalVendorSoldCurrency + totalItemValueOfGrays or 0
            LA.Debug.Log("totalSoldValue: " .. totalSoldValue)
            LA.Session.SetCurrentSession("vendorSoldCurrencyUI", totalSoldValue)
            LA.Debug.Log("Set Session: " .. LA.Session.GetCurrentSession("vendorSoldCurrencyUI"))
            private.HandleVendorSales(totalSoldValue)
        end
    ---------------------------------------------------------------------
    ---------------------------------------------------------------------

        if rarityCounter > 0 then
		    LA:Print("Total Gray Sales: " .. GetCoinTextureString(totalItemValueOfGrays))	
        end	

    else
        LA:Print("You must have a merchant open before selling.")
    end
end

---------------------------------------------------------------------
-- handle vendor sales currency
---------------------------------------------------------------------
function private.HandleVendorSales(totalSoldValue)
	LA.Debug.Log("handle vendor sales: " .. totalSoldValue)
	-- add to total looted currency
	--LA.Session.private.totalLootedCurrency = LA.Session.private.totalLootedCurrency + lootedCopper
	local totalVendorSalesCurrency = (LA.Session.GetCurrentSession("vendorSoldCurrencyUI")) or 0
	LA.Debug.Log("total value: " .. totalVendorSalesCurrency)
	LA.Session.SetCurrentSession("vendorSoldCurrencyUI", totalVendorSalesCurrency)
    --LA.UI.RefreshUIs()
end
---------------------------------------------------------------------
---------------------------------------------------------------------

function private.GetItemValue(itemID, priceSource)
	if (LA.Util.startsWith(LA.CONST.PRICE_SOURCE[LA.GetFromDb("pricesource", "source")], "OE:") 
	or (LA.Util.startsWith(LA.CONST.PRICE_SOURCE[LA.GetFromDb("pricesource", "source")], "AN:")) 
	or (LA.Util.startsWith(LA.CONST.PRICE_SOURCE[LA.GetFromDb("pricesource", "source")], "BLIZ:"))) then
	
		if (priceSource == "VendorSell") then
			local VendorSell =  select(11, GetItemInfo(itemID)) or 0
			return VendorSell
		
		-- Blizzard's native pricing for vendor selling
		elseif priceSource == "VendorValue" then
			local priceInfo = {}
			local BlizzardVendorSell =  select(11, GetItemInfo(itemID)) or 0
			return BlizzardVendorSell

		--new catch for OribosExchange pricing sources	
		elseif priceSource == "region" then
			local priceInfo = {}
			OEMarketInfo(itemID, priceInfo)
			return priceInfo[priceSource]
		
		-- Auctionator pricing
		elseif priceSource == "Auctionator" then
			local priceInfo = {}
			--Usage Auctionator.API.v1.GetAuctionPriceByItemID(string, number)
			AuctionatorInfo = Auctionator.API.v1.GetAuctionPriceByItemID("LootAppraiser", itemID)
			return AuctionatorInfo

		else
			local itemLink
			-- battle pet handling
			local newItemID = LA.PetData.ItemID2Species(itemID)
			if newItemID == itemID then
				itemLink = itemID
				local priceInfo = {}
				return priceInfo[priceSource]
			else
				itemLink = newItemID
				local priceInfo = {}
				return priceInfo[priceSource]
			end

			--local priceInfo = {}
			--return priceInfo[priceSource]
		end
	else
		-- TSM price source
		--LA.Debug.Log("GetItemValue Here: " .. tostring(priceSource))
		return LA.TSM.GetItemValue(itemID, priceSource)
	end
end


















-- Event handler for button 'destroy trash'
function private.OnBtnDestroyTrashClick()
    local destroyCounter = 0

    for bag = 0, 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local link = C_Container.GetContainerItemLink(bag, slot)

            -- grey items
            if link and link:find("ff9d9d9d") then -- Poor = ff9d9d9d
                C_Container.PickupContainerItem(bag,slot)
                DeleteCursorItem()

                destroyCounter = destroyCounter + 1
            end

            -- blacklist
            if link and private.IsDestroyBlacklistedItems() then
                local itemID = LA.Util.ToItemID(link)
                if LA.IsItemBlacklisted(itemID) then
                    C_Container.PickupContainerItem(bag, slot)
                    DeleteCursorItem()

                    destroyCounter = destroyCounter + 1
                end
            end
        end
    end

    if destroyCounter == 0 then
        LA:Print("There are currently no items to trash.")
    end

    if destroyCounter >= 1 then
        LA:Print("Destroyed " .. destroyCounter .. " item(s).")
    end
end

-- add a row with label and value to the frame
function private.DefineRowForFrame(frame, id, name, value)
    LA.Debug.Log("  defineRowForFrame: id=%s, name=%s, value=%s", id, name, value)

    if not private.IsDisplayEnabled(id) or frame == nil then
        LA.Debug.Log("  -> not visible")
        return
    end

    local labelWidth = 150  --150
    local valueWidth = 225  --225

    local grp = AceGUI:Create("SimpleGroup")
    grp:SetLayout("flow")
    grp:SetFullWidth(true)
    frame:AddChild(grp)

    -- add label...
    local label = AceGUI:Create("LALabel")
    label:SetText(name)
    label:SetWidth(labelWidth) -- TODO
    label:SetJustifyH("LEFT")
    grp:AddChild(label)

    -- ...and value
    local VALUE = AceGUI:Create("LALabel")
    VALUE:SetText(value)
    VALUE:SetWidth(valueWidth) -- TODO
    VALUE:SetJustifyH("RIGHT")
    grp:AddChild(VALUE)

    return VALUE
end

-- add a blank line to the given frame
function private.AddSpacer(frame)
    local SPACER = AceGUI:Create("LALabel")
    SPACER:SetJustifyH("LEFT")
    SPACER:SetText("   ")
    SPACER:SetWidth(350)
    frame:AddChild(SPACER)
end

function private.IsDestroyBlacklistedItems()
    if not LA.TSM.IsTSMLoaded() then
        return false
    end

    if LA.db.profile.blacklist.addBlacklistedItems2DestroyTrash then
        return true
    end
    return false
end

-- calculate looted item value / hour
--OLD /gph
--function private.CalcLootedItemValuePerHour(key)
--    local offset = LA.Session.GetPauseStart() or time()
--	local delta = offset - LA.Session.GetCurrentSession("start") - LA.Session.GetSessionPause()
--	local factor = 3600	--1 hour in seconds (3600)
--
--    if delta < factor then
--        factor = delta
--    end
--
--    local totalItemValue = LA.Session.GetCurrentSession(key) or 0
--    local livGoldPerHour
--	
--    if totalItemValue == 0 then
--        livGoldPerHour = 0
--    else
--        local livPerHour = (totalItemValue/delta*factor)
--        livGoldPerHour = floor(livPerHour/10000)
--    end
--    return tostring(livGoldPerHour)
--end

-- calculate looted item value / hour
function private.CalcLootedItemValuePerHour(key)
    local offset = LA.Session.GetPauseStart() or time()
    local delta = offset - LA.Session.GetCurrentSession("start") - LA.Session.GetSessionPause()

    local totalItemValue = LA.Session.GetCurrentSession(key) or 0
	--LA.Debug.Log("total value " .. totalItemValue)
    local livGoldPerHour
    if (totalItemValue == 0 or delta == 0 or totalItemValue/delta < 1) then
        livGoldPerHour = 0
    else
        local copperPerSec = totalItemValue/delta
        livGoldPerHour = copperPerSec*60*60
    end

    return LA.Util.MoneyToString(livGoldPerHour)
end







function private.IsDisplayEnabled(name)
    if LA.db.profile.display[name] == nil then
        LA.db.profile.display[name] = LA.dbDefaults.profile.display[name]
    end

    return LA.db.profile.display[name]
end

