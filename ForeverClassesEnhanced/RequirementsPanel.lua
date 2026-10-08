----------------------------------------------------------------------
-- ForeverClassesEnhanced — Requirements Panel
--
-- A persistent, dockable panel that shows the selected enhanced
-- class's full requirement list, with level-gated items greyed out
-- and currently-active items lit up.
--
-- Opens via:
--   * /fce panel  (toggle)
--   * /fce req    (toggle, alias)
--   * the draggable minimap button
--
-- Auto-refreshes on PLAYER_LEVEL_UP and when the selection changes.
--
-- Layout:
--   +------------------------------------------+
--   | Mountain King               [ pin ] [X]  |
--   |  Protection Warrior · lv 14 / 60         |
--   |------------------------------------------|
--   |  3 / 7 requirements active               |
--   |------------------------------------------|
--   |  EQUIPMENT                               |
--   |  [ACTIVE] Mace or axe                    |
--   |  [lv 5]   Shield                         |
--   |  [lv 50]  Flask trinkets                 |
--   |                                          |
--   |  CHALLENGES                              |
--   |  [ACTIVE] No professions                 |
--   |  [lv 20]  Homebound                      |
--   |      Can't leave home continent          |
--   |                                          |
--   |  COMPANION · PET · MOUNT                 |
--   |  ...                                     |
--   +------------------------------------------+
----------------------------------------------------------------------


local UnitBuff
    = FCE.Compat.UnitBuff  -- Forever API shims (ForeverCompat.lua)
FCE = FCE or {}

local Panel = {}
FCE.Panel   = Panel

----------------------------------------------------------------------
-- Constants / visual config
----------------------------------------------------------------------

local FRAME_WIDTH   = 320
local FRAME_HEIGHT  = 440
local ROW_HEIGHT    = 16
local SECTION_GAP   = 8
local PAD_X         = 14
local PAD_Y         = 10

local COLOR_ACTIVE   = { r = 1.00, g = 0.82, b = 0.00 }
local COLOR_INACTIVE = { r = 0.55, g = 0.55, b = 0.55 }
local COLOR_HEADER   = { r = 1.00, g = 0.78, b = 0.10 }
local COLOR_SUBTXT   = { r = 0.75, g = 0.75, b = 0.75 }
local COLOR_PASS     = { r = 0.30, g = 0.90, b = 0.35 }   -- green checkmark
local COLOR_FAIL     = { r = 1.00, g = 0.35, b = 0.30 }   -- red cross
local COLOR_UNCHK    = { r = 0.65, g = 0.65, b = 0.50 }   -- muted amber

local CLASS_COLORS = {
    WARRIOR = "c79c6e", ROGUE   = "fff569", MAGE    = "69ccf0",
    WARLOCK = "9482c9", PRIEST  = "ffffff", PALADIN = "f58cba",
    DRUID   = "ff7d0a", SHAMAN  = "0070de", HUNTER  = "abd473",
}

local function classColor(c)
    return CLASS_COLORS[c or ""] or "ffd100"
end

local function titleCase(s)
    if not s or s == "" then return "" end
    return s:sub(1, 1):upper() .. s:sub(2):lower()
end

-- Returns nil (white/default) when active, COLOR_INACTIVE when not.
-- Can't use "active and nil or COLOR_INACTIVE" because nil is falsy in Lua.
local function activeTextColor(isActive)
    if isActive then return nil end
    return COLOR_INACTIVE
end

----------------------------------------------------------------------
-- Global DB defaults for panel persistence
----------------------------------------------------------------------

local function db()
    FCE_GlobalDB = FCE_GlobalDB or {}
    FCE_GlobalDB.panel = FCE_GlobalDB.panel or {
        shown       = false,     -- visible on login if true
        locked      = false,     -- lock position (disables drag)
        point       = "CENTER",
        relPoint    = "CENTER",
        x           = 0,
        y           = 0,
        minimap     = { angle = 215, hide = false },
    }
    return FCE_GlobalDB.panel
end

----------------------------------------------------------------------
-- Main frame
----------------------------------------------------------------------

local frame          -- the panel itself
local contentFrame   -- child holding the row fontstrings (scroll child)
local scrollFrame
local rowPool = {}
local headerLabel, subLabel
local pinButton
local closeButton
local miniFrame      -- compact side panel (minimize view)

local function acquireRow(index)
    local row = rowPool[index]
    if row then return row end

    row = CreateFrame("Frame", nil, contentFrame)
    row:SetFrameLevel(contentFrame:GetFrameLevel() + 2)  -- Mac: explicit level for hit testing
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("LEFT", contentFrame, "LEFT", 0, 0)
    row:SetPoint("RIGHT", contentFrame, "RIGHT", 0, 0)
    row:EnableMouse(true)

    row.tag = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.tag:SetPoint("TOPLEFT", row, "TOPLEFT", 2, 0)
    row.tag:SetWidth(50)
    row.tag:SetJustifyH("LEFT")

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("TOPLEFT", row.tag, "TOPRIGHT", 2, 0)
    row.text:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(true)

    -- Hover highlight for interactive rows (manually shown/hidden via
    -- OnEnter/OnLeave — we use ARTWORK not HIGHLIGHT so WoW doesn't
    -- auto-show it on every mouse-enabled row)
    row.highlight = row:CreateTexture(nil, "ARTWORK", nil, 7)
    row.highlight:SetColorTexture(0.92, 0.82, 0.58, 0.08)
    row.highlight:SetAllPoints()
    row.highlight:Hide()

    rowPool[index] = row
    return row
end

local function clearRowTooltip(row)
    row.challengeKey = nil
    row.challengeLevel = nil
    row.challengeActive = nil
    row.equipDetail = nil
    row.equipStatus = nil
    row.curatedKey = nil
    row.companionKey = nil
    row.hunterPetKey = nil
    row.selfFoundTip = nil
    row.highlight:Hide()
    row:SetScript("OnEnter", nil)
    row:SetScript("OnLeave", nil)
end

local function releaseExtraRows(used)
    for i = used + 1, #rowPool do
        clearRowTooltip(rowPool[i])
        rowPool[i]:Hide()
    end
end

----------------------------------------------------------------------
-- Tooltip for challenge rows
----------------------------------------------------------------------

-- Challenges that get item forgiveness at rank milestones
local FORGIVABLE_TOOLTIP = {
    ["Exotic"]        = true,
    ["Scout"]         = true,
    ["Scavenger"]     = true,
    ["Partisan"]      = true,
    ["Self-made"]     = true,
    ["Cloth/leather"] = true,
    ["Leather/mail"]  = true,
    ["Mail/plate"]    = true,
    ["Expeditionary"]    = true,
}

-- Reputation-based challenges — displayed in their own section
local REPUTATION_RULES = {
    ["Faction Loyalist"]    = true,
    ["Purifier"]            = true,
    ["Keeper"]              = true,
    ["Smith"]               = true,
    ["Avenger"]             = true,
    ["Cult of the Damned"]  = true,
    ["Twilight's Hammer"]   = true,
    ["Shadow Council"]      = true,
    ["Old Horde"]           = true,
    ["Diplomat"]            = true,
}

local PERMA_CHALLENGE_TOOLTIP = {
    ["No nonsense"]        = true,
    ["Imp"]         = true,
    ["Voidwalker"]     = true,
    ["Lone Wolf"]      = true,
    ["No demons"]     = true,
    ["Ephemeral"] = true,
    ["Drifter"]  = true,
    ["Mortal pets"]    = true,
    ["Pyromancer"]  = true,
    ["Light of Elune"]  = true,
    ["All-out Assault"]  = true,
    ["Truecaster"]  = true,
    ["Windfury Weapon"]  = true,
    ["Rockbiter Weapon"]  = true,
    ["Crude"]  = true,
    ["Overt"]  = true,
    ["Shadow Ascendant"]  = true,
    ["Self-taught"]  = true,
}

-- Get the player's current rank name, hex color, and number of allowed violations.
local function getCurrentRankAndAllowed()
    if not FCE.Progress or not FCE.Progress.Collect or not FCE.Progress.Percentage or not FCE.Progress.GetRank then
        return "Initiate", "ffffff", 0
    end
    local summary = FCE.Progress.Collect()
    if not summary or not summary.counts then return "Initiate", "ffffff", 0 end
    local pct = FCE.Progress.Percentage(summary.counts)
    local rank, color = FCE.Progress.GetRank(pct)
    local allowed = 0
    if pct >= 100 then allowed = 999
    elseif pct >= 75 then allowed = 3
    elseif pct >= 50 then allowed = 2
    elseif pct >= 25 then allowed = 1
    end
    return rank, color, allowed
end

local function onChallengeRowEnter(self)
    local key = self.challengeKey
    if not key then return end
    local desc = FCE.ChallengeDescriptions and FCE.ChallengeDescriptions[key]
    if not desc then return end

    self.highlight:Show()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 20, 0)
    GameTooltip:ClearLines()

    -- Title line in gold
    GameTooltip:AddLine(key, 0.85, 0.70, 0.20)

    -- Status line
    if self.challengeActive then
        GameTooltip:AddLine("ACTIVE", 1.00, 0.82, 0.00)
    else
        GameTooltip:AddLine("Unlocks at level " .. tostring(self.challengeLevel or "?"), 0.55, 0.55, 0.55)
    end

    -- Separator
    GameTooltip:AddLine(" ")

    -- Full description, wrapped
    GameTooltip:AddLine(desc, 0.93, 0.93, 0.93, true)

    -- More info on Expeditionary
    if key == "Expeditionary" then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Group content items include dungeon boss drops and rewards from elite & dungeon quests.", 0.93, 0.93, 0.93, true)
    end

    -- Faction Loyalist: show scaling tiers
    if key == "Faction Loyalist" then
        local playerLevel = UnitLevel("player") or 1
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Required standing by level:", 0.85, 0.70, 0.20)
        local tiers = {
            { label = "Friendly",  from = 1,  to = 24 },
            { label = "Honored",   from = 25, to = 49 },
            { label = "Revered",   from = 50, to = 60 },
        }
        for _, t in ipairs(tiers) do
            local tag = "lv " .. t.from .. "-" .. t.to
            if playerLevel >= t.from and playerLevel <= t.to then
                GameTooltip:AddDoubleLine("> " .. t.label, tag, 1, 1, 1, 1, 0.82, 0)
            else
                GameTooltip:AddDoubleLine("  " .. t.label, tag, 0.45, 0.45, 0.45, 0.45, 0.45, 0.45)
            end
        end
    end

    -- Seeking a Pardon: show faction-specific quest and violation count
    if key == "Seeking a Pardon" then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("No quests may be completed until the pardon quest is done.", 1, 0.3, 0.3, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Pardon quest by faction:", 0.85, 0.70, 0.20)
        local faction = UnitFactionGroup("player")
        local quests = {
            { faction = "Horde",    name = "Wanted: Maggot Eye (quest #398)" },
            { faction = "Alliance", name = "Wanted: \"Hogger\" (quest #176)" },
        }
        for _, q in ipairs(quests) do
            if q.faction == faction then
                GameTooltip:AddLine("> " .. q.faction .. ": " .. q.name, 1, 1, 1)
            else
                GameTooltip:AddLine("  " .. q.faction .. ": " .. q.name, 0.45, 0.45, 0.45)
            end
        end
        local db = FCE_CharDB and FCE_CharDB.eventChallenges
        local violations = db and db.seekingPardonViolations or 0
        if violations > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(violations .. " violation(s) — quests turned in before pardon", 1, 0.3, 0.3)
        end
    end

    -- Master Trainer: show which pet abilities have been detected
    if key == "Master Trainer" then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Required pet abilities:", 0.85, 0.70, 0.20)
        local db = FCE_CharDB and FCE_CharDB.eventChallenges
        local spells = {
            { id = 17261, name = "Bite Rank 8" },
            { id = 24597, name = "Furious Howl Rank 4" },
        }
        for _, s in ipairs(spells) do
            local done = db and db.masterTrainerSpells and db.masterTrainerSpells[s.id]
            if done then
                GameTooltip:AddLine("  " .. s.name, 0, 1, 0)
            else
                GameTooltip:AddLine("  " .. s.name, 0.6, 0.6, 0.6)
            end
        end
    end

    -- Voodoo Ritual: list cursed items
    if key == "Voodoo Ritual" then
        local list = FCE.CuratedItems and FCE.CuratedItems.cursed_items
        if list and next(list) then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Cursed Items:", 0.6, 0.2, 0.8)
            local order = list._order
            local ids = order or {}
            if not order then
                for k in pairs(list) do if k ~= "_order" then ids[#ids + 1] = k end end
            end
            for _, id in ipairs(ids) do
                local desc = list[id]
                if type(desc) == "string" then
                    local found = false
                    for slot = 1, 19 do
                        if GetInventoryItemID("player", slot) == id then
                            found = true
                            break
                        end
                    end
                    if found then
                        GameTooltip:AddLine("  " .. desc, 0, 1, 0, true)
                    else
                        GameTooltip:AddLine("  " .. desc, 0.6, 0.6, 0.6, true)
                    end
                end
            end
        end
    end

    -- Disease Cleansing: show progress, mandatory diseases, cure items
    if key == "Disease Cleansing" then
        if FCE.EventChallenges and FCE.EventChallenges.GetCleanseInfo then
            local _, required, effective, total, hasSilithid, hasCadaver =
                FCE.EventChallenges.GetCleanseInfo()
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Progress: " .. effective .. "/" .. required
                .. "  (total cures: " .. total .. ")", 1, 0.82, 0)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Diseases cleansed must include:", 0.55, 0.8, 0.55)
            local sR, sG, sB = 0.6, 0.6, 0.6
            if hasSilithid then sR, sG, sB = 0, 1, 0 end
            GameTooltip:AddLine("  Silithid Pox", sR, sG, sB, true)
            local cR, cG, cB = 0.6, 0.6, 0.6
            if hasCadaver then cR, cG, cB = 0, 1, 0 end
            GameTooltip:AddLine("  Cadaver Worms", cR, cG, cB, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Cure Items:", 0.55, 0.8, 0.55)
            GameTooltip:AddLine("  Jungle Remedy", 0.6, 0.6, 0.6, true)
            GameTooltip:AddLine("  Restorative Potion", 0.6, 0.6, 0.6, true)
        end
    end

    -- Forgiveness info for eligible challenges
    if FORGIVABLE_TOOLTIP[key] then
        local curRank = getCurrentRankAndAllowed()
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Rank rewards:", 0.85, 0.70, 0.20)

        -- Tier table — highlight the player's current rank, dim the rest
        local tiers = {
            { rank = "Adept",  label = "Adept (25%)",   reward = "1 exemption",    r = 0.12, g = 1.0,  b = 0.0  },
            { rank = "Prime",  label = "Prime (50%)",   reward = "2 exemptions",   r = 0.0,  g = 0.44, b = 0.87 },
            { rank = "Elite",  label = "Elite (75%)",   reward = "3 exemptions",   r = 0.64, g = 0.21, b = 0.93 },
            { rank = "Master", label = "Master (100%)", reward = "All items exempt", r = 1.0,  g = 0.50, b = 0.0  },
        }
        for _, t in ipairs(tiers) do
            if t.rank == curRank then
                -- Current rank: bright colors + arrow marker
                GameTooltip:AddDoubleLine("> " .. t.label, t.reward, t.r, t.g, t.b, 1.0, 1.0, 1.0)
            else
                -- Other ranks: dimmed
                GameTooltip:AddDoubleLine("  " .. t.label, t.reward, 0.45, 0.45, 0.45, 0.45, 0.45, 0.45)
            end
        end

        -- Warrior/Paladin weapon restriction warning for Self-made
        if key == "Self-made" then
            local _, classToken = UnitClass("player")
            if classToken == "WARRIOR" or classToken == "PALADIN" then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Exemptions cannot be used on weapons.", 1.0, 0.3, 0.3, true)
            end
        end

        -- Shoulder restriction warning for armor-type challenges
        if key == "Cloth/leather" or key == "Leather/mail" or key == "Mail/plate" then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Exemptions cannot be used on shoulders.", 1.0, 0.3, 0.3, true)
        end
    end

    -- reset info for eligible challenges
    if PERMA_CHALLENGE_TOOLTIP[key] then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("You can always reset this challenge by typing '/fce reset' in the chat.")
    end

    GameTooltip:Show()
end

local function onChallengeRowLeave(self)
    self.highlight:Hide()
    GameTooltip:Hide()
end

----------------------------------------------------------------------
-- Tooltip for equipment check rows
----------------------------------------------------------------------

local function onEquipRowEnter(self)
    local detail = self.equipDetail
    if not detail then return end

    self.highlight:Show()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 8, 0)
    GameTooltip:ClearLines()

    local eqStatus = FCE.EquipmentCheck and FCE.EquipmentCheck.STATUS or {}
    if self.equipStatus == eqStatus.PASS then
        GameTooltip:AddLine("Requirement met", 0.30, 0.90, 0.35)
    elseif self.equipStatus == eqStatus.FAIL then
        GameTooltip:AddLine("Requirement not met", 1.00, 0.35, 0.30)
    else
        GameTooltip:AddLine("Cannot verify yet", 0.65, 0.65, 0.50)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(detail, 0.93, 0.93, 0.93, true)

    -- Self-found hint
    if self.selfFoundTip then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Self-found mode is chosen during class selection on Hardcore realms. Re-select your class to change this.", 0.55, 0.80, 0.95, true)
    end

    -- Show companion accepted creatures if this is a companion row
    if self.companionKey then
        local db = FCE.CompanionCheck and FCE.CompanionCheck.CompanionDB
        local entry = db and db[self.companionKey]
        if entry then
            GameTooltip:AddLine(" ")
            local names = {}
            if entry.creatureNames then
                for n in pairs(entry.creatureNames) do
                    table.insert(names, n)
                end
                table.sort(names)
            end
            if #names > 0 then
                GameTooltip:AddLine("Accepted companions (" .. #names .. "):", 0.90, 0.78, 0.25)
                for _, n in ipairs(names) do
                    GameTooltip:AddLine("  " .. n, 0.75, 0.75, 0.70)
                end
            end
            if entry.notes then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(entry.notes, 0.55, 0.80, 0.95, true)
            end
        end
    end

    -- Show hunter pet accepted creatures if this is a pet row
    if self.hunterPetKey then
        local db = FCE.HunterPetCheck and FCE.HunterPetCheck.PetDB
        local entry = db and db[self.hunterPetKey]
        if entry then
            if entry.creatureHints and #entry.creatureHints > 0 then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Tameable creatures (" .. #entry.creatureHints .. "):", 0.90, 0.78, 0.25)
                for _, name in ipairs(entry.creatureHints) do
                    GameTooltip:AddLine("  " .. name, 0.75, 0.75, 0.70)
                end
            end
            if entry.notes then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(entry.notes, 0.55, 0.80, 0.95, true)
            end
        end
    end

    -- Show curated approved items if this row has a curated list
    local curatedKey = self.curatedKey
    if curatedKey then
        -- Short summary overrides for large/generic lists
        local CURATED_SUMMARY = {
            fast_daggers = "Any dagger with 1.5 speed or faster",
        }
        local summary = CURATED_SUMMARY[curatedKey]
        if summary then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Approved items:", 0.90, 0.78, 0.25)
            GameTooltip:AddLine("  " .. summary, 0.75, 0.75, 0.70)
        else
            local items = FCE.CuratedItems and FCE.CuratedItems[curatedKey]
            if items then
                local count = 0
                for k in pairs(items) do if k ~= "_order" then count = count + 1 end end
                if count > 0 then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("Approved items (" .. count .. "):", 0.90, 0.78, 0.25)
                    local order = items._order
                    if order then
                        for _, itemID in ipairs(order) do
                            local note = items[itemID]
                            local displayName = type(note) == "string" and note or ("Item #" .. itemID)
                            GameTooltip:AddLine("  " .. displayName, 0.75, 0.75, 0.70)
                        end
                    else
                        for itemID, note in pairs(items) do
                            if itemID ~= "_order" then
                                local displayName = type(note) == "string" and note or ("Item #" .. itemID)
                                GameTooltip:AddLine("  " .. displayName, 0.75, 0.75, 0.70)
                            end
                        end
                    end
                end
            end
        end
    end

    GameTooltip:Show()
end

local function onEquipRowLeave(self)
    self.highlight:Hide()
    GameTooltip:Hide()
end

--- Tag a row as a challenge row so it shows a tooltip on hover.
--- Call this AFTER emitRow for the challenge.
local function tagChallengeRow(rowIndex, challengeKey, level, isActive)
    local row = rowPool[rowIndex]
    if not row then return end
    row.challengeKey    = challengeKey
    row.challengeLevel  = level
    row.challengeActive = isActive
    row:SetScript("OnEnter", onChallengeRowEnter)
    row:SetScript("OnLeave", onChallengeRowLeave)
end

----------------------------------------------------------------------
-- Row emitters
----------------------------------------------------------------------

-- returns a "tag" string and a tag color for a level-gated requirement
local function tagFor(level, playerLevel)
    if playerLevel >= level then
        return "ACTIVE", COLOR_ACTIVE
    else
        return "lv " .. level, COLOR_INACTIVE
    end
end

-- Universal requirement tag: checks PASS/FAIL for ALL requirements (active or not).
--   PASS (active or inactive) -> "PASS" green
--   FAIL + active             -> "FAIL" red
--   FAIL + inactive           -> "lv X" gray
--   unchecked + active        -> "ACTIVE" green
--   unchecked + inactive      -> "lv X" gray
-- Returns: tag, tagColor, textColor
local function reqTag(level, endLevel, playerLevel, status)
    local superseded = endLevel and playerLevel > endLevel
    local isActive = (playerLevel >= level) and not superseded

    -- Outleveled a ranged requirement → show as inactive (counts as PASS in progress)
    if superseded then
        return "lv " .. level .. "-" .. endLevel, COLOR_INACTIVE, COLOR_INACTIVE
    end

    -- Normalise: all checkers use lowercase "pass"/"fail"/"unchecked"
    local st = status and status:lower() or nil

    if st == "pass" then
        return "PASS", COLOR_PASS, nil
    elseif st == "fail" then
        if isActive then
            return "FAIL", COLOR_FAIL, nil
        end
        -- Failing + inactive: just the level, gray
        if endLevel then
            return "lv " .. level .. "-" .. endLevel, COLOR_INACTIVE, COLOR_INACTIVE
        end
        return "lv " .. level, COLOR_INACTIVE, COLOR_INACTIVE
    end

    -- No result or unchecked
    if isActive then
        return "ACTIVE", COLOR_ACTIVE, nil
    end
    if endLevel then
        return "lv " .. level .. "-" .. endLevel, COLOR_INACTIVE, COLOR_INACTIVE
    end
    return "lv " .. level, COLOR_INACTIVE, COLOR_INACTIVE
end

-- Emit a single-line row.  Returns the next row index and accumulated height used
local function emitRow(index, yOffset, tagText, tagColor, text, textColor, indent)
    local row = acquireRow(index)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", (indent or 0), -yOffset)
    row:SetPoint("RIGHT", contentFrame, "RIGHT", 0, 0)

    if tagText then
        row.tag:Show()
        row.tag:SetText(tagText)
        row.tag:SetTextColor(tagColor.r, tagColor.g, tagColor.b)
    else
        row.tag:Hide()
        row.tag:SetText("")
    end
    row.text:SetText(text or "")
    if textColor then
        row.text:SetTextColor(textColor.r, textColor.g, textColor.b)
    else
        row.text:SetTextColor(0.92, 0.87, 0.76)  -- warm parchment
    end

    row:Show()

    -- compute wrapped height so the next row lays out below the wrap
    local h = row.text:GetStringHeight()
    if h < ROW_HEIGHT then h = ROW_HEIGHT end
    row:SetHeight(h)

    return index + 1, yOffset + h + 2
end

local function emitSectionHeader(index, yOffset, title)
    yOffset = yOffset + SECTION_GAP
    local row = acquireRow(index)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -yOffset)
    row:SetPoint("RIGHT", contentFrame, "RIGHT", 0, 0)
    row:SetHeight(ROW_HEIGHT)

    row.tag:Hide()
    row.text:SetText(title)
    row.text:SetTextColor(COLOR_HEADER.r, COLOR_HEADER.g, COLOR_HEADER.b)
    row.text:ClearAllPoints()
    row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.text:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row:Show()

    local nextIdx = index + 1
    -- Gradient separator under the header (gold fading right)
    if not row.separator then
        row.separator = row:CreateTexture(nil, "ARTWORK")
        row.separator:SetTexture("Interface\\Buttons\\WHITE8x8")
        row.separator:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, -2)
        row.separator:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, -2)
        row.separator:SetHeight(1)
        row.separator:SetGradient("HORIZONTAL",
            CreateColor(1.0, 0.80, 0.45, 0.55),
            CreateColor(1.0, 0.80, 0.45, 0))
    end
    row.separator:Show()
    return nextIdx, yOffset + ROW_HEIGHT + 4
end

----------------------------------------------------------------------
-- Rebuild contents
----------------------------------------------------------------------

function Panel.Refresh()
    -- Always refresh mini panel if it's visible
    Panel.RefreshMini()

    if not frame or not frame:IsShown() then
        -- still update the header info so the next open is correct,
        -- but we don't need to rebuild rows while hidden
    end

    -- No frame yet? Nothing to do.
    if not frame then return end

    local key = FCE_CharDB and FCE_CharDB.selectedCharacter
    local char = key and FCE.GetCharacter and FCE.GetCharacter(key) or nil
    local playerLevel = UnitLevel("player") or 1
    local _, classToken = UnitClass("player")

    -- Reset row state that SectionHeader may have added, and clear
    -- tooltip data from previous layout (rows are pooled and reused)
    for _, row in ipairs(rowPool) do
        if row.separator then row.separator:Hide() end
        row.text:ClearAllPoints()
        row.text:SetPoint("TOPLEFT", row.tag, "TOPRIGHT", 4, 0)
        row.text:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        clearRowTooltip(row)
    end

    -- Header
    if char then
        local col = classColor(char.class)
        local displayName = FCE.GetCharDisplayName and FCE.GetCharDisplayName(char) or char.name
        headerLabel:SetText("|cff" .. col .. displayName .. "|r")
        subLabel:SetText(char.spec .. " " .. titleCase(char.class))
        -- Class icon from BROWSE_ICONS
        local browseIcon = FCE.BROWSE_ICONS and FCE.BROWSE_ICONS[displayName]
        if browseIcon and Panel._classIcon then
            Panel._classIcon:SetTexture(browseIcon)
            Panel._classIcon:Show()
            headerLabel:SetPoint("LEFT", Panel._classIcon, "RIGHT", 5, 0)
        elseif Panel._classIcon then
            Panel._classIcon:Hide()
            headerLabel:SetPoint("LEFT", Panel._classIcon:GetParent(), "LEFT", PAD_X, 0)
        end
        -- Art panel (docked to the left, full-opacity class portrait)
        if Panel._artFrame then
            local texPath = FCE.GetCharPortrait and FCE.GetCharPortrait(char)
            if not texPath then
                texPath = FCE.ClassBackgrounds and FCE.ClassBackgrounds[char.name]
            end
            if not texPath and FCE.GetCharDisplayName then
                texPath = FCE.ClassBackgrounds and FCE.ClassBackgrounds[FCE.GetCharDisplayName(char)]
            end
            if texPath then
                Panel._artTex:SetTexture(texPath)
                Panel._artFrame:Show()
            else
                Panel._artFrame:Hide()
            end
        end
    else
        headerLabel:SetText("|cffffd100No enhanced class selected|r")
        subLabel:SetText("Type |cffffd100/fce pick|r to choose one")
        if Panel._classIcon then
            Panel._classIcon:Hide()
            headerLabel:SetPoint("LEFT", Panel._classIcon:GetParent(), "LEFT", PAD_X, 0)
        end
        if Panel._artFrame then Panel._artFrame:Hide() end
    end

    -- Show/hide lore button (show if character has a lore entry)
    if Panel._loreButton then
        if char and FCE.LoreData and FCE.LoreData[char.name] then
            Panel._loreButton:Show()
        else
            Panel._loreButton:Hide()
        end
    end

    local index  = 1
    local yOff   = 0

    if not char then
        local row = acquireRow(index)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -6)
        row:SetPoint("RIGHT", contentFrame, "RIGHT", 0, 0)
        row:SetHeight(ROW_HEIGHT * 3)
        row.tag:Hide()
        row.text:SetText("Open the selection window with |cffffd100/fce ui|r to pick an enhanced class for this character.")
        row.text:SetTextColor(COLOR_SUBTXT.r, COLOR_SUBTXT.g, COLOR_SUBTXT.b)
        row:Show()
        releaseExtraRows(1)
        contentFrame:SetHeight(ROW_HEIGHT * 3 + 12)
        return
    end

    -- Compute completion % and rank using ProgressSummary
    local summary = FCE.Progress and FCE.Progress.Collect and FCE.Progress.Collect()
    local pct = 0
    if summary and summary.counts then
        pct = FCE.Progress.Percentage(summary.counts)
        -- Check for rank changes
        FCE.Progress.CheckRankUp()
    end
    -- Progress bar (built once, updated each refresh)
    -- Anchored below the titleBar, fitting inside the progressSpacer region.
    if FCE.Progress and FCE.Progress.BuildBar then
        if not Panel._progressBar then
            Panel._progressBar = FCE.Progress.BuildBar(frame, Panel._titleBar, -4)
        end
        -- Defer the bar update slightly so all check modules have
        -- had time to write their results this frame
        C_Timer.After(0.05, function()
            if FCE.Progress.UpdateBar then FCE.Progress.UpdateBar() end
        end)
    end

    -- Race / gender / self-found summary row with PASS/FAIL tag
    local sfResults = FCE.SelfFoundCheck and FCE.SelfFoundCheck.GetResults() or {}
    local sfStatus  = FCE.SelfFoundCheck and FCE.SelfFoundCheck.STATUS or {}
    local sfEnabled = not FCE.SelfFoundEnabled or FCE.SelfFoundEnabled()
    local charSelfFound
    if FCE.GetCharSelfFound then charSelfFound = FCE.GetCharSelfFound(char) else charSelfFound = char.selfFound end

    -- Does the player currently have the Self-Found buff?
    local playerHasSelfFoundBuff = false
    local sfBuffResult = sfResults.selfFound
    if sfBuffResult and sfBuffResult.status == (sfStatus.PASS or "pass") then
        playerHasSelfFoundBuff = true
    elseif UnitBuff then
        for bIdx = 1, 40 do
            local bName = UnitBuff("player", bIdx)
            if not bName then break end
            local lower = bName:lower()
            if lower:find("self") and lower:find("found") then
                playerHasSelfFoundBuff = true
                break
            end
        end
    end

    -- Check race and gender against the player
    local playerRace = UnitRace("player") or ""
    local playerSex  = UnitSex("player")  -- 2=male, 3=female
    local playerGender = (playerSex == 3) and "Female" or "Male"
    local raceOk   = (char.raceSet and (char.raceSet["Any race"] or char.raceSet[playerRace]))
                     or (char.race == "Any race") or (playerRace == char.race)
    local genderOk = (char.gender == "Any gender") or (playerGender == char.gender)

    -- Determine self-found pass/fail (only counts if SF requirement exists and is enabled)
    local sfText = ""
    local sfPass = true  -- assume pass if no SF requirement
    if charSelfFound then
        if not sfEnabled then
            sfText = " · |cff888888self-found (opted out)|r"
            -- Opted out doesn't count as fail
        else
            sfText = " · self-found"
            local sfBuff = sfResults.selfFound
            if sfBuff then
                if sfBuff.status == sfStatus.PASS then
                    sfPass = true
                elseif sfBuff.status == sfStatus.FAIL then
                    sfPass = false
                else
                    sfPass = true  -- unchecked: don't penalise
                end
            end
        end
    elseif charSelfFound == false then
        sfText = " · not self-found"
        local nsfResult = sfResults.notSelfFound
        if nsfResult then
            if nsfResult.status == sfStatus.PASS then
                sfPass = true
            elseif nsfResult.status == sfStatus.FAIL then
                sfPass = false
            else
                sfPass = true
            end
        end
    end

    -- Build the summary text: [Gender] - Race - BaseClass [- Self-found]
    -- Gender only shown if the enhanced class requires a specific gender
    -- Self-found only shown if the player has the self-found buff
    local classDisplay = UnitClass and select(1, UnitClass("player")) or ""
    local summaryParts = {}
    if char.gender and char.gender ~= "Any gender" then
        table.insert(summaryParts, playerGender)
    end
    table.insert(summaryParts, playerRace)
    table.insert(summaryParts, classDisplay)
    if playerHasSelfFoundBuff then
        table.insert(summaryParts, "Self-found")
    end
    local summaryText = table.concat(summaryParts, " - ")

    -- Overall row tag
    local rowPass = raceOk and genderOk and sfPass
    local rowTag, rowTagCol
    if rowPass then
        rowTag = "PASS"
        rowTagCol = COLOR_PASS
    else
        rowTag = "FAIL"
        rowTagCol = COLOR_FAIL
    end
    index, yOff = emitRow(index, yOff, rowTag, rowTagCol,
        summaryText, nil)
    -- Tag row for tooltip on hover (race/gender/self-found details)
    do
        local row = rowPool[index - 1]
        if row then
            -- Build tooltip text covering all parts of this row
            -- Always show each sub-check so users know what passed/failed
            local lines = {}
            if raceOk then
                lines[#lines+1] = "|cff55ff55Race:|r " .. playerRace .. " — OK"
            else
                lines[#lines+1] = "|cffff5555Race:|r you are " .. playerRace .. ", requires " .. char.race
            end
            if char.gender and char.gender ~= "Any gender" then
                if genderOk then
                    lines[#lines+1] = "|cff55ff55Gender:|r " .. playerGender .. " — OK"
                else
                    lines[#lines+1] = "|cffff5555Gender:|r you are " .. playerGender .. ", requires " .. char.gender
                end
            end
            if charSelfFound then
                if sfEnabled then
                    local sfBuff = sfResults.selfFound
                    if sfBuff then
                        if sfBuff.status == sfStatus.PASS then
                            lines[#lines+1] = "|cff55ff55Self-Found:|r " .. (sfBuff.detail or "active")
                        else
                            lines[#lines+1] = "|cffff5555Self-Found:|r " .. (sfBuff.detail or "not detected")
                        end
                    end
                else
                    lines[#lines+1] = "|cff888888Self-Found:|r opted out"
                end
            elseif charSelfFound == false then
                local nsfResult = sfResults.notSelfFound
                if nsfResult then
                    if nsfResult.status == sfStatus.PASS then
                        lines[#lines+1] = "|cff55ff55Not Self-Found:|r " .. (nsfResult.detail or "OK")
                    else
                        lines[#lines+1] = "|cffff5555Not Self-Found:|r " .. (nsfResult.detail or "requires AH/trade access")
                    end
                else
                    lines[#lines+1] = "|cff888888Not Self-Found:|r requires AH/trade access"
                end
            end
            -- Always attach tooltip (shows pass details too)
            if #lines > 0 then
                row.equipDetail = table.concat(lines, "\n")
                row.equipStatus = rowPass and "pass" or "fail"
                row:SetScript("OnEnter", onEquipRowEnter)
                row:SetScript("OnLeave", onEquipRowLeave)
            end
        end
    end

    -- Challenges + Reputation sections
    local chResults = FCE.ChallengeCheck and FCE.ChallengeCheck.GetResults() or {}
    local chStatus  = FCE.ChallengeCheck and FCE.ChallengeCheck.STATUS or {}
    local activeChallenges = FCE.GetActiveChallenges and FCE.GetActiveChallenges(char) or char.challenges or {}

    -- Split into normal challenges and reputation challenges
    local normalChallenges = {}
    local reputationChallenges = {}
    for i, ch in ipairs(activeChallenges) do
        if REPUTATION_RULES[ch.desc] then
            table.insert(reputationChallenges, { ch = ch, idx = i })
        else
            table.insert(normalChallenges, { ch = ch, idx = i })
        end
    end

    -- Helper: emit one challenge/reputation row (shared by both sections)
    local function emitChallengeEntry(ch, origIdx)
        local isActive = (playerLevel >= ch.level) and not (ch.endLevel and playerLevel > ch.endLevel)
        local checkResult = chResults[origIdx]
        local tag, col, txtCol = reqTag(ch.level, ch.endLevel, playerLevel,
            checkResult and checkResult.status or nil)

        local forgiveSuffix = ""
        if isActive and FORGIVABLE_TOOLTIP[ch.desc] then
            local curRank, rankCol, allowed = getCurrentRankAndAllowed()
            if allowed >= 999 then
                forgiveSuffix = " |cff888888(|cff" .. rankCol .. "Master|r|cff888888: all exempt)|r"
            else
                forgiveSuffix = " |cff888888(|cff" .. rankCol .. curRank .. "|r|cff888888: " .. allowed .. " exemptions)|r"
            end
        end

        index, yOff = emitRow(index, yOff, tag, col, ch.desc .. forgiveSuffix, txtCol)
        tagChallengeRow(index - 1, ch.desc, ch.level, isActive)

        local row = rowPool[index - 1]
        if row then
            if isActive and checkResult and checkResult.detail then
                row.equipDetail = checkResult.detail
                row.equipStatus = checkResult.status
            end
            local origEnter = row:GetScript("OnEnter")
            local capturedResult = (isActive and checkResult) or nil
            row:SetScript("OnEnter", function(self)
                if origEnter then origEnter(self) end
                if GameTooltip:IsShown() then
                    if capturedResult and capturedResult.detail then
                        GameTooltip:AddLine(" ")
                        local statusLabel
                        if capturedResult.status == chStatus.PASS then
                            statusLabel = "|cff4de64dPassing|r"
                        elseif capturedResult.status == chStatus.FAIL then
                            statusLabel = "|cffff5a4cViolation detected|r"
                        else
                            statusLabel = "|cffa5a582Cannot fully verify yet|r"
                        end
                        GameTooltip:AddLine("Status: " .. statusLabel, 0.93, 0.93, 0.93)
                        GameTooltip:AddLine(capturedResult.detail, 0.75, 0.75, 0.75, true)
                    end
                    GameTooltip:Show()
                end
            end)
        end

        local extra = FCE.ChallengeDescriptions and FCE.ChallengeDescriptions[ch.desc]
        if extra then
            index, yOff = emitRow(index, yOff, nil, nil, "  " .. extra, COLOR_SUBTXT)
            yOff = yOff + 4
        end
    end

    -- CHALLENGES section (non-reputation)
    if #normalChallenges > 0 then
        index, yOff = emitSectionHeader(index, yOff, "CHALLENGES")
        for _, entry in ipairs(normalChallenges) do
            emitChallengeEntry(entry.ch, entry.idx)
        end
    end

    -- REPUTATION section
    if #reputationChallenges > 0 then
        index, yOff = emitSectionHeader(index, yOff, "REPUTATION")
        for _, entry in ipairs(reputationChallenges) do
            emitChallengeEntry(entry.ch, entry.idx)
        end
    end

    -- Quests section (collapsed theme rows — click to open journal)
    local qcResults = FCE.QuestCheck and FCE.QuestCheck.GetResults() or {}
    local charQuests = FCE.GetCharQuests and FCE.GetCharQuests(char) or char.quests or {}
    if #charQuests > 0 then
        index, yOff = emitSectionHeader(index, yOff, "QUESTS")

        local groups
        if char.questGroups then
            groups = char.questGroups
        elseif char.questTheme then
            groups = { { theme = char.questTheme, count = #charQuests } }
        else
            groups = { { theme = "Quests", count = #charQuests } }
        end

        local questIdx = 1
        for _, group in ipairs(groups) do
            local groupStart  = questIdx
            local groupQuests = {}
            local doneCount   = 0
            local activeCount = 0
            local doneActive  = 0

            for j = 1, group.count do
                local quest = charQuests[questIdx]
                if not quest then break end
                groupQuests[j] = quest
                local res = qcResults[questIdx]
                questIdx = questIdx + 1

                if res and res.status == "pass" then
                    doneCount = doneCount + 1
                end
                if playerLevel >= quest.level then
                    activeCount = activeCount + 1
                    if res and res.status == "pass" then
                        doneActive = doneActive + 1
                    end
                end
            end

            -- Tag: PASS when all level-appropriate quests are done
            local tag, col, txtCol
            if activeCount > 0 and doneActive == activeCount then
                tag, col, txtCol = "PASS", COLOR_PASS, nil
            elseif activeCount > 0 then
                tag, col, txtCol = "FAIL", COLOR_FAIL, nil
            else
                local fl = groupQuests[1] and groupQuests[1].level or "?"
                tag, col, txtCol = "lv " .. fl, COLOR_INACTIVE, COLOR_INACTIVE
            end

            local themeName = group.theme or "Quests"
            local label = themeName .. " (" .. doneCount .. "/" .. #groupQuests .. ")"
            index, yOff = emitRow(index, yOff, tag, col, label, txtCol)

            -- Make the row clickable — tooltip + journal open
            local row = rowPool[index - 1]
            if row then
                local gQ = groupQuests
                local gS = groupStart
                local gT = themeName
                local gD = doneCount
                row:SetScript("OnEnter", function(self)
                    self.highlight:Show()
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(gT, 1, 0.82, 0.35)
                    GameTooltip:AddLine(gD .. " of " .. #gQ .. " quests completed",
                        0.85, 0.82, 0.72)
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("Click to see your story",
                        0.30, 0.90, 0.35)
                    GameTooltip:Show()
                end)
                row:SetScript("OnLeave", function(self)
                    self.highlight:Hide()
                    GameTooltip:Hide()
                end)
                row:SetScript("OnMouseUp", function()
                    if FCE.QuestJournal and FCE.QuestJournal.Open then
                        -- Build parallel results array for this group
                        local gr = {}
                        for j = 1, #gQ do
                            gr[j] = qcResults[gS + j - 1]
                        end
                        FCE.QuestJournal.Open(gQ, gr, gT)
                    end
                end)
            end
        end
    end

    -- Professions section (with tracking indicators from ProfessionCheck)
    local profResults = FCE.ProfessionCheck and FCE.ProfessionCheck.GetResults() or {}
    local profStatus  = FCE.ProfessionCheck and FCE.ProfessionCheck.STATUS or {}
    if char.professions and #char.professions > 0 then
        index, yOff = emitSectionHeader(index, yOff, "PROFESSIONS")
        for _, profName in ipairs(char.professions) do
            local res = profResults[profName]
            local tag, col, txtCol = reqTag(5, nil, playerLevel,
                res and res.status or nil)
            index, yOff = emitRow(index, yOff, tag, col, profName, txtCol)
            -- Tag profession rows for tooltip on hover (show rank detail)
            if res and res.detail then
                local row = rowPool[index - 1]
                if row then
                    row.equipDetail = res.detail
                    row.equipStatus = res.status
                    row:SetScript("OnEnter", onEquipRowEnter)
                    row:SetScript("OnLeave", onEquipRowLeave)
                end
            end
        end
    end

    -- Weapon Proficiency section
    local wpResults = FCE.WeaponProficiencyCheck and FCE.WeaponProficiencyCheck.GetResults() or {}
    local wpStatus  = FCE.WeaponProficiencyCheck and FCE.WeaponProficiencyCheck.STATUS or {}
    if char.weaponProficiency and #char.weaponProficiency > 0 then
        index, yOff = emitSectionHeader(index, yOff, "WEAPON PROFICIENCY")
        for _, wpnEntry in ipairs(char.weaponProficiency) do
            -- Support both "Bows" and E("Bows", 10) formats
            local wpn, wpnLevel
            if type(wpnEntry) == "table" then
                wpn = wpnEntry.desc or wpnEntry.name or "?"
                wpnLevel = wpnEntry.level or 1
            else
                wpn = wpnEntry
                wpnLevel = 1
            end
            local res = wpResults[wpn]
            local tag, col, txtCol = reqTag(wpnLevel, nil, playerLevel,
                res and res.status or nil)
            index, yOff = emitRow(index, yOff, tag, col, wpn, txtCol)
            if res and res.detail then
                local row = rowPool[index - 1]
                if row then
                    row.equipDetail = res.detail
                    row.equipStatus = res.status
                    row:SetScript("OnEnter", onEquipRowEnter)
                    row:SetScript("OnLeave", onEquipRowLeave)
                end
            end
        end
    end

    -- Equipment section
    local eqResults = FCE.EquipmentCheck and FCE.EquipmentCheck.GetResults() or {}
    local eqStatus  = FCE.EquipmentCheck and FCE.EquipmentCheck.STATUS or {}
    local _rpEquip = FCE.GetCharEquipment(char)
    if #_rpEquip > 0 then
        index, yOff = emitSectionHeader(index, yOff, "EQUIPMENT")
        for i, eq in ipairs(_rpEquip) do
            local res = eqResults[i]
            local tag, col, txtCol = reqTag(eq.level, eq.endLevel, playerLevel,
                res and res.status or nil)
            local isActive = (playerLevel >= eq.level) and not (eq.endLevel and playerLevel > eq.endLevel)
            index, yOff = emitRow(index, yOff, tag, col, eq.desc, txtCol)
            -- Tag equipment rows for tooltip on hover (show check detail + curated items)
            local row = rowPool[index - 1]
            if row then
                -- Attach curated list key so tooltip can show approved items
                local keyMap = FCE.CuratedKeyForDesc or {}
                row.curatedKey = keyMap[eq.desc]

                if res and res.detail then
                    row.equipDetail = res.detail
                    row.equipStatus = res.status
                    row:SetScript("OnEnter", onEquipRowEnter)
                    row:SetScript("OnLeave", onEquipRowLeave)
                elseif row.curatedKey then
                    -- Even without a check result, show curated items on hover
                    row.equipDetail = "Hover to see approved items"
                    row.equipStatus = "unchecked"
                    row:SetScript("OnEnter", onEquipRowEnter)
                    row:SetScript("OnLeave", onEquipRowLeave)
                end
            end
        end
    end

    -- Companion / pet / mount
    local hasAnimals = char.companion or char.pet or char.mount
    if hasAnimals then
        index, yOff = emitSectionHeader(index, yOff, "MOUNTS/COMPANIONS/PETS")
        if char.companion then
            local compResult = FCE_CharDB and FCE_CharDB.companionResults
            if not compResult and FCE.CompanionCheck and FCE.CompanionCheck.RunCheck then
                compResult = FCE.CompanionCheck.RunCheck()
            end
            local tag, col, txtCol = reqTag(char.companion.level, nil, playerLevel,
                compResult and compResult.status or nil)
            index, yOff = emitRow(index, yOff, tag, col, "Companion: " .. char.companion.desc, txtCol)
            -- Tooltip: always attach so hover shows CompanionDB info
            local compRow = rowPool[index - 1]
            if compRow then
                compRow.companionKey = char.companion.desc
                if compResult then
                    compRow.equipDetail = compResult.detail or "Checking..."
                    compRow.equipStatus = compResult.status
                else
                    compRow.equipDetail = "Activates at level " .. char.companion.level
                    compRow.equipStatus = "unchecked"
                end
                compRow:SetScript("OnEnter", onEquipRowEnter)
                compRow:SetScript("OnLeave", onEquipRowLeave)
            end
        end
        if char.pet then
            local hpResult = FCE_CharDB and FCE_CharDB.hunterPetResults
            -- If no stored result, run the check now so we always have data
            if not hpResult and FCE.HunterPetCheck and FCE.HunterPetCheck.RunCheck then
                hpResult = FCE.HunterPetCheck.RunCheck()
            end
            local tag, col, txtCol = reqTag(char.pet.level, nil, playerLevel,
                hpResult and hpResult.status or nil)
            index, yOff = emitRow(index, yOff, tag, col, "Hunter pet: " .. char.pet.desc, txtCol)
            -- Tooltip on hover showing hunter pet check detail
            local hpRow = rowPool[index - 1]
            if hpRow then
                hpRow.hunterPetKey = char.pet.desc
                if hpResult and hpResult.detail then
                    hpRow.equipDetail = hpResult.detail
                    hpRow.equipStatus = hpResult.status
                else
                    hpRow.equipDetail = "Unlocks at level " .. char.pet.level
                    hpRow.equipStatus = "unchecked"
                end
                hpRow:SetScript("OnEnter", onEquipRowEnter)
                hpRow:SetScript("OnLeave", onEquipRowLeave)
            end
        end
        if char.mount then
            local mtResult = FCE_CharDB and FCE_CharDB.mountResults
            if not mtResult and FCE.MountCheck and FCE.MountCheck.RunCheck then
                mtResult = FCE.MountCheck.RunCheck()
            end
            local tag, col, txtCol = reqTag(char.mount.level, nil, playerLevel,
                mtResult and mtResult.status or nil)
            index, yOff = emitRow(index, yOff, tag, col, "Mount: " .. char.mount.desc, txtCol)
            -- Tooltip on hover showing mount check detail
            local mtRow = rowPool[index - 1]
            if mtRow then
                if mtResult and mtResult.detail then
                    mtRow.equipDetail = mtResult.detail
                    mtRow.equipStatus = mtResult.status
                else
                    mtRow.equipDetail = "Waiting for mount data..."
                    mtRow.equipStatus = "unchecked"
                end
                mtRow:SetScript("OnEnter", onEquipRowEnter)
                mtRow:SetScript("OnLeave", onEquipRowLeave)
            end
        end
    end

    
    -- Talents section (spec tracking + per-talent requirements)
    -- Run a fresh check so results are always current (the API calls
    -- are cheap and this avoids stale-cache / timing-race issues).
    if FCE.TalentCheck and FCE.TalentCheck.RunCheck then
        local tok, terr = pcall(FCE.TalentCheck.RunCheck)
        if not tok and FCE.Print then
            FCE.Print("|cffff5555Talent check error:|r " .. tostring(terr))
        end
    end
    local talentResult = FCE.TalentCheck and FCE.TalentCheck.GetResults() or {}
    local talentStatus = FCE.TalentCheck and FCE.TalentCheck.STATUS or {}
    if char.spec then
        index, yOff = emitSectionHeader(index, yOff, "TALENTS")

        -- Row 1: spec label (informational only, not tracked)
        index, yOff = emitRow(index, yOff, nil, nil,
            "Spec: " .. char.spec, COLOR_SUBTXT)

        -- Per-talent requirement rows (indented under the spec row)
        -- Read directly from TalentRequirements data so rows are ALWAYS
        -- visible, even before the talent scan has run.  Check results
        -- (from talentResult.talentReqs) are overlaid for ✓/✗/? status.
        local talentKey = char.class .. "_" .. (char.spec or "")
        local rawReqs   = FCE.TalentRequirements and FCE.TalentRequirements[talentKey]
        local checkReqs = talentResult.talentReqs
        if rawReqs then
            for ri, req in ipairs(rawReqs) do
                -- Use check result for this index if available
                local chk = checkReqs and checkReqs[ri]
                local tTag, tCol, tTxtCol = reqTag(req.level, req.endLevel, playerLevel,
                    chk and chk.status or nil)
                local maxRank = (chk and chk.maxRank) or req.rank
                local rankStr = req.rank .. "/" .. maxRank
                local tText = req.name .. " (" .. rankStr .. ")"
                index, yOff = emitRow(index, yOff, tTag, tCol, tText, tTxtCol)
                -- Hover tooltip
                local tRow = rowPool[index - 1]
                if tRow then
                    tRow.equipDetail = (chk and chk.detail) or "Talent check pending\226\128\166"
                    tRow.equipStatus = (chk and chk.status) or "unchecked"
                    tRow:SetScript("OnEnter", onEquipRowEnter)
                    tRow:SetScript("OnLeave", onEquipRowLeave)
                end
            end
        end
    end

    -- Recommended profession (not a requirement — shown like gameplay tips)
    local _rpProf = FCE.GetCharRecommendedProfession(char)
    if _rpProf then
        local COLOR_TIPS = { r = 0.55, g = 0.70, b = 0.85 }
        local rp = _rpProf
        index, yOff = emitSectionHeader(index, yOff, "RECOMMENDED")
        local rowIdx = index
        index, yOff = emitRow(index, yOff, nil, nil,
            "Profession: " .. rp.name, COLOR_TIPS)
        local row = rowPool[rowIdx]
        if row then
            row.tipTitle = "Recommended: " .. rp.name
            row.tipDesc  = rp.reason
            row:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:ClearLines()
                GameTooltip:AddLine(self.tipTitle, 0.55, 0.70, 0.85)
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(self.tipDesc, 0.93, 0.93, 0.93, true)
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("This is a suggestion, not a requirement.", 0.55, 0.55, 0.50, true)
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
        end
    end

    -- Gameplay tips (expanded via GameplayTips module)
    local _rpGameplay = FCE.GetCharGameplay and FCE.GetCharGameplay(char) or char.gameplay
    if _rpGameplay and _rpGameplay ~= "" then
        index, yOff = emitSectionHeader(index, yOff, "GAMEPLAY")
        local COLOR_TIPS = { r = 0.55, g = 0.70, b = 0.85 }
        local tips = FCE.GameplayTips and FCE.GameplayTips.Parse and FCE.GameplayTips.Parse(_rpGameplay)
        if tips and #tips > 0 then
            for _, tip in ipairs(tips) do
                local rowIdx = index
                index, yOff = emitRow(index, yOff, nil, nil,
                    tip.title, COLOR_TIPS)
                -- Add hover tooltip with the full description
                local row = rowPool[rowIdx]
                if row then
                    row.tipDesc = tip.desc
                    row.tipTitle = tip.title
                    row:SetScript("OnEnter", function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:ClearLines()
                        GameTooltip:AddLine(self.tipTitle, 0.55, 0.70, 0.85)
                        GameTooltip:AddLine(" ")
                        GameTooltip:AddLine(self.tipDesc, 0.93, 0.93, 0.93, true)
                        GameTooltip:AddLine(" ")
                        GameTooltip:AddLine("This is a flavour suggestion, not a requirement.", 0.55, 0.55, 0.50, true)
                        GameTooltip:Show()
                    end)
                    row:SetScript("OnLeave", function()
                        GameTooltip:Hide()
                    end)
                end
            end
        else
            -- Fallback: show raw text if GameplayTips module not loaded
            index, yOff = emitRow(index, yOff, nil, nil, _rpGameplay, COLOR_SUBTXT)
        end
    end

    releaseExtraRows(index - 1)
    contentFrame:SetHeight(math.max(yOff + 10, 1))
end

----------------------------------------------------------------------
-- Build the frame
----------------------------------------------------------------------

local function BuildFrame()
    if frame then return frame end

    frame = CreateFrame("Frame", "HCE_RequirementsPanel", UIParent, "BackdropTemplate")
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)

    -- Close panel with Escape key
    tinsert(UISpecialFrames, "HCE_RequirementsPanel")

    -- Dark panel with gold tooltip-border (StoryMode-inspired)
    if FCE.Style then
        FCE.Style.ApplyPanelBackdrop(frame)
        FCE.Style.AddInnerFill(frame)
    elseif frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 16,
            insets   = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        frame:SetBackdropColor(0.040, 0.035, 0.030, 0.94)
        frame:SetBackdropBorderColor(0.72, 0.56, 0.30, 0.72)
    end

    -- Title bar -------------------------------------------------------
    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)
    titleBar:SetHeight(50)
    Panel._titleBar = titleBar
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function()
        if not db().locked then frame:StartMoving() end
    end)
    titleBar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        local p, _, rp, x, y = frame:GetPoint()
        local s = db()
        s.point, s.relPoint, s.x, s.y = p, rp, x, y
    end)

    if FCE.Style then
        FCE.Style.TintTitleBar(titleBar)
        FCE.Style.CreateGoldStripe(frame, titleBar, 0)
    else
        local titleBg = titleBar:CreateTexture(nil, "BACKGROUND")
        titleBg:SetColorTexture(0.85, 0.70, 0.20, 0.10)
        titleBg:SetAllPoints(titleBar)
        local titleStripe = titleBar:CreateTexture(nil, "ARTWORK")
        titleStripe:SetColorTexture(0.72, 0.56, 0.30, 0.85)
        titleStripe:SetPoint("BOTTOMLEFT", titleBar, "BOTTOMLEFT", 0, 0)
        titleStripe:SetPoint("BOTTOMRIGHT", titleBar, "BOTTOMRIGHT", 0, 0)
        titleStripe:SetHeight(1)
    end

    -- Class icon (set dynamically in Refresh from FCE.BROWSE_ICONS)
    local classIcon = titleBar:CreateTexture(nil, "ARTWORK")
    classIcon:SetSize(22, 22)
    classIcon:SetPoint("TOPLEFT", titleBar, "TOPLEFT", PAD_X, -PAD_Y)
    classIcon:Hide()
    Panel._classIcon = classIcon

    headerLabel = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    headerLabel:SetPoint("LEFT", classIcon, "RIGHT", 5, 0)
    headerLabel:SetPoint("RIGHT", titleBar, "RIGHT", -58, 0)
    headerLabel:SetJustifyH("LEFT")
    headerLabel:SetText("Forever Classes Enhanced")
    -- Bump font size a touch
    local hlFont, hlSize, hlFlags = headerLabel:GetFont()
    if hlFont then headerLabel:SetFont(hlFont, (hlSize or 14) + 2, hlFlags or "") end

    subLabel = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subLabel:SetPoint("BOTTOMLEFT", titleBar, "BOTTOMLEFT", PAD_X, 5)
    subLabel:SetJustifyH("LEFT")
    subLabel:SetTextColor(COLOR_SUBTXT.r, COLOR_SUBTXT.g, COLOR_SUBTXT.b)
    subLabel:SetText("")

    -- Close button (top-right corner)
    closeButton = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    closeButton:SetSize(24, 24)
    closeButton:SetPoint("TOPRIGHT", titleBar, "TOPRIGHT", -4, -4)
    closeButton:SetScript("OnClick", function() Panel.Hide() end)

    ----------------------------------------------------------------
    -- ROW 1: Left of close button — Catalog, Lore
    ----------------------------------------------------------------

    -- Catalog button (class icon)
    local catalogButton = CreateFrame("Button", nil, titleBar)
    catalogButton:SetSize(20, 20)
    catalogButton:SetPoint("RIGHT", closeButton, "LEFT", -4, 0)
    catalogButton.icon = catalogButton:CreateTexture(nil, "ARTWORK")
    catalogButton.icon:SetAllPoints()
    catalogButton.icon:SetTexture("Interface\\MINIMAP\\TRACKING\\Class")
    catalogButton:SetScript("OnClick", function()
        if FCE.CatalogUI and FCE.CatalogUI.Toggle then
            FCE.CatalogUI.Toggle()
        end
    end)
    catalogButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Browse all enhanced classes")
        GameTooltip:Show()
    end)
    catalogButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Lore button (scroll icon) — only shown for core-set characters
    local loreButton = CreateFrame("Button", nil, titleBar)
    loreButton:SetSize(15, 15)
    loreButton:SetPoint("RIGHT", catalogButton, "LEFT", -5, 0)
    loreButton.icon = loreButton:CreateTexture(nil, "ARTWORK")
    loreButton.icon:SetAllPoints()
    loreButton.icon:SetTexture("Interface\\ICONS\\INV_Scroll_02")
    loreButton.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    loreButton:SetScript("OnClick", function()
        Panel.ToggleLore()
    end)
    loreButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Read lore background")
        GameTooltip:Show()
    end)
    loreButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    loreButton:Hide()
    Panel._loreButton = loreButton

    ----------------------------------------------------------------
    -- ROW 2: Below close button — Settings, Commands
    ----------------------------------------------------------------

    -- Minimize button (right-most in row 2, directly below close X)
    local minimizeButton = CreateFrame("Button", nil, titleBar)
    minimizeButton:SetSize(18, 18)
    minimizeButton:SetPoint("TOP", closeButton, "BOTTOM", 0, -1)
    minimizeButton.icon = minimizeButton:CreateTexture(nil, "ARTWORK")
    minimizeButton.icon:SetAllPoints()
    minimizeButton.icon:SetTexture("Interface\\Buttons\\UI-Panel-CollapseButton-Up")
    minimizeButton.icon:SetTexCoord(0, 1, 0, 1)
    minimizeButton:SetScript("OnClick", function()
        Panel.Minimize()
    end)
    minimizeButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Minimize to side panel")
        GameTooltip:Show()
    end)
    minimizeButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Settings button (gear icon)
    local settingsButton = CreateFrame("Button", nil, titleBar)
    settingsButton:SetSize(18, 18)
    settingsButton:SetPoint("RIGHT", minimizeButton, "LEFT", -2, 0)
    settingsButton.icon = settingsButton:CreateTexture(nil, "ARTWORK")
    settingsButton.icon:SetAllPoints()
    settingsButton.icon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
    settingsButton:SetScript("OnClick", function()
        if FCE.SettingsPanel and FCE.SettingsPanel.Toggle then
            FCE.SettingsPanel.Toggle()
        end
    end)
    settingsButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Settings")
        GameTooltip:Show()
    end)
    settingsButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Commands button (? icon)
    local cmdButton = CreateFrame("Button", nil, titleBar)
    cmdButton:SetSize(27, 27)
    cmdButton:SetPoint("RIGHT", settingsButton, "LEFT", -2, 0)
    cmdButton.icon = cmdButton:CreateTexture(nil, "ARTWORK")
    cmdButton.icon:SetAllPoints()
    cmdButton.icon:SetTexture("Interface\\COMMON\\help-i")
    cmdButton:SetScript("OnClick", function()
        SlashCmdList["FCE"]("help")
    end)
    cmdButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Commands", 0.85, 0.70, 0.20)
        GameTooltip:AddLine("Click to show all /fce commands", 0.75, 0.75, 0.75)
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("/fce share <name>", "Whisper about FCE", 1,1,1, 0.7,0.7,0.7)
        GameTooltip:AddDoubleLine("/fce share party", "Share in party chat", 1,1,1, 0.7,0.7,0.7)
        GameTooltip:AddDoubleLine("/fce list", "Browse all classes", 1,1,1, 0.7,0.7,0.7)
        GameTooltip:AddDoubleLine("/fce reset", "Clear your character selection & reset challenges", 1,1,1, 0.7,0.7,0.7)
        GameTooltip:AddDoubleLine("/fce pick", "Open character selection window", 1,1,1, 0.7,0.7,0.7)
        GameTooltip:AddDoubleLine("/fce pick <name>", "Pick a specific character by name", 1,1,1, 0.7,0.7,0.7)
        GameTooltip:AddDoubleLine("/fce donate", "Support the addon", 1,1,1, 0.7,0.7,0.7)
        GameTooltip:AddDoubleLine("/fce join", "Join the Discord", 1,1,1, 0.7,0.7,0.7)
        GameTooltip:Show()
    end)
    cmdButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Scan button (magnifying glass) — find other FCE players
    local scanButton = CreateFrame("Button", nil, titleBar)
    scanButton:SetSize(20, 20)
    scanButton:SetPoint("RIGHT", cmdButton, "LEFT", -2, 0)
    scanButton.icon = scanButton:CreateTexture(nil, "ARTWORK")
    scanButton.icon:SetAllPoints()
    scanButton.icon:SetTexture("Interface\\MINIMAP\\TRACKING\\None")
    scanButton:SetScript("OnClick", function()
        if FCE.AddonComm and FCE.AddonComm.StartNearbyScan then
            FCE.AddonComm.StartNearbyScan()
        else
            FCE.Print("Addon communication module not loaded.")
        end
    end)
    scanButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Find FCE Players", 0.85, 0.70, 0.20)
        GameTooltip:AddLine("Scan for other players using", 0.75, 0.75, 0.75, true)
        GameTooltip:AddLine("Forever Classes Enhanced", 0.75, 0.75, 0.75, true)
        GameTooltip:Show()
    end)
    scanButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Achievement button (trophy) — account-wide progress
    if FCE.Achieve and FCE.Achieve.CreateButton then
        FCE.Achieve.CreateButton(titleBar, scanButton)
    end

    -- UpdatePinIcon kept as no-op for backward compat
    function Panel.UpdatePinIcon() end

    -- Progress bar spacer — reserve vertical space so the scroll frame
    -- starts below the progress bar when it's present.  The bar itself
    -- is created lazily in Panel.Refresh; this just offsets the scroll.
    local PROGRESS_H = 48
    local progressSpacer = CreateFrame("Frame", nil, frame)
    progressSpacer:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, 0)
    progressSpacer:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", 0, 0)
    progressSpacer:SetHeight(PROGRESS_H)
    progressSpacer:EnableMouse(true)
    progressSpacer:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM", 0, -4)
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Rank Tiers", 0.85, 0.70, 0.20)
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("0%",   "Initiate", 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine("25%",  "Adept",    1, 1, 1, 0.12, 1.0, 0.0)
        GameTooltip:AddDoubleLine("50%",  "Prime",    1, 1, 1, 0.0, 0.44, 0.87)
        GameTooltip:AddDoubleLine("75%",  "Elite",    1, 1, 1, 0.64, 0.21, 0.93)
        GameTooltip:AddDoubleLine("100%", "Master",   1, 1, 1, 1.0, 0.50, 0.0)
        GameTooltip:Show()
    end)
    progressSpacer:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Panel._progressSpacer = progressSpacer

    -- Scroll frame ----------------------------------------------------
    scrollFrame = CreateFrame("ScrollFrame", "HCE_RequirementsPanelScroll", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", progressSpacer, "BOTTOMLEFT", PAD_X, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 11, PAD_Y)

    contentFrame = CreateFrame("Frame", nil, scrollFrame)
    contentFrame:SetSize(FRAME_WIDTH - PAD_X - 34, 10)
    contentFrame:EnableMouse(false)       -- Mac: prevent scroll child from eating row events
    scrollFrame:SetScrollChild(contentFrame)

    -- Style the scrollbar (thin gold thumb, dark track)
    if FCE.Style then FCE.Style.StyleScrollbar(scrollFrame) end

    -- Art panel — a separate frame docked to the left of the requirements
    -- panel, showing the class portrait at full opacity.  Moves with the
    -- main frame and shares the same ornate border style.
    local artFrame = CreateFrame("Frame", "HCE_ArtPanel", frame, "BackdropTemplate")
    artFrame:SetWidth(FRAME_WIDTH)
    artFrame:SetPoint("TOPRIGHT", frame, "TOPLEFT", 0, 0)
    artFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", 0, 0)
    artFrame:SetFrameStrata("MEDIUM")
    if FCE.Style then
        FCE.Style.ApplyPanelBackdrop(artFrame)
        FCE.Style.AddInnerFill(artFrame)
    elseif artFrame.SetBackdrop then
        artFrame:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 16,
            insets   = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        artFrame:SetBackdropColor(0.040, 0.035, 0.030, 0.94)
        artFrame:SetBackdropBorderColor(0.72, 0.56, 0.30, 0.72)
    end

    -- The actual class art texture — full opacity, fills the panel
    local artTex = artFrame:CreateTexture(nil, "ARTWORK")
    artTex:SetPoint("TOPLEFT", artFrame, "TOPLEFT", 6, -6)
    artTex:SetPoint("BOTTOMRIGHT", artFrame, "BOTTOMRIGHT", -6, 6)
    artTex:SetTexCoord(0, 1, 0, 1)

    artFrame:Hide()
    Panel._artFrame = artFrame
    Panel._artTex = artTex

    -- Restore position
    local s = db()
    -- Default position offsets the main frame rightward by half the art
    -- panel width so the combined pair (art + requirements) is centered.
    local defaultX = math.floor(FRAME_WIDTH / 2)
    frame:ClearAllPoints()
    frame:SetPoint(s.point or "CENTER", UIParent, s.relPoint or "CENTER", s.x or defaultX, s.y or 0)
    Panel.UpdatePinIcon()

    frame:Hide()
    return frame
end

----------------------------------------------------------------------
-- Lore popup
----------------------------------------------------------------------

local loreFrame  -- created once, toggled

local function BuildLoreFrame()
    if loreFrame then return loreFrame end

    loreFrame = CreateFrame("Frame", "HCE_LoreFrame", UIParent, "BackdropTemplate")
    loreFrame:SetSize(340, 320)
    loreFrame:SetFrameStrata("DIALOG")
    loreFrame:SetClampedToScreen(true)
    loreFrame:SetMovable(true)
    loreFrame:EnableMouse(true)
    tinsert(UISpecialFrames, "HCE_LoreFrame")

    if FCE.Style then
        FCE.Style.ApplyPanelBackdrop(loreFrame)
        FCE.Style.AddInnerFill(loreFrame)
    elseif loreFrame.SetBackdrop then
        loreFrame:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 16,
            insets   = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        loreFrame:SetBackdropColor(0.040, 0.035, 0.030, 0.94)
        loreFrame:SetBackdropBorderColor(0.72, 0.56, 0.30, 0.72)
    end

    -- Title bar
    local loreTitleBar = CreateFrame("Frame", nil, loreFrame)
    loreTitleBar:SetPoint("TOPLEFT", 0, 0)
    loreTitleBar:SetPoint("TOPRIGHT", 0, 0)
    loreTitleBar:SetHeight(32)
    loreTitleBar:EnableMouse(true)
    loreTitleBar:RegisterForDrag("LeftButton")
    loreTitleBar:SetScript("OnDragStart", function() loreFrame:StartMoving() end)
    loreTitleBar:SetScript("OnDragStop", function() loreFrame:StopMovingOrSizing() end)

    if FCE.Style then
        FCE.Style.TintTitleBar(loreTitleBar)
        FCE.Style.CreateGoldStripe(loreFrame, loreTitleBar, 0)
    else
        local loreTitleBg = loreTitleBar:CreateTexture(nil, "BACKGROUND")
        loreTitleBg:SetColorTexture(0.85, 0.70, 0.20, 0.10)
        loreTitleBg:SetAllPoints(loreTitleBar)
        local loreTitleStripe = loreTitleBar:CreateTexture(nil, "ARTWORK")
        loreTitleStripe:SetColorTexture(0.72, 0.56, 0.30, 0.85)
        loreTitleStripe:SetPoint("BOTTOMLEFT", loreTitleBar, "BOTTOMLEFT", 0, 0)
        loreTitleStripe:SetPoint("BOTTOMRIGHT", loreTitleBar, "BOTTOMRIGHT", 0, 0)
        loreTitleStripe:SetHeight(1)
    end

    loreFrame.titleText = loreTitleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    loreFrame.titleText:SetPoint("LEFT", loreTitleBar, "LEFT", 12, 0)
    loreFrame.titleText:SetPoint("RIGHT", loreTitleBar, "RIGHT", -28, 0)
    loreFrame.titleText:SetJustifyH("LEFT")
    loreFrame.titleText:SetTextColor(0.85, 0.70, 0.20)

    local loreClose = CreateFrame("Button", nil, loreTitleBar, "UIPanelCloseButton")
    loreClose:SetSize(22, 22)
    loreClose:SetPoint("TOPRIGHT", loreTitleBar, "TOPRIGHT", -2, -2)
    loreClose:SetScript("OnClick", function() loreFrame:Hide() end)

    -- Scroll frame for lore body (no scrollbar — mousewheel only)
    local loreScroll = CreateFrame("ScrollFrame", "HCE_LoreScroll", loreFrame, "UIPanelScrollFrameTemplate")
    loreScroll:SetPoint("TOPLEFT", loreTitleBar, "BOTTOMLEFT", 12, -8)
    loreScroll:SetPoint("BOTTOMRIGHT", loreFrame, "BOTTOMRIGHT", -12, 12)

    -- Hide the scrollbar
    local sb = loreScroll.ScrollBar or _G["HCE_LoreScrollScrollBar"]
    if sb then sb:Hide(); sb:SetAlpha(0); sb.Show = function() end end

    local LORE_TEXT_W = 306

    local loreContent = CreateFrame("Frame", nil, loreScroll)
    loreContent:SetWidth(LORE_TEXT_W + 4)
    loreContent:SetHeight(1)
    loreScroll:SetScrollChild(loreContent)

    loreFrame.body = loreContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    loreFrame.body:SetPoint("TOPLEFT", loreContent, "TOPLEFT", 0, 0)
    loreFrame.body:SetWidth(LORE_TEXT_W)
    loreFrame.body:SetJustifyH("LEFT")
    loreFrame.body:SetWordWrap(true)
    loreFrame.body:SetSpacing(3)

    -- Wiki link at the bottom of the content
    loreFrame.wikiLabel = loreContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    loreFrame.wikiLabel:SetPoint("TOPLEFT", loreFrame.body, "BOTTOMLEFT", 0, -12)
    loreFrame.wikiLabel:SetWidth(LORE_TEXT_W)
    loreFrame.wikiLabel:SetJustifyH("LEFT")
    loreFrame.wikiLabel:SetWordWrap(true)
    loreFrame.wikiLabel:SetTextColor(0.40, 0.73, 1.00)

    loreFrame.loreContent = loreContent

    -- Position next to the requirements panel
    if frame then
        loreFrame:SetPoint("TOPLEFT", frame, "TOPRIGHT", 4, 0)
    else
        loreFrame:SetPoint("CENTER")
    end

    loreFrame:Hide()
    return loreFrame
end

function Panel.ShowLore()
    BuildLoreFrame()

    local key = FCE_CharDB and FCE_CharDB.selectedCharacter
    local char = key and FCE.GetCharacter and FCE.GetCharacter(key) or nil
    if not char then return end

    local lore = FCE.LoreData and FCE.LoreData[char.name]
    if not lore or lore == "" then
        lore = "No lore entry found for this class."
    end

    local cc = classColor(char.class)
    loreFrame.titleText:SetText("|cff" .. cc .. char.name .. "|r — Lore")
    loreFrame.body:SetText(lore)

    -- Wiki link
    local slug = char.name:gsub(" ", "_")
    loreFrame.wikiLabel:SetText("Read more: https://warcraft.wiki.gg/wiki/" .. slug)

    -- Resize content to fit text
    local textH = loreFrame.body:GetStringHeight()
    local wikiH = loreFrame.wikiLabel:GetStringHeight()
    loreFrame.loreContent:SetHeight(textH + wikiH + 24)

    -- Reanchor next to the panel if it's shown
    if frame and frame:IsShown() then
        loreFrame:ClearAllPoints()
        loreFrame:SetPoint("TOPLEFT", frame, "TOPRIGHT", 4, 0)
    end

    loreFrame:Show()
end

function Panel.HideLore()
    if loreFrame then loreFrame:Hide() end
end

function Panel.ToggleLore()
    BuildLoreFrame()
    if loreFrame:IsShown() then
        Panel.HideLore()
    else
        Panel.ShowLore()
    end
end

----------------------------------------------------------------------
-- Mini panel (compact side view)
----------------------------------------------------------------------

local MINI_W = 210
local MINI_ROW_H = 14

local function BuildMiniPanel()
    if miniFrame then return end

    miniFrame = CreateFrame("Frame", "FCEMiniPanel", UIParent, "BackdropTemplate")
    miniFrame:SetSize(MINI_W, 120)
    miniFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -80, -300)
    miniFrame:SetFrameStrata("MEDIUM")
    miniFrame:SetMovable(true)
    miniFrame:EnableMouse(true)
    miniFrame:SetClampedToScreen(true)

    if miniFrame.SetBackdrop then
        miniFrame:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 14,
            insets   = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        miniFrame:SetBackdropColor(0.06, 0.05, 0.04, 0.92)
        miniFrame:SetBackdropBorderColor(0.55, 0.45, 0.25, 0.70)
    end

    -- Drag
    miniFrame:RegisterForDrag("LeftButton")
    miniFrame:SetScript("OnDragStart", miniFrame.StartMoving)
    miniFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local d = db()
        d.miniX = self:GetLeft()
        d.miniY = self:GetTop()
    end)

    -- Restore saved position
    local d = db()
    if d.miniX and d.miniY then
        miniFrame:ClearAllPoints()
        miniFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", d.miniX, d.miniY)
    end

    -- Expand button (top-right)
    local expandBtn = CreateFrame("Button", nil, miniFrame)
    expandBtn:SetSize(16, 16)
    expandBtn:SetPoint("TOPRIGHT", miniFrame, "TOPRIGHT", -4, -4)
    expandBtn.icon = expandBtn:CreateTexture(nil, "ARTWORK")
    expandBtn.icon:SetAllPoints()
    expandBtn.icon:SetTexture("Interface\\Buttons\\UI-Panel-ExpandButton-Up")
    expandBtn.icon:SetTexCoord(0, 1, 0, 1)
    expandBtn:SetScript("OnClick", function()
        Panel.Restore()
    end)
    expandBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Expand requirements panel")
        GameTooltip:Show()
    end)
    expandBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Rank title
    local rankText = miniFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rankText:SetPoint("TOPLEFT", miniFrame, "TOPLEFT", 8, -8)
    rankText:SetPoint("RIGHT", expandBtn, "LEFT", -4, 0)
    rankText:SetJustifyH("LEFT")
    miniFrame.rankText = rankText

    -- Container for dynamic rows
    local rowArea = CreateFrame("Frame", nil, miniFrame)
    rowArea:SetPoint("TOPLEFT", rankText, "BOTTOMLEFT", 0, -4)
    rowArea:SetPoint("RIGHT", miniFrame, "RIGHT", -8, 0)
    rowArea:SetHeight(200)
    miniFrame.rowArea = rowArea

    -- Pre-create row fontstrings (reused each refresh)
    miniFrame.rows = {}
    miniFrame.rowsR = {}
    for i = 1, 20 do
        local r = rowArea:CreateFontString(nil, "OVERLAY", "GameFontHighlightExtraSmall")
        r:SetPoint("TOPLEFT", rowArea, "TOPLEFT", 0, -(i - 1) * MINI_ROW_H)
        r:SetPoint("RIGHT", rowArea, "RIGHT", 0, 0)
        r:SetJustifyH("LEFT")
        r:SetWordWrap(false)
        r:Hide()
        miniFrame.rows[i] = r

        local rr = rowArea:CreateFontString(nil, "OVERLAY", "GameFontHighlightExtraSmall")
        rr:SetPoint("TOP", r, "TOP", 0, 0)
        rr:SetPoint("RIGHT", rowArea, "RIGHT", 0, 0)
        rr:SetJustifyH("RIGHT")
        rr:SetWordWrap(false)
        rr:Hide()
        miniFrame.rowsR[i] = rr

    end

    miniFrame:Hide()
end

function Panel.RefreshMini()
    if not miniFrame or not miniFrame:IsShown() then return end

    local summary = FCE.Progress and FCE.Progress.Collect and FCE.Progress.Collect()
    if not summary then return end

    local pct = FCE.Progress.Percentage(summary.counts)
    local rank, rankColor = FCE.Progress.GetRank(pct)

    -- Rank + display name
    local key = FCE_CharDB and FCE_CharDB.selectedCharacter
    local char = key and FCE.GetCharacter and FCE.GetCharacter(key) or nil
    local displayName = char and (FCE.GetCharDisplayName and FCE.GetCharDisplayName(char) or char.name) or "?"
    miniFrame.rankText:SetText("|cff" .. rankColor .. rank .. " " .. displayName .. "|r")

    -- Hide all rows
    for _, r in ipairs(miniFrame.rows) do r:SetFontObject(GameFontHighlightExtraSmall); r:SetText(""); r:Hide() end
    for _, r in ipairs(miniFrame.rowsR) do r:SetText(""); r:Hide() end

    local ri = 1

    -- Spacer after rank title
    miniFrame.rows[ri]:SetText(" ")
    miniFrame.rows[ri]:Show()
    ri = ri + 1

    -- Collect failing items grouped by category
    local failCats = {}   -- ordered list of {cat, items}
    local failCatIdx = {} -- cat → index in failCats
    for _, item in ipairs(summary.items) do
        if item.status == "fail" then
            if not failCatIdx[item.category] then
                failCatIdx[item.category] = #failCats + 1
                failCats[#failCats + 1] = { cat = item.category, items = {} }
            end
            local bucket = failCats[failCatIdx[item.category]]
            bucket.items[#bucket.items + 1] = item
        end
    end

    if #failCats > 0 and ri <= 20 then
        miniFrame.rows[ri]:SetFontObject(GameFontNormalSmall)
        miniFrame.rows[ri]:SetText("|cffff5a4cFailing:|r")
        miniFrame.rows[ri]:Show()
        ri = ri + 1
        for _, bucket in ipairs(failCats) do
            if ri > 20 then break end
            miniFrame.rows[ri]:SetText("|cffcc8844" .. bucket.cat .. ":|r")
            miniFrame.rows[ri]:Show()
            ri = ri + 1
            for _, item in ipairs(bucket.items) do
                if ri > 20 then break end
                miniFrame.rows[ri]:SetText("  |cffff5a4c" .. item.name .. "|r")
                miniFrame.rows[ri]:Show()
                ri = ri + 1
            end
        end
    end

    -- Collect ALL inactive items, sort by level, take first 3, then group
    local allInactive = {}
    for _, item in ipairs(summary.items) do
        if item.status == "inactive" then
            local lvl = item.detail and tonumber(item.detail:match("level (%d+)")) or 99
            allInactive[#allInactive + 1] = { item = item, lvl = lvl }
        end
    end
    table.sort(allInactive, function(a, b) return a.lvl < b.lvl end)

    local upCats = {}
    local upCatIdx = {}
    for i = 1, math.min(3, #allInactive) do
        local item = allInactive[i].item
        if not upCatIdx[item.category] then
            upCatIdx[item.category] = #upCats + 1
            upCats[#upCats + 1] = { cat = item.category, items = {} }
        end
        local bucket = upCats[upCatIdx[item.category]]
        bucket.items[#bucket.items + 1] = item
    end

    if #upCats > 0 and ri <= 20 then
        -- Spacer before upcoming
        miniFrame.rows[ri]:SetText(" ")
        miniFrame.rows[ri]:Show()
        ri = ri + 1
        miniFrame.rows[ri]:SetFontObject(GameFontNormalSmall)
        miniFrame.rows[ri]:SetText("|cff888888Upcoming:|r")
        miniFrame.rows[ri]:Show()
        ri = ri + 1
        for _, bucket in ipairs(upCats) do
            if ri > 20 then break end
            miniFrame.rows[ri]:SetText("|cff777766" .. bucket.cat .. ":|r")
            miniFrame.rows[ri]:Show()
            ri = ri + 1
            for _, item in ipairs(bucket.items) do
                if ri > 20 then break end
                local lvl = item.detail and item.detail:match("level (%d+)")
                local dispName = item.name
                if lvl and #dispName > 18 then
                    dispName = dispName:sub(1, 16) .. ".."
                end
                miniFrame.rows[ri]:SetText("  |cff595959" .. dispName .. "|r")
                miniFrame.rows[ri]:Show()
                if lvl then
                    miniFrame.rowsR[ri]:SetText("|cff666655(lv " .. lvl .. ")|r")
                    miniFrame.rowsR[ri]:Show()
                end
                ri = ri + 1
            end
        end
    end

    -- Resize frame to fit content
    local contentH = 8 + (miniFrame.rankText:GetStringHeight() or 14) + 4 + (ri - 1) * MINI_ROW_H + 8
    miniFrame:SetHeight(math.max(contentH, 40))
end

function Panel.Minimize()
    BuildMiniPanel()
    if frame then frame:Hide() end
    miniFrame:Show()
    db().minimized = true
    db().shown = true
    Panel.RefreshMini()
end

function Panel.Restore()
    if miniFrame then miniFrame:Hide() end
    db().minimized = false
    Panel.Show()
end

----------------------------------------------------------------------
-- Show / hide / toggle
----------------------------------------------------------------------

function Panel.Show()
    BuildFrame()
    frame:Show()
    db().shown = true
    db().minimized = false
    Panel.Refresh()
end

function Panel.Hide()
    if frame then frame:Hide() end
    if miniFrame then miniFrame:Hide() end
    db().shown = false
    db().minimized = false
end

function Panel.Toggle()
    BuildFrame()
    if frame:IsShown() then
        Panel.Hide()
    elseif miniFrame and miniFrame:IsShown() then
        Panel.Restore()
    else
        Panel.Show()
    end
end

function Panel.IsShown()
    return frame and frame:IsShown()
end

-- Expose under FCE so the main file's slash command can call it
FCE.TogglePanel   = Panel.Toggle
FCE.ShowPanel     = Panel.Show
FCE.HidePanel     = Panel.Hide
FCE.IsShownPanel  = Panel.IsShown
FCE.RefreshPanel = Panel.Refresh

----------------------------------------------------------------------
-- Minimap button backend selection
----------------------------------------------------------------------

local minimapBackend

local function MinimapSettings()
    local panelDB = db()
    panelDB.minimap = panelDB.minimap or { angle = 215, hide = false }
    return panelDB.minimap
end

local function HandleMinimapClick(_, button)
    if button == "RightButton" then
        local panelDB = db()
        panelDB.locked = not panelDB.locked
        Panel.UpdatePinIcon()
        FCE.Print(panelDB.locked and "Requirements panel locked." or "Requirements panel unlocked.")
        return
    end

    if not FCE_CharDB or not FCE_CharDB.selectedCharacter then
        if FCE.CatalogUI then
            if FCE.CatalogUI.IsShown and FCE.CatalogUI.IsShown() then
                FCE.CatalogUI.Hide()
            elseif FCE.CatalogUI.ShowForPlayer then
                FCE.CatalogUI.ShowForPlayer()
            end
        end
    else
        Panel.Toggle()
    end
end

local function AddMinimapTooltip(tooltip)
    tooltip:AddLine("Forever Classes Enhanced")
    if not FCE_CharDB or not FCE_CharDB.selectedCharacter then
        tooltip:AddLine("|cffffffffLeft-click|r open class catalog", 1, 1, 1)
    else
        tooltip:AddLine("|cffffffffLeft-click|r toggle requirements panel", 1, 1, 1)
    end
    tooltip:AddLine("|cffffffffRight-click|r lock/unlock panel", 1, 1, 1)
    tooltip:AddLine("|cffffffffDrag|r move this button", 1, 1, 1)
end

local function BuildMinimapButton()
    if minimapBackend then return minimapBackend end

    local backendName
    local preference = MinimapSettings().backend or "auto"
    local options = {
        GetSettings = MinimapSettings,
        OnClick = HandleMinimapClick,
        OnTooltipShow = AddMinimapTooltip,
    }

    local broker = FCE.MinimapButtonBroker
    if preference ~= "standalone" and broker and broker.Create(options) then
        minimapBackend = broker
        backendName = "LibDBIcon"
    else
        if preference == "broker" then
            FCE.Print("LibDBIcon backend requested but unavailable; using standalone.")
        end
        local standalone = FCE.MinimapButtonStandalone
        if not standalone then
            FCE.Print("Unable to create minimap button: no backend loaded.")
            return nil
        end
        standalone.Create(options)
        minimapBackend = standalone
        backendName = "standalone"
    end

    if preference ~= "auto" then
        FCE.Print("Minimap button backend: " .. backendName)
    end

    if MinimapSettings().hide then
        minimapBackend.Hide()
    else
        minimapBackend.Show()
    end
    return minimapBackend
end

function Panel.ShowMinimapButton()
    MinimapSettings().hide = false
    local backend = BuildMinimapButton()
    if backend then backend.Show() end
end

function Panel.HideMinimapButton()
    MinimapSettings().hide = true
    local backend = BuildMinimapButton()
    if backend then backend.Hide() end
end

function Panel.GetMinimapBackendPreference()
    return MinimapSettings().backend or "auto"
end

function Panel.SetMinimapBackendPreference(preference)
    if preference ~= "auto" and preference ~= "broker" and preference ~= "standalone" then
        return false
    end
    MinimapSettings().backend = preference
    return true
end

FCE.ShowMinimapButton = Panel.ShowMinimapButton
FCE.HideMinimapButton = Panel.HideMinimapButton

----------------------------------------------------------------------
-- Event hookup (for live refresh)
----------------------------------------------------------------------

local liveFrame = CreateFrame("Frame")
liveFrame:RegisterEvent("PLAYER_LOGIN")
liveFrame:RegisterEvent("PLAYER_LEVEL_UP")
liveFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
liveFrame:RegisterEvent("SKILL_LINES_CHANGED")
liveFrame:RegisterEvent("CHARACTER_POINTS_CHANGED")
liveFrame:RegisterEvent("UNIT_AURA")
liveFrame:RegisterEvent("UNIT_PET")
pcall(function() liveFrame:RegisterEvent("COMPANION_UPDATE") end)
liveFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
liveFrame:RegisterEvent("ZONE_CHANGED")
pcall(function() liveFrame:RegisterEvent("PLAYER_UPDATE_RESTING") end)
liveFrame:RegisterEvent("BAG_UPDATE")
liveFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        -- Defer a tick so SavedVariables + CharacterData are ready
        C_Timer.After(1.2, function()
            BuildFrame()
            BuildMinimapButton()
            if db().shown then
                if db().minimized then
                    Panel.Minimize()
                else
                    Panel.Show()
                end
            end
            Panel.Refresh()
        end)
    elseif event == "PLAYER_LEVEL_UP" then
        -- Player level isn't updated until the next frame; defer.
        C_Timer.After(0.1, Panel.Refresh)
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        -- EquipmentCheck.lua handles the actual check and calls
        -- RefreshPanel, but if it hasn't loaded yet we still refresh.
        C_Timer.After(0.5, Panel.Refresh)
    elseif event == "SKILL_LINES_CHANGED" then
        -- ProfessionCheck.lua handles the actual check and calls
        -- RefreshPanel, but we also refresh here as a fallback.
        C_Timer.After(0.5, Panel.Refresh)
    elseif event == "CHARACTER_POINTS_CHANGED" then
        -- TalentCheck.lua handles the actual check and calls
        -- RefreshPanel, but we also refresh here as a fallback.
        C_Timer.After(0.5, Panel.Refresh)
    elseif event == "UNIT_AURA" then
        local unit = ...
        if unit == "player" then
            -- SelfFoundCheck.lua handles the actual check and calls
            -- RefreshPanel, but we also refresh here as a fallback.
            C_Timer.After(0.5, Panel.Refresh)
        end
    elseif event == "UNIT_PET" then
        local unit = ...
        if unit == "player" then
            -- ChallengeCheck (Imp/No demon) reacts to pet changes.
            C_Timer.After(0.5, Panel.Refresh)
        end
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        -- Homebound / zone-visit challenges react to zone changes.
        C_Timer.After(0.7, Panel.Refresh)
    elseif event == "ZONE_CHANGED" or event == "PLAYER_UPDATE_RESTING" then
        -- Nocturnal/Diurnal challenges react to entering/leaving rest areas.
        C_Timer.After(0.3, Panel.Refresh)
    elseif event == "BAG_UPDATE" then
        -- Bag contents changed -- refresh for herb pouch / consumable checks.
        C_Timer.After(0.6, Panel.Refresh)
    end
end)

-- Periodic timer for time-of-day challenges (Nocturnal/Diurnal).
-- Checks every 60 seconds so the panel updates when server hour changes.
C_Timer.NewTicker(60, function()
    if Panel.frame and Panel.frame:IsShown() then
        Panel.Refresh()
    end
end)
