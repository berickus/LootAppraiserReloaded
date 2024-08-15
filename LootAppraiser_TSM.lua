-- LootAppraiser_TSM.lua --
--local LA = LibStub("AceAddon-3.0"):GetAddon("LootAppraiser")
local LA = select(2, ...)

local TSM = {}
LA.TSM = TSM

local private = {}


-- Lua APIs
local tostring, pairs, ipairs, table, select, sort =
	  tostring, pairs, ipairs, table, select, sort


-- TSM3
local TSMAPI = _G.TSMAPI

-- TSM4
local TSM_API = _G.TSM_API


function TSM.IsItemInGroup(itemID, group)
	-- TSM 3
	if TSMAPI and TSMAPI.Groups and TSMAPI.Groups.GetPath then
		local path = TSMAPI.Groups:GetPath("i:" .. tostring(itemID))
		return path == group
	end

	-- TSM 4
	if TSM_API and TSM_API.GetGroupPathByItem then
		local path = TSM_API.GetGroupPathByItem("i:" .. tostring(itemID))
		LA.Debug.Log("    path = \"" .. tostring(path) .. "\"")
		return path == group
	end

	return false
end


-- this method also encapsulate the special price source 'custom'
function TSM.GetItemValue(itemID, priceSource)
	-- special handling for priceSource = 'Custom'
	if priceSource == "Custom" then
		LA.Debug.Log("    price source (custom): " ..  LA.db.profile.pricesource.customPriceSource)

		-- TSM 3
		if TSMAPI and TSMAPI.GetCustomPriceValue then
			return TSMAPI:GetCustomPriceValue(LA.db.profile.pricesource.customPriceSource, itemID)
		end

		-- TSM 4
        if TSM_API and TSM_API.GetCustomPriceValue then
			return TSM_API.GetCustomPriceValue(LA.db.profile.pricesource.customPriceSource, "i:" .. tostring(itemID))
        end

		return 0		
	end

	-- TSM 3
	if TSMAPI and TSMAPI.GetItemValue then
		return TSMAPI:GetItemValue(itemID, priceSource)
	end

	-- TSM 4
	if TSM_API and TSM_API.GetCustomPriceValue then
		local itemLink

		local newItemID = LA.PetData.ItemID2Species(itemID) -- battle pet handling
		if newItemID == itemID then
			itemLink = "i:" .. tostring(itemID)
		else
			itemLink = newItemID
		end

		return TSM_API.GetCustomPriceValue(priceSource, itemLink) -- "i:" .. tostring(itemID)
	end

	return 0
end


function TSM.ParseCustomPrice(value)
	LA.Debug.Log("ParseCustomPrice(value=" .. tostring(value) .. ")")

	-- TSM 3
	if TSMAPI and TSMAPI.ValidateCustomPrice then
		return TSMAPI:ValidateCustomPrice(value)
	end

	-- TSM 4
    if TSM_API and TSM_API.IsCustomPriceValid then
        return TSM_API.IsCustomPriceValid(value)
    end

	return false
end


function TSM.IsTSMLoaded()
	if TSMAPI or TSM_API then
		return true
	end
	return false
end


-- returns a table with the filtered available price sources
function TSM.GetAvailablePriceSources()
	LA.Debug.Log("TSM.GetAvailablePriceSources")

	if not TSM.IsTSMLoaded() then
		LA.Debug.Log("TSM.GetAvailablePriceSources: TSM not loaded")
		return
	end

	local priceSources = {}
	local keys = {}

	-- filter
	local tsmPriceSources = private.GetPriceSources()

	for k, v in pairs(tsmPriceSources) do
		if LA.CONST.PRICE_SOURCE[k] then
			table.insert(keys, k)
		elseif LA.CONST.PRICE_SOURCE[v] then
			table.insert(keys, v)
		end
	end

	-- add custom
	table.insert(keys, "Custom")
	sort(keys)

	for _,v in ipairs(keys) do
		priceSources[v] = LA.CONST.PRICE_SOURCE[v]
	end

	return priceSources
end


function private.GetPriceSources()
	-- TSM 3
	if TSMAPI and TSMAPI.GetPriceSources then
		return select(1, TSMAPI:GetPriceSources())
	end

	-- TSM 4
	if TSM_API and TSM_API.GetPriceSourceKeys then
		local tempPriceSources = {}
		TSM_API.GetPriceSourceKeys(tempPriceSources)

		return tempPriceSources
	end

	return {}
end


function TSM.GetGroupPaths(values)
	TSM_API.GetGroupPaths(values)
end

function TSM.IsGroupValid(value)
	local itemString = TSM_API.ToItemString(value)
	local itemLink = itemString and TSMAPI.GetItemLink(itemString)
	if not itemLink then
		-- Log whatever error you want
	end
end



function TSM.GetGroupPathByItem(itemString)
    -- TSM 3
    if TSMAPI and TSMAPI.Groups and TSMAPI.Groups.GetPath then
        return TSMAPI.Groups:GetPath(itemString)
    end

    -- TSM 4
    if TSM_API and TSM_API.GetGroupPathByItem then
        return TSM_API.GetGroupPathByItem(itemString)
    end
end

function TSM.ToItemString(value)
    -- TSM 3
    if TSMAPI and TSMAPI.Item and TSMAPI.Item.ToItemString then
        return TSMAPI.Item:ToItemString(value)
    end

    -- TSM 4
    if TSM_API and TSM_API.ToItemString then
        return TSM_API.ToItemString(value)
    end
end

function TSM.FormatGroupPath(path)
    -- TSM 3
    if TSMAPI and TSMAPI.Groups and TSMAPI.Groups.FormatPath then
        return TSMAPI.Groups:FormatPath(path)
    end

    -- TSM 4
    if TSM_API and TSM_API.FormatGroupPath then
        return TSM_API.FormatGroupPath(path)
    end
end
