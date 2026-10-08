----------------------------------------------------------------------
-- ForeverClassesEnhanced — Achievement System
--
-- Account-wide tracking of enhanced class progress + guild
-- announcements for rank-ups and requirement completions.
--
-- Features:
--   1) Account DB (FCE_AccountDB): persists rank/pct for every
--      character that reaches Adept (25%+).  If a character changes
--      class the entry is overwritten, not duplicated.
--   2) Achievement Panel: scrollable list of all tracked characters,
--      showing rank, enhanced class name, and completion %.
--   3) Guild Announcements: automatic GUILD chat messages on
--      rank-ups and qualifying requirement completions.
--
-- Qualifying requirements for guild announcements:
--   • Challenges with level > 1
--   • Equipment  with level > 1 (excluding show/hide cloak/helm)
--   • Quest requirements
--   • Companion / pet / mount requirements
----------------------------------------------------------------------


local SendChatMessage
    = FCE.Compat.SendChatMessage  -- Forever API shims (ForeverCompat.lua)
FCE = FCE or {}

local Achieve = {}
FCE.Achieve = Achieve

----------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------

local ADEPT_THRESHOLD = 25   -- minimum % to be tracked in account DB

-- Equipment descriptions that are cosmetic-only (not announced)
local COSMETIC_EQUIP = {
    ["Show Helm"]  = true,
    ["Hide Helm"]  = true,
    ["Show Cloak"] = true,
    ["Hide Cloak"] = true,
}

----------------------------------------------------------------------
-- Account DB helpers
----------------------------------------------------------------------

local function ensureDB()
    FCE_AccountDB = FCE_AccountDB or {}
    FCE_AccountDB.characters = FCE_AccountDB.characters or {}
    return FCE_AccountDB
end

--- Save (or update) the current character's progress in the account DB.
--- Called after every rank check so the panel stays current.
function Achieve.SaveCurrent()
    if not FCE_CharDB or not FCE_CharDB.selectedCharacter then return end
    local key = FCE_CharDB.selectedCharacter
    local char = FCE.GetCharacter and FCE.GetCharacter(key)
    if not char then return end

    local summary = FCE.Progress and FCE.Progress.Collect and FCE.Progress.Collect()
    if not summary or not summary.counts then return end
    local pct  = FCE.Progress.Percentage(summary.counts)
    local rank = FCE.Progress.GetRank(pct)

    -- Only persist Adept+ characters
    if pct < ADEPT_THRESHOLD then return end

    local db = ensureDB()

    -- Unique key: player name + realm (so alts on different realms don't clash)
    local realm  = GetRealmName and GetRealmName() or "Unknown"
    local player = UnitName and UnitName("player") or "Unknown"
    local dbKey  = player .. "-" .. realm

    local displayName = FCE.GetCharDisplayName and FCE.GetCharDisplayName(char) or char.name
    local faction = UnitFactionGroup and UnitFactionGroup("player") or nil

    db.characters[dbKey] = {
        charKey     = key,
        displayName = displayName,
        className   = char.name,
        baseClass   = char.class,
        spec        = char.spec or "",
        rank        = rank,
        pct         = pct,
        level       = UnitLevel and UnitLevel("player") or 1,
        faction     = faction,
        lastUpdate  = time(),
    }
end

--- Get a sorted list of all tracked characters (highest pct first).
function Achieve.GetAll()
    local db = ensureDB()
    local list = {}
    for dbKey, entry in pairs(db.characters) do
        entry._dbKey = dbKey
        list[#list + 1] = entry
    end
    table.sort(list, function(a, b)
        if a.pct == b.pct then return a.displayName < b.displayName end
        return a.pct > b.pct
    end)
    return list
end

----------------------------------------------------------------------
-- Guild chat announcements
----------------------------------------------------------------------

local function isInGuild()
    return IsInGuild and IsInGuild()
end

local function guildEnabled()
    return FCE_GlobalDB and FCE_GlobalDB.guildAnnounce
end

--- Persistent dedup tables stored in FCE_CharDB so announcements
--- survive /reload and relog.  Each is a set: key → true.
local function ensureDedup()
    if not FCE_CharDB then return end
    FCE_CharDB.announcedRanks = FCE_CharDB.announcedRanks or {}
    FCE_CharDB.announcedReqs  = FCE_CharDB.announcedReqs  or {}
end

--- Announce a rank-up to guild chat (once per rank, ever).
--- Rank-up messages cannot be opted out of — they always fire.
function Achieve.AnnounceRankUp(rank, displayName, pct)
    if not isInGuild() then return end
    ensureDedup()
    if FCE_CharDB.announcedRanks[rank] then return end
    FCE_CharDB.announcedRanks[rank] = true
    local msg = "[FCE] Rank Up! I just reached " .. rank .. " rank as a " .. displayName
        .. "! I'm at " .. pct .. "% progress towards becoming a Master " .. displayName .. "."
    SendChatMessage(msg, "GUILD")
end

--- Announce a qualifying requirement completion to guild chat (once per req, ever).
--- Controlled by FCE_GlobalDB.guildAnnounceReqs (can be toggled in settings).
function Achieve.AnnounceRequirement(reqName, category, displayName)
    if not (FCE_GlobalDB and FCE_GlobalDB.guildAnnounceReqs) then return end
    if not isInGuild() then return end
    ensureDedup()
    local dedupKey = category .. "|" .. reqName
    if FCE_CharDB.announcedReqs[dedupKey] then return end
    FCE_CharDB.announcedReqs[dedupKey] = true
    local pct = 0
    if FCE.Progress and FCE.Progress.Collect then
        local summary = FCE.Progress.Collect()
        if summary and summary.counts then
            pct = FCE.Progress.Percentage(summary.counts)
        end
    end
    local msg = "[FCE] Requirement completed: " .. reqName .. " (" .. category .. "). I'm at " .. pct .. "% progress towards becoming a Master " .. displayName .. "."
    SendChatMessage(msg, "GUILD")
end

----------------------------------------------------------------------
-- Requirement state tracking — detect FAIL → PASS transitions
----------------------------------------------------------------------
-- We snapshot requirement states after each collect and compare with
-- the previous snapshot to find newly-completed requirements.

local prevSnapshot = nil   -- { [category.."|"..name] = status }

--- Decide whether a requirement qualifies for guild announcement.
local function isQualifying(item, char)
    local cat = item.category

    -- Quests, Companions (includes companion, pet, mount) always qualify
    if cat == "Quests" or cat == "Companions" then
        return true
    end

    -- Challenges: only if the underlying data has level > 1
    if cat == "Challenges" then
        local challenges = FCE.GetActiveChallenges and FCE.GetActiveChallenges(char) or char.challenges or {}
        for _, ch in ipairs(challenges) do
            if ch.desc == item.name and ch.level and ch.level > 1 then
                return true
            end
        end
        return false
    end

    -- Equipment: level > 1 and not cosmetic
    if cat == "Equipment" then
        if COSMETIC_EQUIP[item.name] then return false end
        local equipment = FCE.GetCharEquipment and FCE.GetCharEquipment(char) or {}
        for _, eq in ipairs(equipment) do
            if eq.desc == item.name and eq.level and eq.level > 1 then
                return true
            end
        end
        return false
    end

    return false
end

--- Build a snapshot table from progress items.
local function buildSnapshot(items)
    local snap = {}
    for _, item in ipairs(items) do
        snap[item.category .. "|" .. item.name] = item.status
    end
    return snap
end

--- Compare current snapshot with previous, announce newly-passed qualifying reqs.
function Achieve.CheckRequirementTransitions()
    if not FCE_CharDB or not FCE_CharDB.selectedCharacter then return end
    local char = FCE.GetCharacter and FCE.GetCharacter(FCE_CharDB.selectedCharacter)
    if not char then return end

    local summary = FCE.Progress and FCE.Progress.Collect and FCE.Progress.Collect()
    if not summary or not summary.items then return end

    local currentSnap = buildSnapshot(summary.items)

    if prevSnapshot then
        local displayName = FCE.GetCharDisplayName and FCE.GetCharDisplayName(char) or char.name
        for _, item in ipairs(summary.items) do
            local snapKey = item.category .. "|" .. item.name
            local oldStatus = prevSnapshot[snapKey]
            -- Detect transition to PASS from a non-PASS state
            if item.status == "pass" and oldStatus and oldStatus ~= "pass" then
                if isQualifying(item, char) then
                    Achieve.AnnounceRequirement(item.name, item.category, displayName)
                end
            end
        end
    end

    prevSnapshot = currentSnap
end

----------------------------------------------------------------------
-- Hook into Progress.CheckRankUp — wrap it to also save to account DB
-- and announce rank-ups to guild.
----------------------------------------------------------------------

function Achieve.HookRankUp()
    if not FCE.Progress or not FCE.Progress.CheckRankUp then return end

    local originalCheckRankUp = FCE.Progress.CheckRankUp

    FCE.Progress.CheckRankUp = function()
        -- Capture rank before the original call
        local oldRank = FCE_CharDB and FCE_CharDB.currentRank

        -- Run original rank-up logic (sets FCE_CharDB.currentRank, fires popup)
        originalCheckRankUp()

        -- Save to account DB regardless
        Achieve.SaveCurrent()

        -- Check for requirement transitions
        Achieve.CheckRequirementTransitions()

        -- If rank actually changed upward, announce to guild
        local newRank = FCE_CharDB and FCE_CharDB.currentRank
        if oldRank and newRank and oldRank ~= newRank then
            -- Check direction — RANK_TIERS is highest first
            local tiers = { Master = 1, Elite = 2, Prime = 3, Adept = 4, Initiate = 5 }
            local oldIdx = tiers[oldRank] or 99
            local newIdx = tiers[newRank] or 99
            if newIdx < oldIdx then
                -- Rank up!
                local char = FCE_CharDB.selectedCharacter and FCE.GetCharacter and FCE.GetCharacter(FCE_CharDB.selectedCharacter)
                if char then
                    local displayName = FCE.GetCharDisplayName and FCE.GetCharDisplayName(char) or char.name
                    local summary = FCE.Progress.Collect()
                    local pct = FCE.Progress.Percentage(summary.counts)
                    Achieve.AnnounceRankUp(newRank, displayName, pct)
                end
            end
        end
    end
end

----------------------------------------------------------------------
-- Achievement Panel UI
----------------------------------------------------------------------

local achieveFrame   -- the panel itself

local PANEL_W = 220
local PANEL_H = 300
local ROW_H   = 18
local PAD     = 12

local RANK_COLORS = {
    Master   = "ff8000",
    Elite    = "a335ee",
    Prime    = "0070dd",
    Adept    = "1eff00",
    Initiate = "ffffff",
}

local CLASS_COLORS = {
    WARRIOR = "c79c6e", ROGUE   = "fff569", MAGE    = "69ccf0",
    WARLOCK = "9482c9", PRIEST  = "ffffff", PALADIN = "f58cba",
    DRUID   = "ff7d0a", SHAMAN  = "0070de", HUNTER  = "abd473",
}

local function createPanel()
    if achieveFrame then return achieveFrame end

    achieveFrame = CreateFrame("Frame", "FCE_AchievementPanel", UIParent, "BackdropTemplate")
    achieveFrame:SetSize(PANEL_W, PANEL_H)
    achieveFrame:SetPoint("CENTER")
    achieveFrame:SetFrameStrata("HIGH")
    achieveFrame:SetMovable(true)
    achieveFrame:EnableMouse(true)
    achieveFrame:RegisterForDrag("LeftButton")
    achieveFrame:SetScript("OnDragStart", achieveFrame.StartMoving)
    achieveFrame:SetScript("OnDragStop", achieveFrame.StopMovingOrSizing)
    achieveFrame:SetClampedToScreen(true)

    if achieveFrame.SetBackdrop then
        achieveFrame:SetBackdrop({
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
            tile     = true, tileSize = 32, edgeSize = 24,
            insets   = { left = 6, right = 6, top = 6, bottom = 6 },
        })
        achieveFrame:SetBackdropColor(0.06, 0.06, 0.08, 0.96)
    end

    -- Title
    local title = achieveFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -14)
    title:SetText("|cffe6b422Account Achievements|r")

    -- Close button
    local closeBtn = CreateFrame("Button", nil, achieveFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() achieveFrame:Hide() end)

    -- Subtitle
    local subtitle = achieveFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -4)
    subtitle:SetTextColor(0.7, 0.7, 0.7)
    achieveFrame._subtitle = subtitle

    -- Column headers — anchored to frame edges so they don't shift
    local hdrName = achieveFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hdrName:SetPoint("TOPLEFT", achieveFrame, "TOPLEFT", PAD + 6, -52)
    hdrName:SetTextColor(0.85, 0.70, 0.20)
    hdrName:SetText("Class")
    local hdrRank = achieveFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hdrRank:SetPoint("TOPRIGHT", achieveFrame, "TOPRIGHT", -PAD - 20, -52)
    hdrRank:SetTextColor(0.85, 0.70, 0.20)
    hdrRank:SetJustifyH("RIGHT")
    hdrRank:SetText("Rank")

    -- Content area (no scroll frame — simple direct children)
    local contentFrame = CreateFrame("Frame", nil, achieveFrame)
    contentFrame:SetPoint("TOPLEFT", hdrName, "BOTTOMLEFT", 0, -4)
    contentFrame:SetPoint("TOPRIGHT", hdrRank, "BOTTOMRIGHT", 0, -4)
    contentFrame:SetPoint("BOTTOM", achieveFrame, "BOTTOM", 0, PAD + 4)
    achieveFrame._content = contentFrame

    achieveFrame:Hide()
    tinsert(UISpecialFrames, "FCE_AchievementPanel")  -- ESC to close
    return achieveFrame
end

--- Populate the panel with current account data.
function Achieve.RefreshPanel()
    local panel = createPanel()
    local content = panel._content

    -- Clear old rows
    local kids = { content:GetChildren() }
    for _, kid in ipairs(kids) do kid:Hide(); kid:SetParent(nil) end
    local regions = { content:GetRegions() }
    for _, r in ipairs(regions) do r:Hide() end

    local entries = Achieve.GetAll()
    panel._subtitle:SetText(#entries .. " enhanced class" .. (#entries == 1 and "" or "es") .. " tracked")

    if #entries == 0 then
        local empty = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        empty:SetPoint("TOPLEFT", 4, -10)
        empty:SetWidth(PANEL_W - 44)
        empty:SetJustifyH("LEFT")
        empty:SetText("|cff999999No characters have reached Adept rank yet.\nKeep playing to earn your first achievement!|r")
        content:SetHeight(60)
        return
    end

    local rowW = content:GetWidth()
    if rowW < 10 then rowW = PANEL_W - 44 end  -- fallback before layout
    local yOff = -2
    for i, entry in ipairs(entries) do
        local row = CreateFrame("Frame", nil, content)
        row:SetPoint("TOPLEFT", 0, yOff)
        row:SetPoint("RIGHT", content, "RIGHT", 0, 0)
        row:SetHeight(ROW_H)

        local rankCol = RANK_COLORS[entry.rank] or "ffffff"
        local classCol = CLASS_COLORS[entry.baseClass] or "ffd100"

        -- Name on the left
        local nameStr = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        nameStr:SetPoint("LEFT", 2, 0)
        nameStr:SetWidth(rowW - 60)
        nameStr:SetJustifyH("LEFT")
        nameStr:SetWordWrap(false)
        nameStr:SetText("|cff" .. classCol .. entry.displayName .. "|r")

        -- Rank on the right (colored)
        local rankStr = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        rankStr:SetPoint("RIGHT", -2, 0)
        rankStr:SetJustifyH("RIGHT")
        rankStr:SetText("|cff" .. rankCol .. entry.rank .. "|r")

        -- Tooltip with full details
        row:EnableMouse(true)
        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:ClearLines()
            GameTooltip:AddLine("|cff" .. classCol .. entry.displayName .. "|r")
            local baseClass = entry.baseClass and (entry.baseClass:sub(1,1) .. entry.baseClass:sub(2):lower()) or "?"
            GameTooltip:AddLine(entry.spec .. " " .. baseClass, 0.7, 0.7, 0.7)
            GameTooltip:AddDoubleLine("Rank:", "|cff" .. rankCol .. entry.rank .. "|r", 0.85, 0.85, 0.85)
            GameTooltip:AddDoubleLine("Progress:", entry.pct .. "%", 0.85, 0.85, 0.85)
            GameTooltip:AddDoubleLine("Level:", entry.level or "?", 0.85, 0.85, 0.85)
            if entry.lastUpdate then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Last updated: " .. date("%b %d, %Y", entry.lastUpdate), 0.5, 0.5, 0.5)
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)

        yOff = yOff - ROW_H - 2
    end
end

--- Toggle the achievement panel.
function Achieve.Toggle()
    local panel = createPanel()
    if panel:IsShown() then
        panel:Hide()
    else
        Achieve.RefreshPanel()
        panel:Show()
    end
end

----------------------------------------------------------------------
-- Button creator — called from RequirementsPanel to add the button
----------------------------------------------------------------------

function Achieve.CreateButton(titleBar, anchorButton)
    local btn = CreateFrame("Button", nil, titleBar)
    btn:SetSize(15, 15)
    btn:SetPoint("RIGHT", anchorButton, "LEFT", -4, 0)
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetAllPoints()
    btn.icon:SetTexture("Interface\\ICONS\\INV_Misc_Trophy_Argent")
    btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    btn:SetScript("OnClick", function()
        Achieve.Toggle()
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Account Achievements")
        GameTooltip:AddLine("View all your enhanced classes\nacross this account.", 0.75, 0.75, 0.75, true)
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    return btn
end

----------------------------------------------------------------------
-- Initialization — called after ADDON_LOADED
----------------------------------------------------------------------

function Achieve.Init()
    ensureDB()
    Achieve.HookRankUp()

    -- Take initial requirement snapshot so we don't announce everything
    -- as "newly completed" on first login.
    C_Timer.After(3.0, function()
        if FCE.Progress and FCE.Progress.Collect then
            local summary = FCE.Progress.Collect()
            if summary and summary.items then
                prevSnapshot = buildSnapshot(summary.items)
            end
        end
        -- Also save current progress on login
        Achieve.SaveCurrent()
    end)
end
