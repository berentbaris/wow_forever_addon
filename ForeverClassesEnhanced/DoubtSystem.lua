----------------------------------------------------------------------
-- ForeverClassesEnhanced — Doubt System
--
-- A time-weighted compliance meter inspired by Purity's Ringbearer
-- corruption mechanic.  Doubt rises when requirements are FAIL and
-- falls when the player rests at an inn or near a campfire.
--
-- Storage: FCE_CharDB.doubtByClass = { ["ClassName"] = 54.3, … }
-- When the player resets / changes class, current doubt is saved
-- under the OLD class key.  Switching back restores it.
--
-- Rate (per second):
--   +0.01 per 1% of total requirements that are FAILing
--   (so 10% failing = +0.1/sec,  50% failing = +0.5/sec)
--
-- Cleanse (per second):
--   Resting (inn):     −1.5  (suppressed to −1.0 if any req failing)
--   Sitting+campfire:  −1.0  (suppressed to −0.5 if any req failing)
--   Standing+campfire: −0.5  (suppressed to  0.0 if any req failing)
--
-- Cap: 100.  Floor: 0.
----------------------------------------------------------------------


local UnitBuff
    = FCE.Compat.UnitBuff  -- Forever API shims (ForeverCompat.lua)
FCE = FCE or {}

local Doubt = {}
FCE.DoubtSystem = Doubt

----------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------

local MAX_DOUBT     = 100
local TICK_INTERVAL = 1        -- seconds

-- Burden: per 1% of failing requirements, per second
local BURDEN_PER_PCT = 0.005

-- Cleanse rates (per second) — applied in full, no burden while cleansing
local CLEANSE_INN        = 1.5
local CLEANSE_SIT_FIRE   = 1.0
local CLEANSE_STAND_FIRE = 0.5

----------------------------------------------------------------------
-- Visual constants
----------------------------------------------------------------------

local BAR_W = 160
local BAR_H = 14

local COL = {
    BG     = { 0.10, 0.10, 0.10, 0.80 },
    BORDER = { 0.72, 0.62, 0.20, 1.0  },
    FILL   = { 0.65, 0.20, 0.20, 0.90 },  -- dark red
    WARN   = { 0.90, 0.30, 0.15, 0.95 },   -- bright red at high doubt
    GOLD   = { 0.90, 0.78, 0.25 },
    WHITE  = { 0.92, 0.92, 0.90 },
    GREY   = { 0.55, 0.55, 0.55 },
}

----------------------------------------------------------------------
-- Runtime state
----------------------------------------------------------------------

local secureDoubt      = 0     -- authoritative value this tick
local previousDoubt    = 0     -- previous tick's doubt (for detecting direction)
local ticker           = nil   -- C_Timer ticker handle
local barFrame         = nil   -- UI frame
local tunnelFrames     = {}    -- stacked vignette overlay frames (like UHC)
local hasFailed        = false -- true once doubt hits 100% (blocks further accumulation)
local initialised      = false

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------

--- Is the Doubt system enabled in settings?
function Doubt.IsEnabled()
    FCE_GlobalDB = FCE_GlobalDB or {}
    if FCE_GlobalDB.doubtEnabled == nil then return true end  -- default ON
    return FCE_GlobalDB.doubtEnabled
end

--- Get or init the per-class doubt table.
local function doubtDB()
    FCE_CharDB = FCE_CharDB or {}
    FCE_CharDB.doubtByClass = FCE_CharDB.doubtByClass or {}
    return FCE_CharDB.doubtByClass
end

--- Current class key (the selectedCharacter name, e.g. "Berserker").
local function classKey()
    return FCE_CharDB and FCE_CharDB.selectedCharacter or nil
end

local function classKeyName()
    local key = FCE_CharDB and FCE_CharDB.selectedCharacter or nil
    if key then
        return key:match("^(.+)_[A-Z]+$") or key
    end
    return nil
end

--- Load doubt for the currently selected class.
local function loadDoubt()
    local key = classKey()
    if not key then secureDoubt = 0; return end
    secureDoubt = doubtDB()[key] or 0
end

--- Save doubt for the currently selected class.
local function saveDoubt()
    local key = classKey()
    if not key then return end
    doubtDB()[key] = secureDoubt
end

--- Get the % of total requirements currently FAILing (0–100).
local function getFailPct()
    if not FCE.Progress or not FCE.Progress.Collect then return 0 end
    local summary = FCE.Progress.Collect()
    if not summary or not summary.counts then return 0 end
    local c = summary.counts
    if c.total == 0 then return 0 end
    return (c.fail / c.total) * 100
end

--- Does the player have ANY requirement currently failing?
local function anyFailing()
    return getFailPct() > 0
end

--- Is the player near a campfire? (has "Cozy Fire" buff)
local function hasCampfireBuff()
    for i = 1, 40 do
        local name = UnitBuff("player", i)
        if not name then break end
        if name == "Cozy Fire" then return true end
    end
    return false
end

--- Is the player sitting? (speed == 0 and not standing)
local function isPlayerSitting()
    -- In WoW, /sit doesn't have a reliable API, but speed == 0 while
    -- having the Cozy Fire buff and being stationary is close enough.
    -- We use IsMounted as a negative check and fall back to checking
    -- if the player is specifically seated via the standState.
    if IsMounted and IsMounted() then return false end
    if GetUnitSpeed("player") > 0 then return false end
    -- There's no perfect "is sitting" API in Classic; approximate:
    -- if they have Cozy Fire buff and speed == 0, treat "sitting by fire"
    -- as a separate cleanse tier from "standing near fire".
    -- The caller differentiates by checking this + campfire.
    return true
end

----------------------------------------------------------------------
-- Core tick
----------------------------------------------------------------------

local function OnTick()
    if not Doubt.IsEnabled() then
        if barFrame then barFrame:Hide() end
        return
    end
    if not classKey() then
        if barFrame then barFrame:Hide() end
        return
    end
    if UnitIsDeadOrGhost("player") then return end
    if UnitOnTaxi("player") or IsMounted() then return end
    if hasFailed then
        Doubt.UpdateBar()
        return
    end

    -- 1. Cleanse check: inn > sit+fire > stand+fire
    local cleanseRate = 0
    local campfire = hasCampfireBuff()
    local sitting  = isPlayerSitting()

    if IsResting() then
        cleanseRate = CLEANSE_INN
    elseif campfire and sitting then
        cleanseRate = CLEANSE_SIT_FIRE
    elseif campfire then
        cleanseRate = CLEANSE_STAND_FIRE
    end

    -- 2. Apply: cleansing and burden are mutually exclusive
    if cleanseRate > 0 then
        secureDoubt = math.max(0, secureDoubt - cleanseRate)
    else
        local failPct    = getFailPct()
        local burdenRate = failPct * BURDEN_PER_PCT
        if burdenRate > 0 then
            secureDoubt = math.min(MAX_DOUBT, secureDoubt + burdenRate)
        end
    end

    saveDoubt()

    -- 4. Check for 100% — challenge failed
    if secureDoubt >= MAX_DOUBT and not hasFailed then
        hasFailed = true
        local name = classKeyName() or "unknown"
        print("|cffff4444Doubt reached 100%, you have failed the \"|cffffcc00" .. name .. "|cffff4444\" challenge.|r")
        print("|cffff4444Type |cffffcc00/fce doubt reset|cffff4444 to reset your doubt.|r")
    end

    -- 5. Update UI
    Doubt.UpdateBar()
end

----------------------------------------------------------------------
-- UI: Screen darkening — stacked vignette overlays (UHC style)
--
-- 4 layers, each with its own texture, stacked as doubt rises:
--   ≥20% doubt → layer 1    ≥40% → layer 2
--   ≥60% → layer 3          ≥80% → layer 4
----------------------------------------------------------------------

local TUNNEL_TEXTURE_PATH = "Interface\\AddOns\\ForeverClassesEnhanced\\Textures\\tunnel_vision_%d.png"
local TUNNEL_FADE_DUR     = 0.5

local function ShowTunnelLayer(intensity)
    local frameName = "HCE_DoubtTunnel_" .. intensity

    -- If already visible and fully faded in, nothing to do
    if tunnelFrames[frameName] and tunnelFrames[frameName]:IsShown() then
        local f = tunnelFrames[frameName]
        local a = f:GetAlpha() or 0
        if a < 1 then
            -- Mid-fade-out — cancel and fade back in
            if UIFrameFadeRemoveFrame then UIFrameFadeRemoveFrame(f) end
            UIFrameFadeIn(f, 0.2, a, 1)
        end
        return
    end

    -- Create frame on first use
    if not tunnelFrames[frameName] then
        local f = CreateFrame("Frame", frameName, UIParent)
        f:SetAllPoints(UIParent)
        f:SetFrameStrata("BACKGROUND")
        f:SetFrameLevel(intensity)
        f.texture = f:CreateTexture(nil, "BACKGROUND")
        f.texture:SetAllPoints()
        f.texture:SetColorTexture(0, 0, 0, 0)
        tunnelFrames[frameName] = f
    end

    local f = tunnelFrames[frameName]
    f.texture:SetTexture(string.format(TUNNEL_TEXTURE_PATH, intensity))
    f:SetAlpha(0)
    f:Show()
    UIFrameFadeIn(f, TUNNEL_FADE_DUR, 0, 1)
end

local function HideTunnelLayer(intensity)
    local frameName = "HCE_DoubtTunnel_" .. intensity
    local f = tunnelFrames[frameName]
    if f and f:IsShown() and f:GetAlpha() > 0 then
        UIFrameFadeOut(f, TUNNEL_FADE_DUR, f:GetAlpha(), 0)
        C_Timer.After(TUNNEL_FADE_DUR + 0.1, function()
            if f:GetAlpha() == 0 then f:Hide() end
        end)
    end
end

local function HideAllTunnelLayers()
    for _, f in pairs(tunnelFrames) do
        if f and f:IsShown() and f:GetAlpha() > 0 then
            UIFrameFadeOut(f, TUNNEL_FADE_DUR, f:GetAlpha(), 0)
            C_Timer.After(TUNNEL_FADE_DUR + 0.1, function()
                if f:GetAlpha() == 0 then f:Hide() end
            end)
        end
    end
end

local function UpdateTunnelVision()
    if not Doubt.IsEnabled() or not classKey() or secureDoubt <= 0 then
        HideAllTunnelLayers()
        previousDoubt = 0
        return
    end

    local doubt = secureDoubt
    local prev  = previousDoubt

    -- Which layers SHOULD be active now vs before
    local shouldShow = {
        doubt >= 50,
        doubt >= 75,
        doubt >= 90,
        doubt >= 95,
    }
    local wasShowing = {
        prev >= 50,
        prev >= 75,
        prev >= 90,
        prev >= 95,
    }

    for i = 1, 4 do
        if shouldShow[i] and not wasShowing[i] then
            ShowTunnelLayer(i)
        elseif wasShowing[i] and not shouldShow[i] then
            HideTunnelLayer(i)
        end
    end

    previousDoubt = doubt
end

----------------------------------------------------------------------
-- UI: Doubt bar (compact, anchored below the minimap)
----------------------------------------------------------------------

local function CreateBar()
    if barFrame then return end

    barFrame = CreateFrame("Frame", "HCE_DoubtBar", UIParent, "BackdropTemplate")
    barFrame:SetSize(BAR_W + 8, BAR_H + 20)
    barFrame:SetPoint("TOP", UIParent, "TOP", 0, -25)
    barFrame:SetFrameStrata("MEDIUM")
    barFrame:SetMovable(true)
    barFrame:EnableMouse(true)
    barFrame:SetClampedToScreen(true)
    barFrame:RegisterForDrag("LeftButton")
    barFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    barFrame:SetScript("OnDragStop",  function(self) self:StopMovingOrSizing() end)

    barFrame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    barFrame:SetBackdropColor(unpack(COL.BG))
    barFrame:SetBackdropBorderColor(unpack(COL.BORDER))

    -- Label
    local label = barFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOP", barFrame, "TOP", 0, -3)
    label:SetTextColor(unpack(COL.GOLD))
    label:SetText("Doubt")
    barFrame.label = label

    -- Bar background
    local barBG = barFrame:CreateTexture(nil, "BACKGROUND", nil, 1)
    barBG:SetPoint("BOTTOMLEFT", barFrame, "BOTTOMLEFT", 4, 4)
    barBG:SetSize(BAR_W, BAR_H)
    barBG:SetColorTexture(0.15, 0.15, 0.15, 1)
    barFrame.barBG = barBG

    -- Bar fill
    local fill = barFrame:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("BOTTOMLEFT", barBG, "BOTTOMLEFT", 0, 0)
    fill:SetHeight(BAR_H)
    fill:SetWidth(1)
    fill:SetColorTexture(unpack(COL.FILL))
    barFrame.fill = fill

    -- Percentage text
    local pctText = barFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pctText:SetPoint("CENTER", barBG, "CENTER", 0, 0)
    pctText:SetTextColor(unpack(COL.WHITE))
    barFrame.pctText = pctText

    -- Tooltip
    barFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Doubt", unpack(COL.GOLD))

        if hasFailed then
            local className = classKeyName() or "unknown"
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Doubt reached 100%.", 1, 0.3, 0.3)
            GameTooltip:AddLine("You have failed the \"" .. className .. "\" challenge.", 1, 0.3, 0.3, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Type /fce doubt reset to reset your doubt.", 1, 0.82, 0)
        else
            local summary = FCE.Progress and FCE.Progress.Collect and FCE.Progress.Collect()
            local c = summary and summary.counts or { fail = 0, total = 0 }
            local failPct = c.total > 0 and (c.fail / c.total) * 100 or 0
            local burden  = failPct * BURDEN_PER_PCT
            local className = classKey() or "unknown"
            local classNameName = classKeyName() or "unknown"
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Straying from your class identity gives you self-doubt.", unpack(COL.WHITE))
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine("Failing " .. classNameName .. " requirements:", string.format("%d/%d", c.fail, c.total), unpack(COL.GOLD))

            local cleanseRate = 0
            if IsResting() then
                cleanseRate = CLEANSE_INN
            elseif hasCampfireBuff() and isPlayerSitting() then
                cleanseRate = CLEANSE_SIT_FIRE
            elseif hasCampfireBuff() then
                cleanseRate = CLEANSE_STAND_FIRE
            end

            if cleanseRate > 0 then
                GameTooltip:AddDoubleLine("Cleansing:", string.format("-%.1f/sec", cleanseRate), 0.3, 1, 0.4, 0.3, 1, 0.4)
            elseif burden > 0 then
                GameTooltip:AddDoubleLine("Doubt rate:", string.format("+%.2f/sec", burden), 1, 0.4, 0.3, 1, 0.4, 0.3)
            end

            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Rest at an inn or sit by a campfire to reduce doubt.", 0.5, 0.5, 0.5, true)
            GameTooltip:AddLine("Learn Cooking to craft a Basic Campfire.", 0.5, 0.5, 0.5, true)
        end
        GameTooltip:Show()
    end)
    barFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)

    barFrame:Hide()
end

function Doubt.UpdateBar()
    -- Always update the stacked vignette overlays
    UpdateTunnelVision()

    if not barFrame then return end

    if not Doubt.IsEnabled() or not classKey() or secureDoubt <= 0 then
        barFrame:Hide()
        return
    end

    barFrame:Show()

    local pct = secureDoubt / MAX_DOUBT
    local fillW = math.max(1, BAR_W * pct)
    barFrame.fill:SetWidth(fillW)

    -- Colour shift: dark red → bright red as doubt rises
    local r = COL.FILL[1] + (COL.WARN[1] - COL.FILL[1]) * pct
    local g = COL.FILL[2] + (COL.WARN[2] - COL.FILL[2]) * pct
    local b = COL.FILL[3] + (COL.WARN[3] - COL.FILL[3]) * pct
    barFrame.fill:SetColorTexture(r, g, b, 0.92)

    barFrame.pctText:SetText(string.format("%.1f%%", secureDoubt))
end

----------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------

--- Get current doubt value (0–100).
function Doubt.GetDoubt()
    return secureDoubt
end

--- Get doubt for a specific class key (for display in catalog etc.).
function Doubt.GetDoubtForClass(key)
    return doubtDB()[key] or 0
end

--- Manually set doubt (for testing / slash commands).
function Doubt.SetDoubt(val)
    previousDoubt = secureDoubt
    secureDoubt = math.max(0, math.min(MAX_DOUBT, val))
    hasFailed = secureDoubt >= MAX_DOUBT
    saveDoubt()
    Doubt.UpdateBar()
end

--- Reset doubt for the current class (used by /fce doubt reset).
function Doubt.ResetDoubt()
    local key = classKey()
    if not key then
        print("|cffffcc00[FCE]|r No class selected — nothing to reset.")
        return
    end
    secureDoubt = 0
    previousDoubt = 0
    hasFailed = false
    saveDoubt()
    HideAllTunnelLayers()
    Doubt.UpdateBar()
    local name = classKeyName() or key
    print("|cffffcc00[FCE]|r Doubt for |cffffcc00" .. name .. "|r has been reset to 0.")
end

--- Called when the player selects a new class (via /fce reset → pick).
--- The OLD class's doubt was already saved by the ticker; we just load
--- the NEW class's doubt (which may be 0 if never played, or restored
--- if they're returning to a previous class).
function Doubt.OnClassChanged()
    HideAllTunnelLayers()
    previousDoubt = 0
    loadDoubt()
    hasFailed = secureDoubt >= MAX_DOUBT
    Doubt.UpdateBar()
end

----------------------------------------------------------------------
-- Initialise (called once on PLAYER_LOGIN)
----------------------------------------------------------------------

function Doubt.Init()
    if initialised then return end
    initialised = true

    CreateBar()
    loadDoubt()
    hasFailed = secureDoubt >= MAX_DOUBT
    Doubt.UpdateBar()

    -- Start the 1-second ticker
    if not ticker then
        ticker = C_Timer.NewTicker(TICK_INTERVAL, OnTick)
    end
end

----------------------------------------------------------------------
-- Event frame — bootstrap on login
----------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        C_Timer.After(3.0, function()
            Doubt.Init()
        end)
    end
end)
