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
        options = {},      -- [optionID] = { name, category, formID, choiceID, choiceName, choiceIndex }
    }
    local L = {
        "Forever Classes Enhanced - barber shop dump",
        "Captured: " .. look.time .. "   Race: " .. s(raceToken) .. "   Sex: " .. s(look.sex),
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
-- (appearance = { E("Braided beard", 1) }).  Fields:
--   options     lowercase substrings matched against the option name
--               ("facial hair", "beard").  First matching option is used.
--   choiceIDs   set of accepted choice IDs (exact; from /fce barber)
--   names       lowercase substrings matched against the choice name
--   maxSaturation  accept colour swatches at or below this saturation
--               (0 = pure grey, 1 = vivid) — for "grey skin" style rules
--   genders     set of UnitSex values the rule applies to (2 male,
--               3 female); other genders pass as "not applicable"
--   hint        shown when failing
-- A choice passes if it matches choiceIDs OR names OR maxSaturation.
----------------------------------------------------------------------

local PASS, FAIL, UNCHECKED = "pass", "fail", "unchecked"

AC.Rules = {
    ["Braided beard"] = {
        options = { "facial hair", "beard" },
        names   = { "braid" },
        genders = { [2] = true },
        hint    = "pick a braided facial hair style at the barber shop",
    },
    ["Grey skin"] = {
        options = { "skin color", "skin colour", "skin" },
        maxSaturation = 0.15,
        hint    = "pick a grey skin colour at the barber shop",
    },
}

local function saturationOf(hex)
    -- swatch hex is AARRGGBB
    if type(hex) ~= "string" or #hex < 8 then return nil end
    local r = tonumber(hex:sub(3, 4), 16)
    local g = tonumber(hex:sub(5, 6), 16)
    local b = tonumber(hex:sub(7, 8), 16)
    if not (r and g and b) then return nil end
    local mx, mn = math.max(r, g, b), math.min(r, g, b)
    if mx == 0 then return 0 end
    return (mx - mn) / mx
end
AC.SaturationOf = saturationOf

local function findOption(look, patterns)
    for _, p in ipairs(patterns or {}) do
        for _, o in pairs(look.options) do
            if o.formID == nil and type(o.name) == "string" and o.name:lower():find(p, 1, true) then
                return o
            end
        end
    end
    return nil
end

--- Check one appearance requirement.  Returns status, detail.
function AC.CheckRule(desc)
    local rule = AC.Rules[desc]
    if not rule then return UNCHECKED, "No rule defined for this requirement" end
    if rule.genders and not rule.genders[UnitSex("player") or 0] then
        return PASS, "Not applicable to this character's gender"
    end
    local look = AC.GetLook()
    if not look then
        return UNCHECKED, "Sit in a barber chair once so FCE can read your appearance"
    end
    local o = findOption(look, rule.options)
    if not o then
        return UNCHECKED, "Option not found for your race \226\128\148 send the /fce barber dump"
    end
    local label = (o.choiceName and o.choiceName ~= "") and o.choiceName
        or ("choice " .. tostring(o.choiceIndex or "?"))
    local ok = false
    if rule.choiceIDs and o.choiceID and rule.choiceIDs[o.choiceID] then ok = true end
    if not ok and rule.names and type(o.choiceName) == "string" then
        local n = o.choiceName:lower()
        for _, p in ipairs(rule.names) do
            if n:find(p, 1, true) then ok = true break end
        end
    end
    if not ok and rule.maxSaturation then
        local sat = saturationOf(o.swatch)
        if sat and sat <= rule.maxSaturation then ok = true end
    end
    if ok then
        return PASS, string.format("%s: %s", o.name, label)
    end
    return FAIL, string.format("%s: %s \226\128\148 %s", o.name, label, rule.hint or "change it at the barber shop")
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
for _, ev in ipairs({ "BARBER_SHOP_OPEN", "BARBER_SHOP_APPEARANCE_APPLIED", "BARBER_SHOP_RESULT" }) do
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
