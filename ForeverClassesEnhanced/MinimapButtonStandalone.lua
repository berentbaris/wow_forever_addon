----------------------------------------------------------------------
-- ForeverClassesEnhanced — Standalone minimap button backend
--
-- Used only when LibDataBroker-1.1 and LibDBIcon-1.0 are unavailable.
----------------------------------------------------------------------

FCE = FCE or {}

local Standalone = {}
FCE.MinimapButtonStandalone = Standalone

local button
local options

-- Each entry is {BL-round, TL-round, BR-round, TR-round}.
local MINIMAP_SHAPES = {
    ["ROUND"]                 = {true, true, true, true},
    ["SQUARE"]                = {false, false, false, false},
    ["CORNER-TOPLEFT"]        = {false, false, false, true},
    ["CORNER-TOPRIGHT"]       = {false, false, true, false},
    ["CORNER-BOTTOMLEFT"]     = {false, true, false, false},
    ["CORNER-BOTTOMRIGHT"]    = {true, false, false, false},
    ["SIDE-LEFT"]             = {false, true, false, true},
    ["SIDE-RIGHT"]            = {true, false, true, false},
    ["SIDE-TOP"]              = {false, false, true, true},
    ["SIDE-BOTTOM"]           = {true, true, false, false},
    ["TRICORNER-TOPLEFT"]     = {false, true, true, true},
    ["TRICORNER-TOPRIGHT"]    = {true, false, true, true},
    ["TRICORNER-BOTTOMLEFT"]  = {true, true, false, true},
    ["TRICORNER-BOTTOMRIGHT"] = {true, true, true, false},
}

local BUTTON_RADIUS = 5

local function UpdatePosition()
    if not button or not options then return end

    local settings = options.GetSettings()
    local angle = math.rad(settings.angle or 215)
    local x, y = math.cos(angle), math.sin(angle)

    local quadrant = 1
    if x < 0 then quadrant = quadrant + 1 end
    if y > 0 then quadrant = quadrant + 2 end

    local shapeName = GetMinimapShape and GetMinimapShape() or "ROUND"
    local shape = MINIMAP_SHAPES[shapeName] or MINIMAP_SHAPES.ROUND
    local width = (Minimap:GetWidth() / 2) + BUTTON_RADIUS
    local height = (Minimap:GetHeight() / 2) + BUTTON_RADIUS

    if shape[quadrant] then
        x, y = x * width, y * height
    else
        local diagonalWidth = math.sqrt(2 * width ^ 2) - 10
        local diagonalHeight = math.sqrt(2 * height ^ 2) - 10
        x = math.max(-width, math.min(x * diagonalWidth, width))
        y = math.max(-height, math.min(y * diagonalHeight, height))
    end

    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function Standalone.Create(config)
    if button then return button end
    options = config

    button = CreateFrame("Button", "HCE_MinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetMovable(true)

    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetSize(54, 54)
    overlay:SetPoint("TOPLEFT", 0, 0)

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetSize(20, 20)
    background:SetPoint("TOPLEFT", 7, -6)

    local disc = button:CreateTexture(nil, "ARTWORK")
    disc:SetTexture("Interface\\Buttons\\WHITE8x8")
    disc:SetVertexColor(0.08, 0.08, 0.11, 1)
    disc:SetSize(18, 18)
    disc:SetPoint("TOPLEFT", 8, -7)

    local glyph = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    glyph:SetPoint("CENTER", disc, "CENTER", 0, 0)
    glyph:SetText("|cffe6b422FCE|r")

    button:SetScript("OnClick", options.OnClick)
    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local minimapX, minimapY = Minimap:GetCenter()
            local cursorX, cursorY = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cursorX, cursorY = cursorX / scale, cursorY / scale

            local angle = math.deg(math.atan2(cursorY - minimapY, cursorX - minimapX))
            local settings = options.GetSettings()
            settings.angle = angle
            UpdatePosition()
        end)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        options.OnTooltipShow(GameTooltip)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    UpdatePosition()
    if options.GetSettings().hide then button:Hide() else button:Show() end
    return button
end

function Standalone.Show()
    if button then button:Show() end
end

function Standalone.Hide()
    if button then button:Hide() end
end
