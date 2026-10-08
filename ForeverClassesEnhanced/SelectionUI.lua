----------------------------------------------------------------------
-- ForeverClassesEnhanced — Selection UI
--
-- A frame that lets the player browse enhanced classes and pick one.
-- Auto-opens on login when multiple race/class/gender matches exist,
-- and is also reachable via /fce pick (with no argument) or /fce ui.
--
-- Layout:
--   +------------------------------------------------+
--   | Forever Classes Enhanced         [?]    [X]   |
--   | Pick your enhanced class                       |
--   |   ( ) Only ones that match my character        |
--   |   ( ) All enhanced classes for <Class>         |
--   | +-------------------+  +---------------------+ |
--   | | [entry]           |  | Mountain King       | |
--   | | [entry]  <-sel    |  | Protection Warrior  | |
--   | | [entry]           |  | Dwarf, Male         | |
--   | | [entry]           |  |                     | |
--   | | ...               |  | Equipment:  ...     | |
--   | +-------------------+  | Challenges: ...     | |
--   |                        +---------------------+ |
--   |                       [ Select ]   [ Cancel ]  |
--   +------------------------------------------------+
----------------------------------------------------------------------

FCE = FCE or {}

local UI            = {}
FCE.UI              = UI

local ROW_HEIGHT    = 34
local LIST_ROWS     = 9
local LIST_WIDTH    = 240
local FRAME_WIDTH   = 640
local FRAME_HEIGHT  = 470

-- Class text colours (Blizzard defaults for Classic)
local CLASS_COLORS = {
    WARRIOR = "c79c6e", ROGUE   = "fff569", MAGE    = "69ccf0",
    WARLOCK = "9482c9", PRIEST  = "ffffff", PALADIN = "f58cba",
    DRUID   = "ff7d0a", SHAMAN  = "0070de", HUNTER  = "abd473",
}

local function classColor(classToken)
    return CLASS_COLORS[classToken or ""] or "ffd100"
end

local function titleCase(s)
    if not s or s == "" then return "" end
    return s:sub(1, 1):upper() .. s:sub(2):lower()
end

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------

UI.selectedKey  = nil     -- currently highlighted entry in the list (not yet committed)
UI.filterMode   = "match" -- "match" or "class"
UI.entries      = {}      -- array of character refs currently shown
UI.selectedOptionalChallenges = {}  -- set of desc strings currently ticked

-- Gear-based (exemptable) challenges — only one allowed at a time
local GEAR_CHALLENGES = {
    ["Exotic"] = true, ["Scout"] = true, ["Scavenger"] = true,
    ["Partisan"] = true, ["Self-made"] = true, ["Expeditionary"] = true,
    ["Cloth/leather"] = true, ["Leather/mail"] = true, ["Mail/plate"] = true,
    ["Cloth"] = true, ["Leather"] = true, ["Off-the-shelf"] = true,
}

----------------------------------------------------------------------
-- Build the frame
----------------------------------------------------------------------

local frame

local function BuildFrame()
    if frame then return frame end

    frame = CreateFrame("Frame", "HCE_SelectionFrame", UIParent, "BackdropTemplate")
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:Hide()

    -- Close panel with Escape key
    tinsert(UISpecialFrames, "HCE_SelectionFrame")

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
    titleBar:SetHeight(28)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() frame:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)

    if FCE.Style then
        FCE.Style.TintTitleBar(titleBar)
        FCE.Style.CreateGoldStripe(frame, titleBar, 0)
    else
        local tbg = titleBar:CreateTexture(nil, "BACKGROUND")
        tbg:SetColorTexture(0.85, 0.70, 0.20, 0.10)
        tbg:SetAllPoints()
        local tstripe = titleBar:CreateTexture(nil, "ARTWORK")
        tstripe:SetColorTexture(0.72, 0.56, 0.30, 0.85)
        tstripe:SetPoint("BOTTOMLEFT", titleBar, "BOTTOMLEFT", 0, 0)
        tstripe:SetPoint("BOTTOMRIGHT", titleBar, "BOTTOMRIGHT", 0, 0)
        tstripe:SetHeight(1)
    end

    -- Title text
    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("LEFT", titleBar, "LEFT", 10, 0)
    titleText:SetText("Forever Classes Enhanced")
    titleText:SetTextColor(1.0, 0.82, 0.0)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("TOPRIGHT", titleBar, "TOPRIGHT", 0, 2)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    -- Subheading
    local heading = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", 16, -38)
    heading:SetText("Choose your enhanced class")
    frame.heading = heading

    -- Subtitle / instructions
    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -4)
    subtitle:SetPoint("RIGHT", frame, "RIGHT", -16, 0)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetTextColor(0.92, 0.87, 0.76)
    subtitle:SetText("Pick a lore-flavoured archetype for this hardcore run. Your choice is saved for this character.")
    frame.subtitle = subtitle

    -- Filter: "match" vs "class"
    local matchBtn = CreateFrame("CheckButton", "HCE_FilterMatch", frame, "UIRadioButtonTemplate")
    matchBtn:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -10)
    matchBtn.text:SetText("Matches for my character")
    matchBtn.text:SetFontObject("GameFontNormal")
    frame.matchBtn = matchBtn

    local classBtn = CreateFrame("CheckButton", "HCE_FilterClass", frame, "UIRadioButtonTemplate")
    classBtn:SetPoint("LEFT", matchBtn.text, "RIGHT", 16, 0)
    classBtn.text:SetText("All archetypes for my class")
    classBtn.text:SetFontObject("GameFontNormal")
    frame.classBtn = classBtn

    matchBtn:SetScript("OnClick", function()
        UI.filterMode = "match"
        UI:Refresh()
    end)
    classBtn:SetScript("OnClick", function()
        UI.filterMode = "class"
        UI:Refresh()
    end)

    ---------- Left: list of entries with a scroll frame ----------
    local listBG = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    listBG:SetPoint("TOPLEFT", matchBtn, "BOTTOMLEFT", -4, -10)
    listBG:SetSize(LIST_WIDTH + 28, ROW_HEIGHT * LIST_ROWS + 14)
    if FCE.Style then
        FCE.Style.ApplyInsetBackdrop(listBG)
    elseif listBG.SetBackdrop then
        listBG:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets   = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        listBG:SetBackdropColor(0.030, 0.025, 0.020, 0.80)
        listBG:SetBackdropBorderColor(0.50, 0.42, 0.25, 0.45)
    end
    frame.listBG = listBG

    local scroll = CreateFrame("ScrollFrame", "HCE_SelectionScroll", listBG, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -26, 6)
    scroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, function() UI:RefreshList() end)
    end)
    frame.scroll = scroll

    -- Pre-create row buttons
    frame.rows = {}
    for i = 1, LIST_ROWS do
        local row = CreateFrame("Button", nil, listBG)
        row:SetHeight(ROW_HEIGHT)
        if i == 1 then
            row:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
            row:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 0, 0)
        else
            row:SetPoint("TOPLEFT", frame.rows[i - 1], "BOTTOMLEFT", 0, 0)
            row:SetPoint("TOPRIGHT", frame.rows[i - 1], "BOTTOMRIGHT", 0, 0)
        end

        -- Highlight texture (subtle gold wash)
        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(0.92, 0.82, 0.58, 0.08)

        -- Selection texture (shown when this row is the selected one)
        local sel = row:CreateTexture(nil, "BACKGROUND")
        sel:SetAllPoints()
        sel:SetColorTexture(1, 0.82, 0, 0.15)
        sel:Hide()
        row.selTex = sel

        -- Name
        local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        name:SetPoint("TOPLEFT", 8, -4)
        name:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        name:SetJustifyH("LEFT")
        row.nameText = name

        -- Subtext (spec + race)
        local sub = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        sub:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -1)
        sub:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        sub:SetJustifyH("LEFT")
        row.subText = sub

        row:SetScript("OnClick", function(self)
            local entry = self.entry
            if entry then
                if UI.selectedKey ~= entry.name then
                    UI.selectedOptionalChallenges = {}  -- reset when switching classes
                end
                UI.selectedKey = entry.name
                UI:Refresh()
            end
        end)

        row:SetScript("OnDoubleClick", function(self)
            local entry = self.entry
            if entry then
                UI.selectedKey = entry.name
                UI:Commit()
            end
        end)

        frame.rows[i] = row
    end

    ---------- Right: details panel ----------
    local detail = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    detail:SetPoint("TOPLEFT", listBG, "TOPRIGHT", 10, 0)
    detail:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 60)
    if FCE.Style then
        FCE.Style.ApplyInsetBackdrop(detail)
    elseif detail.SetBackdrop then
        detail:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets   = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        detail:SetBackdropColor(0.030, 0.025, 0.020, 0.80)
        detail:SetBackdropBorderColor(0.50, 0.42, 0.25, 0.45)
    end
    frame.detail = detail

    local dName = detail:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    dName:SetPoint("TOPLEFT", 12, -12)
    dName:SetPoint("RIGHT", detail, "RIGHT", -12, 0)
    dName:SetJustifyH("LEFT")
    frame.dName = dName

    local dSub = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    dSub:SetPoint("TOPLEFT", dName, "BOTTOMLEFT", 0, -2)
    dSub:SetPoint("RIGHT", detail, "RIGHT", -12, 0)
    dSub:SetJustifyH("LEFT")
    frame.dSub = dSub

    local divider = detail:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", dSub, "BOTTOMLEFT", 0, -6)
    divider:SetPoint("RIGHT", detail, "RIGHT", -12, 0)
    divider:SetHeight(1)
    divider:SetColorTexture(1, 0.82, 0, 0.35)

    -- Scrolling body for the long requirement text
    local bodyScroll = CreateFrame("ScrollFrame", nil, detail, "UIPanelScrollFrameTemplate")
    bodyScroll:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, -6)
    bodyScroll:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", -26, 10)

    local bodyContent = CreateFrame("Frame", nil, bodyScroll)
    bodyContent:SetSize(1, 1)
    bodyScroll:SetScrollChild(bodyContent)

    local dBody = bodyContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dBody:SetPoint("TOPLEFT", 0, 0)
    dBody:SetWidth(FRAME_WIDTH - LIST_WIDTH - 120)
    dBody:SetJustifyH("LEFT")
    dBody:SetSpacing(3)
    frame.dBody        = dBody
    frame.dBodyScroll  = bodyScroll
    frame.dBodyContent = bodyContent

    -- Pre-create checkboxes for optional challenges (max 5: "None" + up to 4 options)
    frame.optionRadios = {}
    local MAX_OPTIONS = 5
    for i = 1, MAX_OPTIONS do
        local radio = CreateFrame("CheckButton", "HCE_OptChallenge" .. i, bodyContent, "UICheckButtonTemplate")
        radio:SetSize(16, 16)
        radio:Hide()

        radio.label = bodyContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        radio.label:SetPoint("LEFT", radio, "RIGHT", 4, 0)
        radio.label:SetWidth(FRAME_WIDTH - LIST_WIDTH - 140)
        radio.label:SetJustifyH("LEFT")

        radio.detail = bodyContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        radio.detail:SetPoint("TOPLEFT", radio.label, "BOTTOMLEFT", 0, -1)
        radio.detail:SetWidth(FRAME_WIDTH - LIST_WIDTH - 140)
        radio.detail:SetJustifyH("LEFT")

        radio:SetScript("OnClick", function(self)
            local desc = self.challengeDesc
            if desc == nil then
                -- "None" — clear everything
                UI.selectedOptionalChallenges = {}
            elseif UI.selectedOptionalChallenges[desc] then
                -- Untick
                UI.selectedOptionalChallenges[desc] = nil
            else
                -- Tick — if gear-based, remove any other gear-based first
                if GEAR_CHALLENGES[desc] then
                    for d in pairs(UI.selectedOptionalChallenges) do
                        if GEAR_CHALLENGES[d] then
                            UI.selectedOptionalChallenges[d] = nil
                        end
                    end
                end
                UI.selectedOptionalChallenges[desc] = true
            end
            UI:RefreshOptionRadios()
        end)

        frame.optionRadios[i] = radio
    end

    ---------- Footer buttons ----------
    local selectBtn
    if FCE.Style then
        selectBtn = FCE.Style.CreateButton(frame, 130, 24, "Select")
    else
        selectBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        selectBtn:SetText("Select")
    end
    selectBtn:SetSize(130, 26)
    selectBtn:SetPoint("BOTTOM", frame, "BOTTOM", 60, 18)
    selectBtn:SetScript("OnClick", function() UI:Commit() end)
    frame.selectBtn = selectBtn

    local cancelBtn
    if FCE.Style then
        cancelBtn = FCE.Style.CreateButton(frame, 100, 26, "Cancel")
    else
        cancelBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        cancelBtn:SetText("Cancel")
    end
    cancelBtn:SetSize(100, 26)
    cancelBtn:SetPoint("RIGHT", selectBtn, "LEFT", -12, 0)
    cancelBtn:SetScript("OnClick", function() frame:Hide() end)
    frame.cancelBtn = cancelBtn

    -- Hint on the bottom-left explaining double-click
    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 22)
    hint:SetText("Tip: double-click an entry to select it instantly.")
    frame.hint = hint

    frame:SetScript("OnShow", function() UI:Refresh() end)
    frame:SetScript("OnHide", function()
        -- Nothing persistent; selection isn't committed until the button is clicked
    end)

    return frame
end

----------------------------------------------------------------------
-- Data gathering
----------------------------------------------------------------------

local function collectEntries()
    local _, playerClass = UnitClass("player")
    local results = {}

    if UI.filterMode == "match" then
        for _, char in ipairs(FCE.FindMatchingCharacters()) do
            table.insert(results, char)
        end
        -- If there are zero matches we silently fall through to the class
        -- list so the player is never stuck with an empty frame.
        if #results == 0 then
            for _, char in pairs(FCE.Characters) do
                if char.class == playerClass then
                    table.insert(results, char)
                end
            end
        end
    else
        for _, char in pairs(FCE.Characters) do
            if char.class == playerClass then
                table.insert(results, char)
            end
        end
    end

    table.sort(results, function(a, b) return a.name < b.name end)
    return results
end

----------------------------------------------------------------------
-- Details pane builder
----------------------------------------------------------------------

local function buildDetails(char)
    if not char then return "Select an enhanced class to see its requirements." end

    local lines = {}
    local function add(line) lines[#lines + 1] = line end

    add("|cffaaaaaaRace:|r " .. char.race
        .. "   |cffaaaaaaGender:|r " .. char.gender)

    if char.professions and #char.professions > 0 then
        add("|cffaaaaaaProfessions:|r " .. table.concat(char.professions, ", "))
    else
        add("|cffaaaaaaProfessions:|r none required")
    end

    add(" ")

    local _selEquip = FCE.GetCharEquipment(char)
    if #_selEquip > 0 then
        add("|cffffd100Equipment|r")
        for _, eq in ipairs(_selEquip) do
            add("  |cff888888[" .. eq.level .. "]|r " .. eq.desc)
        end
        add(" ")
    end

    if char.challenges and #char.challenges > 0 then
        add("|cffffd100Challenges|r")
        for _, ch in ipairs(char.challenges) do
            local detail = ""
            if FCE.ChallengeDescriptions and FCE.ChallengeDescriptions[ch.desc] then
                detail = "  |cff888888— " .. FCE.ChallengeDescriptions[ch.desc] .. "|r"
            end
            add("  |cff888888[" .. ch.level .. "]|r " .. ch.desc .. detail)
        end
        add(" ")
    end

    -- Optional challenges are shown as radio buttons below (see RefreshDetails)
    if char.optionalChallenges and #char.optionalChallenges > 0 then
        add("|cffffd100Optional Challenge|r  |cff888888(pick one or none)|r")
        add(" ")   -- spacing for the radio buttons that RefreshDetails will place here
    end

    if char.companion then
        add("|cffffd100Companion|r  |cff888888[" .. char.companion.level .. "]|r " .. char.companion.desc)
    end
    if char.pet then
        add("|cffffd100Hunter pet|r  |cff888888[" .. char.pet.level .. "]|r " .. char.pet.desc)
    end
    if char.mount then
        add("|cffffd100Mount|r  |cff888888[" .. char.mount.level .. "]|r " .. char.mount.desc)
    end

    local _selGameplay = FCE.GetCharGameplay and FCE.GetCharGameplay(char) or char.gameplay
    if _selGameplay and _selGameplay ~= "" then
        add(" ")
        add("|cffffd100Gameplay|r  |cffcccccc" .. _selGameplay .. "|r")
    end

    return table.concat(lines, "\n")
end

----------------------------------------------------------------------
-- Rendering
----------------------------------------------------------------------

function UI:RefreshList()
    if not frame or not frame:IsShown() then return end

    local total = #UI.entries
    FauxScrollFrame_Update(frame.scroll, total, LIST_ROWS, ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(frame.scroll)

    for i = 1, LIST_ROWS do
        local row   = frame.rows[i]
        local idx   = offset + i
        local entry = UI.entries[idx]

        if entry then
            row.entry = entry
            local color = classColor(entry.class)
            row.nameText:SetText("|cff" .. color .. entry.name .. "|r")
            row.subText:SetText(entry.spec .. " · " .. entry.race .. " " .. entry.gender)
            row:Show()
            if entry.name == UI.selectedKey then
                row.selTex:Show()
            else
                row.selTex:Hide()
            end
        else
            row.entry = nil
            row:Hide()
        end
    end
end

function UI:RefreshOptionRadios()
    if not frame then return end
    local anySelected = next(UI.selectedOptionalChallenges) ~= nil
    for _, radio in ipairs(frame.optionRadios) do
        if radio.challengeDesc == nil then
            -- "None" checkbox — checked when nothing is selected
            radio:SetChecked(not anySelected)
        else
            radio:SetChecked(UI.selectedOptionalChallenges[radio.challengeDesc] or false)
        end
    end
end

function UI:RefreshDetails()
    if not frame then return end
    local char = UI.selectedKey and FCE.Characters[UI.selectedKey] or nil

    if char then
        local color = classColor(char.class)
        frame.dName:SetText("|cff" .. color .. char.name .. "|r")
        frame.dSub:SetText(char.spec .. " " .. titleCase(char.class))
        frame.selectBtn:Enable()
    else
        frame.dName:SetText("|cffaaaaaaNo selection|r")
        frame.dSub:SetText("")
        frame.selectBtn:Disable()
    end

    local text = buildDetails(char)
    frame.dBody:SetText(text)

    -- Position optional challenge radio buttons
    local optionals = char and char.optionalChallenges or {}
    local totalRadios = #optionals > 0 and (#optionals + 1) or 0  -- +1 for "None"
    local radioHeight = 0

    for i, radio in ipairs(frame.optionRadios) do
        if i <= totalRadios then
            radio:Show()
            radio.label:Show()
            radio.detail:Show()

            if i == 1 then
                -- "None" option
                radio.challengeDesc = nil
                radio.label:SetText("|cffffffffNone|r")
                radio.detail:SetText("|cff888888No optional challenge|r")
            else
                local ch = optionals[i - 1]
                radio.challengeDesc = ch.desc
                radio.label:SetText("|cffffffff" .. ch.desc .. "|r")
                local desc = FCE.ChallengeDescriptions and FCE.ChallengeDescriptions[ch.desc] or ""
                radio.detail:SetText("|cff888888" .. desc .. "|r")
            end

            if radio.challengeDesc == nil then
                radio:SetChecked(next(UI.selectedOptionalChallenges) == nil)
            else
                radio:SetChecked(UI.selectedOptionalChallenges[radio.challengeDesc] or false)
            end

            -- Position below the body text
            local textH = frame.dBody:GetStringHeight() or 0
            local yOff = -(textH + 4 + (i - 1) * 36)
            radio:SetPoint("TOPLEFT", frame.dBody, "TOPLEFT", 2, yOff)
        else
            radio:Hide()
            radio.label:Hide()
            radio.detail:Hide()
        end
    end

    radioHeight = totalRadios * 36

    -- Resize the scroll child so scrolling works correctly
    local h = (frame.dBody:GetStringHeight() or 1) + radioHeight + 12
    frame.dBodyContent:SetHeight(math.max(1, h))
end

function UI:Refresh()
    if not frame then return end

    -- Sync radio buttons
    frame.matchBtn:SetChecked(UI.filterMode == "match")
    frame.classBtn:SetChecked(UI.filterMode == "class")

    UI.entries = collectEntries()

    -- If the currently selected key is no longer in the list, clear it
    local stillThere = false
    for _, e in ipairs(UI.entries) do
        if e.name == UI.selectedKey then stillThere = true break end
    end
    if not stillThere then
        UI.selectedKey = UI.entries[1] and UI.entries[1].name or nil
    end

    self:RefreshList()
    self:RefreshDetails()
end

----------------------------------------------------------------------
-- Commit
----------------------------------------------------------------------

function UI:Commit()
    if not UI.selectedKey then return end
    local char = FCE.Characters[UI.selectedKey]
    if not char then return end

    FCE_CharDB.selectedCharacter = char.key
    FCE_CharDB.manualOverride    = true
    -- Save multi-select challenges as an array
    local selArray = {}
    for desc in pairs(UI.selectedOptionalChallenges) do
        selArray[#selArray + 1] = desc
    end
    FCE_CharDB.selectedChallenges = #selArray > 0 and selArray or nil
    FCE_CharDB.selectedChallenge  = nil  -- clear legacy field
    -- Preserve existing selfFoundChoice when re-picking via /fce pick
    -- (the CatalogUI first-time flow sets this explicitly)

    local challengeMsg = ""
    if #selArray > 0 then
        challengeMsg = " + |cffffd100" .. table.concat(selArray, ", ") .. "|r"
    end
    FCE.Print("Selected enhanced class: |cffffd100" .. char.name .. "|r (" .. char.spec .. ")" .. challengeMsg)

    if FCE.ResyncLevelAlerts then FCE.ResyncLevelAlerts() end
    -- Reset and re-run all checks for the newly selected character
    if FCE.CompanionCheck and FCE.CompanionCheck.ResetWarnings then FCE.CompanionCheck.ResetWarnings() end
    if FCE.HunterPetCheck and FCE.HunterPetCheck.ResetWarnings then FCE.HunterPetCheck.ResetWarnings() end
    if FCE.MountCheck and FCE.MountCheck.ResetWarnings then FCE.MountCheck.ResetWarnings() end
    if FCE.EquipmentCheck and FCE.EquipmentCheck.RunCheck then FCE.EquipmentCheck.RunCheck() end
    if FCE.CompanionCheck and FCE.CompanionCheck.RunCheck then FCE.CompanionCheck.RunCheck() end
    if FCE.HunterPetCheck and FCE.HunterPetCheck.RunCheck then FCE.HunterPetCheck.RunCheck() end
    if FCE.MountCheck and FCE.MountCheck.RunCheck then FCE.MountCheck.RunCheck() end
    if FCE.QuestCheck and FCE.QuestCheck.RunCheck then FCE.QuestCheck.RunCheck() end
    if FCE.DoubtSystem and FCE.DoubtSystem.OnClassChanged then FCE.DoubtSystem.OnClassChanged() end
    if FCE.EventChallenges and FCE.EventChallenges.RefreshChallengeCache then FCE.EventChallenges.RefreshChallengeCache() end
    if FCE.RefreshPanel then FCE.RefreshPanel() end
    if frame then frame:Hide() end
end

----------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------

--- Show the selection UI. If the player already has matches, prefer the
--- "match" filter; otherwise fall back to the full class list.
function FCE.ShowSelectionUI()
    BuildFrame()

    -- Decide initial filter based on how many matches the player has
    local matches = FCE.FindMatchingCharacters()
    if #matches > 0 then
        UI.filterMode = "match"
    else
        UI.filterMode = "class"
    end

    -- Preselect the currently saved character if it's still valid
    if FCE_CharDB and FCE_CharDB.selectedCharacter and FCE.Characters[FCE_CharDB.selectedCharacter] then
        UI.selectedKey = FCE_CharDB.selectedCharacter
        -- Restore multi-select from saved data
        UI.selectedOptionalChallenges = {}
        if FCE_CharDB.selectedChallenges then
            for _, d in ipairs(FCE_CharDB.selectedChallenges) do
                UI.selectedOptionalChallenges[d] = true
            end
        elseif FCE_CharDB.selectedChallenge then
            -- Legacy single-challenge migration
            UI.selectedOptionalChallenges[FCE_CharDB.selectedChallenge] = true
        end
    else
        UI.selectedKey = nil
        UI.selectedOptionalChallenges = {}
    end

    frame:Show()
    UI:Refresh()
end

function FCE.HideSelectionUI()
    if frame then frame:Hide() end
end

function FCE.ToggleSelectionUI()
    if frame and frame:IsShown() then
        frame:Hide()
    else
        FCE.ShowSelectionUI()
    end
end
