# Class art workflow

## Portrait (class card / requirements panel background)
1. Save the art here as `<Class_Name>_<WOWCLASS>.jpg` (or .png): spaces become
   underscores, e.g. `Harvest_Witch_WARLOCK.jpg`. Optional faction variants:
   `..._ALLIANCE.jpg` / `..._HORDE.jpg`.
2. `python crop_portraits.py Harvest_Witch_WARLOCK.jpg` writes a 509x720 crop to
   `../test_portraits/` for review.
3. Happy with it? Run again with `--install` to copy it into
   `../ForeverClassesEnhanced/Backgrounds/`. No code change needed: the addon
   finds `Backgrounds/<key>.tga` by name.

## Browse-grid icon (catalog "browse all")
Either:
- add a WoW icon ID to `FCE.BROWSE_ICONS` in `CatalogUI.lua`, or
- put a PNG in `../ForeverClassesEnhanced/Icons/`, run
  `python convert_png_to_tga.py MyIcon.png` there (128x128 circular TGA), and add
  `["Class Name"] = BG .. "MyIcon"` to `FCE.ClassBackgrounds` in `ClassPortraits.lua`.

## Check
`python ../check_class_art.py` (from the repo root: `python check_class_art.py`)
lists every class missing a portrait or browse icon.

`convert_png_to_tga.py` in this folder makes 256x256 / 256x512 TGAs (old-style
panel backgrounds); `Icons/tga_to_jpg.py` converts icons back to JPG for the wiki.
