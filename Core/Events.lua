local LA = select(2, ...)

local Events = {}
LA.Events = Events

local private = {}

-- Wow APIs
local GetUnitName, UnitGUID, IsInGroup = GetUnitName, UnitGUID, IsInGroup

-- Lua APIs
local smatch, time, unpack, tostring = string.match, time, unpack, tostring
local tinsert = table.insert
local LibParse = LibStub:GetLibrary("LibParse")

-- Loot patterns
local LOOT_ITEM_SELF, LOOT_ITEM_SELF_MULTIPLE, INSTANCE_RESET_SUCCESS =
    LOOT_ITEM_SELF, LOOT_ITEM_SELF_MULTIPLE, INSTANCE_RESET_SUCCESS

local PATTERN_LOOT_ITEM_SELF = LOOT_ITEM_SELF:gsub("%%s", "(.+)")
local PATTERN_LOOT_ITEM_SELF_MULTIPLE = LOOT_ITEM_SELF_MULTIPLE:gsub("%%s",
                                                                     "(.+)")
                                            :gsub("%%d", "(%%d+)")

-- Instance reset pattern
local resetmsg = INSTANCE_RESET_SUCCESS:gsub("%%s", ".+")

--[[------------------------------------------------------------------------
    CHAT_MSG_LOOT - Self loot events
--------------------------------------------------------------------------]]
function Events.OnChatMsgLoot(event, msg)
    if not LA.Session.IsRunning() then LA:ShowStartSessionDialog() end

    if LA.Session.IsPaused() then LA.Session.Restart() end

    if event == "CHAT_MSG_LOOT" then
        -- Retail 12.0+: piggyback on loot event to track NPC kills
        -- (CLEU is blocked, but CHAT_MSG_LOOT always fires when looting)
        if LA.Util.IsModern and LA.KillTracker then
            LA.KillTracker.TryTrackFromLoot()
        end

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
            LA.Debug.Log("#### type=%s; itemLink=%s; quantity=%s", loottype,
                         tostring(itemLink), tostring(quantity))
            LA.Debug.Log("----source: " .. tostring(source))

            if not itemLink or not quantity then
                LA.Debug.Log("#### ignore event! msg: " .. msg .. ", type=" ..
                                 tostring(loottype))
                LA.Debug.Log("   itemLink=" .. tostring(itemLink) ..
                                 "; quantity=" .. tostring(quantity) ..
                                 "; source=" .. tostring(source) .. ")")
                return
            end

            local itemID = LA.Util.ToItemID(itemLink)
            LA.LootProcessing.HandleItemLooted(itemLink, itemID, quantity,
                                               source)
        end
    end
end

--[[------------------------------------------------------------------------
    TRADE_SKILL_ITEM_CRAFTED_RESULT - Crafted item tracking
--------------------------------------------------------------------------]]
function Events.OnTradeSkillCrafted(event, data)
    if not LA.Session.IsRunning() then LA:ShowStartSessionDialog() end

    if LA.Session.IsPaused() then LA.Session.Restart() end
    if LA.GetFromDb("notification", "trackCrafts") == false then return end

    local loottype, itemLink, quantity, source
    itemLink = data.hyperlink
    quantity = data.quantity

    if data.quantity == 1 then
        loottype = "## self (single) ##"
    else
        loottype = "## self (multi) ##"
    end

    if loottype then
        LA.Debug.Log("#### type=%s; itemLink=%s; quantity=%s", loottype,
                     tostring(itemLink), tostring(quantity))
        LA.Debug.Log("----source: " .. tostring(source))

        if not itemLink or not quantity then
            LA.Debug.Log("#### ignore event! data: " .. data .. ", type=" ..
                             tostring(loottype))
            LA.Debug.Log(
                "   itemLink=" .. tostring(itemLink) .. "; quantity=" ..
                    tostring(quantity) .. "; source=" .. tostring(source) .. ")")
            return
        end

        local itemID = LA.Util.ToItemID(itemLink)
        LA.LootProcessing.HandleItemLooted(itemLink, itemID, quantity, source)
    end
end

--[[------------------------------------------------------------------------
    CHAT_MSG_ADDON - Group loot addon messages
--------------------------------------------------------------------------]]
function Events.OnChatMsgAddon(event, prefix, msg, type, sender)
    if not LA.Session.IsRunning() then return end

    if prefix ~= LA.CONST.PARTYLOOT_MSGPREFIX then return end

    LA.Debug.Log("sender vs. player: %s vs. %s", sender,
                 GetUnitName("player", true))
    if sender == GetUnitName("player", true) then
        LA.Debug.Log("#### OnChatMsgAddon: ignore message")
        return
    end

    local tokens = LA.Util.split(msg, "\001")
    local v = {}
    for i = 1, #tokens do tinsert(v, LibParse:JSONDecode(tokens[i])) end

    local success, itemLink, itemID, quantity, senderUnitGUID = true, unpack(v)

    LA.Debug.Log("senderGUID vs. playerGUID: %s vs. %s", senderUnitGUID,
                 UnitGUID("player"))
    if senderUnitGUID == UnitGUID("player") then
        LA.Debug.Log("OnChatMsgAddon: ignore message")
        return
    end

    LA.Debug.Log("OnChatMsgAddon: prefix=%s, msg=%s, type=%s, sender=%s",
                 prefix, msg, type, senderUnitGUID)
    LA.LootProcessing.HandleItemLooted(itemLink, itemID, quantity, sender)
end

--[[------------------------------------------------------------------------
    CHAT_MSG_MONEY - Currency loot events
--------------------------------------------------------------------------]]
function Events.OnChatMsgMoney(event, msg)
    if not LA.Session.IsRunning() then return end

    LA.Debug.Log("  OnChatMsgMoney: msg=%s", tostring(msg))

    local lootedCopper = LA.Util.StringToMoney(msg)
    if msg == "Free Trial money cap reached." then
        LA.Debug.Log("Ignoring looted copper.")
    else
        LA.Debug.Log("    lootedCopper=%s", tostring(lootedCopper))
        LA.LootProcessing.HandleCurrencyLooted(lootedCopper)
    end
end

--[[------------------------------------------------------------------------
    CHAT_MSG_SYSTEM - Instance reset detection
--------------------------------------------------------------------------]]
function Events.OnResetInfoEvent(event, msg)
    if event == "CHAT_MSG_SYSTEM" then
        if msg:match("^" .. resetmsg .. "$") then
            LA.Debug.Log("  match: " ..
                             tostring(msg:match("^" .. resetmsg .. "$")))

            local instanceName = smatch(msg, INSTANCE_RESET_SUCCESS:gsub("%%s",
                                                                         "(.+)"))

            local data = {
                ["endTime"] = time() + 60 * 60,
                ["instanceName"] = instanceName
            }

            LA.UI.AddToResetInfo(data)
        end
    end
end
