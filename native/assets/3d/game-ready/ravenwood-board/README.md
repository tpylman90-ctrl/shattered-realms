# Ravenwood board

`ravenwood_board_mobile.glb` is the optimized visual board (260,000 triangles, 1,024 px embedded texture atlases). Scale it by `(38,38,38)`.

`generated/ravenwood_nav_surface.glb` is a separate, untextured movement/grounding model with 2,330 hex tiles in the same local coordinates. Keep it hidden during normal play. `native/data/generated/ravenwood_nav_grid.json` gives world positions, hazards, and symmetric `blocked_edges` for neighboring hexes whose height differs by over 0.85 units. The GLB alone does not enforce path rules.

The world map opens `RavenwoodPreview.tscn` to inspect the board and toggle the movement layer. Campaign gameplay is not yet implemented.

Regenerate the visual asset with `python native/tools/prepare_ravenwood_board.py path/to/original.glb` (numpy, scipy, trimesh, fast-simplification, pillow). Regenerate nav with `python native/tools/generate_ravenwood_nav_surface.py` (also rtree). The original 69 MB GLB remains outside the repository.
