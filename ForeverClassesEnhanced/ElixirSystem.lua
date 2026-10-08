----------------------------------------------------------------------
-- ForeverClassesEnhanced — Elixir System  (Elixir Frenzy)
--
-- The Berserker must always be under the effect of an elixir or flask.
-- A 5-minute grace timer counts down whenever no elixir buff is found.
-- Detecting an elixir buff resets the timer.  If it reaches 0 the
-- challenge is considered failed.
--
-- Timer suspends while on a flight path or dead.
--
-- Active for: Berserker_WARRIOR, Berserker_ROGUE
--
-- Storage: FCE_CharDB.elixirGraceByClass = { ["Berserker_WARRIOR"] = 280, … }
----------------------------------------------------------------------


local UnitBuff
    = FCE.Compat.UnitBuff  -- Forever API shims (ForeverCompat.lua)
FCE = FCE or {}

local ElixirFrenzy = {}
FCE.ElixirSystem = ElixirFrenzy

----------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------

local MAX_GRACE      = 300        -- 5 minutes in seconds
local TICK_INTERVAL  = 2          -- seconds between ticks
local DECAY_PER_TICK = 2          -- seconds lost per tick when unbuffed
local ACTIVE_LEVEL   = 15

local TARGET_CLASSES = {
    ["Berserker_WARRIOR"] = true,
    ["Berserker_ROGUE"]   = true,
}

----------------------------------------------------------------------
-- Tracked elixir / flask buff aura IDs  (WoW Classic 1.15.x)
-- These are the BUFF AURA spell IDs, not item or recipe IDs.
-- Update these if detection fails — check in-game with:
--   /run for i=1,40 do local n,_,_,_,_,_,_,_,_,id=UnitBuff("player",i) if n then print(i,n,id) end end
----------------------------------------------------------------------

local elixirSpellIDs = {
    -- Battle Elixirs  (buff aura IDs)
    [2367]  = true, -- Lion's Strength / Lesser Strength
    [2374]  = true, -- Minor Agility
    [8212]  = true, -- Giant Growth
    [3160]  = true, -- Lesser Agility (rank 1)
    [7844]  = true, -- Firepower
    [3164]  = true, -- Ogre's Strength
    [11328] = true, -- Agility
    [21920] = true, -- Frost Power
    [11390] = true, -- Arcane Elixir
    [11334] = true, -- Greater Agility
    [11405] = true, -- Elixir of Giants
    [11474] = true, -- Shadow Power
    [26276] = true, -- Greater Firepower
    [17539] = true, -- Greater Arcane Elixir
    [11406] = true, -- Demonslaying
    [17538] = true, -- Mongoose
    [17537] = true, -- Brute Force
    -- Guardian Elixirs
    [673]   = true, -- Minor Defense
    [2378]  = true, -- Minor Fortitude
    [3166]  = true, -- Wisdom
    [3220]  = true, -- Defense
    [3593]  = true, -- Fortitude
    [11349] = true, -- Greater Defense
    [11396] = true, -- Greater Intellect
    [15279] = true, -- Gift of Arthas
    [11348] = true, -- Superior Defense
    [17535] = true, -- Elixir of the Sages
    [24363] = true, -- Mageblood Potion
    [3219]  = true, -- Weak Troll's Blood
    [24361]  = true, -- Major Troll's Blood
    [3222]  = true, -- Strong Troll's Blood
    [3223]  = true, -- Mighty Troll's Blood
    -- Flasks
    [17626] = true, -- Flask of the Titans
    [17627] = true, -- Flask of Distilled Wisdom
    [17628] = true, -- Flask of Supreme Power
    [17629] = true, -- Flask of Chromatic Resistance
    -- Winterfall / Juju
    [17038] = true, -- Winterfall Firewater
    [16323] = true, -- Juju Power
    [16329] = true, -- Juju Might
    [16322] = true, -- Juju Flurry
}

----------------------------------------------------------------------
-- Visual constants
----------------------------------------------------------------------

local BAR_W = 160
local BAR_H = 14

local COL = {
    BG     = { 0.10, 0.10, 0.10, 0.80 },
    BORDER = { 0.72, 0.62, 0.20, 1.0  },
    FILL   = { 0.15, 0.50, 0.60, 0.90 },  -- teal / potion colour
    WARN   = { 0.80, 0.15, 0.10, 0.95 },  -- red when running low
    GOLD   = { 0.90, 0.78, 0.25 },
    WHITE  = { 0.92, 0.92, 0.90 },
}

----------------------------------------------------------------------
-- Runtime state
----------------------------------------------------------------------

local graceRemaining = MAX_GRACE
local ticker         = nil
local barFrame       = nil
local hasFailed      = false
local initialised    = false

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------

local function classKey()
    return FCE_CharDB and FCE_CharDB.selectedCharacter or nil
end

local function isActive()
    local key = classKey()
    return key and TARGET_CLASSES[key] and (UnitLevel("player") or 1) >= ACTIVE_LEVEL
end

local function elDB()
    FCE_CharDB = FCE_CharDB or {}
    FCE_CharDB.elixirGraceByClass = FCE_CharDB.elixirGraceByClass or {}
    return FCE_CharDB.elixirGraceByClass
end

local function loadGrace()
    local key = classKey()
    if not key then graceRemaining = MAX_GRACE; return end
    graceRemaining = elDB()[key] or MAX_GRACE
end

local function saveGrace()
    local key = classKey()
    if not key then return end
    elDB()[key] = graceRemaining
end

----------------------------------------------------------------------
-- Buff scanning
----------------------------------------------------------------------

local function hasElixirBuff()
    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
        if not name then break end
        if spellId and elixirSpellIDs[spellId] then
            return true
        end
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
        ElixirFrenzy.UpdateBar()
        return
    end

    if hasElixirBuff() then
        graceRemaining = MAX_GRACE          -- buffed → reset grace timer
    elseif UnitOnTaxi("player") then
        -- Pause during flight path
    else
        graceRemaining = math.max(0, graceRemaining - DECAY_PER_TICK)
    end

    saveGrace()

    if graceRemaining <= 0 and not hasFailed then
        hasFailed = true
        print("|cffff4444[FCE] Elixir Frenzy expired! You went too long without an elixir.|r")
        print("|cffff4444Type |cffffcc00/fce elixir reset|cffff4444 to reset.|r")
        if FCE.RefreshPanel then C_Timer.After(0.3, FCE.RefreshPanel) end
    end

    ElixirFrenzy.UpdateBar()
end

----------------------------------------------------------------------
-- UI: Elixir Frenzy bar
----------------------------------------------------------------------

local function CreateBar()
    if barFrame then return end

    barFrame = CreateFrame("Frame", "HCE_ElixirBar", UIParent, "BackdropTemplate")
    barFrame:SetSize(BAR_W + 8, BAR_H + 20)
    barFrame:SetFrameStrata("MEDIUM")
    barFrame:SetMovable(true)
    barFrame:EnableMouse(true)
    barFrame:SetClampedToScreen(true)
    barFrame:RegisterForDrag("LeftButton")
    barFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    barFrame:SetScript("OnDragStop",  function(self) self:StopMovingOrSizing() end)

    -- Anchor below doubt bar or savagery bar
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
    label:SetText("Elixir Frenzy")
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
        GameTooltip:SetText("Elixir Frenzy", unpack(COL.GOLD))

        if hasFailed then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Grace period expired — no elixir buff!", 1, 0.3, 0.3, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Type /fce elixir reset to reset.", 1, 0.82, 0)
        else
            GameTooltip:AddLine(" ")
            if hasElixirBuff() then
                GameTooltip:AddLine("Elixir active — grace timer full.", 0.3, 1, 0.4, true)
            else
                local mins = math.floor(graceRemaining / 60)
                local secs = math.floor(graceRemaining % 60)
                GameTooltip:AddDoubleLine("Grace remaining:",
                    string.format("%d:%02d", mins, secs),
                    1, 0.4, 0.3, 1, 0.4, 0.3)
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Use an elixir or flask to reset the timer.", 0.5, 0.5, 0.5, true)
            end
        end
        GameTooltip:Show()
    end)
    barFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)

    barFrame:Hide()
end

function ElixirFrenzy.UpdateBar()
    if not barFrame then return end

    if not isActive() then
        barFrame:Hide()
        return
    end

    barFrame:Show()

    local pct   = graceRemaining / MAX_GRACE
    local fillW = math.max(1, BAR_W * pct)
    barFrame.fill:SetWidth(fillW)

    -- Colour shift: teal at full → red at low
    local inv = 1 - pct
    local r = COL.FILL[1] + (COL.WARN[1] - COL.FILL[1]) * inv
    local g = COL.FILL[2] + (COL.WARN[2] - COL.FILL[2]) * inv
    local b = COL.FILL[3] + (COL.WARN[3] - COL.FILL[3]) * inv
    barFrame.fill:SetColorTexture(r, g, b, 0.92)

    local mins = math.floor(graceRemaining / 60)
    local secs = math.floor(graceRemaining % 60)
    barFrame.pctText:SetText(string.format("%d:%02d", mins, secs))
end

----------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------

function ElixirFrenzy.GetGraceRemaining()
    return graceRemaining
end

function ElixirFrenzy.HasFailed()
    return hasFailed
end

function ElixirFrenzy.Reset()
    if not isActive() then
        print("|cffffcc00[FCE]|r Elixir Frenzy only applies to Berserker.")
        return
    end
    graceRemaining = MAX_GRACE
    hasFailed      = false
    saveGrace()
    ElixirFrenzy.UpdateBar()
    print("|cffffcc00[FCE]|r Elixir Frenzy reset to 5 minutes.")
end

function ElixirFrenzy.OnClassChanged()
    loadGrace()
    hasFailed = graceRemaining <= 0
    ElixirFrenzy.UpdateBar()
end

----------------------------------------------------------------------
-- Initialise
----------------------------------------------------------------------

function ElixirFrenzy.Init()
    if initialised then return end
    initialised = true

    CreateBar()
    loadGrace()
    hasFailed = graceRemaining <= 0
    ElixirFrenzy.UpdateBar()

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
        C_Timer.After(3.5, function()
            ElixirFrenzy.Init()
        end)
    end
end)
