local LA = select(2, ...)

--[[
--LootManager
lootmanager = {}
	lootmanager["ZoneLoc"] = ""			-- will hold location of sessions
	lootmanager["LootSession"] = ""		-- will hold the sessions
	lootmanager["LootedItems"] = ""		-- will hold what was looted
--LA.LootManager = lootmanager
--]]


--Location, toon, session date/time, items looted, value
--searchable by item or location 

function LogLoot(itemID, itemLink, itemValue)
		--add in to store the data by key/each toon
		
		LA.Debug.Log("LootManager called")
		LA.Debug.Log("LM itemID: " .. itemID)
		LA.Debug.Log("LM itemLink: " .. itemLink)
		LA.Debug.Log("LM itemValue: " .. itemValue)
		local i = 0
		--get count of index
		local indexCounter = table.getn(LOOTMANAGER)
		LA.Debug.Log("table rows: " .. indexCounter)
		--add next looted item to next index number
		i = indexCounter + 1
		table.insert(LOOTMANAGER, i, itemLink)
		--table.foreach(LOOTMANAGER, print)
		
		LA.Debug.Log("Log to db: " .. itemLink)
		--add session details
		local hour, minute = GetGameTime()
		LALoot.global.session = (hour .. ":" .. minute)
			
		-- add zone details 
		local currentMapID = C_Map.GetBestMapForUnit("player")
		local zoneInfo = C_Map.GetMapInfo(currentMapID)
		zoneInfo = zoneInfo and zoneInfo.name
			
		-- add looted items from session and location
		LALoot.global.location = zoneInfo		
		local newLoot = (itemID .. "," .. itemValue .. "," .. itemLink)
		local curLoot = LALoot.global.loot
		LALoot.global.loot = (newLoot .. "\n" .. curLoot)

		
		
end