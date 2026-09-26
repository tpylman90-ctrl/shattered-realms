#!/usr/bin/env python3
"""Build-time extraction of a single playable hero from multi-pose presentation GLBs.

The source hero files contain a front pose, back pose and collectible chest piece
baked into one mesh. This script keeps connected mesh components on the playable
(front-pose) side and rewrites only the primitive index accessor. Original source
assets remain untouched for collection/relic presentation.
"""
from array import array
import json
import os
import struct
import sys

JCHUNK = 0x4E4F534A
BCHUNK = 0x004E4942

def read_glb(path):
    raw = bytearray(open(path, "rb").read())
    magic, version, total = struct.unpack_from("<4sII", raw, 0)
    if magic != b"glTF" or version != 2:
        raise RuntimeError(f"Unsupported GLB: {path}")
    off = 12
    json_len, json_type = struct.unpack_from("<II", raw, off); off += 8
    if json_type != JCHUNK:
        raise RuntimeError("Missing JSON chunk")
    json_start = off
    doc = json.loads(bytes(raw[off:off+json_len]).decode("utf-8").rstrip(" \x00"))
    off += json_len
    bin_len, bin_type = struct.unpack_from("<II", raw, off); off += 8
    if bin_type != BCHUNK:
        raise RuntimeError("Missing BIN chunk")
    return raw, doc, json_start, json_len, off, bin_len

def accessor_view(raw, doc, bin_start, accessor_index):
    acc = doc["accessors"][accessor_index]
    bv = doc["bufferViews"][acc["bufferView"]]
    start = bin_start + bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
    return acc, bv, start

def extract(source, output, x_center_threshold):
    raw, doc, json_start, json_len, bin_start, _ = read_glb(source)
    prim = doc["meshes"][0]["primitives"][0]

    pos_acc, _, pos_start = accessor_view(raw, doc, bin_start, prim["attributes"]["POSITION"])
    if pos_acc["componentType"] != 5126 or pos_acc["type"] != "VEC3":
        raise RuntimeError("Expected float VEC3 positions")
    pos_count = pos_acc["count"]
    pos = array("f")
    pos.frombytes(bytes(raw[pos_start:pos_start + pos_count * 12]))

    idx_acc, _, idx_start = accessor_view(raw, doc, bin_start, prim["indices"])
    if idx_acc["type"] != "SCALAR":
        raise RuntimeError("Expected scalar indices")
    if idx_acc["componentType"] == 5125:
        code, stride = "I", 4
    elif idx_acc["componentType"] == 5123:
        code, stride = "H", 2
    else:
        raise RuntimeError("Unsupported index type")

    indices = array(code)
    indices.frombytes(bytes(raw[idx_start:idx_start + idx_acc["count"] * stride]))

    parent = list(range(pos_count))
    rank = bytearray(pos_count)

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    def union(a, b):
        ra, rb = find(a), find(b)
        if ra == rb:
            return
        if rank[ra] < rank[rb]:
            ra, rb = rb, ra
        parent[rb] = ra
        if rank[ra] == rank[rb]:
            rank[ra] += 1

    for i in range(0, len(indices), 3):
        a, b, c = indices[i], indices[i+1], indices[i+2]
        union(a, b); union(b, c)

    min_x, max_x = {}, {}
    for v in range(pos_count):
        r = find(v)
        x = pos[v * 3]
        if r not in min_x:
            min_x[r] = max_x[r] = x
        else:
            if x < min_x[r]: min_x[r] = x
            if x > max_x[r]: max_x[r] = x

    keep_roots = {
        r for r in min_x
        if (min_x[r] + max_x[r]) * 0.5 < x_center_threshold
    }

    kept = array(code)
    used = set()
    for i in range(0, len(indices), 3):
        a = indices[i]
        if find(a) in keep_roots:
            a, b, c = indices[i], indices[i+1], indices[i+2]
            kept.extend((a, b, c))
            used.update((a, b, c))

    if not kept:
        raise RuntimeError(f"No geometry selected for {source}")

    kept_bytes = kept.tobytes()
    raw[idx_start:idx_start + len(kept_bytes)] = kept_bytes
    idx_acc["count"] = len(kept)

    # Keep the existing JSON chunk size so the BIN chunk offset remains unchanged.
    new_json = json.dumps(doc, separators=(",", ":")).encode("utf-8")
    if len(new_json) > json_len:
        raise RuntimeError("Updated JSON no longer fits original JSON chunk")
    new_json += b" " * (json_len - len(new_json))
    raw[json_start:json_start + json_len] = new_json

    os.makedirs(os.path.dirname(output), exist_ok=True)
    with open(output, "wb") as f:
        f.write(raw)

    xs = [pos[v*3] for v in used]
    ys = [pos[v*3+1] for v in used]
    zs = [pos[v*3+2] for v in used]

    # Ground the generated playable piece: shift the entire position buffer so
    # the lowest vertex used by the selected hero sits exactly at local Y=0.
    min_y_used = min(ys)
    ground_offset = -min_y_used
    if abs(ground_offset) > 1e-8:
        for v in range(pos_count):
            pos[v * 3 + 1] += ground_offset
        pos_bytes = pos.tobytes()
        raw[pos_start:pos_start + len(pos_bytes)] = pos_bytes
        ys = [y + ground_offset for y in ys]

    print(
        f"{os.path.basename(output)}: {len(kept)//3} triangles, "
        f"bounds x=({min(xs):.3f},{max(xs):.3f}) "
        f"y=({min(ys):.3f},{max(ys):.3f}) "
        f"z=({min(zs):.3f},{max(zs):.3f})"
    )

if __name__ == "__main__":
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    heroes = os.path.join(root, "assets", "3d", "heroes")
    generated = os.path.join(heroes, "generated")

    jobs = [
        (
            os.path.join(heroes, "c8e77735-5007-49e1-bd65-7588443969df-glb-2048-cachehit_eb682eeb80c6cb205f1321287f05cd39.glb"),
            os.path.join(generated, "vesper_single.glb"),
            -0.10,
        ),
        (
            os.path.join(heroes, "08f82aae-ba7a-4eb7-9491-097fd56b8b3f_67b8de66283912f7e65b8a74c3120ba0.glb"),
            os.path.join(generated, "ignis_single.glb"),
            -0.05,
        ),
    ]

    for source, output, threshold in jobs:
        if not os.path.exists(source):
            print(f"Skipping missing source: {source}")
            continue
        extract(source, output, threshold)
