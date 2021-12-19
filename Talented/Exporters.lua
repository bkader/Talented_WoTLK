local Talented = _G.Talented
local L = LibStub("AceLocale-3.0"):GetLocale("Talented")
local ipairs, tonumber = ipairs, tonumber
local RAID_CLASS_COLORS = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS

-------------------------------------------------------------------------------
-- Common
--

Talented.importers[".*/(.*)/talents%..-%?t?a?l?=?(%d+)$"] = function(self, url, dst)
	local s, _, class, src = url:find(".*/(.*)/talents%..-%?t?a?l?=?(%d+)$")
	if not s then return end

	dst.class = class:upper()
	local count = 1
	local info = self:UncompressSpellData(dst.class)
	local len = src:len()

	for tab, tree in ipairs(info) do
		local t = {}
		dst[tab] = t
		for index = 1, #tree do
			t[index] = tonumber(src:sub(count, count))
			count = count + 1
			if count > len then
				break
			end
		end
	end
	return dst
end

Talented.importers["/%??talent#"] = function(self, url, dst)
	local s, _, code = url:find(".*/%??talent#(.*)$")
	if not s or not code then return end
	local p = code:find(":", nil, true)
	if p then
		code = code:sub(1, p - 1)
	end
	local val, class = self:StringToTemplate(code, dst, "0zMcmVokRsaqbdrfwihuGINALpTjnyxtgevE")
	dst.class = class
	return dst
end

-------------------------------------------------------------------------------
-- WoTLKDB
--

Talented.exporters["WoTLKDB"] = function(self, template)
	if not RAID_CLASS_COLORS[template.class] then
		return self:ExportWhpetTemplate(template, "https://www.wotlkdb.com/?petcalc#%s")
	end
	return ("https://www.wotlkdb.com/?talent#%s"):format(self:TemplateToString(template, "0zMcmVokRsaqbdrfwihuGINALpTjnyxtgevE"))
end

-------------------------------------------------------------------------------
-- EvoWOW
--

Talented.exporters["EvoWoW"] = function(self, template)
	if not RAID_CLASS_COLORS[template.class] then
		return self:ExportWhpetTemplate(template, "https://wotlk.evowow.com/?petcalc#%s")
	end
	return ("https://wotlk.evowow.com/?talent#%s"):format(self:TemplateToString(template, "0zMcmVokRsaqbdrfwihuGINALpTjnyxtgevE"))
end

-------------------------------------------------------------------------------
-- TrueWoW
--

Talented.importers[".*/talent%-calculator#"] = function(self, url, dst)
	local s, _, code = url:find(".*/talent%-calculator#(.*)$")
	if not s or not code then return end
	local p = code:find(":", nil, true)
	if p then
		code = code:sub(1, p - 1)
	end
	local val, class = self:StringToTemplate(code, dst, "0zMcmVokRsaqbdrfwihuGINALpTjnyxtgevE")
	dst.class = class
	return dst
end

Talented.exporters["TrueWoW"] = function(self, template)
	if not RAID_CLASS_COLORS[template.class] then
		return self:ExportWhpetTemplate(template)
	end
	return ("https://truewow.org/talent-calculator#%s"):format(self:TemplateToString(template, "0zMcmVokRsaqbdrfwihuGINALpTjnyxtgevE"))
end

-------------------------------------------------------------------------------
-- Altervista
--

Talented.importers["rpgworld%.altervista%.org/335/"] = function(self, url, dst)
	local s, _, class, src = url:find(".*rpgworld%.altervista%.org/335/([^=]+)%.php%?([0-5]+)")
	if not s then return end

	dst.class = class:upper()
	local count = 1
	local info = self:UncompressSpellData(dst.class)
	local len = src:len()

	for tab, tree in ipairs(info) do
		local t = {}
		dst[tab] = t
		for index = 1, #tree do
			t[index] = tonumber(src:sub(count, count))
			count = count + 1
			if count > len then
				break
			end
		end
	end
	return dst
end

Talented.exporters["Altervista"] = function(self, template)
	if not RAID_CLASS_COLORS[template.class] then
		return self:ExportWhpetTemplate(template)
	end
	local s = {}
	for _, tree in ipairs(template) do
		for _, n in ipairs(tree) do
			s[#s + 1] = tostring(n)
		end
	end
	return ("http://rpgworld.altervista.org/335/%s.php?%s"):format(template.class:lower(), table.concat(s))
end