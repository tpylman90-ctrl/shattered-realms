#!/usr/bin/env python3
"""Optimize the user-supplied Ravenwood GLB for mobile, preserving its UV atlas.

Usage: python native/tools/prepare_ravenwood_board.py path/to/original.glb
Dependencies: numpy, scipy, trimesh, fast-simplification, pillow.
"""
import sys
from pathlib import Path
import numpy as np
import trimesh
from scipy.spatial import cKDTree
from PIL import Image
import fast_simplification

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'assets/3d/game-ready/ravenwood-board/ravenwood_board_mobile.glb'
TARGET_FACES = 260_000
TEXTURE_SIZE = 1024

def main(source):
    scene = trimesh.load(source, force='scene', process=False)
    if len(scene.geometry) != 1:
        raise RuntimeError('Expected one board mesh')
    mesh = next(iter(scene.geometry.values()))
    uv = np.asarray(mesh.visual.uv, dtype=np.float32)
    print(f'[ravenwood] source: {len(mesh.vertices):,} vertices, {len(mesh.faces):,} triangles', flush=True)
    points, faces = fast_simplification.simplify(
        np.asarray(mesh.vertices, dtype=np.float64), np.asarray(mesh.faces, dtype=np.int32),
        target_count=TARGET_FACES, agg=7.0, preserve_border=False)
    distances, nearest = cKDTree(np.asarray(mesh.vertices)).query(points, k=1, workers=-1)
    print(f'[ravenwood] optimized: {len(points):,} vertices, {len(faces):,} triangles; UV p95={np.percentile(distances,95):.5f}', flush=True)
    material = mesh.visual.material
    for key in ('baseColorTexture', 'normalTexture', 'metallicRoughnessTexture'):
        image = getattr(material, key, None)
        if image is not None:
            setattr(material, key, image.convert('RGB').resize((TEXTURE_SIZE,TEXTURE_SIZE),Image.Resampling.LANCZOS))
    mobile = trimesh.Trimesh(vertices=points.astype(np.float32),faces=faces.astype(np.int32),process=False)
    mobile.visual = trimesh.visual.TextureVisuals(uv=uv[nearest],material=material)
    output = trimesh.Scene()
    output.add_geometry(mobile,node_name='RavenwoodBoard',geom_name='RavenwoodBoard')
    OUTPUT.parent.mkdir(parents=True,exist_ok=True)
    OUTPUT.write_bytes(output.export(file_type='glb'))
    print(f'[ravenwood] wrote {OUTPUT}: {OUTPUT.stat().st_size/1024/1024:.1f} MiB',flush=True)

if __name__ == '__main__':
    main(Path(sys.argv[1]))
