# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

FlexCoins is a 2D idle falling-coin collector game built with **Godot 4.6** using **GDScript**. Coins spawn at the top of a landscape viewport (2160x1280), fall downward, and the player moves a catcher left/right to collect them for currency. Includes an upgrade shop (centered popup) and combo multiplier system. Every session starts fresh.

## Engine & Language

- **Godot 4.6** with Forward Plus renderer
- **GDScript** (not C# or GDExtension)
- Viewport: 2160x1280 (landscape)

## Development Commands

- **Godot binary (macOS)**: `/Applications/Godot.app/Contents/MacOS/Godot` — all `godot` commands below assume this is on PATH or aliased
- **Open in Godot editor**: `godot project.godot` (or open via Godot Project Manager)
- **Run the game**: Press F5 in editor (main scene: `res://scenes/main.tscn`)
- **Run a specific scene**: Press F6 in editor, or `godot --path . scenes/coin.tscn`
- **Input actions**: `move_left` (Left arrow / A), `move_right` (Right arrow / D)

## Validation & Testing Infrastructure

### Autoloads
- **DevTools** (`scripts/dev_tools.gd`): File-based command interface for automation, testing, and CI
  - Polls `user://devtools_commands.json` every 100ms, writes results to `user://devtools_results.json`
  - Structured logs: `user://devtools_log.jsonl`
  - User data path (macOS): `~/Library/Application Support/Godot/app_userdata/FlexCoins/`

### Headless Lint (no game running needed)
```bash
# Full project lint (UIDs + scene warnings)
godot --headless --script res://tools/lint_project.gd

# Lint specific scene
godot --headless --script res://tools/lint_project.gd -- --scene res://scenes/main.tscn

# JSON output for CI
godot --headless --script res://tools/lint_project.gd -- --all --json

# Fail on warnings (strict mode)
godot --headless --script res://tools/lint_project.gd -- --all --fail-on-warn
```

### Unit Tests (no game running needed)
```bash
# Run all unit tests
godot --headless --script res://tools/run_tests.gd

# JSON output for CI
godot --headless --script res://tools/run_tests.gd -- --json

# Filter specific test
godot --headless --script res://tools/run_tests.gd -- --filter test_bomb
```

### DevTools CLI (requires game running)
```bash
# Check connection
python3 tools/devtools.py ping

# Screenshots
python3 tools/devtools.py screenshot

# Scene validation
python3 tools/devtools.py validate-all
python3 tools/devtools.py validate --scene res://scenes/main.tscn

# Introspection
python3 tools/devtools.py scene-tree
python3 tools/devtools.py performance
python3 tools/devtools.py get-state --node "/root/GameManager"
python3 tools/devtools.py set-state --node "/root/GameManager" --property currency --value 10000
python3 tools/devtools.py run-method --node "/root/GameManager" --method add_currency --args "[500]"

# Input simulation
python3 tools/devtools.py input press move_left
python3 tools/devtools.py input release move_left
python3 tools/devtools.py input tap move_right --hold 1.5
python3 tools/devtools.py input clear
python3 tools/devtools.py input list

# Input sequences (automated test scripts)
python3 tools/devtools.py input sequence test/sequences/move_catcher.json

# Logs
python3 tools/devtools.py logs --tail 20
python3 tools/devtools.py logs --category input
```

### Debug Commands (for E2E testing)
```bash
# Coin control
python3 tools/devtools.py spawn-coin --type GOLD --x 360
python3 tools/devtools.py spawn-coin-on-catcher --type SILVER
python3 tools/devtools.py get-active-coins
python3 tools/devtools.py clear-coins

# State shortcuts
python3 tools/devtools.py set-upgrade-levels --spawn-rate 10 --coin-value 5
python3 tools/devtools.py reset-session

# Time control
python3 tools/devtools.py set-game-speed 10.0
python3 tools/devtools.py wait-frames 60

# Composite queries
python3 tools/devtools.py get-catcher-state

# UI validation
python3 tools/devtools.py validate-ui
python3 tools/devtools.py ui-snapshot
python3 tools/devtools.py ui-snapshot --json
python3 tools/devtools.py node-bounds "/root/Main/HUD/TopBar/CurrencyLabel"
```

### Runtime Validation Workflow (from CLI)
```bash
# Launch game in background
/Applications/Godot.app/Contents/MacOS/Godot --path . &

# Wait for startup, then validate
sleep 5 && python3 tools/devtools.py ping
python3 tools/devtools.py validate-all
python3 tools/devtools.py get-state --node "/root/GameManager"
python3 tools/devtools.py input sequence test/sequences/move_catcher.json
python3 tools/devtools.py performance

# Clean shutdown
python3 tools/devtools.py quit
```

### Pre-commit Validation Checklist (REQUIRED)
**You MUST run runtime validation before every commit that modifies scripts or gameplay.** Do not skip this step — review sub-agents cannot catch runtime errors.

**Preferred:** Use the `/verify` command (`.claude/commands/verify.md`) which automates the full 5-phase workflow below.

**Manual steps (if `/verify` is unavailable):**
1. After modifying scenes: `godot --headless --script res://tools/lint_project.gd`
2. After modifying scripts: launch game + `python3 tools/devtools.py validate-all` + `python3 tools/devtools.py validate-ui`
3. After modifying gameplay: launch game + test with `spawn-coin-on-catcher`, `input tap`, `screenshot`, and `performance`
4. Verify: 0 orphan nodes, no FPS drops, no script errors in game output

### Key Files
| File | Purpose |
|---|---|
| `scripts/dev_tools.gd` | DevTools autoload (command handler) |
| `scripts/scene_validator.gd` | Runtime scene validation (static + instantiation) |
| `tools/lint_project.gd` | Headless UID/NodePath linter |
| `tools/run_tests.gd` | Headless unit test runner (127 tests) |
| `tools/devtools.py` | Python CLI client for DevTools |
| `scripts/ci_test.sh` | CI orchestration (lint → tests → E2E) |
| `.claude/commands/verify.md` | `/verify` command — automated pre-commit validation |
| `test/unit/*.gd` | Unit tests (GameManager, upgrade formulas) |
| `test/sequences/*.json` | Input sequence E2E test scripts |

## Architecture

### Scene Tree (main.tscn)
```
Main (Node2D)
├── Background (ColorRect, 2160x1280, dark navy)
├── CoinSpawner (Node2D, scripts/coin_spawner.gd)
│   └── Timer (dynamic interval from upgrades)
├── Catcher (instanced, positioned at 1080,960)
│   └── spawns FloatingText on coin collection
└── HUD (instanced, CanvasLayer)
    ├── TopBar > %CurrencyLabel (gold, font 48)
    ├── BottomBar (Shop + Settings buttons, bottom center)
    └── UpgradePanel (centered popup 500x600, z_index: 160)
```

### Autoloads
- **GameManager** (`scripts/game_manager.gd`): Single source of truth for game state (loads first)
- **DevTools** (`scripts/dev_tools.gd`): Automation/testing command interface (loads second; see Validation section above)
- **GameManager** details:
  - Currency: `currency`, `add_currency()`, signal `currency_changed`
  - Upgrades: `UPGRADE_DATA` dict, `try_purchase_upgrade()`, `get_upgrade_cost()`, signal `upgrade_purchased`
  - Derived values: `get_spawn_interval()`, `get_coin_value()`, `get_catcher_speed()`, `get_catcher_width()`, `get_earn_rate()`

### Key Scenes
- **coin.tscn**: Area2D + Sprite2D (flexcoin.png @ 0.4 scale) + CollisionShape2D (circle r=24) + VisibleOnScreenNotifier2D. Value set from `GameManager.get_coin_value()` in `_ready()`.
- **catcher.tscn**: Area2D + ColorRect (dynamic width, blue) + CollisionShape2D (duplicated shape for safe resizing). Reads speed/width from GameManager, spawns floating text on catch.
- **hud.tscn**: CanvasLayer with currency label and upgrade panel (4 buttons created programmatically).
- **upgrade_button.tscn**: Reusable PanelContainer — name/level label, description, buy button. Setup via `setup(id)` before `add_child()`.
- **floating_text.tscn**: Label that tweens up 60px + fades out over 0.7s, then self-frees. Spawned by Catcher with `z_index: 10` (world layer).

### Coin Types

Coins have a `CoinType` enum with four variants, each with distinct behaviors and visual effects:

| Type | Base Value | Speed | Color | Effect |
|---|---|---|---|---|
| **SILVER** | 1 (modified by coin_value upgrade) | 1.0x | Gold | Standard coin, primary income source |
| **GOLD** | 5x base value | 1.5x | Yellow-gold | Rare high-value coins, fall faster |
| **FRENZY** | 0 (no currency gain) | 1.0x | Green | Triggers 5-second frenzy mode, spawns increased coin rate |
| **BOMB** | 0 (no currency gain) | 0.8x | Red | Reduces catcher width to 60% for 3 seconds, deducts 10% of current currency |

All coin types display a glow effect and particle trail while falling. Coins spawn at random rotations and accelerate smoothly from 15% to full speed over the first frames. Spawn rates are controlled by the **spawn_rate** upgrade; actual coin type distribution is randomized at spawn time.

### Catcher Visual Tiers

The catcher progresses through four visual milestones as the **catcher_width** upgrade increases:

| Tier | Width Level Range | Appearance | Visual Details |
|---|---|---|---|
| **Tier 0** | Levels 0–9 | Blue (default) | `Color(0.29, 0.56, 0.85)` solid rectangle |
| **Tier 1** | Levels 10–19 | Wooden brown | `Color(0.55, 0.35, 0.17)` with grain stripe overlay `Color(0.65, 0.45, 0.25, 0.6)` |
| **Tier 2** | Levels 20–29 | Chrome/silver metallic | `Color(0.7, 0.72, 0.75)` with white highlight stripe `Color(1.0, 1.0, 1.0, 0.4)` |
| **Tier 3+** | Levels 30+ | Rainbow animated | Hue cycles at 1.5x animation speed; stripe strobe offset by +0.3 hue |

Tier progression is automatic and triggered in `catcher.gd:_update_catcher_visual()` when `level / 10` changes. Tiers reset when a bomb hits, reverting the catcher to its current tier based on upgrade level after the 3-second penalty.

### Prestige/Ascension System

**Ascension** is the late-game progression mechanic that allows players to reset currency and upgrades in exchange for a permanent multiplier bonus:

**Trigger Conditions:**
- Available when all four core upgrades (spawn_rate, coin_value, catcher_speed, catcher_width) reach level 15 or higher
- Ascend button appears in the upgrade shop panel only when `can_ascend()` condition is met
- Visible indicator in top-left HUD shows current ascension count and multiplier (e.g., "Ascension 2  (2.25x)")

**Ascension Effects:**
- **Currency reset:** Resets to 0 coins
- **Upgrade reset:** All upgrades return to level 0 (including magnet)
- **Multiplier bonus:** Subsequent coins are worth `1.5^ascension_count` times base value
  - Example: After 3 ascensions, each coin is worth 1.5^3 = 3.375x multiplier applied to `get_coin_value()`
- **Ascension count:** Increments by 1 (session-only, resets on restart)

**Constants:**
- `ASCEND_MIN_LEVEL`: 15 (minimum upgrade level required for all core upgrades)
- `ASCEND_MULTIPLIER`: 1.5 (exponent base for multiplier calculation)
- `CORE_UPGRADES`: `["spawn_rate", "coin_value", "catcher_speed", "catcher_width"]` (magnet excluded from ascension requirements but still reset)

**UI Integration:**
- Ascend button created dynamically in `hud.gd:_create_ascension_ui()`
- Ascension label displays purple text below currency (`Color(0.8, 0.6, 1.0)` in `_create_ascension_ui()`)
- Ascension triggers milestone celebration with "ASCENDED!" text overlay and gold flash animation

### Upgrade System
| ID | Effect | Base Cost | Growth |
|---|---|---|---|
| spawn_rate | 0.8s × 0.95^level (min 0.1s) | 10 | 1.15 |
| coin_value | 1 + level per coin (affected by ascension multiplier) | 15 | 1.12 |
| catcher_speed | 600 + level × 50 px/s | 10 | 1.15 |
| catcher_width | 100 + level × 15 px | 20 | 1.18 |
| magnet | 80 + level × 30 px radius, 100 + level × 40 px/s strength | 25 | 1.20 |

### Data Flow
Spawner → instantiates Coins (value from GameManager) → Coins fall → Catcher detects overlap → GameManager.add_currency() → emits currency_changed → HUD updates label. Upgrades: UpgradeButton → GameManager.try_purchase_upgrade() → emits upgrade_purchased → Catcher/Spawner react.

### Important: Signal Timing
GameManager `_ready()` runs before scene nodes (autoload ordering). All consumers must read `GameManager.currency` directly in their own `_ready()` for the initial value.

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
- **Never reference `class_name` types directly in autoload scripts** — the parser resolves identifiers before all scripts are loaded, causing "not declared in current scope" errors. Use `load("res://path/to/script.gd")` to get the script, then call static methods on it.

## UI Layering & Scene Tree Organization

### Core Principles (P0)

**Scene tree order is the primary z-ordering mechanism.** In Godot, a node's depth in the scene tree determines render order: children draw after parents, and siblings render in declaration order (top to bottom in the editor). Use `z_index` only to override this for exceptional cases (e.g., floating popups over UI panels). Never rely on `z_index` alone—structure the tree first, then adjust `z_index` if needed.

### z_index Conventions

Follow these ranges to maintain visual hierarchy:
- **0–99**: Game world (coins, catcher, backgrounds)
- **100–199**: Base UI (currency label, upgrade buttons)
- **200–299**: Overlays (floating text)
- **1000+**: Debuggers or temporary overlays

Assign `z_index` explicitly in `_ready()` or via the inspector for any node that needs to break tree order. Example:
```gdscript
floating_text.z_index = 250  # Floats above upgrade buttons
```

### CanvasLayer vs Control Nodes

**CanvasLayer** (`layer` property: 0–128) is a scene tree node that offloads rendering to its own stack, independent of `z_index`. Its `layer` property controls which CanvasLayer renders first globally. Use CanvasLayer for:
- **HUD (layer 1)**: fixed on screen, above game world
- **Transient popups (layer 2)**: pause menus, modals
- Each CanvasLayer's children still respect scene tree order and `z_index` internally

**Control nodes** (buttons, labels) auto-anchor to their parent. Set `anchor_*` and `offset_*` to position them, or use `MarginContainer` / `VBoxContainer` for layout. Never set `global_position` on Controls inside a CanvasLayer—use anchors and offsets instead. If a Control must break free from anchoring, reparent it temporarily or use a Node2D wrapper.

### Common Pitfalls

1. **Mixing tree order and z_index confusingly**: A sibling with high `z_index` can render in front of a later sibling with low `z_index`. Always audit the tree structure when visual order is wrong.
2. **Modifying Control position after layout**: Controls recalculate position on parent resize. Set anchors and offsets once; adjust position only in response to user input (e.g., drag).
3. **CanvasLayer children at z_index < 0**: Negative `z_index` within a CanvasLayer renders below its peers, but the entire CanvasLayer may still draw above siblings in lower layers. Test visually.

---

## Architecture (Expanded)

### Updated Scene Tree (main.tscn)

```
Main (Node2D, z_index: 0)
├── Background (ColorRect, 2160x1280, dark navy, z_index: -1)
├── CoinSpawner (Node2D, z_index: 0)
│   ├── Timer (dynamic interval from upgrades)
│   └── [Coins instantiated with z_index: 10]
├── Catcher (Area2D, positioned at 1080,960, z_index: 20)
│   ├── ColorRect (dynamic width/height)
│   ├── CollisionShape2D (duplicated)
│   └── [FloatingText children spawned with z_index: 250]
└── HUD (CanvasLayer, layer: 1)
    ├── TopBar (Control, anchors: top|left)
    │   └── CurrencyLabel (Label, gold font 48)
    ├── BottomBar (HBoxContainer, bottom center)
    │   ├── ShopToggle (Button) - "Shop"
    │   └── GearButton (Button) - "⚙"
    ├── ShopBackdrop (ColorRect, full screen, z_index: 150)
    └── UpgradePanel (PanelContainer, centered popup 500x600, z_index: 160)
        └── Header ("Shop" + Close button) + ScrollContainer
            └── [UpgradeButton instances, created programmatically]
```

**Ordering Rationale:**
- Background (`z_index: -1`) renders first, behind coins and catcher.
- Coins (`z_index: 10`) and Catcher (`z_index: 20`) render in world space above background.
- HUD on CanvasLayer (layer 1) floats above the world.
- Upgrade buttons inside shop popup (`z_index: 160`) render above the shop backdrop (`z_index: 150`).
- Floating text (`z_index: 250`) appears on top.

**Node Placement Rules:**
- All world nodes (coins, catcher) are direct children of Main (Node2D).
- HUD is the sole CanvasLayer; all UI elements are its descendants.
- Control nodes inside HUD use anchors to position (never `global_position`).
- Dynamically spawned nodes (coins, floating text) record their parent at instantiation and inherit `z_index` from GameManager/context.

---

## UI Testing Protocol

1. **Visual verification in editor**: Press F5, spawn coins, verify they appear above background but below HUD. Move catcher left/right—ensure it stays on-screen. Buy an upgrade—panel should not shift.
2. **Layering stress test**: Spawn coins while upgrade panel is open. Verify floating text appears above the panel.
3. **Resolution scaling**: Resize the editor window; HUD elements should reflow via anchors without detaching.

---

## UI Debugging: Canvas Items Viewer

When UI elements render unexpectedly (wrong layer, clipped, or invisible):

1. **Open Canvas Items in the Remote tab**: In Godot Editor, open the **Debugger** (bottom panel, Debugger tab), then click **Canvas Items**.
2. **Inspect node hierarchy**: Expand the tree to see actual render order. A node's indentation shows its depth; siblings under the same parent render in editor order.
3. **Check z_index values**: Hover over a node; the Inspector (right panel) shows its `z_index` and `layer` (if CanvasLayer). A node with `z_index: 250` will render above one with `z_index: 100` even if lower in the tree.
4. **Verify CanvasLayer properties**: Click on HUD (CanvasLayer). Inspector shows `layer: 1`. If a child Control is invisible, check its `visible` property and `modulate.alpha`.
5. **Test dynamic spawns**: In `hud.gd`, add `print("FloatingText z_index: ", floating_text.z_index)` before `add_child()`. Compare against Inspector for mismatch.

---

## Dynamic UI Creation Guidelines

UI nodes created in `scripts/hud.gd` or similar must follow these rules:

- **Set z_index before `add_child()`**: `floating_text.z_index = 250` ensures correct render order from spawn.
- **Parent to the HUD (CanvasLayer)**: `add_child(floating_text)` parents to HUD. The node inherits CanvasLayer context.
- **Use Control for anchored layouts**: Buttons, labels inside panels should be Control nodes with anchors set. Avoid Node2D for fixed UI.
- **Set visibility and modulate atomically**: If tweening opacity, store the starting `modulate` before tweening—do not mix `modulate.alpha` and `visible` state.
- **Example pattern**:
  ```gdscript
  var floating_text: Label = FloatingText.instantiate()
  floating_text.text = "+%d" % coin_value
  floating_text.global_position = catcher_global_pos
  floating_text.z_index = 250  # Above upgrade panel
  add_child(floating_text)
  ```


