# Hitmarker

A lightweight WoW Forever addon with separate cues for critical hits, other damage, blocks, dodges/misses, parries, and buffs/debuffs received by your character.

## Install

Copy this folder into `World of Warcraft/_classic_beta_/Interface/AddOns/Hitmarker/`, then enable **Hitmarker** from the character-selection AddOns list. The addon creates its saved settings on first load.

## Configure

Open **Options → AddOns → Hitmarker**, or type `/hitmarker`. Each event type has its own enable toggle, sound selection, and Test button. Defaults are:

- Critical hits and other damage: **Hitmarker 2**.
- Blocked damage: **Bonk**.
- Dodged or missed attacks: **Swoosh**.
- Received buffs: **Ding**.
- Received debuffs: **Minecraft Explode**.
- Parrying an attack: **Espada Som** (sword sound).

Any category can be changed to another MP3 cue in the `sounds/` folder.

Other damage is off by default. The options list scrolls to show all event settings.

The addon uses WoW's **Sound Effects** channel, so the game's Sound Effects volume setting controls all cues. WoW's addon playback API does not expose an individual playback-gain parameter. True per-cue volume sliders would require separately pre-scaled audio copies (or changing global game audio), so this addon does not pretend to offer controls that would not work.

WoW Forever does not expose combat-log events to addons. Hitmarker listens for `UNIT_COMBAT` for combat cues and `UNIT_AURA` for newly applied auras on your character. Combat events do not identify the attacker, so in groups another player's hit on your target may also trigger a cue. Damage to targets other than your current target is not detected, and incoming damage/healing are ignored. Aura refreshes and removals do not replay the buff/debuff cue. If Forever marks an event value as secret, that event is skipped.
