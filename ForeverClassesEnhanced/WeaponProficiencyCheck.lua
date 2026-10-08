----------------------------------------------------------------------
-- ForeverClassesEnhanced — Weapon Proficiency Tracking
--
-- Watches SKILL_LINES_CHANGED (and PLAYER_LOGIN) and checks the
-- player's weapon skill levels against the selected character's
-- weaponProficiency requirements.
--
-- Required skill formula: (5 * playerLevel) - 5
--   Level  1 →   0 (inactive — tracking starts at level 2)
--   Level 10 →  45
--   Level 20 →  95
--   Level 40 → 195
--   Level 60 → 295
--
-- Results are stored in FCE_CharDB.weaponProfResults so the
-- requirements panel can display a WEAPON PROFICIENCY section.
--
-- Chat warnings fire once when a weapon skill first falls behind.
----------------------------------------------------------------------


local GetNumSkillLines, GetSkillLineInfo
    = FCE.Compat.GetNumSkillLines, FCE.Compat.GetSkillLineInfo  -- Forever API shims (ForeverCompat.lua)
FCE = FCE or {}

local WP = {}
FCE.WeaponProficiencyCheck = WP

----------------------------------------------------------------------
-- Status constants
----------------------------------------------------------------------

local PASS      = "pass"
local FAIL      = "fail"
local UNCHECKED = "unchecked"

WP.STATUS = { PASS = PASS, FAIL = FAIL, UNCHECKED = UNCHECKED }

--- Extract weapon name and activation level from a weaponProficiency entry.
--- Supports both plain strings ("Bows") and E()-style tables ({ desc="Bows", level=10 }).
--- @param entry string|table
--- @return string name, number level
local function parseWpnEntry(entry)
    if type(entry) == "table" then
        return entry.desc or entry.name or "?", entry.level or 1
    end
    return entry, 1
end

----------------------------------------------------------------------
-- Weapon skill scanning
--
-- Weapon skills live in the Skills window under the "Weapon Skills"
-- header.  We iterate GetSkillLineInfo() looking for lines under
-- that header whose names match required weapon types.
----------------------------------------------------------------------

--- Parse GetSkillLineInfo defensively (same approach as ProfessionCheck).
--- @return name, isHeader, rank, maxRank
local function ParseSkillLine(i)
    local v = { GetSkillLineInfo(i) }
    local name     = v[1]
    local isHeader = v[2]

    if isHeader == 1 or isHeader == true then
        return name, true, 0, 0
    end

    local rank    = tonumber(v[4])
    local maxRank = tonumber(v[7])

    if not rank then
        for idx = 3, #v do
            local n = tonumber(v[idx])
            if n and n > 0 then
                rank = n
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

--- Scan the skill list for weapon skill lines.
--- Returns { ["Swords"] = { rank = 120, maxRank = 300 }, ... }
local function ScanWeaponSkills()
    local found = {}
    local numSkills = GetNumSkillLines and GetNumSkillLines() or 0
    local inWeapons = false

    for i = 1, numSkills do
        local name, isHeader, rank, maxRank = ParseSkillLine(i)
        if isHeader then
            -- "Weapon Skills" is the header in English clients.
            -- Other locales use translated equivalents.
            -- We toggle inWeapons on *any* header, so the first
            -- non-matching header ends the weapon section.
            if name == "Weapon Skills" then
                inWeapons = true
            else
                if inWeapons then break end  -- left the weapon section
            end
        elseif inWeapons and name then
            found[name] = { rank = rank, maxRank = maxRank }
        end
    end

    return found
end

----------------------------------------------------------------------
-- Expected rank formula
----------------------------------------------------------------------

--- What weapon skill rank is expected at a given player level?
--- Formula: 5 * level - 5, clamped to [0, 300].
--- Returns 0 below level 2 (no tracking yet).
local function ExpectedRank(playerLevel)
    if playerLevel < 5 then return 0 end
    local expected = (5 * playerLevel) - 10
    if expected > 300 then expected = 300 end
    return expected
end

----------------------------------------------------------------------
-- Checking logic
----------------------------------------------------------------------

--- Run weapon proficiency checks for the current character.
--- @return table  { [weaponName] = { status, detail, rank, expected } }
function WP.CheckAll()
    local results = {}
    if not FCE_CharDB then return results end

    local key = FCE_CharDB.selectedCharacter
    local char = key and FCE.GetCharacter and FCE.GetCharacter(key) or nil
    if not char then return results end
    if not char.weaponProficiency or #char.weaponProficiency == 0 then
        return results
    end

    local playerLevel = UnitLevel("player") or 1
    local known = ScanWeaponSkills()
    local expected = ExpectedRank(playerLevel)

    for _, entry in ipairs(char.weaponProficiency) do
        local wpn, wpnLevel = parseWpnEntry(entry)

        -- Special: "Weapon Mastery" is an aggregate check, not a single weapon
        if wpn == "Weapon Mastery" then
            if playerLevel < wpnLevel then
                results[wpn] = {
                    status   = "inactive",
                    detail   = "Weapon Mastery tracking starts at level " .. wpnLevel,
                    rank     = 0,
                    expected = 0,
                }
            else
                results[wpn] = WP.CheckWeaponMastery(4, 10)
            end
        -- Below the weapon's activation level: inactive
        elseif playerLevel < wpnLevel then
            results[wpn] = {
                status   = "inactive",
                detail   = wpn .. " tracking starts at level " .. wpnLevel,
                rank     = 0,
                expected = 0,
            }
        else

        local info = known[wpn]
        if not info then
            -- Weapon skill not found at all (might not have trained it)
            results[wpn] = {
                status   = FAIL,
                detail   = wpn .. " weapon skill not found — visit a weapon master",
                rank     = 0,
                expected = expected,
            }
        else
            if info.rank >= expected then
                results[wpn] = {
                    status   = PASS,
                    detail   = string.format(
                        "%s skill %d / %d (required %d at lv %d)",
                        wpn, info.rank, info.maxRank, expected, playerLevel
                    ),
                    rank     = info.rank,
                    expected = expected,
                }
            else
                local delta = expected - info.rank
                results[wpn] = {
                    status   = FAIL,
                    detail   = string.format(
                        "%s skill %d — %d point%s behind (required %d at lv %d)",
                        wpn, info.rank,
                        delta, delta == 1 and "" or "s",
                        expected, playerLevel
                    ),
                    rank     = info.rank,
                    expected = expected,
                }
            end
        end
        end  -- close the if/else for wpnLevel check
    end

    return results
end

--- Run a full check and store results in SavedVariables.
function WP.RunCheck()
    local results = WP.CheckAll()
    if FCE_CharDB then
        FCE_CharDB.weaponProfResults = results
    end
    return results
end

--- Get stored results from the last check.
function WP.GetResults()
    return FCE_CharDB and FCE_CharDB.weaponProfResults or {}
end

----------------------------------------------------------------------
-- Chat warnings (one-shot per weapon per state transition)
----------------------------------------------------------------------

local CHAT_PREFIX = "|cffe6b422[FCE]|r "

local warnedMissing = {}
local warnedBehind  = {}

--- Run checks and fire chat warnings for new problems.
function WP.CheckAndWarn()
    local oldResults = WP.GetResults()
    local oldStatus = {}
    for wpn, r in pairs(oldResults) do oldStatus[wpn] = r.status end

    local newResults = WP.RunCheck()

    for wpn, res in pairs(newResults) do
        if res.status == FAIL then
            local was = oldStatus[wpn]
            if res.rank == 0 and not warnedMissing[wpn] then
                if not FCE.ChatWarningsEnabled or FCE.ChatWarningsEnabled() then
                    DEFAULT_CHAT_FRAME:AddMessage(
                        CHAT_PREFIX .. "|cffffaa33Weapon skill needed:|r " .. wpn ..
                        " — train this weapon type at a weapon master"
                    )
                end
                warnedMissing[wpn] = true
            elseif res.rank > 0 and was ~= FAIL and not warnedBehind[wpn] then
                if not FCE.ChatWarningsEnabled or FCE.ChatWarningsEnabled() then
                    DEFAULT_CHAT_FRAME:AddMessage(
                        CHAT_PREFIX .. "|cffffaa33Weapon skill falling behind:|r " ..
                        res.detail
                    )
                end
                warnedBehind[wpn] = true
            end
        elseif res.status == PASS then
            warnedMissing[wpn] = nil
            warnedBehind[wpn]  = nil
        end
    end

    if FCE.RefreshPanel then FCE.RefreshPanel() end
end

----------------------------------------------------------------------
-- Weapon Mastery challenge
--
-- Checks that the player has at least N different weapon skills
-- within THRESHOLD points of ExpectedRank.  Used as a special
-- weaponProficiency entry: E("Weapon Mastery", level).
----------------------------------------------------------------------

function WP.CheckWeaponMastery(requiredCount, threshold)
    requiredCount = requiredCount or 4
    threshold     = threshold or 10

    local playerLevel = UnitLevel("player") or 1
    local expected = ExpectedRank(playerLevel)
    if expected == 0 then
        return {
            status = UNCHECKED,
            detail = "Weapon Mastery tracking starts at level 5",
        }
    end

    local known = ScanWeaponSkills()
    local qualifying = {}
    local behind = {}

    for name, info in pairs(known) do
        if info.rank >= (expected - threshold) then
            qualifying[#qualifying + 1] = string.format("%s (%d)", name, info.rank)
        else
            behind[#behind + 1] = string.format("%s (%d/%d)", name, info.rank, expected)
        end
    end

    local count = #qualifying
    if count >= requiredCount then
        return {
            status = PASS,
            detail = string.format(
                "%d weapon skills within %d of %d: %s",
                count, threshold, expected, table.concat(qualifying, ", ")
            ),
        }
    else
        return {
            status = FAIL,
            detail = string.format(
                "%d/%d weapon skills within %d of %d. Qualifying: %s",
                count, requiredCount, threshold, expected,
                count > 0 and table.concat(qualifying, ", ") or "none"
            ),
        }
    end
end

--- Reset one-shot warning state.
function WP.ResetWarnings()
    warnedMissing = {}
    warnedBehind  = {}
end

----------------------------------------------------------------------
-- Slash command: /fce weapons
----------------------------------------------------------------------

function WP.PrintStatus()
    if not FCE_CharDB or not FCE_CharDB.selectedCharacter then
        FCE.Print("No enhanced class selected.")
        return
    end

    local char = FCE.GetCharacter and FCE.GetCharacter(FCE_CharDB.selectedCharacter)
    if not char or not char.weaponProficiency or #char.weaponProficiency == 0 then
        FCE.Print("Your character has no weapon proficiency requirements.")
        return
    end

    WP.RunCheck()
    local results = WP.GetResults()
    local playerLevel = UnitLevel("player") or 1
    local expected = ExpectedRank(playerLevel)

    FCE.Print("Weapon proficiency — required " .. expected .. " at level " .. playerLevel .. ":")
    for _, entry in ipairs(char.weaponProficiency) do
        local wpn = parseWpnEntry(entry)
        local res = results[wpn]
        if not res then
            FCE.Print("  |cff888888" .. wpn .. " — not checked|r")
        elseif res.status == "inactive" then
            FCE.Print("  |cff595959" .. wpn .. " — " .. res.detail .. "|r")
        elseif res.status == PASS then
            FCE.Print("  |cff00ff00PASS|r " .. res.detail)
        elseif res.status == FAIL then
            FCE.Print("  |cffff3333FAIL|r " .. res.detail)
        else
            FCE.Print("  |cffa5a582?|r " .. wpn)
        end
    end
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
    -- Only run if we have a character with weapon proficiency requirements
    if not FCE_CharDB or not FCE_CharDB.selectedCharacter then return end
    local char = FCE.GetCharacter and FCE.GetCharacter(FCE_CharDB.selectedCharacter)
    if not char or not char.weaponProficiency or #char.weaponProficiency == 0 then
        return
    end

    if event == "PLAYER_LOGIN" then
        C_Timer.After(2.5, function()
            WP.RunCheck()
            initialCheckDone = true
            if FCE.RefreshPanel then FCE.RefreshPanel() end
        end)
        C_Timer.After(5.5, function()
            WP.CheckAndWarn()
        end)

    elseif event == "SKILL_LINES_CHANGED" then
        if not initialCheckDone then return end
        C_Timer.After(0.3, function()
            WP.CheckAndWarn()
        end)

    elseif event == "PLAYER_LEVEL_UP" then
        if not initialCheckDone then return end
        C_Timer.After(0.5, function()
            WP.CheckAndWarn()
        end)
    end
end)
