std = 'lua51'

quiet = 1 -- suppress report output for files without warnings

-- see https://luacheck.readthedocs.io/en/stable/warnings.html#list-of-warnings
-- and https://luacheck.readthedocs.io/en/stable/cli.html#patterns
ignore = {
	'212/self', -- unused argument self
	'212/event', -- unused argument event
	'212/unit', -- unused argument unit
	'212/element', -- unused argument element
	'312/event', -- unused value of argument event
	'312/unit', -- unused value of argument unit
	'431', -- shadowing an upvalue
	'614', -- trailing whitespace in a comment
	'631', -- line is too long
}

exclude_files = {
	'Libs/*',
}

globals = {
	'LOOTMANAGER',
	'START_SESSION_PROMPT',
	'NUM_BAG_SLOTS',
	'COPPER_PER_GOLD',
	'COPPER_PER_SILVER',
	'CHAT_FRAME_FADE_TIME',
	'COMBATLOG_OBJECT_TYPE_NPC',
	'LE_PARTY_CATEGORY_INSTANCE',
	'LE_PARTY_CATEGORY_HOME',
	'LOOT_ITEM_SELF',
	'LOOT_ITEM_SELF_MULTIPLE',
	'INSTANCE_RESET_SUCCESS',
	'SOUNDKIT',
	'DEFAULT_CHAT_FRAME',
	'LA_API',
	'OKAY',
	'StaticPopupDialogs',
	'StaticPopup_Show',
	'NoteworthyUI',
	'LALoot',
	'LootAppraiser_GroupLoot',
}

read_globals = {
	-- stdlib
	table = {fields = {'wipe', 'getn'}},

	-- WoW API
	'GetBuildInfo',
	'GetItemInfo',
	'GetItemCount',
	'GetCoinTextureString',
	'GetItemQualityColor',
	'UIFrameFadeOut',
	'UIFrameFadeIn',
	'IsShiftKeyDown',
	'GameTooltip',
	'GetUnitName',
	'GetRealmName',
	'C_AddOns',
	'C_Map',
	'ResetInstances',
	'IsInGroup',
	'GetChatWindowInfo',
	'SendChatMessage',
	'GetMerchantNumItems',
	'DeleteCursorItem',
	'SecondsToTime',
	'C_Item',
	'C_ChatInfo',
	'C_Container',
	'C_WowTokenPublic',
	'C_Timer',
	'TUJTooltip',
	'GameFontHighlightSmall',
	'InterfaceOptions_AddCategory',
	'Settings',
	'SettingsPanel',
	'UnitRace',
	'CreateFrame',
	'UIParent',
	'MenuUtil',
	'GameFontNormal',
	'PlaySound',
	'PlaySoundFile',
	'PlaySoundKitID',
	'BackdropTemplateMixin',
	'AddonCompartmentFrame',
	'RepairAllItems',
	'GetMoney',
	'GetRepairAllCost',
	'CanMerchantRepair',
	'UnitGUID',
	'GetGameTime',
	'GetTime',
	'UnitExists',
	'UnitCreatureType',
	'UnitIsDead',
	'UnitName',
	'GetNumLootItems',
	'GetLootSourceInfo',
	'CombatLogGetCurrentEventInfo',

	-- math, str, etc.
	'abs',
	'floor',
	'sort',
	'time',
	'date',
	'strfind',
	'gsub',
	'bit',
	'strsplit',

	-- Auctionator, Oribos
	'Auctionator',
	'OEMarketInfo',

	-- exposed from other addons
	'LibStub',
}