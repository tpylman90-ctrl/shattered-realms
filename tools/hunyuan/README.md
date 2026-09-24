# Hunyuan3D Asset Pipeline

This folder is the integration point for generated 3D assets.

## Intended flow

1. Create or select a concept image.
2. Run Hunyuan3D on a CUDA-capable machine or cloud GPU.
3. Export the result as GLB.
4. Place raw output in `assets/3d/generated/`.
5. Run cleanup/optimization before moving approved assets into `assets/3d/game-ready/`.
6. Game code references only game-ready assets.

## Asset naming

`<realm>_<category>_<asset>_v###.glb`

Examples:

- `ashenreach_city_capital_v001.glb`
- `ashenreach_dungeon_gate_v001.glb`
- `ashenreach_prop_ruined_pillar_v001.glb`

## Production rule

Generated source assets are never treated as final automatically. Every asset should be checked for:
- silhouette
- scale
- normals
- topology
- material count
- texture resolution
- collision requirements
- draw-call cost
- LOD suitability

The game runtime should not depend directly on Hunyuan3D. The generator is an interchangeable build-time tool.
