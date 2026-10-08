----------------------------------------------------------------------
-- ForeverClassesEnhanced — Brewmaster System  (Happy Hour)
--
-- The Brewmaster must drink an alcoholic beverage at least once per
-- hour of gameplay.  A 60-minute timer counts down while the player
-- is sober.  Drinking alcohol (detected via CHAT_MSG_SYSTEM drunk
-- messages) resets the timer to 60 minutes.
--
-- Timer suspends while on a flight path, mounted, or dead.
--
-- Only active when selectedCharacter == "Brewmaster_WARRIOR".
--
-- Storage: FCE_CharDB.happyHourByClass = { ["Brewmaster_WARRIOR"] = 3200, … }
----------------------------------------------------------------------

FCE = FCE or {}

local HappyHour = {}
FCE.BrewmasterSystem = HappyHour

----------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------

local MAX_TIME       = 3600       -- 60 minutes in seconds
local TICK_INTERVAL  = 2          -- seconds between ticks
local DECAY_PER_TICK = 2          -- seconds lost per tick while sober
local TARGET_CLASS   = "Brewmaster_WARRIOR"
local ACTIVE_LEVEL   = 10

----------------------------------------------------------------------
-- Visual constants
----------------------------------------------------------------------

local BAR_W = 160
local BAR_H = 14

local COL = {
    BG     = { 0.10, 0.10, 0.10, 0.80 },
    BORDER = { 0.72, 0.62, 0.20, 1.0  },
    FILL   = { 0.65, 0.50, 0.10, 0.90 },  -- amber / beer colour
    WARN   = { 0.80, 0.15, 0.10, 0.95 },  -- red when running low
    GOLD   = { 0.90, 0.78, 0.25 },
    WHITE  = { 0.92, 0.92, 0.90 },
}

----------------------------------------------------------------------
-- Runtime state
----------------------------------------------------------------------

local timeRemaining = MAX_TIME
local ticker        = nil
local barFrame      = nil
local hasFailed     = false
local initialised   = false

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------

local function classKey()
    return FCE_CharDB and FCE_CharDB.selectedCharacter or nil
end

local function isActive()
    return classKey() == TARGET_CLASS and (UnitLevel("player") or 1) >= ACTIVE_LEVEL
end

local function hhDB()
    FCE_CharDB = FCE_CharDB or {}
    FCE_CharDB.happyHourByClass = FCE_CharDB.happyHourByClass or {}
    return FCE_CharDB.happyHourByClass
end

local function loadTime()
    local key = classKey()
    if not key then timeRemaining = MAX_TIME; return end
    timeRemaining = hhDB()[key] or MAX_TIME
end

local function saveTime()
    local key = classKey()
    if not key then return end
    hhDB()[key] = timeRemaining
end

----------------------------------------------------------------------
-- Alcohol detection via chat messages
----------------------------------------------------------------------

local DRUNK_PATTERNS = { "tipsy", "drunk", "smashed", "inebriated", "sloshed", "buzzed" }

local function isDrunkMessage(msg)
    if not msg then return false end
    local lower = msg:lower()
    for _, pat in ipairs(DRUNK_PATTERNS) do
        if lower:find(pat) then return true end
    end
    return false
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
        HappyHour.UpdateBar()
        return
    end

    if IsMounted() or UnitOnTaxi("player") then
        -- Pause timer while mounted or on flight path
    else
        timeRemaining = math.max(0, timeRemaining - DECAY_PER_TICK)
    end

    saveTime()

    if timeRemaining <= 0 and not hasFailed then
        hasFailed = true
        print("|cffff4444[FCE] Happy Hour expired! You failed to drink in time.|r")
        print("|cffff4444Type |cffffcc00/fce happyhour reset|cffff4444 to reset.|r")
        if FCE.RefreshPanel then C_Timer.After(0.3, FCE.RefreshPanel) end
    end

    HappyHour.UpdateBar()
end

----------------------------------------------------------------------
-- UI: Happy Hour bar
----------------------------------------------------------------------

local function CreateBar()
    if barFrame then return end

    barFrame = CreateFrame("Frame", "HCE_BrewmasterBar", UIParent, "BackdropTemplate")
    barFrame:SetSize(BAR_W + 8, BAR_H + 20)
    barFrame:SetFrameStrata("MEDIUM")
    barFrame:SetMovable(true)
    barFrame:EnableMouse(true)
    barFrame:SetClampedToScreen(true)
    barFrame:RegisterForDrag("LeftButton")
    barFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    barFrame:SetScript("OnDragStop",  function(self) self:StopMovingOrSizing() end)

    -- Anchor below doubt bar or savagery bar if they exist
    if HCE_SavageryBar then
        barFrame:SetPoint("TOP", HCE_SavageryBar, "BOTTOM", 0, -2)
    elseif HCE_DoubtBar then
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
    label:SetText("Happy Hour")
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

    -- Time text
    local pctText = barFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pctText:SetPoint("CENTER", barBG, "CENTER", 0, 0)
    pctText:SetTextColor(unpack(COL.WHITE))
    barFrame.pctText = pctText

    -- Tooltip
    barFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Happy Hour", unpack(COL.GOLD))

        if hasFailed then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Time ran out — you forgot to drink!", 1, 0.3, 0.3, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Type /fce happyhour reset to reset.", 1, 0.82, 0)
        else
            GameTooltip:AddLine(" ")
            local mins = math.floor(timeRemaining / 60)
            local secs = timeRemaining % 60
            GameTooltip:AddDoubleLine("Time remaining:",
                string.format("%d:%02d", mins, secs),
                0.9, 0.9, 0.9, 0.9, 0.9, 0.9)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Drink an alcoholic beverage to reset the timer.", 0.5, 0.5, 0.5, true)
        end
        GameTooltip:Show()
    end)
    barFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)

    barFrame:Hide()
end

function HappyHour.UpdateBar()
    if not barFrame then return end

    if not isActive() then
        barFrame:Hide()
        return
    end

    barFrame:Show()

    local pct   = timeRemaining / MAX_TIME
    local fillW = math.max(1, BAR_W * pct)
    barFrame.fill:SetWidth(fillW)

    -- Colour shift: amber at full → red at low
    local inv = 1 - pct
    local r = COL.FILL[1] + (COL.WARN[1] - COL.FILL[1]) * inv
    local g = COL.FILL[2] + (COL.WARN[2] - COL.FILL[2]) * inv
    local b = COL.FILL[3] + (COL.WARN[3] - COL.FILL[3]) * inv
    barFrame.fill:SetColorTexture(r, g, b, 0.92)

    local mins = math.floor(timeRemaining / 60)
    local secs = math.floor(timeRemaining % 60)
    barFrame.pctText:SetText(string.format("%d:%02d", mins, secs))
end

----------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------

function HappyHour.GetTimeRemaining()
    return timeRemaining
end

function HappyHour.HasFailed()
    return hasFailed
end

function HappyHour.Reset()
    if not isActive() then
        print("|cffffcc00[FCE]|r Happy Hour only applies to Brewmaster.")
        return
    end
    timeRemaining = MAX_TIME
    hasFailed     = false
    saveTime()
    HappyHour.UpdateBar()
    print("|cffffcc00[FCE]|r Happy Hour reset to 60 minutes.")
end

function HappyHour.OnClassChanged()
    loadTime()
    hasFailed = timeRemaining <= 0
    HappyHour.UpdateBar()
end

----------------------------------------------------------------------
-- Initialise
----------------------------------------------------------------------

function HappyHour.Init()
    if initialised then return end
    initialised = true

    CreateBar()
    loadTime()
    hasFailed = timeRemaining <= 0
    HappyHour.UpdateBar()

    if not ticker then
        ticker = C_Timer.NewTicker(TICK_INTERVAL, OnTick)
    end
end

----------------------------------------------------------------------
-- Bootstrap + event handling
----------------------------------------------------------------------

local ef = CreateFrame("Frame")
ef:RegisterEvent("PLAYER_LOGIN")
ef:RegisterEvent("CHAT_MSG_SYSTEM")
ef:SetScript("OnEvent", function(_, event, msg)
    if event == "PLAYER_LOGIN" then
        C_Timer.After(3.5, function()
            HappyHour.Init()
        end)
    elseif event == "CHAT_MSG_SYSTEM" then
        if not isActive() or hasFailed then return end
        if isDrunkMessage(msg) then
            timeRemaining = MAX_TIME
            saveTime()
            HappyHour.UpdateBar()
        end
    end
end)
