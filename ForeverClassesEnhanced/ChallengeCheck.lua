----------------------------------------------------------------------
-- ForeverClassesEnhanced — Challenge Tracking (Rule Engine)
--
-- Each challenge type from CharacterData gets a checker function that
-- evaluates the player's CURRENT STATE against the challenge rules.
-- This is the central engine; individual checkers range from trivial
-- (quality-based gear checks) to zone-based (ZoneCheck.lua) to
-- item-source (Scavenger/Partisan/Off-the-shelf using curated lists
-- from ItemSourceData.lua).
--
-- Challenges covered by other modules:
--   Self-made, Self-made guns → SelfFoundCheck.lua
--   Homebound, zone visits    → ZoneCheck.lua
--   Item source data          → ItemSourceData.lua
--
-- Results are stored in FCE_CharDB.challengeResults so the
-- RequirementsPanel can show pass/fail/unchecked indicators.
----------------------------------------------------------------------


local IsSpellKnown, GetItemInfo, UnitBuff, GetNumFactions, GetFactionInfo
    = FCE.Compat.IsSpellKnown, FCE.Compat.GetItemInfo, FCE.Compat.UnitBuff, FCE.Compat.GetNumFactions, FCE.Compat.GetFactionInfo  -- Forever API shims (ForeverCompat.lua)
FCE = FCE or {}

local CC = {}
FCE.ChallengeCheck = CC

----------------------------------------------------------------------
-- Status constants (same vocabulary as EquipmentCheck)
----------------------------------------------------------------------

local PASS      = "pass"
local FAIL      = "fail"
local UNCHECKED = "unchecked"

CC.STATUS = {
    PASS      = PASS,
    FAIL      = FAIL,
    UNCHECKED = UNCHECKED,
}

----------------------------------------------------------------------
-- Challenge forgiveness based on completion %
----------------------------------------------------------------------

--- Challenges eligible for item forgiveness based on completion %.
local FORGIVABLE_CHALLENGES = {
    ["exotic"]        = true,
    ["scout"]         = true,
    ["scavenger"]     = true,
    ["partisan"]      = true,
    ["self-made"]     = true,
    ["cloth/leather"] = true,
    ["leather/mail"]  = true,
    ["mail/plate"]    = true,
    ["expeditionary"]    = true,
    ["cloth"]    = true,
    ["leather"]     = true,
}

--- Pre-computed forgiveness allowance, set by RunCheck() before CheckAll().
--- When set, getAllowedViolations() uses this instead of recomputing.
--- This breaks the circular dependency: forgivable challenges need to know
--- the rank, but the rank depends on whether they pass.  We solve it by
--- computing the rank optimistically (assuming forgivable challenges PASS)
--- before evaluating them.
local cachedAllowedViolations = nil

--- Get the number of allowed item violations for a forgivable challenge.
--- 0-24% -> 0 allowed, 25-49% -> 1, 50-74% -> 2, 75-99% -> 3, 100% -> 999 (fully lifted)
local function getAllowedViolations()
    if cachedAllowedViolations then return cachedAllowedViolations end
    if not FCE.Progress or not FCE.Progress.Collect or not FCE.Progress.Percentage then
        return 0
    end
    local summary = FCE.Progress.Collect()
    if not summary or not summary.counts then return 0 end
    local pct = FCE.Progress.Percentage(summary.counts)
    if pct >= 100 then return 999 end  -- fully lifted
    if pct >= 75 then return 3 end
    if pct >= 50 then return 2 end
    if pct >= 25 then return 1 end
    return 0
end

--- Compute the forgiveness allowance optimistically: temporarily set all
--- forgivable challenge stored results to PASS so the rank calculation
--- isn't dragged down by the very challenges that need forgiveness.
local function computeOptimisticAllowed()
    if not FCE.Progress or not FCE.Progress.Collect or not FCE.Progress.Percentage then
        return 0
    end
    -- Temporarily flip forgivable challenge results to PASS
    local stored = FCE_CharDB and FCE_CharDB.challengeResults or {}
    if FCE_CharDB and not FCE_CharDB.challengeResults then
        FCE_CharDB.challengeResults = stored
    end
    local saved = {}    -- backup originals (may be nil)
    local touched = {}  -- track which indices we modified
    local key = FCE_CharDB and FCE_CharDB.selectedCharacter
    local char = key and FCE.GetCharacter and FCE.GetCharacter(key) or nil
    local activeChallenges = char and FCE.GetActiveChallenges and FCE.GetActiveChallenges(char) or (char and char.challenges or {})
    if #activeChallenges > 0 then
        for i, ch in ipairs(activeChallenges) do
            local lowerDesc = ch.desc and ch.desc:lower() or ""
            if FORGIVABLE_CHALLENGES[lowerDesc] then
                saved[i] = stored[i]  -- may be nil
                touched[i] = true
                stored[i] = { status = "pass", detail = "optimistic", desc = ch.desc }
            end
        end
    end
    -- Compute rank with the optimistic results
    local summary = FCE.Progress.Collect()
    -- Restore originals (nil means the slot was empty before)
    for i in pairs(touched) do
        stored[i] = saved[i]
    end
    if not summary or not summary.counts then return 0 end
    local pct = FCE.Progress.Percentage(summary.counts)
    if pct >= 100 then return 999 end
    if pct >= 75 then return 3 end
    if pct >= 50 then return 2 end
    if pct >= 25 then return 1 end
    return 0
end

----------------------------------------------------------------------
-- WoW Classic inventory slot IDs (duplicated from EquipmentCheck so
-- this module is self-contained — they're just integer constants)
----------------------------------------------------------------------

local SLOT = {
    HEAD      =  1,
    NECK      =  2,
    SHOULDER  =  3,
    SHIRT     =  4,
    CHEST     =  5,
    WAIST     =  6,
    LEGS      =  7,
    FEET      =  8,
    WRIST     =  9,
    HANDS     = 10,
    FINGER0   = 11,
    FINGER1   = 12,
    TRINKET0  = 13,
    TRINKET1  = 14,
    BACK      = 15,
    MAINHAND  = 16,
    OFFHAND   = 17,
    RANGED    = 18,
    TABARD    = 19,
}

-- Armor classID = 4, weapon classID = 2 (from GetItemInfo)
local ARMOR_CLASS  = 4
local WEAPON_CLASS = 2

local ARMOR_SUB = {
    MISC    = 0,
    CLOTH   = 1,
    LEATHER = 2,
    MAIL    = 3,
    PLATE   = 4,
    SHIELD  = 6,
}

----------------------------------------------------------------------
-- Equipment snapshot helper — reuses EquipmentCheck if available,
-- otherwise builds its own (defensive, should never actually run
-- because EquipmentCheck loads first)
----------------------------------------------------------------------

local function getEquipSnapshot()
    if FCE.EquipmentCheck and FCE.EquipmentCheck.Snapshot then
        return FCE.EquipmentCheck.Snapshot()
    end
    -- Fallback: build a minimal snapshot ourselves
    local state = {}
    for _, slotID in pairs(SLOT) do
        local itemID = GetInventoryItemID("player", slotID)
        if itemID then
            local name, link, quality, _, _, _, _,
                  _, equipLoc, _, _, classID, subclassID = GetItemInfo(itemID)
            if classID then
                state[slotID] = {
                    id         = itemID,
                    name       = name or "",
                    quality    = quality or 0,
                    classID    = classID,
                    subclassID = subclassID,
                    equipLoc   = equipLoc or "",
                }
            end
        end
    end
    return state
end

----------------------------------------------------------------------
-- Armor slot set — slots where armor can be worn (excludes shirt,
-- tabard, weapons, trinkets, rings, neck).  Used by quality and
-- armor-type challenges that only care about actual armor pieces.
----------------------------------------------------------------------

local ARMOR_SLOTS = {
    SLOT.HEAD, SLOT.SHOULDER, SLOT.CHEST, SLOT.WAIST,
    SLOT.LEGS, SLOT.FEET, SLOT.WRIST, SLOT.HANDS, SLOT.BACK,
}

-- ALL gear slots — every slot that can hold a quality-bearing item.
-- Used by quality-based challenges (White Knight, Exotic, etc.).
-- Excludes shirt and tabard since those are cosmetic.
local GEAR_SLOTS = {
    SLOT.HEAD, SLOT.NECK, SLOT.SHOULDER, SLOT.CHEST,
    SLOT.WAIST, SLOT.LEGS, SLOT.FEET, SLOT.WRIST, SLOT.HANDS,
    SLOT.FINGER0, SLOT.FINGER1, SLOT.TRINKET0, SLOT.TRINKET1,
    SLOT.BACK, SLOT.MAINHAND, SLOT.OFFHAND, SLOT.RANGED,
}

----------------------------------------------------------------------
-- Challenge rule registry
--
-- Maps challenge description strings (from CharacterData.challenges)
-- to checker functions.  Each function receives no arguments (it
-- reads from the WoW API directly) and returns (status, detail).
--
-- Matching is case-insensitive.
----------------------------------------------------------------------

local rules = {}

local function R(pattern, fn)
    rules[pattern:lower()] = fn
end

----------------------------------------------------------------------
-- QUALITY-BASED CHALLENGES
----------------------------------------------------------------------

--- Helper: scan all gear slots and flag items whose quality violates
--- a predicate.  Returns (status, detail).
--- @param badQualityFn  function(quality) -> bool  true if this quality is forbidden
--- @param ruleName      string  for the detail message
-- Items exempt from quality checks (quest rewards, class-defining items, etc.)
local QUALITY_EXEMPT = {
}
local function qualityGearCheck(badQualityFn, ruleName, isForgivable)
    local state = getEquipSnapshot()
    local violations = {}
    local checked = 0

    for _, sid in ipairs(GEAR_SLOTS) do
        local item = state[sid]
        if item then
            checked = checked + 1
            if badQualityFn(item.quality) and not QUALITY_EXEMPT[item.id] then
                local qLabel
                if item.quality == 1 then qLabel = "common"
                elseif item.quality == 2 then qLabel = "uncommon"
                elseif item.quality == 3 then qLabel = "rare"
                elseif item.quality == 4 then qLabel = "epic"
                elseif item.quality == 0 then qLabel = "poor"
                else qLabel = "q" .. item.quality end
                table.insert(violations, item.name .. " (" .. qLabel .. ")")
            end
        end
    end

    if #violations > 0 then
        -- Check if this challenge has forgiveness allowance
        local allowed = (isForgivable and getAllowedViolations()) or 0
        if #violations <= allowed then
            return PASS, #violations .. " item" .. (#violations > 1 and "s" or "")
                .. " exempt (" .. allowed .. " allowed at current rank)"
        end
        local detail = ruleName .. " — " .. #violations .. " violation"
            .. (#violations > 1 and "s" or "") .. ": "
            .. table.concat(violations, ", ")
        if allowed > 0 then
            detail = detail .. " (" .. allowed .. " exempt, " .. (#violations - allowed) .. " over limit)"
        end
        return FAIL, detail
    end
    if #violations == 0 and ruleName == "Scout" then
        local allowed = getAllowedViolations()
        if allowed > 0 then
            return PASS, "Wearing 0 rare/epic items despite having " .. allowed .. " exemption(s)."
        end
    end
    if #violations == 0 and ruleName == "Exotic" then
        local allowed = getAllowedViolations()
        if allowed > 0 then
            return PASS, "Wearing 0 green items despite having " .. allowed .. " exemption(s)."
        end
    end
    if checked == 0 then
        return PASS, "No gear equipped"
    end

    return PASS, "All " .. checked .. " equipped items meet the " .. ruleName .. " rule"
end

-- White knight: only white (1) or grey (0) gear
R("White knight", function()
    return qualityGearCheck(
        function(q) return q >= 2 end,
        "White Knight (white/grey only)"
    )
end)

-- Exotic: no uncommon (green, quality 2) gear
R("Exotic", function()
    return qualityGearCheck(
        function(q) return q == 2 end,
        "Exotic",
        true  -- forgivable
    )
end)

-- Footman: no rare (3) or epic (4) quality items
R("Footman", function()
    return qualityGearCheck(
        function(q) return q >= 3 end,
        "Footman (no rare/epic)"
    )
end)

-- Grunt: same as Footman — no rare or epic
R("Grunt", function()
    return qualityGearCheck(
        function(q) return q >= 3 end,
        "Grunt (no rare/epic)"
    )
end)

-- Scout: no rare or epic (forgivable)
R("Scout", function()
    return qualityGearCheck(
        function(q) return q >= 3 end,
        "Scout",
        true  -- forgivable
    )
end)

----------------------------------------------------------------------
-- ARMOR-TYPE CHALLENGES
----------------------------------------------------------------------

R("Cloth", function()
    local state = getEquipSnapshot()
    local violations = {}
    local shoulderViolations = {}
    local checked = 0

    -- Slots that actually have armor subclasses (head, shoulder, chest,
    -- waist, legs, feet, wrist, hands).  Back is always "cloth" in Classic.
    local checkSlots = {
        SLOT.HEAD, SLOT.SHOULDER, SLOT.CHEST, SLOT.WAIST,
        SLOT.LEGS, SLOT.FEET, SLOT.WRIST, SLOT.HANDS,
    }

    for _, sid in ipairs(checkSlots) do
        local item = state[sid]
        if item and item.classID == ARMOR_CLASS then
            checked = checked + 1
            local sub = item.subclassID
            if sub ~= ARMOR_SUB.CLOTH and sub ~= ARMOR_SUB.MISC then
                local label
                if sub == ARMOR_SUB.MAIL then label = "mail"
                elseif sub == ARMOR_SUB.PLATE then label = "plate"
                elseif sub == ARMOR_SUB.LEATHER then label = "leather"
                else label = "type " .. sub end
                local desc = item.name .. " (" .. label .. ")"
                if sid == SLOT.SHOULDER then
                    table.insert(shoulderViolations, desc)
                else
                    table.insert(violations, desc)
                end
            end
        end
    end

    local totalViolations = #violations + #shoulderViolations
    if totalViolations > 0 then
        local allowed = getAllowedViolations()
        -- Shoulder violations are unforgivable — only forgive non-shoulder ones
        local forgiven = math.min(allowed, #violations)
        local remaining = (#violations - forgiven) + #shoulderViolations
        if remaining <= 0 then
            return PASS, totalViolations .. " item"
                .. (totalViolations > 1 and "s" or "") .. " exempt ("
                .. allowed .. " allowed at current rank)"
        end
        local allViolations = {}
        for _, v in ipairs(shoulderViolations) do table.insert(allViolations, v) end
        for _, v in ipairs(violations) do table.insert(allViolations, v) end
        local detail = "Cloth only — " .. totalViolations .. " violation"
            .. (totalViolations > 1 and "s" or "") .. ": "
            .. table.concat(allViolations, ", ")
        if forgiven > 0 then
            detail = detail .. " (" .. forgiven .. " exempt, " .. remaining .. " over limit)"
        end
        return FAIL, detail
    end
    if totalViolations == 0 then
        local allowed = getAllowedViolations()
        if allowed > 0 then
            return PASS, "Wearing 0 leather gear despite having " .. allowed .. " exemption(s)."
        end
    end
    if checked == 0 then
        return PASS, "No armor equipped"
    end

    return PASS, "All " .. checked .. " armor pieces are cloth"
end)


R("Leather", function()
    local state = getEquipSnapshot()
    local violations = {}
    local shoulderViolations = {}
    local checked = 0

    -- Slots that actually have armor subclasses (head, shoulder, chest,
    -- waist, legs, feet, wrist, hands).  Back is always "leather" in Classic.
    local checkSlots = {
        SLOT.HEAD, SLOT.SHOULDER, SLOT.CHEST, SLOT.WAIST,
        SLOT.LEGS, SLOT.FEET, SLOT.WRIST, SLOT.HANDS,
    }

    for _, sid in ipairs(checkSlots) do
        local item = state[sid]
        if item and item.classID == ARMOR_CLASS then
            checked = checked + 1
            local sub = item.subclassID
            if sub ~= ARMOR_SUB.LEATHER and sub ~= ARMOR_SUB.MISC then
                local label
                if sub == ARMOR_SUB.CLOTH then label = "cloth"
                else label = "type " .. sub end
                local desc = item.name .. " (" .. label .. ")"
                if sid == SLOT.SHOULDER then
                    table.insert(shoulderViolations, desc)
                else
                    table.insert(violations, desc)
                end
            end
        end
    end

    local totalViolations = #violations + #shoulderViolations
    if totalViolations > 0 then
        local allowed = getAllowedViolations()
        -- Shoulder violations are unforgivable — only forgive non-shoulder ones
        local forgiven = math.min(allowed, #violations)
        local remaining = (#violations - forgiven) + #shoulderViolations
        if remaining <= 0 then
            return PASS, totalViolations .. " item"
                .. (totalViolations > 1 and "s" or "") .. " exempt ("
                .. allowed .. " allowed at current rank)"
        end
        local allViolations = {}
        for _, v in ipairs(shoulderViolations) do table.insert(allViolations, v) end
        for _, v in ipairs(violations) do table.insert(allViolations, v) end
        local detail = "Leather only — " .. totalViolations .. " violation"
            .. (totalViolations > 1 and "s" or "") .. ": "
            .. table.concat(allViolations, ", ")
        if forgiven > 0 then
            detail = detail .. " (" .. forgiven .. " exempt, " .. remaining .. " over limit)"
        end
        return FAIL, detail
    end
    if totalViolations == 0 then
        local allowed = getAllowedViolations()
        if allowed > 0 then
            return PASS, "Wearing 0 cloth gear despite having " .. allowed .. " exemption(s)."
        end
    end
    if checked == 0 then
        return PASS, "No armor equipped"
    end

    return PASS, "All " .. checked .. " armor pieces are leather"
end)

-- Leather/mail: leather only until 40, then leather or mail.
R("Leather/mail", function()
    local state = getEquipSnapshot()
    local violations = {}
    local shoulderViolations = {}
    local checked = 0
    local level = UnitLevel("player")
    local allowMail = (level >= 40)

    local checkSlots = {
        SLOT.HEAD, SLOT.SHOULDER, SLOT.CHEST, SLOT.WAIST,
        SLOT.LEGS, SLOT.FEET, SLOT.WRIST, SLOT.HANDS,
    }

    for _, sid in ipairs(checkSlots) do
        local item = state[sid]
        if item and item.classID == ARMOR_CLASS then
            checked = checked + 1
            local sub = item.subclassID
            local ok = (sub == ARMOR_SUB.LEATHER or sub == ARMOR_SUB.MISC)
            if allowMail then
                ok = ok or (sub == ARMOR_SUB.MAIL)
            end
            if not ok then
                local label
                if sub == ARMOR_SUB.CLOTH then label = "cloth"
                elseif sub == ARMOR_SUB.MAIL then label = "mail"
                elseif sub == ARMOR_SUB.PLATE then label = "plate"
                else label = "type " .. sub end
                local desc = item.name .. " (" .. label .. ")"
                if sid == SLOT.SHOULDER then
                    table.insert(shoulderViolations, desc)
                else
                    table.insert(violations, desc)
                end
            end
        end
    end

    local totalViolations = #violations + #shoulderViolations
    local ruleText = allowMail and "Leather/mail" or "Leather only"

    if totalViolations > 0 then
        local allowed = getAllowedViolations()
        local forgiven = math.min(allowed, #violations)
        local remaining = (#violations - forgiven) + #shoulderViolations
        if remaining <= 0 then
            return PASS, totalViolations .. " item"
                .. (totalViolations > 1 and "s" or "") .. " exempt ("
                .. allowed .. " allowed at current rank)"
        end
        local allViolations = {}
        for _, v in ipairs(shoulderViolations) do table.insert(allViolations, v) end
        for _, v in ipairs(violations) do table.insert(allViolations, v) end
        local detail = totalViolations .. " violation"
            .. (totalViolations > 1 and "s" or "") .. ": "
            .. table.concat(allViolations, ", ")
        if forgiven > 0 then
            detail = detail .. " (" .. forgiven .. " exempt, " .. remaining .. " over limit)"
        end
        return FAIL, detail
    end
    if totalViolations == 0 then
        local allowed = getAllowedViolations()
        if allowed > 0 then
            if allowMail then
                return PASS, "Wearing 0 plate gear despite having " .. allowed .. " exemption(s)."
            end
            if not allowMail then
                return PASS, "Wearing 0 mail gear despite having " .. allowed .. " exemption(s)."
            end
        end
    end
    if checked == 0 then
        return PASS, "No armor equipped"
    end

    local passText = allowMail and "leather or mail" or "leather"
    return PASS, "All " .. checked .. " armor pieces are " .. passText
end)

R("Cloth/leather", function()
    local state = getEquipSnapshot()
    local violations = {}
    local shoulderViolations = {}
    local checked = 0
    local level = UnitLevel("player")
    local allowLeather = (level >= 40)

    local checkSlots = {
        SLOT.HEAD, SLOT.SHOULDER, SLOT.CHEST, SLOT.WAIST,
        SLOT.LEGS, SLOT.FEET, SLOT.WRIST, SLOT.HANDS,
    }

    for _, sid in ipairs(checkSlots) do
        local item = state[sid]
        if item and item.classID == ARMOR_CLASS then
            checked = checked + 1
            local sub = item.subclassID
            local ok = (sub == ARMOR_SUB.CLOTH or sub == ARMOR_SUB.MISC)
            if allowLeather then
                ok = ok or (sub == ARMOR_SUB.LEATHER)
            end
            if not ok then
                local label
                if sub == ARMOR_SUB.CLOTH then label = "cloth"
                elseif sub == ARMOR_SUB.LEATHER then label = "leather"
                elseif sub == ARMOR_SUB.MAIL then label = "mail"
                elseif sub == ARMOR_SUB.PLATE then label = "plate"
                else label = "type " .. sub end
                local desc = item.name .. " (" .. label .. ")"
                if sid == SLOT.SHOULDER then
                    table.insert(shoulderViolations, desc)
                else
                    table.insert(violations, desc)
                end
            end
        end
    end

    local totalViolations = #violations + #shoulderViolations
    local ruleText = allowLeather and "Cloth/leather" or "Cloth only"

    if totalViolations > 0 then
        local allowed = getAllowedViolations()
        local forgiven = math.min(allowed, #violations)
        local remaining = (#violations - forgiven) + #shoulderViolations
        if remaining <= 0 then
            return PASS, totalViolations .. " item"
                .. (totalViolations > 1 and "s" or "") .. " exempt ("
                .. allowed .. " allowed at current rank)"
        end
        local allViolations = {}
        for _, v in ipairs(shoulderViolations) do table.insert(allViolations, v) end
        for _, v in ipairs(violations) do table.insert(allViolations, v) end
        local detail = totalViolations .. " violation"
            .. (totalViolations > 1 and "s" or "") .. ": "
            .. table.concat(allViolations, ", ")
        if forgiven > 0 then
            detail = detail .. " (" .. forgiven .. " exempt, " .. remaining .. " over limit)"
        end
        return FAIL, detail
    end
    if totalViolations == 0 then
        local allowed = getAllowedViolations()
        if allowed > 0 then
            if allowLeather then
                return PASS, "Wearing 0 mail gear despite having " .. allowed .. " exemption(s)."
            end
            if not allowLeather then
                return PASS, "Wearing 0 leather gear despite having " .. allowed .. " exemption(s)."
            end
        end
    end
    if checked == 0 then
        return PASS, "No armor equipped"
    end

    local passText = allowLeather and "cloth or leather" or "cloth"
    return PASS, "All " .. checked .. " armor pieces are " .. passText
end)

-- Mail/plate: must wear mail or plate in all armor slots where the
-- class can equip those types.  Paladin can wear mail 1–39, plate 40+.
-- Off-hand (shield) is excluded since shields are their own type.
R("Mail/plate", function()
    local state = getEquipSnapshot()
    local violations = {}
    local shoulderViolations = {}
    local checked = 0

    local checkSlots = {
        SLOT.HEAD, SLOT.SHOULDER, SLOT.CHEST, SLOT.WAIST,
        SLOT.LEGS, SLOT.FEET, SLOT.WRIST, SLOT.HANDS,
    }

    for _, sid in ipairs(checkSlots) do
        local item = state[sid]
        if item and item.classID == ARMOR_CLASS then
            checked = checked + 1
            local sub = item.subclassID
            if sub ~= ARMOR_SUB.MAIL and sub ~= ARMOR_SUB.PLATE then
                local label
                if sub == ARMOR_SUB.CLOTH then label = "cloth"
                elseif sub == ARMOR_SUB.LEATHER then label = "leather"
                else label = "type " .. sub end
                local desc = item.name .. " (" .. label .. ")"
                if sid == SLOT.SHOULDER then
                    table.insert(shoulderViolations, desc)
                else
                    table.insert(violations, desc)
                end
            end
        end
    end

    local totalViolations = #violations + #shoulderViolations
    if totalViolations > 0 then
        local allowed = getAllowedViolations()
        local forgiven = math.min(allowed, #violations)
        local remaining = (#violations - forgiven) + #shoulderViolations
        if remaining <= 0 then
            return PASS, totalViolations .. " item"
                .. (totalViolations > 1 and "s" or "") .. " exempt ("
                .. allowed .. " allowed at current rank)"
        end
        local allViolations = {}
        for _, v in ipairs(shoulderViolations) do table.insert(allViolations, v) end
        for _, v in ipairs(violations) do table.insert(allViolations, v) end
        local detail = "Mail/plate only — " .. totalViolations .. " violation"
            .. (totalViolations > 1 and "s" or "") .. ": "
            .. table.concat(allViolations, ", ")
        if forgiven > 0 then
            detail = detail .. " (" .. forgiven .. " exempt, " .. remaining .. " over limit)"
        end
        return FAIL, detail
    end
    if totalViolations == 0 then
        local allowed = getAllowedViolations()
        if allowed > 0 then
            return PASS, "Wearing 0 cloth/leather gear despite having " .. allowed .. " exemption(s)."
        end
    end
    if checked == 0 then
        -- No armor equipped — technically not violating, but warn
        return UNCHECKED, "No armor equipped to verify"
    end

    return PASS, "All " .. checked .. " armor pieces are mail or plate"
end)

----------------------------------------------------------------------
-- PROFESSION-BASED CHALLENGES
----------------------------------------------------------------------

-- No professions: cannot learn any professions.  We piggyback on
-- ProfessionCheck's spell-ID detection.
R("No nonsense", function()
    -- Use IsSpellKnown with the same profession spell IDs from ProfessionCheck
    local PROF_SPELLS = {
        { name = "Alchemy",        id = 2259 },
        { name = "Blacksmithing",  id = 2018 },
        { name = "Enchanting",     id = 7411 },
        { name = "Engineering",    id = 4036 },
        { name = "Herbalism",      id = 2366 },
        { name = "Leatherworking", id = 2108 },
        { name = "Mining",         id = 2575 },
        { name = "Skinning",       id = 8613 },
        { name = "Tailoring",      id = 3908 },
        { name = "Cooking",        id = 2550 },
        { name = "First Aid",      id = 3273 },
        { name = "Fishing",        id = 7620 },
    }

    local learned = {}
    for _, prof in ipairs(PROF_SPELLS) do
        if IsSpellKnown and IsSpellKnown(prof.id) then
            table.insert(learned, prof.name)
        end
    end

    if #learned > 0 then
        return FAIL, "Learned " .. #learned .. " profession"
            .. (#learned > 1 and "s" or "") .. ": "
            .. table.concat(learned, ", ")
    end

    return PASS, "No professions learned"
end)

----------------------------------------------------------------------
-- PET / DEMON CHALLENGES
----------------------------------------------------------------------

-- Imp: must always use the Imp as your demon pet.
-- We check if the warlock has an active pet and whether it's an Imp.
-- In Classic, warlock demons each have a creature family that we can
-- detect.  The Imp's creature family is "Imp" and its creature type
-- is "Demon".  We use UnitCreatureFamily("pet").
R("Imp", function()
    -- Only relevant for warlocks, but the rule engine doesn't filter by
    -- class — if someone assigns this challenge to a non-warlock, it'll
    -- just pass trivially.
    local _, classToken = UnitClass("player")
    if classToken ~= "WARLOCK" then
        return PASS, "Not a warlock — Imp rule not applicable"
    end

    -- Is a pet active?
    if not UnitExists("pet") then
        return PASS, "No pet summoned (OK — rule applies when a pet is active)"
    end

    -- Check if the pet is an Imp.  UnitCreatureFamily returns the
    -- family name (locale-dependent).  For locale safety we also check
    -- creature type and the pet's name.
    local family = UnitCreatureFamily("pet") or ""
    -- In English: "Imp".  We do a case-insensitive check.
    if family:lower() == "imp" then
        return PASS, "Imp is summoned"
    end

    -- Fallback: check the pet spell name.  Warlock demon spells in Classic:
    --   Imp:       spell 688
    --   Voidwalker: spell 697
    --   Succubus:  spell 712
    --   Felhunter: spell 691
    -- If the player knows these spells, we can check which pet is out
    -- by comparing the pet's name to the spell's summoned creature name.
    -- For now the family check is our best approach.

    local petName = UnitName("pet") or "unknown"
    return FAIL, "Active pet is not an Imp — pet: " .. petName .. " (" .. family .. ")"
end)

R("Voidwalker", function()
    -- Only relevant for warlocks, but the rule engine doesn't filter by
    -- class — if someone assigns this challenge to a non-warlock, it'll
    -- just pass trivially.
    local _, classToken = UnitClass("player")
    if classToken ~= "WARLOCK" then
        return PASS, "Not a warlock — Imp rule not applicable"
    end

    -- Is a pet active?
    if not UnitExists("pet") then
        return PASS, "No pet summoned (OK — rule applies when a pet is active)"
    end

    -- Check if the pet is an Imp.  UnitCreatureFamily returns the
    -- family name (locale-dependent).  For locale safety we also check
    -- creature type and the pet's name.
    local family = UnitCreatureFamily("pet") or ""
    -- In English: "Imp".  We do a case-insensitive check.
    if family:lower() == "voidwalker" then
        return PASS, "Voidwalker is summoned"
    end

    -- Fallback: check the pet spell name.  Warlock demon spells in Classic:
    --   Imp:       spell 688
    --   Voidwalker: spell 697
    --   Succubus:  spell 712
    --   Felhunter: spell 691
    -- If the player knows these spells, we can check which pet is out
    -- by comparing the pet's name to the spell's summoned creature name.
    -- For now the family check is our best approach.

    local petName = UnitName("pet") or "unknown"
    return FAIL, "Active pet is not an Voidwalker — pet: " .. petName .. " (" .. family .. ")"
end)

----------------------------------------------------------------------
-- ITEM-SOURCE CHALLENGES
--
-- These challenges restrict WHERE the player's gear comes from.
-- Item source data is auto-generated from Wowhead Classic and lives
-- in ItemSourceData.lua (quest rewards, vendor items, crafted items,
-- and loot drops — all four source types).
--
-- Design:
--   Scavenger      → deny-list (quest_rewards is a blocklist)
--   Off-the-shelf → allow-list (vendor_items is an allowlist)
--   Partisan      → deny-list (looted_gear is a blocklist)
--
-- Quality 0–1 (white/grey) items auto-pass all source checks.
----------------------------------------------------------------------

--- Count entries in a table.
local function tblCount(tbl)
    if not tbl then return 0 end
    local n = 0
    for _ in pairs(tbl) do n = n + 1 end
    return n
end

-- Scavenger: cannot equip quest reward gear.
-- Deny-list: if the item appears on quest_rewards, it's forbidden.
-- White/grey auto-passes.
R("Scavenger", function()
    local list = FCE.CuratedItems and FCE.CuratedItems.quest_rewards
    if not list or tblCount(list) == 0 then
        return UNCHECKED, "Quest-reward item list not loaded"
    end

    local state = getEquipSnapshot()
    local violations = {}
    local checked = 0

    for _, sid in ipairs(GEAR_SLOTS) do
        local item = state[sid]
        if item then
            checked = checked + 1
            if item.quality >= 2 and list[item.id] then
                table.insert(violations, item.name)
            end
        end
    end

    if #violations > 0 then
        local allowed = getAllowedViolations()
        if #violations <= allowed then
            return PASS, #violations .. " quest reward item" .. (#violations > 1 and "s" or "")
                .. " exempt (" .. allowed .. " allowed at current rank)"
        end
        local detail = "Quest reward gear equipped: " .. table.concat(violations, ", ")
        if allowed > 0 then
            detail = detail .. " (" .. allowed .. " exempt, " .. (#violations - allowed) .. " over limit)"
        end
        return FAIL, detail
    end
    if checked == 0 then
        return PASS, "No gear equipped"
    end
    if #violations == 0 then
        local allowed = getAllowedViolations()
        if allowed > 0 then
            return PASS, "Wearing 0 quest reward gear despite having " .. allowed .. " exemption(s)."
        end
    end
    return PASS, "No quest reward gear equipped (" .. checked .. " items verified)"
end)

-- Partisan: cannot equip looted (mob drop) gear.
-- Deny-list approach: green+ items on the looted_gear list → FAIL.
-- White/grey auto-passes.
R("Partisan", function()
    local list = FCE.CuratedItems and FCE.CuratedItems.looted_gear
    if not list or not next(list) then
        return UNCHECKED, "Loot-drop item list not loaded"
    end

    local state = getEquipSnapshot()
    local violations = {}
    local checked = 0

    for _, sid in ipairs(GEAR_SLOTS) do
        local item = state[sid]
        if item then
            checked = checked + 1
            if item.quality >= 2 and list[item.id] then
                table.insert(violations, item.name)
            end
        end
    end

    if #violations > 0 then
        local allowed = getAllowedViolations()
        if #violations <= allowed then
            return PASS, #violations .. " looted item" .. (#violations > 1 and "s" or "")
                .. " exempt (" .. allowed .. " allowed at current rank)"
        end
        local detail = "Looted gear equipped: " .. table.concat(violations, ", ")
        if allowed > 0 then
            detail = detail .. " (" .. allowed .. " exempt, " .. (#violations - allowed) .. " over limit)"
        end
        return FAIL, detail
    end
    if checked == 0 then
        return PASS, "No gear equipped"
    end
    if #violations == 0 then
        local allowed = getAllowedViolations()
        if allowed > 0 then
            return PASS, "Wearing 0 looted gear despite having " .. allowed .. " exemption(s)."
        end
    end
    return PASS, "No looted gear equipped (" .. checked .. " items checked)"
end)

R("Expeditionary", function()
    local list = FCE.CuratedItems and FCE.CuratedItems.groupQuestRewardItems
    if not list or not next(list) then
        return UNCHECKED, "Curated item list not loaded"
    end

    local state = getEquipSnapshot()
    local violations = {}
    local checked = 0

    for _, sid in ipairs(GEAR_SLOTS) do
        local item = state[sid]
        if item then
            checked = checked + 1
            if item.quality >= 2 and not list[item.id] then
                table.insert(violations, item.name)
            end
        end
    end

    if #violations > 0 then
        local allowed = getAllowedViolations()
        if #violations <= allowed then
            return PASS, #violations .. " non-group item" .. (#violations > 1 and "s" or "")
                .. " exempt (" .. allowed .. " allowed at current rank)"
        end
        local detail = "Non-group gear equipped: " .. table.concat(violations, ", ")
        if allowed > 0 then
            detail = detail .. " (" .. allowed .. " exempt, " .. (#violations - allowed) .. " over limit)"
        end
        return FAIL, detail
    end
    if checked == 0 then
        return PASS, "No gear equipped"
    end
    if #violations == 0 then
        local allowed = getAllowedViolations()
        if allowed > 0 then
            return PASS, "Wearing only group gear despite having " .. allowed .. " exemption(s)."
        end
    end
    return PASS, "All equipped gear is from group content (" .. checked .. " items checked)"
end)

-- Off-the-shelf: can only equip gear sold by vendors.
-- Allow-list: green+ items must appear on vendor_items.
-- White/grey auto-passes (basic vendor gear).
R("Off-the-shelf", function()
    local list = FCE.CuratedItems and FCE.CuratedItems.vendor_items
    if not list or tblCount(list) == 0 then
        return UNCHECKED, "Vendor-item list not loaded"
    end

    local state = getEquipSnapshot()
    local violations = {}
    local checked = 0

    for _, sid in ipairs(GEAR_SLOTS) do
        local item = state[sid]
        if item then
            checked = checked + 1
            if item.quality >= 2 and not list[item.id] then
                table.insert(violations, item.name)
            end
        end
    end

    if #violations > 0 then
        return FAIL, "Non-vendor gear equipped: " .. table.concat(violations, ", ")
    end
    if checked == 0 then
        return PASS, "No gear equipped"
    end
    return PASS, "All " .. checked .. " items are vendor-sourced"
end)

----------------------------------------------------------------------
-- ZONE-BASED CHALLENGES (powered by ZoneCheck.lua)
----------------------------------------------------------------------

-- Homebound: can't leave home continent.
-- Uses ZoneCheck.lua for C_Map continent detection + persistent
-- violation tracking.
R("Homebound", function()
    if not FCE.ZoneCheck or not FCE.ZoneCheck.CheckHomebound then
        return UNCHECKED, "Zone tracking module not loaded"
    end
    return FCE.ZoneCheck.CheckHomebound()
end)

-- Explorer: world exploration % scales with level (65% at 60).
-- ExplorerCheck.lua reads fog-of-war state via C_MapExplorationInfo.
R("Explorer", function()
    if not FCE.ExplorerCheck or not FCE.ExplorerCheck.CheckExplorer then
        return UNCHECKED, "Explorer module not loaded"
    end
    return FCE.ExplorerCheck.CheckExplorer()
end)

-- Zone-visit challenges: these are thematic gameplay suggestions rather
-- than hard pass/fail rules.  They report how many of the suggested
-- zones the player has visited.  Currently no characters have these as
-- formal challenge entries (they appear in gameplay tips), but we
-- register rules so the engine has full coverage.

local function zoneVisitChecker(listName, label)
    return function()
        if not FCE.ZoneCheck or not FCE.ZoneCheck.GetZoneProgress then
            return UNCHECKED, "Zone tracking module not loaded"
        end
        local count, total, visited, unvisited = FCE.ZoneCheck.GetZoneProgress(listName)
        if total == 0 then
            return UNCHECKED, "No zone list defined for " .. label
        end
        if count == total then
            return PASS, "Visited all " .. total .. " " .. label .. " zones: "
                .. table.concat(visited, ", ")
        end
        local detail = count .. "/" .. total .. " zones visited"
        if #visited > 0 then
            detail = detail .. " — visited: " .. table.concat(visited, ", ")
        end
        if #unvisited > 0 then
            detail = detail .. " — remaining: " .. table.concat(unvisited, ", ")
        end
        -- These are aspirational, not restrictive — use UNCHECKED so the
        -- panel shows ? instead of ✗ when incomplete.
        return UNCHECKED, detail
    end
end

R("Anti-undead", zoneVisitChecker("Anti-undead", "anti-undead"))
R("Pro-nature",  zoneVisitChecker("Pro-nature",  "pro-nature"))
R("Anti-demon",  zoneVisitChecker("Anti-demon",  "anti-demon"))
R("Aoe-farmer",  zoneVisitChecker("Aoe-farmer",  "AoE farmer"))

----------------------------------------------------------------------
-- BEHAVIORAL CHALLENGES (powered by BehavioralCheck.lua)
----------------------------------------------------------------------

-- Drifter: cannot use hearthstone or bank.
-- BehavioralCheck.lua hooks BANKFRAME_OPENED and UNIT_SPELLCAST_SENT
-- for hearthstone detection.  Violations are persistent in saved vars.
R("Drifter", function()
    if not FCE.BehavioralCheck or not FCE.BehavioralCheck.CheckDrifter then
        return UNCHECKED, "Behavioral tracking module not loaded"
    end
    return FCE.BehavioralCheck.CheckDrifter()
end)

-- Ephemeral: cannot repair gear.
-- BehavioralCheck.lua hooks MERCHANT_SHOW/MERCHANT_CLOSED and
-- UPDATE_INVENTORY_DURABILITY to detect repair actions via durability
-- comparison.
R("Ephemeral", function()
    if not FCE.BehavioralCheck or not FCE.BehavioralCheck.CheckEphemeral then
        return UNCHECKED, "Behavioral tracking module not loaded"
    end
    return FCE.BehavioralCheck.CheckEphemeral()
end)

----------------------------------------------------------------------
-- TIME-OF-DAY CHALLENGES
----------------------------------------------------------------------

-- Towns and cities list for Nocturnal/Diurnal checks.
-- Matches against GetZoneText() and GetSubZoneText().
local TOWNS_AND_CITIES = {
    -- Alliance capitals
    ["Stormwind City"]      = true,
    ["Ironforge"]           = true,
    ["Darnassus"]           = true,
    ["Moonglade"]           = true,
    -- Horde capitals
    ["Orgrimmar"]           = true,
    ["Thunder Bluff"]       = true,
    ["Undercity"]           = true,
    -- Neutral cities
    ["Gadgetzan"]           = true,
    ["Booty Bay"]           = true,
    ["Ratchet"]             = true,
    ["Everlook"]            = true,
    ["Cenarion Hold"]       = true,
    ["Light's Hope Chapel"] = true,
    -- Alliance towns
    ["Goldshire"]           = true,
    ["Lakeshire"]           = true,
    ["Sentinel Hill"]       = true,
    ["Southshore"]          = true,
    ["Menethil Harbor"]     = true,
    ["Thelsamar"]           = true,
    ["Kharanos"]            = true,
    ["Darkshire"]           = true,
    ["Nethergarde Keep"]    = true,
    ["Refuge Pointe"]       = true,
    ["Aerie Peak"]          = true,
    ["Nijel's Point"]       = true,
    ["Feathermoon Stronghold"] = true,
    ["Theramore"]           = true,
    ["Astranaar"]           = true,
    ["Auberdine"]           = true,
    ["Dolanaar"]            = true,
    ["Stonetalon Peak"]     = true,
    ["Morgan's Vigil"]      = true,
    ["Chillwind Camp"]      = true,
    -- Horde towns
    ["Razor Hill"]          = true,
    ["Crossroads"]          = true,
    ["Camp Taurajo"]        = true,
    ["Tarren Mill"]         = true,
    ["Brill"]               = true,
    ["The Sepulcher"]       = true,
    ["Hammerfall"]          = true,
    ["Kargath"]             = true,
    ["Stonard"]             = true,
    ["Grom'gol Base Camp"]  = true,
    ["Brackenwall Village"] = true,
    ["Sun Rock Retreat"]    = true,
    ["Freewind Post"]       = true,
    ["Camp Mojache"]        = true,
    ["Shadowprey Village"]  = true,
    ["Splintertree Post"]   = true,
    ["Bloodvenom Post"]     = true,
    ["Valormok"]            = true,
    ["Revantusk Village"]   = true,
    ["Flame Crest"]         = true,
    ["Bulwark"]             = true,
    ["Sen'jin Village"]     = true,
    ["Zoram'gar Outpost"]   = true,
    ["Nighthaven"]          = true,
    -- Named inns (subzone text when inside the building)
    ["Lion's Pride Inn"]        = true,
    ["The Gilded Rose"]         = true,
    ["Stonefire Tavern"]        = true,
    ["Thunderbrew Distillery"]  = true,
    ["Stoutlager Inn"]          = true,
    ["Deepwater Tavern"]        = true,
    ["Scarlet Raven Tavern"]    = true,
    ["Gallows' End Tavern"]     = true,
    ["Salty Sailor Tavern"]     = true,
    ["The Broken Tusk"]         = true,
    ["Brill Town Hall"]         = true,
    ["Lakeshire Town Hall"]         = true,
}

local function isInTown()
    local zone = GetZoneText() or ""
    local subzone = GetSubZoneText() or ""
    return TOWNS_AND_CITIES[zone] or TOWNS_AND_CITIES[subzone]
end

-- Nocturnal: must remain in towns during daytime.
-- Night = server hours 21:00–05:59, Day = 06:00–20:59.
R("Nocturnal", function()
    if UnitOnTaxi("player") then
        return PASS, "On flight path — exempt"
    end
    local hour = GetGameTime()
    local isDay = (hour >= 6 and hour < 21)

    if not isDay then
        return PASS, "Nighttime (19:00 - 6:00) — free to roam"
    end
    -- Daytime: must be in a town or city
    if isInTown() then
        return PASS, "Daytime, in town — good"
    end
    return FAIL, "Daytime (06:00 - 19:00) and not in a town — must remain in town during the day"
end)

-- Diurnal: must remain in towns/cities during nighttime.
-- Opposite of Nocturnal.
R("Diurnal", function()
    if UnitOnTaxi("player") then
        return PASS, "On flight path — exempt"
    end
    local hour = GetGameTime()
    local isNight = (hour >= 21 or hour < 6)

    if not isNight then
        return PASS, "Daytime (06:00 - 19:00) — free to roam"
    end
    -- Nighttime: must be in a town or city
    if isInTown() then
        return PASS, "Nighttime, in town — good"
    end
    return FAIL, "Nighttime (19:00 - 6:00) and not in a town — must remain in town at night"
end)

----------------------------------------------------------------------
-- PET / COMPANION CHALLENGES (stubs until Milestone 6)
----------------------------------------------------------------------

-- Mortal pets: hunter pets that die stay dead.
-- BehavioralCheck.lua hooks UNIT_SPELLCAST_SENT to detect Revive Pet
-- casts (spell ID 982).  This is an honour-system rule — the addon
-- warns but cannot prevent the revive.
R("Mortal pets", function()
    if not FCE.BehavioralCheck or not FCE.BehavioralCheck.CheckMortalPets then
        local _, classToken = UnitClass("player")
        if classToken ~= "HUNTER" then
            return PASS, "Not a hunter — mortal pets rule not applicable"
        end
        return UNCHECKED, "Behavioral tracking module not loaded"
    end
    return FCE.BehavioralCheck.CheckMortalPets()
end)

----------------------------------------------------------------------
-- SPELL RESTRICTION CHALLENGES
----------------------------------------------------------------------

-- Pyromancer: no frost spells (Bloodmage)
R("Pyromancer", function()
    if not FCE.BehavioralCheck or not FCE.BehavioralCheck.CheckSpellRestriction then
        local _, classToken = UnitClass("player")
        if classToken ~= "MAGE" then
            return PASS, "Not a mage — Pyromancer rule not applicable"
        end
        return UNCHECKED, "Behavioral tracking module not loaded"
    end
    return FCE.BehavioralCheck.CheckSpellRestriction("Pyromancer")
end)

R("Cryomancer", function()
    if not FCE.BehavioralCheck or not FCE.BehavioralCheck.CheckSpellRestriction then
        local _, classToken = UnitClass("player")
        if classToken ~= "MAGE" then
            return PASS, "Not a mage — Cryomancer rule not applicable"
        end
        return UNCHECKED, "Behavioral tracking module not loaded"
    end
    return FCE.BehavioralCheck.CheckSpellRestriction("Cryomancer")
end)

-- Light of Elune: no shadow spells (Priestess of the Moon)
R("Light of Elune", function()
    if not FCE.BehavioralCheck or not FCE.BehavioralCheck.CheckSpellRestriction then
        local _, classToken = UnitClass("player")
        if classToken ~= "PRIEST" then
            return PASS, "Not a priest — Light of Elune rule not applicable"
        end
        return UNCHECKED, "Behavioral tracking module not loaded"
    end
    return FCE.BehavioralCheck.CheckSpellRestriction("Light of Elune")
end)

R("All-out Assault", function()
    if not FCE.BehavioralCheck or not FCE.BehavioralCheck.CheckSpellRestriction then
        local _, classToken = UnitClass("player")
        if classToken ~= "WARRIOR" then
            return PASS, "Not a warrior — All-out Assault rule not applicable"
        end
        return UNCHECKED, "Behavioral tracking module not loaded"
    end
    return FCE.BehavioralCheck.CheckSpellRestriction("All-out Assault")
end)

R("Truecaster", function()
    if not FCE.BehavioralCheck or not FCE.BehavioralCheck.CheckSpellRestriction then
        local _, classToken = UnitClass("player")
        if classToken ~= "DRUID" then
            return PASS, "Not a druid — Truecaster rule not applicable"
        end
        return UNCHECKED, "Behavioral tracking module not loaded"
    end
    return FCE.BehavioralCheck.CheckSpellRestriction("Truecaster")
end)

R("Windfury Weapon", function()
    if not FCE.BehavioralCheck or not FCE.BehavioralCheck.CheckSpellRestriction then
        local _, classToken = UnitClass("player")
        if classToken ~= "SHAMAN" then
            return PASS, "Not a shaman — Windfury Weapon rule not applicable"
        end
        return UNCHECKED, "Behavioral tracking module not loaded"
    end
    return FCE.BehavioralCheck.CheckSpellRestriction("Windfury Weapon")
end)

R("Master of Fire", function()
    if not FCE.BehavioralCheck or not FCE.BehavioralCheck.CheckSpellRestriction then
        local _, classToken = UnitClass("player")
        if classToken ~= "SHAMAN" then
            return PASS, "Not a shaman — Master of Fire rule not applicable"
        end
        return UNCHECKED, "Behavioral tracking module not loaded"
    end
    return FCE.BehavioralCheck.CheckSpellRestriction("Master of Fire")
end)

R("Master of Water", function()
    if not FCE.BehavioralCheck or not FCE.BehavioralCheck.CheckSpellRestriction then
        local _, classToken = UnitClass("player")
        if classToken ~= "SHAMAN" then
            return PASS, "Not a shaman — Master of Water rule not applicable"
        end
        return UNCHECKED, "Behavioral tracking module not loaded"
    end
    return FCE.BehavioralCheck.CheckSpellRestriction("Master of Water")
end)

R("Master of Water", function()
    if not FCE.BehavioralCheck or not FCE.BehavioralCheck.CheckSpellRestriction then
        local _, classToken = UnitClass("player")
        if classToken ~= "SHAMAN" then
            return PASS, "Not a shaman — Master of Water rule not applicable"
        end
        return UNCHECKED, "Behavioral tracking module not loaded"
    end
    return FCE.BehavioralCheck.CheckSpellRestriction("Master of Water")
end)

R("Lockdown", function()
    if not FCE.BehavioralCheck or not FCE.BehavioralCheck.CheckSpellRestriction then
        local _, classToken = UnitClass("player")
        if classToken ~= "ROGUE" then
            return PASS, "Not a rogue — Lockdown rule not applicable"
        end
        return UNCHECKED, "Behavioral tracking module not loaded"
    end
    return FCE.BehavioralCheck.CheckSpellRestriction("Lockdown")
end)

R("Spirit of Ursol", function()
    if not FCE.BehavioralCheck or not FCE.BehavioralCheck.CheckSpellRestriction then
        local _, classToken = UnitClass("player")
        if classToken ~= "DRUID" then
            return PASS, "Not a druid — Spirit of Ursol rule not applicable"
        end
        return UNCHECKED, "Behavioral tracking module not loaded"
    end
    return FCE.BehavioralCheck.CheckSpellRestriction("Spirit of Ursol")
end)

R("Spirit of Aviana", function()
    if not FCE.BehavioralCheck or not FCE.BehavioralCheck.CheckSpellRestriction then
        local _, classToken = UnitClass("player")
        if classToken ~= "DRUID" then
            return PASS, "Not a druid — Spirit of Aviana rule not applicable"
        end
        return UNCHECKED, "Behavioral tracking module not loaded"
    end
    return FCE.BehavioralCheck.CheckSpellRestriction("Spirit of Aviana")
end)

R("Spirit of Ashamane", function()
    if not FCE.BehavioralCheck or not FCE.BehavioralCheck.CheckSpellRestriction then
        local _, classToken = UnitClass("player")
        if classToken ~= "DRUID" then
            return PASS, "Not a druid — Spirit of Ashamane rule not applicable"
        end
        return UNCHECKED, "Behavioral tracking module not loaded"
    end
    return FCE.BehavioralCheck.CheckSpellRestriction("Spirit of Ashamane")
end)

R("Retribution Aura", function()
    if not FCE.BehavioralCheck or not FCE.BehavioralCheck.CheckSpellRestriction then
        local _, classToken = UnitClass("player")
        if classToken ~= "DRUID" then
            return PASS, "Not a druid — Retribution Aura rule not applicable"
        end
        return UNCHECKED, "Behavioral tracking module not loaded"
    end
    return FCE.BehavioralCheck.CheckSpellRestriction("Retribution Aura")
end)

R("Rockbiter Weapon", function()
    if not FCE.BehavioralCheck or not FCE.BehavioralCheck.CheckSpellRestriction then
        local _, classToken = UnitClass("player")
        if classToken ~= "SHAMAN" then
            return PASS, "Not a shaman — Rockbiter Weapon rule not applicable"
        end
        return UNCHECKED, "Behavioral tracking module not loaded"
    end
    return FCE.BehavioralCheck.CheckSpellRestriction("Rockbiter Weapon")
end)

R("Crude", function()
    if not FCE.BehavioralCheck or not FCE.BehavioralCheck.CheckSpellRestriction then
        local _, classToken = UnitClass("player")
        if classToken ~= "ROGUE" then
            return PASS, "Not a rogue — Crude rule not applicable"
        end
        return UNCHECKED, "Behavioral tracking module not loaded"
    end
    return FCE.BehavioralCheck.CheckSpellRestriction("Crude")
end)

R("Overt", function()
    if not FCE.BehavioralCheck or not FCE.BehavioralCheck.CheckSpellRestriction then
        local _, classToken = UnitClass("player")
        if classToken ~= "ROGUE" then
            return PASS, "Not a rogue — Overt rule not applicable"
        end
        return UNCHECKED, "Behavioral tracking module not loaded"
    end
    return FCE.BehavioralCheck.CheckSpellRestriction("Overt")
end)

R("Firemancer", function()
    if not FCE.BehavioralCheck or not FCE.BehavioralCheck.CheckSpellRestriction then
        local _, classToken = UnitClass("player")
        if classToken ~= "WARLOCK" then
            return PASS, "Not a warlock — Firemancer rule not applicable"
        end
        return UNCHECKED, "Behavioral tracking module not loaded"
    end
    return FCE.BehavioralCheck.CheckSpellRestriction("Firemancer")
end)

R("No demons", function()
    if not FCE.BehavioralCheck or not FCE.BehavioralCheck.CheckSpellRestriction then
        local _, classToken = UnitClass("player")
        if classToken ~= "WARLOCK" then
            return PASS, "Not a warlock — No demons rule not applicable"
        end
        return UNCHECKED, "Behavioral tracking module not loaded"
    end
    return FCE.BehavioralCheck.CheckSpellRestriction("No demons")
end)

R("Lone Wolf", function()
    if not FCE.BehavioralCheck or not FCE.BehavioralCheck.CheckSpellRestriction then
        local _, classToken = UnitClass("player")
        if classToken ~= "HUNTER" then
            return PASS, "Not a hunter — No pet rule not applicable"
        end
        return UNCHECKED, "Behavioral tracking module not loaded"
    end
    return FCE.BehavioralCheck.CheckSpellRestriction("Lone Wolf")
end)

R("Agnostic", function()
    if FCE.EventChallenges and FCE.EventChallenges.CheckAgnostic then
        return FCE.EventChallenges.CheckAgnostic()
    end
    local _, classToken = UnitClass("player")
    if classToken ~= "PALADIN" then
        return PASS, "Not a paladin — Agnostic rule not applicable"
    end
    return UNCHECKED, "Event challenge module not loaded"
end)

R("Shadow Ascendant", function()
    if not FCE.BehavioralCheck or not FCE.BehavioralCheck.CheckSpellRestriction then
        local _, classToken = UnitClass("player")
        if classToken ~= "PRIEST" then
            return PASS, "Not a priest — Shadow Ascendant rule not applicable"
        end
        return UNCHECKED, "Behavioral tracking module not loaded"
    end
    return FCE.BehavioralCheck.CheckSpellRestriction("Shadow Ascendant")
end)

R("Self-taught", function()
    if not FCE.BehavioralCheck or not FCE.BehavioralCheck.CheckSpellRestriction then
        local _, classToken = UnitClass("player")
        if classToken ~= "MAGE" then
            return PASS, "Not a mage — Self-taught rule not applicable"
        end
        return UNCHECKED, "Behavioral tracking module not loaded"
    end
    return FCE.BehavioralCheck.CheckSpellRestriction("Self-taught")
end)

----------------------------------------------------------------------
-- REPUTATION-BASED CHALLENGES
----------------------------------------------------------------------

local HOME_FACTION = {
    ["Human"]    = "Stormwind",
    ["Dwarf"]    = "Ironforge",
    ["NightElf"] = "Darnassus",
    ["Gnome"]    = "Gnomeregan Exiles",
    ["Orc"]      = "Orgrimmar",
    ["Undead"]   = "Undercity",
    ["Scourge"]  = "Undercity",
    ["Tauren"]   = "Thunder Bluff",
    ["Troll"]    = "Darkspear Trolls",
}

local function getStandingForFaction(factionName)
    for i = 1, GetNumFactions() do
        local name, _, standingId = GetFactionInfo(i)
        if name and name == factionName then
            return standingId, name
        end
    end
    return nil, factionName
end

-- Faction Loyalist: maintain standing with your home faction that scales with level.
--   Friendly by lv20, Honored by lv40, Revered by lv55, Exalted by lv60.
R("Faction Loyalist", function()
    local _, raceKey = UnitRace("player")
    local targetFaction = HOME_FACTION[raceKey]
    if not targetFaction then
        return UNCHECKED, "Unknown race: " .. tostring(raceKey)
    end

    local standing = getStandingForFaction(targetFaction)
    if not standing then
        return UNCHECKED, targetFaction .. " not found in reputation panel"
    end

    local playerLevel = UnitLevel("player")
    local standingNames = { "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" }
    local standingLabel = standingNames[standing] or "?"

    -- Determine required standing for current level
    local FRIENDLY = 5
    local HONORED  = 6
    local REVERED  = 7
    local EXALTED  = 8

    local requiredStanding, requiredLabel
    if playerLevel >= 50 then
        requiredStanding = REVERED
        requiredLabel = "Revered"
    elseif playerLevel >= 25 then
        requiredStanding = HONORED
        requiredLabel = "Honored"
    else
        requiredStanding = FRIENDLY
        requiredLabel = "Friendly"
    end

    if standing >= requiredStanding then
        return PASS, standingLabel .. " with " .. targetFaction
    end

    return FAIL, standingLabel .. " with " .. targetFaction .. " (need " .. requiredLabel .. " by lv" .. playerLevel .. ")"
end)

-- Purifier: reach Honored with Argent Dawn.
R("Purifier", function()
    local standing = getStandingForFaction("Argent Dawn")
    if not standing then
        return UNCHECKED, "Argent Dawn not found in reputation panel"
    end

    local HONORED = 6
    local standingNames = { "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" }
    local standingLabel = standingNames[standing] or "?"

    if standing >= HONORED then
        return PASS, standingLabel .. " with Argent Dawn"
    end

    return FAIL, standingLabel .. " with Argent Dawn (need Honored)"
end)

R("Keeper", function()
    local standing = getStandingForFaction("Cenarion Circle")
    if not standing then
        return UNCHECKED, "Cenarion Circle not found in reputation panel"
    end

    local HONORED = 6
    local standingNames = { "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" }
    local standingLabel = standingNames[standing] or "?"

    if standing >= HONORED then
        return PASS, standingLabel .. " with Cenarion Circle"
    end

    return FAIL, standingLabel .. " with Cenarion Circle (need Honored)"
end)

R("Smith", function()
    local standing = getStandingForFaction("Thorium Brotherhood")
    if not standing then
        return UNCHECKED, "Thorium Brotherhood not found in reputation panel"
    end

    local HONORED = 6
    local standingNames = { "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" }
    local standingLabel = standingNames[standing] or "?"

    if standing >= HONORED then
        return PASS, standingLabel .. " with Thorium Brotherhood"
    end

    return FAIL, standingLabel .. " with Thorium Brotherhood (need Honored)"
end)

R("Avenger", function()
    local standing = getStandingForFaction("Zandalar Tribe")
    if not standing then
        return UNCHECKED, "Zandalar Tribe not found in reputation panel"
    end

    local Friendly = 5
    local standingNames = { "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" }
    local standingLabel = standingNames[standing] or "?"

    if standing >= Friendly then
        return PASS, standingLabel .. " with Zandalar Tribe"
    end

    return FAIL, standingLabel .. " with Zandalar Tribe (need Friendly)"
end)

R("Cult of the Damned", function()
    local factionName = "Argent Dawn"
    for i = 1, GetNumFactions() do
        local name, _, standingID, _, _, _, atWarWith, canToggleAtWar = GetFactionInfo(i)
        if name == factionName then
            if atWarWith then
                local standing = getStandingForFaction("Argent Dawn")
                if not standing then
                    return UNCHECKED, "Argent Dawn not found in reputation panel"
                end

                local HOSTILE = 2
                local standingNames = { "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" }
                local standingLabel = standingNames[standing] or "?"

                if standing <= HOSTILE then
                    return PASS, standingLabel .. " with Argent Dawn"
                end

                return FAIL, standingLabel .. " with Argent Dawn (need Hostile)"
            else
                return FAIL, "Not At War with " .. factionName
            end
        end
    end
    return UNCHECKED, factionName .. " not found in reputation panel"
end)

R("Twilight's Hammer", function()
    local factionName = "Cenarion Circle"
    for i = 1, GetNumFactions() do
        local name, _, standingID, _, _, _, atWarWith, canToggleAtWar = GetFactionInfo(i)
        if name == factionName then
            if atWarWith then
                local standing = getStandingForFaction("Cenarion Circle")
                if not standing then
                    return UNCHECKED, "Cenarion Circle not found in reputation panel"
                end

                local HOSTILE = 2
                local standingNames = { "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" }
                local standingLabel = standingNames[standing] or "?"

                if standing <= HOSTILE then
                    return PASS, standingLabel .. " with Cenarion Circle"
                end

                return FAIL, standingLabel .. " with Cenarion Circle (need Hostile)"
            else
                return FAIL, "Not At War with " .. factionName
            end
        end
    end
    return UNCHECKED, factionName .. " not found in reputation panel"
end)

R("Shadow Council", function()
    local factionName = "Cenarion Circle"
    for i = 1, GetNumFactions() do
        local name, _, standingID, _, _, _, atWarWith, canToggleAtWar = GetFactionInfo(i)
        if name == factionName then
            if atWarWith then
                local standing = getStandingForFaction("Cenarion Circle")
                if not standing then
                    return UNCHECKED, "Cenarion Circle not found in reputation panel"
                end

                local HOSTILE = 2
                local standingNames = { "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" }
                local standingLabel = standingNames[standing] or "?"

                if standing <= HOSTILE then
                    return PASS, standingLabel .. " with Cenarion Circle"
                end

                return FAIL, standingLabel .. " with Cenarion Circle (need Hostile)"
            else
                return FAIL, "Not At War with " .. factionName
            end
        end
    end
    return UNCHECKED, factionName .. " not found in reputation panel"
end)

R("Old Horde", function()
    local standing = getStandingForFaction("Orgrimmar")
    if not standing then
        return UNCHECKED, "Orgrimmar not found in reputation panel"
    end

    local REVERED = 7
    local standingNames = { "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" }
    local standingLabel = standingNames[standing] or "?"

    if standing >= REVERED then
        return FAIL, standingLabel .. " with Orgimmar (need less than Revered)"
    end

    return PASS, standingLabel .. " with Orgimmar (need less than Revered)"
end)

-- Diplomat: must obtain another faction's mount before reaching 60.
-- We check if the player is exalted with any non-home faction (mount requires exalted in Classic).
R("Diplomat", function()
    local _, raceKey = UnitRace("player")
    local homeFaction = HOME_FACTION[raceKey]

    local ALLIANCE_FACTIONS = { ["Stormwind"] = true, ["Ironforge"] = true, ["Darnassus"] = true, ["Gnomeregan Exiles"] = true }
    local HORDE_FACTIONS = { ["Orgrimmar"] = true, ["Undercity"] = true, ["Thunder Bluff"] = true, ["Darkspear Trolls"] = true }

    local myFactions = ALLIANCE_FACTIONS[homeFaction] and ALLIANCE_FACTIONS or HORDE_FACTIONS
    local EXALTED = 8
    local bestOther, bestStanding = nil, 0

    for i = 1, GetNumFactions() do
        local name, _, standingId = GetFactionInfo(i)
        if name and myFactions[name] and name ~= homeFaction then
            if standingId and standingId > bestStanding then
                bestStanding = standingId
                bestOther = name
            end
            if standingId and standingId >= EXALTED then
                return PASS, "Exalted with " .. name .. " — can buy their mount"
            end
        end
    end

    local standingNames = { "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" }

    if bestOther then
        return FAIL, (standingNames[bestStanding] or "?") .. " with " .. bestOther .. " (need Exalted)"
    end

    return UNCHECKED, "No allied faction rep found — expand reputation panel headers"
end)

----------------------------------------------------------------------
-- EVENT-BASED CHALLENGES (powered by EventChallenges.lua)
----------------------------------------------------------------------

-- Voodoo Ritual: /dance at Jintha'Alor peak with 3 cursed items
R("Voodoo Ritual", function()
    if not FCE.EventChallenges or not FCE.EventChallenges.CheckVoodooRitual then
        return UNCHECKED, "Event challenge module not loaded"
    end
    return FCE.EventChallenges.CheckVoodooRitual()
end)

-- Gnomish Justice: Universal Remote on Clunk + kill Kovic
R("Gnomish Justice", function()
    if not FCE.EventChallenges or not FCE.EventChallenges.CheckGnomishJustice then
        return UNCHECKED, "Event challenge module not loaded"
    end
    return FCE.EventChallenges.CheckGnomishJustice()
end)

-- Scarlet Redemption: destroy Scarlet Tabard at Light's Hope Chapel
R("Scarlet Redemption", function()
    if not FCE.EventChallenges or not FCE.EventChallenges.CheckScarletRedemption then
        return UNCHECKED, "Event challenge module not loaded"
    end
    return FCE.EventChallenges.CheckScarletRedemption()
end)

-- The New Plague: destroy Nightglow Concoction in Southshore under Nature Protection
R("The New Plague", function()
    if not FCE.EventChallenges or not FCE.EventChallenges.CheckNewPlague then
        return UNCHECKED, "Event challenge module not loaded"
    end
    return FCE.EventChallenges.CheckNewPlague()
end)

-- Savagery: shapeshift uptime meter — fails at 0%
R("Savagery", function()
    if not FCE.SavagerySystem then
        return UNCHECKED, "Savagery module not loaded"
    end
    if FCE.SavagerySystem.HasFailed and FCE.SavagerySystem.HasFailed() then
        return FAIL, "Savagery reached 0% — /fce savagery reset to retry"
    end
    local val = FCE.SavagerySystem.GetSavagery and FCE.SavagerySystem.GetSavagery() or 100
    return PASS, string.format("Savagery at %.0f%%", val)
end)

-- Happy Hour: drink alcohol once per hour — Brewmaster
R("Happy Hour", function()
    if not FCE.BrewmasterSystem then
        return UNCHECKED, "Brewmaster module not loaded"
    end
    if FCE.BrewmasterSystem.HasFailed and FCE.BrewmasterSystem.HasFailed() then
        return FAIL, "Happy Hour expired — /fce happyhour reset to retry"
    end
    local t = FCE.BrewmasterSystem.GetTimeRemaining and FCE.BrewmasterSystem.GetTimeRemaining() or 3600
    local mins = math.floor(t / 60)
    return PASS, string.format("%d min remaining", mins)
end)

-- Elixir Frenzy: always have an elixir buff — Berserker
R("Elixir Frenzy", function()
    if not FCE.ElixirSystem then
        return UNCHECKED, "Elixir module not loaded"
    end
    if FCE.ElixirSystem.HasFailed and FCE.ElixirSystem.HasFailed() then
        return FAIL, "Elixir Frenzy expired — /fce elixir reset to retry"
    end
    local t = FCE.ElixirSystem.GetGraceRemaining and FCE.ElixirSystem.GetGraceRemaining() or 300
    if t >= 300 then
        return PASS, "Elixir active"
    end
    local mins = math.floor(t / 60)
    local secs = math.floor(t % 60)
    return PASS, string.format("Grace: %d:%02d", mins, secs)
end)

-- Disease Cleansing: cure 10 tracked diseases from self with consumable items
R("Disease Cleansing", function()
    if not FCE.EventChallenges or not FCE.EventChallenges.CheckDiseaseCleansing then
        return UNCHECKED, "Event challenge module not loaded"
    end
    return FCE.EventChallenges.CheckDiseaseCleansing()
end)

-- Master Trainer: pet must use Bite Rank 8 and Furious Howl Rank 4
R("Master Trainer", function()
    if not FCE.EventChallenges or not FCE.EventChallenges.CheckMasterTrainer then
        return UNCHECKED, "Event challenge module not loaded"
    end
    return FCE.EventChallenges.CheckMasterTrainer()
end)

-- Seeking a Pardon: no quests until pardon quest is done
R("Seeking a Pardon", function()
    if not FCE.EventChallenges or not FCE.EventChallenges.CheckSeekingPardon then
        return UNCHECKED, "Event challenge module not loaded"
    end
    return FCE.EventChallenges.CheckSeekingPardon()
end)

-- Master Smelter: player must cast Smelt Dark Iron (14891)
R("Master Smelter", function()
    if not FCE.EventChallenges or not FCE.EventChallenges.CheckMasterSmelter then
        return UNCHECKED, "Event challenge module not loaded"
    end
    return FCE.EventChallenges.CheckMasterSmelter()
end)

-- XXX: kill NPC 3936
R("XXX", function()
    if not FCE.EventChallenges or not FCE.EventChallenges.CheckXXX then
        return UNCHECKED, "Event challenge module not loaded"
    end
    return FCE.EventChallenges.CheckXXX()
end)

-- Tame Snarler: tame Snarler (NPC 5356) in Feralas
R("Tame Son of Hakkar", function()
    if not FCE.EventChallenges or not FCE.EventChallenges.CheckTameSonOfHakkar then
        return UNCHECKED, "Event challenge module not loaded"
    end
    return FCE.EventChallenges.CheckTameSonOfHakkar()
end)

-- Tame Bloodaxe Worg: tame a Bloodaxe Worg (NPC 9696) in LBRS
R("Tame Bloodaxe Worg", function()
    if not FCE.EventChallenges or not FCE.EventChallenges.CheckTameBloodaxeWorg then
        return UNCHECKED, "Event challenge module not loaded"
    end
    return FCE.EventChallenges.CheckTameBloodaxeWorg()
end)

-- Native Tongue: speak only your racial language, not Common/Orcish
R("Insular", function()
    if not FCE.EventChallenges or not FCE.EventChallenges.CheckNativeTongue then
        return UNCHECKED, "Event challenge module not loaded"
    end
    return FCE.EventChallenges.CheckNativeTongue()
end)

----------------------------------------------------------------------
-- CHALLENGES HANDLED ELSEWHERE
-- Self-made and Self-made guns are tracked by SelfFoundCheck.lua.
-- We register stubs here that defer to SelfFoundCheck results so the
-- rule engine has entries for ALL challenge types (no gaps in lookup).
----------------------------------------------------------------------

-- All self-made variants run a fresh check instead of reading stale results,
-- so that equipment changes are reflected immediately.
local function selfMadeResult()
    if FCE.SelfFoundCheck and FCE.SelfFoundCheck.RunCheck then
        local results = FCE.SelfFoundCheck.RunCheck()
        if results.selfMade then
            return results.selfMade.status, results.selfMade.detail
        end
    end
    return UNCHECKED, "Self-found module not loaded"
end

R("Self-made", selfMadeResult)

R("Self-made guns", function()
    if FCE.SelfFoundCheck and FCE.SelfFoundCheck.RunCheck then
        local results = FCE.SelfFoundCheck.RunCheck()
        if results.selfMadeGuns then
            return results.selfMadeGuns.status, results.selfMadeGuns.detail
        end
    end
    return UNCHECKED, "Self-found module not loaded"
end)

----------------------------------------------------------------------
-- BUFF-BASED CHALLENGES
----------------------------------------------------------------------

-- Demonic Sacrifice: the player must have the Demonic Sacrifice buff
-- active (spell ID 18788).  This is a Warlock talent that sacrifices
-- the current demon pet for a persistent self-buff.
R("Demonic Sacrifice", function()
    local SPELL_ID = 18788
    -- Strategy 1: scan by spell ID (locale-safe)
    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, spellID = UnitBuff("player", i)
        if not name then break end
        if spellID and spellID == SPELL_ID then
            return PASS, "Demonic Sacrifice buff active (spell " .. spellID .. ")"
        end
    end
    -- Strategy 2: name-based fallback for clients that don't return spellID
    for i = 1, 40 do
        local name = UnitBuff("player", i)
        if not name then break end
        if name:lower():find("demonic sacrifice") then
            return PASS, "Demonic Sacrifice buff active (\"" .. name .. "\")"
        end
    end
    return FAIL, "Demonic Sacrifice buff not detected — sacrifice your demon pet"
end)

----------------------------------------------------------------------
-- Rule lookup and execution
----------------------------------------------------------------------

--- Look up the checker for a challenge description.
function CC.FindRule(desc)
    if not desc then return nil end
    return rules[desc:lower()]
end

--- Run all challenge checks for the current character.
--- Returns a table of results keyed by challenge index.
function CC.CheckAll()
    local results = {}
    if not FCE_CharDB then return results end

    local key = FCE_CharDB.selectedCharacter
    local char = key and FCE.GetCharacter and FCE.GetCharacter(key) or nil
    if not char then return results end

    local playerLevel = UnitLevel("player") or 1

    local activeChallenges = FCE.GetActiveChallenges and FCE.GetActiveChallenges(char) or char.challenges or {}

    for i, ch in ipairs(activeChallenges) do
        if ch.endLevel and playerLevel > ch.endLevel then
            results[i] = { status = "inactive", detail = "Superseded (was lv " .. ch.level .. "-" .. ch.endLevel .. ")", desc = ch.desc }
        elseif playerLevel >= ch.level then
            local rule = CC.FindRule(ch.desc)
            if rule then
                local status, detail = rule()
                results[i] = { status = status, detail = detail, desc = ch.desc }
            else
                results[i] = { status = UNCHECKED, detail = "No rule defined for this challenge", desc = ch.desc }
            end
        else
            results[i] = { status = "inactive", detail = "Unlocks at level " .. ch.level, desc = ch.desc }
        end
    end

    return results
end

--- Run a full check and store results.  Returns the results table.
--- Pre-computes forgiveness optimistically so forgivable challenges
--- see the rank they'd have if they all passed (breaking circularity).
function CC.RunCheck()
    -- Pre-compute forgiveness: assume forgivable challenges PASS,
    -- then compute rank from everything else.  This breaks the
    -- circular dependency where a challenge needs rank to pass,
    -- but rank needs the challenge to pass.
    cachedAllowedViolations = computeOptimisticAllowed()

    local results = CC.CheckAll()
    if FCE_CharDB then
        FCE_CharDB.challengeResults = results
    end

    cachedAllowedViolations = nil  -- clear cache
    return results
end

--- Get stored results (from last check).
function CC.GetResults()
    return FCE_CharDB and FCE_CharDB.challengeResults or {}
end

----------------------------------------------------------------------
-- Chat warnings — fires once per challenge per state transition
----------------------------------------------------------------------

local CHAT_PREFIX = "|cffe6b422[FCE]|r "
local warnedChallenges = {}  -- [challengeDesc] = lastWarnedStatus

local function warnChallenge(desc, detail)
    if FCE.ChatWarningsEnabled and not FCE.ChatWarningsEnabled() then return end
    DEFAULT_CHAT_FRAME:AddMessage(
        CHAT_PREFIX .. "|cffff8844Challenge violation:|r " .. desc ..
        (detail and (" — " .. detail) or "")
    )
end

--- Run checks and print warnings for newly-failed challenges.
--- Also triggers forbidden-alert toasts for quality/armor violations.
function CC.CheckAndWarn()
    local oldResults = CC.GetResults()
    local oldStatus = {}
    for i, r in pairs(oldResults) do oldStatus[i] = r.status end

    local newResults = CC.RunCheck()

    local newViolations = {}
    for i, res in pairs(newResults) do
        if res.status == FAIL then
            local was = oldStatus[i]
            if was ~= FAIL then
                warnChallenge(res.desc, res.detail)
                table.insert(newViolations, { desc = res.desc, detail = res.detail })
            end
        end
    end

    -- Fire forbidden-alert toasts for challenge violations too
    if #newViolations > 0 and FCE.ForbiddenAlert and FCE.ForbiddenAlert.FireBatch then
        FCE.ForbiddenAlert.FireBatch(newViolations)
    end

    if FCE.RefreshPanel then FCE.RefreshPanel() end
end

--- Reset warning state (called on character pick/reset).
function CC.ResetWarnings()
    warnedChallenges = {}
    if FCE_CharDB then
        FCE_CharDB.challengeResults = {}
    end
end

----------------------------------------------------------------------
-- Slash command: /fce challenges
----------------------------------------------------------------------

function CC.PrintStatus()
    if not FCE_CharDB or not FCE_CharDB.selectedCharacter then
        FCE.Print("No enhanced class selected.")
        return
    end
    local char = FCE.GetCharacter(FCE_CharDB.selectedCharacter)
    local activeChallenges = FCE.GetActiveChallenges and FCE.GetActiveChallenges(char) or char.challenges or {}
    if not char or #activeChallenges == 0 then
        FCE.Print("Your enhanced class has no challenge requirements.")
        return
    end

    local results = CC.RunCheck()
    local level = UnitLevel("player") or 1
    FCE.Print("Challenge status (level " .. level .. "):")

    for i, ch in ipairs(activeChallenges) do
        local res = results[i]
        local tag
        if not res or res.status == "inactive" then
            tag = "|cff888888inactive|r"
        elseif res.status == PASS then
            tag = "|cff00ff00OK|r"
        elseif res.status == FAIL then
            tag = "|cffff5555FAIL|r"
        else
            tag = "|cffffaa33???|r"
        end
        local detail = (res and res.detail) and (" — " .. res.detail) or ""
        FCE.Print("  " .. ch.desc .. ": " .. tag .. detail)
    end
end

----------------------------------------------------------------------
-- Curated item list stubs — ensure the tables exist so the challenge
-- checkers don't nil-index.  ItemSourceData.lua (loaded after this
-- file) populates these with actual item IDs.
----------------------------------------------------------------------

local function ensureCuratedList(name)
    FCE.CuratedItems = FCE.CuratedItems or {}
    if not FCE.CuratedItems[name] then
        FCE.CuratedItems[name] = {}
    end
end

ensureCuratedList("quest_rewards")
ensureCuratedList("vendor_items")
ensureCuratedList("crafted_items")
ensureCuratedList("looted_gear")

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("UNIT_PET")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("BANKFRAME_OPENED")
eventFrame:RegisterEvent("MERCHANT_CLOSED")

local initialCheckDone = false

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        -- Defer so SavedVariables + item cache are ready
        C_Timer.After(2.5, function()
            CC.RunCheck()
            initialCheckDone = true
            if FCE.RefreshPanel then FCE.RefreshPanel() end
        end)
        -- Second pass for uncached items
        C_Timer.After(5.5, function()
            CC.CheckAndWarn()
        end)

    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        if not initialCheckDone then return end
        -- Quality, armor-type, and item-source challenges all react to
        -- equipment changes.
        C_Timer.After(0.4, function()
            CC.CheckAndWarn()
        end)

    elseif event == "UNIT_PET" then
        if not initialCheckDone then return end
        -- Imp / No demon challenges react to pet changes.
        local unit = ...
        if unit == "player" then
            C_Timer.After(0.3, function()
                CC.CheckAndWarn()
            end)
        end

    elseif event == "ZONE_CHANGED_NEW_AREA" then
        if not initialCheckDone then return end
        -- Homebound and zone-visit challenges react to zone changes.
        -- ZoneCheck.lua handles its own zone recording; we just need
        -- to re-evaluate challenge results here.
        C_Timer.After(0.6, function()
            CC.CheckAndWarn()
        end)

    elseif event == "BANKFRAME_OPENED" or event == "MERCHANT_CLOSED" then
        if not initialCheckDone then return end
        -- Behavioral challenges (Drifter, Ephemeral) are tracked by
        -- BehavioralCheck.lua, which handles its own warnings and
        -- forbidden-alert toasts.  We re-run the full challenge check
        -- here so the results table stays current for the panel.
        C_Timer.After(0.5, function()
            CC.RunCheck()
            if FCE.RefreshPanel then FCE.RefreshPanel() end
        end)
    end
end)
