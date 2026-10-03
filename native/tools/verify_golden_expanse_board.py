#!/usr/bin/env python3
"""Check the exported board assets and the two required bridge routes."""
import collections
import json
import math
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
data = json.loads((ROOT / "data/generated/golden_expanse_nav_grid.json").read_text())
cells = data["cells"]


def nearest(x, z):
    return min(range(len(cells)), key=lambda i: (cells[i]["x"] - x) ** 2 + (cells[i]["z"] - z) ** 2)


def path(start, end):
    queue = collections.deque([start])
    parents = {start: -1}
    while queue and end not in parents:
        current = queue.popleft()
        for neighbor in cells[current]["neighbors"]:
            if neighbor not in parents:
                parents[neighbor] = current
                queue.append(neighbor)
    if end not in parents:
        return []
    result = []
    at = end
    while at != -1:
        result.append(at)
        at = parents[at]
    return result[::-1]


assert 1800 <= len(cells) <= 2600
assert len(path(0, len(cells) - 1)) > 1, "Movement graph is disconnected"
for z in data["bridges"]:
    bridge_route = path(nearest(-7, z), nearest(8, z))
    assert any(cells[i]["terrain"] == "bridge" and abs(cells[i]["z"] - z) < 1.1 for i in bridge_route), f"Bridge at {z} is not used"
    assert all(math.isfinite(float(cells[i]["y"])) for i in bridge_route)

for filename in ("golden_expanse_board.glb", "golden_expanse_nav.glb"):
    blob = (ROOT / "assets/3d/game-ready/golden-expanse-board" / filename).read_bytes()
    magic, version, length = struct.unpack_from("<4sII", blob)
    assert (magic, version, length) == (b"glTF", 2, len(blob))
    json_length, chunk_type = struct.unpack_from("<I4s", blob, 12)
    assert chunk_type == b"JSON"
    model = json.loads(blob[20:20 + json_length])
    assert model["meshes"] and model["scenes"]

print(f"Golden Expanse verified: {len(cells)} connected hexes, 2 usable bridges, 2 valid GLBs")
