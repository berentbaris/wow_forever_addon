# Forever Classes Enhanced

A World of Warcraft: Forever addon (port of Classic Classes Enhanced) that introduces 27 lore-based "character classes" — one per specialization of every base class — to your hardcore run. Pick a character archetype and the addon tracks whether you're following its unique requirements as you level.

This is **not** a verification or auditing system. It's purely for fun. The addon tells you what your character's requirements are, surfaces new ones as you level up, and gives you a progress overview — but it never blocks gameplay or auto-unequips items.

## Installation

1. Download or clone this folder so that it's named `ForeverClassesEnhanced`
2. Place it in your WoW Forever addons directory. During the beta that is:
   ```
   World of Warcraft/_classic_beta_/Interface/AddOns/ForeverClassesEnhanced/
   ```
3. Make sure the folder contains `ForeverClassesEnhanced.toc` at the top level (not nested inside another subfolder)
4. Fully restart the client the first time (a new addon folder isn't picked up by `/reload`)

## WoW Forever notes

Forever plays like Classic but runs on the modern (Midnight / Mainline 12.1.x) addon API, interface `16001`. `ForeverCompat.lua` loads first and bridges the Classic APIs this addon uses to their modern equivalents; type `/fce compat` in game to see which APIs are native, shimmed or missing on your build, or `/fce apitest` for the full self-test (every API and event FCE relies on, mapped to the requirements it affects, in a copyable report window). See `FOREVER_TODO.md` in the repo root for the launch checklist. Known gaps on the beta: the combat log is unavailable to addons (kill/dispel-based challenges can't auto-complete), classic talent APIs were reported missing (talent checks show no data), and weapon skills aren't exposed through the modern API.
5. On your next login, the addon will auto-detect matching characters for your race, class, and gender

## How It Works

When you log in on a hardcore character, the addon checks your race, class, and gender against its database of 27 characters. If there's exactly one match, it's assigned automatically. If multiple characters match (e.g., Hunters with the "Any" race Buccaneer), a selection window appears so you can pick.

Once a character is active, the addon tracks equipment rules, profession progress, talent spec, challenge restrictions, companions, hunter pets, and mounts — everything the character's lore demands. A requirements panel (toggled via the minimap button or `/hce panel`) shows your full checklist with colour-coded pass/fail/pending indicators and a progress bar.

Requirements are level-gated: they appear greyed out until the level they become active, and a toast notification fires when you level up and something new kicks in. If you equip a forbidden item, a red warning toast and a brief screen-edge flash let you know.

## Slash Commands

Use `/hce` or `/hardcoreclasses` followed by any of these:

| Command | What it does |
|---|---|
| `help` | List all commands |
| `status` | Print your current character's full requirement breakdown |
| `panel` | Toggle the requirements panel |
| `ui` | Open the character selection window |
| `list` | List all characters for your class |
| `pick <name>` | Manually select a character by name |
| `progress` | Print a progress checklist with percentage |
| `settings` | Open the settings panel |
| `professions` | Print profession tracking status |
| `talents` | Print talent/spec status |
| `challenges` | Print challenge check results |
| `zones` | Print zone visit tracking |
| `selffound` | Print self-found/self-made status |
| `sources` | Print per-slot item source breakdown |
| `companion` | Print companion pet status |
| `hunterpet` | Print hunter pet status |
| `mount` | Print mount check status |
| `behavioral` | Print behavioral challenge status |
| `gameplay` | Print gameplay tips |
| `curated` | Print curated item list statistics |
| `minimap` | Toggle the minimap button |
| `alerts` | Toggle level-up toast alerts |
| `forbidden` | Toggle forbidden-item warnings |
| `reset` | Clear all tracking data for the current character |
| `version` | Print the addon version |

## Characters

27 characters across 9 classes, 3 per class. Each is tied to a specific talent spec and carries its own combination of race, gender, profession, equipment, and challenge requirements.

### Warrior

**Mountain King** — Dwarf Male, Protection. Self-found. Mace or axe, shield, flask trinkets (lv 50). No professions challenge. Gameplay: beer, treasure.

**Brewmaster** — Tauren Male, Arms. Self-found. Alchemy + Cooking. Staff, lunar festival suit (lv 10). Exotic challenge (no uncommon gear). Gameplay: drunk, darkmoon special.

**Demon Hunter** — Night Elf Male, Fury. Self-found. Swords, no chest armor, kilt (lv 25). Renegade challenge (no quest rewards).

### Rogue

**Berserker** — Troll (any gender), Assassination. Self-found. Alchemy. Dagger and sword (lv 10), thrown axe (lv 10). Grunt challenge (no rare/epic gear). Gameplay: thistle tea.

**Warden** — Night Elf Female, Combat. Self-found. Swords, robe (lv 10), thrown blade (lv 10). Homebound challenge (can't leave home continent). Companion: owl (lv 10).

**Runemaster** — Dwarf Male, Subtlety. Enchanting. Fist weapons, no chest, kilt (lv 25). Off-the-shelf challenge (vendor gear only). Gameplay: self-made enchants, scrolls.

### Warlock

**Pyremaster** — Orc (any gender), Destruction. Self-found. Cooking. 1.5-speed dagger (lv 15), firestone (lv 25), no wands. Exotic + Imp challenges. Mount: wolf (lv 40). Gameplay: campfire, melee weaving.

**Death Knight** — Undead Male, Affliction. Self-found. Fishing. Staff or polearm, cowl (lv 25), no robes, no wands, 120 attack power (lv 50). No demon challenge. Mount: skeletal horse (lv 40). Gameplay: melee weaving.

**Shadowmage** — Gnome Female, Demonology. Self-found. Tailoring. Robe, spellstone (lv 40). Self-made + Drifter challenges. Companion: black cat (lv 10).

### Druid

**Druid of the Claw** — Night Elf Male, Feral. Self-found. Armored weapon (lv 35), armored off-hand (lv 25), armored rings (lv 45). Ephemeral + Drifter challenges. Gameplay: /roar, pro-nature.

**Plagueshifter** — Tauren Female, Restoration. Self-found. Jungle remedy (lv 35), restoration potion (lv 45). Partisan challenge (no looted gear). Gameplay: anti-undead.

**Savagekin** — Tauren Male, Balance. Self-found. Armored ring (lv 45), 180 intellect (lv 40), 250 intellect (lv 50). Homebound + Drifter challenges. Gameplay: pro-nature.

### Hunter

**Buccaneer** — Any race, any gender, Survival. Self-found. Tailoring + Fishing. Captain's hat (lv 45), gun, rapier/cutlass/harpoon (lv 20). Renegade challenge. Companion: parrot (lv 15). Hunter pet: jungle cat (lv 15). Gameplay: rum, melee weaving.

**Beastmaster** — Orc (any gender), Beast Mastery. Self-found. Leatherworking. Wolf helm (lv 45), anti-beast cloak (lv 20), gloves (lv 30), melee weapon (lv 35), ranged weapon (lv 50), no guns. Mortal pets challenge (dead pets stay dead). Companion: prairie dog (lv 10). Gameplay: rare pets.

**Mountaineer** — Dwarf (any gender), Marksmanship. Self-found. Engineering. Gun, 2h axe, scope (lv 5). Partisan + Self-made guns challenges. Hunter pet: bear (lv 10). Gameplay: hooded cloak.

### Shaman

**Spirit Champion** — Orc (any gender), Enhancement. Self-found. 2h weapon, shield (lv 5). Exotic challenge. Gameplay: /sit and /meditate.

**Witch Doctor** — Troll Female, Restoration. Self-found. Alchemy. Voodoo mask (lv 45), cursed amulet (lv 45), shell shield (lv 20). Renegade + Cloth/leather challenges.

**Spiritwalker** — Tauren (any gender), Elemental. Self-found. Leatherworking. 1h axe, torch (lv 10). Self-made challenge.

### Paladin

**Exemplar** — Human Female, Holy. Self-found. Engineering. Shield (lv 5), guild tabard (lv 10), blue shirt (lv 10), insignia (lv 30). Partisan + Mail/plate challenges. Gameplay: Stormwind hearthstone.

**Templar** — Human Male, Protection. Self-found. Sword or mace, shield (lv 5), Argent Dawn trinket (lv 50). Homebound challenge. Gameplay: anti-undead.

**Sister of Steel** — Dwarf Female, Retribution. Self-found. Blacksmithing. No daggers. Self-made challenge. Mount: ram (lv 40).

### Priest

**Priestess of the Moon** — Night Elf Female, Holy. Self-found. Tailoring. Robe, 180 spirit (lv 40), 250 spirit (lv 50). Partisan challenge. Mount: frostsaber (lv 40). Gameplay: spirit tap + starshards.

**Apothecary** — Undead (any gender), Discipline. Self-found. Alchemy. Dagger, robe, herb pouch (lv 10). Homebound challenge. Companion: cockroach (lv 10).

**Shadow Hunter** — Troll (any gender), Shadow. Self-found. Fishing. Staff or polearm, voodoo mask (lv 45), no robes, no wands, 120 attack power (lv 50). Faction Loyalist challenge (lv 1). Gameplay: melee weaving.

### Mage

**Bloodmage** — Undead Female, Fire. Enchanting. Unholy weapon (lv 45), shadow or fire wand (lv 5). White Knight + Drifter challenges. Companion: phoenix (lv 10). Gameplay: self-made enchants.

**Mechano-Mage** — Gnome (any gender), Arcane. Self-found. Engineering. Flying Tiger Goggles (lv 20), green-tinted goggles (lv 30), gnomish goggles (lv 40). Renegade challenge. Companion: mechanical pet (lv 30). Gameplay: pyroblast + arcane missiles.

**Warmage** — Human (any gender), Frost. Self-found. Sword, staff-like off-hand (lv 5), armored rings (lv 45). Footman challenge (no rare/epic gear). Companion: snow rabbit (lv 10). Gameplay: AoE-farmer.

## Challenge Types

| Challenge | Rule |
|---|---|
| Anti-undead | Visit undead-themed zones (Tirisfal, Silverpine, Duskwood, Plaguelands, etc.) |
| Pro-nature | Visit nature zones (Mulgore, Barrens, Stonetalon, STV) |
| Homebound | Cannot leave your home continent |
| Anti-demon | Visit demon-themed zones (Durotar, Teldrassil, Darkshore, Felwood, etc.) |
| Renegade | Cannot equip quest reward gear |
| White Knight | Can only equip white or grey gear |
| Partisan | Cannot equip looted gear |
| Drifter | Cannot use hearthstone or bank |
| Ephemeral | Cannot repair gear |
| Self-made | Can only equip self-crafted or white/grey items |
| Exotic | Cannot equip uncommon (green) quality gear |
| Off-the-shelf | Can only equip gear sold by vendors |
| Faction Loyalist | Maintain standing with your home faction as you level up (Friendly→Honored→Revered→Exalted) |
| Footman / Grunt | Cannot equip rare or epic quality items |
| No professions | Cannot learn any professions |
| No demon | Cannot summon a demon pet |
| Mortal pets | Hunter pets that die stay dead |
| Cloth/leather | Can only wear cloth or leather armor |
| Mail/plate | Must wear mail or plate in all possible slots |
| Imp | Must always use the Imp as your demon pet |
| Self-made guns | Ranged weapon must be self-crafted via Engineering |
| Diplomat | Must obtain another faction's mount before reaching 60 |
| Aoe-farmer | Visit key AoE farming zones |

## Settings

Open the settings panel with `/hce settings`. You can toggle:

- Level-up toast alerts
- Forbidden-item warnings
- Chat warning messages
- Alert sounds
- Screen-edge flash effect
- Minimap button visibility
- Auto-show panel on login
- Panel position lock

## Design Notes

The addon tracks **current state only** — what's equipped right now, current profession levels, current talent points, current zone. It doesn't try to track item acquisition history or enforce rules retroactively. This keeps the design simple and means installing the addon mid-run works fine.

All item tracking uses numeric item IDs (locale-independent). Profession detection uses spell IDs. Zone checks use map IDs. The addon works on any language client.

## Files

The addon consists of 22 Lua files:

- `CharacterData.lua` — all 27 characters and lookup helpers
- `SelectionUI.lua` — character selection window
- `RequirementsPanel.lua` — persistent requirements sidebar and minimap button
- `LevelAlert.lua` — level-up toast notifications
- `EquipmentCheck.lua` — equipment type and item tracking
- `CuratedItems.lua` — verified item ID lists for thematic requirements
- `ForbiddenAlert.lua` — forbidden-item warning toasts and screen flash
- `ProfessionCheck.lua` — profession detection and rank tracking
- `TalentCheck.lua` — talent spec verification
- `SelfFoundCheck.lua` — self-found buff and self-made item tracking
- `ZoneCheck.lua` — continent and zone-visit tracking
- `BehavioralCheck.lua` — hearthstone, bank, repair, and pet-revive tracking
- `ChallengeCheck.lua` — central challenge rule engine
- `ItemSourceData.lua` — curated quest-reward and vendor item ID lists
- `CompanionCheck.lua` — vanity pet tracking
- `HunterPetCheck.lua` — hunter pet species verification
- `MountCheck.lua` — mount type verification
- `SettingsPanel.lua` — settings toggles
- `ProgressSummary.lua` — progress bar and checklist
- `LevelUpSummary.lua` — level-up summary panel
- `GameplayTips.lua` — gameplay suggestion display
- `ForeverClassesEnhanced.lua` — main addon file, event handling, slash commands

## Version

0.1.0 — Built for WoW Classic (Interface 11507).

## Author

Beba
