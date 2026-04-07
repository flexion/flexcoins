# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

FlexCoins is a 2D idle falling-coin collector game built with **Godot 4.6** using **GDScript**. Coins spawn at the top of a portrait viewport (720x1280), fall downward, and the player moves a catcher left/right to collect them for currency. Includes an upgrade shop, save/load persistence, and offline earnings.

## Engine & Language

- **Godot 4.6** with Forward Plus renderer
- **GDScript** (not C# or GDExtension)
- Viewport: 720x1280 (portrait)

## Development Commands

- **Open in Godot editor**: `godot project.godot` (or open via Godot Project Manager)
- **Run the game**: Press F5 in editor (main scene: `res://scenes/main.tscn`)
- **Run a specific scene**: Press F6 in editor, or `godot --path . scenes/coin.tscn`
- **Input actions**: `move_left` (Left arrow / A), `move_right` (Right arrow / D)
- **Save file location**: `user://save.json` (auto-saves every 30s + on quit)

## Architecture

### Scene Tree (main.tscn)
```
Main (Node2D)
├── Background (ColorRect, 720x1280, dark navy)
├── CoinSpawner (Node2D, scripts/coin_spawner.gd)
│   └── Timer (dynamic interval from upgrades)
├── Catcher (instanced, positioned at 360,1000)
│   └── spawns FloatingText on coin collection
└── HUD (instanced, CanvasLayer)
    ├── TopBar > %CurrencyLabel (gold, font 32)
    ├── UpgradePanel (bottom 260px, 4 upgrade buttons)
    └── WelcomePanel (centered popup for offline earnings)
```

### Autoloads
- **GameManager** (`scripts/game_manager.gd`): Single source of truth for game state
  - Currency: `currency`, `add_currency()`, signal `currency_changed`
  - Upgrades: `UPGRADE_DATA` dict, `try_purchase_upgrade()`, `get_upgrade_cost()`, signal `upgrade_purchased`
  - Derived values: `get_spawn_interval()`, `get_coin_value()`, `get_catcher_speed()`, `get_catcher_width()`, `get_earn_rate()`
  - Persistence: `save_game()`, `load_game()`, auto-save Timer (30s), save-on-quit via `NOTIFICATION_WM_CLOSE_REQUEST`
  - Offline: `get_offline_earnings()`, `clear_offline_earnings()`, 50% efficiency, 8hr cap, 60s minimum threshold

### Key Scenes
- **coin.tscn**: Area2D + Sprite2D (flexcoin.png @ 0.4 scale) + CollisionShape2D (circle r=24) + VisibleOnScreenNotifier2D. Value set from `GameManager.get_coin_value()` in `_ready()`.
- **catcher.tscn**: Area2D + ColorRect (dynamic width, blue) + CollisionShape2D (duplicated shape for safe resizing). Reads speed/width from GameManager, spawns floating text on catch.
- **hud.tscn**: CanvasLayer with currency label, upgrade panel (4 buttons created programmatically), and welcome-back popup.
- **upgrade_button.tscn**: Reusable PanelContainer — name/level label, description, buy button. Setup via `setup(id)` before `add_child()`.
- **floating_text.tscn**: Label that tweens up 60px + fades out over 0.7s, then self-frees.

### Upgrade System
| ID | Effect | Base Cost | Growth |
|---|---|---|---|
| spawn_rate | 0.8s × 0.95^level (min 0.1s) | 10 | 1.15 |
| coin_value | 1 + level per coin | 15 | 1.12 |
| catcher_speed | 600 + level × 50 px/s | 10 | 1.15 |
| catcher_width | 100 + level × 15 px | 20 | 1.18 |

### Data Flow
Spawner → instantiates Coins (value from GameManager) → Coins fall → Catcher detects overlap → GameManager.add_currency() → emits currency_changed → HUD updates label. Upgrades: UpgradeButton → GameManager.try_purchase_upgrade() → emits upgrade_purchased → Catcher/Spawner react.

### Important: Signal Timing
GameManager `_ready()` runs before scene nodes (autoload ordering). The `currency_changed` emit in `load_game()` fires before listeners connect. All consumers must read `GameManager.currency` directly in their own `_ready()`.

## GDScript Conventions

- Use **static typing** everywhere: `var speed: float = 200.0`, `func move(delta: float) -> void:`
- Use `@export` for editor-tunable values, never hardcoded magic numbers
- Use `@onready` for node references: `@onready var sprite: Sprite2D = $Sprite2D`
- Naming: `snake_case` for files/functions/variables, `PascalCase` for classes, `UPPER_CASE` for constants
- Signals named in past tense: `coin_collected`, `upgrade_purchased`
- File order: extends → class_name → signals → enums → constants → @export → public vars → private vars → @onready → _ready() → lifecycle → public methods → private methods

## Godot Patterns to Follow

- **Composition over inheritance**: build small reusable scenes (components), instance them into actors
- **Signals go up, calls go down** the scene tree
- **Autoloads** only for truly global concerns (GameManager is the current one)
- Use `Area2D` (not RigidBody2D) for falling items with constant velocity
- Use `VisibleOnScreenNotifier2D` to free offscreen objects
- Use `set_process(false)` on nodes that don't need per-frame updates
- Duck-type checks (`has_method`) for cross-scene interactions
- Duplicate shared sub-resources before modifying (e.g., collision shapes)
