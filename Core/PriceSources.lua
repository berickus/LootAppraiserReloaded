local LA = select(2, ...)

local PriceSources = {}
LA.PriceSources = PriceSources

local private = {}

-- External globals
local OEMarketInfo = OEMarketInfo
local BlizzardVendorSell = 1

-- Wow APIs
local GetItemInfo, StaticPopupDialogs, StaticPopup_Show = GetItemInfo,
                                                          StaticPopupDialogs,
                                                          StaticPopup_Show
local OKAY = OKAY

--[[------------------------------------------------------------------------
    Get available price sources from loaded addons
--------------------------------------------------------------------------]]
function PriceSources.GetAvailable()
    local priceSources = {}

    -- TSM
    if LA.TSM.IsTSMLoaded() then
        priceSources = LA.TSM.GetAvailablePriceSources() or {}
    end

    -- OE (OribosExchange)
    if OEMarketInfo then
        priceSources["region"] = "OE: Median All Realms in Region"
    end

    -- Blizzard vendor price
    if BlizzardVendorSell == 1 then
        priceSources["VendorValue"] = "Bliz: Vendor price"
    end

    -- Auctionator
    if (C_AddOns.IsAddOnLoaded("Auctionator")) and Auctionator and
        Auctionator.API and Auctionator.API.v1 and
        Auctionator.API.v1.RegisterForDBUpdate then
        priceSources["Auctionator"] = "AN: Auctionator"
    end

    return priceSources
end

--[[------------------------------------------------------------------------
    Validate and prepare price sources on addon enable
--------------------------------------------------------------------------]]
function PriceSources.Prepare()
    LA.Debug.Log("PreparePricesources()")

    local priceSources = PriceSources.GetAvailable() or {}

    -- No price sources available at all
    if LA.Util.tablelength(priceSources) == 0 then
        StaticPopupDialogs["LA_NO_PRICESOURCES"] = {
            text = "|cffff0000Attention!|r Missing additional addons for price sources (e.g. like TradeSkillMaster, Oribos Exchange, or Auctionator).\n\n|cffff0000LootAppraiser Reloaded disabled.|r",
            button1 = OKAY,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true
        }
        StaticPopup_Show("LA_NO_PRICESOURCES")

        LA:Print(
            "|cffff0000LootAppraiser Reloaded disabled.|r (see popup window for further details)")
        LA:Disable()
        return
    end

    -- Validate current price source selection
    local priceSource = LA.GetFromDb("pricesource", "source")

    if priceSource == "Custom" then
        local isValid = LA.TSM.ParseCustomPrice(
                            LA.GetFromDb("pricesource", "customPriceSource"))
        if not isValid then
            StaticPopupDialogs["LA_INVALID_CUSTOM_PRICESOURCE"] = {
                text = "|cffff0000Attention!|r You have selected 'Custom' as price source but your formular is invalid (see TSM documentation for detailed custom price source informations).\n\n" ..
                    (LA.GetFromDb("pricesource", "customPriceSource") or
                        "-empty-"),
                button1 = OKAY,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true
            }
            StaticPopup_Show("LA_INVALID_CUSTOM_PRICESOURCE")
        end
    else
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

    LA.availablePriceSources = priceSources
end

--[[------------------------------------------------------------------------
    Get item value based on the selected/requested price source
--------------------------------------------------------------------------]]
function PriceSources.GetItemValue(itemID, priceSource)
    local currentSource = LA.CONST.PRICE_SOURCE[LA.GetFromDb("pricesource",
                                                             "source")] or ""

    if LA.Util.startsWith(currentSource, "OE:") or
        LA.Util.startsWith(currentSource, "AN:") or
        LA.Util.startsWith(currentSource, "BLIZ:") then

        if priceSource == "VendorSell" then
            return select(11, GetItemInfo(itemID)) or 0

        elseif priceSource == "VendorValue" then
            return select(11, GetItemInfo(itemID)) or 0

        elseif priceSource == "region" then
            local priceInfo = {}
            OEMarketInfo(itemID, priceInfo)
            return priceInfo[priceSource]

        elseif priceSource == "Auctionator" then
            return Auctionator.API.v1.GetAuctionPriceByItemID(
                       "LootAppraiserReloaded", itemID)

        else
            -- Battle pet handling
            local newItemID = LA.PetData.ItemID2Species(itemID)
            local priceInfo = {}
            return priceInfo[priceSource]
        end
    else
        -- TSM price source
        return LA.TSM.GetItemValue(itemID, priceSource)
    end
end

--[[------------------------------------------------------------------------
    Resolve effective price source for an item (handles class-based overrides)
--------------------------------------------------------------------------]]
function PriceSources.ResolveForItem(itemID, basePriceSource)
    local priceSource = basePriceSource

    if priceSource == "Custom" then
        priceSource = LA.GetFromDb("pricesource", "customPriceSource")
        LA.Debug.Log("CP here: " .. tostring(priceSource))
    end

    -- Class-based price source overrides
    if LA.db.profile.general.useSubClasses == true then
        local class = select(6, GetItemInfo(itemID)) or 0
        local classOverrides = {
            ["Armor"] = {
                enabled = LA.db.profile.classTypeArmor,
                source = LA.db.profile.classTypeArmorPriceSource
            },
            ["Consumable"] = {
                enabled = LA.db.profile.classTypeConsumable,
                source = LA.db.profile.classTypeConsumablePriceSource
            },
            ["Recipe"] = {
                enabled = LA.db.profile.classTypeRecipe,
                source = LA.db.profile.classTypeRecipePriceSource
            },
            ["Tradeskill"] = {
                enabled = LA.db.profile.classTypeTradeskill,
                source = LA.db.profile.classTypeTradeskillPriceSource
            },
            ["Weapon"] = {
                enabled = LA.db.profile.classTypeWeapon,
                source = LA.db.profile.classTypeWeaponPriceSource
            },
            ["Quest"] = {
                enabled = LA.db.profile.classTypeQuest,
                source = LA.db.profile.classTypeQuestPriceSource
            }
        }

        local override = classOverrides[class]
        if override and override.enabled == true then
            priceSource = override.source
            LA.Debug.Log(class .. " price source: " .. tostring(priceSource))
        end
    end

    return priceSource
end
