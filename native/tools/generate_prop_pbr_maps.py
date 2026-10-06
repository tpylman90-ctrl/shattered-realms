#!/usr/bin/env python3
"""Derive lightweight detail normal and roughness maps from the prop albedo set."""
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parents[1] / "assets/props/materials"
MATERIALS = {
    "weathered_wood": (0.82, 18.0, 0.10),
    "bark": (0.92, 25.0, 0.06),
    "masonry": (0.87, 16.0, 0.10),
    "aged_plaster": (0.94, 8.0, 0.04),
    "clay_roof": (0.78, 14.0, 0.10),
    "thatch": (0.96, 18.0, 0.04),
}

for name, (roughness, height_gain, rough_variation) in MATERIALS.items():
    source = ROOT / f"{name}.jpg"
    if not source.is_file():
        raise FileNotFoundError(source)
    gray = ImageOps.grayscale(Image.open(source)).filter(ImageFilter.GaussianBlur(radius=0.7))
    pixels = np.asarray(gray, dtype=np.float32) / 255.0
    broad = np.asarray(ImageOps.grayscale(Image.open(source)).filter(ImageFilter.GaussianBlur(radius=5.0)), dtype=np.float32) / 255.0
    detail = pixels - broad
    height = detail * height_gain
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 0.5
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * 0.5
    nx, ny, nz = -dx, -dy, np.ones_like(dx)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    normal = np.stack(((nx / length + 1.0) * 127.5, (ny / length + 1.0) * 127.5, (nz / length + 1.0) * 127.5), axis=-1)
    Image.fromarray(np.clip(normal, 0, 255).astype(np.uint8), "RGB").save(ROOT / f"{name}_normal.jpg", quality=92, optimize=True, progressive=True)

    local_detail = np.abs(pixels - np.asarray(ImageOps.grayscale(Image.open(source)).filter(ImageFilter.GaussianBlur(radius=1.5)), dtype=np.float32) / 255.0)
    variation = np.clip((local_detail - 0.015) * 2.4, -rough_variation, rough_variation)
    rough = np.clip(roughness + variation, 0.55, 1.0)
    Image.fromarray(np.uint8(rough * 255), "L").save(ROOT / f"{name}_roughness.jpg", quality=92, optimize=True, progressive=True)
    print(name, "normal", (ROOT / f"{name}_normal.jpg").stat().st_size, "roughness", (ROOT / f"{name}_roughness.jpg").stat().st_size)
