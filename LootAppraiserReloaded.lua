local LA = select(2, ...)

local LibStub = LibStub
local AceGUI = LibStub("AceGUI-3.0")
local LibToast = LibStub("LibToast-1.0")
local LSM = LibStub:GetLibrary("LibSharedMedia-3.0")
local LibParse = LibStub:GetLibrary("LibParse")

local OEMarketInfo = OEMarketInfo
local AuctionatorInfo = AuctionatorInfo
local BlizzardVendorSell = 1	-- used to always show blizzard's native vendor sell pricing as a pricesource 
local LootAppraiserReloaded_GroupLoot = LootAppraiserReloaded_GroupLoot

--lootPrompt = 0 -- set to have it show by default upon first loot 

-- Lua APIs
local select, tostring, time, unpack, tonumber, floor, pairs, tinsert, smatch, math, gsub = 
select, tostring, time, unpack, tonumber, floor, pairs, table.insert, string.match, math, gsub

-- wow APIs
local GetContainerItemID, GetContainerItemInfo, GetUnitName, GetItemInfo, IsShiftKeyDown, GetBestMapForUnit, PlaySoundFile, GameFontNormal, RegisterAddonMessagePrefix, IsInGroup, UnitGUID, SecondsToTime, StaticPopupDialogs, StaticPopup_Show, SendAddonMessage =
GetContainerItemID, GetContainerItemInfo, GetUnitName, GetItemInfo, IsShiftKeyDown, C_Map.GetBestMapForUnit, PlaySoundFile, GameFontNormal, C_ChatInfo.RegisterAddonMessagePrefix, IsInGroup, UnitGUID, SecondsToTime, StaticPopupDialogs, StaticPopup_Show, C_ChatInfo.SendAddonMessage
local INSTANCE_RESET_SUCCESS, OKAY, LOOT_ITEM_SELF, LOOT_ITEM_SELF_MULTIPLE = INSTANCE_RESET_SUCCESS, OKAY, LOOT_ITEM_SELF, LOOT_ITEM_SELF_MULTIPLE


local private = {
    modules = {}
}


-- global api object
LA_API = {}
LA.LA_API = LA_API

--PLAYERRELOADED = false


--global object for managing loot
--Location, toon, session date/time, items looted, value
LOOTMANAGER = {}
	LOOTMANAGER["ZoneLoc"] = ""			-- will hold location of sessions
		LOOTMANAGER["Player"] = ""			-- will hold the player's toon's name
			LOOTMANAGER["LootSession"] = ""		-- will hold the sessions
				LOOTMANAGER["LootedItems"] = ""		-- will hold what was looted



function LA_API.RegisterModule(theModule)
    LA.Debug.Log("RegisterModule")
	LA.Debug.TableToString(theModule)

    if not private.modules then
        private.modules = {}
    end

    private.modules[theModule.name] = theModule
end

function LA_API.GetVersion()
    return LA.CONST.METADATA.VERSION
end

function LA_API.StartSession(qualityFilter, priceSource, ...)
	if not qualityFilter or not priceSource then
		return
	end

	local startPaused
	for i = 1, select('#', ...) do
		local opt = select(i, ...)
		if opt == nil then
			-- do nothing
		elseif opt == "START_PAUSED" then
			startPaused = true
		end
	end

	LA.db.profile.notification.qualityFilter = qualityFilter
	LA.db.profile.pricesource.source = priceSource

	LA.Session.Start(true)	-- start session
	LA.Session.New()		-- force new session in case a session is already running
	
	if startPaused then
		LA.Session.Pause()	-- and pause session
	end
end

function LA_API.GetCurrentSession()
	return LA.Session.GetCurrentSession()
end

function LA_API.PauseSession()
	LA.Session.Pause()
end

-- Added back in Loot Item Value text for ElvUI support and datatext/labels
--6/27/2019

local UPDATEPERIOD, elapsed = 1, 0
local ldb = LibStub("LibDataBroker-1.1")
local dataobj = ldb:NewDataObject("LootedItemValue", {

type = "data source",
text="0g",
label = "Looted Item Value",

OnClick = function(self, button, down)
if button == "LeftButton" then
local isShiftKeyDown = IsShiftKeyDown()
if isShiftKeyDown then
local callback = private.GetMinimapIconModulCallback("LeftButton", "Shift")
if callback then
callback()
end
else
if not LA.Session.IsRunning() then
LA.Session.Start(true)
end

LA.UI.ShowMainWindow(true)
end
elseif button == "RightButton" then
local isShiftKeyDown = IsShiftKeyDown()
if isShiftKeyDown then
local callback = private.GetMinimapIconModulCallback("RightButton", "Shift")
if callback then
callback()
end
else
	Settings.OpenToCategory(LA.CONST.METADATA.NAME)
    SettingsPanel.AddOnsTab:Click()
end
end
end,})
local f = CreateFrame("frame")
f:SetScript("OnUpdate",
function(self, elap)
elapsed = elapsed + elap
if elapsed < UPDATEPERIOD then return end

elapsed = 0

local lootedItemValue
local currentSession = LA:getCurrentSession()
if currentSession ~= nil then
lootedItemValue = currentSession["liv"] or 0
else
lootedItemValue = 0
end

dataobj.text = LA.Util.MoneyToString(lootedItemValue)
end
)
--------------------------------------------------------------

-- AceAddon-3.0 standard methods
function LA:OnInitialize()
    private.InitDB()

	LA.Debug.Log("LA:OnInitialize()")

	LA:SetSinkStorage(LA.db.profile.notification.sink)

	-- prepare minimap icon --
	LA.icon = LibStub("LibDBIcon-1.0")
	LA.LibDataBroker = LibStub("LibDataBroker-1.1"):NewDataObject(LA.CONST.METADATA.NAME, {
		type = "launcher",
		text ="LootAppraiser Reloaded",	-- used as a label to load LA from datatext panels with UI addons like ElvUI (datatext panel)
		icon = "Interface\\Icons\\Ability_Racial_PackHobgoblin",

		OnClick = function(self, button, down)
			if button == "LeftButton" then
				local isShiftKeyDown = IsShiftKeyDown()
				if isShiftKeyDown then
					local callback = private.GetMinimapIconModulCallback("LeftButton", "Shift")
					if callback then
						callback()
					end
				else
					if not LA.Session.IsRunning() then
				        LA.Session.Start(true)
				    end

				    LA.UI.ShowMainWindow(true)
				end
			elseif button == "RightButton" then
				local isShiftKeyDown = IsShiftKeyDown()
				if isShiftKeyDown then
					local callback = private.GetMinimapIconModulCallback("RightButton", "Shift")
					if callback then
						callback()
					end
				else
					LA.Debug.Log("Name: "..LA.CONST.METADATA.NAME)
					Settings.OpenToCategory(LA.CONST.METADATA.NAME)
    				SettingsPanel.AddOnsTab:Click()
				end
			end
		end,

		OnTooltipShow = function (tooltip)
			tooltip:AddLine(LA.CONST.METADATA.NAME .. " " .. LA.CONST.METADATA.VERSION, 1 , 1, 1)
			tooltip:AddLine("|cFFFFFFCCLeft-Click|r to open the main window")
			tooltip:AddLine("|cFFFFFFCCRight-Click|r to open options window")
			tooltip:AddLine("|cFFFFFFCCDrag|r to move this button")
			tooltip:AddLine(" ") -- spacer

			if LA.Session.IsRunning() then
				local offset = LA.Session.GetPauseStart() or time()
				local delta = offset - LA.Session.GetCurrentSession("start") - LA.Session.GetSessionPause()

				-- don't show seconds
				local noSeconds = false
				if delta > 3600 then
					noSeconds = true
				end

				local text = "Session is "
				if LA.Session.IsPaused() then
					text = text .. "paused: "
				else
					text = text .. "running: "
				end

				tooltip:AddDoubleLine(text, SecondsToTime(delta, noSeconds, false))
			else
				tooltip:AddLine("Session is not running")
			end

			-- if module present we add the additional modul informations
			if private.modules then
				for name, module in pairs(private.modules) do
					if module.icon and module.icon.tooltip then
						-- add lines
						tooltip:AddLine(" ") -- spacer

						for _, line in pairs(module.icon.tooltip) do
							tooltip:AddLine(line)
						end
					end
				end
			end
		end
	})
	LA.icon:Register(LA.CONST.METADATA.NAME, LA.LibDataBroker, LA.db.profile.minimapIcon)
	if LA.db.profile.minimapIcon.hide == true then
		LA.icon:Show(LA.CONST.METADATA.NAME)
	else
		LA.icon:Hide(LA.CONST.METADATA.NAME)
	end
end

function LA:OnEnable()
    --LA:Print("Addon Enabled")

    private.PreparePricesources()

    -- register chat commands
    LA:RegisterChatCommand("la", private.chatCmdLootAppraiserReloaded)
    LA:RegisterChatCommand("lal", private.chatCmdLootAppraiserReloadedLite)
    LA:RegisterChatCommand("laa", private.chatCmdGoldAlertTresholdMonitor)
    LA:RegisterChatCommand("lade", private.chatCmdUseDisenchantValueStatus)
	LA:RegisterChatCommand("laconfig", private.chatCmdShowConfig)
	--LA:RegisterChatCommand("lanw", private.chatCmdShowNotewortyItemsUI)
	
	-- register event for reset instance
	LA:RegisterEvent("CHAT_MSG_SYSTEM", private.OnResetInfoEvent)
	LA:RegisterEvent("CHAT_MSG_ADDON", private.OnChatMsgAddon)

    -- register event for...
    -- ...looting items (new loot tracking logic)
    LA:RegisterEvent("CHAT_MSG_LOOT", private.OnChatMsgEvents)
	-- ...looting currency
	LA:RegisterEvent("CHAT_MSG_MONEY", private.OnChatMsgMoney)

	-- register addon message prefix for LootAppraiserReloaded_GroupLoot
    RegisterAddonMessagePrefix(LA.CONST.PARTYLOOT_MSGPREFIX)
	
	-- register event for merchant to sell / vendor grays
	LA:RegisterEvent("MERCHANT_SHOW", private.onMerchantEventShow)
	LA:RegisterEvent("MERCHANT_CLOSED", private.onMerchantEventClosed)
	
	-- register event for capturing data from LA while doing a /reload
	--LA:RegisterEvent("PLAYER_ENTERING_WORLD", private.onReloadScreen)
		
end

-- self loot
-- ...single item - "You receive loot: %s." -> item
-- gsub(s, pattern, replace [, n])
--wow API:  You receive loot : %s|Hitem :%d :%d :%d :%d|h[%s]|h%s.
local PATTERN_LOOT_ITEM_SELF = LOOT_ITEM_SELF:gsub("%%s", "(.+)")

--local PATTERN_LOOT_ITEM_SELF_UNIQUE = LOOT_ITEM:gsub("%%s", "(.+)")
--TESTING DEFAULT LOOT FROM LOOT_ITEM_SELF
-- ...multiple item - "You receive loot: %sx%d." -> item + quantity
local PATTERN_LOOT_ITEM_SELF_MULTIPLE = LOOT_ITEM_SELF_MULTIPLE:gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")

--[[
----------------------------------------------------------------
-- WORKING HERE --
----------------------------------------------------------------
--During a /reload save LA data
function private.onReloadScreen(event, isInitialLogin, isReloadingUi)
	print("event: " .. tostring(event) .. " InitialLogin: " .. tostring(isInitialLogin) .. " isReloadingUi: " .. tostring(isReloadingUi))
	if isInitialLogin == true then
		print("player joined world for the first time.")
	end
	if isReloadingUi == true then
		PLAYERRELOADED = true
		print("PLAYERRELOADED: " .. tostring(PLAYERRELOADED))
		print("player reloaded...saving data.")
		--reload data here
		LA.Session.RestoreSession()
	end

end
----------------------------------------------------------------
--]]

-- merchant interaction event when opening
function private.onMerchantEventShow(event, msg)
	--Since no loot has been picked up, start session now for LA to interact with vendor to sell grays	
	--auto sell gray items
	if LA.GetFromDb("general", "sellGrayItemsToVendor") == true then
		LA.Session.Start(showMainUI)
		LA.Debug.Log("Merchant Opened")
		LA.Debug.Log("Auto Sell Grays: |cff00fe00Enabled|r")
		private.sellGrayItems()
	end
	--auto repair gear with player's currency	--added feature toggle with player or guild funds?
	if LA.GetFromDb("general", "autoRepairGear") == true then
		LA.Debug.Log("Auto Repair: |cff00fe00Enabled|r")
		private.autoRepairGearOperations()
	end
	
end

function private.sellGrayItems()
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
						rarityCounter = rarityCounter + 1
						LA.Debug.Log("selling gray item: " .. itemLink .. " x" .. iStackCount .. ": " .. GetCoinTextureString(currentItemValue))
						totalItemValueOfGrays = totalItemValueOfGrays + currentItemValue
						--output to player
						--if Verbose is enabled, then only show the total and don't do an output of the sale per item
						if LA.db.profile.general.sellGrayItemsToVendorVerbose == true then

						else
							LA:Print("Selling " .. itemLink .. " x" .. iStackCount .. ": " .. GetCoinTextureString(currentItemValue))
						end
						
						
						C_Container.UseContainerItem(bag, slot)		--perform selling of item

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
end
	
-- merchant interaction event when closed
function private.onMerchantEventClosed()
	LA.Debug.Log("Merchant Closed")
end


function private.OnChatMsgEvents(event, msg)

    -- is a loot appraiser session running?
    --if not LA.Session.IsRunning() then return end

	if not LA.Session.IsRunning() then 
	--implemented back the prompt for starting LA window upon first loot msg 
		LA:ShowStartSessionDialog()

	end
		-- pause? restart session
	if LA.Session.IsPaused() then
		LA.Session.Restart()
	end

	-- loot
	if event == "CHAT_MSG_LOOT" then
		-- self
		local loottype, itemLink, quantity, source


		if msg:match(PATTERN_LOOT_ITEM_SELF_MULTIPLE) then
			loottype = "## self (multi) ##"
			itemLink, quantity = smatch(msg, PATTERN_LOOT_ITEM_SELF_MULTIPLE)

		elseif msg:match(PATTERN_LOOT_ITEM_SELF) then
			loottype = "## self (single) ##"
			itemLink = smatch(msg, PATTERN_LOOT_ITEM_SELF)
			quantity = 1
			
		end


		if loottype then
			LA.Debug.Log("#### type=%s; itemLink=%s; quantity=%s", loottype, tostring(itemLink), tostring(quantity))
			LA.Debug.Log("----source: " .. tostring(source))
			
			if not itemLink or not quantity then
				LA.Debug.Log("#### ignore event! msg: " .. msg .. ", type=" .. tostring(loottype))
				LA.Debug.Log("   itemLink=" .. tostring(itemLink) .."; quantity=" .. tostring(quantity) .. "; source=" .. tostring(source) .. ")")
				return
				--this part cancels out and returns so never calls HandledItemLooted() below
			end

			local itemID = LA.Util.ToItemID(itemLink)

			private.HandleItemLooted(itemLink, itemID, quantity, source)
		end
	end
end




function private.GetMinimapIconModulCallback(button, modifier)
	-- if modules present we add the additional callbacks
	if not private.modules then return end

	for name, module in pairs(private.modules) do
		if module.icon and module.icon.action then
			for _, action in pairs(module.icon.action) do
				if action.button == button then
					if action.modifier == modifier then
						return action.callback
					end
				end
			end
		end
	end
end


function private.PreparePricesources()
	LA.Debug.Log("PreparePricesources()")

	-- price source check --
	local priceSources = private.GetAvailablePriceSources() or {}

	-- only 2 or less price sources -> chat msg: missing modules
	if LA.Util.tablelength(priceSources) == 0 then
		StaticPopupDialogs["LA_NO_PRICESOURCES"] = {
			text = "|cffff0000Attention!|r Missing additional addons for price sources (e.g. like TradeSkillMaster, Oribos Exchange, or Auctionator).\n\n|cffff0000LootAppraiser Reloaded disabled.|r",
			button1 = OKAY,
			timeout = 0,
			whileDead = true,
			hideOnEscape = true
		}
		StaticPopup_Show("LA_NO_PRICESOURCES")

		LA:Print("|cffff0000LootAppraiser Reloaded disabled.|r (see popup window for further details)")
		LA:Disable()
		return
	else
		-- current preselected price source
		local priceSource = LA.GetFromDb("pricesource", "source") --LA's default price source

		-- price source 'custom'
		if priceSource == "Custom" then
			-- validate 'custom' price source
			local isValidCustomPriceSource = LA.TSM.ParseCustomPrice(LA.GetFromDb("pricesource", "customPriceSource"))
			if not isValidCustomPriceSource then
				StaticPopupDialogs["LA_INVALID_CUSTOM_PRICESOURCE"] = {
					text = "|cffff0000Attention!|r You have selected 'Custom' as price source but your formular is invalid (see TSM documentation for detailed custom price source informations).\n\n" .. (LA.GetFromDb("pricesource", "customPriceSource") or "-empty-"),
					button1 = OKAY,
					timeout = 0,
					whileDead = true,
					hideOnEscape = true
				}
				StaticPopup_Show("LA_INVALID_CUSTOM_PRICESOURCE")
			end
		else
			-- normal price source check against prepared list
			if not priceSources[priceSource] then
				StaticPopupDialogs["LA_INVALID_CUSTOM_PRICESOURCE"] = {
					text = "|cffff0000Attention!|r Your selected price source in Loot Appraiser is not or no longer valid (maybe due to a missing module/addon). Please select another price source in the Loot Appraiser settings or install the needed module/addon for the selected price source.",
					button1 = OKAY,
					timeout = 0,
					whileDead = true,
					hideOnEscape = true
				}
				StaticPopup_Show("LA_INVALID_CUSTOM_PRICESOURCE")
			end
		end
	end

	LA.availablePriceSources = priceSources

end


-- propagate group loot
function private.SendAddonMsg(...)
	if LootAppraiserReloaded_GroupLoot then
		return
	end

	local json = ""
	for n=1, select('#', ...) do
		if json ~= "" then
			json = json .. "\001"
		end
		json = json .. LibParse:JSONEncode(select(n,...))
	end

	-- add UnitGUID
	if json ~= "" then
		json = json .. "\001"
	end
	json = json .. LibParse:JSONEncode(UnitGUID("player"))

if LA.GetFromDb("display","showGroupLootAlerts") == true then
	---print('showing showGroupLootAlerts')
	--LA:Print("raid warning no")
	SendAddonMessage(LA.CONST.PARTYLOOT_MSGPREFIX, json, "RAID")
else
	---SendAddonMessage(LA.CONST.PARTYLOOT_MSGPREFIX, json, "RAID") -- RAID, with fallback to PARTY if not in a raid
	---LA:Print("Yes - raid warning")
end


end


function private.OnChatMsgAddon(event, prefix, msg, type, sender)
	-- is a loot appraiser session running?
	if not LA.Session.IsRunning() then return end

    --LA.Debug.Log("#### OnChatMsgAddon: prefix: %s; msg: %s", tostring(prefix), tostring(msg))

	-- is message for loot appraiser?
	if prefix ~= LA.CONST.PARTYLOOT_MSGPREFIX then
        --LA.Debug.Log("#### OnChatMsgAddon: wrong prefix: %s", tostring(prefix))
		return
    end

	LA.Debug.Log("sender vs. player: %s vs. %s", sender, GetUnitName("player", true))
	if sender == GetUnitName("player", true) then
		LA.Debug.Log("#### OnChatMsgAddon: ignore message")
		return
	end

	local tokens = LA.Util.split(msg, "\001")
	local v = {}
	for i=1, #tokens do
		local temp = LibParse:JSONDecode(tokens[i])
		tinsert(v, temp)
	end

	local success, itemLink, itemID, quantity, senderUnitGUID = true, unpack(v)

	LA.Debug.Log("senderGUID vs. playerGUID: %s vs. %s", senderUnitGUID, UnitGUID("player"))
	if senderUnitGUID == UnitGUID("player") then
		LA.Debug.Log("OnChatMsgAddon: ignore message")
		return
	end

	LA.Debug.Log("OnChatMsgAddon: prefix=%s, msg=%s, type=%s, sender=%s", prefix, msg, type, senderUnitGUID)
	private.HandleItemLooted(itemLink, itemID, quantity, sender)
end


function private.OnChatMsgMoney(event, msg)
	if not LA.Session.IsRunning() then return end

	LA.Debug.Log("  OnChatMsgMoney: msg=%s", tostring(msg))

	local lootedCopper = LA.Util.StringToMoney(msg)
	if msg == "Free Trial money cap reached." then
		LA.Debug.Log("Ignoring looted copper.")
	else
		LA.Debug.Log("    lootedCopper=%s", tostring(lootedCopper))
		private.HandleCurrencyLooted(lootedCopper)
	end
	
end


-- open gold alert treshold monitor
function private.chatCmdGoldAlertTresholdMonitor()
    if not LA.Session.IsRunning() then
        LA.Session.Start(true)
    end

    LA.UI.ShowLastNoteworthyItemWindow()
end


-- Print the value of useDisenchantValue
function private.chatCmdUseDisenchantValueStatus()
	LA:Print(tostring(LA.GetFromDb("pricesource", "useDisenchantValue", "TSM_REQUIRED")))
end

-- open loot appraiser and start a new session
function private.chatCmdLootAppraiserReloaded(input)
	-- first: reset frames if requested
	if input == "freset" then LA.UI.ResetFrames() end

    if not LA.Session.IsRunning() then
		LA.Session.Start(true)
	end
    LA.UI.ShowMainWindow(true)
end

-- command to show config menu for LA (especially if mini-map is disabled)
function private.chatCmdShowConfig()
	Settings.OpenToCategory(LA.CONST.METADATA.NAME)
    SettingsPanel.AddOnsTab:Click()
end

--[[
function private.chatCmdShowNotewortyItemsUI()
	--show new NoteworthyItems UI 
	LA.Debug.Log("Displaying NW-UI")
	FontString1:SetText("Testing")
	NoteworthyUI:Show()

end
--]]

-- open loot appraiser lite and start a new session
function private.chatCmdLootAppraiserReloadedLite()
    if not LA.Session.IsRunning() then
        LA.Session.Start(false)
    end
    LA.UI.ShowLiteWindow()
end


-- the main logic for item processing
function private.HandleItemLooted(itemLink, itemID, quantity, source)
	LA.Debug.Log("handleItemLooted itemID=%s", itemID)
	LA.Debug.Log("*****Source: " .. tostring(source))

	LA.Debug.Log("  " .. tostring(itemID) .. ": " .. tostring(itemLink) .. " x" .. tostring(quantity)) --gsub(itemLink, "\124", "\124\124");
	LA.Debug.Log("  " .. tostring(itemID) .. ": " .. tostring(gsub(tostring(itemLink), "\124", "\124\124")))

	if not LA.Session.IsRunning() then return end

	-- settings we need
	local qualityFilter = tonumber(LA.GetFromDb("notification", "qualityFilter"))
	local priceSource = LA.GetFromDb("pricesource", "source")
	LA.Debug.Log("Initial Source: " .. tostring(priceSource))

	if priceSource == "Custom" then
		priceSource = LA.GetFromDb("pricesource", "customPriceSource")
		LA.Debug.Log("CP here: " .. tostring(priceSource))
	end

	--local priceSource = LA.GetFromDb("pricesource", "customPriceSource")
	local ignoreSoulboundItems = LA.GetFromDb("general", "ignoreSoulboundItems")
	--local autoDestroyTrash = LA.GetFromDb("general", "autoDestroyTrash")
	local addItem2List = true -- normally we add the item to the list if we reach this part of the logic
	local disenchanted = false -- indicator for disenchat value
	local showLootedItemValueGroup = LA.GetFromDb("display", "showLootedItemValueGroup")
	local addGroupDropsToLootedItemList = LA.GetFromDb("display", "addGroupDropsToLootedItemList")
	
-- new value to opt-out of not seeing group/party loot alerts
	local showGroupLootAlerts = LA.GetFromDb("display", "showGroupLootAlerts")
	LA.Debug.Log("showGroupLootAlerts: " .. tostring(showGroupLootAlerts))

	local showGroupLoot = source and (showLootedItemValueGroup or addGroupDropsToLootedItemList)
	LA.Debug.Log("showGroupLoot = %s", tostring(showGroupLoot))

	-- always count the looted items
	--    if quantity then
	--        LA.Session.private.totalItemLootedCounter = LA.Session.private.totalItemLootedCounter + quantity
	--    end

	-- check the item quality
	local quality = select(3, GetItemInfo(itemID)) or 0

	if quality < qualityFilter then
		LA.Debug.Log("  " .. tostring(itemID) .. ": item quality (" .. tostring(quality) .. ") < filter (" .. tostring(qualityFilter) .. ") -> ignore item")
		return
	end
	LA.Debug.Log("  " .. tostring(itemID) .. ": item quality (" .. tostring(quality) .. ") >= filter (" .. tostring(qualityFilter) .. ")")

	-- item blacklisted?
	if LA.IsItemBlacklisted(itemID) then
		LA.Debug.Log("  " .. tostring(itemID) .. ": blacklisted -> ignore")
		return
	end

	-- overwrite link if we only want base items
	if LA.GetFromDb("general", "ignoreRandomEnchants") then
		itemLink = select(2, GetItemInfo(itemID)) -- we use the link from GetItemInfo(...) because GetLootSlotLink(...) returns not the base item
	end

	-- special handling for poor quality and vendor filter items
	if quality == 0 then
		LA.Debug.Log("  " .. tostring(itemID) .. ": poor quality -> price source 'VendorSell'")
		--priceSource = "VendorSell"
		
	end


--new working area for category pricing
	--class and subclass of item looted
	--example:  Tradeskill, Herb or Tradeskill, Metal & Stone
	-- class = Consumable, Weapon, Armor, Reagent, Tradeskill, Item Enhancement, Recipe, Glyph, Battle Pets, Quest, Gem, Projectile, Quiver
	local class = select(6, GetItemInfo(itemID)) or 0	
	local subclass = select(7, GetItemInfo(itemID)) or 0
	LA.Debug.Log("class: " .. class .. ", sub: " .. subclass)
	--print("class: " .. class .. ", sub: " .. subclass)
	--if the class or subclass equals, then read from saved vars to pull SIV price source
--useSubClasses


--check if enabled then check price source 
if LA.db.profile.general.useSubClasses == true then
	--check which class type is enabled for custom pricing

	if class == "Armor" and LA.db.profile.classTypeArmor == true then
		local armorPrice = LA.db.profile.classTypeArmorPriceSource													  
		priceSource = armorPrice
		LA.Debug.Log("Armor price source: " .. priceSource)

	elseif class == "Consumable" and LA.db.profile.classTypeConsumable == true then
		local consumablePrice = LA.db.profile.classTypeConsumablePriceSource													  
		priceSource = consumablePrice
		LA.Debug.Log("Consumable price source: " .. priceSource)

	elseif class == "Recipe" and LA.db.profile.classTypeRecipe == true then
		local recipePrice = LA.db.profile.classTypeRecipePriceSource													  
		priceSource = recipePrice
		LA.Debug.Log("recipePrice price source: " .. priceSource)

	elseif class == "Tradeskill" and LA.db.profile.classTypeTradeskill == true then
		local tradeskillPrice = LA.db.profile.classTypeTradeskillPriceSource													  
		priceSource = tradeskillPrice
		LA.Debug.Log("Tradeskill price source: " .. priceSource)

	elseif class == "Weapon" and LA.db.profile.classTypeWeapon == true then
		local weaponPrice = LA.db.profile.classTypeWeaponPriceSource													  
		priceSource = weaponPrice
		LA.Debug.Log("Weapon price source: " .. priceSource)

	elseif class == "Quest" and LA.db.profile.classTypeQuest == true then
		local questPrice = LA.db.profile.classTypeQuestPriceSource													  
		priceSource = questPrice
		LA.Debug.Log("Quest price source: " .. priceSource)

	else
		--using standard price source set globally in general taba
	end
end


	-- get single item value
	local singleItemValue = private.GetItemValue(itemID, priceSource) or 0
	LA.Debug.Log("SIV price source: " .. tostring(singleItemValue))
	LA.Debug.Log("PriceSource: " .. tostring(priceSource))
	LA.Debug.Log("  " .. tostring(itemID) .. ": single item value: " .. tostring(singleItemValue))

	-- special handling for soulbound items and activated disenchant value
	if singleItemValue == 0 and quality > 0 then
		local blizVendorPrice =  select(11, GetItemInfo(itemID)) or 0		--use Blizzard API vendorPrice directly	

		if ignoreSoulboundItems then	--if option is enabled
			addItem2List = false
			singleItemValue = tostring(blizVendorPrice) or 0	--use Blizzard API vendorPrice directly
			LA.Debug.Log("ignoreSoulBoundItems is on. No output to loot window.")
		else							--if option is disabled
			addItem2List = true
			--local blizVendorPrice =  select(11, GetItemInfo(itemID)) or 0		--use Blizzard API vendorPrice directly
			--singleItemValue = private.GetItemValue(itemID, "VendorSell") or 0
			singleItemValue = tostring(blizVendorPrice) or 0
			LA.Debug.Log("ignoreSoulBoundItems is off. Showing VendorSell: " .. tostring(blizVendorPrice))
		end

		if LA.GetFromDb("pricesource", "useDisenchantValue", "TSM_REQUIRED") then
			singleItemValue = private.GetItemValue(itemID, "Destroy") or 0
			disenchanted = true
			LA.Debug.Log("  " .. tostring(itemID) .. ": single item value (de): " .. tostring(singleItemValue))
		end
	end

	-- calc the overall item value (get the quantity into the formula)
	local itemValue = singleItemValue * quantity

	private.IncLootedItemCounter(quantity, source)              -- increase looted item counter
	private.AddItemValue2LootedItemValue(itemValue, source)     -- add item value

	if addItem2List == true then
		itemValue = singleItemValue
		LA.Debug.Log("itemValue: " .. tostring(itemValue))
		LA.Debug.Log("quality: " .. tostring(quality))
		LA.UI.AddItem2LootCollectedList(itemID, itemLink, quantity, itemValue, false, source, disenchanted)	-- add item
		

		--If session already started, then just append.  If not, start new session.
		if LA.Session.IsRunning() then
			LogLoot(itemID, itemLink, itemValue)			
		
		end
		
	else
		LA.Debug.Log("soulbound item ignored: " .. tostring(itemID))
	end

	-- gold alert threshold
	local goldValue = floor(singleItemValue/10000)
	--local gat = LA.GetFromDb("general", "goldAlertThreshold")
	local gatA = LA.GetFromDb("notification", "goldAlertThresholdA")
	local gatB = LA.GetFromDb("notification", "goldAlertThresholdB")
	local gatC = LA.GetFromDb("notification", "goldAlertThresholdC")
	local gatSoundToPlay = ""

	local gatAValue = tonumber(gatA)
	local gatBValue = tonumber(gatB)
	local gatCValue = tonumber(gatC)

	LA.Debug.Log("gatA: " .. gatAValue)
	LA.Debug.Log("gatB: " .. gatBValue)
	LA.Debug.Log("gatC: " .. gatCValue)

------GAT A
	if goldValue >= gatAValue and gatBValue == 0 and gatCValue == 0 then
			gatSoundToPlay = "A"
			LA.Debug.Log("  " .. tostring(itemID) .. ": gold value (" .. tostring(goldValue) .. ") >= gold alert threshold (" .. gatA .. ")")

------GAT B
	elseif goldValue > gatAValue and goldValue < gatBValue and gatBValue ~= 0 then
			gatSoundToPlay = "A"
	
	elseif goldValue >= gatBValue and gatBValue ~= 0 then
			if goldValue > gatCValue and gatCValue ~= 0 then
				gatSoundToPlay = "C"
			else
				gatSoundToPlay = "B"
				LA.Debug.Log("  " .. tostring(itemID) .. ": gold value (" .. tostring(goldValue) .. ") >= gold alert threshold (" .. gatB .. ")")			
			end
------GAT C
	elseif goldValue >= gatCValue and gatCValue ~= 0 then
			gatSoundToPlay = "C"
			LA.Debug.Log("  " .. tostring(itemID) .. ": gold value (" .. tostring(goldValue) .. ") >= gold alert threshold (" .. gatC .. ")")			

	else
		--gatSoundToPlay = "A"
	end	

	if gatSoundToPlay ~= "" then
		-- prepare party loot suffix
		local partyLootSuffix = ""
		if source then
			partyLootSuffix = " (|cFF2DA6ED" .. source .. "|r)"
		end

		-- inc noteworthy items counter
		private.IncNoteworthyItemCounter(quantity, source)

		-- print to configured output 'channels'
		if not source or showGroupLoot then
			local formattedValue = LA.Util.MoneyToString(singleItemValue) or 0
			local qtyValue = 0
			if tonumber(quantity) > 1 then
				qtyValue = singleItemValue * tonumber(quantity)
				formatValue = LA.Util.MoneyToString(qtyValue) or 0
				LA:Pour(itemLink .. " x" .. quantity .. ": " .. formatValue .. partyLootSuffix)		--this outputs to the channnel selected with qty value > 1
				LA.UI.UpdateLastNoteworthyItemUI(itemLink, quantity, singleItemValue, formatValue)
			else
				-- last noteworthy item ui
				qtyValue = singleItemValue * tonumber(quantity)
				formatValue = LA.Util.MoneyToString(qtyValue) or 0
				LA:Pour(itemLink .. " x" .. quantity .. ": " .. formatValue .. partyLootSuffix)		--this outputs to the channnel selected with qty value 1
				LA.UI.UpdateLastNoteworthyItemUI(itemLink, quantity, singleItemValue, formattedValue)
			end
			

			-- toast
			if LA.GetFromDb("notification", "enableToasts") then
				local name, _, _, _, _, _, _, _, _, texturePath = GetItemInfo(itemID)
				--LibToast:Spawn("LootAppraiserReloaded", name, texturePath, quality, quantity, formattedValue, source)
				LibToast:Spawn("LootAppraiserReloaded", name, texturePath, quality, quantity, formatValue, source)	--updated to show qty value > 1
			end
		end

		-- check current mapID with session mapID
		if LA.Session.GetCurrentSession("mapID") ~= GetBestMapForUnit("player") then
			LA.Debug.Log("  current vs. session mapID: %s vs. %s" , GetBestMapForUnit("player"), LA.Session.GetCurrentSession("mapID"))

			-- if we loot a noteworthy item we change the map id
			LA.Session.SetCurrentSession("mapID", GetBestMapForUnit("player"))
		end
	else

	end
	-- play sound (if enabled)
	
	

	if IsInGroup() == true and LA.GetFromDb("display","showGroupLootAlerts") == true then
		--opted out of group loot alerts - play only your alerts
		---print('in group and true', IsInGroup)
		---print('source: ', source)

		if LA.GetFromDb("notification", "playSoundEnabled") then
			--PlaySound("AuctionWindowOpen", "master");
			if 	gatSoundToPlay == "A" then
				LA.Debug.Log("gatSound: " .. gatSoundToPlay)
				local soundNameA = LA.db.profile.notification.soundNameA or "None"
				PlaySoundFile(LSM:Fetch("sound", soundNameA), "master")
			elseif gatSoundToPlay == "B" then
				LA.Debug.Log("gatSound: " .. gatSoundToPlay)
				local soundNameB = LA.db.profile.notification.soundNameB or "None"
				PlaySoundFile(LSM:Fetch("sound", soundNameB), "master")
			elseif 	gatSoundToPlay == "C" then
				LA.Debug.Log("gatSound: " .. gatSoundToPlay)
				local soundNameC = LA.db.profile.notification.soundNameC or "None"
				PlaySoundFile(LSM:Fetch("sound", soundNameC), "master")
			else
				--
			end
		end

	elseif source == nil and not IsInGroup("player") then
		--player is not in a group and looting
		---print('not in group')
		if LA.GetFromDb("notification", "playSoundEnabled") then
			--PlaySound("AuctionWindowOpen", "master");
			if 	gatSoundToPlay == "A" then
				LA.Debug.Log("gatSound: " .. gatSoundToPlay)
				local soundNameA = LA.db.profile.notification.soundNameA or "None"
				PlaySoundFile(LSM:Fetch("sound", soundNameA), "master")
			elseif gatSoundToPlay == "B" then
				LA.Debug.Log("gatSound: " .. gatSoundToPlay)
				local soundNameB = LA.db.profile.notification.soundNameB or "None"
				PlaySoundFile(LSM:Fetch("sound", soundNameB), "master")
			elseif 	gatSoundToPlay == "C" then
				LA.Debug.Log("gatSound: " .. gatSoundToPlay)
				local soundNameC = LA.db.profile.notification.soundNameC or "None"
				PlaySoundFile(LSM:Fetch("sound", soundNameC), "master")
			else
				--
			end
		end

	elseif source == nil and IsInGroup("player") and LA.GetFromDb("display","showGroupLootAlerts") == false then
		--player is not in a group and looting
		--print('in group and false')
		if LA.GetFromDb("notification", "playSoundEnabled") then
			--PlaySound("AuctionWindowOpen", "master");
			if 	gatSoundToPlay == "A" then
				LA.Debug.Log("gatSound: " .. gatSoundToPlay)
				local soundNameA = LA.db.profile.notification.soundNameA or "None"
				PlaySoundFile(LSM:Fetch("sound", soundNameA), "master")
			elseif gatSoundToPlay == "B" then
				LA.Debug.Log("gatSound: " .. gatSoundToPlay)
				local soundNameB = LA.db.profile.notification.soundNameB or "None"
				PlaySoundFile(LSM:Fetch("sound", soundNameB), "master")
			elseif 	gatSoundToPlay == "C" then
				LA.Debug.Log("gatSound: " .. gatSoundToPlay)
				local soundNameC = LA.db.profile.notification.soundNameC or "None"
				PlaySoundFile(LSM:Fetch("sound", soundNameC), "master")
			else
				--
			end
		end
	end


	LA.UI.RefreshUIs()

	-- modules callback
	if not source and private.modules then
		for name, data in pairs(private.modules) do
			if data and data.callback and data.callback.itemDrop then
				local callback = data.callback.itemDrop
				callback(itemID, singleItemValue)
			end
		end
	end


	-- handle party loot
	if IsInGroup() and not source then
		--from player standpoint, if I'm in a group but NOT the one looting the item then do this
		--check new value 
--		LA:Print("inside")
		if LA.GetFromDb("display","showGroupLootAlerts") == false then
			--do nothing
--			LA:Print("do nothing")			
		else
--			LA:Print("here")
			private.SendAddonMsg(itemLink, itemID, quantity) 	--true = want to see group alerts - default is true
		end
	end
end
-- get item value based on the selected/requested price source
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
			AuctionatorInfo = Auctionator.API.v1.GetAuctionPriceByItemID("LootAppraiserReloaded", itemID)
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

-- handle looted currency
function private.HandleCurrencyLooted(lootedCopper)
	-- add to total looted currency
	--LA.Session.private.totalLootedCurrency = LA.Session.private.totalLootedCurrency + lootedCopper
	local totalLootedCurrency = (LA.Session.GetCurrentSession("totalLootedCurrency") or 0) + lootedCopper
	LA.Session.SetCurrentSession("totalLootedCurrency", totalLootedCurrency)

	LA.Debug.Log("  handle currency: add " .. tostring(lootedCopper) .. " copper -> new total: " .. tostring(totalLootedCurrency))

    LA.UI.RefreshUIs()
end

---------------------------------------------------------------------
-- handle vendor sales currency
---------------------------------------------------------------------
function private.HandleVendorSales(totalSoldValue)
	LA.Debug.Log("handle vendor sales: " .. totalSoldValue)
	-- add to total looted currency
	--LA.Session.private.totalLootedCurrency = LA.Session.private.totalLootedCurrency + lootedCopper
	local totalVendorSalesCurrency = (LA.Session.GetCurrentSession("vendorSoldCurrencyUI") or 0)
	LA.Debug.Log("total value: " .. totalVendorSalesCurrency)
	LA.Session.SetCurrentSession("vendorSoldCurrencyUI", totalVendorSalesCurrency)

    --LA.UI.RefreshUIs()
end
---------------------------------------------------------------------
---------------------------------------------------------------------

-- increase the noteworthy item counter
function private.IncNoteworthyItemCounter(quantity, source)
	if source then return end

	local noteworthyItemCounter = (LA.Session.GetCurrentSession("noteworthyItemCounter") or 0) + quantity
	LA.Session.SetCurrentSession("noteworthyItemCounter", noteworthyItemCounter)

	LA.Debug.Log("    noteworthy items counter: add " .. tostring(quantity) .. " -> new total: " .. tostring(noteworthyItemCounter))
end


function private.sellGrayItemsToVendor()
	local sellGrayItemsValue = tostring((LA.Session.GetCurrentSession("data_sellGrayItemsToVendor")) or 0)
	LA.Session.SetCurrentSession("data_sellGrayItemsToVendor", tostring(sellGrayItemsValue))
	LA.Debug.Log("Sell gray items: " .. sellGrayItemsValue)

end

function private.autoRepairGearOperations()
	--check to see if auto repair is toggled on (off by default)
	do
	--start repairing process - check for cost and current player currency to cover it
		if CanMerchantRepair() then				--Check to make sure merchant has repairing service available
		LA.Debug.Log("Merchant can repair")	
		local RepairCost = GetRepairAllCost()	--detects if player has enough currency for repairing all gear
			if RepairCost > 0 then 				--merchant can repair gear
				if GetMoney() >= RepairCost then
					RepairAllItems()
					-- Show cost summary
					LA.Debug.Log("Repair cost: " .. GetCoinTextureString(RepairCost))
					LA:Print("Repair cost: " .. GetCoinTextureString(RepairCost))
				end
			end
		end
	end
end	


-- increase the looted item counter
function private.IncLootedItemCounter(quantity, source)
	if source then return end
	local lootedItemCounter = (LA.Session.GetCurrentSession("lootedItemCounter") or 0) + quantity
	LA.Session.SetCurrentSession("lootedItemCounter", lootedItemCounter)
	LA.Debug.Log("    looted items counter: add " .. tostring(quantity) .. " -> new total: " .. tostring(lootedItemCounter))
end

-- add item value to looted item value and refresh ui
function private.AddItemValue2LootedItemValue(itemValue, source)
	local totalItemValue = LA.Session.GetCurrentSession("liv") or 0

	if not source then
		totalItemValue = totalItemValue + itemValue
		LA.Debug.Log("    looted items value: add " .. tostring(itemValue) .. " -> new total: " .. tostring(totalItemValue))
    end

    LA.Session.SetCurrentSession("liv", totalItemValue or 0)
	--LA.Debug.Log("LIV: " .. tostring(totalItemValue))
	
	if LA.UI.ShowLiteWindow then
		LA.UI.UpdateLiteWindowUI(totalItemValue or 0)	--sends total item value to Lite UI for updating
	end
		
    -- group
    local totalItemValueGroup = LA.Session.GetCurrentSession("livGroup") or 0
	totalItemValueGroup = totalItemValueGroup + itemValue
	LA.Debug.Log("    group: looted items value: add " .. tostring(itemValue) .. " -> new total: " .. tostring(totalItemValueGroup))
    LA.Session.SetCurrentSession("livGroup", totalItemValueGroup or 0)
end

--[[------------------------------------------------------------------------
-- checks if a item is blacklisted
--   check depends on the blacklist options (see config)
--------------------------------------------------------------------------]]
function LA.IsItemBlacklisted(itemID)
	--LA.Debug.Log("isItemBlacklisted(): itemID=" .. itemID)
	--LA.Debug.Log("  isBlacklistTsmGroupEnabled()=" .. tostring(private.IsBlacklistTsmGroupEnabled()))
	if not LA.GetFromDb("blacklist", "tsmGroupEnabled", "TSM_REQUIRED") then
		-- only use static list
		return LA.CONST.ITEM_FILTER_BLACKLIST[tostring(itemID)]
	end

	--local result = LA:isItemInList(itemID, blacklistItems)
	local result = LA.TSM.IsItemInGroup(itemID, LA.GetFromDb("blacklist", "tsmGroup"))
	--LA.Debug.Log("  isItemInList=" .. tostring(result))
	return result
end

-- get available price sources from the different modules
function private.GetAvailablePriceSources()
	local priceSources = {}

	-- TSM
	if LA.TSM.IsTSMLoaded() then
		priceSources = LA.TSM.GetAvailablePriceSources() or {}
	end

	-- OE (OribosExchange)
	if OEMarketInfo then
		priceSources["region"] = "OE: Median All Realms in Region"
		--priceSources["market"] = "OE: Median AH 4-Day"
	end

	if BlizzardVendorSell == 1 then
		priceSources["VendorValue"] = "Bliz: Vendor price"
	end

	-- Auctionator
	if (C_AddOns.IsAddOnLoaded("Auctionator")) and Auctionator and Auctionator.API and Auctionator.API.v1 and Auctionator.API.v1.RegisterForDBUpdate then
		priceSources["Auctionator"] = "AN: Auctionator"
	end



	return priceSources
end


-- init LootAppraiserReloaded db
function private.InitDB()
    LA.Debug.Log("InitDB")

    -- load the saved db values
    LA.db = LibStub:GetLibrary("AceDB-3.0"):New("LootAppraiserReloadedDB", LA.CONST.DB_DEFAULTS, true)
	
	-- Added db for tracking loot and sessions
	LALoot = LibStub("AceDB-3.0"):New("LALootDB", LA.CONST.DB_LOOT, true) --make sure global 
	
end

--[[--------------------------------------------------------------------------------------------------------------------
-- new
----------------------------------------------------------------------------------------------------------------------]]
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

	if tsmRequired and not LA.TSM.IsTSMLoaded() then
		return false
	end

    if LA.db.profile[grp][key] == nil then
        LA.db.profile[grp][key] = LA.CONST.DB_DEFAULTS.profile[grp][key]
    end
    return LA.db.profile[grp][key]
end

-- reset instance historie
local resetmsg = INSTANCE_RESET_SUCCESS:gsub("%%s",".+")
function private.OnResetInfoEvent(event, msg) --
    --if not LA.Session.IsRunning() then return end

    if event == "CHAT_MSG_SYSTEM" then
        if msg:match("^" .. resetmsg .. "$") then
            LA.Debug.Log("  match: " .. tostring(msg:match("^" .. resetmsg .. "$")))

            local instanceName = smatch(msg, INSTANCE_RESET_SUCCESS:gsub("%%s","(.+)"))

            local data = {["endTime"] = time() + 60*60, ["instanceName"] = instanceName}

			LA.UI.AddToResetInfo(data)
        end
    end
end

function LA.GetModules()
    return private.modules
end


-- legacy api for older LAC versions
function LA:RegisterModule(theModule)
    LA_API.RegisterModule(theModule)
end

-------------------------------------------------HERE 
-- 'start session' dialog --
function LA:ShowStartSessionDialog() 
	
	--Auto-start feature added 11.21.2020
	if LA.GetFromDb("general", "autoStartLA") == true then
		LA.Debug.Log("auto-start LA enabled")
		LA.Session.Start(showMainUI)
		return
	end
	--End auto-start feature 
	
	if LA.GetFromDb("general", "surpressSessionStartDialog") == true then
		local lootPrompt = LA.GetFromDb("general", "surpressSessionStartDialog")
		--LA:Print(tostring(LA.GetFromDb("general", "surpressSessionStartDialog")))
		if lootPrompt == true then return end
    end
	
	--if lootPrompt == true then return end -- return if they answered NO to the loot prompt
	if START_SESSION_PROMPT then return end -- gui is already open
			
	local openLootAppraiserReloaded = true

	-- create 'start session prompt' frame
	START_SESSION_PROMPT = AceGUI:Create("Frame")	
	START_SESSION_PROMPT:SetStatusTable(self.db.profile.startSessionPromptUI)
	START_SESSION_PROMPT:SetLayout("Flow")
	START_SESSION_PROMPT:SetTitle("Would you like to start a LootAppraiser Reloaded session?")
	START_SESSION_PROMPT:SetPoint("CENTER")
	START_SESSION_PROMPT:SetWidth(250)
	START_SESSION_PROMPT:SetHeight(115)
	START_SESSION_PROMPT:EnableResize(false)
	START_SESSION_PROMPT:SetCallback("OnClose",
		function(widget) 
			AceGUI:Release(widget)
			START_SESSION_PROMPT = nil
		end
	)
	
	-- Button: Yes
	local btnYes = AceGUI:Create("Button")
	btnYes:SetPoint("CENTER")
	btnYes:SetAutoWidth(true)
	btnYes:SetText("Yes" .. " ")
	btnYes:SetCallback("OnClick", 
		function()
			LA:StartSession(openLootAppraiserReloaded)
            START_SESSION_PROMPT:Release()
            START_SESSION_PROMPT = nil
		end
	)
	START_SESSION_PROMPT:AddChild(btnYes)
	
	-- Button: No
	local btnNo = AceGUI:Create("Button")
	btnNo:SetPoint("CENTER")
	btnNo:SetAutoWidth(true)
	btnNo:SetText("No" .. " ")
	btnNo:SetCallback("OnClick", 
		function()
			local curValue = LA.GetFromDb("general", "surpressSessionStartDialog")
			--LA:Print("Current value: " .. tostring(curValue))
			surpressSessionStartDialog = curValue
			local surpressSessionStartDialogStatus = curValue
			LA.db.profile.general.surpressSessionStartDialog = surpressSessionStartDialogStatus
			START_SESSION_PROMPT:Release()
            START_SESSION_PROMPT = true		-- added 2.13.2022 to support an answer of NO to not prompt again on loot making LA's start manual
		end
	)	
	START_SESSION_PROMPT:AddChild(btnNo)

	-- Checkbox: Open LA window	
	local checkboxOpenWindow = AceGUI:Create("CheckBox")
	checkboxOpenWindow:SetValue(openLootAppraiserReloaded)
	checkboxOpenWindow:SetLabel(" " .. "Open LootAppraiser Reloaded window")
	checkboxOpenWindow:SetCallback("OnValueChanged",
		function(value)
			--self:Debug("  OnValueChanged: value=%s", tostring(value))
			--LA:print_r(value)
			openLootAppraiserReloaded = value.checked
		end
	)

	START_SESSION_PROMPT:AddChild(checkboxOpenWindow)

	START_SESSION_PROMPT.statustext:Hide()
end



LA.METADATA = {
    VERSION = "2018." .. LA_API.GetVersion()
}

LA.QUALITY_FILTER = LA.CONST.QUALITY_FILTER

LA.PRICE_SOURCE = LA.CONST.PRICE_SOURCE

function LA:tablelength(t)
    return LA.Util.tablelength(t)
end

function LA:print_r(t)
    LA.Debug.TableToString (t)
end

function LA:D(msg, ...)
    LA.Debug.Log(msg, ...)
end

function LA:getCurrentSession()
    return LA.Session.GetCurrentSession()
end

function LA:StartSession(showMainUI)
    LA.Session.Start(showMainUI)
end

function LA:ShowMainWindow(showMainUI)
    LA.UI.ShowMainWindow(showMainUI)
end

function LA:NewSession()
    LA.Session.New()
end

function LA:pauseSession()
    LA.Session.Pause()
end

function LA:refreshStatusText()
    LA.UI.RefreshStatusText()
end
