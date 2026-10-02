# Ravenwood board mobile pipeline

`prepare_ravenwood_board.py` reduces the 1,915,206-triangle original to **650,000 triangles** using MeshLab's texture-aware quadric decimation. It retains the original UV atlas and splits the result into ten sections with 16-bit indices. The three 2048px PBR atlases are stored once, then applied as one shared material in `ravenwood_preview.gd`. Total board assets are about 15 MB rather than 65 MB in the full-detail build.

The earlier geometry-only decimator produced black cracks and was rejected. Texture-aware candidates were rendered against the original at overview and close camera distances. The 650k version retains trees, bridges, ruins, riverbanks, and board frame in those comparisons. Keep the original source GLB outside the game project as the quality reference. Device inspection should precede further simplification.

Regenerate: `python native/tools/prepare_ravenwood_board.py path/to/source.glb` (requires `numpy`, `trimesh`, `pillow`, `pymeshlab`, `pygltflib`). The movement layer and grid remain in `generated/ravenwood_nav_surface.glb` and `native/data/generated/ravenwood_nav_grid.json` and can be regenerated with `python native/tools/generate_ravenwood_nav_surface.py`. The preview opens from Ravenwood on the world map.
