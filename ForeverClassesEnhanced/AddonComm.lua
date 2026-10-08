----------------------------------------------------------------------
-- ForeverClassesEnhanced  —  Addon Communication  (v4)
--
-- Modelled after AutoLayer_Vanilla's proven pattern:
--   - Hidden custom channel "hce"
--   - Messages queued, sent only on hardware events (mouse/key)
--     because SendChatMessage is protected in Classic 1.15.x
--   - ChatFrame_RemoveChannel hides protocol traffic
----------------------------------------------------------------------


local SendChatMessage, ChatFrame_AddMessageEventFilter, ChatFrame_RemoveChannel
    = FCE.Compat.SendChatMessage, FCE.Compat.ChatFrame_AddMessageEventFilter, FCE.Compat.ChatFrame_RemoveChannel  -- Forever API shims (ForeverCompat.lua)
FCE = FCE or {}

local Comm = {}
FCE.AddonComm = Comm

local CHANNEL_NAME = "hce"
local PROTO_TAG    = "FCE:"
local CACHE_TTL    = 240        -- 4 min; generous AFK window since sends need hardware events

----------------------------------------------------------------------
-- Debug
----------------------------------------------------------------------
local debugMode = false

function Comm.ToggleDebug()
    debugMode = not debugMode
    FCE.Print(debugMode and "|cff00ff00AddonComm debug ON|r" or "|cffff6060AddonComm debug OFF|r")
end

local function dbg(msg)
    if debugMode and FCE.Print then
        FCE.Print("|cff888888[dbg] " .. msg .. "|r")
    end
end

----------------------------------------------------------------------
-- Rank colours
----------------------------------------------------------------------
local RANK_COLORS = {
    ["Master"]   = "ff8000",
    ["Elite"]    = "a335ee",
    ["Prime"]    = "0070dd",
    ["Adept"]    = "1eff00",
    ["Initiate"] = "ffffff",
}

----------------------------------------------------------------------
-- Player cache
----------------------------------------------------------------------
local playerCache = {}

function Comm.GetPlayerClass(name)
    local e = playerCache[name]
    if e and (GetTime() - e.time) < CACHE_TTL then return e.class end
    return nil
end

function Comm.GetPlayerRank(name)
    local e = playerCache[name]
    if e and (GetTime() - e.time) < CACHE_TTL then return e.rank end
    return nil
end

local function cachePlayer(name, className, rank, level, zone)
    if not name or name == "" or not className or className == "" then return end
    local short = name:match("^([^%-]+)") or name

    local isNew = true
    for k, v in pairs(playerCache) do
        local ks = k:match("^([^%-]+)") or k
        if ks == short and (GetTime() - v.time) < CACHE_TTL then
            isNew = false
            break
        end
    end

    playerCache[name] = {
        class = className,
        rank  = rank or "Initiate",
        level = tonumber(level) or 0,
        zone  = zone or "",
        time  = GetTime(),
    }
    dbg("Cached: " .. short .. " = " .. className .. " (" .. (rank or "Initiate") .. ") lv" .. tostring(level or "?") .. " @ " .. tostring(zone or "?") .. (isNew and " NEW" or ""))

    -- (no per-player chat spam; periodic count printed by ticker instead)
end

----------------------------------------------------------------------
-- Own identity
----------------------------------------------------------------------

-- Shortened names for addon comm display (long names clutter chat tags)
local COMM_SHORT_NAMES = {
    ["Wilderness Stalker"]       = "W. Stalker",
    ["Spirit Champion"]          = "Spirit C.",
    ["Scarlet Champion"]         = "Scarlet C.",
    ["Priestess of the Moon"]    = "P. of the Moon",
    ["Druid of the Claw"]        = "D. of the Claw",
    ["Kirin Tor Mage"]    = "K. T. Mage",
    ["Elven Ranger"]    = "E. Ranger",
    ["Dark Ranger"]    = "D. Ranger",
    ["Mountain King"]    = "M. King",
    ["Demon Hunter"]    = "D. Hunter",
    ["Sister of Steel"]    = "S. of Steel",
    ["Hedge Wizard"]    = "H. Wizard",
}

local function getMyClassName()
    if not FCE_CharDB or not FCE_CharDB.selectedCharacter then return nil end
    local char = FCE.GetCharacter and FCE.GetCharacter(FCE_CharDB.selectedCharacter)
    if not char then return nil end
    local full = FCE.GetCharDisplayName and FCE.GetCharDisplayName(char) or char.name
    return COMM_SHORT_NAMES[full] or full
end

local function getMyRank()
    if not FCE.Progress or not FCE.Progress.Collect
       or not FCE.Progress.Percentage or not FCE.Progress.GetRank then
        return "Initiate"
    end
    local s = FCE.Progress.Collect()
    if not s or not s.counts then return "Initiate" end
    return FCE.Progress.GetRank(FCE.Progress.Percentage(s.counts))
end

----------------------------------------------------------------------
-- Channel management  (mirrors AutoLayer)
----------------------------------------------------------------------
local function joinHCE()
    JoinChannelByName(CHANNEL_NAME)
    local id = GetChannelName(CHANNEL_NAME)
    if id and id > 0 then
        for i = 1, 10 do
            local cf = _G["ChatFrame" .. i]
            if cf then ChatFrame_RemoveChannel(cf, CHANNEL_NAME) end
        end
        dbg("Joined channel #" .. id)
        return true
    end
    dbg("Join failed")
    return false
end

----------------------------------------------------------------------
-- Send queue  (AutoLayer pattern)
--
-- SendChatMessage is protected in Classic 1.15.x — it can only be
-- called from a hardware-event execution path (mouse click, key
-- press).  We queue outgoing messages and drain the queue on
-- WorldFrame:OnMouseDown and a keyboard hook, exactly like AutoLayer.
----------------------------------------------------------------------
local sendQueue = {}

local function queueMsg(text)
    sendQueue[#sendQueue + 1] = text
    dbg("queued: " .. text .. " (queue=" .. #sendQueue .. ")")
end

local function drainQueue()
    if #sendQueue == 0 then return end

    local id = GetChannelName(CHANNEL_NAME)
    if not id or id == 0 then
        joinHCE()
        id = GetChannelName(CHANNEL_NAME)
        if not id or id == 0 then return end
    end

    -- Send ONE message per hardware event to avoid throttle
    local text = table.remove(sendQueue, 1)
    dbg("drain #" .. id .. ": " .. text)
    SendChatMessage(text, "CHANNEL", nil, id)
end

----------------------------------------------------------------------
-- Protocol helpers
----------------------------------------------------------------------
local function helloText()
    local c = getMyClassName()
    if not c then return nil end
    local lvl = UnitLevel("player") or 0
    local zone = GetZoneText() or ""
    return PROTO_TAG .. "HELLO:" .. c .. ":" .. getMyRank() .. ":" .. tostring(lvl) .. ":" .. zone
end

local function queueHello()
    -- Don't broadcast if WoW class doesn't match selected character's class
    local selKey = FCE_CharDB and FCE_CharDB.selectedCharacter
    local selChar = selKey and FCE.GetCharacter and FCE.GetCharacter(selKey)
    if selChar then
        local _, playerClass = UnitClass("player")
        if playerClass and selChar.class and playerClass ~= selChar.class then return end
    end
    -- Don't broadcast if above lv 29 and still Initiate (not progressing)
    local lvl = UnitLevel("player") or 0
    if lvl > 29 and getMyRank() == "Initiate" then return end
    local h = helloText()
    if h then queueMsg(h) end
end

local function queuePing()
    queueMsg(PROTO_TAG .. "PING")
end

----------------------------------------------------------------------
-- Receive  (CHAT_MSG_CHANNEL handler)
----------------------------------------------------------------------
local function onChannelMsg(msg, sender, channelName)
    if not channelName or channelName:lower() ~= CHANNEL_NAME then return end
    if not msg or msg:sub(1, #PROTO_TAG) ~= PROTO_TAG then return end

    local short = sender:match("^([^%-]+)") or sender
    if short == UnitName("player") then return end

    local payload = msg:sub(#PROTO_TAG + 1)
    dbg("recv from " .. short .. ": " .. payload)

    if payload:sub(1, 6) == "HELLO:" then
        local rest = payload:sub(7)
        -- Format: className:rank:level:zone (zone may contain colons)
        local className, rank, lvl, zone = rest:match("^([^:]+):([^:]+):([^:]+):(.+)$")
        if not className then
            -- Fallback: old format className:rank
            className, rank = rest:match("^([^:]+):([^:]+)$")
            if not className then className = rest; rank = "Initiate" end
            lvl = nil
            zone = nil
        end
        cachePlayer(sender, className, rank, lvl, zone)
        cachePlayer(short, className, rank, lvl, zone)
    elseif payload == "PING" then
        queueHello()
    end
end

----------------------------------------------------------------------
-- Chat tag injection  (SAY / YELL / PARTY / GUILD / WHISPER only)
----------------------------------------------------------------------
local TAG_EVENTS = {
    "CHAT_MSG_SAY",
    "CHAT_MSG_YELL",
    "CHAT_MSG_PARTY",
    "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID",
    "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_GUILD",
    "CHAT_MSG_OFFICER",
    "CHAT_MSG_WHISPER",
}

local function chatTagFilter(self, event, msg, sender, ...)
    if not msg or not sender then return false end
    local short = sender:match("^([^%-]+)") or sender
    local cls = Comm.GetPlayerClass(sender) or Comm.GetPlayerClass(short)
    if not cls then return false end
    local rank = Comm.GetPlayerRank(sender) or Comm.GetPlayerRank(short) or "Initiate"
    local col = RANK_COLORS[rank] or "ffffff"
    local tag = "|cffffd100[|cff" .. col .. rank .. "|r " .. cls .. "]|r "
    return false, tag .. msg, sender, ...
end

----------------------------------------------------------------------
-- Scan popup frame  (shown when clicking the magnifying glass)
----------------------------------------------------------------------
local scanFrame = nil

local function getOnlinePlayers()
    local found, seen = {}, {}
    local now = GetTime()
    for name, e in pairs(playerCache) do
        if (now - e.time) < CACHE_TTL then
            local s = name:match("^([^%-]+)") or name
            if not seen[s] then
                seen[s] = true
                found[#found+1] = {
                    name  = s,
                    class = e.class,
                    rank  = e.rank,
                    level = e.level or 0,
                    zone  = e.zone or "",
                }
            end
        end
    end
    table.sort(found, function(a, b) return a.name < b.name end)
    return found
end

local FRAME_W   = 360
local FRAME_H   = 320
local ROW_H     = 16
local HEADER_H  = 40
local COL_NAME  = 90
local COL_LVL   = 28
local COL_RANK  = 62
local COL_CLASS = 100
local BTN_SZ    = 16
local CONTENT_W = FRAME_W - 40

local function createScanFrame()
    -- Anchor to the left of the art panel (or requirements panel fallback)
    local artPanel = _G["HCE_ArtPanel"]
    local anchor = artPanel or _G["HCE_RequirementsPanel"]

    local f = CreateFrame("Frame", "HCE_ScanFrame", anchor or UIParent, "BackdropTemplate")
    f:SetSize(FRAME_W, FRAME_H)

    if anchor then
        f:SetPoint("TOPRIGHT", anchor, "TOPLEFT", 2, 0)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", -200, 40)
    end

    f:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
        edgeSize = 16,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0.06, 0.06, 0.08, 1.0)
    f:SetBackdropBorderColor(1.0, 0.85, 0.45, 0.95)
    f:EnableMouse(true)
    f:SetFrameStrata("MEDIUM")

    -- Close with Escape
    tinsert(UISpecialFrames, "HCE_ScanFrame")

    -- Solid opaque fill (match requirements panel)
    local solidBg = f:CreateTexture(nil, "BACKGROUND", nil, 0)
    solidBg:SetColorTexture(0.20, 0.20, 0.20, 1.0)
    solidBg:SetPoint("TOPLEFT", 6, -6)
    solidBg:SetPoint("BOTTOMRIGHT", -6, 6)

    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 0, -12)
    title:SetText("|cffffd100FCE Players|r")
    f._title = title

    -- Close button
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetSize(24, 24)
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function() f:Hide() end)

    -- Column header bar
    local hdrY = -HEADER_H
    local headers = { { "Name", 14 }, { "Lv", 14 + COL_NAME + 4 }, { "Rank", 14 + COL_NAME + COL_LVL + 8 }, { "Class", 14 + COL_NAME + COL_LVL + COL_RANK + 12 } }
    for _, h in ipairs(headers) do
        local lbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", f, "TOPLEFT", h[2], hdrY)
        lbl:SetText("|cffbbbb88" .. h[1] .. "|r")
    end

    -- Separator
    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetColorTexture(0.5, 0.42, 0.20, 0.5)
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", f, "TOPLEFT", 10, hdrY - 12)
    sep:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, hdrY - 12)

    -- Scroll area
    local scroll = CreateFrame("ScrollFrame", "HCE_ScanScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 10, hdrY - 14)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30, 24)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(CONTENT_W)
    content:SetHeight(1)
    scroll:SetScrollChild(content)
    f._content = content
    f._rows = {}

    -- Player count
    local countLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countLabel:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 8)
    countLabel:SetText("")
    f._countLabel = countLabel

    return f
end

local function acquireScanRow(index)
    local rows = scanFrame._rows
    if rows[index] then
        rows[index]:Show()
        return rows[index]
    end
    local parent = scanFrame._content
    local r = CreateFrame("Frame", nil, parent)
    r:SetHeight(ROW_H)
    r:SetWidth(CONTENT_W)
    r:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(index - 1) * ROW_H)

    -- Highlight
    r.hl = r:CreateTexture(nil, "BACKGROUND")
    r.hl:SetAllPoints()
    r.hl:SetColorTexture(1, 0.82, 0.3, 0.08)
    r.hl:Hide()

    -- Name
    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.name:SetPoint("LEFT", r, "LEFT", 4, 0)
    r.name:SetWidth(COL_NAME)
    r.name:SetJustifyH("LEFT")

    -- Level
    r.lvl = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.lvl:SetPoint("LEFT", r.name, "RIGHT", 4, 0)
    r.lvl:SetWidth(COL_LVL)
    r.lvl:SetJustifyH("CENTER")

    -- Rank
    r.rank = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.rank:SetPoint("LEFT", r.lvl, "RIGHT", 4, 0)
    r.rank:SetWidth(COL_RANK)
    r.rank:SetJustifyH("LEFT")

    -- Class
    r.class = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.class:SetPoint("LEFT", r.rank, "RIGHT", 4, 0)
    r.class:SetWidth(COL_CLASS)
    r.class:SetJustifyH("LEFT")

    -- Zone icon (hover-only, shows zone in tooltip)
    local zBtn = CreateFrame("Frame", nil, r)
    zBtn:SetSize(BTN_SZ, BTN_SZ)
    zBtn:SetPoint("RIGHT", r, "RIGHT", -2, 0)
    local zIcon = zBtn:CreateTexture(nil, "ARTWORK")
    zIcon:SetAllPoints()
    zIcon:SetTexture("Interface\\MINIMAP\\TRACKING\\None")
    zIcon:SetVertexColor(0.6, 0.6, 0.6)
    r._zone = ""
    zBtn:EnableMouse(true)
    zBtn:SetScript("OnEnter", function(self)
        if r._zone and r._zone ~= "" then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(r._zone, 0.47, 0.67, 0.80)
            GameTooltip:Show()
        end
    end)
    zBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r.zBtn = zBtn

    -- Whisper button
    local wBtn = CreateFrame("Button", nil, r)
    wBtn:SetSize(BTN_SZ, BTN_SZ)
    wBtn:SetPoint("RIGHT", zBtn, "LEFT", -1, 0)
    wBtn:SetNormalTexture("Interface\\CHATFRAME\\UI-ChatIcon-Chat-Up")
    wBtn:SetPushedTexture("Interface\\CHATFRAME\\UI-ChatIcon-Chat-Down")
    wBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    wBtn:SetScript("OnClick", function()
        if r._playerName then
            -- ChatFrame_OpenChat is protected on Forever (fails silently
            -- and bumps the "action blocked" counter), so just print the
            -- whisper command for the player to type.
            FCE.Print("Whisper: |cffffcc00/w " .. r._playerName .. "|r")
        end
    end)
    wBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Whisper " .. (r._playerName or ""))
        GameTooltip:Show()
    end)
    wBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r.wBtn = wBtn

    -- Invite button — regular button; clicks are hardware events so InviteUnit works
    local iBtn = CreateFrame("Button", nil, r)
    iBtn:SetSize(BTN_SZ, BTN_SZ)
    iBtn:SetPoint("RIGHT", wBtn, "LEFT", -1, 0)
    iBtn:SetNormalTexture("Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon")
    iBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    iBtn:RegisterForClicks("AnyUp", "AnyDown")
    iBtn:SetScript("OnClick", function()
        local name = r._playerName
        if not name or name == "" then return end
        -- Try all known invite APIs; one of them will work on this client
        if C_PartyInfo and C_PartyInfo.InviteUnit then
            C_PartyInfo.InviteUnit(name)
        elseif InviteUnit then
            InviteUnit(name)
        end
        if FCE.Print then
            FCE.Print("Invited |cffffffff" .. name .. "|r to group.")
        end
    end)
    iBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Invite " .. (r._playerName or ""))
        GameTooltip:Show()
    end)
    iBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r.iBtn = iBtn

    -- Row hover
    r:EnableMouse(true)
    r:SetScript("OnEnter", function(self)
        self.hl:Show()
        self.name:SetTextColor(1, 0.9, 0.5)
    end)
    r:SetScript("OnLeave", function(self)
        self.hl:Hide()
        self.name:SetTextColor(1, 1, 1)
    end)

    rows[index] = r
    return r
end

local function refreshScanFrame()
    if not scanFrame then scanFrame = createScanFrame() end

    -- Re-anchor to art panel (or requirements panel) if it exists now
    local artPanel = _G["HCE_ArtPanel"]
    local anchor = artPanel or _G["HCE_RequirementsPanel"]
    if anchor and scanFrame:GetParent() ~= anchor then
        scanFrame:SetParent(anchor)
        scanFrame:ClearAllPoints()
        scanFrame:SetPoint("TOPRIGHT", anchor, "TOPLEFT", 2, 0)
    end

    local players = getOnlinePlayers()
    local content = scanFrame._content

    for _, r in pairs(scanFrame._rows) do r:Hide() end

    if #players == 0 then
        scanFrame._countLabel:SetText("|cff8888880 players found|r")
        content:SetHeight(ROW_H)
        local r = acquireScanRow(1)
        r.name:SetText("|cff666666Searching...|r")
        r.name:SetTextColor(0.6, 0.6, 0.6)
        r.lvl:SetText("")
        r.rank:SetText("")
        r.class:SetText("")
        r._zone = ""
        r.zBtn:Hide()
        r.wBtn:Hide()
        r.iBtn:Hide()
        r._playerName = nil
    else
        scanFrame._countLabel:SetText("|cff888888" .. #players .. " player" .. (#players == 1 and "" or "s") .. " found|r")
        for i, p in ipairs(players) do
            local r = acquireScanRow(i)
            r.name:SetText(p.name)
            r.name:SetTextColor(1, 1, 1)
            if p.level and p.level > 0 then
                r.lvl:SetText("|cffbbbbbb" .. p.level .. "|r")
            else
                r.lvl:SetText("")
            end
            local col = RANK_COLORS[p.rank] or "ffffff"
            r.rank:SetText("|cff" .. col .. (p.rank or "Initiate") .. "|r")
            r.class:SetText("|cffe0c040" .. (p.class or "") .. "|r")
            r._zone = p.zone or ""
            r.zBtn:Show()
            r.wBtn:Show()
            r.iBtn:Show()
            r._playerName = p.name
        end
        content:SetHeight(#players * ROW_H)
    end

    scanFrame:Show()
end

----------------------------------------------------------------------
-- /fce scan  (public API)
----------------------------------------------------------------------
function Comm.StartNearbyScan()
    -- Show the popup
    refreshScanFrame()
    -- Queue a fresh ping so new players will reply for next time
    queuePing()
end

----------------------------------------------------------------------
-- /fce status
----------------------------------------------------------------------
function Comm.PrintStatus()
    local id = GetChannelName(CHANNEL_NAME) or 0
    FCE.Print("|cffffd100HCE AddonComm Status:|r")
    FCE.Print("  Channel: " .. CHANNEL_NAME .. " #" .. tostring(id))
    FCE.Print("  My class: " .. tostring(getMyClassName() or "NONE"))
    FCE.Print("  My rank: " .. tostring(getMyRank()))
    FCE.Print("  Debug: " .. (debugMode and "ON" or "OFF"))
    FCE.Print("  Queue: " .. #sendQueue .. " pending")
    local count = 0
    local now = GetTime()
    for _, e in pairs(playerCache) do
        if (now - e.time) < CACHE_TTL then count = count + 1 end
    end
    FCE.Print("  Cached players: " .. count)
    local cl = { GetChannelList() }
    if #cl > 0 then
        FCE.Print("  Channels:")
        local i = 1
        while i <= #cl do
            FCE.Print("    #" .. tostring(cl[i]) .. " " .. tostring(cl[i+1]))
            i = i + 3
        end
    end
end

----------------------------------------------------------------------
-- Periodic heartbeat
----------------------------------------------------------------------

----------------------------------------------------------------------
-- Init
----------------------------------------------------------------------
local frame = CreateFrame("Frame", "HCE_CommFrame", UIParent)

local function Init()
    dbg("Init()")

    -- Chat tag filters (NOT on CHAT_MSG_CHANNEL)
    for _, ev in ipairs(TAG_EVENTS) do
        ChatFrame_AddMessageEventFilter(ev, chatTagFilter)
    end

    -- Join channel with retries
    local attempts = 0
    local function tryJoin()
        attempts = attempts + 1
        if joinHCE() then
            dbg("Channel OK on attempt " .. attempts)
        elseif attempts < 6 then
            C_Timer.After(5.0, tryJoin)
        end
    end
    C_Timer.After(3.0, tryJoin)

    -- Queue initial broadcast after channel settles
    C_Timer.After(10.0, queueHello)

    -- Heartbeat every 30 sec
    C_Timer.NewTicker(30, function()
        queueHello()
    end)

    -- Print online count every 5 min
    C_Timer.NewTicker(300, function()
        local count = 0
        local now = GetTime()
        local seen = {}
        for name, e in pairs(playerCache) do
            if (now - e.time) < CACHE_TTL then
                local s = name:match("^([^%-]+)") or name
                if not seen[s] then
                    seen[s] = true
                    count = count + 1
                end
            end
        end
        if count > 0 and FCE.Print then
            FCE.Print("|cff4de64d" .. count .. " FCE player" .. (count == 1 and "" or "s") .. " online.|r")
        end
    end)

    -- HARDWARE EVENT HOOKS (the AutoLayer secret sauce)
    -- SendChatMessage is protected; it can only run inside a
    -- hardware-event callstack.  We drain the queue on every
    -- mouse click / key press, exactly like AutoLayer does.
    C_Timer.After(1.0, function()
        WorldFrame:HookScript("OnMouseDown", function()
            drainQueue()
        end)
    end)

    local keyFrame = CreateFrame("Frame", "HCE_KeyDrain", UIParent)
    keyFrame:SetScript("OnKeyDown", function()
        drainQueue()
    end)
    keyFrame:SetPropagateKeyboardInput(true)
end

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("CHAT_MSG_CHANNEL")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        Init()
    elseif event == "CHAT_MSG_CHANNEL" then
        local msg, sender, _, _, _, _, _, _, channelName = ...
        onChannelMsg(msg, sender, channelName)
    end
end)
