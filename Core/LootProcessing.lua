local LA = select(2, ...)

local LootProcessing = {}
LA.LootProcessing = LootProcessing

local private = {}

-- Libs
local LibToast = LibStub("LibToast-1.0")
local LSM = LibStub:GetLibrary("LibSharedMedia-3.0")
local LibParse = LibStub:GetLibrary("LibParse")

-- Wow APIs
local GetItemInfo, IsInGroup, UnitGUID, GetUnitName, GetBestMapForUnit,
      PlaySoundFile, SendAddonMessage, IsShiftKeyDown = GetItemInfo, IsInGroup,
                                                        UnitGUID, GetUnitName,
                                                        C_Map.GetBestMapForUnit,
                                                        PlaySoundFile,
                                                        C_ChatInfo.SendAddonMessage,
                                                        IsShiftKeyDown

-- Lua APIs
local tonumber, tostring, floor, pairs, gsub, time = tonumber, tostring, floor,
                                                     pairs, gsub, time

local LootAppraiserReloaded_GroupLoot = LootAppraiserReloaded_GroupLoot

--[[------------------------------------------------------------------------
    Main item processing entry point
--------------------------------------------------------------------------]]
function LootProcessing.HandleItemLooted(itemLink, itemID, quantity, source)
    LA.Debug.Log("handleItemLooted itemID=%s", itemID)
    LA.Debug.Log("*****Source: " .. tostring(source))
    LA.Debug.Log(
        "  " .. tostring(itemID) .. ": " .. tostring(itemLink) .. " x" ..
            tostring(quantity))
    LA.Debug.Log("  " .. tostring(itemID) .. ": " ..
                     tostring(gsub(tostring(itemLink), "\124", "\124\124")))

    if not LA.Session.IsRunning() then return end

    -- Settings
    local qualityFilter =
        tonumber(LA.GetFromDb("notification", "qualityFilter"))
    local priceSource = LA.PriceSources.ResolveForItem(itemID, LA.GetFromDb(
                                                           "pricesource",
                                                           "source"))
    LA.Debug.Log("Resolved price source: " .. tostring(priceSource))

    local ignoreSoulboundItems = LA.GetFromDb("general", "ignoreSoulboundItems")
    local addItem2List = true
    local disenchanted = false
    local showLootedItemValueGroup = LA.GetFromDb("display",
                                                  "showLootedItemValueGroup")
    local addGroupDropsToLootedItemList =
        LA.GetFromDb("display", "addGroupDropsToLootedItemList")
    local showGroupLootAlerts = LA.GetFromDb("display", "showGroupLootAlerts")
    LA.Debug.Log("showGroupLootAlerts: " .. tostring(showGroupLootAlerts))

    local showGroupLoot = source and
                              (showLootedItemValueGroup or
                                  addGroupDropsToLootedItemList)
    LA.Debug.Log("showGroupLoot = %s", tostring(showGroupLoot))

    -- Check item quality
    local quality = select(3, GetItemInfo(itemID)) or 0
    if quality < qualityFilter then
        LA.Debug.Log("  " .. tostring(itemID) .. ": item quality (" ..
                         tostring(quality) .. ") < filter (" ..
                         tostring(qualityFilter) .. ") -> ignore item")
        return
    end
    LA.Debug.Log("  " .. tostring(itemID) .. ": item quality (" ..
                     tostring(quality) .. ") >= filter (" ..
                     tostring(qualityFilter) .. ")")

    -- Blacklist check
    if LA.IsItemBlacklisted(itemID) then
        LA.Debug.Log("  " .. tostring(itemID) .. ": blacklisted -> ignore")
        return
    end

    -- Overwrite link for base items only
    if LA.GetFromDb("general", "ignoreRandomEnchants") then
        itemLink = select(2, GetItemInfo(itemID))
    end

    -- Special handling for poor quality items
    if quality == 0 then
        LA.Debug.Log("  " .. tostring(itemID) ..
                         ": poor quality -> price source 'VendorSell'")
    end

    -- Get single item value
    local singleItemValue = LA.PriceSources.GetItemValue(itemID, priceSource) or
                                0
    LA.Debug.Log("SIV price source: " .. tostring(singleItemValue))
    LA.Debug.Log("PriceSource: " .. tostring(priceSource))
    LA.Debug.Log("  " .. tostring(itemID) .. ": single item value: " ..
                     tostring(singleItemValue))

    -- Special handling for soulbound items and disenchant value
    if singleItemValue == 0 and quality > 0 then
        local blizVendorPrice = select(11, GetItemInfo(itemID)) or 0

        if ignoreSoulboundItems then
            addItem2List = false
            singleItemValue = tostring(blizVendorPrice) or 0
            LA.Debug
                .Log("ignoreSoulBoundItems is on. No output to loot window.")
        else
            addItem2List = true
            singleItemValue = tostring(blizVendorPrice) or 0
            LA.Debug.Log("ignoreSoulBoundItems is off. Showing VendorSell: " ..
                             tostring(blizVendorPrice))
        end

        if LA.GetFromDb("pricesource", "useDisenchantValue", "TSM_REQUIRED") then
            singleItemValue = LA.PriceSources.GetItemValue(itemID, "Destroy") or
                                  0
            disenchanted = true
            LA.Debug.Log("  " .. tostring(itemID) ..
                             ": single item value (de): " ..
                             tostring(singleItemValue))
        end
    end

    -- Calculate overall item value
    local itemValue = singleItemValue * quantity

    private.IncLootedItemCounter(quantity, source)
    private.AddItemValue2LootedItemValue(itemValue, source)
    if LA.Util.IsModern then private.IncWoWTokenPercentage(source) end

    -- Track loot for session history
    LA.SessionHistory.AddLootItem(itemID, itemLink, quantity, itemValue)

    if addItem2List == true then
        itemValue = singleItemValue
        LA.Debug.Log("itemValue: " .. tostring(itemValue))
        LA.Debug.Log("quality: " .. tostring(quality))
        LA.UI.AddItem2LootCollectedList(itemID, itemLink, quantity, itemValue,
                                        false, source, disenchanted)

        if LA.Session.IsRunning() then
            LogLoot(itemID, itemLink, itemValue)
        end
    else
        LA.Debug.Log("soulbound item ignored: " .. tostring(itemID))
    end

    -- Gold alert thresholds
    private.ProcessGoldAlerts(itemID, itemLink, singleItemValue, quantity,
                              quality, source, showGroupLoot)

    LA.UI.RefreshUIs()

    -- Module callbacks
    if not source then
        local modules = LA.GetModules()
        if modules then
            for name, data in pairs(modules) do
                if data and data.callback and data.callback.itemDrop then
                    data.callback.itemDrop(itemID, singleItemValue)
                end
            end
        end
    end

    -- Handle party loot propagation
    if IsInGroup() and not source then
        if LA.GetFromDb("display", "showGroupLootAlerts") ~= false then
            private.SendAddonMsg(itemLink, itemID, quantity)
        end
    end
end

--[[------------------------------------------------------------------------
    Gold Alert Threshold processing
--------------------------------------------------------------------------]]
function private.ProcessGoldAlerts(itemID, itemLink, singleItemValue, quantity,
                                   quality, source, showGroupLoot)
    local goldValue = floor(singleItemValue / 10000)
    local gatA = tonumber(LA.GetFromDb("notification", "goldAlertThresholdA"))
    local gatB =
        tonumber(LA.GetFromDb("notification", "goldAlertThresholdB")) or 0
    local gatC =
        tonumber(LA.GetFromDb("notification", "goldAlertThresholdC")) or 0
    local gatSoundToPlay = ""

    LA.Debug.Log("gatA: " .. gatA)
    LA.Debug.Log("gatB: " .. gatB)
    LA.Debug.Log("gatC: " .. gatC)

    -- Determine which GAT tier was hit
    if goldValue >= gatA and gatB == 0 and gatC == 0 then
        gatSoundToPlay = "A"
    elseif goldValue > gatA and goldValue < gatB and gatB ~= 0 then
        gatSoundToPlay = "A"
    elseif goldValue >= gatB and gatB ~= 0 then
        if goldValue > gatC and gatC ~= 0 then
            gatSoundToPlay = "C"
        else
            gatSoundToPlay = "B"
        end
    elseif goldValue >= gatC and gatC ~= 0 then
        gatSoundToPlay = "C"
    end

    if gatSoundToPlay == "" then return end

    -- Party loot suffix
    local partyLootSuffix = ""
    if source then partyLootSuffix = " (|cFF2DA6ED" .. source .. "|r)" end

    -- Increment noteworthy counter
    private.IncNoteworthyItemCounter(quantity, source)

    -- Print to configured output channels
    if not source or showGroupLoot then
        local formattedValue = LA.Util.MoneyToString(singleItemValue) or 0
        local qtyValue = singleItemValue * tonumber(quantity)
        local formatValue = LA.Util.MoneyToString(qtyValue) or 0

        LA:Pour(itemLink .. " x" .. quantity .. ": " .. formatValue ..
                    partyLootSuffix)

        if tonumber(quantity) > 1 then
            LA.UI.UpdateLastNoteworthyItemUI(itemLink, quantity,
                                             singleItemValue, formatValue)
        else
            LA.UI.UpdateLastNoteworthyItemUI(itemLink, quantity,
                                             singleItemValue, formattedValue)
        end

        -- Toast notification
        if LA.GetFromDb("notification", "enableToasts") then
            local name, _, _, _, _, _, _, _, _, texturePath =
                GetItemInfo(itemID)
            LibToast:Spawn("LootAppraiserReloaded", name, texturePath, quality,
                           quantity, formatValue, source)
        end
    end

    -- Update mapID if changed
    if LA.Session.GetCurrentSession("mapID") ~= GetBestMapForUnit("player") then
        LA.Debug.Log("  current vs. session mapID: %s vs. %s",
                     GetBestMapForUnit("player"),
                     LA.Session.GetCurrentSession("mapID"))
        LA.Session.SetCurrentSession("mapID", GetBestMapForUnit("player"))
    end

    -- Play alert sound
    private.PlayGATSound(gatSoundToPlay, source)
end

--[[------------------------------------------------------------------------
    Play the appropriate GAT alert sound
--------------------------------------------------------------------------]]
function private.PlayGATSound(gatTier, source)
    if not LA.GetFromDb("notification", "playSoundEnabled") then return end

    -- Only play sounds for own loot, or group loot if opted in
    local shouldPlay = false
    if IsInGroup() and LA.GetFromDb("display", "showGroupLootAlerts") == true then
        shouldPlay = true
    elseif source == nil and not IsInGroup("player") then
        shouldPlay = true
    elseif source == nil and IsInGroup("player") and
        LA.GetFromDb("display", "showGroupLootAlerts") == false then
        shouldPlay = true
    end

    if not shouldPlay then return end

    local soundKey = "soundName" .. gatTier
    local soundName = LA.db.profile.notification[soundKey] or "None"
    LA.Debug.Log("gatSound: " .. gatTier)
    PlaySoundFile(LSM:Fetch("sound", soundName), "master")
end

--[[------------------------------------------------------------------------
    Handle looted currency (gold/silver/copper drops)
--------------------------------------------------------------------------]]
function LootProcessing.HandleCurrencyLooted(lootedCopper)
    local totalLootedCurrency = (LA.Session.GetCurrentSession(
                                    "totalLootedCurrency") or 0) + lootedCopper
    LA.Session.SetCurrentSession("totalLootedCurrency", totalLootedCurrency)

    LA.Debug.Log("  handle currency: add " .. tostring(lootedCopper) ..
                     " copper -> new total: " .. tostring(totalLootedCurrency))

    LA.UI.RefreshUIs()
end

--[[------------------------------------------------------------------------
    Send addon message for group loot propagation
--------------------------------------------------------------------------]]
function private.SendAddonMsg(...)
    if LootAppraiserReloaded_GroupLoot then return end

    local json = ""
    for n = 1, select('#', ...) do
        if json ~= "" then json = json .. "\001" end
        json = json .. LibParse:JSONEncode(select(n, ...))
    end

    if json ~= "" then json = json .. "\001" end
    json = json .. LibParse:JSONEncode(UnitGUID("player"))

    if LA.GetFromDb("display", "showGroupLootAlerts") == true then
        SendAddonMessage(LA.CONST.PARTYLOOT_MSGPREFIX, json, "RAID")
    end
end

--[[------------------------------------------------------------------------
    Counter and value helper functions
--------------------------------------------------------------------------]]
function private.IncLootedItemCounter(quantity, source)
    if source then return end
    local lootedItemCounter =
        (LA.Session.GetCurrentSession("lootedItemCounter") or 0) + quantity
    LA.Session.SetCurrentSession("lootedItemCounter", lootedItemCounter)
    LA.Debug.Log("    looted items counter: add " .. tostring(quantity) ..
                     " -> new total: " .. tostring(lootedItemCounter))
end

function private.AddItemValue2LootedItemValue(itemValue, source)
    local totalItemValue = LA.Session.GetCurrentSession("liv") or 0

    if not source then
        totalItemValue = totalItemValue + itemValue
        LA.Debug.Log("    looted items value: add " .. tostring(itemValue) ..
                         " -> new total: " .. tostring(totalItemValue))
    end

    LA.Session.SetCurrentSession("liv", totalItemValue or 0)

    if LA.UI.ShowLiteWindow then
        LA.UI.UpdateLiteWindowUI(totalItemValue or 0)
    end

    -- Group value
    local totalItemValueGroup = LA.Session.GetCurrentSession("livGroup") or 0
    totalItemValueGroup = totalItemValueGroup + itemValue
    LA.Debug.Log("    group: looted items value: add " .. tostring(itemValue) ..
                     " -> new total: " .. tostring(totalItemValueGroup))
    LA.Session.SetCurrentSession("livGroup", totalItemValueGroup or 0)
end

function private.IncNoteworthyItemCounter(quantity, source)
    if source then return end
    local noteworthyItemCounter = (LA.Session.GetCurrentSession(
                                      "noteworthyItemCounter") or 0) + quantity
    LA.Session.SetCurrentSession("noteworthyItemCounter", noteworthyItemCounter)
    LA.Debug.Log("    noteworthy items counter: add " .. tostring(quantity) ..
                     " -> new total: " .. tostring(noteworthyItemCounter))
end

function private.IncWoWTokenPercentage(source)
    if source then return end

    local wowToken = LA.UI.GetTokenPrice()
    local totalItemValue = LA.Session.GetCurrentSession("liv") or 0

    if wowToken and wowToken > 0 then
        local percentage = totalItemValue / wowToken * 100
        LA.Session.SetCurrentSession("wowTokenPercentage", percentage)
        LA.Debug.Log(" WoW token price: " .. tostring(wowToken) ..
                         ", totalItemValue: " .. tostring(totalItemValue) ..
                         ", percentage: " .. percentage)
    else
        LA.Debug.Log(
            "WoW token price unavailable, skipping token percentage update.")
    end
end

--[[------------------------------------------------------------------------
    Blacklist check
--------------------------------------------------------------------------]]
function LA.IsItemBlacklisted(itemID)
    if not LA.GetFromDb("blacklist", "tsmGroupEnabled", "TSM_REQUIRED") then
        return LA.CONST.ITEM_FILTER_BLACKLIST[tostring(itemID)]
    end
    return LA.TSM.IsItemInGroup(itemID, LA.GetFromDb("blacklist", "tsmGroup"))
end
