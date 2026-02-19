local LA = select(2, ...)

local Merchant = {}
LA.Merchant = Merchant

local private = {}

-- Wow APIs
local GetItemInfo, GetItemCount, C_Container, GetCoinTextureString =
    GetItemInfo, GetItemCount, C_Container, GetCoinTextureString

--[[------------------------------------------------------------------------
    Event: Merchant window opened
--------------------------------------------------------------------------]]
function Merchant.OnShow(event, msg)
    -- Auto sell gray items
    if LA.GetFromDb("general", "sellGrayItemsToVendor") == true then
        LA.Session.Start(showMainUI)
        LA.Debug.Log("Merchant Opened")
        LA.Debug.Log("Auto Sell Grays: |cff00fe00Enabled|r")
        private.SellGrayItems()
    end

    -- Auto repair gear
    if LA.GetFromDb("general", "autoRepairGear") == true then
        LA.Debug.Log("Auto Repair: |cff00fe00Enabled|r")
        private.AutoRepairGear()
    end
end

--[[------------------------------------------------------------------------
    Event: Merchant window closed
--------------------------------------------------------------------------]]
function Merchant.OnClose() LA.Debug.Log("Merchant Closed") end

--[[------------------------------------------------------------------------
    Sell all gray (poor quality) items in bags
--------------------------------------------------------------------------]]
function private.SellGrayItems()
    local totalItemValueOfGrays = 0
    local rarityCounter = 0

    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local itemLink = C_Container.GetContainerItemLink(bag, slot)

            if itemLink ~= nil then
                local _, _, itemID = strfind(itemLink, "item:(%d+):")
                if itemID == nil then
                    LA.Debug.Log("No itemID found for " .. itemLink ..
                                     " in bag slot " .. bag)
                else
                    local name, _, rarity = GetItemInfo(itemID)
                    local itemInfo = GetItemInfo(itemID)
                    local currentItemValue =
                        LA.PriceSources.GetItemValue(itemID, "VendorSell") or 0

                    local iStackCount = GetItemCount(itemInfo)
                    if iStackCount > 1 then
                        currentItemValue = currentItemValue * iStackCount
                    end

                    if rarity == 0 and currentItemValue ~= 0 then
                        rarityCounter = rarityCounter + 1
                        LA.Debug.Log(
                            "selling gray item: " .. itemLink .. " x" ..
                                iStackCount .. ": " ..
                                GetCoinTextureString(currentItemValue))
                        totalItemValueOfGrays =
                            totalItemValueOfGrays + currentItemValue

                        if LA.db.profile.general.sellGrayItemsToVendorVerbose ~=
                            true then
                            LA:Print("Selling " .. itemLink .. " x" ..
                                         iStackCount .. ": " ..
                                         GetCoinTextureString(currentItemValue))
                        end

                        C_Container.UseContainerItem(bag, slot)
                    end
                end
            end
        end
    end

    -- Update vendor sales on UI
    if LA.GetFromDb("display", "showValueSoldToVendor") == true then
        local formattedTotalVendorSoldCurrency =
            LA.Session.GetCurrentSession("vendorSoldCurrencyUI") or 0
        local totalSoldValue = formattedTotalVendorSoldCurrency +
                                   totalItemValueOfGrays or 0
        LA.Debug.Log("totalSoldValue: " .. totalSoldValue)
        LA.Session.SetCurrentSession("vendorSoldCurrencyUI", totalSoldValue)
        LA.Debug.Log("Set Session: " ..
                         LA.Session.GetCurrentSession("vendorSoldCurrencyUI"))

        private.HandleVendorSales(totalSoldValue)
    end

    if rarityCounter > 0 then
        LA:Print("Total Gray Sales: " ..
                     GetCoinTextureString(totalItemValueOfGrays))
    end
end

--[[------------------------------------------------------------------------
    Handle vendor sales currency tracking
--------------------------------------------------------------------------]]
function private.HandleVendorSales(totalSoldValue)
    LA.Debug.Log("handle vendor sales: " .. totalSoldValue)
    local totalVendorSalesCurrency = LA.Session.GetCurrentSession(
                                         "vendorSoldCurrencyUI") or 0
    LA.Debug.Log("total value: " .. totalVendorSalesCurrency)
    LA.Session.SetCurrentSession("vendorSoldCurrencyUI",
                                 totalVendorSalesCurrency)
end

--[[------------------------------------------------------------------------
    Auto-repair all gear at vendor
--------------------------------------------------------------------------]]
function private.AutoRepairGear()
    if CanMerchantRepair() then
        LA.Debug.Log("Merchant can repair")
        local RepairCost = GetRepairAllCost()
        if RepairCost > 0 then
            if GetMoney() >= RepairCost then
                RepairAllItems()
                LA.Debug
                    .Log("Repair cost: " .. GetCoinTextureString(RepairCost))
                LA:Print("Repair cost: " .. GetCoinTextureString(RepairCost))
            end
        end
    end
end
