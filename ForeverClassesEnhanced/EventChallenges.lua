----------------------------------------------------------------------
-- ForeverClassesEnhanced — Event-Based Challenge Tracking
--
-- One-time event challenges that require specific player actions:
--   Voodoo Ritual    → /dance at Jintha'Alor peak with 3 cursed items
--   Gnomish Justice  → Use Universal Remote on Clunk + kill Kovic
--   Scarlet Redemption → Destroy Scarlet Tabard at Light's Hope Chapel
--   The New Plague     → Destroy Nightglow Concoction in Southshore
--                        while under Nature Protection Potion
--
-- Completion is permanent (saved in FCE_CharDB.eventChallenges).
-- Once done, the ChallengeCheck rule returns PASS forever.
----------------------------------------------------------------------


local UnitBuff, UnitDebuff
    = FCE.Compat.UnitBuff, FCE.Compat.UnitDebuff  -- Forever API shims (ForeverCompat.lua)
FCE = FCE or {}

local EC = {}
FCE.EventChallenges = EC

----------------------------------------------------------------------
-- Challenge-active cache (avoids per-event table allocations)
--
-- GetActiveChallenges creates 2 new tables every call.  Combat log
-- fires hundreds of times per second in combat, so calling it per-
-- event creates massive GC pressure that manifests as gradual
-- degradation over an hour-long play session.
-- These flags are refreshed at login and character selection change.
----------------------------------------------------------------------

local challengeCache = {
    masterTrainer  = false,
    masterSmelter  = false,
    insular        = false,
    seekingPardon  = false,
    agnostic       = false,
    xxx            = false,
    tameSonofHakkar    = false,
    tameBloodaxeWorg = false,
}

local function RefreshChallengeCache()
    challengeCache.masterTrainer  = false
    challengeCache.masterSmelter  = false
    challengeCache.insular        = false
    challengeCache.seekingPardon  = false
    challengeCache.agnostic       = false
    challengeCache.xxx            = false
    challengeCache.tameSonofHakkar    = false
    challengeCache.tameBloodaxeWorg = false

    local key = FCE_CharDB and FCE_CharDB.selectedCharacter
    if not key then return end
    local char = FCE.GetCharacter and FCE.GetCharacter(key)
    if not char then return end
    local active = FCE.GetActiveChallenges and FCE.GetActiveChallenges(char)
                   or char.challenges or {}
    for _, ch in ipairs(active) do
        local d = ch.desc
        if     d == "Master Trainer"      then challengeCache.masterTrainer    = true
        elseif d == "Master Smelter"      then challengeCache.masterSmelter    = true
        elseif d == "Insular"             then challengeCache.insular          = true
        elseif d == "Seeking a Pardon"    then challengeCache.seekingPardon    = true
        elseif d == "Agnostic"            then challengeCache.agnostic        = true
        elseif d == "XXX"                 then challengeCache.xxx              = true
        elseif d == "Tame Son of Hakkar"        then challengeCache.tameSonofHakkar      = true
        elseif d == "Tame Bloodaxe Worg"  then challengeCache.tameBloodaxeWorg = true
        end
    end
    -- Sync insular language enforcement with the new challenge state
    if EC.SyncInsularLanguage then EC.SyncInsularLanguage() end
end

EC.RefreshChallengeCache = RefreshChallengeCache

----------------------------------------------------------------------
-- Saved variable access
----------------------------------------------------------------------

local function getDB()
    if not FCE_CharDB then return nil end
    if not FCE_CharDB.eventChallenges then
        FCE_CharDB.eventChallenges = {}
    end
    return FCE_CharDB.eventChallenges
end

--- Check if the selected character has a specific challenge in its list.
local function playerHasChallenge(challengeDesc)
    local key = FCE_CharDB and FCE_CharDB.selectedCharacter
    if not key then return false end
    local char = FCE.GetCharacter and FCE.GetCharacter(key) or nil
    if not char then return false end
    local challenges = FCE.GetActiveChallenges and FCE.GetActiveChallenges(char) or char.challenges or {}
    for _, ch in ipairs(challenges) do
        if ch.desc == challengeDesc then return true end
    end
    return false
end

----------------------------------------------------------------------
-- VOODOO RITUAL
--
-- Dance at the peak of Jintha'Alor in The Hinterlands while wearing
-- at least 3 cursed items (from CuratedItems.cursed_items).
--
-- A ritual button appears when the player enters The Hinterlands.
-- It enables when: (a) at the peak coordinates, (b) 3+ cursed
-- items equipped.  Clicking performs /dance and marks complete.
----------------------------------------------------------------------

local VOODOO_ZONE    = "The Hinterlands"
-- Bounding box around the peak altar of Jintha'Alor
local VOODOO_MIN_X   = 0.56
local VOODOO_MAX_X   = 0.63
local VOODOO_MIN_Y   = 0.76
local VOODOO_MAX_Y   = 0.84
local VOODOO_CURSED  = 3

local ritualFrame    = nil
local ritualTicker   = nil

--- Count cursed items currently equipped.
local function countEquippedCursed()
    local list = FCE.CuratedItems and FCE.CuratedItems.cursed_items
    if not list then return 0 end
    local n = 0
    for slot = 1, 19 do
        local id = GetInventoryItemID("player", slot)
        if id and list[id] then
            n = n + 1
        end
    end
    return n
end

--- Check if player stands at Jintha'Alor peak.
local function isAtPeak()
    if (GetZoneText() or "") ~= VOODOO_ZONE then return false end
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return false end
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return false end
    local x, y = pos:GetXY()
    return x >= VOODOO_MIN_X and x <= VOODOO_MAX_X
       and y >= VOODOO_MIN_Y and y <= VOODOO_MAX_Y
end

--- Build the on-screen ritual button (created once, shown/hidden).
local function CreateRitualFrame()
    if ritualFrame then return end

    local f = CreateFrame("Frame", "HCE_VoodooRitualFrame", UIParent, "BackdropTemplate")
    f:SetSize(280, 120)
    f:SetPoint("TOP", UIParent, "TOP", 0, -180)
    f:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
        tile     = true, tileSize = 32, edgeSize = 24,
        insets   = { left = 6, right = 6, top = 6, bottom = 6 },
    })
    f:SetBackdropColor(0.1, 0.0, 0.15, 0.9)
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetScript("OnEnter", function(self)
        local list = FCE.CuratedItems and FCE.CuratedItems.cursed_items
        if not list or not next(list) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Cursed Items", 0.6, 0.2, 0.8)
        GameTooltip:AddLine(" ")
        for id, desc in pairs(list) do
            local found = false
            for slot = 1, 19 do
                if GetInventoryItemID("player", slot) == id then
                    found = true
                    break
                end
            end
            if found then
                GameTooltip:AddLine(desc, 0, 1, 0, true)
            else
                GameTooltip:AddLine(desc, 0.6, 0.6, 0.6, true)
            end
        end
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() f.dismissed = true; f:Hide() end)

    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText("|cff9933ccVoodoo Ritual|r")

    -- Status lines
    local status = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    status:SetPoint("TOP", title, "BOTTOM", 0, -4)
    status:SetWidth(260)
    status:SetJustifyH("CENTER")
    f.statusText = status

    -- Ritual button
    local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btn:SetSize(180, 28)
    btn:SetPoint("BOTTOM", 0, 14)
    btn:SetText("Perform the Ritual")
    btn:SetScript("OnClick", function()
        DoEmote("DANCE")
        local db = getDB()
        if db then db.voodooRitual = true end
        print("|cff9933cc[FCE]|r |cffffcc00Voodoo Ritual complete!|r The spirits of Jintha'Alor acknowledge your dark dance.")
        f:Hide()
        if FCE.ChallengeCheck and FCE.ChallengeCheck.CheckAndWarn then
            C_Timer.After(0.5, FCE.ChallengeCheck.CheckAndWarn)
        end
    end)
    f.ritualBtn = btn

    f:Hide()
    ritualFrame = f
end

--- Refresh the ritual frame: show/hide, enable/disable button.
local function UpdateRitualFrame()
    if not ritualFrame then return end

    -- Already complete?
    local db = getDB()
    if db and db.voodooRitual then ritualFrame:Hide(); return end

    -- Must have the Voodoo Ritual challenge
    if not playerHasChallenge("Voodoo Ritual") then ritualFrame:Hide(); return end

    -- Zone gate
    if (GetZoneText() or "") ~= VOODOO_ZONE then ritualFrame.dismissed = false; ritualFrame:Hide(); return end

    -- Dismissed by player this visit
    if ritualFrame.dismissed then return end

    -- Show frame in zone; button depends on conditions
    ritualFrame:Show()
    local peak   = isAtPeak()
    local cursed = countEquippedCursed()
    local ready  = peak and cursed >= VOODOO_CURSED

    ritualFrame.ritualBtn:SetEnabled(ready)

    local lines = {}
    if peak then
        lines[#lines + 1] = "|cff00ff00At Jintha'Alor peak|r"
    else
        lines[#lines + 1] = "|cffff5555Travel to the peak of Jintha'Alor|r"
    end
    if cursed >= VOODOO_CURSED then
        lines[#lines + 1] = "|cff00ff00" .. cursed .. " cursed items equipped|r"
    else
        lines[#lines + 1] = "|cffff5555" .. cursed .. "/" .. VOODOO_CURSED .. " cursed items equipped|r"
    end
    ritualFrame.statusText:SetText(table.concat(lines, "\n"))
end

----------------------------------------------------------------------
-- GNOMISH JUSTICE
--
-- Use Gnomish Universal Remote on NPC "Clunk", then defeat
-- "Trade Master Kovic".  Tracked via COMBAT_LOG_EVENT_UNFILTERED.
-- The Clunk-controlled flag persists across sessions so the player
-- can relog between the two steps.
----------------------------------------------------------------------

-- Spell names the Universal Remote may appear as in the combat log
local REMOTE_SPELLS = {
    ["Control Machine"]         = true,
    ["Gnomish Universal Remote"] = true,
}
local REMOTE_SPELL_ID = 9269          -- Control Machine spell ID
local TARGET_CLUNK    = "Clunk"
local TARGET_KOVIC    = "Trade Master Kovic"

local gnomishClunkControlled = false   -- session cache

--- Process a single combat log event.
local function OnCombatLogEvent(sub, sourceGUID, sourceName, destGUID, destName, spellID, spellName)
    local db = getDB()
    if not db then return end
    if db.gnomishJustice then return end  -- already complete

    -- Only track for characters with Gnomish Justice challenge
    if not playerHasChallenge("Gnomish Justice") then return end

    -- Detect Universal Remote on Clunk
    if sub == "SPELL_CAST_SUCCESS" or sub == "SPELL_AURA_APPLIED" then
        if sourceName == UnitName("player") and destName == TARGET_CLUNK then
            if REMOTE_SPELLS[spellName] or spellID == REMOTE_SPELL_ID then
                gnomishClunkControlled = true
                db.gnomishJustice_clunkControlled = true
                print("|cffe6b422[FCE]|r |cff00ff00Clunk has been mind-controlled!|r Now defeat Trade Master Kovic.")
            end
        end
    end

    -- Detect Kovic death
    if sub == "UNIT_DIED" and destName == TARGET_KOVIC then
        local controlled = gnomishClunkControlled or db.gnomishJustice_clunkControlled
        if controlled then
            db.gnomishJustice = true
            print("|cffe6b422[FCE]|r |cffffcc00Gnomish Justice complete!|r Trade Master Kovic has been dealt with.")
            if FCE.ChallengeCheck and FCE.ChallengeCheck.CheckAndWarn then
                C_Timer.After(0.5, FCE.ChallengeCheck.CheckAndWarn)
            end
        end
    end
end

----------------------------------------------------------------------
-- SCARLET REDEMPTION
--
-- At level 60, destroy the Tabard of the Scarlet Crusade (23192)
-- at Light's Hope Chapel in Eastern Plaguelands — renouncing the
-- Crusade after a full career wearing their colours.
----------------------------------------------------------------------

local REDEMPTION_ZONE       = "Eastern Plaguelands"
local REDEMPTION_SUBZONE    = "Light's Hope Chapel"
local REDEMPTION_TABARD_ID  = 23192  -- Tabard of the Scarlet Crusade
local TABARD_SLOT           = 19     -- inventory slot for tabard
-- Bounding box around Light's Hope Chapel
local REDEMPTION_MIN_X      = 0.74
local REDEMPTION_MAX_X      = 0.83
local REDEMPTION_MIN_Y      = 0.51
local REDEMPTION_MAX_Y      = 0.60

local redemptionFrame = nil
local hadTabardAtChapel = false  -- true once we see the tabard while at Light's Hope

--- Find the Scarlet Tabard — check equipped slot first, then bags.
--- Returns "equipped", slot  OR  "bag", bag, slot  OR  nil.
local function findScarletTabard()
    if GetInventoryItemID("player", TABARD_SLOT) == REDEMPTION_TABARD_ID then
        return "equipped", TABARD_SLOT
    end
    for bag = 0, 4 do
        local slots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, slots do
            if C_Container.GetContainerItemID(bag, slot) == REDEMPTION_TABARD_ID then
                return "bag", bag, slot
            end
        end
    end
    return nil
end

--- Check if player is at Light's Hope Chapel.
local function isAtLightsHope()
    if (GetZoneText() or "") ~= REDEMPTION_ZONE then return false end
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return false end
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return false end
    local x, y = pos:GetXY()
    return x >= REDEMPTION_MIN_X and x <= REDEMPTION_MAX_X
       and y >= REDEMPTION_MIN_Y and y <= REDEMPTION_MAX_Y
end

--- Helper: mark Scarlet Redemption complete and clean up.
local function CompleteScarletRedemption()
    local db = getDB()
    if db then db.scarletRedemption = true end
    DoEmote("KNEEL")
    print("|cffcc3333[FCE]|r |cffffcc00Scarlet Redemption complete!|r")
    print("|cffcc3333[FCE]|r You have renounced the Scarlet Crusade at Light's Hope Chapel.")
    if redemptionFrame then redemptionFrame:Hide() end
    hadTabardAtChapel = false
    if FCE.ChallengeCheck and FCE.ChallengeCheck.CheckAndWarn then
        C_Timer.After(0.5, FCE.ChallengeCheck.CheckAndWarn)
    end
    if FCE.RefreshPanel then C_Timer.After(0.6, FCE.RefreshPanel) end
end


--- Build the redemption button.
local function CreateRedemptionFrame()
    if redemptionFrame then return end

    local f = CreateFrame("Frame", "HCE_ScarletRedemptionFrame", UIParent, "BackdropTemplate")
    f:SetSize(280, 145)
    f:SetPoint("TOP", UIParent, "TOP", 0, -180)
    f:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
        tile     = true, tileSize = 32, edgeSize = 24,
        insets   = { left = 6, right = 6, top = 6, bottom = 6 },
    })
    f:SetBackdropColor(0.15, 0.02, 0.02, 0.9)
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() f.dismissed = true; f:Hide() end)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText("|cffcc3333Scarlet Redemption|r")

    local status = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    status:SetPoint("TOP", title, "BOTTOM", 0, -4)
    status:SetWidth(260)
    status:SetJustifyH("CENTER")
    f.statusText = status

    local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btn:SetSize(200, 28)
    btn:SetPoint("BOTTOM", 0, 14)
    btn:SetText("Renounce the Crusade")
    btn:SetScript("OnClick", function()
        local where, a, b = findScarletTabard()
        if not where then
            print("|cffcc3333[FCE]|r Scarlet Tabard not found.")
            return
        end
        if where == "equipped" then
            PickupInventoryItem(a)
        else
            C_Container.PickupContainerItem(a, b)
        end
        DeleteCursorItem()
        CompleteScarletRedemption()
    end)
    f.redemptionBtn = btn

    -- Manual confirm button — shown when tabard is already gone
    local cbtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    cbtn:SetSize(200, 22)
    cbtn:SetPoint("BOTTOM", btn, "TOP", 0, 4)
    cbtn:SetText("I already destroyed it here")
    cbtn:SetNormalFontObject("GameFontHighlightSmall")
    cbtn:SetScript("OnClick", function()
        CompleteScarletRedemption()
    end)
    cbtn:Hide()
    f.confirmBtn = cbtn

    f:Hide()
    redemptionFrame = f
end

--- Refresh the redemption frame state.
local function UpdateRedemptionFrame()
    if not redemptionFrame then return end

    local db = getDB()
    if db and db.scarletRedemption then redemptionFrame:Hide(); return end

    if not playerHasChallenge("Scarlet Redemption") then redemptionFrame:Hide(); return end

    if (GetZoneText() or "") ~= REDEMPTION_ZONE then
        hadTabardAtChapel = false
        redemptionFrame.dismissed = false
        redemptionFrame:Hide()
        return
    end

    -- Dismissed by player this visit
    if redemptionFrame.dismissed then return end

    redemptionFrame:Show()
    local atChapel = isAtLightsHope()
    local hasTabard = findScarletTabard() ~= nil

    -- Track that we saw the tabard while at the chapel
    if atChapel and hasTabard then
        hadTabardAtChapel = true
    end

    -- Auto-complete: tabard disappeared while we were at the chapel
    if atChapel and hadTabardAtChapel and not hasTabard then
        CompleteScarletRedemption()
        return
    end

    local ready = atChapel and hasTabard
    redemptionFrame.redemptionBtn:SetEnabled(ready)

    -- Show/hide the manual confirm button (at chapel, no tabard, not auto-detected)
    if atChapel and not hasTabard and not hadTabardAtChapel then
        redemptionFrame.confirmBtn:Show()
    else
        redemptionFrame.confirmBtn:Hide()
    end

    local lines = {}
    if atChapel then
        lines[#lines + 1] = "|cff00ff00At Light's Hope Chapel|r"
    else
        lines[#lines + 1] = "|cffff5555Travel to Light's Hope Chapel|r"
    end
    if hasTabard then
        lines[#lines + 1] = "|cff00ff00Scarlet Tabard ready|r"
    else
        lines[#lines + 1] = "|cffff5555Scarlet Tabard not found|r"
    end
    redemptionFrame.statusText:SetText(table.concat(lines, "\n"))
end

----------------------------------------------------------------------
-- THE NEW PLAGUE
--
-- Destroy a Nightglow Concoction (item 3451) near the Southshore
-- inn in Hillsbrad Foothills while under the effect of Nature
-- Protection Potion (spell 7254).
--
-- Buildup: Alchemy leveled over many levels to craft the concoction
-- and the protection potion.  Culmination: infiltrate an Alliance
-- town as an Undead Priest and deploy the plague.
----------------------------------------------------------------------

local PLAGUE_ZONE          = "Hillsbrad Foothills"
local PLAGUE_SUBZONE       = "Southshore"
local PLAGUE_ITEM_ID       = 3451   -- Nightglow Concoction
local PLAGUE_BUFF_SPELL_ID = 7254   -- Nature Protection Potion
-- Bounding box near the Southshore inn (tight, not the whole town)
local PLAGUE_MIN_X         = 0.48
local PLAGUE_MAX_X         = 0.53
local PLAGUE_MIN_Y         = 0.56
local PLAGUE_MAX_Y         = 0.62

local plagueFrame = nil

--- Find Nightglow Concoction in bags.  Returns bag, slot or nil.
local function findPlagueItem()
    for bag = 0, 4 do
        local slots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, slots do
            if C_Container.GetContainerItemID(bag, slot) == PLAGUE_ITEM_ID then
                return bag, slot
            end
        end
    end
    return nil, nil
end

--- Check if Nature Protection Potion buff is active.
local function hasNatureProtection()
    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, spellID = UnitBuff("player", i)
        if not name then break end
        if spellID == PLAGUE_BUFF_SPELL_ID then return true end
    end
    return false
end

--- Check if player is near the Southshore inn.
local function isNearSouthshoreInn()
    if (GetZoneText() or "") ~= PLAGUE_ZONE then return false end
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return false end
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return false end
    local x, y = pos:GetXY()
    return x >= PLAGUE_MIN_X and x <= PLAGUE_MAX_X
       and y >= PLAGUE_MIN_Y and y <= PLAGUE_MAX_Y
end

--- Build the plague deployment button.
local function CreatePlagueFrame()
    if plagueFrame then return end

    local f = CreateFrame("Frame", "HCE_NewPlagueFrame", UIParent, "BackdropTemplate")
    f:SetSize(280, 140)
    f:SetPoint("TOP", UIParent, "TOP", 0, -180)
    f:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
        tile     = true, tileSize = 32, edgeSize = 24,
        insets   = { left = 6, right = 6, top = 6, bottom = 6 },
    })
    f:SetBackdropColor(0.05, 0.12, 0.0, 0.9)
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() f.dismissed = true; f:Hide() end)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText("|cff44ff44The New Plague|r")

    local status = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    status:SetPoint("TOP", title, "BOTTOM", 0, -4)
    status:SetWidth(260)
    status:SetJustifyH("CENTER")
    f.statusText = status

    local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btn:SetSize(200, 28)
    btn:SetPoint("BOTTOM", 0, 14)
    btn:SetText("Deploy the Plague")
    btn:SetScript("OnClick", function()
        -- Find and destroy the Nightglow Concoction
        local bag, slot = findPlagueItem()
        if not bag then
            print("|cffe6b422[FCE]|r Nightglow Concoction not found in bags.")
            return
        end
        C_Container.PickupContainerItem(bag, slot)
        DeleteCursorItem()

        local db = getDB()
        if db then db.newPlague = true end
        DoEmote("CACKLE")
        print("|cff44ff44[FCE]|r |cffffcc00The New Plague has been deployed in Southshore!|r")
        print("|cff44ff44[FCE]|r The Royal Apothecary Society's work is complete.")
        f:Hide()
        if FCE.ChallengeCheck and FCE.ChallengeCheck.CheckAndWarn then
            C_Timer.After(0.5, FCE.ChallengeCheck.CheckAndWarn)
        end
    end)
    f.plagueBtn = btn

    f:Hide()
    plagueFrame = f
end

--- Refresh the plague frame state.
local function UpdatePlagueFrame()
    if not plagueFrame then return end

    local db = getDB()
    if db and db.newPlague then plagueFrame:Hide(); return end

    if not playerHasChallenge("The New Plague") then plagueFrame:Hide(); return end

    if (GetZoneText() or "") ~= PLAGUE_ZONE then plagueFrame.dismissed = false; plagueFrame:Hide(); return end

    -- Dismissed by player this visit
    if plagueFrame.dismissed then return end

    plagueFrame:Show()
    local atInn    = isNearSouthshoreInn()
    local hasItem  = (findPlagueItem()) ~= nil
    local hasBuff  = hasNatureProtection()
    local ready    = atInn and hasItem and hasBuff

    plagueFrame.plagueBtn:SetEnabled(ready)

    local lines = {}
    if atInn then
        lines[#lines + 1] = "|cff00ff00Near Southshore inn|r"
    else
        lines[#lines + 1] = "|cffff5555Get closer to the Southshore inn|r"
    end
    if hasItem then
        lines[#lines + 1] = "|cff00ff00Nightglow Concoction in bags|r"
    else
        lines[#lines + 1] = "|cffff5555Nightglow Concoction not in bags|r"
    end
    if hasBuff then
        lines[#lines + 1] = "|cff00ff00Nature Protection active|r"
    else
        lines[#lines + 1] = "|cffff5555Drink Nature Protection Potion|r"
    end
    plagueFrame.statusText:SetText(table.concat(lines, "\n"))
end

----------------------------------------------------------------------
-- DISEASE CLEANSING  (Plagueshifter)
--
-- Cure 10 disease debuffs from self.  Any disease counts toward the
-- generic 8 slots, but 2 mandatory diseases must each be cleansed at
-- least once:
--   Silithid Pox   (spell 8137)
--   Cadaver Worms  (spell 16143)
--
-- Effective progress = min(totalCures, 8 + mandatoryDone).
-- Cleansing 100 random diseases without the mandatory two → 8/10.
--
-- Detection: SPELL_DISPEL in combat log where dest = player and the
-- removed aura was a disease.  We maintain a live set of current
-- disease debuffs via UNIT_AURA scanning (debuffType == "Disease")
-- and check extraSpellId against that set.  Plagueshifter is a Druid
-- (no Cure Disease spell), so item-based cures are the only option.
----------------------------------------------------------------------

local CLEANSE_MANDATORY = {
    [8137]  = "Silithid Pox",
    [16143] = "Cadaver Worms",
}
local CLEANSE_REQUIRED = 10
local CLEANSE_GENERIC  = 8       -- slots filled by any disease

local knownDiseases = {}          -- { [spellID] = true } — live set

--- Rebuild the disease debuff set from current auras.
local function updateDiseaseList()
    wipe(knownDiseases)
    for i = 1, 40 do
        local name, _, _, debuffType, _, _, _, _, _, spellID = UnitDebuff("player", i)
        if not name then break end
        if debuffType == "Disease" then
            knownDiseases[spellID] = true
        end
    end
end

--- Helper: compute effective progress from DB fields.
local function cleanseProgress(db)
    local total = db.diseaseCures or 0
    local mandatory = 0
    if db.cleansedSilithidPox  then mandatory = mandatory + 1 end
    if db.cleansedCadaverWorms then mandatory = mandatory + 1 end
    return math.min(total, CLEANSE_GENERIC + mandatory), mandatory
end

local function OnPlagueshifterCombatLog(sub, destGUID, extraSpellID, extraSpellName)
    local db = getDB()
    if not db then return end

    if not playerHasChallenge("Disease Cleansing") then return end

    local eff = cleanseProgress(db)
    if eff >= CLEANSE_REQUIRED then return end

    if sub ~= "SPELL_DISPEL" then return end
    if destGUID ~= UnitGUID("player") then return end

    -- Must be a disease: either in our live set or a mandatory ID
    if not knownDiseases[extraSpellID] and not CLEANSE_MANDATORY[extraSpellID] then
        return
    end

    local total = (db.diseaseCures or 0) + 1
    db.diseaseCures = total

    if extraSpellID == 8137  then db.cleansedSilithidPox  = true end
    if extraSpellID == 16143 then db.cleansedCadaverWorms = true end

    local effective = cleanseProgress(db)
    local label = extraSpellName or CLEANSE_MANDATORY[extraSpellID] or "Disease"
    print("|cff55cc55[FCE]|r " .. label .. " cleansed! ("
        .. effective .. "/" .. CLEANSE_REQUIRED .. ")")

    if effective >= CLEANSE_REQUIRED then
        print("|cff55cc55[FCE]|r |cffffcc00Disease Cleansing complete!|r")
        if FCE.ChallengeCheck and FCE.ChallengeCheck.CheckAndWarn then
            C_Timer.After(0.5, FCE.ChallengeCheck.CheckAndWarn)
        end
    end
end

----------------------------------------------------------------------
-- NATIVE TONGUE
--
-- The player must speak only their racial language, not the faction
-- lingua franca (Common for Alliance, Orcish for Horde).
-- Forces the chat edit box language directly (like RaceLocked) and
-- monitors outgoing chat as a safety-net violation counter.
----------------------------------------------------------------------

-- Race file token → language name (for display / violation check)
local RACE_LANGUAGE = {
    Human       = "Common",
    Dwarf       = "Dwarven",
    NightElf    = "Darnassian",
    Gnome       = "Gnomish",
    Orc         = "Orcish",
    Troll       = "Zandali",
    Tauren      = "Taurahe",
    Scourge     = "Gutterspeak",
}

-- Race file token → WoW language ID (stable client constants)
local RACE_LANGUAGE_ID = {
    Human    = 7,
    Orc      = 1,
    Dwarf    = 6,
    NightElf = 2,
    Scourge  = 33,
    Tauren   = 3,
    Gnome    = 13,
    Troll    = 14,
}

local nativeTongueRequired = nil   -- language name string
local nativeTongueLangID   = nil   -- numeric language ID
local insularHooksInstalled = false
local insularPollAccum      = 0

local function resolveNativeTongue()
    local _, raceToken = UnitRace("player")
    nativeTongueRequired = RACE_LANGUAGE[raceToken]
    nativeTongueLangID   = RACE_LANGUAGE_ID[raceToken]
    -- Verify the player actually knows this language
    if nativeTongueLangID and GetNumLanguages then
        local found = false
        for i = 1, GetNumLanguages() do
            local _, id = GetLanguageByIndex(i)
            if id == nativeTongueLangID then found = true; break end
        end
        if not found then nativeTongueLangID = nil end
    end
end

--- Returns true if the current character has the Insular challenge active.
--- Uses cached flag (refreshed at login / character change).
local function isInsularActive()
    return challengeCache.insular
end

--- Force every chat edit box to use the racial language.
local function applyInsularLanguage()
    if not nativeTongueRequired or not nativeTongueLangID then return end
    if not NUM_CHAT_WINDOWS then return end
    for i = 1, NUM_CHAT_WINDOWS do
        local eb = _G["ChatFrame" .. i .. "EditBox"]
        if eb then
            eb.language   = nativeTongueRequired
            eb.languageID = nativeTongueLangID
        end
    end
end

local function enforceInsular()
    if not isInsularActive() then return end
    applyInsularLanguage()
end

--- Revert all chat edit boxes to the player's default faction language.
local function revertInsularLanguage()
    if not GetDefaultLanguage then return end
    local defName, defID = GetDefaultLanguage("player")
    if not defName or not NUM_CHAT_WINDOWS then return end
    for i = 1, NUM_CHAT_WINDOWS do
        local eb = _G["ChatFrame" .. i .. "EditBox"]
        if eb then
            eb.language   = defName
            eb.languageID = defID
        end
    end
end

--- Hook the language-changed callback so manual switching is overridden.
local function installInsularHooks()
    if insularHooksInstalled then return end
    insularHooksInstalled = true

    local function afterLangChange()
        if isInsularActive() then
            if C_Timer and C_Timer.After then
                C_Timer.After(0, enforceInsular)
            end
        end
    end
    for _, fname in ipairs({
        "ChatEdit_OnLanguageChanged",
        "ChatFrame_ChatEdit_OnLanguageChanged",
    }) do
        if type(_G[fname]) == "function" then
            hooksecurefunc(fname, afterLangChange)
        end
    end

    -- Poll every 0.25s to catch any edit box that drifts back
    local pollFrame = CreateFrame("Frame")
    pollFrame:SetScript("OnUpdate", function(_, elapsed)
        insularPollAccum = insularPollAccum + (elapsed or 0)
        if insularPollAccum < 0.25 then return end
        insularPollAccum = 0
        if not isInsularActive() then return end
        if not nativeTongueLangID or not NUM_CHAT_WINDOWS then return end
        for i = 1, NUM_CHAT_WINDOWS do
            local eb = _G["ChatFrame" .. i .. "EditBox"]
            if eb and tonumber(eb.languageID) ~= tonumber(nativeTongueLangID) then
                applyInsularLanguage()
                break
            end
        end
    end)
end

--- Called by CHAT_MSG_* events for the player's own messages.
--- Safety net — records violations if something slips past the edit-box
--- enforcement.
local function OnPlayerChat(lang)
    if not nativeTongueRequired then resolveNativeTongue() end
    if not nativeTongueRequired then return end
    if not isInsularActive() then return end

    if not lang or lang == "" then return end  -- no language info, skip

    if lang ~= nativeTongueRequired then
        local db = getDB()
        if db then
            db.nativeTongueViolations = (db.nativeTongueViolations or 0) + 1
            print("|cffff6644[FCE]|r You spoke " .. lang
                .. "! Your native tongue is |cffffcc00" .. nativeTongueRequired
                .. "|r. Type |cffffcc00/fce insular reset|r to reset.")
        end
    end
end

function EC.ResetInsular()
    local db = getDB()
    if db then db.nativeTongueViolations = 0 end
    print("|cffe6b422[FCE]|r Insular violations reset.")
    if FCE.ChallengeCheck and FCE.ChallengeCheck.CheckAndWarn then
        C_Timer.After(0.5, FCE.ChallengeCheck.CheckAndWarn)
    end
end

function EC.CheckNativeTongue()
    if not nativeTongueRequired then resolveNativeTongue() end
    local db = getDB()
    local violations = db and db.nativeTongueViolations or 0
    if violations == 0 then
        return "pass", "Speaking only " .. (nativeTongueRequired or "racial language")
    end
    return "fail", violations .. " violation(s) — spoke Common/Orcish instead of "
        .. (nativeTongueRequired or "racial language")
        .. ".  /fce insular reset"
end

--- Called from RefreshChallengeCache — enforce or revert insular language
--- whenever the active FCE character changes.
function EC.SyncInsularLanguage()
    if not nativeTongueRequired then resolveNativeTongue() end
    if challengeCache.insular then
        installInsularHooks()
        enforceInsular()
    else
        revertInsularLanguage()
    end
end

----------------------------------------------------------------------
-- Public API — called by ChallengeCheck rules
----------------------------------------------------------------------

function EC.CheckVoodooRitual()
    local db = getDB()
    if db and db.voodooRitual then
        return "pass", "Voodoo Ritual completed at Jintha'Alor"
    end

    local parts = {}
    local cursed = countEquippedCursed()
    if cursed > 0 then
        parts[#parts + 1] = cursed .. "/" .. VOODOO_CURSED .. " cursed items"
    end
    if isAtPeak() then
        parts[#parts + 1] = "at peak"
    end

    local detail = "Perform /dance at Jintha'Alor peak with "
        .. VOODOO_CURSED .. " cursed items equipped"
    if #parts > 0 then
        detail = detail .. " (" .. table.concat(parts, ", ") .. ")"
    end
    return "fail", detail
end

function EC.CheckGnomishJustice()
    local db = getDB()
    if db and db.gnomishJustice then
        return "pass", "Gnomish Justice served — Kovic eliminated"
    end

    local parts = {}
    if db and db.gnomishJustice_clunkControlled then
        parts[#parts + 1] = "Clunk controlled"
    else
        parts[#parts + 1] = "Clunk not yet controlled"
    end
    parts[#parts + 1] = "Kovic alive"

    return "fail", "Use Gnomish Universal Remote on Clunk, then defeat Trade Master Kovic ("
        .. table.concat(parts, ", ") .. ")"
end

function EC.CheckScarletRedemption()
    local db = getDB()
    if db and db.scarletRedemption then
        return "pass", "Renounced the Scarlet Crusade at Light's Hope Chapel"
    end

    local parts = {}
    if findScarletTabard() then
        parts[#parts + 1] = "tabard ready"
    else
        parts[#parts + 1] = "need Scarlet Tabard"
    end
    if isAtLightsHope() then
        parts[#parts + 1] = "at Light's Hope"
    end

    return "fail", "Destroy the Scarlet Tabard at Light's Hope Chapel ("
        .. table.concat(parts, ", ") .. ")"
end

function EC.CheckNewPlague()
    local db = getDB()
    if db and db.newPlague then
        return "pass", "The New Plague deployed in Southshore"
    end

    local parts = {}
    if (findPlagueItem()) then
        parts[#parts + 1] = "concoction ready"
    else
        parts[#parts + 1] = "need Nightglow Concoction"
    end
    if hasNatureProtection() then
        parts[#parts + 1] = "protected"
    end
    if isNearSouthshoreInn() then
        parts[#parts + 1] = "at Southshore"
    end

    return "fail", "Destroy Nightglow Concoction near Southshore inn under Nature Protection ("
        .. table.concat(parts, ", ") .. ")"
end

function EC.CheckDiseaseCleansing()
    local db = getDB()
    if not db then return "fail", "Cure 10 diseases (0/10)" end
    local effective, mandatory = cleanseProgress(db)
    if effective >= CLEANSE_REQUIRED then
        return "pass", "Cleansed " .. CLEANSE_REQUIRED .. " diseases"
    end
    local parts = { effective .. "/" .. CLEANSE_REQUIRED }
    if not db.cleansedSilithidPox  then parts[#parts + 1] = "need Silithid Pox"  end
    if not db.cleansedCadaverWorms then parts[#parts + 1] = "need Cadaver Worms" end
    return "fail", "Cure diseases using Jungle Remedy or Restorative Potion ("
        .. table.concat(parts, ", ") .. ")"
end

--- Return cleanse info for tooltip display.
function EC.GetCleanseInfo()
    local db = getDB()
    if not db then return CLEANSE_MANDATORY, CLEANSE_REQUIRED, 0, 0, false, false end
    local effective, mandatory = cleanseProgress(db)
    return CLEANSE_MANDATORY, CLEANSE_REQUIRED, effective,
           db.diseaseCures or 0,
           db.cleansedSilithidPox or false,
           db.cleansedCadaverWorms or false
end

--- Called on /fce reset — only resets Insular violations.
--- Event-based challenges (Voodoo Ritual, Gnomish Justice, Scarlet
--- Redemption, The New Plague, Disease Cleansing) persist through
--- class resets because they represent real in-world actions.
function EC.ResetAll()
    local db = getDB()
    if db then
        db.nativeTongueViolations = nil
    end
    if ritualFrame then UpdateRitualFrame() end
    if redemptionFrame then UpdateRedemptionFrame() end
    if plagueFrame then UpdatePlagueFrame() end
end

----------------------------------------------------------------------
-- MASTER TRAINER
--
-- Pet must use both Bite Rank 8 (17261) and Furious Howl Rank 4
-- (24597) in combat.  Detected via COMBAT_LOG_EVENT_UNFILTERED
-- checking SPELL_CAST_SUCCESS from the player's pet.
-- Each ability is tracked independently; both must fire at least once.
----------------------------------------------------------------------

local MASTER_TRAINER_SPELLS = {
    [17261] = "Bite Rank 8",
    [24597] = "Furious Howl Rank 4",
}

local function OnMasterTrainerCombatLog(sub, sourceGUID, spellID)
    if not challengeCache.masterTrainer then return end

    local db = getDB()
    if not db then return end
    if db.masterTrainer then return end  -- already complete

    if sub ~= "SPELL_CAST_SUCCESS" then return end

    -- Check if source is the player's pet
    local petGUID = UnitGUID("pet")
    if not petGUID or sourceGUID ~= petGUID then return end

    if not MASTER_TRAINER_SPELLS[spellID] then return end

    -- Mark this ability as seen
    if not db.masterTrainerSpells then db.masterTrainerSpells = {} end
    if not db.masterTrainerSpells[spellID] then
        db.masterTrainerSpells[spellID] = true
        print("|cffe6b422[FCE]|r |cff00ff00" .. MASTER_TRAINER_SPELLS[spellID]
            .. " detected!|r")
    end

    -- Check if all abilities seen
    local allDone = true
    for id in pairs(MASTER_TRAINER_SPELLS) do
        if not db.masterTrainerSpells[id] then
            allDone = false
            break
        end
    end

    if allDone then
        db.masterTrainer = true
        print("|cffe6b422[FCE]|r |cffffcc00Master Trainer complete!|r Your pet has mastered all required abilities.")
        if FCE.ChallengeCheck and FCE.ChallengeCheck.CheckAndWarn then
            C_Timer.After(0.5, FCE.ChallengeCheck.CheckAndWarn)
        end
    end
end

function EC.CheckMasterTrainer()
    local db = getDB()
    if db and db.masterTrainer then
        return "pass", "Pet has used all required abilities"
    end

    local parts = {}
    for id, name in pairs(MASTER_TRAINER_SPELLS) do
        if db and db.masterTrainerSpells and db.masterTrainerSpells[id] then
            parts[#parts + 1] = "|cff00ff00" .. name .. "|r"
        else
            parts[#parts + 1] = "|cffff5555" .. name .. "|r"
        end
    end

    return "fail", "Pet must use: " .. table.concat(parts, ", ")
end

----------------------------------------------------------------------
-- SEEKING A PARDON
--
-- Cannot complete ANY quests until a specific pardon quest is done.
--   Horde: { id = 398,  name = "Wanted: Maggot Eye" },
--   Alliance: Wanted: "Hogger" (quest ID 176)
--
-- Detection: QUEST_TURNED_IN — if a non-pardon quest is turned in
-- before the pardon quest is flagged complete, it's a violation.
-- Once the pardon quest is complete, the challenge is permanently
-- passed.
----------------------------------------------------------------------

local PARDON_QUESTS = {
    Horde    = { id = 398,  name = "Wanted: Maggot Eye" },
    Alliance = { id = 176,  name = "Wanted: \"Hogger\"" },
}

--- Returns true if the Seeking a Pardon challenge is active on the
--- current character.  Uses cached flag.
local function isPardonActive()
    return challengeCache.seekingPardon
end

--- Get the pardon quest for the player's faction.
local function getPardonQuest()
    local faction = UnitFactionGroup("player")
    return faction and PARDON_QUESTS[faction]
end

--- Check if the pardon quest is flagged complete on the server.
local function isPardonComplete()
    local pq = getPardonQuest()
    if not pq then return false end
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        return C_QuestLog.IsQuestFlaggedCompleted(pq.id)
    end
    return false
end

--- Called on QUEST_TURNED_IN(questID).
local function OnPardonQuestTurnedIn(questID)
    if not isPardonActive() then return end
    local db = getDB()
    if not db then return end
    if db.seekingPardon then return end  -- already complete

    local pq = getPardonQuest()
    if not pq then return end

    if questID == pq.id then
        -- Pardon quest completed!
        db.seekingPardon = true
        print("|cffe6b422[FCE]|r |cffffcc00Seeking a Pardon complete!|r You have earned your faction's trust.")
        if FCE.ChallengeCheck and FCE.ChallengeCheck.CheckAndWarn then
            C_Timer.After(0.5, FCE.ChallengeCheck.CheckAndWarn)
        end
    else
        -- Violation: turned in a quest before getting the pardon
        db.seekingPardonViolations = (db.seekingPardonViolations or 0) + 1
        print("|cffff6644[FCE]|r Quest turned in before obtaining your pardon! ("
            .. db.seekingPardonViolations .. " violation(s))")
    end
end

function EC.CheckSeekingPardon()
    local db = getDB()
    if db and db.seekingPardon then
        local pq = getPardonQuest()
        return "pass", "Pardon obtained" .. (pq and (" — " .. pq.name) or "")
    end

    -- Also check server-side in case they completed it before the addon was installed
    if isPardonComplete() then
        if db then db.seekingPardon = true end
        local pq = getPardonQuest()
        return "pass", "Pardon obtained" .. (pq and (" — " .. pq.name) or "")
    end

    local pq = getPardonQuest()
    local violations = db and db.seekingPardonViolations or 0
    local detail = "No quests allowed until pardon is obtained"
    if pq then
        detail = detail .. " — complete " .. pq.name
    end
    if violations > 0 then
        detail = detail .. " (" .. violations .. " violation(s))"
    end
    return "fail", detail
end

----------------------------------------------------------------------
-- AGNOSTIC
--
-- No Holy spells until quest "The Test of Righteousness" (ID 1806)
-- is completed.  The spell restriction is enforced by BehavioralCheck;
-- this EventChallenge tracks the quest completion that lifts it.
----------------------------------------------------------------------

local AGNOSTIC_QUEST_ID   = 1806
local AGNOSTIC_QUEST_NAME = "The Test of Righteousness"

local function OnAgnosticQuestTurnedIn(questID)
    if not challengeCache.agnostic then return end
    if questID ~= AGNOSTIC_QUEST_ID then return end

    local db = getDB()
    if not db then return end
    if db.agnostic then return end  -- already complete

    db.agnostic = true
    print("|cffe6b422[FCE]|r |cffffcc00Agnostic complete!|r You may now use Holy spells.")
    if FCE.ChallengeCheck and FCE.ChallengeCheck.CheckAndWarn then
        C_Timer.After(0.5, FCE.ChallengeCheck.CheckAndWarn)
    end
end

function EC.CheckAgnostic()
    local db = getDB()
    if db and db.agnostic then
        return "pass", "Quest complete — " .. AGNOSTIC_QUEST_NAME
    end

    -- Check server-side in case they completed it before addon was installed
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        if C_QuestLog.IsQuestFlaggedCompleted(AGNOSTIC_QUEST_ID) then
            if db then db.agnostic = true end
            return "pass", "Quest complete — " .. AGNOSTIC_QUEST_NAME
        end
    end

    -- Check for behavioral violations — only FAIL if the player
    -- actually cast a forbidden spell.  Having the quest incomplete
    -- is not itself a failure; the player is passing by abstaining.
    local violations = FCE_CharDB and FCE_CharDB.behavioral
                       and FCE_CharDB.behavioral["spellViolation_Agnostic"]
    if violations and violations > 0 then
        return "fail", "No Holy spells until " .. AGNOSTIC_QUEST_NAME
            .. " is completed — cast " .. tostring(violations)
    end
    return "pass", "No Holy spells used — complete " .. AGNOSTIC_QUEST_NAME .. " to unlock them"
end

--- Utility: returns true if the Agnostic event challenge is completed.
function EC.IsAgnosticComplete()
    local db = getDB()
    if db and db.agnostic then return true end
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        return C_QuestLog.IsQuestFlaggedCompleted(AGNOSTIC_QUEST_ID)
    end
    return false
end

----------------------------------------------------------------------
-- MASTER SMELTER
--
-- Player must cast spell 14891 (Smelt Dark Iron).
-- Detected via COMBAT_LOG_EVENT_UNFILTERED → SPELL_CAST_SUCCESS
-- from the player with that spell ID.
----------------------------------------------------------------------

local MASTER_SMELTER_SPELL = 14891

local function OnMasterSmelterCombatLog(sub, sourceGUID, spellID)
    if not challengeCache.masterSmelter then return end

    local db = getDB()
    if not db then return end
    if db.masterSmelter then return end

    if sub ~= "SPELL_CAST_SUCCESS" then return end
    if sourceGUID ~= UnitGUID("player") then return end
    if spellID ~= MASTER_SMELTER_SPELL then return end

    db.masterSmelter = true
    print("|cffe6b422[FCE]|r |cffffcc00Master Smelter complete!|r You have smelted Dark Iron.")
    if FCE.ChallengeCheck and FCE.ChallengeCheck.CheckAndWarn then
        C_Timer.After(0.5, FCE.ChallengeCheck.CheckAndWarn)
    end
end

function EC.CheckMasterSmelter()
    local db = getDB()
    if db and db.masterSmelter then
        return "pass", "Dark Iron smelted"
    end
    return "fail", "Cast Smelt Dark Iron (spell 14891)"
end

----------------------------------------------------------------------
-- XXX
--
-- Kill NPC 3936.  Detected via COMBAT_LOG_EVENT_UNFILTERED →
-- UNIT_DIED where the dest GUID contains the NPC ID.
----------------------------------------------------------------------

local XXX_NPC_ID = 3936

--- Extract NPC ID from a creature GUID (format: Creature-0-...-NPCID-...)
local function npcIDFromGUID(guid)
    if not guid then return nil end
    local _, _, _, _, _, npcID = strsplit("-", guid)
    return tonumber(npcID)
end

local function OnXXXCombatLog(sub, destGUID)
    if not challengeCache.xxx then return end

    local db = getDB()
    if not db then return end
    if db.xxx then return end  -- already complete

    if sub ~= "UNIT_DIED" then return end
    if npcIDFromGUID(destGUID) ~= XXX_NPC_ID then return end

    db.xxx = true
    print("|cffe6b422[FCE]|r |cffffcc00XXX complete!|r")
    if FCE.ChallengeCheck and FCE.ChallengeCheck.CheckAndWarn then
        C_Timer.After(0.5, FCE.ChallengeCheck.CheckAndWarn)
    end
end

function EC.CheckXXX()
    local db = getDB()
    if db and db.xxx then
        return "pass", "Target eliminated"
    end
    return "fail", "Kill the target NPC"
end

----------------------------------------------------------------------
-- TAME BEAST CHALLENGES
--
-- Tracks Tame Beast (spell) cast successes via combat log.
-- Parses NPC ID from destGUID to match specific creatures.
--
-- GUID format in Classic 1.15.x:
--   Creature-0-serverID-instanceID-zoneUID-NPCID-spawnUID
----------------------------------------------------------------------

local TAME_BEAST_SPELL = "Tame Beast"

local TAME_NPC_MAP = {
    [11357]  = "tameSonofHakkar",        -- SonofHakkar (Feralas)
    [9696]  = "tameBloodaxeWorg",   -- Bloodaxe Worg (LBRS)
}

local TAME_DB_KEYS = {
    tameSonofHakkar       = "tameSonofHakkar",
    tameBloodaxeWorg  = "tameBloodaxeWorg",
}

--- Parse NPC ID from a creature GUID.
local function npcIdFromGUID(guid)
    if not guid then return nil end
    local npcId = select(6, strsplit("-", guid))
    return tonumber(npcId)
end

--- Called from the combat log handler when Tame Beast succeeds.
local function OnTameBeastCombatLog(sub, sourceGUID, destGUID, destName, spellName)
    if sub ~= "SPELL_CAST_SUCCESS" then return end
    if spellName ~= TAME_BEAST_SPELL then return end
    if sourceGUID ~= UnitGUID("player") then return end

    local npcId = npcIdFromGUID(destGUID)
    if not npcId then return end

    local cacheKey = TAME_NPC_MAP[npcId]
    if not cacheKey then return end                 -- not a tracked tame
    if not challengeCache[cacheKey] then return end  -- character doesn't need it

    local db = getDB()
    if not db then return end
    if db[cacheKey] then return end  -- already done

    db[cacheKey] = true
    if FCE.Print then
        FCE.Print("|cff00ff00Tame challenge complete:|r " .. (destName or "creature") .. "!")
    end
    if FCE.RefreshPanel then FCE.RefreshPanel() end
end

function EC.CheckTameSonofHakkar()
    local db = getDB()
    if db and db.tameSonofHakkar then
        return "pass", "Son of Hakkar has been tamed"
    end
    return "fail", "Tame Son of Hakkar in Zul'Gurub (NPC 11357)"
end

function EC.CheckTameBloodaxeWorg()
    local db = getDB()
    if db and db.tameBloodaxeWorg then
        return "pass", "Bloodaxe Worg has been tamed"
    end
    return "fail", "Tame a Bloodaxe Worg in Lower Blackrock Spire (NPC 9696)"
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------

local ef = CreateFrame("Frame")
ef:RegisterEvent("PLAYER_LOGIN")
ef:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ef:RegisterEvent("ZONE_CHANGED")
ef:RegisterEvent("ZONE_CHANGED_INDOORS")
ef:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
-- Forever runs Midnight's addon rules: registering the combat log
-- throws and CombatLogGetCurrentEventInfo is unavailable.  Try it (in
-- case a later build allows it); otherwise fall back to the player's
-- and pet's own UNIT_SPELLCAST_SUCCEEDED, which covers every
-- SPELL_CAST_SUCCESS-based challenge.  UNIT_DIED / SPELL_DISPEL based
-- challenges (Gnomish Justice kill, XXX, Disease Cleansing) cannot be
-- detected without the combat log.
do
    -- On Forever, don't even try: a forbidden registration can raise the
    -- "addon blocked" popup.  Only register when the client explicitly
    -- says the event is valid AND the reader function exists.
    local ok, res = false, false
    local allowed = type(CombatLogGetCurrentEventInfo) == "function"
    if allowed and FCE.Compat.IS_FOREVER then
        allowed = C_EventUtils and C_EventUtils.IsEventValid
            and C_EventUtils.IsEventValid("COMBAT_LOG_EVENT_UNFILTERED") or false
    end
    if allowed then
        ok, res = pcall(ef.RegisterEvent, ef, "COMBAT_LOG_EVENT_UNFILTERED")
    end
    FCE.Compat.HAS_COMBAT_LOG = allowed and ok and res ~= false
    if not FCE.Compat.HAS_COMBAT_LOG then
        if ok then pcall(ef.UnregisterEvent, ef, "COMBAT_LOG_EVENT_UNFILTERED") end
        ef:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "pet")
    end
end
ef:RegisterEvent("BAG_UPDATE")
ef:RegisterEvent("UNIT_AURA")
ef:RegisterEvent("CHAT_MSG_SAY")
ef:RegisterEvent("CHAT_MSG_YELL")
ef:RegisterEvent("QUEST_TURNED_IN")

local function UpdateAllFrames()
    if ritualFrame then UpdateRitualFrame() end
    if redemptionFrame then UpdateRedemptionFrame() end
    if plagueFrame then UpdatePlagueFrame() end
end

ef:SetScript("OnEvent", function(_, event, arg1, arg2, arg3)
    if event == "PLAYER_LOGIN" then
        C_Timer.After(3, function()
            RefreshChallengeCache()
            CreateRitualFrame()
            CreateRedemptionFrame()
            CreatePlagueFrame()
            -- Restore persistent clunk flag
            local db = getDB()
            if db and db.gnomishJustice_clunkControlled then
                gnomishClunkControlled = true
            end
            updateDiseaseList()
            UpdateAllFrames()
            -- Insular: resolve racial language and force chat edit boxes
            resolveNativeTongue()
            installInsularHooks()
            enforceInsular()
            -- Periodic coordinate check for ritual UIs (cheap: early-returns when not in zone)
            ritualTicker = C_Timer.NewTicker(2, UpdateAllFrames)
        end)

    elseif event == "ZONE_CHANGED_NEW_AREA"
        or event == "ZONE_CHANGED"
        or event == "ZONE_CHANGED_INDOORS" then
        UpdateAllFrames()

    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        if ritualFrame then UpdateRitualFrame() end

    elseif event == "BAG_UPDATE" then
        if redemptionFrame then UpdateRedemptionFrame() end
        if plagueFrame then UpdatePlagueFrame() end

    elseif event == "UNIT_AURA" then
        if arg1 == "player" then
            if plagueFrame then UpdatePlagueFrame() end
            updateDiseaseList()
        end

    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        -- Extract once; each handler receives only the fields it needs
        local _, sub, _, sourceGUID, sourceName, _, _,
              destGUID, destName, _, _, spellID, spellName,
              _, extraSpellID, extraSpellName = CombatLogGetCurrentEventInfo()
        OnCombatLogEvent(sub, sourceGUID, sourceName, destGUID, destName, spellID, spellName)
        OnPlagueshifterCombatLog(sub, destGUID, extraSpellID, extraSpellName)
        OnMasterTrainerCombatLog(sub, sourceGUID, spellID)
        OnMasterSmelterCombatLog(sub, sourceGUID, spellID)
        OnXXXCombatLog(sub, destGUID)
        OnTameBeastCombatLog(sub, sourceGUID, destGUID, destName, spellName)

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- Forever fallback: synthesize a SPELL_CAST_SUCCESS from our own
        -- (or our pet's) cast.  arg1 = unit, arg2 = castGUID, arg3 = spellID
        local C = FCE.Compat
        local unit, spellID = arg1, C.Plain(arg3)
        if not spellID then return end
        local sourceGUID = C.Plain(UnitGUID(unit))
        local sourceName = C.Plain(UnitName(unit))
        local destGUID   = C.Plain(UnitGUID("target"))
        local destName   = C.Plain(UnitName("target"))
        local spellName  = C.Plain((C.GetSpellInfo(spellID)))
        OnCombatLogEvent("SPELL_CAST_SUCCESS", sourceGUID, sourceName, destGUID, destName, spellID, spellName)
        OnMasterTrainerCombatLog("SPELL_CAST_SUCCESS", sourceGUID, spellID)
        OnMasterSmelterCombatLog("SPELL_CAST_SUCCESS", sourceGUID, spellID)
        OnTameBeastCombatLog("SPELL_CAST_SUCCESS", sourceGUID, destGUID, destName, spellName)

    elseif event == "QUEST_TURNED_IN" then
        OnPardonQuestTurnedIn(arg1)  -- arg1 = questID
        OnAgnosticQuestTurnedIn(arg1)

    elseif event == "CHAT_MSG_SAY" or event == "CHAT_MSG_YELL" then
        -- Insular only tracks /say and /yell — party/raid/guild force the
        -- faction default language server-side, so violations there are
        -- unavoidable and shouldn't count.
        -- arg1 = message, arg2 = sender, arg3 = language
        -- Sender names can be secret strings on Forever — skip if so.
        local playerName = FCE.Compat.Plain(UnitName("player"))
        local sender = FCE.Compat.Plain(arg2)
        local senderBase = sender and sender:match("^([^%-]+)") or ""
        if playerName and senderBase == playerName then
            OnPlayerChat(arg3)
        end
    end
end)
