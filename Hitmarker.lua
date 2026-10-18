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

local function OnUnitCombat(unit, action, flag, amount)
	-- WoW Forever blocks combat-log events. UNIT_COMBAT is the supported
	-- replacement, but it omits the attacker and reports damage to the target.
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

	local canAttackTarget = UnitCanAttack("player", "target")
	if IsSecret(canAttackTarget) or not canAttackTarget then
		return
	end

	if action == "WOUND" then
		if IsSecret(flag) or IsSecret(amount) or type(amount) ~= "number" or amount <= 0 then
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

local function OnUnitAura(unit, updateInfo)
	if IsSecret(unit) or unit ~= "player" or IsSecret(updateInfo) or type(updateInfo) ~= "table" then
		return
	end
	if IsSecret(updateInfo.isFullUpdate) or updateInfo.isFullUpdate then
		return
	end

	local addedAuras = updateInfo.addedAuras
	if IsSecret(addedAuras) or type(addedAuras) ~= "table" then
		return
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

	-- Play at most once per update batch to avoid a burst when several auras land together.
	if receivedBuff then
		PlayEffect("buff")
	end
	if receivedDebuff then
		PlayEffect("debuff")
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
eventFrame:RegisterEvent("UNIT_COMBAT")
eventFrame:RegisterEvent("UNIT_AURA")
eventFrame:SetScript("OnEvent", function(_, event, ...)
	local loadedAddon = ...
	if event == "ADDON_LOADED" and loadedAddon == ADDON_NAME then
		BuildSoundList()
		InitializeDatabase()
		CreateOptionsPanel()
	elseif event == "UNIT_COMBAT" then
		OnUnitCombat(...)
	elseif event == "UNIT_AURA" then
		OnUnitAura(...)
	end
end)

SLASH_HITMARKER1 = "/hitmarker"
SlashCmdList.HITMARKER = OpenOptions
