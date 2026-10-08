----------------------------------------------------------------------
-- ForeverClassesEnhanced — Level-Up Summary
--
-- On PLAYER_LEVEL_UP, displays a compact centre-screen summary frame
-- listing any requirements that just became active at the new level,
-- along with the current overall progress percentage.
--
-- This is the "big picture" counterpart to LevelAlert.lua's individual
-- toast banners: where those surface one-per-requirement, this shows a
-- single consolidated view that auto-dismisses after a few seconds.
--
-- Appearance: a centered charcoal panel with a gold header, a list of
-- newly active requirements with their section icon, and a progress
-- bar at the bottom.  Fades in smoothly after Blizzard's default
-- level-up fanfare finishes, holds briefly, and slides/fades out.
--
--   ┌───────────────────────────────────────────┐
--   │          LEVEL 12 · 3 new rules           │
--   │                                           │
--   │  ⚔  Shield                Equipment      │
--   │  ⚔  No daggers            Equipment      │
--   │  ☠  Homebound             Challenge       │
--   │                                           │
--   │  ▓▓▓▓▓▓▓▓▓░░░░  62% complete             │
--   │                  (click to dismiss)        │
--   └───────────────────────────────────────────┘
----------------------------------------------------------------------

FCE = FCE or {}

local Summary = {}
FCE.LevelUpSummary = Summary

----------------------------------------------------------------------
-- Tunables
----------------------------------------------------------------------

local MAX_VISIBLE_ROWS = 6       -- truncate if many reqs flip at once
local DELAY_AFTER_DING = 2.5     -- seconds after PLAYER_LEVEL_UP before showing
local FADE_IN_TIME     = 0.4
local HOLD_TIME        = 8.0
local FADE_OUT_TIME    = 1.2
local FRAME_WIDTH      = 290
local ROW_HEIGHT       = 16
local PADDING_X        = 14
local PADDING_Y        = 10

----------------------------------------------------------------------
-- Colours (matched to the addon's charcoal + gold identity)
----------------------------------------------------------------------

local GOLD       = { 0.85, 0.70, 0.20 }
local GOLD_DIM   = { 0.85, 0.70, 0.20, 0.15 }
local CHARCOAL   = { 0.04, 0.05, 0.07, 0.94 }
local BORDER     = { 0.55, 0.45, 0.12, 0.80 }
local TEXT_BRIGHT = { 0.97, 0.94, 0.80 }
local TEXT_DIM    = { 0.60, 0.60, 0.55 }
local GREEN       = { 0.30, 0.90, 0.35 }
local RED         = { 1.00, 0.35, 0.30 }
local AMBER       = { 0.65, 0.65, 0.50 }

----------------------------------------------------------------------
-- Section icons (flavour glyphs, keeps it from looking like a list)
----------------------------------------------------------------------

----------------------------------------------------------------------
-- Frame construction (lazy, built once)
----------------------------------------------------------------------

local frame       -- the summary panel
local rows = {}   -- pooled row fontstrings
local headerText, subheaderText, progressBar, progressLabel, hintText
local progressBg, progressFill

local function buildFrame()
    if frame then return end

    frame = CreateFrame("Button", "HCE_LevelUpSummaryFrame", UIParent, "BackdropTemplate")
    frame:SetFrameStrata("DIALOG")
    frame:SetSize(FRAME_WIDTH, 100)  -- height is dynamic
    frame:SetPoint("TOP", UIParent, "TOP", 0, -220)
    frame:Hide()

    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
            edgeSize = 16,
            insets   = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        frame:SetBackdropColor(0.06, 0.06, 0.08, 0.96)
        frame:SetBackdropBorderColor(1.0, 0.85, 0.45, 0.95)
    end

    -- Top gold wash
    local wash = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    wash:SetColorTexture(GOLD_DIM[1], GOLD_DIM[2], GOLD_DIM[3], GOLD_DIM[4])
    wash:SetPoint("TOPLEFT", 4, -4)
    wash:SetPoint("TOPRIGHT", -4, -4)
    wash:SetHeight(28)

    -- Header: "LEVEL 12"
    headerText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerText:SetPoint("TOP", frame, "TOP", 0, -PADDING_Y)
    headerText:SetTextColor(GOLD[1], GOLD[2], GOLD[3])

    -- Subheader: "3 new requirements active"
    subheaderText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subheaderText:SetPoint("TOP", headerText, "BOTTOM", 0, -2)
    subheaderText:SetTextColor(TEXT_DIM[1], TEXT_DIM[2], TEXT_DIM[3])

    -- Progress bar background
    progressBg = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    progressBg:SetHeight(10)
    progressBg:SetPoint("LEFT", frame, "LEFT", PADDING_X, 0)
    progressBg:SetPoint("RIGHT", frame, "RIGHT", -PADDING_X, 0)
    if progressBg.SetBackdrop then
        progressBg:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets   = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        progressBg:SetBackdropColor(0.08, 0.08, 0.10, 0.90)
        progressBg:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.50)
    end

    -- Progress bar fill
    progressFill = progressBg:CreateTexture(nil, "ARTWORK")
    progressFill:SetPoint("TOPLEFT", progressBg, "TOPLEFT", 1, -1)
    progressFill:SetPoint("BOTTOMLEFT", progressBg, "BOTTOMLEFT", 1, 1)
    progressFill:SetColorTexture(GREEN[1], GREEN[2], GREEN[3], 0.85)

    -- Progress label (right of bar)
    progressLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    progressLabel:SetPoint("TOP", progressBg, "BOTTOM", 0, -3)
    progressLabel:SetTextColor(TEXT_DIM[1], TEXT_DIM[2], TEXT_DIM[3])

    -- Hint text at bottom
    hintText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hintText:SetPoint("BOTTOM", frame, "BOTTOM", 0, 6)
    hintText:SetTextColor(TEXT_DIM[1], TEXT_DIM[2], TEXT_DIM[3], 0.6)
    hintText:SetText("click to dismiss")

    -- Click to dismiss
    frame:RegisterForClicks("AnyUp")
    frame:SetScript("OnClick", function(self)
        self.state = "out"
        self.elapsed = 0
    end)

    -- Hover effect
    frame:SetScript("OnEnter", function(self)
        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 1)
        end
        if self.state == "hold" then
            self.hoverPaused = true
        end
    end)
    frame:SetScript("OnLeave", function(self)
        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(BORDER[1], BORDER[2], BORDER[3], BORDER[4])
        end
        self.hoverPaused = false
    end)
end

----------------------------------------------------------------------
-- Row management (fontstrings for each requirement line)
----------------------------------------------------------------------

local function getRow(index)
    if rows[index] then return rows[index] end

    local r = {}
    r.icon = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    r.icon:SetJustifyH("LEFT")
    r.icon:SetWidth(18)

    r.name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    r.name:SetJustifyH("LEFT")
    r.name:SetTextColor(TEXT_BRIGHT[1], TEXT_BRIGHT[2], TEXT_BRIGHT[3])

    r.section = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    r.section:SetJustifyH("RIGHT")
    r.section:SetTextColor(TEXT_DIM[1], TEXT_DIM[2], TEXT_DIM[3])

    rows[index] = r
    return r
end

local function positionRows(items, startY)
    local y = startY
    for i, item in ipairs(items) do
        local r = getRow(i)
        local icon = "•"

        r.icon:ClearAllPoints()
        r.icon:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING_X, y)
        r.icon:SetText(icon)
        r.icon:Show()

        r.name:ClearAllPoints()
        r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 4, 0)
        r.name:SetPoint("RIGHT", frame, "RIGHT", -80, 0)
        -- Truncate long descriptions
        local desc = item.desc or ""
        if #desc > 28 then desc = desc:sub(1, 25) .. "..." end
        r.name:SetText(desc)
        r.name:Show()

        r.section:ClearAllPoints()
        r.section:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PADDING_X, y)
        r.section:SetText(item.section or "")
        r.section:Show()

        y = y - ROW_HEIGHT
    end

    -- Hide unused rows
    for i = #items + 1, #rows do
        if rows[i] then
            rows[i].icon:Hide()
            rows[i].name:Hide()
            rows[i].section:Hide()
        end
    end

    return y
end

----------------------------------------------------------------------
-- Animation (fade in → hold → fade out)
----------------------------------------------------------------------

local function startAnimation()
    frame:SetAlpha(0)
    frame.elapsed = 0
    frame.state = "in"
    frame.hoverPaused = false
    frame:Show()

    frame:SetScript("OnUpdate", function(self, dt)
        self.elapsed = self.elapsed + dt

        if self.state == "in" then
            local p = math.min(self.elapsed / FADE_IN_TIME, 1)
            self:SetAlpha(p)
            if p >= 1 then
                self.state = "hold"
                self.elapsed = 0
                self:SetAlpha(1)
            end
        elseif self.state == "hold" then
            if not self.hoverPaused then
                if self.elapsed >= HOLD_TIME then
                    self.state = "out"
                    self.elapsed = 0
                end
            end
        elseif self.state == "out" then
            local p = math.min(self.elapsed / FADE_OUT_TIME, 1)
            self:SetAlpha(1 - p)
            if p >= 1 then
                self:SetScript("OnUpdate", nil)
                self:Hide()
            end
        end
    end)
end

----------------------------------------------------------------------
-- Public: show the level-up summary
----------------------------------------------------------------------

--- Display the level-up summary frame with the given new requirements.
-- @param newLevel  number — the level the player just reached
-- @param items    list of { section, desc, level } — newly active reqs
function Summary.Show(newLevel, items)
    -- Respect the global alert toggle
    if FCE_GlobalDB and FCE_GlobalDB.alertsEnabled == false then return end

    -- Nothing new? Don't show an empty frame
    if not items or #items == 0 then return end

    buildFrame()

    -- If already showing, dismiss and restart
    if frame:IsShown() then
        frame:SetScript("OnUpdate", nil)
        frame:Hide()
    end

    -- Header
    headerText:SetText("LEVEL " .. tostring(newLevel))

    -- Subheader
    local count = #items
    if count == 1 then
        subheaderText:SetText("1 new requirement active")
    else
        subheaderText:SetText(count .. " new requirements active")
    end

    -- Truncate visible items to MAX_VISIBLE_ROWS
    local displayItems = items
    local truncated = false
    if #items > MAX_VISIBLE_ROWS then
        displayItems = {}
        for i = 1, MAX_VISIBLE_ROWS do
            displayItems[i] = items[i]
        end
        truncated = true
    end

    -- Position requirement rows
    local rowStartY = -PADDING_Y - 14 - 14 - 8  -- below header + subheader + gap
    local bottomOfRows = positionRows(displayItems, rowStartY)

    -- Show "and N more..." if truncated
    if truncated then
        local extra = #items - MAX_VISIBLE_ROWS
        local moreRow = getRow(MAX_VISIBLE_ROWS + 1)
        moreRow.icon:ClearAllPoints()
        moreRow.icon:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING_X, bottomOfRows)
        moreRow.icon:SetText("")
        moreRow.icon:Show()
        moreRow.name:ClearAllPoints()
        moreRow.name:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING_X, bottomOfRows)
        moreRow.name:SetText("|cff" .. "a5a582" .. "...and " .. extra .. " more|r")
        moreRow.name:Show()
        moreRow.section:Hide()
        bottomOfRows = bottomOfRows - ROW_HEIGHT

        -- Hide any rows after the "more" row
        for i = MAX_VISIBLE_ROWS + 2, #rows do
            if rows[i] then
                rows[i].icon:Hide()
                rows[i].name:Hide()
                rows[i].section:Hide()
            end
        end
    end

    -- Progress bar placement
    local barY = bottomOfRows - 10
    progressBg:ClearAllPoints()
    progressBg:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING_X, barY)
    progressBg:SetPoint("RIGHT", frame, "RIGHT", -PADDING_X, 0)

    -- Update progress data
    local pct = 0
    if FCE.Progress and FCE.Progress.Collect then
        local data = FCE.Progress.Collect()
        pct = FCE.Progress.Percentage(data.counts)
    end

    -- Size the fill
    local barInnerW = FRAME_WIDTH - (PADDING_X * 2) - 2
    local fillW = math.max(1, math.floor(barInnerW * pct / 100))
    progressFill:SetWidth(fillW)

    -- Colour based on percentage
    if pct >= 80 then
        progressFill:SetColorTexture(GREEN[1], GREEN[2], GREEN[3], 0.85)
    elseif pct >= 50 then
        progressFill:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.85)
    else
        progressFill:SetColorTexture(RED[1], RED[2], RED[3], 0.85)
    end

    -- Progress label
    progressLabel:ClearAllPoints()
    progressLabel:SetPoint("TOP", progressBg, "BOTTOM", 0, -3)
    progressLabel:SetText(pct .. "% complete")

    -- Hint below progress
    hintText:ClearAllPoints()
    hintText:SetPoint("TOP", progressLabel, "BOTTOM", 0, -4)

    -- Calculate total frame height
    local totalH = math.abs(barY) + 10 + 3 + 14 + 4 + 14 + PADDING_Y
    frame:SetHeight(totalH)

    -- Animate
    startAnimation()
end

----------------------------------------------------------------------
-- Hook into LevelAlert's event flow
----------------------------------------------------------------------
-- LevelAlert already computes the "flipped" requirements — we piggyback
-- on that by wrapping Alert.Check to capture the data it uses.

local hookInstalled = false

local function installHook()
    if hookInstalled then return end
    hookInstalled = true

    -- We hook into the PLAYER_LEVEL_UP event with a slightly longer delay
    -- than LevelAlert uses (it fires at 0.15s).  This ensures:
    --   1) The player sees Blizzard's fanfare first
    --   2) The individual toasts from LevelAlert are already queuing
    --   3) Our summary appears as a complementary "here's the big picture"
    local summaryFrame = CreateFrame("Frame")
    summaryFrame:RegisterEvent("PLAYER_LEVEL_UP")
    summaryFrame:SetScript("OnEvent", function(_, event)
        C_Timer.After(DELAY_AFTER_DING, function()
            Summary.CheckAndShow()
        end)
    end)
end

--- Compute what just flipped and show the summary.
--- Uses the same logic as LevelAlert but independent of it (since
--- LevelAlert already updated lastLevel by the time we run).
function Summary.CheckAndShow()
    if not FCE_CharDB then return end
    if FCE_GlobalDB and FCE_GlobalDB.alertsEnabled == false then return end

    local key = FCE_CharDB.selectedCharacter
    local char = key and FCE.GetCharacter and FCE.GetCharacter(key) or nil
    if not char then return end

    local current = UnitLevel("player") or 1
    -- We check (current - 1, current] — what became active at exactly this level
    local fromLevel = current - 1
    local items = {}

    -- Walk requirements and find what activates at exactly 'current'
    for _, eq in ipairs(FCE.GetCharEquipment(char)) do
        if eq.level and eq.level == current then
            table.insert(items, { section = "Equipment", desc = eq.desc, level = eq.level })
        end
    end
    local activeChallenges = FCE.GetActiveChallenges and FCE.GetActiveChallenges(char) or char.challenges or {}
    for _, ch in ipairs(activeChallenges) do
        if ch.level and ch.level == current then
            table.insert(items, { section = "Challenge", desc = ch.desc, level = ch.level })
        end
    end
    if char.companion and char.companion.level == current then
        table.insert(items, { section = "Companion", desc = char.companion.desc, level = current })
    end
    if char.pet and char.pet.level == current then
        table.insert(items, { section = "Hunter pet", desc = char.pet.desc, level = current })
    end
    if char.mount and char.mount.level == current then
        table.insert(items, { section = "Mount", desc = char.mount.desc, level = current })
    end

    -- Also check professions (level 5 gate) and talents (level 10 gate)
    if current == 5 and char.professions and #char.professions > 0 then
        for _, prof in ipairs(char.professions) do
            table.insert(items, { section = "Equipment", desc = prof .. " required", level = 5 })
        end
    end
    if current == 10 and char.spec then
        table.insert(items, { section = "Challenge", desc = "Spec: " .. char.spec, level = 10 })
    end

    -- Sort by section for visual grouping
    local sectionOrder = { Equipment = 1, Challenge = 2, Companion = 3, ["Hunter pet"] = 4, Mount = 5 }
    table.sort(items, function(a, b)
        local oa = sectionOrder[a.section] or 99
        local ob = sectionOrder[b.section] or 99
        if oa ~= ob then return oa < ob end
        return (a.desc or "") < (b.desc or "")
    end)

    Summary.Show(current, items)
end

----------------------------------------------------------------------
-- Test command: /fce testsummary
----------------------------------------------------------------------

function Summary.Test()
    local fakeItems = {
        { section = "Equipment", desc = "Shield",         level = 12 },
        { section = "Equipment", desc = "No daggers",     level = 12 },
        { section = "Challenge", desc = "Homebound",      level = 12 },
        { section = "Companion", desc = "Owl",            level = 12 },
    }
    Summary.Show(12, fakeItems)
end

----------------------------------------------------------------------
-- Init: install the event hook on load
----------------------------------------------------------------------

installHook()
