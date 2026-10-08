----------------------------------------------------------------------
-- ForeverClassesEnhanced — Quest Journal
--
-- StoryMode-inspired chapter-by-chapter quest tracker.
-- Uses the same visual patterns as StoryMode for Classic:
-- circular portrait nodes with ring borders, masked glows,
-- distance-based alpha fade, nav arrows, gradient dividers.
----------------------------------------------------------------------


local GetQuestsCompleted
    = FCE.Compat.GetQuestsCompleted  -- Forever API shims (ForeverCompat.lua)
FCE = FCE or {}

local Journal = {}
FCE.QuestJournal = Journal

----------------------------------------------------------------------
-- Textures & constants (matching StoryMode)
----------------------------------------------------------------------

local SOLID         = "Interface\\Buttons\\WHITE8x8"
local CIRC_MASK     = "Interface/CHARACTERFRAME/TempPortraitAlphaMask"
local PORTRAIT_RING = "Interface\\Common\\portrait-ring-withbg"
local PORTRAIT_RING_FB = "Interface\\Buttons\\GoldRing64"
local ARROW_TEX     = "Interface\\RAIDFRAME\\UI-RAIDFRAME-ARROW"
local CHECKMARK_TEX = "Interface\\Buttons\\UI-CheckBox-Check"

local JOURNAL_W     = 500
local JOURNAL_H     = 470
local CP            = 16          -- content padding

local NODE_SIZE     = 48
local ARROW_GAP     = 24
local TRACK_STEP    = NODE_SIZE + ARROW_GAP   -- 72
local TRACK_H       = 72
local TRACK_ARROW_SZ = 18
local NAV_ARROW_SZ  = 26
local NAV_INSET     = 12

-- Colors (StoryMode palette)
local C_BODY    = { 0.922, 0.871, 0.761 }
local C_GOLD    = { 1.0,   0.82,  0.0   }
local C_DIM     = { 0.50,  0.50,  0.50  }
local C_DIVIDER = { 1.0,   0.80,  0.45  }
local RING_GREEN = { 0.35, 0.78, 0.28 }
local RING_GOLD  = { 1.0,  0.82, 0.35 }

----------------------------------------------------------------------
-- Helpers (matching StoryMode's Style.lua)
----------------------------------------------------------------------

local function NoShadow(fs) fs:SetShadowOffset(0, 0); return fs end

local function SafeSetTexture(tex, path)
    if not tex or not path then return false end
    local ok = pcall(tex.SetTexture, tex, path)
    return ok and tex:GetTexture() ~= nil
end

local function SetSolid(tex, r, g, b, a)
    tex:SetTexture(SOLID)
    tex:SetVertexColor(r or 1, g or 1, b or 1, a or 1)
end

local function CreateSimpleBorder(parent, thickness)
    local b = {}
    thickness = thickness or 1
    local L = "OVERLAY"
    b.top    = parent:CreateTexture(nil, L)
    b.bottom = parent:CreateTexture(nil, L)
    b.left   = parent:CreateTexture(nil, L)
    b.right  = parent:CreateTexture(nil, L)
    b.top:SetHeight(thickness)
    b.bottom:SetHeight(thickness)
    b.left:SetWidth(thickness)
    b.right:SetWidth(thickness)
    return b
end

local function SetBorderColor(border, r, g, b, a)
    if not border then return end
    for _, tex in pairs(border) do
        SetSolid(tex, r, g, b, a)
    end
end

local function SetArrow(tex, direction)
    if not tex then return end
    tex:SetRotation(0)
    SafeSetTexture(tex, ARROW_TEX)
    if direction == "down" then
        tex:SetRotation(-math.pi / 2)
    elseif direction == "left" then
        tex:SetRotation(math.pi)
    end
end

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------

local journalFrame
local titleText, progText
local trackContainer, trackClip, trackInner
local trackNodes  = {}
local trackArrows = {}
local navLBtn, navRBtn, navLTex, navRTex
local detTitle, detInfo, detStatus
local selectedIdx = 1
local questCount  = 0
local curQuests   = {}
local curResults  = {}
local chainScroll, chainContent
local chainRows   = {}
local MAX_CHAIN_ROWS = 14
local CHAIN_ROW_STEP = 30

----------------------------------------------------------------------
-- Track node factory (StoryMode's CreateTrackNode adapted for FCE)
----------------------------------------------------------------------

local function createTrackNode(parent)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(NODE_SIZE, NODE_SIZE)

    -- Portrait (dark circle with level text on top)
    local portrait = btn:CreateTexture(nil, "ARTWORK")
    portrait:SetSize(NODE_SIZE - 4, NODE_SIZE - 4)
    portrait:SetPoint("TOP", btn, "TOP", 0, 0)
    SetSolid(portrait, 0.06, 0.05, 0.04, 0.95)
    if portrait.SetTexelSnappingBias then
        portrait:SetTexelSnappingBias(0)
        portrait:SetSnapToPixelGrid(false)
    end

    -- Circular mask
    local hasMask = false
    local ok, mask = pcall(btn.CreateMaskTexture, btn)
    if ok and mask then
        mask:SetTexture(CIRC_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(portrait)
        portrait:AddMaskTexture(mask)
        hasMask = true
    end
    btn.portrait = portrait

    -- Ring (circular border — same as StoryMode)
    local ring = btn:CreateTexture(nil, "OVERLAY")
    local hasRing = SafeSetTexture(ring, PORTRAIT_RING)
        or SafeSetTexture(ring, PORTRAIT_RING_FB)
        or SafeSetTexture(ring, "Interface\\Buttons\\UI-ActionButton-Border")
    if hasRing then
        ring:SetPoint("CENTER", portrait, "CENTER", 0, 0)
        ring:SetSize(NODE_SIZE + 64, NODE_SIZE + 64)
        ring:SetBlendMode("ADD")
        ring:SetVertexColor(1, 1, 1)
    else
        ring:Hide()
    end
    btn.ring = ring
    btn.hasRing = hasRing

    -- Portrait border (2px simple border as complement)
    local pb = CreateSimpleBorder(btn, 2)
    pb.top:ClearAllPoints()
    pb.top:SetPoint("TOPLEFT",  portrait, "TOPLEFT",  -2,  2)
    pb.top:SetPoint("TOPRIGHT", portrait, "TOPRIGHT",  2,  2)
    pb.bottom:ClearAllPoints()
    pb.bottom:SetPoint("BOTTOMLEFT",  portrait, "BOTTOMLEFT",  -2, -2)
    pb.bottom:SetPoint("BOTTOMRIGHT", portrait, "BOTTOMRIGHT",  2, -2)
    pb.left:ClearAllPoints()
    pb.left:SetPoint("TOPLEFT",    portrait, "TOPLEFT",    -2,  2)
    pb.left:SetPoint("BOTTOMLEFT", portrait, "BOTTOMLEFT", -2, -2)
    pb.right:ClearAllPoints()
    pb.right:SetPoint("TOPRIGHT",    portrait, "TOPRIGHT",    2,  2)
    pb.right:SetPoint("BOTTOMRIGHT", portrait, "BOTTOMRIGHT", 2, -2)
    SetBorderColor(pb, 0.55, 0.48, 0.38, hasRing and 0 or 0.65)
    btn.portraitBorder = pb

    -- Level text (centered on portrait)
    local lv = NoShadow(btn:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
    lv:SetPoint("CENTER", portrait, "CENTER", 0, 0)
    btn.levelText = lv

    -- Checkmark (bottom-right, sublevel 6)
    local ck = btn:CreateTexture(nil, "OVERLAY", nil, 6)
    SafeSetTexture(ck, CHECKMARK_TEX)
    ck:SetSize(18, 18)
    ck:SetPoint("BOTTOMRIGHT", portrait, "BOTTOMRIGHT", 5, -5)
    ck:Hide()
    btn.checkmark = ck

    -- Active glow (golden overlay, masked circular)
    local ag = btn:CreateTexture(nil, "ARTWORK", nil, 3)
    ag:SetTexture(SOLID)
    ag:SetAllPoints(portrait)
    ag:SetVertexColor(1, 0.82, 0.50, 0.25)
    if hasMask then
        local gm = btn:CreateMaskTexture()
        gm:SetTexture(CIRC_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        gm:SetAllPoints(portrait)
        ag:AddMaskTexture(gm)
    end
    ag:Hide()
    btn.activeGlow = ag

    -- Hover glow (same treatment)
    local hg = btn:CreateTexture(nil, "ARTWORK", nil, 4)
    hg:SetTexture(SOLID)
    hg:SetAllPoints(portrait)
    hg:SetVertexColor(1, 0.82, 0.50, 0.25)
    if hasMask then
        local hm = btn:CreateMaskTexture()
        hm:SetTexture(CIRC_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        hm:SetAllPoints(portrait)
        hg:AddMaskTexture(hm)
    end
    hg:Hide()
    btn.hoverGlow = hg

    -- Down-arrow indicator (below node)
    local da = btn:CreateTexture(nil, "OVERLAY", nil, 3)
    SetArrow(da, "down")
    da:SetSize(22, 22)
    da:SetPoint("TOP", portrait, "BOTTOM", 0, 6)
    da:SetVertexColor(C_GOLD[1], C_GOLD[2], C_GOLD[3])
    da:Hide()
    btn.downArrow = da

    -- Tooltip + hover
    btn:SetScript("OnEnter", function(self)
        self.hoverGlow:Show()
        if self.hasRing then
            self.ring:SetVertexColor(C_GOLD[1], C_GOLD[2], C_GOLD[3])
            self.ring:SetAlpha(1.0)
        end
        SetBorderColor(self.portraitBorder, C_GOLD[1], C_GOLD[2], C_GOLD[3],
            self.hasRing and 0 or 1.0)
        if self.tipTitle then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:ClearLines()
            GameTooltip:AddLine(self.tipTitle, 1, 1, 1)
            if self.tipBody then
                GameTooltip:AddLine(self.tipBody, C_BODY[1], C_BODY[2], C_BODY[3], true)
            end
            if self.tipProg then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(self.tipProg, C_DIM[1], C_DIM[2], C_DIM[3])
            end
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function(self)
        self.hoverGlow:Hide()
        if self.bR then
            if self.hasRing then
                self.ring:SetVertexColor(self.bR, self.bG, self.bB)
                self.ring:SetAlpha(self.bA or 1)
            end
            SetBorderColor(self.portraitBorder, self.bR, self.bG, self.bB,
                self.hasRing and 0 or (self.bA or 1))
        end
        GameTooltip:Hide()
    end)

    return btn
end

----------------------------------------------------------------------
-- Gradient divider (center-split, matching StoryMode Classic)
----------------------------------------------------------------------

local function createDivider(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(8)
    local tL = f:CreateTexture(nil, "ARTWORK")
    tL:SetTexture(SOLID)
    tL:SetPoint("LEFT",  f, "LEFT",   0, 0)
    tL:SetPoint("RIGHT", f, "CENTER", 0, 0)
    tL:SetHeight(1)
    tL:SetGradient("HORIZONTAL",
        CreateColor(C_DIVIDER[1], C_DIVIDER[2], C_DIVIDER[3], 0),
        CreateColor(C_DIVIDER[1], C_DIVIDER[2], C_DIVIDER[3], 0.34))
    local tR = f:CreateTexture(nil, "ARTWORK")
    tR:SetTexture(SOLID)
    tR:SetPoint("LEFT",  f, "CENTER", 0, 0)
    tR:SetPoint("RIGHT", f, "RIGHT",  0, 0)
    tR:SetHeight(1)
    tR:SetGradient("HORIZONTAL",
        CreateColor(C_DIVIDER[1], C_DIVIDER[2], C_DIVIDER[3], 0.34),
        CreateColor(C_DIVIDER[1], C_DIVIDER[2], C_DIVIDER[3], 0))
    return f
end

----------------------------------------------------------------------
-- Ornamental divider (diamond centre, gradient wings)
----------------------------------------------------------------------

local function createOrnament(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(12)
    -- left gradient line
    local tL = f:CreateTexture(nil, "ARTWORK")
    tL:SetTexture(SOLID)
    tL:SetPoint("LEFT",  f, "LEFT",   0, 0)
    tL:SetPoint("RIGHT", f, "CENTER", -5, 0)
    tL:SetHeight(1)
    tL:SetGradient("HORIZONTAL",
        CreateColor(C_DIVIDER[1], C_DIVIDER[2], C_DIVIDER[3], 0),
        CreateColor(C_DIVIDER[1], C_DIVIDER[2], C_DIVIDER[3], 0.5))
    -- right gradient line
    local tR = f:CreateTexture(nil, "ARTWORK")
    tR:SetTexture(SOLID)
    tR:SetPoint("LEFT",  f, "CENTER", 5, 0)
    tR:SetPoint("RIGHT", f, "RIGHT",  0, 0)
    tR:SetHeight(1)
    tR:SetGradient("HORIZONTAL",
        CreateColor(C_DIVIDER[1], C_DIVIDER[2], C_DIVIDER[3], 0.5),
        CreateColor(C_DIVIDER[1], C_DIVIDER[2], C_DIVIDER[3], 0))
    -- centre diamond (small rotated square)
    local gem = f:CreateTexture(nil, "ARTWORK", nil, 1)
    gem:SetTexture(SOLID)
    gem:SetSize(6, 6)
    gem:SetPoint("CENTER", f, "CENTER", 0, 0)
    gem:SetVertexColor(C_DIVIDER[1], C_DIVIDER[2], C_DIVIDER[3], 0.6)
    gem:SetRotation(math.pi / 4)
    return f
end

----------------------------------------------------------------------
-- Center track + distance-based alpha fade
----------------------------------------------------------------------

local function centerTrack()
    if questCount == 0 or not trackClip then return end
    local clipW = trackClip:GetWidth()
    if clipW <= 0 then clipW = 350 end
    local selCenter = (selectedIdx - 1) * TRACK_STEP + NODE_SIZE / 2
    local offset = selCenter - clipW / 2

    trackInner:ClearAllPoints()
    trackInner:SetPoint("LEFT", trackClip, "LEFT", -offset, 0)

    local center    = clipW / 2
    local fadeStart = center - NODE_SIZE
    local fadeEnd   = clipW / 2 + 10
    for i, node in ipairs(trackNodes) do
        if not node:IsShown() then break end
        local nc   = (i - 1) * TRACK_STEP + NODE_SIZE / 2 - offset
        local dist = math.abs(nc - center)
        if dist <= fadeStart then
            node:SetAlpha(1.0)
        elseif dist >= fadeEnd then
            node:SetAlpha(0.0)
        else
            node:SetAlpha(1.0 - (dist - fadeStart) / (fadeEnd - fadeStart))
        end
    end
    for i, arrow in ipairs(trackArrows) do
        if not arrow:IsShown() then break end
        local ax   = (i - 1) * TRACK_STEP + NODE_SIZE + ARROW_GAP / 2 - offset
        local dist = math.abs(ax - center)
        if dist <= fadeStart then
            arrow:SetAlpha(1.0)
        elseif dist >= fadeEnd then
            arrow:SetAlpha(0.0)
        else
            arrow:SetAlpha(1.0 - (dist - fadeStart) / (fadeEnd - fadeStart))
        end
    end
end

----------------------------------------------------------------------
-- Navigate helper (shared by arrows + mousewheel)
----------------------------------------------------------------------

local function navigate(delta)
    local next = selectedIdx + delta
    if next < 1 or next > questCount then return end
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    selectedIdx = next
    Journal.LayoutSelected()
    C_Timer.After(0, centerTrack)
end

----------------------------------------------------------------------
-- Ensure frame (lazy creation)
----------------------------------------------------------------------

local function ensureFrame()
    if journalFrame then return end

    -- Main frame (StoryMode panel style for Classic)
    local tmpl = BackdropTemplateMixin and "BackdropTemplate" or nil
    journalFrame = CreateFrame("Frame", "FCE_QuestJournal", UIParent, tmpl)
    journalFrame:SetSize(JOURNAL_W, JOURNAL_H)
    journalFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    journalFrame:SetFrameStrata("HIGH")
    journalFrame:SetMovable(true)
    journalFrame:EnableMouse(true)
    journalFrame:RegisterForDrag("LeftButton")
    journalFrame:SetScript("OnDragStart", journalFrame.StartMoving)
    journalFrame:SetScript("OnDragStop",  journalFrame.StopMovingOrSizing)

    journalFrame:SetBackdrop({
        bgFile   = SOLID,
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = true,
        tileSize = 16,
        edgeSize = 16,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    journalFrame:SetBackdropColor(0.040, 0.035, 0.030, 0.92)
    journalFrame:SetBackdropBorderColor(1.0, 1.0, 1.0, 0.68)

    tinsert(UISpecialFrames, "FCE_QuestJournal")

    -- Close button
    local cb = CreateFrame("Button", nil, journalFrame, "UIPanelCloseButton")
    cb:SetPoint("TOPRIGHT", -4, -4)
    cb:SetScript("OnClick", function() journalFrame:Hide() end)

    -- Title
    titleText = NoShadow(journalFrame:CreateFontString(nil, "OVERLAY", "QuestFont_Large"))
    titleText:SetPoint("TOP", journalFrame, "TOP", 0, -16)
    titleText:SetTextColor(C_GOLD[1], C_GOLD[2], C_GOLD[3])

    -- Progress summary
    progText = NoShadow(journalFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
    progText:SetPoint("TOP", titleText, "BOTTOM", 0, -4)
    progText:SetTextColor(C_BODY[1], C_BODY[2], C_BODY[3])

    -- Divider 1
    local div1 = createDivider(journalFrame)
    div1:SetPoint("TOPLEFT",  journalFrame, "TOPLEFT",  CP, -52)
    div1:SetPoint("TOPRIGHT", journalFrame, "TOPRIGHT", -CP, -52)

    -- Track container
    trackContainer = CreateFrame("Frame", nil, journalFrame)
    trackContainer:SetPoint("TOP", div1, "BOTTOM", 0, -2)
    trackContainer:SetPoint("LEFT",  journalFrame, "LEFT",  0, 0)
    trackContainer:SetPoint("RIGHT", journalFrame, "RIGHT", 0, 0)
    trackContainer:SetHeight(TRACK_H)

    local TRACK_INSET = NAV_ARROW_SZ + NAV_INSET + 8
    trackClip = CreateFrame("Frame", nil, trackContainer)
    trackClip:SetClipsChildren(true)
    trackClip:SetPoint("TOPLEFT",     trackContainer, "TOPLEFT",     TRACK_INSET, 0)
    trackClip:SetPoint("BOTTOMRIGHT", trackContainer, "BOTTOMRIGHT", -TRACK_INSET, 0)

    trackInner = CreateFrame("Frame", nil, trackClip)
    trackInner:SetPoint("LEFT", trackClip, "LEFT", 0, 0)
    trackInner:SetHeight(TRACK_H)

    -- Nav left
    navLBtn = CreateFrame("Button", nil, trackContainer)
    navLBtn:SetSize(NAV_ARROW_SZ + 16, NAV_ARROW_SZ + 16)
    navLBtn:SetPoint("LEFT", trackContainer, "LEFT", NAV_INSET, 5)
    navLBtn:SetFrameLevel(trackClip:GetFrameLevel() + 20)
    navLTex = navLBtn:CreateTexture(nil, "ARTWORK")
    SetArrow(navLTex, "left")
    navLTex:SetSize(NAV_ARROW_SZ, NAV_ARROW_SZ)
    navLTex:SetPoint("CENTER")
    navLTex:SetVertexColor(0.85, 0.75, 0.55)
    navLBtn:SetScript("OnEnter", function() navLTex:SetVertexColor(1, 0.90, 0.65) end)
    navLBtn:SetScript("OnLeave", function()
        local c = selectedIdx > 1
        navLTex:SetVertexColor(c and 0.85 or 0.3, c and 0.75 or 0.25, c and 0.55 or 0.2)
    end)
    navLBtn:SetScript("OnClick", function() navigate(-1) end)

    -- Nav right
    navRBtn = CreateFrame("Button", nil, trackContainer)
    navRBtn:SetSize(NAV_ARROW_SZ + 16, NAV_ARROW_SZ + 16)
    navRBtn:SetPoint("RIGHT", trackContainer, "RIGHT", -NAV_INSET, 5)
    navRBtn:SetFrameLevel(trackClip:GetFrameLevel() + 20)
    navRTex = navRBtn:CreateTexture(nil, "ARTWORK")
    SetArrow(navRTex, "right")
    navRTex:SetSize(NAV_ARROW_SZ, NAV_ARROW_SZ)
    navRTex:SetPoint("CENTER")
    navRTex:SetVertexColor(0.85, 0.75, 0.55)
    navRBtn:SetScript("OnEnter", function() navRTex:SetVertexColor(1, 0.90, 0.65) end)
    navRBtn:SetScript("OnLeave", function()
        local c = selectedIdx < questCount
        navRTex:SetVertexColor(c and 0.85 or 0.3, c and 0.75 or 0.25, c and 0.55 or 0.2)
    end)
    navRBtn:SetScript("OnClick", function() navigate(1) end)

    -- Mousewheel on track
    trackContainer:EnableMouseWheel(true)
    trackContainer:SetScript("OnMouseWheel", function(_, delta)
        navigate(delta > 0 and -1 or 1)
    end)

    -- Divider 2
    local div2 = createDivider(journalFrame)
    div2:SetPoint("TOPLEFT",  trackContainer, "BOTTOMLEFT",  CP, -2)
    div2:SetPoint("TOPRIGHT", trackContainer, "BOTTOMRIGHT", -CP, -2)

    -- Detail: quest name
    detTitle = NoShadow(journalFrame:CreateFontString(nil, "ARTWORK", "QuestFont_Huge"))
    detTitle:SetPoint("TOP", div2, "BOTTOM", 0, -10)
    detTitle:SetPoint("LEFT",  journalFrame, "LEFT",  CP, 0)
    detTitle:SetPoint("RIGHT", journalFrame, "RIGHT", -CP, 0)
    detTitle:SetJustifyH("CENTER")
    detTitle:SetTextColor(C_GOLD[1], C_GOLD[2], C_GOLD[3])

    -- Detail: level + quest ID
    detInfo = NoShadow(journalFrame:CreateFontString(nil, "ARTWORK", "QuestFont"))
    detInfo:SetPoint("TOP", detTitle, "BOTTOM", 0, -4)
    detInfo:SetPoint("LEFT",  journalFrame, "LEFT",  CP, 0)
    detInfo:SetPoint("RIGHT", journalFrame, "RIGHT", -CP, 0)
    detInfo:SetJustifyH("CENTER")
    detInfo:SetSpacing(4)
    detInfo:SetWordWrap(true)
    detInfo:SetTextColor(C_BODY[1], C_BODY[2], C_BODY[3])

    -- Detail: completion status
    detStatus = NoShadow(journalFrame:CreateFontString(nil, "ARTWORK",
        "QuestFont_Shadow_Small"))
    detStatus:SetPoint("TOP", detInfo, "BOTTOM", 0, -8)
    detStatus:SetJustifyH("CENTER")
    detStatus:SetSpacing(3)
    detStatus:SetWordWrap(true)

    -- Ornamental divider (above chain area)
    local div3 = createOrnament(journalFrame)
    div3:SetPoint("TOP",   detStatus, "BOTTOM",  0, -8)
    div3:SetPoint("LEFT",  journalFrame, "LEFT",  CP, 0)
    div3:SetPoint("RIGHT", journalFrame, "RIGHT", -CP, 0)
    journalFrame.div3 = div3

    -- Chain label (hidden – kept for reference)
    local chainLabel = NoShadow(journalFrame:CreateFontString(nil, "ARTWORK",
        "GameFontNormal"))
    chainLabel:SetPoint("TOP", div3, "BOTTOM", 0, -4)
    chainLabel:Hide()
    journalFrame.chainLabel = chainLabel

    -- Chain scroll area
    chainScroll = CreateFrame("ScrollFrame", nil, journalFrame,
        "UIPanelScrollFrameTemplate")
    chainScroll:SetPoint("TOP",  div3, "BOTTOM",  0, -4)
    chainScroll:SetPoint("LEFT", journalFrame, "LEFT", CP, 0)
    chainScroll:SetPoint("RIGHT", journalFrame, "RIGHT", -CP - 14, 0)
    chainScroll:SetPoint("BOTTOM", journalFrame, "BOTTOM", 0, 12)

    chainContent = CreateFrame("Frame", nil, chainScroll)
    chainContent:SetWidth(JOURNAL_W - CP - CP - 6)
    chainContent:SetHeight(1)
    chainScroll:SetScrollChild(chainContent)

    -- Pre-create chain row pool (two-line: quest name + NPC name)
    local CHAIN_ROW_H = 28
    for ci = 1, MAX_CHAIN_ROWS do
        local row = CreateFrame("Frame", nil, chainContent)
        row:SetHeight(CHAIN_ROW_H)
        row:SetPoint("TOPLEFT", chainContent, "TOPLEFT", 0, -(ci - 1) * CHAIN_ROW_STEP)
        row:SetPoint("RIGHT", chainContent, "RIGHT", 0, 0)

        row.icon = { SetText = function() end }   -- icon inlined into name

        local name = NoShadow(row:CreateFontString(nil, "ARTWORK", "GameFontNormal"))
        name:SetPoint("LEFT", row, "LEFT", 4, 4)
        name:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        name:SetJustifyH("CENTER")
        name:SetWordWrap(false)
        row.name = name

        local npc = NoShadow(row:CreateFontString(nil, "ARTWORK",
            "GameFontNormalSmall"))
        npc:SetPoint("TOP", name, "BOTTOM", 0, -1)
        npc:SetPoint("LEFT", row, "LEFT", 4, 0)
        npc:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        npc:SetJustifyH("CENTER")
        npc:SetWordWrap(false)
        npc:SetTextColor(C_DIM[1], C_DIM[2], C_DIM[3])
        row.npc = npc

        row:Hide()
        chainRows[ci] = row
    end

    journalFrame:Hide()
end

----------------------------------------------------------------------
-- Layout selected quest (updates nodes + detail area)
----------------------------------------------------------------------

function Journal.LayoutSelected()
    if not journalFrame or questCount == 0 then return end
    local quest = curQuests[selectedIdx]
    if not quest then return end
    local playerLevel = UnitLevel("player") or 1

    -- Nav arrow enabled state
    local canL = selectedIdx > 1
    local canR = selectedIdx < questCount
    navLBtn:SetEnabled(canL)
    navLTex:SetVertexColor(canL and 0.85 or 0.3, canL and 0.75 or 0.25, canL and 0.55 or 0.2)
    navLTex:SetAlpha(canL and 1.0 or 0.3)
    navRBtn:SetEnabled(canR)
    navRTex:SetVertexColor(canR and 0.85 or 0.3, canR and 0.75 or 0.25, canR and 0.55 or 0.2)
    navRTex:SetAlpha(canR and 1.0 or 0.3)

    -- Update each track node
    for i, node in ipairs(trackNodes) do
        if not node:IsShown() then break end
        local nR  = curResults[i]
        local nQ  = curQuests[i]
        local done   = nR and nR.status == "pass"
        local active = not done and playerLevel >= nQ.level
        local r, g, b, a

        local hp = node.hasPortrait

        if i == selectedIdx then
            r, g, b, a = C_GOLD[1], C_GOLD[2], C_GOLD[3], 1.0
            node.portrait:SetVertexColor(hp and 1 or 0.10, hp and 1 or 0.08, hp and 1 or 0.06, 1)
            node.levelText:SetTextColor(1, 0.82, 0.35)
            node.activeGlow:Show()
            node.downArrow:Show()
            if done then node.checkmark:Show() else node.checkmark:Hide() end
        else
            node.activeGlow:Hide()
            node.downArrow:Hide()
            if done then
                r, g, b, a = RING_GREEN[1], RING_GREEN[2], RING_GREEN[3], 0.8
                node.portrait:SetVertexColor(hp and 0.7 or 0.06, hp and 0.85 or 0.10, hp and 0.7 or 0.06, 1)
                node.levelText:SetTextColor(RING_GREEN[1], RING_GREEN[2], RING_GREEN[3])
                node.checkmark:Show()
            elseif active then
                r, g, b, a = RING_GOLD[1], RING_GOLD[2], RING_GOLD[3], 0.9
                node.portrait:SetVertexColor(hp and 1 or 0.08, hp and 0.95 or 0.07, hp and 0.85 or 0.04, 1)
                node.levelText:SetTextColor(0.90, 0.75, 0.40)
                node.checkmark:Hide()
            else
                r, g, b, a = 0.4, 0.35, 0.30, 0.5
                node.portrait:SetVertexColor(hp and 0.4 or 0.04, hp and 0.35 or 0.03, hp and 0.3 or 0.02, hp and 0.8 or 0.6)
                node.levelText:SetTextColor(0.45, 0.40, 0.35)
                node.checkmark:Hide()
            end
        end

        node.bR, node.bG, node.bB, node.bA = r, g, b, a
        if node.hasRing then
            node.ring:SetVertexColor(r, g, b)
            node.ring:SetAlpha(a)
        end
        SetBorderColor(node.portraitBorder, r, g, b, node.hasRing and 0 or a)
    end

    -- Detail area
    detTitle:SetText(quest.name)
    detInfo:SetText("Level " .. quest.level)
    detStatus:SetText("")

    -- Chain display
    local chain = FCE.QuestChains and FCE.QuestChains[quest.questID]
    if chain and #chain > 1 then
        journalFrame.div3:Show()
        chainScroll:Show()

        -- API check for chain quest completion
        local apiCheck
        if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
            apiCheck = C_QuestLog.IsQuestFlaggedCompleted
        else
            local completed = GetQuestsCompleted and GetQuestsCompleted() or {}
            apiCheck = function(qid) return completed[qid] end
        end

        -- Also check saved completions
        local savedQ = FCE_CharDB and FCE_CharDB.completedQuests or {}

        for ci = 1, MAX_CHAIN_ROWS do
            local row = chainRows[ci]
            if ci <= #chain then
                local cq = chain[ci]
                local cid  = cq[1]
                local cname = cq[2]
                if not cname or cname == "" then
                    cname = "Quest #" .. cid
                end

                local done = apiCheck(cid) or savedQ[cid]
                local isCurrent = (cid == quest.questID)

                if done then
                    row.name:SetText("|TInterface\\RAIDFRAME\\ReadyCheck-Ready:12:12|t " .. cname)
                    row.name:SetTextColor(0.55, 0.80, 0.45)
                elseif isCurrent then
                    row.name:SetText(cname)
                    row.name:SetTextColor(C_GOLD[1], C_GOLD[2], C_GOLD[3])
                else
                    row.name:SetText(cname)
                    row.name:SetTextColor(C_BODY[1], C_BODY[2], C_BODY[3])
                end

                -- NPC quest-giver name + zone
                local npcName = FCE.QuestNPCs and FCE.QuestNPCs[cid]
                local npcZone = FCE.QuestZones and FCE.QuestZones[cid]
                if npcName then
                    if npcZone then
                        row.npc:SetText(npcName .. " - " .. npcZone)
                    else
                        row.npc:SetText(npcName)
                    end
                    row.npc:Show()
                else
                    row.npc:SetText("")
                    row.npc:Hide()
                end

                row:Show()
            else
                row:Hide()
            end
        end
        chainContent:SetHeight(math.max(1, #chain * CHAIN_ROW_STEP))
    else
        -- No chain — show single quest info (same style as chain rows)
        journalFrame.div3:Show()
        chainScroll:Show()

        local row = chainRows[1]
        local apiSolo
        if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
            apiSolo = C_QuestLog.IsQuestFlaggedCompleted
        else
            local completed = GetQuestsCompleted and GetQuestsCompleted() or {}
            apiSolo = function(qid) return completed[qid] end
        end
        local savedQ = FCE_CharDB and FCE_CharDB.completedQuests or {}
        local done = apiSolo(quest.questID) or savedQ[quest.questID]
        if done then
            row.name:SetText("|TInterface\\RAIDFRAME\\ReadyCheck-Ready:12:12|t " .. quest.name)
            row.name:SetTextColor(0.55, 0.80, 0.45)
        else
            row.name:SetText(quest.name)
            row.name:SetTextColor(C_GOLD[1], C_GOLD[2], C_GOLD[3])
        end

        local soloNpc  = FCE.QuestNPCs  and FCE.QuestNPCs[quest.questID]
        local soloZone = FCE.QuestZones and FCE.QuestZones[quest.questID]
        if soloNpc then
            local npcLine = soloNpc
            if soloZone then npcLine = npcLine .. " - " .. soloZone end
            row.npc:SetText(npcLine)
            row.npc:Show()
        else
            row.npc:SetText("")
            row.npc:Hide()
        end
        row:Show()

        for ci = 2, MAX_CHAIN_ROWS do chainRows[ci]:Hide() end
        chainContent:SetHeight(CHAIN_ROW_STEP)
    end

    -- Fixed panel size (no bouncing)
    journalFrame:SetHeight(JOURNAL_H)

    centerTrack()
end

----------------------------------------------------------------------
-- Open the journal for a quest group
----------------------------------------------------------------------

function Journal.Open(quests, results, theme)
    ensureFrame()

    curQuests  = quests
    curResults = results
    questCount = #quests

    titleText:SetText(theme or "Quests")

    local doneN = 0
    for i = 1, questCount do
        if results[i] and results[i].status == "pass" then doneN = doneN + 1 end
    end
    progText:SetText(doneN .. " of " .. questCount .. " quests completed")

    -- Track width
    local totalW = questCount * NODE_SIZE + math.max(0, questCount - 1) * ARROW_GAP
    trackInner:SetWidth(math.max(totalW, 1))

    -- Reset pools
    for _, n in ipairs(trackNodes) do n:Hide() end
    for _, a in ipairs(trackArrows) do a:Hide() end

    local playerLevel = UnitLevel("player") or 1

    for i, q in ipairs(quests) do
        if not trackNodes[i] then
            trackNodes[i] = createTrackNode(trackInner)
        end
        local node = trackNodes[i]

        -- NPC portrait or fallback to level number
        local dispID = FCE.QuestPortraits and FCE.QuestPortraits[q.questID]
        if dispID then
            SetPortraitTextureFromCreatureDisplayID(node.portrait, dispID)
            node.levelText:SetText("")
            node.hasPortrait = true
        else
            SetSolid(node.portrait, 0.06, 0.05, 0.04, 0.95)
            node.levelText:SetText(tostring(q.level))
            node.hasPortrait = false
        end

        -- Tooltip data
        node.tipTitle = q.name
        local chainInfo = FCE.QuestChains and FCE.QuestChains[q.questID]
        local bodyStr = "Level " .. q.level
        if chainInfo and #chainInfo > 1 then
            bodyStr = bodyStr .. "  |  " .. #chainInfo .. "-quest chain"
        end
        local tipNpc = FCE.QuestNPCs and FCE.QuestNPCs[q.questID]
        if tipNpc then
            bodyStr = bodyStr .. "\n" .. tipNpc
            local tipZone = FCE.QuestZones and FCE.QuestZones[q.questID]
            if tipZone then bodyStr = bodyStr .. " - " .. tipZone end
        end
        node.tipBody = bodyStr
        local r = results[i]
        if r and r.status == "pass" then
            node.tipProg = "Completed"
        elseif r and r.status == "inactive" then
            node.tipProg = "Unlocks at level " .. q.level
        elseif r and r.status == "fail" and playerLevel >= q.level then
            node.tipProg = "Not yet completed"
        else
            node.tipProg = nil
        end

        -- Position
        local x = (i - 1) * TRACK_STEP
        node:ClearAllPoints()
        node:SetPoint("TOP", trackInner, "TOPLEFT", x + NODE_SIZE / 2, -8)

        local idx = i
        node:SetScript("OnClick", function()
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            selectedIdx = idx
            Journal.LayoutSelected()
            C_Timer.After(0, centerTrack)
        end)

        node:Show()

        -- Arrow between nodes
        if i < questCount then
            if not trackArrows[i] then
                trackArrows[i] = trackInner:CreateTexture(nil, "ARTWORK")
                SetArrow(trackArrows[i], "right")
            end
            local arrow = trackArrows[i]
            arrow:ClearAllPoints()
            arrow:SetSize(TRACK_ARROW_SZ, TRACK_ARROW_SZ)
            arrow:SetPoint("LEFT", trackInner, "TOPLEFT",
                x + NODE_SIZE + (ARROW_GAP - TRACK_ARROW_SZ) / 2,
                -(NODE_SIZE / 2 + 5))
            if r and r.status == "pass" then
                arrow:SetVertexColor(RING_GREEN[1], RING_GREEN[2], RING_GREEN[3], 0.6)
            else
                arrow:SetVertexColor(C_DIM[1], C_DIM[2], C_DIM[3], 0.3)
            end
            arrow:Show()
        end
    end

    -- Select first incomplete quest
    selectedIdx = 1
    for i = 1, questCount do
        local r = results[i]
        if not r or r.status ~= "pass" then
            selectedIdx = i
            break
        end
        if i == questCount then selectedIdx = i end
    end

    Journal.LayoutSelected()
    journalFrame:Show()
end

function Journal.IsOpen()
    return journalFrame and journalFrame:IsShown()
end

function Journal.Close()
    if journalFrame then journalFrame:Hide() end
end
