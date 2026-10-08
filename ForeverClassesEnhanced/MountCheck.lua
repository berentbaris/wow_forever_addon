----------------------------------------------------------------------
-- ForeverClassesEnhanced — Mount Tracking
--
-- At level 40+, verifies the player owns the correct mount species.
-- In WoW Classic, mounts are items carried in bags.  Detection uses:
--   1. Bag scanning to find mount items by item ID (primary)
--   2. Bag scanning by item name patterns (fallback)
--   3. Buff scanning when mounted (secondary verification)
--
-- Four characters have mount requirements (all at level 40):
--   Hellcaller     → "Wolf"           (Horde wolf mounts)
--   Death Knight   → "Skeletal horse"  (Undead skeletal mounts)
--   Sister of Steel→ "Ram"            (Dwarf ram mounts)
--   Priestess      → "Frostsaber"     (Night Elf cat mounts)
--
-- The addon checks on login, BAG_UPDATE, and mount/dismount events.
-- PASS = correct mount item found in bags (regardless of mounted state).
-- FAIL = no matching mount item in bags at the required level.
--
-- Events:
--   PLAYER_LOGIN, PLAYER_LEVEL_UP, BAG_UPDATE
--   UNIT_AURA (player) — catches wrong-mount warnings while riding
----------------------------------------------------------------------


local GetItemInfo, UnitBuff
    = FCE.Compat.GetItemInfo, FCE.Compat.UnitBuff  -- Forever API shims (ForeverCompat.lua)
FCE = FCE or {}

local MC = {}
FCE.MountCheck = MC

----------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------

local PASS      = "pass"
local FAIL      = "fail"
local UNCHECKED = "unchecked"

----------------------------------------------------------------------
-- Mount database
--
-- Maps spreadsheet description to:
--   spellIDs    : set of accepted mount spell IDs (locale-independent)
--   buffNames   : set of accepted mount buff names (English; fallback)
--   notes       : acquisition tips
--
-- WoW Classic mount spell IDs (verified from Classic DB):
--   These are the "Summon <Mount>" spells, NOT the item IDs.
----------------------------------------------------------------------

MC.MountDB = {
    ["Wolf"] = {
        -- Item IDs: mount items carried in bags
        itemIDs = {
            [1132]  = true,   -- Horn of the Timber Wolf
            [5665]  = true,   -- Horn of the Dire Wolf
            [5668]  = true,   -- Horn of the Brown Wolf
            [18796] = true,   -- Horn of the Swift Brown Wolf
            [18797] = true,   -- Horn of the Swift Timber Wolf
            [18798] = true,   -- Horn of the Swift Gray Wolf
        },
        -- Name patterns for fallback matching (lowercase substrings)
        -- Buff names for wrong-mount detection while riding
        buffNames = {
            ["Timber Wolf"]       = true,
            ["Dire Wolf"]         = true,
            ["Brown Wolf"]        = true,
            ["Swift Brown Wolf"]  = true,
            ["Swift Timber Wolf"] = true,
            ["Swift Gray Wolf"]   = true,
            ["Gray Wolf"]         = true,
        },
        spellIDs = { 580, 6653, 6654, 23250, 23251, 23252 },
        notes = "Orc racial mount — buy from Ogunaro Wolfrunner in Orgrimmar",
    },

    ["Skeletal horse"] = {
        itemIDs = {
            [13331] = true,   -- Red Skeletal Horse
            [13332] = true,   -- Blue Skeletal Horse
            [13333] = true,   -- Brown Skeletal Horse
            [13334] = true,   -- Green Skeletal Warhorse
            [18791] = true,   -- Purple Skeletal Warhorse
            [13335] = true,   -- Deathcharger's Reins (Baron Rivendare)
        },
        buffNames = {
            ["Skeletal Horse"]            = true,
            ["Red Skeletal Horse"]        = true,
            ["Blue Skeletal Horse"]       = true,
            ["Brown Skeletal Horse"]      = true,
            ["Green Skeletal Warhorse"]   = true,
            ["Purple Skeletal Warhorse"]  = true,
            ["Skeletal Warhorse"]         = true,
            ["Deathcharger"]              = true,
        },
        spellIDs = { 8980, 10789, 10790, 10793, 23246, 17462, 17464, 23247 },
        notes = "Undead racial mount — buy from Zachariah Post in Brill",
    },

    ["Horse"] = {
        itemIDs = {
            [5656] = true,   -- Brown Horse Bridle
            [18777] = true,   -- Blue Skeletal Horse
            [18776] = true,   -- Brown Skeletal Horse
            [18778] = true,   -- Green Skeletal Warhorse
            [2411] = true,   -- Purple Skeletal Warhorse
            [5655] = true,   -- Deathcharger's Reins (Baron Rivendare)
            [2414] = true,   -- Deathcharger's Reins (Baron Rivendare)
        },
        itemPatterns = { "skeletal" },
        notes = "Human racial mount — buy from Elwynn Forest",
    },

    ["Ram"] = {
        itemIDs = {
            [5864]  = true,   -- Gray Ram
            [5872]  = true,   -- Brown Ram
            [5873]  = true,   -- White Ram
            [18785] = true,   -- Swift White Ram
            [18786] = true,   -- Swift Brown Ram
            [18787] = true,   -- Swift Gray Ram
            [13328] = true,   -- Black Ram (AV reward)
        },
        buffNames = {
            ["Gray Ram"]         = true,
            ["White Ram"]        = true,
            ["Brown Ram"]        = true,
            ["Swift Brown Ram"]  = true,
            ["Swift Gray Ram"]   = true,
            ["Swift White Ram"]  = true,
            ["Black Ram"]        = true,
            ["Ram"]              = true,
        },
        spellIDs = { 6777, 6898, 6899, 23238, 23239, 23240 },
        notes = "Dwarf racial mount — buy from Veron Amberstill in Dun Morogh",
    },

    ["Frostsaber"] = {
        itemIDs = {
            [8631]  = true,   -- Reins of the Striped Frostsaber
            [8632]  = true,   -- Reins of the Spotted Frostsaber
            [18766] = true,   -- Reins of the Swift Frostsaber
        },
        buffNames = {
            ["Striped Frostsaber"]    = true,
            ["Spotted Frostsaber"]    = true,
            ["Swift Frostsaber"]      = true,
            ["Frostsaber"]            = true,
        },
        spellIDs = { 8394, 6648, 23219, 23221 },
        notes = "Night Elf racial mount — buy from Lelanai in Darnassus",
    },

    ["Nightsaber"] = {
        itemIDs = {
            [8629]  = true,   -- Reins of the Striped Frostsaber
            [18902]  = true,   -- Reins of the Spotted Frostsaber        
        },
        buffNames = {
            ["Striped Nightsaber"]    = true,
            ["Swift Stormsaber"]      = true,
        },
        spellIDs = { 23338, 10793 },
        notes = "Night Elf racial mount — buy from Lelanai in Darnassus",
    },
}

----------------------------------------------------------------------
-- Chat helpers
----------------------------------------------------------------------

local CHAT_PREFIX = "|cff66bbff[FCE]|r "

local function cprint(msg)
    DEFAULT_CHAT_FRAME:AddMessage(CHAT_PREFIX .. tostring(msg))
end

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------

local warnedWrongMount = false

----------------------------------------------------------------------
-- Reset
----------------------------------------------------------------------

function MC.ResetWarnings()
    warnedWrongMount = false
    if FCE_CharDB then
        FCE_CharDB.mountResults = nil
    end
end

----------------------------------------------------------------------
-- Bag scanning — primary mount detection
----------------------------------------------------------------------

--- Scan the player's bags for a mount item matching the given DB entry.
--- Returns itemName, itemID if found, or nil.
local function ScanBagsForMount(entry)
    if not entry then return nil end

    -- Use GetContainerNumSlots / GetContainerItemID (Classic API)
    local getNumSlots = C_Container and C_Container.GetContainerNumSlots
                        or GetContainerNumSlots
    local getItemID   = C_Container and C_Container.GetContainerItemID
                        or GetContainerItemID

    if not getNumSlots or not getItemID then return nil end

    for bag = 0, 4 do
        local numSlots = getNumSlots(bag) or 0
        for slot = 1, numSlots do
            local itemID = getItemID(bag, slot)
            if itemID then
                -- Check against known item IDs (fast path)
                if entry.itemIDs and entry.itemIDs[itemID] then
                    local name = GetItemInfo(itemID)
                    return name or ("Item " .. itemID), itemID
                end

                -- Fallback: check item name against patterns
                if entry.itemPatterns then
                    local name = GetItemInfo(itemID)
                    if name then
                        local lower = name:lower()
                        for _, pattern in ipairs(entry.itemPatterns) do
                            if lower:find(pattern, 1, true) then
                                return name, itemID
                            end
                        end
                    end
                end
            end
        end
    end

    return nil
end

--- Scan ALL bags and return every mount item found (for debug).
--- Returns { { name, itemID, bag, slot }, ... }
local function ScanAllMountItems()
    local results = {}

    local getNumSlots = C_Container and C_Container.GetContainerNumSlots
                        or GetContainerNumSlots
    local getItemID   = C_Container and C_Container.GetContainerItemID
                        or GetContainerItemID

    if not getNumSlots or not getItemID then return results end

    -- Build a quick set of ALL known mount item IDs across all entries
    local allItemIDs = {}
    local allPatterns = {}
    for _, entry in pairs(MC.MountDB) do
        if entry.itemIDs then
            for id in pairs(entry.itemIDs) do allItemIDs[id] = true end
        end
        if entry.itemPatterns then
            for _, p in ipairs(entry.itemPatterns) do
                allPatterns[p] = true
            end
        end
    end

    for bag = 0, 4 do
        local numSlots = getNumSlots(bag) or 0
        for slot = 1, numSlots do
            local itemID = getItemID(bag, slot)
            if itemID then
                local isMount = false
                if allItemIDs[itemID] then
                    isMount = true
                else
                    local name = GetItemInfo(itemID)
                    if name then
                        local lower = name:lower()
                        for p in pairs(allPatterns) do
                            if lower:find(p, 1, true) then
                                isMount = true
                                break
                            end
                        end
                    end
                end
                if isMount then
                    local name = GetItemInfo(itemID) or ("Item " .. itemID)
                    table.insert(results, {
                        name = name, itemID = itemID,
                        bag = bag, slot = slot,
                    })
                end
            end
        end
    end

    return results
end

----------------------------------------------------------------------
-- Buff scanning — secondary check (wrong-mount warning while riding)
----------------------------------------------------------------------

--- Scan player buffs for the active mount buff.
--- Returns buffName, spellID or nil.
local function getActiveMountBuff()
    if not IsMounted or not IsMounted() then return nil end

    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, spellID = UnitBuff("player", i)
        if not name then break end

        -- Check against our mount DB
        for _, entry in pairs(MC.MountDB) do
            if entry.spellIDs then
                for _, sid in ipairs(entry.spellIDs) do
                    if spellID == sid then return name, spellID end
                end
            end
            if entry.buffNames and entry.buffNames[name] then
                return name, spellID
            end
        end
    end

    -- Heuristic fallback for unrecognised mount buffs
    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, spellID = UnitBuff("player", i)
        if not name then break end
        local lower = name:lower()
        if lower:find("wolf") or lower:find("ram") or lower:find("skeletal")
           or lower:find("saber") or lower:find("horse") or lower:find("raptor")
           or lower:find("kodo") or lower:find("mechanostrider")
           or lower:find("mount") or lower:find("riding") then
            return name, spellID
        end
    end

    return nil
end

--- Check if a buff matches a specific mount DB entry.
local function matchesMountEntry(entry, buffName, spellID)
    if not entry then return false end
    if spellID and entry.spellIDs then
        for _, sid in ipairs(entry.spellIDs) do
            if spellID == sid then return true end
        end
    end
    if buffName and entry.buffNames then
        if entry.buffNames[buffName] then return true end
    end
    return false
end

----------------------------------------------------------------------
-- Core check
----------------------------------------------------------------------

function MC.RunCheck()
    if not FCE_CharDB or not FCE_CharDB.selectedCharacter then
        local r = { status = UNCHECKED, detail = "No character selected" }
        if FCE_CharDB then FCE_CharDB.mountResults = r end
        return r
    end

    local char = FCE.GetCharacter(FCE_CharDB.selectedCharacter)
    if not char or not char.mount then
        local r = { status = UNCHECKED, detail = "No mount requirement" }
        FCE_CharDB.mountResults = r
        return r
    end

    local playerLevel = UnitLevel("player") or 1
    if playerLevel < char.mount.level then
        local result = {
            status = UNCHECKED,
            detail = string.format(
                "Mount requirement activates at level %d (currently %d)",
                char.mount.level, playerLevel
            ),
        }
        FCE_CharDB.mountResults = result
        return result
    end

    local mountKey = char.mount.desc   -- e.g. "Wolf", "Ram"
    local dbEntry = MC.MountDB[mountKey]

    if not dbEntry then
        local result = {
            status = UNCHECKED,
            detail = string.format(
                "\"%s\" — not in the mount database yet",
                mountKey
            ),
        }
        FCE_CharDB.mountResults = result
        return result
    end

    -- PRIMARY CHECK: scan bags for the correct mount item
    local foundName, foundID = ScanBagsForMount(dbEntry)

    local result = {}

    if foundName then
        -- Correct mount item is in bags — PASS
        result.status = PASS
        result.detail = string.format(
            "%s found in bags (item %d)",
            foundName, foundID or 0
        )
        result.itemName = foundName
        result.itemID   = foundID
    else
        -- No matching mount item in bags — FAIL
        result.status = FAIL
        result.detail = string.format(
            "No %s mount found in bags. %s",
            mountKey, dbEntry.notes or ""
        )
    end

    -- SECONDARY CHECK: if mounted, verify they're on the RIGHT mount
    -- (they might have multiple mounts — correct one in bags but riding wrong one)
    if IsMounted and IsMounted() then
        local buffName, spellID = getActiveMountBuff()
        if buffName then
            if matchesMountEntry(dbEntry, buffName, spellID) then
                -- Riding the correct mount
                result.status = PASS
                result.detail = string.format(
                    "Riding %s — correct mount!",
                    buffName
                )
                result.buffName = buffName
                result.spellID  = spellID
            elseif result.status == PASS then
                -- Has correct mount in bags but riding the wrong one
                result.status = FAIL
                result.detail = string.format(
                    "Riding %s — wrong mount! Your requirement is a %s. %s",
                    buffName, mountKey, dbEntry.notes or ""
                )
                result.buffName = buffName
                result.spellID  = spellID
            end
        end
    end

    FCE_CharDB.mountResults = result
    return result
end

----------------------------------------------------------------------
-- Warning logic
----------------------------------------------------------------------

local function maybeWarn(result)
    if not result then return end
    if result.status == PASS then
        if warnedWrongMount then
            cprint("|cff00ff00Mount:|r " .. (result.detail or "Correct mount!"))
        end
        warnedWrongMount = false
        return
    end
    if result.status == UNCHECKED then return end

    -- FAIL — wrong mount
    if not warnedWrongMount then
        warnedWrongMount = true
        cprint("|cffffaa33Mount:|r " .. result.detail)
    end
end

----------------------------------------------------------------------
-- Slash command: /fce mount
----------------------------------------------------------------------

function MC.PrintStatus()
    if not FCE_CharDB or not FCE_CharDB.selectedCharacter then
        cprint("No enhanced class selected.")
        return
    end

    local char = FCE.GetCharacter(FCE_CharDB.selectedCharacter)
    if not char or not char.mount then
        cprint("Your enhanced class has no mount requirement.")
        return
    end

    local playerLevel = UnitLevel("player") or 1
    local tag = (playerLevel >= char.mount.level)
        and "|cff00ff00ACTIVE|r"
        or  "|cff888888lv " .. char.mount.level .. "|r"

    cprint("Mount requirement: " .. tag .. " " .. char.mount.desc)

    local dbEntry = MC.MountDB[char.mount.desc]
    if dbEntry then
        if dbEntry.notes then
            cprint("  Note: " .. dbEntry.notes)
        end

        -- Show accepted item IDs
        if dbEntry.itemIDs then
            local ids = {}
            for id in pairs(dbEntry.itemIDs) do
                local name = GetItemInfo(id)
                table.insert(ids, tostring(id) .. (name and (" (" .. name .. ")") or ""))
            end
            table.sort(ids)
            cprint("  Accepted item IDs: " .. table.concat(ids, ", "))
        end
    else
        cprint("  |cffffaa33Not in mount database yet|r")
    end

    -- Bag scan results
    cprint("  --- Bag scan ---")
    local allMounts = ScanAllMountItems()
    if #allMounts == 0 then
        cprint("  No known mount items found in bags")
    else
        for _, m in ipairs(allMounts) do
            cprint(string.format("  Found: %s (ID %d) in bag %d slot %d",
                m.name, m.itemID, m.bag, m.slot))
        end
    end

    -- Current mount status
    if IsMounted and IsMounted() then
        local buffName, spellID = getActiveMountBuff()
        if buffName then
            cprint("  Currently riding: " .. buffName .. (spellID and (" (spell " .. spellID .. ")") or ""))
        else
            cprint("  Currently mounted (buff not identified)")
        end
    else
        cprint("  Currently: not mounted")
    end

    -- Run check
    local result = MC.RunCheck()
    if result.status == PASS then
        cprint("  Status: |cff00ff00" .. (result.detail or "OK") .. "|r")
    elseif result.status == FAIL then
        cprint("  Status: |cffff5555" .. (result.detail or "FAIL") .. "|r")
    else
        cprint("  Status: |cffffaa33" .. (result.detail or "unchecked") .. "|r")
    end
end

----------------------------------------------------------------------
-- Event frame
----------------------------------------------------------------------

local eventFrame = CreateFrame("Frame", "HCE_MountCheckFrame", UIParent)

eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:RegisterEvent("UNIT_AURA")

local bagUpdateThrottle = 0

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if not FCE_CharDB or not FCE_CharDB.selectedCharacter then return end
    local char = FCE.GetCharacter and FCE.GetCharacter(FCE_CharDB.selectedCharacter)
    if not char or not char.mount then return end

    if event == "PLAYER_LOGIN" then
        C_Timer.After(3.0, function()
            local result = MC.RunCheck()
            maybeWarn(result)
            if FCE.RefreshPanel then FCE.RefreshPanel() end
        end)

    elseif event == "PLAYER_LEVEL_UP" then
        C_Timer.After(1.0, function()
            local result = MC.RunCheck()
            maybeWarn(result)
            if FCE.RefreshPanel then FCE.RefreshPanel() end
        end)

    elseif event == "BAG_UPDATE" then
        -- Throttle: BAG_UPDATE fires many times in quick succession
        local now = GetTime()
        if now - bagUpdateThrottle < 1.0 then return end
        bagUpdateThrottle = now
        C_Timer.After(0.5, function()
            local result = MC.RunCheck()
            if FCE.RefreshPanel then FCE.RefreshPanel() end
        end)

    elseif event == "UNIT_AURA" then
        local unit = ...
        if unit == "player" then
            C_Timer.After(0.3, function()
                local result = MC.RunCheck()
                if IsMounted and IsMounted() then
                    maybeWarn(result)
                else
                    warnedWrongMount = false
                end
                if FCE.RefreshPanel then FCE.RefreshPanel() end
            end)
        end
    end
end)
