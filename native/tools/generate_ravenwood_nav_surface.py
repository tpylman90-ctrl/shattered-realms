#!/usr/bin/env python3
"""Sample Ravenwood into hex movement GLB and steep-edge-aware grid."""
import json
from pathlib import Path
import generate_ashenreach_nav_surface as nav

ROOT = Path(__file__).resolve().parents[1]
nav.SOURCE = ROOT / 'assets/3d/game-ready/ravenwood-board/ravenwood_board_mobile.glb'
nav.OUTPUT = ROOT / 'assets/3d/game-ready/ravenwood-board/generated/ravenwood_nav_surface.glb'
nav.GRID_OUTPUT = ROOT / 'data/generated/ravenwood_nav_grid.json'
nav.HEX_SIZE_WORLD = 0.42
nav.Q_MIN,nav.Q_MAX = -31,31
nav.R_MIN,nav.R_MAX = -42,42
nav.HEX_RADIUS_LOCAL = nav.HEX_SIZE_WORLD*0.97/nav.TERRAIN_SCALE
MAX_STEP_WORLD = 0.85

def main():
    mesh = nav.scene_to_mesh(nav.SOURCE)
    keys,centers,axial = nav.collect_hex_centers()
    candidates = nav.sample_candidates(mesh,centers)
    selected = nav.choose_supported_surfaces(keys,axial,candidates)
    selected,inferred = nav.infer_bridge_gaps(keys,axial,selected)
    hazards = nav.classify_depression_hazards(keys,axial,selected)
    nav.export_glb(nav.build_nav_mesh(keys,centers,selected),nav.OUTPUT)
    nav.export_grid_json(keys,centers,selected,inferred,hazards,nav.GRID_OUTPUT)
    data=json.loads(nav.GRID_OUTPUT.read_text())
    tiles=data['tiles']
    steep=0
    for key,tile in tiles.items():
        q,r=map(int,key.split(','))
        blocked=[]
        traversable=0
        for dq,dr in nav.DIRECTIONS:
            neighbor_key=f'{q+dq},{r+dr}'
            neighbor=tiles.get(neighbor_key)
            if neighbor is None: continue
            if abs(tile['y']-neighbor['y'])>MAX_STEP_WORLD: blocked.append(neighbor_key)
            else: traversable+=1
        tile['blocked_edges']=blocked
        if traversable<2: tile['auto_blocked']=True
        steep+=len(blocked)
    data['max_step_height']=MAX_STEP_WORLD
    data['region']='ravenwood'
    nav.GRID_OUTPUT.write_text(json.dumps(data,separators=(',',':')))
    print(f'[ravenwood] {len(tiles):,} tiles, {steep//2:,} steep edges, nav {nav.OUTPUT.stat().st_size/1024:.1f} KiB')

if __name__ == '__main__':main()
