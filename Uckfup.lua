--[[ 
	Uckfup, Mayen/Selari/Dayliss from Illidan (US) PvP
]]

Uckfup = LibStub("AceAddon-3.0"):NewAddon("Uckfup", "AceEvent-3.0")

local L = UckfupLocals

function Uckfup:ADDON_LOADED(event, addon)
	if( addon ~= "Uckfup" ) then return end
	self.frame:UnregisterEvent("ADDON_LOADED")
	self.frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	self.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	self.spells = UckfupSpells
	
	UckfupDB = UckfupDB or {enabled = true, report = "RAID", reportType = "main"}
end

local COMBATLOG_OBJECT_REACTION_HOSTILE	= COMBATLOG_OBJECT_REACTION_HOSTILE
local COMBATLOG_OBJECT_AFFILIATION_MINE = COMBATLOG_OBJECT_AFFILIATION_MINE
local eventRegistered = {["SPELL_DAMAGE"] = true, ["SPELL_INTERRUPT"] = true, ["SPELL_DISPEL"] = true, ["SPELL_AURA_APPLIED"] = true}
function Uckfup:COMBAT_LOG_EVENT_UNFILTERED(event, timestamp, eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, ...)
	if( not eventRegistered[eventType] ) then
		return
	end
	
	-- Aura applied
	if( event == "SPELL_AURA_APPLIED" ) then
		local spellID, spellName, spellSchool, auraType = ...
	
	-- Energizer bunny
	elseif( event == "SPELL_ENERGIZE" ) then
		local spellID, spellName, spellSchool, amount = ...
	
	-- Damage >:(
	elseif( eventType == "SPELL_DAMAGE" ) then
		local spellID, spellName, spellSchool, amount = ...

	-- We got interrupted, or we interrupted someone else
	-- In both SPELL_INTERRUPT and SPELL_DISPEL, the extra* args are the spell that was affected, the first ones are the spell used
	elseif( eventType == "SPELL_INTERRUPT" ) then
		local spellID, spellName, spellSchool, extraSpellID, extraSpellName, extraSpellSchool = ...
		
	-- Managed to dispel or steal a buff
	elseif( eventType == "SPELL_DISPEL" ) then
		local spellID, spellName, spellSchool, extraSpellID, extraSpellName, extraSpellSchool = ...
	end
end

function Uckfup:GetMobID(guid)
	return tonumber(string.sub(guid, 8, 12), 16)
end

-- Random enabler
function Uckfup:ZONE_CHANGED_NEW_AREA()
	if( not UckfupDB.enabled or select(2, IsInInstance()) ~= "raid" ) then
		self.frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	else
		self.frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	end
end

function Uckfup:PLAYER_ENTERING_WORLD()
	self:ZONE_CHANGED_NEW_AREA()
end

function Uckfup:Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Uckfup|r: " .. msg)
end

function Uckfup:Echo(msg)
	DEFAULT_CHAT_FRAME:AddMessage(msg)
end

-- Slash command
SLASH_UCKFUP1 = "/uckfup"
SLASH_UCKFUP2 = "/failbot"
SLASH_UCKFUP3 = "/fail"
SlashCmdList["UCKFUP"] = function(msg)
	local self = Uckfup
	local cmd, arg = string.split(" ", msg or "", 2)
	cmd = string.lower(cmd or "")
	
	if( cmd == "report" ) then
		if( tonumber(cmd) ) then
			UckfupDB.report = cmd
			UckfupDB.reportType = "chat"
			self:Print(string.format(L["Now reporting fails to chat frame #%s."], cmd))
		elseif( cmd == "raid" or cmd == "party" or cmd == "guid" or cmd == "officer" or cmd == "say" ) then
			UckfupDB.report = cmd
			UckfupDB.reportType = "main"
			self:Print(string.format(L["Now reporting fails to %s chat."], cmd))
		else
			UckfupDB.report = cmd
			UckfupDB.reportType = "channel"
			self:Print(string.format(L["Now reporting fails to channel %s."], cmd))
		end
	elseif( cmd == "toggle" ) then
		UckfupDB.enabled = not UckfupDB.enanled
		self:ZONE_CHANGED_NEW_AREA()
		
		if( UckfupDB.enabled ) then
			self:Print(L["Uckfup is now enabled, you will need to type /fail toggle to disable it."])
		else
			self:Print(L["Uckfup is now disabled, you will need to type /fail toggle to enable it."])
		end
	else
		self:Print(L["Slash commands"])
		self:Echo(L["/fail report <channel> - Channel to report to, supports RAID/PARTY/SAY/GUILD/OFFICER/Channel name/Chat frame #"])
		self:Echo(L["/fail toggle - Toggles if this mod is enabled."])
	end
end

-- Event handler
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, ...)
	Uckfup[event](Uckfup, event, ...)
end)

Uckfup.frame = frame