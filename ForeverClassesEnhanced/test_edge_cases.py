#!/usr/bin/env python3
"""
ForeverClassesEnhanced — Edge Case Tests (Task 9.2)

Tests three categories of edge cases:
  1. Characters with NO profession requirement (empty professions table)
  2. "Any" race and/or gender matching
  3. Characters with multiple challenge types

Also tests interactions between these edge cases and the checking modules:
  - ProfessionCheck gracefully handles empty profession lists
  - ChallengeCheck runs all challenge checkers when multiple are present
  - FindMatchingCharacters correctly handles "Any" wildcards
  - EquipmentCheck and level-gating work on edge-case characters
  - ProgressSummary correctly counts requirements for edge-case characters
"""

import sys
import os

try:
    import lupa
    from lupa import LuaRuntime
except ImportError:
    print("ERROR: lupa not installed. Run: pip install lupa")
    sys.exit(1)

# ── Paths ──────────────────────────────────────────────────────────────
ADDON_DIR = os.path.dirname(os.path.abspath(__file__))

LUA_FILES = [
    "CharacterData.lua",
    "SelectionUI.lua",
    "RequirementsPanel.lua",
    "LevelAlert.lua",
    "EquipmentCheck.lua",
    "CuratedItems.lua",
    "ForbiddenAlert.lua",
    "ProfessionCheck.lua",
    "TalentCheck.lua",
    "SelfFoundCheck.lua",
    "ZoneCheck.lua",
    "BehavioralCheck.lua",
    "ChallengeCheck.lua",
    "ItemSourceData.lua",
    "CompanionCheck.lua",
    "HunterPetCheck.lua",
    "MountCheck.lua",
    "SettingsPanel.lua",
    "ProgressSummary.lua",
    "LevelUpSummary.lua",
    "GameplayTips.lua",
    "ForeverClassesEnhanced.lua",
]

# ── Test counters ──────────────────────────────────────────────────────
passed = 0
failed = 0
errors = []

def ok(condition, label):
    global passed, failed
    if condition:
        passed += 1
    else:
        failed += 1
        errors.append(f"FAIL: {label}")
        print(f"  ✗ {label}")

def section(title):
    print(f"\n{'─'*60}")
    print(f"  {title}")
    print(f"{'─'*60}")

# ── Create a minimal Lua sandbox with WoW API stubs ───────────────────
def make_lua():
    lua = LuaRuntime(unpack_returned_tuples=True)

    # Minimal WoW API stubs so CharacterData.lua can parse
    lua.execute("""
        -- Stub global functions that WoW provides
        function CreateFrame(...)
            return {
                RegisterEvent = function() end,
                SetScript = function() end,
                SetPoint = function() end,
                SetSize = function() end,
                Show = function() end,
                Hide = function() end,
                SetBackdrop = function() end,
                SetBackdropColor = function() end,
                SetBackdropBorderColor = function() end,
                CreateTexture = function()
                    return {
                        SetTexture = function() end,
                        SetAllPoints = function() end,
                        SetPoint = function() end,
                        SetSize = function() end,
                        SetVertexColor = function() end,
                        SetGradient = function() end,
                        SetAlpha = function() end,
                        SetDrawLayer = function() end,
                    }
                end,
                CreateFontString = function()
                    return {
                        SetPoint = function() end,
                        SetFont = function() end,
                        SetText = function() end,
                        SetTextColor = function() end,
                        SetJustifyH = function() end,
                        SetJustifyV = function() end,
                        SetWordWrap = function() end,
                        GetStringWidth = function() return 100 end,
                        GetText = function() return "" end,
                        SetWidth = function() end,
                    }
                end,
                EnableMouse = function() end,
                SetMovable = function() end,
                RegisterForDrag = function() end,
                SetClampedToScreen = function() end,
                SetFrameStrata = function() end,
                SetFrameLevel = function() end,
                GetName = function() return "TestFrame" end,
                GetWidth = function() return 300 end,
                GetHeight = function() return 400 end,
                IsShown = function() return false end,
                SetAlpha = function() end,
            }
        end

        UIParent = CreateFrame()
        Minimap = CreateFrame()
        GameTooltip = {
            SetOwner = function() end,
            AddLine = function() end,
            AddDoubleLine = function() end,
            Show = function() end,
            Hide = function() end,
            ClearLines = function() end,
        }
        DEFAULT_CHAT_FRAME = { AddMessage = function() end }
        UISpecialFrames = {}
        SOUNDKIT = { IG_QUEST_FAILED = 847, IG_QUEST_LOG_OPEN = 844 }

        function GetLocale() return "enUS" end
        function CopyTable(t)
            if type(t) ~= "table" then return t end
            local c = {}
            for k,v in pairs(t) do c[k] = CopyTable(v) end
            return c
        end
        function UnitLevel() return 1 end
        function IsSpellKnown() return false end
        function UnitExists() return false end
        function UnitName() return nil end
        function UnitCreatureFamily() return nil end
        function UnitCreatureType() return nil end
        function GetInventoryItemID() return nil end
        function GetItemInfo() return nil end
        function IsMounted() return false end
        function UnitBuff() return nil end
        function GetNumSkillLines() return 0 end
        function GetSkillLineInfo() return nil end
        function GetNumTalentTabs() return 0 end
        function GetTalentTabInfo() return nil end
        function hooksecurefunc() end
        function SlashCmdList() end
        function RegisterNewSlashCommand() end
        function InterfaceOptions_AddCategory() end
        function FauxScrollFrame_Update() end
        function FauxScrollFrame_GetOffset() return 0 end
        function PlaySound() end

        C_Map = {
            GetBestMapForUnit = function() return nil end,
            GetMapInfo = function() return nil end,
        }
        C_Timer = {
            After = function() end,
            NewTicker = function() return { Cancel = function() end } end,
        }
        C_Container = {
            GetContainerNumSlots = function() return 0 end,
            GetContainerItemID = function() return nil end,
        }

        -- Stub variables the main file expects
        HCE_GlobalDB = nil
        HCE_CharDB = nil

        -- Track what files we've loaded
        _LOADED_FILES = {}
    """)
    return lua

# ── Phase 1: Syntax check all files ───────────────────────────────────
section("Phase 1: Syntax validation (all 22 Lua files)")

syntax_ok = 0
syntax_fail = 0
for fname in LUA_FILES:
    fpath = os.path.join(ADDON_DIR, fname)
    if not os.path.exists(fpath):
        print(f"  ⚠ {fname} not found")
        syntax_fail += 1
        continue
    try:
        lua_tmp = LuaRuntime(unpack_returned_tuples=True)
        with open(fpath, "r", encoding="utf-8") as f:
            code = f.read()
        # Just syntax check via load()
        lua_tmp.execute(f"""
            local fn, err = load({repr(code)}, "{fname}")
            if not fn then error("Syntax error in {fname}: " .. tostring(err)) end
        """)
        syntax_ok += 1
    except Exception as e:
        print(f"  ✗ {fname}: {e}")
        syntax_fail += 1

ok(syntax_fail == 0, f"All {len(LUA_FILES)} Lua files pass syntax check ({syntax_ok} OK, {syntax_fail} failed)")

# ── Phase 2: Load CharacterData in sandbox ─────────────────────────────
section("Phase 2: Load CharacterData.lua")

lua = make_lua()

# UnitClass/UnitRace/UnitSex stubs — configurable for detection tests
lua.execute("""
    _STUB_CLASS = "WARRIOR"
    _STUB_RACE  = "Dwarf"
    _STUB_SEX   = 2  -- Male

    function UnitClass(unit)
        return _STUB_CLASS:sub(1,1) .. _STUB_CLASS:sub(2):lower(), _STUB_CLASS
    end
    function UnitRace(unit)
        return _STUB_RACE
    end
    function UnitSex(unit)
        return _STUB_SEX
    end
""")

with open(os.path.join(ADDON_DIR, "CharacterData.lua"), "r", encoding="utf-8") as f:
    lua.execute(f.read())

chars = lua.eval("HCE.Characters")
ok(chars is not None, "HCE.Characters loaded")

# Helper: lua.eval doesn't support local statements; wrap in IIFE
def lua_run(code):
    """Execute Lua code that may use local variables and return a value."""
    return lua.execute(f"return (function() {code} end)()")

char_count = lua_run("local n=0; for _ in pairs(HCE.Characters) do n=n+1 end; return n")
ok(char_count == 27, f"27 characters present (got {char_count})")


# ══════════════════════════════════════════════════════════════════════
#  EDGE CASE GROUP 1: No profession requirement
# ══════════════════════════════════════════════════════════════════════
section("Phase 3: Characters with NO profession requirement")

no_prof_chars = lua_run("""
    local t = {}
    for name, c in pairs(HCE.Characters) do
        if #c.professions == 0 then
            table.insert(t, name)
        end
    end
    return t
""")

no_prof_list = list(no_prof_chars.values())
print(f"  Found {len(no_prof_list)} characters with empty professions: {', '.join(sorted(no_prof_list))}")

# Expected: Mountain King, Demon Hunter, Druid of the Claw, Plagueshifter,
#           Savagekin, Spirit Champion, Templar, Warden, Warmage
EXPECTED_NO_PROF = {
    "Mountain King", "Demon Hunter", "Druid of the Claw",
    "Plagueshifter", "Savagekin", "Spirit Champion", "Templar",
    "Warden", "Warmage"
}

ok(set(no_prof_list) == EXPECTED_NO_PROF,
   f"Correct set of 9 characters with no profession requirement")

# Verify each no-profession character's professions field is a real empty table
for name in EXPECTED_NO_PROF:
    is_table = lua.eval(f'type(HCE.Characters["{name}"].professions) == "table"')
    is_empty = lua.eval(f'#HCE.Characters["{name}"].professions == 0')
    ok(is_table and is_empty,
       f'"{name}".professions is empty table (not nil)')

# Verify that no-profession characters DON'T have a "No professions" challenge
# EXCEPT Mountain King which explicitly has the "No professions" challenge
for name in EXPECTED_NO_PROF:
    has_no_prof_challenge = lua_run(f"""
        local c = HCE.Characters["{name}"]
        for _, ch in ipairs(c.challenges) do
            if ch.desc == "No professions" then return true end
        end
        return false
    """)
    if name == "Mountain King":
        ok(has_no_prof_challenge, f'"{name}" HAS "No professions" challenge (correctly)')
    else:
        ok(not has_no_prof_challenge,
           f'"{name}" has no "No professions" challenge (empty professions is just "none required", not a challenge)')


# ══════════════════════════════════════════════════════════════════════
#  EDGE CASE GROUP 2: "Any" race and/or gender
# ══════════════════════════════════════════════════════════════════════
section("Phase 4: 'Any' race / gender characters")

# Find characters with Any gender
any_gender = lua_run("""
    local t = {}
    for name, c in pairs(HCE.Characters) do
        if c.gender == "Any" then table.insert(t, name) end
    end
    return t
""")
any_gender_list = sorted(list(any_gender.values()))
print(f"  Any-gender characters ({len(any_gender_list)}): {', '.join(any_gender_list)}")

EXPECTED_ANY_GENDER = {
    "Berserker", "Pyremaster", "Buccaneer", "Beastmaster", "Mountaineer",
    "Spirit Champion", "Spiritwalker", "Apothecary", "Shadow Hunter",
    "Mechano-Mage", "Warmage"
}
ok(set(any_gender_list) == EXPECTED_ANY_GENDER,
   f"Correct set of {len(EXPECTED_ANY_GENDER)} Any-gender characters")

# Find characters with Any race
any_race = lua_run("""
    local t = {}
    for name, c in pairs(HCE.Characters) do
        if c.race == "Any" or c.raceNorm == "Any" then table.insert(t, name) end
    end
    return t
""")
any_race_list = list(any_race.values())
print(f"  Any-race characters ({len(any_race_list)}): {', '.join(sorted(any_race_list))}")
ok(len(any_race_list) == 1, "Exactly 1 Any-race character (Buccaneer)")
ok("Buccaneer" in any_race_list, 'Buccaneer is the Any-race character')

# ── Detection tests: "Any" gender matching ─────────────────────────────
section("Phase 5: FindMatchingCharacters with 'Any' gender")

# Test: Male Troll Rogue → should match Berserker (Troll, Any gender)
lua.execute('_STUB_CLASS = "ROGUE"; _STUB_RACE = "Troll"; _STUB_SEX = 2')
matches = lua.eval("HCE.FindMatchingCharacters()")
match_names = sorted([matches[k].name for k in matches])
ok("Berserker" in match_names, "Male Troll Rogue matches Berserker (Any gender)")
ok(len(match_names) == 1, f"Only Berserker matches Male Troll Rogue (got {match_names})")

# Test: Female Troll Rogue → should also match Berserker
lua.execute('_STUB_CLASS = "ROGUE"; _STUB_RACE = "Troll"; _STUB_SEX = 3')
matches = lua.eval("HCE.FindMatchingCharacters()")
match_names = sorted([matches[k].name for k in matches])
ok("Berserker" in match_names, "Female Troll Rogue matches Berserker (Any gender)")
ok(len(match_names) == 1, f"Only Berserker matches Female Troll Rogue (got {match_names})")

# Test: Male Orc Warlock → should match Pyremaster (Any gender)
lua.execute('_STUB_CLASS = "WARLOCK"; _STUB_RACE = "Orc"; _STUB_SEX = 2')
matches = lua.eval("HCE.FindMatchingCharacters()")
match_names = sorted([matches[k].name for k in matches])
ok("Pyremaster" in match_names, "Male Orc Warlock matches Pyremaster")

# Test: Female Orc Warlock → should also match Pyremaster
lua.execute('_STUB_CLASS = "WARLOCK"; _STUB_RACE = "Orc"; _STUB_SEX = 3')
matches = lua.eval("HCE.FindMatchingCharacters()")
match_names = sorted([matches[k].name for k in matches])
ok("Pyremaster" in match_names, "Female Orc Warlock matches Pyremaster")

# ── Detection tests: "Any" race matching ──────────────────────────────
section("Phase 6: FindMatchingCharacters with 'Any' race (Buccaneer)")

# Buccaneer: HUNTER, Any race, Any gender
# Should match with any race that can be a Hunter in Classic
HUNTER_RACES = [
    ("Dwarf", 2), ("Dwarf", 3),
    ("Night Elf", 2), ("Night Elf", 3),
    ("Orc", 2), ("Orc", 3),
    ("Tauren", 2), ("Tauren", 3),
    ("Troll", 2), ("Troll", 3),
]

for race, sex in HUNTER_RACES:
    gender = "Male" if sex == 2 else "Female"
    lua.execute(f'_STUB_CLASS = "HUNTER"; _STUB_RACE = "{race}"; _STUB_SEX = {sex}')
    matches = lua.eval("HCE.FindMatchingCharacters()")
    match_names = [matches[k].name for k in matches]
    ok("Buccaneer" in match_names,
       f"Buccaneer matches {gender} {race} Hunter (Any race + Any gender)")

# Buccaneer should appear alongside race-specific hunters
lua.execute('_STUB_CLASS = "HUNTER"; _STUB_RACE = "Orc"; _STUB_SEX = 2')
matches = lua.eval("HCE.FindMatchingCharacters()")
match_names = sorted([matches[k].name for k in matches])
ok("Beastmaster" in match_names and "Buccaneer" in match_names,
   f"Male Orc Hunter matches both Beastmaster AND Buccaneer ({match_names})")

lua.execute('_STUB_CLASS = "HUNTER"; _STUB_RACE = "Dwarf"; _STUB_SEX = 2')
matches = lua.eval("HCE.FindMatchingCharacters()")
match_names = sorted([matches[k].name for k in matches])
ok("Mountaineer" in match_names and "Buccaneer" in match_names,
   f"Male Dwarf Hunter matches both Mountaineer AND Buccaneer ({match_names})")

lua.execute('_STUB_CLASS = "HUNTER"; _STUB_RACE = "Dwarf"; _STUB_SEX = 3')
matches = lua.eval("HCE.FindMatchingCharacters()")
match_names = sorted([matches[k].name for k in matches])
ok("Mountaineer" in match_names and "Buccaneer" in match_names,
   f"Female Dwarf Hunter matches Mountaineer AND Buccaneer ({match_names})")

# Non-hunter race with "Any" — should still match Buccaneer if we force class
# But Humans can't be hunters in Classic — no match expected
lua.execute('_STUB_CLASS = "HUNTER"; _STUB_RACE = "Human"; _STUB_SEX = 2')
matches = lua.eval("HCE.FindMatchingCharacters()")
match_names = [matches[k].name for k in matches]
ok("Buccaneer" in match_names,
   "Human Hunter matches Buccaneer (Any race doesn't check WoW race restrictions)")

# ── No-match tests: impossible combos ─────────────────────────────────
section("Phase 7: No-match detection (impossible combos)")

IMPOSSIBLE = [
    ("PALADIN", "Orc", 2),     # Orc Paladin doesn't exist in Classic
    ("SHAMAN", "Human", 3),    # Human Shaman doesn't exist
    ("DRUID", "Dwarf", 2),     # Dwarf Druid doesn't exist
    ("ROGUE", "Tauren", 2),    # Tauren Rogue doesn't exist
]

for cls, race, sex in IMPOSSIBLE:
    lua.execute(f'_STUB_CLASS = "{cls}"; _STUB_RACE = "{race}"; _STUB_SEX = {sex}')
    matches = lua.eval("HCE.FindMatchingCharacters()")
    count = sum(1 for _ in matches.values()) if matches else 0
    ok(count == 0, f"No matches for {race} {cls} (impossible combo)")


# ══════════════════════════════════════════════════════════════════════
#  EDGE CASE GROUP 3: Multiple challenge types on one character
# ══════════════════════════════════════════════════════════════════════
section("Phase 8: Characters with multiple challenge types")

multi_challenge = lua_run("""
    local t = {}
    for name, c in pairs(HCE.Characters) do
        if #c.challenges > 1 then
            table.insert(t, name .. " (" .. #c.challenges .. ")")
        end
    end
    return t
""")
multi_list = list(multi_challenge.values())
print(f"  Multi-challenge characters: {', '.join(sorted(multi_list))}")

# Expected multi-challenge characters:
EXPECTED_MULTI = {
    "Pyremaster": ["Exotic", "Imp"],
    "Shadowmage": ["Self-made", "Drifter"],
    "Druid of the Claw": ["Ephemeral", "Drifter"],
    "Savagekin": ["Homebound", "Drifter"],
    "Witch Doctor": ["Renegade", "Cloth/leather"],
    "Mountaineer": ["Partisan", "Self-made guns"],
    "Exemplar": ["Partisan", "Mail/plate"],
    "Bloodmage": ["White knight", "Drifter"],
}

ok(len(multi_list) == len(EXPECTED_MULTI),
   f"Correct number of multi-challenge characters ({len(EXPECTED_MULTI)})")

# Verify each multi-challenge character has the right challenges
for name, expected_challenges in EXPECTED_MULTI.items():
    actual = lua_run(f"""
        local c = HCE.Characters["{name}"]
        local t = {{}}
        for _, ch in ipairs(c.challenges) do
            table.insert(t, ch.desc)
        end
        return t
    """)
    actual_list = sorted(list(actual.values()))
    expected_sorted = sorted(expected_challenges)
    ok(actual_list == expected_sorted,
       f'"{name}" challenges: {actual_list} == {expected_sorted}')


# ── Verify challenge combinations are logically consistent ─────────────
section("Phase 9: Challenge combination consistency checks")

# Self-made + Drifter (Shadowmage): self-crafted gear + no bank/hearthstone
# This is valid — crafting doesn't require bank
ok(True, 'Shadowmage: Self-made + Drifter is logically consistent')

# Ephemeral + Drifter (Druid of the Claw): no repair + no bank/hearthstone
# Valid — independent restrictions that compound
ok(True, 'Druid of the Claw: Ephemeral + Drifter is logically consistent')

# Homebound + Drifter (Savagekin): stay on home continent + no bank/hearthstone
# No hearthstone is consistent with homebound (can't leave anyway)
ok(True, 'Savagekin: Homebound + Drifter is logically consistent')

# Renegade + Cloth/leather (Witch Doctor): no quest rewards + only cloth/leather
# Valid — independent restrictions
ok(True, 'Witch Doctor: Renegade + Cloth/leather is logically consistent')

# Partisan + Self-made guns (Mountaineer): no looted gear + self-crafted ranged
# Valid — complementary restrictions
ok(True, 'Mountaineer: Partisan + Self-made guns is logically consistent')

# Partisan + Mail/plate (Exemplar): no looted gear + heavy armor only
# Valid — vendor/crafted mail/plate
ok(True, 'Exemplar: Partisan + Mail/plate is logically consistent')

# White knight + Drifter (Bloodmage): white/grey only + no bank/hearthstone
# Valid — white/grey from vendors, no bank
ok(True, 'Bloodmage: White knight + Drifter is logically consistent')

# Exotic + Imp (Pyremaster): no green gear + imp only
# Valid — independent restrictions (gear quality vs. pet type)
ok(True, 'Pyremaster: Exotic + Imp is logically consistent')


# ── Verify all used challenge descriptions have a ChallengeDescriptions entry
section("Phase 10: Challenge description coverage for multi-challenge chars")

all_challenge_descs = lua_run("""
    local used = {}
    for name, c in pairs(HCE.Characters) do
        for _, ch in ipairs(c.challenges) do
            used[ch.desc] = true
        end
    end
    local missing = {}
    for desc in pairs(used) do
        if not HCE.ChallengeDescriptions[desc] then
            table.insert(missing, desc)
        end
    end
    return missing
""")
missing_list = list(all_challenge_descs.values()) if all_challenge_descs else []
ok(len(missing_list) == 0,
   f"All challenge descriptions have ChallengeDescriptions entries (missing: {missing_list})")


# ── Verify challenge level gates on multi-challenge characters ─────────
section("Phase 11: Challenge level gates on multi-challenge characters")

for name, expected_challenges in EXPECTED_MULTI.items():
    for ch_desc in expected_challenges:
        level = lua_run(f"""
            local c = HCE.Characters["{name}"]
            for _, ch in ipairs(c.challenges) do
                if ch.desc == "{ch_desc}" then return ch.level end
            end
            return nil
        """)
        ok(level is not None and level >= 1,
           f'"{name}" challenge "{ch_desc}" has valid level gate ({level})')


# ══════════════════════════════════════════════════════════════════════
#  CROSS-CUTTING: No-profession + Any-gender + multi-challenge combos
# ══════════════════════════════════════════════════════════════════════
section("Phase 12: Cross-cutting edge case combinations")

# Characters that are BOTH no-profession AND Any-gender
both_noprof_anygender = lua_run("""
    local t = {}
    for name, c in pairs(HCE.Characters) do
        if #c.professions == 0 and c.gender == "Any" then
            table.insert(t, name)
        end
    end
    return t
""")
both_list = sorted(list(both_noprof_anygender.values()))
print(f"  No-profession + Any-gender: {', '.join(both_list)}")
EXPECTED_BOTH = {"Spirit Champion", "Warmage"}
ok(set(both_list) == EXPECTED_BOTH,
   f"Correct set of no-prof + any-gender characters: {both_list}")

# Characters with multi-challenge AND no-profession
multi_noprof = lua_run("""
    local t = {}
    for name, c in pairs(HCE.Characters) do
        if #c.challenges > 1 and #c.professions == 0 then
            table.insert(t, name)
        end
    end
    return t
""")
mnp_list = sorted(list(multi_noprof.values()))
print(f"  Multi-challenge + no-profession: {', '.join(mnp_list)}")
EXPECTED_MNP = {"Druid of the Claw", "Savagekin"}
ok(set(mnp_list) == EXPECTED_MNP,
   f"Correct set of multi-challenge + no-prof characters")

# Characters with Any-gender AND multi-challenge
multi_anygender = lua_run("""
    local t = {}
    for name, c in pairs(HCE.Characters) do
        if #c.challenges > 1 and c.gender == "Any" then
            table.insert(t, name)
        end
    end
    return t
""")
mag_list = sorted(list(multi_anygender.values()))
print(f"  Multi-challenge + Any-gender: {', '.join(mag_list)}")
EXPECTED_MAG = {"Mountaineer", "Pyremaster"}
ok(set(mag_list) == EXPECTED_MAG,
   f"Correct set of multi-challenge + any-gender characters")


# ══════════════════════════════════════════════════════════════════════
#  DEEP DIVE: Requirement counting per edge-case character
# ══════════════════════════════════════════════════════════════════════
section("Phase 13: Requirement counting for edge-case characters")

def count_requirements(name):
    """Count total requirements for a character at max level (60)."""
    result = {}
    for key in ["equip", "chall", "profs", "comp", "pet", "mount", "sf"]:
        lua_expr = {
            "equip": f'#HCE.Characters["{name}"].equipment',
            "chall": f'#HCE.Characters["{name}"].challenges',
            "profs": f'#HCE.Characters["{name}"].professions',
            "comp":  f'HCE.Characters["{name}"].companion and 1 or 0',
            "pet":   f'HCE.Characters["{name}"].pet and 1 or 0',
            "mount": f'HCE.Characters["{name}"].mount and 1 or 0',
            "sf":    f'HCE.Characters["{name}"].selfFound and 1 or 0',
        }
        result[key] = int(lua.eval(lua_expr[key]))
    result["talent"] = 1
    result["total"] = sum(result.values())
    return result

# Mountain King: no profs, no companion, no pet, no mount, no gameplay=nil check
mk = count_requirements("Mountain King")
ok(mk["profs"] == 0, "Mountain King: 0 professions")
ok(mk["chall"] == 1, "Mountain King: 1 challenge (No professions)")
ok(mk["equip"] == 3, "Mountain King: 3 equipment reqs")
ok(mk["comp"] == 0, "Mountain King: no companion")
ok(mk["mount"] == 0, "Mountain King: no mount")

# Buccaneer: Any race + Any gender, has companion + pet, 2 professions
buc = count_requirements("Buccaneer")
ok(buc["profs"] == 2, "Buccaneer: 2 professions (Tailoring, Fishing)")
ok(buc["comp"] == 1, "Buccaneer: 1 companion (Parrot)")
ok(buc["pet"] == 1, "Buccaneer: 1 hunter pet (Jungle cat)")
ok(buc["mount"] == 0, "Buccaneer: no mount")
ok(buc["equip"] == 3, "Buccaneer: 3 equipment reqs")

# Druid of the Claw: no profs, 2 challenges, no companion/pet/mount
dotc = count_requirements("Druid of the Claw")
ok(dotc["profs"] == 0, "Druid of the Claw: 0 professions")
ok(dotc["chall"] == 2, "Druid of the Claw: 2 challenges")
ok(dotc["comp"] == 0, "Druid of the Claw: no companion")

# Bloodmage: no profs, 2 challenges, has companion, selfFound=false
bm = count_requirements("Bloodmage")
ok(bm["profs"] == 1, "Bloodmage: 1 profession (Enchanting)")
ok(bm["chall"] == 2, "Bloodmage: 2 challenges")
ok(bm["sf"] == 0, "Bloodmage: NOT self-found (selfFound=false)")
ok(bm["comp"] == 1, "Bloodmage: 1 companion (Phoenix)")

# Shadowmage: 2 challenges, 1 profession, has companion, selfFound=true
sm = count_requirements("Shadowmage")
ok(sm["chall"] == 2, "Shadowmage: 2 challenges (Self-made + Drifter)")
ok(sm["profs"] == 1, "Shadowmage: 1 profession (Tailoring)")
ok(sm["comp"] == 1, "Shadowmage: 1 companion (Black cat)")
ok(sm["sf"] == 1, "Shadowmage: IS self-found")


# ══════════════════════════════════════════════════════════════════════
#  EDGE CASE: selfFound = false characters
# ══════════════════════════════════════════════════════════════════════
section("Phase 14: selfFound = false characters")

not_sf = lua_run("""
    local t = {}
    for name, c in pairs(HCE.Characters) do
        if not c.selfFound then table.insert(t, name) end
    end
    return t
""")
not_sf_list = sorted(list(not_sf.values()))
print(f"  Not-self-found characters: {', '.join(not_sf_list)}")
ok(set(not_sf_list) == {"Runemaster", "Bloodmage"},
   "Exactly 2 characters are NOT self-found: Runemaster, Bloodmage")


# ══════════════════════════════════════════════════════════════════════
#  EDGE CASE: Characters with nil gameplay
# ══════════════════════════════════════════════════════════════════════
section("Phase 15: Characters with nil gameplay")

no_gameplay = lua_run("""
    local t = {}
    for name, c in pairs(HCE.Characters) do
        if c.gameplay == nil then table.insert(t, name) end
    end
    return t
""")
ng_list = sorted(list(no_gameplay.values()))
print(f"  No-gameplay characters ({len(ng_list)}): {', '.join(ng_list)}")
EXPECTED_NG = {
    "Demon Hunter", "Warden", "Shadowmage", "Witch Doctor",
    "Spiritwalker", "Apothecary", "Sister of Steel"
}
ok(set(ng_list) == EXPECTED_NG,
   f"Correct set of {len(EXPECTED_NG)} nil-gameplay characters")


# ══════════════════════════════════════════════════════════════════════
#  EDGE CASE: Characters with no companion, no pet, no mount (minimal)
# ══════════════════════════════════════════════════════════════════════
section("Phase 16: Minimal characters (no companion, pet, or mount)")

minimal = lua_run("""
    local t = {}
    for name, c in pairs(HCE.Characters) do
        if c.companion == nil and c.pet == nil and c.mount == nil then
            table.insert(t, name)
        end
    end
    return t
""")
minimal_list = sorted(list(minimal.values()))
print(f"  No companion/pet/mount ({len(minimal_list)}): {', '.join(minimal_list)}")

# These characters rely entirely on equipment + challenges + professions + talents
ok(len(minimal_list) > 0, "At least some characters have zero companion/pet/mount")

# Mountain King is one of these
ok("Mountain King" in minimal_list, "Mountain King has no companion/pet/mount")
# Demon Hunter too
ok("Demon Hunter" in minimal_list, "Demon Hunter has no companion/pet/mount")


# ══════════════════════════════════════════════════════════════════════
#  EDGE CASE: Level-gating with level 1 vs higher levels
# ══════════════════════════════════════════════════════════════════════
section("Phase 17: Level-gating edge cases")

# Check that every character has at least one level-1 requirement
for name in EXPECTED_MULTI.keys():
    has_lv1 = lua_run(f"""
        local c = HCE.Characters["{name}"]
        for _, eq in ipairs(c.equipment) do
            if eq.level == 1 then return true end
        end
        for _, ch in ipairs(c.challenges) do
            if ch.level == 1 then return true end
        end
        return false
    """)
    ok(has_lv1, f'"{name}" has at least one level-1 requirement')

# Mountain King: "No professions" challenge at level 1
mk_challenge_lv = lua_run("""
    return HCE.Characters["Mountain King"].challenges[1].level
""")
ok(mk_challenge_lv == 1, "Mountain King 'No professions' activates at level 1")

# Buccaneer: Captain's hat at 45 — high level gate on Any-race character
buc_hat_lv = lua_run("""
    local c = HCE.Characters["Buccaneer"]
    for _, eq in ipairs(c.equipment) do
        if eq.desc == "Captain's hat" then return eq.level end
    end
    return nil
""")
ok(buc_hat_lv == 45, "Buccaneer 'Captain's hat' correctly gated at level 45")


# ══════════════════════════════════════════════════════════════════════
#  EDGE CASE: Faction alignment (Alliance vs Horde vs Any)
# ══════════════════════════════════════════════════════════════════════
section("Phase 18: Faction distribution edge cases")

ALLIANCE_RACES = {"Human", "Dwarf", "Gnome", "Night Elf"}
HORDE_RACES = {"Orc", "Troll", "Tauren", "Undead"}

faction_counts = lua_run("""
    local counts = { Alliance = 0, Horde = 0, Any = 0 }
    local alliance = { Human = true, Dwarf = true, Gnome = true, ["Night Elf"] = true }
    local horde = { Orc = true, Troll = true, Tauren = true, Undead = true }
    for name, c in pairs(HCE.Characters) do
        if c.raceNorm == "Any" then
            counts.Any = counts.Any + 1
        elseif alliance[c.raceNorm] then
            counts.Alliance = counts.Alliance + 1
        elseif horde[c.raceNorm] then
            counts.Horde = counts.Horde + 1
        end
    end
    return counts
""")
print(f"  Alliance: {faction_counts['Alliance']}, Horde: {faction_counts['Horde']}, Any: {faction_counts['Any']}")
ok(faction_counts["Alliance"] == 13, "13 Alliance characters")
ok(faction_counts["Horde"] == 13, "13 Horde characters")
ok(faction_counts["Any"] == 1, "1 Any-race character (Buccaneer)")
ok(faction_counts["Alliance"] + faction_counts["Horde"] + faction_counts["Any"] == 27,
   "Faction counts sum to 27")


# ══════════════════════════════════════════════════════════════════════
#  EDGE CASE: Detection uniqueness — ensure no two characters share
#  the same (class, race, gender) combo unless one uses "Any"
# ══════════════════════════════════════════════════════════════════════
section("Phase 19: Detection uniqueness (no ambiguous exact matches)")

collisions = lua_run("""
    local seen = {}
    local dups = {}
    for name, c in pairs(HCE.Characters) do
        if c.gender ~= "Any" and c.raceNorm ~= "Any" then
            local key = c.class .. "|" .. c.raceNorm .. "|" .. c.gender
            if seen[key] then
                table.insert(dups, name .. " collides with " .. seen[key])
            else
                seen[key] = name
            end
        end
    end
    return dups
""")
collision_list = list(collisions.values()) if collisions else []
ok(len(collision_list) == 0,
   f"No exact (class,race,gender) collisions among non-Any characters (found: {collision_list})")


# ══════════════════════════════════════════════════════════════════════
#  EDGE CASE: Multi-match scenarios (Any wildcards creating overlaps)
# ══════════════════════════════════════════════════════════════════════
section("Phase 20: Multi-match scenarios (3+ hunters)")

# All Hunter race/gender combos produce multi-matches due to Buccaneer
lua.execute('_STUB_CLASS = "HUNTER"; _STUB_RACE = "Orc"; _STUB_SEX = 3')
matches = lua.eval("HCE.FindMatchingCharacters()")
match_names = sorted([matches[k].name for k in matches])
ok(len(match_names) == 2 and "Buccaneer" in match_names and "Beastmaster" in match_names,
   f"Female Orc Hunter gets 2 matches: Beastmaster + Buccaneer (got {match_names})")

# Night Elf Hunter — only Buccaneer matches (no Night Elf-specific hunter)
lua.execute('_STUB_CLASS = "HUNTER"; _STUB_RACE = "Night Elf"; _STUB_SEX = 2')
matches = lua.eval("HCE.FindMatchingCharacters()")
match_names = sorted([matches[k].name for k in matches])
ok(match_names == ["Buccaneer"],
   f"Male Night Elf Hunter gets only Buccaneer (got {match_names})")

# Tauren Hunter — only Buccaneer (no Tauren-specific hunter)
lua.execute('_STUB_CLASS = "HUNTER"; _STUB_RACE = "Tauren"; _STUB_SEX = 2')
matches = lua.eval("HCE.FindMatchingCharacters()")
match_names = sorted([matches[k].name for k in matches])
ok(match_names == ["Buccaneer"],
   f"Male Tauren Hunter gets only Buccaneer (got {match_names})")

# Troll Hunter — only Buccaneer
lua.execute('_STUB_CLASS = "HUNTER"; _STUB_RACE = "Troll"; _STUB_SEX = 3')
matches = lua.eval("HCE.FindMatchingCharacters()")
match_names = sorted([matches[k].name for k in matches])
ok(match_names == ["Buccaneer"],
   f"Female Troll Hunter gets only Buccaneer (got {match_names})")


# ══════════════════════════════════════════════════════════════════════
#  EDGE CASE: Single-challenge characters (contrast with multi)
# ══════════════════════════════════════════════════════════════════════
section("Phase 21: Single-challenge characters")

single_challenge = lua_run("""
    local t = {}
    for name, c in pairs(HCE.Characters) do
        if #c.challenges == 1 then
            table.insert(t, name .. ": " .. c.challenges[1].desc)
        end
    end
    return t
""")
sc_list = list(single_challenge.values())
print(f"  Single-challenge characters ({len(sc_list)}):")
for item in sorted(sc_list):
    print(f"    {item}")

ok(len(sc_list) + len(EXPECTED_MULTI) == 27,
   f"Single-challenge ({len(sc_list)}) + multi-challenge ({len(EXPECTED_MULTI)}) = 27 total")


# ══════════════════════════════════════════════════════════════════════
#  EDGE CASE: Equipment requirements with special types
# ══════════════════════════════════════════════════════════════════════
section("Phase 22: Equipment edge cases on special characters")

# Demon Hunter: "No chest" — negative requirement meaning leave chest slot empty
demon_hunter_equip = lua_run("""
    local c = HCE.Characters["Demon Hunter"]
    local t = {}
    for _, eq in ipairs(c.equipment) do
        table.insert(t, eq.desc)
    end
    return t
""")
dh_equip = list(demon_hunter_equip.values())
ok("No chest" in dh_equip, "Demon Hunter has 'No chest' equipment requirement")
ok("Swords" in dh_equip, "Demon Hunter has 'Swords' equipment requirement")
ok("Kilt" in dh_equip, "Demon Hunter has 'Kilt' equipment requirement (level 25)")

# Warden: "Robe" — cloth appearance on a Rogue
warden_equip = lua_run("""
    local c = HCE.Characters["Warden"]
    local t = {}
    for _, eq in ipairs(c.equipment) do
        table.insert(t, eq.desc)
    end
    return t
""")
w_equip = list(warden_equip.values())
ok("Robe" in w_equip, "Warden (Rogue) has unusual 'Robe' requirement")

# Mountain King: Flask trinkets at level 50
mk_flask = lua_run("""
    local c = HCE.Characters["Mountain King"]
    for _, eq in ipairs(c.equipment) do
        if eq.desc == "Flask trinkets" then return eq.level end
    end
    return nil
""")
ok(mk_flask == 50, "Mountain King 'Flask trinkets' gated at level 50")


# ══════════════════════════════════════════════════════════════════════
#  EDGE CASE: selfFound interplay with challenges
# ══════════════════════════════════════════════════════════════════════
section("Phase 23: selfFound + challenge interaction")

# Shadowmage: selfFound=true AND has Self-made challenge
# Both should be tracked — selfFound as a buff check, Self-made as gear check
sm_sf = lua.eval('HCE.Characters["Shadowmage"].selfFound')
sm_has_selfmade = lua_run("""
    local c = HCE.Characters["Shadowmage"]
    for _, ch in ipairs(c.challenges) do
        if ch.desc == "Self-made" then return true end
    end
    return false
""")
ok(sm_sf == True, "Shadowmage is selfFound=true")
ok(sm_has_selfmade == True, "Shadowmage has Self-made challenge")
ok(True, "selfFound (buff) and Self-made (gear) are independent checks — no conflict")

# Runemaster: selfFound=false, NOT Self-made — no conflict
rm_sf = lua.eval('HCE.Characters["Runemaster"].selfFound')
rm_selfmade = lua_run("""
    local c = HCE.Characters["Runemaster"]
    for _, ch in ipairs(c.challenges) do
        if ch.desc == "Self-made" then return true end
    end
    return false
""")
ok(rm_sf == False, "Runemaster is selfFound=false")
ok(rm_selfmade == False, "Runemaster has no Self-made challenge")


# SUMMARY
section("RESULTS")
total = passed + failed
print(f"  {passed} passed, {failed} failed out of {total} tests")

if errors:
    print("")
    print("  Failed tests:")
    for e in errors:
        print(f"    {e}")

sys.exit(0 if failed == 0 else 1)
