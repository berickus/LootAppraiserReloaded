local LA = select(2, ...)

local SalvageCrate = LA:NewModule("SalvageCrate", "AceEvent-3.0")

-- WoW APIs
local GetContainerNumSlots, GetContainerItemID, GetContainerItemInfo =
GetContainerNumSlots, GetContainerItemID, GetContainerItemInfo

-- Lua APIs
local tostring, tonumber, select, time, string =
tostring, tonumber, select, time, string


--[[-------------------------------------------------------------------------------------
-- AceAddon-3.0 - module standard methods
---------------------------------------------------------------------------------------]]
function SalvageCrate:OnInitialize()
    LA.Debug.Log("SalvageCrate:OnInitialize()")

end

function SalvageCrate:OnEnable()
    LA.Debug.Log("SalvageCrate:OnEnable()")

    -- events for opening of salvage crates
    SalvageCrate:RegisterEvent("UNIT_SPELLCAST_START", SalvageCrate.onUnitSpellcast)
    --SalvageCrate:RegisterEvent("UNIT_SPELLCAST_STOP", SalvageCrate.onUnitSpellcast)
    SalvageCrate:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", SalvageCrate.onUnitSpellcast)
    SalvageCrate:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED", SalvageCrate.onUnitSpellcast)
    SalvageCrate:RegisterEvent("BAG_UPDATE", SalvageCrate.onBagUpdate)
end


--[[-------------------------------------------------------------------------------------
-- event handler for UNIT_SPELLCAST_...
-- ...START ("unitID", "spell", "rank", lineID, spellID)
-- ...STOP ("unitID", "spell", "rank", lineID, spellID)
-- ...SUCCEEDED ("unitID", "spell", "rank", lineID, spellID)
-- ...INTERRUPTED ("unitID", "spell", "rank", lineID, spellID)
---------------------------------------------------------------------------------------]]
local salvageSpellIDs = {["174798"] = true, ["168179"] = true, ["168178"] = true, ["168180"] = true}


local currentLineID -- spell lineID counter.
local openEndTime -- spell ends on this time
local scBagSnapshot = {} -- bag snapshot
local newItems = {} -- list of new items


function SalvageCrate.onUnitSpellcast(event, unitID, spell, rank, lineID, spellID)

    if not LA.Session.IsRunning() then return end

    -- only salvage spells
    if not spellID or not salvageSpellIDs[tostring(spellID)] then
        return
    end

    if event == "UNIT_SPELLCAST_START" then
        -- store lineID for the upcomming events
        currentLineID = lineID
        scBagSnapshot = {}
        openEndTime = nil

        LA.Debug.Log("    started: unitID=" .. unitID .. ", spell=" .. spell .. ", rank=" .. rank .. ", lineID=" .. tostring(lineID) .. ", spellID=" .. tostring(spellID))

        -- take a snapshot from the bags
        --local freeSlots = 0
        for bag = 0, NUM_BAG_SLOTS, 1 do
            --freeSlots = freeSlots + select(1, GetContainerNumFreeSlots(bag))
            for slot = 1, GetContainerNumSlots(bag), 1 do
                local itemID = GetContainerItemID(bag, slot)
                local count = select(2, GetContainerItemInfo(bag, slot))

                -- prepare key and value
                local key = "" .. tostring(bag) .. ":" .. tostring(slot)
                local value = "" .. tostring(itemID) .. ":" .. tostring(count)

                scBagSnapshot[key] = value
            end
        end

        --LA.Debug.Log("    free slots=" .. freeSlots)

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then

        -- only events for the same lineID
        if currentLineID ~= lineID then
            return
        end

        LA.Debug.Log("    succeeded: unitID=" .. unitID .. ", spell=" .. spell .. ", rank=" .. rank .. ", lineID=" .. tostring(lineID) .. ", spellID=" .. tostring(spellID))

        openEndTime = time()
        newItems = {}

        LA.Debug.Log("    openEndTime=" .. tostring(openEndTime))

    elseif event == "UNIT_SPELLCAST_INTERRUPTED" then

        -- only events for the same lineID
        if currentLineID ~= lineID then
            return
        end

        LA.Debug.Log("    interrupted: unitID=" .. unitID .. ", spell=" .. spell .. ", rank=" .. rank .. ", lineID=" .. tostring(lineID) .. ", spellID=" .. tostring(spellID))

        -- reset data
        currentLineID = nil
        openEndTime = nil
        scBagSnapshot = {}

    end
end


--[[-------------------------------------------------------------------------------------
-- event handler for
-- ...BAG_UPDATE (bagID)
---------------------------------------------------------------------------------------]]
function SalvageCrate.onBagUpdate(event, bagID)

    if not LA.Session.IsRunning() then return end

    local currentTime = time()

    if not openEndTime or currentTime - openEndTime >= 3 then
        --LA.Debug.Log("  loot window expired...")
        return
    end

    LA.Debug.Log("SalvageCrate.onBagUpdate(): bagID=" .. tostring(bagID))

    -- compare snapshot with the current bag and store diff
    for slot = 1, GetContainerNumSlots(bagID), 1 do
        local newItemID = GetContainerItemID(bagID, slot)
        local newCount = select(2, GetContainerItemInfo(bagID, slot))

        -- prepare key and current value
        local key = "" .. tostring(bagID) .. ":" .. tostring(slot)
        local newValue = "" .. tostring(newItemID) .. ":" .. tostring(newCount)

        -- compare with snapshot
        local oldValue = scBagSnapshot[key]
        if oldValue ~= newValue then
            LA.Debug.Log("    different value for key=" .. key .. ", " .. tostring(oldValue) .. " vs. " .. tostring(newValue))

            -- first time see?
            if newItems[key] == nil then
                LA.Debug.Log("      processing")

                -- new item
                newItems[key] = newValue -- store so we only process once

                -- prepare input for processItem(...)
                local oldItemId
                local oldCount = 0

                if oldValue ~= nil then
                    local oldValueTokens = SalvageCrate:split(oldValue, ":")

                    oldItemId = oldValueTokens[1]
                    oldCount = tonumber(oldValueTokens[2]) or 0
                end


                if oldItemId ~= tostring(newItemID) then
                    LA.Debug.Log("        item on this pos changed: " .. tostring(oldItemId) .. " vs. " .. tostring(newItemID) .. " -> set count to 0")
                    -- old item is gone (e.g. open the last salvage crate on this position) so we also don't want the old count
                    oldCount = 0
                end

                if newCount == nil then
                    newCount = 0
                end

                -- only process this item if the newCount > oldCount
                if newCount > oldCount then
                    -- give item info to loot appraiser processing
                    local itemLink = select(7, GetContainerItemInfo(bagID, slot))
                    local quantity = newCount - oldCount

                    --processItem(itemLink, newItemID, ItemQty)
                    LA:handleItemLooted(itemLink, newItemID, quantity)
                end
            else
                LA.Debug.Log("      already processed -> ignore")
            end
        end
    end
end


function SalvageCrate:split(str, sep)
    local sep, fields = sep or ":", {}
    local pattern = string.format("([^%s]+)", sep)
    str:gsub(pattern,
        function(c)
            fields[#fields+1] = c
        end
    )
    return fields
end
