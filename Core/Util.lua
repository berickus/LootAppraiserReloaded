local LA = select(2, ...)

local Util = {}
LA.Util = Util

local tocVersion = select(4, GetBuildInfo()) -- Returns TOC version (e.g., 110205)
Util.TOCVersion = tocVersion

-- Classic Versions (check first - more specific)
Util.IsClassicEra = (tocVersion < 20000) -- Classic Era (1.x)
Util.IsTBCClassic = (tocVersion >= 20000 and tocVersion < 30000) -- TBC Classic (2.x) - legacy
Util.IsWrathClassic = (tocVersion >= 30000 and tocVersion < 40000) -- Wrath Classic (3.x) - legacy
Util.IsCataClassic = (tocVersion >= 40000 and tocVersion < 50000) -- Cata Classic (4.x) - legacy
Util.IsMoPClassic = (tocVersion >= 50000 and tocVersion < 60000) -- MoP Classic (5.x)
Util.IsClassic = Util.IsClassicEra or Util.IsMoPClassic or Util.IsCataClassic or
                     Util.IsWrathClassic or Util.IsTBCClassic

-- Retail Expansions
Util.IsRetail = (tocVersion >= 100000) -- Dragonflight+ (10.x+)
Util.IsTWW = (tocVersion >= 110200 and tocVersion < 120000) -- The War Within (11.x)
Util.IsMidnight = (tocVersion >= 120000)

Util.IsModern = Util.IsRetail or Util.IsTWW or Util.IsMidnight

-- lua api
local abs, floor, string, pairs, table, tonumber = abs, floor, string, pairs,
                                                   table, tonumber

-- based on Money.ToString from TSM 3/4
local goldText, silverText, copperText = "|cffffd70ag|r", "|cffc7c7cfs|r",
                                         "|cffeda55fc|r"
function Util.MoneyToString(money, ...)
    money = tonumber(money)
    if not money then return end

    local isNegative = money < 0
    money = abs(money)

    local gold = floor(money / COPPER_PER_GOLD)
    local silver = floor((money % COPPER_PER_GOLD) / COPPER_PER_SILVER)
    local copper = floor(money % COPPER_PER_SILVER)

    if money == 0 then return "0" .. copperText end

    local text
    if gold > 0 then
        text =
            gold .. goldText .. " " .. silver .. silverText .. " " .. copper ..
                copperText
    elseif silver > 0 then
        text = silver .. silverText .. " " .. copper .. copperText
    else
        text = copper .. copperText
    end

    if isNegative then
        return "-" .. text
    else
        return text
    end
end

-- based on Item:ToItemID from TSM 3/4
function Util.ToItemID(itemString)
    if not itemString then return end

    -- local printable = gsub(itemString, "\124", "\124\124");
    -- ChatFrame1:AddMessage("Here's what it really looks like: \"" .. printable .. "\"");

    -- local itemId = LA.TSM.GetItemID(itemString)

    -- local _, _, Color, Ltype, Id, Enchant, Gem1, Gem2, Gem3, Gem4, Suffix,
    --      Unique, LinkLvl, reforging, Name =
    --    string.find(itemString,
    --                "|?c?f?f?(%x*)|?H?([^:]*):?(%d+):?(%d*):?(%d*):?(%d*):?(%d*):?(%d*):?(%-?%d*):?(%-?%d*):?(%d*):?(%d*)|?h?%[?([^%[%]]*)%]?|?h?|?r?")

    -- ChatFrame1:AddMessage("Id: " .. Id .. " vs. " .. itemId);
    return tonumber(string.match(itemString, "|Hitem:(%d+):"))
end

--[[
    Parse a WoW item link into its components.
    Item link format: |Hitem:itemID:enchant:gem1:gem2:gem3:gem4:suffixID:uniqueID:linkLevel:specID:modifiersMask:instanceDifficultyID:numBonusIDs[:bonusID1:...]:numModifiers[:modType1:modVal1:...]|h[Name]|h

    Returns a table with: itemID, itemName, itemLevel, bonusIds (array), modifiers (array of type-9 values)
]]
function Util.ParseItemLink(itemLink)
    if not itemLink then return nil end

    -- Extract the item string between |H and |h
    local itemString = itemLink:match("|Hitem:([^|]+)|")
    if not itemString then return nil end

    -- Split the item string by ":"
    local parts = {}
    for v in itemString:gmatch("([^:]*):?") do parts[#parts + 1] = v end

    local itemID = tonumber(parts[1])
    if not itemID then return nil end

    -- Get item name from the link
    local itemName = itemLink:match("|h%[(.-)%]|h")

    -- Get item level from GetItemInfo (index 4 = item level in GetDetailedItemLevelInfo or select(4, GetItemInfo()))
    local itemLevel = 0
    if C_Item.GetDetailedItemLevelInfo then
        itemLevel = C_Item.GetDetailedItemLevelInfo(itemLink) or 0
    else
        itemLevel = select(4, C_Item.GetItemInfo(itemLink)) or 0
    end

    -- Parse bonus IDs
    -- Standard positions: 1=itemID, 2=enchant, 3-6=gems, 7=suffixID, 8=uniqueID,
    -- 9=linkLevel, 10=specID, 11=modifiersMask, 12=instanceDifficultyID,
    -- 13=numBonusIDs, then bonusIDs, then numModifiers, then modifier pairs
    local bonusIds = {}
    local modifiers = {}

    local numBonusIDs = tonumber(parts[13]) or 0
    local bonusStart = 14
    for i = bonusStart, bonusStart + numBonusIDs - 1 do
        local bid = tonumber(parts[i])
        if bid then bonusIds[#bonusIds + 1] = bid end
    end

    -- After bonus IDs comes numModifiers then pairs of (type, value)
    local modStart = bonusStart + numBonusIDs
    local numModifiers = tonumber(parts[modStart]) or 0
    for i = 1, numModifiers do
        local modType = tonumber(parts[modStart + (i - 1) * 2 + 1])
        local modValue = tonumber(parts[modStart + (i - 1) * 2 + 2])
        if modType == 9 and modValue then
            modifiers[#modifiers + 1] = modValue
        end
    end

    return {
        itemID = itemID,
        itemName = itemName or "",
        itemLevel = tonumber(itemLevel) or 0,
        bonusIds = bonusIds,
        modifiers = modifiers
    }
end

--[[
    Serialize a Lua table to a JSON string.
    Handles nested tables, arrays, strings, numbers, booleans, and nil.
]]
function Util.TableToJSON(val, indent, currentIndent)
    indent = indent or "  "
    currentIndent = currentIndent or ""
    local nextIndent = currentIndent .. indent

    if val == nil then
        return "null"
    elseif type(val) == "boolean" then
        return val and "true" or "false"
    elseif type(val) == "number" then
        -- Avoid scientific notation for large integers
        if val == floor(val) and val < 1e15 and val > -1e15 then
            return string.format("%d", val)
        end
        return tostring(val)
    elseif type(val) == "string" then
        -- Escape special characters
        local escaped = val:gsub('\\', '\\\\'):gsub('"', '\\"')
                            :gsub('\n', '\\n'):gsub('\r', '\\r')
                            :gsub('\t', '\\t')
        -- Strip WoW color codes for cleaner JSON
        escaped = escaped:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub(
                      "|H.-|h", ""):gsub("|h", "")
        return '"' .. escaped .. '"'
    elseif type(val) == "table" then
        -- Determine if array (sequential integer keys starting at 1)
        local isArray = true
        local maxN = 0
        for k, _ in pairs(val) do
            if type(k) == "number" and k == floor(k) and k > 0 then
                if k > maxN then maxN = k end
            else
                isArray = false
                break
            end
        end
        if maxN == 0 and next(val) ~= nil then isArray = false end
        -- Also verify there are no gaps
        if isArray then
            for i = 1, maxN do
                if val[i] == nil then
                    isArray = false
                    break
                end
            end
        end

        local parts = {}
        if isArray then
            for i = 1, maxN do
                parts[#parts + 1] = nextIndent ..
                                        Util.TableToJSON(val[i], indent,
                                                         nextIndent)
            end
            if #parts == 0 then return "[]" end
            return
                "[\n" .. table.concat(parts, ",\n") .. "\n" .. currentIndent ..
                    "]"
        else
            -- Sort keys for consistent output
            local keys = {}
            for k in pairs(val) do keys[#keys + 1] = k end
            table.sort(keys, function(a, b)
                return tostring(a) < tostring(b)
            end)
            for _, k in ipairs(keys) do
                local keyStr = '"' .. tostring(k) .. '"'
                parts[#parts + 1] = nextIndent .. keyStr .. ": " ..
                                        Util.TableToJSON(val[k], indent,
                                                         nextIndent)
            end
            if #parts == 0 then return "{}" end
            return
                "{\n" .. table.concat(parts, ",\n") .. "\n" .. currentIndent ..
                    "}"
        end
    else
        return '"' .. tostring(val) .. '"'
    end
end

function Util.split(str, sep)
    local sep, fields = sep or ":", {}
    local pattern = string.format("([^%s]+)", sep)
    str:gsub(pattern, function(c) fields[#fields + 1] = c end)
    return fields
end

function Util.tablelength(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end

function Util.startsWith(String, Start)
    return string.sub(String, 1, string.len(Start)) == Start
end

-- parse currency text from loot window and covert the result to copper
-- e.g. 2 silver, 2 copper -> 202 copper
function Util.StringToMoney(lootedCurrencyAsText)
    local digits = {}
    local digitsCounter = 0;
    lootedCurrencyAsText:gsub("%d+", function(i)
        table.insert(digits, i)
        digitsCounter = digitsCounter + 1
    end)

    local copper = 0
    -- gold, silver, copper (gold, silver copper)
    -- *10000 = gold to copper
    -- *100 = silver to copper
    -- Detect if ZandalariTroll to help count digits for the additional currency buff
    local raceName, raceFile, raceID = UnitRace("player")
    if raceID == 31 then
        -- print("ZandalariTroll detected")
        -- ZT = Zandalari Troll
        if digitsCounter == 6 then
            copper = (digits[1] * 10000) + (digits[2] * 100) + (digits[3]) +
                         (digits[4] * 10000) + (digits[5] * 100) + (digits[6]) -- Zandalari Troll + gold + silver + copper
        elseif digitsCounter == 5 then
            copper = (digits[1] * 10000) + (digits[2] * 100) + (digits[3]) +
                         (digits[4] * 100) + (digits[5]) -- Zandalari troll + silver + copper
        elseif digitsCounter == 4 then
            -- silver + copper + ZT silver + ZT copper
            copper = (digits[1] * 100) + (digits[2]) + (digits[3] * 100) +
                         (digits[4]) -- Zandalari Troll + copper
        elseif digitsCounter == 3 then
            -- silver + copper + ZT copper
            copper = (digits[1] * 100) + (digits[2] + (digits[3]))
        elseif digitsCounter == 2 then
            -- copper + ZT copper
            copper = (digits[1]) + (digits[2])
        else
            -- copper
            copper = digits[1]
        end

    else
        if digitsCounter == 3 then
            -- gold + silver + copper
            copper = (digits[1] * 10000) + (digits[2] * 100) + (digits[3])
        elseif digitsCounter == 2 then
            -- silver + copper
            copper = (digits[1] * 100) + (digits[2])
        else
            -- copper
            copper = digits[1]
        end

    end

    return copper
end
