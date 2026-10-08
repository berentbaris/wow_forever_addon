----------------------------------------------------------------------
-- ForeverClassesEnhanced – Character Data
-- All 27 enhanced characters from the EnhancedClasses spreadsheet.
--
-- Fields per character:
--   class       : base WoW class (English, matches UnitClass 2nd return)
--   spec        : talent spec name
--   name        : character archetype name (display name, also used as key)
--   race        : required race, or "Any"
--   gender      : "Male", "Female", or "Any"
--   selfFound   : boolean - must play with Self-Found mode on
--   professions : list of required professions (may be empty)
--   equipment   : list of { desc, level } tables
--   challenges  : list of { desc, level } tables (non-optional, always active)
--   optionalChallenges : list of { desc, level } tables (player picks one or none)
--   companion   : { name, level } or nil
--   pet         : { desc, level } or nil   (hunter pet)
--   mount       : { desc, level } or nil
--   quests      : list of { name, level, questID } tables, or nil
--   gameplay    : free-text flavour/tips, or nil
----------------------------------------------------------------------

FCE = FCE or {}

-- Challenge type descriptions (from the Notes sheet)
FCE.ChallengeDescriptions = {
    ["Anti-undead"]     = "Level in undead-heavy zones (Tirisfal Glades, Plaguelands, Duskwood, Zul'Farrak)",
    ["Pro-nature"]      = "Complete quests against those who want to pillage and pollute Azeroth",
    ["Homebound"]       = "Can't leave home continent - focus on encroaching threats at home",
    ["Anti-demon"]      = "Level in demon-heavy zones (Darkshore, Blackfathom Deeps, Ashenvale, Felwood)",
    ["Diplomat"]        = "Must obtain another faction's mount",
    ["Scavenger"]        = "Cannot equip quest reward gear (except for white/grey items)",
    ["Aoe-farmer"]      = "Level mainly by aoe-farming in the open world",
    ["White knight"]    = "Can only equip white or grey gear",
    ["Partisan"]        = "Cannot equip looted gear (except for white/grey items)",
    ["Drifter"]         = "Cannot use hearthstone or bank - outsiders don't use city amenities",
    ["Ephemeral"]       = "Cannot repair gear",
    ["Self-made"]       = "Can only equip self-crafted or white/grey items (jewelry, cloak exempt)",
    ["Expeditionary"]       = "Can only equip items earned via group content or white/grey items",
    ["Exotic"]          = "Cannot equip green quality gear - exotic heros wear exotic armor",
    ["Off-the-shelf"]   = "Can only equip gear sold by vendors or white/grey items",
    ["Faction Loyalist"]  = "Maintain standing with your home faction as you level up",
    ["Master Trainer"]    = "Your pet must use Bite (Rank 8) and Furious Howl (Rank 4) in combat",
    ["Seeking a Pardon"]  = "Gain your faction's trust - obtain a pardon for your past pirate crimes",
    ["Master Smelter"]    = "Smelt Dark Iron ore at the Black Forge in Blackrock Depths",
    ["Scout"]         = "Cannot equip rare or epic quality items",
    ["No nonsense"]  = "Cannot learn any professions - you live only for battle",
    ["No demons"]        = "Cannot summon a demon pet or mount",
    ["Mortal pets"]     = "Hunter pets that die stay dead - cannot revive them",
    ["Cloth/leather"]   = "Cloth only until level 40, then cloth or leather",
    ["Cloth"]   = "Can only wear cloth armor",
    ["Leather"]   = "Can only wear leather armor",
    ["Leather/mail"]    = "Leather only until level 40, then leather or mail",
    ["Mail/plate"]      = "Must wear mail or plate in all possible slots",
    ["Imp"]             = "Must always use the Imp as your demon pet",
    ["Voidwalker"]             = "Cannot summon any demons besides the Voidwalker",
    ["Self-made guns"]  = "Ranged weapon must be self-crafted via Engineering",
    ["Demonic Sacrifice"] = "Must sacrifice your demon pet and maintain the Demonic Sacrifice buff",
    ["Purifier"]          = "Reach Honored reputation with the Argent Dawn",
    ["Keeper"]          = "Reach Honored reputation with the Cenarion Circle",
    ["Smith"]          = "Reach Honored reputation with the Thorium Brotherhood",
    ["Avenger"]          = "Reach Friendly reputation with the Zandalar Tribe",
    ["Nocturnal"]         = "Must remain in towns or cities during daytime",
    ["Diurnal"]           = "Must remain in towns or cities during nighttime",
    ["Pyromancer"]        = "Cannot cast Frost spells - Bloodmages rely mostly on fire magic",
    ["Firemancer"]        = "Cannot cast Shadowbolt - Bloodmages rely mostly on fire magic",
    ["Cryomancer"]        = "Cannot cast Fire spells - Spellblades abandon fire magic",
    ["Light of Elune"]    = "Cannot cast Shadow spells - servants of Elune reject the void",
    ["All-out Assault"]             = "Cannot switch to Defensive Stance - Fight with brute force!",
    ["Shadow Ascendant"]             = "Cannot use Holy abilities - Lightslayers fight against the light",
    ["Self-taught"]             = "Cannot use Arcane abilities - Hedge Wizards lack formal education",
    ["Overt"]             = "Cannot use Stealth or Vanish",
    ["Lone Wolf"]             = "Cannot summon a pet - Elven Rangers don't have animal companions",
    ["Old Horde"]             = "Mustn't become Revered with Orgrimmar - Gul'dan's Death Knights support the Old Horde, not Thrall's New Horde",
    ["Agnostic"]             = "Cannot use Holy spells until completing The Test of Righteousness",
    ["Truecaster"]             = "Cannot shapeshift - Not all druids pray to wild gods",
    ["Windfury Weapon"]             = "Cannot use any other weapon enchant",
    ["Voodoo Ritual"]               = "Perform a dark dance at the peak of Jintha'Alor while wearing 3 cursed items",
    ["Gnomish Justice"]             = "Use Gnomish Universal Remote on Clunk, then defeat Trade Master Kovic",
    ["Scarlet Redemption"]           = "Destroy the Scarlet Tabard at Light's Hope Chapel - renounce the Crusade",
    ["The New Plague"]               = "Destroy Nightglow Concoction near the Southshore inn while under the effect of a Nature Protection Potion",
    ["Disease Cleansing"]            = "Cure 10 diseases including Silithid Pox and Cadaver Worms",
    ["Insular"]                = "Can only speak one language",
    ["Rockbiter Weapon"]             = "Cannot use any other weapon enchants",
    ["Cult of the Damned"]             = "Must become Hostile with the Argent Dawn - Cult of the Damned serves the Lich King",
    ["Twilight's Hammer"]             = "Must become Hostile with the Cenarion Circle - Twilight's Hammer serves Old Gods",
    ["Shadow Council"]             = "Must become Hostile with the Cenarion Circle - the Shadow Council serves the Burning Legion",
    ["Explorer"]            = "Explore the world - required exploration % scales with level",
    ["Lockdown"]            = "Can only use Cheap Shot as a stealth opener - cannot use Ambush or Garrote",
    ["Spirit of Ursol"]            = "Cannot shapeshift into Cat Form - Druids of the Claw worship only the Spirit of Ursol",
    ["Spirit of Ashamane"]            = "Cannot shapeshift into Bear Form - Savagekin worship only the Spirit of Ashamane",
    ["Spirit of Aviana"]                  = "Cannot shapeshift into Cat or Bear Form - Druid of the Talon worship only the Spirit of Aviana",
    ["Savagery"]                  = "Savagery decays while in caster form - shapeshift to restore it - fails at 0%",
    ["Happy Hour"]                = "Drink alcohol at least once per hour - 60 min timer decays while sober",
    ["Elixir Frenzy"]             = "Must always have an elixir buff active - 5 min grace period when unbuffed",
    ["Master of Fire"]                  = "Cannot use Water Totems, Frost Shock, or any weapon enchant other than Flametongue",
    ["Master of Water"]                  = "Cannot use Fire Totems, Flame Shock, or any weapon enchant other than Frostbrand",
    ["Retribution Aura"]                  = "Cannot use any other auras",
    ["Tame Son of Hakkar"]                  = "Find and tame Son of Hakkar in Zul'Gurub",
    ["Tame Bloodaxe Worg"]                  = "Find and tame a Bloodaxe Worg in Blackrock Spire",
}

-- Quest theme descriptions (displayed under the QUESTS header)
FCE.QuestThemeDescriptions = {
    ["Anti-demon"]         = "",
    ["Pro-nature"]         = "",
    ["Anti-scourge"]        = "",
    ["Big Game Hunter"]    = "",
    ["Ironforge Loyalist"] = "",
    ["Stormwind Loyalist"] = "",
    ["Plague-brewer"]      = "",
    ["Darkspear Loyalist"] = "",
    ["Gadgetist"]          = "",
}

----------------------------------------------------------------------
-- Helpers to build requirement entries.
--   E("Fist weapons", 10)      → active from level 10 onward
--   E("Goggles", 20, 29)       → active only at levels 20–29
--   Q("Quest Name", 18, 4763)  → quest due by level 18, WoW questID 4763
----------------------------------------------------------------------
local function E(desc, level, endLevel)
    return { desc = desc, level = level or 1, endLevel = endLevel or nil }
end

local function Q(name, level, questID)
    return { name = name, level = level or 1, questID = questID }
end

----------------------------------------------------------------------
-- Character table
----------------------------------------------------------------------
FCE.Characters = {
    ---------- WARRIOR ----------

    ["Sister of Steel_WARRIOR"] = {
        class       = "WARRIOR",
        spec        = "Arms/Prot",
        name        = "Sister of Steel",
        races       = { "Dwarf" },
        gender      = "Female",
        selfFound   = true,
        professions = { "Blacksmithing" },
        challenges  = {
            E("Self-made", 1),
            E("Smith", 60),
        },
        optionalChallenges = {
            E("Homebound", 1),
            E("Insular", 1),
        },
        questsByHomebound = { 
            default = {
                Q("Supplying the Front", 16, 1578),
                Q("Jarl Needs a Blade", 35, 1203),
                Q("Expert Blacksmith!", 45, 2765),
                Q("Did You Lose This?", 50, 3321),
                Q("Gaining Acceptance", 55, 7737),
                Q("Corruption", 60, 5307),
            },
            homebound = {
                Q("Supplying the Front", 16, 1578),
                Q("The Everstill Bridge", 20, 89),
                Q("Gearing Redridge", 20, 1618),
                Q("Expert Blacksmith!", 45, 2765),
                Q("STOLEN: Smithing Tuyere and Lookout's Spyglass", 48, 7728),
                Q("Gaining Acceptance", 55, 7737),
            },
        },
        questTheme  = "The Mithril Order",
        companion   = nil,
        pet         = nil,
        mount       = nil,
        gameplay    = "epic hammer",
    },

    ["Dragonsworn_WARRIOR"] = {
        class       = "WARRIOR",
        spec        = "Flurry",
        name        = "Dragonsworn",
        race        = "Night Elf",
        gender      = "Any gender",
        selfFound   = true,
        professions = {},
        recommendedProfession = {
            name = "Alchemy, Tailoring",
            reason = "The 2x Elixir of Fortitude required for Faerie Dragon pet can be crafted with Alchemy. A low level is Tailoring is required to obtain the Green Shirt",
        },
        challenges  = {
            E("Keeper", 60),
        },
        optionalChallenges = {
            E("Partisan", 1),
            E("Expeditionary", 1),
            E("Mail/plate", 1),
        },
        equipment   = {
            E("Green shirt", 10),
            E("Dragonsworn blade", 10, 54),
            E("Dragonsworn helm", 35),
            E("Dragonsworn shoulders", 45),
            E("Dual dragon blades", 55),
        },
        quests      = {
            Q("The Sleeper Has Awakened", 20, 5321),
            Q("In Nightmares", 25, 3370),
            Q("Satyr Slaying!", 32, 1032),
            Q("Extinguishing the Idol", 37, 3525),
            Q("Becoming a Parent", 48, 4298),
            Q("Further Corruption", 54, 4906),
            Q("In Eranikus' Own Words", 55, 3512),
        },
        questTheme  = "Serving the Green Dragonflight",
        companion   = E("Faerie dragon", 48),
        pet         = nil,
        mount       = nil,
        gameplay    = nil,
    },

    ["Mountain King_WARRIOR"] = {
        class       = "WARRIOR",
        spec        = "Fury/Prot",
        name        = "Mountain King",
        races       = { "Dwarf" },
        gender      = "Male",
        selfFound   = true,
        professions = {},
        challenges  = {
            E("No nonsense", 1),
            E("Happy Hour", 10),
        },
        optionalChallenges = {
            E("Partisan", 1),
            E("Expeditionary", 1),
            E("Mail/plate", 1),
            E("Explorer", 1),
        },
        equipment   = {
            E("Axe & mace", 20),
            E("Horned helm", 34),
            E("Flask trinket", 44),
        },
        quests      = {
            Q("In Defense of the King's Lands", 17, 217),
            Q("The Absent Minded Prospector", 24, 943),
            Q("Defeat Nek'rosh", 32, 474),
            Q("The Lost Tablets of Will", 45, 1139),
            Q("Rise, Obsidion!", 52, 3566),
            Q("The Princess's Surprise", 59, 4363),
        },
        questTheme  = "Ironforge Loyalist",
        companion   = nil,
        pet         = nil,
        mount       = nil,
        gameplay    = "Beer, treasure, tank tour",
    },

    ["Tinker_WARRIOR"] = {
        class       = "WARRIOR",
        spec        = "Mace",
        name        = "Tinker",
        races       = { "Gnome" },
        gender      = "Any gender",
        selfFound   = true,
        professions = { "Engineering" },
        equipment   = {
            E("Tinker mace", 5),
            E("Gun", 10),
            E("Beginner goggles", 20, 29),
            E("Intermediate goggles", 30, 39),
            E("Engineering trinkets", 35),
            E("Discombobulator ray", 35),
            E("Advanced goggles", 40),
        },
        challenges  = {
            E("Gnomish Justice", 45),
        },
        optionalChallenges = {
            E("Scavenger", 1),
            E("Expeditionary", 1),
            E("Off-the-shelf", 1),
        },
        quests      = {
            Q("A Dark Threat Looms", 20, 283),
            Q("Data Rescue", 30, 2930),
            Q("Show Your Work", 47, 3641),
            Q("An OOX of Your Own", 50, 3721),
        },
        questTheme  = "Gadgetist",
        companion   = E("Mechanical", 45),
        pet         = nil,
        mount       = nil,
        gameplay    = nil,
    },

    ["Brewmaster_WARRIOR"] = {
        class       = "WARRIOR",
        spec        = "Slam",
        name        = "Brewmaster",
        races       = { "Gnome", "Human", "Orc", "Tauren", "Troll", "Dwarf" },
        gender      = "Any gender",
        selfFound   = true,
        professions = { "Alchemy" },
        recommendedProfession = {
            name = "Cooking",
            reason = "Need advanced cooking skills to make Dragonbreath Chili.",
        },
        challenges  = {
            E("Happy Hour", 10),
        },
        optionalChallenges = {
            E("Exotic", 1),
            E("Scavenger", 1),
            E("Leather/mail", 1),
        },
        equipmentByFaction = {
            Alliance = {
                E("Robe", 5),
                E("Staff", 10),
                E("Dragonbreath chili", 40),
                E("Flask trinket", 50), 
            },
            Horde = {
                E("Robe", 5),
                E("Staff", 10),
                E("Dragonbreath chili", 40),
                E("Flask trinket", 50),             
            },
        },
        questsByFaction = {
            Alliance = {
                Q("The Perfect Stout", 9, 315),
                Q("Dry Times", 15, 116),
                Q("... and Bugs", 40, 1258),
                Q("Sweet Amber", 44, 53),
                Q("Report Back to Fizzlebub", 44, 1122),
                Q("Voodoo Feathers", 50, 8425),
                Q("Hurley Blackbreath", 55, 4126),
                Q("The Love Potion", 58, 4201),
                Q("Mother's Milk", 60, 4866),
            },
            Horde = {
                Q("Smart Drinks", 20, 1491),
                Q("Chen's Empty Keg", 24, 821),
                Q("Report Back to Fizzlebub", 44, 1122),
                Q("Voodoo Feathers", 50, 8425),
                Q("Lost Thunderbrew Recipe", 55, 4134),
                Q("The Love Potion", 58, 4201),
                Q("Mother's Milk", 60, 4866),
            },
        },
        questTheme  = "Brew Guzzler",
        companion   = nil,
        pet         = nil,
        mount       = nil,
        gameplay    = "darkmoon special, dragonbreath",
    },

    ["Barbarian_WARRIOR"] = {
        class       = "WARRIOR",
        spec        = "Slam",
        name        = "Barbarian",
        races       = { "Human", "Orc", "Troll", "Undead" },
        gender      = "Any gender",
        selfFound   = true,
        professions = {},
        challenges  = {
            E("No nonsense", 1),
            E("Insular", 1),
        },
        optionalChallenges = {
            E("Exotic", 1),
            E("Scavenger", 1),
            E("Leather/mail", 1),
            E("Drifter", 1),
        },
        equipmentByFaction = {
            Alliance = {
                E("Primitive weapon", 5),
                E("No chest", 5),
                E("No pants", 5),
                E("Horned helm", 34),
            },
            Horde = {
                E("Primitive weapon", 5),
                E("No chest", 5),
                E("No pants", 5),
                E("Horned helm", 34),
            },
        },
        questsByFaction = {
            Alliance = {
                Q("In Defense of the King's Lands", 17, 217),
                Q("The People's Militia", 17, 14),
                Q("Blackrock Bounty", 25, 128),
                Q("Reassignment", 32, 563),
                Q("Stromgarde Badges", 37, 682),
                Q("Crushridge Warmongers", 40, 504),
                Q("Murdaloc", 42, 739),
                Q("Extinguish the Firegut", 52, 3823),
                Q("The Last Barov", 59, 5344),
            },
            Horde = {
                Q("The Disruption Ends", 15, 872),
                Q("Consumed by Hatred", 20, 899),
                Q("Bloodfury Bloodline", 26, 6283),
                Q("Battle of Hillsbrad", 32, 550),
                Q("Theramore Spies", 35, 1201),
                Q("Call to Arms", 40, 679),
                Q("Threat From the Sea", 43, 1427),
                Q("A Grim Discovery", 45, 2974),
                Q("The Ranger Lord's Behest", 59, 6133),
            },
        },
        questTheme  = "Slayer",
        companion   = nil,
        pet         = nil,
        mount       = nil,
        gameplay    = nil,
    },

    ["Demon Hunter_WARRIOR"] = {
        class       = "WARRIOR",
        spec        = "Sword",
        name        = "Demon Hunter",
        races       = { "Night Elf" },
        gender      = "Any gender",
        selfFound   = true,
        professions = {},
        challenges  = {},
        optionalChallenges = {
            E("Exotic", 1),
            E("Scavenger", 1),
            E("Self-made", 1),
        },
        equipment   = {
            E("No chest", 1),
            E("Dual swords", 20),
            E("Kilt", 25),
        },
        questsByHomebound = { 
            default = {
                Q("The Blackwood Corrupted", 18, 4763),
                Q("The Tower of Althalaxx", 31, 981),
                Q("Satyr Slaying!", 32, 1032),
                Q("A Land Filled with Hatred", 47, 5536),
                Q("Ancient Spirit", 56, 4261),
                Q("A Final Blow", 58, 5242),
                Q("You Are Rakh'likh, Demon", 60, 3628),
            },
            homebound = {
                Q("The Blackwood Corrupted", 18, 4763),
                Q("The Tower of Althalaxx", 31, 981),
                Q("Satyr Slaying!", 32, 1032),
                Q("A Land Filled with Hatred", 47, 5536),
                Q("Ancient Spirit", 56, 4261),
                Q("A Final Blow", 58, 5242),
            },
        },
        questTheme  = "The Legion Shall Fall",
        companion   = nil,
        pet         = nil,
        mount       = nil,
        gameplay    = "Anti-demon",
    },

    ["Huntress_WARRIOR"] = {
        class       = "WARRIOR",
        spec        = '"Sword & Board"',
        name        = "Huntress",
        races       = { "Night Elf" },
        gender      = "Female",
        selfFound   = true,
        professions = {},
        challenges  = {
            E("Faction Loyalist", 1),
        },
        optionalChallenges = {
            E("Exotic", 1),
            E("Partisan", 1),
            E("Self-made", 1),
        },
        equipment   = {
            E("Sword or dagger", 1),
            E("Shield", 5),
            E("Thrown", 10),
        },
        quests      = {
            Q("Sathrah's Sacrifice", 12, 2520),
            Q("Raene's Cleansing", 30, 1046),
            Q("Rise of the Silithid", 46, 4267),
            Q("The Mystery of Morrowgrain", 50, 3791),
            Q("Calm Before the Storm", 54, 4508),
            Q("The Treasure of the Shen'dralar", 60, 7877),
        },
        questTheme  = "Darnassus Loyalist",
        companion   = E("Owl", 10),
        pet         = nil,
        mount       = E("Nightsaber", 44),
        gameplay    = nil,
    },

    ["Prospector_WARRIOR"] = {
        class       = "WARRIOR",
        spec        = "Arms/Prot",
        name        = "Prospector",
        races       = { "Dwarf" },
        gender      = "Any gender",
        selfFound   = true,
        professions = { "Mining" },
        equipment   = {
            E("Crossbow", 10),
            E("Prospector's pickaxe", 20),
            E("Prospector headgear", 32),
        },
        challenges  = {
            E("Explorer", 1),
        },
        optionalChallenges = {
            E("Scout", 1),
            E("Scavenger", 1),
            E("Expeditionary", 1),
        },
        quests      = {
            Q("Cave Mushrooms", 17, 947),
            Q("Collecting Memories", 18, 168),
            Q("Search for Incendicite", 22, 466),
            Q("Rethban Ore", 24, 347),
            Q("A King's Tribute", 31, 700),
            Q("Favor for Krazek", 37, 627),
            Q("Restoring the Necklace", 44, 2361),
            Q("Delivering the Relic", 45, 2871),
            Q("The Mighty U'cha", 55, 4301),
        },
        questTheme  = "Dungeoneer",
        companion   = nil,
        pet         = nil,
        mount       = nil,
        gameplay    = nil,
    },

    ["Gladiator_WARRIOR"] = {
        class       = "WARRIOR",
        spec        = "Flurry",
        name        = "Gladiator",
        races       = { "Orc", "Human" },
        gender      = "Any gender",
        selfFound   = true,
        professions = {},
        weaponProficiency = { E("Weapon Mastery", 22) },
        equipment   = {
            E("No chest", 1),
            E("No guns", 10),
            E("Mixed weapons", 20),
        },
        challenges  = {
            E("All-out Assault", 1),
            E("Insular", 1),
        },
        optionalChallenges = {
            E("Scavenger", 1),
            E("Expeditionary", 1),
            E("Off-the-shelf", 1),
        },
        questsByFaction = {
            Alliance = {
                Q("Wanted: Hogger", 11, 176),
                Q("WANTED: Baron Longshore", 16, 895),
                Q("WANTED: Chok'sul", 22, 256),
                Q("Wanted: Gath'Ilzogg", 26, 169),
                Q("Wanted! Otto and Falconcrest", 40, 685),
                Q("WANTED: Andre Firebeard", 45, 2875),
                Q("WANTED: Caliph Scorpidsting", 46, 2781),
                Q("WANTED: Overseer Maltorius", 50, 7701),
                Q("Wanted - Deathclasp, Terror of the Sands", 59, 8283),
            },
            Horde = {
                Q("Wanted: Maggot Eye", 10, 398),
                Q("WANTED: Baron Longshore", 16, 895),
                Q("Wanted - Arnak Grimtotem", 29, 5147),
                Q("Challenge Overlord Mok'Morokk", 45, 1173),
                Q("WANTED: Andre Firebeard", 45, 2875),
                Q("WANTED: Caliph Scorpidsting", 46, 2781),
                Q("WANTED: Overseer Maltorius", 50, 7701),
                Q("Wanted - Deathclasp, Terror of the Sands", 59, 8283),          
            },
        },
        questTheme  = "Challenger",
        companion   = nil,
        pet         = nil,
        mount       = nil,
        gameplay    = nil,
    },

    ["Blademaster_WARRIOR"] = {
        class       = "WARRIOR",
        spec        = "Sword",
        name        = "Blademaster",
        races       = { "Orc" },
        gender      = "Any gender",
        selfFound   = false,
        professions = {},
        recommendedProfession = {
            name = "Enchanting",
            reason = "90 Enchanting is needed to blaze your weapon with Minor Beastslaying.",
        },
        equipment   = {
            E("No chest", 1),
            E("2h sword", 10),
            E("Blazing weapon", 20),
            E("Katana", 21),
        },
        challenges  = {},
        optionalChallenges = {
            E("Exotic", 1),
            E("Partisan", 1),
            E("Expeditionary", 1),
            E("Leather/mail", 1),
        },
        quests      = {
            Q("Hidden Enemies", 16, 5730),
            Q("King of the Foulweald", 26, 6621),
            Q("The Corrupter", 37, 1488),
            Q("Service to the Horde", 40, 7541),
            Q("Continued Threat", 45, 1428),
            Q("The Princess Saved?", 59, 4004),
            Q("For The Horde!", 60, 4974),
        },
        questTheme  = "Orgrimmar Loyalist",
        companion   = nil,
        pet         = nil,
        mount       = nil,
        gameplay    = "/sit and /meditate",
    },

    ["Berserker_WARRIOR"] = {
        class       = "WARRIOR",
        spec        = "Fury/Prot",
        name        = "Berserker",
        races       = { "Troll" },
        gender      = "Any gender",
        selfFound   = true,
        professions = { "Alchemy" },
        challenges  = {
            E("Faction Loyalist", 1),
            E("Elixir Frenzy", 15),
            E("Avenger", 60),
        },
        optionalChallenges = {
            E("Scout", 1),
            E("Partisan", 1),
            E("Expeditionary", 1),
        },
        equipment   = {
            E("Thrown", 10),
            E("Dual axes", 20),
            E("Rage potion", 25),
        },
        quests      = {
            Q("Zalazane", 10, 826),
            Q("Troll Charm", 24, 6462),
            Q("Jin'Zil's Forest Magic", 26, 1058),
            Q("Trol'kalar", 42, 646),
            Q("Saving Yenniku", 46, 592),
        },
        questTheme = "Darkspear Loyalist",
        companion   = nil,
        pet         = nil,
        mount       = nil,
        gameplay    = "rage pot",
    },

    ["Brave_WARRIOR"] = {
        class       = "WARRIOR",
        spec        = "Polearm",
        name        = "Brave",
        races       = { "Tauren" },
        gender      = "Any gender",
        selfFound   = true,
        professions = {},
        equipment   = {
            E("No shirt", 1),
            E("War harness", 10),
            E("Polearm", 20),
        },
        challenges  = {
            E("Faction Loyalist", 1),
        },
        optionalChallenges = {
            E("Scout", 1),
            E("Partisan", 1),
            E("Leather/mail", 1),
        },
        questsByHomebound = { 
            default = {
                Q("Rites of the Earthmother", 14, 776),
                Q("Earthen Arise", 20, 6481),
                Q("Grimtotem Spying", 28, 5064),
                Q("Final Passage", 36, 1394),
                Q("Zukk'ash Report", 48, 7732),
                Q("Glyphed Oaken Branch", 56, 4987),
            },
            homebound = {
                Q("Rites of the Earthmother", 14, 776),
                Q("Earthen Arise", 20, 6481),
                Q("Grimtotem Spying", 28, 5064),
                Q("Zukk'ash Report", 48, 7732),
                Q("Morrowgrain Research", 50, 3786),
                Q("Past Endeavors", 59, 5057),
            },
        },
        questTheme  = "Thunderbluff Loyalist",
        companion   = nil,
        pet         = nil,
        mount       = nil,
        gameplay    = nil,
    },

    ["Runemaster_WARRIOR"] = {
        class       = "WARRIOR",
        spec        = "Flurry",
        name        = "Runemaster",
        races       = { "Tauren", "Dwarf", "Orc" },
        gender      = "Any gender",
        selfFound   = false,
        professions = { "Enchanting" },
        challenges  = {
            E("All-out Assault", 1),
            E("Keeper", 60),
        },
        optionalChallenges = {
            E("Exotic", 1),
            E("Scavenger", 1),
            E("Expeditionary", 1),
            E("Leather/mail", 1),
        },
        equipment   = {
            E("No chest", 1),
            E("Fist weapons", 10),
            E("Kilt", 25),
        },
        questsByFaction = {
            Alliance = {
                Q("Cleansing of the Infected", 16, 2138),
                Q("The Escape", 18, 863),
                Q("Keeper of the Flame", 20, 103),
                Q("Gerenzo Wrenchwhistle", 27, 1096),
                Q("Hostile Takeover", 36, 213),
                Q("Venture Company Mining", 41, 600),
                Q("Verifying the Corruption", 54, 5156),
                Q("Arcane Runes", 52, 3449),
                Q("Cleansing Felwood", 55, 4101),
            },
            Horde = {
                Q("The Venture Co.", 10, 764),
                Q("Keeper of the Flame", 20, 103),
                Q("The Weaver", 22, 480),
                Q("Revenge of Gann", 26, 849),
                Q("Gerenzo Wrenchwhistle", 27, 1096),
                Q("Hostile Takeover", 36, 213),
                Q("Venture Company Mining", 41, 600),
                Q("Summoning the Princess", 50, 656),
                Q("Cleansing Felwood", 55, 4102),
            },
        },
        questTheme  = "Naturalist Scribe",
        companion   = nil,
        pet         = nil,
        mount       = nil,
        gameplay    = "Self-made enchants, scrolls, pro-nature",
    },

    ["Death Knight_WARRIOR"] = {
        class       = "WARRIOR",
        spec        = "Fury/Prot",
        name        = "Death Knight",
        races       = { "Undead" },
        gender      = "Any gender",
        selfFound   = true,
        professions = {},
        challenges  = {
            E("Cult of the Damned", 60),
        },
        optionalChallenges = {
            E("Expeditionary", 1),
            E("Drifter", 1),
            E("Nocturnal", 1),
        },
        equipment   = {
            E("No shield", 1),
            E("Runeblade", 25),
            E("Runebelt", 45),
        },
        quests = {
            Q("The Book of Ur", 26, 1013),
            Q("The Star, the Hand and the Heart", 44, 736),
            Q("Twisted Evils", 47, 7028),
            Q("The God Hakkar", 53, 3528),
            Q("Helcular's Revenge", 55, 553),
        },
        questTheme  = "Nihilist",
        companion   = nil,
        pet         = nil,
        mount       = nil,
        gameplay    = "argent war",
    },

    ["Exemplar_WARRIOR"] = {
        class       = "WARRIOR",
        spec        = '"Sword & Board"',
        name        = "Exemplar",
        races       = { "Human" },
        gender      = "Any gender",
        selfFound   = true,
        professions = {},
        recommendedProfessionByFaction  = {
            Alliance = {
                name = "Tailoring, Blacksmithing",
                reason = "A very modest level of Tailoring skill is required to craft the Blue Linen Shirt. Forge the Imperial armor pieces with Blacksmithing.",
            },
        },
        challenges  = {
            E("Faction Loyalist", 1),
        },
        optionalChallenges = {
            E("Homebound", 1),
            E("Partisan", 1),
            E("Self-made", 1),
        },
        equipmentByFaction   = {
            Horde = {
                E("Guild tabard", 20),
                E("Insignia", 30),
                E("Forsaken shield", 30),
                E("Forsaken shoulders", 42),
                E("Forsaken helm", 45),
            },
            Alliance = {
                E("Sword or mace", 5),
                E("Blue shirt", 10),
                E("Guild tabard", 20),
                E("Insignia", 30),
                E("Imperial helm", 45),
                E("Imperial shoulders", 53),
            },
        },
        questsByFaction = {
            Alliance = {
                default = {
                    Q("Missing In Action", 25, 219),
                    Q("An Audience with the King", 31, 396),
                    Q("Reassignment", 32, 563),
                    Q("The Missing Diplomat", 38, 1267),
                    Q("Mai'Zoth", 46, 206),
                    Q("The Great Masquerade", 59, 6403),
                }, 
                homebound = {
                    Q("Missing In Action", 25, 219),
                    Q("An Audience with the King", 31, 396),
                    Q("Reassignment", 32, 563),
                    Q("The Legend of Stalvan", 35, 98),
                    Q("Mai'Zoth", 46, 206),
                    Q("The Great Masquerade", 59, 6403),
                },
            },
            Horde = {
                default = {
                    Q("Arugal's Folly", 15, 99),
                    Q("Battle of Hillsbrad", 32, 550),
                    Q("Nothing But The Truth", 42, 1391),
                    Q("The Crown of Will", 43, 521),
                    Q("The Ranger Lord's Behest", 59, 6133),
                }, 
                homebound = {
                    Q("Arugal's Folly", 15, 99),
                    Q("Battle of Hillsbrad", 32, 550),
                    Q("Nothing But The Truth", 42, 1391),
                    Q("The Crown of Will", 43, 521),
                    Q("The Ranger Lord's Behest", 59, 6133),
                },
            },
        },
        questTheme = "Faction Loyalist",
        companion   = nil,
        pet         = nil,
        mount       = nil,
        gameplayByFaction    = {
            Alliance = "Stormwind hearthstone, sw tabard",
            Horde    = "uc hearthstone, uc tabard",
        },
    },

    ["Deathguard_WARRIOR"] = {
        class       = "WARRIOR",
        spec        = '"Sword & Board"',
        name        = "Deathguard",
        races       = { "Undead" },
        gender      = "Any gender",
        selfFound   = true,
        professions = {},
        challenges  = {
            E("Faction Loyalist", 1),
            E("Insular", 1),
        },
        optionalChallenges = {
            E("Partisan", 1),
            E("Self-made", 1),
        },
        equipment   = {
            E("Axe & shield", 10),
            E("Guild tabard", 20),
            E("Insignia", 30),
            E("Forsaken shield", 30),
            E("Forsaken shoulders", 42),
            E("Forsaken helm", 45),
        },
        quests = {
            default = {
                Q("Arugal's Folly", 15, 99),
                Q("Battle of Hillsbrad", 32, 550),
                Q("Nothing But The Truth", 42, 1391),
                Q("The Crown of Will", 43, 521),
                Q("The Ranger Lord's Behest", 59, 6133),
            }, 
            homebound = {
                Q("Arugal's Folly", 15, 99),
                Q("Battle of Hillsbrad", 32, 550),
                Q("Nothing But The Truth", 42, 1391),
                Q("The Crown of Will", 43, 521),
                Q("The Ranger Lord's Behest", 59, 6133),
            },
        },
        questTheme = "Undercity Loyalist",
        companion   = nil,
        pet         = nil,
        mount       = nil,
        gameplay    = "uc hearthstone, uc tabard",
    },

    ---------- ROGUE ----------

    ["Mountain King_ROGUE"] = {
        class       = "ROGUE",
        spec        = "Mace",
        name        = "Mountain King",
        races       = { "Dwarf" },
        gender      = "Male",
        selfFound   = true,
        professions = {},
        challenges  = {
            E("No nonsense", 1),
            E("Happy Hour", 10),
        },
        optionalChallenges = {
            E("Partisan", 1),
            E("Expeditionary", 1),
            E("Explorer", 1),
        },
        equipment   = {
            E("Maces", 10),
            E("Wildhammer helm", 34),
            E("Flask trinket", 44),
            E("Wildhammer mace", 50),
        },
        quests      = {
            Q("In Defense of the King's Lands", 17, 217),
            Q("The Absent Minded Prospector", 24, 943),
            Q("Defeat Nek'rosh", 32, 474),
            Q("The Lost Tablets of Will", 45, 1139),
            Q("Rise, Obsidion!", 52, 3566),
            Q("The Princess's Surprise", 59, 4363),
        },
        questTheme  = "Ironforge Loyalist",
        companion   = nil,
        pet         = nil,
        mount       = nil,
        gameplay    = "Beer, treasure",
    },

    ["Prospector_ROGUE"] = {
        class       = "ROGUE",
        spec        = "Ambush",
        name        = "Prospector",
        races       = { "Dwarf" },
        gender      = "Any gender",
        selfFound   = true,
        professions = { "Mining" },
        equipment   = {
            E("Dagger", 10),
            E("Crossbow", 10),
            E("Prospector headgear", 32),
            E("Prospector's pick", 35),
        },
        challenges  = {
            E("Explorer", 1),
            E("Master Smelter", 55),
        },
        optionalChallenges = {
            E("Scout", 1),
            E("Scavenger", 1),
            E("Expeditionary", 1),
        },
        quests      = {
            Q("Cave Mushrooms", 17, 947),
            Q("Collecting Memories", 18, 168),
            Q("Search for Incendicite", 22, 466),
            Q("Rethban Ore", 24, 347),
            Q("A King's Tribute", 31, 700),
            Q("Favor for Krazek", 37, 627),
            Q("Restoring the Necklace", 44, 2361),
            Q("Delivering the Relic", 45, 2871),
            Q("The Mighty U'cha", 55, 4301),
        },
        questTheme  = "Dungeoneer",
        companion   = nil,
        pet         = nil,
        mount       = nil,
        gameplay    = "pick",
    },

    ["Runemaster_ROGUE"] = {
        class       = "ROGUE",
        spec        = "Fist Combat",
        name        = "Runemaster",
        races       = { "Orc", "Dwarf" },
        gender      = "Any gender",
        selfFound   = false,
        professions = { "Enchanting" },
        challenges  = {
            E("Overt", 1),
            E("Keeper", 60),
        },
        optionalChallenges = {
            E("Exotic", 1),
            E("Scavenger", 1),
            E("Expeditionary", 1),
            E("Cloth", 1),
        },
        equipment   = {
            E("No chest", 1),
            E("Fist weapons", 10),
            E("Kilt", 25),
        },
        questsByFaction = {
            Alliance = {
                Q("Cleansing of the Infected", 16, 2138),
                Q("The Escape", 18, 863),
                Q("Keeper of the Flame", 20, 103),
                Q("Gerenzo Wrenchwhistle", 27, 1096),
                Q("Hostile Takeover", 36, 213),
                Q("Venture Company Mining", 41, 600),
                Q("Verifying the Corruption", 54, 5156),
                Q("Arcane Runes", 52, 3449),
                Q("Cleansing Felwood", 55, 4101),
            },
            Horde = {
                Q("The Venture Co.", 10, 764),
                Q("Keeper of the Flame", 20, 103),
                Q("The Weaver", 22, 480),
                Q("Revenge of Gann", 26, 849),
                Q("Gerenzo Wrenchwhistle", 27, 1096),
                Q("Hostile Takeover", 36, 213),
                Q("Venture Company Mining", 41, 600),
                Q("Summoning the Princess", 50, 656),
                Q("Cleansing Felwood", 55, 4102),
            },
        },
        questTheme  = "Naturalist Scribe",
        companion   = nil,
        pet         = nil,
        mount       = nil,
        gameplay    = "Self-made enchants, scrolls, pro-nature",
    },

    ["Tinker_ROGUE"] = {
        class       = "ROGUE",
        spec        = "Mace",
        name        = "Tinker",
        races       = { "Gnome" },
        gender      = "Any gender",
        selfFound   = true,
        professions = { "Engineering" },
        equipment   = {
            E("Maces", 5),
            E("Gun", 10),
            E("Beginner goggles", 20, 29),
            E("Intermediate goggles", 30, 39),
            E("Engineering trinkets", 35),
            E("Discombobulator ray", 35),
            E("Advanced goggles", 40),
        },
        challenges  = {
            E("Gnomish Justice", 45),
        },
        optionalChallenges = {
            E("Scavenger", 1),
            E("Expeditionary", 1),
            E("Off-the-shelf", 1),
        },
        quests      = {
            Q("A Dark Threat Looms", 20, 283),
            Q("Data Rescue", 30, 2930),
            Q("Show Your Work", 47, 3641),
            Q("An OOX of Your Own", 50, 3721),
        },
        questTheme  = "Gadgetist",
        companion   = E("Mechanical", 45),
        pet         = nil,
        mount       = nil,
        gameplay    = nil,
    },

    ["Dark Ranger_ROGUE"] = {
        class       = "ROGUE",
        spec        = "Ghost",
        name        = "Dark Ranger",
        races       = { "Undead" },
        gender      = "Any gender",
        selfFound   = true,
        professions = {},
        weaponProficiency = { E("Bows", 15) },
        challenges  = {
        },
        optionalChallenges = {
            E("Scout", 1),
            E("Partisan", 1),
            E("Drifter", 1),
        },
        equipment   = {
            E("No maces", 1),
            E("Bow", 12),
            E("Quiver", 12),
            E("Dark Ranger blade", 25),
            E("Dark Ranger cape", 46),
            E("Dark Ranger hood", 50),  
            E("Dark Ranger shoulders", 50),          
        },
        quests      = {
            Q("Arachnophobia", 21, 6284),
            Q("Bloodfury Bloodline", 26, 6283),
            Q("Arikara", 28, 5088),
            Q("Hypercapacitor Gizmo", 30, 5151),
            Q("Vorrel's Revenge", 33, 1051),
            Q("Excelsior", 38, 628),
            Q("Big Game Hunter", 43, 208),
            Q("Facing Negolash", 50, 8554),
            Q("Past Endeavors", 59, 5057),
        },
        questTheme  = "Test of the Solo Ranger",
        companion   = nil,
        pet         = nil,
        mount       = nil,
        gameplay    = "bow kiting",
    },

    ["Fletcher_ROGUE"] = {
        class       = "ROGUE",
        spec        = "Ghost",
        name        = "Fletcher",
        races       = { "Human" },
        gender      = "Any gender",
        selfFound   = true,
        professions = {},
        recommendedProfession = {
            name = "Tailoring & Leatherworking",
            reason = "Level Tailoring first to obtain the hood, then switch to Leatherworking for the cape & the gloves.",
        },
        weaponProficiency = { E("Bows", 15) },
        challenges  = {
        },
        optionalChallenges = {
            E("Scout", 1),
            E("Partisan", 1),
            E("Drifter", 1),
        },
        equipment   = {
            E("No maces", 1),
            E("Fletcher blade", 10),
            E("Bow", 12),
            E("Quiver", 12),
            E("Fletcher hood", 36),
            E("Fletcher gloves", 38),
            E("Fletcher cape", 38),
            E("Fletcher shoulders", 40), 
        },
        quests      = {
            Q("Wanted: Hogger", 11, 176),
            Q("Vyrin's Revenge", 20, 531),
            Q("Gyromast's Revenge", 20, 2078),
            Q("Defeat Nek'rosh", 32, 474),
            Q("Proof of Deed", 48, 3182),
            Q("Big Game Hunter", 43, 208),
            Q("Facing Negolash", 50, 8554),
            Q("Wanted - Deathclasp, Terror of the Sands", 59, 8283),
        },
        questTheme  = "Test of the Solo Archer",
        companion   = nil,
        pet         = nil,
        mount       = nil,
        gameplay    = "bow kiting",
    },

    ["Warden_ROGUE"] = {
        class       = "ROGUE",
        spec        = "Backstab/Poison",
        name        = "Warden",
        races       = { "Night Elf" },
        gender      = "Female",
        selfFound   = true,
        professions = {},
        challenges  = {
            E("Lockdown", 1),
        },
        optionalChallenges = {
            E("Exotic", 1),
            E("Partisan", 1),
            E("Self-made", 1),
        },
        equipment   = {
            E("Daggers", 1),
            E("Robe", 5),
            E("Thrown", 10),
        },
        quests      = {
            Q("Sathrah's Sacrifice", 12, 2520),
            Q("Raene's Cleansing", 30, 1046),
            Q("Rise of the Silithid", 46, 4267),
            Q("The Mystery of Morrowgrain", 50, 3791),
            Q("Calm Before the Storm", 54, 4508),
            Q("The Treasure of the Shen'dralar", 60, 7877),
        },
        questTheme  = "Darnassus Loyalist",
        companion   = E("Owl", 10),
        pet         = nil,
        mount       = nil,
        gameplay    = nil,
    },

    ["Demon Hunter_ROGUE"] = {
        class       = "ROGUE",
        spec        = "Sword",
        name        = "Demon Hunter",
        races       = { "Night Elf" },
        gender      = "Any gender",
        selfFound   = true,
        professions = {},
        challenges  = {},
        optionalChallenges = {
            E("Exotic", 1),
            E("Scavenger", 1),
            E("Self-made", 1),
        },
        equipment   = {
            E("No chest", 1),
            E("Dual swords", 20),
            E("Kilt", 25),
        },
        questsByHomebound = { 
            default = {
                Q("The Blackwood Corrupted", 18, 4763),
                Q("The Tower of Althalaxx", 31, 981),
                Q("Satyr Slaying!", 32, 1032),
                Q("A Land Filled with Hatred", 47, 5536),
                Q("Ancient Spirit", 56, 4261),
                Q("A Final Blow", 58, 5242),
                Q("You Are Rakh'likh, Demon", 60, 3628),
            },
            homebound = {
                Q("The Blackwood Corrupted", 18, 4763),
                Q("The Tower of Althalaxx", 31, 981),
                Q("Satyr Slaying!", 32, 1032),
                Q("A Land Filled with Hatred", 47, 5536),
                Q("Ancient Spirit", 56, 4261),
                Q("A Final Blow", 58, 5242),
            },
        },
        questTheme  = "The Legion Shall Fall",
        companion   = nil,
        pet         = nil,
        mount       = nil,
        gameplay    = "Anti-demon, /bow",
    },

    ["Buccaneer_ROGUE"] = {
        class       = "ROGUE",
        spec        = "Backstab/Riposte",
        name        = "Buccaneer",
        races       = { "Human", "Undead", "Gnome" },
        gender      = "Any gender",
        selfFound   = true,
        professions = { "Fishing" },
        recommendedProfession = {
            name = "Tailoring",
            reason = "Needed to craft Captain's Hat, which requires 240 Tailoring.",
        },
        weaponProficiency = { E("Guns", 15) },
        equipment   = {
            E("Dagger", 1),
            E("Gun", 10),
            E("Pirate blade", 20),
            E("Pirate shirt", 20),
            E("Pirate belt", 40),
            E("Captain's hat", 45),
        },
        challenges  = {
            E("Explorer", 1),
            E("Lockdown", 1),
            E("Seeking a Pardon", 10),
        },
        optionalChallenges = {
            E("Scout", 1),
            E("Scavenger", 1),
            E("Expeditionary", 1),
            E("Drifter", 1),
        },
        questsByFaction = {
            Alliance = {
                Q("Stolen Booty", 16, 888),
                Q("Deep Ocean, Vast Sea", 17, 982),
                Q("Trouble at the Docks", 19, 959),
                Q("The Cursed Crew", 29, 289),
                Q("Claim Rackmore's Treasure!", 36, 6161),
                Q("Pearl Diving", 37, 705),
                Q("Deep Sea Salvage", 40, 662),
                Q("Cuergo's Gold", 45, 2882),
                Q("Whiskey Slim's Lost Grog", 50, 580),
            },
            Horde = {
                Q("From The Wreckage....", 8, 825),
                Q("Stolen Booty", 16, 888),
                Q("Trouble at the Docks", 19, 959),
                Q("Claim Rackmore's Treasure!", 36, 6161),
                Q("Catch of the Day", 37, 5386),
                Q("Pearl Diving", 37, 705),
                Q("Deep Sea Salvage", 40, 662),
                Q("Cuergo's Gold", 45, 2882),
                Q("Whiskey Slim's Lost Grog", 50, 580),
            },
        },
        questTheme  = "Treasure Hunter",
        companion   = E("Parrot", 15),
        pet         = nil,
        mount       = nil,
        gameplay    = "Rum, gun kiting",
    },

    ["Berserker_ROGUE"] = {
        class       = "ROGUE",
        spec        = "Ambush",
        name        = "Berserker",
        races       = { "Troll" },
        gender      = "Any gender",
        selfFound   = true,
        professions = { "Alchemy" },
        recommendedProfession = {
            name = "Cooking",
            reason = "Need basic Cooking skills to make Thistle Tea.",
        },
        challenges  = {
            E("Faction Loyalist", 1),
            E("Elixir Frenzy", 15),
            E("Avenger", 60),
        },
        optionalChallenges = {
            E("Scout", 1),
            E("Partisan", 1),
            E("Expeditionary", 1),
        },
        equipment   = {
            E("Dagger and sword", 10),
            E("Thrown", 10),
            E("Thistle tea", 16),
        },
        quests      = {
            Q("Zalazane", 10, 826),
            Q("Troll Charm", 24, 6462),
            Q("Jin'Zil's Forest Magic", 26, 1058),
            Q("Trol'kalar", 42, 646),
            Q("Saving Yenniku", 46, 592),
        },
        questTheme = "Darkspear Loyalist",
        companion   = nil,
        pet         = nil,
        mount       = nil,
        gameplay    = "thistle tea",
    },

    ["Gladiator_ROGUE"] = {
        class       = "ROGUE",
        spec        = "Combat",
        name        = "Gladiator",
        races       = { "Orc", "Human", "Troll" },
        gender      = "Any gender",
        selfFound   = true,
        professions = {},
        weaponProficiency = { E("Weapon Mastery", 22) },
        equipment   = {
            E("No chest", 1),
            E("No guns", 10),
            E("Mixed weapons", 20),
        },
        challenges  = {
            E("Overt", 1),
            E("Insular", 1),
        },
        optionalChallenges = {
            E("Scavenger", 1),
            E("Expeditionary", 1),
            E("Off-the-shelf", 1),
        },
        questsByFaction = {
            Alliance = {
                Q("Wanted: Hogger", 11, 176),
                Q("WANTED: Baron Longshore", 16, 895),
                Q("WANTED: Chok'sul", 22, 256),
                Q("Wanted: Gath'Ilzogg", 26, 169),
                Q("Wanted! Otto and Falconcrest", 40, 685),
                Q("WANTED: Andre Firebeard", 45, 2875),
                Q("WANTED: Caliph Scorpidsting", 46, 2781),
                Q("WANTED: Overseer Maltorius", 50, 7701),
                Q("Wanted - Deathclasp, Terror of the Sands", 59, 8283),
            },
            Horde = {
                Q("Wanted: Maggot Eye", 10, 398),
                Q("WANTED: Baron Longshore", 16, 895),
                Q("Wanted - Arnak Grimtotem", 29, 5147),
                Q("Challenge Overlord Mok'Morokk", 45, 1173),
                Q("WANTED: Andre Firebeard", 45, 2875),
                Q("WANTED: Caliph Scorpidsting", 46, 2781),
                Q("WANTED: Overseer Maltorius", 50, 7701),
                Q("Wanted - Deathclasp, Terror of the Sands", 59, 8283),          
            },
        },
        questTheme  = "Challenger",
        companion   = nil,
        pet         = nil,
        mount       = nil,
        gameplay    = nil,
    },

    ["Apothecary_ROGUE"] = {
        class       = "ROGUE",
        spec        = "Backstab/Poison",
        name        = "Apothecary",
        races       = { "Undead" },
        gender      = "Any gender",
        selfFound   = true,
        professions = { "Alchemy" },
        equipment   = {
            E("Robe", 1),
            E("Dagger", 5),
            E("Herb pouch", 10),
            E("Vial off-hand", 18),
        },
        challenges  = {
            E("The New Plague", 55),
        },
        optionalChallenges = {
            E("Scout", 1),
            E("Partisan", 1),
            E("Homebound", 1),
            E("Insular", 1),
        },
        questsByHomebound = { 
            default = {
                Q("A New Plague", 11, 492),
                Q("A Recipe For Death", 18, 451),
                Q("Elixir of Suffering", 22, 499),
                Q("The Flying Machine Airport", 23, 1086),
                Q("Elixir of Pain", 24, 502),
                Q("Elixir of Agony", 30, 524),
                Q("Nothing But The Truth", 42, 1383),
                Q("Zanzil's Secret", 44, 621),
                Q("Venom to the Undercity", 55, 2938),
            },
            homebound = {
                Q("A New Plague", 11, 492),
                Q("A Recipe For Death", 18, 451),
                Q("Elixir of Suffering", 22, 499),
                Q("Elixir of Pain", 24, 502),
                Q("Elixir of Agony", 30, 524),
                Q("Nothing But The Truth", 42, 1383),
                Q("Zanzil's Secret", 44, 621),
                Q("Venom to the Undercity", 55, 2938),
            },
        },
        questTheme  = "Plague-brewer",
        companion   = E("Cockroach", 10),
        pet         = nil,
        mount       = nil,
        gameplay    = nil,
    },

    ["Elven Ranger_ROGUE"] = {
        class       = "ROGUE",
        spec        = "Ghost",
        name        = "Elven Ranger",
        races       = { "Night Elf" },
        gender      = "Any gender",
        selfFound   = true,
        professions = {},
        recommendedProfession = {
            name = "Tailoring",
            reason = "A modest level of Tailoring is required to craft the Azure Silk Hood (125 Tailoring).",
        },
        weaponProficiency = { E("Bows", 15) },
        challenges  = {
            E("Faction Loyalist", 1),
        },
        optionalChallenges = {
            E("Scout", 1),
            E("Partisan", 1),
            E("Expeditionary", 1),
            E("Cloth/leather", 1),
        },
        equipment   = {
            E("Bow", 12),
            E("Dual swords", 20),
            E("Elven hood", 28),
            E("Elven cape", 30),
        },
        quests      = {
            Q("Wanted: Hogger", 11, 176),
            Q("Vyrin's Revenge", 20, 531),
            Q("Gyromast's Revenge", 20, 2078),
            Q("Defeat Nek'rosh", 32, 474),
            Q("Proof of Deed", 48, 3182),
            Q("Big Game Hunter", 43, 208),
            Q("Facing Negolash", 50, 8554),
            Q("Wanted - Deathclasp, Terror of the Sands", 59, 8283),
        },
        questTheme  = "Test of the Solo Ranger",
        companion   = nil,
        pet         = nil,
        mount       = nil,
        gameplay    = "bow kiting",
    },

    ---------- PALADIN ----------

    ["Templar_PALADIN"] = {
        class       = "PALADIN",
        spec        = "Holy/Prot",
        name        = "Templar",
        races       = { "Dwarf", "Human" },
        gender      = "Any gender",
        selfFound   = true,
        professions = {},
        challenges  = {
            E("Purifier", 60),
        },
        optionalChallenges = {
            E("Homebound", 1),
            E("Mail/plate", 1),
            E("Self-made", 1),
        },
        equipment   = {
            E("Sword or mace", 5, 49),
            E("Guild tabard", 20),
            E("Argent shoulders", 35),
            E("Argent helm", 45),
            E("Argent Dawn trinket", 50),
            E("Templar blade", 50),
        },
        questsByHomebound = { 
            default = {
                Q("Collecting Memories", 18, 168),
                Q("Cleansing the Eye", 30, 293),
                Q("Bride of the Embalmer", 30, 253),
                Q("Voodoo Dues", 44, 609),
                Q("Spiritual Unrest", 47, 5535),
                Q("The Remains of Trey Lightforge", 57, 5385),
                Q("The Argent Hold", 60, 5265),
            },
            homebound = {
                Q("Collecting Memories", 18, 168),
                Q("Cleansing the Eye", 30, 293),
                Q("Bride of the Embalmer", 30, 253),
                Q("Voodoo Dues", 44, 609),
                Q("Mission Accomplished!", 58, 5237),
                Q("The Argent Hold", 60, 5265),
            },
        },
        questTheme  = "Purging the Undead",
        companion   = nil,
        pet         = nil,
        mount       = nil,
        gameplay    = "Anti-undead, argent tabard",
    },

    ["Shieldbearer_PALADIN"] = {
        class       = "PALADIN",
        spec        = '"Sword & Board"',
        name        = "Shieldbearer",
        races       = { "Dwarf" },
        gender      = "Any gender",
        selfFound   = false,
        professions = {},
        challenges  = {
            E("Retribution Aura", 20),
        },
        optionalChallenges = {
            E("Homebound", 1),
            E("Mail/plate", 1),
            E("Partisan", 1),
        },
        equipment   = {
            E("Shield", 5),
            E("Reflector shield", 32),
            E("Shield spike", 32),
            E("Reflector belt", 46),
            E("Reflector armor", 50),
        },
        questsByHomebound = { 
            default = {
                Q("Tramping Paws", 21, 276),
                Q("The Night Watch", 26, 57),
                Q("Worgen in the Woods", 31, 222),
                Q("Syndicate Assassins", 33, 505),
                Q("Hints of a New Plague?", 37, 661),
                Q("Clear the Way", 52, 5092),
            },
            homebound = {
                Q("Tramping Paws", 21, 276),
                Q("The Night Watch", 26, 57),
                Q("Worgen in the Woods", 31, 222),
                Q("Syndicate Assassins", 33, 505),
                Q("Hints of a New Plague?", 37, 661),
                Q("Clear the Way", 52, 5092),
            },
        },
        questTheme  = "Crowd Control",
        companion   = nil,
        pet         = nil,
        mount       = nil,
        gameplay    = "tank tour",
    },

    ["Sister of Steel_PALADIN"] = {
        class       = "PALADIN",
        spec        = "Retribution",
        name        = "Sister of Steel",
        races       = { "Dwarf" },
        gender      = "Female",
        selfFound   = true,
        professions = { "Blacksmithing" },
        challenges  = {
            E("Self-made", 1),
            E("Agnostic", 1),
            E("Smith", 60),
        },
        optionalChallenges = {
            E("Homebound", 1),
            E("Insular", 1),
        },
        questsByHomebound = { 
            default = {
                Q("Supplying the Front", 16, 1578),
                Q("Jarl Needs a Blade", 35, 1203),
                Q("Expert Blacksmith!", 45, 2765),
                Q("Did You Lose This?", 50, 3321),
                Q("Gaining Acceptance", 55, 7737),
                Q("Corruption", 60, 5307),
            },
            homebound = {
                Q("Supplying the Front", 16, 1578),
                Q("The Everstill Bridge", 20, 89),
                Q("Gearing Redridge", 20, 1618),
                Q("Expert Blacksmith!", 45, 2765),
                Q("STOLEN: Smithing Tuyere and Lookout's Spyglass", 48, 7728),
                Q("Gaining Acceptance", 55, 7737),
            },
        },
        questTheme  = "The Mithril Order",
        companion   = nil,
        pet         = nil,
        mount       = nil,
        gameplay    = "epic hammer",
    },

    ["Exemplar_PALADIN"] = {
        class       = "PALADIN",
        spec        = "Retribution",
        name        = "Exemplar",
        races       = { "Human" },
        gender      = "Any gender",
        selfFound   = true,
        professions = {},
        recommendedProfession = {
            name = "Tailoring, Blacksmithing",
            reason = "A very modest level of Tailoring skill is required to craft the Blue Linen Shirt. Forge the Imperial armor pieces with Blacksmithing.",
        },
        challenges  = {
            E("Faction Loyalist", 1),
        },
        optionalChallenges = {
            E("Partisan", 1),
            E("Expeditionary", 1),
            E("Self-made", 1),
        },
        equipment   = {
            E("Sword or mace", 5),
            E("Blue shirt", 10),
            E("Guild tabard", 20),
            E("Insignia", 30),
            E("Imperial helm", 45),
            E("Imperial shoulders", 53),
        },
        quests      = {
            Q("Missing In Action", 25, 219),
            Q("An Audience with the King", 31, 396),
            Q("The Missing Diplomat", 38, 1267),
            Q("Mai'Zoth", 46, 206),
            Q("The Great Masquerade", 59, 6403),
        },
        questTheme  = "Stormwind Loyalist",
        companion   = nil,
        pet         = nil,
        mount       = nil,
        gameplay    = "Stormwind hearthstone, sw tabard",
    },

    ["Scarlet Champion_PALADIN"] = {
        class       = "PALADIN",
        spec        = '"Sword & Board"',
        name        = "Scarlet Champion",
        races       = { "Human" },
        gender      = "Any gender",
        selfFound   = true,
        professions = {},
        recommendedProfession = {
            name = "Tailoring",
            reason = "A very modest level of skill is required to craft the Red Linen Shirt (Tailoring 40).",
        },
        equipment   = {
            E("Red shirt", 10),
            E("Scarlet tabard", 40, 59),
            E("Scarlet shoulders", 40),
            E("Scarlet helm", 40),
            E("Scarlet shield", 44),
            E("Scarlet chestpiece", 46),
            E("Scarlet leggings", 46),
            E("Scarlet gauntlets", 46),
            E("Scarlet boots", 50),
        },
        challenges  = {
            E("Purifier", 60),
            E("Scarlet Redemption", 60),
        },
        optionalChallenges = {
            E("Exotic", 1),
            E("Scavenger", 1),
            E("Homebound", 1),
        },
        questsByHomebound = { 
            default = {
                Q("Collecting Memories", 18, 168),
                Q("Cleansing the Eye", 30, 293),
                Q("Bride of the Embalmer", 30, 253),
                Q("Mythology of the Titans", 38, 1050),
                Q("Spiritual Unrest", 47, 5535),
                Q("The Remains of Trey Lightforge", 57, 5385),
                Q("Unfinished Business", 58, 6025),
                Q("The Truth Comes Crashing Down", 60, 5262),
                Q("In Dreams", 60, 5944),
            },
            homebound = {
                Q("Collecting Memories", 18, 168),
                Q("Cleansing the Eye", 30, 293),
                Q("Bride of the Embalmer", 30, 253),
                Q("Mythology of the Titans", 38, 1050),
                Q("Voodoo Dues", 44, 609),
                Q("The Truth Comes Crashing Down", 60, 5262),
                Q("Unfinished Business", 58, 6025),
                Q("In Dreams", 60, 5944),
            },
        },
        questTheme  = "Leaving the Cult",
        companion   = nil,
        pet         = nil,
        mount       = nil,
        gameplay    = "tank tour",
    },

    ---------- PRIEST ----------

    ["Templar_PRIEST"] = {
        class       = "PRIEST",
        spec        = "Discipline",
        name        = "Templar",
        races       = { "Dwarf", "Human", "Night Elf" },
        gender      = "Any gender",
        selfFound   = true,
        professions = {},
        challenges  = {
            E("Purifier", 60),
        },
        optionalChallenges = {
            E("Homebound", 1),
            E("Self-made", 1),
            E("Partisan", 1),
        },
        equipment   = {
            E("Argent robe", 8),
            E("Guild tabard", 20),
            E("Holy flame", 30),
            E("Argent mantle", 30),
            E("Righteous hammer", 40),
            E("Argent Dawn trinket", 50),
            E("Argent circlet", 60),
        },
        questsByHomebound = { 
            default = {
                Q("Collecting Memories", 18, 168),
                Q("Cleansing the Eye", 30, 293),
                Q("Bride of the Embalmer", 30, 253),
                Q("Voodoo Dues", 44, 609),
                Q("Spiritual Unrest", 47, 5535),
                Q("The Remains of Trey Lightforge", 57, 5385),
                Q("The Argent Hold", 60, 5265),
            },
            homebound = {
                Q("Collecting Memories", 18, 168),
                Q("Cleansing the Eye", 30, 293),
                Q("Bride of the Embalmer", 30, 253),
                Q("Voodoo Dues", 44, 609),
                Q("Mission Accomplished!", 58, 5237),
                Q("The Argent Hold", 60, 5265),
            },
        },
        questTheme  = "Purging the Undead",
        companion   = nil,
        pet         = nil,
        mount       = nil,
        gameplay    = "Anti-undead, argent tabard",
    },

    ["Twilight Cultist_PRIEST"] = {
        class       = "PRIEST",
        spec        = "Shadow",
        name        = "Twilight Cultist",
        races       = { "Dwarf", "Night Elf", "Undead", "Troll" },
        gender      = "Any gender",
        selfFound   = true,
        professions = {},
        equipment   = {
            E("Dark robe", 8),
            E("Shadow wand", 15),
            E("Cultist shoulders", 60),
            E("Cultist cowl", 60),
            E("Cultist robe", 60),
        },
        challenges  = {
            E("Drifter", 1),
            E("Twilight's Hammer", 60),
        },
        optionalChallenges = {
            E("Exotic", 1),
            E("Scavenger", 1),
            E("Expeditionary", 1),
        },
        questsByFaction = {
            Alliance = {
                Q("Knowledge in the Deeps", 25, 971),
                Q("A Noble Brew", 30, 336),
                Q("The Star, the Hand and the Heart", 44, 735),
                Q("Twisted Evils", 47, 7028),
                Q("The God Hakkar", 53, 3528),
            },
            Horde = {
                Q("The Book of Ur", 26, 1013),
                Q("The Star, the Hand and the Heart", 44, 736),
                Q("Twisted Evils", 47, 7028),
                Q("The God Hakkar", 53, 3528),
                Q("Helcular's Revenge", 55, 553),
            },
        },
        questTheme  = "Nihilist",
        companion   = nil,
        pet         = nil,
        mount       = nil,
        gameplay    = "cenarion war",
    },

    ["Scarlet Champion_PRIEST"] = {
        class       = "PRIEST",
        spec        = "Spirit",
        name        = "Scarlet Champion",
        races       = { "Human" },
        gender      = "Any gender",
        selfFound   = true,
        professions = {},
        recommendedProfession = {
            name = "Tailoring",
            reason = "A very modest level of skill is required to craft the Red Linen Shirt (Tailoring 40).",
        },
        equipment   = {
            E("Red shirt", 10),
            E("Scarlet mantle", 30),
            E("Holy flame", 30),
            E("Scarlet tabard", 40, 59),
            E("Scarlet chapeau", 40),
            E("Righteous hammer", 40),
            E("Scarlet robe", 45),
        },
        challenges  = {
            E("Purifier", 60),
            E("Scarlet Redemption", 60),
        },
        optionalChallenges = {
            E("Exotic", 1),
            E("Scavenger", 1),
            E("Homebound", 1),
        },
        questsByHomebound = { 
            default = {
                Q("Collecting Memories", 18, 168),
                Q("Cleansing the Eye", 30, 293),
                Q("Bride of the Embalmer", 30, 253),
                Q("Mythology of the Titans", 38, 1050),
                Q("Spiritual Unrest", 47, 5535),
                Q("The Remains of Trey Lightforge", 57, 5385),
                Q("Unfinished Business", 58, 6025),
                Q("The Truth Comes Crashing Down", 60, 5262),
                Q("In Dreams", 60, 5944),
            },
            homebound = {
                Q("Collecting Memories", 18, 168),
                Q("Cleansing the Eye", 30, 293),
                Q("Bride of the Embalmer", 30, 253),
                Q("Mythology of the Titans", 38, 1050),
                Q("Voodoo Dues", 44, 609),
                Q("Unfinished Business", 58, 6025),
                Q("The Truth Comes Crashing Down", 60, 5262),
                Q("In Dreams", 60, 5944),
            },
        },
        questTheme  = "Leaving the Cult",
        companion   = nil,
        pet         = nil,
        mount       = nil,
        gameplay    = nil,
    },

    ["Apothecary_PRIEST"] = {
        class       = "PRIEST",
        spec        = "Hybrid",
        name        = "Apothecary",
        races       = { "Undead" },
        gender      = "Any gender",
        selfFound   = true,
        professions = { "Alchemy" },
        equipment   = {
            E("Robe", 1),
            E("Dagger", 5),
            E("Herb pouch", 10),
            E("Vial off-hand", 18),
            E("Nature wand", 30),
        },
        challenges  = {
            E("The New Plague", 55),
        },
        optionalChallenges = {
            E("Scout", 1),
            E("Partisan", 1),
            E("Homebound", 1),
            E("Insular", 1),
        },
        questsByHomebound = { 
            default = {
                Q("A New Plague", 11, 492),
                Q("A Recipe For Death", 18, 451),
                Q("Elixir of Suffering", 22, 499),
                Q("The Flying Machine Airport", 23, 1086),
                Q("Elixir of Pain", 24, 502),
                Q("Elixir of Agony", 30, 524),
                Q("Nothing But The Truth", 42, 1383),
                Q("Zanzil's Secret", 44, 621),
                Q("Venom to the Undercity", 55, 2938),
            },
            homebound = {
                Q("A New Plague", 11, 492),
                Q("A Recipe For Death", 18, 451),
                Q("Elixir of Suffering", 22, 499),
                Q("Elixir of Pain", 24, 502),
                Q("Elixir of Agony", 30, 524),
                Q("Nothing But The Truth", 42, 1383),
                Q("Zanzil's Secret", 44, 621),
                Q("Venom to the Undercity", 55, 2938),
            },
        },
        questTheme  = "Plague-brewer",
        companion   = E("Cockroach", 10),
        pet         = nil,
        mount       = nil,
        gameplay    = nil,
    },

    ["Lightslayer_PRIEST"] = {
        class       = "PRIEST",
        spec        = "Shadow Ascendant",
        name        = "Lightslayer",
        races       = { "Undead" },
        gender      = "Any gender",
        selfFound   = true,
        professions = {},
        equipment   = {
            E("Dagger", 10),
            E("Shadow wand", 15),
        },
        challenges  = {
            E("Shadow Ascendant", 1),
        },
        optionalChallenges = {
            E("Scavenger", 1),
            E("Homebound", 1),
            E("Self-made", 1),
            E("Nocturnal", 1),
        },
        questsByHomebound = { 
            default = {
                Q("At War With The Scarlet Crusade", 12, 372),
                Q("Vorrel's Revenge", 33, 1051),
                Q("Hearts of Zeal", 33, 1113),
                Q("Into The Scarlet Monastery", 42, 1048),
                Q("Unfinished Business", 58, 6025),
                Q("The Scarlet Oracle, Demetria", 60, 6148),
            },
            homebound = {
                Q("At War With The Scarlet Crusade", 12, 372),
                Q("Vorrel's Revenge", 33, 1051),
                Q("Into The Scarlet Monastery", 42, 1048),
                Q("Unfinished Business", 58, 6025),
                Q("The Scarlet Oracle, Demetria", 60, 6148),
            },
        },
        questTheme  = "Cult of the Forgotten Shadow",
        companion   = nil,
        pet         = nil,
        mount       = nil,
        gameplay    = nil,
    },

    ["Witch Doctor_PRIEST"] = {
        class       = "PRIEST",
        spec        = "Melee-weaving Mind Flayer",
        name        = "Witch Doctor",
        races       = { "Troll" },
        gender      = "Any gender",
        selfFound   = true,
        professions = { "Alchemy", "Cooking", "Fishing" },
        equipment   = {
            E("No robes", 1),
            E("Herb pouch", 10),
            E("Fishing pole", 44),
            E("Voodoo mask", 45),
            E("120 attack power", 50),
        },
        challenges  = {
            E("Voodoo Ritual", 50),
        },
        optionalChallenges = {
            E("Scavenger", 1),
            E("Self-made", 1),
            E("Nocturnal", 1),
        },
        quests      = {
            Q("A Recipe For Death", 18, 451),
            Q("Catch of the Day", 37, 5386),
            Q("Deadmire", 42, 1205),
            Q("The Swamp Talker", 45, 2623),
            Q("Tiara of the Deep", 46, 2846),
            Q("Shadowshard Fragments", 42, 7068),
            Q("Snapjaws, Mon!", 44, 7815),
            Q("A Grim Discovery", 45, 2976),
            Q("Bone-Bladed Weapons", 51, 4300),
            Q("Job Opening: Guard Captain of Revantusk Village", 52, 7862),
        },
        questGroups = {
            { theme = "Swamp Witch", count = 5 },
            { theme = "Building Attack Power", count = 5 },
        },
        questTheme  = nil,
        companion   = E("Frog", 30),
        pet         = nil,
        mount       = nil,
        gameplay    = "Melee weaving caster 1, pole weaving",
    },

    ["Shadow Hunter_PRIEST"] = {
        class       = "PRIEST",
        spec        = "Hybrid",
        name        = "Shadow Hunter",
        races       = { "Troll" },
        gender      = "Any gender",
        selfFound   = true,
        professions = {},
        equipment   = {
            E("No wands", 1),
            E("No robes", 1),
            E("Shadow Hunter knife", 35),
            E("Voodoo mask", 45),
        },
        challenges  = {
            E("Faction Loyalist", 1),
            E("Avenger", 60),
        },
        optionalChallenges = {
            E("Partisan", 1),
            E("Self-made", 1),
            E("Nocturnal", 1),
        },
        quests      = {
            Q("Zalazane", 10, 826),
            Q("Troll Charm", 24, 6462),
            Q("Trol'kalar", 42, 646),
            Q("Saving Yenniku", 46, 592),
        },
        questTheme = "Darkspear Loyalist",
        questTheme  = nil,
        companion   = nil,
        pet         = nil,
        mount       = nil,
        gameplay    = nil,
    },

    ["Priestess of the Moon_PRIEST"] = {
        class       = "PRIEST",
        spec        = "Spirit",
        name        = "Priestess of the Moon",
        races       = { "Night Elf" },
        gender      = "Female",
        selfFound   = true,
        professions = {},
        equipment   = {
            E("Robe", 1),
            E("Arcane wand", 13),
            E("180 spirit", 40),
            E("250 spirit", 50),
        },
        questsByHomebound = { 
            default = {
                Q("Sathrah's Sacrifice", 12, 2520),
                Q("Answered Questions", 30, 1044),
                Q("Rise of the Silithid", 46, 4267),
                Q("The Mystery of Morrowgrain", 50, 3791),
                Q("Prayer to Elune", 50, 3378),
                Q("Wildkin of Elune", 57, 4902),
                Q("The Treasure of the Shen'dralar", 60, 7877),
            },
            homebound = {
                Q("Sathrah's Sacrifice", 12, 2520),
                Q("Raene's Cleansing", 30, 1046),
                Q("Rise of the Silithid", 46, 4267),
                Q("The Mystery of Morrowgrain", 50, 3791),
                Q("Ancient Spirit", 56, 4261),
                Q("The Treasure of the Shen'dralar", 60, 7877),
            },
        },
        questTheme  = "Darnassus Loyalist",
        challenges  = {
            E("Faction Loyalist", 1),
            E("Light of Elune", 1),
        },
        optionalChallenges = {
            E("Partisan", 1),
            E("Homebound", 1),
            E("Self-made", 1),
        },
        companion   = nil,
        pet         = nil,
        mount       = E("Frostsaber", 44),
        gameplay    = "Spirit tap + starshards",
    },

    ---------- HUNTER ----------

    ["Shadow Hunter_HUNTER"] = {
        class       = "HUNTER",
        spec        = "Spell Power",
        name        = "Shadow Hunter",
        races       = { "Troll" },
        gender      = "Any gender",
        selfFound   = true,
        professions = {},
        recommendedProfession = {
            name = "Tailoring",
            reason = "A high level of Tailoring is required to craft items that give spell power, including the Dreamweave gloves and vest.",
        },
        equipment   = {
            E("Bow", 1),
            E("25 spell power", 35),
            E("Voodoo vest", 45),
            E("Voodoo gloves", 45),
            E("Voodoo mask", 45),
            E("50 spell power", 45),
            E("Voodoo shoulders", 50),
            E("100 spell power", 55),
        },
        challenges  = {
            E("Faction Loyalist", 1),
            E("Avenger", 60),
        },
        optionalChallenges = {
            E("Partisan", 1),
            E("Self-made", 1),
            E("Nocturnal", 1),
            E("Mortal pets", 1),
        },
        quests      = {
            Q("Zalazane", 10, 826),
            Q("Troll Charm", 24, 6462),
            Q("Trol'kalar", 42, 646),
            Q("Saving Yenniku", 46, 592),
        },
        questTheme = "Darkspear Loyalist",
        questTheme  = nil,
        companion   = nil,
        pet         = E("Panther", 30),
        mount       = nil,
        gameplay    = nil,
    },

    ["Wilderness Stalker_HUNTER"] = {
        class       = "HUNTER",
        spec        = "Melee",
        name        = "Wilderness Stalker",
        races       = { "Troll" },
        gender      = "Any gender",
        selfFound   = true,
        professions = {},
        weaponProficiency = { E("Thrown", 10) },
        equipment   = {
            E("Thrown", 10),
            E("Dual axes", 20),
        },
        challenges  = {
            E("Drifter", 1),
            E("Explorer", 1),
            E("Tame Bloodaxe Worg", 56),
        },
        optionalChallenges = {
            E("Partisan", 1),
            E("Self-made", 1),
            E("Cloth/leather", 1),
        },
        questsByHomebound = { 
            default = {
                Q("Zalazane", 10, 826),
                Q("Troll Charm", 24, 6462),
                Q("Other Fish to Fry", 36, 6143),
                Q("Trol'kalar", 42, 646),
                Q("Saving Yenniku", 46, 592),
            },
            homebound = {
                Q("Zalazane", 10, 826),
                Q("Troll Charm", 24, 6462),
                Q("Other Fish to Fry", 36, 6143),
                Q("Weapons of Spirit", 50, 3129),
            },
        },
        questTheme = "Darkspear Loyalist",
        companion   = nil,
        pet         = E("Wolf", 11),
        mount       = nil,
        gameplay    = "wing clip axe",
    },

    ["Priestess of the Moon_HUNTER"] = {
        class       = "HUNTER",
        spec        = "Spell Power",
        name        = "Priestess of the Moon",
        races       = { "Night Elf" },
        gender      = "Female",
        selfFound   = true,
        professions = {},
        recommendedProfession = {
            name = "Tailoring",
            reason = "A high level of Tailoring is required to craft items that give spell power, including the Dreamweave gloves and vest.",
        },
        equipment   = {
            E("25 spell power", 35),
            E("Dreamweave vest", 45),
            E("Dreamweave gloves", 45),
            E("50 spell power", 45),
            E("Dreamweave circlet", 50),
            E("100 spell power", 55),
        },
        challenges  = {
            E("Faction Loyalist", 1),
        },
        optionalChallenges = {
            E("Partisan", 1),
            E("Self-made", 1),
            E("Cloth", 1),
            E("Mortal pets", 1),
        },
        questsByHomebound = { 
            default = {
                Q("Sathrah's Sacrifice", 12, 2520),
                Q("Answered Questions", 30, 1044),
                Q("Rise of the Silithid", 46, 4267),
                Q("The Mystery of Morrowgrain", 50, 3791),
                Q("Wildkin of Elune", 57, 4902),
                Q("The Treasure of the Shen'dralar", 60, 7877),
            },
            homebound = {
                Q("Sathrah's Sacrifice", 12, 2520),
                Q("Raene's Cleansing", 30, 1046),
                Q("Rise of the Silithid", 46, 4267),
                Q("The Mystery of Morrowgrain", 50, 3791),
                Q("Ancient Spirit", 56, 4261),
                Q("The Treasure of the Shen'dralar", 60, 7877),
            },
        },
        questTheme  = "Darnassus Loyalist",
        companion   = nil,
        pet         = E("Frostsaber", 11),
        mount       = E("Frostsaber", 44),
        gameplay    = nil,
    },

    ["Elven Ranger_HUNTER"] = {
        class       = "HUNTER",
        spec        = "Lone Wolf",
        name        = "Elven Ranger",
        races       = { "Night Elf" },
        gender      = "Any gender",
        selfFound   = true,
        professions = {},
        recommendedProfession = {
            name = "Tailoring",
            reason = "A modest level of Tailoring is required to craft the Azure Silk Hood (125 Tailoring).",
        },
        challenges  = {
            E("Lone Wolf", 1),
            E("Faction Loyalist", 1),
        },
        optionalChallenges = {
            E("Scout", 1),
            E("Partisan", 1),
            E("Expeditionary", 1),
            E("Cloth/leather", 1),
        },
        equipment   = {
            E("Bow", 1),
            E("Dual swords", 20),
            E("Elven hood", 28),
            E("Elven cape", 30),
        },
        quests      = {
            Q("Sathrah's Sacrifice", 12, 2520),
            Q("Answered Questions", 30, 1044),
            Q("Rise of the Silithid", 46, 4267),
            Q("The Mystery of Morrowgrain", 50, 3791),
            Q("Wildkin of Elune", 57, 4902),
            Q("The Treasure of the Shen'dralar", 60, 7877),
        },
        questTheme  = "Darnassus Loyalist",
        companion   = nil,
        pet         = nil,
        mount       = nil,
        gameplay    = nil,
    },

    ["Mountaineer_HUNTER"] = {
        class       = "HUNTER",
        spec        = "Marksmanship",
        name        = "Mountaineer",
        races       = { "Dwarf" },
        gender      = "Any gender",
        selfFound   = true,
        professions = { "Engineering" },
        equipment   = {
            E("Gun", 1),
            E("2h axe", 10),
            E("Scope", 15),
            E("Mountaineer cape", 40),
            E("Mountaineer hood", 50),
        },
        challenges  = {
            E("Self-made guns", 10),
        },
        optionalChallenges = {
            E("Scout", 1),
            E("Partisan", 1),
            E("Explorer", 1),
            E("Mortal pets", 1),
        },
        quests      = {
            Q("In Defense of the King's Lands", 17, 217),
            Q("The Absent Minded Prospector", 24, 943),
            Q("Defeat Nek'rosh", 32, 474),
            Q("The Lost Tablets of Will", 45, 1139),
            Q("Rise, Obsidion!", 52, 3566),
            Q("The Princess's Surprise", 59, 4363),
        },
        questTheme  = "Ironforge Loyalist",
        companion   = nil,
        pet         = E("Bear", 11),
        mount       = nil,
        gameplay    = nil,
    },

    ["Brave_HUNTER"] = {
        class       = "HUNTER",
        spec        = "Melee",
        name        = "Brave",
        races       = { "Tauren" },
        gender      = "Any gender",
        selfFound   = true,
        professions = {},
        equipment   = {
            E("No shirt", 1),
            E("No ranged weapons", 2),
            E("War harness", 10),
            E("Polearm", 20),
        },
        challenges  = {
            E("Faction Loyalist", 1),
        },
        optionalChallenges = {
            E("Scout", 1),
            E("Partisan", 1),
            E("Mortal pets", 1),
        },
        questsByHomebound = { 
            default = {
                Q("Rites of the Earthmother", 14, 776),
                Q("Earthen Arise", 20, 6481),
                Q("Grimtotem Spying", 28, 5064),
                Q("Final Passage", 36, 1394),
                Q("Zukk'ash Report", 48, 7732),
                Q("Glyphed Oaken Branch", 56, 4987),
            },
            homebound = {
                Q("Rites of the Earthmother", 14, 776),
                Q("Earthen Arise", 20, 6481),
                Q("Grimtotem Spying", 28, 5064),
                Q("Zukk'ash Report", 48, 7732),
                Q("Morrowgrain Research", 50, 3786),
                Q("Past Endeavors", 59, 5057),
            },
        },
        questTheme  = "Thunderbluff Loyalist",
        companion   = nil,
        pet         = E("Tallstrider", 11),
        mount       = nil,
        gameplay    = "wing clip polearm",
    },

    ["Buccaneer_HUNTER"] = {
        class       = "HUNTER",
        spec        = "Survival",
        name        = "Buccaneer",
        races       = { "Tauren", "Orc", "Dwarf" },
        gender      = "Any gender",
        selfFound   = true,
        professions = { "Fishing" },
        recommendedProfession = {
            name = "Tailoring",
            reason = "Needed to craft Captain's Hat, which requires 240 Tailoring.",
        },
        equipment   = {
            E("Gun", 10),
            E("Pirate shirt", 20),
            E("Torch", 24),
            E("Rapier", 32),
            E("Pirate belt", 40),
            E("Captain's hat", 45),
        },
        challenges  = {
            E("Explorer", 1),
            E("Seeking a Pardon", 10),
        },
        optionalChallenges = {
            E("Scout", 1),
            E("Scavenger", 1),
            E("Expeditionary", 1),
            E("Drifter", 1),
        },
        questsByFaction = {
            Alliance = {
                Q("Stolen Booty", 16, 888),
                Q("Deep Ocean, Vast Sea", 17, 982),
                Q("Trouble at the Docks", 19, 959),
                Q("The Cursed Crew", 29, 289),
                Q("Claim Rackmore's Treasure!", 36, 6161),
                Q("Pearl Diving", 37, 705),
                Q("Deep Sea Salvage", 40, 662),
                Q("Cuergo's Gold", 45, 2882),
                Q("Whiskey Slim's Lost Grog", 50, 580),
            },
            Horde = {
                Q("From The Wreckage....", 8, 825),
                Q("Stolen Booty", 16, 888),
                Q("Trouble at the Docks", 19, 959),
                Q("Claim Rackmore's Treasure!", 36, 6161),
                Q("Catch of the Day", 37, 5386),
                Q("Pearl Diving", 37, 705),
                Q("Deep Sea Salvage", 40, 662),
                Q("Cuergo's Gold", 45, 2882),
                Q("Whiskey Slim's Lost Grog", 50, 580),
            },
        },
        questTheme  = "Treasure Hunter",
        companion   = E("Parrot", 16),
        pet         = E("Aquatic", 14),
        mount       = nil,
        gameplay    = "Rum",
    },

    ["Beastmaster_HUNTER"] = {
        class       = "HUNTER",
        spec        = "Beast Mastery",
        name        = "Beastmaster",
        races       = { "Orc", "Tauren", "Night Elf", "Troll" },
        gender      = "Any gender",
        selfFound   = true,
        professions = { "Leatherworking" },
        equipmentByFaction = {
            Alliance = {
                E("No guns", 1),
                E("Beastslaying chest", 26),
                E("Beastslaying gloves", 30),
                E("Beastslaying melee weapon", 35),
                E("Wolf helm", 45),
                E("Beastslaying ranged weapon", 50), 
            },
            Horde = {
                E("No guns", 1),
                E("Beastslaying cloak", 20),
                E("Beastslaying gloves", 30),
                E("Beastslaying melee weapon", 35),
                E("Wolf helm", 45),
                E("Beastslaying ranged weapon", 50),
            },
        },
        challenges  = {
            E("Mortal pets", 1),
            E("Tame Son of Hakkar", 60),
        },
        optionalChallenges = {
            E("Scout", 1),
            E("Scavenger", 1),
            E("Expeditionary", 1),
            E("Insular", 1),
        },
        questsByFaction = {
            Alliance = {
                Q("Vyrin's Revenge", 20, 531),
                Q("Big Game Hunter", 43, 208),
                Q("Message in a Bottle", 51, 630),
                Q("The Bait for Lar'korwi", 56, 4292),
                Q("Wanted - Deathclasp, Terror of the Sands", 59, 8283),
            },
            Horde = {
                Q("Isha Awak", 27, 873),
                Q("Big Game Hunter", 43, 208),
                Q("Message in a Bottle", 51, 630),
                Q("The Bait for Lar'korwi", 56, 4292),
                Q("Past Endeavors", 59, 5057),
            },
        },
        questTheme  = "Big Game Hunter",
        companion   = E("Any companion", 10),
        pet         = nil,
        mount       = nil,
        gameplay    = "Rare pets",
    },

    ---------- MAGE ----------

    ["Techno-mage_MAGE"] = {
        class       = "MAGE",
        spec        = "Presence of Mind",
        name        = "Techno-mage",
        races       = { "Gnome" },
        gender      = "Any gender",
        selfFound   = true,
        professions = { "Engineering" },
        equipment   = {
            E("Beginner goggles", 20, 29),
            E("Intermediate goggles", 30, 39),
            E("Engineering trinkets", 35),
            E("Discombobulator ray", 35),
            E("Advanced goggles", 40),
            E("Engineer off-hand", 48),
        },
        challenges  = {
            E("Gnomish Justice", 45),
        },
        optionalChallenges = {
            E("Scavenger", 1),
            E("Expeditionary", 1),
            E("Homebound", 1),
        },
        questsByHomebound = { 
            default = {
                Q("Bingles' Missing Supplies", 15, 2038),
                Q("A Dark Threat Looms", 20, 283),
                Q("Data Rescue", 30, 2930),
                Q("Show Your Work", 47, 3641),
                Q("An OOX of Your Own", 50, 3721),
            },
            homebound = {
                Q("Bingles' Missing Supplies", 15, 2038),
                Q("A Dark Threat Looms", 20, 283),
                Q("Data Rescue", 30, 2930),
                Q("Gnome Improvement", 35, 2948),
                Q("Show Your Work", 47, 3641),
            },
        },
        questTheme  = "Gadgetist",
        companion   = E("Mechanical", 45),
        pet         = nil,
        mount       = nil,
        gameplay    = "Pyroblast + arcane missile",
    },

    ["Kirin Tor Mage_MAGE"] = {
        class       = "MAGE",
        spec        = "Frostfire",
        name        = "Kirin Tor Mage",
        races       = { "Gnome", "Human" },
        gender      = "Any gender",
        selfFound   = false,
        professions = { "Enchanting" },
        equipment   = {
            E("Staff", 1),
            E("Kirin Tor robes", 20),
            E("Kirin Tor shoulders", 34),
            E("Kirin Tor cape", 52),
            E("Kirin Tor circlet", 52),
        },
        challenges  = {},
        optionalChallenges = {
            E("Exotic", 1),
            E("Partisan", 1),
        },
        quests      = {
            Q("Investigate the Blue Recluse", 16, 1920),
            Q("Ur's Treatise on Shadow Magic", 28, 1938),
            Q("The Curse of the Tides", 40, 611),
            Q("Mage's Wand", 40, 1952),
            Q("Celestial Power", 40, 1958),
            Q("Destroy Morphaz", 52, 8253),
            Q("Arcane Refreshment", 60, 7463),
        },
        questTheme  = "Formal Education",
        companion   = nil,
        pet         = nil,
        mount       = nil,
        gameplay    = "kirin tor trade",
    },

    ["Hedge Wizard_MAGE"] = {
        class       = "MAGE",
        spec        = "Scorch",
        name        = "Hedge Wizard",
        races       = { "Troll" },
        gender      = "Any gender",
        selfFound   = true,
        professions = {},
        equipment   = {
            E("Fire wand", 15),
        },
        challenges  = {
            E("Self-taught", 1),
        },
        optionalChallenges = {
            E("Scout", 1),
            E("Scavenger", 1),
            E("Self-made", 1),
        },
        quests      = {
            Q("The Weaver", 22, 480),
            Q("Dalaran Patrols", 35, 545),
            Q("Fragmented Magic", 60, 9364),
            Q("Arcane Refreshment", 60, 7463),
        },
        questTheme  = "Seeking Education",
        companion   = E("Crimson snake", 10),
        pet         = nil,
        mount       = nil,
        gameplay    = nil,
    },

    ["Ley Walker_MAGE"] = {
        class       = "MAGE",
        spec        = "Presence of Mind",
        name        = "Ley Walker",
        races       = { "Human" },
        gender      = "Any gender",
        selfFound   = true,
        professions = { "Enchanting" },
        recommendedProfession = {
            name = "Tailoring",
            reason = "High level of Tailoring is required to craft the Robe of Power.",
        },
        equipment   = {
            E("Staff", 1),
            E("Arcane wand", 13),
            E("Robe of power", 45),
        },
        challenges  = {
            E("Explorer", 1),
            E("Drifter", 1),
            E("Keeper", 60),
        },
        optionalChallenges = {
            E("Exotic", 1),
            E("Scavenger", 1),
            E("Self-made", 1),
        },
        questsByFaction = {
            Alliance = {
                Q("Cleansing of the Infected", 16, 2138),
                Q("The Escape", 18, 863),
                Q("Keeper of the Flame", 20, 103),
                Q("Gerenzo Wrenchwhistle", 27, 1096),
                Q("Hostile Takeover", 36, 213),
                Q("Venture Company Mining", 41, 600),
                Q("Verifying the Corruption", 54, 5156),
                Q("Arcane Runes", 52, 3449),
                Q("Cleansing Felwood", 55, 4101),
            },
            Horde = {
                Q("The Venture Co.", 10, 764),
                Q("Keeper of the Flame", 20, 103),
                Q("The Weaver", 22, 480),
                Q("Revenge of Gann", 26, 849),
                Q("Gerenzo Wrenchwhistle", 27, 1096),
                Q("Hostile Takeover", 36, 213),
                Q("Venture Company Mining", 41, 600),
                Q("Summoning the Princess", 50, 656),
                Q("Cleansing Felwood", 55, 4102),
            },
        },
        questTheme  = "Naturalist Scribe",
        companion   = nil,
        pet         = nil,
        mount       = nil,
        gameplay    = "Self-made enchants, scrolls, pro-nature, Pyroblast + arcane missile",
    },

    ["Spellblade_MAGE"] = {
        class       = "MAGE",
        spec        = "Aoe-grinder",
        name        = "Spellblade",
        races       = { "Troll", "Undead", "Human" },
        gender      = "Any gender",
        selfFound   = true,
        professions = {},
        equipmentByFaction = {
            Alliance = {
                E("No robes", 1),
                E("Warmage blade", 10),
                E("Armored off-hand", 20),
                E("Frost wand", 35),
                E("Armored ring", 45),
            },
            Horde = {
                E("No robes", 1),
                E("Sword", 10),
                E("Staff-like off-hand", 35),
                E("Frost wand", 35),
                E("Armored ring", 45),             
            },
        },
        challenges  = {
            E("Cryomancer", 1),
        },
        optionalChallenges = {
            E("Scout", 1),
            E("Scavenger", 1),
            E("Self-made", 1),
        },
        questsByFaction = {
            Alliance = {
                Q("Tramping Paws", 21, 276),
                Q("The Night Watch", 26, 57),
                Q("Worgen in the Woods", 31, 222),
                Q("Syndicate Assassins", 33, 505),
                Q("Hints of a New Plague?", 37, 661),
                Q("Clear the Way", 52, 5092),
            },
            Horde = {
                Q("Souvenirs of Death", 25, 546),
                Q("Battle of Hillsbrad", 32, 550),
                Q("To Steal From Thieves", 36, 1164),
                Q("Into The Scarlet Monastery", 42, 1048),
                Q("Continued Threat", 45, 1428),
                Q("Melding of Influences", 55, 4642),
            },
        },
        questTheme  = "Crowd Control",
        companion   = nil,
        pet         = nil,
        mount       = nil,
        gameplay    = "Aoe-farmer",
    },

    ["Bloodmage_MAGE"] = {
        class       = "MAGE",
        spec        = "Pyromancer",
        name        = "Bloodmage",
        races       = { "Undead" },
        gender      = "Any gender",
        selfFound   = false,
        professions = { "Enchanting" },
        equipment   = {
            E("Shadow or fire wand", 15),
            E("Unholy weapon", 55),
        },
        challenges  = {
            E("Pyromancer", 1),
        },
        optionalChallenges = {
            E("Exotic", 1),
            E("Scavenger", 1),
            E("Homebound", 1),
            E("Self-made", 1),
        },
        questsByHomebound = { 
            default = {
                Q("The Guns of Northwatch", 20, 891),
                Q("Free From the Hold", 20, 898),
                Q("The Den", 29, 1089),
                Q("Ripple Delivery", 48, 81),
                Q("Xylem's Payment to Jediga", 52, 3565),
                Q("Alas, Andorhal", 60, 105),
                Q("The Lich, Ras Frostwhisper", 60, 5466),
            },
            homebound = {
                Q("The Family Crypt", 13, 408),
                Q("Assault on Fenris Isle", 24, 442),
                Q("A Boar's Vitality", 50, 2583),
                Q("Snickerfang Jowls", 50, 2581),
                Q("The Decisive Striker", 50, 2585),
                Q("Alas, Andorhal", 60, 105),
                Q("The Lich, Ras Frostwhisper", 60, 5466),
            },
        },
        questTheme  = "For Quel'Thalas!",
        companion   = E("Phoenix", 10),
        pet         = nil,
        mount       = nil,
        gameplay    = "Self-made enchants, phoenix trade",
    },

    ---------- WARLOCK ----------

    ["Necromancer_WARLOCK"] = {
        class       = "WARLOCK",
        spec        = "Drain Life",
        name        = "Necromancer",
        races       = { "Gnome", "Human", "Orc" },
        gender      = "Any gender",
        selfFoundByFaction = {
            Alliance = true,
            Horde    = false,
        },
        professions = {},
        challenges  = {
            E("No demons", 1),
            E("Cult of the Damned", 60),
        },
        optionalChallenges = {
            E("Exotic", 1),
            E("Scavenger", 1),
            E("Expeditionary", 1),
        },
        equipment   = {  
            E("Dark robe", 8),
            E("Shadow wand", 15),
            E("Necromancer hat", 30),
            E("Skull off-hand", 30, 59),
            E("Necromancer robe", 36),
            E("Book of necromancy", 60),
        },
        questsByFaction = {
            Alliance = {
                Q("Knowledge in the Deeps", 25, 971),
                Q("A Noble Brew", 30, 336),
                Q("The Star, the Hand and the Heart", 44, 735),
                Q("Twisted Evils", 47, 7028),
                Q("The God Hakkar", 53, 3528),
            },
            Horde = {
                Q("The Book of Ur", 26, 1013),
                Q("The Star, the Hand and the Heart", 44, 736),
                Q("Twisted Evils", 47, 7028),
                Q("The God Hakkar", 53, 3528),
                Q("Helcular's Revenge", 55, 553),
            },
        },
        questTheme  = "Nihilist",
        companion   = E("Cat", 20),
        pet         = nil,
        mount       = nil,
        gameplay    = "argent war",
    },
    --[[
    ["Harvest Witch_WARLOCK"] = {
        class       = "WARLOCK",
        spec        = "Drain Life",
        name        = "Harvest Witch",
        races       = { "Human" },
        gender      = "Any gender",
        selfFoundByFaction = {
            Alliance = true,
            Horde    = true,
        },
        professions = { "Herbalism" },
        challenges  = {
            E("No demons", 1),
        },
        optionalChallenges = {
            E("Exotic", 1),
            E("Scavenger", 1),
            E("Expeditionary", 1),
        },
        equipment   = {
            E("Harvest Witch staff", 8),
            E("Herb pouch", 10),
            E("Harvest Witch robe", 14),
            E("Nature wand", 30),
            E("Harvest Witch hood", 34),
            E("Soul Harvester", 50),
        },
        quests = {
            Q("Milly's Harvest", 4, 3904),
            Q("An Unwelcome Guest", 24, 34),
            Q("The Star, the Hand and the Heart", 44, 735),
            Q("Twisted Evils", 47, 7028),
            Q("The God Hakkar", 53, 3528),
        },
        questTheme  = "Harvester",
        companion   = E("Cat", 10),
        pet         = nil,
        mount       = nil,
        gameplay    = nil,
    },
    --]]

    ["Twilight Cultist_WARLOCK"] = {
        class       = "WARLOCK",
        spec        = "DS/Ruin",
        name        = "Twilight Cultist",
        races       = { "Gnome", "Human", "Undead", "Orc" },
        gender      = "Any gender",
        selfFound   = true,
        professions = {},
        equipment   = {
            E("Dark robe", 8),
            E("Shadow wand", 15),
            E("Cultist shoulders", 60),
            E("Cultist cowl", 60),
            E("Cultist robe", 60),
        },
        challenges  = {
            E("Drifter", 1),
            E("Voidwalker", 10, 29),
            E("Twilight's Hammer", 60),
        },
        optionalChallenges = {
            E("Exotic", 1),
            E("Scavenger", 1),
            E("Expeditionary", 1),
        },
        questsByFaction = {
            Alliance = {
                Q("Knowledge in the Deeps", 25, 971),
                Q("A Noble Brew", 30, 336),
                Q("The Star, the Hand and the Heart", 44, 735),
                Q("Twisted Evils", 47, 7028),
                Q("The God Hakkar", 53, 3528),
            },
            Horde = {
                Q("The Book of Ur", 26, 1013),
                Q("The Star, the Hand and the Heart", 44, 736),
                Q("Twisted Evils", 47, 7028),
                Q("The God Hakkar", 53, 3528),
                Q("Helcular's Revenge", 55, 553),
            },
        },
        questTheme  = "Nihilist",
        companion   = nil,
        pet         = nil,
        mount       = nil,
        gameplay    = "cenarion war",
    },

    ["Pyremaster_WARLOCK"] = {
        class       = "WARLOCK",
        spec        = "Melee-weaving Fire",
        name        = "Pyremaster",
        races       = { "Orc" },
        gender      = "Any gender",
        selfFound   = true,
        professions = {},
        recommendedProfession = {
            name = "Cooking",
            reason = "Need advanced cooking skills to make Dragonbreath Chili.",
        },
        challenges  = {
            E("Imp", 1),
        },
        optionalChallenges = {
            E("Exotic", 1),
            E("Partisan", 1),
            E("Homebound", 1),
            E("Self-made", 1),
        },
        equipment   = {
            E("No wands", 1),
            E("Dark robe", 8),
            E("Flint and tinder", 10),
            E("Fast dagger", 15),
            E("Firestone", 28),
            E("Dragonbreath chili", 40),
        },
        questsByHomebound = { 
            default = {
                Q("Keeper of the Flame", 21, 103),
                Q("Dangerous!", 28, 567),
                Q("The Sacred Flame", 29, 1197),
                Q("Rig Wars", 35, 2841),
                Q("Extinguishing the Idol", 37, 3525),
                Q("Volcanic Activity", 55, 4502),
                Q("A Taste of Flame", 58, 4024),
            },
            homebound = {
                Q("The Demon Seed", 14, 924),
                Q("Hidden Enemies", 16, 5730),
                Q("The Corrupter", 37, 1488),
                Q("The Sacred Flame", 29, 1197),
                Q("Extinguishing the Idol", 37, 3525),
                Q("Volcanic Activity", 55, 4502),
            },
        },
        questTheme  = "Fiery Garments & Rituals",
        companion   = nil,
        pet         = nil,
        mount       = E("Wolf", 44),
        gameplay    = "Campfire, melee weaving dagger, dragonbreath, melee weaving dagger 2",
    },

    ["Dark Rider_WARLOCK"] = {
        class       = "WARLOCK",
        spec        = "Soul Link",
        name        = "Dark Rider",
        races       = { "Undead" },
        gender      = "Any gender",
        selfFound   = true,
        professions = {},
        challenges  = {
            E("Voidwalker", 10),
            E("Shadow Council", 60),
        },
        optionalChallenges = {
            E("Expeditionary", 1),
            E("Drifter", 1),
            E("Nocturnal", 1),
        },
        equipment   = {
            E("No wands", 1),
            E("Sword", 12, 33),
            E("Armored weapon/off-hand", 34),
            E("140 stamina", 40),
            E("Armored rings", 45),
            E("Armored trinket", 45),
            E("180 stamina", 50),
        },
        quests = {
            Q("The Book of Ur", 26, 1013),
            Q("The Star, the Hand and the Heart", 44, 736),
            Q("Set Them Ablaze!", 52, 3463),
            Q("Helcular's Revenge", 55, 553),
            Q("A Taste of Flame", 58, 4024),
        },
        questTheme  = "Serving the Shadow Council",
        companion   = nil,
        pet         = nil,
        mount       = E("Skeletal horse", 44),
        gameplay    = "tank, sacrifice, cenarion war",
    },

    ["Bloodmage_WARLOCK"] = {
        class       = "WARLOCK",
        spec        = "Fire Destruction",
        name        = "Bloodmage",
        races       = { "Undead" },
        gender      = "Any gender",
        selfFound   = false,
        professions = { "Enchanting" },
        equipment   = {
            E("Shadow or fire wand", 15),
            E("Unholy weapon", 55),
        },
        challenges  = {
            E("Imp", 1),
            E("Firemancer", 1),
        },
        optionalChallenges = {
            E("Exotic", 1),
            E("Scavenger", 1),
            E("Homebound", 1),
            E("Self-made", 1),
        },
        questsByHomebound = { 
            default = {
                Q("The Guns of Northwatch", 20, 891),
                Q("Free From the Hold", 20, 898),
                Q("The Den", 29, 1089),
                Q("Ripple Delivery", 48, 81),
                Q("Xylem's Payment to Jediga", 52, 3565),
            },
            homebound = {
                Q("The Family Crypt", 13, 408),
                Q("Assault on Fenris Isle", 24, 442),
                Q("A Boar's Vitality", 50, 2583),
                Q("Snickerfang Jowls", 50, 2581),
                Q("The Decisive Striker", 50, 2585),
                Q("Vulture's Vigor", 50, 2603),
                Q("The Basilisk's Bite", 50, 2601),
            },
        },
        questTheme  = "For Quel'Thalas!",
        companion   = E("Phoenix", 10),
        pet         = nil,
        mount       = nil,
        gameplay    = "Self-made enchants",
    },


    ---------- DRUID ----------

    ["Savagekin_DRUID"] = {
        class       = "DRUID",
        spec        = "Moonkin",
        name        = "Savagekin",
        races       = { "Night Elf", "Tauren" },
        gender      = "Any gender",
        selfFound   = true,
        professions = {},
        equipment   = {
            E("80 strength", 30),
            E("125 intellect", 40),
            E("Armored ring", 45),
            E("200 intellect", 50),
        },
        challenges  = {
            E("Drifter", 1),
            E("Savagery", 11),
        },
        optionalChallenges = {
            E("Homebound", 1),
            E("Leather", 1),
            E("Nocturnal", 1),
            E("Insular", 1),
        },
        questsByFaction = {
            Alliance = {
                default = {
                    Q("Cleansing of the Infected", 16, 2138),
                    Q("The Escape", 18, 863),
                    Q("Insane Druids", 32, 1012),
                    Q("Hostile Takeover", 36, 213),
                    Q("Venture Company Mining", 41, 600),
                    Q("Rise of the Silithid", 49, 162),
                    Q("Verifying the Corruption", 54, 5156),
                    Q("Cleansing Felwood", 55, 4101),
                }, 
                homebound = {
                    Q("Cleansing of the Infected", 16, 2138),
                    Q("The Escape", 18, 863),
                    Q("Gerenzo Wrenchwhistle", 27, 1096),
                    Q("Insane Druids", 32, 1012),
                    Q("Rise of the Silithid", 49, 162),
                    Q("Verifying the Corruption", 54, 5156),
                    Q("Cleansing Felwood", 55, 4101),
                },
            },
            Horde = {
                default = {
                    Q("The Venture Co.", 10, 764),
                    Q("Samophlange", 16, 902),
                    Q("Samophlange Manual", 19, 3924),
                    Q("Shredding Machines", 23, 1068),
                    Q("Gerenzo Wrenchwhistle", 27, 1096),
                    Q("Hostile Takeover", 36, 213),
                    Q("Venture Company Mining", 41, 600),
                }, 
                homebound = {
                    Q("The Venture Co.", 10, 764),
                    Q("Samophlange", 16, 902),
                    Q("Samophlange Manual", 19, 3924),
                    Q("Shredding Machines", 23, 1068),
                    Q("Gerenzo Wrenchwhistle", 27, 1096),
                    Q("Cleansing Felwood", 55, 4102),
                },
            },
        },
        questTheme  = "Naturalist",
        companion   = nil,
        pet         = nil,
        mount       = nil,
        gameplay    = "Pro-nature, savage",
    },

    ["Druid of the Claw_DRUID"] = {
        class       = "DRUID",
        spec        = "Bear",
        name        = "Druid of the Claw",
        races       = { "Night Elf" },
        gender      = "Any gender",
        selfFound   = true,
        professions = {},
        recommendedProfession = {
            name = "Alchemy",
            reason = "Needed to craft Elixir of Minor Fortitude (80 Alchemy) for Reception from Tyrande.",
        },
        challenges  = {
            E("Spirit of Ursol", 1),
        },
        optionalChallenges = {
            E("Drifter", 1),
            E("Partisan", 1),
            E("Expeditionary", 1),
        },
        equipment   = {
            E("Armored weapon/off-hand", 25),
            E("Armored rings", 45),
        },
        quests      = {
            Q("The Escape", 18, 863),
            Q("Gerenzo Wrenchwhistle", 27, 1096),
            Q("Reception from Tyrande", 28, 1081),
            Q("Hostile Takeover", 36, 213),
            Q("Venture Company Mining", 41, 600),
            Q("Cleansing Felwood", 55, 4101),
        },
        questTheme  = "Naturalist",
        companion   = nil,
        pet         = nil,
        mount       = nil,
        gameplay    = "/roar, pro-nature, tank tour",
    },

    ["Druid of the Talon_DRUID"] = {
        class       = "DRUID",
        spec        = "Melee Moonkin",
        name        = "Druid of the Talon",
        races       = { "Night Elf", "Tauren" },
        gender      = "Any gender",
        selfFound   = true,
        professions = {},
        equipment   = {
            E("Two-handed weapon", 5),
            E("150 attack power", 35),
            E("250 attack power", 45),
            E("400 attack power", 55),
        },
        challenges  = {
            E("Explorer", 1),
            E("Spirit of Aviana", 1),
        },
        optionalChallenges = {
            E("Leather", 1),
            E("Nocturnal", 1),
            E("Insular", 1),
            E("Drifter", 1),
        },
        questsByFaction = {
            Alliance = {
                default = {
                    Q("Cleansing of the Infected", 16, 2138),
                    Q("The Escape", 18, 863),
                    Q("Insane Druids", 32, 1012),
                    Q("Hostile Takeover", 36, 213),
                    Q("Venture Company Mining", 41, 600),
                    Q("Rise of the Silithid", 49, 162),
                    Q("Saving Sharpbeak", 51, 2994),
                    Q("Verifying the Corruption", 54, 5156),
                    Q("Cleansing Felwood", 55, 4101),
                    Q("Into The Maw of Madness", 59, 8306),
                }, 
                homebound = {
                    Q("Cleansing of the Infected", 16, 2138),
                    Q("The Escape", 18, 863),
                    Q("Gerenzo Wrenchwhistle", 27, 1096),
                    Q("Insane Druids", 32, 1012),
                    Q("Rise of the Silithid", 49, 162),
                    Q("Verifying the Corruption", 54, 5156),
                    Q("Into The Maw of Madness", 59, 8306),
                },
            },
            Horde = {
                default = {
                    Q("The Venture Co.", 10, 764),
                    Q("Samophlange", 16, 902),
                    Q("Samophlange Manual", 19, 3924),
                    Q("Shredding Machines", 23, 1068),
                    Q("Gerenzo Wrenchwhistle", 27, 1096),
                    Q("Hostile Takeover", 36, 213),
                    Q("Venture Company Mining", 41, 600),
                    Q("Cleansing Felwood", 55, 4101),
                    Q("Into The Maw of Madness", 59, 8306),
                }, 
                homebound = {
                    Q("The Venture Co.", 10, 764),
                    Q("Samophlange", 16, 902),
                    Q("Samophlange Manual", 19, 3924),
                    Q("Shredding Machines", 23, 1068),
                    Q("Gerenzo Wrenchwhistle", 27, 1096),
                    Q("Cleansing Felwood", 55, 4102),
                    Q("Into The Maw of Madness", 59, 8306),
                },
            },
        },
        questTheme  = "Naturalist",
        companion   = E("Bird", 10),
        pet         = nil,
        mount       = nil,
        gameplay    = "Pro-nature",
    },

    ["Druid of the Wild_DRUID"] = {
        class       = "DRUID",
        spec        = "Powershifting Hybrid",
        name        = "Druid of the Wild",
        races       = { "Night Elf", "Tauren" },
        gender      = "Any gender",
        selfFound   = true,
        professions = {},
        recommendedProfession = {
            name = "Leatherworking",
            reason = "Needed to craft Powershifting helm (Wolfshead Helm), which requires 225 Leatherworking.",
        },
        equipment   = {
            E("75 strength & intellect", 30),
            E("100 strength & intellect", 40),
            E("Powershifting helm", 45),
            E("150 strength & intellect", 50),
        },
        challenges = {
            E("Drifter", 1),
        },
        optionalChallenges = {
            E("Explorer", 1),
            E("Partisan", 1),
            E("Expeditionary", 1),
        },
        questsByFaction = {
            Alliance = {
                default = {
                    Q("Cleansing of the Infected", 16, 2138),
                    Q("The Escape", 18, 863),
                    Q("Insane Druids", 32, 1012),
                    Q("Hostile Takeover", 36, 213),
                    Q("Venture Company Mining", 41, 600),
                    Q("Rise of the Silithid", 49, 162),
                    Q("Verifying the Corruption", 54, 5156),
                    Q("Cleansing Felwood", 55, 4101),
                    Q("Shards of the Felvine", 60, 5526),
                }, 
                homebound = {
                    Q("Cleansing of the Infected", 16, 2138),
                    Q("The Escape", 18, 863),
                    Q("Gerenzo Wrenchwhistle", 27, 1096),
                    Q("Insane Druids", 32, 1012),
                    Q("Rise of the Silithid", 49, 162),
                    Q("Verifying the Corruption", 54, 5156),
                    Q("Cleansing Felwood", 55, 4101),
                    Q("Shards of the Felvine", 60, 5526),
                },
            },
            Horde = {
                default = {
                    Q("The Venture Co.", 10, 764),
                    Q("Samophlange", 16, 902),
                    Q("Shredding Machines", 23, 1068),
                    Q("Gerenzo Wrenchwhistle", 27, 1096),
                    Q("Hostile Takeover", 36, 213),
                    Q("Venture Company Mining", 41, 600),
                    Q("Poisoned Water", 56, 6804),
                    Q("Shards of the Felvine", 60, 5526),
                }, 
                homebound = {
                    Q("The Venture Co.", 10, 764),
                    Q("Samophlange", 16, 902),
                    Q("Samophlange Manual", 19, 3924),
                    Q("Shredding Machines", 23, 1068),
                    Q("Gerenzo Wrenchwhistle", 27, 1096),
                    Q("Cleansing Felwood", 55, 4102),
                    Q("Shards of the Felvine", 60, 5526),
                },
            },
        },
        questTheme  = "Naturalist",
        companion   = nil,
        pet         = nil,
        mount       = nil,
        gameplay    = "pro-nature, powershifting",
    },

    ["Plagueshifter_DRUID"] = {
        class       = "DRUID",
        spec        = "Restoration",
        name        = "Plagueshifter",
        races       = { "Tauren" },
        gender      = "Any gender",
        selfFound   = true,
        professions = {},
        equipment   = {
            E("Plagueshifter robes", 20),
            E("Plagueshifter shoulders", 30),
            E("Plagueshifter cloak", 40),
        },
        challenges  = {
            E("Disease Cleansing", 55),
            E("Purifier", 60),
        },
        optionalChallenges = {
            E("Partisan", 1),
            E("Expeditionary", 1),
            E("Self-made", 1),
            E("Cloth", 1),
        },
        quests      = {
            Q("The Family Crypt", 13, 408),
            Q("Assault on Fenris Isle", 24, 442),
            Q("The Swarm Grows", 35, 1147),
            Q("An Unholy Alliance", 36, 6521),
            Q("Ghost-o-plasm Round Up", 39, 6134),
            Q("Spiritual Unrest", 47, 5535),
            Q("Alien Ecology", 52, 3883),
            Q("Poisoned Water", 56, 6804),
            Q("Mission Accomplished!", 58, 5238),
            Q("The Argent Hold", 60, 5265),
        },
        questTheme  = "All Diseases Must be Purged!",
        companion   = nil,
        pet         = nil,
        mount       = nil,
        gameplay    = "Anti-undead",
    },

    ["Dragonsworn_DRUID"] = {
        class       = "DRUID",
        spec        = "Truecaster",
        name        = "Dragonsworn",
        races       = { "Night Elf" },
        gender      = "Any gender",
        selfFound   = true,
        professions = {},
        recommendedProfession = {
            name = "Alchemy, Tailoring",
            reason = "Craft the 2x Elixir of Fortitude required for Faerie Dragon pet, then switch to Tailoring to craft the Dreamweave set.",
        },
        challenges  = {
            E("Truecaster", 1),
            E("Keeper", 60),
        },
        optionalChallenges = {
            E("Exotic", 1),
            E("Self-made", 1),
            E("Cloth", 1),
        },
        equipment   = {
            E("Green shirt", 10),
            E("Dreamweave gloves", 45),
            E("Dreamweave vest", 45),
            E("Dreamweave kilt", 48),
            E("Dreamweave circlet", 50),
        },
        quests      = {
            Q("The Sleeper Has Awakened", 20, 5321),
            Q("In Nightmares", 25, 3370),
            Q("Satyr Slaying!", 32, 1032),
            Q("Extinguishing the Idol", 37, 3525),
            Q("Becoming a Parent", 48, 4298),
            Q("Further Corruption", 54, 4906),
            Q("In Eranikus' Own Words", 55, 3512),
        },
        questTheme  = "Serving the Green Dragonflight",
        companion   = E("Faerie dragon", 48),
        pet         = nil,
        mount       = nil,
        gameplay    = nil,
    },

    ---------- SHAMAN ----------

    ["Spirit Champion_SHAMAN"] = {
        class       = "SHAMAN",
        spec        = "2-handed Stormstrike",
        name        = "Spirit Champion",
        races       = { "Orc", "Tauren" },
        gender      = "Any gender",
        selfFound   = true,
        professions = {},
        equipment   = {
            E("No chest", 1),
            E("2h mace or axe", 20),
        },
        challenges  = {
            E("Windfury Weapon", 30),
        },
        optionalChallenges = {
            E("Exotic", 1),
            E("Partisan", 1),
            E("Expeditionary", 1),
        },
        quests      = {
            Q("Weapons of Choice", 24, 893),
            Q("Final Passage", 36, 1394),
            Q("Threat From the Sea", 43, 1427),
            Q("Mok'thardin's Enchantment", 44, 573),
            Q("Weapons of Spirit", 50, 3129),
            Q("The Perfect Poison", 60, 9023),
        },
        questTheme  = "Choose Your Weapon",
        companion   = nil,
        pet         = nil,
        mount       = nil,
        gameplay    = "/sit and /meditate",
    },

    ["Earthcaller_SHAMAN"] = {
        class       = "SHAMAN",
        spec        = '"Sword & Board"',
        name        = "Earthcaller",
        races       = { "Troll", "Tauren", "Orc" },
        gender      = "Any gender",
        selfFound   = true,
        professions = {},
        equipment   = {
            E("Shield", 5),
            E("1200 armor", 30),
            E("3000 armor", 50),
        },
        challenges  = {
            E("Rockbiter Weapon", 2),
        },
        optionalChallenges = {
            E("Exotic", 1),
            E("Expeditionary", 1),
            E("Self-made", 1),
        },
        quests      = {
            Q("Earthen Arise", 20, 6481),
            Q("A New Ore Sample", 29, 1153),
            Q("Test of Strength", 30, 1151),
            Q("Bracers of Binding", 34, 557),
            Q("Study of the Elements: Rock", 42, 712),
            Q("Summoning the Princess", 50, 656),
            Q("Corruption of Earth and Seed", 51, 7064),
            Q("Earthen Templar", 60, 8536),
        },
        questTheme  = "Earthbender",
        companion   = nil,
        pet         = nil,
        mount       = nil,
        gameplay    = "tank tour",
    },

    ["Farseer_SHAMAN"] = {
        class       = "SHAMAN",
        spec        = 'Elemental',
        name        = "Farseer",
        races       = { "Orc" },
        gender      = "Any gender",
        selfFound   = true,
        professions = {},
        equipment   = {
            E("Shield", 5),
            E("Fist weapon", 10, 42),
            E("Cowl", 25),
            E("Totem weapon", 43),
            E("Wolf helm", 45),
        },
        challenges  = {
            E("Faction Leader", 1),
        },
        optionalChallenges = {
            E("Exotic", 1),
            E("Expeditionary", 1),
            E("Self-made", 1),
        },
        quests      = {
            Q("Hidden Enemies", 16, 5730),
            Q("King of the Foulweald", 26, 6621),
            Q("The Corrupter", 37, 1488),
            Q("Service to the Horde", 40, 7541),
            Q("Continued Threat", 45, 1428),
            Q("The Princess Saved?", 59, 4004),
            Q("For The Horde!", 60, 4974),
        },
        questTheme  = "Orgrimmar Loyalist",
        companion   = nil,
        pet         = nil,
        mount       = E("Wolf", 44),
        gameplay    = nil,
    },

    ["Witch Doctor_SHAMAN"] = {
        class       = "SHAMAN",
        spec        = "Ward",
        name        = "Witch Doctor",
        races       = { "Troll" },
        gender      = "Any gender",
        selfFound   = true,
        professions = { "Alchemy" },
        equipment   = {
            E("Herb pouch", 10),
            E("Witch Doctor staff", 11),
            E("Voodoo mask", 45),
            E("Cursed amulet", 45),
        },
        challenges  = {
            E("Voodoo Ritual", 50),
        },
        optionalChallenges = {
            E("Expeditionary", 1),
            E("Cloth/leather", 1),
            E("Drifter", 1),
        },
        quests      = {
            Q("Troll Charm", 24, 6462),
            Q("Jin'Zil's Forest Magic", 26, 1058),
            Q("Stranglethorn Fever", 45, 348),
            Q("Weapons of Spirit", 50, 3129),
            Q("Luck Be With You", 59, 969),
        },
        questTheme  = "Voodoo Magic",
        companion   = E("Frog", 30),
        pet         = nil,
        mount       = nil,
        gameplay    = "cursed necklace",
    },

    ["Spiritwalker_SHAMAN"] = {
        class       = "SHAMAN",
        spec        = "Elemental",
        name        = "Spiritwalker",
        races       = { "Tauren" },
        gender      = "Any gender",
        selfFound   = true,
        professions = {},
        equipment   = {
            E("1h axe", 10),
            E("Lantern", 24),
        },
        challenges  = {
            E("Explorer", 1),
        },
        optionalChallenges = {
            E("Exotic", 1),
            E("Self-made", 1),
            E("Drifter", 1),
        },
        quests      = {
            Q("The Warsong Reports", 19, 6543),
            Q("Weapons of Choice", 24, 893),
            Q("Final Passage", 36, 1394),
            Q("Cuergo's Gold", 45, 2882),
            Q("Cortello's Riddle", 51, 626),
            Q("It's Dangerous to Go Alone", 56, 3962),
        },
        questTheme  = "Wander the land",
        companion   = nil,
        pet         = nil,
        mount       = nil,
        gameplay    = nil,
    },

    ["Pyremaster_SHAMAN"] = {
        class       = "SHAMAN",
        spec        = "Fire Elemental",
        name        = "Pyremaster",
        races       = { "Orc" },
        gender      = "Any gender",
        selfFound   = true,
        professions = {},
        recommendedProfession = {
            name = "Cooking",
            reason = "Need advanced cooking skills to make Dragonbreath Chili.",
        },
        equipment   = {
            E("Dark robe", 8),
            E("Flint and tinder", 10),
            E("Dragonbreath chili", 40),
        },
        challenges  = {
            E("Master of Fire", 1),
        },
        optionalChallenges = {
            E("Exotic", 1),
            E("Partisan", 1),
            E("Homebound", 1),
            E("Self-made", 1),
        },
        questsByHomebound = { 
            default = {
                Q("Keeper of the Flame", 21, 103),
                Q("Dangerous!", 28, 567),
                Q("The Sacred Flame", 29, 1197),
                Q("Extinguishing the Idol", 37, 3525),
                Q("Volcanic Activity", 55, 4502),
                Q("A Taste of Flame", 58, 4024),
            },
            homebound = {
                Q("The Demon Seed", 14, 924),
                Q("Hidden Enemies", 16, 5730),
                Q("The Corrupter", 37, 1488),
                Q("The Sacred Flame", 29, 1197),
                Q("Extinguishing the Idol", 37, 3525),
                Q("Volcanic Activity", 55, 4502),
            },
        },
        questTheme  = "Fiery Garments & Rituals",
        companion   = nil,
        pet         = nil,
        mount       = nil,
        gameplay    = "Campfire, dragonbreath",
    },

    ["Plagueshifter_SHAMAN"] = {
        class       = "SHAMAN",
        spec        = "Restoration",
        name        = "Plagueshifter",
        races       = { "Tauren", "Troll" },
        gender      = "Any gender",
        selfFound   = true,
        professions = {},
        equipment   = {
            E("Plagueshifter robes", 20),
            E("Plagueshifter shoulders", 30),
            E("Plagueshifter cloak", 40),
        },
        challenges  = {
            E("Master of Water", 1),
            E("Purifier", 60),
        },
        optionalChallenges = {
            E("Partisan", 1),
            E("Expeditionary", 1),
            E("Cloth/leather", 1),
        },
        quests      = {
            Q("The Family Crypt", 13, 408),
            Q("Assault on Fenris Isle", 24, 442),
            Q("The Swarm Grows", 35, 1147),
            Q("An Unholy Alliance", 36, 6521),
            Q("Ghost-o-plasm Round Up", 39, 6134),
            Q("Spiritual Unrest", 47, 5535),
            Q("Alien Ecology", 52, 3883),
            Q("Poisoned Water", 56, 6804),
            Q("Mission Accomplished!", 58, 5238),
            Q("The Argent Hold", 60, 5265),
        },
        questTheme  = "All Diseases Must be Purged!",
        companion   = nil,
        pet         = nil,
        mount       = nil,
        gameplay    = "Anti-undead",        
    },
}

----------------------------------------------------------------------
-- Lookup helpers
----------------------------------------------------------------------

-- Race names as returned by UnitRace (English client)
local RACE_ALIASES = {
    ["Nelf"]     = "Night Elf",
    ["Forsaken"] = "Undead",
    ["Tauren"]   = "Tauren",
    ["Dwarf"]    = "Dwarf",
    ["Human"]    = "Human",
    ["Gnome"]    = "Gnome",
    ["Orc"]      = "Orc",
    ["Troll"]    = "Troll",
}

-- Precompute a normalised race set and display string on each character.
for key, char in pairs(FCE.Characters) do
    char.key = key
    -- Normalise singular race = "X" into races = { "X" }
    if not char.races and char.race then
        char.races = { char.race }
    end
    char.raceSet = {}
    local raceNames = {}
    for _, r in ipairs(char.races or {}) do
        local norm = RACE_ALIASES[r] or r
        char.raceSet[norm] = true
        raceNames[#raceNames + 1] = norm
    end
    char.race = table.concat(raceNames, ", ")
end


--- Find all characters that match the player's class, race, and gender.
--- @return table list of character table references
function FCE.FindMatchingCharacters()
    local _, playerClass = UnitClass("player")  -- e.g. "WARRIOR"
    local playerRace     = UnitRace("player")   -- e.g. "Night Elf"
    local playerSex      = UnitSex("player")    -- 2=male, 3=female

    local playerGender
    if playerSex == 3 then
        playerGender = "Female"
    else
        playerGender = "Male"
    end

    local matches = {}
    for key, char in pairs(FCE.Characters) do
        if char.class == playerClass then
            local raceOK   = char.raceSet["Any race"] or char.raceSet[playerRace]
            local genderOK = (char.gender == "Any gender") or (char.gender == playerGender)
            if raceOK and genderOK then
                table.insert(matches, char)
            end
        end
    end
    return matches
end

--- Same as FindMatchingCharacters but ignores gender — returns ALL
--- enhanced classes that match the player's race + base class.
--- Used by the undecided panel so it can show gender-locked classes
--- with a warning instead of hiding them entirely.
function FCE.FindMatchingCharactersNoGender()
    local _, playerClass = UnitClass("player")
    local playerRace     = UnitRace("player")

    local matches = {}
    for key, char in pairs(FCE.Characters) do
        if char.class == playerClass then
            local raceOK = char.raceSet["Any race"] or char.raceSet[playerRace]
            if raceOK then
                table.insert(matches, char)
            end
        end
    end
    return matches
end

--- Get a character by its archetype name (table key).
--- @param name string
--- @return table|nil
function FCE.GetCharacter(name)
    return FCE.Characters[name]
end

--- Check whether the player has the Homebound challenge active.
--- @return boolean
function FCE.IsHomeboundActive()
    local sel = FCE_CharDB and FCE_CharDB.selectedChallenges
    if sel then
        for _, d in ipairs(sel) do
            if d == "Homebound" then return true end
        end
        return false
    end
    -- Legacy single-challenge field
    return FCE_CharDB and FCE_CharDB.selectedChallenge == "Homebound"
end

--- Resolve a quest source that may be a flat array or a { default, homebound } table.
--- @param source table|nil  either a quest array or { default = {...}, homebound = {...} }
--- @return table
local function resolveHomebound(source)
    if not source then return {} end
    -- If the source has a "default" key, it's a homebound-aware table
    if source.default then
        if FCE.IsHomeboundActive() and source.homebound then
            return source.homebound
        end
        return source.default
    end
    -- Otherwise it's a plain quest array
    return source
end

--- Get the resolved quest list for a character, handling faction and
--- homebound variants.
---
--- Supported data shapes:
---   char.quests = { Q(...), ... }                        -- simple
---   char.questsByHomebound = { default = {...}, homebound = {...} }
---   char.questsByFaction = { Alliance = {...}, Horde = {...} }
---   char.questsByFaction = { Alliance = { default = {...}, homebound = {...} },
---                            Horde   = { default = {...}, homebound = {...} } }
--- @param char table
--- @return table
function FCE.GetCharQuests(char)
    if char.questsByFaction then
        local faction = UnitFactionGroup("player")
        local factionQuests = char.questsByFaction[faction] or {}
        return resolveHomebound(factionQuests)
    end
    if char.questsByHomebound then
        return resolveHomebound(char.questsByHomebound)
    end
    return char.quests or {}
end

--- Get the display name for a character, handling faction variants.
--- @param char table
--- @return string
function FCE.GetCharDisplayName(char)
    if char.nameByFaction then
        local faction = UnitFactionGroup("player")
        return char.nameByFaction[faction] or char.name
    end
    return char.name
end

--- Get the quest theme for a character, handling faction variants.
--- @param char table
--- @return string|nil
function FCE.GetCharQuestTheme(char)
    if char.questThemeByFaction then
        local faction = UnitFactionGroup("player")
        return char.questThemeByFaction[faction] or char.questTheme
    end
    return char.questTheme
end

--- Get the resolved selfFound value for a character, handling faction variants.
--- Returns true, false, or nil.
--- @param char table
--- @return boolean|nil
function FCE.GetCharSelfFound(char)
    if char.selfFoundByFaction then
        local faction = UnitFactionGroup("player")
        return char.selfFoundByFaction[faction]
    end
    return char.selfFound
end

--- Get the resolved equipment list for a character, handling faction variants.
--- Supported data shapes:
---   char.equipment = { E(...), ... }                           -- simple
---   char.equipmentByFaction = { Alliance = {...}, Horde = {...} }
--- @param char table
--- @return table
function FCE.GetCharEquipment(char)
    if char.equipmentByFaction then
        local faction = UnitFactionGroup("player")
        return char.equipmentByFaction[faction] or {}
    end
    return char.equipment or {}
end

--- Get the resolved recommendedProfession for a character, handling faction variants.
--- Supported data shapes:
---   char.recommendedProfession = { name = ..., reason = ... }  -- simple
---   char.recommendedProfessionByFaction = { Alliance = {...}, Horde = {...} }
--- @param char table
--- @return table|nil
function FCE.GetCharRecommendedProfession(char)
    if char.recommendedProfessionByFaction then
        local faction = UnitFactionGroup("player")
        return char.recommendedProfessionByFaction[faction]
    end
    return char.recommendedProfession
end

--- Get the resolved gameplay string for a character, handling faction variants.
--- Supported data shapes:
---   char.gameplay = "string"                                     -- simple
---   char.gameplayByFaction = { Alliance = "...", Horde = "..." }
--- @param char table
--- @return string|nil
function FCE.GetCharGameplay(char)
    if char.gameplayByFaction then
        local faction = UnitFactionGroup("player")
        return char.gameplayByFaction[faction]
    end
    return char.gameplay
end

--- Get the active challenges for a character: non-optional challenges plus
--- the player's selected optional challenge (if any).
--- @param char table  character data table
--- @return table  array of { desc, level [, endLevel] } entries
function FCE.GetActiveChallenges(char)
    local active = {}

    -- Build lookup of selected optional challenges
    local selTable = FCE_CharDB and FCE_CharDB.selectedChallenges
    local selLookup = {}
    if selTable then
        for _, d in ipairs(selTable) do selLookup[d] = true end
    elseif FCE_CharDB and FCE_CharDB.selectedChallenge then
        -- Legacy single-challenge field
        selLookup[FCE_CharDB.selectedChallenge] = true
    end

    -- Insert selected optional challenges first so they appear at the top
    if next(selLookup) and char.optionalChallenges then
        for _, ch in ipairs(char.optionalChallenges) do
            if selLookup[ch.desc] then
                table.insert(active, ch)
            end
        end
    end

    -- Then append the non-optional challenges
    for _, ch in ipairs(char.challenges or {}) do
        table.insert(active, ch)
    end
    return active
end
