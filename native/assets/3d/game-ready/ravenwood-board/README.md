# Ravenwood board

The twenty `ravenwood_section_*.glb` files contain **all 1,915,206 source triangles and original UV coordinates**, split at triangle boundaries. Each section uses 16-bit indices and has no embedded material or texture. The three 2048px atlases are saved once and assigned as a shared material in `ravenwood_preview.gd`. This avoids embedding eight copies of every texture and prevents the cracked terrain caused by the earlier decimation/UV remapping. The source geometry remains deliberately high detail; future boards should be baked to lower resolution meshes with seam-safe UVs and visual LODs instead of preserving millions of unique triangles by default.

Regenerate with `python native/tools/prepare_ravenwood_board.py path/to/source.glb` (`numpy`, `trimesh`, `pillow`). The source stays outside the repository. The movement surface and grid are in `generated/ravenwood_nav_surface.glb` and `native/data/generated/ravenwood_nav_grid.json`; regenerate with `python native/tools/generate_ravenwood_nav_surface.py`.

The preview opens from Ravenwood on the world map. Drag to orbit, pinch or wheel to zoom, and toggle the movement overlay. Campaign encounters, city and dungeon entrances remain in development.
