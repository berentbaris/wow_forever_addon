----------------------------------------------------------------------
-- ForeverClassesEnhanced — Integrated Class Catalog & Picker
--
-- A unified UI that combines browsing and selecting enhanced classes.
--
-- Three-screen flow:
--   Screen 1: WoW class grid (9 classes)
--   Screen 2: Enhanced classes for that WoW class (Core + Additional)
--   Screen 3: Class detail with art panel on the right + Select button
--
-- Auto-opens on login when no class is picked.
-- Also reachable via /fce catalog, /fce pick, /fce ui.
----------------------------------------------------------------------


local UnitBuff
    = FCE.Compat.UnitBuff  -- Forever API shims (ForeverCompat.lua)
FCE = FCE or {}

local Catalog = {}
FCE.CatalogUI = Catalog

----------------------------------------------------------------------
-- Hardcore realm detection (no API exists; maintain list manually)
----------------------------------------------------------------------
local HARDCORE_REALMS = {
    -- NA (original Aug 2023)
    ["Skull Rock"]       = true,
    ["Defias Pillager"]  = true,
    -- EU (original Aug 2023)
    ["Nek'Rosh"]         = true,
    ["Stitches"]         = true,
    -- Anniversary (Nov 2024)
    ["Doomhowl"]         = true,
    ["Soulseeker"]       = true,
    -- Add new HC realms here as Blizzard creates them
}

local function IsHardcoreRealm()
    local realm = GetRealmName and GetRealmName()
    return realm and HARDCORE_REALMS[realm] or false
end

----------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------
local FRAME_WIDTH   = 710
local FRAME_HEIGHT  = 620
local GRID_COL_W    = 280    -- width of each faction column
local GRID_GAP      = 30     -- gap between faction columns
local GRID_CELL_H   = 44
local GRID_PAD_Y    = 6
local LIST_ROW_H    = 40
local ROW_HEIGHT    = 16

-- WoW class colours (hex, no leading |cff)
local CLASS_COLORS = {
    WARRIOR = "c79c6e", PALADIN = "f58cba", HUNTER  = "abd473",
    ROGUE   = "fff569", PRIEST  = "ffffff", SHAMAN  = "0070de",
    MAGE    = "69ccf0", WARLOCK = "9482c9", DRUID   = "ff7d0a",
}

-- WoW class icons (Blizzard texture atlas paths)
local CLASS_ICONS = {
    WARRIOR = "Interface\\Icons\\ClassIcon_Warrior",
    PALADIN = "Interface\\Icons\\ClassIcon_Paladin",
    HUNTER  = "Interface\\Icons\\ClassIcon_Hunter",
    ROGUE   = "Interface\\Icons\\ClassIcon_Rogue",
    PRIEST  = "Interface\\Icons\\ClassIcon_Priest",
    SHAMAN  = "Interface\\Icons\\ClassIcon_Shaman",
    MAGE    = "Interface\\Icons\\ClassIcon_Mage",
    WARLOCK = "Interface\\Icons\\ClassIcon_Warlock",
    DRUID   = "Interface\\Icons\\ClassIcon_Druid",
}

----------------------------------------------------------------------
-- Cosmic sphere icons for enhanced class browse grid
----------------------------------------------------------------------
local ICO = "Interface\\AddOns\\ForeverClassesEnhanced\\Icons\\"
local SPHERE_COLORS = {
    light   = "fff2b0",  -- warm gold
    life    = "7ec850",  -- nature green
    chaos   = "50e650",  -- fel green
    reality = "c8a862",  -- earthy tan
    order   = "5cc0e8",  -- arcane blue
    death   = "b060d8",  -- purple
    shadow  = "7848b0",  -- deep violet
}

local SPHERE_ICONS = {
    light   = ICO .. "light",
    life    = ICO .. "life",
    chaos   = ICO .. "chaos",
    reality = ICO .. "reality",
    order   = ICO .. "order",
    death   = ICO .. "death",
    shadow  = ICO .. "shadow",
}

-- Browse-all icon IDs (WoW texture file IDs, no external files needed)
-- Find IDs at: https://www.wowhead.com/icons  — uncomment and fill in as you go
FCE.BROWSE_ICONS = {
    ["Shadow Hunter"]      = 136200,
    ["Death Knight"]       = 133074,
    ["Dark Rider"]         = 136177,
    ["Demon Hunter"]       = 136172,
    ["Blademaster"]        = 136056,
    ["Beastmaster"]        = 134326,
    ["Berserker"]          = 135727,
    ["Barbarian"]          = 132352,
    ["Mountain King"]      = 132275,
    ["Brewmaster"]         = 132814,
    ["Dark Ranger"]        = 255133,
    ["Mountaineer"]        = 133582,
    ["Wilderness Stalker"] = 134166,
    ["Prospector"]         = 236575,
    ["Buccaneer"]          = 133168,
    ["Brave"]              = 135125,
    ["Warden"]             = 132330,
    ["Elven Ranger"]       = 132089,
    ["Druid of the Claw"]  = 236164,
    ["Druid of the Wild"]  = 132280,
    ["Savagekin"]          = 236163,
    ["Plagueshifter"]      = 136066,
    ["Earthcaller"]        = 136089,
    ["Dragonsworn"]        = 134157,
    ["Bloodmage"]          = 343635,
    ["Pyremaster"]         = 135817,
    ["Hedge Wizard"]       = 236220,
    ["Techno-mage"]        = 135815,
    ["Ley Walker"]         = 236219,
    ["Runemaster"]         = 134416,
    ["Sister of Steel"]    = 135038,
    ["Kirin Tor Mage"]     = 236693,
    ["Spellblade"]         = 135642,
    ["Tinker"]             = 133023,
    ["Scarlet Champion"]   = 135951,
    ["Priestess of the Moon"]     = 135900,
    ["Exemplar"]           = 133328,
    ["Templar"]            = 135977,
    ["Shieldbearer"]       = 135870,
    ["Apothecary"]         = 134799,
    ["Necromancer"]        = 136143,
    ["Spiritwalker"]       = 237571,
    ["Lightslayer"]        = 136205,
    ["Witch Doctor"]       = 132482,
    ["Twilight Cultist"]   = 132658,
    ["Huntress"]           = 132279,
    ["Gladiator"]          = 135358,
    ["Deathguard"]         = 306622,
    ["Spirit Champion"]    = 136075,
    ["Farseer"]            = 237577,
    ["Barbarian"]          = 132352,
    ["Druid of the Talon"] = 136076,
    ["Fletcher"]           = 134404,
}

-- Map each enhanced class display name → sphere key
local CLASS_SPHERE = {
    -- Reality (earth)
    
}

----------------------------------------------------------------------
-- Race data for Screen 1 grid
----------------------------------------------------------------------
local RACE_ORDER = {
    "Human",     "Dwarf",    "Night Elf", "Gnome",
    "Orc",       "Troll",    "Tauren",    "Undead",
}

-- Race portrait icons (Blizzard race icon textures)
local RACE_ICONS = {
    ["Human"]     = "Interface\\Icons\\Achievement_Character_Human_Male",
    ["Dwarf"]     = "Interface\\Icons\\Achievement_Character_Dwarf_Male",
    ["Night Elf"] = "Interface\\Icons\\Achievement_Character_Nightelf_Male",
    ["Gnome"]     = "Interface\\Icons\\Achievement_Character_Gnome_Male",
    ["Orc"]       = "Interface\\Icons\\Achievement_Character_Orc_Male",
    ["Troll"]     = "Interface\\Icons\\Achievement_Character_Troll_Male",
    ["Tauren"]    = "Interface\\Icons\\Achievement_Character_Tauren_Male",
    ["Undead"]    = "Interface\\Icons\\Achievement_Character_Undead_Male",
}

-- Race display colours (faction-tinted)
local RACE_COLORS = {
    ["Human"]     = "3399ff", ["Dwarf"]     = "3399ff",
    ["Night Elf"] = "3399ff", ["Gnome"]     = "3399ff",
    ["Orc"]       = "ff4444", ["Troll"]     = "ff4444",
    ["Tauren"]    = "ff4444", ["Undead"]    = "ff4444",
}

-- WoW Classic race → valid base classes
local RACE_CLASSES = {
    ["Human"]     = { WARRIOR=true, PALADIN=true, ROGUE=true, PRIEST=true, MAGE=true, WARLOCK=true },
    ["Dwarf"]     = { WARRIOR=true, PALADIN=true, HUNTER=true, ROGUE=true, PRIEST=true },
    ["Night Elf"] = { WARRIOR=true, HUNTER=true, ROGUE=true, PRIEST=true, DRUID=true },
    ["Gnome"]     = { WARRIOR=true, ROGUE=true, MAGE=true, WARLOCK=true },
    ["Orc"]       = { WARRIOR=true, HUNTER=true, ROGUE=true, SHAMAN=true, WARLOCK=true },
    ["Troll"]     = { WARRIOR=true, HUNTER=true, ROGUE=true, PRIEST=true, SHAMAN=true, MAGE=true },
    ["Tauren"]    = { WARRIOR=true, HUNTER=true, SHAMAN=true, DRUID=true },
    ["Undead"]    = { WARRIOR=true, ROGUE=true, PRIEST=true, MAGE=true, WARLOCK=true },
}

-- Alliance races are indices 1–4, Horde are 5–8 in RACE_ORDER
local ALLIANCE_RACE_ORDER = { "Human", "Dwarf", "Night Elf", "Gnome" }
local HORDE_RACE_ORDER    = { "Orc", "Troll", "Tauren", "Undead" }

local HIDE_CHALLENGE = { ["yamama"] = true }

-- Colours matching RequirementsPanel (exact same values)
local COLOR_HEADER   = { r = 1.00, g = 0.78, b = 0.10 }
local COLOR_SUBTXT   = { r = 0.75, g = 0.75, b = 0.75 }
local COLOR_INACTIVE = { r = 0.55, g = 0.55, b = 0.55 }
local COLOR_TIPS     = { r = 0.55, g = 0.70, b = 0.85 }
local DETAIL_ROW_H   = 16
local DETAIL_PAD_X   = 14
local DETAIL_PAD_Y   = 10
local DETAIL_SEC_GAP = 8
local DETAIL_WIDTH   = 350

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------
local frame              -- main frame (created once)
local currentScreen = 1  -- 1=browse all, 2=build picker, 3=detail
local selectedRace   -- e.g. "WARRIOR"
local selectedCharKey    -- e.g. "Mountain King"
local selectedOptChallenges = {}  -- set of desc strings currently ticked
local selectedEnhancedName   -- e.g. "Moon Priest" (for build picker)

-- Browse-all filter state (toggleable)
local raceFilters  = {}  -- { ["Human"]=true, ["Orc"]=true, ... }
local classFilters = {}  -- { ["WARRIOR"]=true, ["MAGE"]=true, ... }

-- Browse icon constants
local ICON_SIZE  = 64
local ICON_GAP   = 10
local ICON_CELL  = ICON_SIZE + 28  -- icon + name label height
local FILTER_H   = 26
local FILTER_GAP = 4

-- Gear-based (exemptable) challenges — only one allowed at a time
local GEAR_CHALLENGES_CAT = {
    ["Exotic"] = true, ["Scout"] = true, ["Scavenger"] = true,
    ["Partisan"] = true, ["Self-made"] = true, ["Expeditionary"] = true,
    ["Cloth/leather"] = true, ["Leather/mail"] = true, ["Mail/plate"] = true,
    ["Cloth"] = true, ["Leather"] = true, ["Off-the-shelf"] = true,
}
local selectedSelfFound    -- true/false/nil — player's self-found choice (hardcore only)
local cameFromUndecided = false  -- true when Screen 3 was reached via undecided panel

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
local function titleCase(s)
    if not s or s == "" then return "" end
    return s:sub(1, 1):upper() .. s:sub(2):lower()
end

local function cc(classToken)
    return CLASS_COLORS[classToken or ""] or "ffd100"
end

local ALLIANCE_RACES = { Human = true, Dwarf = true, ["Night Elf"] = true, Gnome = true }
local HORDE_RACES    = { Orc = true, Troll = true, Tauren = true, Undead = true }

local FACTION_CLASS = { SHAMAN = "HORDE", PALADIN = "ALLIANCE" }

local function factionColor(race, classToken)
    -- Shaman is always Horde, Paladin is always Alliance in Classic
    if classToken and FACTION_CLASS[classToken] == "HORDE" then
        return 0.70, 0.20, 0.20, 0.30
    elseif classToken and FACTION_CLASS[classToken] == "ALLIANCE" then
        return 0.20, 0.40, 0.80, 0.30
    end
    if not race or race == "Any race" or race == "" then
        return 0.85, 0.75, 0.30, 0.25   -- gold/neutral
    end
    -- Handle multi-race like "Human, Gnome"
    local allA, allH = true, true
    for token in race:gmatch("[^,]+") do
        local r = token:match("^%s*(.-)%s*$")  -- trim whitespace
        if not ALLIANCE_RACES[r] then allA = false end
        if not HORDE_RACES[r] then allH = false end
    end
    if allA and not allH then
        return 0.20, 0.40, 0.80, 0.30   -- blue/alliance
    elseif allH and not allA then
        return 0.70, 0.20, 0.20, 0.30   -- red/horde
    end
    return 0.85, 0.75, 0.30, 0.25       -- gold/neutral (mixed)
end

--- Get all characters for a given WoW class, sorted by name.
local function getCharactersForClass(wowClass)
    local chars = {}
    for key, char in pairs(FCE.Characters or {}) do
        if char.class == wowClass then
            table.insert(chars, char)
        end
    end
    table.sort(chars, function(a, b) return a.name < b.name end)
    return chars
end

--- Get all characters available for a given race, sorted by class then name.
--- Includes "Any race" characters, but only for classes the race can play.
local function getCharactersForRace(race)
    local validClasses = RACE_CLASSES[race] or {}
    local chars = {}
    for _, char in pairs(FCE.Characters or {}) do
        -- Must be a class this race can play
        if validClasses[char.class] then
            -- Must match the race (explicit or "Any race")
            if char.raceSet and (char.raceSet[race] or char.raceSet["Any race"]) then
                table.insert(chars, char)
            end
        end
    end
    table.sort(chars, function(a, b)
        if a.class ~= b.class then return a.class < b.class end
        return a.name < b.name
    end)
    return chars
end

----------------------------------------------------------------------
-- Frame creation (once)
----------------------------------------------------------------------
-- Sub-frames for each screen
local classGridFrame     -- Screen 1
local classListFrame     -- Screen 2
local detailFrame        -- Screen 3
local undecidedFrame     -- Screen 2u (undecided path picker)
local selfFoundFrame     -- Screen 3.5 (self-found picker, hardcore only)
local challengeFrame     -- Screen 4 (optional challenge picker)

local function BuildFrame()
    if frame then return end

    frame = CreateFrame("Frame", "HCE_CatalogFrame", UIParent, "BackdropTemplate")
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")
    tinsert(UISpecialFrames, "HCE_CatalogFrame")

    -- Dark panel with gold tooltip-border (StoryMode-inspired)
    if FCE.Style then
        FCE.Style.ApplyPanelBackdrop(frame)
        FCE.Style.AddInnerFill(frame)
    elseif frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 16,
            insets   = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        frame:SetBackdropColor(0.040, 0.035, 0.030, 0.94)
        frame:SetBackdropBorderColor(0.72, 0.56, 0.30, 0.72)
    end

    -- Title bar
    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOPLEFT", 4, -4)
    titleBar:SetPoint("TOPRIGHT", -4, -4)
    titleBar:SetHeight(32)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() frame:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)

    if FCE.Style then
        FCE.Style.TintTitleBar(titleBar)
        FCE.Style.CreateGoldStripe(frame, titleBar, 0)
    else
        local titleBg = titleBar:CreateTexture(nil, "BACKGROUND")
        titleBg:SetColorTexture(0.85, 0.70, 0.20, 0.10)
        titleBg:SetAllPoints()
        local titleStripe = titleBar:CreateTexture(nil, "ARTWORK")
        titleStripe:SetColorTexture(0.72, 0.56, 0.30, 0.85)
        titleStripe:SetPoint("BOTTOMLEFT", titleBar, "BOTTOMLEFT", 0, 0)
        titleStripe:SetPoint("BOTTOMRIGHT", titleBar, "BOTTOMRIGHT", 0, 0)
        titleStripe:SetHeight(1)
    end

    frame.titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.titleText:SetPoint("LEFT", titleBar, "LEFT", 10, 0)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("TOPRIGHT", titleBar, "TOPRIGHT", 0, 2)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    -- Back button (hidden on screen 1)
    local backBtn
    if FCE.Style then
        backBtn = FCE.Style.CreateButton(frame, 80, 22, "< Back")
    else
        backBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        backBtn:SetText("< Back")
    end
    backBtn:SetSize(80, 22)
    backBtn:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 8, -6)
    backBtn:Hide()
    backBtn:SetScript("OnClick", function()
        if currentScreen == 4 then
            -- Go back to self-found screen if it was shown, else detail
            local ch = selectedCharKey and FCE.Characters and FCE.Characters[selectedCharKey]
            local charSF = ch and (FCE.GetCharSelfFound and FCE.GetCharSelfFound(ch) or ch.selfFound)
            if charSF and IsHardcoreRealm() then
                Catalog.ShowSelfFoundScreen(selectedCharKey)
            else
                Catalog.ShowScreen3(selectedCharKey)
            end
        elseif currentScreen == 35 then  -- self-found screen
            Catalog.ShowScreen3(selectedCharKey)
        elseif currentScreen == 3 then
            if cameFromUndecided then
                Catalog.ShowUndecidedPanel()
            elseif selectedEnhancedName then
                Catalog.ShowScreen2(selectedEnhancedName)
            else
                Catalog.ShowScreen1()
            end
        elseif currentScreen == 20 then  -- undecided panel
            Catalog.ShowScreen1()
        elseif currentScreen == 2 then
            Catalog.ReturnToScreen1()
        end
    end)
    frame.backBtn = backBtn

    -- Content area (below title + back button)
    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -68)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)
    frame.content = content

    ----------------------------------------------------------------
    -- SCREEN 1: Browse All — filter rows + circular icon grid
    ----------------------------------------------------------------
    classGridFrame = CreateFrame("Frame", nil, content)
    classGridFrame:SetAllPoints()

    -- Race filter row (8 radio buttons, centered)
    local ALL_RACES = { "Human", "Dwarf", "Night Elf", "Gnome", "Orc", "Troll", "Tauren", "Undead" }
    local raceRowW = #ALL_RACES * (FILTER_H + FILTER_GAP) - FILTER_GAP
    local raceRow = CreateFrame("Frame", nil, classGridFrame)
    raceRow:SetSize(raceRowW, FILTER_H)
    raceRow:SetPoint("TOP", classGridFrame, "TOP", 0, 0)
    classGridFrame.raceRow = raceRow
    classGridFrame.raceBtns = {}

    -- Forward-declare so race OnClick can call it
    local deselectAllClass

    local function deselectAllRace()
        for _, b in pairs(classGridFrame.raceBtns) do
            b.active = false
            if b.SetBackdropBorderColor then
                b:SetBackdropBorderColor(0.40, 0.35, 0.22, 0.55)
            end
        end
        wipe(raceFilters)
    end

    for i, race in ipairs(ALL_RACES) do
        local fb = CreateFrame("Button", nil, raceRow, "BackdropTemplate")
        fb:SetSize(FILTER_H, FILTER_H)
        fb:SetPoint("LEFT", raceRow, "LEFT", (i - 1) * (FILTER_H + FILTER_GAP), 0)
        if fb.SetBackdrop then
            fb:SetBackdrop({
                bgFile   = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 10,
                insets   = { left = 1, right = 1, top = 1, bottom = 1 },
            })
            fb:SetBackdropColor(0.06, 0.055, 0.05, 0.85)
            fb:SetBackdropBorderColor(0.40, 0.35, 0.22, 0.55)
        end
        local ico = fb:CreateTexture(nil, "ARTWORK")
        ico:SetPoint("CENTER")
        ico:SetSize(FILTER_H - 6, FILTER_H - 6)
        ico:SetTexture(RACE_ICONS[race])
        fb.icon = ico
        fb.filterKey = race
        fb.active = false
        fb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(self.filterKey)
            GameTooltip:Show()
        end)
        fb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        fb:SetScript("OnClick", function(self)
            if self.greyed then return end
            if self.active then
                deselectAllRace()
            else
                deselectAllRace()
                self.active = true
                raceFilters[self.filterKey] = true
                if self.SetBackdropBorderColor then
                    self:SetBackdropBorderColor(1.0, 0.82, 0.0, 0.95)
                end
            end
            Catalog.RefreshFilterStates()
            Catalog.RefreshBrowseIcons()
        end)
        classGridFrame.raceBtns[i] = fb
    end

    -- Race label to the right
    local raceLabel = raceRow:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    raceLabel:SetPoint("LEFT", raceRow, "RIGHT", 6, 0)
    raceLabel:SetText("Race")

    -- Class filter row (dynamic, shown after race selection)
    local CLASS_ORDER = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
    local classRowW = #CLASS_ORDER * (FILTER_H + FILTER_GAP) - FILTER_GAP
    local classRow = CreateFrame("Frame", nil, classGridFrame)
    classRow:SetSize(classRowW, FILTER_H)
    classRow:SetPoint("TOP", raceRow, "BOTTOM", 0, -(FILTER_GAP))
    classGridFrame.classRow = classRow
    classGridFrame.classBtns = {}

    deselectAllClass = function()
        for _, b in pairs(classGridFrame.classBtns) do
            b.active = false
            if b.SetBackdropBorderColor then
                b:SetBackdropBorderColor(0.40, 0.35, 0.22, 0.55)
            end
        end
        wipe(classFilters)
    end

    for i, cls in ipairs(CLASS_ORDER) do
        local fb = CreateFrame("Button", nil, classRow, "BackdropTemplate")
        fb:SetSize(FILTER_H, FILTER_H)
        fb:SetPoint("LEFT", classRow, "LEFT", (i - 1) * (FILTER_H + FILTER_GAP), 0)
        if fb.SetBackdrop then
            fb:SetBackdrop({
                bgFile   = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 10,
                insets   = { left = 1, right = 1, top = 1, bottom = 1 },
            })
            fb:SetBackdropColor(0.06, 0.055, 0.05, 0.85)
            fb:SetBackdropBorderColor(0.40, 0.35, 0.22, 0.55)
        end
        local ico = fb:CreateTexture(nil, "ARTWORK")
        ico:SetPoint("CENTER")
        ico:SetSize(FILTER_H - 6, FILTER_H - 6)
        ico:SetTexture(CLASS_ICONS[cls])
        fb.icon = ico
        fb.filterKey = cls
        fb.active = false
        fb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(titleCase(self.filterKey))
            GameTooltip:Show()
        end)
        fb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        fb:SetScript("OnClick", function(self)
            if self.greyed then return end
            if self.active then
                deselectAllClass()
            else
                deselectAllClass()
                self.active = true
                classFilters[self.filterKey] = true
                if self.SetBackdropBorderColor then
                    self:SetBackdropBorderColor(1.0, 0.82, 0.0, 0.95)
                end
            end
            Catalog.RefreshFilterStates()
            Catalog.RefreshBrowseIcons()
        end)
        classGridFrame.classBtns[i] = fb
    end

    -- Class label to the right
    local classLabel = classRow:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    classLabel:SetPoint("LEFT", classRow, "RIGHT", 6, 0)
    classLabel:SetText("Class")

    -- "Destiny" button -- random class picker
    local destinyBtn = CreateFrame("Button", nil, classGridFrame, "BackdropTemplate")
    local destinySize = FILTER_H * 1.5 + FILTER_GAP
    destinyBtn:SetSize(destinySize, destinySize)
    destinyBtn:SetPoint("TOPRIGHT", classGridFrame, "TOPRIGHT", -4, 0)
    if destinyBtn.SetBackdrop then
        destinyBtn:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets   = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        destinyBtn:SetBackdropColor(0.08, 0.06, 0.12, 0.9)
        destinyBtn:SetBackdropBorderColor(0.55, 0.45, 0.70, 0.8)
    end
    local destinyIcon = destinyBtn:CreateTexture(nil, "ARTWORK")
    destinyIcon:SetPoint("CENTER")
    destinyIcon:SetSize(destinySize - 10, destinySize - 10)
    destinyIcon:SetTexture(237284)
    destinyBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Let destiny choose your next class")
        GameTooltip:Show()
        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(0.85, 0.70, 1.0, 1.0)
        end
    end)
    destinyBtn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(0.55, 0.45, 0.70, 0.8)
        end
    end)
    destinyBtn:SetScript("OnClick", function()
        -- Collect all character keys
        local allKeys = {}
        if FCE.Characters then
            for key in pairs(FCE.Characters) do
                allKeys[#allKeys + 1] = key
            end
        end
        if #allKeys == 0 then return end
        local pick = allKeys[math.random(#allKeys)]
        cameFromUndecided = false
        Catalog.ShowScreen3(pick)
    end)
    classGridFrame.destinyBtn = destinyBtn

    -- Scrollable icon grid area
    local iconScroll = CreateFrame("ScrollFrame", "HCE_BrowseIconScroll", classGridFrame, "UIPanelScrollFrameTemplate")
    iconScroll:SetPoint("TOPLEFT", classGridFrame, "TOPLEFT", 0, -(FILTER_H * 2 + FILTER_GAP * 2 + 8))
    iconScroll:SetPoint("BOTTOMRIGHT", classGridFrame, "BOTTOMRIGHT", 20, 20)
    if FCE.Style then FCE.Style.StyleScrollbar(iconScroll) end

    local iconContent = CreateFrame("Frame", nil, iconScroll)
    iconContent:SetWidth(1)
    iconContent:SetHeight(1)
    iconScroll:SetScrollChild(iconContent)
    classGridFrame.iconScroll = iconScroll
    classGridFrame.iconContent = iconContent
    classGridFrame.iconCells = {}

    ----------------------------------------------------------------
    -- SCREEN 2: Build picker for a specific enhanced class name
    ----------------------------------------------------------------
    classListFrame = CreateFrame("Frame", nil, content)
    classListFrame:SetAllPoints()
    classListFrame:Hide()

    classListFrame.subtitle = classListFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    classListFrame.subtitle:SetPoint("TOP", classListFrame, "TOP", 0, -2)
    classListFrame.subtitle:SetTextColor(0.92, 0.87, 0.76)

    classListFrame.loreText = classListFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    classListFrame.loreText:SetPoint("TOPLEFT", classListFrame, "TOPLEFT", 50, -22)
    classListFrame.loreText:SetPoint("RIGHT", classListFrame, "RIGHT", -50, 0)
    classListFrame.loreText:SetJustifyH("LEFT")
    classListFrame.loreText:SetTextColor(0.75, 0.73, 0.68)
    classListFrame.loreText:SetWordWrap(true)
    classListFrame.loreText:SetText("")

    local buildArea = CreateFrame("Frame", nil, classListFrame)
    buildArea:SetPoint("TOPLEFT", classListFrame, "TOPLEFT", 0, -24)
    buildArea:SetPoint("BOTTOMRIGHT", classListFrame, "BOTTOMRIGHT", 0, 0)
    classListFrame.buildArea = buildArea
    classListFrame.buildCards = {}

    ----------------------------------------------------------------
    -- SCREEN 3: Character detail — pixel-perfect RequirementsPanel replica
    -- Art panel docked to the LEFT, info panel on the right, same row
    -- system (tag 50px + text), same colours, fonts, spacing.
    ----------------------------------------------------------------
    detailFrame = CreateFrame("Frame", nil, content)
    detailFrame:SetAllPoints()
    detailFrame:Hide()

    -- Art panel on the LEFT (same as RequirementsPanel)
    local artPanel = CreateFrame("Frame", nil, detailFrame, "BackdropTemplate")
    artPanel:SetWidth(DETAIL_WIDTH)
    artPanel:SetPoint("TOPLEFT", detailFrame, "TOPLEFT", 0, 0)
    artPanel:SetPoint("BOTTOMLEFT", detailFrame, "BOTTOMLEFT", 0, 36)
    if FCE.Style then
        FCE.Style.ApplyPanelBackdrop(artPanel)
        FCE.Style.AddInnerFill(artPanel)
    elseif artPanel.SetBackdrop then
        artPanel:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 16,
            insets   = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        artPanel:SetBackdropColor(0.040, 0.035, 0.030, 0.94)
        artPanel:SetBackdropBorderColor(0.72, 0.56, 0.30, 0.72)
    end
    local artTex = artPanel:CreateTexture(nil, "ARTWORK")
    artTex:SetPoint("TOPLEFT", artPanel, "TOPLEFT", 6, -6)
    artTex:SetPoint("BOTTOMRIGHT", artPanel, "BOTTOMRIGHT", -6, 6)
    artTex:SetTexCoord(0, 1, 0, 1)
    detailFrame.artPanel = artPanel
    detailFrame.artTex = artTex

    -- Right side: scrolling info panel (mirrors RequirementsPanel scroll)
    local infoScroll = CreateFrame("ScrollFrame", "HCE_CatalogDetailScroll", detailFrame, "UIPanelScrollFrameTemplate")
    infoScroll:SetPoint("TOPLEFT", artPanel, "TOPRIGHT", 8, 8)
    infoScroll:SetPoint("BOTTOMRIGHT", detailFrame, "BOTTOMRIGHT", 20, 36)
    if FCE.Style then FCE.Style.StyleScrollbar(infoScroll) end

    local infoContent = CreateFrame("Frame", nil, infoScroll)
    infoContent:SetWidth(1)
    infoContent:SetHeight(1)
    infoScroll:SetScrollChild(infoContent)
    detailFrame.infoScroll = infoScroll
    detailFrame.infoContent = infoContent

    -- Row pool (frames with .tag + .text, identical to RequirementsPanel)
    detailFrame.rowPool = {}

    -- Select button (bottom-right)
    local selectBtn
    if FCE.Style then
        selectBtn = FCE.Style.CreateButton(detailFrame, 240, 26, "Select This Class")
    else
        selectBtn = CreateFrame("Button", nil, detailFrame, "UIPanelButtonTemplate")
        selectBtn:SetText("Select This Class")
    end
    selectBtn:SetSize(240, 28)
    selectBtn:SetPoint("BOTTOM", detailFrame, "BOTTOM", 0, 6)
    selectBtn:SetScript("OnClick", function()
        if not selectedCharKey then return end
        Catalog.ProceedFromDetail()
    end)
    detailFrame.selectBtn = selectBtn

    -- Screen 3.5: Self-found picker (hardcore realms only)
    selfFoundFrame = CreateFrame("Frame", nil, content)
    selfFoundFrame:SetAllPoints()
    selfFoundFrame:Hide()

    selfFoundFrame.titleText = selfFoundFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    selfFoundFrame.titleText:SetPoint("TOP", selfFoundFrame, "TOP", 0, -4)
    selfFoundFrame.titleText:SetJustifyH("CENTER")

    selfFoundFrame.subtitleText = selfFoundFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    selfFoundFrame.subtitleText:SetPoint("TOP", selfFoundFrame.titleText, "BOTTOM", 0, -6)
    selfFoundFrame.subtitleText:SetJustifyH("CENTER")
    selfFoundFrame.subtitleText:SetWidth(500)
    selfFoundFrame.subtitleText:SetWordWrap(true)
    selfFoundFrame.subtitleText:SetTextColor(0.92, 0.87, 0.76)

    selfFoundFrame.rows = {}

    -- Screen 4: Optional challenge picker
    challengeFrame = CreateFrame("Frame", nil, frame)
    challengeFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -40)
    challengeFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 18, 12)
    challengeFrame:Hide()

    challengeFrame.titleText = challengeFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    challengeFrame.titleText:SetPoint("TOP", challengeFrame, "TOP", 0, -4)
    challengeFrame.titleText:SetJustifyH("CENTER")

    challengeFrame.subtitleText = challengeFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    challengeFrame.subtitleText:SetPoint("TOP", challengeFrame.titleText, "BOTTOM", 0, -4)
    challengeFrame.subtitleText:SetJustifyH("CENTER")
    challengeFrame.subtitleText:SetTextColor(0.92, 0.87, 0.76)

    -- Scroll frame for challenge options
    local chScroll = CreateFrame("ScrollFrame", "HCE_CatalogChallengeScroll", challengeFrame, "UIPanelScrollFrameTemplate")
    chScroll:SetPoint("TOPLEFT", challengeFrame, "TOPLEFT", 0, -50)
    chScroll:SetPoint("BOTTOMRIGHT", challengeFrame, "BOTTOMRIGHT", -6, 4)
    if FCE.Style then FCE.Style.StyleScrollbar(chScroll) end
    local chContent = CreateFrame("Frame", nil, chScroll)
    chContent:SetWidth(FRAME_WIDTH - 40)
    chContent:SetHeight(1)
    chScroll:SetScrollChild(chContent)
    challengeFrame.scroll = chScroll
    challengeFrame.content = chContent
    challengeFrame.rows = {}

    ----------------------------------------------------------------
    -- SCREEN 2u: Undecided panel — path picker for the player
    ----------------------------------------------------------------
    undecidedFrame = CreateFrame("Frame", nil, content)
    undecidedFrame:SetAllPoints()
    undecidedFrame:Hide()

    -- "< See all enhanced classes" button (top-left corner)
    local seeAllBtn
    if FCE.Style then
        seeAllBtn = FCE.Style.CreateButton(undecidedFrame, 200, 4, "< See all enhanced classes")
    else
        seeAllBtn = CreateFrame("Button", nil, undecidedFrame, "UIPanelButtonTemplate")
        seeAllBtn:SetText("< See all enhanced classes")
    end
    seeAllBtn:SetSize(200, 22)
    seeAllBtn:SetPoint("TOPLEFT", undecidedFrame, "TOPLEFT", 0, 28)

    undecidedFrame.subtitle = undecidedFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    undecidedFrame.subtitle:SetPoint("TOP", frame.backBtn, "TOP", 8, 0)
    undecidedFrame.subtitle:SetPoint("LEFT", frame, "LEFT", 0, 0)
    undecidedFrame.subtitle:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
    undecidedFrame.subtitle:SetJustifyH("CENTER")
    undecidedFrame.subtitle:SetTextColor(0.92, 0.87, 0.76)
    seeAllBtn:SetScript("OnClick", function()
        Catalog.ShowScreen1()
    end)
    undecidedFrame.seeAllBtn = seeAllBtn

    -- Container for the path cards (populated dynamically)
    local cardArea = CreateFrame("Frame", nil, undecidedFrame)
    cardArea:SetPoint("TOPLEFT", undecidedFrame, "TOPLEFT", 0, -4)
    cardArea:SetPoint("BOTTOMRIGHT", undecidedFrame, "BOTTOMRIGHT", 0, 0)
    undecidedFrame.cardArea = cardArea
    undecidedFrame.cards = {}

    frame:SetScript("OnShow", function() end)
    frame:SetScript("OnHide", function() end)
end

----------------------------------------------------------------------
-- Screen 1: Browse all enhanced classes (icon grid + filters)
----------------------------------------------------------------------
function Catalog.ShowScreen1()
    BuildFrame()
    frame:SetWidth(FRAME_WIDTH)
    frame:SetHeight(FRAME_HEIGHT)
    currentScreen = 1
    selectedRace = nil
    selectedEnhancedName = nil
    selectedCharKey = nil
    selectedOptChallenges = {}
    selectedSelfFound = nil

    frame.titleText:SetText("|cffffd100Browse All Enhanced Classes|r")
    frame.backBtn:Hide()

    classGridFrame:Show()
    classListFrame:Hide()
    undecidedFrame:Hide()
    detailFrame:Hide()
    selfFoundFrame:Hide()
    challengeFrame:Hide()

    -- Reset filters
    wipe(raceFilters)
    wipe(classFilters)
    if classGridFrame.raceBtns then
        for _, btn in pairs(classGridFrame.raceBtns) do
            btn.active = false
            btn.greyed = false
            btn.icon:SetDesaturated(false)
            btn.icon:SetAlpha(1)
            if btn.SetBackdropBorderColor then
                btn:SetBackdropBorderColor(0.40, 0.35, 0.22, 0.55)
            end
        end
    end
    if classGridFrame.classBtns then
        for _, btn in pairs(classGridFrame.classBtns) do
            btn.active = false
            btn.greyed = false
            btn.icon:SetDesaturated(false)
            btn.icon:SetAlpha(1)
            if btn.SetBackdropBorderColor then
                btn:SetBackdropBorderColor(0.40, 0.35, 0.22, 0.55)
            end
        end
    end
    if classGridFrame.classRow then
        classGridFrame.classRow:Show()
    end

    Catalog.RefreshBrowseIcons()
end

--- Return to Screen 1 without resetting filters (used by back button from Screen 2).
function Catalog.ReturnToScreen1()
    BuildFrame()
    frame:SetWidth(FRAME_WIDTH)
    frame:SetHeight(FRAME_HEIGHT)
    currentScreen = 1
    selectedEnhancedName = nil
    selectedCharKey = nil
    selectedOptChallenges = {}
    selectedSelfFound = nil

    frame.titleText:SetText("|cffffd100Browse All Enhanced Classes|r")
    frame.backBtn:Hide()

    classGridFrame:Show()
    classListFrame:Hide()
    undecidedFrame:Hide()
    detailFrame:Hide()
    selfFoundFrame:Hide()
    challengeFrame:Hide()

    -- Filters and filter button states are preserved — just refresh the grid
    Catalog.RefreshBrowseIcons()
end

----------------------------------------------------------------------
-- Screen 2u: Undecided panel — choose your path
----------------------------------------------------------------------

-- Undecided card: same portrait panel style as RequirementsPanel / Screen 3 art
local UD_CARD_W   = 220   -- fits 3 cards in 710px frame; same panel style as RequirementsPanel
local BUILD_CARD_W = 300  -- wider card for Screen 2 build picker (art stays UD_CARD_W)
local UD_CARD_ART_H = 300 -- tall portrait ratio matching RequirementsPanel proportions
local UD_CARD_GAP = 12

local function acquireUndecidedCard(index, parent)
    local cards = undecidedFrame.cards
    if cards[index] then return cards[index] end

    -- Outer wrapper (holds art panel + text + button vertically)
    local card = CreateFrame("Button", nil, parent)
    card:SetWidth(UD_CARD_W)
    card:SetHeight(UD_CARD_ART_H + 160)  -- art + text area; adjusted dynamically

    -- Art panel frame (same bordered style as RequirementsPanel)
    local artPanel = CreateFrame("Frame", nil, card, "BackdropTemplate")
    artPanel:SetWidth(UD_CARD_W)
    artPanel:SetHeight(UD_CARD_ART_H)
    artPanel:SetPoint("TOPLEFT", card, "TOPLEFT", 0, 0)
    if FCE.Style then
        FCE.Style.ApplyPanelBackdrop(artPanel)
        FCE.Style.AddInnerFill(artPanel)
    elseif artPanel.SetBackdrop then
        artPanel:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 16,
            insets   = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        artPanel:SetBackdropColor(0.040, 0.035, 0.030, 0.94)
        artPanel:SetBackdropBorderColor(0.72, 0.56, 0.30, 0.72)
    end
    card.artPanel = artPanel

    -- Art texture: full uncropped, inset 6px (same as RequirementsPanel)
    local art = artPanel:CreateTexture(nil, "ARTWORK")
    art:SetPoint("TOPLEFT", artPanel, "TOPLEFT", 6, -6)
    art:SetPoint("BOTTOMRIGHT", artPanel, "BOTTOMRIGHT", -6, 6)
    art:SetTexCoord(0, 1, 0, 1)
    card.artTex = art

    -- Name (below art panel)
    local name = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    name:SetPoint("TOPLEFT", artPanel, "BOTTOMLEFT", 6, -6)
    name:SetPoint("RIGHT", card, "RIGHT", -6, 0)
    name:SetJustifyH("LEFT")
    card.nameText = name

    -- Spec line
    local spec = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    spec:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2)
    spec:SetPoint("RIGHT", card, "RIGHT", -6, 0)
    spec:SetJustifyH("LEFT")
    card.specText = spec

    -- Roles line
    local roles = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    roles:SetPoint("TOPLEFT", spec, "BOTTOMLEFT", 0, -1)
    roles:SetPoint("RIGHT", card, "RIGHT", -6, 0)
    roles:SetJustifyH("LEFT")
    card.rolesText = roles

    -- Warning line (gender / self-found mismatch) — hidden by default
    local warn = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    warn:SetPoint("TOPLEFT", roles, "BOTTOMLEFT", 0, -3)
    warn:SetPoint("RIGHT", card, "RIGHT", -6, 0)
    warn:SetJustifyH("LEFT")
    warn:SetTextColor(0.80, 0.20, 0.20)
    warn:SetText("")
    card.warnText = warn

    -- Info area for challenges / equipment / quests (multi-line)
    local info = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", warn, "BOTTOMLEFT", 0, -6)
    info:SetPoint("RIGHT", card, "RIGHT", -6, 0)
    info:SetJustifyH("LEFT")
    info:SetWordWrap(true)
    info:SetTextColor(0.82, 0.80, 0.72)
    card.infoText = info

    -- Hover: brighten art panel border
    card:SetScript("OnEnter", function(self)
        if self.artPanel and self.artPanel.SetBackdropBorderColor then
            self.artPanel:SetBackdropBorderColor(1.0, 0.82, 0.0, 0.90)
        end
    end)
    card:SetScript("OnLeave", function(self)
        if self.artPanel and self.artPanel.SetBackdropBorderColor then
            self.artPanel:SetBackdropBorderColor(0.72, 0.56, 0.30, 0.72)
        end
    end)

    cards[index] = card
    return card
end

function Catalog.ShowUndecidedPanel()
    BuildFrame()
    currentScreen = 20
    cameFromUndecided = true
    selectedCharKey = nil
    selectedOptChallenges = {}
    selectedSelfFound = nil

    frame.titleText:SetText("|cffffd100Choose Your Path|r")
    frame.backBtn:Hide()

    classGridFrame:Hide()
    classListFrame:Hide()
    undecidedFrame:Show()
    detailFrame:Hide()
    selfFoundFrame:Hide()
    challengeFrame:Hide()

    -- Get ALL enhanced classes for this race/class (gender NOT filtered)
    local matches = FCE.FindMatchingCharactersNoGender and FCE.FindMatchingCharactersNoGender() or {}

    -- Sort by name for consistent ordering
    table.sort(matches, function(a, b) return a.name < b.name end)

    local numCards = #matches
    if numCards == 0 then
        undecidedFrame.subtitle:SetText("No enhanced classes found for your race/class.")
        for _, c in pairs(undecidedFrame.cards) do c:Hide() end
        return
    end

    -- Detect player gender
    local playerSex = UnitSex and UnitSex("player") or 2
    local playerGender = (playerSex == 3) and "Female" or "Male"

    -- Detect player self-found buff status
    local playerHasSelfFound = false
    if FCE.SelfFoundCheck then
        -- Reuse the buff scanner from SelfFoundCheck module
        local sfStatus = FCE.SelfFoundCheck.GetResults and FCE.SelfFoundCheck.GetResults()
        if sfStatus and sfStatus.buffStatus == "pass" then
            playerHasSelfFound = true
        else
            -- Try running the check directly if results aren't cached
            -- Scan auras inline (lightweight)
            if UnitBuff then
                for idx = 1, 40 do
                    local name = UnitBuff("player", idx)
                    if not name then break end
                    local lower = name:lower()
                    if lower:find("self") and lower:find("found") then
                        playerHasSelfFound = true
                        break
                    end
                end
            end
        end
    elseif UnitBuff then
        -- No SelfFoundCheck module; scan auras directly
        for idx = 1, 40 do
            local name = UnitBuff("player", idx)
            if not name then break end
            local lower = name:lower()
            if lower:find("self") and lower:find("found") then
                playerHasSelfFound = true
                break
            end
        end
    end

    -- Build subtitle: "Night Elf Priest — 3 paths available"
    local classDisplay, playerClass
    if UnitClass then
        classDisplay, playerClass = UnitClass("player")
    end
    local playerRace = UnitRace and UnitRace("player") or "Unknown"
    classDisplay = classDisplay or ""
    local classColor = cc(playerClass)
    local raceColor = RACE_COLORS[playerRace] or "ffd100"
    undecidedFrame.subtitle:SetText(
        "|cff" .. raceColor .. playerRace .. "|r " ..
        "|cff" .. classColor .. classDisplay .. "|r — " ..
        numCards .. " path" .. (numCards == 1 and "" or "s") .. " available"
    )

    -- Widen the frame if needed to fit all cards, restore default otherwise
    local totalW = numCards * UD_CARD_W + (numCards - 1) * UD_CARD_GAP
    local neededW = totalW + 30  -- 15px padding each side
    local frameW = (neededW > FRAME_WIDTH) and neededW or FRAME_WIDTH
    frame:SetWidth(frameW)

    -- Center the cards horizontally in the card area
    local areaW = frameW - 20
    local startX = (areaW - totalW) / 2

    -- Hide extra cards from previous render
    for i = numCards + 1, #undecidedFrame.cards do
        undecidedFrame.cards[i]:Hide()
    end

    -- Dark red colour for requirement mismatches
    local WARN_RED = "cc3333"

    for i, char in ipairs(matches) do
        local card = acquireUndecidedCard(i, undecidedFrame.cardArea)
        card:ClearAllPoints()
        local xPos = startX + (i - 1) * (UD_CARD_W + UD_CARD_GAP)
        card:SetPoint("TOPLEFT", undecidedFrame.cardArea, "TOPLEFT", xPos, 0)

        -- Art portrait (per-build icon first, then fallback)
        local portrait = FCE.GetCharPortrait and FCE.GetCharPortrait(char)
        local bgPath = portrait or (FCE.ClassBackgrounds and FCE.ClassBackgrounds[char.name])
        if bgPath then
            card.artTex:SetTexture(bgPath)
        elseif CLASS_ICONS[char.class] then
            card.artTex:SetTexture(CLASS_ICONS[char.class])
        end

        -- Name (coloured by class, left-aligned like catalog)
        local color = cc(char.class)
        local displayName = FCE.GetCharDisplayName and FCE.GetCharDisplayName(char) or char.name
        card.nameText:SetText("|cff" .. color .. displayName .. "|r")

        -- Spec line
        card.specText:SetText(char.spec and (char.spec .. " spec") or "")

        -- Role(s) line
        local reqs = FCE.TalentRequirements and FCE.TalentRequirements[char.class .. "_" .. (char.spec or "")]
        local rolesStr = reqs and reqs.roles or nil
        card.rolesText:SetText(rolesStr and ("Role(s): " .. rolesStr) or "")

        -- Warning line: gender or self-found mismatch
        local warnings = {}
        if char.gender and char.gender ~= "Any gender" and char.gender ~= playerGender then
            warnings[#warnings + 1] = "This build requires " .. char.gender
        end
        if char.selfFound == false and playerHasSelfFound then
            warnings[#warnings + 1] = "This build requires AH access"
        end
        local warnStr = table.concat(warnings, "\n")
        card.warnText:SetText(warnStr ~= "" and ("|cff" .. WARN_RED .. warnStr .. "|r") or "")

        -- Info: build-specific lore if available, otherwise class-level lore
        local loreText = FCE.LoreData and (FCE.LoreData[char.key] or FCE.LoreData[char.name]) or ""
        card.infoText:SetText(loreText)

        -- Auto-resize card height based on content
        local warnH = (warnStr ~= "") and (card.warnText:GetStringHeight() or 0) or 0
        local infoH = card.infoText:GetStringHeight() or 0
        local totalH = UD_CARD_ART_H + 6 + (card.nameText:GetStringHeight() or 14)
                      + 2 + (card.specText:GetStringHeight() or 12)
                      + 1 + (card.rolesText:GetStringHeight() or 12)
                      + 3 + warnH
                      + 6 + infoH + 10
        card:SetHeight(totalH)

        -- Click card → Screen 3
        card.charKey = char.key
        card:SetScript("OnClick", function(self)
            cameFromUndecided = true
            Catalog.ShowScreen3(self.charKey)
        end)

        card:Show()
    end

    -- Auto-resize frame height to fit tallest card + header space
    local maxCardH = 0
    for i = 1, numCards do
        local c = undecidedFrame.cards[i]
        if c and c:IsShown() then
            local h = c:GetHeight()
            if h > maxCardH then maxCardH = h end
        end
    end
    -- Set all visible cards to tallest height so buttons align at bottom
    for i = 1, numCards do
        local c = undecidedFrame.cards[i]
        if c and c:IsShown() then
            c:SetHeight(maxCardH)
        end
    end
    local neededH = maxCardH + 80  -- 80px for subtitle + back button + padding
    if neededH < FRAME_HEIGHT then neededH = FRAME_HEIGHT end
    frame:SetHeight(neededH)
end

----------------------------------------------------------------------
-- Screen 2: Enhanced class list for a WoW class (browsing catalog)
----------------------------------------------------------------------

----------------------------------------------------------------------
-- Browse icon cell factory (circular portrait + name label)
----------------------------------------------------------------------

local function acquireIconCell(index, parent)
    local cells = classGridFrame.iconCells
    if cells[index] then return cells[index] end

    local cell = CreateFrame("Button", nil, parent)
    cell:SetSize(ICON_SIZE + 8, ICON_CELL)

    -- Portrait (sphere icons already have circular alpha baked in)
    local art = cell:CreateTexture(nil, "ARTWORK")
    art:SetSize(ICON_SIZE, ICON_SIZE)
    art:SetPoint("TOP", cell, "TOP", 0, 0)
    cell.artTex = art


    -- Name label below
    local name = cell:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    name:SetPoint("TOP", art, "BOTTOM", 0, -3)
    name:SetWidth(ICON_SIZE + 36)
    name:SetJustifyH("CENTER")
    name:SetWordWrap(true)
    cell.nameText = name

    -- Hover highlight
    cell:SetScript("OnEnter", function(self)
        self.artTex:SetAlpha(1.0)
        if self.nameText then
            self.nameText:SetTextColor(1, 0.82, 0)
        end
    end)
    cell:SetScript("OnLeave", function(self)
        self.artTex:SetAlpha(0.85)
        if self.nameText then
            self.nameText:SetTextColor(0.93, 0.93, 0.93)
        end
    end)

    cell.artTex:SetAlpha(0.85)
    cells[index] = cell
    return cell
end

----------------------------------------------------------------------
-- Build card factory for Screen 2 (reuses undecided-panel style)
----------------------------------------------------------------------

local function acquireBuildCard(index, parent)
    local cards = classListFrame.buildCards
    if cards[index] then return cards[index] end

    local card = CreateFrame("Button", nil, parent)
    card:SetWidth(BUILD_CARD_W)
    card:SetHeight(UD_CARD_ART_H + 160)

    local artPanel = CreateFrame("Frame", nil, card, "BackdropTemplate")
    artPanel:SetWidth(UD_CARD_W)
    artPanel:SetHeight(UD_CARD_ART_H)
    artPanel:SetPoint("TOP", card, "TOP", 0, 0)
    if FCE.Style then
        FCE.Style.ApplyPanelBackdrop(artPanel)
        FCE.Style.AddInnerFill(artPanel)
    elseif artPanel.SetBackdrop then
        artPanel:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 16,
            insets   = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        artPanel:SetBackdropColor(0.040, 0.035, 0.030, 0.94)
        artPanel:SetBackdropBorderColor(0.72, 0.56, 0.30, 0.72)
    end
    card.artPanel = artPanel

    local art = artPanel:CreateTexture(nil, "ARTWORK")
    art:SetPoint("TOPLEFT", artPanel, "TOPLEFT", 6, -6)
    art:SetPoint("BOTTOMRIGHT", artPanel, "BOTTOMRIGHT", -6, 6)
    art:SetTexCoord(0, 1, 0, 1)
    card.artTex = art

    local name = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    name:SetPoint("TOP", artPanel, "BOTTOM", 0, -6)
    name:SetPoint("LEFT", card, "LEFT", 6, 0)
    name:SetPoint("RIGHT", card, "RIGHT", -6, 0)
    name:SetJustifyH("CENTER")
    card.nameText = name

    local spec = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    spec:SetPoint("TOP", name, "BOTTOM", 0, -2)
    spec:SetPoint("LEFT", card, "LEFT", 6, 0)
    spec:SetPoint("RIGHT", card, "RIGHT", -6, 0)
    spec:SetJustifyH("CENTER")
    card.specText = spec

    local roles = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    roles:SetPoint("TOP", spec, "BOTTOM", 0, -1)
    roles:SetPoint("LEFT", card, "LEFT", 6, 0)
    roles:SetPoint("RIGHT", card, "RIGHT", -6, 0)
    roles:SetJustifyH("CENTER")
    card.rolesText = roles

    local info = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    info:SetPoint("TOP", roles, "BOTTOM", 0, -6)
    info:SetPoint("LEFT", card, "LEFT", 6, 0)
    info:SetPoint("RIGHT", card, "RIGHT", -6, 0)
    info:SetJustifyH("CENTER")
    info:SetWordWrap(true)
    info:SetTextColor(0.82, 0.80, 0.72)
    card.infoText = info

    card:SetScript("OnEnter", function(self)
        if self.artPanel and self.artPanel.SetBackdropBorderColor then
            self.artPanel:SetBackdropBorderColor(1.0, 0.82, 0.0, 0.90)
        end
    end)
    card:SetScript("OnLeave", function(self)
        if self.artPanel and self.artPanel.SetBackdropBorderColor then
            self.artPanel:SetBackdropBorderColor(0.72, 0.56, 0.30, 0.72)
        end
    end)

    cards[index] = card
    return card
end

----------------------------------------------------------------------
-- Browse helpers: group characters by display name
----------------------------------------------------------------------

--- Returns a sorted list of { name, art, builds={char,...} } tables,
--- one per unique enhanced class display name, filtered by current
--- raceFilters / classFilters.
local function getFilteredEnhancedClasses()
    local byName = {}  -- name → { name, art, builds }
    local order  = {}  -- insertion order for stable sort
    for _, char in pairs(FCE.Characters or {}) do
        local dName = FCE.GetCharDisplayName and FCE.GetCharDisplayName(char) or char.name

        -- Apply filters
        local raceOK = true
        if next(raceFilters) then
            raceOK = false
            if char.raceSet then
                if char.raceSet["Any race"] then
                    raceOK = true
                else
                    for r in pairs(raceFilters) do
                        if char.raceSet[r] then raceOK = true; break end
                    end
                end
            end
        end
        local classOK = true
        if next(classFilters) then
            classOK = classFilters[char.class] or false
        end

        if raceOK and classOK then
            if not byName[dName] then
                byName[dName] = { name = dName, builds = {} }
                table.insert(order, dName)
            end
            table.insert(byName[dName].builds, char)
        end
    end
    table.sort(order)
    local result = {}
    for _, n in ipairs(order) do
        table.insert(result, byName[n])
    end
    return result
end

--- Returns all builds (characters) sharing a display name, unfiltered.
local function getBuildsForName(enhancedName)
    local builds = {}
    for _, char in pairs(FCE.Characters or {}) do
        local dName = FCE.GetCharDisplayName and FCE.GetCharDisplayName(char) or char.name
        if dName == enhancedName then
            table.insert(builds, char)
        end
    end
    table.sort(builds, function(a, b)
        if a.class ~= b.class then return a.class < b.class end
        return (a.spec or "") < (b.spec or "")
    end)
    return builds
end

----------------------------------------------------------------------
-- Screen 1: Show class buttons valid for a given race
----------------------------------------------------------------------

----------------------------------------------------------------------
-- Screen 1: Grey out incompatible race/class filter buttons
----------------------------------------------------------------------
-- When a race is selected, class buttons with no enhanced classes for
-- that race are greyed out (desaturated + dimmed).  When a class is
-- selected, race buttons that can't play that class are greyed out.
-- If a button is currently selected (active) but becomes incompatible
-- due to the OTHER filter, it is auto-deselected.

function Catalog.RefreshFilterStates()
    if not classGridFrame then return end

    -- Determine current single selections (radio = at most one each)
    local selRace  = nil
    for r in pairs(raceFilters) do selRace = r; break end
    local selClass = nil
    for c in pairs(classFilters) do selClass = c; break end

    -- Build lookups from actual enhanced-class data:
    --   raceHasClass[race][class] = true  (an enhanced class of `class` exists for `race`)
    --   classHasRace[class][race] = true  (reverse)
    local raceHasClass = {}
    local classHasRace = {}
    for _, char in pairs(FCE.Characters or {}) do
        if not classHasRace[char.class] then classHasRace[char.class] = {} end
        if char.raceSet then
            if char.raceSet["Any race"] then
                for _, race in ipairs(RACE_ORDER) do
                    if RACE_CLASSES[race] and RACE_CLASSES[race][char.class] then
                        if not raceHasClass[race] then raceHasClass[race] = {} end
                        raceHasClass[race][char.class] = true
                        classHasRace[char.class][race] = true
                    end
                end
            else
                for race in pairs(char.raceSet) do
                    if not raceHasClass[race] then raceHasClass[race] = {} end
                    raceHasClass[race][char.class] = true
                    classHasRace[char.class][race] = true
                end
            end
        end
    end

    -- Grey / un-grey class buttons based on selected race
    for _, btn in ipairs(classGridFrame.classBtns) do
        local cls = btn.filterKey
        local shouldGrey = false
        if selRace then
            local rc = raceHasClass[selRace]
            if not rc or not rc[cls] then shouldGrey = true end
        end
        if shouldGrey then
            -- Auto-deselect if this class is now incompatible
            if btn.active then
                btn.active = false
                classFilters[cls] = nil
                selClass = nil  -- update local so race greying below is correct
            end
            btn.greyed = true
            btn.icon:SetDesaturated(true)
            btn.icon:SetAlpha(0.35)
            if btn.SetBackdropBorderColor then
                btn:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.35)
            end
        else
            btn.greyed = false
            btn.icon:SetDesaturated(false)
            btn.icon:SetAlpha(1)
            if not btn.active and btn.SetBackdropBorderColor then
                btn:SetBackdropBorderColor(0.40, 0.35, 0.22, 0.55)
            end
        end
    end

    -- Grey / un-grey race buttons based on selected class
    for _, btn in ipairs(classGridFrame.raceBtns) do
        local race = btn.filterKey
        local shouldGrey = false
        if selClass then
            local cr = classHasRace[selClass]
            if not cr or not cr[race] then shouldGrey = true end
        end
        if shouldGrey then
            if btn.active then
                btn.active = false
                raceFilters[race] = nil
            end
            btn.greyed = true
            btn.icon:SetDesaturated(true)
            btn.icon:SetAlpha(0.35)
            if btn.SetBackdropBorderColor then
                btn:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.35)
            end
        else
            btn.greyed = false
            btn.icon:SetDesaturated(false)
            btn.icon:SetAlpha(1)
            if not btn.active and btn.SetBackdropBorderColor then
                btn:SetBackdropBorderColor(0.40, 0.35, 0.22, 0.55)
            end
        end
    end
end

function Catalog.RefreshClassRow(raceName)
    if not classGridFrame or not classGridFrame.classBtns then return end
    -- Find which base classes have enhanced classes for this race
    local validClasses = {}
    for _, char in pairs(FCE.Characters or {}) do
        if char.raceSet and (char.raceSet[raceName] or char.raceSet["Any race"]) then
            validClasses[char.class] = true
        end
    end
    -- Show/hide each class button based on validity
    local visCount = 0
    for _, btn in ipairs(classGridFrame.classBtns) do
        if validClasses[btn.filterKey] then
            btn:Show()
            btn:ClearAllPoints()
            btn:SetPoint("LEFT", classGridFrame.classRow, "LEFT", visCount * (FILTER_H + FILTER_GAP), 0)
            visCount = visCount + 1
        else
            btn:Hide()
        end
    end
    -- Resize and show class row
    local rowW = visCount * (FILTER_H + FILTER_GAP) - FILTER_GAP
    if rowW < 1 then rowW = 1 end
    classGridFrame.classRow:SetWidth(rowW)
    classGridFrame.classRow:Show()
end

----------------------------------------------------------------------
-- Screen 1: Refresh the icon grid (called after filter toggles)
----------------------------------------------------------------------

function Catalog.RefreshBrowseIcons()
    local entries = getFilteredEnhancedClasses()
    local parent = classGridFrame.iconContent

    -- Hide old cells
    for _, c in pairs(classGridFrame.iconCells) do c:Hide() end

    local scrollW = classGridFrame.iconScroll:GetWidth()
    if scrollW < 100 then scrollW = frame:GetWidth() - 60 end
    local cellW = ICON_SIZE + 38  -- wider cells so names don't overlap
    local cols = math.max(1, math.floor(scrollW / cellW))
    local gridW = cols * cellW
    local offsetX = math.floor((scrollW - gridW) / 2)
    if offsetX < 0 then offsetX = 0 end

    for i, entry in ipairs(entries) do
        local cell = acquireIconCell(i, parent)
        cell:ClearAllPoints()
        local col = (i - 1) % cols
        local rowIdx = math.floor((i - 1) / cols)
        local xPos = offsetX + col * cellW
        local yPos = rowIdx * (ICON_CELL + ICON_GAP)
        cell:SetPoint("TOPLEFT", parent, "TOPLEFT", xPos, -yPos)

        -- Art — prefer BROWSE_ICONS (WoW texture IDs), fall back to file icons
        local firstBuild = entry.builds[1]
        local browseIcon = FCE.BROWSE_ICONS[entry.name]
        if browseIcon then
            cell.artTex:SetTexture(browseIcon)
        else
            local bgPath = FCE.ClassBackgrounds and FCE.ClassBackgrounds[entry.name]
            if bgPath then
                local iconPath = bgPath:gsub("Backgrounds", "Icons")
                cell.artTex:SetTexture(iconPath)
            elseif firstBuild then
                local sphereKey = CLASS_SPHERE[entry.name]
                if sphereKey and SPHERE_ICONS[sphereKey] then
                    cell.artTex:SetTexture(SPHERE_ICONS[sphereKey])
                elseif CLASS_ICONS[firstBuild.class] then
                    cell.artTex:SetTexture(CLASS_ICONS[firstBuild.class])
                end
            end
        end

        -- Name label — colour by sphere affinity
        local sphereKey = CLASS_SPHERE[entry.name]
        local color = (sphereKey and SPHERE_COLORS[sphereKey]) or "ffd100"
        cell.nameText:SetText("|cff" .. color .. entry.name .. "|r")

        -- Click → show build picker (Screen 2)
        cell.enhancedName = entry.name
        cell:SetScript("OnClick", function(self)
            Catalog.ShowScreen2(self.enhancedName)
        end)

        cell:Show()
    end

    -- Set content height for scroll
    local totalRows = math.ceil(#entries / math.max(1, cols))
    parent:SetHeight(totalRows * (ICON_CELL + ICON_GAP) + 20)
    parent:SetWidth(scrollW)
end

----------------------------------------------------------------------
-- Screen 2: Build picker for a specific enhanced class name
----------------------------------------------------------------------

function Catalog.ShowScreen2(enhancedName)
    BuildFrame()
    frame:SetWidth(FRAME_WIDTH)
    currentScreen = 2
    cameFromUndecided = false
    selectedEnhancedName = enhancedName
    selectedCharKey = nil
    selectedOptChallenges = {}
    selectedSelfFound = nil

    frame.titleText:SetText("|cffffd100" .. enhancedName .. " - Builds|r")
    frame.backBtn:Show()

    classGridFrame:Hide()
    classListFrame:Show()
    undecidedFrame:Hide()
    detailFrame:Hide()
    selfFoundFrame:Hide()
    challengeFrame:Hide()

    local builds = getBuildsForName(enhancedName)
    local numCards = #builds

    if numCards == 0 then
        classListFrame.subtitle:SetText("No builds found.")
        for _, c in pairs(classListFrame.buildCards) do c:Hide() end
        return
    end

    classListFrame.subtitle:SetText(
        enhancedName .. " — " .. numCards .. " build" .. (numCards == 1 and "" or "s") .. " available"
    )

    -- Lore text above cards
    local loreText = FCE.LoreData and FCE.LoreData[enhancedName] or ""
    classListFrame.loreText:SetText(loreText)
    local loreH = 0
    if loreText ~= "" then
        classListFrame.loreText:Show()
        loreH = classListFrame.loreText:GetStringHeight() + 10
    else
        classListFrame.loreText:Hide()
    end

    -- Offset build area below subtitle + lore
    classListFrame.buildArea:SetPoint("TOPLEFT", classListFrame, "TOPLEFT", 0, -(24 + loreH))

    -- Widen frame if needed
    local totalW = numCards * BUILD_CARD_W + (numCards - 1) * UD_CARD_GAP
    local neededW = totalW + 30
    local frameW = (neededW > FRAME_WIDTH) and neededW or FRAME_WIDTH
    frame:SetWidth(frameW)

    local areaW = frameW - 20
    local startX = (areaW - totalW) / 2

    -- Hide extra
    for i = numCards + 1, #classListFrame.buildCards do
        classListFrame.buildCards[i]:Hide()
    end

    for i, char in ipairs(builds) do
        local card = acquireBuildCard(i, classListFrame.buildArea)
        card:ClearAllPoints()
        local xPos = startX + (i - 1) * (BUILD_CARD_W + UD_CARD_GAP)
        card:SetPoint("TOPLEFT", classListFrame.buildArea, "TOPLEFT", xPos, 0)

        -- Art (per-build icon first, then fallback)
        local portrait = FCE.GetCharPortrait and FCE.GetCharPortrait(char)
        local bgPath = portrait or (FCE.ClassBackgrounds and FCE.ClassBackgrounds[char.name])
        if bgPath then
            card.artTex:SetTexture(bgPath)
        elseif CLASS_ICONS[char.class] then
            card.artTex:SetTexture(CLASS_ICONS[char.class])
        end

        -- Name: show base class (e.g. "Warlock", "Warrior")
        local color = cc(char.class)
        local classDisplay = titleCase(char.class)
        card.nameText:SetText("|cff" .. color .. classDisplay .. "|r")

        -- Spec tree (e.g. "Soul Link spec")
        local specName = char.spec or ""
        card.specText:SetText(specName ~= "" and (specName .. " spec") or "")

        -- Roles
        local specKey = char.class .. "_" .. (char.spec or "")
        local reqs = FCE.TalentRequirements and FCE.TalentRequirements[specKey]
        local rolesStr = reqs and reqs.roles or nil
        card.rolesText:SetText(rolesStr and ("Role(s): " .. rolesStr) or "")

        -- Info: race list + gender + build-specific lore (if any)
        local infoLines = {}
        local raceList = {}
        if char.raceSet then
            for r in pairs(char.raceSet) do table.insert(raceList, r) end
        end
        if #raceList > 0 then
            table.sort(raceList)
            table.insert(infoLines, "|cff888888" .. table.concat(raceList, ", ") .. "|r")
        end
        if char.gender and char.gender ~= "Any gender" then
            table.insert(infoLines, "|cff888888" .. char.gender .. " only|r")
        end
        local buildLore = FCE.LoreData and FCE.LoreData[char.key]
        if buildLore then
            if #infoLines > 0 then table.insert(infoLines, " ") end
            table.insert(infoLines, buildLore)
        end
        card.infoText:SetText(table.concat(infoLines, "\n"))

        -- Auto-resize card height based on content
        local infoH = card.infoText:GetStringHeight() or 0
        local totalH = UD_CARD_ART_H + 6 + (card.nameText:GetStringHeight() or 14)
                      + 2 + (card.specText:GetStringHeight() or 12)
                      + 1 + (card.rolesText:GetStringHeight() or 12)
                      + 6 + infoH + 10
        card:SetHeight(totalH)

        -- Wire card click → Screen 3
        card.charKey = char.key
        card:SetScript("OnClick", function(self)
            Catalog.ShowScreen3(self.charKey)
        end)

        card:Show()
    end

    -- Auto-resize frame height to fit tallest card + header space
    local maxCardH = 0
    for i = 1, numCards do
        local c = classListFrame.buildCards[i]
        if c and c:IsShown() then
            local h = c:GetHeight()
            if h > maxCardH then maxCardH = h end
        end
    end
    -- Set all visible cards to tallest height so buttons align at bottom
    for i = 1, numCards do
        local c = classListFrame.buildCards[i]
        if c and c:IsShown() then
            c:SetHeight(maxCardH)
        end
    end
    local neededH = maxCardH + 80 + loreH
    if neededH < FRAME_HEIGHT then neededH = FRAME_HEIGHT end
    frame:SetHeight(neededH)
end

----------------------------------------------------------------------
-- Screen 3: Character detail — RequirementsPanel replica
----------------------------------------------------------------------

-- Row pool: each row is a Frame with .tag (50px FontString) + .text
-- Identical structure to RequirementsPanel.acquireRow()
local function acquireCatRow(index)
    local pool = detailFrame.rowPool
    if pool[index] then return pool[index] end

    local row = CreateFrame("Frame", nil, detailFrame.infoContent)
    row:SetHeight(DETAIL_ROW_H)

    row.tag = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.tag:SetPoint("TOPLEFT", row, "TOPLEFT", 2, 0)
    row.tag:SetWidth(50)
    row.tag:SetJustifyH("LEFT")

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("TOPLEFT", row.tag, "TOPRIGHT", 2, 0)
    row.text:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(true)

    pool[index] = row
    return row
end

-- Identical to RequirementsPanel.emitRow()
local function emitCatRow(index, yOffset, tagText, tagColor, text, textColor, indent)
    local row = acquireCatRow(index)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", detailFrame.infoContent, "TOPLEFT", (indent or 0), -yOffset)
    row:SetPoint("RIGHT", detailFrame.infoContent, "RIGHT", 0, 0)
    if tagText then
        row.tag:Show()
        row.tag:SetText(tagText)
        row.tag:SetTextColor(tagColor.r, tagColor.g, tagColor.b)
    else
        row.tag:Hide()
        row.tag:SetText("")
    end
    row.text:SetText(text or "")
    if textColor then
        row.text:SetTextColor(textColor.r, textColor.g, textColor.b)
    else
        row.text:SetTextColor(0.93, 0.93, 0.93)
    end
    -- Reset text anchoring (section headers change it)
    row.text:ClearAllPoints()
    row.text:SetPoint("TOPLEFT", row.tag, "TOPRIGHT", 2, 0)
    row.text:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    row:Show()
    local h = row.text:GetStringHeight()
    if h < DETAIL_ROW_H then h = DETAIL_ROW_H end
    row:SetHeight(h)
    return index + 1, yOffset + h + 2
end

-- Identical to RequirementsPanel.emitSectionHeader()
local function emitCatSectionHeader(index, yOffset, title)
    yOffset = yOffset + DETAIL_SEC_GAP
    local row = acquireCatRow(index)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", detailFrame.infoContent, "TOPLEFT", 0, -yOffset)
    row:SetPoint("RIGHT", detailFrame.infoContent, "RIGHT", 0, 0)
    row:SetHeight(DETAIL_ROW_H)
    row.tag:Hide()
    row.text:SetText(title)
    row.text:SetTextColor(COLOR_HEADER.r, COLOR_HEADER.g, COLOR_HEADER.b)
    row.text:ClearAllPoints()
    row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.text:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row:Show()
    if not row.separator then
        row.separator = row:CreateTexture(nil, "ARTWORK")
        row.separator:SetColorTexture(COLOR_HEADER.r, COLOR_HEADER.g, COLOR_HEADER.b, 0.35)
        row.separator:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, -2)
        row.separator:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, -2)
        row.separator:SetHeight(1)
    end
    row.separator:Show()
    return index + 1, yOffset + DETAIL_ROW_H + 4
end

local function releaseExtraCatRows(lastUsed)
    local pool = detailFrame.rowPool
    for i = lastUsed + 1, #pool do
        pool[i]:Hide()
        if pool[i].separator then pool[i].separator:Hide() end
    end
end

function Catalog.ShowScreen3(charKey)
    BuildFrame()
    frame:SetWidth(FRAME_WIDTH)
    currentScreen = 3
    selectedCharKey = charKey

    local char = FCE.Characters and FCE.Characters[charKey]
    if not char then return end

    -- Track the enhanced class name for back navigation
    local displayName = FCE.GetCharDisplayName and FCE.GetCharDisplayName(char) or char.name
    if not cameFromUndecided then
        selectedEnhancedName = displayName
    end

    local color = cc(char.class)

    frame.titleText:SetText("|cffffd100" .. displayName .. "|r")
    frame.backBtn:Show()

    classGridFrame:Hide()
    classListFrame:Hide()
    undecidedFrame:Hide()
    detailFrame:Show()
    selfFoundFrame:Hide()
    challengeFrame:Hide()

    -- Art panel (LEFT side, per-build icon first)
    local bgPath = FCE.GetCharPortrait and FCE.GetCharPortrait(char)
    if not bgPath then
        bgPath = FCE.ClassBackgrounds and FCE.ClassBackgrounds[char.name]
    end
    if not bgPath and FCE.GetCharDisplayName then
        bgPath = FCE.ClassBackgrounds and FCE.ClassBackgrounds[FCE.GetCharDisplayName(char)]
    end
    if bgPath then
        detailFrame.artTex:SetTexture(bgPath)
        detailFrame.artPanel:Show()
    else
        detailFrame.artPanel:Hide()
    end

    -- Set info content width to match RequirementsPanel content width
    local infoWidth = detailFrame.infoScroll:GetWidth() - 40
    if infoWidth < 100 then infoWidth = 200 end
    detailFrame.infoContent:SetWidth(infoWidth)

    -- Reset row pool state (separators, text anchors)
    for _, row in ipairs(detailFrame.rowPool) do
        if row.separator then row.separator:Hide() end
        row.text:ClearAllPoints()
        row.text:SetPoint("TOPLEFT", row.tag, "TOPRIGHT", 2, 0)
        row.text:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    end

    local index = 1
    local yOff  = 0

    -- Race / gender summary row
    index, yOff = emitCatRow(index, yOff, nil, nil,
        char.race .. " \194\183 " .. char.gender, COLOR_SUBTXT)

    -- PROFESSIONS
    if char.professions and #char.professions > 0 then
        index, yOff = emitCatSectionHeader(index, yOff, "PROFESSIONS")
        for _, profName in ipairs(char.professions) do
            local pName = type(profName) == "table" and (profName.name or "?") or tostring(profName)
            index, yOff = emitCatRow(index, yOff, "lv 5", COLOR_INACTIVE, pName)
        end
    end

    -- WEAPON PROFICIENCY
    if char.weaponProficiency and #char.weaponProficiency > 0 then
        index, yOff = emitCatSectionHeader(index, yOff, "WEAPON PROFICIENCY")
        for _, wpnEntry in ipairs(char.weaponProficiency) do
            local wpn, wpnLevel
            if type(wpnEntry) == "table" then
                wpn = wpnEntry.desc or wpnEntry.name or "?"
                wpnLevel = wpnEntry.level or 1
            else
                wpn = tostring(wpnEntry)
                wpnLevel = 1
            end
            index, yOff = emitCatRow(index, yOff, "lv " .. wpnLevel, COLOR_INACTIVE, wpn)
        end
    end

    -- CHALLENGES + REPUTATION (mandatory)
    local REPUTATION_RULES_C = {
        ["Faction Loyalist"]=true, ["Purifier"]=true, ["Keeper"]=true,
        ["Smith"]=true, ["Avenger"]=true, ["Cult of the Damned"]=true,
        ["Twilight's Hammer"]=true, ["Shadow Council"]=true,
        ["Old Horde"]=true, ["Diplomat"]=true,
    }
    local mandatoryChallenges = {}
    local mandatoryReputation = {}
    for _, ch in ipairs(char.challenges or {}) do
        if not HIDE_CHALLENGE[ch.desc] then
            if REPUTATION_RULES_C[ch.desc] then
                table.insert(mandatoryReputation, ch)
            else
                table.insert(mandatoryChallenges, ch)
            end
        end
    end
    -- Optional challenges (collected for summary line)
    local optionalNames = {}
    if char.optionalChallenges then
        for _, ch in ipairs(char.optionalChallenges) do
            if not HIDE_CHALLENGE[ch.desc] then
                table.insert(optionalNames, ch.desc)
            end
        end
    end
    if #mandatoryChallenges > 0 or #optionalNames > 0 then
        index, yOff = emitCatSectionHeader(index, yOff, "CHALLENGES")
        for _, ch in ipairs(mandatoryChallenges) do
            local lvTag = "lv " .. ch.level
            if ch.endLevel then
                lvTag = "lv " .. ch.level .. "-" .. ch.endLevel
            end
            index, yOff = emitCatRow(index, yOff, lvTag, COLOR_INACTIVE, ch.desc)
            local extra = FCE.ChallengeDescriptions and FCE.ChallengeDescriptions[ch.desc]
            if extra then
                index, yOff = emitCatRow(index, yOff, nil, nil, "  " .. extra, COLOR_SUBTXT)
                yOff = yOff + 4
            end
        end
        if #optionalNames > 0 then
            index, yOff = emitCatRow(index, yOff, nil, nil, "Optional challenges:")
            index, yOff = emitCatRow(index, yOff, nil, nil, "  " .. table.concat(optionalNames, ", "), COLOR_SUBTXT)
        end
    end
    if #mandatoryReputation > 0 then
        index, yOff = emitCatSectionHeader(index, yOff, "REPUTATION")
        for _, ch in ipairs(mandatoryReputation) do
            local lvTag = "lv " .. ch.level
            if ch.endLevel then
                lvTag = "lv " .. ch.level .. "-" .. ch.endLevel
            end
            index, yOff = emitCatRow(index, yOff, lvTag, COLOR_INACTIVE, ch.desc)
            local extra = FCE.ChallengeDescriptions and FCE.ChallengeDescriptions[ch.desc]
            if extra then
                index, yOff = emitCatRow(index, yOff, nil, nil, "  " .. extra, COLOR_SUBTXT)
                yOff = yOff + 4
            end
        end
    end

    -- EQUIPMENT
    local _catEquip = FCE.GetCharEquipment(char)
    if #_catEquip > 0 then
        index, yOff = emitCatSectionHeader(index, yOff, "EQUIPMENT")
        for _, eq in ipairs(_catEquip) do
            local lvTag = "lv " .. eq.level
            if eq.endLevel then
                lvTag = "lv " .. eq.level .. "-" .. eq.endLevel
            end
            index, yOff = emitCatRow(index, yOff, lvTag, COLOR_INACTIVE, eq.desc)
        end
    end

    -- TALENTS
    if char.spec then
        index, yOff = emitCatSectionHeader(index, yOff, "TALENTS")
        -- Spec label
        index, yOff = emitCatRow(index, yOff, nil, nil,
            "Spec: " .. char.spec, COLOR_SUBTXT)
        -- Per-talent requirements
        local talentKey = char.class .. "_" .. (char.spec or "")
        local rawReqs = FCE.TalentRequirements and FCE.TalentRequirements[talentKey]
        if rawReqs then
            local TREE_NAMES = {
                WARRIOR = { "Arms", "Fury", "Protection" },
                ROGUE   = { "Assassination", "Combat", "Subtlety" },
                WARLOCK = { "Affliction", "Demonology", "Destruction" },
                DRUID   = { "Balance", "Feral", "Restoration" },
                HUNTER  = { "Beast Mastery", "Marksmanship", "Survival" },
                SHAMAN  = { "Elemental", "Enhancement", "Restoration" },
                PALADIN = { "Holy", "Protection", "Retribution" },
                PRIEST  = { "Discipline", "Holy", "Shadow" },
                MAGE    = { "Arcane", "Fire", "Frost" },
            }
            local trees = TREE_NAMES[char.class]
            for _, req in ipairs(rawReqs) do
                local lvTag = "lv " .. req.level
                if req.endLevel then
                    lvTag = "lv " .. req.level .. "-" .. req.endLevel
                end
                local treeName = trees and trees[req.tab] or ""
                local detail = req.name .. " " .. req.rank .. "/" .. req.rank
                if treeName ~= "" then
                    detail = detail .. "  |cff888888(" .. treeName .. ")|r"
                end
                index, yOff = emitCatRow(index, yOff, lvTag, COLOR_INACTIVE, detail)
            end
        end
    end

    -- QUESTS
    local charQuests = FCE.GetCharQuests and FCE.GetCharQuests(char) or char.quests or {}
    if #charQuests > 0 then
        index, yOff = emitCatSectionHeader(index, yOff, "QUESTS")
        local groups
        if char.questGroups then
            groups = char.questGroups
        elseif char.questTheme then
            groups = { { theme = char.questTheme, count = #charQuests } }
        else
            groups = { { theme = nil, count = #charQuests } }
        end
        local questIdx = 1
        for _, group in ipairs(groups) do
            if group.theme then
                index, yOff = emitCatRow(index, yOff, nil, nil,
                    group.theme, COLOR_SUBTXT)
            end
            for _ = 1, group.count do
                local quest = charQuests[questIdx]
                if not quest then break end
                questIdx = questIdx + 1
                index, yOff = emitCatRow(index, yOff, "lv " .. quest.level, COLOR_INACTIVE, quest.name)
            end
        end
    end

    -- MOUNTS/COMPANIONS/PETS
    local hasAnimals = char.companion or char.pet or char.mount
    if hasAnimals then
        index, yOff = emitCatSectionHeader(index, yOff, "MOUNTS/COMPANIONS/PETS")
        if char.companion then
            index, yOff = emitCatRow(index, yOff, "lv " .. char.companion.level, COLOR_INACTIVE,
                "Companion: " .. char.companion.desc)
        end
        if char.pet then
            index, yOff = emitCatRow(index, yOff, "lv " .. char.pet.level, COLOR_INACTIVE,
                "Hunter pet: " .. char.pet.desc)
        end
        if char.mount then
            index, yOff = emitCatRow(index, yOff, "lv " .. char.mount.level, COLOR_INACTIVE,
                "Mount: " .. char.mount.desc)
        end
    end

    -- RECOMMENDED PROFESSION
    local _catRecProf = FCE.GetCharRecommendedProfession(char)
    if _catRecProf then
        index, yOff = emitCatSectionHeader(index, yOff, "RECOMMENDED")
        index, yOff = emitCatRow(index, yOff, nil, nil,
            "Profession: " .. _catRecProf.name, COLOR_TIPS)
    end

    -- GAMEPLAY
    local _catGameplay = FCE.GetCharGameplay and FCE.GetCharGameplay(char) or char.gameplay
    if _catGameplay and _catGameplay ~= "" then
        index, yOff = emitCatSectionHeader(index, yOff, "GAMEPLAY")
        local tips = FCE.GameplayTips and FCE.GameplayTips.Parse and FCE.GameplayTips.Parse(_catGameplay)
        if tips and #tips > 0 then
            for _, tip in ipairs(tips) do
                index, yOff = emitCatRow(index, yOff, nil, nil, tip.title, COLOR_TIPS)
            end
        else
            index, yOff = emitCatRow(index, yOff, nil, nil, _catGameplay, COLOR_SUBTXT)
        end
    end

    releaseExtraCatRows(index - 1)
    detailFrame.infoContent:SetHeight(math.max(yOff + 10, 1))

    -- Select button label
    if char.optionalChallenges and #char.optionalChallenges > 0 then
        detailFrame.selectBtn:SetText("Select " .. displayName .. " >")
    else
        detailFrame.selectBtn:SetText("Select " .. displayName)
    end
end

----------------------------------------------------------------------
-- Screen 3 → next: routing logic
----------------------------------------------------------------------

--- Determine whether to show the self-found picker, optional challenges,
--- or commit immediately after the player clicks "Select This Class".
function Catalog.ProceedFromDetail()
    if not selectedCharKey then return end
    local ch = FCE.Characters and FCE.Characters[selectedCharKey]
    if not ch then return end

    local charSF = FCE.GetCharSelfFound and FCE.GetCharSelfFound(ch) or ch.selfFound

    -- On hardcore realms, ask about self-found if the character supports it
    if charSF and IsHardcoreRealm() then
        Catalog.ShowSelfFoundScreen(selectedCharKey)
        return
    end

    -- Char doesn't support self-found → skip to challenges or commit
    selectedSelfFound = nil
    Catalog.ProceedFromSelfFound()
end

--- Continue after self-found choice (or skip) → optional challenges or commit.
function Catalog.ProceedFromSelfFound()
    if not selectedCharKey then return end
    local ch = FCE.Characters and FCE.Characters[selectedCharKey]
    if ch and ch.optionalChallenges and #ch.optionalChallenges > 0 then
        Catalog.ShowScreen4(selectedCharKey)
    else
        selectedOptChallenges = {}
        Catalog.CommitSelection()
    end
end

----------------------------------------------------------------------
-- Screen 3.5: Self-found picker (hardcore realms only)
----------------------------------------------------------------------

local SF_ROW_H = 70

local function acquireSFRow(index, parent)
    local rows = selfFoundFrame.rows
    if rows[index] then return rows[index] end

    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetHeight(SF_ROW_H)
    if FCE.Style then
        FCE.Style.ApplyCardBackdrop(row, { bgA = 0.80 })
    elseif row.SetBackdrop then
        row:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets   = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        row:SetBackdropColor(0.055, 0.050, 0.045, 0.80)
        row:SetBackdropBorderColor(0.50, 0.42, 0.25, 0.55)
    end

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(0.92, 0.82, 0.58, 0.08)

    local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    name:SetPoint("TOPLEFT", 14, -10)
    name:SetPoint("RIGHT", row, "RIGHT", -14, 0)
    name:SetJustifyH("LEFT")
    row.nameText = name

    local desc = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -4)
    desc:SetPoint("RIGHT", row, "RIGHT", -14, 0)
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true)
    desc:SetTextColor(0.75, 0.73, 0.68)
    row.descText = desc

    rows[index] = row
    return row
end

function Catalog.ShowSelfFoundScreen(charKey)
    BuildFrame()
    frame:SetWidth(FRAME_WIDTH)
    currentScreen = 35  -- 3.5
    selectedSelfFound = nil

    local char = FCE.Characters and FCE.Characters[charKey]
    if not char then return end

    local displayName = FCE.GetCharDisplayName and FCE.GetCharDisplayName(char) or char.name
    local color = cc(char.class)

    frame.titleText:SetText("|cffffd100" .. displayName .. " — Self-Found|r")
    frame.backBtn:Show()

    classGridFrame:Hide()
    classListFrame:Hide()
    undecidedFrame:Hide()
    detailFrame:Hide()
    selfFoundFrame:Show()
    challengeFrame:Hide()

    selfFoundFrame.titleText:SetText("|cff" .. color .. displayName .. "|r")
    selfFoundFrame.subtitleText:SetText("You are on a Hardcore realm. Will you play this character as Self-Found?")

    for _, row in pairs(selfFoundFrame.rows) do row:Hide() end

    local parent = selfFoundFrame
    local cardW = 500
    local yOff = 70

    -- "Self-Found" option
    local sfRow = acquireSFRow(1, parent)
    sfRow:ClearAllPoints()
    sfRow:SetSize(cardW, SF_ROW_H)
    sfRow:SetPoint("TOP", parent, "TOP", 0, -yOff)
    sfRow.nameText:SetText("|cffaaddffSelf-Found|r")
    sfRow.descText:SetText("No auction house, no trading. Only use items you find or craft yourself.\n|cff88cc88Recommended for immersion.|r")
    sfRow:SetScript("OnClick", function()
        selectedSelfFound = true
        Catalog.ProceedFromSelfFound()
    end)
    sfRow:Show()
    yOff = yOff + SF_ROW_H + 8

    -- "Not Self-Found" option
    local nsfRow = acquireSFRow(2, parent)
    nsfRow:ClearAllPoints()
    nsfRow:SetSize(cardW, SF_ROW_H)
    nsfRow:SetPoint("TOP", parent, "TOP", 0, -yOff)
    nsfRow.nameText:SetText("|cffffffffNot Self-Found|r")
    nsfRow.descText:SetText("Use the auction house and trade freely. The self-found buff check will be skipped.")
    nsfRow:SetScript("OnClick", function()
        selectedSelfFound = false
        Catalog.ProceedFromSelfFound()
    end)
    nsfRow:Show()
end

----------------------------------------------------------------------
-- Screen 4: Optional challenge picker
----------------------------------------------------------------------
local OPT_ROW_H = 60
local OPT_ROW_H_EXEMPT = 82  -- taller when exemption notice is shown

local EXEMPTION_CHALLENGES = {
    ["Exotic"] = true, ["Scout"] = true, ["Scavenger"] = true,
    ["Partisan"] = true, ["Self-made"] = true, ["Expeditionary"] = true,
    ["Cloth/leather"] = true, ["Leather/mail"] = true, ["Mail/plate"] = true,
    ["Cloth"] = true,
}

local function acquireChallengeRow(index, parent)
    local rows = challengeFrame.rows
    if rows[index] then return rows[index] end

    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetHeight(OPT_ROW_H)
    if FCE.Style then
        FCE.Style.ApplyCardBackdrop(row, { bgA = 0.80 })
    elseif row.SetBackdrop then
        row:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets   = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        row:SetBackdropColor(0.06, 0.055, 0.05, 0.80)
        row:SetBackdropBorderColor(0.50, 0.42, 0.25, 0.45)
    end

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(0.92, 0.82, 0.58, 0.08)

    -- Checkbox: outer box (dark inset with gold border)
    local cbSize = 20
    local cbBox = CreateFrame("Frame", nil, row, "BackdropTemplate")
    cbBox:SetSize(cbSize, cbSize)
    cbBox:SetPoint("LEFT", row, "LEFT", 14, 0)
    if cbBox.SetBackdrop then
        cbBox:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 8,
            insets   = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        cbBox:SetBackdropColor(0.03, 0.025, 0.02, 0.95)
        cbBox:SetBackdropBorderColor(0.55, 0.45, 0.25, 0.80)
    end
    row.cbBox = cbBox

    -- Checkbox: check mark texture (gold-tinted)
    local cbCheck = cbBox:CreateTexture(nil, "OVERLAY")
    cbCheck:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    cbCheck:SetPoint("CENTER", cbBox, "CENTER", 0, 0)
    cbCheck:SetSize(28, 28)
    cbCheck:SetVertexColor(1.0, 0.85, 0.0)
    cbCheck:Hide()
    row.cbCheck = cbCheck

    -- Name (offset right for checkbox)
    local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    name:SetPoint("TOPLEFT", cbBox, "TOPRIGHT", 10, 2)
    name:SetPoint("RIGHT", row, "RIGHT", -14, 0)
    name:SetJustifyH("LEFT")
    row.nameText = name

    local desc = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
    desc:SetPoint("RIGHT", row, "RIGHT", -14, 0)
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true)
    desc:SetTextColor(0.75, 0.73, 0.68)
    row.descText = desc

    -- Exemption notice (hidden by default, shown for forgivable challenges)
    local exempt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    exempt:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -4)
    exempt:SetPoint("RIGHT", row, "RIGHT", -14, 0)
    exempt:SetJustifyH("LEFT")
    exempt:SetWordWrap(true)
    exempt:SetTextColor(0.53, 0.80, 0.53)
    exempt:Hide()
    row.exemptText = exempt

    rows[index] = row
    return row
end

local function refreshScreen4Highlights()
    if not challengeFrame or not challengeFrame.rows then return end
    -- Check if any real challenge is selected (ignore __none__ marker)
    local anySelected = false
    for k in pairs(selectedOptChallenges) do
        if k ~= "__none__" then anySelected = true; break end
    end
    for _, row in pairs(challengeFrame.rows) do
        if row:IsShown() then
            local desc = row.challengeDesc
            local isActive = false
            if desc == nil then
                -- "Skip" row: active when explicitly chosen
                isActive = (selectedOptChallenges["__none__"] == true)
            elseif selectedOptChallenges[desc] then
                isActive = true
            end
            -- Toggle checkbox
            if row.cbCheck then
                if isActive then
                    row.cbCheck:Show()
                else
                    row.cbCheck:Hide()
                end
            end
            -- Brighten border on selected cards
            if row.cbBox and row.cbBox.SetBackdropBorderColor then
                if isActive then
                    row.cbBox:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
                else
                    row.cbBox:SetBackdropBorderColor(0.55, 0.45, 0.25, 0.80)
                end
            end
            if row.SetBackdropBorderColor then
                if isActive then
                    row:SetBackdropBorderColor(0.85, 0.70, 0.25, 0.90)
                else
                    row:SetBackdropBorderColor(0.50, 0.42, 0.25, 0.55)
                end
            end
        end
    end
end

function Catalog.ShowScreen4(charKey)
    BuildFrame()
    frame:SetWidth(FRAME_WIDTH)
    currentScreen = 4
    selectedOptChallenges = {}

    local char = FCE.Characters and FCE.Characters[charKey]
    if not char then return end

    local displayName = FCE.GetCharDisplayName and FCE.GetCharDisplayName(char) or char.name
    local color = cc(char.class)

    frame.titleText:SetText("|cffffd100" .. displayName .. " — Optional Challenges|r")
    frame.backBtn:Show()

    classGridFrame:Hide()
    classListFrame:Hide()
    undecidedFrame:Hide()
    detailFrame:Hide()
    selfFoundFrame:Hide()
    challengeFrame:Show()

    challengeFrame.titleText:SetText("|cff" .. color .. displayName .. "|r")
    challengeFrame.subtitleText:SetText("Pick optional challenges. Only one gear-based challenge allowed.")

    -- Hide old rows
    for _, row in pairs(challengeFrame.rows) do row:Hide() end

    local parent = challengeFrame.content
    local cardW = 600

    local yOff = 4
    local idx = 0

    -- One row per optional challenge
    for _, ch in ipairs(char.optionalChallenges or {}) do
        idx = idx + 1
        local row = acquireChallengeRow(idx, parent)
        row:ClearAllPoints()
        row:SetSize(cardW, OPT_ROW_H)
        row:SetPoint("TOP", parent, "TOP", 0, -yOff)
        row.challengeDesc = ch.desc

        row.nameText:SetText("|cffffd100" .. ch.desc .. "|r")
        local extra = FCE.ChallengeDescriptions and FCE.ChallengeDescriptions[ch.desc] or ""
        row.descText:SetText(extra)

        -- Show exemption notice for forgivable challenges
        local isExempt = EXEMPTION_CHALLENGES[ch.desc]
        if isExempt then
            row.exemptText:SetText("Rankable: This restriction loosens as you level up and stay on top of your class requirements.")
            row.exemptText:Show()
            row:SetHeight(OPT_ROW_H_EXEMPT)
        else
            row.exemptText:Hide()
            row:SetHeight(OPT_ROW_H)
        end

        local capturedDesc = ch.desc
        row:SetScript("OnClick", function()
            if selectedOptChallenges[capturedDesc] then
                -- Untick
                selectedOptChallenges[capturedDesc] = nil
            else
                -- Tick — if gear-based, remove any other gear-based first
                if GEAR_CHALLENGES_CAT[capturedDesc] then
                    for d in pairs(selectedOptChallenges) do
                        if GEAR_CHALLENGES_CAT[d] then
                            selectedOptChallenges[d] = nil
                        end
                    end
                end
                selectedOptChallenges[capturedDesc] = true
                selectedOptChallenges["__none__"] = nil
            end
            refreshScreen4Highlights()
        end)
        row:Show()
        yOff = yOff + (isExempt and OPT_ROW_H_EXEMPT or OPT_ROW_H) + 8
    end

    -- "Skip" option — clears all and proceeds
    idx = idx + 1
    local noneRow = acquireChallengeRow(idx, parent)
    noneRow:ClearAllPoints()
    noneRow:SetSize(cardW, OPT_ROW_H)
    noneRow:SetPoint("TOP", parent, "TOP", 0, -yOff)
    noneRow.challengeDesc = nil
    noneRow.nameText:SetText("|cff888888Skip — No Optional Challenge|r")
    noneRow.descText:SetText("Play " .. displayName .. " without any additional challenge.")
    noneRow:SetScript("OnClick", function()
        selectedOptChallenges = { ["__none__"] = true }
        refreshScreen4Highlights()
    end)
    noneRow.exemptText:Hide()
    noneRow:SetHeight(OPT_ROW_H)
    noneRow:Show()
    yOff = yOff + OPT_ROW_H + 4

    -- Confirm button
    idx = idx + 1
    if not challengeFrame.confirmBtn then
        local btn
        if FCE.Style then
            btn = FCE.Style.CreateButton(challengeFrame, 140, 26, "Confirm")
        else
            btn = CreateFrame("Button", nil, challengeFrame, "UIPanelButtonTemplate")
            btn:SetSize(140, 26)
            btn:SetText("Confirm")
        end
        challengeFrame.confirmBtn = btn
    end
    challengeFrame.confirmBtn:ClearAllPoints()
    challengeFrame.confirmBtn:SetPoint("BOTTOM", challengeFrame, "BOTTOM", 0, 12)
    challengeFrame.confirmBtn:SetScript("OnClick", function()
        Catalog.CommitSelection()
    end)
    challengeFrame.confirmBtn:Show()

    parent:SetHeight(yOff + 10)
    refreshScreen4Highlights()
end

----------------------------------------------------------------------
-- Commit selection (same logic as SelectionUI.Commit)
----------------------------------------------------------------------
function Catalog.CommitSelection()
    if not selectedCharKey then return end
    local char = FCE.Characters and FCE.Characters[selectedCharKey]
    if not char then return end

    FCE_CharDB.selectedCharacter = char.key
    FCE_CharDB.manualOverride    = true
    -- Save multi-select challenges as an array
    local selArray = {}
    for desc in pairs(selectedOptChallenges) do
        if desc ~= "__none__" then
            selArray[#selArray + 1] = desc
        end
    end
    FCE_CharDB.selectedChallenges = #selArray > 0 and selArray or nil
    FCE_CharDB.selectedChallenge  = nil  -- clear legacy field
    FCE_CharDB.selfFoundChoice    = selectedSelfFound  -- true/false/nil

    local challengeMsg = ""
    if #selArray > 0 then
        challengeMsg = " + |cffffd100" .. table.concat(selArray, ", ") .. "|r"
    end
    FCE.Print("Selected enhanced class: |cffffd100" .. char.name .. "|r (" .. char.spec .. ")" .. challengeMsg)

    -- Re-sync all modules
    if FCE.ResyncLevelAlerts then FCE.ResyncLevelAlerts() end
    if FCE.CompanionCheck and FCE.CompanionCheck.ResetWarnings then FCE.CompanionCheck.ResetWarnings() end
    if FCE.HunterPetCheck and FCE.HunterPetCheck.ResetWarnings then FCE.HunterPetCheck.ResetWarnings() end
    if FCE.MountCheck and FCE.MountCheck.ResetWarnings then FCE.MountCheck.ResetWarnings() end
    if FCE.ProfessionCheck and FCE.ProfessionCheck.ResetWarnings then FCE.ProfessionCheck.ResetWarnings() end
    if FCE.TalentCheck and FCE.TalentCheck.ResetWarnings then FCE.TalentCheck.ResetWarnings() end
    if FCE.SelfFoundCheck and FCE.SelfFoundCheck.ResetWarnings then FCE.SelfFoundCheck.ResetWarnings() end
    if FCE.ChallengeCheck and FCE.ChallengeCheck.ResetWarnings then FCE.ChallengeCheck.ResetWarnings() end
    if FCE.ZoneCheck and FCE.ZoneCheck.ResetTracking then FCE.ZoneCheck.ResetTracking() end
    if FCE.BehavioralCheck and FCE.BehavioralCheck.ResetTracking then FCE.BehavioralCheck.ResetTracking() end
    if FCE.DoubtSystem and FCE.DoubtSystem.OnClassChanged then FCE.DoubtSystem.OnClassChanged() end
    if FCE.EventChallenges and FCE.EventChallenges.RefreshChallengeCache then FCE.EventChallenges.RefreshChallengeCache() end
    -- Clear stale stored results so Progress.Collect doesn't read
    -- old data from a previous character during rank calculation
    FCE_CharDB.challengeResults   = nil
    FCE_CharDB.selfFoundResults   = nil
    FCE_CharDB.companionResults   = nil
    FCE_CharDB.hunterPetResults   = nil
    FCE_CharDB.mountResults       = nil

    -- Run ALL check modules — ChallengeCheck LAST because its rank
    -- calculation (computeOptimisticAllowed -> Progress.Collect) reads
    -- stored results from every other module.
    if FCE.ProfessionCheck and FCE.ProfessionCheck.RunCheck then FCE.ProfessionCheck.RunCheck() end
    if FCE.WeaponProficiencyCheck and FCE.WeaponProficiencyCheck.RunCheck then FCE.WeaponProficiencyCheck.RunCheck() end
    if FCE.EquipmentCheck and FCE.EquipmentCheck.RunCheck then FCE.EquipmentCheck.RunCheck() end
    if FCE.TalentCheck and FCE.TalentCheck.RunCheck then FCE.TalentCheck.RunCheck() end
    if FCE.SelfFoundCheck and FCE.SelfFoundCheck.RunCheck then FCE.SelfFoundCheck.RunCheck() end
    if FCE.CompanionCheck and FCE.CompanionCheck.RunCheck then FCE.CompanionCheck.RunCheck() end
    if FCE.HunterPetCheck and FCE.HunterPetCheck.RunCheck then FCE.HunterPetCheck.RunCheck() end
    if FCE.MountCheck and FCE.MountCheck.RunCheck then FCE.MountCheck.RunCheck() end
    if FCE.QuestCheck and FCE.QuestCheck.RunCheck then FCE.QuestCheck.RunCheck() end
    if FCE.ZoneCheck and FCE.ZoneCheck.RunCheck then FCE.ZoneCheck.RunCheck() end
    if FCE.BehavioralCheck and FCE.BehavioralCheck.RunCheck then FCE.BehavioralCheck.RunCheck() end
    -- ChallengeCheck last: rank depends on fresh results from above
    if FCE.ChallengeCheck and FCE.ChallengeCheck.RunCheck then FCE.ChallengeCheck.RunCheck() end
    if FCE.RefreshPanel then FCE.RefreshPanel() end

    -- Close the catalog and show the requirements panel
    panelWasShown = false  -- don't double-show via Catalog.Hide
    if frame then frame:Hide() end
    if FCE.ShowPanel then
        C_Timer.After(0.3, function()
            FCE.ShowPanel()
        end)
    end
end

----------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------

local panelWasShown = false  -- track whether we hid the requirements panel

function Catalog.Show()
    BuildFrame()
    -- Hide requirements panel while catalog is open
    if FCE.HidePanel then
        panelWasShown = FCE.IsShownPanel and FCE.IsShownPanel() or false
        FCE.HidePanel()
    end
    Catalog.ShowScreen1()
    frame:Show()
end

function Catalog.IsShown()
    return frame and frame:IsShown()
end

function Catalog.Hide()
    if frame then frame:Hide() end
    -- Restore / open requirements panel after catalog closes
    if panelWasShown and FCE.ShowPanel then
        C_Timer.After(0.3, FCE.ShowPanel)
    end
    panelWasShown = false
end

function Catalog.Toggle()
    if frame and frame:IsShown() then
        Catalog.Hide()
    else
        Catalog.Show()
    end
end

--- Open the catalog. If no character is saved, show the undecided panel.
--- Otherwise show the race grid (Screen 1).
function Catalog.ShowForPlayer()
    BuildFrame()
    if FCE.HidePanel then
        panelWasShown = FCE.IsShownPanel and FCE.IsShownPanel() or false
        FCE.HidePanel()
    end
    if not FCE_CharDB or not FCE_CharDB.selectedCharacter then
        Catalog.ShowUndecidedPanel()
    else
        Catalog.ShowScreen1()
    end
    frame:Show()
end

-- Alias for old SelectionUI API (so existing code keeps working)
function FCE.ShowSelectionUI()
    Catalog.Show()
end

function FCE.HideSelectionUI()
    Catalog.Hide()
end

function FCE.ToggleSelectionUI()
    Catalog.Toggle()
end

-- Keep the old Catalog API names working
Catalog.Refresh = Catalog.Show
