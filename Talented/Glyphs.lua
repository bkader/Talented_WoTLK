local _G = _G
local Talented = _G.Talented
local L = LibStub("AceLocale-3.0"):GetLocale("Talented")

local Talented_CreateGlyphFrame
local Talented_MakeGlyph

do
	local SLOT_COORD_BASE = {0, 0.130859375, 0.392578125, 0.5234375, 0.26171875, 0.654296875}

	local function Glyph_StartAnimation(self)
		local sparkle = self.sparkle
		local enabled, _, spell = GetGlyphSocketInfo(self.id, self:GetParent().group)
		if enabled and spell then
			sparkle:Show()
			sparkle.anim:Play()
		else
			sparkle:Hide()
			sparkle.anim:Stop()
		end
	end

	local function Glyph_StopAnimation(self)
		local sparkle = self.sparkle
		sparkle:Hide()
		sparkle.anim:Stop()
	end

	local function Glyph_OnEnter(self)
		local id, group = self.id, self:GetParent().group
		if GetGlyphSocketInfo(id, group) then
			self.highlight:Show()
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetGlyph(id, group)
		GameTooltip:Show()
		self.hasCursor = true
	end

	local function Glyph_OnLeave(self)
		self.highlight:Hide()
		if GameTooltip:IsOwned(self) then
			GameTooltip:Hide()
		end
		self.hasCursor = nil
	end

	local function Glyph_Update(self)
		local id, group = self.id, self:GetParent().group
		local enabled, gtype, spell, icon = GetGlyphSocketInfo(id, group)

		self.highlight:Hide()
		if not enabled then
			self.setting:SetTexture("Interface\\Spellbook\\UI-GlyphFrame-Locked")
			self.setting:SetTexCoord(.1, .9, .1, .9)
			self.background:Hide()
			self.glyph:Hide()
			self.ring:Hide()
			self.shine:Hide()
		else
			self.setting:SetTexture("Interface\\Spellbook\\UI-GlyphFrame")
			self.shine:Show()
			self.background:Show()
			self.ring:Show()

			if gtype == 2 then -- minor
				self.setting:SetSize(86, 86)
				self.setting:SetTexCoord(0.765625, 0.927734375, 0.15625, 0.31640625)

				self.highlight:SetSize(86, 86)
				self.highlight:SetTexCoord(0.765625, 0.927734375, 0.15625, 0.31640625)

				self.background:SetSize(64, 64)

				self.glyph:SetVertexColor(0, 0.25, 1)

				self.ring:SetSize(62, 62)
				self.ring:SetPoint("CENTER", self, 0, 1)
				self.ring:SetTexCoord(0.787109375, 0.908203125, 0.033203125, 0.154296875)

				self.shine:SetTexCoord(0.9609375, 1, 0.921875, 0.9609375)
			else
				self.setting:SetSize(108, 108)
				self.setting:SetTexCoord(0.740234375, 0.953125, 0.484375, 0.697265625)

				self.highlight:SetSize(108, 108)
				self.highlight:SetTexCoord(0.740234375, 0.953125, 0.484375, 0.697265625)

				self.background:SetSize(70, 70)

				self.glyph:SetVertexColor(1, 0.25, 0)

				self.ring:SetSize(82, 82)
				self.ring:SetPoint("CENTER", self, 0, -1)
				self.ring:SetTexCoord(0.767578125, 0.92578125, 0.32421875, 0.482421875)

				self.shine:SetTexCoord(0.9609375, 1, 0.9609375, 1)
			end
			if not spell then
				self.glyph:Hide()
				self.background:SetTexCoord(0.78125, 0.91015625, 0.69921875, 0.828125)
				if not GlyphMatchesSocket(id) then
					self.background:SetAlpha(1)
				end
			else
				self.glyph:Show()
				self.glyph:SetTexture(icon or "Interface\\Spellbook\\UI-Glyph-Rune1")
				local left = SLOT_COORD_BASE[id]
				self.background:SetTexCoord(left, left + 0.12890625, 0.87109375, 1)
				self.background:SetAlpha(1)
			end
		end

		self.elapsed = 0
		self.tintElapsed = 0
		self:StartAnimation()

		if GameTooltip:IsOwned(self) then
			Glyph_OnEnter(self)
		end
	end

	local ChatEdit_GetActiveWindow = ChatEdit_GetActiveWindow
	if not ChatEdit_GetActiveWindow then
		ChatEdit_GetActiveWindow = function()
			return _G.ChatFrameEditBox:IsVisible()
		end
	end

	local function Glyph_OnClick(self, button)
		local id, group = self.id, self:GetParent().group

		if IsModifiedClick("CHATLINK") and ChatEdit_GetActiveWindow() then
			local link = GetGlyphLink(id, group)
			if link then
				ChatEdit_InsertLink(link)
			end
		else
			if group ~= GetActiveTalentGroup() then
				return
			end
			if button == "RightButton" then
				if IsShiftKeyDown() then
					local _, _, spell = GetGlyphSocketInfo(id)
					if spell then
						StaticPopup_Show("CONFIRM_REMOVE_GLYPH", GetSpellInfo(spell)).data = id
					end
				end
			elseif self.glyph:IsShown() and GlyphMatchesSocket(id) then
				StaticPopup_Show("CONFIRM_GLYPH_PLACEMENT").data = id
			else
				PlaceGlyphInSocket(id)
			end
		end
	end

	local function Glyph_OnUpdate(self, elapsed)
		local id, group = self.id, self:GetParent().group
		local enabled, _, spell = GetGlyphSocketInfo(id, group)

		spell = enabled and spell
		enabled = enabled and GlyphMatchesSocket(id)

		local alpha = 0.6
		if spell or (self.elapsed or 0) > 0 then
			elapsed = (self.elapsed or 0) + elapsed
			if elapsed >= 6 then
				elapsed = 0
			elseif elapsed <= 2 then
				alpha = 0.6 + 0.2 * elapsed
			elseif elapsed < 4 then
				alpha = 1
			elseif elapsed >= 4 then
				alpha = 1.8 - 0.2 * elapsed
			end
			self.elapsed = elapsed
		end
		self.setting:SetAlpha(alpha)

		if not spell and enabled then
			local tintElapsed = self.tintElapsed + elapsed

			local left = SLOT_COORD_BASE[id]
			self.background:SetTexCoord(left, left + 0.12890625, 0.87109375, 1)

			self.highlight:Show()

			alpha = 1
			if elapsed >= 1.4 then
				tintElapsed = 0
			elseif elapsed <= 0.6 then
				alpha = 1 - elapsed
			elseif elapsed >= 0.8 then
				alpha = elapsed - 0.4
			end

			self.background:SetAlpha(alpha)
			if self.hasCursor then
				self.highlight:SetAlpha(.4 * alpha)
			else
				self.highlight:SetAlpha(.4)
			end
			self.tintElapsed = tintElapsed
		elseif not spell then
			self.background:SetTexCoord(0.78125, 0.91015625, 0.69921875, 0.828125)
			self.background:SetAlpha(1)
			self.highlight:SetAlpha(.4)
		end

		if self.hasCursor and SpellIsTargeting() then
			SetCursor(enabled and "CAST_CURSOR" or "CAST_ERROR_CURSOR")
		end
	end

	function Talented_MakeGlyph(parent, id)
		local glyph = CreateFrame("Button", nil, parent)
		glyph.id = id

		-- GlyphTemplate
		glyph:SetSize(72, 72)

		local setting = glyph:CreateTexture(nil, "BACKGROUND")
		setting:SetTexture("Interface\\Spellbook\\UI-GlyphFrame")
		setting:SetPoint("CENTER")
		glyph.setting = setting

		local highlight = glyph:CreateTexture(nil, "BORDER")
		highlight:SetTexture("Interface\\Spellbook\\UI-GlyphFrame")
		highlight:SetPoint("CENTER")
		highlight:SetVertexColor(1, 1, 1, .25)
		glyph.highlight = highlight

		local background = glyph:CreateTexture(nil, "BORDER")
		background:SetTexture("Interface\\Spellbook\\UI-GlyphFrame")
		background:SetPoint("CENTER")
		glyph.background = background

		local texture = glyph:CreateTexture(nil, "ARTWORK")
		texture:SetSize(53, 53)
		texture:SetPoint("CENTER")
		glyph.glyph = texture

		local ring = glyph:CreateTexture(nil, "OVERLAY")
		ring:SetTexture("Interface\\Spellbook\\UI-GlyphFrame")
		glyph.ring = ring

		local shine = glyph:CreateTexture(nil, "OVERLAY")
		shine:SetTexture("Interface\\Spellbook\\UI-GlyphFrame")
		shine:SetSize(16, 16)
		shine:SetPoint("CENTER", -9, 12)
		glyph.shine = shine

		glyph.Update = Glyph_Update
		glyph.StartAnimation = Glyph_StartAnimation
		glyph.StopAnimation = Glyph_StopAnimation
		glyph:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		glyph:SetScript("OnClick", Glyph_OnClick)
		glyph:SetScript("OnEnter", Glyph_OnEnter)
		glyph:SetScript("OnLeave", Glyph_OnLeave)
		glyph:SetScript("OnUpdate", Glyph_OnUpdate)

		return glyph
	end
end

-------------------------------------------------------------------------------

do
	local GLYPH_POSITIONS = {
		{"CENTER", -15, 140, -13, 17, 0, 83},
		{"CENTER", -14, -113, -13, 17, 0, -83},
		{"TOPLEFT", 28, -133, -13, 17, -72, 43},
		{"BOTTOMRIGHT", -66, 178, -13, 18, 74, -45},
		{"TOPRIGHT", -56, -133, -13, 17, 72, 43},
		{"BOTTOMLEFT", 40, 178, -13, 18, -74, -45}
	}

	local SPARKLE_DIMENSIONS = {7, 10, 13}
	local SPARKLE_DURATIONS = {1.25, 3, 5.4}
	local function Sparkle_Update(self)
		local sparkle = self:GetRegionParent()
		local index = math.random(#SPARKLE_DIMENSIONS)
		local size = SPARKLE_DIMENSIONS[index]
		sparkle:SetSize(size, size)
		self:SetDuration(SPARKLE_DURATIONS[index])
	end

	local function MakeSparkleAnimation(parent, x, y, dx, dy)
		local sparkle = parent:CreateTexture(nil, "ARTWORK")
		sparkle:SetTexture("Interface\\ItemSocketingFrame\\UI-ItemSockets")
		sparkle:SetPoint("CENTER", x, y)
		sparkle:SetTexCoord(0.3984375, 0.4453125, 0.40234375, 0.44921875)
		sparkle:SetBlendMode("ADD")
		local animGroup = sparkle:CreateAnimationGroup()
		local translation = animGroup:CreateAnimation("Translation")
		animGroup:SetLooping("REPEAT")
		animGroup.translation = translation
		translation:SetStartDelay(0)
		translation:SetEndDelay(0)
		translation:SetSmoothing("IN_OUT")
		translation:SetOrder(1)
		translation:SetMaxFramerate(30)
		translation:SetOffset(dx, dy)
		translation:SetScript("OnFinished", Sparkle_Update)
		Sparkle_Update(translation)
		sparkle.anim = animGroup
		return sparkle
	end

	local function GlowAnimation_Hide(self)
		self:GetParent():Hide()
	end

	local function GlyphFrame_OnEvent(self, event, ...)
		if event == "GLYPH_ADDED" or event == "GLYPH_UPDATED" or event == "GLYPH_REMOVED" then
			if not self:IsShown() then
				return
			end
			local id = ...
			self.glyphs[id]:Update()
			local _, type = GetGlyphSocketInfo(id, self.group)
			if event == "GLYPH_REMOVED" then
				PlaySound(type == 2 and "Glyph_MinorDestroy" or "Glyph_MajorDestroy")
			else
				PlaySound(type == 2 and "Glyph_MinorCreate" or "Glyph_MajorCreate")
				self:Glow()
			end
			self:UpdateGroup()
		elseif event == "UNIT_PORTRAIT_UPDATE" and (...) == "player" then
			SetPortraitTexture(self.portrait, "player")
		elseif event == "ACTIVE_TALENT_GROUP_CHANGED" then
			local policy = Talented.db.profile.glyph_on_talent_swap
			if policy == "swap" then
				self.group = 3 - self.group
				self:Update()
			elseif policy == "active" then
				self.group = GetActiveTalentGroup()
				self:Update()
			end
		else
			self:Update()
		end
	end

	local function GlyphFrame_OnEnter(self)
		if SpellIsTargeting() then
			SetCursor("CAST_ERROR_CURSOR")
		end
	end

	local function GlyphFrame_OnShow(self)
		PlaySound "igSpellBookOpen"
		self:StartAnimations()
		local b = Talented.base
		if b and b.bglyphs then
			b.bglyphs:SetButtonState("PUSHED", 1)
		end
		SetPortraitTexture(self.portrait, "player")
	end

	local function GlyphFrame_OnHide(self)
		self:StopAnimations()
		local b = Talented.base
		if b and b.bglyphs then
			b.bglyphs:SetButtonState("NORMAL")
		end
	end

	local function GlyphFrame_OnUpdate(self)
		self:StopAnimations()
		self:StartAnimations()
		self:Glow()
		self.glow.anim:Stop()
		self:SetScript("OnUpdate", nil)
	end

	local function GlyphFrame_StartAnimations(self)
		for _, glyph in ipairs(self.glyphs) do
			glyph:StartAnimation()
		end
	end

	local function GlyphFrame_StopAnimations(self)
		for _, glyph in ipairs(self.glyphs) do
			glyph:StopAnimation()
		end
	end

	local function makeTexture(cb, path, blend)
		local t = cb:CreateTexture()
		t:SetTexture(path)
		t:SetAllPoints(cb)
		if blend then
			t:SetBlendMode(blend)
		end
		return t
	end

	function Talented_CreateGlyphFrame()
		if _G.TalentedGlyphs then
			return
		end
		local frame = CreateFrame("Frame", "TalentedGlyphs", UIParent)

		frame:Hide()
		frame:SetFrameStrata("DIALOG")
		frame:SetSize(384, 512)
		frame:EnableMouse(true)
		frame:SetToplevel(true)
		frame:SetHitRectInsets(0, 30, 0, 70)

		local t = frame:CreateTexture(nil, "BORDER")
		t:SetTexture("Interface\\Spellbook\\UI-GlyphFrame")
		t:SetSize(352, 441)
		t:SetPoint("TOPLEFT")
		t:SetTexCoord(0, 0.6875, 0, 0.861328125)
		frame.background = t

		local p = frame:CreateTexture(nil, "BACKGROUND")
		p:SetSize(64, 64)
		p:SetPoint("TOPLEFT", 5, -4)
		frame.portrait = p

		local title = frame:CreateFontString(nil, "ARTWORK")
		title:SetFontObject(GameFontNormal)
		title:SetText(GLYPHS)
		title:SetPoint("TOP", 0, -17)
		frame.title = title

		local glow = frame:CreateTexture(nil, "OVERLAY")
		glow:Hide()
		glow:SetTexture("Interface\\Spellbook\\UI-GlyphFrame-Glow")
		glow:SetBlendMode("ADD")
		glow:SetSize(352, 441)
		glow:SetPoint("TOPLEFT", -9, -38)
		glow:SetTexCoord(0, 0.6875, 0, 0.861328125)
		frame.glow = glow

		local animGroup = glow:CreateAnimationGroup()
		local alpha = animGroup:CreateAnimation("Alpha")
		alpha:SetChange(1)
		alpha:SetDuration(0.1)
		alpha:SetOrder(1)
		alpha = animGroup:CreateAnimation("Alpha")
		alpha:SetChange(-1)
		alpha:SetDuration(1.5)
		alpha:SetOrder(2)
		glow.anim = animGroup

		animGroup:SetScript("OnStop", GlowAnimation_Hide)
		animGroup:SetScript("OnFinished", GlowAnimation_Hide)

		frame:RegisterEvent("GLYPH_ADDED")
		frame:RegisterEvent("GLYPH_REMOVED")
		frame:RegisterEvent("GLYPH_UPDATED")
		frame:RegisterEvent("USE_GLYPH")
		frame:RegisterEvent("PLAYER_LEVEL_UP")
		frame:RegisterEvent("UNIT_PORTRAIT_UPDATE")
		frame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")

		frame:SetScript("OnEvent", GlyphFrame_OnEvent)
		frame:SetScript("OnEnter", GlyphFrame_OnEnter)
		frame:SetScript("OnLeave", function(self) SetCursor(nil) end)
		frame:SetScript("OnShow", GlyphFrame_OnShow)
		frame:SetScript("OnHide", GlyphFrame_OnHide)
		frame:SetScript("OnUpdate", GlyphFrame_OnUpdate)

		frame.Update = function(self)
			if self.group > GetNumTalentGroups() then
				self.group = GetActiveTalentGroup()
			end
			for _, glyph in ipairs(self.glyphs) do
				glyph:Update()
			end
			self:UpdateGroup()
		end

		frame.UpdateGroup = function(self)
			local cb, alt = self.checkbox, GetNumTalentGroups() > 1
			if alt then
				self.title:SetText(self.group ~= 1 and TALENT_SPEC_SECONDARY_GLYPH or TALENT_SPEC_PRIMARY_GLYPH)
				cb:Show()
				local checked = (self.group ~= GetActiveTalentGroup())
				cb:SetChecked(checked)
				SetDesaturation(self.background, checked)
			else
				cb:Hide()
			end
		end

		frame.OnMouseDown = GlyphFrame_StopAnimations
		frame.OnMouseUp = GlyphFrame_StartAnimations
		frame.StartAnimations = GlyphFrame_StartAnimations
		frame.StopAnimations = GlyphFrame_StopAnimations

		frame.Glow = function(self)
			local glow = self.glow
			glow:SetAlpha(0)
			glow:Show()
			glow.anim:Play()
		end

		frame.glyphs = {}
		frame.group = GetActiveTalentGroup()

		for id, position in ipairs(GLYPH_POSITIONS) do
			local glyph = Talented_MakeGlyph(frame, id)
			glyph.sparkle = MakeSparkleAnimation(frame, unpack(position, 4))
			glyph:SetPoint(unpack(position, 1, 3))
			frame.glyphs[id] = glyph
		end

		frame:SetFrameLevel(5)

		local close = Talented:CreateCloseButton(frame)
		frame.close = close
		close:ClearAllPoints()
		close:SetPoint("TOPRIGHT", -28, -9)

		local cb = CreateFrame("Checkbutton", nil, frame)
		frame.checkbox = cb

		cb:SetSize(20, 20)

		local label = cb:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
		label:SetJustifyH("LEFT")
		label:SetSize(400, 20)
		label:SetPoint("LEFT", cb, "RIGHT", 1, 1)
		cb.label = label

		cb:SetNormalTexture(makeTexture(cb, "Interface\\Buttons\\UI-CheckBox-Up"))
		cb:SetPushedTexture(makeTexture(cb, "Interface\\Buttons\\UI-CheckBox-Down"))
		cb:SetDisabledTexture(makeTexture(cb, "Interface\\Buttons\\UI-CheckBox-Check-Disabled"))
		cb:SetCheckedTexture(makeTexture(cb, "Interface\\Buttons\\UI-CheckBox-Check"))
		cb:SetHighlightTexture(makeTexture(cb, "Interface\\Buttons\\UI-CheckBox-Highlight", "ADD"))
		cb:SetScript("OnClick", function(self)
			local talentGroup = GetActiveTalentGroup()
			if self:GetChecked() then
				talentGroup = 3 - talentGroup
			end
			local gframe = self:GetParent()
			gframe.group = talentGroup
			gframe:Update()
		end)
		cb.label:SetText(L["View glyphs of alternate Spec"])
		cb:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 82)
		cb:SetFrameLevel(frame:GetFrameLevel() + 2)

		Talented:LoadFramePosition(frame)
		Talented:SetFrameLock(frame)

		UISpecialFrames[#UISpecialFrames + 1] = "TalentedGlyphs"
	end
end

-------------------------------------------------------------------------------

function Talented:CreateGlyphFrame()
	Talented_CreateGlyphFrame()
	_G.TalentedGlyphs:Update()
end

function Talented:OpenGlyphFrame()
	Talented_CreateGlyphFrame()
	_G.TalentedGlyphs:Update()
	_G.TalentedGlyphs:Show()
end

function Talented:ToggleGlyphFrame()
	if not _G.TalentedGlyphs then
		self:OpenGlyphFrame()
	elseif _G.TalentedGlyphs:IsShown() then
		_G.TalentedGlyphs:Hide()
	else
		_G.TalentedGlyphs:Show()
	end
end

Talented.USE_GLYPH = Talented.OpenGlyphFrame

StaticPopupDialogs["CONFIRM_REMOVE_GLYPH"].OnAccept = function(self)
	if _G.TalentedGlyphs and _G.TalentedGlyphs.group == GetActiveTalentGroup() then
		RemoveGlyphFromSocket(self.data)
	end
end