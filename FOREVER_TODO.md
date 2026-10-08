# Forever Classes Enhanced — Launch Prep & API Risk Map

Compiled 2 October 2026 from public beta reports (beta builds 1.60.1.69913 → 70170). Nothing here has been tested in a real Forever client yet. Each claim is labelled with how sure we are, and `/fce apitest` is built to confirm or disprove every one of them on launch day.

## 1. What is known about Forever's addon API

| Fact | Confidence | Source |
|---|---|---|
| Interface version is `16001` (TOC suffix `_Camelot`, game type `camelot`) | Reported (wiki + several sites) | Warcraft Wiki TOC format; Patch 1.60.1/API changes |
| Forever uses the **modern Mainline API** (12.1.5 family), *not* Classic Era's | Confirmed by Blizzard (Sept 15 blue post, Sept 17 Q&A) | Warcraft Wiki Patch 1.60.1; wowforeverguides |
| Midnight's addon restrictions ("secret values") are active | Confirmed by Blizzard | same |
| `GetItemInfo`, `GetSpellInfo`, `GetNumTalentTabs`, `GetTalentInfo`, `GetNumSkillLines` are gone from the globals | Reported (tested on beta build 69913) | WoW Forever Builds |
| Talents run on the modern trait system (`C_Traits`). The 3-tree layout stays, with new nodes, 1 point per level from 10 (51 total) and a new 16-point milestone | Reported | WoW Forever Builds; talent site summaries |
| Forever **adds** `C_SkillInfo.GetNumSkillLines / GetSkillLineInfo / ExpandSkillHeader` (so weapon skills should exist again) | From the API diff vs 12.1.5 | Warcraft Wiki Patch 1.60.1/API changes |
| Forever adds `C_GameRules.IsSelfFoundAllowed`, `IsHardcoreActive`, `C_DateAndTime.IsDayTime`, `C_PetInfo.GetPetHappiness/Loyalty/TrainingPoints`, `C_Item.DeleteItem`, `C_Item.GetWeaponEnchantInfo` | From the API diff | same |
| Combat log (`COMBAT_LOG_EVENT_UNFILTERED`) is not available to addons; `PARTY_KILL` (killer and victim GUIDs) and a "unit died" event exist as replacements | Midnight-confirmed; Forever inherits it | Warcraft Wiki Patch 12.0.0 planned changes; DragonShout issue #28 |
| **The player's own spellcasts (pets included) are NOT secret, even in combat** | Confirmed for Midnight | Patch 12.0.0 notes (Nov 4) |
| **Aura data is secret while in combat**, during instance encounters, M+ and PvP matches | Confirmed for Midnight | Patch 12.0.0 notes (Oct 11) |
| Creature names, GUIDs and NPC IDs are secret **inside instances** (regardless of combat) | Confirmed for Midnight | Patch 12.0.0 notes (Oct 27 / Nov 4) |
| Chat messages are secret, and addons can't send chat or addon messages, only during **encounters / M+ / PvP matches** | Confirmed for Midnight | Patch 12.0.0 notes (Oct 11) |
| SavedVariables can't contain secret values (they're saved as nil) | Confirmed for Midnight | Patch 12.0.0 notes (Beta 1) |
| Beta bug: SavedVariables written to disk but not restored at login. Reportedly fixed in build 70009 | Unverified | Blizzard forums; forever-codex |
| **Companion pets (113) and mounts (137) are account-wide journal collections** in Forever, not bag items | Datamined | forever-codex.com collections |
| `WOW_PROJECT_ID` reports `1` (Mainline). Detect Forever by interface version 16000–19999 instead | Reported | WoW Forever Builds; Warcraft Wiki |
| `ChatFrame_OpenChat` and secure snippets fail silently / are protected | Reported | wowforeverguides pitfalls |

## 2. FCE requirements, by risk

Legend:

- **BROKEN** — won't work without a rewrite.
- **AT RISK** — works in some situations, or depends on something unconfirmed.
- **SHIMMED** — fixed by `ForeverCompat.lua`, needs confirming in game.
- **LIKELY OK** — should work as-is.

`/fce apitest` probe names are shown in brackets.

### BROKEN

| Requirement | Why | Files | Fix plan |
|---|---|---|---|
| **TALENTS section** (every character) | `GetTalentInfo`/`GetNumTalentTabs` are gone; talents are `C_Traits` nodes. Forever also reworked the trees, so talent *names* in `TalentRequirements.lua` may have changed | TalentCheck.lua, TalentRequirements.lua | Rebuild the talent cache from `C_ClassTalents.GetActiveConfigID` → `C_Traits.GetTreeNodes` → `GetNodeInfo` → `GetEntryInfo` → `GetDefinitionInfo().spellID` → name. `/fce apitest talents` dumps this structure on day one. Re-check every required talent name against a Forever talent calculator. [Talents] |
| **MOUNT requirements** (Wolf, Skeletal horse, Ram, Frostsaber…) | MountCheck scans bags for mount *items*; Forever mounts are journal entries | MountCheck.lua | Use `C_MountJournal.GetMountIDs` + `GetMountInfoByID` (returns `spellID`, `isCollected`, `isActive`) and match Classic mount **spell IDs** instead of item IDs. Can be written before launch. [Mount collection] |
| **COMPANION requirements** | CompanionCheck uses the Classic `"critter"` unit plus bag items; Forever companions are an account journal | CompanionCheck.lua | Use `C_PetJournal.GetSummonedPetGUID` → `GetPetInfoByPetID` (speciesID, name). Map required companions to species/creature names. [Companion detection] |
| **Disease Cleansing** | Counted `SPELL_DISPEL` from the combat log | EventChallenges.lua | Track `UNIT_AURA` on the player: a known disease debuff disappearing right after your own cure cast (`UNIT_SPELLCAST_SUCCEEDED`) counts as a cleanse. Debuffs are secret in combat, so only out-of-combat cures can be counted. Consider relaxing the rule |
| **Gnomish Justice** (kill Kovic) and **XXX** (kill NPC 3936) | Used `UNIT_DIED` from the combat log | EventChallenges.lua | Switch to `PARTY_KILL` / the new unit-died event. Works in the open world; **GUIDs are secret inside instances**, so if the target is in a dungeon, fall back to a quest-completion or manual confirm. [Kill / death events] |

### AT RISK

| Requirement | Why | Files | Fix plan |
|---|---|---|---|
| **Elixir Frenzy, Happy Hour, Doubt (campfire), Demonic Sacrifice, The New Plague, mount-buff checks** | Auras are secret in combat. The shim turns a secret aura into name `"?"`, so a timer could think the elixir/drink buff is gone mid-fight and tick down (false FAIL) | ElixirSystem.lua, BrewmasterSystem.lua, DoubtSystem.lua, ChallengeCheck.lua, EventChallenges.lua, MountCheck.lua | Pause these timers while `FCE.Compat.AurasMayBeSecret()` is true, same pattern as the flight/death pause. Small change, can be done now. [Read player buffs] |
| **Self-Found / Not self-found** | Detects a "Self-Found" buff. Forever's self-found mode isn't confirmed (Hardcore arrives after launch) | SelfFoundCheck.lua, CatalogUI.lua, RequirementsPanel.lua | If there's no buff, use `C_GameRules.IsSelfFoundAllowed()`. Decide what Self-Found means if Forever has no SSF mode. [C_GameRules, Self-Found buff] |
| **Self-made / Self-made guns** | Reads the "Made by" tooltip line with a scanning GameTooltip. Usually still works on Mainline | SelfFoundCheck.lua | If the scan comes back empty, port to `C_TooltipInfo.GetInventoryItem`. [Tooltip scan] |
| **Helm/cloak must be visible** (curated HEAD/BACK items) | Classic `ShowingHelm`/`ShowingCloak` may not exist (modern clients hide via transmog). **Fixed a crash:** these were called unguarded; now shimmed to "always shown" | EquipmentCheck.lua | Find Forever's equivalent, or drop this sub-rule. [ShowingHelm / ShowingCloak] |
| **Insular** | Writes the language onto the chat edit box (taint risk under Midnight rules); hook targets may not exist; Skyborne has a new language; chat is secret during encounters | EventChallenges.lua | Test that `/say` still works after enforcement (no "action blocked"). Add Skyborne's language. [Languages, Chat edit box, live /say probe] |
| **Tame Son of Hakkar / Tame Bloodaxe Worg** | Now uses the spellcast fallback (target GUID → NPC ID). Both creatures are **inside instances** (ZG, LBRS), where creature GUIDs are secret | EventChallenges.lua | Fall back to `UnitCreatureFamily("pet")` + pet name after the tame, or a manual confirm button |
| **Scarlet Redemption / The New Plague** (destroy an item) | Uses `PickupInventoryItem` + `DeleteCursorItem`; deleting may be protected; Forever added `C_Item.DeleteItem` | EventChallenges.lua | Let the player delete the item themselves and detect that it's gone, instead of deleting it for them. [DeleteCursorItem] |
| **AddonComm** (nearby FCE players) | Sends *visible chat* to a custom channel with `SendChatMessage` (needs a hardware event; blocked during encounters) | AddonComm.lua | Migrate to `C_ChatInfo.SendAddonMessage` over the same channel or guild. Whisper button already changed to print `/w name`. [Addon messaging] |
| **Faction Loyalist, Diplomat, Old Horde, Catalog** for **Skyborne** | New race (High Order for Alliance, Windshaper for Horde); race token, home faction and language unknown | ChallengeCheck.lua (HOME_FACTION), EventChallenges.lua, CatalogUI.lua, CharacterData.lua | Add mappings once the race token is seen (`/fce apitest` prints it). [Race token] |
| **Diplomat** (another faction's mount) | Mounts are an account-wide collection now, so "owning" another faction's mount may be trivial or impossible | ChallengeCheck.lua | Rethink: e.g. *exalted with another faction* only, or the mount must be summoned on this character |
| **Homebound, Anti-undead / Pro-nature / Anti-demon / Aoe-farmer, Explorer** | Forever adds zones (Zephras Isle, Mount Hyjal, Riverglades…) and dungeons; uiMapIDs of reworked maps may differ | ZoneCheck.lua, ExplorerCheck.lua, ChallengeCheck.lua | Re-validate continent/zone mapIDs and exploration points against Forever. [Map position, Exploration] |
| **Content data** (quest IDs, item IDs, curated lists, NPC display IDs) | Classic IDs mostly carry over, but Forever changes quests and adds gear | CharacterData.lua (~850 quest refs), CuratedItems.lua, QuestChainData.lua | Spot-check against wowhead.com/forever; flag removed quests |
| **SavedVariables** | Beta restore bug (reportedly fixed) | — | `/fce apitest` has a relog canary. [SavedVariables restored] |

### SHIMMED (fixed in ForeverCompat.lua, confirm with `/fce apitest`)

Item info for all equipment rules (`GetItemInfo` → `C_Item`), spell info (`GetSpellInfo` → `C_Spell`), `IsSpellKnown`, `UnitBuff/UnitDebuff` (→ `C_UnitAuras`), reputation (`GetFactionInfo` → `C_Reputation`) for the whole **REPUTATION section**, professions and weapon skills (→ `C_SkillInfo`, with a `GetProfessions` fallback), completed quests (→ `C_QuestLog`), `SendChatMessage` (→ `C_ChatInfo`), chat filter/channel helpers (→ `ChatFrameUtil`).

### LIKELY OK

- **Spell-restriction challenges:** Pyromancer, Cryomancer, Firemancer, Light of Elune, Shadow Ascendant, Self-taught, All-out Assault, Overt, Lockdown, Truecaster, Windfury/Rockbiter Weapon, Master of Fire/Water, Retribution Aura, Agnostic, Imp, Voidwalker, No demons, Lone Wolf, Mortal pets. Your own casts stay readable even in combat. Watch for Forever class changes renaming spells.
- **Shapeshift systems:** Savagery, Spirit of Ursol / Ashamane / Aviana (`GetShapeshiftForm`).
- **Behavioural challenges:** Drifter, Ephemeral, Nocturnal, Diurnal. Could switch Nocturnal/Diurnal to the new `C_DateAndTime.IsDayTime()`.
- **Pet challenges:** hunter pet family requirements, Master Trainer (pet casts are readable), Master Smelter.
- **Event challenges:** Voodoo Ritual (open world), Seeking a Pardon, quest tracking, Quest Journal.
- **UI:** all panels (BackdropTemplate, gradients, portraits, timers).

## 3. To-do list

### Before launch (no game needed)

- [ ] **Aura-secret pause:** make Elixir Frenzy, Happy Hour, Doubt campfire and Demonic Sacrifice skip their tick while `FCE.Compat.AurasMayBeSecret()` is true.
- [ ] **MountCheck → C_MountJournal**, keyed on Classic mount spell IDs.
- [ ] **CompanionCheck → C_PetJournal**.
- [ ] **Kill events:** wire `PARTY_KILL` into Gnomish Justice and XXX.
- [ ] **Disease Cleansing:** rewrite on `UNIT_AURA` diffs plus your own cure casts.
- [ ] **Destroy-item challenges:** detect that the item is gone instead of deleting it.
- [ ] **AddonComm → `C_ChatInfo.SendAddonMessage`.**
- [ ] **TalentCheck:** draft a `C_Traits` version (name → rank map, points per tree), finalised with the day-one dump.
- [ ] **Re-check talent names** in TalentRequirements.lua against a Forever talent calculator (trees were reworked).
- [ ] **Skyborne placeholders:** HOME_FACTION entries for High Order / Windshaper, native language, Catalog race lists.
- [ ] **Diplomat:** decide the new rule (mounts are account-wide).
- [ ] **Zone lists:** add Forever's new zones/dungeons to the themed zone lists (Anti-demon → Mount Hyjal?) and Homebound continents.
- [ ] **Content IDs:** spot-check quest/item IDs against wowhead.com/forever.
- [ ] **Addon compartment:** add an `## AddonCompartmentFunc` entry so FCE shows in the modern addon compartment.

### Launch day (4 November)

1. Check the AddOns folder name in your install (the beta used `_classic_beta_`; the live client may differ) and copy `ForeverClassesEnhanced` there.
2. At character select, open AddOns. If FCE says *Out of date*, run `/dump select(4, GetBuildInfo())` in game and put that number in the `.toc`.
3. Log in out of combat, with some gear on and at least one buff (food or similar):
   - `/fce apitest talents` opens the report window. Ctrl+A, Ctrl+C, then paste it to me.
   - `/fce apitest live`, then cast any spell, `/say hello` and summon your pet (hunter/warlock), then run `/fce apitest` again.
   - Summon a companion pet and run `/fce apitest` once more (tests the companion path).
4. Log out **fully**, log back in and run `/fce apitest` to check the SavedVariables canary.
5. Combat test: get an elixir buff, fight a mob, and make sure Elixir Frenzy / Happy Hour don't drop.
6. Watch the AddOns panel's "Interface action failed" counter. It only resets after a full client restart.
7. With Insular active, check `/say` still works and doesn't cause "action blocked".

The report is also saved to `WTF\Account\<account>\SavedVariables\ForeverClassesEnhanced.lua` → `FCE_GlobalDB.apiReport`, in case the window is awkward.

## Sources

- Warcraft Wiki — Patch 1.60.1/API changes: https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes
- Warcraft Wiki — Patch 12.0.0/Planned API changes: https://warcraft.wiki.gg/wiki/Patch_12.0.0/Planned_API_changes
- Warcraft Wiki — TOC format: https://warcraft.wiki.gg/wiki/TOC_format
- Warcraft Wiki — SendChatMessage: https://warcraft.wiki.gg/wiki/API_SendChatMessage
- WoW Forever Builds — What the beta breaks for addons: https://wowforeverbuilds.com/news/what-the-wow-forever-beta-breaks-for-addons-secret-health-values-dead-secure-sni
- WoW Forever Guides — Addon developer guide / API cheat sheet / pitfalls: https://wowforeverguides.com/addons/developers
- Forever Codex — Addons & fixes: https://forever-codex.com/addons/
- Forever Codex — Mounts / Pets collections: https://forever-codex.com/collections/mounts/ , https://forever-codex.com/collections/pets/
- DragonShout issue #28 (CLEU removal, PARTY_KILL): https://github.com/Xerrion/DragonShout/issues/28
