#!/usr/bin/env python3
"""Prepare Ravenwood for mobile with UV-aware decimation and shared atlases.

Usage: python native/tools/prepare_ravenwood_board.py source.glb
Dependencies: numpy, trimesh, pillow, pymeshlab, pygltflib.
The source stays outside the game project. A texture-aware decimator is essential:
geometry-only simplification tears UV islands and produces black cracks.
"""
import sys
import tempfile
from pathlib import Path

import numpy as np
import pymeshlab
import trimesh
from PIL import Image
from pygltflib import GLTF2

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'assets/3d/game-ready/ravenwood-board'
PARTS = 10
TARGET_FACES = 650_000
TEXTURE_SIZE = 2048


def decimate_with_uvs(vertices, faces, uv, albedo_path, work_dir):
    # Loading an OBJ with a material gives MeshLab valid per-corner UVs and a
    # texture ID. Constructing a Mesh from vertex UVs alone does neither.
    obj = work_dir / 'ravenwood.obj'
    (work_dir / 'ravenwood.mtl').write_text('newmtl board\nmap_Kd atlas.jpg\n')
    (work_dir / 'atlas.jpg').write_bytes(albedo_path.read_bytes())
    with obj.open('w') as stream:
        stream.write('mtllib ravenwood.mtl\n')
        for x, y, z in vertices:
            stream.write(f'v {x:.8f} {y:.8f} {z:.8f}\n')
        for u, v in uv:
            stream.write(f'vt {u:.8f} {v:.8f}\n')
        stream.write('usemtl board\n')
        for a, b, c in faces + 1:
            stream.write(f'f {a}/{a} {b}/{b} {c}/{c}\n')
    meshes = pymeshlab.MeshSet()
    meshes.load_new_mesh(str(obj))
    meshes.meshing_decimation_quadric_edge_collapse_with_texture(
        targetfacenum=TARGET_FACES, qualitythr=0.8, extratcoordw=8.0,
        preserveboundary=True, preservenormal=True)
    result = meshes.current_mesh()
    positions = result.vertex_matrix().astype(np.float32)
    triangles = result.face_matrix().astype(np.int32)
    wedge_uv = result.wedge_tex_coord_matrix().astype(np.float32)
    # Preserve per-corner UVs, including all atlas seams. A vertex may have
    # multiple UVs; pair the source vertex ID with the exact corner UV.
    corners = np.empty(len(triangles) * 3, dtype=[('vertex', '<i4'), ('u', '<f4'), ('v', '<f4')])
    corners['vertex'] = triangles.reshape(-1)
    corners['u'] = wedge_uv[:, 0]
    corners['v'] = wedge_uv[:, 1]
    unique, remapped = np.unique(corners, return_inverse=True)
    return positions[unique['vertex']], remapped.reshape(-1, 3).astype(np.int32), np.stack((unique['u'], unique['v']), axis=1)


def write_section(part, vertices, faces, uv):
    section = trimesh.Trimesh(vertices=vertices, faces=faces, process=False)
    section.visual = trimesh.visual.TextureVisuals(uv=uv)
    section_scene = trimesh.Scene()
    section_scene.add_geometry(section, node_name=f'RavenwoodSection{part:02d}', geom_name=f'RavenwoodSection{part:02d}')
    destination = OUTPUT / f'ravenwood_section_{part:02d}.glb'
    destination.write_bytes(section_scene.export(file_type='glb'))
    gltf = GLTF2().load(str(destination))
    accessor = gltf.accessors[gltf.meshes[0].primitives[0].indices]
    if len(vertices) >= 65536 or accessor.componentType != 5125 or accessor.byteOffset != 0:
        raise RuntimeError(f'Section {part} cannot use 16-bit indices')
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
    print(f'[ravenwood] {destination.name}: {len(faces):,} triangles, {destination.stat().st_size/1024/1024:.1f} MiB', flush=True)


def main(source):
    scene = trimesh.load(source, force='scene', process=False)
    if len(scene.geometry) != 1:
        raise RuntimeError('Expected one board mesh')
    mesh = next(iter(scene.geometry.values()))
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for key, filename in (('baseColorTexture', 'ravenwood_albedo.jpg'),
                          ('normalTexture', 'ravenwood_normal.jpg'),
                          ('metallicRoughnessTexture', 'ravenwood_metal_rough.jpg')):
        image = getattr(mesh.visual.material, key, None)
        if image is None:
            raise RuntimeError(f'Missing {key}')
        image.resize((TEXTURE_SIZE, TEXTURE_SIZE), Image.Resampling.LANCZOS).convert('RGB').save(
            OUTPUT / filename, format='JPEG', quality=88, subsampling=0)
    with tempfile.TemporaryDirectory(prefix='ravenwood-uv-') as temporary:
        vertices, faces, uv = decimate_with_uvs(
            np.asarray(mesh.vertices, dtype=np.float32), np.asarray(mesh.faces, dtype=np.int32),
            np.asarray(mesh.visual.uv, dtype=np.float32), OUTPUT / 'ravenwood_albedo.jpg', Path(temporary))
    centers = vertices[faces].mean(axis=1)
    order = np.lexsort((centers[:, 2], centers[:, 0]))
    for part, indices in enumerate(np.array_split(order, PARTS)):
        selected = faces[indices]
        used, inverse = np.unique(selected.reshape(-1), return_inverse=True)
        write_section(part, vertices[used], inverse.reshape(-1, 3), uv[used])
    for stale in OUTPUT.glob('ravenwood_section_*.glb'):
        if int(stale.stem.rsplit('_', 1)[-1]) >= PARTS:
            stale.unlink()
    print(f'[ravenwood] {len(faces):,} UV-preserving triangles from {len(mesh.faces):,} source triangles', flush=True)


if __name__ == '__main__':
    main(Path(sys.argv[1]))
