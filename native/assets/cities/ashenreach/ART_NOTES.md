# Ashenreach city scene art

These are fixed-camera background plates for the 2.5D city exploration scene. The player sprite is rendered separately at low resolution with nearest-neighbor filtering and sorted by floor Y position.

The plaza and market use compact, warm timber-town street plates. The forge, inn, keep, and gate images are connected camera scenes. The high-resolution scenery remains still while the small sprite walks over it.

- `market.jpg` — OpenAI ImageGen output `exec-c78c8e21-e06a-46ba-b57b-79726d262bf5.png`, generated with `ashenreach_city.jpg` as the visual reference.
- `forge.jpg` — OpenAI ImageGen output `exec-000b19cd-e070-46a1-8c1e-afb0f3f16426.png`.
- `inn.jpg` — OpenAI ImageGen output `exec-dfcd4d11-f244-47e4-ba83-5cb1b431224c.png`.
- `keep.jpg` — OpenAI ImageGen output `exec-b29d651e-7588-426c-94e8-4b9d7bebb245.png`.
- `gate.jpg` — OpenAI ImageGen output `exec-6bece8ea-cc18-44c8-9c7d-021b805dabab.png`.

Each scene plate is 1672 × 941 pixels and was converted to optimized progressive JPEG at quality 89 for Android delivery. Original PNG outputs remain in the generation workspace.

## Market lane prompt

Create a wide 16:9 cinematic environment background for an original fantasy RPG city scene called Ashenreach Forge. Match the warm high-detail painterly 3D diorama atmosphere of the supplied Ashenreach city reference: grounded medieval stone-and-timber architecture, soot-dark stone, glowing forge hearths, hanging hammers and tongs, anvil, stacked ore, ember sparks, timber rafters, copper lanterns, orange light, rich realistic surface detail, atmospheric depth. This is one fixed-camera game background image with the camera at a slight elevated three-quarter angle looking into the forge workshop. Leave a clear walkable stone floor area across the lower center foreground for a small pixel-art player sprite composited over it. Keep the central walkway open and unobstructed. No people, no characters, no text, no UI, no labels, no watermark. Sharp, high-resolution, coherent realistic painted game background, not toy-like, no visible grid.

## Forge prompt

Wide 16:9 fixed-camera background painting for an original fantasy RPG, inside the Ashenreach blacksmith forge workshop. The entire scene is indoors: heavy rough-hewn timber ceiling beams across the top, thick stone walls, two blazing blacksmith hearths built into the back wall, anvil and bellows, hanging hammers and tongs, racks of swords and shields, ore bins, scattered coal, ember light and warm copper lanterns. Camera from the entrance looking inward at a three-quarter angle, cozy but large working forge, cinematic depth, richly detailed realistic painterly game environment, medieval grounded materials, warm firelight against cool smoky shadows. Leave a broad empty stone floor in the lower middle foreground as a clear walkable area for a small pixel-art player sprite composited over it. Keep the central walkway open and unobstructed. No people, no characters, no text, no UI, no labels, no watermark. Sharp, high-resolution, coherent realistic painted game background, not toy-like, no visible grid.

## Inn prompt

Wide 16:9 fixed-camera background illustration for an original fantasy RPG, inside a welcoming medieval inn in Ashenreach, a mountain stronghold city. Large timber beams, stone fireplace glowing amber, tavern tables and benches, a long wooden bar with mugs and bottles, stairway to upper rooms, red-and-gold Ashenreach banners, candle lanterns, cozy late-evening warmth, rainy mountain light visible through small windows. Camera from the entry looking across the common room in a three-quarter perspective, cinematic richly detailed painterly realism, believable worn wood and stone. Keep the lower center floor between the entry and hearth open for a small pixel-art player sprite to walk across. No people, no characters, no text, no letters, no UI, no watermark, no grid. High-resolution game background, grounded fantasy, not toy-like.

## Keep prompt

Wide 16:9 fixed-camera illustrated game background for an original high fantasy RPG, inside the great hall of Ashenreach Keep, a formidable mountain city fortress. Grand but believable medieval stone keep interior, soaring ribbed timber-and-stone ceiling, massive pillars, red-and-gold heraldic banners with a simple abstract flame crest (no letters), tall narrow windows with mountain daylight, a broad stone dais and carved wooden council table at the far end, braziers and wall torches, layered archways suggesting halls beyond. Camera at the entrance looking down the central aisle in a three-quarter perspective, painterly realistic environment art, rich stone and cloth detail, cinematic scale and atmospheric depth. Keep a clear walkable central floor from foreground toward the dais for a tiny low-resolution pixel-art adventurer sprite overlaid later. No people or characters, no text, no UI, no watermark, no grid, no toy-like style.

## Gate prompt

Wide 16:9 fixed-camera exterior environment background for an original fantasy RPG, the main gate road of Ashenreach, a fortified mountain city. View from within the city looking toward enormous open stone gates between layered round towers, red-and-gold flame banners, timber balconies and stone guard walls, beyond the arch a winding mountain road descends toward pine forest and distant snow peaks with a faint volcanic orange glow. Late afternoon light, cinematic atmospheric painterly realism, rich believable medieval detail, same grounded world as a high-budget fantasy RPG. Broad empty cobbled road across the lower center foreground for a small low-resolution pixel-art player sprite overlay; keep path clear and visible. No people, no characters, no text, no UI, no letters, no watermark, no grid, not toy-like.

## 2.5D interiors and dialogue portraits

These additions move the forge, inn, and keep from exterior-style plates into fixed angled room scenes. Godot draws the room as a detailed high-resolution environment plate and sorts low-resolution character sprites by their floor Y position. NPC portrait art appears in the dialogue panel; no generated image contains game UI or text.

- `forge_interior.webp` — source `exec-8a4a5f86-c18f-4730-b598-a5d9c606606a.png`; 1439 × 810, WebP quality 84.
- `inn_interior.webp` — source `exec-ede8fa10-73ae-4b92-b0ab-c3bde3ff343e.png`; 1439 × 810, WebP quality 84.
- `keep_interior.webp` — source `exec-a9aae3ed-f1b6-4d23-8537-6cb686cab8ae.png`; 1439 × 810, WebP quality 84.
- `portraits/innkeeper.webp` — source `exec-4d8994b3-ca55-4004-a72e-8a54205691d0.png`; transparent 512 × 480 WebP.
- `portraits/steward.webp` — source `exec-e4340c55-6e6b-4acc-bae2-0646fd61de9a.png`; transparent 512 × 468 WebP.
- `portraits/smith.webp` — source `exec-b2606353-01f7-4935-946e-93dfb72e4a96.png`; transparent 512 × 478 WebP.

### Interior scene prompts

**Keep:** Generate a wide landscape 16:9 background artwork for an interior chamber of Ashenreach Keep in a premium HD-2D JRPG style. Treat the attached game screenshot as a style reference only: fixed elevated three-quarter/isometric camera, compact explorable room, strong room depth, detailed environment with soft cinematic light and layered cutaway walls. Scene: a fortified lord's audience and map room, raised oak command table with maps, tall stone windows, banners, book shelves, iron-bound doors, braziers, a modest seat of rule, clear central flagstone floor and visible paths between points. Ashenreach's medieval frontier identity, firelight, deep stone shadows, realistic proportions, richly detailed environment, not toy-like, not cute, not blocky. The room fills almost the entire frame and remains readable at game scale. Environment background only: absolutely no people, characters, sprites, text, signs, UI, portraits, speech bubbles, or logos. Avoid an exterior street/city view.

**Inn:** Generate a wide landscape 16:9 background artwork for the interior of Ashenreach's Wayfarer Inn in a premium HD-2D JRPG style. Treat the attached game screenshot as a style reference only: fixed elevated three-quarter/isometric camera, compact explorable room, strong room depth, crisp detailed environment with a softly cinematic light bloom, layered architecture and cutaway walls. Scene: a warm old stone-and-timber inn common room, long dark oak counter with shelves and mugs along the back wall, hearth glowing on one side, tables and benches, stairway to rooms, a clear central stone floor with open walking space. Ashenreach's medieval frontier identity, rich amber light, worn textures, realistic proportions and high detail, not toy-like, not cute, not blocky. The room fills almost the entire frame and remains readable at game scale. Environment background only: absolutely no people, characters, sprites, text, signs, UI, portraits, speech bubbles, or logos. Avoid an exterior street/city view.

**Forge:** Generate a wide landscape 16:9 background artwork for the interior of Ashenreach's blacksmith forge in a premium HD-2D JRPG style. Treat the attached game screenshot as a style reference only: fixed elevated three-quarter/isometric camera, compact explorable room, strong depth, detailed environment with soft cinematic light, layered architecture and cutaway walls. Scene: a large stone forge room with a glowing furnace, anvil and hammer station, weapon racks, workbench, bellows, coal bins, hanging tools, a side doorway and a clear central stone floor with space to walk. Medieval frontier workmanship, warm firelight against cool stone shadows, realistic scale, deeply textured materials, sophisticated game environment, not toy-like, not cute, not blocky. The room fills almost the entire frame and remains readable at game scale. Environment background only: absolutely no people, characters, sprites, text, signs, UI, portraits, speech bubbles, or logos. Avoid an exterior city view.

### Portrait prompts

Each portrait was generated with this exact prompt; the role-specific description was substituted for the character description: `Create a single character bust portrait for a fantasy JRPG dialogue screen, with transparent background. Use the attached screenshot as a style reference for painterly anime game portrait only, ignore its phone and browser UI. [CHARACTER DESCRIPTION]. Chest-up three-quarter view, facing left toward dialogue text, expressive face, refined painted detail, rich natural palette, clean silhouette, dramatic but soft scene lighting, no frame, no background, no text, no props covering the face.`

- **Innkeeper character description:** Ashenreach Wayfarer Inn keeper: a warm, weathered middle-aged woman with braided auburn hair, kind alert eyes, practical cream blouse, dark green wool vest and brass key ring. Dramatic but soft warm inn lighting.
- **Steward character description:** Ashenreach keep steward and campaign advisor: a disciplined older man with silver-streaked hair, dark blue travel coat, pale gold trim, leather map case strap over shoulder. Thoughtful expression, warm candle rim light against cool shadow.
- **Smith character description:** Ashenreach master smith: a broad middle-aged man with a soot-dark beard, tied-back dark hair, one small healed eyebrow scar, leather apron over a charcoal shirt and a red-brown shoulder mantle. Confident friendly expression, warm forge edge light.


## Classic JRPG street plates

The plaza and market were restyled toward the user's reference: close human-scale half-timber houses, terracotta roof tiles, soft daylight, and broad cobblestone paths. They remain high-resolution fixed camera plates; the hero and residents are separate low-resolution sprites. The main plaza now reads as a walkable town lane instead of a distant fortress panorama.

- `plaza_legacy.webp` — source `exec-1994c1f3-9ecb-4a3f-ad6e-1a8da6ee0eec.png`; 1280 × 720, WebP quality 78.
- `market_legacy.webp` — source `exec-a67acc1d-792e-4ace-8b1a-accc223d1e0d.png`; 1280 × 720, WebP quality 78.
