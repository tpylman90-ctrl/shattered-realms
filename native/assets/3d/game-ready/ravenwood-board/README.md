# Ravenwood board

The preview scene is accessible from Ravenwood on the world map. Orbit with a drag, pinch or wheel to zoom, and toggle the movement overlay. The campaign, encounters, and city/dungeon entrances remain in development.

The eight `ravenwood_section_*.glb` files contain **all 1,915,206 source triangles and original UV coordinates**. They split the mesh at triangle boundaries, duplicating only shared boundary vertices. The 2048px atlas textures are JPEG encoded to keep each section importable. This fixes the cracked terrain caused by the previous 260k-triangle simplification and nearest-neighbor UV remapping. Do not use `ravenwood_board_mobile.glb` for rendering.

Regenerate the board with `python native/tools/prepare_ravenwood_board.py path/to/source.glb` (`numpy`, `trimesh`, `pillow`, `pygltflib`). The source file stays outside the repository. The movement layer is in `generated/ravenwood_nav_surface.glb` and `native/data/generated/ravenwood_nav_grid.json`; regenerate it with `python native/tools/generate_ravenwood_nav_surface.py`.
