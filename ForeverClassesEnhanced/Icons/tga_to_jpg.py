"""
Convert all .tga files in this folder to .jpg.
Output goes to a 'jpg' subfolder, same filenames but with .jpg extension.

Usage:
    python tga_to_jpg.py
"""
import os
from PIL import Image

SRC_DIR = os.path.dirname(os.path.abspath(__file__))
DST_DIR = os.path.join(SRC_DIR, "jpg")

os.makedirs(DST_DIR, exist_ok=True)

count = 0
for fname in sorted(os.listdir(SRC_DIR)):
    if not fname.lower().endswith(".tga"):
        continue
    src = os.path.join(SRC_DIR, fname)
    dst = os.path.join(DST_DIR, os.path.splitext(fname)[0] + ".jpg")
    try:
        img = Image.open(src)
        # TGA files may have alpha — flatten onto white before saving as JPG
        if img.mode in ("RGBA", "LA", "PA"):
            bg = Image.new("RGB", img.size, (0, 0, 0))
            bg.paste(img, mask=img.split()[-1])
            img = bg
        elif img.mode != "RGB":
            img = img.convert("RGB")
        img.save(dst, "JPEG", quality=92)
        count += 1
        print(f"  {fname} -> jpg/{os.path.basename(dst)}")
    except Exception as e:
        print(f"  SKIP {fname}: {e}")

print(f"\nDone — {count} files converted to {DST_DIR}")
