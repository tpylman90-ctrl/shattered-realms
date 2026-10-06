#!/usr/bin/env python3
"""Generate a lightweight, tileable equirectangular cloud layer for the editor sky."""
from pathlib import Path

import numpy as np
from PIL import Image


WIDTH, HEIGHT = 1024, 512
OUTPUT = Path(__file__).resolve().parents[1] / "assets/environment/ravenwood_cloud_cover.png"
RNG = np.random.default_rng(9137)


def periodic_noise(cells_x: int, cells_y: int) -> np.ndarray:
    grid = RNG.random((cells_y, cells_x), dtype=np.float32)
    x = np.arange(WIDTH, dtype=np.float32) * cells_x / WIDTH
    y = np.arange(HEIGHT, dtype=np.float32) * cells_y / HEIGHT
    x0 = np.floor(x).astype(np.int32)
    y0 = np.floor(y).astype(np.int32)
    fx = x - x0
    fy = y - y0
    fx = fx * fx * (3.0 - 2.0 * fx)
    fy = fy * fy * (3.0 - 2.0 * fy)
    x1 = (x0 + 1) % cells_x
    y1 = np.minimum(y0 + 1, cells_y - 1)
    lower = grid[y0[:, None], x0[None, :]] * (1.0 - fx[None, :]) + grid[y0[:, None], x1[None, :]] * fx[None, :]
    upper = grid[y1[:, None], x0[None, :]] * (1.0 - fx[None, :]) + grid[y1[:, None], x1[None, :]] * fx[None, :]
    return lower * (1.0 - fy[:, None]) + upper * fy[:, None]


field = (
    periodic_noise(7, 5) * 0.48
    + periodic_noise(15, 10) * 0.28
    + periodic_noise(32, 21) * 0.16
    + periodic_noise(64, 42) * 0.08
)
y = np.linspace(0.0, 1.0, HEIGHT, dtype=np.float32)[:, None]
cloud_band = np.clip(1.0 - np.abs(y - 0.56) / 0.50, 0.0, 1.0)
threshold = 0.54 - 0.08 * cloud_band
clouds = np.clip((field - threshold) * 7.5, 0.0, 1.0)
clouds = clouds * clouds * (3.0 - 2.0 * clouds)
alpha = (clouds * cloud_band * 220.0).astype(np.uint8)
rgba = np.empty((HEIGHT, WIDTH, 4), dtype=np.uint8)
rgba[:, :, :3] = np.array([244, 250, 255], dtype=np.uint8)
rgba[:, :, 3] = alpha
OUTPUT.parent.mkdir(parents=True, exist_ok=True)
Image.fromarray(rgba, "RGBA").save(OUTPUT, optimize=True)
print(f"Wrote {OUTPUT} ({WIDTH}x{HEIGHT})")
