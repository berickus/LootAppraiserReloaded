local LA = LibStub("AceAddon-3.0"):NewAddon(select(2, ...), "LootAppraiser", "AceConsole-3.0", "AceEvent-3.0",  "LibSink-2.0") -- "AceHook-3.0",

-- wow api
local GetAddOnMetadata, UIParent = C_AddOns.GetAddOnMetadata, UIParent

local CONST = {}
LA.CONST = CONST

CONST.METADATA = {
    NAME = GetAddOnMetadata(..., "Title"),
    VERSION = GetAddOnMetadata(..., "Version")
}

CONST.LAGUILDED = "https://www.guilded.gg/r/Ad8jyP61OE?i=54kKyPE4"

CONST.QUALITY_FILTER = { -- little hack to sort them in the menu
    ["0"] = "|cff9d9d9dPoor|r",
    ["1"] = "|cffffffffCommon|r",
    ["2"] = "|cff1eff00Uncommon|r",
    ["3"] = "|cff0070ddRare|r",
    ["4"] = "|cffa335eeEpic|r"
}

-- TSM predefined price sources + 'Custom'
CONST.PRICE_SOURCE = {
    ["VendorValue"] = "BLIZ: Vendor price",              --Native Blizzard Pricing for Vendor
    ["Custom"] = "Custom Price Source",                  -- TSM price sources
    ["DBHistorical"] = "TSM: Historical Price",
    ["DBMarket"] = "TSM: Market Value",
    ["DBRecent"] = "TSM: Recent Value",
    ["DBMinBuyout"] = "TSM: Min Buyout",
    ["DBRegionHistorical"] = "TSM: Region Historical Price",
    ["DBRegionMarketAvg"] = "TSM: Region Market Value Avg",
    ["DBRegionSaleAvg"] = "TSM: Region Sale Avg",
    ["DBRegionSaleAvg"] = "TSM: Region Global Sale Average",
    ["VendorSell"] = "TSM: VendorSell",
    ["region"] = "OE: Median All Realms in Region",     --OEMarketInfo (OE) (add:  ["market"] = "OE: Median AH 4-Day")
    ["Auctionator"] = "AN: Auctionator",                    -- Auctionator price source
}

CONST.PARTYLOOT_MSGPREFIX = "LA_PARTYLOOT"

-- la defaults
local parentHeight = UIParent:GetHeight()
CONST.DB_DEFAULTS = {
    profile = {
        enableDebugOutput = false,
        -- minimap icon position and visibility
        minimapIcon = { hide = false, minimapPos = 220, radius = 80, },
        mainUI = { ["height"] = 400, ["top"] = (parentHeight-50), ["left"] = 50, ["width"] = 400, },
        timerUI = { ["height"] = 32, ["top"] = (parentHeight+55), ["left"] = 50, ["width"] = 400, },
        challengeUI = { ["height"] = 400, ["top"] = (parentHeight-50), ["left"] = 50, ["width"] = 400, },
        liteUI = { ["height"] = 32, ["top"] = (parentHeight+20), ["left"] = 50, ["width"] = 400, },
        lastNotewothyItemUI = { ["height"] = 32, ["top"] = (parentHeight-15), ["left"] = 50, ["width"] = 400, },
		lastNotewothyItemUI2 = { ["height"] = 32, ["top"] = (parentHeight-15), ["left"] = 50, ["width"] = 400, },
        startSessionPromptUI = { },
        general = { ["ignoreRandomEnchants"] = true, ["surpressSessionStartDialog"] = true, ["ignoreSoulboundItems"] = false,  ["sellGrayItemsToVendor"] = false, ["autoRepairGear"] = false },
        pricesource = { ["source"] = "DBRegionMarketAvg", ["useDisenchantValue"] = false },
        notification = { ["sink"] = { ["sink20Sticky"] = false, ["sink20OutputSink"] = "RaidWarning", }, ["enableToasts"] = false, ["qualityFilter"] = "1", ["goldAlertThresholdA"] = "100", ["goldAlertThresholdB"] = "0", ["goldAlertThresholdC"] = "0", ["playSoundEnabled"] = true, ["soundNameA"] = "Auction Window Open", ["soundNameB"] = "None",["soundNameC"] = "None",},
        itemclasses = { },
        sellTrash = { ["tsmGroupEnabled"] = false, ["tsmGroup"] = "LootAppraiser`Trash", },
        blacklist = { ["tsmGroupEnabled"] = false, ["tsmGroup"] = "LootAppraiser`Blacklist", ["addBlacklistedItems2DestroyTrash"] = false, },
        display = {
            lootedItemListRowCount = 5,
            showZoneInfo = true,
            showSessionDuration = true,
            showLootedItemValue = true,
            showLootedItemValuePerHour = true,
            showCurrencyLooted = true,
            showItemsLooted = true,
            showNoteworthyItems = true,
			showValueSoldToVendor = false,
            enableLastNoteworthyItemUI = false,
            enableLootAppraiserLite = false,
            enableLootAppraiserTimerUI = false,
            enableStatisticTooltip = true,
            enableMinimapIcon = true,
            showLootedItemValueGroup = false,
            showLootedItemValueGroupPerHour = false,
            addGroupDropsToLootedItemList = false,
            showGroupLootAlerts = true,                              --new value for opting-out of seeing group/party loot alerts
        },
        sessionData = { groupBy = "datetime", },
    },
    global = { sessions = { }, drops = { }, },
}
CONST.DB_LOOT = {
	global = {
		session = { },
		location = { },
		loot = { },
	},
}

--[[  depricating this since item #s are no longer valid
CONST.ITEM_FILTER_VENDOR = {
    --DEFAULT ITEM IDs BELOW TO VENDORSELL PRICING
    ["1205"] = true, ["3770"] = true, ["104314"] = true, ["11444"] = true, ["104314"] = true, ["11444"] = true, ["117437"] = true, ["117439"] = true,
    ["117442"] = true, ["117453"] = true, ["117568"] = true, ["1179"] = true, ["117"] = true, ["159"] = true, ["1645"] = true, ["1707"] = true, ["1708"] = true,
    ["17344"] = true, ["17404"] = true, ["17406"] = true, ["17407"] = true, ["19221"] = true, ["19222"] = true, ["19223"] = true, ["19224"] = true, ["19225"] = true,
    ["19299"] = true, ["19300"] = true, ["19304"] = true, ["19305"] = true, ["19306"] = true, ["2070"] = true, ["20857"] = true, ["21151"] = true, ["21215"] = true,
    ["2287"] = true, ["2593"] = true, ["2594"] = true, ["2595"] = true, ["2596"] = true, ["2723"] = true, ["27854"] = true, ["27855"] = true, ["27856"] = true,
    ["27857"] = true, ["27858"] = true, ["27859"] = true, ["27860"] = true, ["28284"] = true, ["28399"] = true, ["29453"] = true, ["29454"] = true, ["33443"] = true,
    ["33444"] = true, ["33445"] = true, ["33449"] = true, ["33451"] = true, ["33452"] = true, ["33454"] = true, ["35947"] = true, ["35948"] = true, ["35951"] = true,
    ["3703"] = true, ["37252"] = true, ["3771"] = true, ["3927"] = true, ["40042"] = true, ["414"] = true, ["41731"] = true, ["422"] = true, ["44570"] = true,
    ["44940"] = true, ["44941"] = true, ["4536"] = true, ["4537"] = true, ["4538"] = true, ["4539"] = true, ["4540"] = true, ["4541"] = true, ["4542"] = true,
    ["4544"] = true, ["4592"] = true, ["4593"] = true, ["4594"] = true, ["4595"] = true, ["4599"] = true, ["4600"] = true, ["4601"] = true, ["4602"] = true,
    ["4604"] = true, ["4605"] = true, ["4606"] = true, ["4607"] = true, ["4608"] = true, ["58256"] = true, ["58257"] = true, ["58258"] = true, ["58259"] = true,
    ["58260"] = true, ["58261"] = true, ["58262"] = true, ["58263"] = true, ["58264"] = true, ["58265"] = true, ["58266"] = true, ["58268"] = true,
    ["58269"] = true, ["59029"] = true, ["59230"] = true, ["61982"] = true, ["61985"] = true, ["61986"] = true, ["73260"] = true, ["74822"] = true, ["787"] = true,
    ["81400"] = true, ["81401"] = true, ["81402"] = true, ["81403"] = true, ["81404"] = true, ["81405"] = true, ["81406"] = true, ["81407"] = true,
    ["81408"] = true, ["81409"] = true, ["81410"] = true, ["81411"] = true, ["81412"] = true, ["81413"] = true, ["81414"] = true, ["81415"] = true,
    ["8766"] = true, ["8932"] = true, ["8948"] = true, ["8950"] = true, ["8952"] = true, ["8953"] = true, ["9260"] = true, ["20404"] = true
}
--]]
--CONST.ITEM_FILTER_NOVALUEITEMS = {
    --DEFAULT ITEM IDs BELOW TO NO VALUE ITEMS - MEANING THESE ITEMS WILL NOT SHOW LOOTED AND HAVE NO VALUE
	--Blasted Lands loot crates
		--Emerald Encrusted Chest 			10752
		--Kum'isha's Junk					12122
		--Imperfect Draenethyst Fragment	10593	
		--Flawless Draenethyst Sphere		8244
	--["10752"] = true, ["12122"] = true, ["10593"] = true, ["8244"] = true
	--}

CONST.ITEM_FILTER_BLACKLIST = {
    --These items are from AQ20.  All of the Idols and Scarabs are Blacklisted.
    ["20858"] = true, ["20859"] = true, ["20860"] = true, ["20861"] = true, ["20862"] = true, ["20863"] = true, ["20864"] = true, ["20865"] = true,
    ["20874"] = true, ["20866"] = true, ["20868"] = true, ["20869"] = true, ["20870"] = true, ["20871"] = true, ["20872"] = true, ["20873"] = true,
    ["20867"] = true, ["20875"] = true, ["20876"] = true, ["20877"] = true,	["20878"] = true, ["20879"] = true, ["20881"] = true, ["20882"] = true,
    ["19183"] = true, ["18640"] = true, ["8623"]  = true, ["9243"] = true
}