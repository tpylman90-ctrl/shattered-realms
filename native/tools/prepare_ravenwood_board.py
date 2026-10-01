#!/usr/bin/env python3
"""Split the original Ravenwood mesh without decimating geometry or altering UVs.

Usage: python native/tools/prepare_ravenwood_board.py path/to/original.glb
Dependencies: numpy, trimesh, pillow.
"""
import sys
import io
from pathlib import Path
import numpy as np
import trimesh
from PIL import Image
from pygltflib import GLTF2

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'assets/3d/game-ready/ravenwood-board'
PARTS = 8
TEXTURE_SIZE = 2048

def main(source):
    scene = trimesh.load(source, force='scene', process=False)
    if len(scene.geometry) != 1:
        raise RuntimeError('Expected one board mesh')
    mesh = next(iter(scene.geometry.values()))
    vertices = np.asarray(mesh.vertices, dtype=np.float32)
    faces = np.asarray(mesh.faces, dtype=np.int32)
    uv = np.asarray(mesh.visual.uv, dtype=np.float32)
    material = mesh.visual.material
    for key in ('baseColorTexture', 'normalTexture', 'metallicRoughnessTexture'):
        image = getattr(material, key, None)
        if image is not None:
            setattr(material, key, image.resize((TEXTURE_SIZE, TEXTURE_SIZE), Image.Resampling.LANCZOS))
    centers = vertices[faces].mean(axis=1)
    order = np.lexsort((centers[:, 2], centers[:, 0]))
    OUTPUT.mkdir(parents=True, exist_ok=True)
    total = 0
    for part, indices in enumerate(np.array_split(order, PARTS)):
        selected = faces[indices]
        used, inverse = np.unique(selected.reshape(-1), return_inverse=True)
        section = trimesh.Trimesh(vertices=vertices[used], faces=inverse.reshape(-1, 3), process=False)
        section.visual = trimesh.visual.TextureVisuals(uv=uv[used], material=material)
        section_scene = trimesh.Scene()
        section_scene.add_geometry(section, node_name=f'RavenwoodSection{part:02d}', geom_name=f'RavenwoodSection{part:02d}')
        destination = OUTPUT / f'ravenwood_section_{part:02d}.glb'
        destination.write_bytes(section_scene.export(file_type='glb'))
        gltf = GLTF2().load(str(destination))
        blob = gltf.binary_blob()
        replacements = {}
        for image in gltf.images:
            view = gltf.bufferViews[image.bufferView]
            original = Image.open(io.BytesIO(blob[view.byteOffset:view.byteOffset + view.byteLength]))
            compressed = io.BytesIO()
            original.convert('RGB').save(compressed, format='JPEG', quality=88, subsampling=0)
            replacements[image.bufferView] = compressed.getvalue()
            image.mimeType = 'image/jpeg'
        packed = bytearray()
        for index, view in enumerate(gltf.bufferViews):
            data = replacements.get(index)
            if data is None:
                data = blob[view.byteOffset:view.byteOffset + view.byteLength]
            view.byteOffset = len(packed)
            view.byteLength = len(data)
            packed.extend(data)
            packed.extend(b'\x00' * (-len(packed) % 4))
        gltf.set_binary_blob(bytes(packed))
        gltf.buffers[0].byteLength = len(packed)
        gltf.save_binary(str(destination))
        total += len(selected)
        print(f'[ravenwood] {destination.name}: {len(selected):,} triangles, {destination.stat().st_size/1024/1024:.1f} MiB', flush=True)
    assert total == len(faces)
    print(f'[ravenwood] retained all {total:,} original triangles and UVs', flush=True)

if __name__ == '__main__':
    main(Path(sys.argv[1]))
