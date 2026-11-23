"""
Check that every class in CharacterData.lua has its art.

For each build key (e.g. "Sister of Steel_WARRIOR"):
  portrait    ForeverClassesEnhanced/Backgrounds/<Key_with_underscores>[_ALLIANCE|_HORDE].tga
  source      portraits/<Key_with_underscores>.(jpg|png)   (only needed to regenerate)
For each class name (e.g. "Sister of Steel"), the browse-grid icon:
  a BROWSE_ICONS entry in CatalogUI.lua (WoW icon ID), or
  a ClassBackgrounds entry in ClassPortraits.lua -> Icons/<value>.tga

Usage:  python check_class_art.py          (lists only what is missing)
        python check_class_art.py --all    (lists every class)
"""
import os, re, sys

REPO = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.join(REPO, "ForeverClassesEnhanced")
BG = os.path.join(ADDON, "Backgrounds")
ICONS = os.path.join(ADDON, "Icons")
SRC = os.path.join(REPO, "portraits")


def read(p):
    with open(p, encoding="utf-8") as f:
        return f.read()


def exists_any(folder, base, exts):
    return any(os.path.exists(os.path.join(folder, base + e)) for e in exts)


def main(show_all):
    data = read(os.path.join(ADDON, "CharacterData.lua"))
    start = data.index("FCE.Characters = {")
    keys = re.findall(r'^    \["([^"]+_[A-Z]+)"\] = \{', data[start:], re.M)
    names = {}
    for k in keys:
        m = re.search(r'\["' + re.escape(k) + r'"\] = \{.*?\n        name\s*=\s*"([^"]+)"', data[start:], re.S)
        names[k] = m.group(1) if m else k.rsplit("_", 1)[0]

    portraits = read(os.path.join(ADDON, "ClassPortraits.lua"))
    cls_bg = dict(re.findall(r'\["([^"]+)"\]\s*=\s*BG \.\. "([^"]+)"', portraits))
    catalog = read(os.path.join(ADDON, "CatalogUI.lua"))
    b = catalog.index("FCE.BROWSE_ICONS = {")
    browse = set(re.findall(r'\["([^"]+)"\]\s*=', catalog[b:catalog.index("}", b)]))

    missing = 0
    print(f"{len(keys)} builds, {len(set(names.values()))} class names\n")
    for k in keys:
        fk = k.replace(" ", "_")
        probs = []
        if not exists_any(BG, fk, [".tga", "_ALLIANCE.tga", "_HORDE.tga"]):
            probs.append("portrait Backgrounds/" + fk + ".tga")
        if not exists_any(SRC, fk, [".jpg", ".jpeg", ".png", "_ALLIANCE.jpg", "_HORDE.jpg"]):
            probs.append("(source portraits/" + fk + ".jpg)")
        if probs or show_all:
            print(f"  {k:34} " + ("missing: " + ", ".join(probs) if probs else "ok"))
        missing += sum(1 for p in probs if not p.startswith("("))

    print()
    for n in sorted(set(names.values())):
        probs = []
        v = cls_bg.get(n)
        if n not in browse:
            if not v:
                probs.append("browse icon: BROWSE_ICONS or ClassBackgrounds entry")
            elif not os.path.exists(os.path.join(ICONS, v + ".tga")):
                probs.append("browse icon Icons/" + v + ".tga")
        if probs or show_all:
            print(f"  {n:34} " + ("missing: " + ", ".join(probs) if probs else "ok"))
        missing += len(probs)
    print(f"\n{missing} missing item(s)")


if __name__ == "__main__":
    main("--all" in sys.argv)
