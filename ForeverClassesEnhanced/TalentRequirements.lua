----------------------------------------------------------------------
-- ForeverClassesEnhanced — Per-Character Talent Requirements
--
-- On top of the spec-plurality rule (majority of points in the
-- character's native tree), each character may require specific
-- talents at specific levels.
--
-- Data format per entry:
--   name  = English talent name (matched via GetTalentInfo scan)
--   tab   = talent tab index (1/2/3), locale-independent
--   rank  = minimum points required in this talent
--   level = player level at which this requirement activates
--
-- Tab reference:
--   Warrior:  1=Arms,       2=Fury,       3=Protection
--   Rogue:    1=Assassination, 2=Combat,  3=Subtlety
--   Warlock:  1=Affliction,  2=Demonology, 3=Destruction
--   Druid:    1=Balance,     2=Feral,      3=Restoration
--   Hunter:   1=Beast Mastery, 2=Marksmanship, 3=Survivaltan
--   Shaman:   1=Elemental,   2=Enhancement, 3=Restoration
--   Paladin:  1=Holy,        2=Protection,  3=Retribution
--   Priest:   1=Discipline,  2=Holy,        3=Shadow
--   Mage:     1=Arcane,      2=Fire,        3=Frost
----------------------------------------------------------------------

FCE = FCE or {}

local R = function(name, tab, rank, level, endLevel)
    return { name = name, tab = tab, rank = rank, level = level, endLevel = endLevel or nil }
end

FCE.TalentRequirements = {

    ---------- WARRIOR ----------

    ['WARRIOR_"Sword & Board"'] = {   -- Protection
        roles = "Tank/damage",
        R("Last Stand",      3, 1, 20),
        R("Improved Shield Block",      3, 1, 21),
        R("Concussion Blow", 3, 1, 30),
        R("Shield Slam",     3, 1, 40),
        R("Anger Management", 1, 1, 51),
    },

    ["WARRIOR_Slam"] = {      -- Arms
        roles = "Damage/tank",
        R("Improved Cleave",        2, 3, 23),
        R("Improved Slam",        2, 5, 35),
        R("Flurry",        2, 5, 41),
    },

    ["WARRIOR_Flurry"] = {    -- Fury
        roles = "Damage",
        R("Cruelty", 2, 5, 14),
        R("Blood Craze", 2, 3, 23),
        R("Enrage", 2, 5, 29),
        R("Flurry", 2, 5, 39),
        R("Bloodthirst", 2, 1, 40),
        R("Dual Wield Specialization", 2, 5, 41),
    },

    ["WARRIOR_Fury/Prot"] = {   
        roles = "Damage/tank",
        R("Cruelty", 2, 5, 14),
        R("Blood Craze", 2, 3, 23),
        R("Enrage", 2, 5, 29),
        R("Flurry", 2, 5, 39),
        R("Bloodthirst", 2, 1, 40),
        R("Anticipation", 3, 5, 45),
        R("Last Stand", 3, 1, 52),
        R("Defiance",     3, 5, 57),
    },

    ["WARRIOR_Arms/Prot"] = {   -- Protection
        roles = "Damage/tank",
        R("Improved Overpower",        1, 2, 21),
        R("Impale",        1, 2, 26),
        R("Sweeping Strikes",        1, 1, 30),
        R("Mortal Strike", 1, 1, 40),
        R("Anticipation", 3, 5, 45),
        R("Last Stand", 3, 1, 52),
        R("Defiance",     3, 5, 57),
    },

    ["WARRIOR_Sword"] = {      -- Arms
        roles = "Damage/tank",
        R("Improved Overpower",        1, 2, 21),
        R("Impale",        1, 2, 26),
        R("Sword Specialization",        1, 5, 35),
        R("Mortal Strike", 1, 1, 40),
    },

    ["WARRIOR_Mace"] = {      -- Arms
        roles = "Damage/tank",
        R("Improved Overpower",        1, 2, 21),
        R("Impale",        1, 2, 26),
        R("Mace Specialization",        1, 5, 35),
        R("Mortal Strike", 1, 1, 40),
    },

    ["WARRIOR_Axe"] = {      -- Arms
        roles = "Damage/tank",
        R("Improved Overpower",        1, 2, 21),
        R("Impale",        1, 2, 26),
        R("Axe Specialization",        1, 5, 35),
        R("Mortal Strike", 1, 1, 40),
    },

    ["WARRIOR_Polearm"] = {      -- Slam
        roles = "Damage/tank",
        R("Improved Overpower",        1, 2, 21),
        R("Impale",        1, 2, 26),
        R("Polearm Specialization",        1, 5, 39),
        R("Mortal Strike", 1, 1, 40),
    },

    ---------- ROGUE ----------

    ["ROGUE_Mace"] = {       -- Combat
        roles = "Damage",
        R("Riposte",             2, 1, 22),
        R("Mace Specialization",2, 5, 37),
        R("Aggression",2, 3, 40),
        R("Dual Wield Specialization",2, 5, 41),
        R("Improved Slice and Dice",1, 3, 47),
    },

    ["ROGUE_Combat"] = {       -- Combat
        roles = "Damage",
        R("Riposte",             2, 1, 22),
        R("Dual Wield Specialization",2, 5, 33),
        R("Weapon Expertise",2, 2, 38),
        R("Aggression",2, 3, 41),
        R("Improved Slice and Dice",1, 3, 47),
    },

    ["ROGUE_Backstab/Riposte"] = {       -- Combat
        roles = "Damage",
        R("Remorseless Attacks",  1, 2, 11),
        R("Improved Gouge",  2, 3, 16),
        R("Riposte",             2, 1, 22),
        R("Improved Backstab",    2, 3, 25),  -- Combat tree (cross-spec)
        R("Ruthlessness",            1, 3, 31),
        R("Lethality",            1, 5, 39),
        R("Improved Kidney Shot", 1, 3, 47),
        R("Seal Fate", 1, 5, 53),
        R("Dagger Specialization",          2, 5, 60),  -- Subtlety tree (cross-spec)
    },

    ["ROGUE_Backstab/Poison"] = {       -- Subtlety
        roles = "Damage",
        R("Remorseless Attacks",  1, 2, 11),
        R("Improved Gouge",  2, 3, 16),
        R("Improved Backstab",    2, 3, 19),  -- Combat tree (cross-spec)
        R("Ruthlessness",            1, 3, 27),
        R("Lethality",            1, 5, 33),
        R("Improved Poisons",            1, 5, 39),
        R("Improved Kidney Shot", 1, 3, 42),
        R("Seal Fate", 1, 5, 47),
        R("Opportunity",          3, 5, 52),  -- Subtlety tree (cross-spec)
        R("Vile Poisons",            1, 5, 58),
    },

    ["ROGUE_Backstab"] = {       -- Subtlety
        roles = "Damage",
        R("Remorseless Attacks",  1, 2, 11),
        R("Improved Gouge",  2, 3, 16),
        R("Improved Backstab",    2, 3, 19),  -- Combat tree (cross-spec)
        R("Ruthlessness",            1, 3, 27),
        R("Lethality",            1, 5, 33),
        R("Improved Kidney Shot", 1, 3, 41),
        R("Seal Fate", 1, 5, 47),
        R("Opportunity",          3, 5, 53),  -- Subtlety tree (cross-spec)
    },

    ["ROGUE_Ambush"] = {       -- Assa
        roles = "Damage",
        R("Remorseless Attacks",  1, 2, 11),
        R("Opportunity",    3, 5, 16),
        R("Improved Ambush",   3, 3, 25),
        R("Improved Sap",   3, 3, 34),
        R("Premeditation", 3, 1, 42),
    },

    ["ROGUE_Ghost"] = {       -- Assa
        roles = "Damage",
        R("Improved Gouge",  2, 3, 14),
        R("Riposte",             2, 1, 22),
        R("Ghostly Strike",   3, 1, 31),
        R("Setup",   3, 3, 38),
        R("Endurance", 2, 2, 40),
        R("Lightning Reflexes", 2, 5, 45),
    },

    ["ROGUE_Sword"] = {          -- Combat
        roles = "Damage",
        R("Remorseless Attacks",  1, 2, 11),
        R("Riposte",             2, 1, 22),
        R("Precision",             2, 5, 27),
        R("Sword Specialization",2, 5, 37),
        R("Weapon Expertise",2, 2, 39),
        R("Dual Wield Specialization",2, 5, 40),
        R("Adrenaline Rush",2, 1, 42),
    },

    ["ROGUE_Fist Combat"] = {          -- Combat
        roles = "Damage",
        R("Riposte",             2, 1, 20),
        R("Precision",             2, 5, 25),
        R("Weapon Expertise",2, 2, 37),
        R("Fist Weapon Specialization",2, 5, 37),
        R("Dual Wield Specialization",2, 5, 38),
        R("Adrenaline Rush",2, 1, 40),
        R("Improved Eviscerate",1, 3, 45),
        R("Adrenaline Slice and Dice",1, 3, 48),
    },

    ---------- WARLOCK ----------

    ["WARLOCK_Fire Destruction"] = {      -- Destruction
        roles = "Damage",
        R("Improved Imp",     2, 3, 12),  -- Demonology tree (cross-spec)
        R("Improved Corruption",     1, 5, 17),
        R("Improved Firebolt",3, 2, 29),
        R("Ruin",             3, 1, 38),
        R("Emberstorm",       3, 5, 49),
    },

    ["WARLOCK_Melee-weaving Fire"] = {      -- Destruction
        roles = "Damage",
        R("Improved Imp",     2, 3, 12),  -- Demonology tree (cross-spec)
        R("Improved Corruption",     1, 5, 17),
        R("Improved Firebolt",3, 2, 29),
        R("Ruin",             3, 1, 38),
        R("Emberstorm",       3, 5, 49),
    },

    ["WARLOCK_Drain Life"] = {    -- Affliction
        roles = "Damage",
        R("Improved Corruption", 1, 5, 14),
        R("Improved Drain Life", 1, 5, 21),
        R("Fel Concentration",   1, 5, 27),
        R("Shadow Mastery",      1, 5, 39),
    },
    
    ["WARLOCK_Soul Link"] = {      -- Demonology
        roles = "Tank/damage",
        R("Demonic Embrace", 2, 5, 14),
        R("Improved Voidwalker", 2, 3, 17),
        R("Unholy Power", 2, 5, 32),
        R("Master Demonologist", 2, 5, 39),
        R("Soul Link", 2, 1, 40),
        R("Shadowburn",   3, 1, 56),
    },

    ["WARLOCK_DS/Ruin"] = {      -- Demonology
        roles = "Damage",
        R("Demonic Embrace", 2, 5, 14),
        R("Demonic Sacrifice", 2, 1, 30),
        R("Improved Shadow Bolt", 3, 5, 35),
        R("Bane", 3, 5, 40),
        R("Shadowburn", 3, 1, 41),
        R("Ruin", 3, 1, 51),
    },

    ---------- DRUID ----------

    ["DRUID_Bear"] = {  -- Feral
        roles = "Tank",
        R("Feral Charge",       2, 1, 21),
        R("Primal Fury",        2, 2, 27),
        R("Faerie Fire (Feral)",2, 1, 31),
        R("Leader of the Pack", 2, 1, 41),
    },

    ["DRUID_Powershifting Hybrid"] = {
        roles = "Healer/damage/tank",
        R("Improved Nature's Grasp", 1, 4, 14),
        R("Omen of Clarity",      1, 1, 20),
        R("Ferocity",      2, 5, 25),
        R("Furor",      3, 5, 30),
        R("Improved Healing Touch",      3, 5, 35),
        R("Natural Shapeshifter",      1, 3, 39),
        R("Reflection",      3, 3, 42),
        R("Nature's Swiftness",      3, 1, 49),
    },

    ["DRUID_Restoration"] = {   -- Restoration
        roles = "Healer",
        R("Improved Wrath", 1, 5, 15),
        R("Improved Healing Touch",      3, 5, 25),
        R("Reflection",      3, 3, 29),
        R("Nature's Swiftness",      3, 1, 36),
        R("Improved Tranquility",      3, 2, 38),
        R("Swiftmend",      3, 1, 46),
    },

    ["DRUID_Moonkin"] = {       -- Balance
        roles = "Damage",
        R("Improved Moonfire", 1, 5, 19),
        R("Vengeance",         1, 5, 35),
        R("Moonkin Form",         1, 1, 40),
        R("Moonfury",      1, 5, 44),
    },

    ["DRUID_Melee Moonkin"] = {       -- Balance
        roles = "Damage",
        R("Improved Nature's Grasp", 1, 4, 14),
        R("Omen of Clarity", 1, 1, 20),
        R("Improved Moonfire",      1, 5, 25),
        R("Moonglow",         1, 3, 33),
        R("Natural Shapeshifter",         1, 3, 37),
        R("Moonkin Form",         1, 1, 40),
        R("Improved Mark of the Wild",         3, 5, 48),
    },
    
    ["DRUID_Truecaster"] = {       -- Balance
        roles = "Damage/healer",
        R("Improved Wrath", 1, 5, 15),
        R("Improved Moonfire", 1, 5, 20),
        R("Vengeance",         1, 5, 30),
        R("Moonfury",      1, 5, 40),
        R("Improved Healing Touch",      3, 5, 50),
        R("Reflection",      3, 3, 54),
    },

    ---------- HUNTER ----------

    ["HUNTER_Lone Wolf"] = {       -- Survival
        roles = "Damage",
        R("Savage Strikes", 3, 2, 16),
        R("Entrapment", 3, 5, 21),
        R("Clever Traps", 3, 2, 24),
        R("Trap Mastery", 3, 2, 26),
        R("Counterattack",  3, 1, 30),
        R("Killer Instinct",   3, 3, 33),
        R("Wyvern Sting",  3, 1, 40),
    }, 

    ["HUNTER_Beast Mastery"] = {     -- Beast Mastery
        roles = "Damage/tank",
        R("Endurance Training", 1, 5, 14),
        R("Ferocity",          1, 5, 31),
        R("Spirit Bond",       1, 2, 33),
        R("Frenzy",            1, 5, 41),
        R("Monster Slaying",            3, 3, 44),
    },

    ["HUNTER_Melee"] = {     -- Beast Mastery
        roles = "Damage/tank",
        R("Savage Strikes", 3, 2, 16),
        R("Thick Hide", 1, 3, 24),
        R("Ferocity",          1, 5, 36),
        R("Frenzy",            1, 5, 46),
    },

    ["HUNTER_Spell Power"] = {     -- Marksmanship
        roles = "Damage",
        R("Efficiency", 2, 5, 14),
        R("Improved Arcane Shot",                  2, 5, 25),
        R("Improved Serpent Sting",                2, 5, 31),
        R("Mortal Shots",                          2, 5, 39),
        R("Trueshot Aura", 1, 1, 40),  -- BM tree (cross-spec)
    },

    ["HUNTER_Marksmanship"] = {     -- Marksmanship
        roles = "Damage",
        R("Lethal Shots", 2, 5, 19),
        R("Aimed Shot",                  2, 1, 20),
        R("Mortal Shots",                2, 5, 29),
        R("Ranged Weapon Specialization",2, 5, 39),
        R("Improved Aspect of the Hawk", 1, 5, 45),  -- BM tree (cross-spec)
    },

    ["HUNTER_Melee Survival"] = {
        roles = "Damage",
        R("Savage Strikes", 3, 2, 16),
        R("Monster Slaying", 3, 3, 17),
        R("Humanoid Slaying", 3, 3, 17),
        R("Clever Traps", 3, 2, 22),
        R("Counterattack",  3, 1, 30),
        R("Survivalist",  3, 5, 34),
        R("Lightning Reflexes",  3, 5, 39),
    },

    ["HUNTER_Survival"] = {
        roles = "Damage",
        R("Savage Strikes", 3, 2, 16),
        R("Clever Traps", 3, 2, 22),
        R("Improved Wing Clip", 3, 5, 24),
        R("Surefooted",  3, 3, 27),
        R("Counterattack",  3, 1, 30),
        R("Killer Instinct",   3, 3, 33),
        R("Wyvern Sting",  3, 1, 40),
    },

    ---------- SHAMAN ----------

    ['SHAMAN_"Sword & Board"'] = { -- Enhancement
        roles = "Tank",
        R("Shield Specialization", 2, 5, 14),
        R("Flurry", 2, 5, 29),
        R("Parry",                 2, 1, 30),
        R("Stormstrike",         2, 1, 40),
        R("Reverberation",         1, 5, 56),
    },

    ["SHAMAN_Ward"] = {    -- Restoration
        roles = "Healer",
        R("Improved Healing Wave", 3, 5, 14),
        R("Totemic Focus",        3, 5, 19),
        R("Totemic Mastery",      3, 1, 20),
        R("Restorative Totems",   3, 5, 29),
        R("Mana Tide Totem",      3, 1, 40),
    },

    ["SHAMAN_Restoration"] = {    -- Restoration
        roles = "Healer",
        R("Improved Healing Wave", 3, 5, 14),
        R("Ancestral Healing", 3, 3, 17),
        R("Nature's Swiftness", 3, 1, 30),
        R("Purification", 3, 5, 39),
        R("Mana Tide Totem",      3, 1, 40),
    },

    ["SHAMAN_Elemental"] = {    -- Elemental
        roles = "Damage/healer",
        R("Call of Thunder",       1, 5, 25),
        R("Improved Healing Wave", 3, 5, 30),  -- Restoration tree (cross-spec)
        R("Elemental Fury",        1, 1, 35),
        R("Lightning Mastery",     1, 5, 44),
    },

    ["SHAMAN_Fire Elemental"] = {    -- Elemental
        roles = "Damage/healer",
        R("Call of Flame",       1, 3, 17),
        R("Improved Fire Totems", 1, 2, 26), 
        R("Elemental Fury",        1, 1, 35),
        R("Lightning Mastery",     1, 5, 40),
    },

    ["SHAMAN_2-handed Stormstrike"] = { -- Enhancement
        roles = "Damage",
        R("Two-Handed Axes and Maces", 2, 1, 20),
        R("Thundering Strikes", 2, 5, 22),
        R("Enhancing Totems",                 2, 2, 24),
        R("Flurry",                 2, 5, 29),
        R("Elemental Weapons",                 2, 3, 33),
        R("Stormstrike",         2, 1, 40),
        R("Call of Flame",         1, 3, 48),
        R("Elemental Devastation",         1, 3, 58),
    },

    ---------- PALADIN ----------

    ["PALADIN_Holy/Prot"] = {        -- Holy
        roles = "Healer/tank",
        R("Divine Intellect", 1, 5, 14),
        R("Improved Seal of Righteousness", 1, 5, 19),
        R("Consecration", 1, 1, 20),
        R("Healing Light",    1, 3, 23),
        R("Divine Favor",     1, 1, 30),
        R("Redoubt",       2, 5, 35),
        R("Improved Righteous Fury",       2, 3, 43),
        R("Shield Specialization",       2, 3, 46),
        R("Holy Shock",       1, 1, 56),
    },

    ['PALADIN_"Sword & Board"'] = {         -- Protection
        roles = "Tank",
        R("Consecration",           1, 1, 20),
        R("Redoubt",                 2, 5, 25),
        R("Improved Righteous Fury", 2, 3, 33),
        R("Shield Specialization",  2, 3, 37),
        R("Blessing of Sanctuary",  2, 1, 41),
        R("Reckoning",  2, 5, 46),
        R("Holy Shield",            2, 1, 51),
    },

    ["PALADIN_Retribution"] = { -- Retribution
        roles = "Damage",
        R("Seal of Command",                    3, 1, 20),
        R("Conviction",                         3, 5, 27),
        R("Deflection",                              3, 5, 29),
        R("Vengeance",                          3, 5, 39),
        R("Precision",                          2, 3, 48),
        R("Divine Strength",                    1, 5, 56),
    },

    ---------- PRIEST ----------

    ["PRIEST_Spirit"] = {  -- Holy
        roles = "Damage/healer",
        R("Spirit Tap",          3, 5, 14),  -- Shadow tree (cross-spec)
        R("Divine Fury",         2, 5, 24),
        R("Holy Specialization", 2, 5, 27),
        R("Searing Light",       2, 2, 31),
        R("Spiritual Guidance",  2, 5, 39),
        R("Meditation",1, 3, 53),
        R("Divine Spirit",1, 1, 60),
    },

    ["PRIEST_Discipline"] = {      -- Discipline
        roles = "Healer/damage",
        R("Wand Specialization", 1, 5, 14),
        R("Inner Focus",         1, 1, 25),
        R("Divine Spirit",       1, 1, 35),
        R("Power Infusion",      1, 1, 46),
    },

    ["PRIEST_Melee-weaving Mind Flayer"] = {   -- Shadow
        roles = "Damage/healer",
        R("Mind Flay",        3, 1, 20),
        R("Vampiric Embrace", 3, 1, 30),
        R("Shadowform",       3, 1, 40),
        R("Improved Power Word: Shield", 1, 3, 48),
        R("Martyrdom",       1, 2, 50),
        R("Meditation",       1, 3, 54),
        R("Blackout",       3, 5, 59),
    },

    ["PRIEST_Hybrid"] = {   -- Shadow
        roles = "Damage/healer",
        R("Healing Focus",        2, 2, 11),
        R("Mind Flay",        3, 1, 22),
        R("Improved Mind Blast",        3, 4, 26),
        R("Shadow Reach",        3, 3, 29),
        R("Divine Fury", 2, 5, 37),
        R("Inspiration",       2, 3, 41),
        R("Meditation",       1, 3, 55),
    },

    ["PRIEST_Shadow Ascendant"] = {   -- Shadow
        roles = "Damage",
        R("Mind Flay",        3, 1, 20),
        R("Vampiric Embrace", 3, 1, 30),
        R("Shadowform",       3, 1, 40),
        R("Shadow Weaving",       3, 5, 45),
        R("Improved Mind Blast",       3, 4, 49),
        R("Shadow Affinity",       3, 3, 54),
    },

    ["PRIEST_Shadow"] = {   -- Shadow
        roles = "Damage/healer",
        R("Mind Flay",        3, 1, 20),
        R("Vampiric Embrace", 3, 1, 30),
        R("Shadowform",       3, 1, 40),
    },

    ---------- MAGE ----------

    ["MAGE_Pyromancer"] = {       -- Fire
        roles = "Damage",
        R("Improved Fireball", 2, 5, 17),
        R("Blast Wave", 2, 1, 33),
        R("Critical Mass",    2, 3, 36),
        R("Fire Power",       2, 5, 42),
    },

    ["MAGE_Presence of Mind"] = {    -- Arcane
        roles = "Damage",
        R("Improved Arcane Missiles", 1, 5, 14),
        R("Arcane Resilience",        1, 1, 20),
        R("Impact",                   2, 5, 27),  -- Fire tree (cross-spec)
        R("Pyroblast",                2, 1, 33),  -- Fire tree (cross-spec)
        R("Presence of Mind",         1, 1, 41),
        R("Arcane Power",             1, 1, 51),
    },

    ["MAGE_Aoe-grinder"] = {         -- Frost
        roles = "Damage",
        R("Permafrost",        3, 3, 19),
        R("Improved Blizzard", 3, 3, 23),
        R("Ice Block",         3, 1, 30),
        R("Ice Barrier",       3, 1, 40),
    },

    ["MAGE_Frostfire"] = {       -- Frostfire
        roles = "Damage",
        R("Improved Fireball", 2, 5, 14),
        R("Elemental Precision", 3, 3, 17),
        R("Ignite", 2, 5, 22),
        R("Blast Wave", 2, 1, 33),
        R("Frostbite", 3, 3, 38),
        R("Shatter", 3, 5, 50),
        R("Critical Mass",    2, 3, 53),
        R("Combustion",       2, 1, 60),
    },

    ["MAGE_Scorch"] = {       -- Fire
        roles = "Damage",
        R("Impact", 2, 5, 14),
        R("Elemental Precision", 3, 3, 17),
        R("Ignite", 2, 5, 22),
        R("Incinerate", 2, 2, 24),
        R("Improved Scorch", 2, 3, 30),
        R("Blast Wave", 2, 1, 33),
        R("Master of Elements", 2, 3, 37),
        R("Combustion",       2, 1, 43),
    },
}
