#!/usr/bin/env python3
"""Split Ravenwood without decimation, sharing a single set of texture atlases.

Usage: python native/tools/prepare_ravenwood_board.py path/to/original.glb
Dependencies: numpy, trimesh, pillow.
"""
import sys
from pathlib import Path
import numpy as np
import trimesh
from PIL import Image
from pygltflib import GLTF2

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'assets/3d/game-ready/ravenwood-board'
PARTS = 20
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
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for key, filename in (('baseColorTexture', 'ravenwood_albedo.jpg'),
                          ('normalTexture', 'ravenwood_normal.jpg'),
                          ('metallicRoughnessTexture', 'ravenwood_metal_rough.jpg')):
        image = getattr(material, key, None)
        if image is None:
            raise RuntimeError(f'Missing {key}')
        image.resize((TEXTURE_SIZE, TEXTURE_SIZE), Image.Resampling.LANCZOS).convert('RGB').save(
            OUTPUT / filename, format='JPEG', quality=88, subsampling=0)
    centers = vertices[faces].mean(axis=1)
    order = np.lexsort((centers[:, 2], centers[:, 0]))
    total = 0
    for part, indices in enumerate(np.array_split(order, PARTS)):
        selected = faces[indices]
        used, inverse = np.unique(selected.reshape(-1), return_inverse=True)
        section = trimesh.Trimesh(vertices=vertices[used], faces=inverse.reshape(-1, 3), process=False)
        # Godot assigns one shared material to all sections. Keep the UVs in
        # the mesh but never repeat the large image atlases inside each GLB.
        section.visual = trimesh.visual.TextureVisuals(uv=uv[used])
        section_scene = trimesh.Scene()
        section_scene.add_geometry(section, node_name=f'RavenwoodSection{part:02d}', geom_name=f'RavenwoodSection{part:02d}')
        destination = OUTPUT / f'ravenwood_section_{part:02d}.glb'
        destination.write_bytes(section_scene.export(file_type='glb'))
        # Each section has fewer than 65,536 vertices. Trimesh exports 32-bit
        # indices anyway; repack them as 16-bit without touching positions/UVs.
        gltf = GLTF2().load(str(destination))
        accessor = gltf.accessors[gltf.meshes[0].primitives[0].indices]
        if len(used) >= 65536 or accessor.componentType != 5125 or accessor.byteOffset != 0:
            raise RuntimeError('Section cannot use 16-bit indices')
        blob = gltf.binary_blob()
        packed = bytearray()
        image_views = {image.bufferView for image in gltf.images}
        retained_views = []
        view_mapping = {}
        for index, view in enumerate(gltf.bufferViews):
            if index in image_views:
                continue
            data = blob[view.byteOffset:view.byteOffset + view.byteLength]
            if index == accessor.bufferView:
                data = np.frombuffer(data, dtype='<u4').astype('<u2').tobytes()
                accessor.componentType = 5123
            view_mapping[index] = len(retained_views)
            retained_views.append(view)
            view.byteOffset = len(packed)
            view.byteLength = len(data)
            packed.extend(data)
            packed.extend(b'\x00' * (-len(packed) % 4))
        for mesh_accessor in gltf.accessors:
            mesh_accessor.bufferView = view_mapping[mesh_accessor.bufferView]
        gltf.bufferViews = retained_views
        gltf.meshes[0].primitives[0].material = None
        gltf.materials = []
        gltf.textures = []
        gltf.images = []
        gltf.set_binary_blob(bytes(packed))
        gltf.buffers[0].byteLength = len(packed)
        gltf.save_binary(str(destination))
        total += len(selected)
        print(f'[ravenwood] {destination.name}: {len(selected):,} triangles, {destination.stat().st_size/1024/1024:.1f} MiB', flush=True)
    assert total == len(faces)
    print(f'[ravenwood] retained all {total:,} original triangles and UVs', flush=True)

if __name__ == '__main__':
    main(Path(sys.argv[1]))
