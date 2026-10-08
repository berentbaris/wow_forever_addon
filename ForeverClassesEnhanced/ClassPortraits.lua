----------------------------------------------------------------------
-- ForeverClassesEnhanced — Class Background Art
--
-- Maps each enhanced class to a background image (talent-tree style).
-- Images are .tga files in the Backgrounds/ subfolder of the addon.
--
-- WoW requires .tga (or .blp) for addon textures.
-- Recommended dimensions: 256 x 256 pixels (or 256 x 512 for tall).
--   - Power-of-two sizes are required by WoW's texture system.
--   - The image will be stretched to fill the scroll area, so square
--     or slightly tall works best.
--   - Use dark, moody art — it will be shown at ~15% opacity behind
--     white/gold text.
--
-- To add a new image:
--   1. Save your art as a .tga file (32-bit, uncompressed or RLE)
--   2. Put it in: ForeverClassesEnhanced/Backgrounds/
--   3. Add an entry below mapping the character name to the path
--
-- The path format is:
--   "Interface\\AddOns\\ForeverClassesEnhanced\\Backgrounds\\filename"
--   (no .tga extension — WoW finds it automatically)
----------------------------------------------------------------------

FCE = FCE or {}

local BG = "Interface\\AddOns\\ForeverClassesEnhanced\\Backgrounds\\"

--- Map of character name → background texture path.
--- Characters not listed here will show no background image.
FCE.ClassBackgrounds = {
    -- WARRIOR
    ["Mountain King"]   = BG .. "mking",
    ["Brewmaster"]      = BG .. "brewmaster",
    ["Blademaster"]     = BG .. "blademaster",
    ["Brave"]           = BG .. "brave",
    ["Berserker"]       = BG .. "berserker",
    ["Runemaster"]       = BG .. "ley",
    ["Sister of Steel"] = BG .. "Sistersteel",
    ["Tinker"]    = BG .. "tinker",
    -- ROGUE
    ["Demon Hunter"]       = BG .. "DH",
    ["Warden"]          = BG .. "warden",
    ["Buccaneer"]       = BG .. "Buccaneer",
    ["Barbarian"]    = BG .. "barbarian",
    ["Prospector"]      = BG .. "pros",
    ["Ranger"]      = BG .. "dark_ranger",
    -- HUNTER
    ["Elven Archer"]    = BG .. "ElvenRanger",
    ["Beastmaster"]     = BG .. "Orcbeastmaster",
    ["Mountaineer"]     = BG .. "Mountaineer",
    ["Wilderness Stalker"] = BG .. "Wildernessstalker",
    -- MAGE
    ["Bloodmage"]       = BG .. "Bloodmage",
    ["Techno-mage"]     = BG .. "Techno-mage",
    ["Spellblade"]      = BG .. "Spellblade",
    ["Hedge Wizard"]    = BG .. "Hedgewizard",
    ["Ley Walker"]     = BG .. "ryze",
    ["Kirin Tor Mage"]    = BG .. "kirin_tor",
    -- WARLOCK
    ["Pyremaster"]      = BG .. "Pyremaster",
    ["Death Knight"]    = BG .. "Death_Knight",
    ["Necromancer"]     = BG .. "Necromancer",
    -- DRUID
    ["Druid of the Claw"] = BG .. "Claw",
    ["Plagueshifter"]   = BG .. "Plagueshifter",
    ["Savagekin"]       = BG .. "Savagekin",
    ["Druid of the Wild"]     = BG .. "savage",
    ["Dragonsworn"]     = BG .. "dragonsworn",
    -- PRIEST
    ["Moon Priest"] = BG .. "Moon",
    ["Apothecary"]      = BG .. "Apothecary",
    ["Shadow Hunter"]   = BG .. "shadow_hunter",
    ["Lightslayer"]     = BG .. "Lightslayer",
    ["Twilight Cultist"]     = BG .. "cultist",
    -- SHAMAN
    ["Earthcaller"]     = BG .. "Earthcaller",
    ["Witch Doctor"]    = BG .. "witch_doctor",
    ["Spiritwalker"]    = BG .. "spirit_walk",
    ["Spirit Champion"]    = BG .. "spirit_champ",
    ["Hexxer"]    = BG .. "hexxer",
    -- PALADIN
    ["Exemplar"]        = BG .. "Exemplar",
    ["Templar"]         = BG .. "Templar",
    ["Scarlet Champion"]         = BG .. "scarlet_champ",
    ["Shieldbearer"]         = BG .. "shieldbearer",
}

--- Hidden texture used to probe whether a faction-specific portrait exists.
local probeFrame = CreateFrame("Frame")
local probeTex = probeFrame:CreateTexture(nil, "BACKGROUND")
probeFrame:Hide()

--- Cache of resolved portrait paths so we only probe once per key.
local portraitCache = {}

--- Per-build portrait path (full rectangular art in Backgrounds/).
--- Tries faction-specific variant first (e.g. Ranger_ROGUE_ALLIANCE.tga),
--- falls back to base key (e.g. Ranger_ROGUE.tga).
function FCE.GetCharPortrait(char)
    if not char or not char.key then return nil end
    local bgKey = char.key:gsub(" ", "_")

    if portraitCache[bgKey] ~= nil then
        return portraitCache[bgKey]
    end

    local faction = UnitFactionGroup("player")
    if faction then
        local factionKey = bgKey .. "_" .. faction:upper()
        local factionPath = BG .. factionKey
        probeTex:SetTexture(factionPath)
        local resolved = probeTex:GetTexture()
        if resolved and type(resolved) == "number" then
            -- Resolved to a file ID — the faction-specific file exists
            portraitCache[bgKey] = factionPath
            return factionPath
        end
    end

    portraitCache[bgKey] = BG .. bgKey
    return BG .. bgKey
end
