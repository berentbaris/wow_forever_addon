----------------------------------------------------------------------
-- ForeverClassesEnhanced — Companion (Non-Combat Pet) Tracking
--
-- Detects whether the player has the correct vanity pet summoned
-- once they reach the required level.  Uses the "critter" unit
-- token (available in WoW Classic for summoned non-combat pets).
--
-- Detection strategy:
--   1. UnitExists("critter") + UnitName("critter") to identify the
--      active companion by creature name.
--   2. A mapping from the spreadsheet's short description ("Owl",
--      "Black cat", etc.) to the set of matching creature names
--      and the companion item IDs that summon them.
--   3. Bag scanning for companion items to check whether the player
--      even owns a matching pet item (informational).
--
-- The addon is casual/fun — it doesn't enforce "always summoned".
-- Instead it:
--   • Checks on login, level-up, and periodically (60s heartbeat)
--   • Shows a gentle chat reminder if the correct pet isn't out
--   • Shows ✓/✗/? in the requirements panel
--   • Fires a soft chat warning (not the red forbidden-alert toast)
--
-- Events:
--   PLAYER_LOGIN, PLAYER_LEVEL_UP   — initial/level-up checks
--   COMPANION_UPDATE (if available)  — companion summon/dismiss
--   UNIT_PET                         — fallback for pet changes
----------------------------------------------------------------------


local GetItemInfo
    = FCE.Compat.GetItemInfo  -- Forever API shims (ForeverCompat.lua)
FCE = FCE or {}

local CC = {}
FCE.CompanionCheck = CC

----------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------

local PASS      = "pass"
local FAIL      = "fail"
local UNCHECKED = "unchecked"

----------------------------------------------------------------------
-- Companion database
--
-- Maps the short description from CharacterData ("Owl", "Black cat",
-- etc.) to a table with:
--   creatureNames : set of creature names UnitName("critter") may
--                   return (English; locale note below)
--   itemIDs       : list of item IDs that summon a matching pet
--                   (used for bag scanning — "do you even own one?")
--   notes         : human-readable note for tooltips
--
-- LOCALE NOTE: UnitName returns localised strings. The creature-name
-- sets here are English.  For non-English clients the name match will
-- fail and we fall back to item-based bag scanning, which is locale-
-- independent (item IDs are integers). The worst case is UNCHECKED,
-- never a false FAIL.
----------------------------------------------------------------------

CC.CompanionDB = {
    ["Owl"] = {
        creatureNames = {
            ["Great Horned Owl"] = true,
            ["Hawk Owl"]         = true,
        },
        itemIDs = {
            8500,   -- Great Horned Owl (Alliance vendor, Darnassus)
            8501,   -- Hawk Owl         (Alliance vendor, Darnassus)
        },
        notes = "Great Horned Owl or Hawk Owl — sold by Shylenai in Darnassus",
    },

    ["Bird"] = {
        creatureNames = {
            ["Great Horned Owl"] = true,
            ["Hawk Owl"]         = true,
            ["Cockatiel"]        = true,
            ["Senegal"]          = true,
            ["Green Wing Macaw"] = true,
        },
        itemIDs = {
            8500,   -- Great Horned Owl (Alliance vendor, Darnassus)
            8501,   -- Hawk Owl         (Alliance vendor, Darnassus)
            8495,   -- Cockatiel           (vendor, Narkk in Booty Bay)
            8496,   -- Senegal             (vendor, Narkk in Booty Bay)
            8492,   -- Green Wing Macaw    (drop, Deadmines pirates)
        },
        notes = "Any Owl or Parrot",
    },

    ["Black cat"] = {
        creatureNames = {
            ["Black Tabby"]  = true,   -- Black Tabby Cat (drop)
            ["Bombay"]       = true,   -- Bombay Cat (vendor)
            ["Black Tabby Cat"] = true, -- alternate name variant
        },
        itemIDs = {
            8491,   -- Black Tabby Cat  (world drop, Dalaran cats)
            8485,   -- Bombay Cat       (vendor, Donni Anthania in Elwynn)
        },
        notes = "Black Tabby Cat (rare drop) or Bombay Cat (vendor in Elwynn Forest)",
    },

    ["Cat"] = {
        itemIDs = {
            8491,   -- Black Tabby Cat  (world drop, Dalaran cats)
            8485,   -- Bombay Cat       (vendor, Donni Anthania in Elwynn)
            8486,
            8487,
            8490,
            8488,
            8489,
        },
        notes = "Vendor in Elwynn Forest or Dalaran Spellscribe drop",
    },

    ["Parrot"] = {
        creatureNames = {
            ["Cockatiel"]        = true,
            ["Senegal"]          = true,
            ["Green Wing Macaw"] = true,
        },
        itemIDs = {
            8495,   -- Cockatiel           (vendor, Narkk in Booty Bay)
            8496,   -- Senegal             (vendor, Narkk in Booty Bay)
            8492,   -- Green Wing Macaw    (drop, Deadmines pirates)
        },
        notes = "Cockatiel, Senegal, or Green Wing Macaw — Booty Bay vendor or Deadmines drop",
    },

    ["Faerie dragon"] = {
        creatureNames = {
            ["Sprite Darter Egg"]        = true,
        },
        itemIDs = {
            11474,
        },
        notes = "Becoming a Parent quest starting in Feralas",
    },

    ["Any companion"] = {
        itemIDs = {
            11474,
            8495,   -- Cockatiel           (vendor, Narkk in Booty Bay)
            8496,   -- Senegal             (vendor, Narkk in Booty Bay)
            8492,   -- Green Wing Macaw    (drop, Deadmines pirates)
            8491,   -- Black Tabby Cat  (world drop, Dalaran cats)
            8485,   -- Bombay Cat       (vendor, Donni Anthania in Elwynn)
            8486,
            8487,
            8490,
            8488,
            8489,
            10393,
            10394,
            8497,
            10392,
            8500,   -- Great Horned Owl (Alliance vendor, Darnassus)
            8501,   -- Hawk Owl         (Alliance vendor, Darnassus)
            10360, --black snake
            10361, --brown snake
            13583, --panda
            11026, --frog
            11027, --frog
            19450, --jubling
        },
        notes = "Any non-mechanical companion (owls, cats, frogs, parrots, etc.)",
    },

    ["Frog"] = {
        itemIDs = {
            11026, --frog
            11027, --frog
            19450, --jubling
        },
        notes = "Any frog (Wood, Tree, or Jubling) from the Darkmoon Faire",
    },

    ["Prairie dog"] = {
        creatureNames = {
            ["Prairie Dog"]      = true,
        },
        itemIDs = {
            10394,  -- Prairie Dog Whistle (vendor, Halpa in Thunder Bluff)
        },
        notes = "Prairie Dog Whistle — sold by Halpa in Thunder Bluff",
    },

    ["Cockroach"] = {
        creatureNames = {
            ["Cockroach"]            = true,
            ["Undercity Cockroach"]   = true,
        },
        itemIDs = {
            10393,  -- Undercity Cockroach (vendor, Jeremiah Payson in Undercity)
        },
        notes = "Undercity Cockroach — sold by Jeremiah Payson in Undercity",
    },

    ["Phoenix"] = {
        -- No direct "Phoenix" companion pet exists in Classic WoW.
        -- Closest thematic matches: Crimson Whelpling (fire-breathing
        -- dragonkin), Firefly (if Outland patch), or the Disgusting
        -- Oozeling (not really).  We include Crimson Whelpling as the
        -- best-fit fire-themed companion available in Classic era.
        creatureNames = {
            ["Great Horned Owl"] = true,
        },
        itemIDs = {
            8500,   -- Great Horned Owl (Alliance vendor, Darnassus)
        },
        notes = "Great Horned Owl (trade to Horde via goblin auction house)",
    },

    ["Mechanical"] = {
        creatureNames = {
            ["Mechanical Squirrel"]  = true,
            ["Pet Bombling"]         = true,
            ["Lil' Smoky"]           = true,
            ["Mechanical Chicken"]   = true,
        },
        itemIDs = {
            4401,   -- Mechanical Squirrel Box  (Engineering craft)
            11825,  -- Pet Bombling             (Engineering craft)
            11826,  -- Lil' Smoky               (Engineering craft)
            10398,  -- Mechanical Chicken        (quest chain reward)
        },
        notes = "Any mechanical companion — Squirrel, Bombling, Lil' Smoky, or Chicken (Engineering-themed)",
    },

    ["Snow rabbit"] = {
        creatureNames = {
            ["Snowshoe Rabbit"]  = true,
            ["Rabbit"]           = true,   -- generic variant
        },
        itemIDs = {
            8497,   -- Snowshoe Rabbit  (vendor, Yarlyn Amberstill in Dun Morogh)
        },
        notes = "Snowshoe Rabbit — sold by Yarlyn Amberstill in Dun Morogh",
    },

    ["Crimson snake"] = {
        creatureNames = {
            ["Crimson snake"]  = true,
        },
        itemIDs = {
            10392,   -- Snowshoe Rabbit  (vendor, Yarlyn Amberstill in Dun Morogh)
        },
        notes = "Crimson snake — sold by Xan'tish in Orgrimmar",
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

-- Per-session warning suppression so we don't nag every 60 seconds.
local warnedNoCompanion  = false
local warnedWrongCompanion = false
local warnedNotOwned     = false

----------------------------------------------------------------------
-- Reset (called on /fce pick, /fce reset)
----------------------------------------------------------------------

function CC.ResetWarnings()
    warnedNoCompanion  = false
    warnedWrongCompanion = false
    warnedNotOwned     = false
    if FCE_CharDB then
        FCE_CharDB.companionResults = nil
    end
end

----------------------------------------------------------------------
-- Core detection
----------------------------------------------------------------------

--- Get the currently summoned critter's name (nil if none).
local function getCritterName()
    if not UnitExists("critter") then return nil end
    local name = UnitName("critter")
    return name
end

--- Scan bags for any item whose ID is in the given list.
--- Returns the first matching item ID found, or nil.
local function findCompanionItemInBags(itemIDs)
    if not itemIDs or #itemIDs == 0 then return nil end
    local lookup = {}
    for _, id in ipairs(itemIDs) do lookup[id] = true end

    for bag = 0, 4 do
        local numSlots = C_Container and C_Container.GetContainerNumSlots
            and C_Container.GetContainerNumSlots(bag)
            or (GetContainerNumSlots and GetContainerNumSlots(bag))
            or 0
        for slot = 1, numSlots do
            local itemID
            if C_Container and C_Container.GetContainerItemID then
                itemID = C_Container.GetContainerItemID(bag, slot)
            elseif GetContainerItemID then
                itemID = GetContainerItemID(bag, slot)
            end
            if itemID and lookup[itemID] then
                return itemID
            end
        end
    end
    return nil
end

--- Main check routine.  Returns { status, detail, critterName, owned }
function CC.RunCheck()
    if not FCE_CharDB or not FCE_CharDB.selectedCharacter then
        local r = { status = UNCHECKED, detail = "No character selected" }
        if FCE_CharDB then FCE_CharDB.companionResults = r end
        return r
    end

    local char = FCE.GetCharacter(FCE_CharDB.selectedCharacter)
    if not char or not char.companion then
        local r = { status = UNCHECKED, detail = "No companion requirement" }
        FCE_CharDB.companionResults = r
        return r
    end

    local playerLevel = UnitLevel("player") or 1
    if playerLevel < char.companion.level then
        local r = {
            status = UNCHECKED,
            detail = string.format(
                "Companion requirement activates at level %d (currently %d)",
                char.companion.level, playerLevel
            ),
        }
        FCE_CharDB.companionResults = r
        return r
    end

    local companionKey = char.companion.desc   -- e.g. "Owl", "Black cat"
    local dbEntry = CC.CompanionDB[companionKey]

    if not dbEntry then
        local r = {
            status = UNCHECKED,
            detail = string.format(
                "\"%s\" — not in the companion database yet",
                companionKey
            ),
        }
        FCE_CharDB.companionResults = r
        return r
    end

    -- PRIMARY CHECK: scan bags for a matching companion item
    local ownedItemID = findCompanionItemInBags(dbEntry.itemIDs)

    -- SECONDARY: check what critter is currently out (informational)
    local critterName = getCritterName()

    -- Build result — owning the item in bags is sufficient for PASS
    local result = {
        critterName = critterName,
        ownedItemID = ownedItemID,
    }

    if ownedItemID then
        local itemName = GetItemInfo(ownedItemID)
        result.status = PASS
        result.detail = string.format(
            "%s found in bags (item %d)",
            itemName or companionKey, ownedItemID
        )
    elseif critterName and dbEntry.creatureNames[critterName] then
        -- Item not in bags but correct companion is summoned (consumed item?)
        result.status = PASS
        result.detail = string.format(
            "%s is summoned — correct companion!",
            critterName
        )
    else
        result.status = FAIL
        result.detail = string.format(
            "No %s companion item found in bags. %s",
            companionKey,
            dbEntry.notes or ""
        )
    end

    -- Store in SavedVars for panel display
    FCE_CharDB.companionResults = result

    return result
end

----------------------------------------------------------------------
-- Warning logic (soft chat messages, not red alerts)
----------------------------------------------------------------------

local function maybeWarn(result)
    if not result then return end
    if result.status == PASS or result.status == UNCHECKED then
        -- Reset "wrong" warnings on pass so re-summoning gets acknowledged
        warnedWrongCompanion = false
        warnedNoCompanion    = false
        return
    end

    -- status == FAIL
    if not result.critterName then
        -- No companion out
        if not warnedNoCompanion then
            warnedNoCompanion = true
            cprint("|cffffaa33Companion:|r " .. result.detail)
        end
    else
        -- Wrong companion out
        if not warnedWrongCompanion then
            warnedWrongCompanion = true
            cprint("|cffffaa33Companion:|r " .. result.detail)
        end
    end

    -- "You don't own one" — mention once
    if not result.ownedItemID and not warnedNotOwned then
        warnedNotOwned = true
        local char = FCE.GetCharacter(FCE_CharDB.selectedCharacter)
        if char and char.companion then
            local dbEntry = CC.CompanionDB[char.companion.desc]
            if dbEntry and dbEntry.notes then
                cprint("|cff888888Where to get one:|r " .. dbEntry.notes)
            end
        end
    end
end

----------------------------------------------------------------------
-- Periodic heartbeat
-- A gentle 60-second timer that re-checks companion status.
-- This catches summon/dismiss that may not fire a clean event.
----------------------------------------------------------------------

local heartbeatHandle = nil

local function heartbeat()
    if not FCE_CharDB or not FCE_CharDB.selectedCharacter then return end
    local char = FCE.GetCharacter(FCE_CharDB.selectedCharacter)
    if not char or not char.companion then return end

    local result = CC.RunCheck()
    -- Only warn once per session per state — RunCheck stores in SavedVars
    -- so the panel always has fresh data.  We don't re-nag here;
    -- warnings already fired from the initial check or event-driven path.

    -- Refresh the panel if it's visible
    if FCE.RefreshPanel then FCE.RefreshPanel() end
end

local function startHeartbeat()
    if heartbeatHandle then return end
    -- C_Timer.NewTicker returns a handle; 60s interval, runs forever
    if C_Timer and C_Timer.NewTicker then
        heartbeatHandle = C_Timer.NewTicker(60, heartbeat)
    end
end

local function stopHeartbeat()
    if heartbeatHandle then
        heartbeatHandle:Cancel()
        heartbeatHandle = nil
    end
end

----------------------------------------------------------------------
-- Slash command: /fce companion
----------------------------------------------------------------------

function CC.PrintStatus()
    if not FCE_CharDB or not FCE_CharDB.selectedCharacter then
        cprint("No enhanced class selected.")
        return
    end

    local char = FCE.GetCharacter(FCE_CharDB.selectedCharacter)
    if not char or not char.companion then
        cprint("Your enhanced class has no companion requirement.")
        return
    end

    local playerLevel = UnitLevel("player") or 1
    local tag = (playerLevel >= char.companion.level)
        and "|cff00ff00ACTIVE|r"
        or  "|cff888888lv " .. char.companion.level .. "|r"

    cprint("Companion requirement: " .. tag .. " " .. char.companion.desc)

    local dbEntry = CC.CompanionDB[char.companion.desc]
    if dbEntry then
        cprint("  Accepted creatures: " .. table.concat(
            (function()
                local names = {}
                for n in pairs(dbEntry.creatureNames) do
                    table.insert(names, n)
                end
                table.sort(names)
                return names
            end)(), ", "
        ))
        cprint("  Item IDs: " .. table.concat(dbEntry.itemIDs, ", "))
        if dbEntry.notes then
            cprint("  Note: " .. dbEntry.notes)
        end
    else
        cprint("  |cffffaa33Not in companion database yet|r")
    end

    -- Current status
    local result = CC.RunCheck()
    if result.status == PASS then
        cprint("  Status: |cff00ff00" .. (result.detail or "OK") .. "|r")
    elseif result.status == FAIL then
        cprint("  Status: |cffff5555" .. (result.detail or "FAIL") .. "|r")
    else
        cprint("  Status: |cffffaa33" .. (result.detail or "unchecked") .. "|r")
    end

    -- Bag scan
    local critterName = getCritterName()
    if critterName then
        cprint("  Current critter: " .. critterName)
    else
        cprint("  Current critter: none")
    end

    local ownedItemID = dbEntry and findCompanionItemInBags(dbEntry.itemIDs)
    if ownedItemID then
        local itemName = GetItemInfo(ownedItemID)
        cprint("  Matching pet item in bags: " .. (itemName or ("item:" .. ownedItemID)))
    else
        cprint("  Matching pet item in bags: none found")
    end
end

----------------------------------------------------------------------
-- Event frame
----------------------------------------------------------------------

local eventFrame = CreateFrame("Frame", "HCE_CompanionCheckFrame", UIParent)

eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:RegisterEvent("UNIT_PET")

-- COMPANION_UPDATE exists in some Classic builds; try to register it
-- but don't error if it's absent.
pcall(function() eventFrame:RegisterEvent("COMPANION_UPDATE") end)

eventFrame:SetScript("OnEvent", function(self, event, ...)
    -- Only run if we have a character with a companion requirement
    if not FCE_CharDB or not FCE_CharDB.selectedCharacter then return end
    local char = FCE.GetCharacter and FCE.GetCharacter(FCE_CharDB.selectedCharacter)
    if not char or not char.companion then return end

    if event == "PLAYER_LOGIN" then
        -- Delay to let the critter spawn after login
        C_Timer.After(3.0, function()
            local result = CC.RunCheck()
            maybeWarn(result)
            if FCE.RefreshPanel then FCE.RefreshPanel() end
            startHeartbeat()
        end)

    elseif event == "PLAYER_LEVEL_UP" then
        -- Re-check in case the requirement just became active
        C_Timer.After(1.0, function()
            local result = CC.RunCheck()
            maybeWarn(result)
            if FCE.RefreshPanel then FCE.RefreshPanel() end
        end)

    elseif event == "COMPANION_UPDATE" or event == "UNIT_PET" then
        -- Small delay for the game state to settle
        C_Timer.After(0.5, function()
            local result = CC.RunCheck()
            -- On COMPANION_UPDATE/UNIT_PET, re-evaluate warnings
            -- since the player may have just summoned/dismissed
            if result.status == PASS then
                -- Summoned the right one — acknowledge it
                if warnedNoCompanion or warnedWrongCompanion then
                    cprint("|cff00ff00Companion:|r " .. (result.detail or "Correct companion summoned!"))
                    warnedNoCompanion    = false
                    warnedWrongCompanion = false
                end
            else
                maybeWarn(result)
            end
            if FCE.RefreshPanel then FCE.RefreshPanel() end
        end)
    end
end)
