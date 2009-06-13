--[[ 
	Uckfup, Mayen/Selari from Illidan (US) PvP
]]

Uckfup = {}

local L = UckfupLocals
local mobGUIDMap = {}

-- Resets all data we were saving, this works out well because technically the mod is disabled whenever you release
-- it's pretty reliable that at some point, you will release and the stored data can be reset, odds are if you one don't die a few times
-- you probably aren't failing that much and it's needed
function Uckfup:ResetData()
	self.frame.announcements = 0

	for k in pairs(self.ticks) do self.ticks[k] = nil end
	for k in pairs(self.reported) do self.reported[k] = nil end
	for k in pairs(self.lastEvents) do self.lastEvents[k] = nil end
	for k in pairs(self.sendTimeouts) do self.sendTimeouts[k] = nil end
	for k in pairs(self.lastTick) do self.lastTick[k] = nil end
	for k in pairs(self.attackFails) do self.attackFails[k] = nil end
	for k in pairs(mobGUIDMap) do mobGUIDMap[k] = nil end
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
	if( not IsAddOnLoaded("Uckfup") ) then return end
	UckfupDB = UckfupDB or {enabled = true, report = "RAID", reportType = "main"}
	UckfupDB.disabled = UckfupDB.disabled or {[64190] = true}
	UckfupDB.reportTimeout = UckfupDB.reportTimeout or 5
	
	self.spells = {}
	self.auras = {}
	self.attacks = {}
	self.lastEvents = {}
	self.lastTick = {}
	self.reported = {}
	self.ticks = {}
	self.sendTimeouts = {}
	self.sendQueue = {}
	self.attackFails = {}
	
	self.frame:UnregisterEvent("ADDON_LOADED")
	self.frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	self.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	self.frame:SetScript("OnUpdate", OnUpdate)
	self.frame.announceElapsed = 0
	self.frame.announcements = 0
	self.frame:Hide()

	-- Load our DB in and add spell info and stuff
	for spellID, fail in pairs(UckfupSpells) do
		fail.spellID = spellID
		fail.disabled = UckfupDB.disabled[spellID]
		fail.boss = fail.boss or L["Unknown"]
		
		local name = GetSpellInfo(spellID)
		if( fail.type == "AURA" ) then
			self.auras[name] = fail
		elseif( fail.type == "SWAP" ) then
			self.attacks[name] = fail
		else
			self.spells[name] = fail
		end
	end
end

function Uckfup:UpdateStatus()
	for spellID, fail in pairs(UckfupSpells) do
		fail.disabled = UckfupDB.disabled[spellID]
	end
end

local chatFrames = {}
function Uckfup:TriggerFail(id, throttle, destGUID, destName, spellName, noSpam)
	if( throttle and self.reported[id] and self.reported[id] > GetTime() ) then
		return
	elseif( throttle ) then
		self.reported[id] = GetTime() + throttle
	end
		
	-- Start our timeout before reporting the list of bads
	if( not self.sendTimeouts[spellName] ) then
		self.sendTimeouts[spellName] = GetTime() + (noSpam and 0 or UckfupDB.reportTimeout)
		self.frame.announcements = self.frame.announcements + 1
	end

	-- Add them to the list
	self.sendQueue[spellName] = self.sendQueue[spellName] or {}
	table.insert(self.sendQueue[spellName], destName)

	-- Start watching
	self.frame:Show()
end

local tempFail = {}
function Uckfup:PrintFail(spellName)
	-- Make sure we have something to announce of course.
	if( not self.sendQueue[spellName] or #(self.sendQueue[spellName]) == 0 ) then
		return
	end
	
	-- Load all of the fails into a single table so we can show how many times they failed, if they failed multiple times before we printed
	for k in pairs(tempFail) do tempFail[k] = nil end
	for _, name in pairs(self.sendQueue[spellName]) do
		tempFail[name] = (tempFail[name] or 0) + 1
	end
	
	local nameList
	for name, count in pairs(tempFail) do
		if( nameList ) then
			if( count > 1 ) then
				nameList = string.format("%s, %s (%d)", nameList, name, count)
			else
				nameList = string.format("%s, %s", nameList, name)
			end
		elseif( count > 1 ) then
			nameList = string.format("%s (%d)", name, count)
		else
			nameList = name
		end
	end
	
	local msg = string.format(L["%s failed at %s"], nameList or "????", spellName)
	
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

-- Check for aura fails
function Uckfup:UNIT_AURA(event, unit)
	if( not UnitIsPlayer(unit) ) then
		return
	end
	
	for spellName, spellData in pairs(self.auras) do
		local name, _, _, count = UnitDebuff(unit, spellName)
		if( name and ( not spellData.stacks or ( count and count >= spellData.stacks ) ) ) then
			local guid, name = UnitGUID(unit), UnitName(unit)
			self:TriggerFail(guid .. spellName, spellData.throttle, guid, name, spellName)
			break
		end
	end
end

-- Check for combatlog fails
local COMBATLOG_OBJECT_TYPE_PLAYER = COMBATLOG_OBJECT_TYPE_PLAYER
local COMBATLOG_OBJECT_TYPE_GUARDIAN = COMBATLOG_OBJECT_TYPE_GUARDIAN
local eventRegistered = {["SPELL_AURA_APPLIED_DOSE"] = true, ["SPELL_DAMAGE"] = true, ["SPELL_INTERRUPT"] = true, ["SPELL_ENERGIZE"] = true, ["SPELL_DISPEL"] = true, ["SPELL_PERIODIC_DAMAGE"] = true}
function Uckfup:COMBAT_LOG_EVENT_UNFILTERED(event, timestamp, eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, ...)
	if( not eventRegistered[eventType] or bit.band(sourceFlags, COMBATLOG_OBJECT_TYPE_GUARDIAN) > 0 or bit.band(destFlags, COMBATLOG_OBJECT_TYPE_GUARDIAN) > 0 ) then
		return
	end
	
	-- Aura stacks change
	if( eventType == "SPELL_AURA_APPLIED_DOSE" and bit.band(sourceFlags, COMBATLOG_OBJECT_TYPE_NPC) > 0 ) then
		local spellID, spellName, spellSchool, auraType, stacks = ...
		local spellData = self.attacks[spellName]
		if( spellData and not spellData.disabled and spellData.event == eventType and auraType == spellData.auraType and spellData.mob == self:GetMobID(sourceGUID) ) then
			if( stacks >= spellData.stopAt ) then
				self.attackFails[spellData.mob] = spellName
			end
		end
	
	-- Aura faded
	elseif( eventType == "SPELL_AURA_REMOVED" and bit.band(sourceFlags, COMBATLOG_OBJECT_TYPE_NPC) > 0 ) then
		local spellID, spellName, spellSchool, auraType = ...
		local spellData = self.attacks[spellName]
		if( spellData and not spellData.disabled and spellData.event == eventType and auraType == spellData.auraType and spellData.mob == self:GetMobID(sourceGUID) ) then
			self.attackFails[spellData.mob] = nil
		end
		
	-- Periodic ticks
	elseif( eventType == "SPELL_PERIODIC_DAMAGE" and bit.band(destFlags, COMBATLOG_OBJECT_TYPE_PLAYER) > 0 ) then
		local spellID, spellName, spellSchool, auraType = ...
		local spellData = self.spells[spellName]
		if( spellData and not spellData.disabled and spellData.event == eventType ) then
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
				self:TriggerFail(id, spellData.throttle, destGUID, destName, spellName, spellData.noSpam)
			end
		end
				
	-- Damage >:( + Energizer Bunny :)
	elseif( eventType == "SPELL_DAMAGE" or eventType == "SPELL_ENERGIZE" ) then
		local spellID, spellName, spellSchool, amount = ...
		
		-- Check for attack fails
		if( bit.band(sourceFlags, COMBATLOG_OBJECT_TYPE_PLAYER) > 0 and bit.band(destFlags, COMBATLOG_OBJECT_TYPE_NPC) > 0 ) then
			local mobID = self:GetMobID(destGUID)
			if( mobID and self.attackFails[mobID] ) then
				local spellData = self.attacks[self.attackFails[mobID]]
				local failSpell = self.attackFails[mobID]
				if( spellData ) then
					self:TriggerFail(failSpell .. destGUID, spellData.throttle, sourceGUID, sourceName, failSpell, spellData.noSpam)
					return
				end
			end
		end
		
		-- Check for spell fails
		local spellData = self.spells[spellName]
		if( spellData and not spellData.disabled and spellData.event == eventType ) then
			local byPlayer = bit.band(sourceFlags, COMBATLOG_OBJECT_TYPE_PLAYER) > 0
			
			-- The person who did the event isn't a player, and the target of the event isn't a player either.
			if( not byPlayer and bit.band(destFlags, COMBATLOG_OBJECT_TYPE_PLAYER) == 0 ) then
				return
			end
						
			-- If it's done by a player, it obviously wasn't done by a mob so it's fine, if we have no mob data we don't care where it came from, if we DO have mob data
			-- then will filter and make sure it's good
			if( byPlayer or not spellData.mob or ( ( spellData.mob and spellData.mob == self:GetMobID(sourceGUID ) ) or ( spellData.secondMob and spellData.secondMob == self:GetMobID(sourceGUID) ) ) ) then
				-- Figure out what variables to use
				local name, guid, flag = sourceName, sourceGUID
				if( not byPlayer ) then
					name, guid = destName, destGUID
				end
				
				-- Damage is by a player, the spell is flagged to ignore any charges gained through their self inflicted damage (Emo people)
				if( byPlayer and spellData.skipPlayer and destGUID == sourceGUID ) then
					return
				end
								
				local id = spellName .. guid
				local time = GetTime()
				
				-- Check for data expiration
				if( self.lastEvents[id] and self.lastEvents[id] <= time ) then
					self.lastEvents[id] = nil
					self.ticks[id] = nil
				end
				
				-- If it's a damaging event, add up the misc thing that changes our total number
				if( eventType == "SPELL_DAMAGE" ) then
					local overkill, _, resisted, _, blocked, absorbed = select(5, ...)
					amount = amount + (overkill or 0) + (resisted or 0) + (blocked or 0) + (absorbed or 0)
				end
				
				-- Either no threshold on damage/regen, or we exceeded the amount
				if( not spellData.threshold or spellData.threshold <= amount ) then
					-- Throttle how quickly charges count up
					if( spellData.hitThrottle ) then
						if( self.lastTick[id] and self.lastTick[id] > time ) then
							return
						end
						
						self.lastTick[id] = time + spellData.hitThrottle
					end
										
					self.lastEvents[id] = time + (spellData.hitExpires or spellData.throttle or 30)
					self.ticks[id] = (self.ticks[id] or 0) + 1

					-- Either no rqeuired number of hits before whining, or we exceeded it.
					if( not spellData.hits or self.ticks[id] >= spellData.hits ) then
						self:TriggerFail(id, spellData.throttle, guid, name, spellName, spellData.noSpam)
						self.ticks[id] = nil
					end
				end
			end
		end

	-- We got interrupted, or we interrupted someone else
	-- In both SPELL_INTERRUPT and SPELL_DISPEL, the extra* args are the spell that was affected, the first ones are the spell used
	elseif( eventType == "SPELL_INTERRUPT" and bit.band(destFlags, COMBATLOG_OBJECT_TYPE_PLAYER) > 0 ) then
		local spellID, spellName, spellSchool, extraSpellID, extraSpellName, extraSpellSchool = ...
		local spellData = self.spells[spellName]
		if( spellData and not spellData.disabled and spellData.event == eventType ) then
			self:TriggerFail(id, spellData.throttle, destGUID, destName, spellName, spellData.noSpam)
		end
		
	-- Managed to dispel or steal a buff
	elseif( eventType == "SPELL_DISPEL" and bit.band(destFlags, COMBATLOG_OBJECT_TYPE_PLAYER) > 0 ) then
		local spellID, spellName, spellSchool, extraSpellID, extraSpellName, extraSpellSchool = ...
		local spellData = self.spells[spellName]
		if( spellData and not spellData.disabled and spellData.event == eventType ) then
			self:TriggerFail(id, spellData.throttle, destGUID, destName, extraSpellName, spellData.noSpam)
		end
	end
end

function Uckfup:GetMobID(guid)
	if( mobGUIDMap[guid] ) then return mobGUIDMap[guid] end
	mobGUIDMap[guid] = tonumber(string.sub(guid, 8, 12), 16)
	return mobGUIDMap[guid]
end

-- Random enabler
function Uckfup:ZONE_CHANGED_NEW_AREA()
	if( not UckfupDB.enabled or select(2, IsInInstance()) ~= "raid" ) then
		self:ResetData()
		self.frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		self.frame:UnregisterEvent("UNIT_AURA")
		self.frame:Hide()
	else
		self.frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		self.frame:RegisterEvent("UNIT_AURA")
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
		local lowerArg = string.lower(arg)
		if( tonumber(arg) ) then
			UckfupDB.report = arg
			UckfupDB.reportType = "chat"
			self:Print(string.format(L["Now reporting fails to chat frame #%s."], arg))
		elseif( lowerArg == "raid" or lowerArg == "party" or lowerArg == "guild" or lowerArg == "officer" or lowerArg == "say" ) then
			UckfupDB.report = lowerArg
			UckfupDB.reportType = "main"
			self:Print(string.format(L["Now reporting fails to %s chat."],lowerArg))
		else
			UckfupDB.report = lowerArg
			UckfupDB.reportType = "channel"
			self:Print(string.format(L["Now reporting fails to channel %s."],lowerArg))
		end
	elseif( cmd == "toggle" ) then
		UckfupDB.enabled = not UckfupDB.enabled
		self:ZONE_CHANGED_NEW_AREA()
		
		if( UckfupDB.enabled ) then
			self:Print(L["Uckfup is now enabled, you will need to type /fail toggle to disable it."])
		else
			self:Print(L["Uckfup is now disabled, you will need to type /fail toggle to enable it."])
		end
	elseif( cmd == "timeout" and arg ) then
		UckfupDB.timeout = tonumber(arg) or 5
		self:Print(string.format(L["Set fail grouping to %d seconds before output."], UckfupDB.timeout))
	elseif( arg and ( cmd == "enable" or cmd == "disable" ) ) then
		local setStatus = cmd == "disable" and true or nil
		local setString = setStatus and L["%d spells disabled: %s"] or L["%d spells enabled: %s"]
		local list = {}
		
		local scanArg = string.lower(arg)
		local bossName
		for spellID, spell in pairs(UckfupSpells) do
			local name = GetSpellInfo(spellID)
			if( string.lower(name) == scanArg or string.lower(spell.boss) == scanArg ) then
				bossName = spell.boss
				UckfupDB.disabled[spellID] = setStatus

				if( UckfupDB.disabled[spellID] ) then
					table.insert(list, string.format("%s|Hspell:%d|h[%s]|h|r", RED_FONT_COLOR_CODE, spellID, name))
				else
					table.insert(list, string.format("|cff71d5ff|Hspell:%d|h[%s]|h|r", spellID, name))
				end
			end
		end
		
		if( #(list) > 1 ) then
			self:Echo(string.format("|cff33ff99%s|r", bossName))
			self:Echo(string.format(setString, #(list), table.concat(list, "")))
		elseif( #(list) == 1 ) then
			if( setStatus ) then
				self:Echo(string.format(L["Disabled spell %s on %s"], list[1], bossName))
			else
				self:Echo(string.format(L["Enabled spell %s on %s"], list[1], bossName))
			end
		else
			self:Echo(string.format(L["No spells found to enable or disable using the filter \"%s\""], arg))
		end
		
		self:UpdateStatus()
		
	elseif( cmd == "list" ) then
		self:Print(L["Listing current fail status"])
		
		local spells = {}
		for spellID, spell in pairs(UckfupSpells) do
			if( not arg or string.lower(spell.boss) == string.lower(arg) ) then
				spells[spell.boss] = spells[spell.boss] or {}

				local name = GetSpellInfo(spellID)
				if( UckfupDB.disabled[spellID] ) then
					table.insert(spells[spell.boss], string.format("%s|Hspell:%d|h[%s]|h|r", RED_FONT_COLOR_CODE, spellID, name))
				else
					table.insert(spells[spell.boss], string.format("|cff71d5ff|Hspell:%d|h[%s]|h|r", spellID, name))
				end
			end
		end
		
		for boss, list in pairs(spells) do
			if( #(list) > 3 ) then
				self:Echo(string.format(L["|cff33ff99%s|r (%d fails)"], boss, #(list)))
				self:Echo(table.concat(list, ", "))
			else
				self:Echo(string.format(L["|cff33ff99%s|r (%d fails)"] .. ": %s", boss, #(list), table.concat(list, "")))
			end
		end
	else
		self:Print(L["Slash commands"])
		self:Echo(L["/fail report <channel> - Channel to report to, supports raid/party/say/guild/officer/Channel name/Chat frame 1 - 7"])
		self:Echo(L["/fail toggle - Toggles if this mod is enabled."])
		self:Echo(L["/fail enable <name/boss> - Enables a fail, if you pass the boss name then all fails for that boss are enabled."])
		self:Echo(L["/fail disable <name/boss> - Disables a fail, if you pass the boss name then all fails for that boss are disabled."])
		self:Echo(L["/fail list <boss> - Lists the status of all fails if they are enabled or disabled, optional you can pass the boss name to show only his fails."])
		self:Echo(L["/fail timeout <seconds> - How many seconds to wait before outputting failures, this reduces spam when multiple people can fail at the same time."])
		self:Echo(L["Spell name is the spell of the fail you see in chat (and the one in /fail list), boss is the full boss name so Ignis the Furnace Master or XT-002 Deconstructor."])
	end
end

-- Event handler
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, ...)
	Uckfup[event](Uckfup, event, ...)
end)

Uckfup.frame = frame