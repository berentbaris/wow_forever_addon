----------------------------------------------------------------------
-- ForeverClassesEnhanced — Zone-Based Challenge Tracking
--
-- Two kinds of zone tracking live here:
--
-- 1.  HOMEBOUND — a hard restriction.  The player may not leave their
--     home continent (determined by race).  Continent detection uses
--     C_Map.GetBestMapForUnit + C_Map.GetMapInfo hierarchy traversal.
--     Once the player sets foot on the wrong continent the violation is
--     persisted — coming back doesn't clear it.
--
-- 2.  ZONE-VISIT CHALLENGES — thematic gameplay suggestions.  "Anti-
--     undead", "Pro-nature", "Anti-demon", and "Aoe-farmer" each name
--     a set of zones the player is encouraged to visit.  We track which
--     of those zones the player has entered and report progress.
--     These are informational rather than hard pass/fail.
--
-- All continent/zone IDs use WoW Classic uiMapIDs (integers, locale-
-- independent).  Zone names stored alongside are for display only.
----------------------------------------------------------------------

FCE = FCE or {}

local ZC = {}
FCE.ZoneCheck = ZC

----------------------------------------------------------------------
-- Continent uiMapIDs (Classic Era / Season of Discovery)
----------------------------------------------------------------------

local CONTINENT = {
    KALIMDOR         = 1414,
    EASTERN_KINGDOMS = 1415,
}

ZC.CONTINENT = CONTINENT   -- expose for tests / other modules

----------------------------------------------------------------------
-- Race → home continent
-- The four Homebound characters:
--   Warden       (Night Elf)  → Kalimdor
--   Savagekin    (Tauren)     → Kalimdor
--   Templar      (Human)      → Eastern Kingdoms
--   Apothecary   (Undead)     → Eastern Kingdoms
----------------------------------------------------------------------

local RACE_HOME = {
    ["Human"]     = CONTINENT.EASTERN_KINGDOMS,
    ["Dwarf"]     = CONTINENT.EASTERN_KINGDOMS,
    ["Gnome"]     = CONTINENT.EASTERN_KINGDOMS,
    ["Night Elf"] = CONTINENT.KALIMDOR,
    ["Orc"]       = CONTINENT.KALIMDOR,
    ["Troll"]     = CONTINENT.KALIMDOR,
    ["Tauren"]    = CONTINENT.KALIMDOR,
    ["Undead"]    = CONTINENT.EASTERN_KINGDOMS,
}

local CONTINENT_NAME = {
    [CONTINENT.KALIMDOR]         = "Kalimdor",
    [CONTINENT.EASTERN_KINGDOMS] = "Eastern Kingdoms",
}

----------------------------------------------------------------------
-- Dungeon / instance → continent mapping
--
-- Dungeons exist in their own map hierarchy and don't parent up to a
-- continent node.  This table maps dungeon uiMapIDs to the continent
-- where their physical entrance is located.
----------------------------------------------------------------------

local EK = CONTINENT.EASTERN_KINGDOMS
local KA = CONTINENT.KALIMDOR

local INSTANCE_CONTINENT = {
    -- Eastern Kingdoms dungeons
    [225]  = EK,   -- The Stockade (Stormwind)
    [226]  = EK,   -- Gnomeregan (Dun Morogh)
    [229]  = EK,   -- Uldaman (Badlands)
    [230]  = EK,   -- Blackrock Depths (Burning Steppes)
    [228]  = EK,   -- Blackrock Spire (Burning Steppes)
    [250]  = EK,   -- Blackrock Spire Upper
    [232]  = EK,   -- Molten Core (Blackrock Mountain)
    [287]  = EK,   -- Blackwing Lair (Blackrock Mountain)
    [234]  = EK,   -- Scholomance (Western Plaguelands)
    [236]  = EK,   -- Stratholme (Eastern Plaguelands)
    [233]  = EK,   -- Shadowfang Keep (Silverpine Forest)
    [227]  = EK,   -- The Deadmines (Westfall)
    [231]  = EK,   -- Sunken Temple (Swamp of Sorrows)
    [235]  = EK,   -- Naxxramas (Eastern Plaguelands)
    [289]  = EK,   -- Scarlet Monastery - Armory
    [290]  = EK,   -- Scarlet Monastery - Cathedral
    [291]  = EK,   -- Scarlet Monastery - Graveyard
    [292]  = EK,   -- Scarlet Monastery - Library
    [1004] = EK,   -- Scarlet Monastery (combined, Classic Era)
    [431]  = EK,   -- Scarlet Halls
    [476]  = EK,   -- Scarlet Monastery (alternate ID)

    -- Kalimdor dungeons
    [221]  = KA,   -- Blackfathom Deeps (Ashenvale)
    [220]  = KA,   -- Wailing Caverns (The Barrens)
    [222]  = KA,   -- Razorfen Kraul (The Barrens)
    [223]  = KA,   -- Razorfen Downs (The Barrens)
    [224]  = KA,   -- Maraudon (Desolace)
    [237]  = KA,   -- Zul'Farrak (Tanaris)
    [238]  = KA,   -- Dire Maul East (Feralas)
    [239]  = KA,   -- Dire Maul West
    [240]  = KA,   -- Dire Maul North
    [248]  = KA,   -- Onyxia's Lair (Dustwallow Marsh)
    [247]  = KA,   -- Ruins of Ahn'Qiraj (Silithus)
    [319]  = KA,   -- Ahn'Qiraj Temple (Silithus)
    [218]  = KA,   -- Ragefire Chasm (Orgrimmar)

    -- Battlegrounds (neutral — treat as current continent / no violation)
    -- These return nil so homebound check stays "unchecked" inside them.
}

----------------------------------------------------------------------
-- Continent detection via C_Map hierarchy traversal
--
-- Starting from the player's current map, walk parentMapID upward
-- until we find a node with mapType == 2 (Continent).
-- Falls back to the INSTANCE_CONTINENT table for dungeons/raids.
----------------------------------------------------------------------

--- @return number|nil continentMapID, string|nil continentName
function ZC.GetCurrentContinent()
    if not C_Map or not C_Map.GetBestMapForUnit then return nil, nil end

    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return nil, nil end

    -- Walk up parent chain (cycle-safe)
    local guard = 0
    local currentID = mapID
    while currentID and currentID > 0 and guard < 20 do
        guard = guard + 1
        local info = C_Map.GetMapInfo(currentID)
        if not info then break end

        -- mapType 2 == Continent
        if info.mapType == 2 then
            return currentID, info.name
        end

        currentID = info.parentMapID
    end

    -- Hierarchy didn't reach a continent — check dungeon/instance table.
    -- Try the player's immediate mapID first, then walk up again checking
    -- each level against the lookup.
    currentID = mapID
    guard = 0
    while currentID and currentID > 0 and guard < 20 do
        guard = guard + 1
        if INSTANCE_CONTINENT[currentID] then
            local cID = INSTANCE_CONTINENT[currentID]
            return cID, CONTINENT_NAME[cID] or "Unknown"
        end
        local info = C_Map.GetMapInfo(currentID)
        if not info then break end
        currentID = info.parentMapID
    end

    return nil, nil
end

--- @return number|nil continentMapID
function ZC.GetHomeContinent()
    local race = UnitRace("player")
    return RACE_HOME[race]
end

----------------------------------------------------------------------
-- Homebound check
--
-- Returns (status, detail) using the same vocabulary as EquipmentCheck
-- and ChallengeCheck:  "pass", "fail", "unchecked".
--
-- Violation is persistent: once the player leaves the home continent,
-- `FCE_CharDB.homeboundViolated` is set true and stays true even if
-- they return.  The only way to clear it is /fce reset.
----------------------------------------------------------------------

local function ensureHomeboundData()
    if not FCE_CharDB then return end
    if FCE_CharDB.homeboundViolated == nil then
        FCE_CharDB.homeboundViolated = false
    end
end

--- Full Homebound check.
--- @return string status, string detail
function ZC.CheckHomebound()
    ensureHomeboundData()

    local homeCont = ZC.GetHomeContinent()
    if not homeCont then
        return "unchecked", "Could not determine home continent for this race"
    end

    local homeName = CONTINENT_NAME[homeCont] or ("mapID " .. homeCont)

    local currentCont, currentName = ZC.GetCurrentContinent()
    if not currentCont then
        return "unchecked", "Could not detect current continent (home: " .. homeName .. ")"
    end
    currentName = currentName or ("mapID " .. currentCont)

    if currentCont ~= homeCont then
        -- Player is on the wrong continent right now
        if FCE_CharDB then
            FCE_CharDB.homeboundViolated = true
        end
        return "fail",
            "Currently on " .. currentName .. " — must stay on " .. homeName
    end

    -- Currently on home continent — but did we ever leave?
    if FCE_CharDB and FCE_CharDB.homeboundViolated then
        return "fail",
            "Previously left " .. homeName .. " (currently back, but the violation stands)"
    end

    return "pass", "On home continent: " .. homeName
end

----------------------------------------------------------------------
-- Zone-visit tracking
--
-- Each "thematic zone list" maps uiMapIDs to display names.  We
-- record which of these zones the player has entered and report
-- progress counts.  These are informational — not hard pass/fail.
----------------------------------------------------------------------

-- Overworld zone uiMapIDs (Classic Era).
-- Dungeon entrances map to the overworld zone they sit in, which is
-- already on the list where applicable.  Interior dungeon map IDs
-- would need separate lookup tables and aren't worth the complexity
-- for what are essentially gameplay suggestions.

local ZONE_LISTS = {
    ["Anti-undead"] = {
        -- "Tirisfal Glades, Silverpine Forest, DM, SFK, Duskwood,
        --  Zanzil, RFD, ZF, ST, Plaguelands, Argent Dawn"
        -- Overworld zones that contain (or are adjacent to) undead content:
        [1420] = "Tirisfal Glades",
        [1421] = "Silverpine Forest",       -- also SFK entrance
        [1431] = "Duskwood",
        [1422] = "Western Plaguelands",     -- Argent Dawn hub
        [1423] = "Eastern Plaguelands",     -- Argent Dawn hub
    },

    ["Pro-nature"] = {
        -- "Mulgore, Barrens, Stonetalon Mountains, Stranglethorn Vale"
        [1412] = "Mulgore",
        [1413] = "The Barrens",
        [1442] = "Stonetalon Mountains",
        [1434] = "Stranglethorn Vale",
    },

    ["Anti-demon"] = {
        -- "Durotar, Teldrassil, RFC, Darkshore, BFD, Ashenvale,
        --  Felwood, Blasted Lands, Winterspring"
        [1440] = "Ashenvale",
        [1448] = "Felwood",
        [1419] = "Blasted Lands",
        [1452] = "Winterspring",
    },
}

ZC.ZONE_LISTS = ZONE_LISTS  -- expose for other modules

----------------------------------------------------------------------
-- Saved-variable helpers
----------------------------------------------------------------------

local function ensureZoneData()
    if not FCE_CharDB then return end
    if not FCE_CharDB.visitedZones then
        FCE_CharDB.visitedZones = {}
    end
end

----------------------------------------------------------------------
-- Get the player's current zone-level uiMapID
-- (If the player is in a subzone or dungeon floor, walk up to the
--  nearest zone-level map — mapType 3.)
----------------------------------------------------------------------

local function getCurrentZoneMap()
    if not C_Map or not C_Map.GetBestMapForUnit then return nil, nil end

    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return nil, nil end

    local info = C_Map.GetMapInfo(mapID)
    if not info then return nil, nil end

    -- Already at zone level (type 3) or continent (type 2)
    if info.mapType and info.mapType <= 3 then
        return mapID, info.name or ""
    end

    -- Walk up from deeper levels (dungeon floors, micro zones, etc.)
    local guard = 0
    local cid = info.parentMapID
    while cid and cid > 0 and guard < 15 do
        guard = guard + 1
        local pInfo = C_Map.GetMapInfo(cid)
        if not pInfo then break end
        if pInfo.mapType == 3 then
            return cid, pInfo.name or ""
        end
        -- Don't go higher than zone level
        if pInfo.mapType and pInfo.mapType < 3 then break end
        cid = pInfo.parentMapID
    end

    -- Fallback: return the original map (might be a dungeon-level map)
    return mapID, info.name or ""
end

----------------------------------------------------------------------
-- Record the current zone and notify if it's on a thematic list
----------------------------------------------------------------------

local CHAT_PREFIX = "|cffe6b422[FCE]|r "

--- Record the player's current zone.  If it's new and belongs to a
--- thematic zone list, print an informational message.
function ZC.RecordCurrentZone()
    ensureZoneData()
    if not FCE_CharDB then return end

    local zoneID, zoneName = getCurrentZoneMap()
    if not zoneID then return end

    -- Already recorded?
    if FCE_CharDB.visitedZones[zoneID] then return end

    -- Record it
    FCE_CharDB.visitedZones[zoneID] = zoneName

    -- Check each thematic list for a match and notify
    for listName, zones in pairs(ZONE_LISTS) do
        if zones[zoneID] then
            -- Only notify if the player has a challenge or gameplay tip
            -- referencing this list.  We check both challenge descriptions
            -- and the gameplay string.
            if ZC.IsListRelevant(listName) then
                DEFAULT_CHAT_FRAME:AddMessage(
                    CHAT_PREFIX .. "|cff88ccff" .. listName .. ":|r Entered "
                    .. zoneName .. " — a thematic zone for your character."
                )
            end
        end
    end
end

--- Check if a zone list name is relevant to the current character.
--- Matches against challenge descriptions AND the gameplay tips string.
function ZC.IsListRelevant(listName)
    if not FCE_CharDB or not FCE_CharDB.selectedCharacter then return false end
    local char = FCE.GetCharacter and FCE.GetCharacter(FCE_CharDB.selectedCharacter)
    if not char then return false end

    local listLower = listName:lower()

    -- Check challenges (including selected optional challenge)
    local activeChallenges = FCE.GetActiveChallenges and FCE.GetActiveChallenges(char) or char.challenges or {}
    for _, ch in ipairs(activeChallenges) do
        if ch.desc:lower() == listLower then return true end
    end

    -- Check gameplay tips (e.g. "Anti-undead", "Pro-nature", "Aoe-farmer")
    local _zcGameplay = FCE.GetCharGameplay and FCE.GetCharGameplay(char) or char.gameplay
    if _zcGameplay then
        if _zcGameplay:lower():find(listLower, 1, true) then return true end
    end

    return false
end

----------------------------------------------------------------------
-- Progress query for a specific zone list
--
-- Returns:  visitedCount, totalCount, visitedNames{}, unvisitedNames{}
----------------------------------------------------------------------

function ZC.GetZoneProgress(listName)
    local zones = ZONE_LISTS[listName]
    if not zones then return 0, 0, {}, {} end

    ensureZoneData()
    local savedZones = FCE_CharDB and FCE_CharDB.visitedZones or {}

    local visitedNames   = {}
    local unvisitedNames = {}
    local total = 0
    local count = 0

    for mapID, name in pairs(zones) do
        total = total + 1
        if savedZones[mapID] then
            count = count + 1
            table.insert(visitedNames, name)
        else
            table.insert(unvisitedNames, name)
        end
    end

    table.sort(visitedNames)
    table.sort(unvisitedNames)

    return count, total, visitedNames, unvisitedNames
end

----------------------------------------------------------------------
-- Reset (called on character pick / /fce reset)
----------------------------------------------------------------------

function ZC.ResetTracking()
    if FCE_CharDB then
        FCE_CharDB.visitedZones = {}
        FCE_CharDB.homeboundViolated = false
    end
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------

local zoneFrame = CreateFrame("Frame", "HCE_ZoneFrame", UIParent)
zoneFrame:RegisterEvent("PLAYER_LOGIN")
zoneFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
zoneFrame:RegisterEvent("ZONE_CHANGED")

local zoneInitialized = false

zoneFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        -- Deferred so SavedVariables and C_Map are ready
        C_Timer.After(3.0, function()
            ensureHomeboundData()
            ensureZoneData()
            ZC.RecordCurrentZone()
            zoneInitialized = true

            -- Run an initial Homebound check (ChallengeCheck will pick up
            -- the result on its own deferred init, but an explicit poke
            -- here covers race conditions)
            if FCE.ChallengeCheck and FCE.ChallengeCheck.RunCheck then
                FCE.ChallengeCheck.RunCheck()
            end
            if FCE.RefreshPanel then FCE.RefreshPanel() end
        end)

    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" then
        if not zoneInitialized then return end
        -- Short delay so the C_Map data has settled after a zone transition
        C_Timer.After(0.5, function()
            ZC.RecordCurrentZone()

            -- Recheck challenges (Homebound reacts to zone changes)
            if FCE.ChallengeCheck and FCE.ChallengeCheck.CheckAndWarn then
                FCE.ChallengeCheck.CheckAndWarn()
            end
        end)
    end
end)

----------------------------------------------------------------------
-- Slash command: /fce zones
----------------------------------------------------------------------

function ZC.PrintStatus()
    if not FCE_CharDB then
        if FCE.Print then FCE.Print("No character data.") end
        return
    end

    -- Homebound
    local hStatus, hDetail = ZC.CheckHomebound()
    local hTag
    if hStatus == "pass" then
        hTag = "|cff00ff00OK|r"
    elseif hStatus == "fail" then
        hTag = "|cffff5555FAIL|r"
    else
        hTag = "|cffffaa33???|r"
    end
    FCE.Print("Homebound: " .. hTag .. " — " .. hDetail)

    -- Zone-visit progress for each thematic list
    FCE.Print("Zone visit progress:")
    for listName, _ in pairs(ZONE_LISTS) do
        local count, total, visited, unvisited = ZC.GetZoneProgress(listName)
        local relevant = ZC.IsListRelevant(listName)
        local relevantTag = relevant and "" or " |cff888888(not relevant to your character)|r"

        FCE.Print("  " .. listName .. ": " .. count .. "/" .. total .. " zones" .. relevantTag)
        if #visited > 0 then
            FCE.Print("    |cff00ff00Visited:|r " .. table.concat(visited, ", "))
        end
        if #unvisited > 0 then
            FCE.Print("    |cff888888Remaining:|r " .. table.concat(unvisited, ", "))
        end
    end
end
