--[[
    MinimapIcon.lua
    DataBroker, minimap icon, and addon compartment integration
]]

local LA = select(2, ...)

local MinimapIcon = {}
LA.MinimapIcon = MinimapIcon

-- Wow APIs
local IsShiftKeyDown, SecondsToTime, time, pairs =
    IsShiftKeyDown, SecondsToTime, time, pairs

local private = {}

--[[------------------------------------------------------------------------
    Tooltip drawing (shared between minimap icon and addon compartment)
--------------------------------------------------------------------------]]
local function tooltip_draw(isAddonCompartment, blizzardTooltip)
    local tooltip
    if isAddonCompartment then
        tooltip = blizzardTooltip
    else
        tooltip = GameTooltip
    end

    tooltip:AddDoubleLine(LA.CONST.METADATA.NAME, LA.CONST.METADATA.VERSION)
    tooltip:AddLine(" ")
    tooltip:AddLine("|cffff8040Left-Click|r to open the main window")
    tooltip:AddLine("|cffff8040Right-Click|r to open options window")
    tooltip:Show()
end

LA.GenerateTooltip = tooltip_draw

--[[------------------------------------------------------------------------
    Handle click actions (shared between all icon sources)
--------------------------------------------------------------------------]]
function private.HandleLeftClick()
    local isShiftKeyDown = IsShiftKeyDown()
    if isShiftKeyDown then
        local callback = private.GetModuleCallback("LeftButton", "Shift")
        if callback then callback() end
    else
        if not LA.Session.IsRunning() then
            LA.Session.Start(true)
        end
        LA.UI.ShowMainWindow(true)
    end
end

function private.HandleRightClick()
    local isShiftKeyDown = IsShiftKeyDown()
    if isShiftKeyDown then
        local callback = private.GetModuleCallback("RightButton", "Shift")
        if callback then callback() end
    else
        if LA.configFrameID then
            Settings.OpenToCategory(LA.configFrameID)
            SettingsPanel.AddOnsTab:Click()
        else
            Settings.OpenToCategory(LA.CONST.METADATA.NAME)
            SettingsPanel.AddOnsTab:Click()
        end
    end
end

function private.HandleClick(button)
    if button == "LeftButton" then
        private.HandleLeftClick()
    elseif button == "RightButton" then
        private.HandleRightClick()
    end
end

--[[------------------------------------------------------------------------
    Get module callback for icon actions
--------------------------------------------------------------------------]]
function private.GetModuleCallback(button, modifier)
    local modules = LA.GetModules()
    if not modules then return end

    for name, module in pairs(modules) do
        if module.icon and module.icon.action then
            for _, action in pairs(module.icon.action) do
                if action.button == button and action.modifier == modifier then
                    return action.callback
                end
            end
        end
    end
end

--[[------------------------------------------------------------------------
    DataBroker: "LootedItemValue" data source (for ElvUI support / datatexts)
--------------------------------------------------------------------------]]
function MinimapIcon.SetupDataBroker()
    local ldb = LibStub("LibDataBroker-1.1")

    ldb:NewDataObject("LootedItemValue", {
        type = "data source",
        text = "0g",
        label = "Looted Item Value",

        OnClick = function(self, button, down)
            private.HandleClick(button)
        end
    })

    -- Periodic update frame for data text
    local UPDATEPERIOD, elapsed = 1, 0
    local f = CreateFrame("Frame")
    f:SetScript("OnUpdate", function(self, elap)
        elapsed = elapsed + elap
        if elapsed < UPDATEPERIOD then return end
        elapsed = 0

        local lootedItemValue = 0
        local currentSession = LA:getCurrentSession()
        if currentSession ~= nil then
            lootedItemValue = currentSession["liv"] or 0
        end

        -- Update the data object text
        local dataobj = ldb:GetDataObjectByName("LootedItemValue")
        if dataobj then
            dataobj.text = LA.Util.MoneyToString(lootedItemValue)
        end
    end)
end

--[[------------------------------------------------------------------------
    Minimap icon setup (LibDBIcon)
--------------------------------------------------------------------------]]
function MinimapIcon.SetupMinimapIcon()
    LA.icon = LibStub("LibDBIcon-1.0")
    LA.LibDataBroker = LibStub("LibDataBroker-1.1"):NewDataObject(
        LA.CONST.METADATA.NAME, {
            type = "launcher",
            text = LA.CONST.METADATA.NAME,
            icon = "Interface\\Icons\\Ability_Racial_PackHobgoblin",

            OnClick = function(self, button, down)
                private.HandleClick(button)
            end,

            OnTooltipShow = function(tooltip)
                tooltip:AddLine(LA.CONST.METADATA.NAME .. " " .. LA.CONST.METADATA.VERSION, 1, 1, 1)
                tooltip:AddLine("|cFFFFFFCCLeft-Click|r to open the main window")
                tooltip:AddLine("|cFFFFFFCCRight-Click|r to open options window")
                tooltip:AddLine("|cFFFFFFCCDrag|r to move this button")
                tooltip:AddLine(" ")

                if LA.Session.IsRunning() then
                    local offset = LA.Session.GetPauseStart() or time()
                    local delta = offset - LA.Session.GetCurrentSession("start") -
                                      LA.Session.GetSessionPause()

                    local noSeconds = delta > 3600

                    local text = "Session is "
                    if LA.Session.IsPaused() then
                        text = text .. "paused: "
                    else
                        text = text .. "running: "
                    end

                    tooltip:AddDoubleLine(text, SecondsToTime(delta, noSeconds, false))
                else
                    tooltip:AddLine("Session is not running")
                end

                -- Module tooltip lines
                local modules = LA.GetModules()
                if modules then
                    for name, module in pairs(modules) do
                        if module.icon and module.icon.tooltip then
                            tooltip:AddLine(" ")
                            for _, line in pairs(module.icon.tooltip) do
                                tooltip:AddLine(line)
                            end
                        end
                    end
                end
            end
        })

    LA.icon:Register(LA.CONST.METADATA.NAME, LA.LibDataBroker, LA.db.profile.minimapIcon)

    if LA.db.profile.minimapIcon.hide == true then
        LA.icon:Show(LA.CONST.METADATA.NAME)
    else
        LA.icon:Hide(LA.CONST.METADATA.NAME)
    end
end

--[[------------------------------------------------------------------------
    Addon Compartment (retail 10.x+)
--------------------------------------------------------------------------]]
function MinimapIcon.SetupAddonCompartment()
    if not LA.Util.IsModern then return end

    AddonCompartmentFrame:RegisterAddon({
        text = LA.CONST.METADATA.NAME,
        icon = "Interface\\Icons\\inv_scroll_11",
        registerForAnyClick = true,
        notCheckable = true,
        func = function(button, menuInputData, menu)
            private.HandleClick(menuInputData.buttonName)
        end,
        funcOnEnter = function(button)
            MenuUtil.ShowTooltip(button, function(tooltip)
                LA.GenerateTooltip(true, tooltip)
            end)
        end,
        funcOnLeave = function(button)
            MenuUtil.HideTooltip(button)
        end
    })
end
