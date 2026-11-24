----------------------------------------------------------------------
-- ForeverClassesEnhanced — Appearance (barber shop) tracking
--
-- Addons can only read character customization at the barber shop
-- (C_BarberShop.GetAvailableCustomizations).  Appearance only changes
-- there, so we read it when the barber shop opens (= current look) and
-- again after changes are applied, and keep it in FCE_CharDB.appearance.
--
--   /fce barber   show the last captured dump (copyable): every option
--                 and choice with IDs, current choice marked.  Used to
--                 write appearance rules (match by choice ID).
----------------------------------------------------------------------

FCE = FCE or {}
local AC = {}
FCE.AppearanceCheck = AC

local function s(v) return v == nil and "nil" or tostring(v) end

local function swatchHex(c)
    if type(c) ~= "table" then return nil end
    local ok, hex = pcall(function() return c:GenerateHexColor() end)
    return ok and hex or nil
end

--- Character model mode: "sd" (Standard Definition) or "hd".
--- Forever-only account rule (C_GameRules.AccountHasSDEnabled); nil if unknown.
function AC.ModelMode()
    if C_GameRules and C_GameRules.AccountHasSDEnabled then
        local ok, sd = pcall(C_GameRules.AccountHasSDEnabled)
        if ok and sd ~= nil then return sd and "sd" or "hd" end
    end
    return nil
end

--- "Dwarf_F" style key for per-race rules.
local function raceSexKey(raceToken, sex)
    return tostring(raceToken) .. "_" .. ((sex == 3) and "F" or "M")
end
AC.RaceSexKey = raceSexKey

--- Read the current customization.  Returns look table + dump text, or nil.
local function ReadLook()
    if not (C_BarberShop and C_BarberShop.GetAvailableCustomizations) then return nil end
    local ok, cats = pcall(C_BarberShop.GetAvailableCustomizations)
    if not ok or type(cats) ~= "table" or #cats == 0 then return nil end

    local _, raceToken = UnitRace("player")
    local look = {
        time    = date("%Y-%m-%d %H:%M"),
        race    = raceToken,
        sex     = UnitSex("player"),
        models  = AC.ModelMode(),
        options = {},      -- [optionID] = { name, category, formID, choiceID, choiceName, choiceIndex }
    }
    local L = {
        "Forever Classes Enhanced - barber shop dump",
        "Captured: " .. look.time .. "   Race: " .. s(raceToken) .. "   Sex: " .. s(look.sex)
            .. "   Models: " .. string.upper(look.models or "?"),
        "Format: option [optionID] = current choice;  choices: index:choiceID name (#swatch)",
    }
    local anyCurrent = false
    for _, cat in ipairs(cats) do
        L[#L + 1] = ""
        L[#L + 1] = "== " .. s(cat.name) .. " (category " .. s(cat.id)
            .. (cat.spellShapeshiftFormID and (", form " .. cat.spellShapeshiftFormID) or "") .. ") =="
        for _, opt in ipairs(cat.options or {}) do
            local cur = opt.currentChoiceIndex and opt.choices and opt.choices[opt.currentChoiceIndex]
            if cur then anyCurrent = true end
            look.options[opt.id] = {
                name = opt.name, category = cat.name, formID = cat.spellShapeshiftFormID,
                choiceID = cur and cur.id, choiceName = cur and cur.name,
                choiceIndex = opt.currentChoiceIndex,
                swatch = cur and swatchHex(cur.swatchColor1),
            }
            L[#L + 1] = string.format("%s [%s] = %s", s(opt.name), s(opt.id),
                cur and (s(opt.currentChoiceIndex) .. ":" .. s(cur.id) .. " " .. s(cur.name)) or "?")
            local parts = {}
            for i, ch in ipairs(opt.choices or {}) do
                local hex = swatchHex(ch.swatchColor1)
                parts[#parts + 1] = i .. ":" .. s(ch.id)
                    .. ((ch.name and ch.name ~= "") and (" " .. ch.name) or "")
                    .. (hex and (" #" .. hex) or "")
            end
            L[#L + 1] = "    " .. table.concat(parts, ", ")
        end
    end
    if not anyCurrent then return nil end   -- options listed but no current look
    return look, table.concat(L, "\n")
end

local function Capture(reason)
    local look, text = ReadLook()
    if not look or not FCE_CharDB then return false end
    look.source = reason
    text = text:gsub("\n", "   Source: " .. reason .. "\n", 1)
    FCE_CharDB.appearance = look
    FCE_CharDB.appearanceDump = text
    if AC.RunCheck then AC.RunCheck() end
    if FCE.RefreshPanel then FCE.RefreshPanel() end
    return true
end
AC.Capture = Capture

--- Saved look (nil until the first barber shop visit).
function AC.GetLook()
    return FCE_CharDB and FCE_CharDB.appearance
end

--- Current choice for an option: by optionID (number) or option name (string).
function AC.GetChoice(option)
    local look = AC.GetLook()
    if not look then return nil end
    if type(option) == "number" then return look.options[option] end
    for _, o in pairs(look.options) do
        if o.name == option then return o end
    end
    return nil
end

function AC.ShowDump()
    local text = FCE_CharDB and FCE_CharDB.appearanceDump
    if not text then
        FCE.Print("No barber shop capture yet \226\128\148 sit in a barber chair once, then run /fce barber again.")
        return
    end
    FCE.Print("Barber shop dump from " .. s(FCE_CharDB.appearance and FCE_CharDB.appearance.time)
        .. " \226\128\148 opening the report window")
    if FCE.APIProbe and FCE.APIProbe.ShowWindow then
        FCE.APIProbe.ShowWindow(text)
    else
        for line in text:gmatch("[^\n]+") do FCE.Print(line) end
    end
end

----------------------------------------------------------------------
-- Appearance rules
--
-- Keyed by the requirement description used in CharacterData
-- (appearance = { E("Braids", 1) }).  Per gender (M / F) a list of
-- conditions that must ALL hold; a gender without a list is "not
-- applicable" (passes).  Condition fields:
--   option     exact option name as shown by /fce barber ("Facial Hair")
--   positions  qualifying positions (the number before the colon in
--              /fce barber); or { sd = {...}, hd = {...} } if they differ
--   sdOnly     only checked with Standard Definition models
-- Optional: label = { M = "...", F = "..." } — panel text per gender.
--           races = { Human = true } — only these race tokens (others: not applicable)
----------------------------------------------------------------------

local PASS, FAIL, UNCHECKED = "pass", "fail", "unchecked"

local function C(option, positions, extra)
    local c = { option = option, positions = positions }
    if extra then for k, v in pairs(extra) do c[k] = v end end
    return c
end
local SD_ONLY = { sdOnly = true }

AC.Rules = {
    ["Braids"] = {                                   -- Blademaster (Orc)
        M = { C("Facial Hair", { 6, 7, 8, 9 }) },
        F = { C("Hair Style", { 15, 1, 2 }) },
    },
    ["Blind/Demon Hunter Markings"] = {              -- Demon Hunter (Night Elf)
        label = { M = "Blind", F = "Demon Hunter Markings" },
        M = { C("Face", { 6 }) },
        F = { C("Markings", { 2, 6 }) },
    },
    ["Metallic skin"] = {                            -- Sister of Steel (Dwarf)
        F = { C("Skin Color", { 9 }) },
    },
    ["Withered"] = {                                 -- Apothecary (Undead)
        M = { C("Jaw Features", { 2, 3, 4, 5, 6, 7, 8, 9, 10 }), C("Face Features", { 2, 3, 4, 5 }) },
        F = { C("Jaw Features", { 2, 3, 4, 5 }), C("Face Features", { 2, 3, 4 }) },
    },
    ["White fur & blue eyes"] = {                    -- Spiritwalker (Tauren)
        M = { C("Skin Color", { 19 }), C("Face", { 5 }, SD_ONLY) },
        F = { C("Skin Color", { 11 }), C("Face", { 1 }, SD_ONLY) },
    },
    ["Wildhammer Dwarf (ginger)"] = {                -- Mountain King rogue (Dwarf)
        M = { C("Hair Color", { 1, 2, 3 }) },
        F = { C("Hair Color", { 1, 2, 3 }) },
    },
    ["Face Paint"] = {                               -- Berserker, Shadow Hunter (Troll)
        M = { C("Face Paint", { 2, 3, 4, 5, 6, 7 }) },
    },
    ["Jungle Troll (green skin)"] = {                -- Witch Doctor (Troll)
        M = { C("Skin Color", { 3 }) },
        F = { C("Skin Color", { 3 }) },
    },
    ["Hairless"] = {                                 -- Templar (human males only)
        races = { Human = true },
        M = { C("Hair Style", { 1 }), C("Facial Hair", { 9 }) },
    },
    ["Fallen Elf (blonde, face intact)"] = {         -- Bloodmage (Undead)
        M = { C("Hair Color", { 4, 5, 7 }), C("Face Features", { 1 }), C("Jaw Features", { 1 }),
              C("Face", { 1, 2, 5, 9 }) },
        F = { C("Hair Color", { 4, 5, 7 }), C("Face Features", { 1 }), C("Jaw Features", { 1 }),
              C("Face", { 1, 4, 7, 8, 9 }) },
    },
    ["Light hair"] = {                               -- Death Knight (Undead)
        M = { C("Hair Color", { 4, 5, 7 }) },
        F = { C("Hair Color", { 4, 5, 7 }) },
    },
}

local function genderKey()
    return (UnitSex("player") == 3) and "F" or "M"
end

--- Panel text for a requirement (gender-specific label if the rule has one).
function AC.DisplayName(desc)
    local rule = AC.Rules[desc]
    local g = genderKey()
    if rule and rule.label and rule.label[g] then return rule.label[g] end
    return desc
end

local function findOption(look, name)
    local want = name:lower()
    for _, o in pairs(look.options) do
        if o.formID == nil and type(o.name) == "string" and o.name:lower() == want then
            return o
        end
    end
    return nil
end

--- Check one appearance requirement.  Returns status, detail.
function AC.CheckRule(desc)
    local rule = AC.Rules[desc]
    if not rule then return UNCHECKED, "No rule defined for this requirement" end
    if rule.races then
        local _, raceToken = UnitRace("player")
        if not rule.races[raceToken] then
            return PASS, "Not applicable to this character's race"
        end
    end
    local conds = rule[genderKey()]
    if not conds then
        return PASS, "Not applicable to this character's gender"
    end
    local look = AC.GetLook()
    if not look then
        return UNCHECKED, "Sit in a barber chair once so FCE can read your appearance"
    end
    local mode = AC.ModelMode()
    local parts, failed, missing = {}, false, false
    for _, c in ipairs(conds) do
        if not (c.sdOnly and mode == "hd") then
            local o = findOption(look, c.option)
            if not o then
                missing = true
                parts[#parts + 1] = c.option .. ": not found"
            else
                local list = c.positions
                if list.sd or list.hd then list = (mode and list[mode]) or list.hd or list.sd end
                local ok = false
                for _, p in ipairs(list or {}) do
                    if p == o.choiceIndex then ok = true break end
                end
                local cur = (o.choiceName and o.choiceName ~= "") and o.choiceName
                    or tostring(o.choiceIndex or "?")
                if ok then
                    parts[#parts + 1] = c.option .. " " .. cur .. " \226\156\147"
                else
                    failed = true
                    local need = {}
                    for _, p in ipairs(list or {}) do need[#need + 1] = tostring(p) end
                    parts[#parts + 1] = c.option .. " " .. cur .. " (needs " .. table.concat(need, "/") .. ")"
                end
            end
        end
    end
    local detail = table.concat(parts, ", ") .. (mode and (" [" .. mode:upper() .. "]") or "")
    if failed then return FAIL, detail .. " \226\128\148 change it at the barber shop" end
    if missing then return UNCHECKED, detail .. " \226\128\148 send the /fce barber dump" end
    return PASS, detail
end

--- Check all appearance requirements of the selected character.
--- Results: { [i] = { status, detail, desc, level, endLevel } }
function AC.RunCheck()
    local results = {}
    local key = FCE_CharDB and FCE_CharDB.selectedCharacter
    local char = key and FCE.GetCharacter and FCE.GetCharacter(key)
    local list = char and char.appearance
    if not list then
        if FCE_CharDB then FCE_CharDB.appearanceResults = results end
        return results
    end
    local level = UnitLevel("player") or 1
    for i, req in ipairs(list) do
        local r = { desc = req.desc, level = req.level, endLevel = req.endLevel }
        if req.endLevel and level > req.endLevel then
            r.status, r.detail = "inactive", "Superseded"
        elseif level < req.level then
            r.status, r.detail = "inactive", "Unlocks at level " .. req.level
        else
            r.status, r.detail = AC.CheckRule(req.desc)
        end
        results[i] = r
    end
    if FCE_CharDB then FCE_CharDB.appearanceResults = results end
    return results
end

function AC.GetResults()
    return FCE_CharDB and FCE_CharDB.appearanceResults or {}
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------

local ef = CreateFrame("Frame")
ef:RegisterEvent("PLAYER_LOGIN")
ef:RegisterEvent("PLAYER_LEVEL_UP")
for _, ev in ipairs({ "BARBER_SHOP_OPEN", "BARBER_SHOP_APPEARANCE_APPLIED", "BARBER_SHOP_RESULT",
                      "GAME_RULES_CHANGED" }) do
    pcall(ef.RegisterEvent, ef, ev)
end

ef:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGIN" then
        -- Probe: does the API also work away from the barber shop?
        FCE.After("AppearanceCheck", 4, function()
            local okLive = Capture("live")
            if FCE_GlobalDB then FCE_GlobalDB.barberLiveReadable = okLive end
            AC.RunCheck()
        end)
    elseif event == "PLAYER_LEVEL_UP" then
        FCE.After("AppearanceCheck", 1, AC.RunCheck)
    elseif event == "GAME_RULES_CHANGED" then
        -- SD/HD model setting may have changed
        FCE.After("AppearanceCheck", 0.5, function()
            AC.RunCheck()
            if FCE.RefreshPanel then FCE.RefreshPanel() end
        end)
    elseif event == "BARBER_SHOP_OPEN" then
        -- Nothing previewed yet: this is the real current look
        FCE.After("AppearanceCheck", 0.5, function()
            if Capture("barber open") then
                FCE.Print("Appearance read at the barber shop \226\128\148 /fce barber shows the dump.")
            end
        end)
    elseif event == "BARBER_SHOP_APPEARANCE_APPLIED"
        or (event == "BARBER_SHOP_RESULT" and arg1) then
        FCE.After("AppearanceCheck", 0.5, function() Capture("barber applied") end)
    end
end)

FCE.Compat.GuardScript(ef, "OnEvent", "AppearanceCheck")
