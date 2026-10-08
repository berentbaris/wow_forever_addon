----------------------------------------------------------------------
-- ForeverClassesEnhanced — API self-test   (/fce apitest)
--
-- Probes every game API and event FCE depends on and reports, per
-- requirement, whether the data we need is actually available on this
-- client.  Built for WoW Forever launch day: run it once, then copy the
-- report from the window (Ctrl+A, Ctrl+C) or grab FCE_GlobalDB.apiReport
-- from WTF\Account\<account>\SavedVariables\ForeverClassesEnhanced.lua
--
--   /fce apitest           run every probe, open the report window
--   /fce apitest talents   also dump the talent tree (C_Traits) layout
--   /fce apitest live      arm live probes for 2 minutes: cast any
--                          spell, /say something, summon your pet
--
-- Status meanings:
--   OK    the API exists and returned the data we need
--   WARN  works partially / needs a code change to be reliable
--   FAIL  missing or unusable — the listed requirements won't track
--   SKIP  couldn't test right now (e.g. no pet out) — read the hint
--   INFO  informational only
--
-- Probes never perform actions with side effects (no chat sends, no
-- item deletes, no emotes) — those are existence checks only.
----------------------------------------------------------------------

FCE = FCE or {}
local Probe = {}
FCE.APIProbe = Probe

local C = FCE.Compat

local OK, WARN, FAIL, SKIP, INFO = "OK", "WARN", "FAIL", "SKIP", "INFO"
local ORDER  = { OK, WARN, FAIL, SKIP, INFO }
local COLORS = { OK = "4de64d", WARN = "e6b422", FAIL = "ff5a4c", SKIP = "888888", INFO = "7fb2ff" }

local probes = {}
local function P(area, name, uses, fn)
    probes[#probes + 1] = { area = area, name = name, uses = uses, fn = fn }
end

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------

local function isFunc(f) return type(f) == "function" end

-- Resolve "A.B.C" from _G without erroring
local function G(path)
    local t = _G
    for part in string.gmatch(path, "[^%.]+") do
        if type(t) ~= "table" then return nil end
        t = t[part]
    end
    return t
end

local function exists(path) return isFunc(G(path)) end
local function secret(v) return C.IsSecret(v) end
local function plain(v, fb) return C.Plain(v, fb or "<secret>") end
local function s(v) return tostring(plain(v)) end

local scratch = CreateFrame("Frame")

-- Is an event name valid?  Prefers C_EventUtils (no side effects).
-- noRegister: never fall back to RegisterEvent (used for the combat log,
-- where a forbidden registration can raise the "addon blocked" popup).
local function eventValid(ev, noRegister)
    if C_EventUtils and isFunc(C_EventUtils.IsEventValid) then
        local ok, v = pcall(C_EventUtils.IsEventValid, ev)
        if ok then return v and true or false end
    end
    if noRegister then return nil end
    local ok, res = pcall(scratch.RegisterEvent, scratch, ev)
    if ok and res ~= false then
        pcall(scratch.UnregisterEvent, scratch, ev)
        return true
    end
    return false
end

local function needFunc(area, path, uses, missingStatus, missingNote)
    P(area, path .. "()", uses, function()
        if exists(path) then return OK, "present" end
        return missingStatus or FAIL, missingNote or "missing"
    end)
end

-- A Classic global we shim: report native / via alternative / missing
local function shimmed(area, name, uses, altPath)
    P(area, name .. "()", uses, function()
        if exists(name) then return OK, "native global" end
        if altPath and exists(altPath) then return OK, "missing, using " .. altPath .. " (shim)" end
        return FAIL, "missing" .. (altPath and (", and " .. altPath .. " missing too") or "")
    end)
end

local function needEvent(area, ev, uses, missingStatus)
    P(area, "event " .. ev, uses, function()
        local v = eventValid(ev)
        if v then return OK, "valid" end
        if v == nil then return SKIP, "couldn't check" end
        return missingStatus or FAIL, "not a valid event on this client"
    end)
end

local function firstEquippedSlot()
    if not isFunc(GetInventoryItemID) then return nil end
    for slot = 1, 19 do
        local id = GetInventoryItemID("player", slot)
        if id then return slot, id end
    end
end

local canarySetThisSession = false

----------------------------------------------------------------------
-- 1. Client
----------------------------------------------------------------------

P("Client", "Interface version", "everything", function()
    local build = select(2, GetBuildInfo())
    if C.IS_FOREVER then
        return OK, C.TOC_VERSION .. " (build " .. tostring(build) .. ")"
    end
    return WARN, C.TOC_VERSION .. " — not a Forever client (expected 16xxx). Update ## Interface in the .toc if Forever moved"
end)

P("Client", "Game type detection", "client detection in ForeverCompat", function()
    return INFO, "WOW_PROJECT_ID=" .. tostring(WOW_PROJECT_ID)
        .. ", LE_EXPANSION_LEVEL_CURRENT=" .. tostring(LE_EXPANSION_LEVEL_CURRENT)
        .. ", LE_EXPANSION_CLASSIC=" .. tostring(LE_EXPANSION_CLASSIC)
end)

P("Client", "issecretvalue()", "secret-value guards everywhere", function()
    if exists("issecretvalue") then return INFO, "present — Midnight secret-value rules are active" end
    return INFO, "absent — no secret values on this client"
end)

P("Client", "SavedVariables restored after relog",
  "all saved progress: Doubt, Savagery, Happy Hour, Elixir, event challenges, achievements, zone history",
  function()
    local db = FCE_GlobalDB
    if type(db) ~= "table" then return FAIL, "FCE_GlobalDB is nil — SavedVariables not loaded" end
    if canarySetThisSession then
        return SKIP, "canary was written earlier this session — log out fully, log back in, run again"
    end
    if db._probeCanary then
        return OK, "data from a previous session was restored (" .. date("%Y-%m-%d %H:%M", db._probeCanary) .. ")"
    end
    return WARN, "no data from a previous session — either first run, or the client isn't restoring SavedVariables (known beta bug). Log out fully, back in, run again"
end)

----------------------------------------------------------------------
-- 2. Character identity
----------------------------------------------------------------------

P("Character", "Player identity (name/class/race/sex/level)",
  "character auto-match, Catalog, every level-gated requirement",
  function()
    local name = UnitName("player")
    local _, cls = UnitClass("player")
    local race, raceTok = UnitRace("player")
    local sex, lvl = UnitSex("player"), UnitLevel("player")
    for _, v in ipairs({ name, cls, raceTok, sex, lvl }) do
        if secret(v) then return FAIL, "a player identity value is secret" end
    end
    if not (name and cls and raceTok and sex and lvl) then return FAIL, "a value came back nil" end
    return OK, string.format("%s — %s %s (race token %s), sex %s, level %s",
        name, tostring(race), cls, raceTok, tostring(sex), tostring(lvl))
end)

P("Character", "Race token is known to FCE",
  "Faction Loyalist, Insular, Diplomat, Old Horde, Catalog race filters, portraits",
  function()
    local _, tok = UnitRace("player")
    local known = { Human = 1, Dwarf = 1, NightElf = 1, Gnome = 1,
                    Orc = 1, Scourge = 1, Tauren = 1, Troll = 1 }
    if known[tok] then return OK, tostring(tok) end
    return WARN, "unknown race token '" .. s(tok) .. "' (Skyborne?) — add it to HOME_FACTION (ChallengeCheck), native language (EventChallenges), CatalogUI race tables"
end)

P("Character", "UnitFactionGroup", "faction-specific characters, achievements, portraits", function()
    local f = UnitFactionGroup("player")
    if secret(f) then return FAIL, "secret" end
    if not f then return FAIL, "nil" end
    return OK, f
end)

P("Character", "C_GameRules (self-found / hardcore)", "Self-Found, Not self-found", function()
    if type(C_GameRules) ~= "table" then return WARN, "C_GameRules missing" end
    local parts = {}
    for _, fn in ipairs({ "IsSelfFoundAllowed", "IsHardcoreActive" }) do
        if isFunc(C_GameRules[fn]) then
            local ok, v = pcall(C_GameRules[fn])
            parts[#parts + 1] = fn .. "=" .. (ok and s(v) or "error")
        else
            parts[#parts + 1] = fn .. " missing"
        end
    end
    return INFO, table.concat(parts, ", ") .. " — SelfFoundCheck still looks for a 'Self-Found' buff; switch to these if the buff doesn't exist"
end)

----------------------------------------------------------------------
-- 3. Items & equipment
----------------------------------------------------------------------

P("Items", "GetInventoryItemID / GetInventoryItemLink",
  "every EQUIPMENT rule, curated items, Self-made, armor-type challenges",
  function()
    if not exists("GetInventoryItemID") then return FAIL, "GetInventoryItemID missing" end
    local slot, id = firstEquippedSlot()
    if not slot then return SKIP, "nothing equipped — equip something and rerun" end
    local link = exists("GetInventoryItemLink") and GetInventoryItemLink("player", slot)
    if not link then return WARN, "item id ok (" .. id .. ") but GetInventoryItemLink returned nothing" end
    return OK, "slot " .. slot .. " -> item " .. id
end)

P("Items", "GetItemInfo (quality / type / subtype / classID)",
  "White knight, Scout, Exotic, Cloth / Leather / Mail rules, Mixed weapons, Off-the-shelf",
  function()
    local _, id = firstEquippedSlot()
    id = id or 6948
    local name, _, quality, _, _, itemType, subType, _, equipLoc, _, _, classID, subclassID = C.GetItemInfo(id)
    if not name then return WARN, "item " .. id .. " not cached yet — run again in a few seconds" end
    if quality == nil or classID == nil then return FAIL, "quality or classID missing" end
    return OK, string.format("%s: quality %s, %s / %s, slot %s, class %s.%s",
        s(name), s(quality), s(itemType), s(subType), s(equipLoc), s(classID), s(subclassID))
end)

P("Items", "Bag scanning (C_Container)",
  "Mount (bag scan), Companion (bag scan), ritual item checks, Self-found",
  function()
    if not (C_Container and isFunc(C_Container.GetContainerNumSlots) and isFunc(C_Container.GetContainerItemID)) then
        return FAIL, "C_Container missing"
    end
    local n = C_Container.GetContainerNumSlots(0) or 0
    local items = 0
    for slot = 1, n do
        if C_Container.GetContainerItemID(0, slot) then items = items + 1 end
    end
    return OK, "backpack: " .. n .. " slots, " .. items .. " items"
end)

P("Items", "Tooltip scan (\"Made by\" line)", "Self-made, Self-made guns", function()
    local slot = firstEquippedSlot()
    if not slot then return SKIP, "nothing equipped" end
    local tip = _G.FCE_ProbeTooltip or CreateFrame("GameTooltip", "FCE_ProbeTooltip", nil, "GameTooltipTemplate")
    tip:SetOwner(WorldFrame, "ANCHOR_NONE")
    tip:ClearLines()
    tip:SetInventoryItem("player", slot)
    local lines = tip:NumLines() or 0
    local fs = _G.FCE_ProbeTooltipTextLeft1
    local first = fs and fs:GetText()
    tip:Hide()
    if lines == 0 or not first then
        if C_TooltipInfo and isFunc(C_TooltipInfo.GetInventoryItem) then
            return FAIL, "template tooltip scan is empty; C_TooltipInfo.GetInventoryItem exists — port SelfFoundCheck to it"
        end
        return FAIL, "tooltip scan returned nothing"
    end
    if secret(first) then return FAIL, "tooltip text is secret" end
    local alt = (C_TooltipInfo and isFunc(C_TooltipInfo.GetInventoryItem)) and " (C_TooltipInfo also available)" or ""
    return OK, lines .. " lines, first: " .. first .. alt
end)

P("Items", "ShowingHelm / ShowingCloak", "helm/cloak must be visible on curated HEAD/BACK items", function()
    if exists("ShowingHelm") and exists("ShowingCloak") then
        return OK, "helm shown=" .. tostring(ShowingHelm()) .. ", cloak shown=" .. tostring(ShowingCloak())
    end
    return WARN, "missing — shim treats helm/cloak as always shown, so this part of the rule can't fail. Find Forever's equivalent (transmog hide?)"
end)

needFunc("Items", "GetInventoryItemDurability", "Ephemeral (no repairs)")

P("Items", "Character stat APIs", "stat-based equipment rules (spell power, armor, attack power, stats)", function()
    local missing, sec = {}, {}
    local checks = {
        { "GetSpellBonusDamage", function() return GetSpellBonusDamage(3) end },
        { "UnitStat",            function() return UnitStat("player", 1) end },
        { "UnitArmor",           function() return UnitArmor("player") end },
        { "UnitAttackPower",     function() return UnitAttackPower("player") end },
    }
    for _, c in ipairs(checks) do
        if not exists(c[1]) then
            missing[#missing + 1] = c[1]
        else
            local ok, v = pcall(c[2])
            if not ok or secret(v) then sec[#sec + 1] = c[1] end
        end
    end
    if #missing > 0 then return FAIL, "missing: " .. table.concat(missing, ", ") end
    if #sec > 0 then return WARN, "secret or erroring: " .. table.concat(sec, ", ") .. " (rerun out of combat)" end
    return OK, "all readable"
end)

needFunc("Items", "PickupInventoryItem", "Scarlet Redemption (destroy the tabard)")
needFunc("Items", "DeleteCursorItem", "Scarlet Redemption, The New Plague", WARN,
    "missing — Forever adds C_Item.DeleteItem; switch EventChallenges to it")

----------------------------------------------------------------------
-- 4. Spells & auras
----------------------------------------------------------------------

P("Spells", "GetSpellInfo",
  "spell restrictions (Pyromancer, Cryomancer, Light of Elune, Overt, Lockdown...), Tame Beast, Behavioral checks",
  function()
    local name = C.GetSpellInfo(6603)
    if not name then return FAIL, "no data for spell 6603 (Auto Attack)" end
    return OK, (exists("GetSpellInfo") and "native" or "C_Spell shim") .. ": " .. s(name)
end)

P("Spells", "IsSpellKnown", "Professions (locale-safe pass), No nonsense", function()
    if not (exists("IsSpellKnown") or (C_SpellBook and isFunc(C_SpellBook.IsSpellKnown))) then
        return FAIL, "neither IsSpellKnown nor C_SpellBook.IsSpellKnown"
    end
    local ok, v = pcall(C.IsSpellKnown, 6603)
    if not ok then return FAIL, "error: " .. tostring(v) end
    return OK, "IsSpellKnown(6603) = " .. s(v)
end)

P("Auras", "Read player buffs (out of combat)",
  "Self-Found buff, Happy Hour, Elixir Frenzy, Doubt (campfire), mount buff, Demonic Sacrifice, The New Plague",
  function()
    if not (C_UnitAuras and isFunc(C_UnitAuras.GetAuraDataByIndex)) and not exists("UnitBuff") then
        return FAIL, "no aura API at all"
    end
    if C.AurasMayBeSecret() then return SKIP, "you're in combat — auras are secret; rerun out of combat" end
    local n, hidden, names = 0, 0, {}
    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, spellID = C.UnitBuff("player", i)
        if not name then break end
        n = n + 1
        if name == "?" or spellID == 0 then
            hidden = hidden + 1
        elseif #names < 6 then
            names[#names + 1] = name .. " (" .. tostring(spellID) .. ")"
        end
    end
    if n == 0 then return SKIP, "no buffs on you — get any buff (food, Fortitude...) and rerun" end
    if hidden > 0 then return FAIL, hidden .. "/" .. n .. " buffs secret even out of combat" end
    return OK, n .. " readable: " .. table.concat(names, ", ")
end)

P("Auras", "Aura timers in combat", "Elixir Frenzy, Happy Hour, Doubt (campfire)", function()
    return INFO, "auras are secret in combat/encounters on Forever. The shim reports them as '?' — ElixirSystem/BrewmasterSystem should pause while FCE.Compat.AurasMayBeSecret() is true (see FOREVER_TODO.md)"
end)

P("Auras", "Self-Found buff present", "Self-Found", function()
    if C.AurasMayBeSecret() then return SKIP, "in combat" end
    for i = 1, 40 do
        local name = C.UnitBuff("player", i)
        if not name then break end
        local lower = name:lower()
        if lower:find("self") and lower:find("found") then return OK, "found buff: " .. name end
    end
    return INFO, "no Self-Found buff on this character (fine if you didn't pick self-found)"
end)

needFunc("Auras", "GetShapeshiftForm", "Savagery, Spirit of Ursol / Ashamane / Aviana, Truecaster")

P("State", "Movement & state APIs",
  "Doubt, Savagery, Happy Hour, Elixir Frenzy pauses; Nocturnal/Diurnal taxi exemption; Drifter",
  function()
    local missing = {}
    for _, f in ipairs({ "IsMounted", "UnitOnTaxi", "UnitIsDeadOrGhost", "IsResting", "GetUnitSpeed", "UnitIsDead" }) do
        if not exists(f) then missing[#missing + 1] = f end
    end
    if #missing > 0 then return FAIL, "missing: " .. table.concat(missing, ", ") end
    return OK, "all present"
end)

----------------------------------------------------------------------
-- 5. Events
----------------------------------------------------------------------

needEvent("Events", "UNIT_SPELLCAST_SENT", "Drifter (hearthstone), Mortal pets, spell restrictions")
needEvent("Events", "UNIT_SPELLCAST_SUCCEEDED", "spell restrictions, Master Smelter, Master Trainer, Tame challenges")
needEvent("Events", "UNIT_AURA", "Elixir Frenzy, Happy Hour, The New Plague, Disease Cleansing, mount checks")
needEvent("Events", "UNIT_PET", "hunter/warlock pet checks, companions")
needEvent("Events", "BAG_UPDATE", "mount/companion bag scans, ritual items")
needEvent("Events", "PLAYER_EQUIPMENT_CHANGED", "every equipment rule, Voodoo Ritual")
needEvent("Events", "MERCHANT_SHOW", "Ephemeral (repair detection)")
needEvent("Events", "MERCHANT_CLOSED", "Ephemeral (repair detection)")
needEvent("Events", "BANKFRAME_OPENED", "Drifter (no bank)")
needEvent("Events", "UPDATE_INVENTORY_DURABILITY", "Ephemeral")
needEvent("Events", "SKILL_LINES_CHANGED", "professions, weapon skills", WARN)
needEvent("Events", "QUEST_TURNED_IN", "Seeking a Pardon, Agnostic, quest tracking")
needEvent("Events", "QUEST_LOG_UPDATE", "quest tracking")
needEvent("Events", "CHAT_MSG_SAY", "Insular")
needEvent("Events", "CHAT_MSG_YELL", "Insular")
needEvent("Events", "CHAT_MSG_CHANNEL", "AddonComm (nearby players)")
needEvent("Events", "CHAT_MSG_SYSTEM", "AddonComm / misc")
needEvent("Events", "COMPANION_UPDATE", "companion checks", WARN)
needEvent("Events", "CHARACTER_POINTS_CHANGED", "talent checks", WARN)
needEvent("Events", "ACTIVE_TALENT_GROUP_CHANGED", "talent checks (dual spec)", WARN)
needEvent("Events", "TRAIT_CONFIG_UPDATED", "talent checks on the trait system", INFO)
needEvent("Events", "ZONE_CHANGED_NEW_AREA", "Homebound, zone challenges, rituals")
needEvent("Events", "PLAYER_UPDATE_RESTING", "Doubt")

P("Events", "Combat log", "Gnomish Justice (Kovic kill), XXX, Disease Cleansing", function()
    if C.HAS_COMBAT_LOG then return OK, "registered and readable" end
    local v = eventValid("COMBAT_LOG_EVENT_UNFILTERED", true)
    return WARN, "not available to addons (IsEventValid=" .. tostring(v) .. "). Spellcast fallback covers cast-based challenges; kill/dispel ones need the replacement events below"
end)

P("Events", "Kill / death events (combat-log replacements)", "Gnomish Justice (Kovic kill), XXX", function()
    local found = {}
    for _, ev in ipairs({ "PARTY_KILL", "UNIT_DIED", "UNIT_DEATH", "UNIT_DESTROYED" }) do
        if eventValid(ev) then found[#found + 1] = ev end
    end
    if #found > 0 then
        return OK, "available: " .. table.concat(found, ", ") .. " — wire into EventChallenges (GUIDs are secret inside instances)"
    end
    return WARN, "none of PARTY_KILL / UNIT_DIED / UNIT_DEATH found"
end)

----------------------------------------------------------------------
-- 6. Skills, professions, talents
----------------------------------------------------------------------

P("Skills", "Skill lines (professions + weapon skills)",
  "PROFESSIONS section, Weapon proficiency, Weapon Mastery, No nonsense",
  function()
    local src = exists("GetNumSkillLines") and "native"
        or ((C_SkillInfo and isFunc(C_SkillInfo.GetNumSkillLines)) and "C_SkillInfo"
        or "GetProfessions fallback")
    local ok, n = pcall(C.GetNumSkillLines)
    if not ok then return FAIL, src .. " errored: " .. tostring(n) end
    n = n or 0
    if n == 0 then return WARN, "0 skill lines via " .. src .. " (fine only if you know no professions)" end
    local headers, weapons, inWeapons = {}, 0, false
    for i = 1, n do
        local name, isHeader = C.GetSkillLineInfo(i)
        if isHeader == true or isHeader == 1 then
            headers[#headers + 1] = tostring(name)
            inWeapons = (name == "Weapon Skills")
        elseif inWeapons then
            weapons = weapons + 1
        end
    end
    local detail = src .. ": " .. n .. " lines; headers [" .. table.concat(headers, ", ") .. "]; " .. weapons .. " weapon skills"
    if weapons == 0 then return WARN, detail .. " — weapon proficiency checks will show no data" end
    return OK, detail
end)

shimmed("Skills", "GetProfessions", "profession fallback when skill lines are missing")

P("Skills", "Talents", "TALENTS section for every character, spec detection", function()
    if exists("GetTalentInfo") and exists("GetNumTalentTabs") then
        return OK, "Classic talent API present"
    end
    if C_ClassTalents and isFunc(C_ClassTalents.GetActiveConfigID) and type(C_Traits) == "table" then
        local ok, cfg = pcall(C_ClassTalents.GetActiveConfigID)
        return FAIL, "Classic talent API missing; C_Traits present (configID " .. (ok and s(cfg) or "error")
            .. "). TalentCheck needs a rewrite — run /fce apitest talents to dump the tree"
    end
    return FAIL, "no talent API found"
end)

----------------------------------------------------------------------
-- 7. Pets, companions, mounts
----------------------------------------------------------------------

P("Pets", "Combat pet (hunter / warlock)",
  "hunter pet family requirements, Imp, Voidwalker, No demons, Lone Wolf, Mortal pets",
  function()
    if not UnitExists("pet") then return SKIP, "no pet out — summon it and rerun" end
    local fam, name = UnitCreatureFamily("pet"), UnitName("pet")
    if secret(fam) or secret(name) then return FAIL, "pet family/name is secret" end
    if not fam or fam == "" then return WARN, s(name) .. " — UnitCreatureFamily returned nothing" end
    return OK, s(name) .. " (" .. s(fam) .. ")"
end)

P("Pets", "Companion (vanity pet) detection", "COMPANION requirements", function()
    if UnitExists("critter") then
        return OK, "'critter' unit works: " .. s(UnitName("critter"))
    end
    if C_PetJournal and isFunc(C_PetJournal.GetSummonedPetGUID) then
        local guid = C_PetJournal.GetSummonedPetGUID()
        if guid and isFunc(C_PetJournal.GetPetInfoByPetID) then
            local speciesID, _, _, _, _, _, _, name = C_PetJournal.GetPetInfoByPetID(guid)
            return WARN, "'critter' unit is empty but the pet journal reports " .. s(name)
                .. " (species " .. s(speciesID) .. ") — rewrite CompanionCheck on C_PetJournal"
        end
        return SKIP, "no companion out. C_PetJournal is present (pets are an account collection on Forever) — summon one and rerun"
    end
    return FAIL, "neither the 'critter' unit nor C_PetJournal is available"
end)

P("Pets", "Mount collection", "MOUNT requirements (Wolf, Skeletal horse, Ram, Frostsaber...)", function()
    if C_MountJournal and isFunc(C_MountJournal.GetMountIDs) and isFunc(C_MountJournal.GetMountInfoByID) then
        local ids = C_MountJournal.GetMountIDs() or {}
        local collected = 0
        for _, id in ipairs(ids) do
            local isCollected = select(11, C_MountJournal.GetMountInfoByID(id))
            if isCollected then collected = collected + 1 end
        end
        return WARN, "mounts are a journal collection (" .. collected .. "/" .. #ids
            .. " collected) — MountCheck scans bags for mount items; rewrite on C_MountJournal"
    end
    return INFO, "no C_MountJournal — mounts are bag items like Classic"
end)

P("Pets", "Pet happiness / loyalty", "possible future hunter-pet challenges", function()
    if C_PetInfo and isFunc(C_PetInfo.GetPetHappiness) then return INFO, "C_PetInfo.GetPetHappiness present (new in Forever)" end
    if exists("GetPetHappiness") then return INFO, "GetPetHappiness present" end
    return INFO, "no pet happiness API"
end)

----------------------------------------------------------------------
-- 8. Quests, reputation, world
----------------------------------------------------------------------

P("Quests", "Quest completion", "QUESTS section, Quest Journal, Seeking a Pardon, Agnostic", function()
    if not (C_QuestLog and isFunc(C_QuestLog.IsQuestFlaggedCompleted)) then return FAIL, "C_QuestLog.IsQuestFlaggedCompleted missing" end
    local all = C.GetQuestsCompleted() or {}
    local n = 0
    for _ in pairs(all) do n = n + 1 end
    return OK, n .. " completed quests visible"
end)

local REP_NAMES = {
    "Argent Dawn", "Cenarion Circle", "Thorium Brotherhood", "Zandalar Tribe",
    "Stormwind", "Ironforge", "Darnassus", "Gnomeregan Exiles",
    "Orgrimmar", "Undercity", "Thunder Bluff", "Darkspear Trolls",
}

P("Reputation", "Faction list & standings",
  "REPUTATION section: Faction Loyalist, Purifier, Keeper, Smith, Avenger, Cult of the Damned, Twilight's Hammer, Shadow Council, Old Horde, Diplomat",
  function()
    local n = C.GetNumFactions() or 0
    if n == 0 then return FAIL, "0 faction rows" end
    local seen, missing = {}, {}
    for i = 1, n do
        local name, _, standing, _, _, _, _, _, isHeader = C.GetFactionInfo(i)
        if name and not isHeader and not secret(name) then seen[name] = standing end
    end
    for _, want in ipairs(REP_NAMES) do
        if not seen[want] then missing[#missing + 1] = want end
    end
    local detail = n .. " rows"
    if #missing > 0 then
        return WARN, detail .. "; not found (undiscovered, collapsed header, or renamed): " .. table.concat(missing, ", ")
    end
    return OK, detail .. "; all tracked factions present"
end)

needEvent("Reputation", "FACTION_STANDING_CHANGED", "faster reputation refresh (Midnight event)", INFO)

P("World", "Map ID & player position",
  "Homebound, Anti-undead / Pro-nature / Anti-demon / Aoe-farmer, ritual locations",
  function()
    if not (C_Map and isFunc(C_Map.GetBestMapForUnit)) then return FAIL, "C_Map missing" end
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return WARN, "no map ID (in an instance?)" end
    local info = C_Map.GetMapInfo(mapID)
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return WARN, "map " .. mapID .. " ok, but no player position (normal inside instances)" end
    local x, y = pos:GetXY()
    if secret(x) or secret(y) then return FAIL, "player position is secret" end
    return OK, string.format("%s (map %d) at %.1f, %.1f", info and s(info.name) or "?", mapID, x * 100, y * 100)
end)

P("World", "Exploration API", "Explorer", function()
    if not (C_MapExplorationInfo and isFunc(C_MapExplorationInfo.GetExploredAreaIDsAtPosition)) then
        return FAIL, "C_MapExplorationInfo.GetExploredAreaIDsAtPosition missing"
    end
    local mapID = C_Map.GetBestMapForUnit("player")
    local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return SKIP, "no position here — rerun in the open world" end
    local ok, ids = pcall(C_MapExplorationInfo.GetExploredAreaIDsAtPosition, mapID, pos)
    if not ok then return FAIL, "error: " .. tostring(ids) end
    return OK, (ids and #ids or 0) .. " explored area IDs at your position"
end)

P("World", "Zone text", "Nocturnal / Diurnal (town check), Voodoo Ritual, Scarlet Redemption, The New Plague", function()
    local z, sz = GetZoneText(), GetSubZoneText()
    if secret(z) or secret(sz) then return FAIL, "zone text is secret" end
    return OK, tostring(z) .. " / " .. tostring(sz)
end)

P("World", "Game time / day-night", "Nocturnal, Diurnal", function()
    local h, m = GetGameTime()
    local detail = string.format("GetGameTime %02d:%02d", h or 0, m or 0)
    if C_DateAndTime and isFunc(C_DateAndTime.IsDayTime) then
        detail = detail .. "; C_DateAndTime.IsDayTime() = " .. s(C_DateAndTime.IsDayTime())
            .. " (new in Forever — compare with the 06:00-21:00 window FCE uses)"
    end
    return OK, detail
end)

----------------------------------------------------------------------
-- 9. Chat, language, communication
----------------------------------------------------------------------

P("Chat", "Languages", "Insular", function()
    if not (exists("GetDefaultLanguage") and exists("GetNumLanguages") and exists("GetLanguageByIndex")) then
        return FAIL, "language API missing"
    end
    local def, defID = GetDefaultLanguage("player")
    local list = {}
    for i = 1, GetNumLanguages() do
        local name, id = GetLanguageByIndex(i)
        list[#list + 1] = s(name) .. "=" .. s(id)
    end
    if #list == 0 then return FAIL, "no languages known" end
    return OK, "default " .. s(def) .. " (" .. s(defID) .. "); known: " .. table.concat(list, ", ")
end)

P("Chat", "Chat edit box language fields", "Insular (forces your racial language)", function()
    local eb = _G.ChatFrame1EditBox or (ChatFrame1 and ChatFrame1.editBox)
    if not eb then return FAIL, "ChatFrame1EditBox not found" end
    local hooks = {}
    for _, f in ipairs({ "ChatEdit_OnLanguageChanged", "ChatFrame_ChatEdit_OnLanguageChanged" }) do
        if exists(f) then hooks[#hooks + 1] = f end
    end
    local hasField = (eb.languageID ~= nil) or (eb.language ~= nil)
    local detail = "languageID=" .. s(eb.languageID) .. ", language=" .. s(eb.language)
        .. "; hook targets: " .. (#hooks > 0 and table.concat(hooks, ", ") or "none (poll fallback only)")
    if not hasField then return WARN, detail .. " — Insular may need a different way to set the language" end
    return OK, detail .. ". Verify: after enforcement, /say still sends (no 'action blocked')"
end)

shimmed("Chat", "SendChatMessage", "guild achievement announcements, party messages, AddonComm", "C_ChatInfo.SendChatMessage")

P("Chat", "Addon messaging", "AddonComm (nearby FCE players)", function()
    local addonMsg = C_ChatInfo and isFunc(C_ChatInfo.SendAddonMessage) and isFunc(C_ChatInfo.RegisterAddonMessagePrefix)
    local channel = exists("JoinChannelByName") and exists("GetChannelName")
    local detail = "C_ChatInfo.SendAddonMessage " .. (addonMsg and "present" or "missing")
        .. "; custom channel API " .. (channel and "present" or "missing")
        .. ". AddonComm sends visible chat to a custom channel (hardware-event only; blocked in encounters) — migrating to addon messages is cleaner"
    if not channel and not addonMsg then return FAIL, detail end
    return (channel and OK or WARN), detail
end)

shimmed("Chat", "ChatFrame_AddMessageEventFilter", "AddonComm chat tags", "ChatFrameUtil.AddMessageEventFilter")
shimmed("Chat", "ChatFrame_RemoveChannel", "AddonComm hides its protocol channel", "ChatFrameUtil.RemoveChannel")
needFunc("Chat", "DoEmote", "Voodoo Ritual (dance), Seeking a Pardon (kneel), The New Plague (cackle)")
needFunc("Social", "C_PartyInfo.InviteUnit", "AddonComm invite button", WARN)
needFunc("Social", "IsInGuild", "guild achievement announcements")
needFunc("Social", "GetRealmName", "achievements, Catalog")

----------------------------------------------------------------------
-- 10. UI building blocks
----------------------------------------------------------------------

P("UI", "Frame & texture APIs", "every FCE window", function()
    local missing = {}
    local need = {
        { "SetPortraitTextureFromCreatureDisplayID", "Quest Journal NPC portraits" },
        { "FauxScrollFrame_Update",                  "character selection list" },
        { "UIFrameFadeIn",                           "Doubt screen tunnel" },
        { "UIFrameFadeOut",                          "Doubt screen tunnel" },
        { "CopyTable",                               "settings reset" },
        { "PlaySound",                               "alerts" },
        { "CreateColor",                             "gradients / dividers" },
        { "C_Timer.NewTicker",                       "all timers" },
        { "hooksecurefunc",                          "Insular hooks" },
    }
    for _, n in ipairs(need) do
        if not exists(n[1]) then missing[#missing + 1] = n[1] .. " (" .. n[2] .. ")" end
    end
    local ok = pcall(function()
        local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        local t = f:CreateTexture()
        t:SetColorTexture(1, 1, 1, 1)
        t:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, 1))
        f:Hide()
    end)
    if not ok then missing[#missing + 1] = "BackdropTemplate / SetGradient(CreateColor) (panel styling)" end
    if type(SOUNDKIT) ~= "table" then missing[#missing + 1] = "SOUNDKIT table (alert sounds)" end
    if #missing > 0 then return FAIL, "missing: " .. table.concat(missing, "; ") end
    return OK, "all present"
end)

P("UI", "Minimap libraries", "minimap button", function()
    local lib = LibStub and LibStub:GetLibrary("LibDBIcon-1.0", true)
    return INFO, lib and "LibDBIcon available (another addon ships it)" or "no LibDBIcon — standalone minimap button will be used"
end)

----------------------------------------------------------------------
-- Talent dump (C_Traits) — raw data so TalentCheck can be rewritten
----------------------------------------------------------------------

function Probe.DumpTalents()
    if not (C_ClassTalents and isFunc(C_ClassTalents.GetActiveConfigID) and type(C_Traits) == "table") then
        return nil, "C_ClassTalents / C_Traits not available"
    end
    local ok, result = pcall(function()
        local out = {}
        local configID = C_ClassTalents.GetActiveConfigID()
        if not configID then return out end
        local cfg = C_Traits.GetConfigInfo(configID)
        for _, treeID in ipairs(cfg and cfg.treeIDs or {}) do
            for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
                local node = C_Traits.GetNodeInfo(configID, nodeID)
                if node and node.ID and node.ID ~= 0 then
                    local entryID = (node.activeEntry and node.activeEntry.entryID)
                        or (node.entryIDs and node.entryIDs[1])
                    local name, spellID
                    if entryID then
                        local e = C_Traits.GetEntryInfo(configID, entryID)
                        local d = e and e.definitionID and C_Traits.GetDefinitionInfo(e.definitionID)
                        spellID = d and (d.spellID or d.overriddenSpellID)
                        if spellID then name = C.GetSpellInfo(spellID) end
                        name = name or (d and d.overrideName)
                    end
                    out[#out + 1] = {
                        tree = treeID, node = nodeID, subTree = node.subTreeID,
                        name = name and plain(name, nil), spellID = spellID,
                        rank = node.activeRank or node.currentRank, maxRank = node.maxRanks,
                        x = node.posX, y = node.posY,
                    }
                end
            end
        end
        return out
    end)
    if not ok then return nil, "error: " .. tostring(result) end
    return result
end

----------------------------------------------------------------------
-- Running & reporting
----------------------------------------------------------------------

local function colored(st, text)
    return "|cff" .. (COLORS[st] or "ffffff") .. text .. "|r"
end

function Probe.FormatText(report)
    local L = {}
    L[#L + 1] = "Forever Classes Enhanced - API self-test"
    L[#L + 1] = "When: " .. report.when .. "   Interface: " .. tostring(report.toc) .. "   Build: " .. tostring(report.build)
    local sum = {}
    for _, st in ipairs(ORDER) do sum[#sum + 1] = st .. " " .. (report.counts[st] or 0) end
    L[#L + 1] = "Summary: " .. table.concat(sum, "   ")
    L[#L + 1] = ""

    local lastArea
    for _, r in ipairs(report.results) do
        if r.area ~= lastArea then
            L[#L + 1] = "== " .. r.area .. " =="
            lastArea = r.area
        end
        L[#L + 1] = string.format("[%s] %s - %s", r.status, r.name, r.detail)
        if r.status == FAIL or r.status == WARN then
            L[#L + 1] = "        affects: " .. r.uses
        end
    end

    if report.live and #report.live > 0 then
        L[#L + 1] = ""
        L[#L + 1] = "== Live probes =="
        for _, r in ipairs(report.live) do
            L[#L + 1] = string.format("[%s] %s - %s", r.status, r.name, r.detail)
        end
    end

    if report.talents then
        L[#L + 1] = ""
        L[#L + 1] = "== Talent tree dump (" .. #report.talents .. " nodes) =="
        for _, t in ipairs(report.talents) do
            L[#L + 1] = string.format("tree %s sub %s node %s  %s (spell %s)  rank %s/%s  pos %s,%s",
                tostring(t.tree), tostring(t.subTree), tostring(t.node), tostring(t.name),
                tostring(t.spellID), tostring(t.rank), tostring(t.maxRank), tostring(t.x), tostring(t.y))
        end
    elseif report.talentsErr then
        L[#L + 1] = ""
        L[#L + 1] = "Talent dump: " .. report.talentsErr
    end
    return table.concat(L, "\n")
end

function Probe.PrintSummary(report)
    local p = FCE.Print or print
    local sum = {}
    for _, st in ipairs(ORDER) do
        sum[#sum + 1] = colored(st, st .. " " .. (report.counts[st] or 0))
    end
    p("API self-test: " .. table.concat(sum, "  "))
    for _, r in ipairs(report.results) do
        if r.status == FAIL then
            p("  " .. colored(FAIL, "FAIL") .. " " .. r.name .. " |cff888888(" .. r.uses .. ")|r")
        end
    end
    p("Full report is in the window (Ctrl+A, Ctrl+C to copy) and saved to FCE_GlobalDB.apiReport.")
end

local win
function Probe.ShowWindow(text)
    if not win then
        win = CreateFrame("Frame", "FCE_APIProbeWindow", UIParent, "BackdropTemplate")
        win:SetSize(680, 480)
        win:SetPoint("CENTER")
        win:SetFrameStrata("DIALOG")
        win:SetMovable(true)
        win:EnableMouse(true)
        win:SetClampedToScreen(true)
        win:RegisterForDrag("LeftButton")
        win:SetScript("OnDragStart", win.StartMoving)
        win:SetScript("OnDragStop", win.StopMovingOrSizing)
        win:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        win:SetBackdropColor(0.06, 0.05, 0.04, 0.96)
        win:SetBackdropBorderColor(0.72, 0.62, 0.20, 1)

        local title = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOPLEFT", 12, -10)
        title:SetText("Forever Classes Enhanced - API self-test   |cff888888(click text, Ctrl+A, Ctrl+C to copy)|r")

        local close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -2, -2)

        local sf = CreateFrame("ScrollFrame", "FCE_APIProbeScroll", win, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 12, -32)
        sf:SetPoint("BOTTOMRIGHT", -32, 12)

        local eb = CreateFrame("EditBox", nil, sf)
        eb:SetMultiLine(true)
        eb:SetAutoFocus(false)
        eb:SetMaxLetters(0)
        eb:SetFontObject(ChatFontNormal)
        eb:SetWidth(620)
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        sf:SetScrollChild(eb)
        win.eb = eb

        if UISpecialFrames then tinsert(UISpecialFrames, "FCE_APIProbeWindow") end
    end
    win.eb:SetText(text)
    win.eb:SetCursorPosition(0)
    win:Show()
end

function Probe.Run(opts)
    opts = opts or {}
    local results = {}
    local counts = {}
    for _, p in ipairs(probes) do
        local ok, st, detail = pcall(p.fn)
        if not ok then st, detail = FAIL, "Lua error: " .. tostring(st) end
        st = st or INFO
        detail = tostring(plain(detail, "<secret>") or "")
        counts[st] = (counts[st] or 0) + 1
        results[#results + 1] = { area = p.area, name = p.name, uses = p.uses, status = st, detail = detail }
    end

    local report = {
        when = date("%Y-%m-%d %H:%M:%S"),
        toc = C.TOC_VERSION,
        build = select(2, GetBuildInfo()),
        counts = counts,
        results = results,
        live = (FCE_GlobalDB and FCE_GlobalDB.apiReport and FCE_GlobalDB.apiReport.live) or nil,
    }
    if opts.talents then
        report.talents, report.talentsErr = Probe.DumpTalents()
    end

    FCE_GlobalDB = FCE_GlobalDB or {}
    FCE_GlobalDB.apiReport = report
    FCE_GlobalDB._probeCanary = time()
    canarySetThisSession = true

    Probe.last = report
    Probe.PrintSummary(report)
    Probe.ShowWindow(Probe.FormatText(report))
    return report
end

----------------------------------------------------------------------
-- Live probes — things that can only be verified as they happen
----------------------------------------------------------------------

local live = CreateFrame("Frame")
local LIVE_SECONDS = 120

local function recordLive(name, st, detail)
    FCE_GlobalDB = FCE_GlobalDB or {}
    FCE_GlobalDB.apiReport = FCE_GlobalDB.apiReport or { results = {}, counts = {} }
    local rep = FCE_GlobalDB.apiReport
    rep.live = rep.live or {}
    rep.live[#rep.live + 1] = { name = name, status = st, detail = tostring(plain(detail, "<secret>")) }
    local p = FCE.Print or print
    p("Live probe " .. colored(st, st) .. " " .. name .. ": " .. tostring(plain(detail, "<secret>")))
end

live:SetScript("OnEvent", function(self, event, ...)
    if GetTime() > (self.deadline or 0) then
        self:UnregisterAllEvents()
        return
    end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local _, _, spellID = ...
        if secret(spellID) then
            recordLive("Your spellcast payload", FAIL, "spellID is secret — spell restrictions can't be tracked")
        else
            recordLive("Your spellcast payload", OK, "spellID " .. tostring(spellID) .. " (" .. s(C.GetSpellInfo(spellID)) .. ")"
                .. (InCombatLockdown() and ", in combat" or ", out of combat"))
        end
        self:UnregisterEvent(event)
    elseif event == "CHAT_MSG_SAY" then
        local _, sender, lang = ...
        local me = UnitName("player")
        if secret(sender) then
            recordLive("/say payload", WARN, "sender name is secret — Insular can't tell it's you here")
            self:UnregisterEvent(event)
        elseif sender and me and sender:match("^([^%-]+)") == me then
            recordLive("/say payload", secret(lang) and FAIL or OK, "language arg = " .. s(lang) .. " (Insular reads this)")
            self:UnregisterEvent(event)
        end
    elseif event == "UNIT_PET" then
        local unit = ...
        if unit ~= "player" then return end
        C_Timer.After(0.5, function()
            if not UnitExists("pet") then return end
            local fam, name = UnitCreatureFamily("pet"), UnitName("pet")
            if secret(fam) or secret(name) then
                recordLive("Pet summon", FAIL, "pet family/name secret")
            else
                recordLive("Pet summon", (fam and fam ~= "") and OK or WARN, s(name) .. " (" .. s(fam) .. ")")
            end
        end)
        self:UnregisterEvent(event)
    end
end)

function Probe.ArmLive()
    live.deadline = GetTime() + LIVE_SECONDS
    live:UnregisterAllEvents()
    live:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    live:RegisterEvent("CHAT_MSG_SAY")
    live:RegisterEvent("UNIT_PET")
    if FCE_GlobalDB and FCE_GlobalDB.apiReport then FCE_GlobalDB.apiReport.live = {} end
    local p = FCE.Print or print
    p("Live probes armed for " .. LIVE_SECONDS .. "s. Now: 1) cast any spell, 2) type /say hello, 3) summon your pet (hunter/warlock).")
    p("Then run /fce apitest again to see everything in one report.")
end
