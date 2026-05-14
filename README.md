# 2D Game

A top-down bullet hell survival game built with Godot 4.6. Players fight off waves of enemies across multiple maps, collect loot and upgrades, and defeat a boss to unlock the next area.

## Gameplay

- **WASD** to move, **left click** to shoot, **right click** to cast a magic wave
- Kill enemies to earn XP and level up — each level triggers an upgrade screen
- Collect coins to spend at the shop between runs
- Collect **boss tokens** dropped by enemies to trigger the map boss
- Defeat the boss to unlock the next map

## Enemy Types

| Enemy | Behaviour |
|---|---|
| Spider | Fast melee chaser |
| Blob | Slow, high-damage melee bruiser |
| Triangle | Ranged, orbits the player and fires projectiles |
| Boss Goblin | Melee + ranged spread, scales per map |

## Maps

Maps are unlocked in sequence by defeating each boss.

| Map | Enemies | Boss multiplier |
|---|---|---|
| Cracked Plains | Spider, Blob | 1× |
| Frigid Tundra | Spider, Blob, Triangle | 1.5× HP / 1.3× DMG |
| Depths | Spider, Blob | 2.5× HP / 2.0× DMG |

## Installation

1. Install [Godot 4.6](https://godotengine.org/download)
2. Clone the repository
3. Open Godot, click **Import**, and select the `project.godot` file
4. Press **F5** or click the Play button to run

> Sprite sheets are embedded directly in `.tscn` files via the [AsepriteWizard](https://github.com/viniciusgerevini/godot-aseprite-wizard) plugin. If you add new sprites, open the scene in the editor and use the plugin panel to regenerate the frames.

## Project Structure

```
scenes/          # Top-level scene files
  main.tscn      # Gameplay scene (enemy spawning, environment)
  map_selection.tscn
  game_over.tscn
  shop.tscn
  stats_screen.tscn

scripts/
  characters/    # Player, all enemy types, projectiles
  effects/       # Pickups (coin, health, ammo, crate, boss token), particles
  environment/   # Procedural world generation (trees, grass, walls, clouds)
  ui/            # HUD labels, boss health bar, menus, upgrade/shop screens
  utils/         # Shared helpers (floating text, flash shader utils)
  game_state.gd  # Autoload — current run state (kills, boss flags, map config)
  player_stats.gd # Autoload — persistent stats across maps (XP, coins, upgrades)

prefabs/
  enemies/       # Spider, Blob, Triangle, Boss Goblin scenes
  environment/   # Grass variants
  items/         # Coin, health pickup, ammo pickup, crate, boss token
  projectiles/   # Player bullet, enemy bullet
  ui/            # Boss arrow, map card, upgrade/shop UI scenes

assets/
  fonts/
  shaders/       # Gold glow, blue glow, white flash
  sprites/
    backgrounds/
    characters/
    environment/
    items/

addons/
  AsepriteWizard/ # Sprite sheet import plugin
```
