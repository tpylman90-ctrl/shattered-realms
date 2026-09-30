# Shattered Realms

Shattered Realms is a native Godot strategy/adventure game for Android.

## Current vertical slice

The title screen opens a five-region world atlas. **The Ashen Wastes → Ashenreach** is the playable campaign route; the other mapped regions are previews. Entering Ashenreach shows a loading screen with real resource progress. The playable slice currently supports:

- 3D territory-board exploration
- selectable unlocked heroes
- road-constrained movement with terrain grounding
- turn-based movement points
- route previews
- discoverable and claimable points of interest
- visible board encounters that can block routes
- hero health, XP, levels, signature abilities and defeat/retreat
- Inferno-Lord Vulgrim territory threat escalation
- persistent Ashenreach campaign state
- Sundered Vault dungeon entry from the physical Vault Gate
- playable Sundered Vault first chamber
- dungeon encounter, relic recovery and return to Ashenreach
- Android release APK generation through GitHub Actions

## Project layout

- `native/project.godot` — Godot project entry
- `native/scenes/` — territory and dungeon scenes
- `native/scripts/` — gameplay logic
- `native/data/` — world, hero and territory data
- `native/assets/3d/game-ready/` — approved environment assets
- `native/assets/3d/heroes/` — source hero presentation GLBs
- `native/tools/extract_hero_piece.py` — build-time extraction of playable hero figures
- `.github/workflows/android-apk.yml` — signed Android build pipeline

## Android build

Pushes that change `native/**` trigger the Android workflow. The generated artifact is named:

`ShatteredRealms-Android`

The APK uses package id:

`com.shatteredrealms.game`

The workflow retains APK artifacts briefly to avoid exhausting GitHub Actions storage during rapid iteration.

## Asset workflow

Hero presentation GLBs may contain multiple presentation elements. The build pipeline extracts the single playable figure into a generated asset before Godot export. Source GLBs remain intact so relic/presentation content can be separated later.

Creature assets should preferably be supplied as one playable creature per GLB. Encounter behavior is data-driven so new models can replace current placeholders without rewriting territory logic.
