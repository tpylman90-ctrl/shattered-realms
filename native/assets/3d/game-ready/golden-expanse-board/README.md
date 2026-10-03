# Golden Expanse board

This board is generated in-repo with `python native/tools/generate_golden_expanse_board.py` (NumPy and Pillow). No third-party 3D conversion is needed.

The script deterministically produces a sculpted desert GLB, a separate hex outline GLB, and `native/data/generated/golden_expanse_nav_grid.json` from the same terrain height function. The graph contains 1,938 connected cells. The oasis, sandstone clusters and canyon are blocked; both wooden bridges provide continuous paths across the canyon. Caravan roads receive a lower path cost. The authored concept image remains a visual reference, not a perspective texture projected onto the mesh.

The preview lets the player orbit, pan, zoom, toggle the movement grid, and move a scout along calculated paths. The board does not yet contain the campaign encounters, fog, Sunspire city scene or dungeon.
