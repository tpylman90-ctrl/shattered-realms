#!/usr/bin/env python3
"""
Generate a lightweight Ashenreach navigation/grounding surface from the detailed
visual GLB.

The visual board remains untouched. This tool samples the source mesh at the same
flat-top axial hex centers used by the game, chooses a locally-supported top
surface, suppresses isolated prop tops, and writes a tiny untextured GLB made of
hex plates. Godot uses the result only for grounding/collision/hex projection.
"""

from __future__ import annotations

import json
import math
import os
import struct
from collections import defaultdict
from pathlib import Path

import numpy as np
import trimesh
from trimesh.ray.ray_triangle import RayMeshIntersector

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/3d/game-ready/ashenreach-hex-board/ashenreach_hex_board.glb"
OUTPUT = ROOT / "assets/3d/game-ready/ashenreach-hex-board/generated/ashenreach_nav_surface.glb"
GRID_OUTPUT = ROOT / "data/generated/ashenreach_nav_grid.json"

TERRAIN_SCALE = 38.0
HEX_SIZE_WORLD = 0.55
HEX_WORLD_LIMIT = 17.3
Q_MIN, Q_MAX = -23, 23
R_MIN, R_MAX = -30, 30

# Surface selection tuning in source-model units. The board is scaled x38 in Godot.
MIN_TOP_NORMAL_Y = 0.20
HIGH_OUTLIER_WORLD = 0.70
HIGH_OUTLIER_LOCAL = HIGH_OUTLIER_WORLD / TERRAIN_SCALE
NEIGHBOR_MATCH_WORLD = 0.80
NEIGHBOR_MATCH_LOCAL = NEIGHBOR_MATCH_WORLD / TERRAIN_SCALE
SMOOTH_PASSES = 5

# Slightly overlap neighboring nav plates so downward grounding rays do not fall
# through floating-point cracks at tile boundaries.
HEX_RADIUS_LOCAL = (HEX_SIZE_WORLD * 0.97) / TERRAIN_SCALE


def axial_world(q: int, r: int) -> tuple[float, float]:
    x = HEX_SIZE_WORLD * 1.5 * q
    z = HEX_SIZE_WORLD * math.sqrt(3.0) * (r + q * 0.5)
    return x, z


def scene_to_mesh(path: Path) -> trimesh.Trimesh:
    loaded = trimesh.load(path, force="scene", process=False)

    if isinstance(loaded, trimesh.Trimesh):
        mesh = loaded.copy()
    else:
        pieces = []
        for node_name in loaded.graph.nodes_geometry:
            transform, geometry_name = loaded.graph[node_name]
            geometry = loaded.geometry[geometry_name].copy()
            geometry.apply_transform(transform)
            pieces.append(geometry)
        if not pieces:
            raise RuntimeError("No mesh geometry found in source GLB")
        mesh = trimesh.util.concatenate(pieces)

    mesh.remove_unreferenced_vertices()
    return mesh


def collect_hex_centers() -> tuple[list[str], np.ndarray, dict[str, tuple[int, int]]]:
    keys: list[str] = []
    origins = []
    axial: dict[str, tuple[int, int]] = {}

    for r in range(R_MIN, R_MAX + 1):
        for q in range(Q_MIN, Q_MAX + 1):
            wx, wz = axial_world(q, r)
            if abs(wx) > HEX_WORLD_LIMIT or abs(wz) > HEX_WORLD_LIMIT:
                continue
            key = f"{q},{r}"
            keys.append(key)
            axial[key] = (q, r)
            origins.append([wx / TERRAIN_SCALE, 0.0, wz / TERRAIN_SCALE])

    return keys, np.asarray(origins, dtype=np.float64), axial


def sample_candidates(mesh: trimesh.Trimesh, centers: np.ndarray):
    bounds = mesh.bounds
    ray_y = float(bounds[1, 1] + max(0.2, bounds[1, 1] - bounds[0, 1] + 0.2))

    origins = centers.copy()
    origins[:, 1] = ray_y
    directions = np.zeros_like(origins)
    directions[:, 1] = -1.0

    intersector = RayMeshIntersector(mesh)
    locations, ray_ids, tri_ids = intersector.intersects_location(
        origins,
        directions,
        multiple_hits=True,
    )

    candidates: list[list[float]] = [[] for _ in range(len(centers))]
    if len(locations) == 0:
        return candidates

    normals = mesh.face_normals[np.asarray(tri_ids, dtype=np.int64)]
    for loc, ray_id, normal in zip(locations, ray_ids, normals):
        if float(normal[1]) < MIN_TOP_NORMAL_Y:
            continue
        candidates[int(ray_id)].append(float(loc[1]))

    for i, values in enumerate(candidates):
        if not values:
            continue
        # De-duplicate coplanar hits from adjacent triangles.
        values = sorted(set(round(v, 7) for v in values))
        candidates[i] = values

    return candidates


DIRECTIONS = ((1, 0), (1, -1), (0, -1), (-1, 0), (-1, 1), (0, 1))


def choose_supported_surfaces(
    keys: list[str],
    axial: dict[str, tuple[int, int]],
    candidates: list[list[float]],
):
    index_by_key = {key: i for i, key in enumerate(keys)}

    selected: list[float | None] = [
        max(values) if values else None for values in candidates
    ]

    for _ in range(SMOOTH_PASSES):
        next_selected = list(selected)

        for i, key in enumerate(keys):
            values = candidates[i]
            current = selected[i]
            if current is None or len(values) <= 1:
                continue

            q, r = axial[key]
            neighbor_values = []
            for dq, dr in DIRECTIONS:
                j = index_by_key.get(f"{q+dq},{r+dr}")
                if j is not None and selected[j] is not None:
                    neighbor_values.append(float(selected[j]))

            if len(neighbor_values) < 2:
                continue

            median = float(np.median(np.asarray(neighbor_values, dtype=np.float64)))

            # Keep high surfaces that have local support (bridges/platforms), but
            # demote isolated high hits such as pillars/rocks to the candidate
            # closest to the neighborhood floor.
            support = sum(
                abs(float(v) - current) <= NEIGHBOR_MATCH_LOCAL
                for v in neighbor_values
            )

            if current - median > HIGH_OUTLIER_LOCAL and support < 2:
                best = min(values, key=lambda y: abs(float(y) - median))
                if abs(float(best) - median) < abs(current - median):
                    next_selected[i] = float(best)

        selected = next_selected

    return selected


def build_nav_mesh(
    keys: list[str],
    centers: np.ndarray,
    selected: list[float | None],
) -> trimesh.Trimesh:
    vertices: list[list[float]] = []
    normals: list[list[float]] = []
    faces: list[list[int]] = []

    kept = 0
    for i, key in enumerate(keys):
        y = selected[i]
        if y is None:
            continue

        cx = float(centers[i, 0])
        cz = float(centers[i, 2])

        base = len(vertices)
        vertices.append([cx, float(y), cz])
        normals.append([0.0, 1.0, 0.0])

        # 30-degree offset matches the flat-top hex overlay in Godot.
        for corner in range(6):
            angle = math.radians(30.0 + 60.0 * corner)
            vertices.append([
                cx + math.cos(angle) * HEX_RADIUS_LOCAL,
                float(y),
                cz + math.sin(angle) * HEX_RADIUS_LOCAL,
            ])
            normals.append([0.0, 1.0, 0.0])

        for corner in range(6):
            a = base
            b = base + 1 + corner
            c = base + 1 + ((corner + 1) % 6)
            faces.append([a, b, c])

        kept += 1

    if not faces:
        raise RuntimeError("Navigation surface generation produced zero tiles")

    mesh = trimesh.Trimesh(
        vertices=np.asarray(vertices, dtype=np.float32),
        faces=np.asarray(faces, dtype=np.int64),
        vertex_normals=np.asarray(normals, dtype=np.float32),
        process=False,
    )
    mesh.metadata["hex_tiles"] = kept
    return mesh


def export_glb(mesh: trimesh.Trimesh, output: Path):
    output.parent.mkdir(parents=True, exist_ok=True)

    scene = trimesh.Scene()
    scene.add_geometry(mesh, node_name="AshenreachNavSurface", geom_name="AshenreachNavSurface")
    data = scene.export(file_type="glb")
    output.write_bytes(data)

def export_grid_json(
    keys: list[str],
    centers: np.ndarray,
    selected: list[float | None],
    output: Path,
):
    output.parent.mkdir(parents=True, exist_ok=True)

    tiles = {}
    for i, key in enumerate(keys):
        y_local = selected[i]
        if y_local is None:
            continue
        tiles[key] = {
            "x": round(float(centers[i, 0]) * TERRAIN_SCALE, 5),
            "y": round(float(y_local) * TERRAIN_SCALE, 5),
            "z": round(float(centers[i, 2]) * TERRAIN_SCALE, 5),
        }

    payload = {
        "version": 1,
        "terrain_scale": TERRAIN_SCALE,
        "hex_size": HEX_SIZE_WORLD,
        "tile_count": len(tiles),
        "tiles": tiles,
    }
    output.write_text(json.dumps(payload, separators=(",", ":")), encoding="utf-8")


def main():
    if not SOURCE.exists():
        raise SystemExit(f"Missing source board: {SOURCE}")

    print(f"[nav] loading {SOURCE}")
    mesh = scene_to_mesh(SOURCE)
    print(f"[nav] source vertices={len(mesh.vertices):,} faces={len(mesh.faces):,}")
    print(f"[nav] source bounds={mesh.bounds.tolist()}")

    keys, centers, axial = collect_hex_centers()
    print(f"[nav] logical hex centers={len(keys):,}")

    candidates = sample_candidates(mesh, centers)
    hit_count = sum(bool(v) for v in candidates)
    multi_count = sum(len(v) > 1 for v in candidates)
    print(f"[nav] surface hits={hit_count:,}; multi-layer hits={multi_count:,}")

    selected = choose_supported_surfaces(keys, axial, candidates)
    chosen = [v for v in selected if v is not None]
    print(
        f"[nav] selected tiles={len(chosen):,}; "
        f"y_local=[{min(chosen):.5f}, {max(chosen):.5f}] "
        f"y_world=[{min(chosen)*TERRAIN_SCALE:.2f}, {max(chosen)*TERRAIN_SCALE:.2f}]"
    )

    nav_mesh = build_nav_mesh(keys, centers, selected)
    export_glb(nav_mesh, OUTPUT)
    export_grid_json(keys, centers, selected, GRID_OUTPUT)

    print(
        f"[nav] wrote {OUTPUT} "
        f"({OUTPUT.stat().st_size / 1024.0:.1f} KiB, "
        f"{len(nav_mesh.faces):,} triangles)"
    )
    print(
        f"[nav] wrote {GRID_OUTPUT} "
        f"({GRID_OUTPUT.stat().st_size / 1024.0:.1f} KiB)"
    )


if __name__ == "__main__":
    main()
