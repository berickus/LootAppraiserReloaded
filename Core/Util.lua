 local LA = select(2, ...)

local Util = {}
LA.Util = Util

-- lua api
local abs, floor, string, pairs, table, tonumber = 
      abs, floor, string, pairs, table, tonumber

-- based on Money.ToString from TSM 3/4
local goldText, silverText, copperText = "|cffffd70ag|r", "|cffc7c7cfs|r", "|cffeda55fc|r"
function Util.MoneyToString(money, ...)
    money = tonumber(money)
    if not money then return end

    local isNegative = money < 0
    money = abs(money)

    local gold = floor(money / COPPER_PER_GOLD)
    local silver = floor((money % COPPER_PER_GOLD) / COPPER_PER_SILVER)
    local copper = floor(money % COPPER_PER_SILVER)

    if money == 0 then
        return "0"..copperText
    end

    local text
    if gold > 0 then
        text = gold..goldText.." "..silver..silverText.." "..copper..copperText
    elseif silver > 0 then
        text = silver..silverText.." "..copper..copperText
    else
        text = copper..copperText
    end

    if isNegative then
        return "-"..text
    else
        return text
    end
end

-- based on Item:ToItemID from TSM 3/4
function Util.ToItemID(itemString)
    if not itemString then
        return
    end

    --local printable = gsub(itemString, "\124", "\124\124");
    --ChatFrame1:AddMessage("Here's what it really looks like: \"" .. printable .. "\"");

    --local itemId = LA.TSM.GetItemID(itemString)

    local _, _, Color, Ltype, Id, Enchant, Gem1, Gem2, Gem3, Gem4, Suffix, Unique, LinkLvl, reforging, Name = string.find(itemString, "|?c?f?f?(%x*)|?H?([^:]*):?(%d+):?(%d*):?(%d*):?(%d*):?(%d*):?(%d*):?(%-?%d*):?(%-?%d*):?(%d*):?(%d*)|?h?%[?([^%[%]]*)%]?|?h?|?r?")

    --ChatFrame1:AddMessage("Id: " .. Id .. " vs. " .. itemId);
    return tonumber(Id)
end

function Util.split(str, sep)
    local sep, fields = sep or ":", {}
    local pattern = string.format("([^%s]+)", sep)
    str:gsub(pattern,
        function(c)
            fields[#fields+1] = c
        end
    )
    return fields
end

function Util.tablelength(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end

function Util.startsWith(String,Start)
    return string.sub(String,1,string.len(Start))==Start
end

-- parse currency text from loot window and covert the result to copper
-- e.g. 2 silver, 2 copper -> 202 copper
function Util.StringToMoney(lootedCurrencyAsText)
    local digits = {}
    local digitsCounter = 0;
    lootedCurrencyAsText:gsub("%d+",
        function(i)
            table.insert(digits, i)
            digitsCounter = digitsCounter + 1
        end
    )
    
    local copper = 0
    --gold, silver, copper (gold, silver copper)
    --*10000 = gold to copper
    --*100 = silver to copper
    --Detect if ZandalariTroll to help count digits for the additional currency buff
	local raceName, raceFile, raceID = UnitRace("player")
	if raceID == 31 then
		--print("ZandalariTroll detected")
        --ZT = Zandalari Troll
        if digitsCounter == 6 then
            copper = (digits[1]*10000)+(digits[2]*100)+(digits[3])+(digits[4]*10000)+(digits[5]*100)+(digits[6])    --Zandalari Troll + gold + silver + copper
        elseif digitsCounter == 5 then
            copper = (digits[1]*10000)+(digits[2]*100)+(digits[3])+(digits[4]*100)+(digits[5])                      --Zandalari troll + silver + copper
        elseif digitsCounter == 4 then
            -- silver + copper + ZT silver + ZT copper
            copper = (digits[1]*100)+(digits[2])+(digits[3]*100)+(digits[4])                                      --Zandalari Troll + copper
        elseif digitsCounter == 3 then
            -- silver + copper + ZT copper
            copper = (digits[1]*100)+(digits[2]+(digits[3]))        
        elseif digitsCounter == 2 then
            -- copper + ZT copper
            copper = (digits[1])+(digits[2])
        else
            -- copper
            copper = digits[1]
        end


    else
        if digitsCounter == 3 then
            -- gold + silver + copper
            copper = (digits[1]*10000)+(digits[2]*100)+(digits[3])
        elseif digitsCounter == 2 then
            -- silver + copper
            copper = (digits[1]*100)+(digits[2])
        else
            -- copper
            copper = digits[1]
        end
        
    end

    return copper
end