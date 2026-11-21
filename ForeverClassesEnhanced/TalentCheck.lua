----------------------------------------------------------------------
-- ForeverClassesEnhanced — Talent / Spec Tracking
--
-- Two layers of talent verification:
--
-- 1. SPEC PLURALITY — the character's native spec tree must have
--    strictly more points than either other tree individually.
--
-- 2. PER-TALENT REQUIREMENTS — specific talents must reach a minimum
--    rank by a given player level (data in TalentRequirements.lua).
--
-- Talent lookup is done by scanning GetTalentInfo(tab, i) at runtime
-- and matching by name (case-insensitive).  Tab indices (1/2/3) are
-- positional and locale-independent; talent names are English, which
-- works directly on English clients.  On non-English clients, a
-- match failure returns UNCHECKED rather than a false FAIL.
--
-- On Forever the Classic API is gone; talents come from C_Traits
-- (see ScanTalents).  WoW Classic talent API (1.15.x):
--   GetNumTalentTabs()                → 3
--   GetTalentTabInfo(tabIndex)        → name, texture, pointsSpent, …
--   GetNumTalents(tabIndex)           → count
--   GetTalentInfo(tabIndex, talentIndex)
--       → name, iconTexture, tier, column, rank, maxRank, isExceptional, available
----------------------------------------------------------------------

FCE = FCE or {}

local TC = {}
FCE.TalentCheck = TC

----------------------------------------------------------------------
-- Status constants
----------------------------------------------------------------------

local PASS      = "pass"
local FAIL      = "fail"
local UNCHECKED = "unchecked"

TC.STATUS = { PASS = PASS, FAIL = FAIL, UNCHECKED = UNCHECKED }

----------------------------------------------------------------------
-- Spec → talent tab index mapping
----------------------------------------------------------------------

local SPEC_TAB = {
    WARRIOR = {
        ["Arms"]       = 1,
        ["Fury"]       = 2,
        ["Protection"] = 3,
    },
    ROGUE = {
        ["Assassination"] = 1,
        ["Combat"]        = 2,
        ["Subtlety"]      = 3,
    },
    WARLOCK = {
        ["Affliction"]  = 1,
        ["Demonology"]  = 2,
        ["Destruction"] = 3,
    },
    DRUID = {
        ["Balance"]     = 1,
        ["Feral"]       = 2,
        ["Restoration"] = 3,
    },
    HUNTER = {
        ["Beast Mastery"] = 1,
        ["Marksmanship"]  = 2,
        ["Survival"]      = 3,
    },
    SHAMAN = {
        ["Elemental"]   = 1,
        ["Enhancement"] = 2,
        ["Restoration"] = 3,
    },
    PALADIN = {
        ["Holy"]        = 1,
        ["Protection"]  = 2,
        ["Retribution"] = 3,
    },
    PRIEST = {
        ["Discipline"] = 1,
        ["Holy"]       = 2,
        ["Shadow"]     = 3,
    },
    MAGE = {
        ["Arcane"] = 1,
        ["Fire"]   = 2,
        ["Frost"]  = 3,
    },
}

----------------------------------------------------------------------
-- Talent reading — two backends behind one cache
--
-- Classic API (GetTalentInfo) when present; otherwise Forever's
-- C_Traits.  Forever puts all three specs in ONE trait tree laid out
-- side by side, so tabs 1/2/3 are recovered from node x positions
-- (split at the two widest gaps).  If a client ever returns three
-- separate trees, tree order is used instead.
----------------------------------------------------------------------

local GetSpellInfo = FCE.Compat.GetSpellInfo  -- Forever API shims (ForeverCompat.lua)

local talentCache = {}   -- [tab][lower_name] = { rank, maxRank, name }
local talentPoints = { 0, 0, 0 }
local talentTotal  = 0
local usingTraits  = false

local function HasClassicTalentAPI()
    return (GetNumTalents and GetTalentInfo) and true or false
end

local function HasTraitsAPI()
    return (C_ClassTalents and C_ClassTalents.GetActiveConfigID
        and C_Traits and C_Traits.GetConfigInfo) and true or false
end

local function AssignTabsByX(nodes)
    local xs = {}
    for _, n in ipairs(nodes) do xs[#xs + 1] = n.x end
    table.sort(xs)
    if #xs < 3 then
        for _, n in ipairs(nodes) do n.tab = 1 end
        return
    end
    local g1, g2
    local function gap(i) return xs[i + 1] - xs[i] end
    for i = 1, #xs - 1 do
        if not g1 or gap(i) > gap(g1) then
            g2, g1 = g1, i
        elseif not g2 or gap(i) > gap(g2) then
            g2 = i
        end
    end
    local lo, hi = math.min(g1, g2), math.max(g1, g2)
    local cutA = (xs[lo] + xs[lo + 1]) / 2
    local cutB = (xs[hi] + xs[hi + 1]) / 2
    for _, n in ipairs(nodes) do
        n.tab = (n.x < cutA) and 1 or ((n.x < cutB) and 2 or 3)
    end
end

local function ReadTraitNodes()
    local ok, res = pcall(function()
        local out = {}
        local configID = C_ClassTalents.GetActiveConfigID()
        if not configID then return out end
        local cfg = C_Traits.GetConfigInfo(configID)
        local trees = (cfg and cfg.treeIDs) or {}
        for ti, treeID in ipairs(trees) do
            for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
                local node = C_Traits.GetNodeInfo(configID, nodeID)
                if node and node.ID and node.ID ~= 0 then
                    local entryID = (node.activeEntry and node.activeEntry.entryID)
                        or (node.entryIDs and node.entryIDs[1])
                    local name
                    if entryID then
                        local e = C_Traits.GetEntryInfo(configID, entryID)
                        local d = e and e.definitionID and C_Traits.GetDefinitionInfo(e.definitionID)
                        local spellID = d and (d.spellID or d.overriddenSpellID)
                        if spellID then name = GetSpellInfo(spellID) end
                        name = name or (d and d.overrideName)
                    end
                    if type(name) == "string" and name ~= "" then
                        out[#out + 1] = {
                            name      = name,
                            rank      = tonumber(node.activeRank or node.currentRank) or 0,
                            maxRank   = tonumber(node.maxRanks) or 0,
                            x         = tonumber(node.posX) or 0,
                            treeIndex = ti,
                        }
                    end
                end
            end
        end
        if #trees >= 3 then
            for _, n in ipairs(out) do n.tab = math.min(n.treeIndex, 3) end
        else
            AssignTabsByX(out)
        end
        return out
    end)
    return ok and res or nil
end

local function ScanTalents()
    talentCache  = { {}, {}, {} }
    talentPoints = { 0, 0, 0 }
    talentTotal  = 0
    usingTraits  = false

    if HasClassicTalentAPI() then
        for tab = 1, 3 do
            local n = GetNumTalents(tab) or 0
            for i = 1, n do
                local name, _, _, _, rank, maxRank = GetTalentInfo(tab, i)
                rank = tonumber(rank) or 0
                if name and name ~= "" then
                    talentCache[tab][name:lower()] = { rank = rank, maxRank = maxRank or 0, name = name }
                end
                talentPoints[tab] = talentPoints[tab] + rank
            end
            talentTotal = talentTotal + talentPoints[tab]
        end
    elseif HasTraitsAPI() then
        usingTraits = true
        for _, n in ipairs(ReadTraitNodes() or {}) do
            local tab = n.tab or 1
            talentCache[tab][n.name:lower()] = { rank = n.rank, maxRank = n.maxRank, name = n.name }
            talentPoints[tab] = talentPoints[tab] + n.rank
            talentTotal = talentTotal + n.rank
        end
    end
end

local function FindTalent(tab, englishName)
    local key = englishName:lower()
    if talentCache[tab] and talentCache[tab][key] then
        return talentCache[tab][key]
    end
    -- Fall back to all tabs (Forever moved some talents between trees)
    for t = 1, 3 do
        if talentCache[t] and talentCache[t][key] then
            return talentCache[t][key]
        end
    end
    return nil
end

--- For /fce apitest: backend, talents read, points per tab.
function TC.ScanSummary()
    ScanTalents()
    local n = 0
    for t = 1, 3 do for _ in pairs(talentCache[t]) do n = n + 1 end end
    return usingTraits and "C_Traits" or "Classic API", n,
        { talentPoints[1], talentPoints[2], talentPoints[3] }
end

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------

local function ReadTalentPoints()
    ScanTalents()
    return { talentPoints[1], talentPoints[2], talentPoints[3] }, talentTotal
end

local function ExpectedPointsAtLevel(playerLevel)
    if playerLevel < 10 then return 0 end
    return playerLevel - 9
end

--- Reverse lookup: tab index → spec name using our hardcoded SPEC_TAB.
--- GetTalentTabInfo is unreliable in Classic 1.15.x (returns numbers
--- instead of names), so we build from our own data.
local TAB_NAME_CACHE = {}   -- [classToken] = { [1] = "Arms", [2] = "Fury", ... }

local function BuildTabNameCache(classToken)
    if TAB_NAME_CACHE[classToken] then return end
    TAB_NAME_CACHE[classToken] = {}
    local specMap = SPEC_TAB[classToken]
    if specMap then
        for specName, tabIdx in pairs(specMap) do
            TAB_NAME_CACHE[classToken][tabIdx] = specName
        end
    end
end

local function TabName(tabIndex)
    local _, classToken = UnitClass("player")
    if classToken then
        BuildTabNameCache(classToken)
        local cached = TAB_NAME_CACHE[classToken]
        if cached and cached[tabIndex] then
            return cached[tabIndex]
        end
    end
    -- Absolute last resort
    return "Tree " .. tabIndex
end

----------------------------------------------------------------------
-- Spec plurality check
----------------------------------------------------------------------

local function CheckSpecPlurality(expectedTab, points, totalSpent, playerLevel)
    local expected = ExpectedPointsAtLevel(playerLevel)
    local specName = TabName(expectedTab)
    local specPts  = points[expectedTab]
    local unspent  = expected - totalSpent

    -- Informational only — no pass/fail enforcement on tree distribution.
    local detail
    if totalSpent == 0 then
        if expected > 0 then
            detail = string.format(
                "No talent points spent yet (%d point%s available at lv %d)",
                expected, expected == 1 and "" or "s", playerLevel
            )
        else
            return UNCHECKED, "No talent points available yet"
        end
    elseif unspent > 0 then
        detail = string.format(
            "%s: %d/%d points (%d unspent)",
            specName, specPts, totalSpent, unspent
        )
    else
        detail = string.format(
            "%s: %d/%d points",
            specName, specPts, totalSpent
        )
    end

    return PASS, detail
end

----------------------------------------------------------------------
-- Per-talent requirement check
----------------------------------------------------------------------

local function CheckTalentReqs(charName, playerLevel)
    local reqs = FCE.TalentRequirements and FCE.TalentRequirements[charName]
    if not reqs then return {}, false, false end

    ScanTalents()

    local results = {}
    local anyFail      = false
    local anyUnchecked = false

    for i, req in ipairs(reqs) do
        local superseded = req.endLevel and playerLevel > req.endLevel
        local entry = {
            name         = req.name,
            tab          = req.tab,
            requiredRank = req.rank,
            currentRank  = 0,
            maxRank      = req.rank,
            level        = req.level,
            endLevel     = req.endLevel,
            active       = (playerLevel >= req.level) and not superseded,
            superseded   = superseded,
            status       = "inactive",
            detail       = "",
        }

        if superseded then
            entry.detail = "Was active lv " .. req.level .. "-" .. req.endLevel
        elseif not entry.active then
            entry.detail = "Unlocks at level " .. req.level
        else
            local talent = FindTalent(req.tab, req.name)
            if not talent then
                entry.status = UNCHECKED
                entry.detail = req.name .. (usingTraits
                    and " \226\128\148 not in this talent tree (renamed or removed on Forever?)"
                    or  " \226\128\148 talent not found (non-English locale?)")
                anyUnchecked = true
            else
                -- Forever lowered some max ranks (Flurry 5->3 etc.): "max it"
                -- requirements cap at the tree's real maximum.
                local need = req.rank
                if talent.maxRank and talent.maxRank > 0 and need > talent.maxRank then
                    need = talent.maxRank
                end
                entry.requiredRank = need
                entry.currentRank  = talent.rank
                entry.maxRank      = talent.maxRank
                if talent.rank >= need then
                    entry.status = PASS
                    entry.detail = string.format(
                        "%s %d/%d", talent.name, talent.rank, talent.maxRank
                    )
                else
                    entry.status = FAIL
                    entry.detail = string.format(
                        "%s %d/%d \226\128\148 need %d by lv %d",
                        talent.name, talent.rank, talent.maxRank,
                        need, req.level
                    )
                    anyFail = true
                end
            end
        end

        results[i] = entry
    end

    return results, anyFail, anyUnchecked
end

----------------------------------------------------------------------
-- Main check — combines spec plurality + per-talent requirements
----------------------------------------------------------------------

function TC.CheckAll()
    local result = {
        status        = UNCHECKED,
        detail        = "",
        specTab       = nil,
        specPoints    = 0,
        totalSpent    = 0,
        expectedTotal = 0,
        points        = { 0, 0, 0 },
        specStatus    = UNCHECKED,
        specDetail    = "",
        talentReqs    = {},
    }

    if not FCE_CharDB then return result end
    local key  = FCE_CharDB.selectedCharacter
    local char = key and FCE.GetCharacter and FCE.GetCharacter(key) or nil
    if not char then return result end

    local _, playerClass = UnitClass("player")
    local playerLevel    = UnitLevel("player") or 1

    -- Before level 10: no talent points to spend
    if playerLevel < 10 then
        result.status     = "inactive"
        result.detail     = "Talent tracking starts at level 10"
        result.specStatus = "inactive"
        result.specDetail = result.detail
        return result
    end

    -- Resolve expected tab index
    local classSpecs = SPEC_TAB[playerClass]
    if not classSpecs then
        result.status     = UNCHECKED
        result.detail     = "Unknown class: " .. tostring(playerClass)
        result.specStatus = UNCHECKED
        result.specDetail = result.detail
        return result
    end
    local expectedTab = classSpecs[char.spec]

    -- Read current talent distribution
    local points, totalSpent = ReadTalentPoints()
    result.points        = points
    result.totalSpent    = totalSpent
    result.expectedTotal = ExpectedPointsAtLevel(playerLevel)

    if expectedTab then
        result.specTab    = expectedTab
        result.specPoints = points[expectedTab]

        -- Layer 1: spec plurality (only if we know the expected tab)
        result.specStatus, result.specDetail = CheckSpecPlurality(
            expectedTab, points, totalSpent, playerLevel
        )
    else
        -- Custom spec name (e.g. "Slam", "Arms/Prot") doesn't map to a
        -- standard WoW tree — skip plurality, still check per-talent reqs.
        result.specStatus = PASS
        result.specDetail = char.spec .. " (custom spec)"
    end

    -- Layer 2: per-talent requirements (always runs)
    local talentReqs, anyFail, anyUnchecked = CheckTalentReqs(char.class .. "_" .. char.spec, playerLevel)
    result.talentReqs = talentReqs

    -- Combined status (spec plurality is informational only, not enforced)
    if anyFail then
        result.status = FAIL
    elseif result.specStatus == UNCHECKED then
        result.status = UNCHECKED
    else
        result.status = PASS
    end

    -- Combined detail string
    if anyFail then
        local failCount = 0
        for _, tr in ipairs(talentReqs) do
            if tr.active and tr.status == FAIL then failCount = failCount + 1 end
        end
        result.detail = failCount .. (failCount == 1 and " talent behind" or " talents behind")
    else
        result.detail = result.specDetail
    end

    return result
end

--- Run a full check and store results in SavedVariables.
function TC.RunCheck()
    local result = TC.CheckAll()
    if FCE_CharDB then
        FCE_CharDB.talentResults = result
    end
    return result
end

--- Get stored results from the last check.
function TC.GetResults()
    return FCE_CharDB and FCE_CharDB.talentResults or {}
end

----------------------------------------------------------------------
-- Chat warnings
----------------------------------------------------------------------

local CHAT_PREFIX = "|cffe6b422[FCE]|r "

local warnedTalents    = {}   -- [talentName] = true once warned

function TC.CheckAndWarn()
    local oldResult = TC.GetResults()
    local newResult = TC.RunCheck()

    local canChat = (not FCE.ChatWarningsEnabled) or FCE.ChatWarningsEnabled()

    -- Per-talent requirement warnings
    if canChat and newResult.talentReqs then
        for _, treq in ipairs(newResult.talentReqs) do
            if treq.active and treq.status == FAIL and not warnedTalents[treq.name] then
                DEFAULT_CHAT_FRAME:AddMessage(
                    CHAT_PREFIX .. "|cffffaa33Talent:|r " .. treq.detail
                )
                warnedTalents[treq.name] = true
            elseif treq.active and treq.status == PASS and warnedTalents[treq.name] then
                -- Clear warning so it can re-fire if they respec
                warnedTalents[treq.name] = nil
            end
        end
    end

    if FCE.RefreshPanel then FCE.RefreshPanel() end
end

--- Reset one-shot warning state (called on character pick / reset).
function TC.ResetWarnings()
    warnedTalents = {}
end

----------------------------------------------------------------------
-- Slash command handler: /fce talents
----------------------------------------------------------------------

function TC.PrintStatus()
    if not FCE_CharDB or not FCE_CharDB.selectedCharacter then
        FCE.Print("No enhanced class selected. Type |cffffd100/fce pick|r to choose one.")
        return
    end

    local char = FCE.GetCharacter(FCE_CharDB.selectedCharacter)
    if not char then
        FCE.Print("Character data not found.")
        return
    end

    local level = UnitLevel("player") or 1
    local result = TC.RunCheck()

    FCE.Print("Talent status (level " .. level .. ", spec: " .. char.spec .. "):")

    -- Per-tree breakdown
    local points = result.points or { 0, 0, 0 }
    local numTabs = GetNumTalentTabs and GetNumTalentTabs() or 3
    for i = 1, math.min(numTabs, 3) do
        local name = TabName(i)
        local marker = ""
        if result.specTab and i == result.specTab then
            marker = " |cffffd100\226\151\132 required|r"
        end
        local ptsColor
        if result.specTab and i == result.specTab then
            ptsColor = points[i] > 0 and "|cff00ff00" or "|cffff5555"
        else
            ptsColor = "|cff888888"
        end
        FCE.Print("  " .. name .. ": " .. ptsColor .. points[i] .. "|r" .. marker)
    end

    -- Spec verdict
    local tag
    if result.specStatus == PASS then
        tag = "|cff00ff00OK|r"
    elseif result.specStatus == FAIL then
        tag = "|cffff5555BEHIND|r"
    elseif result.specStatus == "inactive" then
        tag = "|cff888888inactive|r"
    else
        tag = "|cffffaa33???|r"
    end
    FCE.Print("  Spec verdict: " .. tag .. " \226\128\148 " .. (result.specDetail or ""))

    -- Per-talent requirements
    if result.talentReqs and #result.talentReqs > 0 then
        FCE.Print("  Talent requirements:")
        for _, treq in ipairs(result.talentReqs) do
            local icon
            if not treq.active then
                icon = "|cff888888\194\183|r"   -- grey dot
            elseif treq.status == PASS then
                icon = "|cff00ff00\226\156\147|r"  -- green check
            elseif treq.status == FAIL then
                icon = "|cffff5555\226\156\151|r"  -- red cross
            else
                icon = "|cffffaa33?|r"
            end
            local rankStr = treq.requiredRank .. "/" .. treq.maxRank
            local lvTag = treq.active and "" or (" |cff888888(lv " .. treq.level .. ")|r")
            FCE.Print("    " .. icon .. " " .. treq.name .. " (" .. rankStr .. ")" .. lvTag)
        end
    end
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("CHARACTER_POINTS_CHANGED")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
pcall(eventFrame.RegisterEvent, eventFrame, "TRAIT_CONFIG_UPDATED")   -- Forever (C_Traits)

local initialCheckDone = false

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        FCE.After("TalentCheck", 3.0, function()
            TC.RunCheck()
            initialCheckDone = true
            if FCE.RefreshPanel then FCE.RefreshPanel() end
        end)
        FCE.After("TalentCheck", 6.0, function()
            TC.CheckAndWarn()
        end)

    elseif event == "CHARACTER_POINTS_CHANGED" then
        if not initialCheckDone then return end
        FCE.After("TalentCheck", 0.3, function()
            TC.CheckAndWarn()
        end)

    elseif event == "ACTIVE_TALENT_GROUP_CHANGED" or event == "TRAIT_CONFIG_UPDATED" then
        if not initialCheckDone then return end
        FCE.After("TalentCheck", 0.5, function()
            TC.CheckAndWarn()
        end)

    elseif event == "PLAYER_LEVEL_UP" then
        if not initialCheckDone then return end
        FCE.After("TalentCheck", 0.5, function()
            TC.CheckAndWarn()
        end)
    end
end)

-- Route event errors through the FCE error guard (ForeverCompat.lua)
FCE.Compat.GuardScript(eventFrame, "OnEvent", "TalentCheck")
