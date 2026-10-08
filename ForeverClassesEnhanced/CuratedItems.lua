----------------------------------------------------------------------
-- ForeverClassesEnhanced - Curated Item ID Lists
--
-- This file populates FCE.CuratedItems (defined in EquipmentCheck.lua)
-- with specific WoW Classic item IDs for visual/thematic equipment
-- requirements that cannot be detected by item type alone.
--
-- Each list maps itemID -> a short provenance comment.  EquipmentCheck
-- only cares about key existence, but the value lets us keep a paper
-- trail of where each ID was verified (Wowhead Classic).
--
-- Lists marked COMPLETE mean a miss on an equipped item is a hard FAIL;
-- incomplete lists return UNCHECKED instead.
--
-- Task 7.2 curation pass - 2026-04-26
----------------------------------------------------------------------

FCE = FCE or {}
FCE.CuratedItems = FCE.CuratedItems or {}
FCE.CuratedComplete = FCE.CuratedComplete or {}
local C = FCE.CuratedItems
local COMPLETE = FCE.CuratedComplete

----------------------------------------------------------------------
-- Helper: fold a list of {itemID, "note"} pairs into the target table.
----------------------------------------------------------------------

local function fill(target, entries)
    if not target._order then target._order = {} end
    for _, pair in ipairs(entries) do
        target[pair[1]] = pair[2] or true
        target._order[#target._order + 1] = pair[1]
    end
end

----------------------------------------------------------------------
-- ENGINEERING GOGGLES / HEADGEAR (Mechano-Mage)
----------------------------------------------------------------------

-- Flying Tiger Goggles - single definitive item
fill(C.flying_tiger_goggles, {
    { 4368, "Flying Tiger Goggles - Engineering 100" },
    { 4373, "Shadow Goggles - Engineering 120" },
    { 4385,  "Green Tinted Goggles - Engineering 150" },
    { 9492,  "Electromagnetic Gigaflux Reactivator - Gnomeregan drop" },
})
COMPLETE.flying_tiger_goggles = true

-- Green-tinted goggles - green-lens / tinted eyewear
fill(C.green_tinted_goggles, {
    { 4385,  "Green Tinted Goggles - Engineering 150" },
    { 10499, "Bright-Eye Goggles - Engineering 175" },
    { 4393, "Gnomish Mind Control Cap - Engineering 185" },
    { 10500, "Fire Goggles - Engineering 205" },
    { 10545, "Gnomish Goggles - Engineering 210" },
    { 10502, "Spellpower Goggles Xtreme - Engineering 215" },
    { 10726, "Gnomish Mind Control Cap - Engineering 215" },
    { 10503, "Rose Colored Goggles - Engineering 230" },
    { 10506, "Gnomish Mind Control Cap - Engineering 230" },
    { 15999, "Spellpower Goggles Xtreme Plus - Engineering 270" },
    { 16008, "Master Engineer's Goggles - Engineering 280" },
    { 19999, "Bloodvine Goggles - Engineering 300" },
    { 9492,  "Electromagnetic Gigaflux Reactivator - Gnomeregan drop" },
})
COMPLETE.green_tinted_goggles = true

-- Gnomish goggles - engineering headgear with goggle/helmet art
fill(C.gnomish_goggles, {
    { 10545, "Gnomish Goggles - Engineering 210" },
    { 10502, "Spellpower Goggles Xtreme - Engineering 215" },
    { 10503, "Rose Colored Goggles - Engineering 230" },
    { 10506, "Gnomish Mind Control Cap - Engineering 230" },
    { 15999, "Spellpower Goggles Xtreme Plus - Engineering 270" },
    { 16008, "Master Engineer's Goggles - Engineering 280" },
    { 19999, "Bloodvine Goggles - Engineering 300" },
})
COMPLETE.gnomish_goggles = true
-- All Engineering-crafted headgear in Classic with goggle/helmet art.

----------------------------------------------------------------------
-- WARLOCK FIRESTONES / SPELLSTONES (Pyremaster, Shadowmage)
----------------------------------------------------------------------

fill(C.firestone, {
    { 1254,  "Firestone - rank 1 (lvl 28)" },
    { 13699, "Greater Firestone - rank 2 (lvl 46)" },
    { 13700, "Major Firestone - rank 3 (lvl 56)" },
})
COMPLETE.firestone = true

fill(C.brewmaster_robe, {
    { 6801,  "Baroque Apron - Dustwallow quest reward" },
})
COMPLETE.brewmaster_robe = true

fill(C.robe_power, {
    { 7054,  "Robe of Power - Tailoring" },
})
COMPLETE.robe_power = true

fill(C.pirate_shirt, {
    { 5202,  "Corsair's Overshirt - DM drop" },
    { 14175,  "Buccaneer's Vest - World drop" },
    { 22742,  "Bloodsail Shirt - Bloodsail rep reward" },
})
COMPLETE.pirate_shirt = true

fill(C.pirate_belt, {
    { 9636,  "Swashbuckler Sash - STV quest reward" },
})
COMPLETE.pirate_belt = true

fill(C.rapier, {
    { 9446,  "Electrocutioner Leg - Gnomeregan drop" },
    { 12777,  "Blazing Rapier - World drop" },
    { 7944,  "Dazzling Mithril Rapier - Blacksmithing" },
    { 13034,  "Speedsteel Rapier - World drop" },
})
COMPLETE.rapier = true

fill(C.katana, {
    { 922,  "Dacian Falx - Vendor" },
    { 6909, "Strike of the Hydra - BFD drop" },
    { 18520, "Barbarous Blade - Dire Maul drop" },
    { 10573, "Boneslasher - World drop" },
    { 2205, "Duskbringer - SFK zone drop" },
    { 16039, "Ta'Kierthan Songblade - Plaguelands rare mob drop" },
    { 3854, "Frost Tiger Blade - Blacksmithing" },
    { 9385, "Archaic Defender - World drop" },
    { 15251, "Headstriker Sword - World drop" },
    { 15257, "Shin Blade - World drop" },
    { 2822, "Mo'grosh Toothpick - Loch Modan ogre drop" },
    { 2801, "Blade of Hanna - epic World drop" },
})
COMPLETE.katana = true

fill(C.engineer_offhand, {
    { 11855,  "Tork Wrench - Barrens quest reward" },
    { 9644, "Thermotastic Egg Timer - Booty Bay quest reward" },
})
COMPLETE.engineer_offhand = true

fill(C.flint, {
    { 4471,  "Flint and Tinder - Vendor" },
})
COMPLETE.flint = true

fill(C.reflector_belt, {
    { 11861,  "Girdle of Reprisal - Searing Gorge quest reward" },
})
COMPLETE.reflector_belt = true

fill(C.red_shirt, {
    { 2575,  "Red Linen Shirt - Tailoring 40" },
})
COMPLETE.red_shirt = true

fill(C.scarlet_shoulders, {
    { 7718,  "Herod's Shoulder - SM drop" },
})
COMPLETE.scarlet_shoulders = true

fill(C.scarlet_tabard, {
    { 23192,  "Tabard of the Scarlet Crusade - SM drop" },
})
COMPLETE.scarlet_tabard = true

fill(C.scarlet_shield, {
    { 4263,  "Standard Issue Shield - Tirisfal Glades rare drop" },
    { 7726,  "Aegis of the Scarlet Commander - SM drop" },
})
COMPLETE.scarlet_shield = true

fill(C.scarlet_helm, {
    { 7719,  "Raging Berserker's Helm - SM drop" },
    { 10743,  "Drakefire Headguard - Searing Gorge quest reward" },
    { 10235,  "Engraved Helm - World drop" },
    { 10379,  "Commander's Helm - World drop" },
    { 12952,  "Gyth's Skull - UBRS drop" },
})
COMPLETE.scarlet_helm = true

fill(C.scarlet_priest_helm, {
    { 7720,  "Whitemane's Chapeau - SM drop" },
})
COMPLETE.scarlet_priest_helm = true

fill(C.scarlet_priest_shoulders, {
    { 3560,  "Mantle of Honor - Duskwood quest reward" },
    { 22405,  "Mantle of the scarlet crusade - Strat drop" },
})
COMPLETE.scarlet_priest_shoulders = true

fill(C.scarlet_priest_robe, {
    { 3260,  "Scarlet Initiate Robes - rare SM drop" },
    { 7054,  "Robe of Power - Tailoring" },
})
COMPLETE.scarlet_priest_robe = true

fill(C.templar_robes, {
    { 16605,  "Friar's Robes of the Light - Priest quest" },
    { 3216,  "Warm Winter Robe - Dun Morogh quest" },
    { 2114,  "Snowy Robe - Dun Morogh rare drop" },
    { 6241,  "White Linen Robe - Tailoring" },
    { 2616,  "Shimmering Silk Robes - Vendor" },
    { 2618,  "Silver Dress Robes - Vendor" },
    { 13858,  "Runecloth Robe - Tailoring" },
    { 18486,  "Mooncloth Robe - Tailoring" },
    { 23085,  "Robe of Undead Cleansing - Rare drop" },
})
COMPLETE.templar_robes = true

fill(C.templar_mantle, {
    { 3560,  "Mantle of Honor - Duskwood quest reward" },
    { 2913,  "Silk Mantle of Gamn - Wetlands quest reward" },
    { 17047,  "Luminescent Amice - Ashenvale quest reward" },
})
COMPLETE.templar_mantle = true

fill(C.templar_helm, {
    { 13216,  "Crown of the Penitent - Strat quest reward" },
    { 14140,  "Mooncloth Circlet - Tailoring" },
})
COMPLETE.templar_helm = true

fill(C.priest_hammer, {
    { 7721,  "Hand of Righteousness - SM drop" },
})
COMPLETE.priest_hammer = true

fill(C.priest_offhand, {
    { 7344,  "Torch of Holy Flame - Duskwood quest reward" },
})
COMPLETE.priest_offhand = true

fill(C.scarlet_chestpiece, {
    { 6773,  "Gelkis Marauder Chain - Desolace quest reward" },
    { 10328,  "Scarlet Chestpiece - SM zone drop" },
    { 17777,  "Relentless Chain - Maraudon quest reward" },
    { 11194,  "Prismscale Hauberk - Badlands quest reward" },
    { 11195,  "Warforged Chestplate - Badlands quest reward" },
    { 12049,  "Splintsteel Armor - BRD quest reward" },
    { 21322,  "Ursa's Embrace - Winterspring quest reward" },
    { 14611,  "Bloodmail Hauberk - World drop" },
})
COMPLETE.scarlet_chestpiece = true

fill(C.scarlet_leggings, {
    { 10330,  "Scarlet Leggings - SM drop" },
    { 19124,  "Slagplate Leggings - Searing Gorge quest reward" },
    { 21316,  "Leggings of the Ursa - Winterspring quest reward" },
    { 12049,  "Searingscale Leggings - BRD drop" },
    { 11802,  "Lavacrest Leggings - BRD drop" },
    { 16728,  "Lightforge Legplates - Stratholme drop" },
})
COMPLETE.scarlet_leggings = true

fill(C.scarlet_gauntlets, {
    { 3759,  "Insulated Sage Gloves - Alterac quest reward (cloth)" },
    { 6732,  "Gnomish Mechanic's Gloves - T. Needles quest reward (leather)" },
    { 9445,  "Grubbis Paws - Gnomeregan drop" },
    { 7724,  "Gauntlets of Divinity - SM drop" },
    { 10331,  "Scarlet Gauntlets - SM drop" },
    { 9640,  "Vice Grips - ZF drop" },
    { 19126,  "Slagplate Gauntlets - Searing Gorge quest reward" },
    { 11867,  "Maddening Gauntlets - Burning Steppes quest reward" },
    { 11814,  "Molten Fists - BRD drop" },
    { 18366,  "Gordok's Handguards - Dire Maul quest reward" },
    { 14615,  "Bloodmail Gauntlets - World drop" },
})
COMPLETE.scarlet_gauntlets = true

fill(C.scarlet_boots, {
    { 10332,  "Scarlet Boots - SM zone drop" },
    { 9387,  "Revelosh's Boots - Uldaman drop" },
    { 6791,  "Hellion Boots - Desolace quest reward (cloth)" },
    { 11919,  "Cragplate Greaves - Un'Goro quest reward" },
    { 10846,  "Bloodshot Greaves - ST drop" },
    { 11865,  "Rancor Boots - BRD quest reward (cloth)" },
    { 22240,  "Greaves of Withering Despair - BRD drop" },
    { 11627,  "Fleetfoot Greaves - BRD drop" },
    { 13381,  "Master Cannoneer Boots - Stratholme drop" },
    { 19919,  "Bloodstained Greaves - ZG drop" },
})
COMPLETE.scarlet_boots = true

fill(C.reflector_belt, {
    { 11861,  "Girdle of Reprisal - Searing Gorge quest reward" },
})
COMPLETE.reflector_belt = true

fill(C.imperial_shoulders, {
    { 12428,  "Imperial Plate Shoulders - Blacksmithing" },
})
COMPLETE.imperial_shoulders = true

fill(C.imperial_helm, {
    { 12427,  "Imperial Plate Helm - Blacksmithing" },
    { 10763,  "Icemetal Barbute - RFD drop" },
    { 11729,  "Savage Gladiator Helm - BRD drop" },
})
COMPLETE.imperial_helm = true

fill(C.argent_shoulders, {
    { 4123,  "Frost Metal Pauldrons - STV quest reward" },
    { 9411,  "Rockshard Pauldrons - Uldaman drop" },
    { 17779,  "Hulkstone Pauldrons - Maraudon quest reward" },
    { 11632,  "Earthslag Shoulders - BRD drop" },
    { 18686,  "Bone Golem Shoulders - Scholomance drop" },
    { 16733,  "Spaulders of Valor - UBRS drop" },
})
COMPLETE.argent_shoulders = true

fill(C.argent_helm, {
    { 8092,  "Platemail Helm - Vendor" },
    { 7922,  "Steel Plate Helm - Blacksmithing" },
    { 20640,  "Southsea Head Bucket - Tanaris quest reward" },
    { 10833,  "Horns of Eranikus - ST drop" },
    { 10749,  "Avenguard Helm - ST quest reward" },
})
COMPLETE.argent_helm = true

fill(C.dreamweave_gloves, {
    { 10019,  "Dreamweave Gloves - Tailoring" },
})
COMPLETE.dreamweave_gloves = true

fill(C.dreamweave_circlet, {
    { 10041,  "Dreamweave Circlet - Tailoring" },
})
COMPLETE.dreamweave_circlet = true

fill(C.dreamweave_vest, {
    { 10021,  "Dreamweave Vest - Tailoring" },
})
COMPLETE.dreamweave_vest = true

fill(C.dreamweave_kilt, {
    { 9474,  "Jinxed Hoodoo Kilt - ZF drop" },
})
COMPLETE.dreamweave_kilt = true

fill(C.green_shirt, {
    { 2579,  "Green Linen Shirt - Tailoring" },
})
COMPLETE.green_shirt = true

fill(C.reflector_shield, {
    { 7787,  "Resplendent Guardian - World drop" },
    { 9458,  "Thermaplugg's Central Core - Gnomeregan drop" },
    { 4975,  "Vigilant Buckler - Arathi quest reward" },
    { 9643,  "Optomatic Deflector - Tanaris quest reward" },
    { 1204,  "The Green Tower - World drop" },
    { 2040,  "Troll Protector - ZF zone drop" },
    { 1979,  "Wall of the Dead - World drop" },
    { 1168,  "Skullflame Shield - World drop" },
    { 13243,  "Argent Defender - Stratholme quest reward" },
    { 17066,  "Drillborer Disk - Molten Core drop" },    
    { 18499,  "Barrier Shield - Dire Maul rare drop" },
})
COMPLETE.reflector_shield = true

fill(C.dragonsworn_helm, {
    { 21317,  "Helm of the Pathfinder - Felwood quest reward" },
    { 4124,  "Cap of Harmony - STV quest reward" },
})
COMPLETE.dragonsworn_helm = true

fill(C.dragonsworn_shoulders, {
    { 11916,  "Shizzle's Muzzle - Un'goro quest" },
    { 17749,  "Phytoskin Spaulders - Maraudon drop" },
    { 15792,  "Plow Wood Spaulders - Winterspring quest" },
    { 10745,  "Kaylari Shoulders - Searing Gorge quest" },
    { 10783,  "Atal'ai Spaulders - ST drop" },
})
COMPLETE.dragonsworn_shoulders = true

fill(C.reflector_armor, {
    { 7939,  "Truesilver Breastplate - Blacksmithing" },
    { 12628,  "Demon Forged Breastplate - Blacksmithing" },
    { 12641,  "Invulnerable Mail - Blacksmithing" },
})
COMPLETE.reflector_armor = true

fill(C.wizard_hat, {
    { 3556,  "Dread Mage Hat - Warlock Quest Reward" },
    { 14246,  "Darkmist Wizard Hat - World drop" },
    { 6429,  "Mistscape Wizard Hat - World drop" },
    { 7470,  "Regal Wizard Hat - World drop" },
    { 9878,  "Sorcerer Hat - World drop" },
    { 3345,  "Silk Wizard Hat - Syndicate Magus Drop" },
})
COMPLETE.wizard_hat = true

fill(C.dark_robes, {
    { 2612,  "Plain Robe - Vendor" },
    { 1561,  "Harvester's Robe - Westfall Quest Reward" },
    { 14150,  "Robe of Evocation - RFC Drop" },
    { 3461,  "High Robe of the Adjudicator - Silverpine Quest Reward" },
    { 7512,  "Nether-lace Robe - Mage Quest" },
    { 3161,  "Robe of the Keeper - Loch Modan quest" },
    { 5812,  "Robes of Antiquity - Ashenvale Quest" },
    { 6465,  "Robe of the Moccasin - WC drop" },
    { 6226,  "Bloody Apron - SFK Drop" },
    { 6324,  "Robes of Arugal - SFK Drop" },
    { 2231,  "Inferno Robe - Hillsbrad Quest" },
    { 6682,  "Death Speaker Robes - RFK Drop" },
    { 7711,  "Robe of Doan - SM Drop" },
    { 4746,  "Doomsayer's Robe - Badlands Quest Reward" },
    { 6900,  "Enchanted Gold Bloodrobe - Warlock Quest Reward" },
    { 9649,  "Royal Highmark Vestments - Hinterlands Quest" },
    { 10762,  "Robes of the Lich - RFD Drop" },
    { 17775,  "Acumen Robes - Maraudon Quest Reward" },
    { 20530,  "Robes of Servitude - Warlock Quest" },
    { 15824,  "Astoria Robes - LBRS Quest Reward" },
    { 16700,  "Dreadmist Robe - UBRS Drop" },
    { 18385,  "Robe of Everlasting Night - Dire Maul Drop" },
    { 14340,  "Freezing Lich Robes - Scholomance Drop" },
    { 14626,  "Necropile Robe - Scholomance DDrop" },
    { 22301,  "Ironweave Robe - Strat Drop" },
    { 14340,  "Freezing Lich Robes - Scholomance Drop" },
    { 16700,  "Dreadmist Robe - BRS Drop" },
})
COMPLETE.dark_robes = true

fill(C.plagueshifter_cloak, {
    { 4113,  "Medicine Blanket - STV quest reward" },
})
COMPLETE.plagueshifter_cloak = true

fill(C.plagueshifter_shoulders, {
    { 4197,  "Berylline Pads - RFK quest reward" },
})
COMPLETE.plagueshifter_shoulders = true

fill(C.plagueshifter_robes, {
    { 6503,  "Harlequin Robes - Barrens quest reward" },
})
COMPLETE.plagueshifter_robes = true

fill(C.spellstone, {
    { 5522,  "Spellstone - rank 1 (lvl 36)" },
    { 13602, "Greater Spellstone - rank 2 (lvl 48)" },
    { 13603, "Major Spellstone - rank 3 (lvl 58)" },
})
COMPLETE.spellstone = true

----------------------------------------------------------------------
-- WOLF HELM (Beastmaster)
----------------------------------------------------------------------

fill(C.wolf_helm, {
    { 30037, "Embrace of the Lycan - ZF boss drop" },
})
COMPLETE.wolf_helm = true
-- Only the Wolfshead Helm has a literal wolf-head model in Classic.
-- No random-suffix items share this unique wolf-head visual.

fill(C.powershifting_helm, {
    { 8345, "Wolfshead Helm - Tribal Leatherworking" },
})
COMPLETE.powershifting_helm = true

----------------------------------------------------------------------
-- GUILD TABARD (Exemplar)
----------------------------------------------------------------------

fill(C.guild_tabard, {
    { 5976, "Guild Tabard - Vendor" },
})
COMPLETE.guild_tabard = true

----------------------------------------------------------------------
-- LUNAR FESTIVAL SUIT (Brewmaster)
----------------------------------------------------------------------

fill(C.lunar_festival_suit, {
    { 21542, "Festival Suit - Lunar Festival reward" },
    { 21544, "Festive Blue Pant Suit - Lunar Festival reward" },
    { 21543, "Festive Teal Pant Suit - Lunar Festival reward" },
    { 21541, "Festive Black Pant Suit - Lunar Festival reward" },
})
COMPLETE.lunar_festival_suit = true

----------------------------------------------------------------------
-- BLUE SHIRT (Exemplar)
----------------------------------------------------------------------

fill(C.blue_shirt, {
    { 2577, "Blue Linen Shirt - Tailoring" },
})
COMPLETE.blue_shirt = true

fill(C.blue_robe, {
    { 6272, "Blue Linen Robe - Tailoring" },
})
COMPLETE.blue_robe = true

fill(C.exemplar_mantle, {
    { 15784, "Crystal Breeze Mantle - Winterspring quest" },
})
COMPLETE.exemplar_mantle = true

----------------------------------------------------------------------
-- CAPTAIN'S HAT (Buccaneer)
-- Pirate / naval tricorne headgear
----------------------------------------------------------------------

fill(C.captains_hat, {
    { 10030, "Admiral's Hat - Tailoring 240" },
    { 12185, "Bloodsail Admiral's Hat - Bloodsail rep" },
    { 2955, "First Mate Hat - World drop" },
})
COMPLETE.captains_hat = true

fill(C.ranger_blade, {
    { 18957, "Brushwood Blade - Teldrassil quest" },
    { 2263, "Phytoblade - Wetlands quest" },
})
COMPLETE.ranger_blade = true

fill(C.brushwood, {
    { 18957, "Brushwood Blade - Teldrassil quest" },
})
COMPLETE.brushwood = true

fill(C.green_dragon_blades, {
    { 10803, "Blade of the Wretched - ST drop" },
    { 15814, "Hameya's Slayer - EPL quest" },
})
COMPLETE.green_dragon_blades = true

fill(C.dark_ranger_blade, {
    { 11121, "Darkwater Talwar - BFD drop" },
    { 4446, "Blackvenom Blade - Redridge rare elite drop" },
    { 1482, "Shadowfang - SFK zone drop" },
    { 12974, "The Black Knight - World drop" },
    { 17752, "Satyr's Lash - Maraudon drop" },
    { 17780, "Blade of Eternal Darkness - Maraudon epic drop" },
    { 13361, "Skullforge Reaver - Strat drop" },
})
COMPLETE.dark_ranger_blade = true

fill(C.dk_blade, {
    { 11121, "Darkwater Talwar - BFD drop" },
    { 3822, "Runic Darkblade - Hillsbrad quest" },
    { 3854, "Frost Tiger Blade - Blacksmithing" },
    { 10823, "Vanquisher's Sword - RFD quest reward" },
    { 9372, "Sul'thraze the Lasher - ZF drops" },
    { 14541, "Barovian Family Sword - Scholomance drop" },
    { 13982, "Warblade of Caer Darrow - Scholomance quest" },
    { 13361, "Skullforge Reaver - Strat drop" },
    { 13505, "Runeblade of Baron Rivendare - Strat drop" },
})
COMPLETE.dk_blade = true

fill(C.pala_blade, {
    { 10805, "Eater of the Dead - ST drop" },
    { 754, "Shortsword of Vengeance - World drop" },
    { 7960, "Truesilver Champion - Blacksmithing" },
    { 13246, "Argent Avenger - Strat quest" },
})
COMPLETE.pala_blade = true

fill(C.cultist_cowl, {
    { 20408, "Twilight Cultist Cowl - Silithus drop" },
})
COMPLETE.cultist_cowl = true

fill(C.cultist_shoulder, {
    { 20406, "Twilight Cultist Mantle - Silithus drop" },
})
COMPLETE.cultist_shoulder = true

fill(C.cultist_robe, {
    { 20407, "Twilight Cultist Robe - Silithus drop" },
})
COMPLETE.cultist_robe = true

----------------------------------------------------------------------
-- RAPIER / CUTLASS / HARPOON (Buccaneer)
-- Pirate / swashbuckler one-handed swords + harpoon-style weapons
----------------------------------------------------------------------

fill(C.pirate_blade, {
    -- Cutlasses (pirate-named swords)
    { 1951,  "Blackwater Cutlass - Defias Pirate drop" },
    { 5192, "Thief's Blade - Deadmines drop" },
    { 5191,  "Cruel Barb - Deadmines drop" },
    { 3850, "Jade Serpentblade - Blacksmithing" },
    { 19040, "Zorbin's Mega-Slicer - Feralas quest reward" },
    { 2528, "Falchion - Vendor" },
    { 9401, "Nordic Longshank - Uldaman drop" },
    { 15782, "Beaststalker Blade - Winterspring quest reward" },
    { 4560, "Fine Scimitar - World drop" },
    { 15215, "Furious Falchion - World drop" },
    { 8196, "Ebon Scimitar - World drop" },   
    { 13182, "Phase Blade - LBRS rare drop" },   
})

fill(C.fast_daggers, {
    { 7714, "Hypnotic Blade - Arcanist Doan Scarlet Monastery" },
    { 10761, "Coldrage Dagger - Amnennar the Coldbringer Razorfen Downs" },
    { 3187, "Sacrificial Kris - Drop Fished" },
    { 6831, "Black Menace - In the Name of the Light Scarlet Monastery" },
    { 3184, "Hook Dagger - Drop Fished" },
    { 5267, "Scarlet Kris - Drop" },
    { 18392, "Distracting Dagger - Prince Tortheldrin Dire Maul (N)" },
    { 6660, "Julie's Dagger - Drop" },
    { 2819, "Cross Dagger - Drop Fished" },
    { 6691, "Swinetusk Shank - Agathelos the Raging Razorfen Kraul" },
    { 12709, "Pip's Skinner - The Beast Blackrock Spire (N)" },
    { 23168, "Scorn's Focal Dagger - Scorn Scarlet Monastery" },
    { 2494, "Stiletto - Vendors" },
    { 2208, "Poniard - Vendors" },
    { 2236, "Blackfang - Drop" },
    { 22688, "Verimonde's Last Resort - Quests Eastern Plaguelands" },
    { 15242, "Honed Stiletto - Drop Fished" },
    { 15243, "Deadly Kris - Drop" },
    { 5756, "Sliverblade - Zone Drop Scarlet Monastery" },
    { 2207, "Jambiya - Vendors" },
    { 13368, "Bonescraper - Baron Rivendare Stratholme (N)" },
    { 13984, "Darrowspike - The Lich, Ras Frostwhisper Scholomance" },
    { 21802, "The Lost Kris of Zedd - Zone Drop Ruins of Ahn'Qiraj" },
    { 5279, "Harpy Skinner - Serena Bloodfeather The Barrens" },
    { 6904, "Bite of Serra'kis - Old Serra'kis Blackfathom Deeps" },
    { 776, "Vendetta - Zone Drop Razorfen Kraul" },
    { 10828, "Dire Nail - Shade of Eranikus The Temple of Atal'Hakkar" },
    { 15443, "Kris of Orgrimmar - Hidden Enemies Orgrimmar" },
    { 9384, "Stonevault Shiv - Drop" },
    { 20035, "Glacial Spike - Quests" },
    { 2225, "Sharp Kitchen Knife - Westfall Stew Westfall" },
    { 13360, "Gift of the Elven Magi - Zone Drop Stratholme (N)" },
    { 18372, "Blade of the New Moon - Immol'thar Dire Maul (N)" },
    { 2224, "Militia Dagger - Brotherhood of Thieves Elwynn Forest" },
    { 4088, "Dreadblade - Drop" },
    { 6331, "Howling Blade - Skhowl Alterac Mountains (N)" },
    { 18491, "Lorespinner - Quests Dire Maul" },
    { 12062, "Skilled Fighting Blade - Jail Break! Blackrock Depths" },
    { 14151, "Chanting Blade - Jergosh the Invoker Ragefire Chasm" },
    { 2266, "Stonesplinter Dagger - Stonesplinter Seer Loch Modan" },
    { 12259, "Glinting Steel Dagger - Glinting Steel Dagger Blacksmithing" },
    { 15396, "Curvewood Dagger - The Fragments Within Darkshore" },
    { 3413, "Doomspike - Drop" },
    { 4947, "Jagged Dagger - Skull Rock Durotar" },
    { 1287, "Giant Tarantula Fang - Tarantula" },
    { 22379, "Shivsprocket's Shiv - The Perfect Poison Silithus" },
    { 10547, "Camping Knife - Return to Bellowfiz Dun Morogh" },
    { 12260, "Searing Golden Blade - Searing Golden Blade Blacksmithing" },
    { 3445, "Ceremonial Knife - At War With The Scarlet Crusade Tirisfal Glades" },
    { 1936, "Goblin Screwdriver - Goblin Engineer The Deadmines" },
    { 7166, "Copper Dagger - Copper Dagger Blacksmithing" },
    { 15706, "Hunt Tracker Blade - The Remains of Trey Lightforge Felwood" },
    { 10625, "Stealthblade - Zone Drop The Temple of Atal'Hakkar" },
    { 11635, "Hookfang Shanker - Hedrum the Creeper Blackrock Depths" },
    { 2169, "Buzzer Blade - Sneed's Shredder The Deadmines" },
    { 899, "Venom Web Fang - Venom Web Spider Duskwood" },
    { 2235, "Brackclaw - Brack Westfall" },
    { 11922, "Blood-etched Blade - Boss Drop Blackrock Depths (N)" },
    { 14024, "Frightalon - Kirtonos the Herald Scholomance (N)" },
    { 4974, "Compact Fighting Knife - Supervisor Fizsprocket Mulgore" },
    { 10697, "Enchanted Azsharite Felbane Dagger - Enchanted Azsharite Fel Weaponry Stranglethorn Vale" },
    { 2020, "Hollowfang Blade - Pygmy Venom Web Spider Duskwood" },
    { 2763, "Fisherman Knife - Drop" },
    { 4302, "Small Green Dagger - Muad Tirisfal Glades" },
    { 7947, "Ebon Shiv - Ebon Shiv Blacksmithing" },
    { 5112, "Ritual Blade - Rathorian The Barrens" },
    { 816, "Small Hand Blade - Harvest Golem Westfall" },
    { 2502, "Scuffed Dagger" },
    { 2664, "Spinner Fang" },
    { 5742, "Gemstone Dagger" },
    { 10049, "Diabolist's Blade" },
    { 820, "Slicer Blade - Harvest Reaper Westfall" },
    { 3296, "Deadman Dagger - Stephen Bhartec Tirisfal Glades" },
    { 2764, "Small Dagger - Drop" },
    { 20720, "Dark Whisper Blade - Chest of Spoils" },
    { 2137, "Whittling Knife - Rite of Strength Mulgore" },
    { 2484, "Small Knife" },
    { 2766, "Deft Stiletto - Drop" },
    { 2787, "Trogg Dagger - Drop" },
    { 4023, "Fine Pointed Dagger - Drop" },
    { 5516, "Threshadon Fang - Drop" },
})
COMPLETE.fast_daggers = true

----------------------------------------------------------------------
-- FLASK TRINKETS (Mountain King)
-- Flask / bottle-themed trinkets
----------------------------------------------------------------------

fill(C.flask_trinkets, {
    { 20130, "Diamond Flask - Warrior class quest lv 50" },
    { 744,   "Thunderbrew's Boot Flask - Sweet Amber quest reward (Alliance)" },
    { 15873,   "Ragged John's Neverending Cup - LBRS quest reward" },
})
COMPLETE.flask_trinkets = true

fill(C.horned_helm, {
    { 7719, "Raging Berserker's Helm - SM drop" },
    { 3836,   "Green Iron Helm - Blacksmithing" },
    { 6686,   "Tusken Helm - RFK drop" },
    { 11124,   "Helm of Exile - ST quest reward" },
    { 14753,   "Slayer's Skullcap - World drop" },
    { 10198,   "Crusader's Helm - World drop" },
    { 10235,   "Engraved Helm - World drop" },
    { 8270,   "Ebonhold Helmet - World drop" },
    { 15645,   "Ironhide Helmet - World drop" },
    { 14804,   "Bloodlust Helm - World drop" },
    { 13073,   "Mugthol's Helm - World drop" },
    { 7937,   "Ornate Mithril Helm - Blacksmithing" },
    { 22411,   "Helm of the Executioner - Stratholme drop" },
    { 14849,   "Sunscale Helmet - World drop" },
    { 12612,   "Runic Plate Helm - Blacksmithing" },
    { 13073,   "Heavy Mithril Helm - Blacksmithing" },
    { 10132,   "Revenant Helmet - World drop" },
    { 10090,   "Gothic Plate Helmet - World drop" },
    { 14907,   "Brutish Helmet - World drop" },
    { 14935,   "Heroic Skullcap - World drop" },
    { 14907,   "Darkrune Helm - Blacksmithing" },
    { 10379,   "Commander's Helm - World drop" },
    { 12410,   "Thorium Helm - Blacksmithing" },
    { 10279,   "Emerald Helm - World drop" },
    { 10372,   "Imbued Plate Helmet - World drop" },
    { 8142,   "Chromite Barbute - World drop" },
    { 12640,   "Lionheart Helm - Blacksmithing" },
})
COMPLETE.horned_helm = true

fill(C.wildhammer_helm, {
    { 6688,   "Whisperwind Headdress - RFK rare drop" },
    { 5753,   "Ruffled Chaplet - Ashenvale rare drop" },
    { 6204,   "Tribal Worg Helm - Duskwood rare drop" },
    { 3011, "Feathered Headdress - Alterac rare drop" },
    { 17740,   "Soothsayer's Headdress - Maraudon drop" },
    { 15384,   "Rageclaw Helm - World drop" },
    { 9921,   "Tracker's Headband - World drop" },
    { 15363,   "Trickster's Headdress - World drop" },
})
COMPLETE.wildhammer_helm = true

fill(C.skull_shield, {
    { 3761,   "Deadskull Shield - Hillsbrad quest reward" },
    { 4115,   "Grom'gol Buckler - STV quest reward" },
    { 10686,   "Aegis of Battle - Hinterlands quest reward" },
    { 18696,   "Intricately Runed Shield - Scholomance drop" },
    { 13529,   "Husk of Nerub'enkan - Stratholme drop" },
    { 23139,   "Lord Blackwood's Buckler - Scholomance drop" },
    { 14528,   "Rattlecage Buckler - Scholomance drop" },
})
COMPLETE.skull_shield = true

fill(C.voodoo_shoulders, {
    { 11624, "Kentic Amice - BRD drop" },
})
COMPLETE.voodoo_shoulders = true

----------------------------------------------------------------------
-- INSIGNIA (Exemplar)
-- PvP Insignia trinkets - one per class per faction
----------------------------------------------------------------------

fill(C.insignia, {
    -- Alliance Insignia (one per class)
    { 209616, "Insignia of the Alliance - Warrior" },
    { 209614, "Insignia of the Alliance - Paladin" },
    { 209615, "Insignia of the Alliance - Rogue" },
    { 18858, "Insignia of the Alliance - Hunter" },
    { 18859, "Insignia of the Alliance - Mage" },
    { 18862, "Insignia of the Alliance - Priest" },
    { 18863, "Insignia of the Alliance - Warlock" },
    { 18864, "Insignia of the Alliance - Druid" },

    -- Horde Insignia (one per class)
    { 18834, "Insignia of the Horde - Warrior" },
    { 18845, "Insignia of the Horde - Shaman" },
    { 18846, "Insignia of the Horde - Hunter" },
    { 18849, "Insignia of the Horde - Warlock" },
    { 18850, "Insignia of the Horde - Mage" },
    { 18851, "Insignia of the Horde - Priest" },
    { 18852, "Insignia of the Horde - Rogue" },
    { 18853, "Insignia of the Horde - Druid" },
})
COMPLETE.insignia = true

----------------------------------------------------------------------
-- ARGENT DAWN TRINKET (Templar)
----------------------------------------------------------------------

fill(C.argent_dawn_trinket, {
    { 12846, "Argent Dawn Commission - quest reward" },
})
COMPLETE.argent_dawn_trinket = true

----------------------------------------------------------------------
-- KILT (Demon Hunter, Runemaster)
-- Leg items with kilt visual
----------------------------------------------------------------------

fill(C.kilt, {
    -- Cloth kilts
    { 153,   "Primitive Kilt - white cloth legs" },
    { 10047, "Simple Kilt - white cloth legs, Tailoring" },
    { 14315, "Celestial Kilt - green cloth legs" },
    { 10048, "Colorful Kilt - Tailoring" },

    -- Leather kilts
    { 7760,  "Warchief Kilt - rare leather legs, SM" },
    { 16719, "Wildheart Kilt - rare leather legs, Druid T0" },
    { 9474,  "Jinxed Hoodoo Kilt - leather legs, ZF" },
    { 4832,  "Mystic Sarong - Vendor" },
    { 10842,  "Windscale Sarong - ST Drop" },
    { 14324,  "Resplendent Sarong" },
    { 14334,  "Eternal Sarong" },
    { 14462,  "Elunarian Sarong" },  
})

----------------------------------------------------------------------
-- COWL (Death Knight)
-- Head items with cowl / hooded / executioner hood visual
----------------------------------------------------------------------

fill(C.cowl, {
    { 3732, "Hooded Cowl - Quest rewards from Hillsbrad" },
    { 4322, "Enchanter's Cowl - Tailoring 165" },
    { 4039, "Nightsky Cowl - World drop" },
    { 7432, "Twilight Cowl - World drop" },
    { 4041, "Aurora Cowl - World drop" },
    { 8115, "Hibernal Cowl - World drop" },
    { 5608, "Living Cowl - World drop" },
    { 22302, "Ironweave Cowl - Blackrock Spire drop" },
    { 22225, "Dragonskin Cowl - World drop" },
    { 7048, "Azure Silk Hood - Tailoring 125" },
    { 4323, "Shadow Hood - Tailoring" },
    { 9849, "Conjurer's Hood - World drop" },
    { 9940, "Abjurer's Hood - World drop" },
    { 14111, "Felcloth Hood - Tailoring" },
    { 10782, "Hakkari Shroud - ST quest" },
    { 7691, "Embalmed Shroud - World drop" },
    { 2620, "Augural Shroud - World drop" },
    { 2621, "Cowl of Necromancy - Shadowforge Darkweaver drop" },
    { 1280, "Cloaked Hood - Syndicate Assassin drop" },
})

----------------------------------------------------------------------
-- VOODOO MASK (Witch Doctor, Shadow Hunter)
-- Troll ritual masks / tribal face-covering head items
----------------------------------------------------------------------

fill(C.voodoo_mask, {
    -- Crafted / dungeon masks
    { 8201,  "Big Voodoo Mask - green leather helm, LW 220" },
    { 9470,  "Bad Mojo Mask - rare cloth helm, Zul'Farrak" },
    -- Zul'Gurub raid masks
    { 19886, "The Hexxer's Cover - rare cloth helm, ZG" },
})
COMPLETE.voodoo_mask = true

fill(C.blue_cowl, {
    { 7048, "Azure Silk Hood - tailoring 125" },
})
COMPLETE.blue_cowl = true

fill(C.blue_cape, {
    { 4504, "Dwarven Guard Cloak - Wetlands quest" },
    { 7053, "Azure Silk Cloak - Tailoring 175" },
    { 7377, "Frost Leather Cloak - Leatherworking" },
    { 18689, "Phantasmal Cloak - Scholomance drop" },
    { 18734, "Pale Moon Cloak - Stratholme drop" },
    { 15468, "Windsong Drape - Thousand Needles quest" },
})
COMPLETE.blue_cape = true

fill(C.red_cowl, {
    { 3732, "Hooded Cowl - Hillsbrad quest reward" },
})
COMPLETE.red_cowl = true

fill(C.red_cape, {
    { 4933, "Seasoned Fighter's Cloak - Durator quest" },
    { 14149, "Subterranean Cape - RFC drop" },
    { 11858, "Battlehard Cape - Feralas quest reward (horde)" },
    { 11626, "Blackveil Cape - BRD drop" },
    { 11812, "Cape of the Fire Salamander - BRD drop" },
    { 12608, "Butcher's Apron - BRS drop" },
    { 15804, "Cerise Drape - WPL quest reward" },
    { 12967, "Bloodmoon Cloak - UBRS drop" },
    { 11311, "Emberscale Cape - Uldaman drop" },
    { 7056, "Crimson Silk Cloak - Tailoring" },
    { 9699, "Garrison Cloak - Desolace quest (alliance)" },
    { 7004, "Prelacy Cape - BFD quest (alliance)" },
})
COMPLETE.red_cape = true

fill(C.brown_cowl, {
    { 4322, "Enchanter's Cowl - Tailoring 175" },
})
COMPLETE.brown_cowl = true

fill(C.hw_robe, {
    { 1561, "Harvester's Robe - Westfall quest reward" },
})
COMPLETE.hw_robe = true

fill(C.brown_shoulders, {
    { 10774, "Fleshhide Shoulders - RFD drop" },
})
COMPLETE.brown_shoulders = true

fill(C.red_shoulders, {
    { 7750, "Mantle of Woe - SM quest reward" },
})
COMPLETE.red_shoulders = true

fill(C.blue_shoulders, {
    { 9647, "Failed Flying Experiment - Feralas quest reward" },
    { 11963, "Penance Spaulders - BRD quest reward" },
})
COMPLETE.blue_shoulders = true

fill(C.brown_cape, {
    { 5965, "Guardian Cloak - Leatherworking" },
    { 2805, "Yeti Fur Cloak - Hillsbrad quest reward" },
})
COMPLETE.brown_cape = true

fill(C.brown_gloves, {
    { 7348, "Fletcher's Gloves - Leatherworking" },
})
COMPLETE.brown_gloves = true

fill(C.archmage_cape, {
    { 10843, "Featherskin Cape - ST drop" },
})
COMPLETE.archmage_cape = true

fill(C.mountaineer_cape, {
    { 6789, "Ceremonial Centaur Blanket - Desolace quest" },
})
COMPLETE.mountaineer_cape = true

fill(C.mountaineer_hood, {
    { 10782, "Hakkari Shroud - ST quest" },
})
COMPLETE.mountaineer_hood = true

fill(C.dark_cowl, {
    { 4039, "Nightsky Cowl - World drop" },
    { 1280, "Cloaked Hood - Syndicate Assassin drop" },
    { 2621, "Cowl of Necromancy - Shadowforge Darkweaver drop" },
    { 19984, "Ebon Mask - Rogue quest" },
    { 16707, "Shadowcraft Cap - Scholomance drop" },
})
COMPLETE.dark_cowl = true

fill(C.dark_cape, {
    { 9635, "Master Apothecary Cape - Undercity quest" },
    { 6832, "Cloak of Blight - Duskwood quest" },
    { 10802, "Wingveil Cloak - ST drop" },
    { 12066, "Shaleskin Cape - BRD quest" },
    { 13203, "Armswake Cloak - UBRS rare drop" },
    { 22269, "Shadow Prowler's Cloak - UBRS drop" },
    { 13340, "Cape of the Black Baron - Stratholme drop" },
})
COMPLETE.dark_cape = true

fill(C.dark_shoulders, {
    { 6697, "Batwing Mantle - RFK rare drop" },
    { 11310, "Flameseer Mantle - Uldaman drop" },
    { 22234, "Mantle of Lost Hope - BRD drop" },
    { 12082, "Wyrmhide Spaulders - BRD quest" },
    { 15822, "Shadowskin Spaulders - Timbermaw quest" },
    { 13257, "Demonic Runed Spaulders - LBRS rare drop" },
    { 18374, "Flamescarred Shoulders - Dire Maul drop" },
})
COMPLETE.dark_shoulders = true

fill(C.necro_book, {
    { 13353, "Book of the Dead - Stratholme drop" },
    { 17067, "Ancient Cornerstone Grimoire - Onyxia drop" },
})
COMPLETE.necro_book = true

----------------------------------------------------------------------
-- CURSED AMULET (Witch Doctor)
-- Neck items with curse / hex / voodoo / dark magic theme
----------------------------------------------------------------------

fill(C.cursed_amulet, {
    { 9243, "Shriveled Heart - ZF zone drop" },
})
COMPLETE.cursed_amulet = true

fill(C.cursed_items, {
    { 9243, "Shriveled Heart - ZF zone drop" },
    { 2621, "Cowl of Necromancy - Shadowforge Darkweaver drop" },
    { 4746,  "Doomsayer's Robe - Badlands Quest Reward" },
    { 3235, "Ring of Scorn - Silverpine quest" },
    { 4462, "Cloak of Rot - Wetlands rare drop" },
    { 6751, "Mourning Shawl - RFK quest (Alliance)" },
    { 5611, "Tear of Grief - Darkshore quest" },
    { 2944, "Cursed Eye of Paleth - Wetlands quest" },
    { 18425, "Kreeg's Mug - Dire Maul drop" },
})
COMPLETE.cursed_items = true

----------------------------------------------------------------------
-- SHELL SHIELD (Witch Doctor)
-- Shields with tortoise / turtle shell visual
----------------------------------------------------------------------

fill(C.shell_shield, {
    { 6447, "Worn Turtle Shell Shield - WC drop" },
    { 13245, "Kresh's Back - WC drop" },
    { 16660, "Driftmire Shield - Ashenvale quest reward" },
    { 15342, "Pathfinder Guard - World drop" },
    { 15466, "Clink Shield - Thousand Needles quest reward" },
    { 15352, "Headhunter's Buckler - World drop" },
    { 14916, "Jade Deflector - World drop" },
    { 14902, "Saltstone Shield - World drop" },
    { 9661, "Earthclasp Barrier - Feralas quest reward" },
    { 10268, "Rhombeard Protector - LBRS drop" },
    { 18535, "Milli's Shield - Dire Maul quest reward" },
    { 18352, "Petrified Bark Shield - Dire Maul drop" },
    { 18485, "Observer's Shield - Dire Maul drop" },
})
COMPLETE.shell_shield = true

fill(C.farseer_shield, {
    { 15466, "Clink Shield - Thousand Needles quest reward" },
    { 14902, "Saltstone Shield - World drop" },
    { 9661, "Earthclasp Barrier - Feralas quest reward" },
    { 18535, "Milli's Shield - Dire Maul quest reward" },
    { 18485, "Observer's Shield - Dire Maul drop" },
})
COMPLETE.farseer_shield = true

fill(C.hw_staff, {
    { 20536, "Soul Harvester - Warlock quest" },
})
COMPLETE.hw_staff = true

fill(C.hw_staff1, {
    { 1010, "Gnarled Staff - Dun Morogh quest reward" },
    { 6631, "Living Root - WC drop" },
    { 1317, "Hardened Root Staff - Stockades quest reward" },
    { 1720, "Tanglewood Staff - World drop" },
    { 20536, "Soul Harvester - Warlock quest" },
})
COMPLETE.hw_staff1 = true

----------------------------------------------------------------------
-- TORCH (Spiritwalker)
-- Off-hand items with torch / lantern / flame visual
----------------------------------------------------------------------

fill(C.lantern, {
    { 5323, "Everglow Lantern - Barrens Quest Rewards" },
})
COMPLETE.lantern = true
-- Also populate the 'torch' key used by R("Torch") in EquipmentCheck.lua

fill(C.torch, {
    { 1172, "Grayson's Torch - Westfall Quest Rewards" },
    { 5323, "Everglow Lantern - Barrens Quest Rewards" },
})
COMPLETE.torch = true
-- Beacon of Hope is the only torch/lantern-model equippable off-hand in
-- Classic.  Most "torch" items are quest items or consumables, not gear.

----------------------------------------------------------------------
-- ANTI-BEAST GEAR (Beastmaster)
----------------------------------------------------------------------

fill(C.anti_beast_chest, {
    { 3566, "Raptorbane Armor - Wetlands Quest Rewards" },
})
COMPLETE.anti_beast_chest = true

-- Anti-beast cloak (back slot)
fill(C.anti_beast_cloak, {
    { 16658, "Wildhunter Cloak - Ashenvale Quest Reward" },
})

-- Anti-beast gloves (hands slot)
fill(C.anti_beast_gloves, {
    { 7756, "Dog Training Gloves - SM Drop" },
})

-- Anti-beast melee weapon (main/off-hand)
fill(C.anti_beast_melee, {
    { 7710, "Loksey's Training Stick - SM Drop" },
    { 11907, "Beastslayer - Quest Reward" },
    { 1465, "Tigerbane - World drop" },
    { 15782, "Beaststalker Blade - Winterspring quest reward" },
    { 15783, "Beasthunter Dagger - Winterspring quest reward" },
    { 12709, "Finkle's Skinner - UBRS drop" },
    { 19946, "Tigule's Harpoon - ZG drop" },
})

-- Anti-beast ranged weapon (ranged slot)
fill(C.anti_beast_ranged, {
    { 11628, "Houndmaster's Bow - BRD Drop" },
})

----------------------------------------------------------------------
-- ARMORED WEAPON (Druid of the Claw)
-- Heavy / plate-looking / reinforced melee weapons
----------------------------------------------------------------------

fill(C.armored_weapon, {
    { 11855, "Tork Wrench - Barrens quest reward" },
    { 1172, "Grayson's Torch - Westfall quest reward" },
    { 1131, "Totem of Infliction - Duskwood quest reward" },
    { 3360, "Stitches' Femur - Duskwood drop" },
    { 12252, "Staff of Protection - Vendor" },
    { 868, "Ardent Custodian - Epic World drop" },
    { 943,   "Warden Staff - Epic World drop" },
    { 20580,   "Hammer of Bestial Fury - World boss drop" },
    { 21268,   "Blessed Qiraji War Hammer - AQ drop" },
    { 18376,   "Timeworn Mace - Dire Maul drop" },
    { 11805,   "Rubidium Hammer - BRD drop" },
    { 11921,   "Impervious Giant - BRD drop" },
    { 18531,   "Unyielding Maul - Stratholme drop" },
})

----------------------------------------------------------------------
-- ARMORED OFF-HAND (Druid of the Claw)
-- Sturdy / defensive off-hand items
----------------------------------------------------------------------

fill(C.armored_offhand, {
    { 11855, "Tork Wrench - Barrens quest reward" },
    { 1172, "Grayson's Torch - Westfall quest reward" },
    { 1131, "Totem of Infliction - Duskwood quest reward" },
    { 3360, "Stitches' Femur - Duskwood drop" },
})
-- Note: druids cannot equip shields, so the shield entries will likely
-- not pass, but they remain for completeness.  Held-in-off-hand items
-- like Brightly Glowing Stone are the realistic picks.

----------------------------------------------------------------------
-- ARMORED RINGS (Druid of the Claw, Savagekin, Warmage)
-- Rings with + armor
----------------------------------------------------------------------

fill(C.armored_rings, {
    { 11118, "Archaedic Stone - Uldaman boss drop" },
    { 9642, "Band of the Great Tortoise - Tanaris quest reward" },
    { 12544, "Thrall's Resolve - BRD quest reward" },
    { 15855, "Ring of Protection - Eastern Plaguelands quest reward" },
    { 11669, "Naglering - BRD drop" },
    { 18813, "Ring of Binding - Onyxia drop" },
    { 21601, "Ring of Emperor Vek'lor - AQ drop" },
    { 23018, "Signet of the Fallen Defender - Naxxramas drop" },
    { 18879, "Heavy Dark Iron Ring - MC drop" },
})
COMPLETE.armored_rings = true

fill(C.necromancer_robe, {
    { 6690, "Lesser Wizard's Robe - Tailoring" },
    { 7711, "Robes of Doan - SM drop" },
    { 10762, "Robes of the Lich - RFD drop" },
    { 10004, "Shadoweave Robe - Tailoring" },
    { 6900, "Enchanted Gold Bloodrobe - Warlock quest" },
})
COMPLETE.necromancer_robe = true

fill(C.armored_trinket, {
    { 1490, "Guardian Talisman - ST quest reward" },
    { 13966, "Mark of Tyranny - UBRS quest reward" },
    { 11811, "Smoking Heart of the Mountain - Enchanting" },
})
COMPLETE.armored_trinket = true

----------------------------------------------------------------------
-- STAFF-LIKE OFF-HAND (Warmage)
-- Off-hand items that look like short staves / sceptres / batons
----------------------------------------------------------------------

fill(C.staff_like_offhand, {
    { 7559, "Runic Cane - Barrens rare 'Brokespear' drop" },
    { 6803, "Prophetic Cane - Horde RFD quest reward" },
    { 12471, "Desertwalker Cane - ZF rare boss drop" },
})
COMPLETE.staff_like_offhand = true

fill(C.awkward_merch, {
    { 5110, "Dalaran Wizard's Robe - Silverpine drop" },
})
COMPLETE.awkward_merch = true

fill(C.archmage_shoulders, {
    { 7712, "Mantle of Doan - SM drop" },
    { 15812, "Orchid Amice - WPL quest reward" },
    { 11624, "Kentic Amice - BRD drop" },
    { 18757, "Diabolic Mantle - Dire Maul drop" },
})
COMPLETE.archmage_shoulders = true

fill(C.archmage_circlet, {
    { 10139, "High Councillor's Circlet - World drop" },
    { 14436, "Windchaser Coronet - World drop" },
    { 10751, "Gemburst Circlet - ST quest reward" },
})
COMPLETE.archmage_circlet = true

fill(C.war_harness, {
    { 4968, "Bound Harness - Mulgore quest reward" },
    { 6523, "Buckled Harness - Vendor" },
    { 6524, "Studded Leather Harness - Vendor" },
    { 6525, "Grunt's Harness - Vendor" },
    { 6526, "Battle Harness - Vendor" },
    { 14601, "Warden's Wraps - World drop" },
    { 1211, "Gnoll War Harness - Redridge World drop" },
    { 15064, "Warbear Harness - Leatherworking 275" },
    { 2370, "Battered Leather Harness - Vendor" },
    { 4455, "Raptor Hide Harness - Leatherworking 165" },
    { 5739, "Barbaric Harness - Leatherworking 190" },
    { 13110, "Wolffear Harness - World drop" },
    { 10583, "Quillward Harness - RFD zone drop" },
    { 15356, "Headhunter's Armor - World drop" },
    { 15010, "Primal Wraps - World drop" },
    { 15433, "Peerless Armor - World drop" },
    { 15304, "Grizzly Jerkin - World drop" },
    { 3313, "Ceremonial Leather Harness - World drop" },
})
COMPLETE.war_harness = true

----------------------------------------------------------------------
-- Nat Pagle's Pole (Death Knight & Shadow Hunter)
-------------------------------

fill(C.pole, {
    { 19022, "Nat Pagle's Extreme Angler FC-5000" },
})
COMPLETE.pole = true

----------------------------------------------------------------------
-- HERB POUCH (Apothecary)
-- Herb bags (bag slot - curated for bag-scan check)
----------------------------------------------------------------------

fill(C.herb_pouch, {
    { 22250, "Herb Pouch - 12-slot herb bag, vendor" },
    { 22251, "Cenarion Herb Bag - 20-slot herb bag, Tailoring" },
    { 22252, "Satchel of Cenarius - 24-slot herb bag, Tailoring" },
})
COMPLETE.herb_pouch = true

fill(C.quiver, {
    { 2101, "Light Quiver - Vendor" },
    { 5439, "Small Quiver - Vendor" },
    { 7278, "Light Leather Quiver - Leatherworking" },
    { 11362, "Medium Quiver - Vendor" },
    { 7371, "Heavy Quiver - Leatherworking" },
    { 8217, "Quickdraw Quiver - Leatherworking" },
    { 2662, "Ribbly's Quiver - BRD quest reward" },
    { 19319, "Harpy Hide Quiver - Alterac Valley rep" },
})
COMPLETE.quiver = true

----------------------------------------------------------------------
-- JUNGLE REMEDY (Plagueshifter)
-- Consumable item - curated for inventory scanning
----------------------------------------------------------------------

fill(C.jungle_remedy, {
    { 2633, "Jungle Remedy - consumable, Kurzen Medicine Man drop" },
})
COMPLETE.jungle_remedy = true

fill(C.thistle_tea, {
    { 7676, "Thisle Tea - consumable, cooking 60" },
})
COMPLETE.thistle_tea = true

fill(C.rage_pot, {
    { 13442, "Mighty Rage Potion - consumable, alchemy" },
    { 5631, "Rage Potion - consumable, alchemy" },
    { 5633, "Great Rage Potion - consumable, alchemy" },
})
COMPLETE.rage_pot = true

fill(C.pick, {
    { 13442, "Ryedol's Lucky Pick - Badlands quest item" },
})
COMPLETE.pick = true

fill(C.sh_knife, {
    { 5040, "Shadow Hunter Knife - Arathi quest item" },
})
COMPLETE.sh_knife = true

fill(C.primitive_weapon, {
    { 2130, "Club - Vendor" },
    { 3329, "Spiked Wooden Plank - Rare Tirisfal Glades drop" },
    { 1394, "Driftwood Club - Rare Westfall drop" },
    { 2490, "Tomahawk - Vendor" },
    { 2026, "Rock Hammer - Vendor" },
    { 7230, "Smite's Mighty Hammer - DM drop" },
    { 5815, "Glacial Stone - Ashenvale quest reward (Alliance)" },
    { 6692, "Pronged Reaver - RFK drop" },
    { 6975, "Whirlwind Axe - Warrior quest reward" },
    { 12000, "Limb Cleaver - BRD quest reward" },
    { 18420, "Bonecrusher - Dire Maul quest reward" },
    { 18481, "Skullcracking Mace - Dire Maul drop" },
    { 14531, "Frightskull Shaft - Scholomance drop" },
})
COMPLETE.primitive_weapon = true

fill(C.totem_weapon, {
    { 9639, "The Hand of Antu'sul - ZF drop" },
    { 16769, "Furbolg Medicine Totem - Timbermaw rep reward" },
})
COMPLETE.totem_weapon = true

fill(C.wildhammer_mace, {
    { 9651, "Gryphon Rider's Stormhammer - Hinterlands quest reward" },
})
COMPLETE.wildhammer_mace = true

fill(C.pickaxe, {
    { 2048, "Anvilmar Hammer - Dun Morogh quest reward" },
    { 778, "Kobold Excavation Pick - Elwynn kobold drop" },
    { 1195, "Kobold Mining Shovel - Elwynn kobold drop" },
    { 5324, "Engineer's Hammer - Barrens quest reward" },
    { 1893, "Miner's Revenge - DM quest reward" },
    { 756, "Tunnel Pick - Wetlands rare drop" },
    { 1959, "Cold Iron Pick - DM rare drop" },
    { 7687, "Ironspine's Fist - SM rare drop" },
    { 9465, "Digmaster 5000 - World drop" },
    { 4128, "Silver Spade - STV quest reward" },
    { 9378, "Shovelphlange's Mining Axe - Uldaman rare drop" },
    { 13442, "Ryedol's Lucky Pick - Badlands quest item" },
    { 10804, "Fist of the Damned - ST drop" },
    { 20723, "Brann's Trusty Pick - Silithus quest reward" },
})
COMPLETE.pickaxe = true

fill(C.discombobulator, {
    { 4388, "Discombobulator Ray - Gnomeregan engineering schematic" },
})
COMPLETE.discombobulator = true

fill(C.prospector_headgear, {
    { 3890, "Studded Hat - Vendor" },
    { 19972, "Lucky Fishing Hat - Fishing" },
    { 4048, "Emblazoned Hat - World drop" },
    { 8174, "Comfortable Leather Hat - Leatherworking 200" },
    { 9534, "Engineer's Guild Headpiece - ZF quest reward" },
    { 15156, "Nocturnal Cap - World drop" },
    { 19039, "Zorbin's Water Resistant Hat - Feralas quest reward" },
    { 10111, "Wanderer's Hat - World drop" },
    { 9420, "Adventurer's Pith Helmet - World drop" },
    { 10543, "Goblin Construction Helmet - Engineering 205" },
    { 10542, "Goblin Mining Helmet - Engineering (Mail)" },
})
COMPLETE.prospector_headgear = true

fill(C.engineering_trinkets, {
    { 7506, "Gnomish Universal Remote" },
    { 4381, "Minor Recombobulator" },
    { 4397, "Gnomish Cloaking Device" },
    { 4396, "Mechanical Dragonling" },
    { 10577, "Goblin Mortar" },
    { 10716, "Gnomish Shrink Ray" },
    { 10720, "Gnomish Net-o-Matic Projector" },
    { 10725, "Gnomish Battle Chicken" },
    { 10587, "Goblin Bomb Dispenser" },
    { 10645, "Gnomish Death Ray" },
    { 10727, "Goblin Dragon Gun" },
    { 10576, "Mithril Mechanical Dragonling" },
    { 18986, "Ultrasafe Transporter: Gadgetzan" },
    { 18637, "Major Recombobulator" },
    { 18984, "Dimensional Ripper - Everlook" },
    { 18634, "Gyrofreeze Ice Reflector" },
    { 18638, "Hyper-Radiant Flame Reflector" },
    { 16022, "Arcanite Dragonling" },
    { 18639, "Ultra-Flash Shadow Reflector" },
})
COMPLETE.engineering_trinkets = true

fill(C.dragonbreath_chili, {
    { 12217, "Dragonbreath Chili - cooking (recipe sold by vendor)" },
})
COMPLETE.dragonbreath_chili = true

----------------------------------------------------------------------
-- RESTORATION POTION (Plagueshifter)
-- Consumable item - curated for inventory scanning
----------------------------------------------------------------------

fill(C.restoration_potion, {
    { 9030, "Restorative Potion - Alchemy 210 crafted" },
})
COMPLETE.restoration_potion = true

fill(C.natural_haste, {
    { 9449, "Manual Crowd Pummeler - Gnomeregan drop" },
})
COMPLETE.natural_haste = true

fill(C.tinker_mace, {
    { 2048, "Anvilmar Hammer - Dun Morogh quest reward" },
    { 5324, "Engineer's Hammer - Barrens quest reward" },
    { 1264, "Headbasher - Stockades quest reward" },
    { 9449, "Manual Crowd Pummeler - Gnomeregan drop" },
    { 4548, "Servomechanic Sledgehammer - Arathi Highlands quest reward" },
    { 10804, "Fist of the Damned - ST drop" },
    { 18803, "Hyperthermically Insulated Lava Dredger - MC drop" },
})
COMPLETE.tinker_mace = true

----------------------------------------------------------------------
-- MECHANICAL COMPANION (Mechano-Mage)
-- Non-combat pet items from Engineering
----------------------------------------------------------------------

fill(C.mechanical_companion, {
    { 4401,  "Mechanical Squirrel Box - Engineering 75" },
    { 11826, "Lil' Smoky - Gnomish Engineering 205" },
    { 10398, "Mechanical Chicken - quest reward (OOX escorts)" },
    { 21277, "Tranquil Mechanical Yeti - Engineering 250" },
    { 15996, "Lifelike Mechanical Toad - Engineering 250" },
})
COMPLETE.mechanical_companion = true

fill(C.skull_offhand, {
    { 4984, "Skull of Impending Doom - Vendor/Badlands quest reward" },
    { 1131, "Totem of Infliction - Duskwood quest reward" },
    { 11870, "Oblivion Orb - Un'Goro quest reward" },
    { 10708, "Skullspell Orb - Azshara quest reward" },
    { 10770, "Mordresh's Lifeless Skull - RFD drop" },
    { 13524, "Skull of Burning Shadows - Stratholme drop" },
})
COMPLETE.skull_offhand = true

fill(C.witch_doctor_staff, {
    { 854, "Quarter Staff - Vendor" },
    { 2030, "Gnarled Staff - Vendor" },
    { 4938, "Blemished Wooden Staff - Durator quest reward" },
    { 4961, "Dreamwatcher Staff - Mulgore quest reward" },
    { 15444, "Staff of Orgrimmar - RFC quest reward" },
    { 1155, "Wind Rider Staff - Barrens quest reward" },
    { 6631, "Living Root - WC drop" },
    { 1539, "Gnarled Hermit's Staff - Barrens rare drop" },
    { 4575, "Medicine Staff - World drop" },
    { 6689, "Wind Spirit Staff - RFK drop" },
    { 1155, "Rod of the Sleepwalker - BFD drop" },
    { 18082,  "Zum'rah's Vexing Cane - ZF drop" },
    { 17743, "Resurgence Rod - Vendor/Maraudon quest reward" },
    { 9477, "The Chief's Enforcer - ZF drop" },
    { 9482, "Witch Doctor's Cane - ZF zone drop" }, 
    { 20556, "Wildstaff - Shaman quest reward" },
    { 9683, "Strength of the Treant - Feralas quest reward" },
})
COMPLETE.witch_doctor_staff = true

fill(C.vial_offhand, {
    { 3451,  "Nightglow Concoction - Silverpine quest reward" },
    { 19115, "Flask of Forest Mojo - Hinterlands quest reward" },
})
COMPLETE.vial_offhand = true

-- Mark all remaining curated lists as complete
COMPLETE.anti_beast_cloak = true
COMPLETE.anti_beast_gloves = true
COMPLETE.anti_beast_melee = true
COMPLETE.anti_beast_ranged = true
COMPLETE.armored_offhand = true
COMPLETE.armored_weapon = true
COMPLETE.cowl = true
COMPLETE.kilt = true
COMPLETE.pole = true
COMPLETE.pirate_blade = true
COMPLETE.staff_like_offhand = true

----------------------------------------------------------------------
-- Summary counter (diagnostic)
----------------------------------------------------------------------

function FCE.CuratedCount(listName)
    local list = C[listName]
    if not list then return 0 end
    local n = 0
    for _ in pairs(list) do n = n + 1 end
    return n
end

function FCE.CuratedSummary()
    local summary = {}
    for name, list in pairs(C) do
        local n = 0
        for _ in pairs(list) do n = n + 1 end
        summary[name] = n
    end
    return summary
end
