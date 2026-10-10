# Sundered Vault 2.5D room plates

Six 1672 × 941 painted environment plates form the first playable dungeon route beneath Ashenreach:

1. `vault_entrance.webp` — the broken seal hall and descent into the vault.
2. `lower_crossing.webp` — a junction with an optional route to the rune shrine.
3. `sentinel_gallery.webp` — the Vault Sentinel encounter and the sealed route forward.
4. `rune_shrine.webp` — the healing branch.
5. `ember_bridge.webp` — the trapped volcanic crossing.
6. `ember_seal_chamber.webp` — the relic sanctum.

The room art is kept as static background plates. The player and Sentinel are 3D actors under a fixed perspective camera; their apparent size comes from their real camera depth. The walkmesh polygons are authored in image-space, projected onto the 3D floor, triangulated, and installed as invisible collision geometry. Tap-to-walk routing samples only the walkable polygons, so players cannot cross the painted walls, chasms, or debris.

`vault_banner_column.webp` is a transparent cutout on Sprite3D planes. The entry hall and crossing place these cards at mid and near depths so actors can pass in front of or behind the layered props. The Ember Seal is also a small depth-tested Sprite3D card; the remaining environment stays baked into the plates to keep rendering inexpensive.

All room plates use the same composition and palette: elevated three-quarter view, open lower-center paths, black volcanic basalt, Ashenreach burgundy and bronze, ember fissures, and restrained teal ward light. The imagegen prompts describe the Sundered Vault, not a generic cave, to preserve the territory's volcanic fortress identity.
