----------------------------------------------------------------------
-- ForeverClassesEnhanced — Savagery System  (Plagueshifter)
--
-- A shapeshifting uptime meter.  While the druid is in any shapeshift
-- form, Savagery stays at 100 %.  The moment the druid drops to caster
-- form, Savagery decays at 1 % every 2 seconds.  If it reaches 0 %
-- the challenge is considered failed.
--
-- Only active when selectedCharacter == "Plagueshifter".
--
-- Storage: FCE_CharDB.savageryByClass = { ["Plagueshifter"] = 87.5, … }
----------------------------------------------------------------------

FCE = FCE or {}

local Savagery = {}
FCE.SavagerySystem = Savagery

----------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------

local MAX_SAVAGERY   = 100
local TICK_INTERVAL  = 2         -- seconds
local DECAY_PER_TICK = 1         -- % lost per tick in caster form
local TARGET_CLASSES = {
    ["Savagekin_DRUID"] = true,
    ["Savagekin_DRUID_MELEE_MOONKIN"] = true,
}

----------------------------------------------------------------------
-- Visual constants
----------------------------------------------------------------------

local BAR_W = 160
local BAR_H = 14

local COL = {
    BG     = { 0.10, 0.10, 0.10, 0.80 },
    BORDER = { 0.72, 0.62, 0.20, 1.0  },
    FILL   = { 0.20, 0.55, 0.20, 0.90 },  -- green
    WARN   = { 0.80, 0.25, 0.10, 0.95 },  -- red at low savagery
    GOLD   = { 0.90, 0.78, 0.25 },
    WHITE  = { 0.92, 0.92, 0.90 },
}

----------------------------------------------------------------------
-- Runtime state
----------------------------------------------------------------------

local savagery     = MAX_SAVAGERY
local ticker       = nil
local barFrame     = nil
local hasFailed    = false
local initialised  = false

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------

local function classKey()
    return FCE_CharDB and FCE_CharDB.selectedCharacter or nil
end

local ACTIVE_LEVEL = 20

local function isActive()
    return TARGET_CLASSES[classKey()] and (UnitLevel("player") or 1) >= ACTIVE_LEVEL
end

local function savDB()
    FCE_CharDB = FCE_CharDB or {}
    FCE_CharDB.savageryByClass = FCE_CharDB.savageryByClass or {}
    return FCE_CharDB.savageryByClass
end

local function loadSavagery()
    local key = classKey()
    if not key then savagery = MAX_SAVAGERY; return end
    savagery = savDB()[key] or MAX_SAVAGERY
end

local function saveSavagery()
    local key = classKey()
    if not key then return end
    savDB()[key] = savagery
end

--- Is the druid currently in any shapeshift form?
local function isShapeshifted()
    return (GetShapeshiftForm() or 0) > 0
end

----------------------------------------------------------------------
-- Core tick
----------------------------------------------------------------------

local function OnTick()
    if not isActive() then
        if barFrame then barFrame:Hide() end
        return
    end
    if UnitIsDeadOrGhost("player") then return end
    if hasFailed then
        Savagery.UpdateBar()
        return
    end

    if isShapeshifted() then
        savagery = MAX_SAVAGERY
    elseif IsMounted() or UnitOnTaxi("player") then
        -- Pause decay while mounted or on a flight path
    else
        savagery = math.max(0, savagery - DECAY_PER_TICK)
    end

    saveSavagery()

    if savagery <= 0 and not hasFailed then
        hasFailed = true
        print("|cffff4444Savagery reached 0 %, you have failed the \"|cffffcc00"
            .. "Savagery" .. "|cffff4444\" challenge.|r")
        print("|cffff4444Type |cffffcc00/fce savagery reset|cffff4444 to reset.|r")
        if FCE.RefreshPanel then C_Timer.After(0.3, FCE.RefreshPanel) end
    end

    Savagery.UpdateBar()
end

----------------------------------------------------------------------
-- UI: Savagery bar (anchored below the Doubt bar)
----------------------------------------------------------------------

local function CreateBar()
    if barFrame then return end

    barFrame = CreateFrame("Frame", "HCE_SavageryBar", UIParent, "BackdropTemplate")
    barFrame:SetSize(BAR_W + 8, BAR_H + 20)
    barFrame:SetFrameStrata("MEDIUM")
    barFrame:SetMovable(true)
    barFrame:EnableMouse(true)
    barFrame:SetClampedToScreen(true)
    barFrame:RegisterForDrag("LeftButton")
    barFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    barFrame:SetScript("OnDragStop",  function(self) self:StopMovingOrSizing() end)

    -- Anchor below the doubt bar if it exists, else top-center
    if HCE_DoubtBar then
        barFrame:SetPoint("TOP", HCE_DoubtBar, "BOTTOM", 0, -2)
    else
        barFrame:SetPoint("TOP", UIParent, "TOP", 0, -60)
    end

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
    label:SetText("Savagery")
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
        GameTooltip:SetText("Savagery", unpack(COL.GOLD))

        if hasFailed then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Savagery reached 0%.", 1, 0.3, 0.3)
            GameTooltip:AddLine("You have failed the Savagery challenge.", 1, 0.3, 0.3, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Type /fce savagery reset to reset.", 1, 0.82, 0)
        else
            GameTooltip:AddLine(" ")
            if isShapeshifted() then
                GameTooltip:AddLine("Shapeshifted — Savagery is full.", 0.3, 1, 0.4, true)
            else
                GameTooltip:AddDoubleLine("Decaying:",
                    string.format("-%.1f%%/sec", DECAY_PER_TICK / TICK_INTERVAL),
                    1, 0.4, 0.3, 1, 0.4, 0.3)
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Shapeshift to restore Savagery to 100%.", 0.5, 0.5, 0.5, true)
            end
        end
        GameTooltip:Show()
    end)
    barFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)

    barFrame:Hide()
end

function Savagery.UpdateBar()
    if not barFrame then return end

    if not isActive() then
        barFrame:Hide()
        return
    end

    barFrame:Show()

    local pct  = savagery / MAX_SAVAGERY
    local fillW = math.max(1, BAR_W * pct)
    barFrame.fill:SetWidth(fillW)

    -- Colour shift: green at full → red at low
    local inv = 1 - pct  -- 0 at full, 1 at empty
    local r = COL.FILL[1] + (COL.WARN[1] - COL.FILL[1]) * inv
    local g = COL.FILL[2] + (COL.WARN[2] - COL.FILL[2]) * inv
    local b = COL.FILL[3] + (COL.WARN[3] - COL.FILL[3]) * inv
    barFrame.fill:SetColorTexture(r, g, b, 0.92)

    barFrame.pctText:SetText(string.format("%.0f%%", savagery))
end

----------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------

function Savagery.GetSavagery()
    return savagery
end

function Savagery.HasFailed()
    return hasFailed
end

function Savagery.ResetSavagery()
    if not isActive() then
        print("|cffffcc00[FCE]|r Savagery only applies to Savagekin builds.")
        return
    end
    savagery  = MAX_SAVAGERY
    hasFailed = false
    saveSavagery()
    Savagery.UpdateBar()
    print("|cffffcc00[FCE]|r Savagery reset to 100 %.")
end

function Savagery.OnClassChanged()
    loadSavagery()
    hasFailed = savagery <= 0
    Savagery.UpdateBar()
end

----------------------------------------------------------------------
-- Initialise
----------------------------------------------------------------------

function Savagery.Init()
    if initialised then return end
    initialised = true

    CreateBar()
    loadSavagery()
    hasFailed = savagery <= 0
    Savagery.UpdateBar()

    if not ticker then
        ticker = C_Timer.NewTicker(TICK_INTERVAL, OnTick)
    end
end

----------------------------------------------------------------------
-- Bootstrap
----------------------------------------------------------------------

local ef = CreateFrame("Frame")
ef:RegisterEvent("PLAYER_LOGIN")
ef:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        C_Timer.After(3.5, function()   -- slightly after doubt bar
            Savagery.Init()
        end)
    end
end)
