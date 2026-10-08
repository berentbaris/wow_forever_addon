----------------------------------------------------------------------
-- ForeverClassesEnhanced
-- Extra lore-based character classes for hardcore runs.
-- Tracks whether you're meeting your chosen character's requirements.
----------------------------------------------------------------------

-- Addon-wide namespace (CharacterData.lua loads first and may have
-- already created FCE, so we preserve it)

local GetNumSkillLines, GetSkillLineInfo, SendChatMessage
    = FCE.Compat.GetNumSkillLines, FCE.Compat.GetSkillLineInfo, FCE.Compat.SendChatMessage  -- Forever API shims (ForeverCompat.lua)
FCE = FCE or {}
FCE.version = "0.1.0"

----------------------------------------------------------------------
-- Saved variable defaults
----------------------------------------------------------------------
local GLOBAL_DEFAULTS = {
    alertsEnabled = true,
    forbiddenAlertsEnabled = true,
    chatWarningsEnabled = true,
    alertSoundEnabled = true,
    edgeFlashEnabled = true,
    gameplayTipsEnabled = true,
    partyAnnounce = true,
    guildAnnounce = true,
    guildAnnounceReqs = true,
    welcomeShown = {},  -- keyed by "name-realm"
}

local CHAR_DEFAULTS = {
    selectedCharacter = nil,   -- string key into FCE.Characters
    manualOverride    = false, -- true if the player picked manually
    lastLevel         = nil,   -- highest level this char had last time we looked
                               -- (used by LevelAlert to detect crossed gates)
}

----------------------------------------------------------------------
-- Event frame
----------------------------------------------------------------------
local eventFrame = CreateFrame("Frame", "HCE_EventFrame", UIParent)

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")

----------------------------------------------------------------------
-- Saved-variable initialisation helpers
----------------------------------------------------------------------
local function InitDB(saved, defaults)
    if saved == nil then return CopyTable(defaults) end
    for k, v in pairs(defaults) do
        if saved[k] == nil then
            saved[k] = v
        end
    end
    return saved
end

----------------------------------------------------------------------
-- Chat helpers
----------------------------------------------------------------------
local CHAT_PREFIX = "|cff66bbff[FCE]|r "

function FCE.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(CHAT_PREFIX .. tostring(msg))
end

----------------------------------------------------------------------
-- Character detection & assignment
----------------------------------------------------------------------

--- Try to auto-detect the player's enhanced class from race/class/gender.
--- If exactly one match, assign it automatically.
--- If multiple matches, list them and prompt for /fce pick.
--- If no match, inform the player.
local function TryAutoDetect()
    -- Skip if the player already chose manually
    if FCE_CharDB.manualOverride then return end
    -- Skip if already assigned from a previous session
    if FCE_CharDB.selectedCharacter then return end

    local matches = FCE.FindMatchingCharacters()

    if #matches == 1 then
        local char = matches[1]
        FCE_CharDB.selectedCharacter = char.key
        -- First-time selection: the player has already levelled up to
        -- their current level under no enhanced rules, so don't fire
        -- toasts retroactively for the climb to get here.
        FCE_CharDB.lastLevel = UnitLevel("player") or 1
        if FCE.DoubtSystem and FCE.DoubtSystem.OnClassChanged then FCE.DoubtSystem.OnClassChanged() end
        if FCE.SavagerySystem and FCE.SavagerySystem.OnClassChanged then FCE.SavagerySystem.OnClassChanged() end
        if FCE.BrewmasterSystem and FCE.BrewmasterSystem.OnClassChanged then FCE.BrewmasterSystem.OnClassChanged() end
        if FCE.ElixirSystem and FCE.ElixirSystem.OnClassChanged then FCE.ElixirSystem.OnClassChanged() end
        if FCE.EventChallenges and FCE.EventChallenges.RefreshChallengeCache then FCE.EventChallenges.RefreshChallengeCache() end
        FCE.Print("Auto-detected your enhanced class: |cffffd100" .. char.name .. "|r (" .. char.spec .. " " .. char.class:sub(1,1) .. char.class:sub(2):lower() .. ")")
    else
        if FCE.CatalogUI and FCE.CatalogUI.ShowForPlayer then
            C_Timer.After(0.5, FCE.CatalogUI.ShowForPlayer)
        end
    end
end

----------------------------------------------------------------------
-- Welcome & status display
----------------------------------------------------------------------

function FCE.PrintWelcome()
    local _, classToken = UnitClass("player")
    local race   = UnitRace("player")
    local sex    = UnitSex("player")
    local name   = UnitName("player")
    local gender = (sex == 3) and "female" or "male"
    local class  = classToken:sub(1,1) .. classToken:sub(2):lower()

    if FCE_CharDB.selectedCharacter then
        local char = FCE.GetCharacter(FCE_CharDB.selectedCharacter)
        if char then
            FCE.Print("FCE loaded. Enhanced class: |cffffd100" .. char.name .. "|r")
            -- Show a quick summary using ProgressSummary as the source of truth
            local level = UnitLevel("player")
            local summary = FCE.Progress and FCE.Progress.Collect and FCE.Progress.Collect()
            if summary and summary.counts then
                local c = summary.counts
                local active = c.pass + c.fail + c.unchecked
                FCE.Print(active .. " requirement(s) active at level " .. level .. ". Click the minimap icon or type |cffffd100/fce status|r for details.")
            else
                FCE.Print("Click the minimap icon or type |cffffd100/fce status|r for details.")
            end
            -- Warn if the saved enhanced class doesn't match this character's WoW class
            if char.class ~= classToken then
                local expectedClass = char.class:sub(1,1) .. char.class:sub(2):lower()
                local displayName = FCE.GetCharDisplayName and FCE.GetCharDisplayName(char) or char.name
                FCE.Print("|cffff5555WARNING:|r Your saved enhanced class |cffffd100" .. displayName
                    .. "|r requires a |cffffd100" .. expectedClass .. "|r, but you are a |cffffd100" .. class
                    .. "|r! Use |cffffd100/fce reset|r to clear your selection.")
            end
        else
            FCE.Print("Enhanced class: |cffffd100" .. FCE_CharDB.selectedCharacter .. "|r (data not found - try |cffffd100/fce reset|r)")
        end
    else
        FCE.Print("No enhanced class selected. Type |cffffd100/fce catalog|r to choose one.")
    end
    FCE.Print("Join the FCE Discord Community by typing |cffffd100/fce join|r.")
    FCE.Print("Support the addon: |cff66bbffbuymeacoffee.com/berentbaris|r or type |cffffd100/fce donate|r")
end

--- Print full requirement details for the selected character.
local function PrintFullStatus()
    if not FCE_CharDB.selectedCharacter then
        FCE.Print("No enhanced class selected. Type |cffffd100/fce pick|r to choose one.")
        return
    end
    local char = FCE.GetCharacter(FCE_CharDB.selectedCharacter)
    if not char then
        FCE.Print("Character data not found for \"" .. FCE_CharDB.selectedCharacter .. "\".")
        return
    end

    local level = UnitLevel("player")
    local class = char.class:sub(1,1) .. char.class:sub(2):lower()

    FCE.Print("--- " .. char.name .. " (" .. char.spec .. " " .. class .. ") ---")

    -- Race / gender
    FCE.Print("Race: " .. char.race .. " | Gender: " .. char.gender)

    -- Professions
    if #char.professions > 0 then
        FCE.Print("Professions: " .. table.concat(char.professions, ", "))
    end

    -- Equipment
    local _equip = FCE.GetCharEquipment(char)
    if #_equip > 0 then
        FCE.Print("Equipment:")
        for _, eq in ipairs(_equip) do
            local tag = (level >= eq.level) and "|cff00ff00ACTIVE|r" or "|cff888888lv " .. eq.level .. "|r"
            FCE.Print("  " .. tag .. " " .. eq.desc)
        end
    end

    -- Challenges
    local activeChallenges = FCE.GetActiveChallenges and FCE.GetActiveChallenges(char) or char.challenges or {}
    if #activeChallenges > 0 then
        FCE.Print("Challenges:")
        for _, ch in ipairs(activeChallenges) do
            local tag = (level >= ch.level) and "|cff00ff00ACTIVE|r" or "|cff888888lv " .. ch.level .. "|r"
            local desc = ch.desc
            local extra = FCE.ChallengeDescriptions and FCE.ChallengeDescriptions[ch.desc]
            if extra then desc = desc .. " - " .. extra end
            FCE.Print("  " .. tag .. " " .. desc)
        end
    end

    -- Companion / pet / mount
    if char.companion then
        local tag = (level >= char.companion.level) and "|cff00ff00ACTIVE|r" or "|cff888888lv " .. char.companion.level .. "|r"
        FCE.Print("Companion: " .. tag .. " " .. char.companion.desc)
    end
    if char.pet then
        local tag = (level >= char.pet.level) and "|cff00ff00ACTIVE|r" or "|cff888888lv " .. char.pet.level .. "|r"
        FCE.Print("Hunter pet: " .. tag .. " " .. char.pet.desc)
    end
    if char.mount then
        local tag = (level >= char.mount.level) and "|cff00ff00ACTIVE|r" or "|cff888888lv " .. char.mount.level .. "|r"
        FCE.Print("Mount: " .. tag .. " " .. char.mount.desc)
    end

    -- Gameplay tips
    local _gameplay = FCE.GetCharGameplay and FCE.GetCharGameplay(char) or char.gameplay
    if _gameplay then
        FCE.Print("Gameplay: " .. _gameplay)
    end
end

----------------------------------------------------------------------
-- Slash commands
----------------------------------------------------------------------
SLASH_FCE1 = "/fce"
SLASH_FCE2 = "/foreverclasses"

SlashCmdList["FCE"] = function(msg)
    local cmd = strtrim(msg):lower()

    if cmd == "" or cmd == "help" then
        FCE.Print("Commands:")
        FCE.Print("  /fce            - show this help")
        FCE.Print("  /fce settings   - open the settings panel")
        FCE.Print("  /fce donate     - support the addon developer")
        FCE.Print("  /fce join     - join the FCE Discord Community")
        FCE.Print("  /fce wiki     - check out the addon wiki")
        FCE.Print("  /fce progress   - show progress checklist with completion %")
        FCE.Print("  /fce status     - show full requirement details")
        FCE.Print("  /fce ui         - open the character selection window")
        FCE.Print("  /fce pick       - open the class catalog")
        FCE.Print("  /fce pick <name>- pick a specific character by name (text)")
        FCE.Print("  /fce panel      - toggle the requirements panel")
        FCE.Print("  /fce minimap    - show/hide the minimap button")
        FCE.Print("  /fce alerts     - toggle level-up requirement toasts")
        FCE.Print("  /fce testalert  - preview a toast alert")
        FCE.Print("  /fce forbidden  - toggle forbidden-item alerts")
        FCE.Print("  /fce testforbidden - preview a forbidden-item alert")
        FCE.Print("  /fce testsummary - preview the level-up summary frame")
        FCE.Print("  /fce selffound  - check self-found / self-made status")
        FCE.Print("  /fce talents    - check talent/spec status")
        FCE.Print("  /fce professions- check profession status")
        FCE.Print("  /fce challenges - check challenge status")
        FCE.Print("  /fce zones      - check zone/continent tracking status")
        FCE.Print("  /fce companion  - check companion (vanity pet) status")
        FCE.Print("  /fce hunterpet  - check hunter pet species status")
        FCE.Print("  /fce mount      - check mount requirement status")
        FCE.Print("  /fce apitest    - test every game API FCE relies on (add 'talents' or 'live')")
        FCE.Print("  /fce compat     - quick list of native vs shimmed APIs")
        FCE.Print("  /fce quests     - check quest completion progress")
        FCE.Print("  /fce behavioral - check behavioral challenge status (Drifter/Ephemeral)")
        FCE.Print("  /fce sources    - show item-source breakdown (vendor/quest/crafted)")
        FCE.Print("  /fce gameplay   - show expanded gameplay flavour tips")
        FCE.Print("  /fce tips       - toggle periodic gameplay tip reminders")
        FCE.Print("  /fce curated    - show curated item-ID list status")
        FCE.Print("  /fce list       - list all enhanced classes for your class")
        FCE.Print("  /fce reset      - clear your character selection")
        FCE.Print("  /fce doubt      - show current doubt level")
        FCE.Print("  /fce doubt reset- reset doubt for current class")
        FCE.Print("  /fce savagery   - show current savagery (Plagueshifter)")
        FCE.Print("  /fce happyhour  - show Happy Hour timer (Brewmaster)")
        FCE.Print("  /fce elixir     - show Elixir Frenzy grace (Berserker)")
        FCE.Print("  /fce insular    - show insular violations | /fce insular reset")
        FCE.Print("  /fce version    - show addon version")
        FCE.Print(" ")
        FCE.Print("|cffffd100Social:|r")
        FCE.Print("  /fce scan       - scan for other FCE players")
        FCE.Print("  /fce share <name> - whisper a player about FCE")
        FCE.Print("  /fce share party- share FCE info in party chat")
        FCE.Print("  /fce debug      - toggle comm debug messages")
        FCE.Print("  /fce status     - show comm channel diagnostics")

    elseif cmd == "status" then
        PrintFullStatus()

    elseif cmd == "panel" or cmd == "req" or cmd == "requirements" then
        if FCE.TogglePanel then
            FCE.TogglePanel()
        else
            FCE.Print("Requirements panel not loaded.")
        end

    elseif cmd == "testalert" or cmd == "test" then
        if FCE.TestAlert then
            FCE.TestAlert()
        else
            FCE.Print("Alert module not loaded.")
        end

    elseif cmd == "alerts" then
        FCE_GlobalDB.alertsEnabled = not FCE_GlobalDB.alertsEnabled
        if FCE_GlobalDB.alertsEnabled then
            FCE.Print("Level-up requirement toasts |cff00ff00enabled|r.")
        else
            FCE.Print("Level-up requirement toasts |cffff5555disabled|r.")
            if FCE.Alert then FCE.Alert.DismissAll() end
        end

    elseif cmd == "forbidden" then
        FCE_GlobalDB.forbiddenAlertsEnabled = not FCE_GlobalDB.forbiddenAlertsEnabled
        if FCE_GlobalDB.forbiddenAlertsEnabled then
            FCE.Print("Forbidden-item alerts |cff00ff00enabled|r.")
        else
            FCE.Print("Forbidden-item alerts |cffff5555disabled|r.")
            if FCE.ForbiddenAlert then FCE.ForbiddenAlert.DismissAll() end
        end

    elseif cmd == "testforbidden" then
        if FCE.TestForbiddenAlert then
            FCE.TestForbiddenAlert()
        else
            FCE.Print("Forbidden-alert module not loaded.")
        end

    elseif cmd:sub(1, 20) == "debug_minimapbackend" then
        local backend = strtrim(cmd:sub(21))

        if backend == "" then
            local preference = FCE.Panel and FCE.Panel.GetMinimapBackendPreference
                and FCE.Panel.GetMinimapBackendPreference() or "auto"
            FCE.Print("Minimap backend preference: " .. preference)
        elseif FCE.Panel and FCE.Panel.SetMinimapBackendPreference
            and FCE.Panel.SetMinimapBackendPreference(backend) then
            FCE.Print("Minimap backend set to " .. backend .. ". Use |cffffd100/reload|r to apply it.")
        else
            FCE.Print("Usage: |cffffd100/fce debug_minimapbackend <auto|broker|standalone>|r")
        end

    elseif cmd == "minimap" then
        if FCE.ShowMinimapButton and FCE_GlobalDB and FCE_GlobalDB.panel then
            if FCE_GlobalDB.panel.minimap and FCE_GlobalDB.panel.minimap.hide then
                FCE.ShowMinimapButton()
                FCE.Print("Minimap button shown.")
            else
                FCE.HideMinimapButton()
                FCE.Print("Minimap button hidden. Use |cffffd100/fce minimap|r to bring it back.")
            end
        end

    elseif cmd == "ui" or cmd == "show" or cmd == "open" then
        if FCE.CatalogUI and FCE.CatalogUI.Show then
            FCE.CatalogUI.Show()
        else
            FCE.Print("Catalog UI not loaded.")
        end

    elseif cmd:sub(1, 4) == "pick" then
        local arg = strtrim(cmd:sub(5))
        if arg == "" then
            if FCE.CatalogUI and FCE.CatalogUI.ShowForPlayer then
                FCE.CatalogUI.ShowForPlayer()
            else
                FCE.Print("Catalog UI not loaded.")
            end
        else
            -- Try to find a character by name (case-insensitive partial match)
            local found = nil
            local argLower = arg:lower()
            for key, char in pairs(FCE.Characters) do
                if key:lower() == argLower or key:lower():find(argLower, 1, true) then
                    found = char
                    break
                end
            end
            if found then
                FCE_CharDB.selectedCharacter = found.key
                FCE_CharDB.manualOverride = true
                FCE.Print("Selected enhanced class: |cffffd100" .. found.name .. "|r (" .. found.spec .. ")")
                if FCE.ResyncLevelAlerts then FCE.ResyncLevelAlerts() end
                if FCE.ProfessionCheck and FCE.ProfessionCheck.ResetWarnings then FCE.ProfessionCheck.ResetWarnings() end
                if FCE.TalentCheck and FCE.TalentCheck.ResetWarnings then FCE.TalentCheck.ResetWarnings() end
                if FCE.SelfFoundCheck and FCE.SelfFoundCheck.ResetWarnings then FCE.SelfFoundCheck.ResetWarnings() end
                if FCE.ChallengeCheck and FCE.ChallengeCheck.ResetWarnings then FCE.ChallengeCheck.ResetWarnings() end
                if FCE.ZoneCheck and FCE.ZoneCheck.ResetTracking then FCE.ZoneCheck.ResetTracking() end
                if FCE.BehavioralCheck and FCE.BehavioralCheck.ResetTracking then FCE.BehavioralCheck.ResetTracking() end
                if FCE.CompanionCheck and FCE.CompanionCheck.ResetWarnings then FCE.CompanionCheck.ResetWarnings() end
                if FCE.HunterPetCheck and FCE.HunterPetCheck.ResetWarnings then FCE.HunterPetCheck.ResetWarnings() end
                if FCE.MountCheck and FCE.MountCheck.ResetWarnings then FCE.MountCheck.ResetWarnings() end
                -- Immediately run fresh checks so the panel has results
                if FCE.EquipmentCheck and FCE.EquipmentCheck.RunCheck then FCE.EquipmentCheck.RunCheck() end
                if FCE.CompanionCheck and FCE.CompanionCheck.RunCheck then FCE.CompanionCheck.RunCheck() end
                if FCE.HunterPetCheck and FCE.HunterPetCheck.RunCheck then FCE.HunterPetCheck.RunCheck() end
                if FCE.MountCheck and FCE.MountCheck.RunCheck then FCE.MountCheck.RunCheck() end
                if FCE.QuestCheck and FCE.QuestCheck.RunCheck then FCE.QuestCheck.RunCheck() end
                if FCE.DoubtSystem and FCE.DoubtSystem.OnClassChanged then FCE.DoubtSystem.OnClassChanged() end
        if FCE.SavagerySystem and FCE.SavagerySystem.OnClassChanged then FCE.SavagerySystem.OnClassChanged() end
        if FCE.BrewmasterSystem and FCE.BrewmasterSystem.OnClassChanged then FCE.BrewmasterSystem.OnClassChanged() end
        if FCE.ElixirSystem and FCE.ElixirSystem.OnClassChanged then FCE.ElixirSystem.OnClassChanged() end
                if FCE.EventChallenges and FCE.EventChallenges.RefreshChallengeCache then FCE.EventChallenges.RefreshChallengeCache() end
                if FCE.RefreshPanel then FCE.RefreshPanel() end
            else
                FCE.Print("No enhanced class found matching \"" .. arg .. "\". Try |cffffd100/fce pick|r to see options.")
            end
        end

    elseif cmd == "list" or cmd == "catalog" or cmd == "catalogue" or cmd == "browse" then
        if FCE.CatalogUI and FCE.CatalogUI.Toggle then
            FCE.CatalogUI.Toggle()
        else
            FCE.Print("Catalog module not loaded.")
        end

    elseif cmd == "professions" or cmd == "prof" then
        if not FCE.ProfessionCheck then
            FCE.Print("Profession tracking module not loaded.")
        elseif not FCE_CharDB or not FCE_CharDB.selectedCharacter then
            FCE.Print("No enhanced class selected. Type |cffffd100/fce pick|r to choose one.")
        else
            local char = FCE.GetCharacter(FCE_CharDB.selectedCharacter)
            if not char or not char.professions or #char.professions == 0 then
                FCE.Print("Your enhanced class has no profession requirements.")
            else
                local results = FCE.ProfessionCheck.RunCheck()
                local level = UnitLevel("player") or 1
                FCE.Print("Profession status (level " .. level .. "):")
                for _, profName in ipairs(char.professions) do
                    local r = results[profName]
                    if r then
                        local tag
                        if r.status == "pass" then
                            tag = "|cff00ff00OK|r"
                        elseif r.status == "fail" then
                            tag = "|cffff5555BEHIND|r"
                        elseif r.status == "inactive" then
                            tag = "|cff888888inactive|r"
                        else
                            tag = "|cffffaa33???|r"
                        end
                        FCE.Print("  " .. profName .. ": " .. tag .. " - " .. (r.detail or ""))
                    else
                        FCE.Print("  " .. profName .. ": |cff888888no data|r")
                    end
                end
                -- Debug: dump raw skill lines
                FCE.Print("|cff888888--- Debug: raw skill lines ---|r")
                local n = GetNumSkillLines and GetNumSkillLines() or 0
                for i = 1, n do
                    local v = { GetSkillLineInfo(i) }
                    local parts = {}
                    for idx = 1, #v do
                        parts[idx] = tostring(v[idx])
                    end
                    FCE.Print("  [" .. i .. "] " .. table.concat(parts, " | "))
                end
            end
        end

    elseif cmd == "compat" then
        if FCE.Compat and FCE.Compat.Report then FCE.Compat.Report() end

    elseif cmd == "apitest" or cmd:find("^apitest ") then
        local sub = cmd:match("^apitest%s+(%S+)") or ""
        if FCE.APIProbe then
            if sub == "live" then
                FCE.APIProbe.ArmLive()
            else
                FCE.APIProbe.Run({ talents = (sub == "talents") })
            end
        end

    elseif cmd == "challenges" or cmd == "challenge" or cmd == "ch" then
        if FCE.ChallengeCheck and FCE.ChallengeCheck.PrintStatus then
            FCE.ChallengeCheck.PrintStatus()
        else
            FCE.Print("Challenge tracking module not loaded.")
        end

    elseif cmd == "zones" or cmd == "zone" or cmd == "homebound" then
        if FCE.ZoneCheck and FCE.ZoneCheck.PrintStatus then
            FCE.ZoneCheck.PrintStatus()
        else
            FCE.Print("Zone tracking module not loaded.")
        end

    elseif cmd == "selffound" or cmd == "selfmade" or cmd == "sf" then
        if FCE.SelfFoundCheck and FCE.SelfFoundCheck.PrintStatus then
            FCE.SelfFoundCheck.PrintStatus()
        else
            FCE.Print("Self-found tracking module not loaded.")
        end

    elseif cmd == "talents" or cmd == "talent" or cmd == "spec" then
        if FCE.TalentCheck and FCE.TalentCheck.PrintStatus then
            FCE.TalentCheck.PrintStatus()
        else
            FCE.Print("Talent tracking module not loaded.")
        end

    elseif cmd == "sources" or cmd == "source" or cmd == "itemsource" then
        if FCE.PrintItemSources then
            FCE.PrintItemSources()
        else
            FCE.Print("Item source data module not loaded.")
        end

    elseif cmd == "curated" then
        -- Diagnostic: show curated item-ID list status.  Sorted so the
        -- finished lists surface at the top.
        if not FCE.CuratedItems then
            FCE.Print("Curated item lists not loaded.")
        else
            local rows = {}
            for name, list in pairs(FCE.CuratedItems) do
                local n = 0
                for k in pairs(list) do if k ~= "_order" then n = n + 1 end end
                local complete = FCE.CuratedComplete and FCE.CuratedComplete[name]
                table.insert(rows, { name = name, count = n, complete = complete })
            end
            table.sort(rows, function(a, b)
                if a.count ~= b.count then return a.count > b.count end
                return a.name < b.name
            end)
            FCE.Print("Curated item lists:")
            local totalItems, doneLists, totalLists = 0, 0, #rows
            for _, r in ipairs(rows) do
                local tag
                if r.complete then
                    tag = "|cff00ff00done|r"
                    doneLists = doneLists + 1
                elseif r.count > 0 then
                    tag = "|cffffd100" .. r.count .. " item" .. (r.count == 1 and "" or "s") .. "|r"
                else
                    tag = "|cff888888empty|r"
                end
                FCE.Print("  " .. r.name .. ": " .. tag)
                totalItems = totalItems + r.count
            end
            FCE.Print(string.format(
                "Total: %d item%s across %d list%s (%d marked complete).",
                totalItems, totalItems == 1 and "" or "s",
                totalLists, totalLists == 1 and "" or "s",
                doneLists
            ))
        end

    elseif cmd == "reset" then
        if FCE.DoubtSystem and FCE.DoubtSystem.ResetDoubt then FCE.DoubtSystem.ResetDoubt() end
        FCE_CharDB.selectedCharacter = nil
        FCE_CharDB.manualOverride = false
        FCE_CharDB.selectedChallenge = nil
        FCE_CharDB.selectedChallenges = nil
        FCE_CharDB.lastLevel = UnitLevel("player") or 1
        FCE.Print("Enhanced class selection cleared. Opening the catalog…")
        if FCE.ProfessionCheck and FCE.ProfessionCheck.ResetWarnings then FCE.ProfessionCheck.ResetWarnings() end
        if FCE.TalentCheck and FCE.TalentCheck.ResetWarnings then FCE.TalentCheck.ResetWarnings() end
        if FCE.SelfFoundCheck and FCE.SelfFoundCheck.ResetWarnings then FCE.SelfFoundCheck.ResetWarnings() end
        if FCE.ChallengeCheck and FCE.ChallengeCheck.ResetWarnings then FCE.ChallengeCheck.ResetWarnings() end
        if FCE.ZoneCheck and FCE.ZoneCheck.ResetTracking then FCE.ZoneCheck.ResetTracking() end
        if FCE.BehavioralCheck and FCE.BehavioralCheck.ResetTracking then FCE.BehavioralCheck.ResetTracking() end
        if FCE.CompanionCheck and FCE.CompanionCheck.ResetWarnings then FCE.CompanionCheck.ResetWarnings() end
        if FCE.HunterPetCheck and FCE.HunterPetCheck.ResetWarnings then FCE.HunterPetCheck.ResetWarnings() end
        if FCE.MountCheck and FCE.MountCheck.ResetWarnings then FCE.MountCheck.ResetWarnings() end
        if FCE.EventChallenges and FCE.EventChallenges.ResetAll then FCE.EventChallenges.ResetAll() end
        if FCE.EventChallenges and FCE.EventChallenges.RefreshChallengeCache then FCE.EventChallenges.RefreshChallengeCache() end
        if FCE.RefreshPanel then FCE.RefreshPanel() end
        -- Auto-open the catalog for the player's class
        if FCE.CatalogUI and FCE.CatalogUI.ShowForPlayer then
            C_Timer.After(0.3, FCE.CatalogUI.ShowForPlayer)
        end

    elseif cmd == "companion" or cmd == "pet" or cmd == "critter" then
        if FCE.CompanionCheck and FCE.CompanionCheck.PrintStatus then
            FCE.CompanionCheck.PrintStatus()
        else
            FCE.Print("Companion tracking module not loaded.")
        end

    elseif cmd == "hunterpet" or cmd == "hpet" then
        if FCE.HunterPetCheck and FCE.HunterPetCheck.PrintStatus then
            FCE.HunterPetCheck.PrintStatus()
        else
            FCE.Print("Hunter pet tracking module not loaded.")
        end

    elseif cmd == "mount" or cmd == "riding" then
        if FCE.MountCheck and FCE.MountCheck.PrintStatus then
            FCE.MountCheck.PrintStatus()
        else
            FCE.Print("Mount tracking module not loaded.")
        end

    elseif cmd == "quests" or cmd == "quest" then
        if FCE.QuestCheck and FCE.QuestCheck.PrintStatus then
            FCE.QuestCheck.PrintStatus()
        else
            FCE.Print("Quest tracking module not loaded.")
        end

    elseif cmd == "weapons" or cmd == "weapon" or cmd == "wpn" then
        if FCE.WeaponProficiencyCheck and FCE.WeaponProficiencyCheck.PrintStatus then
            FCE.WeaponProficiencyCheck.PrintStatus()
        else
            FCE.Print("Weapon proficiency module not loaded.")
        end

    elseif cmd == "behavioral" or cmd == "behaviour" or cmd == "behavior" then
        if FCE.BehavioralCheck and FCE.BehavioralCheck.PrintStatus then
            FCE.BehavioralCheck.PrintStatus()
        else
            FCE.Print("Behavioral tracking module not loaded.")
        end

    elseif cmd == "progress" or cmd == "prog" or cmd == "checklist" then
        if FCE.Progress and FCE.Progress.PrintStatus then
            FCE.Progress.PrintStatus()
        else
            FCE.Print("Progress summary module not loaded.")
        end

    elseif cmd == "donate" or cmd == "support" then
        FCE.Print("Thanks for your support!")
        FCE.Print("|cff66bbffhttps://buymeacoffee.com/berentbaris|r")
        -- Open an edit box so the player can copy the URL
        if not FCE._donateEditBox then
            local eb = CreateFrame("EditBox", "HCE_DonateEditBox", UIParent, "InputBoxTemplate")
            eb:SetSize(320, 28)
            eb:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
            eb:SetAutoFocus(true)
            eb:SetText("https://buymeacoffee.com/berentbaris")
            eb:HighlightText()
            eb:SetScript("OnEscapePressed", function(self) self:Hide() end)
            eb:SetScript("OnEnterPressed", function(self) self:Hide() end)
            eb:SetScript("OnEditFocusLost", function(self) self:Hide() end)
            FCE._donateEditBox = eb
        else
            FCE._donateEditBox:SetText("https://buymeacoffee.com/berentbaris")
            FCE._donateEditBox:Show()
            FCE._donateEditBox:HighlightText()
            FCE._donateEditBox:SetFocus()
        end

    elseif cmd == "join" or cmd == "discord" then
        FCE.Print("Welcome to the community!")
        FCE.Print("|cff66bbffhttps://discord.gg/YdNZkAsSFf|r")
        -- Open an edit box so the player can copy the URL
        if not FCE._donateJoinBox then
            local eb = CreateFrame("EditBox", "HCE_donateJoinBox", UIParent, "InputBoxTemplate")
            eb:SetSize(320, 28)
            eb:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
            eb:SetAutoFocus(true)
            eb:SetText("https://discord.gg/YdNZkAsSFf")
            eb:HighlightText()
            eb:SetScript("OnEscapePressed", function(self) self:Hide() end)
            eb:SetScript("OnEnterPressed", function(self) self:Hide() end)
            eb:SetScript("OnEditFocusLost", function(self) self:Hide() end)
            FCE._donateJoinBox = eb
        else
            FCE._donateJoinBox:SetText("https://discord.gg/YdNZkAsSFf")
            FCE._donateJoinBox:Show()
            FCE._donateJoinBox:HighlightText()
            FCE._donateJoinBox:SetFocus()
        end

    elseif cmd == "pole weaving" then
        FCE.Print("Check this Youtube video for detailed explanation")
        FCE.Print("|cff66bbffhttps://www.youtube.com/watch?v=-bxMMK2vS5s|r")
        -- Open an edit box so the player can copy the URL
        if not FCE._donateJoinBox then
            local eb = CreateFrame("EditBox", "HCE_donateJoinBox", UIParent, "InputBoxTemplate")
            eb:SetSize(320, 28)
            eb:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
            eb:SetAutoFocus(true)
            eb:SetText("https://www.youtube.com/watch?v=-bxMMK2vS5s")
            eb:HighlightText()
            eb:SetScript("OnEscapePressed", function(self) self:Hide() end)
            eb:SetScript("OnEnterPressed", function(self) self:Hide() end)
            eb:SetScript("OnEditFocusLost", function(self) self:Hide() end)
            FCE._donateJoinBox = eb
        else
            FCE._donateJoinBox:SetText("https://www.youtube.com/watch?v=-bxMMK2vS5s")
            FCE._donateJoinBox:Show()
            FCE._donateJoinBox:HighlightText()
            FCE._donateJoinBox:SetFocus()
        end

    elseif cmd == "wiki" then
        FCE.Print("|cff66bbffhttps://hce-wiki.polia.nl/|r")
        -- Open an edit box so the player can copy the URL
        if not FCE._donateJoinBox then
            local eb = CreateFrame("EditBox", "HCE_donateJoinBox", UIParent, "InputBoxTemplate")
            eb:SetSize(320, 28)
            eb:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
            eb:SetAutoFocus(true)
            eb:SetText("https://hce-wiki.polia.nl/")
            eb:HighlightText()
            eb:SetScript("OnEscapePressed", function(self) self:Hide() end)
            eb:SetScript("OnEnterPressed", function(self) self:Hide() end)
            eb:SetScript("OnEditFocusLost", function(self) self:Hide() end)
            FCE._donateJoinBox = eb
        else
            FCE._donateJoinBox:SetText("https://hce-wiki.polia.nl/")
            FCE._donateJoinBox:Show()
            FCE._donateJoinBox:HighlightText()
            FCE._donateJoinBox:SetFocus()
        end

    elseif cmd == "settings" or cmd == "options" or cmd == "config" then
        if FCE.SettingsPanel and FCE.SettingsPanel.Toggle then
            FCE.SettingsPanel.Toggle()
        else
            FCE.Print("Settings panel not loaded.")
        end

    elseif cmd == "gameplay" or cmd == "tips" or cmd == "flavor" then
        if cmd == "tips" and FCE.GameplayTips then
            -- Toggle periodic tip reminders
            if FCE_GlobalDB.gameplayTipsEnabled == nil then
                FCE_GlobalDB.gameplayTipsEnabled = true
            end
            FCE_GlobalDB.gameplayTipsEnabled = not FCE_GlobalDB.gameplayTipsEnabled
            if FCE_GlobalDB.gameplayTipsEnabled then
                FCE.Print("Periodic gameplay tip reminders |cff00ff00enabled|r.")
                FCE.GameplayTips.StartReminder()
            else
                FCE.Print("Periodic gameplay tip reminders |cffff5555disabled|r.")
                FCE.GameplayTips.StopReminder()
            end
        elseif FCE.GameplayTips and FCE.GameplayTips.PrintStatus then
            FCE.GameplayTips.PrintStatus()
        else
            FCE.Print("Gameplay tips module not loaded.")
        end

    elseif cmd == "testsummary" then
        if FCE.LevelUpSummary and FCE.LevelUpSummary.Test then
            FCE.LevelUpSummary.Test()
        else
            FCE.Print("Level-up summary module not loaded.")
        end

    elseif cmd:sub(1, 5) == "doubt" then
        local doubtArg = strtrim(cmd:sub(6)):lower()
        if doubtArg == "reset" then
            if FCE.DoubtSystem and FCE.DoubtSystem.ResetDoubt then
                FCE.DoubtSystem.ResetDoubt()
            else
                FCE.Print("Doubt system not loaded.")
            end
        elseif doubtArg:sub(1, 3) == "set" then
            local val = tonumber(strtrim(doubtArg:sub(4)))
            if val and FCE.DoubtSystem then
                FCE.DoubtSystem.SetDoubt(val)
                FCE.Print(string.format("Doubt set to %.1f%%", val))
            else
                FCE.Print("Usage: /fce doubt set <0-100>")
            end
        elseif doubtArg == "" then
            -- Show current doubt
            if FCE.DoubtSystem then
                local val = FCE.DoubtSystem.GetDoubt()
                FCE.Print(string.format("Current doubt: %.1f%%", val))
            else
                FCE.Print("Doubt system not loaded.")
            end
        else
            FCE.Print("Usage: /fce doubt - show doubt | /fce doubt set <0-100> | /fce doubt reset")
        end

    elseif cmd:sub(1, 8) == "savagery" then
        local savArg = strtrim(cmd:sub(9)):lower()
        if savArg == "reset" then
            if FCE.SavagerySystem and FCE.SavagerySystem.ResetSavagery then
                FCE.SavagerySystem.ResetSavagery()
            else
                FCE.Print("Savagery system not loaded.")
            end
        elseif savArg == "" then
            if FCE.SavagerySystem then
                FCE.Print(string.format("Current savagery: %.0f%%", FCE.SavagerySystem.GetSavagery()))
            else
                FCE.Print("Savagery system not loaded.")
            end
        else
            FCE.Print("Usage: /fce savagery | /fce savagery reset")
        end

    elseif cmd:sub(1, 9) == "happyhour" then
        local hhArg = strtrim(cmd:sub(10)):lower()
        if hhArg == "reset" then
            if FCE.BrewmasterSystem and FCE.BrewmasterSystem.Reset then
                FCE.BrewmasterSystem.Reset()
            else
                FCE.Print("Brewmaster system not loaded.")
            end
        elseif hhArg == "" then
            if FCE.BrewmasterSystem then
                local t = FCE.BrewmasterSystem.GetTimeRemaining()
                FCE.Print(string.format("Happy Hour: %d:%02d remaining", math.floor(t/60), t%60))
            else
                FCE.Print("Brewmaster system not loaded.")
            end
        else
            FCE.Print("Usage: /fce happyhour | /fce happyhour reset")
        end

    elseif cmd:sub(1, 6) == "elixir" then
        local elArg = strtrim(cmd:sub(7)):lower()
        if elArg == "reset" then
            if FCE.ElixirSystem and FCE.ElixirSystem.Reset then
                FCE.ElixirSystem.Reset()
            else
                FCE.Print("Elixir system not loaded.")
            end
        elseif elArg == "" then
            if FCE.ElixirSystem then
                local t = FCE.ElixirSystem.GetGraceRemaining()
                FCE.Print(string.format("Elixir Frenzy grace: %d:%02d remaining", math.floor(t/60), t%60))
            else
                FCE.Print("Elixir system not loaded.")
            end
        else
            FCE.Print("Usage: /fce elixir | /fce elixir reset")
        end

    elseif cmd:sub(1, 7) == "insular" then
        local iArg = strtrim(cmd:sub(8)):lower()
        if iArg == "reset" then
            if FCE.EventChallenges and FCE.EventChallenges.ResetInsular then
                FCE.EventChallenges.ResetInsular()
            else
                FCE.Print("Event challenge module not loaded.")
            end
        else
            local db = FCE_CharDB and FCE_CharDB.eventChallenges
            local v = db and db.nativeTongueViolations or 0
            FCE.Print("Insular violations: " .. v)
        end

    elseif cmd == "version" then
        FCE.Print("Version " .. FCE.version)

    elseif cmd == "scan" then
        if FCE.AddonComm and FCE.AddonComm.StartNearbyScan then
            FCE.AddonComm.StartNearbyScan()
        else
            FCE.Print("Addon communication module not loaded.")
        end

    elseif cmd == "debug" then
        if FCE.AddonComm and FCE.AddonComm.ToggleDebug then
            FCE.AddonComm.ToggleDebug()
        end

    elseif cmd == "status" then
        if FCE.AddonComm and FCE.AddonComm.PrintStatus then
            FCE.AddonComm.PrintStatus()
        end

    elseif cmd:sub(1, 5) == "share" then
        local arg = strtrim(cmd:sub(6))

        -- Build class name and progress info
        local className = ""
        local progressLine = ""
        if FCE_CharDB and FCE_CharDB.selectedCharacter then
            local char = FCE.GetCharacter and FCE.GetCharacter(FCE_CharDB.selectedCharacter)
            if char then
                className = FCE.GetCharDisplayName and FCE.GetCharDisplayName(char) or char.name
            end
            if FCE.Progress and FCE.Progress.Collect and FCE.Progress.Percentage and FCE.Progress.GetRank then
                local summary = FCE.Progress.Collect()
                if summary and summary.counts then
                    local pct = FCE.Progress.Percentage(summary.counts)
                    local rank = FCE.Progress.GetRank(pct)
                    progressLine = " I'm at " .. math.floor(pct) .. "% progress towards becoming a Master " .. className .. "."
                end
            end
        end

        local msg1 = "I'm using Forever Classes Enhanced, an addon that adds 30+ lore-based classes to WoW Classic with unique challenges, requirements, and a rank system."
        local msg2
        if className ~= "" then
            msg2 = progressLine .. " Check it out on CurseForge!"
        else
            msg2 = "Check it out on CurseForge!"
        end

        if arg == "party" then
            if not IsInGroup or not IsInGroup() then
                FCE.Print("You are not in a party.")
                return
            end
            SendChatMessage(msg1, "PARTY")
            SendChatMessage(msg2, "PARTY")
            FCE.Print("Shared FCE info with your party!")
        else
            -- Determine whisper target: argument name, or current target
            local whisperTarget
            if arg ~= "" then
                whisperTarget = arg:sub(1,1):upper() .. arg:sub(2):lower()
            else
                local targetName = UnitName("target")
                if targetName and UnitIsPlayer("target") then
                    whisperTarget = targetName
                end
            end

            if not whisperTarget then
                FCE.Print("Usage: |cffffd100/fce share <name>|r or target a player.")
                FCE.Print("  |cffffd100/fce share party|r to share in party chat.")
                return
            end

            local myName = UnitName("player")
            if whisperTarget == myName then
                FCE.Print("You can't share with yourself!")
                return
            end

            SendChatMessage(msg1, "WHISPER", nil, whisperTarget)
            SendChatMessage(msg2, "WHISPER", nil, whisperTarget)
            FCE.Print("Shared FCE info with |cffffd100" .. whisperTarget .. "|r!")
        end

    elseif cmd == "debugtooltip" then
        if FCE.SelfFoundCheck and FCE.SelfFoundCheck.DebugTooltips then
            FCE.SelfFoundCheck.DebugTooltips()
        else
            FCE.Print("SelfFoundCheck module not loaded.")
        end

    else
        FCE.Print("Unknown command: " .. cmd .. ". Type /fce for help.")
    end
end

----------------------------------------------------------------------
-- Party chat announcements
--
-- Sends messages to PARTY chat so groupmates know you're playing
-- an enhanced class.  Controlled by FCE_GlobalDB.partyAnnounce.
----------------------------------------------------------------------

--- Check whether the player is in a party/raid.
--- Named HCE_IsInGroup to avoid shadowing the WoW API IsInGroup().
local function HCE_IsInGroup()
    if IsInGroup then return IsInGroup() end
    return (GetNumGroupMembers or GetNumPartyMembers or function() return 0 end)() > 0
end

--- Get the selected character data, or nil.
local function GetSelectedChar()
    if not FCE_CharDB or not FCE_CharDB.selectedCharacter then return nil end
    return FCE.GetCharacter and FCE.GetCharacter(FCE_CharDB.selectedCharacter)
end

--- Group-join announcement to party chat.
--- Waits until at least one other member is actually in the group
--- (not just invited), retrying a few times with a delay.
local function AnnounceGroupJoin(retries)
    retries = retries or 0
    if not FCE_GlobalDB.partyAnnounce then return end
    if not HCE_IsInGroup() then return end

    -- GetNumGroupMembers counts actual members (not pending invites).
    -- Right after sending an invite the count is 1 (just us).
    local count = (GetNumGroupMembers or GetNumPartyMembers or function() return 0 end)()
    if count < 2 then
        if retries < 10 then
            C_Timer.After(2.0, function() AnnounceGroupJoin(retries + 1) end)
        end
        return
    end

    local char = GetSelectedChar()
    if not char then return end

    local displayName = FCE.GetCharDisplayName and FCE.GetCharDisplayName(char) or char.name
    local msg = "[FCE] Beware! I’m playing as a " .. displayName
        .. " - a lore-based sub-optimal build with special rules."

    SendChatMessage(msg, "PARTY")
end

----------------------------------------------------------------------
-- Main event handler
----------------------------------------------------------------------
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == "ForeverClassesEnhanced" then
            FCE_GlobalDB = InitDB(FCE_GlobalDB, GLOBAL_DEFAULTS)
            FCE_CharDB   = InitDB(FCE_CharDB, CHAR_DEFAULTS)
        end

    elseif event == "PLAYER_LOGIN" then
        -- Snapshot current group state so a /reload while already grouped
        -- doesn't trigger a false "just joined" announcement.
        FCE._wasInGroup = HCE_IsInGroup()
        C_Timer.After(1.0, function()
            TryAutoDetect()
            FCE.PrintWelcome()
        end)
        -- Achievement system init (hooks rank-up, takes initial snapshot)
        if FCE.Achieve and FCE.Achieve.Init then
            FCE.Achieve.Init()
        end
        -- Language support check
        C_Timer.After(4.0, function()
            local locale = GetLocale()
            if locale ~= "enUS" and locale ~= "enGB" then
                local f = CreateFrame("Frame", "FCE_LanguageWarning", UIParent, "BackdropTemplate")
                f:SetSize(340, 100)
                f:SetPoint("TOP", UIParent, "TOP", 0, -120)
                f:SetBackdrop({
                    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
                    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
                    tile     = true, tileSize = 32, edgeSize = 24,
                    insets   = { left = 6, right = 6, top = 6, bottom = 6 },
                })
                f:SetBackdropColor(0.1, 0.08, 0.05, 0.95)
                f:SetFrameStrata("DIALOG")
                f:EnableMouse(true)
                f:SetMovable(true)
                f:RegisterForDrag("LeftButton")
                f:SetScript("OnDragStart", f.StartMoving)
                f:SetScript("OnDragStop", f.StopMovingOrSizing)

                local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
                title:SetPoint("TOP", 0, -14)
                title:SetText("|cffe6b422Forever Classes Enhanced|r")

                local msg = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                msg:SetPoint("TOP", title, "BOTTOM", 0, -6)
                msg:SetWidth(310)
                msg:SetJustifyH("CENTER")
                msg:SetText("Languages other than English are not yet supported. Some features may not work correctly.")

                local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
                btn:SetSize(80, 22)
                btn:SetPoint("BOTTOM", 0, 10)
                btn:SetText("OK")
                btn:SetScript("OnClick", function() f:Hide() end)

                f:Show()
            end
        end)

    elseif event == "GROUP_ROSTER_UPDATE" then
        -- Only announce once when we transition from solo -> grouped,
        -- not on every roster change (someone joins/leaves/role changes).
        local inGroup = HCE_IsInGroup()
        if inGroup and not FCE._wasInGroup then
            -- Just joined a group - announce after a short delay
            FCE._wasInGroup = true  -- set immediately to prevent double-fire
            C_Timer.After(2.0, function()
                AnnounceGroupJoin()
            end)
        elseif not inGroup then
            FCE._wasInGroup = false
        end

    elseif event == "PLAYER_LOGOUT" then
        -- Future: persist runtime state
    end
end)
