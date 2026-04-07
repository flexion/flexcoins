# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

FlexCoins is a 2D idle falling-coin collector game built with **Godot 4.6** using **GDScript**. Coins spawn at the top of a portrait viewport (720x1280), fall downward, and the player moves a catcher left/right to collect them for currency.

## Engine & Language

- **Godot 4.6** with Forward Plus renderer
- **GDScript** (not C# or GDExtension)
- Viewport: 720x1280 (portrait)

## Development Commands

- **Open in Godot editor**: `godot project.godot` (or open via Godot Project Manager)
- **Run the game**: Press F5 in editor (main scene: `res://scenes/main.tscn`)
- **Run a specific scene**: Press F6 in editor, or `godot --path . scenes/coin.tscn`
- **Input actions**: `move_left` (Left arrow / A), `move_right` (Right arrow / D)

## Architecture

### Scene Tree (main.tscn)
```
Main (Node2D)
├── Background (ColorRect, 720x1280, dark navy)
├── CoinSpawner (Node2D, scripts/coin_spawner.gd)
│   └── Timer (fires _on_timer_timeout to spawn coins)
├── Catcher (instanced from scenes/catcher.tscn, positioned at 360,1180)
└── HUD (instanced from scenes/hud.tscn, CanvasLayer)
    └── MarginContainer > VBoxContainer > %CurrencyLabel
```

### Autoloads
- **GameManager** (`scripts/game_manager.gd`): Holds `currency: int`, emits `currency_changed(new_amount)`, exposes `add_currency(amount)`

### Key Scenes
- **coin.tscn**: Area2D + Sprite2D (flexcoin.png @ 0.4 scale) + CollisionShape2D (circle r=24) + VisibleOnScreenNotifier2D. Falls at `fall_speed`, has `value` export. `collect()` calls `queue_free()`. Screen exit also frees.
- **catcher.tscn**: Area2D + ColorRect (100x20 blue placeholder) + CollisionShape2D. Moves via input axis, clamped to viewport. On `area_entered`, checks `has_method("collect")`, scores via GameManager, then calls `collect()`.
- **hud.tscn**: CanvasLayer. Connects to `GameManager.currency_changed` to update `%CurrencyLabel`.

### Data Flow
Spawner → instantiates Coins → Coins fall → Catcher detects overlap → GameManager.add_currency() → emits currency_changed → HUD updates label

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
