"""
Class portrait workflow (Forever Classes Enhanced)

Crops source art in this folder to 509x720 (scale-to-cover, then
center-crop) and writes it to ../test_portraits/<same name>.tga for review.
With --install it also copies the results into
../ForeverClassesEnhanced/Backgrounds/, where the addon picks them up.

File naming = the class key with spaces as underscores:
    <Class_Name>_<WOWCLASS>.jpg          e.g. Sister_of_Steel_WARRIOR.jpg
    <Class_Name>_<WOWCLASS>_ALLIANCE.jpg / _HORDE.jpg   faction variant (optional)

Usage:
    python crop_portraits.py                          all images in this folder
    python crop_portraits.py Warden_ROGUE.jpg         only these files
    python crop_portraits.py Warden_ROGUE.jpg --install
"""
import os, sys, shutil
from PIL import Image

TARGET_W, TARGET_H = 509, 720
TARGET_RATIO = TARGET_W / TARGET_H  # ~0.707

SRC_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR = os.path.dirname(SRC_DIR)
DST_DIR = os.path.join(REPO_DIR, "test_portraits")
ADDON_BG_DIR = os.path.join(REPO_DIR, "ForeverClassesEnhanced", "Backgrounds")

EXTS = (".tga", ".jpg", ".jpeg", ".png")


def crop(src_path, dst_path):
    img = Image.open(src_path).convert("RGBA")
    w, h = img.size
    if w / h > TARGET_RATIO:
        # wider than target: scale by height, crop width
        new_w = round(w * TARGET_H / h)
        img = img.resize((new_w, TARGET_H), Image.LANCZOS)
        left = (new_w - TARGET_W) // 2
        img = img.crop((left, 0, left + TARGET_W, TARGET_H))
    else:
        # taller than target: scale by width, crop height
        new_h = round(h * TARGET_W / w)
        img = img.resize((TARGET_W, new_h), Image.LANCZOS)
        top = (new_h - TARGET_H) // 2
        img = img.crop((0, top, TARGET_W, top + TARGET_H))
    # JPEG data with a .tga name (same convention as the existing art)
    img.convert("RGB").save(dst_path, format="JPEG", quality=92)
    return w, h


def main(argv):
    install = "--install" in argv
    names = [a for a in argv if not a.startswith("--")]
    if names:
        files = names
    else:
        files = sorted(f for f in os.listdir(SRC_DIR) if f.lower().endswith(EXTS))
    os.makedirs(DST_DIR, exist_ok=True)
    print(f"{len(files)} file(s) -> {DST_DIR}" + (f"  (+ install to {ADDON_BG_DIR})" if install else ""))
    done = 0
    for fname in files:
        src = fname if os.path.isabs(fname) else os.path.join(SRC_DIR, fname)
        base = os.path.splitext(os.path.basename(fname))[0]
        dst = os.path.join(DST_DIR, base + ".tga")
        try:
            w, h = crop(src, dst)
        except Exception as e:
            print(f"  SKIP {fname}: {e}")
            continue
        if install:
            shutil.copyfile(dst, os.path.join(ADDON_BG_DIR, base + ".tga"))
        done += 1
        print(f"  OK  {base}.tga  ({w}x{h} -> {TARGET_W}x{TARGET_H})" + ("  installed" if install else ""))
    print(f"Done: {done}/{len(files)}")


if __name__ == "__main__":
    main(sys.argv[1:])
