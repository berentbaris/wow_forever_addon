----------------------------------------------------------------------
-- ForeverClassesEnhanced — Level-gated Requirement Surfacing
--
-- When a previously grey ("lv N") requirement becomes active because
-- the player crossed its level gate, fire a toast alert describing
-- the newly unlocked rule.  Also catches level-ups that happened
-- between sessions (e.g. dinged in another addon/session and logged
-- back in) by comparing a persisted last-seen level on login.
--
-- Visual: a horizontal banner that slides in from the right edge of
-- the screen, stacks vertically if several fire at once, auto-fades
-- after a few seconds, and can be dismissed with a click.  Styling
-- deliberately mirrors the charcoal + gold palette of the
-- RequirementsPanel to feel like one addon.
--
--   ┌────────────────────────────────────────┐
--   │ ▌ NEW REQUIREMENT · lv 10              │
--   │ ▌ Shield                               │
--   │ ▌ Equipment                            │
--   └────────────────────────────────────────┘
----------------------------------------------------------------------

FCE = FCE or {}

local Alert = {}
FCE.Alert    = Alert

----------------------------------------------------------------------
-- Tunables
----------------------------------------------------------------------

local TOAST_WIDTH    = 300
local TOAST_HEIGHT   = 54
local TOAST_GAP      = 8
local ANCHOR_POINT   = "TOPRIGHT"       -- screen anchor corner
local ANCHOR_X       = -28
local ANCHOR_Y       = -140
local SLIDE_IN_TIME  = 0.35
local HOLD_TIME      = 6.0
local FADE_OUT_TIME  = 0.9
local SLIDE_DISTANCE = 40                -- pixels travelled during slide-in

local GOLD      = { 0.85, 0.70, 0.20 }
local GOLD_DIM  = { 0.85, 0.70, 0.20, 0.18 }
local CHARCOAL  = { 0.05, 0.06, 0.08, 0.94 }
local TEXT_BRIGHT = { 0.98, 0.95, 0.80 }
local TEXT_DIM    = { 0.75, 0.75, 0.75 }

-- Ding chime — reuse Blizzard's level-up fanfare-ish sound so we
-- don't need a custom audio file.  Not a raid alert (too loud).
local DING_SOUND = SOUNDKIT and SOUNDKIT.ALARM_CLOCK_WARNING_3 or 18871

----------------------------------------------------------------------
-- Active toast management
----------------------------------------------------------------------

local toastPool  = {}   -- reusable frames
local activeList = {}   -- currently-visible, ordered top-to-bottom

local function layoutActive()
    for i, t in ipairs(activeList) do
        t:ClearAllPoints()
        local y = ANCHOR_Y - (i - 1) * (TOAST_HEIGHT + TOAST_GAP)
        t:SetPoint(ANCHOR_POINT, UIParent, ANCHOR_POINT, ANCHOR_X, y)
    end
end

local function releaseToast(toast)
    for i, t in ipairs(activeList) do
        if t == toast then
            table.remove(activeList, i)
            break
        end
    end
    toast:Hide()
    toast.headline:SetText("")
    toast.title:SetText("")
    toast.subtitle:SetText("")
    toast.challengeKey   = nil
    toast.hoverPaused    = false
    toast.tooltipPaused  = false
    table.insert(toastPool, toast)
    layoutActive()
end

----------------------------------------------------------------------
-- Build a single toast frame
----------------------------------------------------------------------

local function buildToast()
    local t = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
    t:SetSize(TOAST_WIDTH, TOAST_HEIGHT)
    t:SetFrameStrata("HIGH")
    t:Hide()

    if t.SetBackdrop then
        t:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets   = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        t:SetBackdropColor(CHARCOAL[1], CHARCOAL[2], CHARCOAL[3], CHARCOAL[4])
        t:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.9)
    end

    -- Left accent stripe (thick gold bar) — the visual "▌" in the
    -- layout sketch above, and the main hook that reads as "FCE".
    local stripe = t:CreateTexture(nil, "ARTWORK")
    stripe:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    stripe:SetPoint("TOPLEFT", 3, -3)
    stripe:SetPoint("BOTTOMLEFT", 3, 3)
    stripe:SetWidth(4)

    -- Dim gold header wash (gives the top a subtle plate).
    local wash = t:CreateTexture(nil, "BACKGROUND")
    wash:SetColorTexture(GOLD_DIM[1], GOLD_DIM[2], GOLD_DIM[3], GOLD_DIM[4])
    wash:SetPoint("TOPLEFT", 1, -1)
    wash:SetPoint("TOPRIGHT", -1, -1)
    wash:SetHeight(18)

    -- Headline: NEW REQUIREMENT · lv 10
    t.headline = t:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    t.headline:SetPoint("TOPLEFT", 14, -4)
    t.headline:SetPoint("RIGHT", -8, 0)
    t.headline:SetJustifyH("LEFT")
    t.headline:SetTextColor(GOLD[1], GOLD[2], GOLD[3])

    -- Title: the requirement description
    t.title = t:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t.title:SetPoint("TOPLEFT", t.headline, "BOTTOMLEFT", 0, -2)
    t.title:SetPoint("RIGHT", -8, 0)
    t.title:SetJustifyH("LEFT")
    t.title:SetTextColor(TEXT_BRIGHT[1], TEXT_BRIGHT[2], TEXT_BRIGHT[3])

    -- Subtitle: section (Equipment / Challenge / Companion / Mount...)
    t.subtitle = t:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    t.subtitle:SetPoint("TOPLEFT", t.title, "BOTTOMLEFT", 0, -1)
    t.subtitle:SetPoint("RIGHT", -8, 0)
    t.subtitle:SetJustifyH("LEFT")
    t.subtitle:SetTextColor(TEXT_DIM[1], TEXT_DIM[2], TEXT_DIM[3])

    -- Left-click to dismiss, right-click to view challenge tooltip.
    t:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    t:SetScript("OnClick", function(self, btn)
        if btn == "RightButton" and self.challengeKey then
            -- Show the full challenge description in a tooltip
            local desc = FCE.ChallengeDescriptions and FCE.ChallengeDescriptions[self.challengeKey]
            if desc then
                GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                GameTooltip:ClearLines()
                GameTooltip:AddLine(self.challengeKey, GOLD[1], GOLD[2], GOLD[3])
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(desc, 0.93, 0.93, 0.93, true)
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Left-click to dismiss", TEXT_DIM[1], TEXT_DIM[2], TEXT_DIM[3])
                GameTooltip:Show()
                -- Pause auto-fade while the tooltip is open
                if self.state == "hold" then
                    self.tooltipPaused = true
                end
                return
            end
        end
        -- Default: dismiss
        GameTooltip:Hide()
        releaseToast(self)
    end)
    t:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(1, 0.92, 0.40, 1)
        -- Pause auto-fade while hovered
        if self.state == "hold" then
            self.hoverPaused = true
        end
    end)
    t:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.9)
        GameTooltip:Hide()
        -- Resume auto-fade
        self.hoverPaused = false
        self.tooltipPaused = false
    end)

    return t
end

local function acquireToast()
    local t = table.remove(toastPool)
    if t then return t end
    return buildToast()
end

----------------------------------------------------------------------
-- Animation: slide in from the right, hold, then fade out
----------------------------------------------------------------------

local function animateToast(t)
    -- Fresh alpha/offset state
    t:SetAlpha(0)
    t.offset = SLIDE_DISTANCE
    t.elapsed = 0
    t.state = "in"

    local baseX = ANCHOR_X - SLIDE_DISTANCE  -- start further right
    local function apply()
        local i = nil
        for k, other in ipairs(activeList) do
            if other == t then i = k; break end
        end
        if not i then return end
        local y = ANCHOR_Y - (i - 1) * (TOAST_HEIGHT + TOAST_GAP)
        t:ClearAllPoints()
        t:SetPoint(ANCHOR_POINT, UIParent, ANCHOR_POINT, ANCHOR_X + t.offset, y)
    end
    apply()

    t:SetScript("OnUpdate", function(self, dt)
        self.elapsed = self.elapsed + dt
        if self.state == "in" then
            local p = math.min(self.elapsed / SLIDE_IN_TIME, 1)
            -- Ease-out cubic
            local eased = 1 - (1 - p) * (1 - p) * (1 - p)
            self.offset = (1 - eased) * SLIDE_DISTANCE
            self:SetAlpha(eased)
            apply()
            if p >= 1 then
                self.state = "hold"
                self.elapsed = 0
                self:SetAlpha(1)
                self.offset = 0
                apply()
            end
        elseif self.state == "hold" then
            -- Pause the hold timer while the player is hovering or
            -- reading a right-click challenge tooltip.
            if not self.hoverPaused and not self.tooltipPaused then
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
                releaseToast(self)
            end
        end
    end)
end

----------------------------------------------------------------------
-- Public: show a single toast
----------------------------------------------------------------------

--- Fire a toast alert for a newly unlocked requirement.
-- @param section  "Equipment" / "Challenge" / "Companion" / "Pet" / "Mount"
-- @param desc     full requirement description (string)
-- @param level    level gate that just flipped active (number)
-- @param playSound  if true, ding once (default true, but caller can suppress
--                   for burst-suppression when many fire at once)
-- @param challengeKey  optional string key into FCE.ChallengeDescriptions for
--                      right-click tooltip on challenge toasts
function Alert.Toast(section, desc, level, playSound, challengeKey)
    local t = acquireToast()
    t.headline:SetText("NEW REQUIREMENT · lv " .. tostring(level))
    t.title:SetText(desc or "")
    t.subtitle:SetText(section or "")
    t.challengeKey = challengeKey  -- nil for non-challenge toasts

    -- Hint for right-click if this is a challenge toast with a description
    if challengeKey and FCE.ChallengeDescriptions and FCE.ChallengeDescriptions[challengeKey] then
        t.subtitle:SetText((section or "") .. "  |cff888888(right-click for details)|r")
    end

    table.insert(activeList, t)
    layoutActive()
    t:Show()
    animateToast(t)

    if playSound ~= false and (not FCE.AlertSoundEnabled or FCE.AlertSoundEnabled()) then
        PlaySound(DING_SOUND, "Master")
    end
end

--- Dismiss any visible toasts immediately.
function Alert.DismissAll()
    for i = #activeList, 1, -1 do
        releaseToast(activeList[i])
    end
end

----------------------------------------------------------------------
-- Core: find what just flipped active and fire toasts for it
----------------------------------------------------------------------

--- Walk a character's requirements and return a list of entries
--- whose level is in (fromLevel, toLevel].  That's the set of
--- requirements that just became active.
-- @return list of { section, desc, level, challengeKey? }
local function flippedRequirements(char, fromLevel, toLevel)
    local out = {}
    if not char then return out end
    if fromLevel == nil then fromLevel = 0 end
    if toLevel == nil or toLevel <= fromLevel then return out end

    local function consider(section, item, chalKey)
        if item and item.level and item.level > fromLevel and item.level <= toLevel then
            table.insert(out, { section = section, desc = item.desc, level = item.level, challengeKey = chalKey })
        end
    end

    for _, eq in ipairs(FCE.GetCharEquipment(char)) do consider("Equipment", eq) end
    local activeChallenges = FCE.GetActiveChallenges and FCE.GetActiveChallenges(char) or char.challenges or {}
    for _, ch in ipairs(activeChallenges) do consider("Challenge", ch, ch.desc) end
    consider("Companion", char.companion)
    consider("Hunter pet", char.pet)
    consider("Mount",     char.mount)

    -- Lowest-level first so the banners stack in rule-order.
    table.sort(out, function(a, b)
        if a.level ~= b.level then return a.level < b.level end
        return (a.section or "") < (b.section or "")
    end)
    return out
end

--- Compare the persisted last-seen level to the current level and
--- fire toasts for any requirement that crossed a level gate.
--- Called on PLAYER_LOGIN and on PLAYER_LEVEL_UP.
function Alert.Check()
    if not FCE_CharDB then return end
    if FCE_GlobalDB and FCE_GlobalDB.alertsEnabled == false then return end

    local key = FCE_CharDB.selectedCharacter
    local char = key and FCE.GetCharacter and FCE.GetCharacter(key) or nil
    if not char then
        -- Still keep lastLevel in sync so switching characters later
        -- doesn't fire a big backlog of toasts.
        FCE_CharDB.lastLevel = UnitLevel("player") or 1
        return
    end

    local current = UnitLevel("player") or 1
    local last = FCE_CharDB.lastLevel or current  -- first run: no backlog

    if current <= last then
        FCE_CharDB.lastLevel = current
        return
    end

    local flipped = flippedRequirements(char, last, current)

    -- Burst control: if a huge number flipped (e.g. first login on an
    -- existing high-level toon), just summarize with one toast instead
    -- of spamming 15 banners.
    if #flipped == 0 then
        FCE_CharDB.lastLevel = current
        return
    elseif #flipped > 4 then
        Alert.Toast("Multiple sections",
            #flipped .. " new requirements now active (lv " .. last .. " → " .. current .. ")",
            current, true)
    else
        for i, row in ipairs(flipped) do
            Alert.Toast(row.section, row.desc, row.level, i == 1, row.challengeKey)
        end
    end

    FCE_CharDB.lastLevel = current

    -- Make the panel reflect the new state, too.
    if FCE.RefreshPanel then FCE.RefreshPanel() end
end

--- Reset the level tracker.  Used by `/fce reset` and when a new
--- character is picked so that picking mid-run doesn't dump a backlog
--- of toasts for every prior level.
function Alert.ResyncBaseline()
    if FCE_CharDB then
        FCE_CharDB.lastLevel = UnitLevel("player") or 1
    end
end

FCE.CheckLevelAlerts  = Alert.Check
FCE.ResyncLevelAlerts = Alert.ResyncBaseline

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        -- Defer so CharacterData + SavedVariables are ready and the
        -- panel has a chance to build before we potentially call its
        -- refresh.
        C_Timer.After(1.5, Alert.Check)
    elseif event == "PLAYER_LEVEL_UP" then
        -- UnitLevel isn't updated until after this frame.
        C_Timer.After(0.15, Alert.Check)
    end
end)

----------------------------------------------------------------------
-- Test slash command: /fce testalert
----------------------------------------------------------------------

FCE.TestAlert = function()
    Alert.Toast("Equipment", "Flask trinkets", 50, true)
    C_Timer.After(0.4, function()
        Alert.Toast("Challenge", "Homebound", 20, false, "Homebound")
    end)
    C_Timer.After(0.8, function()
        Alert.Toast("Mount", "Self-made mechanostrider", 40, false)
    end)
end
