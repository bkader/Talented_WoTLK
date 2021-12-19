local Talented = LibStub("AceAddon-3.0"):NewAddon("Talented", "AceEvent-3.0", "AceHook-3.0", "AceConsole-3.0", "AceComm-3.0", "AceSerializer-3.0")
_G.Talented = Talented

local L = LibStub("AceLocale-3.0"):GetLocale("Talented")

-------------------------------------------------------------------------------
-- core.lua
--

do
	Talented.prev_Print = Talented.Print
	function Talented:Print(s, ...)
		if type(s) == "string" and s:find("%", nil, true) then
			self:prev_Print(s:format(...))
		else
			self:prev_Print(s, ...)
		end
	end

	function Talented:Debug(...)
		if not self.db or self.db.profile.debug then
			self:Print(...)
		end
	end

	function Talented:MakeTarget(targetName)
		local name = self.db.char.targets[targetName]
		local src = name and self.db.global.templates[name]
		if not src then
			if name then
				self.db.char.targets[targetName] = nil
			end
			return
		end

		local target = self.target
		if not target then
			target = {}
			self.target = target
		end
		self:CopyPackedTemplate(src, target)

		if
			not self:ValidateTemplate(target) or
				(RAID_CLASS_COLORS[target.class] and target.class ~= select(2, UnitClass "player")) or
				(not RAID_CLASS_COLORS[target.class] and (not self.GetPetClass or target.class ~= self:GetPetClass()))
		 then
			self.db.char.targets[targetName] = nil
			return nil
		end
		target.name = name
		return target
	end

	function Talented:GetMode()
		return self.mode
	end

	function Talented:SetMode(mode)
		if self.mode ~= mode then
			self.mode = mode
			if mode == "apply" then
				self:ApplyCurrentTemplate()
			elseif self.base and self.base.view then
				self.base.view:SetViewMode(mode)
			end
		end
		local cb = self.base and self.base.checkbox
		if cb then
			cb:SetChecked(mode == "edit")
		end
	end

	function Talented:OnInitialize()
		self.db = LibStub("AceDB-3.0"):New("TalentedDB", self.defaults)
		self:UpgradeOptions()
		self:LoadTemplates()

		local AceDBOptions = LibStub("AceDBOptions-3.0", true)
		if AceDBOptions then
			self.options.args.profiles = AceDBOptions:GetOptionsTable(self.db)
			self.options.args.profiles.order = 200
		end

		LibStub("AceConfig-3.0"):RegisterOptionsTable("Talented", self.options)
		self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Talented", "Talented")
		self:RegisterChatCommand("talented", "OnChatCommand")

		self:RegisterComm("Talented")
		if self.InitializePet then
			self:InitializePet()
		end
		self.OnInitialize = nil
	end

	function Talented:OnChatCommand(input)
		if not input or input:trim() == "" then
			self:OpenOptionsFrame()
		else
			LibStub("AceConfigCmd-3.0").HandleCommand(self, "talented", "Talented", input)
		end
	end

	function Talented:DeleteCurrentTemplate()
		local template = self.template
		if template.talentGroup then return end
		local templates = self.db.global.templates
		templates[template.name] = nil
		self:SetTemplate()
	end

	function Talented:UpdateTemplateName(template, newname)
		if self.db.global.templates[newname] or template.talentGroup or type(newname) ~= "string" or newname == "" then return end

		local oldname = template.name
		template.name = newname
		local t = self.db.global.templates
		t[newname] = template
		t[oldname] = nil
	end

	do
		local function new(templates, name, class)
			local count = 0
			local template = {name = name, class = class}
			while templates[template.name] do
				count = count + 1
				template.name = format(L["%s (%d)"], name, count)
			end
			templates[template.name] = template
			return template
		end

		local function copy(dst, src)
			dst.class = src.class
			if src.code then
				dst.code = src.code
				return
			else
				for tab, tree in ipairs(Talented:UncompressSpellData(src.class)) do
					local s, d = src[tab], {}
					dst[tab] = d
					for index = 1, #tree do
						d[index] = s[index]
					end
				end
			end
		end

		function Talented:ImportFromOther(name, src)
			if not self:UncompressSpellData(src.class) then
				return
			end

			local dst = new(self.db.global.templates, name, src.class)
			copy(dst, src)
			self:OpenTemplate(dst)
			return dst
		end

		function Talented:CopyTemplate(src)
			local dst = new(self.db.global.templates, format(L["Copy of %s"], src.name), src.class)
			copy(dst, src)
			return dst
		end

		function Talented:CreateEmptyTemplate(class)
			class = class or select(2, UnitClass "player")
			local template = new(self.db.global.templates, L["Empty"], class)

			local info = self:UncompressSpellData(class)

			for tab, tree in ipairs(info) do
				local t = {}
				template[tab] = t
				for index = 1, #tree do
					t[index] = 0
				end
			end

			return template
		end

		Talented.importers = {}
		Talented.exporters = {}
		function Talented:ImportTemplate(url)
			local dst, result = new(self.db.global.templates, L["Imported"])
			for pattern, method in pairs(self.importers) do
				if url:find(pattern) then
					result = method(self, url, dst)
					if result then
						break
					end
				end
			end
			if result then
				if not self:ValidateTemplate(dst) then
					self:Print(L["The given template is not a valid one!"])
					self.db.global.templates[dst.name] = nil
				else
					return dst
				end
			else
				self:Print(L['"%s" does not appear to be a valid URL!'], url)
				self.db.global.templates[dst.name] = nil
			end
		end
	end

	function Talented:OpenTemplate(template)
		self:UnpackTemplate(template)
		if not self:ValidateTemplate(template, true) then
			local name = template.name
			self.db.global.templates[name] = nil
			self:Print(L["The template '%s' is no longer valid and has been removed."], name)
			return
		end
		local base = self:CreateBaseFrame()
		if not self.alternates then
			self:UpdatePlayerSpecs()
		end
		self:SetTemplate(template)
		if not base:IsVisible() then
			ShowUIPanel(base)
		end
	end

	function Talented:SetTemplate(template)
		if not template then
			template = assert(self:GetActiveSpec())
		end
		local view = self:CreateBaseFrame().view
		local old = view.template
		if template ~= old then
			if template.talentGroup then
				if not template.pet then
					view:SetTemplate(template, self:MakeTarget(template.talentGroup))
				else
					view:SetTemplate(template, self:MakeTarget(UnitName "PET"))
				end
			else
				view:SetTemplate(template)
			end
			self.template = template
		end
		if not template.talentGroup then
			self.db.profile.last_template = template.name
		end
		self:SetMode(self:GetDefaultMode())
		-- self:UpdateView()
	end

	function Talented:GetDefaultMode()
		return self.db.profile.always_edit and "edit" or "view"
	end

	function Talented:OnEnable()
		self:RawHook("ToggleTalentFrame", true)
		self:RawHook("ToggleGlyphFrame", true)
		self:SecureHook("UpdateMicroButtons")
		self:CheckHookInspectUI()

		self:RegisterEvent("PLAYER_ENTERING_WORLD")
		UIParent:UnregisterEvent("USE_GLYPH")
		UIParent:UnregisterEvent("CONFIRM_TALENT_WIPE")
		self:RegisterEvent("USE_GLYPH")
		self:RegisterEvent("CONFIRM_TALENT_WIPE")
		self:RegisterEvent("CHARACTER_POINTS_CHANGED")
		self:RegisterEvent("PLAYER_TALENT_UPDATE")
		TalentMicroButton:SetScript("OnClick", ToggleTalentFrame)
	end

	function Talented:OnDisable()
		self:UnhookInspectUI()
		UIParent:RegisterEvent("USE_GLYPH")
		UIParent:RegisterEvent("CONFIRM_TALENT_WIPE")
	end

	function Talented:PLAYER_ENTERING_WORLD()
		if ElvUI then
			local E = select(1, unpack(ElvUI))

			-- spec tabs
			local AS = E:GetModule("AddOnSkins", true)
			if AS then
				AS.addons = AS.addons or {}
				AS.addons["talented_spectabs"] = 1
			end

			-- glyph frame
			self:CreateGlyphFrame()
			E.callbacks:Fire("Talented_GlyphFrame")
		end
	end

	function Talented:PLAYER_TALENT_UPDATE()
		self:UpdatePlayerSpecs()
	end

	function Talented:CONFIRM_TALENT_WIPE(_, cost)
		local dialog = StaticPopup_Show("CONFIRM_TALENT_WIPE")
		if dialog then
			MoneyFrame_Update(dialog:GetName() .. "MoneyFrame", cost)
			self:SetTemplate()
			local frame = self.base
			if not frame or not frame:IsVisible() then
				self:Update()
				ShowUIPanel(self.base)
			end
			dialog:SetFrameLevel(frame:GetFrameLevel() + 5)
		end
	end

	function Talented:CHARACTER_POINTS_CHANGED()
		self:UpdatePlayerSpecs()
		self:UpdateView()
		if self.mode == "apply" then
			self:CheckTalentPointsApplied()
		end
	end

	function Talented:UpdateMicroButtons()
		local button = TalentMicroButton
		if self.db.profile.donthide and UnitLevel "player" < button.minLevel then
			button:Enable()
		end
		if self.base and self.base:IsShown() then
			button:SetButtonState("PUSHED", 1)
		else
			button:SetButtonState("NORMAL")
		end
	end

	function Talented:ToggleTalentFrame()
		local frame = self.base
		if not frame or not frame:IsVisible() then
			self:Update()
			ShowUIPanel(self.base)
		else
			HideUIPanel(frame)
		end
	end

	function Talented:Update()
		self:CreateBaseFrame()
		self:UpdatePlayerSpecs()
		if not self.template then
			self:SetTemplate()
		end
		self:UpdateView()
	end

	function Talented:LoadTemplates()
		local db = self.db.global.templates
		local invalid = {}
		for name, code in pairs(db) do
			if type(code) == "string" then
				local class = self:GetTemplateStringClass(code)
				if class then
					db[name] = {
						name = name,
						code = code,
						class = class
					}
				else
					db[name] = nil
					invalid[#invalid + 1] = name
				end
			elseif not self:ValidateTemplate(code) then
				db[name] = nil
				invalid[#invalid + 1] = name
			end
		end
		if next(invalid) then
			table.sort(invalid)
			self:Print(L["The following templates are no longer valid and have been removed:"])
			self:Print(table.concat(invalid, ", "))
		end

		self.OnDatabaseShutdown = function(self, event, db)
			local _db = db.global.templates
			for name, template in pairs(_db) do
				template.talentGroup = nil
				Talented:PackTemplate(template)
				if template.code then
					_db[name] = template.code
				end
			end
			self.db = nil
		end
		self.db.RegisterCallback(self, "OnDatabaseShutdown")
		self.LoadTemplates = nil
	end
end

-------------------------------------------------------------------------------
-- spell.lua
--

do
	local function handle_ranks(...)
		local result = {}
		local first = (...)
		local pos, row, column, req = 1
		local c = string.byte(first, pos)
		if c == 42 then
			row, column = nil, -1
			pos = pos + 1
			c = string.byte(first, pos)
		elseif c > 32 and c <= 40 then
			column = c - 32
			if column > 4 then
				row = true
				column = column - 4
			end
			pos = pos + 1
			c = string.byte(first, pos)
		end
		if c >= 65 and c <= 90 then
			req = c - 64
			pos = pos + 1
		elseif c >= 97 and c <= 122 then
			req = 96 - c
			pos = pos + 1
		end
		result[1] = tonumber(first:sub(pos))
		for i = 2, select("#", ...) do
			result[i] = tonumber((select(i, ...)))
		end
		local entry = {
			ranks = result,
			row = row,
			column = column,
			req = req
		}
		if not result[1] then
			entry.req = nil
			entry.ranks = nil
			entry.inactive = true
		end
		return entry
	end

	local function next_talent_pos(row, column)
		column = column + 1
		if column >= 5 then
			return row + 1, 1
		else
			return row, column
		end
	end

	local function handle_talents(...)
		local result = {}
		for talent = 1, select("#", ...) do
			result[talent] = handle_ranks(strsplit(";", (select(talent, ...))))
		end
		local row, column = 1, 1
		for index, talent in ipairs(result) do
			local drow, dcolumn = talent.row, talent.column
			if dcolumn == -1 then
				talent.row, talent.column = result[index - 1].row, result[index - 1].column
				talent.inactive = true
			elseif dcolumn then
				if drow then
					row = row + 1
					column = dcolumn
				else
					column = column + dcolumn
				end
				talent.row, talent.column = row, column
			else
				talent.row, talent.column = row, column
			end
			if dcolumn ~= -1 or drow then
				row, column = next_talent_pos(row, column)
			end
			if talent.req then
				talent.req = talent.req + index
				assert(talent.req > 0 and talent.req <= #result)
			end
		end
		return result
	end

	local function handle_tabs(...)
		local result = {}
		for tab = 1, select("#", ...) do
			result[tab] = handle_talents(strsplit(",", (select(tab, ...))))
		end
		return result
	end

	function Talented:UncompressSpellData(class)
		local data = self.spelldata[class]
		if type(data) == "table" then
			return data
		end
		self:Debug("UNCOMPRESS CLASSDATA", class)
		data = handle_tabs(strsplit("|", data))
		self.spelldata[class] = data
		if class == select(2, UnitClass("player")) then
			self:CheckSpellData(class)
		end
		return data
	end

	local spellTooltip
	local function CreateSpellTooltip()
		local tt = CreateFrame "GameTooltip"
		local lefts, rights = {}, {}
		for i = 1, 5 do
			local left, right = tt:CreateFontString(), tt:CreateFontString()
			left:SetFontObject(GameFontNormal)
			right:SetFontObject(GameFontNormal)
			tt:AddFontStrings(left, right)
			lefts[i], rights[i] = left, right
		end
		tt.lefts, tt.rights = lefts, rights
		function tt:SetSpell(spell)
			self:SetOwner(_G.TalentedFrame)
			self:ClearLines()
			self:SetHyperlink("spell:" .. spell)
			return self:NumLines()
		end
		local index
		if _G.CowTip then
			index = function(self, key)
				if not key then
					return ""
				end
				local lines = tt:SetSpell(key)
				if not lines then
					return ""
				end
				local value
				if lines == 2 and not tt.rights[2]:GetText() then
					value = tt.lefts[2]:GetText()
				else
					value = {}
					for i = 2, tt:NumLines() do
						value[i - 1] = {
							left = tt.lefts[i]:GetText(),
							right = tt.rights[i]:GetText()
						}
					end
				end
				tt:Hide() -- CowTip forces the Tooltip to Show, for some reason
				self[key] = value
				return value
			end
		else
			index = function(self, key)
				if not key then
					return ""
				end
				local lines = tt:SetSpell(key)
				if not lines then
					return ""
				end
				local value
				if lines == 2 and not tt.rights[2]:GetText() then
					value = tt.lefts[2]:GetText()
				else
					value = {}
					for i = 2, tt:NumLines() do
						value[i - 1] = {
							left = tt.lefts[i]:GetText(),
							right = tt.rights[i]:GetText()
						}
					end
				end
				self[key] = value
				return value
			end
		end
		Talented.spellDescCache = setmetatable({}, {__index = index})
		CreateSpellTooltip = nil
		return tt
	end

	function Talented:GetTalentName(class, tab, index)
		local spell = self:UncompressSpellData(class)[tab][index].ranks[1]
		return (GetSpellInfo(spell))
	end

	function Talented:GetTalentIcon(class, tab, index)
		local spell = self:UncompressSpellData(class)[tab][index].ranks[1]
		return (select(3, GetSpellInfo(spell)))
	end

	function Talented:GetTalentDesc(class, tab, index, rank)
		if not spellTooltip then
			spellTooltip = CreateSpellTooltip()
		end
		local spell = self:UncompressSpellData(class)[tab][index].ranks[rank]
		return self.spellDescCache[spell]
	end

	function Talented:GetTalentPos(class, tab, index)
		local talent = self:UncompressSpellData(class)[tab][index]
		return talent.row, talent.column
	end

	function Talented:GetTalentPrereqs(class, tab, index)
		local talent = self:UncompressSpellData(class)[tab][index]
		return talent.req
	end

	function Talented:GetTalentRanks(class, tab, index)
		local talent = self:UncompressSpellData(class)[tab][index]
		return #talent.ranks
	end

	function Talented:GetTalentLink(template, tab, index, rank)
		local data = self:UncompressSpellData(template.class)
		rank = rank or (template[tab] and template[tab][index])
		if not rank or rank == 0 then
			rank = 1
		end
		return ("|cff71d5ff|Hspell:%d|h[%s]|h|r"):format(
			data[tab][index].ranks[rank],
			self:GetTalentName(template.class, tab, index)
		)
	end
end

-------------------------------------------------------------------------------
-- check.lua
--

do
	local function DisableTalented(s, ...)
		if _G.TalentedFrame then
			_G.TalentedFrame:Hide()
		end
		if s:find("%", nil, true) then
			s = s:format(...)
		end
		StaticPopupDialogs.TALENTED_DISABLE = {
			button1 = OKAY,
			text = L["Talented has detected an incompatible change in the talent information that requires an update to Talented. Talented will now Disable itself and reload the user interface so that you can use the default interface."] .. "|n" .. s,
			OnAccept = function()
				DisableAddOn("Talented")
				ReloadUI()
			end,
			timeout = 0,
			exclusive = 1,
			whileDead = 1,
			interruptCinematic = 1
		}
		StaticPopup_Show("TALENTED_DISABLE")
	end

	function Talented:CheckSpellData(class)
		if GetNumTalentTabs() < 1 then return end -- postpone checking without failing
		local spelldata, tabdata = self.spelldata[class], self.tabdata[class]
		local invalid
		if #spelldata > GetNumTalentTabs() then
			print("too many tabs", #spelldata, GetNumTalentTabs())
			invalid = true
			for i = #spelldata, GetNumTalentTabs() + 1, -1 do
				spelldata[i] = nil
			end
		end
		for tab = 1, GetNumTalentTabs() do
			local talents = spelldata[tab]
			if not talents then
				print("missing talents for tab", tab)
				invalid = true
				talents = {}
				spelldata[tab] = talents
			end
			local tabname, _, _, background = GetTalentTabInfo(tab)
			tabdata[tab].name = tabname -- no need to mark invalid for these
			tabdata[tab].background = background
			if #talents > GetNumTalents(tab) then
				print("too many talents for tab", tab)
				invalid = true
				for i = #talents, GetNumTalents(tab) + 1, -1 do
					talents[i] = nil
				end
			end
			for index = 1, GetNumTalents(tab) do
				local talent = talents[index]
				if not talent then
					return DisableTalented("%s:%d:%d MISSING TALENT", class, tab, index)
				end
				local name, icon, row, column, _, ranks = GetTalentInfo(tab, index)
				if not name then
					if not talent.inactive then
						print("inactive talent", class, tab, index)
						talent.inactive = true
						invalid = true
					end
				else
					if talent.inactive then
						return DisableTalented("%s:%d:%d NOT INACTIVE", class, tab, index)
					end
					local found
					for _, spell in ipairs(talent.ranks) do
						if GetSpellInfo(spell) == name then
							found = true
							break
						end
					end
					if not found then
						local s, n = pcall(GetSpellInfo, talent.ranks[1])
						return DisableTalented("%s:%d:%d MISMATCHED %d ~= %s", class, tab, index, n or "unknown talent-" .. talent.ranks[1], name)
					end
					if row ~= talent.row then
						print("invalid row for talent", tab, index, row, talent.row)
						invalid = true
						talent.row = row
					end
					if column ~= talent.column then
						print("invalid column for talent", tab, index, column, talent.column)
						invalid = true
						talent.column = column
					end
					if ranks > #talent.ranks then
						return DisableTalented("%s:%d:%d MISSING RANKS %d ~= %d", class, tab, index, #talent.ranks, ranks)
					end
					if ranks < #talent.ranks then
						invalid = true
						print("too many ranks for talent", tab, index, ranks, talent.ranks)
						for i = #talent.ranks, ranks + 1, -1 do
							talent.ranks[i] = nil
						end
					end
					local req_row, req_column, _, _, req2 = GetTalentPrereqs(tab, index)
					if req2 then
						print("too many reqs for talent", tab, index, req2)
						invalid = true
					end
					if not req_row then
						if talent.req then
							print("too many req for talent", tab, index)
							invalid = true
							talent.req = nil
						end
					else
						local req = talents[talent.req]
						if not req or req.row ~= req_row or req.column ~= req_column then
							print("invalid req for talent", tab, index, req and req.row, req_row, req and req.column, req_column)
							invalid = true
							-- it requires another pass to get the right talent.
							talent.req = 0
						end
					end
				end
			end
			for index = 1, GetNumTalents(tab) do
				local talent = talents[index]
				if talent.req == 0 then
					local row, column = GetTalentPrereqs(tab, index)
					for j = 1, GetNumTalents(tab) do
						if talents[j].row == row and talents[j].column == column then
							talent.req = j
							break
						end
					end
					assert(talent.req ~= 0)
				end
			end
		end
		if invalid then
			self:Print(L["WARNING: Talented has detected that its talent data is outdated. Talented will work fine for your class for this session but may have issue with other classes. You should update Talented if you can."])
		end
		self.CheckSpellData = nil
	end
end

-------------------------------------------------------------------------------
-- encode.lua
--

do
	local assert, ipairs, modf, fmod = assert, ipairs, math.modf, math.fmod

	local stop = "Z"
	local talented_map = "012345abcdefABCDEFmnopqrMNOPQRtuvwxy*"
	local classmap = {
		"DRUID",
		"HUNTER",
		"MAGE",
		"PALADIN",
		"PRIEST",
		"ROGUE",
		"SHAMAN",
		"WARLOCK",
		"WARRIOR",
		"DEATHKNIGHT",
		"Ferocity",
		"Cunning",
		"Tenacity"
	}

	function Talented:GetTemplateStringClass(code, nmap)
		nmap = nmap or talented_map
		if code:len() <= 0 then return end
		local index = modf((nmap:find(code:sub(1, 1), nil, true) - 1) / 3) + 1
		if not index or index > #classmap then return end
		return classmap[index]
	end

	local function get_point_string(class, tabs, primary)
		if type(tabs) == "number" then
			return " - |cffffd200" .. tabs .. "|r"
		end
		local start = " - |cffffd200"
		if primary then
			start = start .. Talented.tabdata[class][primary].name .. " "
			tabs[primary] = "|cffffffff" .. tostring(tabs[primary]) .. "|cffffd200"
		end
		return start .. table.concat(tabs, "/", 1, 3) .. "|r"
	end

	local temp_tabcount = {}
	local function GetTemplateStringInfo(code)
		if code:len() <= 0 then return end

		local index = modf((talented_map:find(code:sub(1, 1), nil, true) - 1) / 3) + 1
		if not index or index > #classmap then return end
		local class = classmap[index]
		local talents = Talented:UncompressSpellData(class)
		local tabs, count, t = 1, 0, 0
		for i = 2, code:len() do
			local char = code:sub(i, i)
			if char == stop then
				if t >= #talents[tabs] then
					temp_tabcount[tabs] = count
					tabs = tabs + 1
					count, t = 0, 0
				end
				temp_tabcount[tabs] = count
				tabs = tabs + 1
				count, t = 0, 0
			else
				index = talented_map:find(char, nil, true) - 1
				if not index then
					return
				end
				local b = fmod(index, 6)
				local a = (index - b) / 6
				if t >= #talents[tabs] then
					temp_tabcount[tabs] = count
					tabs = tabs + 1
					count, t = 0, 0
				end
				t = t + 2
				count = count + a + b
			end
		end
		if count > 0 then
			temp_tabcount[tabs] = count
		else
			tabs = tabs - 1
		end
		for i = tabs + 1, #talents do
			temp_tabcount[i] = 0
		end
		tabs = #talents
		if tabs == 1 then
			return get_point_string(class, temp_tabcount[1])
		else -- tab == 3
			local primary, min, max, total = 0, 0, 0, 0
			for i = 1, tabs do
				local points = temp_tabcount[i]
				if points < min then
					min = points
				end
				if points > max then
					primary, max = i, points
				end
				total = total + points
			end
			local middle = total - min - max
			if 3 * (middle - min) >= 2 * (max - min) then
				primary = nil
			end
			return get_point_string(class, temp_tabcount, primary)
		end
	end

	function Talented:GetTemplateInfo(template)
		self:Debug("GET TEMPLATE INFO", template.name)
		if template.code then
			return GetTemplateStringInfo(template.code)
		else
			local tabs = #template
			if tabs == 1 then
				return get_point_string(template.class, self:GetPointCount(template))
			else
				local primary, min, max, total = 0, 0, 0, 0
				for i = 1, tabs do
					local points = 0
					for _, value in ipairs(template[i]) do
						points = points + value
					end
					temp_tabcount[i] = points
					if points < min then
						min = points
					end
					if points > max then
						primary, max = i, points
					end
					total = total + points
				end
				local middle = total - min - max
				if 3 * (middle - min) >= 2 * (max - min) then
					primary = nil
				end
				return get_point_string(template.class, temp_tabcount, primary)
			end
		end
	end

	function Talented:StringToTemplate(code, template, nmap)
		nmap = nmap or talented_map
		if code:len() <= 0 then return end

		local index = modf((nmap:find(code:sub(1, 1), nil, true) - 1) / 3) + 1
		assert(index and index <= #classmap, "Unknown class code")

		local class = classmap[index]
		template = template or {}
		template.class = class

		local talents = self:UncompressSpellData(class)
		assert(talents)

		local tab = 1
		local t = wipe(template[tab] or {})
		template[tab] = t

		for i = 2, code:len() do
			local char = code:sub(i, i)
			if char == stop then
				if #t >= #talents[tab] then
					tab = tab + 1
					t = wipe(template[tab] or {})
					template[tab] = t
				end
				tab = tab + 1
				t = wipe(template[tab] or {})
				template[tab] = t
			else
				index = nmap:find(char, nil, true) - 1
				if not index then
					return
				end
				local b = fmod(index, 6)
				local a = (index - b) / 6

				if #t >= #talents[tab] then
					tab = tab + 1
					t = wipe(template[tab] or {})
					template[tab] = t
				end
				t[#t + 1] = a

				if #t < #talents[tab] then
					t[#t + 1] = b
				else
					assert(b == 0)
				end
			end
		end

		assert(#template <= #talents, "Too many branches")
		do
			for tb, tree in ipairs(talents) do
				local _t = template[tb] or {}
				template[tb] = _t
				for i = 1, #tree do
					_t[i] = _t[i] or 0
				end
			end
		end

		return template, class
	end

	local function rtrim(s, c)
		local l = #s
		while l >= 1 and s:sub(l, l) == c do
			l = l - 1
		end
		return s:sub(1, l)
	end

	local function get_next_valid_index(tmpl, index, talents)
		if not talents[index] then
			return 0, index
		else
			return tmpl[index], index + 1
		end
	end

	function Talented:TemplateToString(template, nmap)
		nmap = nmap or talented_map

		local class = template.class

		local code, ccode = ""
		do
			for index, c in ipairs(classmap) do
				if c == class then
					local i = (index - 1) * 3 + 1
					ccode = nmap:sub(i, i)
					break
				end
			end
		end
		assert(ccode, "invalid class")
		local s = nmap:sub(1, 1)
		local info = self:UncompressSpellData(class)
		for tab, talents in ipairs(info) do
			local tmpl = template[tab]
			local index = 1
			while index <= #tmpl do
				local r1, r2
				r1, index = get_next_valid_index(tmpl, index, talents)
				r2, index = get_next_valid_index(tmpl, index, talents)
				local v = r1 * 6 + r2 + 1
				local c = nmap:sub(v, v)
				assert(c)
				code = code .. c
			end
			local ncode = rtrim(code, s)
			if ncode ~= code then
				code = ncode .. stop
			end
		end
		local output = ccode .. rtrim(code, stop)

		return output
	end

	function Talented:PackTemplate(template)
		if not template or template.talentGroup or template.code then return end
		self:Debug("PACK TEMPLATE", template.name)
		template.code = self:TemplateToString(template)
		for tab in ipairs(template) do
			template[tab] = nil
		end
	end

	function Talented:UnpackTemplate(template)
		if not template.code then return end
		self:Debug("UNPACK TEMPLATE", template.name)
		self:StringToTemplate(template.code, template)
		template.code = nil
		if not RAID_CLASS_COLORS[template.class] then
			self:FixPetTemplate(template)
		end
	end

	function Talented:CopyPackedTemplate(src, dst)
		local packed = src.code
		if packed then
			self:UnpackTemplate(src)
		end
		dst.class = src.class
		for tab, talents in ipairs(src) do
			local d = dst[tab]
			if not d then
				d = {}
				dst[tab] = d
			end
			for index, value in ipairs(talents) do
				d[index] = value
			end
		end
		if packed then
			self:PackTemplate(src)
		end
	end
end

-------------------------------------------------------------------------------
-- viewmode.lua
--

do
	local select, ipairs = select, ipairs
	local GetTalentInfo = GetTalentInfo

	function Talented:UpdatePlayerSpecs()
		if GetNumTalentTabs() == 0 then return end
		local class = select(2, UnitClass "player")
		local info = self:UncompressSpellData(class)
		if not self.alternates then
			self.alternates = {}
		end
		for talentGroup = 1, GetNumTalentGroups() do
			local template = self.alternates[talentGroup]
			if not template then
				template = {
					talentGroup = talentGroup,
					name = talentGroup == 1 and TALENT_SPEC_PRIMARY or TALENT_SPEC_SECONDARY,
					class = class
				}
			else
				template.points = nil
			end
			for tab, tree in ipairs(info) do
				local ttab = template[tab]
				if not ttab then
					ttab = {}
					template[tab] = ttab
				end
				for index = 1, #tree do
					ttab[index] = select(5, GetTalentInfo(tab, index, nil, nil, talentGroup))
				end
			end
			self.alternates[talentGroup] = template
			if self.template == template then
				self:UpdateTooltip()
			end
			for _, view in self:IterateTalentViews(template) do
				view:Update()
			end
		end
	end

	function Talented:GetActiveSpec()
		if not self.alternates then
			self:UpdatePlayerSpecs()
		end
		return self.alternates[GetActiveTalentGroup()]
	end

	function Talented:UpdateView()
		if not self.base then return end
		self.base.view:Update()
	end
end

-------------------------------------------------------------------------------
-- view.lua
--

do
	local LAYOUT_BASE_X = 4
	local LAYOUT_BASE_Y = 24

	local LAYOUT_OFFSET_X, LAYOUT_OFFSET_Y, LAYOUT_DELTA_X, LAYOUT_DELTA_Y
	local LAYOUT_SIZE_X

	local function RecalcLayout(offset)
		if LAYOUT_OFFSET_X ~= offset then
			LAYOUT_OFFSET_X = offset
			LAYOUT_OFFSET_Y = LAYOUT_OFFSET_X

			LAYOUT_DELTA_X = LAYOUT_OFFSET_X / 2
			LAYOUT_DELTA_Y = LAYOUT_OFFSET_Y / 2

			LAYOUT_SIZE_X --[[LAYOUT_MAX_COLUMNS]] = 4 * LAYOUT_OFFSET_X + LAYOUT_DELTA_X

			return true
		end
	end

	local function offset(row, column)
		return (column - 1) * LAYOUT_OFFSET_X + LAYOUT_DELTA_X, -((row - 1) * LAYOUT_OFFSET_Y + LAYOUT_DELTA_Y)
	end

	local TalentView = {}
	function TalentView:init(frame, name)
		self.frame = frame
		self.name = name
		self.elements = {}
	end

	function TalentView:SetUIElement(element, ...)
		self.elements[strjoin("-", ...)] = element
	end

	function TalentView:GetUIElement(...)
		return self.elements[strjoin("-", ...)]
	end

	function TalentView:SetViewMode(mode, force)
		if mode ~= self.mode or force then
			self.mode = mode
			self:Update()
		end
	end

	local function GetMaxPoints(...)
		local total = 0
		for i = 1, GetNumTalentTabs(...) do
			total = total + select(3, GetTalentTabInfo(i, ...))
		end
		return total + GetUnspentTalentPoints(...)
	end

	function TalentView:SetClass(class, force)
		if self.class == class and not force then return end
		local pet = not RAID_CLASS_COLORS[class]
		self.pet = pet

		Talented.Pool:changeSet(self.name)
		wipe(self.elements)
		local talents = Talented:UncompressSpellData(class)
		if not LAYOUT_OFFSET_X then
			RecalcLayout(Talented.db.profile.offset)
		end
		local top_offset, bottom_offset = LAYOUT_BASE_X, LAYOUT_BASE_X
		if self.frame.SetTabSize then
			local n = #talents
			self.frame:SetTabSize(n)
			top_offset = top_offset + (4 - n) * LAYOUT_BASE_Y
			if Talented.db.profile.add_bottom_offset then
				bottom_offset = bottom_offset + LAYOUT_BASE_Y
			end
		end
		local first_tree = talents[1]
		local size_y = first_tree[#first_tree].row * LAYOUT_OFFSET_Y + LAYOUT_DELTA_Y
		for tab, tree in ipairs(talents) do
			local frame = Talented:MakeTalentFrame(self.frame, LAYOUT_SIZE_X, size_y)
			frame.tab = tab
			frame.view = self
			frame.pet = self.pet

			local background = Talented.tabdata[class][tab].background
			frame.topleft:SetTexture("Interface\\TalentFrame\\" .. background .. "-TopLeft")
			frame.topright:SetTexture("Interface\\TalentFrame\\" .. background .. "-TopRight")
			frame.bottomleft:SetTexture("Interface\\TalentFrame\\" .. background .. "-BottomLeft")
			frame.bottomright:SetTexture("Interface\\TalentFrame\\" .. background .. "-BottomRight")

			self:SetUIElement(frame, tab)

			for index, talent in ipairs(tree) do
				if not talent.inactive then
					local button = Talented:MakeButton(frame)
					button.id = index

					self:SetUIElement(button, tab, index)

					button:SetPoint("TOPLEFT", offset(talent.row, talent.column))
					button.texture:SetTexture(Talented:GetTalentIcon(class, tab, index))
					button:Show()
				end
			end

			for index, talent in ipairs(tree) do
				local req = talent.req
				if req then
					local elements = {}
					Talented.DrawLine(elements, frame, offset, talent.row, talent.column, tree[req].row, tree[req].column)
					self:SetUIElement(elements, tab, index, req)
				end
			end

			frame:SetPoint("TOPLEFT", (tab - 1) * LAYOUT_SIZE_X + LAYOUT_BASE_X, -top_offset)
		end
		self.frame:SetSize(#talents * LAYOUT_SIZE_X + LAYOUT_BASE_X * 2, size_y + top_offset + bottom_offset)
		self.frame:SetScale(Talented.db.profile.scale)

		self.class = class
		self:Update()
	end

	function TalentView:SetTemplate(template, target)
		if template then
			Talented:UnpackTemplate(template)
		end
		if target then
			Talented:UnpackTemplate(target)
		end

		local curr = self.target
		self.target = target
		if curr and curr ~= template and curr ~= target then
			Talented:PackTemplate(curr)
		end
		curr = self.template
		self.template = template
		if curr and curr ~= template and curr ~= target then
			Talented:PackTemplate(curr)
		end

		self.spec = template.talentGroup
		self:SetClass(template.class)

		return self:Update()
	end

	function TalentView:ClearTarget()
		if self.target then
			self.target = nil
			self:Update()
		end
	end

	function TalentView:GetReqLevel(total)
		if not self.pet then
			return total == 0 and 1 or total + 9
		else
			if total == 0 then
				return 10
			end
			if total > 16 then
				return 60 + (total - 15) * 4 -- this spec requires Beast Mastery
			else
				return 16 + total * 4
			end
		end
	end

	local GRAY_FONT_COLOR = GRAY_FONT_COLOR
	local NORMAL_FONT_COLOR = NORMAL_FONT_COLOR
	local GREEN_FONT_COLOR = GREEN_FONT_COLOR
	local RED_FONT_COLOR = RED_FONT_COLOR
	local LIGHTBLUE_FONT_COLOR = {r = 0.3, g = 0.9, b = 1}
	function TalentView:Update()
		local template, target = self.template, self.target
		local total = 0
		local info = Talented:UncompressSpellData(template.class)
		local at_cap = Talented:IsTemplateAtCap(template)
		for tab, tree in ipairs(info) do
			local count = 0
			for index, talent in ipairs(tree) do
				if not talent.inactive then
					local rank = template[tab][index]
					count = count + rank
					local button = self:GetUIElement(tab, index)
					local color = GRAY_FONT_COLOR
					local state = Talented:GetTalentState(template, tab, index)
					if state == "empty" and (at_cap or self.mode == "view") then
						state = "unavailable"
					end
					if state == "unavailable" then
						button.texture:SetDesaturated(1)
						button.slot:SetVertexColor(0.65, 0.65, 0.65)
						button.rank:Hide()
						button.rank.texture:Hide()
					else
						button.rank:Show()
						button.rank.texture:Show()
						button.rank:SetText(rank)
						button.texture:SetDesaturated(0)
						if state == "full" then
							color = NORMAL_FONT_COLOR
						else
							color = GREEN_FONT_COLOR
						end
						button.slot:SetVertexColor(color.r, color.g, color.b)
						button.rank:SetVertexColor(color.r, color.g, color.b)
					end
					local req = talent.req
					if req then
						local ecolor = color
						if ecolor == GREEN_FONT_COLOR then
							if self.mode == "edit" then
								local s = Talented:GetTalentState(template, tab, req)
								if s ~= "full" then
									ecolor = RED_FONT_COLOR
								end
							else
								ecolor = NORMAL_FONT_COLOR
							end
						end
						for _, element in ipairs(self:GetUIElement(tab, index, req)) do
							element:SetVertexColor(ecolor.r, ecolor.g, ecolor.b)
						end
					end
					local targetvalue = target and target[tab][index]
					if targetvalue and (targetvalue > 0 or rank > 0) then
						local btarget = Talented:GetButtonTarget(button)
						btarget:Show()
						btarget.texture:Show()
						btarget:SetText(targetvalue)
						local tcolor
						if rank < targetvalue then
							tcolor = LIGHTBLUE_FONT_COLOR
						elseif rank == targetvalue then
							tcolor = GRAY_FONT_COLOR
						else
							tcolor = RED_FONT_COLOR
						end
						btarget:SetVertexColor(tcolor.r, tcolor.g, tcolor.b)
					elseif button.target then
						button.target:Hide()
						button.target.texture:Hide()
					end
				end
			end
			local frame = self:GetUIElement(tab)
			frame.name:SetFormattedText(L["%s (%d)"], Talented.tabdata[template.class][tab].name, count)
			total = total + count
			local clear = frame.clear
			if self.mode ~= "edit" or count <= 0 or self.spec then
				clear:Hide()
			else
				clear:Show()
			end
		end
		local maxpoints = GetMaxPoints(nil, self.pet, self.spec)
		local points = self.frame.points
		if points then
			if Talented.db.profile.show_level_req then
				points:SetFormattedText(L["Level %d"], self:GetReqLevel(total))
			else
				points:SetFormattedText(L["%d/%d"], total, maxpoints)
			end
			local color
			if total < maxpoints then
				color = GREEN_FONT_COLOR
			elseif total > maxpoints then
				color = RED_FONT_COLOR
			else
				color = NORMAL_FONT_COLOR
			end
			points:SetTextColor(color.r, color.g, color.b)
		end
		local pointsleft = self.frame.pointsleft
		if pointsleft then
			if maxpoints ~= total and template.talentGroup then
				pointsleft:Show()
				pointsleft.text:SetFormattedText(L["You have %d talent |4point:points; left"], maxpoints - total)
			else
				pointsleft:Hide()
			end
		end
		local edit = self.frame.editname
		if edit then
			if template.talentGroup then
				edit:Hide()
			else
				edit:Show()
				edit:SetText(template.name)
			end
		end
		local cb, activate = self.frame.checkbox, self.frame.bactivate
		if cb then
			if template.talentGroup == GetActiveTalentGroup() or template.pet then
				if activate then
					activate:Hide()
				end
				cb:Show()
				cb.label:SetText(L["Edit talents"])
				cb.tooltip = L["Toggle editing of talents."]
			elseif template.talentGroup then
				cb:Hide()
				if activate then
					activate.talentGroup = template.talentGroup
					activate:Show()
				end
			else
				if activate then
					activate:Hide()
				end
				cb:Show()
				cb.label:SetText(L["Edit template"])
				cb.tooltip = L["Toggle edition of the template."]
			end
			cb:SetChecked(self.mode == "edit")
		end
		local targetname = self.frame.targetname
		if targetname then
			if template.pet then
				targetname:Show()
				targetname:SetText(TALENT_SPEC_PET_PRIMARY)
			elseif template.talentGroup then
				targetname:Show()
				if template.talentGroup == GetActiveTalentGroup() and target then
					targetname:SetText(L["Target: %s"]:format(target.name))
				elseif template.talentGroup == 1 then
					targetname:SetText(TALENT_SPEC_PRIMARY)
				else
					targetname:SetText(TALENT_SPEC_SECONDARY)
				end
			else
				targetname:Hide()
			end
		end
	end

	function TalentView:SetTooltipInfo(owner, tab, index)
		Talented:SetTooltipInfo(owner, self.class, tab, index)
	end

	function TalentView:OnTalentClick(button, tab, index)
		if IsModifiedClick "CHATLINK" then
			local link = Talented:GetTalentLink(self.template, tab, index)
			if link then
				ChatEdit_InsertLink(link)
			end
		else
			self:UpdateTalent(tab, index, button == "LeftButton" and 1 or -1)
		end
	end

	function TalentView:UpdateTalent(tab, index, offset)
		if self.mode ~= "edit" then return end
		if self.spec then
			-- Applying talent
			if offset > 0 then
				Talented:LearnTalent(self.template, tab, index)
			end
			return
		end
		local template = self.template

		if offset > 0 and Talented:IsTemplateAtCap(template) then return end
		local s = Talented:GetTalentState(template, tab, index)

		local ranks = Talented:GetTalentRanks(template.class, tab, index)
		local original = template[tab][index]
		local value = original + offset
		if value < 0 or s == "unavailable" then
			value = 0
		elseif value > ranks then
			value = ranks
		end
		Talented:Debug("Updating %d-%d : %d -> %d (%d)", tab, index, original, value, offset)
		if value == original or not Talented:ValidateTalentBranch(template, tab, index, value) then return end
		template[tab][index] = value
		template.points = nil
		for _, view in Talented:IterateTalentViews(template) do
			view:Update()
		end
		Talented:UpdateTooltip()
		return true
	end

	function TalentView:ClearTalentTab(t)
		local template = self.template
		if template and not template.talentGroup then
			local tab = template[t]
			for index, value in ipairs(tab) do
				tab[index] = 0
			end
		end
		for _, view in Talented:IterateTalentViews(template) do
			view:Update()
		end
	end

	Talented.views = {}
	Talented.TalentView = {
		__index = TalentView,
		new = function(self, ...)
			local view = setmetatable({}, self)
			view:init(...)
			table.insert(Talented.views, view)
			return view
		end
	}

	local function next_TalentView(views, index)
		index = (index or 0) + 1
		local view = views[index]
		if not view then
			return nil
		else
			return index, view
		end
	end

	function Talented:IterateTalentViews(template)
		local next
		if template then
			next = function(views, index)
				while true do
					index = (index or 0) + 1
					local view = views[index]
					if not view then
						return nil
					elseif view.template == template then
						return index, view
					end
				end
			end
		else
			next = next_TalentView
		end
		return next, self.views
	end

	function Talented:ViewsReLayout(force)
		if RecalcLayout(self.db.profile.offset) or force then
			for _, view in self:IterateTalentViews() do
				view:SetClass(view.class, true)
			end
		end
	end
end

-------------------------------------------------------------------------------
-- editmode.lua
--

do
	local ipairs = ipairs

	function Talented:IsTemplateAtCap(template)
		local max = RAID_CLASS_COLORS[template.class] and 71 or 20
		return self.db.profile.level_cap and self:GetPointCount(template) >= max
	end

	function Talented:GetPointCount(template)
		local total = 0
		local info = self:UncompressSpellData(template.class)
		for tab in ipairs(info) do
			total = total + self:GetTalentTabCount(template, tab)
		end
		return total
	end

	function Talented:GetTalentTabCount(template, tab)
		local total = 0
		for _, value in ipairs(template[tab]) do
			total = total + value
		end
		return total
	end

	function Talented:ClearTalentTab(t)
		local template = self.template
		if template and not template.talentGroup and self.mode == "edit" then
			local tab = template[t]
			for index, value in ipairs(tab) do
				tab[index] = 0
			end
		end
		self:UpdateView()
	end

	function Talented:GetSkillPointsPerTier(class)
		-- Player Tiers are 5 points appart, Pet Tiers are only 3 points appart.
		return RAID_CLASS_COLORS[class] and 5 or 3
	end

	function Talented:GetTalentState(template, tab, index)
		local s
		local info = self:UncompressSpellData(template.class)[tab][index]
		local tier = (info.row - 1) * self:GetSkillPointsPerTier(template.class)
		local count = self:GetTalentTabCount(template, tab)

		if count < tier then
			s = false
		else
			s = true
			if info.req and self:GetTalentState(template, tab, info.req) ~= "full" then
				s = false
			end
		end

		if not s or info.inactive then
			s = "unavailable"
		else
			local value = template[tab][index]
			if value == #info.ranks then
				s = "full"
			elseif value == 0 then
				s = "empty"
			else
				s = "available"
			end
		end
		return s
	end

	function Talented:ValidateTalentBranch(template, tab, index, newvalue)
		local count = 0
		local pointsPerTier = self:GetSkillPointsPerTier(template.class)
		local tree = self:UncompressSpellData(template.class)[tab]
		local ttab = template[tab]
		for i, talent in ipairs(tree) do
			local value = i == index and newvalue or ttab[i]
			if value > 0 then
				local tier = (talent.row - 1) * pointsPerTier
				if count < tier then
					self:Debug("Update refused because of tier")
					return false
				end
				local r = talent.req
				if r then
					local rvalue = r == index and newvalue or ttab[r]
					if rvalue < #tree[r].ranks then
						self:Debug("Update refused because of prereq")
						return false
					end
				end
				count = count + value
			end
		end
		return true
	end

	function Talented:ValidateTemplate(template, fix)
		local class = template.class
		if not class then return end
		local pointsPerTier = self:GetSkillPointsPerTier(template.class)
		local info = self:UncompressSpellData(class)
		local fixed
		for tab, tree in ipairs(info) do
			local t = template[tab]
			if not t then
				return
			end
			local count = 0
			for i, talent in ipairs(tree) do
				local value = t[i]
				if not value then
					return
				end
				if value > 0 then
					if count < (talent.row - 1) * pointsPerTier or value > (talent.inactive and 0 or #talent.ranks) then
						if fix then
							t[i], value, fixed = 0, 0, true
						else
							return
						end
					end
					local r = talent.req
					if r then
						if t[r] < #tree[r].ranks then
							if fix then
								t[i], value, fixed = 0, 0, true
							else
								return
							end
						end
					end
					count = count + value
				end
			end
		end
		if fixed then
			self:Print(L["The template '%s' had inconsistencies and has been fixed. Please check it before applying."], template.name)
			template.points = nil
		end
		return true
	end
end

-------------------------------------------------------------------------------
-- learn.lua
--

do
	local StaticPopupDialogs = StaticPopupDialogs

	local function ShowDialog(text, tab, index, pet)
		StaticPopupDialogs.TALENTED_CONFIRM_LEARN = {
			button1 = YES,
			button2 = NO,
			OnAccept = function(self)
				LearnTalent(self.talent_tab, self.talent_index, self.is_pet)
			end,
			timeout = 0,
			exclusive = 1,
			whileDead = 1,
			interruptCinematic = 1
		}
		ShowDialog = function(text, tab, index, pet)
			StaticPopupDialogs.TALENTED_CONFIRM_LEARN.text = text
			local dlg = StaticPopup_Show "TALENTED_CONFIRM_LEARN"
			dlg.talent_tab = tab
			dlg.talent_index = index
			dlg.is_pet = pet
			return dlg
		end
		return ShowDialog(text, tab, index, pet)
	end

	function Talented:LearnTalent(template, tab, index)
		local is_pet = not RAID_CLASS_COLORS[template.class]
		local p = self.db.profile

		if not p.confirmlearn then
			LearnTalent(tab, index, is_pet)
			return
		end

		if not p.always_call_learn_talents then
			local state = self:GetTalentState(template, tab, index)
			if
				state == "full" or -- talent maxed out
					state == "unavailable" or -- prereqs not fullfilled
					GetUnspentTalentPoints(nil, is_pet, GetActiveTalentGroup(nil, is_pet)) == 0
			 then -- no more points
				return
			end
		end

		ShowDialog(L['Are you sure that you want to learn "%s (%d/%d)" ?']:format(self:GetTalentName(template.class, tab, index), template[tab][index] + 1, self:GetTalentRanks(template.class, tab, index)), tab, index, is_pet)
	end
end

-------------------------------------------------------------------------------
-- other.lua
--

do
	local function ShowDialog(sender, name, code)
		StaticPopupDialogs.TALENTED_CONFIRM_SHARE_TEMPLATE = {
			button1 = YES,
			button2 = NO,
			text = L['Do you want to add the template "%s" that %s sent you ?'],
			OnAccept = function(self)
				local res, value, class = pcall(Talented.StringToTemplate, Talented, self.code)
				if res then
					Talented:ImportFromOther(self.name, {
						code = self.code,
						class = class
					})
				else
					Talented:Print("Invalid template", value)
				end
			end,
			timeout = 0,
			exclusive = 1,
			whileDead = 1,
			interruptCinematic = 1
		}
		ShowDialog = function(sender, name, code)
			local dlg = StaticPopup_Show("TALENTED_CONFIRM_SHARE_TEMPLATE", name, sender)
			dlg.name = name
			dlg.code = code
		end
		return ShowDialog(sender, name, code)
	end

	function Talented:OnCommReceived(prefix, message, distribution, sender)
		local status, name, code = self:Deserialize(message)
		if not status then return end

		ShowDialog(sender, name, code)
	end

	function Talented:ExportTemplateToUser(name)
		if not name or name:trim() == "" then return end
		local message = self:Serialize(self.template.name, self:TemplateToString(self.template))
		self:SendCommMessage("Talented", message, "WHISPER", name)
	end
end

-------------------------------------------------------------------------------
-- chat.lua
--

do
	local ipairs, format = ipairs, string.format

	function Talented:WriteToChat(text, ...)
		if text:find("%", 1, true) then
			text = text:format(...)
		end
		local edit = ChatEdit_GetLastActiveWindow and ChatEdit_GetLastActiveWindow() or DEFAULT_CHAT_FRAME.editBox
		local type = edit:GetAttribute("chatType")
		local lang = edit.language
		if type == "WHISPER" then
			local target = edit:GetAttribute("tellTarget")
			SendChatMessage(text, type, lang, target)
		elseif type == "CHANNEL" then
			local channel = edit:GetAttribute("channelTarget")
			SendChatMessage(text, type, lang, channel)
		else
			SendChatMessage(text, type, lang)
		end
	end

	local function GetDialog()
		StaticPopupDialogs.TALENTED_SHOW_DIALOG = {
			text = L["URL:"],
			button1 = OKAY,
			hasEditBox = 1,
			hasWideEditBox = 1,
			timeout = 0,
			whileDead = 1,
			hideOnEscape = 1,
			OnShow = function(self)
				self.button1:SetPoint("TOP", self.editBox, "BOTTOM", 0, -8)
			end
		}
		GetDialog = function()
			return StaticPopup_Show "TALENTED_SHOW_DIALOG"
		end
		return GetDialog()
	end

	function Talented:ShowInDialog(text, ...)
		if text:find("%", 1, true) then
			text = text:format(...)
		end
		local edit = GetDialog().wideEditBox
		edit:SetText(text)
		edit:HighlightText()
	end
end

-------------------------------------------------------------------------------
-- tips.lua
--

do
	local type = type
	local ipairs = ipairs
	local GameTooltip = GameTooltip
	local IsAltKeyDown = IsAltKeyDown
	local GREEN_FONT_COLOR = GREEN_FONT_COLOR
	local NORMAL_FONT_COLOR = NORMAL_FONT_COLOR
	local HIGHLIGHT_FONT_COLOR = HIGHLIGHT_FONT_COLOR
	local RED_FONT_COLOR = RED_FONT_COLOR

	local function addline(line, color, split)
		GameTooltip:AddLine(line, color.r, color.g, color.b, split)
	end

	local function addtipline(tip)
		local color = HIGHLIGHT_FONT_COLOR
		tip = tip or ""
		if type(tip) == "string" then
			addline(tip, NORMAL_FONT_COLOR, true)
		else
			for _, i in ipairs(tip) do
				if (_ == #tip) then
					color = NORMAL_FONT_COLOR
				end
				if i.right then
					GameTooltip:AddDoubleLine(i.left, i.right, color.r, color.g, color.b, color.r, color.g, color.b)
				else
					addline(i.left, color, true)
				end
			end
		end
	end

	local lastTooltipInfo = {}
	function Talented:SetTooltipInfo(frame, class, tab, index)
		lastTooltipInfo[1] = frame
		lastTooltipInfo[2] = class
		lastTooltipInfo[3] = tab
		lastTooltipInfo[4] = index
		if not GameTooltip:IsOwned(frame) then
			GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
		end

		local tree = self.spelldata[class][tab]
		local info = tree[index]
		GameTooltip:ClearLines()
		local tier = (info.row - 1) * self:GetSkillPointsPerTier(class)
		local template = frame:GetParent().view.template

		self:UnpackTemplate(template)
		local rank = template[tab][index]
		local ranks, req = #info.ranks, info.req
		addline(self:GetTalentName(class, tab, index), HIGHLIGHT_FONT_COLOR)
		addline(TOOLTIP_TALENT_RANK:format(rank, ranks), HIGHLIGHT_FONT_COLOR)
		if req then
			local oranks = #tree[req].ranks
			if template[tab][req] < oranks then
				addline(TOOLTIP_TALENT_PREREQ:format(oranks, self:GetTalentName(class, tab, req)), RED_FONT_COLOR)
			end
		end
		if tier >= 1 and self:GetTalentTabCount(template, tab) < tier then
			addline(TOOLTIP_TALENT_TIER_POINTS:format(tier, self.tabdata[class][tab].name), RED_FONT_COLOR)
		end
		if IsAltKeyDown() then
			for i = 1, ranks do
				local tip = self:GetTalentDesc(class, tab, index, i)
				if type(tip) == "table" then
					tip = tip[#tip].left
				end
				addline(tip, i == rank and HIGHLIGHT_FONT_COLOR or NORMAL_FONT_COLOR, true)
			end
		else
			if rank > 0 then
				addtipline(self:GetTalentDesc(class, tab, index, rank))
			end
			if rank < ranks then
				if rank > 0 then
					addline("|n" .. TOOLTIP_TALENT_NEXT_RANK, HIGHLIGHT_FONT_COLOR)
				end
				addtipline(self:GetTalentDesc(class, tab, index, rank + 1))
			end
		end
		local s = self:GetTalentState(template, tab, index)
		if self.mode == "edit" then
			if template.talentGroup then
				if s == "available" or s == "empty" then
					addline(TOOLTIP_TALENT_LEARN, GREEN_FONT_COLOR)
				end
			elseif s == "full" then
				addline(TALENT_TOOLTIP_REMOVEPREVIEWPOINT, GREEN_FONT_COLOR)
			elseif s == "available" then
				GameTooltip:AddDoubleLine(
					TALENT_TOOLTIP_ADDPREVIEWPOINT,
					TALENT_TOOLTIP_REMOVEPREVIEWPOINT,
					GREEN_FONT_COLOR.r,
					GREEN_FONT_COLOR.g,
					GREEN_FONT_COLOR.b,
					GREEN_FONT_COLOR.r,
					GREEN_FONT_COLOR.g,
					GREEN_FONT_COLOR.b
				)
			elseif s == "empty" then
				addline(TALENT_TOOLTIP_ADDPREVIEWPOINT, GREEN_FONT_COLOR)
			end
		end
		GameTooltip:Show()
	end

	function Talented:HideTooltipInfo()
		GameTooltip:Hide()
		wipe(lastTooltipInfo)
	end

	function Talented:UpdateTooltip()
		if next(lastTooltipInfo) then
			self:SetTooltipInfo(unpack(lastTooltipInfo))
		end
	end

	function Talented:MODIFIER_STATE_CHANGED(_, mod)
		if mod:sub(-3) == "ALT" then
			self:UpdateTooltip()
		end
	end
end

-------------------------------------------------------------------------------
-- apply.lua
--

do
	function Talented:ApplyCurrentTemplate()
		local template = self.template
		local pet = not RAID_CLASS_COLORS[template.class]
		if pet then
			if not self.GetPetClass or self:GetPetClass() ~= template.class then
				self:Print(L["Sorry, I can't apply this template because it doesn't match your pet's class!"])
				self.mode = "view"
				self:UpdateView()
				return
			end
		elseif select(2, UnitClass "player") ~= template.class then
			self:Print(L["Sorry, I can't apply this template because it doesn't match your class!"])
			self.mode = "view"
			self:UpdateView()
			return
		end
		local count = 0
		local current = pet and self.pet_current or self:GetActiveSpec()
		local group = GetActiveTalentGroup(nil, pet)
		-- check if enough talent points are available
		local available = GetUnspentTalentPoints(nil, pet, group)
		for tab, tree in ipairs(self:UncompressSpellData(template.class)) do
			for index = 1, #tree do
				local delta = template[tab][index] - current[tab][index]
				if delta > 0 then
					count = count + delta
				end
			end
		end
		if count == 0 then
			self:Print(L["Nothing to do"])
			self.mode = "view"
			self:UpdateView()
		elseif count > available then
			self:Print(L["Sorry, I can't apply this template because you don't have enough talent points available (need %d)!"], count)
			self.mode = "view"
			self:UpdateView()
		else
			self:EnableUI(false)
			self:ApplyTalentPoints()
		end
	end

	function Talented:ApplyTalentPoints()
		local p = GetCVar "previewTalents"
		SetCVar("previewTalents", "1")

		local template = self.template
		local pet = not RAID_CLASS_COLORS[template.class]
		local group = GetActiveTalentGroup(nil, pet)
		ResetGroupPreviewTalentPoints(pet, group)
		local cp = GetUnspentTalentPoints(nil, pet, group)

		while true do
			local missing, set
			for tab, tree in ipairs(self:UncompressSpellData(template.class)) do
				local ttab = template[tab]
				for index = 1, #tree do
					local rank = select(9, GetTalentInfo(tab, index, nil, pet, group))
					local delta = ttab[index] - rank
					if delta > 0 then
						AddPreviewTalentPoints(tab, index, delta, pet, group)
						local nrank = select(9, GetTalentInfo(tab, index, nil, pet, group))
						if nrank < ttab[index] then
							missing = true
						elseif nrank > rank then
							set = true
						end
						cp = cp - nrank + rank
					end
				end
			end
			if not missing then
				break
			end
			assert(set) -- make sure we did something
		end
		if cp < 0 then
			Talented:Print(L["Error while applying talents! Not enough talent points!"])
			ResetGroupPreviewTalentPoints(pet, group)
			Talented:EnableUI(true)
		else
			LearnPreviewTalents(pet)
		end
		SetCVar("previewTalents", p)
	end

	function Talented:CheckTalentPointsApplied()
		local template = self.template
		local pet = not RAID_CLASS_COLORS[template.class]
		local group = GetActiveTalentGroup(nil, pet)
		local failed
		for tab, tree in ipairs(self:UncompressSpellData(template.class)) do
			local ttab = template[tab]
			for index = 1, #tree do
				local delta = ttab[index] - select(5, GetTalentInfo(tab, index, nil, pet, group))
				if delta > 0 then
					failed = true
					break
				end
			end
		end
		if failed then
			Talented:Print(L["Error while applying talents! some of the request talents were not set!"])
		else
			local cp = GetUnspentTalentPoints(nil, pet, group)
			Talented:Print(L["Template applied successfully, %d talent points remaining."], cp)

			if self.db.profile.restore_bars then
				local set = template.name:match("[^-]*"):trim():lower()
				if set and ABS then
					ABS:RestoreProfile(set)
				elseif set and _G.KPack and _G.KPack.ActionBarSaver then
					_G.KPack.ActionBarSaver:RestoreProfile(set)
				end
			end
		end
		Talented:OpenTemplate(pet and self.pet_current or self:GetActiveSpec())
		Talented:EnableUI(true)

		return not failed
	end
end

-------------------------------------------------------------------------------
-- inspectui.lua
--

do
	local prev_script
	local new_script = function()
		local template = Talented:UpdateInspectTemplate()
		if template then
			Talented:OpenTemplate(template)
		end
	end

	function Talented:HookInspectUI()
		if not prev_script then
			prev_script = InspectFrameTab3:GetScript("OnClick")
			InspectFrameTab3:SetScript("OnClick", new_script)
		end
	end

	function Talented:UnhookInspectUI()
		if prev_script then
			InspectFrameTab3:SetScript("OnClick", prev_script)
			prev_script = nil
		end
	end

	function Talented:CheckHookInspectUI()
		self:RegisterEvent("INSPECT_TALENT_READY")
		if self.db.profile.hook_inspect_ui then
			if IsAddOnLoaded("Blizzard_InspectUI") then
				self:HookInspectUI()
			else
				self:RegisterEvent("ADDON_LOADED")
			end
		else
			if IsAddOnLoaded("Blizzard_InspectUI") then
				self:UnhookInspectUI()
			else
				self:UnregisterEvent("ADDON_LOADED")
			end
		end
	end

	function Talented:ADDON_LOADED(_, addon)
		if addon == "Blizzard_InspectUI" then
			self:UnregisterEvent("ADDON_LOADED")
			self.ADDON_LOADED = nil
			self:HookInspectUI()
		end
	end

	function Talented:GetInspectUnit()
		return InspectFrame and InspectFrame.unit
	end

	function Talented:UpdateInspectTemplate()
		local unit = self:GetInspectUnit()
		if not unit then return end
		local name = UnitName(unit)
		if not name then return end
		local inspections = self.inspections or {}
		self.inspections = inspections
		local class = select(2, UnitClass(unit))
		local info = self:UncompressSpellData(class)
		local retval
		for talentGroup = 1, GetNumTalentGroups(true) do
			local template_name = name .. " - " .. tostring(talentGroup)
			local template = inspections[template_name]
			if not template then
				template = {
					name = L["Inspection of %s"]:format(name) .. (talentGroup == GetActiveTalentGroup(true) and "" or L[" (alt)"]),
					class = class
				}
				for tab, tree in ipairs(info) do
					template[tab] = {}
				end
				inspections[template_name] = template
			else
				self:UnpackTemplate(template)
			end
			for tab, tree in ipairs(info) do
				for index = 1, #tree do
					local rank = select(5, GetTalentInfo(tab, index, true, nil, talentGroup))
					template[tab][index] = rank
				end
			end
			if not self:ValidateTemplate(template) then
				inspections[template_name] = nil
			else
				local found
				for _, view in self:IterateTalentViews(template) do
					view:Update()
					found = true
				end
				if not found then
					self:PackTemplate(template)
				end
				if talentGroup == GetActiveTalentGroup(true) then
					retval = template
				end
			end
		end
		return retval
	end

	Talented.INSPECT_TALENT_READY = Talented.UpdateInspectTemplate
end

-------------------------------------------------------------------------------
-- pet.lua
--

do
	function Talented:FixPetTemplate(template)
		local data = self:UncompressSpellData(template.class)[1]
		for index = 1, #data - 1 do
			local info = data[index]
			local ninfo = data[index + 1]
			if info.row == ninfo.row and info.column == ninfo.column then
				local talent = not info.inactive
				local value = template[1][index] + template[1][index + 1]
				if talent then
					template[1][index] = value
					template[1][index + 1] = 0
				else
					template[1][index] = 0
					template[1][index + 1] = value
				end
			end
		end
	end

	function Talented:GetPetClass()
		local _, _, _, texture = GetTalentTabInfo(1, nil, true)
		return texture and texture:sub(10)
	end

	local function PetTalentsAvailable()
		local talentGroup = GetActiveTalentGroup(nil, true)
		if not talentGroup then return end
		local has_talent = GetTalentInfo(1, 1, nil, true, talentGroup) or GetTalentInfo(1, 2, nil, true, talentGroup)
		return has_talent
	end

	function Talented:PET_TALENT_UPDATE()
		local class = self:GetPetClass()
		if not class or not PetTalentsAvailable() then return end
		self:FixAlternatesTalents(class)
		local template = self.pet_current
		if not template then
			template = {pet = true, name = TALENT_SPEC_PET_PRIMARY}
			self.pet_current = template
		end
		local talentGroup = GetActiveTalentGroup(nil, true)
		template.talentGroup = talentGroup
		template.class = class
		local info = self:UncompressSpellData(class)
		for tab, tree in ipairs(info) do
			local ttab = template[tab]
			if not ttab then
				ttab = {}
				template[tab] = ttab
			end
			for index in ipairs(tree) do
				ttab[index] = select(5, GetTalentInfo(tab, index, nil, true, talentGroup))
			end
		end
		for _, view in self:IterateTalentViews(template) do
			view:SetClass(class)
			view:Update()
		end
		if self.mode == "apply" then
			self:CheckTalentPointsApplied()
		end
	end

	function Talented:UNIT_PET(_, unit)
		if unit == "player" then
			self:PET_TALENT_UPDATE()
		end
	end

	function Talented:InitializePet()
		self:RegisterEvent("UNIT_PET")
		self:RegisterEvent("PET_TALENT_UPDATE")
		self:PET_TALENT_UPDATE()
	end

	function Talented:FixAlternatesTalents(class)
		local talentGroup = GetActiveTalentGroup(nil, true)
		local data = self:UncompressSpellData(class)[1]
		for index = 1, #data - 1 do
			local info = data[index]
			local ninfo = data[index + 1]
			if info.row == ninfo.row and info.column == ninfo.column then
				local talent = GetTalentInfo(1, index, nil, true, talentGroup)
				local ntalent = GetTalentInfo(1, index + 1, nil, true, talentGroup)
				if talent then
					assert(not ntalent)
					info.inactive = nil
					ninfo.inactive = true
				else
					assert(ntalent)
					info.inactive = true
					ninfo.inactive = nil
				end
				for _, template in pairs(self.db.global.templates) do
					if template.class == class and not template.code then
						local value = template[1][index] + template[1][index + 1]
						if talent then
							template[1][index] = value
							template[1][index + 1] = 0
						else
							template[1][index] = 0
							template[1][index + 1] = value
						end
					end
				end
			end
		end
		for _, view in self:IterateTalentViews() do
			if view.class == class then
				view:SetClass(view.class, true)
			end
		end
	end
end

-------------------------------------------------------------------------------
-- whpet.lua
--

do
	local WH_MAP = "0zMcmVokRsaqbdrfwihuGINALpTjnyxtgevE"
	local WH_PET_INFO_CLASS = "FFCTTTFTT FF       TT  CFCC  CCTCCC FCF CTTFFF"

	local TALENTED_MAP = "012345abcdefABCDEFmnopqrMNOPQRtuvwxy*"
	local TALENTED_CLASS_CODE = {
		F = "Ferocity",
		C = "Cunning",
		T = "Tenacity",
		Ferocity = "t",
		Cunning = "w",
		Tenacity = "*",
		["t"] = "Ferocity",
		["w"] = "Cunning",
		["*"] = "Tenacity"
	}

	function Talented:GetPetClassByFamily(index)
		return TALENTED_CLASS_CODE[WH_PET_INFO_CLASS:sub(index, index)]
	end

	local function GetPetFamilyForClass(class)
		return WH_PET_INFO_CLASS:find(class:sub(1, 1), nil, true)
	end

	local function map(code, src, dst)
		local temp = {}
		for i = 1, string.len(code) do
			local index = assert(src:find(code:sub(i, i), nil, true))
			temp[i] = dst:sub(index, index)
		end
		return table.concat(temp)
	end

	local function ImportCode(code)
		local a = (WH_MAP:find(code:sub(1, 1), nil, true) - 1) * 10
		local b = (WH_MAP:find(code:sub(2, 2), nil, true) - 1) / 2
		local family = a + math.floor(b)
		local class = Talented:GetPetClassByFamily(family)

		return TALENTED_CLASS_CODE[class] .. map(code:sub(3), WH_MAP, TALENTED_MAP)
	end

	local function ExportCode(code)
		local class = TALENTED_CLASS_CODE[code:sub(1, 1)]
		local family = GetPetFamilyForClass(class)

		local a = math.floor(family / 10)
		local b = (family - (a * 10)) * 2 + 1
		return WH_MAP:sub(a + 1, a + 1) .. WH_MAP:sub(b, b) .. map(code:sub(2), TALENTED_MAP, WH_MAP)
	end

	local function FixImportTemplate(self, template)
		local data = self:UncompressSpellData(template.class)[1]
		template = template[1]
		for index, info in ipairs(data) do
			if info.inactive then
				if index > 1 and info.row == data[index - 1].row and info.column == data[index - 1].column then
					template[index - 1] = template[index] + template[index - 1]
				elseif index < #data and info.row == data[index + 1].row and info.column == data[index + 1].column then
					template[index + 1] = template[index] + template[index + 1]
				end
			end
		end
	end

	local function FixExportTemplate(self, template)
		local data = self:UncompressSpellData(template.class)[1]
		template = template[1]
		for index, info in ipairs(data) do
			if info.inactive then
				if index > 1 and info.row == data[index - 1].row and info.column == data[index - 1].column then
					template[index - 1] = template[index] + template[index - 1]
				end
			end
		end
	end

	Talented.importers["/%??petcalc#"] = function(self, url, dst)
		local s, _, code = url:find(".*/%??petcalc#(.*)$")
		if not s or not code then return end
		code = ImportCode(code)
		if not code then return end
		local val, class = self:StringToTemplate(code, dst)
		dst.class = class
		FixImportTemplate(self, dst)
		return dst
	end

	function Talented:ExportWhpetTemplate(template, url)
		if RAID_CLASS_COLORS[template.class] then return end
		FixExportTemplate(self, template)
		local code = ExportCode(self:TemplateToString(template))
		FixImportTemplate(self, template)
		if code then
			url = url or "https://wotlk.evowow.com/?petcalc#%s"
			return url:format(code)
		end
	end
end