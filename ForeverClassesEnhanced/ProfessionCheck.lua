----------------------------------------------------------------------
-- ForeverClassesEnhanced — Profession Tracking
--
-- Watches SKILL_LINES_CHANGED (and PLAYER_LOGIN) and checks the
-- player's professions against the selected character's requirements.
--
-- Starting at level 5, the addon verifies:
--   1. The correct professions are learned
--   2. Profession rank is keeping pace with player level
--      Expected rank formula: 5 * playerLevel
--        Level 20 → 100 skill, Level 40 → 200, Level 60 → 300
--
-- Results are stored in FCE_CharDB.profResults so the requirements
-- panel can display a PROFESSIONS section with pass/fail indicators.
--
-- Chat warnings fire once when a profession first falls behind.
-- This does NOT fire the red forbidden-item toast — being behind on
-- a profession is a softer problem than equipping a forbidden item.
--
-- Locale handling: profession names from GetSkillLineInfo() are
-- localised.  We map each required profession (English) to the set
-- of known locale-independent learn-spell IDs.  On SKILL_LINES_CHANGED
-- we read the skill list by name AND cross-reference via spell IDs
-- so non-English clients still work.  As a fast-path fallback for
-- English clients, we also do a direct name compare.
----------------------------------------------------------------------


local IsSpellKnown, GetNumSkillLines, GetSkillLineInfo, ExpandSkillHeader
    = FCE.Compat.IsSpellKnown, FCE.Compat.GetNumSkillLines, FCE.Compat.GetSkillLineInfo, FCE.Compat.ExpandSkillHeader  -- Forever API shims (ForeverCompat.lua)
FCE = FCE or {}

local PC = {}
FCE.ProfessionCheck = PC

----------------------------------------------------------------------
-- Status constants (shared vocabulary with EquipmentCheck)
----------------------------------------------------------------------

local PASS      = "pass"
local FAIL      = "fail"
local UNCHECKED = "unchecked"

PC.STATUS = { PASS = PASS, FAIL = FAIL, UNCHECKED = UNCHECKED }

----------------------------------------------------------------------
-- Profession-learning spell IDs (locale-independent)
--
-- Each primary profession has a "learn" spell that teaches rank 1
-- (Apprentice).  These IDs are stable across all Classic clients.
-- Secondary professions (Cooking, First Aid, Fishing) are included
-- because some characters require them.
----------------------------------------------------------------------

local PROF_SPELL_IDS = {
    -- Primary professions
    ["Alchemy"]        = { 2259 },   -- Alchemy (Apprentice)
    ["Blacksmithing"]  = { 2018 },   -- Blacksmithing (Apprentice)
    ["Enchanting"]     = { 7411 },   -- Enchanting (Apprentice)
    ["Engineering"]    = { 4036 },   -- Engineering (Apprentice)
    ["Herbalism"]      = { 2366 },   -- Herbalism (Apprentice passive)
    ["Leatherworking"] = { 2108 },   -- Leatherworking (Apprentice)
    ["Mining"]         = { 2575 },   -- Mining (Apprentice)
    ["Skinning"]       = { 8613 },   -- Skinning (Apprentice)
    ["Tailoring"]      = { 3908 },   -- Tailoring (Apprentice)

    -- Secondary professions
    ["Cooking"]        = { 2550 },   -- Cooking (Apprentice)
    ["First Aid"]      = { 3273 },   -- First Aid (Apprentice)
    ["Fishing"]        = { 7620 },   -- Fishing (Apprentice)
}

----------------------------------------------------------------------
-- Build a reverse map: spellID → English profession name.
-- At runtime we check IsSpellKnown(spellID) as a locale-safe way
-- to determine which professions the player has learned.
----------------------------------------------------------------------

local SPELL_TO_PROF = {}
for profName, spellIDs in pairs(PROF_SPELL_IDS) do
    for _, id in ipairs(spellIDs) do
        SPELL_TO_PROF[id] = profName
    end
end

----------------------------------------------------------------------
-- English → localised name cache.  Populated on first scan by
-- reading the actual skill line names and pairing them with the
-- spell-ID match.  Falls through to the English name if no mapping
-- is found (works fine on English clients).
----------------------------------------------------------------------

local localeNameCache = {}

----------------------------------------------------------------------
-- Skill-line scanning
----------------------------------------------------------------------

--- Parse the return values from GetSkillLineInfo defensively.
--- Classic 1.15.x may return values at unexpected positions.
--- @return name, isHeader, rank, maxRank
local function ParseSkillLine(i)
    local v = { GetSkillLineInfo(i) }
    local name     = v[1]
    local isHeader = v[2]

    -- In Classic, isHeader can be 1/nil, true/false, or "header"/nil.
    -- Normalise to boolean.
    if isHeader == 1 or isHeader == true then
        return name, true, 0, 0
    end

    -- Find rank and maxRank: scan return values for the first two
    -- numbers > 0 that look like skill values.  Positions 4 and 7 are
    -- the documented slots, but we fall back to scanning if those are
    -- nil or non-numeric (same defensive approach as the talent fix).
    local rank    = tonumber(v[4])
    local maxRank = tonumber(v[7])

    -- If documented positions failed, scan for numeric values
    if not rank then
        for idx = 3, #v do
            local n = tonumber(v[idx])
            if n and n > 0 then
                rank = n
                -- Keep looking for maxRank (next number >= rank)
                for j = idx + 1, #v do
                    local m = tonumber(v[j])
                    if m and m >= n then
                        maxRank = m
                        break
                    end
                end
                break
            end
        end
    end

    return name, false, rank or 0, maxRank or 0
end

--- Scan the player's skill list and return a table of
--- professions the player currently knows.
--- @return table  { [englishName] = { rank = N, maxRank = M, localName = "..." }, ... }
local scanningProfessions = false  -- guard against ExpandSkillHeader → SKILL_LINES_CHANGED loop

local function ScanProfessions()
    local found = {}

    -- Expand all collapsed skill headers so hidden professions become
    -- visible.  GetNumSkillLines() only counts VISIBLE lines; if the
    -- "Professions" or "Secondary Skills" header is collapsed, its
    -- children won't appear and we'd read rank as 0.
    if ExpandSkillHeader then
        scanningProfessions = true
        ExpandSkillHeader(0)  -- 0 = expand all headers
        scanningProfessions = false
    end

    -- Pass 1: scan skill lines directly — this is the most reliable
    -- detection method.  English name matching is the fast path.
    local numSkills = GetNumSkillLines and GetNumSkillLines() or 0
    for i = 1, numSkills do
        local name, isHeader, rank, maxRank = ParseSkillLine(i)
        if not isHeader and name then
            -- Direct English match (covers English clients)
            if PROF_SPELL_IDS[name] then
                found[name] = {
                    rank     = rank,
                    maxRank  = maxRank,
                    localName = name,
                }
                localeNameCache[name] = name
            end
        end
    end

    -- Pass 2: use spell IDs for locale-safe detection (non-English
    -- clients).  Only check professions not already found by name.
    for profName, spellIDs in pairs(PROF_SPELL_IDS) do
        if not found[profName] then
            for _, spellID in ipairs(spellIDs) do
                if IsSpellKnown and IsSpellKnown(spellID) then
                    found[profName] = { rank = 0, maxRank = 0, localName = profName }
                    break
                end
            end
        end
    end

    -- Pass 3: for spell-detected professions with rank 0, try to
    -- pair them with unmatched skill lines to read their rank.
    local unmatchedProfs = {}
    for profName, info in pairs(found) do
        if info.rank == 0 then
            table.insert(unmatchedProfs, profName)
        end
    end

    if #unmatchedProfs > 0 then
        -- Collect skill lines not already matched to a profession
        local unmatchedLines = {}
        for i = 1, numSkills do
            local name, isHeader, rank, maxRank = ParseSkillLine(i)
            if not isHeader and name and rank > 0 then
                local alreadyMatched = false
                for _, info in pairs(found) do
                    if info.localName == name and info.rank > 0 then
                        alreadyMatched = true
                        break
                    end
                end
                if not alreadyMatched then
                    table.insert(unmatchedLines, {
                        name = name, rank = rank, maxRank = maxRank,
                    })
                end
            end
        end

        -- Also try locale-cache matching first
        for _, profName in ipairs(unmatchedProfs) do
            if localeNameCache[profName] then
                for _, line in ipairs(unmatchedLines) do
                    if line.name == localeNameCache[profName] then
                        found[profName].rank      = line.rank
                        found[profName].maxRank   = line.maxRank
                        found[profName].localName = line.name
                        line.matched = true
                        break
                    end
                end
            end
        end

        -- Rebuild unmatched lists after cache matching
        local stillUnmatched = {}
        for _, profName in ipairs(unmatchedProfs) do
            if found[profName].rank == 0 then
                table.insert(stillUnmatched, profName)
            end
        end
        local stillUnmatchedLines = {}
        for _, line in ipairs(unmatchedLines) do
            if not line.matched then
                table.insert(stillUnmatchedLines, line)
            end
        end

        -- Pair by count if possible
        if #stillUnmatched == 1 and #stillUnmatchedLines >= 1 then
            local profName = stillUnmatched[1]
            local line = stillUnmatchedLines[1]
            found[profName].rank      = line.rank
            found[profName].maxRank   = line.maxRank
            found[profName].localName = line.name
            localeNameCache[profName] = line.name
        elseif #stillUnmatched > 0 and #stillUnmatchedLines == #stillUnmatched then
            for idx, profName in ipairs(stillUnmatched) do
                local line = stillUnmatchedLines[idx]
                if line then
                    found[profName].rank      = line.rank
                    found[profName].maxRank   = line.maxRank
                    found[profName].localName = line.name
                    localeNameCache[profName] = line.name
                end
            end
        end
    end

    return found
end

----------------------------------------------------------------------
-- Expected rank formula
----------------------------------------------------------------------

--- What rank should a profession be at for a given player level?
--- Linear: 5 * playerLevel, clamped to [1, 300].
--- Returns 0 below level 5 (no profession expected yet).
local function ExpectedRank(playerLevel, profName)
    if playerLevel < 5 then return 0 end
    local offset = (profName == "Enchanting") and 50 or 25
    local expected = (5 * playerLevel) - offset
    if expected > 300 then expected = 300 end
    return math.floor(expected + 0.5)
end

----------------------------------------------------------------------
-- Checking logic
----------------------------------------------------------------------

--- Run profession checks for the current character.
--- @return table  { [profName] = { status, detail, rank, expected } }
function PC.CheckAll()
    local results = {}
    if not FCE_CharDB then return results end

    local key = FCE_CharDB.selectedCharacter
    local char = key and FCE.GetCharacter and FCE.GetCharacter(key) or nil
    if not char then return results end
    if not char.professions or #char.professions == 0 then return results end

    local playerLevel = UnitLevel("player") or 1

    -- Not yet level 5: everything is inactive
    if playerLevel < 5 then
        for _, profName in ipairs(char.professions) do
            results[profName] = {
                status   = "inactive",
                detail   = "Profession tracking starts at level 5",
                rank     = 0,
                expected = 0,
            }
        end
        return results
    end

    local known = ScanProfessions()

    for _, profName in ipairs(char.professions) do
        local expected = ExpectedRank(playerLevel, profName)
        local info = known[profName]
        if not info then
            -- Profession not learned at all
            results[profName] = {
                status   = FAIL,
                detail   = profName .. " not learned yet",
                rank     = 0,
                expected = expected,
            }
        else
            if info.rank >= expected then
                results[profName] = {
                    status   = PASS,
                    detail   = string.format(
                        "%s rank %d / %d (expected %d at lv %d)",
                        info.localName or profName, info.rank, info.maxRank, expected, playerLevel
                    ),
                    rank     = info.rank,
                    expected = expected,
                }
            else
                -- Behind pace
                local delta = expected - info.rank
                results[profName] = {
                    status   = FAIL,
                    detail   = string.format(
                        "%s rank %d — %d point%s behind (expected %d at lv %d)",
                        info.localName or profName, info.rank,
                        delta, delta == 1 and "" or "s",
                        expected, playerLevel
                    ),
                    rank     = info.rank,
                    expected = expected,
                }
            end
        end
    end

    return results
end

--- Run a full check and store results in SavedVariables.
function PC.RunCheck()
    local results = PC.CheckAll()
    if FCE_CharDB then
        FCE_CharDB.profResults = results
    end
    return results
end

--- Get stored results from the last check.
function PC.GetResults()
    return FCE_CharDB and FCE_CharDB.profResults or {}
end

----------------------------------------------------------------------
-- Chat warnings (one-shot per profession per state transition)
----------------------------------------------------------------------

local CHAT_PREFIX = "|cffe6b422[FCE]|r "

-- Track which professions we've already warned about so we only
-- warn once per session per transition (not-learned, or falling behind).
local warnedNotLearned  = {}
local warnedBehind      = {}

--- Run checks and fire chat warnings for new problems.
--- Does NOT fire the ForbiddenAlert toast — profession shortfalls
--- are a softer warning than equipping a forbidden item.
function PC.CheckAndWarn()
    local oldResults = PC.GetResults()

    -- Snapshot old statuses before RunCheck overwrites them
    local oldStatus = {}
    for prof, r in pairs(oldResults) do oldStatus[prof] = r.status end

    local newResults = PC.RunCheck()

    for prof, res in pairs(newResults) do
        if res.status == FAIL then
            local was = oldStatus[prof]
            if res.rank == 0 and not warnedNotLearned[prof] then
                -- Profession not learned
                if not FCE.ChatWarningsEnabled or FCE.ChatWarningsEnabled() then
                    DEFAULT_CHAT_FRAME:AddMessage(
                        CHAT_PREFIX .. "|cffffaa33Profession needed:|r " .. prof ..
                        " — should be learned by now (you're level " ..
                        (UnitLevel("player") or "?") .. ")"
                    )
                end
                warnedNotLearned[prof] = true
            elseif res.rank > 0 and was ~= FAIL and not warnedBehind[prof] then
                -- Falling behind
                if not FCE.ChatWarningsEnabled or FCE.ChatWarningsEnabled() then
                    DEFAULT_CHAT_FRAME:AddMessage(
                        CHAT_PREFIX .. "|cffffaa33Profession falling behind:|r " ..
                        res.detail
                    )
                end
                warnedBehind[prof] = true
            end
        elseif res.status == PASS then
            -- Clear the warning flags so we can re-warn if they fall
            -- behind again later
            warnedNotLearned[prof] = nil
            warnedBehind[prof]     = nil
        end
    end

    -- Refresh the panel to show updated indicators
    if FCE.RefreshPanel then FCE.RefreshPanel() end
end

--- Reset one-shot warning state.  Called when a new character is
--- selected so stale warnings from a previous pick don't block.
function PC.ResetWarnings()
    warnedNotLearned = {}
    warnedBehind     = {}
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("SKILL_LINES_CHANGED")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")

local initialCheckDone = false

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        -- Defer so SavedVariables and CharacterData are ready,
        -- and the skill list has populated.
        C_Timer.After(2.5, function()
            PC.RunCheck()
            initialCheckDone = true
            if FCE.RefreshPanel then FCE.RefreshPanel() end
        end)
        -- Second pass to catch late-loading skill data
        C_Timer.After(5.5, function()
            PC.CheckAndWarn()
        end)

    elseif event == "SKILL_LINES_CHANGED" then
        if not initialCheckDone then return end
        if scanningProfessions then return end  -- ignore events from our own ExpandSkillHeader
        -- Small delay to let the skill data settle
        C_Timer.After(0.3, function()
            PC.CheckAndWarn()
        end)

    elseif event == "PLAYER_LEVEL_UP" then
        if not initialCheckDone then return end
        -- Re-check on level up because the expected rank changes
        C_Timer.After(0.5, function()
            PC.CheckAndWarn()
        end)
    end
end)
