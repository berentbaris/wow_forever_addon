----------------------------------------------------------------------
-- ForeverClassesEnhanced — Quest Completion Tracker
--
-- Checks whether the player has completed the quests required by
-- their enhanced class.  Quest data lives in CharacterData.lua as
-- a quests = { {name, level, questID}, ... } array per character.
--
-- Uses the WoW API:
--   C_QuestLog.IsQuestFlaggedCompleted(questID)  — server-side,
--     persistent, no SavedVars needed.
--
-- Provides:
--   QuestCheck.RunCheck()   — refresh results
--   QuestCheck.GetResults() — { [i] = {status, detail} }
--   QuestCheck.STATUS       — {PASS, FAIL, UNCHECKED, INACTIVE}
----------------------------------------------------------------------


local GetQuestsCompleted
    = FCE.Compat.GetQuestsCompleted  -- Forever API shims (ForeverCompat.lua)
FCE = FCE or {}

local QC = {}
FCE.QuestCheck = QC

----------------------------------------------------------------------
-- Status constants
----------------------------------------------------------------------

local PASS      = "pass"
local FAIL      = "fail"
local UNCHECKED = "unchecked"
local INACTIVE  = "inactive"

QC.STATUS = {
    PASS      = PASS,
    FAIL      = FAIL,
    UNCHECKED = UNCHECKED,
    INACTIVE  = INACTIVE,
}

----------------------------------------------------------------------
-- Results cache — indexed by quest position in char.quests
----------------------------------------------------------------------

local results = {}

function QC.GetResults()
    return results
end

----------------------------------------------------------------------
-- Persistent completion tracking (for repeatable quests)
----------------------------------------------------------------------
-- IsQuestFlaggedCompleted returns false for repeatable quests because
-- the server clears the flag so the quest can be picked up again.
-- We catch QUEST_TURNED_IN and save completions in FCE_CharDB so
-- they survive the flag reset.

--- Build a set of quest IDs required by the current character.
local function getRequiredQuestIDs()
    if not FCE_CharDB or not FCE_CharDB.selectedCharacter then return {} end
    local char = FCE.GetCharacter and FCE.GetCharacter(FCE_CharDB.selectedCharacter)
    if not char then return {} end
    local quests = FCE.GetCharQuests and FCE.GetCharQuests(char) or char.quests or {}
    local set = {}
    for _, q in ipairs(quests) do
        set[q.questID] = true
    end
    return set
end

--- Mark a quest as completed in SavedVariables.
local function markCompleted(questID)
    if not FCE_CharDB then return end
    FCE_CharDB.completedQuests = FCE_CharDB.completedQuests or {}
    FCE_CharDB.completedQuests[questID] = true
end

--- Check if a quest was ever completed (API flag OR saved).
local function isCompleted(questID, apiCheck)
    -- Server-side flag (works for non-repeatable quests)
    if apiCheck(questID) then return true end
    -- Saved flag (catches repeatable quests)
    if FCE_CharDB and FCE_CharDB.completedQuests and FCE_CharDB.completedQuests[questID] then
        return true
    end
    return false
end

----------------------------------------------------------------------
-- Core check
----------------------------------------------------------------------

function QC.RunCheck()
    results = {}

    if not FCE_CharDB or not FCE_CharDB.selectedCharacter then return end
    local char = FCE.GetCharacter and FCE.GetCharacter(FCE_CharDB.selectedCharacter)
    if not char then return end
    local quests = FCE.GetCharQuests and FCE.GetCharQuests(char) or char.quests or {}
    if #quests == 0 then return end

    local playerLevel = UnitLevel("player") or 1

    -- C_QuestLog.IsQuestFlaggedCompleted may not exist on every
    -- Classic build.  Fall back to GetQuestsCompleted if needed.
    local apiCheck
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        apiCheck = C_QuestLog.IsQuestFlaggedCompleted
    else
        -- Bulk lookup fallback
        local completed = GetQuestsCompleted and GetQuestsCompleted() or {}
        apiCheck = function(qid) return completed[qid] end
    end

    for i, quest in ipairs(quests) do
        if playerLevel < quest.level then
            results[i] = {
                status = INACTIVE,
                detail = "Unlocks at level " .. quest.level,
            }
        else
            local done = isCompleted(quest.questID, apiCheck)
            if done then
                results[i] = {
                    status = PASS,
                    detail = quest.name .. " — completed",
                }
            else
                results[i] = {
                    status = FAIL,
                    detail = quest.name .. " — not yet completed (quest #" .. quest.questID .. ")",
                }
            end
        end
    end
end

----------------------------------------------------------------------
-- Slash command: /fce quests
----------------------------------------------------------------------

function QC.PrintStatus()
    if not FCE_CharDB or not FCE_CharDB.selectedCharacter then
        FCE.Print("No enhanced class selected.")
        return
    end

    local char = FCE.GetCharacter and FCE.GetCharacter(FCE_CharDB.selectedCharacter)
    if not char then
        FCE.Print("Your character has no quest requirements.")
        return
    end
    local quests = FCE.GetCharQuests and FCE.GetCharQuests(char) or char.quests or {}
    if #quests == 0 then
        FCE.Print("Your character has no quest requirements.")
        return
    end

    QC.RunCheck()

    -- Build group list
    local groups
    if char.questGroups then
        groups = char.questGroups
    elseif char.questTheme then
        groups = { { theme = char.questTheme, count = #quests } }
    else
        groups = { { theme = "Quests", count = #quests } }
    end

    local questIdx = 1
    for _, group in ipairs(groups) do
        FCE.Print("Quest progress — " .. (group.theme or "Quests") .. ":")
        for _ = 1, group.count do
            local quest = quests[questIdx]
            if not quest then break end
            local res = results[questIdx]
            questIdx = questIdx + 1
            local tag
            if not res or res.status == INACTIVE then
                tag = "|cff595959INACTIVE|r"
            elseif res.status == PASS then
                tag = "|cff4de64dDONE|r"
            elseif res.status == FAIL then
                tag = "|cffff5a4cINCOMPLETE|r"
            else
                tag = "|cffa5a582???|r"
            end
            FCE.Print("  " .. tag .. " [lv " .. quest.level .. "] " .. quest.name)
        end
    end
end

----------------------------------------------------------------------
-- Event frame — re-check on relevant events
----------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("QUEST_TURNED_IN")
eventFrame:RegisterEvent("QUEST_LOG_UPDATE")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    -- Only run if we have a selected character with quests
    if not FCE_CharDB or not FCE_CharDB.selectedCharacter then return end
    local char = FCE.GetCharacter and FCE.GetCharacter(FCE_CharDB.selectedCharacter)
    if not char then return end
    local quests = FCE.GetCharQuests and FCE.GetCharQuests(char) or char.quests or {}
    if #quests == 0 then return end

    if event == "PLAYER_LOGIN" then
        -- Initial check after a short delay so other systems are ready
        C_Timer.After(2, function()
            QC.RunCheck()
            if FCE.RefreshPanel then FCE.RefreshPanel() end
        end)
    elseif event == "QUEST_TURNED_IN" then
        -- QUEST_TURNED_IN fires with (questID, xpReward, moneyReward)
        local questID = ...
        if questID then
            local required = getRequiredQuestIDs()
            if required[questID] then
                markCompleted(questID)
            end
        end
        -- Re-check immediately
        C_Timer.After(0.5, function()
            QC.RunCheck()
            if FCE.RefreshPanel then FCE.RefreshPanel() end
        end)
    elseif event == "QUEST_LOG_UPDATE" then
        -- Throttle quest log updates to avoid spam
        C_Timer.After(1, function()
            QC.RunCheck()
        end)
    end
end)
