--[[ 
	Uckfup, Mayen/Selari from Illidan (US) PvP
]]

Uckfup = {}

local L = UckfupLocals
local REPORT_TIMEOUT = 5

-- Resets all data we were saving, this works out well because technically the mod is disabled whenever you release
-- it's pretty reliable that at some point, you will release and the stored data can be reset, odds are if you one don't die a few times
-- you probably aren't failing that much and it's needed
function Uckfup:ResetData()
	self.frame.announcements = 0

	for k in pairs(self.ticks) do self.ticks[k] = nil end
	for k in pairs(self.reported) do self.reported[k] = nil end
	for k in pairs(self.lastEvents) do self.lastEvents[k] = nil end
	for k in pairs(self.sendTimeouts) do self.sendTimeouts[k] = nil end
	for _, list in pairs(self.sendQueue) do for i=#(list), 1, -1 do table.remove(list, i) end end
end

-- This is just a simple collector that prunes any old data every 10 minutes
-- also handles outputting failures
local function OnUpdate(self, elapsed)
	-- Check if any of the announcements timed out
	self.announceElapsed = self.announceElapsed + elapsed
	if( self.announceElapsed >= 1 ) then
		self.announceElapsed = 0
		
		local time = GetTime()
		for spellName, timeout in pairs(Uckfup.sendTimeouts) do
			if( timeout <= time ) then
				Uckfup:PrintFail(spellName)

				Uckfup.sendTimeouts[spellName] = nil
				self.announcements = self.announcements - 1
			end
		end
		
		-- Nothing left to announce
		if( self.announcements <= 0 ) then
			self:Hide()
		end
	end
end

function Uckfup:ADDON_LOADED(event, addon)
	if( addon ~= "Uckfup" ) then return end
	UckfupDB = UckfupDB or {enabled = true, report = "RAID", reportType = "main"}

	self.spells = UckfupSpells
	self.lastEvents = {}
	self.reported = {}
	self.ticks = {}
	self.sendTimeouts = {}
	self.sendQueue = {}
	
	self.frame:UnregisterEvent("ADDON_LOADED")
	self.frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	self.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	self.frame:SetScript("OnUpdate", OnUpdate)
	self.frame.announceElapsed = 0
	self.frame.announcements = 0
	self.frame:Hide()
end

local chatFrames = {}
function Uckfup:TriggerFail(id, throttle, destGUID, destName, spellName)
	if( throttle and self.reported[id] and self.reported[id] > GetTime() ) then
		return
	elseif( throttle ) then
		self.reported[id] = GetTime() + throttle
	end
	
	-- Start our timeout before reporting the list of bads
	if( not self.sendTimeouts[spellName] ) then
		self.sendTimeouts[spellName] = GetTime() + REPORT_TIMEOUT
		self.frame.announcements = self.frame.announcements + 1
	end

	-- Add them to the list
	self.sendQueue[spellName] = self.sendQueue[spellName] or {}
	table.insert(self.sendQueue[spellName], destName)

	-- Start watching
	self.frame:Show()
end

function Uckfup:PrintFail(spellName)
	-- Make sure we have something to announce of course.
	if( not self.sendQueue[spellName] or #(self.sendQueue[spellName]) == 0 ) then
		return
	end
	
	local msg = string.format(L["%s failed at %s"], table.concat(self.sendQueue[spellName], ", "), spellName)
	
	if( UckfupDB.reportType == "main" ) then
		SendChatMessage(msg, UckfupDB.report)
	elseif( UckfupDB.reportType == "chat" ) then
		local frame = chatFrames[UckfupDB.report] or getglobal("ChatFrame" .. UckfupDB.report) or DEFAULT_CHAT_FRAME
		frame:AddMessage(msg)
	elseif( UckfupDB.reportType == "channel" ) then
		local id = GetChannelName(UckfupDB.report)
		if( id and id > 0 ) then
			SendChatMessage(msg, "CHANNEL", nil, id)
		end
	end
	
	-- Reset list now
	for i=#(self.sendQueue[spellName]), 1, -1 do
		table.remove(self.sendQueue[spellName], i)
	end
end

local COMBATLOG_OBJECT_TYPE_PLAYER = COMBATLOG_OBJECT_TYPE_PLAYER
local eventRegistered = {["SPELL_DAMAGE"] = true, ["SPELL_INTERRUPT"] = true, ["SPELL_ENERGIZE"] = true, ["SPELL_DISPEL"] = true, ["SPELL_AURA_APPLIED"] = true, ["SPELL_PERIODIC_DAMAGE"] = true}
function Uckfup:COMBAT_LOG_EVENT_UNFILTERED(event, timestamp, eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, ...)
	if( not eventRegistered[eventType] ) then
		return
	end
	
	-- Aura applied
	if( eventType == "SPELL_AURA_APPLIED" and bit.band(destFlags, COMBATLOG_OBJECT_TYPE_PLAYER) == COMBATLOG_OBJECT_TYPE_PLAYER ) then
		local spellID, spellName, spellSchool, auraType = ...
		local spellData = self.spells[spellName]
		if( spellData and spellData.type == eventType and spellData.auraType == auraType ) then
			self:TriggerFail(id, spellData.throttle, destGUID, destName, spellName)
		end
		
	-- Periorid ticks
	elseif( eventType == "SPELL_PERIODIC_DAMAGE" and bit.band(destFlags, COMBATLOG_OBJECT_TYPE_PLAYER) == COMBATLOG_OBJECT_TYPE_PLAYER ) then
		local spellID, spellName, spellSchool, auraType = ...
		local spellData = self.spells[spellName]
		if( spellData and spellData.type == eventType ) then
			local id = spellName .. destGUID
			local time = GetTime()
			-- Check for data expiration
			if( self.lastEvents[id] and self.lastEvents[id] <= time ) then
				self.lastEvents[id] = nil
				self.ticks[id] = nil
			end
			
			-- Want data to experience eventually, so defaulting to 30 seconds
			self.lastEvents[id] = time + (spellData.throttle or 30)
			self.ticks[id] = (self.ticks[id] or 0) + 1

			-- Either we aren't throttling by ticks, or we exceeded the limit before data expired
			if( not spellData.ticks or self.ticks[id] >= spellData.ticks ) then
				self:TriggerFail(id, spellData.throttle, destGUID, destName, spellName)
			end
		end
		
	-- Damage >:( + Energizer Bunny :)
	elseif( eventType == "SPELL_DAMAGE" or eventType == "SPELL_ENERGIZE" ) then
		local spellID, spellName, spellSchool, amount = ...
		local spellData = self.spells[spellName]
		if( spellData and spellData.type == eventType ) then
			local byPlayer = bit.band(sourceFlags, COMBATLOG_OBJECT_TYPE_PLAYER) == COMBATLOG_OBJECT_TYPE_PLAYER
			
			-- If it's done by a player, it obviously wasn't done by a mob so it's fine, if we have no mob data we don't care where it came from, if we DO have mob data
			-- then will filter and make sure it's good
			if( byPlayer or not spellData.mob or ( ( spellData.mob and spellData.mob == self:GetMobID(sourceGUID ) ) or ( spellData.secondMob and spellData.secondMob == self:GetMobID(sourceGUID) ) ) ) then
				-- Figure out what variables to use
				local name, guid = sourceName, sourceGUID
				if( not byPlayer ) then
					name, guid = destName, destGUID
				end
				
				local id = spellName .. guid
				local time = GetTime()
				
				-- Check for data expiration
				if( self.lastEvents[id] and self.lastEvents[id] <= time ) then
					self.lastEvents[id] = nil
					self.ticks[id] = nil
				end
				
				-- Either no threshold on damage/regen, or we exceeded the amount
				if( not spellData.threshold or spellData.threshold <= amount ) then
					self.lastEvents[id] = time + (spellData.throttle or 30)
					self.ticks[id] = (self.ticks[id] or 0) + 1
					
					-- Either no rqeuired number of hits before whining, or we exceeded it.
					if( not spellData.hits or self.ticks[id] >= spellData.hits ) then
						self:TriggerFail(id, spellData.throttle, guid, name, spellName)
					end
				end
			end
		end

	-- We got interrupted, or we interrupted someone else
	-- In both SPELL_INTERRUPT and SPELL_DISPEL, the extra* args are the spell that was affected, the first ones are the spell used
	elseif( eventType == "SPELL_INTERRUPT" and bit.band(destFlags, COMBATLOG_OBJECT_TYPE_PLAYER) == COMBATLOG_OBJECT_TYPE_PLAYER ) then
		local spellID, spellName, spellSchool, extraSpellID, extraSpellName, extraSpellSchool = ...
		local spellData = self.spells[spellName]
		if( spellData and spellData.type == eventType ) then
			self:TriggerFail(id, spellData.throttle, destGUID, destName, spellName)
		end
		
	-- Managed to dispel or steal a buff
	elseif( eventType == "SPELL_DISPEL" and bit.band(destFlags, COMBATLOG_OBJECT_TYPE_PLAYER) == COMBATLOG_OBJECT_TYPE_PLAYER ) then
		local spellID, spellName, spellSchool, extraSpellID, extraSpellName, extraSpellSchool = ...
		local spellData = self.spells[spellName]
		if( spellData and spellData.type == eventType ) then
			self:TriggerFail(id, spellData.throttle, destGUID, destName, extraSpellName)
		end
	end
end

function Uckfup:GetMobID(guid)
	return tonumber(string.sub(guid, 8, 12), 16)
end

-- Random enabler
function Uckfup:ZONE_CHANGED_NEW_AREA()
	if( not UckfupDB.enabled or select(2, IsInInstance()) ~= "raid" ) then
		self:ResetData()
		self.frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		self.frame:Hide()
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
	
	if( cmd == "report" and arg ) then
		if( tonumber(arg) ) then
			UckfupDB.report = arg
			UckfupDB.reportType = "chat"
			self:Print(string.format(L["Now reporting fails to chat frame #%s."], arg))
		elseif( arg == "raid" or arg == "party" or arg == "guild" or arg == "officer" or arg == "say" ) then
			UckfupDB.report = arg
			UckfupDB.reportType = "main"
			self:Print(string.format(L["Now reporting fails to %s chat."], arg))
		else
			UckfupDB.report = arg
			UckfupDB.reportType = "channel"
			self:Print(string.format(L["Now reporting fails to channel %s."], arg))
		end
	elseif( cmd == "toggle" ) then
		UckfupDB.enabled = not UckfupDB.enabled
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