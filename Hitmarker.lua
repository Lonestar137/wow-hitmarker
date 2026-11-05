local ADDON_NAME = ...
local ADDON_TITLE = "Hitmarker"

local DEFAULTS = {
	critical = {
		enabled = true,
		sound = "hitmarker_2",
	},
	normal = {
		enabled = false,
		sound = "hitmarker_2",
	},
	blocked = {
		enabled = true,
		sound = "bonk_7zPAD7C",
	},
	dodgeMiss = {
		enabled = true,
		sound = "swoosh-sound-effects",
	},
	buff = {
		enabled = true,
		sound = "ding-sound-effect_2_bICB0mr",
	},
	debuff = {
		enabled = true,
		sound = "minecraft-explode1",
	},
	parry = {
		enabled = true,
		sound = "espada-som",
	},
}

local SOUND_PRESETS = {
	{
		key = "hitmarker_2",
		label = "Hitmarker 2",
		path = "Interface\\AddOns\\Hitmarker\\sounds\\hitmarker_2.mp3",
	},
	{
		key = "woosh-mark_diangelo-4778593",
		label = "Woosh Mark",
		path = "Interface\\AddOns\\Hitmarker\\sounds\\woosh-mark_diangelo-4778593.mp3",
	},
	{
		key = "espada-som",
		label = "Espada Som",
		path = "Interface\\AddOns\\Hitmarker\\sounds\\espada-som.mp3",
	},
	{
		key = "quick-ting",
		label = "Quick Ting",
		path = "Interface\\AddOns\\Hitmarker\\sounds\\quick-ting.mp3",
	},
	{
		key = "minecraft-explode1",
		label = "Minecraft Explode",
		path = "Interface\\AddOns\\Hitmarker\\sounds\\minecraft-explode1.mp3",
	},
	{
		key = "swoosh-sound-effects",
		label = "Swoosh",
		path = "Interface\\AddOns\\Hitmarker\\sounds\\swoosh-sound-effects.mp3",
	},
	{
		key = "ding-sound-effect_2_bICB0mr",
		label = "Ding",
		path = "Interface\\AddOns\\Hitmarker\\sounds\\ding-sound-effect_2_bICB0mr.mp3",
	},
	{
		key = "pistol-shot",
		label = "Pistol Shot",
		path = "Interface\\AddOns\\Hitmarker\\sounds\\pistol-shot.mp3",
	},
	{
		key = "bonk_7zPAD7C",
		label = "Bonk",
		path = "Interface\\AddOns\\Hitmarker\\sounds\\bonk_7zPAD7C.mp3",
	},
}

local AVAILABLE_SOUNDS = {}
local SOUND_BY_KEY = {}
local settingsCategory
local optionsPanel
local optionsContent
local controls = {}
local auraSnapshot

local function BuildSoundList()
	for _, preset in ipairs(SOUND_PRESETS) do
		AVAILABLE_SOUNDS[#AVAILABLE_SOUNDS + 1] = preset
		SOUND_BY_KEY[preset.key] = preset.path
	end
end

local function InitializeDatabase()
	if type(HitmarkerDB) ~= "table" then
		HitmarkerDB = {}
	end

	-- Apply the new default once for existing installs, then preserve user choices.
	if HitmarkerDB._version == nil then
		if type(HitmarkerDB.normal) == "table" then
			HitmarkerDB.normal.enabled = false
		end
		HitmarkerDB._version = 1
	end

	for effectName, defaults in pairs(DEFAULTS) do
		local effect = HitmarkerDB[effectName]
		if type(effect) ~= "table" then
			effect = {}
			HitmarkerDB[effectName] = effect
		end

		if type(effect.enabled) ~= "boolean" then
			effect.enabled = defaults.enabled
		end

		if type(effect.sound) ~= "string" or not SOUND_BY_KEY[effect.sound] then
			if SOUND_BY_KEY[defaults.sound] then
				effect.sound = defaults.sound
			elseif AVAILABLE_SOUNDS[1] then
				effect.sound = AVAILABLE_SOUNDS[1].key
			else
				effect.sound = nil
			end
		end
	end
end

local function PlayEffect(effectName, ignoreEnabled)
	local effect = HitmarkerDB and HitmarkerDB[effectName]
	if not effect or (not ignoreEnabled and not effect.enabled) then
		return
	end

	local soundPath = SOUND_BY_KEY[effect.sound]
	if soundPath and type(PlaySoundFile) == "function" then
		-- PlaySoundFile loads this asset from the addon folder.
		PlaySoundFile(soundPath, "SFX")
	end
end

local function IsSecret(value)
	return type(issecretvalue) == "function" and issecretvalue(value)
end

local function DescribeSecretAware(value)
	if value == nil then
		return "nil"
	end
	if IsSecret(value) then
		return "<secret>"
	end
	return tostring(value)
end

local debugCombatEvents = false
local debugCombatEventCount = 0

local function GetInterfaceVersion()
	if type(GetBuildInfo) ~= "function" then
		return nil
	end

	local _, _, _, interfaceVersion = GetBuildInfo()
	if type(interfaceVersion) == "number" then
		return interfaceVersion
	end
	return nil
end

local function IsForeverClient()
	local interfaceVersion = GetInterfaceVersion()
	return interfaceVersion ~= nil and interfaceVersion >= 16000 and interfaceVersion < 17000
end

local function CanUseCombatLog()
	-- Forever shares the modern UI API but restricts combat-log events. Classic
	-- and TBC clients either expose the combat-log getter or use the legacy event
	-- payload directly.
	if IsForeverClient() then
		return false
	end

	local interfaceVersion = GetInterfaceVersion()
	-- 12.x (Midnight, and Forever's engine) removed CLEU for addons.
	if interfaceVersion ~= nil and interfaceVersion >= 120000 then
		return false
	end

	if type(CombatLogGetCurrentEventInfo) == "function" then
		return true
	end

	if interfaceVersion ~= nil then
		-- 16xxx is Forever's interface range, where CLEU is restricted.
		return interfaceVersion < 16000 or interfaceVersion >= 20000
	end

	return false
end

local function CanAttackCurrentTarget()
	local canAttackTarget = UnitCanAttack("player", "target")

	-- Forever/Midnight can return a secret boolean here in combat. If the answer
	-- cannot be read, keep the hit instead of silently dropping every combat cue.
	if IsSecret(canAttackTarget) then
		return true
	end

	return canAttackTarget and true or false
end

local function OnUnitCombat(unit, action, flag, amount)
	-- WoW Forever blocks combat-log events. UNIT_COMBAT is the supported
	-- replacement, but it omits the attacker and reports damage to the target.
	if debugCombatEvents then
		debugCombatEventCount = debugCombatEventCount + 1
		if debugCombatEventCount <= 100 then
			print(string.format(
				"Hitmarker UNIT_COMBAT unit=%s action=%s flag=%s amount=%s",
				DescribeSecretAware(unit),
				DescribeSecretAware(action),
				DescribeSecretAware(flag),
				DescribeSecretAware(amount)
			))
		elseif debugCombatEventCount == 101 then
			print("Hitmarker debug: 100 combat events shown. Type /hitmarker debug to restart.")
			debugCombatEvents = false
		end
	end

	if IsSecret(unit) or IsSecret(action) then
		return
	end
	if unit == "player" and action == "PARRY" then
		PlayEffect("parry")
		return
	end
	if unit ~= "target" then
		return
	end

	if not CanAttackCurrentTarget() then
		return
	end

	if action == "WOUND" then
		-- The amount is often secret in combat on Forever/Midnight. It is only
		-- used to ignore zero-damage hits, so skip that check when it is hidden
		-- rather than dropping every damage cue.
		if not IsSecret(amount) and type(amount) == "number" and amount <= 0 then
			return
		end

		if IsSecret(flag) then
			return
		end

		if flag == "BLOCK" then
			PlayEffect("blocked")
		else
			PlayEffect(flag == "CRITICAL" and "critical" or "normal")
		end
	elseif action == "BLOCK" then
		PlayEffect("blocked")
	elseif action == "DODGE" or action == "MISS" then
		PlayEffect("dodgeMiss")
	end
end

local function MakeAuraKey(spellID, name, source, icon)
	local identity = spellID
	if IsSecret(identity) or identity == nil then
		identity = name
	end
	if IsSecret(identity) or identity == nil then
		identity = icon
	end
	if IsSecret(identity) or identity == nil then
		return nil
	end

	local sourceKey = ""
	if not IsSecret(source) and type(source) == "string" then
		sourceKey = source
	end
	return tostring(identity) .. ":" .. sourceKey
end

local function GetAuraSnapshot()
	local snapshot = {}
	local auraAPI = C_UnitAuras
	local getAuraData = type(auraAPI) == "table" and auraAPI.GetAuraDataByIndex

	for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
		for index = 1, 255 do
			local key
			if type(getAuraData) == "function" then
				-- Aura access can be blocked while restricted on Forever/Midnight.
				-- A failed read means "no readable auras" rather than a broken event.
				local ok, auraData = pcall(getAuraData, "player", index, filter)
				if not ok then
					break
				end
				if auraData == nil then
					break
				end
				if not IsSecret(auraData) and type(auraData) == "table" then
					local auraInstanceID = auraData.auraInstanceID
					if not IsSecret(auraInstanceID) and auraInstanceID ~= nil then
						key = "instance:" .. tostring(auraInstanceID)
					else
						key = MakeAuraKey(auraData.spellId, auraData.name, auraData.sourceUnit, auraData.icon)
					end
				end
			else
				local getAura = UnitAura
				if type(getAura) ~= "function" then
					if filter == "HELPFUL" then
						getAura = UnitBuff
					else
						getAura = UnitDebuff
					end
				end
				if type(getAura) ~= "function" then
					break
				end

				local name, icon, _, _, _, _, source, _, _, spellID = getAura("player", index, filter)
				if name == nil then
					break
				end
				key = MakeAuraKey(spellID, name, source, icon)
			end

			if key then
				snapshot[filter .. ":" .. key] = true
			end
		end
	end

	return snapshot
end

local function PlayAuraEffects(receivedBuff, receivedDebuff)
	-- Play at most once per update batch to avoid a burst when several auras land together.
	if receivedBuff then
		PlayEffect("buff")
	end
	if receivedDebuff then
		PlayEffect("debuff")
	end
end

local function OnAuraDelta(updateInfo)
	if IsSecret(updateInfo) or type(updateInfo) ~= "table" then
		return false
	end

	local isFullUpdate = updateInfo.isFullUpdate
	if IsSecret(isFullUpdate) then
		return true
	end
	if isFullUpdate then
		auraSnapshot = GetAuraSnapshot()
		return true
	end

	local addedAuras = updateInfo.addedAuras
	if IsSecret(addedAuras) or type(addedAuras) ~= "table" then
		return true
	end

	local receivedBuff = false
	local receivedDebuff = false
	for _, auraData in ipairs(addedAuras) do
		if type(auraData) == "table" and not IsSecret(auraData) then
			local isHelpful = auraData.isHelpful
			local isHarmful = auraData.isHarmful
			if not IsSecret(isHelpful) and not IsSecret(isHarmful) then
				if isHelpful then
					receivedBuff = true
				elseif isHarmful then
					receivedDebuff = true
				end
			end
		end
	end

	PlayAuraEffects(receivedBuff, receivedDebuff)
	return true
end

local function OnLegacyAuraUpdate()
	local currentSnapshot = GetAuraSnapshot()
	if not auraSnapshot then
		auraSnapshot = currentSnapshot
		return
	end

	local receivedBuff = false
	local receivedDebuff = false
	for key in pairs(currentSnapshot) do
		if not auraSnapshot[key] then
			if string.sub(key, 1, 8) == "HELPFUL:" then
				receivedBuff = true
			elseif string.sub(key, 1, 8) == "HARMFUL:" then
				receivedDebuff = true
			end
		end
	end
	auraSnapshot = currentSnapshot
	PlayAuraEffects(receivedBuff, receivedDebuff)
end

local function OnUnitAura(unit, updateInfo)
	if IsSecret(unit) or unit ~= "player" or IsSecret(updateInfo) then
		return
	end

	if OnAuraDelta(updateInfo) then
		return
	end
	OnLegacyAuraUpdate()
end

local function OnCombatLog(...)
	local eventInfo = { ... }
	if type(CombatLogGetCurrentEventInfo) == "function" then
		eventInfo = { CombatLogGetCurrentEventInfo() }
	end

	local subevent = eventInfo[2]
	local destGUID = eventInfo[8]
	if IsSecret(subevent) or IsSecret(destGUID) then
		return
	end

	local playerGUID = UnitGUID("player")
	if not IsSecret(playerGUID) and destGUID == playerGUID then
		local missType
		if subevent == "SWING_MISSED" then
			missType = eventInfo[12]
		elseif subevent == "SPELL_MISSED" or subevent == "RANGE_MISSED" then
			missType = eventInfo[15]
		end
		if not IsSecret(missType) and missType == "PARRY" then
			PlayEffect("parry")
			return
		end
	end

	local targetGUID = UnitGUID("target")
	if IsSecret(targetGUID) or destGUID ~= targetGUID or not CanAttackCurrentTarget() then
		return
	end

	local amount, blocked, critical
	if subevent == "SWING_DAMAGE" then
		amount = eventInfo[12]
		blocked = eventInfo[16]
		critical = eventInfo[18]
	elseif subevent == "RANGE_DAMAGE" or subevent == "SPELL_DAMAGE" or subevent == "SPELL_PERIODIC_DAMAGE" then
		amount = eventInfo[15]
		blocked = eventInfo[19]
		critical = eventInfo[21]
	elseif subevent == "SWING_MISSED" then
		local missType = eventInfo[12]
		if not IsSecret(missType) then
			if missType == "BLOCK" then
				PlayEffect("blocked")
			elseif missType == "DODGE" or missType == "MISS" then
				PlayEffect("dodgeMiss")
			end
		end
		return
	elseif subevent == "SPELL_MISSED" or subevent == "RANGE_MISSED" then
		local missType = eventInfo[15]
		if not IsSecret(missType) then
			if missType == "BLOCK" then
				PlayEffect("blocked")
			elseif missType == "DODGE" or missType == "MISS" then
				PlayEffect("dodgeMiss")
			end
		end
		return
	else
		return
	end

	if IsSecret(amount) or type(amount) ~= "number" or amount <= 0 then
		return
	end
	if not IsSecret(blocked) and type(blocked) == "number" and blocked > 0 then
		PlayEffect("blocked")
	else
		PlayEffect(not IsSecret(critical) and critical and "critical" or "normal")
	end
end

local function SetText(parent, name, text, template, x, y, width)
	local label = parent:CreateFontString(name, "ARTWORK", template or "GameFontNormal")
	label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	label:SetText(text)
	if width then
		label:SetWidth(width)
		label:SetJustifyH("LEFT")
		label:SetWordWrap(true)
	end
	return label
end

local function RefreshControls()
	if not HitmarkerDB then
		return
	end

	for effectName, effectControls in pairs(controls) do
		local effect = HitmarkerDB[effectName]
		effectControls.enabled:SetChecked(effect.enabled)
		if effect.sound then
			UIDropDownMenu_SetSelectedValue(effectControls.sound, effect.sound)
			local presetLabel = effectControls.soundLabels[effect.sound]
			if presetLabel then
				UIDropDownMenu_SetText(effectControls.sound, presetLabel)
			end
		else
			UIDropDownMenu_SetText(effectControls.sound, "No sounds available")
		end
	end
end

local function CreateEffectOptions(effectName, title, xOffset, yOffset)
	local keyPrefix = "Hitmarker" .. effectName
	SetText(optionsContent, nil, title, "GameFontNormalLarge", xOffset, yOffset)

	local enabled = CreateFrame(
		"CheckButton",
		keyPrefix .. "Enabled",
		optionsContent,
		"InterfaceOptionsCheckButtonTemplate"
	)
	enabled:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", xOffset - 4, yOffset - 24)
	local enabledLabel = _G[enabled:GetName() .. "Text"]
	if enabledLabel then
		enabledLabel:SetText("Enable this sound")
	end
	enabled:SetScript("OnClick", function(self)
		HitmarkerDB[effectName].enabled = self:GetChecked()
	end)

	SetText(optionsContent, nil, "Sound effect", "GameFontHighlight", xOffset, yOffset - 61)
	local dropdown = CreateFrame("Frame", keyPrefix .. "Sound", optionsContent, "UIDropDownMenuTemplate")
	dropdown:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", xOffset - 16, yOffset - 72)
	UIDropDownMenu_SetWidth(dropdown, 180)
	UIDropDownMenu_JustifyText(dropdown, "LEFT")
	local soundLabels = {}
	for _, preset in ipairs(AVAILABLE_SOUNDS) do
		soundLabels[preset.key] = preset.label
	end
	UIDropDownMenu_Initialize(dropdown, function(_, level)
		for _, preset in ipairs(AVAILABLE_SOUNDS) do
			local info = UIDropDownMenu_CreateInfo()
			info.text = preset.label
			info.value = preset.key
			info.checked = HitmarkerDB[effectName].sound == preset.key
			info.func = function()
				HitmarkerDB[effectName].sound = preset.key
				UIDropDownMenu_SetSelectedValue(dropdown, preset.key)
				UIDropDownMenu_SetText(dropdown, preset.label)
			end
			UIDropDownMenu_AddButton(info, level)
		end
	end)

	local testButton = CreateFrame("Button", nil, optionsContent, "UIPanelButtonTemplate")
	testButton:SetSize(64, 22)
	testButton:SetPoint("LEFT", dropdown, "RIGHT", 14, 2)
	testButton:SetText("Test")
	testButton:SetScript("OnClick", function()
		PlayEffect(effectName, true)
	end)

	local volumeLabel = SetText(
		optionsContent,
		keyPrefix .. "VolumeNote",
		"Volume: controlled by WoW's Sound Effects setting. The addon API cannot set individual playback gain.",
		"GameFontDisableSmall",
		xOffset + 4,
		yOffset - 120,
		285
	)
	volumeLabel:SetHeight(34)

	controls[effectName] = {
		enabled = enabled,
		sound = dropdown,
		soundLabels = soundLabels,
	}
end

local function CreateOptionsPanel()
	optionsPanel = CreateFrame("Frame", "HitmarkerOptionsPanel", UIParent)
	optionsPanel:SetSize(640, 600)
	optionsPanel.name = ADDON_TITLE

	SetText(optionsPanel, nil, ADDON_TITLE, "GameFontNormalLarge", 16, -16)
	local description = SetText(
		optionsPanel,
		nil,
		"Choose sounds for hits, blocks, misses, parries, and auras on your character/target. WoW's Sound Effects setting controls volume; in groups, other players' actions may trigger combat cues too.",
		"GameFontHighlight",
		16,
		-43,
		590
	)
	description:SetHeight(34)

	local scrollFrame = CreateFrame(
		"ScrollFrame",
		"HitmarkerOptionsScrollFrame",
		optionsPanel,
		"UIPanelScrollFrameTemplate"
	)
	scrollFrame:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 0, -82)
	scrollFrame:SetPoint("BOTTOMRIGHT", optionsPanel, "BOTTOMRIGHT", -26, 8)

	optionsContent = CreateFrame("Frame", nil, scrollFrame)
	optionsContent:SetSize(610, 950)
	scrollFrame:SetScrollChild(optionsContent)

	CreateEffectOptions("critical", "Critical hits", 16, -8)
	CreateEffectOptions("normal", "Other damage", 310, -8)
	CreateEffectOptions("blocked", "Blocked damage", 16, -257)
	CreateEffectOptions("dodgeMiss", "Dodged / missed attacks", 310, -257)
	CreateEffectOptions("buff", "Received buffs", 16, -506)
	CreateEffectOptions("debuff", "Received debuffs", 310, -506)
	CreateEffectOptions("parry", "Parry", 16, -755)
	optionsPanel:SetScript("OnShow", RefreshControls)

	if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
		settingsCategory = Settings.RegisterCanvasLayoutCategory(optionsPanel, ADDON_TITLE)
		Settings.RegisterAddOnCategory(settingsCategory)
	elseif InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(optionsPanel)
	end
end

local function OpenOptions()
	if Settings and Settings.OpenToCategory and settingsCategory then
		local categoryID = settingsCategory.ID
		if not categoryID and settingsCategory.GetID then
			categoryID = settingsCategory:GetID()
		end
		if categoryID then
			Settings.OpenToCategory(categoryID)
			return
		end
	end

	if InterfaceOptionsFrame_OpenToCategory and optionsPanel then
		InterfaceOptionsFrame_OpenToCategory(optionsPanel)
		InterfaceOptionsFrame_OpenToCategory(optionsPanel)
		return
	end

	print("Hitmarker: open Options > AddOns > Hitmarker to configure sounds.")
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("UNIT_AURA")
eventFrame:SetScript("OnEvent", function(_, event, ...)
	local loadedAddon = ...
	if event == "ADDON_LOADED" and loadedAddon == ADDON_NAME then
		BuildSoundList()
		InitializeDatabase()
		auraSnapshot = GetAuraSnapshot()
		CreateOptionsPanel()
	elseif event == "UNIT_COMBAT" then
		OnUnitCombat(...)
	elseif event == "UNIT_AURA" then
		OnUnitAura(...)
	elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
		OnCombatLog(...)
	end
end)

if CanUseCombatLog() then
	local registered = pcall(eventFrame.RegisterEvent, eventFrame, "COMBAT_LOG_EVENT_UNFILTERED")
	if not registered then
		eventFrame:RegisterEvent("UNIT_COMBAT")
	end
else
	eventFrame:RegisterEvent("UNIT_COMBAT")
end

SLASH_HITMARKER1 = "/hitmarker"
SlashCmdList.HITMARKER = function(message)
	local command = ""
	if type(message) == "string" then
		command = string.lower(string.match(message, "^%s*(.-)%s*$") or "")
	end

	if command == "debug" then
		debugCombatEvents = not debugCombatEvents
		debugCombatEventCount = 0
		print("Hitmarker combat debug " .. (debugCombatEvents and "on" or "off") .. ".")
		return
	end

	OpenOptions()
end
