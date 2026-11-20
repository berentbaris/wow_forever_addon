# Handoff — context for a new Claude session

Read this first if you're a fresh Claude session picking up Forever Classes Enhanced work.
Written 20 Nov 2026 at the end of a long session on Beba's other PC.

## The projects

| Repo | What it is |
|---|---|
| `berentbaris/wow_addon` → `ClassicClassesEnhanced/` | **CCE**: Classic Era addon (interface 11509, global `CCE`, SavedVariables `CCE_GlobalDB` / `CCE_CharDB` / `CCE_AccountDB`). Live, versioned via `build.py` zips. |
| `berentbaris/wow_forever_addon` → `ForeverClassesEnhanced/` | **FCE**: port of CCE to WoW Forever (interface 16001, global `FCE`, SavedVariables `FCE_*`, slash `/fce`). Forever launched 4 Nov 2026. |
| `berentbaris/cce-wiki` | Wiki site (has `cce_logo.png`). |

FCE was made by copying CCE and renaming `CCE`→`FCE` everywhere (`(?<![A-Za-z])CCE` regex, so `SUCCESS` is untouched), `ClassicClassesEnhanced`→`ForeverClassesEnhanced`, `/cce`→`/fce`. Legacy frame names starting with `HCE_` were intentionally left alone.

## Why FCE differs from CCE: Forever uses the modern (Midnight) API

Forever plays like Classic but runs on the Mainline 12.1.x addon API with Midnight's restrictions (secret values, no combat log). Full research and per-requirement risk table: **`FOREVER_TODO.md`**. Key points:

- `ForeverCompat.lua` loads first. It wraps missing Classic globals (`GetSpellInfo`, `GetItemInfo`, `UnitBuff`, `GetFactionInfo`, `GetSkillLineInfo`, `GetQuestsCompleted`, `SendChatMessage`, `ShowingHelm`…) into Classic-shaped functions on `FCE.Compat`. Each file pulls the ones it uses into locals via a line marked `-- Forever API shims (ForeverCompat.lua)`. No replacement globals are written. Native functions are preferred when they exist.
- `APIProbe.lua`: `/fce apitest` (and `talents`, `live` variants) tests every API and event FCE relies on, maps failures to requirements, shows a copyable report and saves it to `FCE_GlobalDB.apiReport`. **The first real-Forever run of this is the top priority.** Beba ran it on Classic Era (fine); nobody has run it on Forever yet.
- The combat-log registration is skipped on Forever; cast-based challenges fall back to `UNIT_SPELLCAST_SUCCEEDED` (player/pet casts aren't secret).
- Known BROKEN on Forever: talents (C_Traits), mounts and companions (account journals, not bag items), Disease Cleansing / Gnomish Justice / XXX (needed the combat log). Known AT RISK: aura timers in combat (Elixir Frenzy, Happy Hour, Doubt campfire: need pausing via `FCE.Compat.AurasMayBeSecret()`), Insular, Self-Found, destroy-item rituals, AddonComm, Skyborne race mappings.

## Done recently (both addons unless noted)

- REPUTATION section in RequirementsPanel (split from CHALLENGES via a `REPUTATION_RULES` set, also in CatalogUI and ProgressSummary). CCE + FCE.
- FCE logo generated in Canva (full-res in Beba's Canva uploads; `fce_logo_preview.png` is a 200px preview).
- FCE minimap icon `Textures/minimap_fce.tga`: a pixel-exact copy of the user-made CCE icon style (64×64, 24-bit TGA, top-left origin, bg 20,20,28, gold 230,180,34, plain sans letters; F made from the original E). **Keep this flat style; a glowing version was unreadable in game.**
- AddonComm channel renamed `hce`→`cce` (CCE) / `fce` (FCE); leaves the legacy `hce` channel; `fixChannelOrder()` moves the comm channel below Blizzard channels via `C_ChatInfo.SwapChatChannelsByChannelIndex` (it used to land on /1). Untested in game.
- `core_classes.xlsx`: all 53 classes rated yes (33) / later (12) / no (8) for Forever launch, with reasons and notes. Beba wants to cut down to "core classes"; this sheet is the basis.

## Open to-do (priority order)

1. Run `/fce apitest`, `/fce apitest talents`, `/fce apitest live` on Forever and act on the report (launch-day checklist in FOREVER_TODO.md §3).
2. Pause aura-based timers while auras are secret (small).
3. MountCheck → `C_MountJournal`; CompanionCheck → `C_PetJournal`.
4. TalentCheck → `C_Traits` (use the talent dump), and re-check talent names against Forever's reworked trees.
5. Trim FCE's class roster per `core_classes.xlsx`.
6. Skyborne race (High Order / Windshaper): home faction, language, Catalog.
7. Kill events via `PARTY_KILL`; Disease Cleansing via `UNIT_AURA`; destroy-item challenges detect the item is gone instead of deleting it.

## Working conventions and gotchas

- Beba prefers concise answers, direct action, and keeping CCE and FCE in sync when a change applies to both.
- The Edit tool can silently truncate very large edits (~500+ lines); prefer several smaller edits.
- `FCE.CuratedItems` tables have an `_order` key: skip it when iterating with `pairs()`.
- `SendChatMessage` to SAY/YELL/CHANNEL needs a hardware event (AddonComm drains a queue on mouse/key presses).
- Quest/NPC links use classicdb.ch format `/?quest=ID`, `/?npc=ID` (CCE).
- Syntax-check Lua with Python `lupa` (`load(src)` returns the error) when no `luac` is available.
- `E(desc, level, endLevel)` = requirement entry, `Q(name, level, questID)` = quest, `R(name, fn)` = challenge rule in ChallengeCheck.lua.
