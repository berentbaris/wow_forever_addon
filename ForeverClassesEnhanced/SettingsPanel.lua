----------------------------------------------------------------------
-- ForeverClassesEnhanced — Settings Panel
--
-- A standalone settings frame that exposes all user-configurable
-- toggles: alert types, sounds, edge-flash, chat warnings, minimap
-- button, and panel behaviour.  Accessible via /fce settings.
--
-- Visual style matches the requirements panel: dark charcoal backdrop
-- with gold accents, NOT a stock Blizzard options template.
----------------------------------------------------------------------

FCE = FCE or {}

local Settings = {}
FCE.SettingsPanel = Settings

----------------------------------------------------------------------
-- Colour constants (shared visual language with RequirementsPanel)
----------------------------------------------------------------------

local COL = {
    BG          = { 0.040, 0.035, 0.030, 0.94 },
    BORDER      = { 0.72, 0.56, 0.30, 0.72 },
    GOLD        = { 1.00, 0.82, 0.00 },
    GOLD_DIM    = { 0.72, 0.56, 0.30 },
    WHITE       = { 0.92, 0.87, 0.76 },
    GREY        = { 0.50, 0.50, 0.50 },
    GREEN       = { 0.30, 0.90, 0.30 },
    RED         = { 1.00, 0.35, 0.35 },
    SECTION_BG  = { 0.08, 0.07, 0.06, 0.85 },
}

----------------------------------------------------------------------
-- Frame dimensions
----------------------------------------------------------------------

local FRAME_W = 340
local FRAME_H = 420
local MARGIN  = 14
local ROW_H   = 26
local SECTION_PAD = 10

----------------------------------------------------------------------
-- Internal state
----------------------------------------------------------------------

local frame    -- the main settings frame
local built = false

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------

--- Get or init the global settings table.
local function db()
    FCE_GlobalDB = FCE_GlobalDB or {}
    return FCE_GlobalDB
end

--- Ensure a default value exists.
local function default(key, val)
    if db()[key] == nil then db()[key] = val end
end

--- Get the per-character settings table for the currently selected
--- character, creating it if needed.  Returns nil if no character is
--- selected.
local function charDB()
    if not FCE_CharDB or not FCE_CharDB.selectedCharacter then return nil end
    FCE_CharDB.charSettings = FCE_CharDB.charSettings or {}
    local key = FCE_CharDB.selectedCharacter
    FCE_CharDB.charSettings[key] = FCE_CharDB.charSettings[key] or {}
    return FCE_CharDB.charSettings[key]
end

--- Read a per-character setting with fallback to the global default.
--- Per-char value of nil means "use global default".
local function charSetting(key, globalDefault)
    local cdb = charDB()
    if cdb and cdb[key] ~= nil then return cdb[key] end
    local g = db()[key]
    if g ~= nil then return g end
    return globalDefault
end

--- Write a per-character setting override.
local function setCharSetting(key, val)
    local cdb = charDB()
    if cdb then cdb[key] = val end
end

--- Create a section header label with gradient underline.
local function SectionHeader(parent, yOff, text)
    local bg = parent:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", parent, "TOPLEFT", MARGIN - 4, yOff + 2)
    bg:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -MARGIN + 4, yOff + 2)
    bg:SetHeight(20)
    bg:SetColorTexture(unpack(COL.SECTION_BG))

    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", MARGIN, yOff)
    lbl:SetTextColor(unpack(COL.GOLD))
    lbl:SetText(text)

    -- Gradient underline (gold fading right)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetTexture("Interface\\Buttons\\WHITE8x8")
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", parent, "TOPLEFT", MARGIN, yOff - 14)
    line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -MARGIN, yOff - 14)
    line:SetGradient("HORIZONTAL",
        CreateColor(1.0, 0.80, 0.45, 0.55),
        CreateColor(1.0, 0.80, 0.45, 0))

    return yOff - 22
end

----------------------------------------------------------------------
-- Toggle checkbox factory
----------------------------------------------------------------------

local checkboxPool = {}

local function MakeCheckbox(parent, yOff, label, tooltipText, getVal, setVal)
    local row = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", MARGIN, yOff)
    row:SetSize(24, 24)

    -- Label text
    local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("LEFT", row, "RIGHT", 4, 1)
    text:SetTextColor(unpack(COL.WHITE))
    text:SetText(label)
    row.label = text

    -- Set initial state
    row:SetChecked(getVal() and true or false)

    -- Click handler
    row:SetScript("OnClick", function(self)
        local newVal = self:GetChecked() and true or false
        setVal(newVal)
        -- Play a subtle click
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
    end)

    -- Tooltip
    if tooltipText then
        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(label, unpack(COL.GOLD))
            GameTooltip:AddLine(tooltipText, unpack(COL.WHITE))
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    table.insert(checkboxPool, row)
    return yOff - ROW_H, row
end

----------------------------------------------------------------------
-- Build the frame
----------------------------------------------------------------------

local function BuildFrame()
    if built then return end
    built = true

    -- Ensure defaults
    default("alertsEnabled", true)
    default("forbiddenAlertsEnabled", true)
    default("chatWarningsEnabled", true)
    default("alertSoundEnabled", true)
    default("edgeFlashEnabled", true)
    default("partyAnnounce", true)
    default("guildAnnounce", true)
    default("guildAnnounceReqs", true)

    -- Main frame
    frame = CreateFrame("Frame", "HCE_SettingsPanel", UIParent, "BackdropTemplate")
    frame:SetSize(FRAME_W, FRAME_H)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)

    -- Dark panel with gold tooltip-border (StoryMode-inspired)
    if FCE.Style then
        FCE.Style.ApplyPanelBackdrop(frame)
        FCE.Style.AddInnerFill(frame)
    else
        frame:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile     = true, tileSize = 16,
            edgeSize = 16,
            insets   = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        frame:SetBackdropColor(unpack(COL.BG))
        frame:SetBackdropBorderColor(unpack(COL.BORDER))
    end

    -- Title bar (draggable)
    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    titleBar:SetHeight(28)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() frame:StartMoving() end)
    titleBar:SetScript("OnDragStop",  function() frame:StopMovingOrSizing() end)

    -- Gold stripe under title
    if FCE.Style then
        FCE.Style.CreateGoldStripe(frame, titleBar, 0)
    else
        local stripe = frame:CreateTexture(nil, "ARTWORK")
        stripe:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -32)
        stripe:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -32)
        stripe:SetHeight(1)
        stripe:SetColorTexture(unpack(COL.GOLD_DIM))
    end

    -- Title text
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", frame, "TOP", 0, -11)
    title:SetTextColor(unpack(COL.GOLD))
    title:SetText("Settings")

    -- Close button (custom)
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 20, 0)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    -- Body area starts below stripe
    local y = -40

    ----------------------------------------------------------------
    -- SECTION: Alerts
    ----------------------------------------------------------------
    y = SectionHeader(frame, y, "ALERTS")

    y = MakeCheckbox(frame, y,
        "Level-up requirement toasts",
        "Show a toast banner when you level up and new requirements become active.",
        function() return db().alertsEnabled end,
        function(v)
            db().alertsEnabled = v
            if not v and FCE.Alert then FCE.Alert.DismissAll() end
        end
    )

    y = MakeCheckbox(frame, y,
        "Forbidden-item warnings",
        "Show a red toast and screen flash when you equip an item that violates a requirement.",
        function() return db().forbiddenAlertsEnabled end,
        function(v)
            db().forbiddenAlertsEnabled = v
            if not v and FCE.ForbiddenAlert then FCE.ForbiddenAlert.DismissAll() end
        end
    )

    y = MakeCheckbox(frame, y,
        "Chat warnings",
        "Print gold [FCE] messages in chat when requirements change status (profession behind, wrong talent spec, etc.).",
        function() return db().chatWarningsEnabled end,
        function(v) db().chatWarningsEnabled = v end
    )

    y = MakeCheckbox(frame, y,
        "Party announcements",
        "Announce your enhanced class in party chat when you level up or join a group, so your groupmates know your rules.",
        function() return db().partyAnnounce end,
        function(v) db().partyAnnounce = v end
    )

    y = MakeCheckbox(frame, y,
        "Guild requirement announcements",
        "Announce completed requirements (challenges, equipment, quests, companions) to guild chat. Rank-up messages are always sent.",
        function() return db().guildAnnounceReqs end,
        function(v) db().guildAnnounceReqs = v end
    )

    y = y - SECTION_PAD

    ----------------------------------------------------------------
    -- SECTION: Effects
    ----------------------------------------------------------------
    y = SectionHeader(frame, y, "EFFECTS")

    y = MakeCheckbox(frame, y,
        "Alert sounds",
        "Play a sound effect with level-up toasts and forbidden-item warnings.",
        function() return db().alertSoundEnabled end,
        function(v) db().alertSoundEnabled = v end
    )

    y = MakeCheckbox(frame, y,
        "Screen-edge flash",
        "Flash a red vignette around the screen edges when a forbidden item is equipped.",
        function() return db().edgeFlashEnabled end,
        function(v) db().edgeFlashEnabled = v end
    )

    y = y - SECTION_PAD

    ----------------------------------------------------------------
    -- SECTION: Interface
    ----------------------------------------------------------------
    y = SectionHeader(frame, y, "INTERFACE")

    y = MakeCheckbox(frame, y,
        "Show minimap button",
        "Display the HC minimap button. Left-click toggles the requirements panel, right-click toggles lock.",
        function()
            local p = db().panel or {}
            local m = p.minimap or {}
            return not m.hide
        end,
        function(v)
            db().panel = db().panel or {}
            db().panel.minimap = db().panel.minimap or {}
            db().panel.minimap.hide = not v
            if v then
                if FCE.ShowMinimapButton then FCE.ShowMinimapButton() end
            else
                if FCE.HideMinimapButton then FCE.HideMinimapButton() end
            end
        end
    )

    y = MakeCheckbox(frame, y,
        "Auto-show panel on login",
        "Automatically reopen the requirements panel when you log in (if it was open last session).",
        function()
            local p = db().panel or {}
            -- Default: true (restore last state).  We use a separate flag
            -- so users who always close it manually can turn this off.
            if p.autoShow == nil then return true end
            return p.autoShow
        end,
        function(v)
            db().panel = db().panel or {}
            db().panel.autoShow = v
        end
    )

    y = MakeCheckbox(frame, y,
        "Lock panel position",
        "Prevent the requirements panel from being dragged.",
        function()
            local p = db().panel or {}
            return p.locked
        end,
        function(v)
            db().panel = db().panel or {}
            db().panel.locked = v
            -- If RequirementsPanel exposes a SetLocked method, call it.
            if FCE.SetPanelLocked then FCE.SetPanelLocked(v) end
        end
    )

    y = y - SECTION_PAD

    ----------------------------------------------------------------
    -- SECTION: Gameplay
    ----------------------------------------------------------------
    y = SectionHeader(frame, y, "GAMEPLAY")

    y = MakeCheckbox(frame, y,
        "Enable Doubt system",
        "Track a 'Doubt' meter that rises over time based on how many requirements you are currently failing. Rest at an inn or sit by a campfire to reduce it.\n\nWhen disabled, the Doubt bar is hidden and doubt does not accumulate.",
        function()
            if db().doubtEnabled == nil then return true end
            return db().doubtEnabled
        end,
        function(v)
            db().doubtEnabled = v
            if FCE.DoubtSystem then FCE.DoubtSystem.UpdateBar() end
        end
    )

    y = y - SECTION_PAD

    ----------------------------------------------------------------
    -- SECTION: Character
    ----------------------------------------------------------------
    y = SectionHeader(frame, y, "CHARACTER")

    -- Current character display (not a checkbox)
    local charLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    charLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", MARGIN, y)
    charLabel:SetTextColor(unpack(COL.WHITE))
    frame.charLabel = charLabel
    y = y - 18

    -- Reset button
    local resetBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    resetBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", MARGIN, y)
    resetBtn:SetSize(110, 22)
    resetBtn:SetText("Reset Selection")
    resetBtn:SetScript("OnClick", function()
        if SlashCmdList and SlashCmdList["FCE"] then
            SlashCmdList["FCE"]("reset")
        end
        Settings.Refresh()
    end)
    resetBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Reset Character", unpack(COL.GOLD))
        GameTooltip:AddLine("Clear your enhanced class selection so auto-detect can run again on next login.", unpack(COL.WHITE))
        GameTooltip:Show()
    end)
    resetBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Change button (opens selection UI)
    local changeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    changeBtn:SetPoint("LEFT", resetBtn, "RIGHT", 8, 0)
    changeBtn:SetSize(100, 22)
    changeBtn:SetText("Change Class")
    changeBtn:SetScript("OnClick", function()
        if FCE.ShowSelectionUI then FCE.ShowSelectionUI() end
    end)

    y = y - 30

    ----------------------------------------------------------------
    -- Support / Donate section
    ----------------------------------------------------------------
    local donateHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    donateHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", MARGIN, y)
    donateHeader:SetTextColor(unpack(COL.GOLD))
    donateHeader:SetText("SUPPORT")
    y = y - 20

    local donateLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    donateLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", MARGIN, y)
    donateLabel:SetPoint("RIGHT", frame, "RIGHT", -MARGIN, 0)
    donateLabel:SetJustifyH("LEFT")
    donateLabel:SetTextColor(unpack(COL.WHITE))
    donateLabel:SetText("Enjoy the addon? Consider supporting development:")
    y = y - 18

    local donateLink = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    donateLink:SetPoint("TOPLEFT", frame, "TOPLEFT", MARGIN, y)
    donateLink:SetTextColor(0.40, 0.75, 1.0)
    donateLink:SetText("buymeacoffee.com/berentbaris")
    y = y - 16

    local donateTip = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    donateTip:SetPoint("TOPLEFT", frame, "TOPLEFT", MARGIN, y)
    donateTip:SetTextColor(unpack(COL.GREY))
    donateTip:SetText("Type |cffffd100/fce donate|r to copy the link.")
    y = y - 24

    ----------------------------------------------------------------
    -- Version footer
    ----------------------------------------------------------------
    local ver = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ver:SetPoint("BOTTOM", frame, "BOTTOM", 0, 8)
    ver:SetTextColor(unpack(COL.GREY))
    ver:SetText("Forever Classes Enhanced v" .. (FCE.version or "?"))

    -- ESC to close
    table.insert(UISpecialFrames, "HCE_SettingsPanel")

    -- Resize the frame to fit content
    local totalH = math.abs(y) + 30
    if totalH > FRAME_H then
        frame:SetHeight(totalH)
    end

    frame:Hide()
end

----------------------------------------------------------------------
-- Refresh checkbox states (call after external changes)
----------------------------------------------------------------------

function Settings.Refresh()
    if not frame then return end
    for _, cb in ipairs(checkboxPool) do
        -- Re-trigger the getter by simulating a fresh read.
        -- Each checkbox was created with a closure; we stored the
        -- getVal inside the OnClick.  Instead, just rebuild.
        -- Simpler: brute-force hide/show to re-fire OnShow hooks.
    end
    -- Update character label
    if frame.charLabel then
        local key = FCE_CharDB and FCE_CharDB.selectedCharacter
        if key then
            local char = FCE.GetCharacter and FCE.GetCharacter(key)
            if char then
                local classStr = char.class:sub(1,1) .. char.class:sub(2):lower()
                frame.charLabel:SetText("Current: |cffffd100" .. char.name .. "|r (" .. char.spec .. " " .. classStr .. ")")
            else
                frame.charLabel:SetText("Current: |cffffd100" .. key .. "|r (data not found)")
            end
        else
            frame.charLabel:SetText("No enhanced class selected.")
        end
    end
end

----------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------

function Settings.Show()
    BuildFrame()
    Settings.Refresh()
    -- Also refresh checkboxes to match current DB state
    for _, cb in ipairs(checkboxPool) do
        -- We need the getter.  Store it on the checkbox at creation time.
    end
    frame:Show()
end

function Settings.Hide()
    if frame then frame:Hide() end
end

function Settings.Toggle()
    BuildFrame()
    if frame:IsShown() then
        frame:Hide()
    else
        Settings.Show()
    end
end

function Settings.IsShown()
    return frame and frame:IsShown()
end

----------------------------------------------------------------------
-- Expose chatWarningsEnabled check for other modules
----------------------------------------------------------------------

function FCE.ChatWarningsEnabled()
    return db().chatWarningsEnabled ~= false
end

----------------------------------------------------------------------
-- Expose alertSoundEnabled check for other modules
----------------------------------------------------------------------

function FCE.AlertSoundEnabled()
    return db().alertSoundEnabled ~= false
end

----------------------------------------------------------------------
-- Expose edgeFlashEnabled check for other modules
----------------------------------------------------------------------

function FCE.EdgeFlashEnabled()
    return db().edgeFlashEnabled ~= false
end

----------------------------------------------------------------------
-- Expose self-found check for other modules.
-- Now driven by the selfFoundChoice made during class selection
-- (on hardcore realms) rather than a settings toggle.
----------------------------------------------------------------------

function FCE.SelfFoundEnabled()
    -- selfFoundChoice is saved at FCE_CharDB top level by CommitSelection
    if FCE_CharDB and FCE_CharDB.selfFoundChoice ~= nil then return FCE_CharDB.selfFoundChoice end
    -- Legacy compat: check old selfFoundEnabled (also top-level)
    if FCE_CharDB and FCE_CharDB.selfFoundEnabled ~= nil then return FCE_CharDB.selfFoundEnabled end
    return false  -- default: OFF (only ON when explicitly chosen on hardcore realms)
end

-- EasyMode system removed — replaced by optional challenge picker in SelectionUI

