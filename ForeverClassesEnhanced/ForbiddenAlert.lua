----------------------------------------------------------------------
-- ForeverClassesEnhanced — Forbidden-item Alerts
--
-- Fires a red-accented toast (+ brief screen-edge flash + error
-- chime) when the player equips an item that violates one of their
-- character's active equipment rules — e.g. a dagger on a "no
-- daggers" character, a robe on a "no robes" paladin flavour, a
-- non-sword weapon on a sword-bound duelist.
--
-- Design notes:
--   * Non-intrusive.  Nothing is auto-unequipped, no input is blocked.
--   * Fires ONCE per NEW violation — EquipmentCheck already tracks
--     old-vs-new status, we just hook the transition.
--   * Visual language mirrors LevelAlert (charcoal + gold border) so
--     the addon still feels like one piece, but the accent stripe on
--     the left edge is red to immediately distinguish "you broke a
--     rule" from "a new rule just unlocked".
--   * Stacks below LevelAlert toasts so both can fire at once without
--     covering each other up (e.g. you ding 20 and accidentally equip
--     a dagger in the same second).
--
--       ┌────────────────────────────────────────┐
--       │ ▌ FORBIDDEN ITEM                       │   (red stripe)
--       │ ▌ Dagger equipped — Dirk of Whatever   │
--       │ ▌ Equipment rule: No daggers           │
--       └────────────────────────────────────────┘
----------------------------------------------------------------------

FCE = FCE or {}

local Forbid = {}
FCE.ForbiddenAlert = Forbid

----------------------------------------------------------------------
-- Tunables
----------------------------------------------------------------------

local TOAST_WIDTH    = 320
local TOAST_HEIGHT   = 58
local TOAST_GAP      = 8
local ANCHOR_POINT   = "TOPRIGHT"
local ANCHOR_X       = -28
-- Stack beneath LevelAlert's column.  LevelAlert uses y = -140 and
-- height 54 + gap 8, and can stack up to ~5 before it burst-suppresses
-- to a single summary, so leaving ~360px of vertical headroom avoids
-- overlap in the common case.
local ANCHOR_Y       = -500
local SLIDE_IN_TIME  = 0.30
local HOLD_TIME      = 5.0
local FADE_OUT_TIME  = 0.8
local SLIDE_DISTANCE = 40

local GOLD       = { 0.85, 0.70, 0.20 }
local RED        = { 0.90, 0.22, 0.22 }          -- accent stripe
local RED_WASH   = { 0.55, 0.10, 0.10, 0.22 }    -- headline plate wash
local CHARCOAL   = { 0.05, 0.06, 0.08, 0.94 }
local TEXT_BRIGHT = { 0.99, 0.88, 0.80 }
local TEXT_DIM    = { 0.80, 0.75, 0.72 }

-- Error chime.  Loud-but-short Blizzard sound that reads as "no".
-- Not the raid-warning horn (too loud), not the auction-bid ding (too
-- cheerful).  LOOTWINDOWCOINSOUND or IG_QUEST_FAILED both fit; we pick
-- the quest-failed as it's unambiguously "you broke a thing".
local ERROR_SOUND = SOUNDKIT and SOUNDKIT.IG_QUEST_FAILED or 847

----------------------------------------------------------------------
-- Toast pool
----------------------------------------------------------------------

local toastPool  = {}
local activeList = {}

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
    toast.hoverPaused = false
    table.insert(toastPool, toast)
    layoutActive()
end

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
        -- Gold border keeps the family resemblance to LevelAlert.
        t:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.9)
    end

    -- RED accent stripe — the signal that this is a rule break, not
    -- a newly-unlocked requirement.
    local stripe = t:CreateTexture(nil, "ARTWORK")
    stripe:SetColorTexture(RED[1], RED[2], RED[3], 1)
    stripe:SetPoint("TOPLEFT", 3, -3)
    stripe:SetPoint("BOTTOMLEFT", 3, 3)
    stripe:SetWidth(4)

    -- Thin dim-red wash at the top to echo the stripe.
    local wash = t:CreateTexture(nil, "BACKGROUND")
    wash:SetColorTexture(RED_WASH[1], RED_WASH[2], RED_WASH[3], RED_WASH[4])
    wash:SetPoint("TOPLEFT", 1, -1)
    wash:SetPoint("TOPRIGHT", -1, -1)
    wash:SetHeight(18)

    -- Headline: FORBIDDEN ITEM
    t.headline = t:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    t.headline:SetPoint("TOPLEFT", 14, -4)
    t.headline:SetPoint("RIGHT", -8, 0)
    t.headline:SetJustifyH("LEFT")
    t.headline:SetTextColor(RED[1] + 0.05, RED[2] + 0.20, RED[3] + 0.20)  -- slightly lighter red so it reads

    -- Title: detail line (what specifically is wrong)
    t.title = t:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t.title:SetPoint("TOPLEFT", t.headline, "BOTTOMLEFT", 0, -2)
    t.title:SetPoint("RIGHT", -8, 0)
    t.title:SetJustifyH("LEFT")
    t.title:SetTextColor(TEXT_BRIGHT[1], TEXT_BRIGHT[2], TEXT_BRIGHT[3])
    t.title:SetWordWrap(false)
    t.title:SetNonSpaceWrap(false)

    -- Subtitle: which rule it violated
    t.subtitle = t:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    t.subtitle:SetPoint("TOPLEFT", t.title, "BOTTOMLEFT", 0, -1)
    t.subtitle:SetPoint("RIGHT", -8, 0)
    t.subtitle:SetJustifyH("LEFT")
    t.subtitle:SetTextColor(TEXT_DIM[1], TEXT_DIM[2], TEXT_DIM[3])

    t:RegisterForClicks("LeftButtonUp")
    t:SetScript("OnClick", function(self)
        releaseToast(self)
    end)
    t:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(1, 0.92, 0.40, 1)
        if self.state == "hold" then
            self.hoverPaused = true
        end
    end)
    t:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.9)
        self.hoverPaused = false
    end)

    return t
end

local function acquireToast()
    local t = table.remove(toastPool)
    if t then return t end
    return buildToast()
end

----------------------------------------------------------------------
-- Animation: slide in from the right, hold, fade out
----------------------------------------------------------------------

local function animateToast(t)
    t:SetAlpha(0)
    t.offset = SLIDE_DISTANCE
    t.elapsed = 0
    t.state = "in"

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
                releaseToast(self)
            end
        end
    end)
end

----------------------------------------------------------------------
-- Screen-edge flash
--
-- One shared frame at BACKGROUND strata covers the whole screen with a
-- thin red-gradient vignette along the four edges that pulses once.
-- It's *deliberately* quick — we don't want to obscure combat.
----------------------------------------------------------------------

local edgeFrame = nil
local edgeElapsed = 0
local EDGE_IN    = 0.12
local EDGE_HOLD  = 0.18
local EDGE_OUT   = 0.60
local EDGE_TOTAL = EDGE_IN + EDGE_HOLD + EDGE_OUT
local EDGE_ALPHA_PEAK = 0.35

local function buildEdgeFrame()
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetAllPoints(UIParent)
    f:SetFrameStrata("BACKGROUND")
    f:EnableMouse(false)
    f:Hide()

    -- Build the four edges as gradient textures that fade inward.
    -- Outer edge is solid red at the set alpha; inner edge is
    -- transparent.  ~80px thick on each side.
    local THICK = 80

    local function edge(anchor1, anchor2, orientation, startsFrom)
        local tex = f:CreateTexture(nil, "OVERLAY")
        tex:SetColorTexture(RED[1], RED[2], RED[3], 1)
        tex:SetPoint(unpack(anchor1))
        tex:SetPoint(unpack(anchor2))
        if orientation == "horizontal" then
            tex:SetHeight(THICK)
        else
            tex:SetWidth(THICK)
        end
        -- Fade the inner side to transparent, so it reads as a vignette.
        -- SetGradient signature changed in 10.x; we check for both.
        if tex.SetGradient then
            local ok = pcall(function()
                tex:SetGradient(orientation:upper(),
                    CreateColor(RED[1], RED[2], RED[3], startsFrom == "outer" and 1 or 0),
                    CreateColor(RED[1], RED[2], RED[3], startsFrom == "outer" and 0 or 1))
            end)
            if not ok and tex.SetGradientAlpha then
                tex:SetGradientAlpha(orientation:upper(),
                    RED[1], RED[2], RED[3], startsFrom == "outer" and 1 or 0,
                    RED[1], RED[2], RED[3], startsFrom == "outer" and 0 or 1)
            end
        elseif tex.SetGradientAlpha then
            tex:SetGradientAlpha(orientation:upper(),
                RED[1], RED[2], RED[3], startsFrom == "outer" and 1 or 0,
                RED[1], RED[2], RED[3], startsFrom == "outer" and 0 or 1)
        end
        return tex
    end

    -- Top edge: gradient vertical, outer (top) opaque, inner transparent
    edge({ "TOPLEFT",  UIParent, "TOPLEFT",  0, 0 },
         { "TOPRIGHT", UIParent, "TOPRIGHT", 0, 0 }, "vertical", "inner")
    -- Bottom edge: gradient vertical, outer (bottom) opaque
    edge({ "BOTTOMLEFT",  UIParent, "BOTTOMLEFT",  0, 0 },
         { "BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0 }, "vertical", "outer")
    -- Left edge: gradient horizontal, outer (left) opaque
    edge({ "TOPLEFT",    UIParent, "TOPLEFT",    0, 0 },
         { "BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0 }, "horizontal", "outer")
    -- Right edge: gradient horizontal, outer (right) opaque
    edge({ "TOPRIGHT",    UIParent, "TOPRIGHT",    0, 0 },
         { "BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0 }, "horizontal", "inner")

    return f
end

local function flashEdges()
    if not edgeFrame then
        edgeFrame = buildEdgeFrame()
    end
    edgeElapsed = 0
    edgeFrame:SetAlpha(0)
    edgeFrame:Show()
    edgeFrame:SetScript("OnUpdate", function(self, dt)
        edgeElapsed = edgeElapsed + dt
        if edgeElapsed < EDGE_IN then
            self:SetAlpha((edgeElapsed / EDGE_IN) * EDGE_ALPHA_PEAK)
        elseif edgeElapsed < EDGE_IN + EDGE_HOLD then
            self:SetAlpha(EDGE_ALPHA_PEAK)
        elseif edgeElapsed < EDGE_TOTAL then
            local p = (edgeElapsed - EDGE_IN - EDGE_HOLD) / EDGE_OUT
            self:SetAlpha(EDGE_ALPHA_PEAK * (1 - p))
        else
            self:SetAlpha(0)
            self:Hide()
            self:SetScript("OnUpdate", nil)
        end
    end)
end

----------------------------------------------------------------------
-- Public: fire an alert
----------------------------------------------------------------------

--- Fire a forbidden-item alert.
-- @param ruleDesc  the requirement description (e.g. "No daggers")
-- @param detail    the explanation string from the check ("Dagger equipped: ...")
-- @param playSound if false, suppress the chime (for burst control)
-- @param flashEdge if false, suppress the edge flash (for burst control)
function Forbid.Fire(ruleDesc, detail, playSound, flashEdge)
    if FCE_GlobalDB and FCE_GlobalDB.forbiddenAlertsEnabled == false then
        return
    end

    local t = acquireToast()
    t.headline:SetText("FORBIDDEN ITEM")
    -- Put the detail (the specific "what") up top so the player sees it
    -- even if they dismiss fast.  The rule name goes in subtitle.
    t.title:SetText(detail or "Equipment rule violated")
    t.subtitle:SetText("Rule: " .. (ruleDesc or "—"))

    table.insert(activeList, t)
    layoutActive()
    t:Show()
    animateToast(t)

    if playSound ~= false and (not FCE.AlertSoundEnabled or FCE.AlertSoundEnabled()) then
        PlaySound(ERROR_SOUND, "Master")
    end
    if flashEdge ~= false and (not FCE.EdgeFlashEnabled or FCE.EdgeFlashEnabled()) then
        flashEdges()
    end
end

--- Dismiss any visible forbidden toasts immediately.
function Forbid.DismissAll()
    for i = #activeList, 1, -1 do
        releaseToast(activeList[i])
    end
end

----------------------------------------------------------------------
-- Batch fire (called by EquipmentCheck when multiple new violations
-- surface at the same time, e.g. first PLAYER_LOGIN with already-bad
-- gear).  Suppresses sound + flash on all but the first so a dirty
-- login doesn't strobe the screen.
----------------------------------------------------------------------

--- Fire a batch of forbidden alerts with burst control.
-- @param entries  list of { desc, detail }
function Forbid.FireBatch(entries)
    if FCE_GlobalDB and FCE_GlobalDB.forbiddenAlertsEnabled == false then
        return
    end
    if not entries or #entries == 0 then return end

    -- If a lot fired at once, collapse to a single summary toast.
    if #entries > 3 then
        local t = acquireToast()
        t.headline:SetText("FORBIDDEN ITEMS")
        t.title:SetText(#entries .. " equipment rules violated")
        local names = {}
        for i, e in ipairs(entries) do
            if i <= 3 then table.insert(names, e.desc) end
        end
        if #entries > 3 then table.insert(names, "…") end
        t.subtitle:SetText("Rules: " .. table.concat(names, ", "))
        table.insert(activeList, t)
        layoutActive()
        t:Show()
        animateToast(t)
        if not FCE.AlertSoundEnabled or FCE.AlertSoundEnabled() then
            PlaySound(ERROR_SOUND, "Master")
        end
        if not FCE.EdgeFlashEnabled or FCE.EdgeFlashEnabled() then
            flashEdges()
        end
        return
    end

    for i, e in ipairs(entries) do
        Forbid.Fire(e.desc, e.detail, i == 1, i == 1)
    end
end

----------------------------------------------------------------------
-- Test helper — fire a sample forbidden alert for /fce testforbidden
----------------------------------------------------------------------

function FCE.TestForbiddenAlert()
    Forbid.Fire("No daggers", "Dagger equipped: Bloodspike — daggers are forbidden", true, true)
    C_Timer.After(0.5, function()
        Forbid.Fire("Shield", "No shield in off-hand", false, false)
    end)
end
