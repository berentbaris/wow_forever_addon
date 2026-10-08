----------------------------------------------------------------------
-- ForeverClassesEnhanced — Self-Found & Self-Made Tracking
--
-- Two related checks in one module:
--
-- 1. SELF-FOUND BUFF — Characters with selfFound=true in CharacterData
--    must be on a Self-Found realm / have the Self-Found buff active.
--    We detect this by scanning the player's auras for the Self-Found
--    buff, using spell IDs first (locale-safe) then falling back to
--    an English-name scan for discovery.
--
-- 2. SELF-MADE CHALLENGE — Characters with the "Self-made" or
--    "Self-made guns" challenge must equip only items that are:
--      (a) crafted (on the crafted_items list from ItemSourceData.lua), OR
--      (b) white (Common) or grey (Poor) quality.
--    Since ProfessionCheck.lua already verifies the player has the
--    correct professions, we just need the flat crafted_items list —
--    a player can only craft items from professions they've learned.
--
-- Results are stored in FCE_CharDB.selfFoundResults so the
-- requirements panel can display pass/fail indicators.
--
-- WoW Classic API used:
--   UnitBuff("player", index) — iterate auras to find Self-Found
--   GetInventoryItemID("player", slot) — read equipped items
--   GetItemInfo(itemID) — quality field (index 3, 0-based)
----------------------------------------------------------------------


local GetItemInfo, UnitBuff
    = FCE.Compat.GetItemInfo, FCE.Compat.UnitBuff  -- Forever API shims (ForeverCompat.lua)
FCE = FCE or {}

local SF = {}
FCE.SelfFoundCheck = SF

----------------------------------------------------------------------
-- Status constants (shared vocabulary)
----------------------------------------------------------------------

local PASS      = "pass"
local FAIL      = "fail"
local UNCHECKED = "unchecked"

SF.STATUS = { PASS = PASS, FAIL = FAIL, UNCHECKED = UNCHECKED }

----------------------------------------------------------------------
-- Self-Found buff spell IDs
--
-- The Self-Found buff is a permanent aura applied to characters on
-- Self-Found realms (Classic Era).  We check multiple candidate spell
-- IDs because the ID may vary between client versions / patches.
-- If none match, we fall back to a name-based scan.
--
-- These IDs should be verified in-game.  If the real ID differs,
-- add it here and the check will pick it up automatically.
----------------------------------------------------------------------

local SELF_FOUND_SPELL_IDS = {
    -- Known / candidate spell IDs for the Self-Found buff
    -- (verify in-game and update as needed)
    462515,   -- Self-Found (Classic Era Fresh)
    456540,   -- Self-Found (alternate candidate)
    431567,
}

-- English name for the fallback scan.  On non-English clients the
-- spell-ID path should catch it first; if both miss we report
-- UNCHECKED rather than a false FAIL.
local SELF_FOUND_BUFF_NAME = "Self-Found"

----------------------------------------------------------------------
-- Buff scanning
----------------------------------------------------------------------

--- Scan the player's buffs for the Self-Found aura.
--- @return string status  "pass" if found, "fail" if not, "unchecked" if API missing
--- @return string detail  human-readable explanation
local function CheckSelfFoundBuff()
    -- Guard against missing API (shouldn't happen in Classic, but
    -- defensive is good)
    if not UnitBuff then
        return UNCHECKED, "UnitBuff API not available"
    end

    -- Strategy 1: check by spell ID (locale-independent)
    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, spellID = UnitBuff("player", i)
        if not name then break end
        if spellID then
            for _, knownID in ipairs(SELF_FOUND_SPELL_IDS) do
                if spellID == knownID then
                    return PASS, "Self-Found buff active (spell " .. spellID .. ")"
                end
            end
        end
    end

    -- Strategy 2: check by English name (fast path for EN clients)
    for i = 1, 40 do
        local name = UnitBuff("player", i)
        if not name then break end
        -- Case-insensitive partial match to catch variations like
        -- "Self-Found", "Self Found", "Selffound"
        local lower = name:lower()
        if lower:find("self") and lower:find("found") then
            return PASS, "Self-Found buff active (\"" .. name .. "\")"
        end
    end

    -- Strategy 3: try AuraUtil if available (some Classic builds)
    if AuraUtil and AuraUtil.FindAuraByName then
        local name = AuraUtil.FindAuraByName(SELF_FOUND_BUFF_NAME, "player")
        if name then
            return PASS, "Self-Found buff active (AuraUtil)"
        end
    end

    -- Not found
    return FAIL, "Self-Found buff not detected"
end

----------------------------------------------------------------------
-- Crafted item checking (for Self-Made challenge)
--
-- Uses the comprehensive crafted_items list from ItemSourceData.lua
-- (auto-generated from Wowhead Classic, ~900+ items).  Since the
-- addon already tracks which professions a character has via
-- ProfessionCheck.lua, we don't need per-profession lists — players
-- can only craft items from professions they've actually learned.
--
-- Engineering-crafted guns are kept as a small separate list for
-- the "Self-made guns" challenge (Mountaineer character).
----------------------------------------------------------------------

-- Legacy table kept empty for backward compat; actual check uses
-- FCE.CuratedItems.crafted_items from ItemSourceData.lua.
SF.CraftedByProfession = {}

----------------------------------------------------------------------
-- Engineering-crafted gun list (for "Self-made guns" challenge)
--
-- Specifically guns that an Engineer would craft.  Used by the
-- Mountaineer character who requires self-crafted ranged weapons.
----------------------------------------------------------------------

SF.EngineeringGuns = {
    [4362]  = true,   -- Rough Boomstick (skill 1)
    [4363]  = true,   -- Deadly Blunderbuss (skill 65)
    [4369]  = true,   -- Moonsight Rifle (skill 100)
    [4372]  = true,   -- Lovingly Crafted Boomstick (skill 120)
    [4379]  = true,   -- Silver-plated Shotgun (skill 130)
    [4403]  = true,   -- Mithril Blunderbuss (skill 205)
    [10510] = true,   -- Mithril Heavy-bore Rifle (skill 220)
    [15995] = true,   -- Thorium Rifle (skill 260)
    [16004] = true,   -- Dark Iron Rifle (Dark Iron recipe)
    [18282] = true,   -- Core Marksman Rifle (MC recipe, skill 300)
}

----------------------------------------------------------------------
-- Equipment slot IDs (same as EquipmentCheck)
----------------------------------------------------------------------

local SLOT_IDS = {
    1,   -- INVSLOT_HEAD
    2,   -- INVSLOT_NECK
    3,   -- INVSLOT_SHOULDER
    5,   -- INVSLOT_CHEST
    6,   -- INVSLOT_WAIST
    7,   -- INVSLOT_LEGS
    8,   -- INVSLOT_FEET
    9,   -- INVSLOT_WRIST
    10,  -- INVSLOT_HAND
    11,  -- INVSLOT_FINGER0
    12,  -- INVSLOT_FINGER1
    13,  -- INVSLOT_TRINKET0
    14,  -- INVSLOT_TRINKET1
    15,  -- INVSLOT_BACK
    16,  -- INVSLOT_MAINHAND
    17,  -- INVSLOT_OFFHAND
    18,  -- INVSLOT_RANGED
    19,  -- INVSLOT_TABARD
    4,   -- INVSLOT_BODY (shirt)
}

local RANGED_SLOT = 18
local MAINHAND_SLOT = 16
local OFFHAND_SLOT  = 17

----------------------------------------------------------------------
-- Forgiveness: allowed violations based on overall completion %
----------------------------------------------------------------------

local function getAllowedViolations()
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

-- Slot exclusions for Self-made variants.
-- "Self-made armor": skip jewelry, cloak, and weapons
local SKIP_SELF_MADE = {
    [2]  = true,   -- NECK
    [11] = true,   -- FINGER0
    [12] = true,   -- FINGER1
    [13] = true,   -- TRINKET0
    [14] = true,   -- TRINKET1
    [15] = true,   -- BACK (cloak)
}

--- Check if the item in a given slot is a shield.
--- Uses GetItemInfo subType or itemEquipLoc to identify shields.
local function IsShieldInSlot(slotID)
    if slotID ~= 17 then return false end  -- only off-hand slot can have shields
    local itemID = GetInventoryItemID("player", slotID)
    if not itemID then return false end
    local _, _, _, _, _, _, itemSubType, _, itemEquipLoc = GetItemInfo(itemID)
    -- itemEquipLoc "INVTYPE_SHIELD" is the reliable check
    if itemEquipLoc == "INVTYPE_SHIELD" then return true end
    -- Fallback: check subType string (locale-dependent but catches edge cases)
    if itemSubType and itemSubType:lower():find("shield") then return true end
    return false
end

----------------------------------------------------------------------
-- Self-made item checking
----------------------------------------------------------------------

-- Hidden tooltip used to scan item tooltips for "Made by:" text.
-- Lazily initialized — SetOwner must happen each time we scan,
-- because calling it once at load time can fail if WorldFrame
-- isn't ready yet.
local scanTooltip = CreateFrame("GameTooltip", "HCE_SelfMadeScanTooltip", nil, "GameTooltipTemplate")

--- Scan an equipped item's tooltip for "Made by:" text.
--- @param slotID number  equipment slot to scan
--- @return string|nil crafterName  the crafter's name, or nil if not found
local function GetCrafterFromTooltip(slotID)
    scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    scanTooltip:ClearLines()
    scanTooltip:SetInventoryItem("player", slotID)
    local numLines = scanTooltip:NumLines()
    for i = 1, numLines do
        local line = _G["HCE_SelfMadeScanTooltipTextLeft" .. i]
        if line then
            local text = line:GetText()
            if text then
                -- WoW shows: <Made by PlayerName>
                -- Try with angle brackets first (most common format)
                local crafter = text:match("<Made by ([^>]+)>")
                if crafter then return crafter end
                -- Without angle brackets fallback
                crafter = text:match("Made by (.+)")
                if crafter then return crafter end
            end
        end
    end
    return nil
end

--- DEBUG: Print all tooltip lines for every equipped item.
--- Call via /fce debugtooltip
function SF.DebugTooltips()
    FCE.Print("|cffffd100=== Tooltip Debug ===|r")
    for _, slotID in ipairs(SLOT_IDS) do
        local itemID = GetInventoryItemID("player", slotID)
        if itemID then
            local itemName = GetItemInfo(itemID) or ("item:" .. itemID)
            scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
            scanTooltip:ClearLines()
            scanTooltip:SetInventoryItem("player", slotID)
            local numLines = scanTooltip:NumLines()
            FCE.Print("Slot " .. slotID .. " [" .. itemName .. "] — " .. numLines .. " lines:")
            for i = 1, numLines do
                local lineObj = _G["HCE_SelfMadeScanTooltipTextLeft" .. i]
                local text = lineObj and lineObj:GetText() or "<nil>"
                FCE.Print("  L" .. i .. ": " .. tostring(text))
            end
        end
    end
end

--- Check a single equipped item against the self-made rules.
--- An item passes if it is:
---   (a) white (Common, quality=1) or grey (Poor, quality=0), OR
---   (b) has "Made by:" in its tooltip (confirmed player-crafted), OR
---   (c) falls back to the crafted_items list from ItemSourceData.lua
---
--- @param itemID number
--- @param slotID number  the equipment slot (for tooltip scanning)
--- @return string status
--- @return string detail
local function CheckSelfMadeItem(itemID, slotID)
    if not itemID then
        return PASS, "Empty slot"
    end

    local itemName, _, itemQuality = GetItemInfo(itemID)
    if not itemName then
        -- Item not cached yet; can't verify
        return UNCHECKED, "Item " .. itemID .. " not in cache"
    end

    -- White or grey quality always passes (no restrictions)
    if itemQuality <= 1 then
        return PASS, itemName .. " — quality " .. itemQuality .. " (white/grey, always OK)"
    end

    -- Primary check: scan tooltip for "Made by: <your character>"
    -- The item must have been crafted by the player themselves
    if slotID then
        local crafter = GetCrafterFromTooltip(slotID)
        if crafter then
            local myName = UnitName("player")
            if crafter == myName then
                return PASS, itemName .. " — self-made (Made by " .. crafter .. ")"
            else
                return FAIL, itemName .. " — crafted by " .. crafter .. ", not by you"
            end
        end
    end

    -- No "Made by" text at all — not a crafted item
    return FAIL, itemName .. " (quality " .. itemQuality .. ") — not crafted (no 'Made by' found)"
end

--- Check the ranged slot specifically for a self-made Engineering gun.
--- @return string status
--- @return string detail
local function CheckSelfMadeGun()
    local itemID = GetInventoryItemID("player", RANGED_SLOT)
    if not itemID then
        return PASS, "No ranged weapon equipped"
    end

    local itemName, _, itemQuality = GetItemInfo(itemID)
    if not itemName then
        return UNCHECKED, "Ranged item " .. itemID .. " not in cache"
    end

    -- White/grey guns are fine (same as general self-made rule)
    if itemQuality <= 1 then
        return PASS, itemName .. " — quality " .. itemQuality .. " (white/grey, always OK)"
    end

    do
        local crafter = GetCrafterFromTooltip(RANGED_SLOT)
        if crafter then
            local myName = UnitName("player")
            if crafter == myName then
                return PASS, itemName .. " — self-made (Made by " .. crafter .. ")"
            else
                return FAIL, itemName .. " — crafted by " .. crafter .. ", not by you"
            end
        end
    end

    -- No "Made by" text at all — not a crafted item
    return FAIL, itemName .. " (quality " .. itemQuality .. ") — not crafted (no 'Made by' found)"
end

----------------------------------------------------------------------
-- Full check
----------------------------------------------------------------------

--- Run all self-found / self-made checks for the current character.
--- @return table results  { selfFound = {status, detail},
---                          selfMade  = {status, detail, items = {...}},
---                          selfMadeGuns = {status, detail} }
function SF.CheckAll()
    local results = {}
    if not FCE_CharDB then return results end

    local key = FCE_CharDB.selectedCharacter
    local char = key and FCE.GetCharacter and FCE.GetCharacter(key) or nil
    if not char then return results end

    -- Resolve faction-aware selfFound value (can't use "and/or" — false is a valid result)
    local charSelfFound
    if FCE.GetCharSelfFound then charSelfFound = FCE.GetCharSelfFound(char) else charSelfFound = char.selfFound end

    -- 1a. Self-found buff check (only if character requires it AND player chose self-found)
    if charSelfFound then
        local sfEnabled = not FCE.SelfFoundEnabled or FCE.SelfFoundEnabled()
        if sfEnabled then
            local status, detail = CheckSelfFoundBuff()
            results.selfFound = { status = status, detail = detail }
        else
            results.selfFound = { status = PASS, detail = "Self-found not selected during class setup." }
        end
    end

    -- 1b. NOT self-found check — character requires trading/AH access
    --     (selfFound == false means the player must NOT be on Self-Found)
    if charSelfFound == false then
        local sfEnabled = not FCE.SelfFoundEnabled or FCE.SelfFoundEnabled()
        if sfEnabled then
            local status, detail = CheckSelfFoundBuff()
            if status == PASS then
                -- They have the buff but shouldn't
                results.notSelfFound = {
                    status = FAIL,
                    detail = "Self-Found buff detected — this character requires AH/trade access",
                }
            elseif status == FAIL then
                -- No buff — good, they can trade
                results.notSelfFound = {
                    status = PASS,
                    detail = "Not self-found — AH/trade access confirmed",
                }
            else
                results.notSelfFound = { status = UNCHECKED, detail = detail }
            end
        else
            results.notSelfFound = { status = PASS, detail = "Self-found not selected during class setup." }
        end
    end

    local SELF_MADE_VARIANTS = {
        ["Self-made"]               = SKIP_SELF_MADE,              -- nil = no skips
    }

    local hasSelfMadeGuns = false
    local selfMadeKey = nil
    local selfMadeSkip = nil
    local activeChallenges = FCE.GetActiveChallenges and FCE.GetActiveChallenges(char) or char.challenges or {}
    for _, ch in ipairs(activeChallenges) do
        if SELF_MADE_VARIANTS[ch.desc] ~= nil or ch.desc == "Self-made" then
            selfMadeKey = ch.desc
            selfMadeSkip = SELF_MADE_VARIANTS[ch.desc]
        end
        if ch.desc == "Self-made guns" then hasSelfMadeGuns = true end
    end

    if selfMadeKey then
        -- Check equipment slots, skipping excluded ones
        local itemResults = {}
        local overallStatus = PASS
        local failCount = 0
        local uncheckCount = 0

        for _, slotID in ipairs(SLOT_IDS) do
            if not (selfMadeSkip and selfMadeSkip[slotID]) then
                local itemID = GetInventoryItemID("player", slotID)
                if itemID then
                    local status, detail = CheckSelfMadeItem(itemID, slotID)
                    table.insert(itemResults, {
                        slot   = slotID,
                        itemID = itemID,
                        status = status,
                        detail = detail,
                    })
                    if status == FAIL then
                        failCount = failCount + 1
                        overallStatus = FAIL
                    elseif status == UNCHECKED and overallStatus ~= FAIL then
                        uncheckCount = uncheckCount + 1
                        overallStatus = UNCHECKED
                    end
                end
            end
        end

        -- Always-exempt items (e.g. guild tabard, unique quest rewards)
        -- Run BEFORE forgiveness so they don't consume a forgiven slot
        for _, item in ipairs(itemResults) do
            if item.status == FAIL and (item.itemID == 8708 or item.itemID == 6953) then
                item.status = PASS
                item.detail = item.detail .. " (exempt)"
                failCount = failCount - 1
            end
        end
        if failCount <= 0 then
            failCount = 0
            overallStatus = PASS
        end

        -- Apply forgiveness based on rank progression
        -- Warriors and Paladins cannot use exemptions on weapon slots
        local allowed = getAllowedViolations()
        local actualForgiven = 0
        local totalViolations = failCount
        if allowed > 0 and failCount > 0 then
            local _, classToken = UnitClass("player")
            local weaponLocked = (classToken == "WARRIOR" or classToken == "PALADIN")

            -- Count forgivable vs unforgivable failures
            local forgivable = 0
            local unforgivable = 0
            for _, item in ipairs(itemResults) do
                if item.status == FAIL then
                    local isUnforgivableWeapon = weaponLocked
                        and (item.slot == MAINHAND_SLOT or (item.slot == OFFHAND_SLOT and not IsShieldInSlot(OFFHAND_SLOT)))
                    if isUnforgivableWeapon then
                        unforgivable = unforgivable + 1
                    else
                        forgivable = forgivable + 1
                    end
                end
            end
            actualForgiven = math.min(forgivable, allowed)
            local remaining = unforgivable + (forgivable - actualForgiven)

            if remaining == 0 then
                overallStatus = PASS
            end
            failCount = remaining

            -- Update detail on forgiven items (mark first N forgivable as forgiven)
            if actualForgiven > 0 then
                local count = 0
                for _, item in ipairs(itemResults) do
                    if item.status == FAIL then
                        local isUnforgivableWpn = (item.slot == MAINHAND_SLOT or (item.slot == OFFHAND_SLOT and not IsShieldInSlot(OFFHAND_SLOT)))
                        if not (weaponLocked and isUnforgivableWpn) then
                            count = count + 1
                            if count <= actualForgiven then
                                item.status = PASS
                                item.detail = item.detail .. " (forgiven)"
                            end
                        end
                    end
                end
            end
        end

        local summary
        if overallStatus == PASS and actualForgiven > 0 then
            summary = "Self-made — " .. actualForgiven .. " item" .. (actualForgiven > 1 and "s" or "")
                .. " exempt (" .. allowed .. " allowed at current rank)"
        elseif overallStatus == PASS and allowed > 0 then
            summary = "Wearing 0 non-self-made items despite having " .. allowed .. " exemption(s)."
        elseif overallStatus == PASS then
            summary = "All checked items are self-made or white/grey"
        elseif overallStatus == FAIL then
            summary = totalViolations .. " item" .. (totalViolations == 1 and "" or "s") .. " not self-made"
            if actualForgiven > 0 then
                summary = summary .. " (" .. actualForgiven .. " exempt, " .. failCount .. " over limit)"
            end
        else
            summary = uncheckCount .. " item" .. (uncheckCount == 1 and "" or "s") .. " could not be verified"
        end

        results.selfMade = {
            status = overallStatus,
            detail = summary,
            items  = itemResults,
            key    = selfMadeKey,
        }
    end

    if hasSelfMadeGuns then
        local status, detail = CheckSelfMadeGun()
        results.selfMadeGuns = { status = status, detail = detail }
    end

    return results
end

--- Run a full check and store results in SavedVariables.
function SF.RunCheck()
    local results = SF.CheckAll()
    if FCE_CharDB then
        FCE_CharDB.selfFoundResults = results
    end
    return results
end

--- Get stored results from the last check.
function SF.GetResults()
    return FCE_CharDB and FCE_CharDB.selfFoundResults or {}
end

----------------------------------------------------------------------
-- Chat warnings (one-shot per session)
----------------------------------------------------------------------

local CHAT_PREFIX = "|cffe6b422[FCE]|r "

local warnedSelfFound    = false
local warnedNotSelfFound = false
local warnedSelfMade     = false
local warnedSelfMadeGuns = false

--- Run checks and fire chat warnings for new problems.
function SF.CheckAndWarn()
    local oldResults = SF.GetResults()

    -- Snapshot old statuses
    local oldSF   = oldResults.selfFound and oldResults.selfFound.status
    local oldSM   = oldResults.selfMade and oldResults.selfMade.status
    local oldSMG  = oldResults.selfMadeGuns and oldResults.selfMadeGuns.status

    local newResults = SF.RunCheck()

    -- Self-found buff warning
    if newResults.selfFound and newResults.selfFound.status == FAIL and not warnedSelfFound then
        DEFAULT_CHAT_FRAME:AddMessage(
            CHAT_PREFIX .. "|cffffaa33Self-Found buff not detected.|r " ..
            "Re-select your class to change self-found mode."
        )
        warnedSelfFound = true
    elseif newResults.selfFound and newResults.selfFound.status == PASS then
        warnedSelfFound = false
    end

    -- Not-self-found warning (character must NOT be self-found)
    if newResults.notSelfFound and newResults.notSelfFound.status == FAIL and not warnedNotSelfFound then
        DEFAULT_CHAT_FRAME:AddMessage(
            CHAT_PREFIX .. "|cffffaa33Warning:|r This character requires AH/trade access. " ..
            "You are on a Self-Found realm — this character cannot be played self-found."
        )
        warnedNotSelfFound = true
    elseif newResults.notSelfFound and newResults.notSelfFound.status == PASS then
        warnedNotSelfFound = false
    end

    -- Self-made challenge warning
    if newResults.selfMade and newResults.selfMade.status == FAIL and not warnedSelfMade then
        DEFAULT_CHAT_FRAME:AddMessage(
            CHAT_PREFIX .. "|cffffaa33Self-made violation:|r " ..
            (newResults.selfMade.detail or "Some equipped items are not crafted or white/grey")
        )
        warnedSelfMade = true
    elseif newResults.selfMade and newResults.selfMade.status == PASS then
        warnedSelfMade = false
    end

    -- Self-made guns warning
    if newResults.selfMadeGuns and newResults.selfMadeGuns.status == FAIL and not warnedSelfMadeGuns then
        DEFAULT_CHAT_FRAME:AddMessage(
            CHAT_PREFIX .. "|cffffaa33Self-made guns violation:|r " ..
            (newResults.selfMadeGuns.detail or "Ranged weapon is not Engineering-crafted")
        )
        warnedSelfMadeGuns = true
    elseif newResults.selfMadeGuns and newResults.selfMadeGuns.status == PASS then
        warnedSelfMadeGuns = false
    end

    -- Refresh the panel to show updated indicators
    if FCE.RefreshPanel then FCE.RefreshPanel() end
end

--- Reset one-shot warning state.  Called when a new character is
--- selected so stale warnings from a previous pick don't block.
function SF.ResetWarnings()
    warnedSelfFound    = false
    warnedNotSelfFound = false
    warnedSelfMade     = false
    warnedSelfMadeGuns = false
end

----------------------------------------------------------------------
-- Slash command: /fce selffound
----------------------------------------------------------------------

function SF.PrintStatus()
    if not FCE_CharDB or not FCE_CharDB.selectedCharacter then
        FCE.Print("No enhanced class selected. Type |cffffd100/fce pick|r to choose one.")
        return
    end

    local char = FCE.GetCharacter(FCE_CharDB.selectedCharacter)
    if not char then
        FCE.Print("Character data not found.")
        return
    end

    FCE.Print("Self-Found / Self-Made status:")

    local results = SF.RunCheck()

    -- Self-found buff
    local charSelfFound2
    if FCE.GetCharSelfFound then charSelfFound2 = FCE.GetCharSelfFound(char) else charSelfFound2 = char.selfFound end
    if charSelfFound2 then
        local r = results.selfFound
        if r then
            local tag
            if r.status == PASS then
                tag = "|cff00ff00ACTIVE|r"
            elseif r.status == FAIL then
                tag = "|cffff5555NOT FOUND|r"
            else
                tag = "|cffffaa33???|r"
            end
            FCE.Print("  Self-Found buff: " .. tag .. " — " .. (r.detail or ""))
        else
            FCE.Print("  Self-Found buff: |cff888888no data|r")
        end
    elseif charSelfFound2 == false then
        local r = results.notSelfFound
        if r then
            local tag
            if r.status == PASS then
                tag = "|cff00ff00OK|r"
            elseif r.status == FAIL then
                tag = "|cffff5555VIOLATION|r"
            else
                tag = "|cffffaa33???|r"
            end
            FCE.Print("  Not Self-Found: " .. tag .. " — " .. (r.detail or ""))
        else
            FCE.Print("  Not Self-Found: |cff888888no data|r")
        end
    else
        FCE.Print("  Self-Found: not required for this character")
    end

    -- Self-made challenge
    if results.selfMade then
        local r = results.selfMade
        local tag
        if r.status == PASS then
            tag = "|cff00ff00OK|r"
        elseif r.status == FAIL then
            tag = "|cffff5555VIOLATION|r"
        else
            tag = "|cffffaa33PARTIAL|r"
        end
        FCE.Print("  Self-made: " .. tag .. " — " .. (r.detail or ""))

        -- Show per-item breakdown if any failures
        if r.items then
            for _, item in ipairs(r.items) do
                if item.status ~= PASS then
                    local itemTag = item.status == FAIL and "|cffff5555FAIL|r" or "|cffffaa33?|r"
                    FCE.Print("    Slot " .. item.slot .. ": " .. itemTag .. " " .. (item.detail or ""))
                end
            end
        end
    end

    -- Self-made guns
    if results.selfMadeGuns then
        local r = results.selfMadeGuns
        local tag
        if r.status == PASS then
            tag = "|cff00ff00OK|r"
        elseif r.status == FAIL then
            tag = "|cffff5555VIOLATION|r"
        else
            tag = "|cffffaa33???|r"
        end
        FCE.Print("  Self-made guns: " .. tag .. " — " .. (r.detail or ""))
    end
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("UNIT_AURA")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")

local initialCheckDone = false

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        -- Defer so SavedVariables and CharacterData are ready
        C_Timer.After(3.0, function()
            SF.RunCheck()
            initialCheckDone = true
            if FCE.RefreshPanel then FCE.RefreshPanel() end
        end)
        -- Second pass to fire warnings after everything settled
        C_Timer.After(6.0, function()
            SF.CheckAndWarn()
        end)

    elseif event == "UNIT_AURA" then
        local unit = ...
        if unit ~= "player" then return end
        if not initialCheckDone then return end
        -- Re-check self-found buff when auras change
        C_Timer.After(0.3, function()
            SF.CheckAndWarn()
        end)

    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        if not initialCheckDone then return end
        -- Re-check self-made items when gear changes
        C_Timer.After(0.5, function()
            SF.CheckAndWarn()
        end)

    elseif event == "PLAYER_LEVEL_UP" then
        if not initialCheckDone then return end
        C_Timer.After(0.5, function()
            SF.CheckAndWarn()
        end)
    end
end)
