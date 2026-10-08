#!/usr/bin/env python3
"""
Build a release zip for ForeverClassesEnhanced.

Usage:  python build.py 0.8.0
Output: ForeverClassesEnhanced-0.8.0.zip

Creates a zip with forward-slash paths (per ZIP spec) so it extracts
correctly on Linux, macOS, and Windows.
"""

import os
import sys
import zipfile

ADDON_DIR = "ForeverClassesEnhanced"
ADDON_NAME = "ForeverClassesEnhanced"

# Files/folders to exclude from the zip
EXCLUDE = {".git", "__pycache__", ".DS_Store", "Thumbs.db", ".vs"}


def build(version: str):
    script_dir = os.path.dirname(os.path.abspath(__file__))
    addon_path = os.path.join(script_dir, ADDON_DIR)

    if not os.path.isdir(addon_path):
        print(f"ERROR: addon folder not found: {addon_path}")
        sys.exit(1)

    zip_name = f"{ADDON_NAME}-{version}.zip"
    zip_path = os.path.join(script_dir, zip_name)

    count = 0
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for root, dirs, files in os.walk(addon_path):
            # Prune excluded directories
            dirs[:] = [d for d in dirs if d not in EXCLUDE]

            for fname in sorted(files):
                if fname in EXCLUDE:
                    continue
                full = os.path.join(root, fname)
                # Archive name: AddonName/relative/path  (forward slashes)
                rel = os.path.relpath(full, script_dir)
                arc_name = rel.replace("\\", "/")  # force forward slashes
                zf.write(full, arc_name)
                count += 1

    size_kb = os.path.getsize(zip_path) / 1024
    print(f"Created {zip_name}  ({count} files, {size_kb:.0f} KB)")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python build.py <version>")
        print("  e.g. python build.py 0.8.0")
        sys.exit(1)
    build(sys.argv[1])
