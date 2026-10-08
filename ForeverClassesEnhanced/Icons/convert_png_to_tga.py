"""
Drop a PNG (any size) into this folder, then run:
    python convert_png_to_tga.py MyImage.png

It will create MyImage.tga — 128x128, circular alpha, WoW-compatible.
To convert ALL PNGs that don't have a matching TGA yet:
    python convert_png_to_tga.py --all
"""
import struct, sys, os
from PIL import Image, ImageDraw

def circular_crop(img, size=128):
    img = img.convert("RGBA").resize((size, size), Image.LANCZOS)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size-1, size-1), fill=255)
    r, g, b, a = img.split()
    a = Image.composite(a, Image.new("L", (size, size), 0), mask)
    img.putalpha(a)
    return img

def save_tga(img, path):
    w, h = img.size
    pixels = img.load()
    raw = bytearray()
    for y in range(h - 1, -1, -1):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            raw.extend([b, g, r, a])
    header = bytearray(18)
    header[2] = 2
    struct.pack_into('<H', header, 12, w)
    struct.pack_into('<H', header, 14, h)
    header[16] = 32
    header[17] = 8
    with open(path, 'wb') as f:
        f.write(header)
        f.write(raw)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python convert_png_to_tga.py <file.png> [file2.png ...]")
        print("       python convert_png_to_tga.py --all")
        sys.exit(1)

    if sys.argv[1] == "--all":
        files = [f for f in os.listdir('.') if f.endswith('.png') and not os.path.exists(f.replace('.png', '.tga'))]
    else:
        files = sys.argv[1:]

    for f in files:
        name = f.replace('.png', '')
        img = circular_crop(Image.open(f))
        save_tga(img, name + '.tga')
        print(f"  {name}.tga")
    print(f"Done — {len(files)} file(s)")
