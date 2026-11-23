"""
Drop a PNG (any size) into this folder, then run:
    python convert_png_to_tga.py MyImage.png

It resizes to 256x256 (or 256x512 if tall) and writes a WoW-compatible TGA.
Use --all to convert any PNGs missing a matching TGA.
"""
import struct, sys, os
from PIL import Image

def save_tga(img, path):
    img = img.convert("RGBA")
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

def next_power_of_two(n):
    p = 1
    while p < n:
        p *= 2
    return p

def resize_pot(img):
    w, h = img.size
    ratio = h / w
    new_w = min(next_power_of_two(w), 256)
    new_h = min(next_power_of_two(int(new_w * ratio)), 512)
    # Default to 256x256 for square-ish, 256x512 for tall
    if ratio > 1.3:
        new_w, new_h = 256, 512
    else:
        new_w, new_h = 256, 256
    return img.resize((new_w, new_h), Image.LANCZOS)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python convert_png_to_tga.py <file.png> [file2.png ...]")
        print("       python convert_png_to_tga.py --all")
        sys.exit(1)

    if sys.argv[1] == "--all":
        files = [f for f in os.listdir('.') if f.lower().endswith('.png')
                 and not os.path.exists(f.rsplit('.', 1)[0] + '.tga')]
    else:
        files = sys.argv[1:]

    for f in files:
        name = f.rsplit('.', 1)[0]
        img = resize_pot(Image.open(f))
        save_tga(img, name + '.tga')
        print(f"  {name}.tga ({img.size[0]}x{img.size[1]})")
    print(f"Done — {len(files)} file(s)")
