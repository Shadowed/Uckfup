--[[
	When possible, use GetSpellInfo(#) instead of straight spell name so it's localization independant
	
	Note that, throttle is accepted for all types, but mob/secondMob/hits/threshold are only supported for SPELL_DAMAGE/SPELLL_ENERGIZE
	hits is supported for SPELL_PERIODIC_DAMAGE as well, when you don't pass a throttle it'll default to 30 seconds.
	
	Format:
	-- The spellID is automatically converted to the spell name using GetSpellInfo(spellID)
	[spellID] = {
		-- This is used for special type of fails that need to be separated, aura fails are ones that check UnitAura directly
		-- and swap fails are ones that trigger based off of the fail aura triggering (Via combat log) then a direct damage attack happening to it.
		type = "AURA/SWAP", (Or nil)
		-- Combat event that this is triggered off of
		event = "SPELL_ENERGIZE/SPELL_DAMAGE/SPELL_AURA_APPLIED/SPELL_INTERRUPT/SPELL_DISPEL"
		-- Throttle (in seconds) only show this fail every X seconds
		throttle = 5,
		-- Mob ID/Mob Name, only show this fail if the source is from the passed mobID, in this case 32865 is Thorim http://www.wowhead.com/?npc=32865
		mob = 32865,
		-- Same as above, just lets you set another mob for it to fail off of
		secondMob = 32865,
		-- How many times this spell has to hit before it counts as a fail, 3 means once it hits 3 times total (Including the player + raid), it's a fail.
		hits = 3,
		-- How much damage/energize/etc needs to have happened before it counts as a fail
		threshold = 1000,
		-- How many seconds to throttle charges by, so 0.50 means that it will only add a new charge every 0.50 seconds
		hitThrottle = 0.50,
		-- This is an independant time that the charges will expire at in seconds, so 3 means after 3 seconds of no data, they reset.
		hitExpires = 3,
		-- Sets if the player should be ignored when setting charges
		skipPlayer = true/false,
		-- Indicates that the spell cannot be spammy, and should immeditiately be reported
		noSpam = true/false,
	}
]]

local L = UckfupLocals
UckfupSpells = {
	-- Ulduar: Flame Leviathan
	-- Hodir's Fury
	[62297] = {type = "AURA", boss = L["Flame Leviathan"], throttle = 10},
	-- Mimiron's Inferno
	[62910] = {boss = L["Flame Leviathan"], event = "SPELL_DAMAGE", hits = 2, throttle = 5},

	-- Ulduar: Razorscale
	-- Devouring Flame / 4/28 19:52:13.198  SPELL_DAMAGE,0x0000000000000000,nil,0x80000000,0x05000000027ED384,"Shinen",0x514,64733,"Devouring Flame",0x4,9471,0,4,1002,0,0,nil,nil,nil
	[64733] = {boss = L["Razorscale"], event = "SPELL_DAMAGE"},

	-- Ulduar: Ignis the Furnace Master
	-- Flame Jets / 3/16 19:50:05.275  SPELL_INTERRUPT,0x0000000000000000,nil,0x80000000,0x01000000007CED8E,"Mute",0x514,62681,"Flame Jets",0x4,49238,"Lightning Bolt",8	
	[62681] = {boss = L["Ignis the Furnace Master"], event = "SPELL_INTERRUPT"},
	-- Shatter
	[62383] = {boss = L["Ignis the Furnace Master"], event = "SPELL_DAMAGE"},
		
	-- Ulduar: XT-002 Deconstructor
	-- Light Bomb / 5/16 12:27:24.579 SPELL_DAMAGE,0x05000000007A7977,"Alithia",0x10514,0x05000000007A7977,"Alithia",0x10514,63023,"Light Bomb",0x42,2250,0,66,0,0,0,nil,nil,nil
	[63023] = {boss = L["XT-002 Deconstructor"], event = "SPELL_DAMAGE", hits = 3, noSpam = true, skipPlayer = true, hitThrottle = 0.50, hitExpires = 5, throttle = 5},
	-- Gravity Bomb
	[63024] = {boss = L["XT-002 Deconstructor"], event = "SPELL_DAMAGE", hits = 1, noSpam = true, skipPlayer = true, hitExpires = 1, throttle = 5},

	-- Ulduar: Iron Council
	-- Overload / 3/20 19:22:43.389  SPELL_DAMAGE,0xF130008059000703,"Stormcaller Brundir",0x8000a48,0x01000000007C5537,"Vanen",0x512,61878,"Overload",0x8,17460,0,8,2000,0,0,nil,nil,nil
	[61878] = {boss = L["Iron Council"], event = "SPELL_DAMAGE", mob = 32857},
	-- Rune of Death
	[63490] = {boss = L["Iron Council"], event = "SPELL_DAMAGE", hits = 5},
	
	-- Ulduar: Kologarn
	-- Focused Eyebeam / 5/20 18:57:00.527 SPELL_DAMAGE,0x0000000000000000,nil,0x80000000,0x05000000009E0446,"Tsurara",0x514,63976,"Focused Eyebeam",0x40,3014,0,64,346,0,0,nil,nil,nil
	[63976] = {boss = L["Kologarn"], event = "SPELL_DAMAGE", throttle = 5},

	-- Ulduar: Auriaya
	-- Seeping Feral Essence / 5/16 13:48:58.359 SPELL_DAMAGE,0x0000000000000000,nil,0x80000000,0x05000000013436F1,"Mordant",0x514,64459,"Seeping Feral Essence",0x20,3353,0,32,900,0,0,nil,nil,nil
	[64459] = {boss = L["Auriaya"], event = "SPELL_DAMAGE", throttle = 5},

	-- Ulduar: Hodir
	-- Ice Shards / 5/21 17:21:08.473  SPELL_DAMAGE,0xF130008191009ADF,"Icicle",0xa48,0x0500000002A13CA4,"Taec",0x512,62457,"Ice Shards",0x10,10864,0,16,2800,0,0,nil,nil,nil
	[62457] = {boss = L["Hodir"], event = "SPELL_DAMAGE", throttle = 5},
	-- Three or more stacks of Biting Cold
	[62039] = {type = "AURA", boss = L["Hodir"], stacks = 3, throttle = 10},
	-- Flash Freeze
	[61969] = {type = "AURA", boss = L["Hodir"], throttle = 10},

	-- Ulduar: Thorim
	-- Lightning Charge / 4/16 18:20:24.295  SPELL_DAMAGE,0xF130008061018374,"Thorim",0x8010a48,0x0500000001E8AF39,"Thefeint",0x514,62466,"Lightning Charge",0x8,8977,0,8,3966,0,0,nil,nil,nil
	[62466] = {boss = L["Thorim"], event = "SPELL_DAMAGE", mob = 32865},
	-- Runic Smash / 4/16 01:06:26.414  SPELL_DAMAGE,0x0000000000000000,nil,0x80000000,0x05000000027ECA9C,"Cn",0x514,62465,"Runic Smash",0x4,6544,0,4,3116,0,0,nil,nil,nil
	[62465] = {boss = L["Thorim"], event = "SPELL_DAMAGE", throttle = 5},

	-- Ulduar: Freya
	-- Hardened Bark / SPELL_AURA_APPLIED_DOSE,0xF13000809400BD3B,"Snaplasher",0xa48,0xF13000809400BD3B,"Snaplasher",0xa48,64190,"Hardened Bark",0x1,BUFF,3
	[64190] = {type = "SWAP", boss = L["Freya"], event = "SPELL_AURA_APPLIED_DOSE", mob = 32916, stopAt = 30, throttle = 10, auraType = "BUFF"},
	-- Unstable Energy / SPELL_PERIODIC_DAMAGE,0xF130008192004C98,"Sun Beam",0xa48,0x050000000024ECA2,"Segomos",0x514,62865,"Unstable Energy",0x8,5801,0,8,1699,0,0,nil,nil,nil
	[62451] = {boss = L["Freya"], event = "SPELL_PERIODIC_DAMAGE", hits = 2},
	-- Bind Life / 4/25 13:16:11.832 SPELL_AURA_APPLIED,0xF13000824B0030C4,"Misguided Nymph",0xa48,0xF13000824B0030C4,"Misguided Nymph",0xa48,63082,"Bind Life",0x8,BUFF
	[62659] = {boss = L["Freya"], noSpam = true, event = "SPELL_DISPEL"},
	-- Ground Tremor / 5/21 17:43:09.505 SPELL_INTERRUPT,0xF1300080920040F6,"Elder Stonebark",0x20a48,0x05000000000501EB,"Monthor",0x514,62932,"Ground Tremor",0x1,48465,"S
	[62932] = {boss = L["Freya"], event = "SPELL_INTERRUPT"},
	
	-- Ulduar: Mimiron
	-- Rocket Strike / 3/13 20:56:28.111  SPELL_DAMAGE,0xF1300084FF001E10,"Rocket Strike",0xa48,0x01000000007C088D,"Veev",0x511,63041,"Rocket Strike",0x4,676800,657890,4,200000,0,0,nil,nil,nil
	[63041] = {boss = L["Mimiron"], event = "SPELL_DAMAGE"},
	-- P3W2 Laser Barrage / 3/13 21:05:11.205  SPELL_DAMAGE,0xF1500083730020DC,"VX-001",0x10a48,0x01000000007F4785,"Lawlpurge",0x514,63293,"P3Wx2 Laser Barrage",0x40,19400,1821,64,0,0,0,nil,nil,nil
	[63293] = {boss = L["Mimiron"], event = "SPELL_DAMAGE", throttle = 5},
	-- Shock Blast / 3/13 21:17:23.756  SPELL_DAMAGE,0xF150008298002210,"Leviathan Mk II",0x10a48,0xF1300007AC0025A9,"Treant",0x1114,63631,"Shock Blast",0x8,97000,92908,8,0,0,0,nil,nil,nil
	[63631] = {boss = L["Mimiron"], event = "SPELL_DAMAGE"},
	-- Proximity Mine / 4/16 13:16:23.167  SPELL_DAMAGE,0xF13000863A00929D,"Proximity Mine",0xa48,0x05000000027ECCF4,"Hotalicious",0x512,63009,"Explosion",0x4,22500,16608,4,2500,0,0,nil,nil,nil
	[63009] = {boss = L["Mimiron"], event = "SPELL_DAMAGE", mob = 34362},
	-- Bomb Bot / 4/16 13:35:12.750  SPELL_DAMAGE,0xF13000842C0094E3,"Bomb Bot",0xa48,0x05000000027ECCA5,"Naddia",0x512,63801,"Bomb Bot",0x4,20216,4025,4,5054,0,0,nil,nil,nil
	[63801] = {boss = L["Mimiron"], event = "SPELL_DAMAGE", mob = 33836, secondMob = 34192}, 
	-- Flames / 5/21 21:21:08.993 SPELL_DAMAGE,0x0000000000000000,nil,0x80000000,0x0380000001F43F45,"Rubu",0x511,64566,"Flames",0x4,7204,0,4,2110,0,0,nil,nil,nil
	[64566] = {boss = L["Mimiron"], event = "SPELL_DAMAGE", throttle = 5},
	-- Sapper Explosion / 5/20 19:21:37.014 SPELL_DAMAGE,0x0000000000000000,nil,0x80000000,0x0500000001630D69,"Ashstrike",0x514,64875,"Sapper Explosion",0x40,8150,0,64,2101,0,0,nil,nil,nil
	[64875] = {boss = L["Mimiron"], event = "SPELL_DAMAGE"},

	-- Ulduar: General Vezax
	-- Saronite Vapors / 5/21 19:26:33.135 SPELL_ENERGIZE,0x0000000000000000,nil,0x80000000,0x05000000009E0446,"Tsurara",0x514,63337,"Saronite Vapors",0x20,400,0
	[63337] = {boss = L["General Vezax"], noSpam = true, event = "SPELL_ENERGIZE", threshold = 12800},
	-- Shadow Crash / 4/16 22:06:17.885  SPELL_DAMAGE,0xF1300081F702D928,"General Vezax",0x10a48,0x05000000027FCDFE,"Kosie",0x514,62659,"Shadow Crash",0x20,9413,0,32,2285,0,0,nil,nil,nil
	[62659] = {boss = L["General Vezax"], event = "SPELL_DAMAGE", mob = 33271, throttle = 5},

	-- Ulduar: Yogg-Saron
	-- Death Ray / 4/17 19:50:50.740  SPELL_DAMAGE,0x0000000000000000,nil,0x80000000,0x05000000027ECAFC,"Turyia",0x514,63884,"Death Ray",0x8,14400,0,8,2000,0,0,nil,nil,nil
	[63884] = {boss = L["Yogg-Saron"], event = "SPELL_DAMAGE", throttle = 5},
	-- Brain Link / 5/25 18:44:05.130 SPELL_DAMAGE,0x0500000002A13CA4,"Taec",0x4000514,0x0500000000039C90,"Nokani",0x2000514,63803,"Brain Link",0x20,1920,0,32,600,0,0,nil,nil,ni
	[63803] = {boss = L["Yogg-Saron"], event = "SPELL_DAMAGE", threshold = 1800, throttle = 10},

	-- Obsidian Sanctum: Sartharion
	-- Shadow Fissure / 1/26 17:21:58.706 SPELL_DAMAGE,0xF130003F01003E54,"Shadow Fissure",0xa48,0xF130005E8F003E3D,"Army of the Dead Ghoul",0x2114,27812,"Void Blast",0x20,135642,130121,32,0,0,0,nil,nil,nil
	[27812] = {boss = L["Sartharion"], event = "SPELL_DAMAGE", throttle = 5},
	-- Flame Tsunami / 1/26 18:07:33.731 SPELL_DAMAGE,0xF130007798003120,"Flame Tsunami",0xa48,0xF1406356CD000162,"Dirtleaper",0x1114,57491,"Flame Tsunami",0x4,1800,0,4,0,0,0,nil,nil,nil
	[57491] = {boss = L["Sartharion"], event = "SPELL_DAMAGE", throttle = 10},

	-- Naxxramas: Heigan
	-- Eruption / 3/12 18:30:31.857 SPELL_DAMAGE,0xF11002C514000083,"Plague Fissure",0x4228,0xF140609B60000041,"Momofuku",0x1114,29371,"Eruption",0x8,1728,0,8,0,0,0,nil,nil,nil
	[29371] = {boss = L["Heigan"], event = "SPELL_DAMAGE", throttle = 5},
}
