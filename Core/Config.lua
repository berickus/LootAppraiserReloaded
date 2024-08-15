local LA = select(2, ...)

--local Config = {}
local Config = LA:NewModule("Config", "AceEvent-3.0")
LA.Config = Config

local private = {}


local LibStub = LibStub
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceGUI = LibStub("AceGUI-3.0")
local LSM = LibStub:GetLibrary("LibSharedMedia-3.0")


-- Lua APIs
local tostring, pairs, ipairs, table, tonumber, select, time, math, floor, date, print, type, string, sort, gsub =
tostring, pairs, ipairs, table, tonumber, select, time, math, floor, date, print, type, string, sort, gsub

-- wow APIs
local InterfaceOptions_AddCategory, SecondsToTime, GameFontHighlightSmall, GetItemInfo, GetMapInfo, TUJTooltip, StaticPopupDialogs, StaticPopup_Show =
InterfaceOptions_AddCategory, SecondsToTime, GameFontHighlightSmall, GetItemInfo, C_Map.GetMapInfo, TUJTooltip, StaticPopupDialogs, StaticPopup_Show
local DEFAULT_CHAT_FRAME = DEFAULT_CHAT_FRAME

-- the config tabs
-----------------------------------------
--TAB:  GENERAL
-----------------------------------------
local generalOptionsGroup =  {
    type = "group",
    order = 25,
    name = "General",
    get = function(info)
        return LA.db.profile.general[info[#info]]
    end,
    set = function(info, value)
        LA.db.profile.general[info[#info]] = value;
    end,
    args = {
		generalFeaturesHeader = { order = 30, type = "header", name = "General Features", },
        ignoreRandomEnchants = {
            type = "toggle", order = 40, name = "Ignore random enchants on items", desc = "Ignore random enchants on items (like ...of the Bear) and show only the base item", width = "double",
            set = function(info, value)
                local oldValue = LA.db.profile.general[info[#info]]
                if oldValue ~= value then
                    LA:Print("Ignore random enchants: " .. Config.FormatBoolean(value) .. ".")
                end
                LA.db.profile.general[info[#info]] = value;
            end,
        },

       surpressSessionStartDialog = {
           type = "toggle", order = 50, name = "Suppress 'Start Session' dialogue during first loot.", desc = "Attention! If the dialog is suppressed, the session must be started by hand (left-click on the minimap icon)", width = "double",
			set = function(info, value)
               --local oldValue = LA.db.profile.general[info[#info]]			    
			   local oldValue = LA.GetFromDb("general", "surpressSessionStartDialog")
			   local surpressSessionStartDialogStatus = oldValue
				
                if oldValue ~= value then
					surpressSessionStartDialogStatus = value
					LA:Print("Changing Suppression status to: " .. tostring(value) .. ".")
                end
                --LA.db.profile.general[info[#info]] = value;
				LA.db.profile.general.surpressSessionStartDialog = surpressSessionStartDialogStatus
				LA:Print("Changing Suppression status to: " .. tostring(value) .. ".")

            end,
        },

        
--------------------------------------------------------------------------
--New toggle for auto-starting LA upon first loot (11.21.2020)
--------------------------------------------------------------------------		
        autoStartLA = {
            type = "toggle", order = 55, name = "Auto-start without prompting",  desc = "Enabling this will auto-start LootAppraiser instead of prompting upon first loot.", width = "double",
            set = function (info, value)
                local oldValue = LA.db.profile.general[info[#info]]
                if oldValue ~= value then
                    LA:Print("Auto-start LootAppraiser: " .. Config.FormatBoolean(value) .. ".")
                end
                LA.db.profile.general[info[#info]] = value;
            end,
        },
--------------------------------------------------------------------------
--------------------------------------------------------------------------
		
        --Start:  New toggle for ignoring Soulbound items
        ignoreSoulboundItems = {
            type = "toggle", order = 60, name = "Ignore Soulbound items when looted",  desc = "Enabling this will NOT display soulbound items in the window but will still calculate their values in the totals.", width = "double",
            set = function (info, value)
                local oldValue = LA.db.profile.general[info[#info]]
                if oldValue ~= value then
                    LA:Print("Ignore soulbound items: " .. Config.FormatBoolean(value) .. ".")
                end
                LA.db.profile.general[info[#info]] = value;
            end,
        },
		--New Enhanced Features Added 2.6.2020
		enhancedFeaturesHeader = { order = 61, type = "header", name = "Enhanced Features", },
		sellGrayItemsToVendor = {
			type = "toggle", order = 62, name = "Auto Sell Gray Items", desc = "Auto sell gray items to vendor.", width = "double", 	--added 9.24.2019
			set = function (info, value)
                local oldValue = LA.db.profile.general[info[#info]]
                if oldValue ~= value then
                    LA:Print("Auto Sell Gray Items: " .. Config.FormatBoolean(value) .. ".")
                end
                LA.db.profile.general[info[#info]] = value;
            end,
        },
		--New Enhanced Feature to disable the item by item auto-sell gray messages and instead, just shows the total value sold 	--added 4.25.2021
        sellGrayItemsToVendorVerbose = {
			type = "toggle", order = 63, name = "Disable Verbose Auto Sell Gray Items Messages |cff00ff00NEW!|r", desc = "This will only display the total amount of gray items sold and not a per item message.", width = "double",
			set = function (info, value)
                local oldValue = LA.db.profile.general[info[#info]]
                if oldValue ~= value then
                    LA:Print("Disabling Verbose Auto Sell Gray Item Messages: " .. Config.FormatBoolean(value) .. ".")
                end
                LA.db.profile.general[info[#info]] = value;
            end,
        },
		autoRepairGear = {
			type = "toggle", order = 64, name = "Auto Repair Gear", desc = "Auto repair gear using your currency.", width = "double", 			--added 9.24.2019
			set = function (info, value)
                local oldValue = LA.db.profile.general[info[#info]]
                if oldValue ~= value then
                    LA:Print("Auto Repair: " .. Config.FormatBoolean(value) .. ".")
                end
                LA.db.profile.general[info[#info]] = value;
            end,
        },

        --End: New toggle for ignoring Soulbound items
        spacer2 = { type = "description", order = 65, name = " ", width = "full", },
        source = {
            type = "select", order = 70, name = "Price Source", desc = "Predefined price sources for item value calculation.", width = "double",
            values = function() return LA.availablePriceSources end,
            get = function(info)
                return LA.db.profile.pricesource[info[#info]]
            end,
            set = function(info, value)
                local oldValue = LA.db.profile.pricesource[info[#info]]
                if oldValue ~= value then
                    LA:Print("Price source changed to: " .. value)
                end
                LA.db.profile.pricesource[info[#info]] = value;
                LA.UI.RefreshStatusText()
            end,
            disabled = function(info)
                return not Config.SettingsChangeAllowed(info[#info])
            end,
        },
        customPriceSource = {
            type = "input", order = 80, name = "Custom Price Source", desc = "TSM Custom Price Source. See TSM documentation for detailed description.", width = "full",
            disabled = function()
                return not (LA.db.profile.pricesource.source == "Custom")
            end,
            get = function(info)
                return LA.db.profile.pricesource[info[#info]]
            end,
            set = function(info, value)
                LA:Print("Custom price source changed to: " .. value)
                LA.db.profile.pricesource[info[#info]] = value;
            end,
            validate = function(info, value)
                local isValidPriceSource = LA.TSM.ParseCustomPrice(value)
                if not isValidPriceSource then
                    -- error message
                    DEFAULT_CHAT_FRAME:AddMessage("Invalid custom price source. See TSM documentation for detailed description.")
                    return false
                end
                return true
            end,
        },
        useDisenchantValue = {
            type = "toggle", order = 90, desc = "Attention! Enabling this will use the disenchant value on the item even if you DO NOT have the profession.", width = "full",
            name = function()
                local name = "Use disenchant value when looting bind-on-pickup (BoP) items."
                if not LA.TSM.IsTSMLoaded() then
                    name = name .. " (requires TSM)"
                end
                return name
            end,
            disabled = function()
                return not LA.TSM.IsTSMLoaded()
            end,
            get = function(info)
                return LA.db.profile.pricesource[info[#info]]
            end,
            set = function(info, value)
                local oldValue = LA.db.profile.pricesource[info[#info]]
                if oldValue ~= value then
                    LA:Print("Enable using disenchant value: " .. Config.FormatBoolean(value) .. ".")
                end
                LA.db.profile.pricesource[info[#info]] = value;
            end,
        },
	


        --new price source for class and subclass

        useSubClasses = {
            type = "toggle", order = 93, desc = "Enabling this will allow an item tab for setting price sources by item class.", width = "full",
            name = function()
                local name = "Enable item class tab for multiple price sources. |cff00ff00NEW!|r"
                if not LA.TSM.IsTSMLoaded() then
                    name = name .. " (requires TSM)"
                end
                return name
            end, 
            disabled = function()
                return not LA.TSM.IsTSMLoaded()
            end, 
            set = function(info, value)
                local oldValue = LA.db.profile.general[info[#info]]
                if oldValue ~= value then
                    LA:Print("Enabling item classes: " .. Config.FormatBoolean(value) .. ".")
                end
                LA.db.profile.general[info[#info]] = value;
            end, 
        },



		supportGuildedHeader = { order = 95, type = "header", name = "Suggestions and Support", },
		
		guildedSupportSection = {
		type = "input", order = 96, name = "LootAppraiser Guilded:", desc = "Join the official LootAppraiser Guilded server to send in suggestions and get support.", width = "full", 
			get = function(info)
				return LA.CONST.LAGUILDED
			end,
			set = function(info, value)
				value = info
            end,
		},
    },
}

local tsmGroupsGroup =  {
    type = "group", order = 93, name = "TSM Groups",
    hidden = function()
        return not LA.TSM.IsTSMLoaded()
    end,
    --name = "Sell Trash",
    get = function(info)
        return LA.db.profile.sellTrash[info[#info]]
    end,
    set = function(info, value)
        LA.db.profile.sellTrash[info[#info]] = value;
    end,
    args = {
        sellTrashOptions = { type = "group", order = 10, name = "Sell Trash", hidden = false, inline = true,
            get = function(info)
                return LA.db.profile.sellTrash[info[#info]]
            end,
            set = function(info, value)
                LA.db.profile.sellTrash[info[#info]] = value;
            end,
            args = {
                description = {
                    type = "description", order = 10, fontSize = "medium", width = "full",
                    name = "The button sell trash always sells gray items. Here you can add a TSM group to the sell trash function. All items in this group will also be sold. \n|cffff0000Be careful:|r if your TSM group contains items of value and you click sell trash... then all items are gone... you have been warned.\n\nNote: TSM uses ` as group seperator.\n",
                },
                tsmGroupEnabled = {
                    type = "toggle", order = 20, name = " Sell trash via TSM group", desc = "Use a TSM group to define additional none gray items to sell at the vendor with the sell trash button", width = "full",
                    set = function(info, value)
                        local oldValue = LA.db.profile.sellTrash[info[#info]]
                        if oldValue ~= value then
                            LA:Print("Sell trash via TSM group: " .. Config.FormatBoolean(value) .. ".")
                        end
                        LA.db.profile.sellTrash[info[#info]] = value;
                    end,
                },
                tsmGroup = {
                    type = "input", order = 30, name = "TSM Group", desc = "The TSM Group with all the none gray items to sell at the vendor.\n\nYou can also drop an item into the input field to select the items TSM group as 'Sell Trash'-group.", width = "full",
                    disabled = function()
                        return not (LA.db.profile.sellTrash.tsmGroupEnabled == true)
                    end,
                    set = function(info, value)
                        local itemString = LA.TSM.ToItemString(value)
                        if itemString then
                            local path = LA.TSM.GetGroupPathByItem(value)
                            if not path then
                                StaticPopupDialogs["LA_UNGROUPED_ITEM"] = {
                                    text = "|cffff0000Invalid!|r This item is not in a TSM group.|r",
                                    button1 = OKAY,
                                    timeout = 0,
                                    whileDead = true,
                                    hideOnEscape = true
                                }
                                StaticPopup_Show("LA_UNGROUPED_ITEM")
                            else
                                LA.db.profile.sellTrash[info[#info]] = path;
                            end
                        else
                            LA.db.profile.sellTrash[info[#info]] = value;
                        end
                    end,
                },
                hint = {
                    type = "description", order = 40, fontSize = "medium", width = "full",
                    name = "Hint: You can also drop an item into the input field to select the items TSM group as 'Sell Trash'-group.",
                },
            },
            --        path = {
            --            type = "description", order = 40, fontSize = "medium", width = "full",
            --            name = function()
            --                return "Path: " .. LA.TSM.FormatGroupPath(LA.db.profile.sellTrash.tsmGroup)
            --            end
            --        }
        },
        blacklistOptions = { type = "group", order = 20, name = "Blacklist", hidden = false, inline = true,
            get = function(info)
                return LA.db.profile.blacklist[info[#info]]
            end,
            set = function(info, value)
                LA.db.profile.blacklist[info[#info]] = value;
            end,
            args = {
                description = {
                    type = "description", order = 10, fontSize = "medium", width = "full",
                    name = "The blacklist is intended for all worthless items. They can not be sold to the vendor and the auction value is only theoretical (like the idols and scarabs from AQ20). Therefore, these objects are ignored in the calculation of the looted itemvalue.\n\nNote: TSM uses ` as group seperator.\n",
                },
                addBlacklistedItems2DestroyTrash = {
                    type = "toggle", order = 20, name = " Add blacklisted items to the destroy trash button.", desc = "Adds all blacklisted items from the TSM group to the destroyabel items list.", width = "full",
                    set = function(info, value)
                        local oldValue = LA.db.profile[info[#info]]
                        if oldValue ~= value then
                            LA:Print("Add blacklisted items to destroy trash: " .. Config.FormatBoolean(value) .. ".")
                        end
                        LA.db.profile.blacklist[info[#info]] = value;
                    end,
                },
                tsmGroupEnabled = {
                    type = "toggle", order = 30, name = " Blacklist via TSM group", desc = "Use a TSM group to define blacklisted items. If deactivated LootAppraiser uses the old unmaintained list.", width = "full",
                    set = function(info, value)
                        local oldValue = LA.db.profile.blacklist[info[#info]]
                        if oldValue ~= value then LA:Print("Blacklist items via TSM group: " .. Config.FormatBoolean(value) .. ".") end
                        LA.db.profile.blacklist[info[#info]] = value;
                    end,
                    disabled = function(info)
                        return not Config.SettingsChangeAllowed(info[#info])
                    end,
                },
                tsmGroup = {
                    type = "input", order = 40, name = "TSM Group", desc = "The TSM Group with all the blacklisted items.\n\nYou can also drop an item into the input field to select the items TSM group as 'Blacklist'-group.", width = "full",
                    disabled = function()
                        return not (LA.db.profile.blacklist.tsmGroupEnabled == true)
                    end,
                    set = function(info, value)
                        local itemString = LA.TSM.ToItemString(value)
                        if itemString then
                            local path = LA.TSM.GetGroupPathByItem(value)
                            if not path then
                                StaticPopupDialogs["LA_UNGROUPED_ITEM"] = {
                                    text = "|cffff0000Invalid!|r This item is not in a TSM group.|r",
                                    button1 = OKAY,
                                    timeout = 0,
                                    whileDead = true,
                                    hideOnEscape = true
                                }
                                StaticPopup_Show("LA_UNGROUPED_ITEM")
                            else
                                LA.db.profile.blacklist[info[#info]] = path;
                            end
                        else
                            LA.db.profile.blacklist[info[#info]] = value;
                        end
                    end,
                },
                hint = {
                    type = "description", order = 50, fontSize = "medium", width = "full",
                    name = "Hint: You can also drop an item into the input field to select the items TSM group as 'Blacklist'-group.",
                },
            },
        },
    },
}

local options = {
    type = "group",
    args = {
        general = { type = "group", name = "LootAppraiser " .. LA.CONST.METADATA.VERSION, childGroups = "tab",
            get = function(info) return LA.db.profile[info[#info]] end,
            set = function(info, value)
                LA.db.profile[info[#info]] = value;
                LA.UI.RefreshStatusText()
            end,
            args = {
                generalOptionsGrp = generalOptionsGroup,
                -----------------------------------------
                --TAB:  NOTIFICATIONS
                -----------------------------------------
                notificationOptionsGrp = { type = "group", order = 75, name = "Notifications",
                    get = function(info) return LA.db.profile.notification[info[#info]] end,
					set = function(info, value) LA.db.profile.notification[info[#info]] = value end,
                    args = {
                        noteworthyItemOutputHeader = { order = 100, type = "header", name = "Noteworthy Item Output Channel", },
                        notificationLibSink = LA:GetSinkAce3OptionsDataTable(),
                        
						--To Do:  Fix / remove LibToast issues
                        enableToasts = { type = "toggle", order = 300, name = "Enable Toasts", desc = "Enable Toasts", width = "double",
                            set = function(info, value)
                                local oldValue = LA.db.profile.notification[info[#info]]
                                if oldValue ~= value then LA:Print("Enable Toasts set: " .. Config.FormatBoolean(value) .. ".") end
                                LA.db.profile.notification[info[#info]] = value;
                            end,
                        },
						
                        noteworthyItemSoundHeader = { order = 400, type = "header", name = "Noteworthy Item Sound", },
                        playSoundEnabled = { order = 425, type = "toggle", name = "Play Sound", width = "double", desc = "Play Sound", },
						
						qualityFilter = {
							type = "select", order = 427, name = "Quality Filter", width = "double", desc = "Items below the selected quality will not show in the loot collected list",  values = LA.CONST.QUALITY_FILTER,
							set = function(info, value)
								local oldValue = LA.db.profile.notification[info[#info]]
								if oldValue ~= value then
									LA:Print("Quality Filter set to: " .. LA.CONST.QUALITY_FILTER[value] .. " and above.")
								end
								LA.db.profile.notification[info[#info]] = value;
								LA.UI.RefreshStatusText()
							end,
							disabled = function(info)
								return not Config.SettingsChangeAllowed(info[#info])
							end,
						},



                        --Added 2 more sound alerts to support multiple GATs

                        spacer = { type = "description", order = 440, name = " ", width = "half", },
						
                        goldAlertThresholdA = {
                            type = "input", order = 449, name = "Gold Alert Threshold", desc = "Threshold for gold alert",
                            set = function(info, value)
                                local oldValue = LA.db.profile.notification[info[#info]]
								LA.Debug.Log("oldValue: " .. oldValue)
                                if oldValue ~= value then
                                    LA:Print("Gold alert threshold A set: " .. value .. "|cffffd100g|r or higher.")
                                    LA.Debug.Log("change detected: " .. tostring(value))
									
									
                                end
                                --LA.db.profile.general[info[#info]] = value;
								LA.db.profile.notification[info[#info]] = value;
                                LA.UI.RefreshStatusText()
                            end,
                        },

                        goldAlertThresholdB = {
                            type = "input", order = 454, name = "Gold Alert Threshold", desc = "Threshold for gold alert",
                            set = function(info, value)
                                local oldValue = LA.db.profile.notification[info[#info]]
                                if oldValue ~= value then
                                    LA:Print("Gold alert threshold B set: " .. value .. "|cffffd100g|r or higher.")
                                end
                                LA.db.profile.notification[info[#info]] = value;
                                LA.UI.RefreshStatusText()
                            end,
                        },

                        goldAlertThresholdC = {
                            type = "input", order = 457, name = "Gold Alert Threshold", desc = "Threshold for gold alert",
                            set = function(info, value)
                                local oldValue = LA.db.profile.notification[info[#info]]
                                if oldValue ~= value then
                                    LA:Print("Gold alert threshold C set: " .. value .. "|cffffd100g|r or higher.")
                                end
                                LA.db.profile.notification[info[#info]] = value;
                                LA.UI.RefreshStatusText()
                            end,
                        },

                        soundNameA = { order = 450, type = "select", name = "Sound A", desc = "GAT Sound A", width = "double", dialogControl = "LSM30_Sound", values = LSM:HashTable("sound"),
                        disabled = function() return not LA.db.profile.notification.playSoundEnabled end,},
                        soundNameB = { order = 455, type = "select", name = "Sound B", desc = "GAT Sound B", width = "double", dialogControl = "LSM30_Sound", values = LSM:HashTable("sound"),
                                      disabled = function() return not LA.db.profile.notification.playSoundEnabled end,},
                        soundNameC = { order = 458, type = "select", name = "Sound C", desc = "GAT Sound C", width = "double", dialogControl = "LSM30_Sound", values = LSM:HashTable("sound"),
                                      disabled = function() return not LA.db.profile.notification.playSoundEnabled end,},
                    },
                },
                

                

















                -----------------------------------------
                -- New options for enabling multiple price sources by item class added 4.25.2021
                -----------------------------------------

                subClassOptions = {type = "group", order = 85, name = "Item Classes", --hidden = false,
                --detect check box from General to hide/unhide Sub Class tab
                hidden = function()                    
                    return not LA.db.profile.general.useSubClasses
                end,
                    args = {
                        itemClassOptions = {type = "group", order = 10, name = "Item Classes", hidden = false, inline = true,
                        --itemSubClassesOptions = {type = "group", order = 50, name = "Item Sub Class", hidden = false, inline = true,
                        -- class = Consumable, Weapon, Armor, Reagent, Tradeskill, Item Enhancement, Recipe, Glyph, Battle Pets, Quest, Gem, Projectile, Quiver                 
                        args = {
                            --lootedItemListRowCount = { type = "range", order = 5, name = "Looted Item List: number of rows", desc = "Number of rows in the looted item list", min = 3, max = 10, step = 1, width = "double", },
                            generalSubClassText = { type = "description", order = 10, fontSize = "medium",name = "This section allows setting separate price sources based upon the Blizzard defined item classes.  Select the Item Class you want to enable and enter a valid price source. Tip:  If you are using TSM and want to know valid price sources, type:  /tsm sources and select from AuctionDB or External like TUJ.\n\n  [Examples:  vendorsell, dbminbuyout, dbmarketvalue, dbregionsaleavg, etc.]",width = "full", },
                            --toggle - description is enabled - price source drop down? - set button?
                            classTypeArmor = { type = "toggle", order = 30, name = "Armor", desc = "Set a price source for Armor", },
                            classTypeArmorPriceSource = { type = "input", order = 35, name = "Armor Price Source", desc = "Enter a valid TSM Price Source. See TSM documentation for detailed description.", width = "double", 
                            disabled = function()
                                return not LA.db.profile.classTypeArmor
                            end,
                        },

                            classTypeConsumable = { type = "toggle", order = 40, name = "Consumable", desc = "Set a price source for Consumables (drinks, elixirs, flasks, foods, potions, scrolls, etc.)", },
                            classTypeConsumablePriceSource = { type = "input", order = 45, name = "Consumable Price Source", desc = "Enter a valid TSM Price Source. See TSM documentation for detailed description.", width = "double",
                            disabled = function()
                                return not LA.db.profile.classTypeConsumable
                            end,                        
                        },

                            classTypeRecipe = { type = "toggle", order = 45, name = "Recipe", desc = "Set a price source for Recipes covering all professions", },
                            classTypeRecipePriceSource = { type = "input", order = 46, name = "Recipe Price Source", desc = "Enter a valid TSM Price Source. See TSM documentation for detailed description.", width = "double",
                            disabled = function()
                                return not LA.db.profile.classTypeRecipe
                            end,                                         
                         },

                            classTypeTradeskill = { type = "toggle", order = 50, name = "Tradeskill", desc = "Set a price source for Tradeskills (herbs, metal, stone, leather, cloth, etc.)", },
                            classTypeTradeskillPriceSource = { type = "input", order = 55, name = "Tradeskill Price Source", desc = "Enter a valid TSM Price Source. See TSM documentation for detailed description.", width = "double",
                            disabled = function()
                                return not LA.db.profile.classTypeTradeskill
                            end,                                         
                        },

                            classTypeWeapon = { type = "toggle", order = 60, name = "Weapon", desc = "Set a price source for Weapons", },
                            classTypeWeaponPriceSource = { type = "input", order = 65, name = "Weapon Price Source", desc = "Enter a valid TSM Price Source. See TSM documentation for detailed description.", width = "double",
                            disabled = function()
                                return not LA.db.profile.classTypeWeapon
                            end,                                       
                        },

                            classTypeQuest = { type = "toggle", order = 70, name = "Quest", desc = "Set a price source for sellable Quest items",},
                            classTypeQuestPriceSource = { type = "input", order = 75, name = "Quest Price Source", desc = "Enter a valid TSM Price Source. See TSM documentation for detailed description.", width = "double",
                            disabled = function()
                                return not LA.db.profile.classTypeQuest
                            end,                                                                                                                   
                        },
                        },  
                    },
                    },
                },
            

                
                
                
                
                
                
                
                
                -----------------------------------------
                --TAB:  DISPLAY
                -----------------------------------------
                displayOptions = { type = "group", order = 90, name = "Display", hidden = false,
                    get = function(info) return LA.db.profile.display[info[#info]] end,
                    set = function(info, value)
                        LA.db.profile.display[info[#info]] = value
                        LA.UI.PrepareDataContainer()
                    end,
                    args = {
                        displayMainUiOptions = { type = "group", order = 10, name = "Main UI", hidden = false, inline = true,
                            args = {
                                lootedItemListRowCount = { type = "range", order = 5, name = "Looted Item List: number of rows", desc = "Number of rows in the looted item list", min = 3, max = 10, step = 1, width = "double", },
                                showLootedItemValue = { type = "toggle", order = 30, name = "Show 'Looted Item Value'", desc = "Show 'Looted Item Value'", width = "double", },
                                showXXXLootedItemValuePerHour = { type = "toggle", order = 40, name = "Show 'Looted Item Value' Per Hour", desc = "Show 'Looted Item Value' Per Hour (in parentes behind the Looted Item Value)", width = "double", },
                                showCurrencyLooted = { type = "toggle", order = 50, name = "Show 'Currency Looted'", desc = "Show 'Currency Looted'", width = "double", },
                                showItemsLooted = { type = "toggle", order = 60, name = "Show 'Items Looted'", desc = "Show 'Items Looted'", width = "double", },
                                showNoteworthyItems = { type = "toggle", order = 70, name = "Show 'Noteworthy Items'", desc = "Show 'Noteworthy Items'", width = "double", },
								showDetroyTrashBtn =  { type = "toggle", order = 71, name = "Show 'Destroy Trash' button (/reload required)", desc = "Show 'Destroy Trash' button", width = "double", },
								showSellTrashBtn =  { type = "toggle", order = 72, name = "Show 'Sell Trash' button (/reload required)", desc = "Show 'Sell Trash' button", width = "double", },
								showValueSoldToVendor =  { type = "toggle", order = 73, name = "Show Gray Value Sold to Vendors", desc = "Show the currency made from selling gray items to vendors.", width = "double", },
                                resetInstanzeHeader = { order = 75, type = "header", name = "Reset Instance", },
                                showResetInstanceButton = { type = "toggle", order = 80, name = "Show 'Reset Instance' Button (/reload required)", desc = "Show 'Reset Instance' Button", width = "double", set = function(info, value) LA.db.profile.display[info[#info]] = value end, },
                                descResetInstanceButton = { type = "description", order = 85, fontSize = "medium", name = "The displayed instance lockout should only help to optimize the 10 instance resets per hour. Not more and not less. No lockout magic, cross char tracking or such stuff.\n", width = "full", },

                                groupLootHeader = { order = 100, type = "header", name = "Group Loot", },
                                showLootedItemValueGroup = { type = "toggle", order = 110, name = "Show 'Group: Looted Item Value'", desc = "Show 'Group: Looted Item Value'", width = "double", },
                                showLootedItemValueGroupPerHour = { type = "toggle", order = 120, name = "Show 'Group: Looted Item Value' Per Hour", desc = "Show 'Group: Looted Item Value' Per Hour (in parentes behind the Group: Looted Item Value)", width = "double", },
                                addGroupDropsToLootedItemList =  { type = "toggle", order = 130, name = "Add Group Drops to 'Looted Item List'", desc = "Add Group Drops to 'Looted Item List'", width = "double", },
                                --showGroupLootAlerts = { type = "toggle", order=132,name="Opt-out Group/party loot alerts", desc = "Check to NOT see group/party loot alerts", width = "double", },
                              
                              
                              
                                showGroupLootAlerts = {type = "toggle", order=132,name="Opt-in Group/party loot alerts", desc = "Check to see group/party loot alerts", width = "double", 			--added 9.24.2019
                                set = function (info, value)
                                    local oldValue = LA.db.profile.display[info[#info]]
                                    if oldValue ~= value then
                                        LA:Print("Group Loot Alerting: " .. Config.FormatBoolean(value) .. ".")
                                    end
                                    LA.db.profile.display[info[#info]] = value;
                                end,
                                },



                            },
                            plugins = {},
                        },
                        displayLastNoteworthyItemOptions = { type = "group", order = 20, name = "Additional LootAppraiser 'Lite' windows", hidden = false, inline = true,
                            args = {
                                enableLastNoteworthyItemUI = { type = "toggle", order = 10, name = "Enable 'Last Noteworthy Item' UI", desc = "Enables the 'Last Noteworthy Item' UI", width = "double", },
                                enableLootAppraiserLite = { type = "toggle", order = 10, name = "Enable 'LootAppraiser Lite' UI", desc = "Enables the 'LootAppraiser Lite' UI which shows the looted item value.", width = "double", },
                                enableLootAppraiserTimerUI = { type = "toggle", order = 10, name = "Enable 'Timer' UI", desc = "Enables the 'Timer' UI.", width = "double", set = function(info, value) LA.db.profile.display[info[#info]] = value end, },
                            },
                            plugins = {},
                        },
                        displayMiscOptions = { type = "group", order = 40, name = "Misc", hidden = false, inline = true,
                            args = {
                                enableTUJTooltip = { type = "toggle", order = 5, name = "Show TUJ prices in tooltip", width = "full",
                                    hidden = function()
                                        if not TUJTooltip then return true end
                                        return false
                                    end,
                                    set = function(info, value)
                                        LA.db.profile.display[info[#info]] = value
                                        TUJTooltip(value)
                                    end,
                                },
                                enableMinimapIcon = { type = "toggle", order = 20, name = "Show minimap icon", width = "full",
                                    get = function(info) return not LA.db.profile.minimapIcon.hide end,
                                    set = function(info, value)
                                        LA.db.profile.minimapIcon.hide = not value
                                        if LA.db.profile.minimapIcon.hide == true then
                                            LA.icon:Hide(LA.CONST.METADATA.NAME)
                                        else
                                            LA.icon:Show(LA.CONST.METADATA.NAME)
                                        end
                                    end,
                                },
                                resetFramesButton = { type = "execute", order = 30, name = "reset frames", desc = "reset the position of all loot appraiser frames (or /la freset)",
                                    func = function()
                                        LA.UI.ResetFrames()
                                    end,
                                },
                            },
                            plugins = {},
                        },
                    },
                    plugins = {},
                },
                tsmGroupsGrp = tsmGroupsGroup,
                -----------------------------------------
                --TAB:  ABOUT
                -----------------------------------------
                aboutGroup = { type = "group", order = 100, name = "About",
                    args = {
                        generalText = { type = "description", order = 10, fontSize = "medium",name = "LootAppraiser is an addon which determines an item's value when looted based upon a pricing source you select. It keeps track of all gold asset value of the items in total including a quality item filter. Perfect for farming and determining gold asset value or potential gold-per-hour.\n\nThe reason Profitz developed this addon was because while proving out some gold earnings via farming, he was using spreadsheets for post-run calculations on item values and pricing models. Now, we all can just run this addon, select the price source we want and let it calculate it for us!\n\nPlease understand, this addon does NOT determine liquid gold you are guaranteed to make but rather, potential ‘asset’ values (looted item value) of items looted where you will have to do the work and sell it on the Auction House, trade chat, etc.\n",width = "full", },
						contactDetailsHeader = { order = 11, type = "header", name = "Contact Details", },
                        generalText20 = { type = "description", order = 20, fontSize = "medium", name = "\nCreator/Author/Developer: ProfitzTV", width = "full", },
                        blank26 = { type = "description", order = 26, fontSize = "small", name = "", width = "full", },
                        generalText30 = { type = "description", order = 30, fontSize = "medium", name = "Twitter:", width = "half", },
                        generalText35 = { type = "description", order = 35, fontSize = "medium", name = "ProfitzTV (https://www.twitter.com/ProfitzTV)", width = "double", },
                        blank36 = { type = "description", order = 36, fontSize = "small", name = "", width = "full", },
                        generalText40 = { type = "description", order = 40, fontSize = "medium", name = "Twitch:", width = "half", },
                        generalText45 = { type = "description", order = 45, fontSize = "medium", name = "ProfitzTV (https://www.twitch.tv/ProfitzTV)", width = "double", },
                        blank46 = { type = "description", order = 46, fontSize = "small", name = "", width = "full", },
                        generalText47 = { type = "description", order = 47, fontSize = "medium", name = "YouTube:", width = "half", },
                        generalText48 = { type = "description", order = 48, fontSize = "medium", name = "ProfitzTV (https://www.youtube.com/ProfitzTV)", width = "double", },
						blank47 = { type = "description", order = 49, fontSize = "small", name = "", width = "full", },
						generalText49 = { type = "description", order = 50, fontSize = "medium", name = "Guilded:", width = "half", },
                        generalText50 = { type = "description", order = 51, fontSize = "medium", name = LA.CONST.LAGUILDED, width = "double", },
                        blank49 = { type = "description", order = 52, fontSize = "small", name = "", width = "full", },
						--generalText51 = { type = "description", order = 53, fontSize = "medium", name = "Email:", width = "half", },
                        --generalText55 = { type = "description", order = 55, fontSize = "medium", name = "WowProfitz@gmail.com", width = "double", },
                        generalText60 = { type = "description", order = 60, fontSize = "medium", name = "\nFormer Co-Author/Developer:  Testerle", width = "full", },
                        blank66 = { type = "description", order = 66, fontSize = "small",name = "",width = "full", },
                        --generalText70 = { type = "description", order = 70, fontSize = "medium", name = "Twitter:", width = "half", },
                        --generalText75 = { type = "description", order = 75, fontSize = "medium", name = "@Testerle (https://twitter.com/Testerle)", width = "double", },
                        --blank76 = { type = "description", order = 76, fontSize = "small", name = "", width = "full", },
                        --generalText77 = { type = "description", order = 77, fontSize = "medium", name = "Twitch:", width = "half", },
                        --generalText78 = { type = "description", order = 78, fontSize = "medium", name = "Testerle (http://www.twitch.tv/testerle)", width = "double", },
                        --blank79 = { type = "description", order = 79, fontSize = "small",name = "",width = "full", },
                        earlyAdoptersHeader = { order = 81, type = "header", name = "Early Adopters/Beta Testers:", },	
                        generalText100 = { type = "description", order = 100, fontSize = "medium", name = "ACubed10, Brozerian, Conzec89, Goldgoblin, DozerBob, Fatherfajita, GoblinRaset, Hxtasy, JuniorDeBoss, Killerdamage, Morricade, PhatLewts, Selltacular, Skittlezz420, Soulslicer, Pellew", width = "full", },
                    },
                },
            },
        },
    },
}


function Config:OnEnable()
    -- init config 'module'
    LA.Debug.Log("Config - Init")

   	-- register sounds
    LSM:Register("sound", "Auction Window Open", 567482) -- AuctionWindowOpen
    LSM:Register("sound", "Auction Window Close", 567499) -- AuctionWindowClose
    LSM:Register("sound", "Auto Quest Complete", 567476) -- AutoQuestComplete
    LSM:Register("sound", "Level Up", 567431) -- LevelUp
    LSM:Register("sound", "Player Invite", 567451) -- iPlayerInviteA
    LSM:Register("sound", "Raid Warning", 567397) -- RaidWarning
    LSM:Register("sound", "Ready Check", 567409) -- ReadyCheck

    -- general LootAppraiser configuration
    AceConfigRegistry:RegisterOptionsTable("LootAppraiser", options.args.general)
    --AceConfigRegistry:RegisterOptionsTable("LootAppraiser Statistic", options.args.statistic, "LootAppraiser")

    local lootAppraiserConfig = AceConfigDialog:AddToBlizOptions("LootAppraiser")
    lootAppraiserConfig.default = private.resetDB -- add reset function

    -- Fix sink config options
    options.args.general.args.notificationOptionsGrp.args.notificationLibSink.order = 200
    options.args.general.args.notificationOptionsGrp.args.notificationLibSink.inline = true
    options.args.general.args.notificationOptionsGrp.args.notificationLibSink.name = ""
	
end

-- reset loot appraiser db
function private.resetDB()
    LA.Debug.Log("Config.resetDB")

    LA.db:ResetProfile(false, true)

    AceConfigRegistry:NotifyChange("LootAppraiser")
end


function Config.FormatBoolean(flag)
    if flag then
        return "|cff00ff00" .. "activated" .. "|r"
    else
        return "|cffff0000" .. "deactivated" .. "|r"
    end
end

function Config.SettingsChangeAllowed(setting)
    LA.Debug.Log("SettingsChangeAllowed: name=" .. tostring(setting))
    local modules = LA.GetModules()
    if modules then
        for name, data in pairs(modules) do
            if data and data.callback and data.callback.settingsChangeAllowed then
                local callback = data.callback.settingsChangeAllowed

                return callback(setting)
            end
        end
    end
    return true -- default
end