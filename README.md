# Hitmarker

A lightweight addon for WoW Classic Era, TBC Anniversary, and WoW Forever. It plays separate cues for critical hits, other damage, blocks, dodges/misses, parries, and buffs/debuffs received by your character.

## Install

Copy this folder into the `Interface/AddOns/Hitmarker/` directory for the client you play (for example, `_classic_era_`, the TBC Anniversary client, or Forever's `_forever_` directory), then enable **Hitmarker** from the character-selection AddOns list. The addon creates its saved settings on first load.

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

On Forever, type `/hitmarker debug` to print the raw `UNIT_COMBAT` events the addon receives (and mark any values the client hides as `<secret>`). It shows up to 100 events per toggle, then switches itself off.

The addon uses WoW's **Sound Effects** channel, so the game's Sound Effects volume setting controls all cues. WoW's addon playback API does not expose an individual playback-gain parameter. True per-cue volume sliders would require separately pre-scaled audio copies (or changing global game audio), so this addon does not pretend to offer controls that would not work.

On Classic Era and TBC Anniversary, Hitmarker uses combat-log events for attacks against your current target and aura scans to detect newly applied auras on your character. On Forever, it uses `UNIT_COMBAT` and the modern `UNIT_AURA` update data because combat-log events are restricted there. In groups, other players' hits on your target may also trigger combat cues. Damage to targets other than your current target is not detected, and incoming damage/healing are ignored. Aura refreshes and removals do not replay the buff/debuff cue. Forever may hide some combat values as secret: Hitmarker keeps working when the damage amount or target attackability check is hidden, but an event whose critical/blocked flag itself is hidden cannot be classified and is skipped.
