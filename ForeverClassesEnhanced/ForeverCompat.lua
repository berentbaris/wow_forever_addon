----------------------------------------------------------------------
-- ForeverClassesEnhanced — Forever compatibility layer
--
-- LOADED FIRST (see .toc).
--
-- WoW Forever (interface 16001) plays like Classic but runs on the
-- modern Mainline API (12.1.x family, Midnight's addon rules).  Several
-- Classic Era globals this addon was written against are gone there:
--
--   GetSpellInfo, GetItemInfo, GetItemCount   -> C_Spell / C_Item
--   UnitBuff, UnitDebuff                      -> C_UnitAuras
--   GetNumFactions, GetFactionInfo            -> C_Reputation
--   GetNumSkillLines, GetSkillLineInfo        -> GetProfessions()
--   GetQuestsCompleted                        -> C_QuestLog
--   IsSpellKnown                              -> C_SpellBook
--   SendChatMessage                           -> C_ChatInfo
--   ChatFrame_AddMessageEventFilter           -> ChatFrameUtil
--   COMBAT_LOG_EVENT_UNFILTERED               -> unavailable (see EventChallenges)
--
-- Every wrapper below prefers the NATIVE global when it still exists,
-- so if Blizzard keeps (or restores) a Classic API the addon uses it
-- unchanged.  Wrappers return values in the Classic shape so the rest
-- of the addon did not need rewriting.
--
-- The wrappers live on FCE.Compat and are pulled into each file as
-- file-scoped locals (see the "Forever API shims" line at the top of
-- each file).  We deliberately do NOT write replacement globals, so
-- other addons that feature-detect Classic APIs aren't misled.
--
-- Secret values: Midnight/Forever can hand addons "secret" values
-- (names, GUIDs, aura data in combat) that throw on comparison or
-- string ops.  Compat.IsSecret / Compat.Plain let callers guard them.
--
-- Sources (checked Sep 2026, beta build 1.60.1.69913/70009):
--   https://wowforeverguides.com/addons/api-cheatsheet
--   https://warcraft.wiki.gg/wiki/TOC_format
--   https://warcraft.wiki.gg/wiki/Secret_Values
----------------------------------------------------------------------

FCE = FCE or {}
local Compat = {}
FCE.Compat = Compat

local function native(name)
    local f = _G[name]
    if type(f) == "function" then return f end
    return nil
end

----------------------------------------------------------------------
-- Client detection
----------------------------------------------------------------------

local tocVersion = select(4, GetBuildInfo()) or 0
Compat.TOC_VERSION = tocVersion
-- Forever beta reports 16001.  WOW_PROJECT_ID reports 1 (Mainline) on
-- Forever, so it can't be used on its own to detect the game.
Compat.IS_FOREVER = tocVersion >= 16000 and tocVersion < 20000
Compat.HAS_COMBAT_LOG = false  -- set by EventChallenges after it tries to register

----------------------------------------------------------------------
-- Secret-value guards
----------------------------------------------------------------------

function Compat.IsSecret(v)
    return type(issecretvalue) == "function" and issecretvalue(v) or false
end

--- Returns v if it is a plain (non-secret) value, otherwise fallback.
function Compat.Plain(v, fallback)
    if v == nil then return fallback end
    if Compat.IsSecret(v) then return fallback end
    return v
end

--- Safe equality: false if either side is secret.
function Compat.Equals(a, b)
    if Compat.IsSecret(a) or Compat.IsSecret(b) then return false end
    return a == b
end

----------------------------------------------------------------------
-- Spells
----------------------------------------------------------------------

Compat.GetSpellInfo = native("GetSpellInfo") or function(spell)
    if spell == nil or not (C_Spell and C_Spell.GetSpellInfo) then return nil end
    local info = C_Spell.GetSpellInfo(spell)
    if not info then
        if type(spell) == "number" and C_Spell.RequestLoadSpellData then
            C_Spell.RequestLoadSpellData(spell)
        end
        return nil
    end
    -- Classic order: name, rank, icon, castTime, minRange, maxRange, spellID, originalIcon
    return info.name, nil, info.iconID, info.castTime, info.minRange,
           info.maxRange, info.spellID, info.originalIconID
end

Compat.IsSpellKnown = native("IsSpellKnown") or function(spellID, isPet)
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local bank = isPet and Enum and Enum.SpellBookSpellBank
            and Enum.SpellBookSpellBank.Pet or nil
        return C_SpellBook.IsSpellKnown(spellID, bank)
    end
    return false
end

----------------------------------------------------------------------
-- Items
----------------------------------------------------------------------

Compat.GetItemInfo = native("GetItemInfo") or function(item)
    if item == nil or not (C_Item and C_Item.GetItemInfo) then return nil end
    local name = C_Item.GetItemInfo(item)
    if not name then
        if type(item) == "number" and C_Item.RequestLoadItemDataByID then
            C_Item.RequestLoadItemDataByID(item)
        end
        return nil
    end
    return C_Item.GetItemInfo(item)
end

Compat.GetItemCount = native("GetItemCount") or function(item, includeBank, includeCharges)
    if C_Item and C_Item.GetItemCount then
        return C_Item.GetItemCount(item, includeBank, includeCharges)
    end
    return 0
end

----------------------------------------------------------------------
-- Auras  (UnitBuff / UnitDebuff in the Classic return shape)
--   name, icon, count, debuffType, duration, expirationTime,
--   source, isStealable, nameplateShowPersonal, spellId
-- Secret fields are replaced with harmless placeholders so callers
-- doing name:lower() or spellID comparisons don't throw.
----------------------------------------------------------------------

local function auraTuple(a)
    if not a then return nil end
    local name = a.name
    if name == nil then return nil end
    if Compat.IsSecret(name) then name = "?" end
    local spellId = a.spellId
    if Compat.IsSecret(spellId) then spellId = 0 end
    return name,
        Compat.Plain(a.icon),
        Compat.Plain(a.applications, 0),
        Compat.Plain(a.dispelName),
        Compat.Plain(a.duration, 0),
        Compat.Plain(a.expirationTime, 0),
        Compat.Plain(a.sourceUnit),
        Compat.Plain(a.isStealable, false),
        Compat.Plain(a.nameplateShowPersonal, false),
        spellId
end

local function auraByIndex(unit, index, baseFilter, filter)
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return nil end
    local f = baseFilter
    if type(filter) == "string" and filter ~= "" then f = baseFilter .. "|" .. filter end
    local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, f)
    if not ok then return nil end
    return auraTuple(a)
end

Compat.UnitBuff = native("UnitBuff") or function(unit, index, filter)
    return auraByIndex(unit, index, "HELPFUL", filter)
end

Compat.UnitDebuff = native("UnitDebuff") or function(unit, index, filter)
    return auraByIndex(unit, index, "HARMFUL", filter)
end

----------------------------------------------------------------------
-- Reputation  (GetFactionInfo in the Classic return shape)
--   name, description, standingID, barMin, barMax, barValue,
--   atWarWith, canToggleAtWar, isHeader, isCollapsed, hasRep,
--   isWatched, isChild, factionID
----------------------------------------------------------------------

Compat.GetNumFactions = native("GetNumFactions") or function()
    if C_Reputation and C_Reputation.GetNumFactions then
        return C_Reputation.GetNumFactions() or 0
    end
    return 0
end

Compat.GetFactionInfo = native("GetFactionInfo") or function(index)
    if not (C_Reputation and C_Reputation.GetFactionDataByIndex) then return nil end
    local d = C_Reputation.GetFactionDataByIndex(index)
    if not d then return nil end
    return d.name, d.description, d.reaction,
        d.currentReactionThreshold, d.nextReactionThreshold, d.currentStanding,
        d.atWarWith, d.canToggleAtWar, d.isHeader, d.isCollapsed,
        d.isHeaderWithRep, d.isWatched, d.isChild, d.factionID
end

----------------------------------------------------------------------
-- Skill lines
-- Classic exposes professions (and weapon skills) through the skill
-- list.  Forever's API diff vs 12.1.5 ADDS C_SkillInfo.GetNumSkillLines
-- / GetSkillLineInfo / ExpandSkillHeader (warcraft.wiki.gg, Patch
-- 1.60.1/API changes), so weapon skills should be readable again.
-- Order of preference: native global -> C_SkillInfo -> rebuilt list
-- from GetProfessions() (professions only, no weapon skills).
-- Classic return shape:
--   name, isHeader, isExpanded, rank, numTempPoints, modifier, maxRank
----------------------------------------------------------------------

local function hasSkillInfo()
    return C_SkillInfo and type(C_SkillInfo.GetNumSkillLines) == "function"
        and type(C_SkillInfo.GetSkillLineInfo) == "function"
end

-- C_SkillInfo's return shape is unconfirmed (tuple like Classic, or an
-- info table like most C_ APIs).  Accept either.
local function skillInfoTuple(i)
    local r = { C_SkillInfo.GetSkillLineInfo(i) }
    local t = r[1]
    if type(t) ~= "table" then return unpack(r) end
    return t.skillName or t.name,
        t.isHeader or t.header or false,
        t.isExpanded or t.expanded or false,
        t.skillRank or t.rank or t.currentRank or 0,
        t.numTempPoints or t.tempPoints or 0,
        t.skillModifier or t.modifier or 0,
        t.skillMaxRank or t.maxRank or 0
end

Compat.ExpandSkillHeader = native("ExpandSkillHeader") or function(index)
    if C_SkillInfo and type(C_SkillInfo.ExpandSkillHeader) == "function" then
        return C_SkillInfo.ExpandSkillHeader(index)
    end
end

local skillLines = {}

local function rebuildSkillLines()
    wipe(skillLines)
    if type(GetProfessions) ~= "function" or type(GetProfessionInfo) ~= "function" then
        return
    end
    -- prof1, prof2, archaeology, fishing, cooking (any may be nil)
    local p = { GetProfessions() }
    local primary, secondary = {}, {}
    for slot = 1, 5 do
        local idx = p[slot]
        if idx then
            local name, _, rank, maxRank, _, _, _, modifier = GetProfessionInfo(idx)
            if name then
                local row = { name, false, false, rank or 0, 0, modifier or 0, maxRank or 0 }
                if slot <= 2 then primary[#primary + 1] = row
                else secondary[#secondary + 1] = row end
            end
        end
    end
    if #primary > 0 then
        skillLines[#skillLines + 1] = { "Professions", true, true, 0, 0, 0, 0 }
        for _, r in ipairs(primary) do skillLines[#skillLines + 1] = r end
    end
    if #secondary > 0 then
        skillLines[#skillLines + 1] = { "Secondary Skills", true, true, 0, 0, 0, 0 }
        for _, r in ipairs(secondary) do skillLines[#skillLines + 1] = r end
    end
end

Compat.GetNumSkillLines = native("GetNumSkillLines") or function()
    if hasSkillInfo() then return C_SkillInfo.GetNumSkillLines() or 0 end
    rebuildSkillLines()
    return #skillLines
end

Compat.GetSkillLineInfo = native("GetSkillLineInfo") or function(i)
    if hasSkillInfo() then return skillInfoTuple(i) end
    local r = skillLines[i]
    if not r then return nil end
    return unpack(r)
end

----------------------------------------------------------------------
-- Helm / cloak visibility
-- Modern clients hide helms/cloaks through transmog; the Classic
-- ShowingHelm/ShowingCloak toggles may not exist.  If missing we treat
-- the slot as shown (enforcement silently passes) instead of erroring.
----------------------------------------------------------------------

Compat.ShowingHelm  = native("ShowingHelm")  or function() return true end
Compat.ShowingCloak = native("ShowingCloak") or function() return true end
Compat.HAS_HELM_TOGGLE = native("ShowingHelm") ~= nil

----------------------------------------------------------------------
-- Chat channel helpers (AddonComm)
----------------------------------------------------------------------

Compat.ChatFrame_RemoveChannel = native("ChatFrame_RemoveChannel") or function(frame, channel)
    if ChatFrameUtil and type(ChatFrameUtil.RemoveChannel) == "function" then
        return ChatFrameUtil.RemoveChannel(frame, channel)
    end
end

----------------------------------------------------------------------
-- Aura readability
-- Midnight rules (inherited by Forever): aura data is SECRET while in
-- combat, in an instance encounter, M+ or a PvP match.  Timers that
-- depend on reading a buff (Elixir Frenzy, Happy Hour, Doubt campfire,
-- Self-Found buff) must not treat "can't read" as "buff missing".
----------------------------------------------------------------------

function Compat.AurasMayBeSecret()
    if not Compat.IS_FOREVER then return false end
    if InCombatLockdown and InCombatLockdown() then return true end
    if UnitAffectingCombat and UnitAffectingCombat("player") then return true end
    if IsEncounterInProgress and IsEncounterInProgress() then return true end
    return false
end

----------------------------------------------------------------------
-- Quests
----------------------------------------------------------------------

Compat.GetQuestsCompleted = native("GetQuestsCompleted") or function()
    local out = {}
    if C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs then
        for _, id in ipairs(C_QuestLog.GetAllCompletedQuestIDs() or {}) do
            out[id] = true
        end
    end
    return out
end

----------------------------------------------------------------------
-- Chat
----------------------------------------------------------------------

Compat.SendChatMessage = native("SendChatMessage") or function(msg, chatType, language, target)
    if C_ChatInfo and C_ChatInfo.SendChatMessage then
        return C_ChatInfo.SendChatMessage(msg, chatType, language, target)
    end
end

Compat.ChatFrame_AddMessageEventFilter = native("ChatFrame_AddMessageEventFilter")
    or function(event, filter)
        if ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter then
            return ChatFrameUtil.AddMessageEventFilter(event, filter)
        end
    end

----------------------------------------------------------------------
-- Diagnostics:  /fce compat   (quick view; full test is /fce apitest)
----------------------------------------------------------------------

function Compat.Report()
    local p = FCE.Print or print
    p(string.format("Client interface %d  (Forever: %s)", tocVersion,
        Compat.IS_FOREVER and "yes" or "no"))
    local checks = {
        "GetSpellInfo", "GetItemInfo", "GetItemCount", "UnitBuff", "UnitDebuff",
        "GetNumFactions", "GetFactionInfo", "GetNumSkillLines", "GetSkillLineInfo",
        "GetQuestsCompleted", "IsSpellKnown", "SendChatMessage",
        "GetNumTalentTabs", "GetTalentInfo", "GetNumTalents",
        "CombatLogGetCurrentEventInfo",
    }
    for _, name in ipairs(checks) do
        local state
        if native(name) then
            state = "|cff4de64dnative|r"
        elseif Compat[name] then
            state = "|cffe6b422shimmed|r"
        else
            state = "|cffff5a4cmissing|r"
        end
        p("  " .. name .. ": " .. state)
    end
    p("  Combat log: " .. (Compat.HAS_COMBAT_LOG and "|cff4de64davailable|r"
        or "|cffe6b422unavailable (spellcast fallback)|r"))
end
