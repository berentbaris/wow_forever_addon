----------------------------------------------------------------------
-- ForeverClassesEnhanced — Shared Style Utilities
--
-- StoryMode-inspired visual helpers: dark parchment backgrounds,
-- gold borders, gradient dividers, styled hover highlights, and
-- consistent colour palette.  Every FCE UI file can call these
-- instead of hand-rolling its own backdrop/border code.
----------------------------------------------------------------------

FCE = FCE or {}

local Style = {}
FCE.Style = Style

----------------------------------------------------------------------
-- Texture constants
----------------------------------------------------------------------

local SOLID = "Interface\\Buttons\\WHITE8x8"
Style.SOLID = SOLID

----------------------------------------------------------------------
-- Colour palette
----------------------------------------------------------------------

Style.C_BODY      = { 0.922, 0.871, 0.761 }       -- warm parchment text
Style.C_GOLD      = { 1.00,  0.82,  0.00  }       -- bright gold accents
Style.C_GOLD_DIM  = { 0.72,  0.56,  0.30  }       -- muted gold (borders)
Style.C_DIVIDER   = { 1.00,  0.80,  0.45  }       -- gradient divider gold
Style.C_DIM       = { 0.50,  0.50,  0.50  }       -- dimmed text
Style.C_BG        = { 0.040, 0.035, 0.030, 0.94 } -- dark panel background
Style.C_BG_SOLID  = { 0.055, 0.050, 0.045, 1.00 } -- opaque inner fill
Style.C_TITLE_BG  = { 0.85,  0.70,  0.20,  0.10 } -- title bar tint
Style.C_HOVER     = { 0.92,  0.82,  0.58,  0.08 } -- subtle row hover
Style.C_SECTION   = { 0.08,  0.07,  0.06,  0.85 } -- section header bg

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------

--- Remove font shadow from a FontString.
function Style.NoShadow(fs)
    if fs and fs.SetShadowOffset then
        fs:SetShadowOffset(0, 0)
    end
    return fs
end

--- Set a texture to a solid flat colour.
function Style.SetSolid(tex, r, g, b, a)
    tex:SetTexture(SOLID)
    tex:SetVertexColor(r or 1, g or 1, b or 1, a or 1)
end

----------------------------------------------------------------------
-- Backdrop — dark panel with gold tooltip-style border
----------------------------------------------------------------------

--- Apply the standard FCE panel backdrop (dark bg + gold border).
--- Uses the same Tooltips border that StoryMode uses for its panels.
function Style.ApplyPanelBackdrop(f, bgAlpha, borderAlpha)
    if not f or not f.SetBackdrop then return end
    f:SetBackdrop({
        bgFile   = SOLID,
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = true,
        tileSize = 16,
        edgeSize = 16,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    local bg = Style.C_BG
    f:SetBackdropColor(bg[1], bg[2], bg[3], bgAlpha or bg[4])
    f:SetBackdropBorderColor(Style.C_GOLD_DIM[1], Style.C_GOLD_DIM[2],
        Style.C_GOLD_DIM[3], borderAlpha or 0.72)
end

--- Add an opaque inner fill so the game world never bleeds through.
function Style.AddInnerFill(f, inset)
    inset = inset or 4
    local fill = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    fill:SetTexture(SOLID)
    fill:SetVertexColor(Style.C_BG_SOLID[1], Style.C_BG_SOLID[2],
        Style.C_BG_SOLID[3], Style.C_BG_SOLID[4])
    fill:SetPoint("TOPLEFT", f, "TOPLEFT", inset, -inset)
    fill:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -inset, inset)
    return fill
end

----------------------------------------------------------------------
-- Title bar helpers
----------------------------------------------------------------------

--- Create a thin gold stripe (1px horizontal line).
function Style.CreateGoldStripe(parent, anchorFrame, offsetY)
    local stripe = parent:CreateTexture(nil, "ARTWORK")
    stripe:SetTexture(SOLID)
    stripe:SetVertexColor(Style.C_GOLD_DIM[1], Style.C_GOLD_DIM[2],
        Style.C_GOLD_DIM[3], 0.85)
    if anchorFrame then
        stripe:SetPoint("BOTTOMLEFT", anchorFrame, "BOTTOMLEFT", 0, offsetY or 0)
        stripe:SetPoint("BOTTOMRIGHT", anchorFrame, "BOTTOMRIGHT", 0, offsetY or 0)
    else
        stripe:SetPoint("LEFT", parent, "LEFT", 4, 0)
        stripe:SetPoint("RIGHT", parent, "RIGHT", -4, 0)
    end
    stripe:SetHeight(1)
    return stripe
end

--- Tint a title bar region with a subtle gold wash.
function Style.TintTitleBar(titleBar)
    local tint = titleBar:CreateTexture(nil, "BACKGROUND")
    tint:SetTexture(SOLID)
    tint:SetVertexColor(Style.C_TITLE_BG[1], Style.C_TITLE_BG[2],
        Style.C_TITLE_BG[3], Style.C_TITLE_BG[4])
    tint:SetAllPoints(titleBar)
    return tint
end

----------------------------------------------------------------------
-- Gradient dividers (StoryMode-style)
----------------------------------------------------------------------

--- Horizontal gradient line: transparent → gold → transparent.
--- Returns the container frame.
function Style.CreateGradientDivider(parent, height)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(height or 8)

    local texL = f:CreateTexture(nil, "ARTWORK")
    texL:SetTexture(SOLID)
    texL:SetPoint("LEFT",  f, "LEFT",   0, 0)
    texL:SetPoint("RIGHT", f, "CENTER", 0, 0)
    texL:SetHeight(1)
    local d = Style.C_DIVIDER
    texL:SetGradient("HORIZONTAL",
        CreateColor(d[1], d[2], d[3], 0),
        CreateColor(d[1], d[2], d[3], 0.45))

    local texR = f:CreateTexture(nil, "ARTWORK")
    texR:SetTexture(SOLID)
    texR:SetPoint("LEFT",  f, "CENTER", 0, 0)
    texR:SetPoint("RIGHT", f, "RIGHT",  0, 0)
    texR:SetHeight(1)
    texR:SetGradient("HORIZONTAL",
        CreateColor(d[1], d[2], d[3], 0.45),
        CreateColor(d[1], d[2], d[3], 0))

    return f
end

--- Category divider: centred label with gradient lines fading outward.
--- Returns totalHeight, frame.
function Style.CreateCatDivider(parent, text, yOff)
    local CAT_H = 24
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(CAT_H)
    f:SetPoint("TOPLEFT",  parent, "TOPLEFT",   4, yOff or 0)
    f:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -4, yOff or 0)

    local lbl = Style.NoShadow(
        f:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
    lbl:SetPoint("CENTER", f, "CENTER", 0, 0)
    lbl:SetJustifyH("CENTER")
    lbl:SetText(text)
    lbl:SetTextColor(Style.C_BODY[1], Style.C_BODY[2], Style.C_BODY[3])
    f.label = lbl

    local d = Style.C_DIVIDER
    local lineL = f:CreateTexture(nil, "BACKGROUND")
    lineL:SetTexture(SOLID)
    lineL:SetHeight(1)
    lineL:SetPoint("LEFT",  f,   "LEFT",  6, 0)
    lineL:SetPoint("RIGHT", lbl, "LEFT", -8, 0)
    lineL:SetGradient("HORIZONTAL",
        CreateColor(d[1], d[2], d[3], 0),
        CreateColor(d[1], d[2], d[3], 0.5))

    local lineR = f:CreateTexture(nil, "BACKGROUND")
    lineR:SetTexture(SOLID)
    lineR:SetHeight(1)
    lineR:SetPoint("LEFT",  lbl, "RIGHT", 8, 0)
    lineR:SetPoint("RIGHT", f,   "RIGHT", -6, 0)
    lineR:SetGradient("HORIZONTAL",
        CreateColor(d[1], d[2], d[3], 0.5),
        CreateColor(d[1], d[2], d[3], 0))

    return CAT_H, f
end

----------------------------------------------------------------------
-- Row hover highlight (quest-log style)
----------------------------------------------------------------------

--- Add a subtle gold hover highlight to a row/button.
function Style.AddRowHover(button)
    if not button then return end
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    local ok = pcall(highlight.SetTexture, highlight,
        "Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
    if not ok then
        Style.SetSolid(highlight, Style.C_HOVER[1], Style.C_HOVER[2],
            Style.C_HOVER[3], Style.C_HOVER[4])
    else
        highlight:SetVertexColor(Style.C_HOVER[1], Style.C_HOVER[2],
            Style.C_HOVER[3], Style.C_HOVER[4])
    end
    highlight:SetAllPoints(button)
    button:SetHighlightTexture(highlight)
    return highlight
end

----------------------------------------------------------------------
-- Section header with gradient underline
----------------------------------------------------------------------

--- Emit a styled section header: gold text with a fading underline.
--- Returns the label FontString and the underline texture.
function Style.CreateSectionHeader(parent, text, anchorPoint, offsetX, offsetY)
    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint(anchorPoint or "TOPLEFT", parent,
        anchorPoint or "TOPLEFT", offsetX or 0, offsetY or 0)
    lbl:SetTextColor(Style.C_GOLD[1], Style.C_GOLD[2], Style.C_GOLD[3])
    lbl:SetText(text)

    local d = Style.C_DIVIDER
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetTexture(SOLID)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -2)
    line:SetPoint("RIGHT", parent, "RIGHT", -(offsetX or 0), 0)
    line:SetGradient("HORIZONTAL",
        CreateColor(d[1], d[2], d[3], 0.55),
        CreateColor(d[1], d[2], d[3], 0))

    return lbl, line
end

----------------------------------------------------------------------
-- Styled close button (gold X on hover)
----------------------------------------------------------------------

function Style.CreateCloseButton(parent, size)
    local btn = CreateFrame("Button", nil, parent, "UIPanelCloseButton")
    btn:SetSize(size or 24, size or 24)
    return btn
end

----------------------------------------------------------------------
-- Styled scrollbar (thin gold thumb, dark track)
----------------------------------------------------------------------

----------------------------------------------------------------------
-- Card backdrop (for grid cells, list rows, inset panels)
----------------------------------------------------------------------

--- Apply a dark card backdrop with muted gold border.
--- Lighter than the panel backdrop — used for interactive cards inside a panel.
function Style.ApplyCardBackdrop(f, opts)
    if not f or not f.SetBackdrop then return end
    opts = opts or {}
    f:SetBackdrop({
        bgFile   = SOLID,
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = true,
        tileSize = 16,
        edgeSize = opts.edgeSize or 12,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    f:SetBackdropColor(opts.bgR or 0.055, opts.bgG or 0.050,
        opts.bgB or 0.045, opts.bgA or 0.85)
    f:SetBackdropBorderColor(opts.borderR or 0.50, opts.borderG or 0.42,
        opts.borderB or 0.25, opts.borderA or 0.55)
end

--- Apply a recessed/inset backdrop for inner panels (list bg, detail bg).
--- Darker than a card, feels like a sunken area inside the frame.
function Style.ApplyInsetBackdrop(f)
    if not f or not f.SetBackdrop then return end
    f:SetBackdrop({
        bgFile   = SOLID,
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = true,
        tileSize = 16,
        edgeSize = 12,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    f:SetBackdropColor(0.025, 0.022, 0.018, 0.90)
    f:SetBackdropBorderColor(0.40, 0.34, 0.20, 0.40)
end

----------------------------------------------------------------------
-- Sunken / pressed card state (for selected challenge rows)
----------------------------------------------------------------------

--- Set a card row to "pressed" (sunken) look: darker bg, bright border,
--- inner shadow textures on top and left edges.
function Style.SetCardPressed(row)
    if not row then return end
    if row.SetBackdropColor then
        row:SetBackdropColor(0.025, 0.020, 0.018, 0.95)
    end
    if row.SetBackdropBorderColor then
        row:SetBackdropBorderColor(0.85, 0.70, 0.25, 0.80)
    end
    -- Create inner shadow textures once, then show them
    if not row._fceShadowTop then
        row._fceShadowTop = row:CreateTexture(nil, "ARTWORK", nil, 2)
        row._fceShadowTop:SetTexture(SOLID)
        row._fceShadowTop:SetPoint("TOPLEFT", row, "TOPLEFT", 3, -3)
        row._fceShadowTop:SetPoint("TOPRIGHT", row, "TOPRIGHT", -3, -3)
        row._fceShadowTop:SetHeight(3)
        row._fceShadowTop:SetGradient("VERTICAL",
            CreateColor(0, 0, 0, 0),
            CreateColor(0, 0, 0, 0.35))
    end
    if not row._fceShadowLeft then
        row._fceShadowLeft = row:CreateTexture(nil, "ARTWORK", nil, 2)
        row._fceShadowLeft:SetTexture(SOLID)
        row._fceShadowLeft:SetPoint("TOPLEFT", row, "TOPLEFT", 3, -3)
        row._fceShadowLeft:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 3, 3)
        row._fceShadowLeft:SetWidth(3)
        row._fceShadowLeft:SetGradient("HORIZONTAL",
            CreateColor(0, 0, 0, 0.30),
            CreateColor(0, 0, 0, 0))
    end
    -- Gold accent line along the left edge
    if not row._fceAccent then
        row._fceAccent = row:CreateTexture(nil, "ARTWORK", nil, 3)
        row._fceAccent:SetTexture(SOLID)
        row._fceAccent:SetVertexColor(1.0, 0.82, 0.0, 0.70)
        row._fceAccent:SetPoint("TOPLEFT", row, "TOPLEFT", 3, -3)
        row._fceAccent:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 3, 3)
        row._fceAccent:SetWidth(2)
    end
    if row._fceShadowTop  then row._fceShadowTop:Show()  end
    if row._fceShadowLeft then row._fceShadowLeft:Show() end
    if row._fceAccent     then row._fceAccent:Show()     end
end

--- Set a card row to normal (not pressed) look.
function Style.SetCardNormal(row)
    if not row then return end
    if row.SetBackdropColor then
        row:SetBackdropColor(0.055, 0.050, 0.045, 0.85)
    end
    if row.SetBackdropBorderColor then
        row:SetBackdropBorderColor(0.50, 0.42, 0.25, 0.55)
    end
    if row._fceShadowTop  then row._fceShadowTop:Hide()  end
    if row._fceShadowLeft then row._fceShadowLeft:Hide() end
    if row._fceAccent     then row._fceAccent:Hide()     end
end

----------------------------------------------------------------------
-- Styled action button (replaces UIPanelButtonTemplate)
----------------------------------------------------------------------

--- Create a dark custom button with gold border and hover glow.
--- Returns the Button frame.  Use btn:SetText() as usual.
function Style.CreateButton(parent, width, height, text)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width or 120, height or 26)

    btn:SetBackdrop({
        bgFile   = SOLID,
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = true,
        tileSize = 16,
        edgeSize = 14,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    btn:SetBackdropColor(0.10, 0.08, 0.05, 0.95)
    btn:SetBackdropBorderColor(0.72, 0.56, 0.30, 0.85)

    -- Top-edge highlight (gradient shine)
    local shine = btn:CreateTexture(nil, "ARTWORK", nil, 1)
    shine:SetTexture(SOLID)
    shine:SetPoint("TOPLEFT", btn, "TOPLEFT", 4, -4)
    shine:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -4, -4)
    shine:SetHeight(1)
    shine:SetVertexColor(1.0, 0.82, 0.40, 0.25)

    -- Text
    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER", 0, 1)
    label:SetTextColor(1.0, 0.82, 0.0)
    if text then label:SetText(text) end
    btn._label = label

    -- Override SetText to also set our label
    btn.SetText = function(self, t) self._label:SetText(t) end
    btn.GetText = function(self) return self._label:GetText() end
    btn.Enable = function(self)
        self:SetAlpha(1.0)
        self._label:SetTextColor(1.0, 0.82, 0.0)
        self._disabled = false
    end
    btn.Disable = function(self)
        self:SetAlpha(0.50)
        self._label:SetTextColor(0.50, 0.50, 0.50)
        self._disabled = true
    end

    -- Hover: brighten border + bg glow
    btn:SetScript("OnEnter", function(self)
        if self._disabled then return end
        self:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
        self:SetBackdropColor(0.16, 0.12, 0.06, 0.98)
        self._label:SetTextColor(1.0, 0.90, 0.30)
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.72, 0.56, 0.30, 0.85)
        self:SetBackdropColor(0.10, 0.08, 0.05, 0.95)
        if not self._disabled then
            self._label:SetTextColor(1.0, 0.82, 0.0)
        end
    end)
    -- Pressed: darken + shift
    btn:SetScript("OnMouseDown", function(self)
        if self._disabled then return end
        self:SetBackdropColor(0.04, 0.03, 0.02, 0.98)
        self._label:SetPoint("CENTER", 1, 0)
    end)
    btn:SetScript("OnMouseUp", function(self)
        self:SetBackdropColor(0.16, 0.12, 0.06, 0.98)
        self._label:SetPoint("CENTER", 0, 1)
    end)

    return btn
end


----------------------------------------------------------------------
-- Styled scrollbar (thin gold thumb, dark track)
----------------------------------------------------------------------

function Style.StyleScrollbar(scrollFrame)
    local scrollbar = scrollFrame.ScrollBar
        or scrollFrame.Scrollbar
        or (scrollFrame.GetName and scrollFrame:GetName()
            and _G[scrollFrame:GetName() .. "ScrollBar"])
    if not scrollbar then return end

    scrollbar:SetWidth(8)

    -- Reposition scrollbar (X controls gap between content and scrollbar)
    scrollbar:ClearAllPoints()
    scrollbar:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", -15, -2)
    scrollbar:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", -15, 2)

    -- Dark track
    if not scrollbar._fceTrack then
        scrollbar._fceTrack = scrollbar:CreateTexture(nil, "BACKGROUND")
        scrollbar._fceTrack:SetPoint("TOP", scrollbar, "TOP", 0, -2)
        scrollbar._fceTrack:SetPoint("BOTTOM", scrollbar, "BOTTOM", 0, 2)
        scrollbar._fceTrack:SetWidth(4)
        Style.SetSolid(scrollbar._fceTrack, 0.0, 0.0, 0.0, 0.48)
    end

    -- Gold thumb
    local thumb = (scrollbar.GetThumbTexture and scrollbar:GetThumbTexture())
        or scrollbar.ThumbTexture
    if thumb then
        Style.SetSolid(thumb, 0.72, 0.58, 0.32, 0.88)
        thumb:SetWidth(8)
    end

    -- Dim arrows and other decorations
    for _, region in ipairs({ scrollbar:GetRegions() }) do
        if region ~= thumb and region.SetAlpha then
            region:SetAlpha(0.12)
        end
    end
    for _, child in ipairs({ scrollbar:GetChildren() }) do
        if child.SetAlpha then child:SetAlpha(0.45) end
        if child.SetSize  then child:SetSize(12, 12) end
    end
end
