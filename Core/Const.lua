local LA = LibStub("AceAddon-3.0"):NewAddon(select(2, ...),
                                            "LootAppraiser Reloaded",
                                            "AceConsole-3.0", "AceEvent-3.0",
                                            "LibSink-2.0") -- "AceHook-3.0",

-- wow api
local GetAddOnMetadata, UIParent = C_AddOns.GetAddOnMetadata, UIParent

local CONST = {}
LA.CONST = CONST

CONST.METADATA = {
    NAME = GetAddOnMetadata(..., "Title"),
    VERSION = GetAddOnMetadata(..., "Version")
}

CONST.QUALITY_FILTER = { -- little hack to sort them in the menu
    ["0"] = "|cff9d9d9dPoor|r",
    ["1"] = "|cffffffffCommon|r",
    ["2"] = "|cff1eff00Uncommon|r",
    ["3"] = "|cff0070ddRare|r",
    ["4"] = "|cffa335eeEpic|r"
}

-- TSM predefined price sources + 'Custom'
CONST.PRICE_SOURCE = {
    ["VendorValue"] = "BLIZ: Vendor price", -- Native Blizzard Pricing for Vendor
    ["Custom"] = "Custom Price Source", -- TSM price sources
    ["DBHistorical"] = "TSM: Historical Price",
    ["DBMarket"] = "TSM: Market Value",
    ["DBRecent"] = "TSM: Recent Value",
    ["DBMinBuyout"] = "TSM: Min Buyout",
    ["DBRegionHistorical"] = "TSM: Region Historical Price",
    ["DBRegionMarketAvg"] = "TSM: Region Market Value Avg",
    ["DBRegionSaleAvg"] = "TSM: Region Sale Avg",
    ["VendorSell"] = "TSM: VendorSell",
    ["region"] = "OE: Median All Realms in Region", -- OEMarketInfo (OE) (add:  ["market"] = "OE: Median AH 4-Day")
    ["Auctionator"] = "AN: Auctionator" -- Auctionator price source
}

CONST.PARTYLOOT_MSGPREFIX = "LA_PARTYLOOT"

-- la defaults
local parentHeight = UIParent:GetHeight()
CONST.DB_DEFAULTS = {
    profile = {
        enableDebugOutput = false,
        -- minimap icon position and visibility
        minimapIcon = {hide = false, minimapPos = 220, radius = 80},
        mainUI = {
            ["height"] = 400,
            ["top"] = (parentHeight - 50),
            ["left"] = 50,
            ["width"] = 400
        },
        timerUI = {
            ["height"] = 32,
            ["top"] = (parentHeight + 55),
            ["left"] = 50,
            ["width"] = 400
        },
        challengeUI = {
            ["height"] = 400,
            ["top"] = (parentHeight - 50),
            ["left"] = 50,
            ["width"] = 400
        },
        liteUI = {
            ["height"] = 32,
            ["top"] = (parentHeight + 20),
            ["left"] = 50,
            ["width"] = 400
        },
        lastNotewothyItemUI = {
            ["height"] = 32,
            ["top"] = (parentHeight - 15),
            ["left"] = 50,
            ["width"] = 400
        },
        lastNotewothyItemUI2 = {
            ["height"] = 32,
            ["top"] = (parentHeight - 15),
            ["left"] = 50,
            ["width"] = 400
        },
        startSessionPromptUI = {},
        general = {
            ["ignoreRandomEnchants"] = true,
            ["surpressSessionStartDialog"] = true,
            ["ignoreSoulboundItems"] = false,
            ["sellGrayItemsToVendor"] = false,
            ["autoRepairGear"] = false
        },
        pricesource = {
            ["source"] = "DBRegionMarketAvg",
            ["useDisenchantValue"] = false
        },
        notification = {
            ["sink"] = {
                ["sink20Sticky"] = false,
                ["sink20OutputSink"] = "RaidWarning"
            },
            ["enableToasts"] = false,
            ["trackCrafts"] = false,
            ["qualityFilter"] = "1",
            ["goldAlertThresholdA"] = "100",
            ["goldAlertThresholdB"] = "0",
            ["goldAlertThresholdC"] = "0",
            ["playSoundEnabled"] = true,
            ["soundNameA"] = "Auction Window Open",
            ["soundNameB"] = "None",
            ["soundNameC"] = "None"
        },
        itemclasses = {},
        sellTrash = {
            ["tsmGroupEnabled"] = false,
            ["tsmGroup"] = "LootAppraiser Reloaded`Trash"
        },
        blacklist = {
            ["tsmGroupEnabled"] = false,
            ["tsmGroup"] = "LootAppraiser Reloaded`Blacklist",
            ["addBlacklistedItems2DestroyTrash"] = false
        },
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
            enableLootAppraiserReloadedLite = false,
            enableLootAppraiserReloadedTimerUI = false,
            enableStatisticTooltip = true,
            enableMinimapIcon = true,
            showLootedItemValueGroup = false,
            showLootedItemValueGroupPerHour = false,
            addGroupDropsToLootedItemList = false,
            showGroupLootAlerts = true, -- new value for opting-out of seeing group/party loot alerts
            showWoWTokenPercentage = false
        },
        sessionData = {groupBy = "datetime"}
    },
    global = {sessions = {}, drops = {}}
}

CONST.DB_LOOT = {
    global = {
        dbVersion = 2,
        sessions = {},
        nextSessionID = 1,
        -- Legacy fields kept for backwards compatibility
        session = {},
        location = {},
        loot = {}
    }
}

CONST.ITEM_FILTER_BLACKLIST = {
    -- These items are from AQ20.  All of the Idols and Scarabs are Blacklisted.
    ["20858"] = true,
    ["20859"] = true,
    ["20860"] = true,
    ["20861"] = true,
    ["20862"] = true,
    ["20863"] = true,
    ["20864"] = true,
    ["20865"] = true,
    ["20874"] = true,
    ["20866"] = true,
    ["20868"] = true,
    ["20869"] = true,
    ["20870"] = true,
    ["20871"] = true,
    ["20872"] = true,
    ["20873"] = true,
    ["20867"] = true,
    ["20875"] = true,
    ["20876"] = true,
    ["20877"] = true,
    ["20878"] = true,
    ["20879"] = true,
    ["20881"] = true,
    ["20882"] = true,
    ["19183"] = true,
    ["18640"] = true,
    ["8623"] = true,
    ["9243"] = true
}
