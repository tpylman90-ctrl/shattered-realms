#!/usr/bin/env python3
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets/battle/ashenreach_fortress_arena.jpg"
OUT = ROOT / "assets/battle/generated/ashenreach_fortress_arena.png"

if not SRC.exists():
    raise SystemExit(f"Missing battle backdrop source: {SRC}")

OUT.parent.mkdir(parents=True, exist_ok=True)

with Image.open(SRC) as im:
    im = im.convert("RGB")
    # Keep source resolution; PNG avoids platform-specific JPEG decode/import edge cases.
    im.save(OUT, format="PNG", optimize=True)

print(f"[battle] wrote {OUT} ({OUT.stat().st_size / 1024:.1f} KiB)")
