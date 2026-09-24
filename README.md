# Shattered Realms

Shattered Realms is an early prototype for a world-map strategy/adventure game built around:

- a world divided into territories
- zooming into an individual 2.5D territory board
- fog-of-war exploration
- hero and army movement
- hidden cities, enemies and dungeons
- territory conquest
- reusable territory/dungeon templates
- a build-time AI 3D asset pipeline

## Current prototype

The first build contains:

- world map shell
- Ashenreach as the first selectable territory
- fog-of-war exploration
- movable hero
- hidden city, beast and dungeon POIs
- dungeon transition
- Hunyuan3D asset pipeline directories

## Run it

Download or clone the repository and open `index.html` in a modern browser.

No build step or package install is required for this first prototype.

## 3D asset structure

- `assets/3d/generated/` — raw AI-generated models
- `assets/3d/game-ready/` — approved optimized game assets
- `tools/hunyuan/` — Hunyuan3D workflow and integration tooling

The game runtime is intentionally independent of Hunyuan3D so another generator can be substituted later without rewriting the game.
