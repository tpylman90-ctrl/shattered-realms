# Golden Expanse board

This board is generated in-repo with `python native/tools/generate_golden_expanse_board.py` (NumPy and Pillow). No third-party 3D conversion is needed.

The script deterministically produces a sculpted desert GLB, a separate hex outline GLB, and `native/data/generated/golden_expanse_nav_grid.json` from the same terrain height function. The graph contains 1,938 connected cells. The oasis, sandstone clusters and canyon are blocked; both wooden bridges provide continuous paths across the canyon. Broad sculpted dune crests and height-matched caravan road ribbons make the layout legible from the board camera; roads receive a lower path cost. Layered sandstone, canyon banks, ruined waystations, milestones, and oasis shoreline detail use shared materials and compact geometry. The authored concept image remains available through ART PREVIEW rather than being projected onto the 3D mesh.

The preview lets the player orbit, pan, zoom, toggle the movement grid, view the concept art, and move a scout along calculated paths. The board does not yet contain the campaign encounters, fog, Sunspire city scene or dungeon.
