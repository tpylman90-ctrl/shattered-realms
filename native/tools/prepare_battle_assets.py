#!/usr/bin/env python3
from pathlib import Path
from PIL import Image, ImageFile

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets/battle/ashenreach_fortress_arena.jpg"
OUT = ROOT / "assets/battle/generated/ashenreach_fortress_arena.png"

# The source JPEG in the repository was created from an external image handoff
# and is missing a clean trailing marker. Pillow can still decode the image
# content safely in tolerant mode; re-saving it produces a fully valid PNG.
ImageFile.LOAD_TRUNCATED_IMAGES = True

if not SRC.exists():
    raise SystemExit(f"Missing battle backdrop source: {SRC}")

OUT.parent.mkdir(parents=True, exist_ok=True)

with Image.open(SRC) as im:
    im.load()
    im = im.convert("RGB")

    if im.width < 320 or im.height < 180:
        raise SystemExit(f"Battle backdrop decoded to suspicious dimensions: {im.size}")

    # Re-save as a clean PNG. This removes the malformed JPEG stream and gives
    # Godot a deterministic, platform-safe texture to import.
    im.save(OUT, format="PNG", optimize=True)

# Verify the repaired file before Godot ever sees it.
with Image.open(OUT) as check:
    check.verify()

print(f"[battle] repaired {SRC.name} -> {OUT} ({OUT.stat().st_size / 1024:.1f} KiB)")
