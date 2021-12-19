local Talented = _G.Talented
local L = LibStub("AceLocale-3.0"):GetLocale("Talented")

-- globals
local CreateFrame = CreateFrame
local GREEN_FONT_COLOR = GREEN_FONT_COLOR
local NORMAL_FONT_COLOR = NORMAL_FONT_COLOR
local min, max = math.min, math.max
local GameTooltip = GameTooltip

-------------------------------------------------------------------------------
-- ui\pool.lua - Talented.Pool
--

do
	local rawget, rawset = rawget, rawset
	local setmetatable = setmetatable
	local pairs, ipairs = pairs, ipairs

	local Pool = {pools = {}, sets = {}}

	function Pool:new()
		local pool = setmetatable({used = {}, available = {}}, self)
		self.pools[pool] = true
		return pool
	end

	function Pool:changeSet(name)
		if not self.sets[name] then
			self.sets[name] = {}
		end
		assert(self.sets[name])
		self.set = name
		self:clearSet(name)
	end

	function Pool:clearSet(name)
		local set = self.sets[name]
		assert(set)
		for widget, pool in pairs(set) do
			assert(pool.used[widget])
			widget:Hide()
			pool.used[widget] = nil
			pool.available[widget] = true
			set[widget] = nil
		end
	end

	function Pool:AddToSet(widget, pool)
		self.sets[self.set][widget] = pool
	end

	Pool.__index = {
		next = function(self)
			local widget = next(self.available)
			if not widget then return end
			self.available[widget] = nil
			self.used[widget] = true
			widget:Show()
			Pool:AddToSet(widget, self)
			return widget
		end,
		push = function(self, widget)
			self.used[widget] = true
			Pool:AddToSet(widget, self)
		end
	}

	Talented.Pool = Pool
end

-------------------------------------------------------------------------------
-- ui\base.lua
--

do
	local PlaySound = PlaySound

	Talented.uielements = {}

	-- All this exists so that a UIPanelButtonTemplate2 like button correctly works
	-- with :SetButtonState(). This is because the state is only updated after
	-- :OnMouse{Up|Down}().

	local BUTTON_TEXTURES = {
		NORMAL = "Interface\\Buttons\\UI-Panel-Button-Up",
		PUSHED = "Interface\\Buttons\\UI-Panel-Button-Down",
		DISABLED = "Interface\\Buttons\\UI-Panel-Button-Disabled",
		PUSHED_DISABLED = "Interface\\Buttons\\UI-Panel-Button-Disabled-Down"
	}
	local DefaultButton_Enable = GameMenuButtonOptions.Enable
	local DefaultButton_Disable = GameMenuButtonOptions.Disable
	local DefaultButton_SetButtonState = GameMenuButtonOptions.SetButtonState
	local function Button_SetState(self, state)
		if not state then
			if self:IsEnabled() == 0 then
				state = "DISABLED"
			else
				state = self:GetButtonState()
			end
		end
		if state == "DISABLED" and self.locked_state == "PUSHED" then
			state = "PUSHED_DISABLED"
		end
		local texture = BUTTON_TEXTURES[state]
		self.left:SetTexture(texture)
		self.middle:SetTexture(texture)
		self.right:SetTexture(texture)
	end

	local function Button_SetButtonState(self, state, locked)
		self.locked_state = locked and state
		if self:IsEnabled() ~= 0 then
			DefaultButton_SetButtonState(self, state, locked)
		end
		Button_SetState(self)
	end

	local function Button_OnMouseDown(self)
		Button_SetState(self, self:IsEnabled() == 0 and "DISABLED" or "PUSHED")
	end

	local function Button_OnMouseUp(self)
		Button_SetState(self, self:IsEnabled() == 0 and "DISABLED" or "NORMAL")
	end

	local function Button_Enable(self)
		DefaultButton_Enable(self)
		if self.locked_state then
			Button_SetButtonState(self, self.locked_state, true)
		else
			Button_SetState(self)
		end
	end

	local function Button_Disable(self)
		DefaultButton_Disable(self)
		Button_SetState(self)
	end

	local function MakeButton(parent)
		local button = CreateFrame("Button", nil, parent)
		button:SetNormalFontObject(GameFontNormal)
		button:SetHighlightFontObject(GameFontHighlight)
		button:SetDisabledFontObject(GameFontDisable)

		local texture = button:CreateTexture()
		texture:SetTexCoord(0, 0.09375, 0, 0.6875)
		texture:SetPoint "LEFT"
		texture:SetSize(12, 22)
		button.left = texture

		texture = button:CreateTexture()
		texture:SetTexCoord(0.53125, 0.625, 0, 0.6875)
		texture:SetPoint "RIGHT"
		texture:SetSize(12, 22)
		button.right = texture

		texture = button:CreateTexture()
		texture:SetTexCoord(0.09375, 0.53125, 0, 0.6875)
		texture:SetPoint("LEFT", button.left, "RIGHT")
		texture:SetPoint("RIGHT", button.right, "LEFT")
		texture:SetHeight(22)
		button.middle = texture

		texture = button:CreateTexture()
		texture:SetTexture "Interface\\Buttons\\UI-Panel-Button-Highlight"
		texture:SetBlendMode "ADD"
		texture:SetTexCoord(0, 0.625, 0, 0.6875)
		texture:SetAllPoints(button)
		button:SetHighlightTexture(texture)

		button:SetScript("OnMouseDown", Button_OnMouseDown)
		button:SetScript("OnMouseUp", Button_OnMouseUp)
		button:SetScript("OnShow", Button_SetState)
		button.Enable = Button_Enable
		button.Disable = Button_Disable
		button.SetButtonState = Button_SetButtonState

		table.insert(Talented.uielements, button)
		return button
	end

	local function CreateBaseButtons(parent)
		local function Frame_OnEnter(self)
			if self.tooltip then
				GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
				GameTooltip:SetText(self.tooltip, nil, nil, nil, nil, 1)
			end
		end

		local function Frame_OnLeave(self)
			if GameTooltip:IsOwned(self) then
				GameTooltip:Hide()
			end
		end

		local b = MakeButton(parent)
		b:SetText(L["Actions"])
		b:SetSize(max(100, b:GetTextWidth() + 22), 22)
		b:SetScript("OnClick", function(self) Talented:OpenActionMenu(self) end)
		b:SetPoint("TOPLEFT", 5, -4)
		parent.bactions = b

		b = MakeButton(parent)
		b:SetText(L["Templates"])
		b:SetSize(max(100, b:GetTextWidth() + 22), 22)
		b:SetScript("OnClick", function(self) Talented:OpenTemplateMenu(self) end)
		b:SetPoint("LEFT", parent.bactions, "RIGHT", 14, 0)
		parent.bmode = b

		b = MakeButton(parent)
		b:SetText(GLYPHS)
		b:SetSize(max(100, b:GetTextWidth() + 22), 22)
		b:SetScript("OnClick", function(self) Talented:ToggleGlyphFrame() end)
		b:SetPoint("LEFT", parent.bmode, "RIGHT", 14, 0)
		parent.bglyphs = b

		local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
		e:SetFontObject(ChatFontNormal)
		e:SetTextColor(GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b)
		e:SetSize(185, 13)
		e:SetAutoFocus(false)
		e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
		e:SetScript("OnEditFocusLost", function(self) self:SetText(Talented.template.name) end)
		e:SetScript("OnEnterPressed", function(self)
			Talented:UpdateTemplateName(Talented.template, self:GetText())
			Talented:UpdateView()
			self:ClearFocus()
		end)
		e:SetScript("OnEnter", Frame_OnEnter)
		e:SetScript("OnLeave", Frame_OnLeave)
		e:SetPoint("LEFT", parent.bglyphs, "RIGHT", 14, 1)
		e.tooltip = L["You can edit the name of the template here. You must press the Enter key to save your changes."]
		parent.editname = e

		local targetname = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		targetname:SetJustifyH("LEFT")
		targetname:SetSize(185, 13)
		targetname:SetPoint("LEFT", parent.bglyphs, "RIGHT", 14, 0)
		parent.targetname = targetname

		do
			local f = CreateFrame("Frame", nil, parent)
			local text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			text:SetJustifyH("RIGHT")
			text:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -14, 8)
			f:SetPoint("BOTTOMRIGHT")
			f:SetFrameLevel(parent:GetFrameLevel() + 2)
			f.text = text
			parent.pointsleft = f
		end

		local cb = CreateFrame("Checkbutton", nil, parent)
		parent.checkbox = cb

		local makeTexture = function(path, blend)
			local t = cb:CreateTexture()
			t:SetTexture(path)
			t:SetAllPoints(cb)
			if blend then
				t:SetBlendMode(blend)
			end
			return t
		end

		cb:SetSize(20, 20)

		local label = cb:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
		label:SetJustifyH("LEFT")
		label:SetSize(400, 20)
		label:SetPoint("LEFT", cb, "RIGHT", 1, 1)
		cb.label = label

		cb:SetNormalTexture(makeTexture("Interface\\Buttons\\UI-CheckBox-Up"))
		cb:SetPushedTexture(makeTexture("Interface\\Buttons\\UI-CheckBox-Down"))
		cb:SetDisabledTexture(makeTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled"))
		cb:SetCheckedTexture(makeTexture("Interface\\Buttons\\UI-CheckBox-Check"))
		cb:SetHighlightTexture(makeTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD"))
		cb:SetScript("OnClick", function() Talented:SetMode(Talented.mode == "edit" and "view" or "edit") end)
		cb:SetScript("OnEnter", Frame_OnEnter)
		cb:SetScript("OnLeave", Frame_OnLeave)
		cb:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 14, 8)
		cb:SetFrameLevel(parent:GetFrameLevel() + 2)

		local points = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		points:SetJustifyH("RIGHT")
		points:SetSize(80, 14)
		points:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -40, -6)
		parent.points = points

		b = MakeButton(parent)
		b:SetText(TALENT_SPEC_ACTIVATE)
		b:SetSize(b:GetTextWidth() + 40, 22)
		b:SetScript("OnClick", function(self)
			if self.talentGroup then
				SetActiveTalentGroup(self.talentGroup)
			end
		end)
		b:SetPoint("BOTTOM", 0, 6)
		b:SetFrameLevel(parent:GetFrameLevel() + 2)
		parent.bactivate = b
	end

	local function BaseFrame_SetTabSize(self, tabs)
		tabs = tabs or 3
		local bglyphs, editname, targetname, points = self.bglyphs, self.editname, self.targetname, self.points
		bglyphs:ClearAllPoints()
		editname:ClearAllPoints()
		targetname:ClearAllPoints()
		points:ClearAllPoints()
		if tabs == 1 then
			bglyphs:SetPoint("TOPLEFT", self.bactions, "BOTTOMLEFT", 0, -5)
			editname:SetPoint("TOPLEFT", bglyphs, "BOTTOMLEFT", 0, -4)
			targetname:SetPoint("TOPLEFT", bglyphs, "BOTTOMLEFT", 0, -5)
			points:SetPoint("TOPRIGHT", self, "TOPRIGHT", -8, -56)
		elseif tabs == 2 then
			bglyphs:SetPoint("LEFT", self.bmode, "RIGHT", 14, 0)
			editname:SetPoint("TOPLEFT", bglyphs, "BOTTOMLEFT", 0, -4)
			targetname:SetPoint("TOPLEFT", bglyphs, "BOTTOMLEFT", 0, -5)
			points:SetPoint("TOPRIGHT", self, "TOPRIGHT", -8, -31)
		elseif tabs == 3 then
			bglyphs:SetPoint("LEFT", self.bmode, "RIGHT", 14, 0)
			editname:SetPoint("LEFT", bglyphs, "RIGHT", 14, 1)
			targetname:SetPoint("LEFT", bglyphs, "RIGHT", 14, 0)
			points:SetPoint("TOPRIGHT", self, "TOPRIGHT", -40, -6)
		end
	end

	local function CloseButton_OnClick(self, button)
		if button == "LeftButton" then
			if self.OnClick then
				self:OnClick(button)
			else
				self:GetParent():Hide()
			end
		else
			Talented:OpenLockMenu(self, self:GetParent())
		end
	end

	function Talented:CreateCloseButton(parent, OnClickHandler)
		local close = CreateFrame("Button", nil, parent)

		local makeTexture = function(path, blend)
			local t = close:CreateTexture()
			t:SetAllPoints(close)
			t:SetTexture(path)
			if blend then
				t:SetBlendMode(blend)
			end
			return t
		end

		close:SetNormalTexture(makeTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up"))
		close:SetPushedTexture(makeTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down"))
		close:SetHighlightTexture(makeTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD"))
		close:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		close:SetScript("OnClick", CloseButton_OnClick)
		close.OnClick = OnClickHandler

		close:SetSize(32, 32)
		close:SetPoint("TOPRIGHT", 1, 0)

		return close
	end

	function Talented:CreateBaseFrame()
		local frame = _G.TalentedFrame or CreateFrame("Frame", "TalentedFrame", UIParent)
		frame:Hide()

		frame:SetFrameStrata("DIALOG")
		frame:EnableMouse(true)
		frame:SetToplevel(true)
		frame:SetSize(50, 50)
		frame:SetBackdrop({
			bgFile = "Interface\\TutorialFrame\\TutorialFrameBackground",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true,
			edgeSize = 16,
			tileSize = 32,
			insets = {left = 5, right = 5, top = 5, bottom = 5}
		})

		local close = self:CreateCloseButton(frame, function(self) HideUIPanel(self:GetParent()) end)
		frame.close = close
		table.insert(Talented.uielements, close)

		CreateBaseButtons(frame)

		UISpecialFrames[#UISpecialFrames + 1] = "TalentedFrame"

		frame:SetScript("OnShow", function()
			Talented:RegisterEvent("MODIFIER_STATE_CHANGED")
			SetButtonPulse(TalentMicroButton, 0, 1)
			PlaySound "TalentScreenOpen"
			Talented:UpdateMicroButtons()
		end)
		frame:SetScript("OnHide", function()
			PlaySound "TalentScreenClose"
			if Talented.mode == "apply" then
				Talented:SetMode(Talented:GetDefaultMode())
				Talented:Print(L["Error! Talented window has been closed during template application. Please reapply later."])
				Talented:EnableUI(true)
			end
			Talented:CloseMenu()
			Talented:UpdateMicroButtons()
			Talented:UnregisterEvent("MODIFIER_STATE_CHANGED")
		end)
		frame.SetTabSize = BaseFrame_SetTabSize
		frame.view = self.TalentView:new(frame, "base")
		self:LoadFramePosition(frame)
		self:SetFrameLock(frame)

		self.base = frame
		self.CreateBaseFrame = function(self)
			return self.base
		end
		return frame
	end

	function Talented:EnableUI(enable)
		if enable then
			for _, element in ipairs(self.uielements) do
				element:Enable()
			end
		else
			for _, element in ipairs(self.uielements) do
				element:Disable()
			end
		end
	end

	function Talented:MakeAlternateView()
		local frame = CreateFrame("Frame", "TalentedAltFrame", UIParent)

		frame:SetFrameStrata("DIALOG")
		if _G.TalentedFrame then
			frame:SetFrameLevel(_G.TalentedFrame:GetFrameLevel() + 5)
		end
		frame:EnableMouse(true)
		frame:SetToplevel(true)
		frame:SetSize(50, 50)
		frame:SetBackdrop({
			bgFile = "Interface\\TutorialFrame\\TutorialFrameBackground",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true,
			edgeSize = 16,
			tileSize = 32,
			insets = {left = 5, right = 5, top = 5, bottom = 5}
		})

		frame.close = self:CreateCloseButton(frame)
		frame.view = self.TalentView:new(frame, "alt")
		self:LoadFramePosition(frame)
		self:SetFrameLock(frame)

		self.altView = frame
		self.MakeAlternateView = function(self)
			return self.altView
		end
		return frame
	end
end

-------------------------------------------------------------------------------
-- ui\trees.lua
--

do
	local function CreateTexture(base, layer, path, blend)
		local t = base:CreateTexture(nil, layer)
		if path then
			t:SetTexture(path)
		end
		if blend then
			t:SetBlendMode(blend)
		end
		return t
	end

	local trees = Talented.Pool:new()

	local function Layout(frame, width, height)
		local texture_height = height / (256 + 75)
		local texture_width = width / (256 + 44)

		frame:SetSize(width, height)

		local wl, wr, ht, hb = texture_width * 256, texture_width * 64, texture_height * 256, texture_height * 128

		frame.topleft:SetSize(wl, ht)
		frame.topright:SetSize(wr, ht)
		frame.bottomleft:SetSize(wl, hb)
		frame.bottomright:SetSize(wr, hb)

		frame.name:SetWidth(width)
	end

	local function ClearBranchButton_OnClick(self)
		local parent = self:GetParent()
		if parent.view then
			parent.view:ClearTalentTab(parent.tab)
		else
			Talented:ClearTalentTab(self:GetParent().tab)
		end
	end

	local function NewTalentFrame(parent)
		local frame = CreateFrame("Frame", nil, parent)
		frame:SetPoint("TOPLEFT")

		local t = CreateTexture(frame, "BACKGROUND")
		t:SetPoint("TOPLEFT")
		frame.topleft = t

		t = CreateTexture(frame, "BACKGROUND")
		t:SetPoint("TOPLEFT", frame.topleft, "TOPRIGHT")
		frame.topright = t

		t = CreateTexture(frame, "BACKGROUND")
		t:SetPoint("TOPLEFT", frame.topleft, "BOTTOMLEFT")
		frame.bottomleft = t

		t = CreateTexture(frame, "BACKGROUND")
		t:SetPoint("TOPLEFT", frame.topleft, "BOTTOMRIGHT")
		frame.bottomright = t

		local fs = frame:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
		fs:SetPoint("TOP", 0, -4)
		fs:SetJustifyH("CENTER")
		frame.name = fs

		local overlay = CreateFrame("Frame", nil, frame)
		overlay:SetAllPoints(frame)

		frame.overlay = overlay

		local clear = CreateFrame("Button", nil, frame)
		frame.clear = clear

		local makeTexture = function(path, blend)
			local t = CreateTexture(clear, nil, path, blend)
			t:SetAllPoints(clear)
			return t
		end

		clear:SetNormalTexture(makeTexture("Interface\\Buttons\\CancelButton-Up"))
		clear:SetPushedTexture(makeTexture("Interface\\Buttons\\CancelButton-Down"))
		clear:SetHighlightTexture(makeTexture("Interface\\Buttons\\CancelButton-Highlight", "ADD"))

		clear:SetScript("OnClick", ClearBranchButton_OnClick)
		clear:SetScript("OnEnter", Talented.base.editname:GetScript("OnEnter"))
		clear:SetScript("OnLeave", Talented.base.editname:GetScript("OnLeave"))
		clear.tooltip = L["Remove all talent points from this tree."]
		clear:SetSize(32, 32)
		clear:ClearAllPoints()
		clear:SetPoint("TOPRIGHT", -4, -4)

		trees:push(frame)

		return frame
	end

	function Talented:MakeTalentFrame(parent, width, height)
		local tree = trees:next()
		if tree then
			tree:SetParent(parent)
		else
			tree = NewTalentFrame(parent)
		end
		Layout(tree, width, height)
		return tree
	end
end

-------------------------------------------------------------------------------
-- ui\buttons.lua
--

do
	local function CreateTexture(base, layer, path, blend)
		local t = base:CreateTexture(nil, layer)
		if path then
			t:SetTexture(path)
		end
		if blend then
			t:SetBlendMode(blend)
		end
		return t
	end

	local buttons = Talented.Pool:new()

	local function Button_OnEnter(self)
		local parent = self:GetParent()
		parent.view:SetTooltipInfo(self, parent.tab, self.id)
	end

	local function Button_OnLeave(self)
		Talented:HideTooltipInfo()
	end

	local function Button_OnClick(self, button, down)
		local parent = self:GetParent()
		parent.view:OnTalentClick(button, parent.tab, self.id)
	end

	local function MakeRankFrame(button, anchor)
		local t = CreateTexture(button, "OVERLAY", "Interface\\Addons\\Talented\\Textures\\border")
		t:SetSize(32, 32)
		t:SetPoint("CENTER", button, anchor)
		local fs = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		fs.texture = t
		fs:SetPoint("CENTER", t)
		return fs
	end

	local function NewButton(parent)
		local button = CreateFrame("Button", nil, parent.child or parent)
		-- ItemButtonTemplate (minus Count and Slot)
		button:SetSize(37, 37)
		local t = CreateTexture(button, "BORDER")
		t:SetSize(64, 64)
		t:SetAllPoints(button)
		button.texture = t
		t = CreateTexture(button, nil, "Interface\\Buttons\\UI-Quickslot2")
		t:SetSize(64, 64)
		t:SetPoint("CENTER", 0, -1)
		button:SetNormalTexture(t)
		t = CreateTexture(button, nil, "Interface\\Buttons\\UI-Quickslot-Depress")
		t:SetSize(36, 36)
		t:SetPoint("CENTER")
		button:SetPushedTexture(t)
		t = CreateTexture(button, nil, "Interface\\Buttons\\ButtonHilight-Square", "ADD")
		t:SetSize(36, 36)
		t:SetPoint("CENTER")
		button:SetHighlightTexture(t)
		-- TalentButtonTemplate
		local texture = CreateTexture(button, "BACKGROUND", "Interface\\Buttons\\UI-EmptySlot-White")
		texture:SetSize(64, 64)
		texture:SetPoint("CENTER", 0, -1)
		button.slot = texture

		button.rank = MakeRankFrame(button, "BOTTOMRIGHT")

		button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

		button:SetScript("OnEnter", Button_OnEnter)
		button:SetScript("OnLeave", Button_OnLeave)
		button:SetScript("OnClick", Button_OnClick)

		buttons:push(button)
		return button
	end

	function Talented:MakeButton(parent)
		local button = buttons:next()
		if button then
			button:SetParent(parent)
		else
			button = NewButton(parent)
		end
		return button
	end

	function Talented:GetButtonTarget(button)
		local target = button.target
		if not target then
			target = MakeRankFrame(button, "TOPRIGHT")
			button.target = target
		end
		return target
	end
end

-------------------------------------------------------------------------------
-- ui\branches.lua
--

do
	local branches = Talented.Pool:new()

	local function NewBranch(parent)
		local t = parent:CreateTexture(nil, "BORDER")
		t:SetTexture("Interface\\Addons\\Talented\\Textures\\branches-normal")
		t:SetSize(32, 32)
		t:SetVertexColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)

		branches:push(t)

		return t
	end

	function Talented:MakeBranch(parent)
		local branch = branches:next()
		if branch then
			branch:SetParent(parent)
		else
			branch = NewBranch(parent)
		end
		return branch
	end
end

-------------------------------------------------------------------------------
-- ui\arrows.lua
--

do
	local arrows = Talented.Pool:new()

	local function NewArrow(parent)
		local t = parent:CreateTexture(nil, "OVERLAY")
		t:SetTexture("Interface\\Addons\\Talented\\Textures\\arrows-normal")
		t:SetSize(32, 32)
		t:SetVertexColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)

		arrows:push(t)

		return t
	end

	function Talented:MakeArrow(parent)
		local arrow = arrows:next()
		if arrow then
			arrow:SetParent(parent.overlay)
		else
			arrow = NewArrow(parent.overlay)
		end
		return arrow
	end
end

-------------------------------------------------------------------------------
-- ui\lines.lua
--

do
	local COORDS = {
		branch = {
			top = {left = 0.12890625, width = 0.125, height = 0.96875},
			left = {left = 0.2578125, width = 0.125},
			topright = {left = 0.515625, width = 0.125},
			topleft = {left = 0.640625, width = -0.125}
		},
		arrow = {
			top = {left = 0, width = 0.5},
			left = {left = 0.5, width = 0.5},
			right = {left = 1.0, width = -0.5}
		}
	}

	local function SetTextureCoords(object, type, subtype)
		local coords = COORDS[type] and COORDS[type][subtype]
		if not coords then return end

		local left = coords.left
		local right = left + coords.width
		local bottom = coords.height or 1

		object:SetTexCoord(left, right, 0, bottom)
	end

	local function DrawVerticalLine(list, parent, offset, base_row, base_column, row, column)
		if column ~= base_column then
			return false
		end
		for i = row + 1, base_row - 1 do
			local x, y = offset(i, column)
			local branch = Talented:MakeBranch(parent)
			branch:SetPoint("TOPLEFT", x + 2, y + 32)
			list[#list + 1] = branch
			SetTextureCoords(branch, "branch", "top")
			branch = Talented:MakeBranch(parent)
			branch:SetPoint("TOPLEFT", x + 2, y)
			list[#list + 1] = branch
			SetTextureCoords(branch, "branch", "top")
		end
		local x, y = offset(base_row, base_column)
		local branch = Talented:MakeBranch(parent)
		branch:SetPoint("TOPLEFT", x + 2, y + 32)
		list[#list + 1] = branch
		SetTextureCoords(branch, "branch", "top")
		local arrow = Talented:MakeArrow(parent)
		SetTextureCoords(arrow, "arrow", "top")
		arrow:SetPoint("TOPLEFT", x + 2, y + 16)
		list[#list + 1] = arrow

		return true
	end

	local function DrawHorizontalLine(list, parent, offset, base_row, base_column, row, column)
		if row ~= base_row then
			return false
		end
		for i = min(base_column, column) + 1, max(base_column, column) - 1 do
			local x, y = offset(row, i)
			local branch = Talented:MakeBranch(parent)
			branch:SetPoint("TOPLEFT", x - 32, y - 2)
			list[#list + 1] = branch
			SetTextureCoords(branch, "branch", "left")
			branch = Talented:MakeBranch(parent)
			branch:SetPoint("TOPLEFT", x, y - 2)
			list[#list + 1] = branch
			SetTextureCoords(branch, "branch", "left")
		end
		local x, y = offset(base_row, base_column)
		local branch = Talented:MakeBranch(parent)
		list[#list + 1] = branch
		SetTextureCoords(branch, "branch", "left")
		local arrow = Talented:MakeArrow(parent)
		if base_column < column then
			SetTextureCoords(arrow, "arrow", "right")
			arrow:SetPoint("TOPLEFT", x + 20, y - 2)
			branch:SetPoint("TOPLEFT", x + 32, y - 2)
		else
			SetTextureCoords(arrow, "arrow", "left")
			arrow:SetPoint("TOPLEFT", x - 15, y - 2)
			branch:SetPoint("TOPLEFT", x - 32, y - 2)
		end
		list[#list + 1] = arrow
		return true
	end

	local function DrawHorizontalVerticalLine(list, parent, offset, base_row, base_column, row, column)
		local min_row, max_row, min_column, max_column
		--[[
			FIXME : I need to check if this line is possible and return false if not.
			Note that for the current trees, it's never impossible.
		]]
		if base_column < column then
			min_column = base_column + 1
			max_column = column - 1
		else
			min_column = column + 1
			max_column = base_column - 1
		end

		for i = min_column, max_column do
			local x, y = offset(row, i)
			local branch = Talented:MakeBranch(parent)
			branch:SetPoint("TOPLEFT", x - 32, y - 2)
			list[#list + 1] = branch
			SetTextureCoords(branch, "branch", "left")
			branch = Talented:MakeBranch(parent)
			branch:SetPoint("TOPLEFT", x, y - 2)
			list[#list + 1] = branch
			SetTextureCoords(branch, "branch", "left")
		end

		local x, y = offset(row, base_column)
		local branch = Talented:MakeBranch(parent)
		branch:SetPoint("TOPLEFT", x + 2, y - 2)
		list[#list + 1] = branch
		local branch2 = Talented:MakeBranch(parent)
		SetTextureCoords(branch2, "branch", "left")
		list[#list + 1] = branch2
		if base_column < column then
			branch2:SetPoint("TOPLEFT", x + 35, y - 2)
			SetTextureCoords(branch, "branch", "topleft")
		else
			branch2:SetPoint("TOPLEFT", x - 29, y - 2)
			SetTextureCoords(branch, "branch", "topright")
		end

		for i = row + 1, base_row - 1 do
			local xofs, yofs = offset(i, base_column)
			local b = Talented:MakeBranch(parent)
			b:SetPoint("TOPLEFT", xofs + 2, yofs + 32)
			list[#list + 1] = b
			SetTextureCoords(b, "branch", "top")
			b = Talented:MakeBranch(parent)
			b:SetPoint("TOPLEFT", xofs + 2, yofs)
			list[#list + 1] = b
			SetTextureCoords(b, "branch", "top")
		end

		x, y = offset(base_row, base_column)
		branch = Talented:MakeBranch(parent)
		branch:SetPoint("TOPLEFT", x + 2, y + 32)
		list[#list + 1] = branch
		SetTextureCoords(branch, "branch", "top")
		local arrow = Talented:MakeArrow(parent)
		SetTextureCoords(arrow, "arrow", "top")
		arrow:SetPoint("TOPLEFT", x + 2, y + 16)
		list[#list + 1] = arrow

		return true
	end

	local function DrawVerticalHorizontalLine(list, parent, offset, base_row, base_column, row, column)
		--[[
			FIXME : I need to check if this line is possible and return false if not.
			Note that it should never be impossible.
			Also, I need to really implement it.
		]]
		return true
	end

	function Talented.DrawLine(...)
		return DrawVerticalLine(...) or DrawHorizontalLine(...) or DrawHorizontalVerticalLine(...) or DrawVerticalHorizontalLine(...)
	end
end

-------------------------------------------------------------------------------
-- ui\menu.lua
--

do
	local classNames = {}
	FillLocalizedClassList(classNames, false)
	classNames["Ferocity"] = Talented.tabdata["Ferocity"][1].name
	classNames["Tenacity"] = Talented.tabdata["Tenacity"][1].name
	classNames["Cunning"] = Talented.tabdata["Cunning"][1].name

	local menuColorCodes = {}
	local function fill_menuColorCodes()
		for name, default in pairs(RAID_CLASS_COLORS) do
			local color = CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[name] or default
			menuColorCodes[name] = string.format("|cff%2x%2x%2x", color.r * 255, color.g * 255, color.b * 255)
		end
		menuColorCodes["Ferocity"] = "|cffe0a040"
		menuColorCodes["Tenacity"] = "|cffe0a040"
		menuColorCodes["Cunning"] = "|cffe0a040"
	end
	fill_menuColorCodes()

	if CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS.RegisterCallback then
		CUSTOM_CLASS_COLORS:RegisterCallback(fill_menuColorCodes)
	end

	function Talented:OpenOptionsFrame()
		LibStub("AceConfigDialog-3.0"):Open("Talented")
	end

	function Talented:GetNamedMenu(name)
		local menus = self.menus
		if not menus then
			menus = {}
			self.menus = menus
		end
		local menu = menus[name]
		if not menu then
			menu = {}
			menus[name] = menu
		end
		return menu
	end

	local function Menu_SetTemplate(entry, template)
		if IsShiftKeyDown() then
			local frame = Talented:MakeAlternateView()
			frame.view:SetTemplate(template)
			frame.view:SetViewMode "view"
			frame:Show()
		else
			Talented:OpenTemplate(template)
		end
		Talented:CloseMenu()
	end

	local function Menu_IsTemplatePlayerClass()
		return Talented.template.class == select(2, UnitClass("player"))
	end

	local function Menu_NewTemplate(entry, class)
		Talented:OpenTemplate(Talented:CreateEmptyTemplate(class))
		Talented:CloseMenu()
	end

	function Talented:CreateTemplateMenu()
		local menu = self:GetNamedMenu("Template")

		local entry = self:GetNamedMenu("primary")
		entry.text = TALENT_SPEC_PRIMARY
		entry.func = Menu_SetTemplate
		menu[#menu + 1] = entry

		entry = self:GetNamedMenu("secondary")
		entry.text = TALENT_SPEC_SECONDARY
		entry.disabled = true
		entry.func = Menu_SetTemplate
		menu[#menu + 1] = entry

		if select(2, UnitClass "player") == "HUNTER" then
			entry = self:GetNamedMenu("petcurrent")
			entry.text = L["View Pet Spec"]
			entry.disabled = true
			entry.func = function()
				Talented:PET_TALENT_UPDATE()
				Talented:OpenTemplate(Talented.pet_current)
				Talented:CloseMenu()
			end
			menu[#menu + 1] = entry
		end

		entry = self:GetNamedMenu("separator")
		if not entry.text then
			entry.text = ""
			entry.disabled = true
			entry.separator = true
		end
		menu[#menu + 1] = entry

		local list = {}
		for index, name in ipairs(CLASS_SORT_ORDER) do
			list[index] = name
		end
		list[#list + 1] = "Ferocity"
		list[#list + 1] = "Tenacity"
		list[#list + 1] = "Cunning"

		for _, name in ipairs(list) do
			entry = self:GetNamedMenu(name)
			entry.text = classNames[name]
			entry.colorCode = menuColorCodes[name]
			entry.hasArrow = true
			entry.menuList = self:GetNamedMenu(name .. "List")
			menu[#menu + 1] = entry
		end

		menu[#menu + 1] = self:GetNamedMenu("separator")

		entry = self:GetNamedMenu("Inspected")
		entry.text = L["Inspected Characters"]
		entry.hasArrow = true
		entry.menuList = self:GetNamedMenu("InspectedList")
		menu[#menu + 1] = entry

		self.CreateTemplateMenu = function(self)
			return self:GetNamedMenu("Template")
		end
		return menu
	end

	local function Sort_Template_Menu_Entry(a, b)
		a, b = a.text, b.text
		if not a then
			return false
		end
		if not b then
			return true
		end
		return a < b
	end

	local function update_template_entry(entry, name, template)
		local points = template.points
		if not points then
			points = Talented:GetTemplateInfo(template)
			template.points = points
		end
		entry.text = name .. points
	end

	function Talented:MakeTemplateMenu()
		local menu = self:CreateTemplateMenu()

		for class, color in pairs(menuColorCodes) do
			local menuList = self:GetNamedMenu(class .. "List")
			local index = 1
			for name, template in pairs(self.db.global.templates) do
				if template.class == class then
					local entry = menuList[index]
					if not entry then
						entry = {}
						menuList[index] = entry
					end
					index = index + 1
					update_template_entry(entry, name, template)
					entry.func = Menu_SetTemplate
					entry.checked = (self.template == template)
					entry.arg1 = template
					entry.colorCode = color
				end
			end
			for i = index, #menuList do
				menuList[i].text = nil
			end
			table.sort(menuList, Sort_Template_Menu_Entry)
			local mnu = self:GetNamedMenu(class)
			mnu.text = classNames[class]
			if index == 1 then
				mnu.disabled = true
			else
				mnu.disabled = nil
				mnu.colorCode = color
			end
		end

		if not self.inspections then
			self:GetNamedMenu("Inspected").disabled = true
		else
			self:GetNamedMenu("Inspected").disabled = nil
			local menuList = self:GetNamedMenu("InspectedList")
			local index = 1
			for name, template in pairs(self.inspections) do
				local entry = menuList[index]
				if not entry then
					entry = {}
					menuList[index] = entry
				end
				index = index + 1
				update_template_entry(entry, name, template)
				entry.func = Menu_SetTemplate
				entry.checked = (self.template == template)
				entry.arg1 = template
				entry.colorCode = menuColorCodes[template.class]
			end
			table.sort(menuList, Sort_Template_Menu_Entry)
		end
		local talentGroup = GetActiveTalentGroup()
		local entry = self:GetNamedMenu("primary")
		local current = self.alternates[1]
		update_template_entry(entry, TALENT_SPEC_PRIMARY, current)
		entry.arg1 = current
		entry.checked = (self.template == current)
		if #self.alternates > 1 then
			local alt = self.alternates[2]
			local e = self:GetNamedMenu("secondary")
			e.disabled = false
			update_template_entry(e, TALENT_SPEC_SECONDARY, alt)
			e.arg1 = alt
			e.checked = (self.template == alt)
		end

		entry = self.menus.petcurrent
		if entry then
			entry.disabled = not self.pet_current
			entry.checked = (self.template == self.pet_current)
		end

		return menu
	end

	StaticPopupDialogs["TALENTED_IMPORT_URL"] = {
		text = L["Enter the complete URL of a template from Blizzard talent calculator or wowhead."],
		button1 = ACCEPT,
		button2 = CANCEL,
		hasEditBox = 1,
		hasWideEditBox = 1,
		maxLetters = 256,
		whileDead = 1,
		OnShow = function(self)
			self.wideEditBox:SetText ""
		end,
		OnAccept = function(self)
			local url = self.wideEditBox:GetText()
			self:Hide()
			local template = Talented:ImportTemplate(url)
			if template then
				Talented:OpenTemplate(template)
			end
		end,
		timeout = 0,
		EditBoxOnEnterPressed = function(self)
			local parent = self:GetParent()
			StaticPopupDialogs[parent.which].OnAccept(parent)
		end,
		EditBoxOnEscapePressed = function(self)
			self:GetParent():Hide()
		end,
		hideOnEscape = 1
	}

	StaticPopupDialogs["TALENTED_EXPORT_TO"] = {
		text = L["Enter the name of the character you want to send the template to."],
		button1 = ACCEPT,
		button2 = CANCEL,
		hasEditBox = 1,
		maxLetters = 256,
		whileDead = 1,
		autoCompleteParams = AUTOCOMPLETE_LIST.WHISPER,
		OnAccept = function(self)
			local name = self.editBox:GetText()
			self:Hide()
			Talented:ExportTemplateToUser(name)
		end,
		timeout = 0,
		EditBoxOnEnterPressed = StaticPopupDialogs.TALENTED_IMPORT_URL.EditBoxOnEnterPressed,
		EditBoxOnEscapePressed = StaticPopupDialogs.TALENTED_IMPORT_URL.EditBoxOnEscapePressed,
		hideOnEscape = 1
	}

	function Talented:CreateActionMenu()
		local menu = self:GetNamedMenu("Action")

		local menuList = self:GetNamedMenu("NewTemplates")

		local list = {}
		for index, name in ipairs(CLASS_SORT_ORDER) do
			list[index] = name
		end
		list[#list + 1] = "Ferocity"
		list[#list + 1] = "Tenacity"
		list[#list + 1] = "Cunning"

		for _, name in ipairs(list) do
			local s = {
				text = classNames[name],
				colorCode = menuColorCodes[name],
				func = Menu_NewTemplate,
				arg1 = name
			}
			menuList[#menuList + 1] = s
		end

		menu[#menu + 1] = {
			text = L["New Template"],
			hasArrow = true,
			menuList = menuList
		}
		local entry = self:GetNamedMenu("separator")
		if not entry.text then
			entry.text = ""
			entry.disabled = true
			entry.separator = true
		end
		menu[#menu + 1] = entry

		entry = self:GetNamedMenu("Apply")
		entry.text = L["Apply template"]
		entry.func = function()
			Talented:SetMode("apply")
		end
		menu[#menu + 1] = entry

		entry = self:GetNamedMenu("SwitchTalentGroup")
		entry.text = L["Switch to this Spec"]
		entry.func = function(entry, talentGroup)
			SetActiveTalentGroup(talentGroup)
		end
		menu[#menu + 1] = entry

		entry = self:GetNamedMenu("Delete")
		entry.text = L["Delete template"]
		entry.func = function()
			Talented:DeleteCurrentTemplate()
		end
		menu[#menu + 1] = entry

		entry = self:GetNamedMenu("Copy")
		entry.text = L["Copy template"]
		entry.func = function()
			Talented:OpenTemplate(Talented:CopyTemplate(Talented.template))
		end
		menu[#menu + 1] = entry

		entry = self:GetNamedMenu("Target")
		entry.text = L["Set as target"]
		entry.func = function(entry, targetName, name)
			if entry.checked then
				Talented.db.char.targets[targetName] = nil
			else
				Talented.db.char.targets[targetName] = name
				if not name then
					Talented.base.view:ClearTarget()
				end
			end
		end
		entry.arg2 = self.template.name
		menu[#menu + 1] = entry

		menu[#menu + 1] = self:GetNamedMenu("separator")
		menu[#menu + 1] = {
			text = L["Import template ..."],
			func = function()
				StaticPopup_Show "TALENTED_IMPORT_URL"
			end
		}

		menu[#menu + 1] = {
			text = L["Export template"],
			hasArrow = true,
			menuList = self:GetNamedMenu("exporters")
		}

		menu[#menu + 1] = {
			text = L["Send to ..."],
			func = function()
				StaticPopup_Show "TALENTED_EXPORT_TO"
			end
		}

		menu[#menu + 1] = {
			text = L["Options ..."],
			func = function()
				Talented:OpenOptionsFrame()
			end
		}

		self.CreateActionMenu = function(self)
			return self:GetNamedMenu("Action")
		end
		return menu
	end

	local function Export_Template(entry, handler)
		local url = handler(Talented, Talented.template)
		if url then
			if Talented.db.profile.show_url_in_chat then
				Talented:WriteToChat(url)
			else
				Talented:ShowInDialog(url)
			end
		end
	end

	function Talented:MakeActionMenu()
		local menu = self:CreateActionMenu()
		local templateTalentGroup, activeTalentGroup = self.template.talentGroup, GetActiveTalentGroup()
		local restricted = (self.template.class ~= select(2, UnitClass("player")))
		local pet_restricted = not self.GetPetClass or self:GetPetClass() ~= self.template.class
		local targetName
		if not restricted then
			targetName = templateTalentGroup or activeTalentGroup
		elseif not pet_restricted then
			targetName = UnitName "PET"
		end

		self:GetNamedMenu("Apply").disabled = templateTalentGroup or restricted and pet_restricted
		self:GetNamedMenu("Delete").disabled = templateTalentGroup or not self.db.global.templates[self.template.name]
		local switch = self:GetNamedMenu("SwitchTalentGroup")
		switch.disabled = (restricted or not templateTalentGroup or templateTalentGroup == activeTalentGroup)
		switch.arg1 = templateTalentGroup

		local target = self:GetNamedMenu("Target")
		if templateTalentGroup then
			target.text = L["Clear target"]
			target.arg1 = targetName
			target.arg2 = nil
			target.disabled = not self.db.char.targets[targetName]
			target.checked = nil
		else
			target.text = L["Set as target"]
			target.arg1 = targetName
			target.arg2 = self.template.name
			target.disabled = not targetName

			target.checked = (self.db.char.targets[targetName] == self.template.name)
		end

		for _, entry in ipairs(self:GetNamedMenu("NewTemplates")) do
			local class = entry.arg1
			entry.colorCode = menuColorCodes[class]
		end

		local exporters = self:GetNamedMenu("exporters")
		local index = 1
		for name, handler in pairs(self.exporters) do
			exporters[index] = exporters[index] or {}
			exporters[index].text = name
			exporters[index].func = Export_Template
			exporters[index].arg1 = handler
			index = index + 1
		end
		for i = index, #exporters do
			exporters[i].text = nil
		end

		return menu
	end

	function Talented:CloseMenu()
		HideDropDownMenu(1)
	end

	function Talented:GetDropdownFrame(frame)
		local dropdown = CreateFrame("Frame", "TalentedDropDown", nil, "UIDropDownMenuTemplate")
		dropdown.point = "TOPLEFT"
		dropdown.relativePoint = "BOTTOMLEFT"
		dropdown.displayMode = "MENU"
		dropdown.xOffset = 2
		dropdown.yOffset = 2
		dropdown.relativeTo = frame
		self.dropdown = dropdown
		self.GetDropdownFrame = function(self, frame)
			local dropdown = self.dropdown
			dropdown.relativeTo = frame
			return dropdown
		end
		return dropdown
	end

	function Talented:OpenTemplateMenu(frame)
		EasyMenu(self:MakeTemplateMenu(), self:GetDropdownFrame(frame))
	end

	function Talented:OpenActionMenu(frame)
		EasyMenu(self:MakeActionMenu(), self:GetDropdownFrame(frame))
	end

	function Talented:OpenLockMenu(frame, parent)
		local menu = self:GetNamedMenu("LockFrame")
		local entry = menu[1]
		if not entry then
			entry = {
				text = L["Lock frame"],
				func = function(entry, frame)
					Talented:SetFrameLock(frame, not entry.checked)
				end
			}
			menu[1] = entry
		end
		entry.arg1 = parent
		entry.checked = self:GetFrameLock(parent)
		EasyMenu(menu, self:GetDropdownFrame(frame))
	end
end

-------------------------------------------------------------------------------
-- ui\spectabs.lua
--

do
	local specs = {
		["spec1"] = {
			talentGroup = 1,
			tooltip = TALENT_SPEC_PRIMARY,
			cache = {}
		},
		["spec2"] = {
			talentGroup = 2,
			tooltip = TALENT_SPEC_SECONDARY,
			cache = {}
		},
		["petspec1"] = {
			pet = true,
			tooltip = TALENT_SPEC_PET_PRIMARY,
			cache = {}
		}
	}

	local function UpdateSpecInfo(info)
		local pet, talentGroup = info.pet, info.talentGroup
		local tabs = GetNumTalentTabs(nil, pet)
		if tabs == 0 then return end

		local imax, min, max, total = 0, 0, 0, 0
		for i = 1, tabs do
			local cache = info.cache[i]
			if not cache then
				cache = {}
				info.cache[i] = cache
			end
			local name, icon, points = GetTalentTabInfo(i, nil, pet, talentGroup)
			cache.name, cache.icon, cache.points = name, icon, points
			if points < min then
				min = points
			end
			if points > max then
				imax, max = i, points
			end
			total = total + points
		end
		info.primary = nil
		if tabs > 2 then
			local middle = total - min - max
			if 3 * (middle - min) < 2 * (max - min) then
				info.primary = imax
			end
		end
		return info
	end

	local function TabFrame_OnEnter(self)
		local info = specs[self.type]
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(info.tooltip)
		for index, cache in ipairs(info.cache) do
			local color = info.primary == index and GREEN_FONT_COLOR or HIGHLIGHT_FONT_COLOR
			GameTooltip:AddDoubleLine(cache.name, cache.points, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b, color.r, color.g, color.b, 1)
		end
		if not info.pet and not self:GetChecked() then
			GameTooltip:AddLine(L["Right-click to activate this spec"], GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b, 1)
		end
		GameTooltip:Show()
	end

	local function TabFrame_OnLeave(self)
		GameTooltip:Hide()
	end

	local function Tabs_UpdateCheck(self, template)
		if not template or not Talented.alternates then return end
		self.petspec1:SetChecked(template == Talented.pet_current)
		self.spec1:SetChecked(template == Talented.alternates[1])
		self.spec2:SetChecked(template == Talented.alternates[2])
	end

	local function TabFrame_OnClick(self, button)
		local info = specs[self.type]
		if button == "RightButton" then
			if not info.pet and not InCombatLockdown() then
				SetActiveTalentGroup(info.talentGroup)
				Tabs_UpdateCheck(self:GetParent(), Talented.alternates[info.talentGroup])
			end
		else
			local template
			if info.pet then
				template = Talented.pet_current
			else
				template = Talented.alternates[info.talentGroup]
			end
			if template then
				Talented:OpenTemplate(template)
			end
			Tabs_UpdateCheck(self:GetParent(), template)
		end
	end

	local function TabFrame_Update(self)
		local info = UpdateSpecInfo(specs[self.type])
		if info then
			self.texture:SetTexture(info.cache[info.primary or 1].icon)
		end
	end

	local function MakeTab(parent, type)
		local tab = CreateFrame("CheckButton", nil, parent)
		tab:SetSize(32, 32)
		local t = tab:CreateTexture(nil, "BACKGROUND")
		t:SetTexture "Interface\\SpellBook\\SpellBook-SkillLineTab"
		t:SetSize(64, 64)
		t:SetPoint("TOPLEFT", -3, 11)

		t = tab:CreateTexture()
		t:SetTexture "Interface\\Buttons\\ButtonHilight-Square"
		t:SetBlendMode "ADD"
		t:SetAllPoints()
		tab:SetHighlightTexture(t)
		t = tab:CreateTexture()
		t:SetTexture "Interface\\Buttons\\CheckButtonHilight"
		t:SetBlendMode "ADD"
		t:SetAllPoints()
		tab:SetCheckedTexture(t)
		t = tab:CreateTexture()
		t:SetAllPoints()
		tab:SetNormalTexture(t)
		tab.texture = t

		tab.type = type
		tab.Update = TabFrame_Update

		tab:SetScript("OnEnter", TabFrame_OnEnter)
		tab:SetScript("OnLeave", TabFrame_OnLeave)

		tab:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		tab:SetScript("OnClick", TabFrame_OnClick)

		return tab
	end

	local function Tabs_Update(self)
		local anchor = self.spec1
		anchor:SetPoint "TOPLEFT"
		anchor:Update()

		if GetNumTalentGroups() > 1 then
			local spec2 = self.spec2
			spec2:Show()
			spec2:SetPoint("TOP", anchor, "BOTTOM", 0, -20)
			spec2:Update()
			anchor = spec2
		else
			self.spec2:Hide()
		end
		-- local _, pet = HasPetUI()
		local pet = UnitExists "pet"
		if pet then
			local petspec1 = self.petspec1
			petspec1:Show()
			petspec1:Update()
			petspec1:SetPoint("TOP", anchor, "BOTTOM", 0, -20)
		else
			self.petspec1:Hide()
		end
	end

	local function Tabs_OnEvent(self, event, ...)
		if event ~= "UNIT_PET" or (...) == "player" then
			Tabs_Update(self)
		end
	end

	local function MakeTabs(parent)
		local f = CreateFrame("Frame", nil, parent)

		f.spec1 = MakeTab(f, "spec1")
		f.spec2 = MakeTab(f, "spec2")
		f.petspec1 = MakeTab(f, "petspec1")

		f:SetPoint("TOPLEFT", parent, "TOPRIGHT", -2, -40)
		f:SetSize(32, 150)

		f:SetScript("OnEvent", Tabs_OnEvent)

		f:RegisterEvent("UNIT_PET")
		f:RegisterEvent("PLAYER_LEVEL_UP")
		f:RegisterEvent("PLAYER_TALENT_UPDATE")
		f:RegisterEvent("PET_TALENT_UPDATE")
		f:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")

		f.Update = Tabs_Update
		f.UpdateCheck = Tabs_UpdateCheck
		Talented.tabs = f
		f:Update()

		local baseView = parent.view
		local prev = baseView.SetTemplate
		baseView.SetTemplate = function(self, template, ...)
			Talented.tabs:UpdateCheck(template)
			return prev(self, template, ...)
		end
		f:UpdateCheck(baseView.template)
		MakeTabs = nil
		return f
	end

	if Talented.base then
		MakeTabs(Talented.base)
	else
		local prev = Talented.CreateBaseFrame
		Talented.CreateBaseFrame = function(self)
			local base = prev(self)
			MakeTabs(base)
			return base
		end
	end
end