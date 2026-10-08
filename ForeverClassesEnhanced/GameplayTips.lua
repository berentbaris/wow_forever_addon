----------------------------------------------------------------------
-- ForeverClassesEnhanced — Gameplay Tips
--
-- Parses the free-text "gameplay" field on each character into
-- individual tips, maps them to expanded flavour descriptions, and
-- exposes them for the RequirementsPanel and a periodic "tip of the
-- moment" chat reminder.
--
-- These are NON-REQUIRED suggestions — roleplaying flavour, not rules.
-- The panel displays them in a distinct muted-blue style so they read
-- clearly as "nice to do" rather than "must do."
----------------------------------------------------------------------

FCE = FCE or {}

local Tips = {}
FCE.GameplayTips = Tips

----------------------------------------------------------------------
-- Tip database: known keywords → expanded flavour descriptions
----------------------------------------------------------------------
-- Keys are lowercase trimmed.  Some gameplay strings are compound
-- ("Beer, treasure") so we split on comma and match each fragment.

Tips.DB = {
    ["beer"] = {
        icon  = "\240\159\141\186",  -- 🍺
        title = "Drink Up",
        desc  = "Buy and drink beer/ale/mead from innkeepers and vendors whenever you rest. Your character appreciates a cold one after a long day of slaughter.",
    },
    ["phoenix trade"] = {
        icon  = "\240\159\141\186",  -- 🍺
        title = "Black Market Phoenix",
        desc  = "The only way to acquire a Phoenix pet is by trading it from Alliance using the neutral Goblin auction house.",
    },
    ["kirin tor trade"] = {
        icon  = "\240\159\141\186",  -- 🍺
        title = "Black Market Robes",
        desc  = "The only way to acquire Kirin Tor robes is by trading them from the Horde using the neutral Goblin auction house.",
    },
    ["sw tabard"] = {
        icon  = "\240\159\141\186",  -- 🍺
        title = "For the Alliance!",
        desc  = "Find a guild with a blue tabard to reflect your allegiance to the Alliance.",
    },
    ["uc tabard"] = {
        icon  = "\240\159\141\186",  -- 🍺
        title = "Glory to the Forsaken!",
        desc  = "Find a guild with a tabard displaying a skull motif to reflect your allegiance to the Dark Lady.",
    },
    ["argent tabard"] = {
        icon  = "\240\159\141\186",  -- 🍺
        title = "For Argent Dawn!",
        desc  = "Find a guild with a black & white tabard to reflect your allegiance to the Argent Dawn.",
    },
    ["dragonbreath"] = {
        icon  = "\240\159\141\186",  -- 🍺
        title = "Fire Breath",
        desc  = "Regularly consume Dragonbreath Chilis to keep your mouth (and melee strikes) fiery.",
    },
    ["treasure"] = {
        icon  = "\240\159\146\176",  -- 💰
        title = "Treasure Hunter",
        desc  = "Without professions, you are free to use your Find Treasure racial to seek out treasure chests.",
    },
    ["darkmoon special"] = {
        icon  = "\240\159\142\170",  -- 🎪
        title = "Darkmoon Faire Regular",
        desc  = "Visit the Darkmoon Faire whenever it's in town. The Darkmoon Special Reserve is the most affordable way to always remain drunk.",
    },
    ["thistle tea"] = {
        icon  = "\240\159\141\181",  -- 🍵
        title = "Thistle Tea Connoisseur",
        desc  = "Keep Thistle Tea in your bags at all times. Use it alongside your elixirs and potions to go full berserk!",
    },
    ["Rage pot"] = {
        icon  = "\240\159\141\181",  -- 🍵
        title = "Rage Potion Connoisseur",
        desc  = "Keep Rage Potions in your bags at all times. Use it alongside your elixirs to go full berserk!",
    },
    ["wing clip axe"] = {
        icon  = "\240\159\141\181",  -- 🍵
        title = "Quick Strikes",
        desc  = "You can maximize your dps by equipping a Chance on Hit weapon (Like the Ripsaw from ZF) and spamming Rank 1 Wing Clip.",
    },
    ["wing clip polearm"] = {
        icon  = "\240\159\141\181",  -- 🍵
        title = "Quick Strikes",
        desc  = "You can maximize your dps by equipping a Chance on Hit weapon (Like the Diabolic Skiver from ZF) and spamming Rank 1 Wing Clip.",
    },
    ["self-made enchants"] = {
        icon  = "\226\156\168",  -- ✨
        title = "Self-Enchanted",
        desc  = "Use your enchanting to improve your gear. Only use enchantments you cast yourself — no borrowing other enchanters.",
    },
    ["scrolls"] = {
        icon  = "\240\159\147\156",  -- 📜
        title = "Scroll Scribe",
        desc  = "Buy and use scrolls (Scroll of Intellect, Scroll of Strength, etc.) as consumable buffs. They are sold by librarians in major cities.",
    },
    ["campfire"] = {
        icon  = "\240\159\148\165",  -- 🔥
        title = "Cremation Ritual",
        desc  = "Light a Basic Campfire under fallen allies to cremate them and honor their legacy with a funeral.",
    },
    ["melee weaving hunter"] = {
        icon  = "\226\154\148",  -- ⚔
        title = "Melee Weave",
        desc  = "Weave melee Raptor Strike between your shots. Step in, swing, step out.",
    },
    ["melee weaving caster 1"] = {
        icon  = "\226\154\148",  -- ⚔
        title = "Melee Weave",
        desc  = "Weave melee auto-attacks while channeling Mind Flay. Switch to high dps fishing pole (+ lure) at 44 to avoid caster melee penalty.",
    },
    ["melee weaving caster lock"] = {
        icon  = "\226\154\148",  -- ⚔
        title = "Melee Weave",
        desc  = "Weave melee auto-attacks while channeling Drain Life. Switch to high dps fishing pole (+ lure) at 44 to avoid caster melee penalty.",
    },
    ["pole weaving"] = {
        icon  = "\226\154\148",  -- ⚔
        title = "Detailed explanation",
        desc  = "Type '/fce pole weaving' for a link to a YouTube video that presents the detailed explanation behind this build.",
    },
    ["exotic"] = {
        icon  = "\226\154\148",  -- ⚔
        title = "Rare Collector",
        desc  = "Try to do some open world quests that give rare (blue) quality rewards.",
    },
    ["pick"] = {
        icon  = "\226\154\148",  -- ⚔
        title = "A Dwarf and His Tools",
        desc  = "Do not lose your pick by turning in A Dwarf and His Tools.",
    },
    ["melee weaving caster 2"] = {
        icon  = "\226\154\148",  -- ⚔
        title = "Melee Weave",
        desc  = "Weave melee auto-attacks while channeling Drain Life. Switch to high dps fishing pole (+ lure) at 44 to avoid caster melee penalty.",
    },
    ["rage pot"] = {
        icon  = "\226\154\148",  -- ⚔
        title = "Rage Potion Connoisseur",
        desc  = "Keep Rage Potions in your bags at all times. Use it alongside your elixirs to go full berserk!",
    },
    ["melee weaving dagger 2"] = {
        icon  = "\226\154\148",  -- ⚔
        title = "Melee Weave Bonus",
        desc  = "If you use a 1.5 or lower speed dagger, you can weave instant-cast spells between your melee auto-attacks. Use mouse-over macros to DoT multiple targets while stabbing your main target.",
    },
    ["tank"] = {
        icon  = "\226\154\148",  -- ⚔
        title = "Try Tanking",
        desc  = "4 enemies: 1 polymorped/sapped, 1 nuked by dps (ignored by you), 1 face-tanked by your voidwalker, and 1 tanked by you spamming Searing Pain (after a Soul Fire opener).",
    },
    ["safety"] = {
        icon  = "\226\152\160",  -- ☠
        title = "Safety First!",
        desc  = "Your engineering goggles and trinkets don't count against the off-the-shelf challenge.",
    },
    ["timber"] = {
        icon  = "\226\152\160",  -- ☠
        title = "Timbermaw Mace",
        desc  = "The only high-quality vendor mace is sold by the Timbermaw Clan (Furbolg Medicine Totem). You should befriend them.",
    },
    ["sacrifice"] = {
        icon  = "\226\154\148",  -- ⚔
        title = "Sacrifice Combo",
        desc  = "Thanks to Fel Domination, you can Sacrifice your Voidwalker, then resummon it instantly and reapply Soul Link for a big mid-combat shield.",
    },
    ["melee weaving dagger"] = {
        icon  = "\226\154\148",  -- ⚔
        title = "Firestone Rotation",
        desc  = "Immolate + Corruption opener, stab, stab, stab, Conflagrate right before Immolate DoT drops off, finish with Shadowburn. Weave melee auto-attacks between your instant spells.",
    },
    ["cenarion war"] = {
        icon  = "\226\154\148",  -- ⚔
        title = "At War with the Cenarion Circle",
        desc  = "Be very careful when attacking members of the Cenarion Circle. Carry out your attacks outside of the Cenarion Hold in Silithus, perhaps on the Great Bear Spirit and Tajarri.",
    },
    ["argent war"] = {
        icon  = "\226\154\148",  -- ⚔
        title = "At War with the Argent Dawn",
        desc  = "Be very careful when attacking members of the Argent Dawn. Carry out your attacks in secluded areas, perhaps on Injured Argent Dawn Infantry.",
    },
    ["bow kiting"] = {
        icon  = "\226\154\148",  -- ⚔
        title = "Bow Kiting",
        desc  = "You can use Gouge + Shoot to kite enemies with your bow.",
    },
    ["gun kiting"] = {
        icon  = "\226\154\148",  -- ⚔
        title = "Gun Kiting",
        desc  = "You can use Gouge + Shoot to kite enemies with your gun. This is especially effective against elites.",
    },
    ["/roar"] = {
        icon  = "\240\159\166\129",  -- 🦁
        title = "Battle Roar",
        desc  = "Use /roar (or /charge, /flex) before engaging elite mobs or entering dungeons. Announce your presence to the world.",
    },
    ["pro-nature"] = {
        icon  = "\240\159\140\191",  -- 🌿
        title = "Nature's Ally",
        desc  = "Prioritize quest-chains that have you fight against those who want to pillage and pollute Azeroth (e.g., The Venture Company).",
    },
    ["/bow"] = {
        icon  = "\240\159\140\191",  -- 🌿
        title = "Shobek",
        desc  = "Don't forget to /stopattack & /bow after Gouge.",
    },
    ["anti-undead"] = {
        icon  = "\226\152\160",  -- ☠
        title = "Undead Slayer",
        desc  = "Seek out undead-heavy zones (Plaguelands, Duskwood, Razorfen Downs) and purge the restless dead. Carry your Argent Dawn trinket with pride.",
    },
    ["Anti-demon"] = {
        icon  = "\226\152\160",  -- ☠
        title = "Demon Slayer",
        desc  = "Seek out demon-heavy zones (Ashenvale, Felwood, Blasted Lands) and fight against the Burning Legion.",
    },
    ["epic hammer"] = {
        icon  = "\226\152\160",  -- ☠
        title = "Weaponsmith",
        desc  = "The epic hammer from your lv 45 quest counts as a self-made item.",
    },
    ["rum"] = {
        icon  = "\240\159\143\180",  -- 🏴
        title = "Pirate's Grog",
        desc  = "Keep Rum (or Grog) in your bags. Drink at sunset or whenever you spot a boat.",
    },
    ["rare pets"] = {
        icon  = "\240\159\144\190",  -- 🐾
        title = "Exotic Collector",
        desc  = "Seek out rare-spawn tameable beasts. The Rake, Broken Tooth, Echeyakee — the rarer the better. Show off your collection.",
    },
    ["cursed necklace"] = {
        icon  = "\240\159\167\165",  -- 🧥
        title = "Searching for the amulet",
        desc  = "The amulet you are looking is the undead heart of a sand troll.",
    },
    ["tank tour"] = {
        icon  = "\240\159\167\165",  -- 🧥
        title = "World Tour",
        desc  = "Attempt to tank every dungeon and outdoor group content up to and including Blackrock Depths.",
    },
    ["powershifting"] = {
        icon  = "\240\159\167\165",  -- 🧥
        title = "Powershifting",
        desc  = "After you get your helmet and talents, you'll generate 60 energy everytime you shift into Cat Form. You can take advantage of this with a Powershifting macro.",
    },
    ["/sit and /meditate"] = {
        icon  = "\240\159\167\152",  -- 🧘
        title = "Meditative Pauses",
        desc  = "Use /sit or /kneel between fights to roleplay meditation. Take a breath. Centre yourself. Then resume the grind.",
    },
    ["stormwind hearthstone"] = {
        icon  = "\240\159\143\160",  -- 🏠 (house)
        title = "Stormwind Loyalist",
        desc  = "Keep your hearthstone set to Stormwind. For the Alliance!",
    },
    ["uc hearthstone"] = {
        icon  = "\240\159\143\160",  -- 🏠 (house)
        title = "Undercity Loyalist",
        desc  = "Keep your hearthstone set to Undercity. For the Forsaken!",
    },
    ["spirit tap + starshards"] = {
        icon  = "\226\173\144",  -- ⭐
        title = "Spirit Tap Rotation",
        desc  = "Boost your damage with Spirit Tap (and Spiritual Guidance talent). Cast Starshards before the buff drops off for maximum efficiency.",
    },
    ["pyroblast + arcane missiles"] = {
        icon  = "\240\159\146\165",  -- 💥
        title = "Pyroblast Opener",
        desc  = "Open every fight with Pyroblast + Arcane Missiles. This method spends all your mana at once, and allows for maximum mana regen, decreasing downtime.",
    },
    ["aoe-farmer"] = {
        icon  = "\240\159\140\128",  -- 🌀 (cyclone)
        title = "AoE Grinder",
        desc  = "Pull big packs and grind them down with AoE (Blizzard, Frost Nova, and other frost spells). High risk, high reward.",
    },
    ["savage"] = {
        icon  = "\240\159\140\128",  -- 🌀 (cyclone)
        title = "Owlkin",
        desc  = "Savagekin are druids who spend most of their time in animal form.",
    },
}

----------------------------------------------------------------------
-- Parse a gameplay string into individual tip entries
----------------------------------------------------------------------

--- Split a gameplay string like "Beer, treasure" into individual tips,
--- look each up in the DB, and return a list of { icon, title, desc }.
--- Unknown fragments get a generic entry.
function Tips.Parse(gameplayStr)
    if not gameplayStr or gameplayStr == "" then return {} end

    local result = {}
    -- Split on comma
    for fragment in gameplayStr:gmatch("[^,]+") do
        local trimmed = strtrim(fragment)
        local key = trimmed:lower()

        -- Try exact match first
        local entry = Tips.DB[key]

        -- Try partial match if exact fails
        if not entry then
            for dbKey, dbEntry in pairs(Tips.DB) do
                if key:find(dbKey, 1, true) or dbKey:find(key, 1, true) then
                    entry = dbEntry
                    break
                end
            end
        end

        if entry then
            table.insert(result, {
                icon  = entry.icon,
                title = entry.title,
                desc  = entry.desc,
                raw   = trimmed,
            })
        else
            -- Unknown tip — show it plain
            table.insert(result, {
                icon  = "\194\183",  -- · (middle dot)
                title = trimmed,
                desc  = "Roleplay suggestion: " .. trimmed,
                raw   = trimmed,
            })
        end
    end

    return result
end

----------------------------------------------------------------------
-- Get tips for the currently selected character
----------------------------------------------------------------------

function Tips.GetCurrent()
    local key = FCE_CharDB and FCE_CharDB.selectedCharacter
    local char = key and FCE.GetCharacter and FCE.GetCharacter(key)
    if not char then return {} end
    local gp = FCE.GetCharGameplay and FCE.GetCharGameplay(char) or char.gameplay
    return Tips.Parse(gp)
end

----------------------------------------------------------------------
-- Periodic "tip of the moment" chat reminder
----------------------------------------------------------------------
-- Every 15 minutes (if enabled and tips exist), print a random tip
-- in chat as a gentle roleplay nudge.

local TIP_INTERVAL = 900  -- 15 minutes in seconds
local tipTimer = nil

local function fireTipReminder()
    -- Respect chat warnings toggle
    if FCE_GlobalDB and FCE_GlobalDB.chatWarningsEnabled == false then return end
    if FCE_GlobalDB and FCE_GlobalDB.gameplayTipsEnabled == false then return end

    local tips = Tips.GetCurrent()
    if #tips == 0 then return end

    local tip = tips[math.random(#tips)]
    local GOLD_HEX = "e6c73f"
    local DIM_HEX  = "a0a0a0"
    FCE.Print("|cff" .. GOLD_HEX .. "Gameplay tip:|r " .. tip.title
        .. " — |cff" .. DIM_HEX .. tip.desc .. "|r")
end

function Tips.StartReminder()
    if tipTimer then return end  -- already running
    tipTimer = C_Timer.NewTicker(TIP_INTERVAL, fireTipReminder)
end

function Tips.StopReminder()
    if tipTimer then
        tipTimer:Cancel()
        tipTimer = nil
    end
end

----------------------------------------------------------------------
-- Slash command: /fce gameplay
----------------------------------------------------------------------

function Tips.PrintStatus()
    local key = FCE_CharDB and FCE_CharDB.selectedCharacter
    if not key then
        FCE.Print("No enhanced class selected. Type |cffffd100/fce pick|r to choose one.")
        return
    end
    local char = FCE.GetCharacter and FCE.GetCharacter(key)
    if not char then
        FCE.Print("Character data not found.")
        return
    end

    local _gp = FCE.GetCharGameplay and FCE.GetCharGameplay(char) or char.gameplay
    if not _gp or _gp == "" then
        FCE.Print("Your enhanced class has no gameplay suggestions.")
        return
    end

    local tips = Tips.Parse(_gp)
    local GOLD_HEX = "e6c73f"
    local classStr = char.class:sub(1, 1) .. char.class:sub(2):lower()
    FCE.Print("--- " .. char.name .. " (" .. char.spec .. " " .. classStr .. ") Gameplay Tips ---")
    FCE.Print("|cff888888These are flavour suggestions, not requirements.|r")

    for _, tip in ipairs(tips) do
        FCE.Print("  |cff" .. GOLD_HEX .. tip.title .. "|r")
        FCE.Print("     " .. tip.desc)
    end

    -- Reminder toggle status
    local enabled = (FCE_GlobalDB and FCE_GlobalDB.gameplayTipsEnabled ~= false)
    if enabled then
        FCE.Print("|cff888888Periodic tip reminders: |cff00ff00ON|r (every 15 min). Toggle: /fce tips|r")
    else
        FCE.Print("|cff888888Periodic tip reminders: |cffff5555OFF|r. Toggle: /fce tips|r")
    end
end

----------------------------------------------------------------------
-- Init: start the reminder ticker on PLAYER_LOGIN (deferred)
----------------------------------------------------------------------

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(10, function()
        -- Only start if the player has tips and hasn't disabled them
        if FCE_GlobalDB and FCE_GlobalDB.gameplayTipsEnabled == false then return end
        local tips = Tips.GetCurrent()
        if #tips > 0 then
            Tips.StartReminder()
        end
    end)
end)
