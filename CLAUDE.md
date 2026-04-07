# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

FlexCoins is a 2D idle game built with **Godot 4.6** using **GDScript**. The game concept is a falling-coin collector with idle progression mechanics, featuring a custom Flexion-branded coin asset (`flexcoin.png`).

The project is in early stage — scaffold only, no scenes or scripts yet.

## Engine & Language

- **Godot 4.6** with Forward Plus renderer
- **GDScript** (not C# or GDExtension)
- Physics engine: Jolt Physics (configured but this is a 2D project)

## Development Commands

- **Open in Godot editor**: `godot project.godot` (or open via Godot Project Manager)
- **Run the game**: `godot --path . --main-scene <scene_path>` or press F5 in editor
- **Run a specific scene**: `godot --path . <scene_path>.tscn` or press F6 in editor
- **Export**: Configure export presets in editor, then `godot --headless --export-release <preset>`

## Architecture Notes

- All game files live under `res://` (project root)
- `.tscn` files are scene definitions, `.gd` files are scripts, `.tres` files are resources
- The `.godot/` directory is generated/cached — it is gitignored
- `project.godot` is the project configuration (entry scene, input maps, settings)

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
- **Autoloads** (singletons) only for truly global concerns (e.g., GameManager, AudioManager)
- **Object pooling** for frequently spawned items (coins) — hide/reposition instead of queue_free() + instantiate
- Use `Area2D` (not RigidBody2D) for falling items with constant velocity
- Use `VisibleOnScreenNotifier2D` to free/recycle offscreen objects
- Use `set_process(false)` on nodes that don't need per-frame updates
