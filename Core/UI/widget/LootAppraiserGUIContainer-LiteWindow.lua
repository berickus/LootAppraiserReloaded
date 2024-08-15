--[[-------------------------------------------------------------------------------------
-- copy of ace gui 'Window' with loot appraiser changes
---------------------------------------------------------------------------------------]]
local AceGUI = LibStub("AceGUI-3.0")

-- Lua APIs
local pairs, assert, type = pairs, assert, type

-- WoW APIs
local PlaySound = PlaySound
local CreateFrame, UIParent = CreateFrame, UIParent

-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: GameFontNormal

----------------
-- Main Frame --
----------------
--[[
	Events :
		OnClose

]]
do
	local Type = "LALiteWindow"
	local Version = 5

	local function frameOnClose(this)
		this.obj:Fire("OnClose")
	end
	
	local function closeOnClick(this)
		PlaySound(PlaySoundKitID and "gsTitleOptionExit" or 799) -- SOUNDKIT.GS_TITLE_OPTION_EXIT
		this.obj:Hide()
	end
	
	local function frameOnMouseDown(this)
		AceGUI:ClearFocus()
	end
	
	local function titleOnMouseDown(this)
		this:GetParent():StartMoving()
		AceGUI:ClearFocus()
	end
	
	local function frameOnMouseUp(this)
		local frame = this:GetParent()
		frame:StopMovingOrSizing()
		local self = frame.obj
		local status = self.status or self.localstatus
		status.width = frame:GetWidth()
		status.height = frame:GetHeight()
		status.top = frame:GetTop()
		status.left = frame:GetLeft()
	end
	
	local function sizerseOnMouseDown(this)
		this:GetParent():StartSizing("BOTTOMRIGHT")
		AceGUI:ClearFocus()
	end
	
	local function sizersOnMouseDown(this)
		this:GetParent():StartSizing("BOTTOM")
		AceGUI:ClearFocus()
	end
	
	local function sizereOnMouseDown(this)
		this:GetParent():StartSizing("RIGHT")
		AceGUI:ClearFocus()
	end
	
	local function sizerOnMouseUp(this)
		this:GetParent():StopMovingOrSizing()
	end

	local function SetTitle(self,title)
		self.titletext:SetText(title)
	end
	
	local function SetStatusText(self,text)
		-- self.statustext:SetText(text)
	end
	
	local function Hide(self)
		self.frame:Hide()
	end
	
	local function Show(self)
		self.frame:Show()
	end

	local function SetMinResize(self, width, height)
		self.frame:SetMinResize(width, height)
	end
	
	local function OnAcquire(self)
		self.frame:SetParent(UIParent)
		self.frame:SetFrameStrata("FULLSCREEN_DIALOG")
		self:ApplyStatus()
		--self:EnableResize(true)
		self:Show()
	end
	
	local function OnRelease(self)
		self.status = nil
		for k in pairs(self.localstatus) do
			self.localstatus[k] = nil
		end
	end
	
	-- called to set an external table to store status in
	local function SetStatusTable(self, status)
		assert(type(status) == "table")
		self.status = status
		self:ApplyStatus()
	end
	
	local function ApplyStatus(self)
		local status = self.status or self.localstatus
		local frame = self.frame
		self:SetWidth(status.width or 700)
		self:SetHeight(status.height or 500)
		if status.top and status.left then
			frame:SetPoint("TOP",UIParent,"BOTTOM",0,status.top)
			frame:SetPoint("LEFT",UIParent,"LEFT",status.left,0)
		else
			frame:SetPoint("CENTER",UIParent,"CENTER")
		end
	end
	
	local function OnWidthSet(self, width)
		local content = self.content
		local contentwidth = width - 34
		if contentwidth < 0 then
			contentwidth = 0
		end
		content:SetWidth(contentwidth)
		content.width = contentwidth
	end
	
	
	local function OnHeightSet(self, height)
		local content = self.content
		local contentheight = height - 57
		if contentheight < 0 then
			contentheight = 0
		end
		content:SetHeight(contentheight)
		content.height = contentheight
	end
	
	--[[
	local function EnableResize(self, state)
		local func = state and "Show" or "Hide"
		self.sizer_se[func](self.sizer_se)
		self.sizer_s[func](self.sizer_s)
		self.sizer_e[func](self.sizer_e)
	end
	]]
	
	local function Constructor()
		local frame = CreateFrame("Frame",nil,UIParent)
		local self = {}
		self.type = "LALiteWindow"
		
		self.Hide = Hide
		self.Show = Show
		self.SetTitle =  SetTitle
		self.OnRelease = OnRelease
		self.OnAcquire = OnAcquire
		self.SetStatusText = SetStatusText
		self.SetStatusTable = SetStatusTable
		self.ApplyStatus = ApplyStatus
		self.OnWidthSet = OnWidthSet
		self.OnHeightSet = OnHeightSet
		--self.EnableResize = EnableResize
		
		self.localstatus = {}
		
		self.frame = frame
		frame.obj = self
		frame:SetWidth(700)
		frame:SetHeight(32)
		frame:SetPoint("CENTER",UIParent,"CENTER",0,0)
		frame:EnableMouse()
		frame:SetMovable(true)
		frame:SetResizable(false)
		frame:SetFrameStrata("FULLSCREEN_DIALOG")
		frame:SetScript("OnMouseDown", frameOnMouseDown)
		frame:SetClampedToScreen(true)

		frame:SetScript("OnHide",frameOnClose)
		--frame:SetMinResize(240,240)
		frame:SetToplevel(true)

		local titlebg = frame:CreateTexture(nil, "BACKGROUND")
		titlebg:SetTexture([[Interface\PaperDollInfoFrame\UI-GearManager-Title-Background]])
		titlebg:SetPoint("TOPLEFT", 9, -6)
		titlebg:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -24, -24)
		
		local topleft = frame:CreateTexture(nil, "BORDER")
		topleft:SetTexture([[Interface\PaperDollInfoFrame\UI-GearManager-Collapsed]])
		topleft:SetWidth(32)
		topleft:SetHeight(32)
		topleft:SetPoint("TOPLEFT")
		topleft:SetTexCoord(0, 0.25, 0.03125, 0.96875)
		
		local topright = frame:CreateTexture(nil, "BORDER")
		topright:SetTexture([[Interface\PaperDollInfoFrame\UI-GearManager-Collapsed]])
		topright:SetWidth(32)
		topright:SetHeight(32)
		topright:SetPoint("TOPRIGHT")
		topright:SetTexCoord(0.725, 0.98, 0.03125, 0.96875)
		
		local top = frame:CreateTexture(nil, "BORDER")
		top:SetTexture([[Interface\PaperDollInfoFrame\UI-GearManager-Collapsed]])
		top:SetHeight(32)
		top:SetPoint("TOPLEFT", topleft, "TOPRIGHT")
		top:SetPoint("TOPRIGHT", topright, "TOPLEFT")
		top:SetTexCoord(0.25, 0.625, 0.03125, 0.96875)
		
		local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
		close:SetPoint("TOPRIGHT", 2, 1)
		close:SetScript("OnClick", closeOnClick)
		self.closebutton = close
		close.obj = self
		
		local titletext = frame:CreateFontString(nil, "ARTWORK")
		titletext:SetFontObject(GameFontNormal)
		titletext:SetPoint("TOPLEFT", 12, -10)
		titletext:SetPoint("TOPRIGHT", -32, -10)
		self.titletext = titletext
		
		local title = CreateFrame("Button", nil, frame)
		title:SetPoint("TOPLEFT", titlebg)
		title:SetPoint("BOTTOMRIGHT", titlebg)
		title:EnableMouse()
		title:SetScript("OnMouseDown",titleOnMouseDown)
		title:SetScript("OnMouseUp", frameOnMouseUp)
		self.title = title
	
		--Container Support
		local content = CreateFrame("Frame",nil,frame)
		self.content = content
		content.obj = self
		content:SetPoint("TOPLEFT",frame,"TOPLEFT",12,-32)
		content:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-12,13)
		
		AceGUI:RegisterAsContainer(self)
		return self	
	end
	
	AceGUI:RegisterWidgetType(Type,Constructor,Version)
end
