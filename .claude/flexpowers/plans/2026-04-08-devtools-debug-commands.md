# DevTools Debug Commands Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use flexpowers:subagent-driven-development (recommended) or flexpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 9 debug commands to DevTools for deterministic E2E test control over coin spawning, game state, time, and catcher queries.

**Architecture:** Extend the existing file-based DevTools command system (`dev_tools.gd` + `devtools.py`). All new handlers follow the same pattern as existing ones: register in `_ready()`, return `Dictionary`. One dispatcher change makes `_check_for_commands()` async-aware. Python CLI adds 9 matching subcommands.

**Tech Stack:** GDScript (Godot 4.6), Python 3 (argparse CLI)

---

## File Map

| Action | File | Responsibility |
|--------|------|---------------|
| Modify | `scripts/dev_tools.gd` (line 101) | Make dispatcher `await`-aware |
| Modify | `scripts/dev_tools.gd` (after line 45) | Register 9 new handler mappings |
| Modify | `scripts/dev_tools.gd` (after line 660) | Add 9 new `_cmd_*` handler functions + `COIN_TYPE_MAP` constant |
| Modify | `tools/devtools.py` (after line 408) | Add 9 new `cmd_*` Python functions |
| Modify | `tools/devtools.py` (after line 509) | Register 9 new argparse subcommands |
| Modify | `CLAUDE.md` | Add debug commands documentation |

---

### Task 1: Make Dispatcher Async-Aware

**Files:**
- Modify: `scripts/dev_tools.gd:101`

- [ ] **Step 1: Change dispatcher to await handler calls**

In `_check_for_commands()`, change line 101 from:
```gdscript
var result: Dictionary = handler.call(args)
```
to:
```gdscript
var result: Dictionary = await handler.call(args)
```

In GDScript, `await` on a non-async function returns immediately, so all 16 existing handlers are unaffected. Only new async handlers (like `wait_frames`) will actually yield.

- [ ] **Step 2: Run headless lint to verify no parse errors**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script res://tools/lint_project.gd`
Expected: No errors mentioning `dev_tools.gd`

---

### Task 2: Coin Control Commands (GDScript)

**Files:**
- Modify: `scripts/dev_tools.gd` — add `COIN_TYPE_MAP` constant, register 4 handlers, implement 4 `_cmd_*` functions

- [ ] **Step 1: Add COIN_TYPE_MAP constant**

Add after line 12 (after the existing constants block):
```gdscript
const COIN_TYPE_MAP: Dictionary = {
	"SILVER": 0,
	"GOLD": 1,
	"FRENZY": 2,
	"BOMB": 3,
}
```
These int values match the `CoinType` enum declaration order in `scripts/coin.gd:3`.

- [ ] **Step 2: Register the 4 coin control handlers in `_ready()`**

Add after line 45 (after the last existing `_handlers` assignment):
```gdscript
	_handlers["spawn_coin"] = _cmd_spawn_coin
	_handlers["spawn_coin_on_catcher"] = _cmd_spawn_coin_on_catcher
	_handlers["get_active_coins"] = _cmd_get_active_coins
	_handlers["clear_coins"] = _cmd_clear_coins
```

- [ ] **Step 3: Implement `_cmd_spawn_coin`**

Add at the end of the file (before the utility functions section, after line 569):
```gdscript
func _cmd_spawn_coin(args: Dictionary) -> Dictionary:
	var type_str: String = args.get("type", "SILVER").to_upper()
	if not COIN_TYPE_MAP.has(type_str):
		return {"success": false, "message": "Unknown coin type: %s" % type_str}

	var coin_scene: PackedScene = load("res://scenes/coin.tscn")
	var coin: Area2D = coin_scene.instantiate()
	coin.coin_type = COIN_TYPE_MAP[type_str]

	var viewport_width := get_tree().root.size.x
	var x: float = args.get("x", randf_range(40.0, viewport_width - 40.0))
	var y: float = args.get("y", -50.0)
	coin.position = Vector2(x, y)

	get_tree().current_scene.add_child(coin)

	return {
		"success": true,
		"message": "Spawned %s coin at (%.0f, %.0f)" % [type_str, x, y],
		"data": {
			"type": type_str,
			"position": {"x": coin.position.x, "y": coin.position.y},
			"value": coin.value,
		},
	}
```

- [ ] **Step 4: Implement `_cmd_spawn_coin_on_catcher`**

```gdscript
func _cmd_spawn_coin_on_catcher(args: Dictionary) -> Dictionary:
	var catchers := get_tree().get_nodes_in_group("catcher")
	if catchers.is_empty():
		return {"success": false, "message": "No catcher node found"}

	var catcher: Node2D = catchers[0]
	var type_str: String = args.get("type", "SILVER").to_upper()
	if not COIN_TYPE_MAP.has(type_str):
		return {"success": false, "message": "Unknown coin type: %s" % type_str}

	var coin_scene: PackedScene = load("res://scenes/coin.tscn")
	var coin: Area2D = coin_scene.instantiate()
	coin.coin_type = COIN_TYPE_MAP[type_str]
	coin.position = Vector2(catcher.position.x, catcher.position.y - 100)

	get_tree().current_scene.add_child(coin)

	return {
		"success": true,
		"message": "Spawned %s coin above catcher at (%.0f, %.0f)" % [type_str, coin.position.x, coin.position.y],
		"data": {
			"type": type_str,
			"position": {"x": coin.position.x, "y": coin.position.y},
			"value": coin.value,
		},
	}
```

- [ ] **Step 5: Implement `_cmd_get_active_coins`**

```gdscript
func _cmd_get_active_coins(_args: Dictionary) -> Dictionary:
	var coins: Array = []
	for child in get_tree().current_scene.get_children():
		if child.has_method("collect"):
			var type_name: String = "SILVER"
			for key: String in COIN_TYPE_MAP:
				if COIN_TYPE_MAP[key] == child.coin_type:
					type_name = key
					break
			coins.append({
				"type": type_name,
				"position": {"x": child.position.x, "y": child.position.y},
				"value": child.value,
				"collected": child._collected,
			})

	return {
		"success": true,
		"message": "%d active coins" % coins.size(),
		"data": {"count": coins.size(), "coins": coins},
	}
```

- [ ] **Step 6: Implement `_cmd_clear_coins`**

```gdscript
func _cmd_clear_coins(_args: Dictionary) -> Dictionary:
	var cleared: int = 0
	for child in get_tree().current_scene.get_children():
		if child.has_method("collect"):
			child.queue_free()
			cleared += 1

	return {
		"success": true,
		"message": "Cleared %d coins" % cleared,
		"data": {"cleared": cleared},
	}
```

- [ ] **Step 7: Run headless lint**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script res://tools/lint_project.gd`
Expected: No errors mentioning `dev_tools.gd`

---

### Task 3: State Shortcut Commands (GDScript)

**Files:**
- Modify: `scripts/dev_tools.gd` — register 2 handlers, implement 2 `_cmd_*` functions

- [ ] **Step 1: Register the 2 state shortcut handlers in `_ready()`**

Add after the coin control handler registrations:
```gdscript
	_handlers["set_upgrade_levels"] = _cmd_set_upgrade_levels
	_handlers["reset_session"] = _cmd_reset_session
```

- [ ] **Step 2: Implement `_cmd_set_upgrade_levels`**

```gdscript
func _cmd_set_upgrade_levels(args: Dictionary) -> Dictionary:
	var warnings: Array = []
	for key: String in args:
		if GameManager.UPGRADE_DATA.has(key):
			GameManager._upgrade_levels[key] = int(args[key])
			GameManager.upgrade_purchased.emit(key)
		else:
			warnings.append("Unknown upgrade key: %s" % key)

	var result: Dictionary = {
		"success": true,
		"message": "Upgrade levels updated",
		"data": {"levels": GameManager._upgrade_levels.duplicate()},
	}
	if not warnings.is_empty():
		result["data"]["warnings"] = warnings
	return result
```

- [ ] **Step 3: Implement `_cmd_reset_session`**

```gdscript
func _cmd_reset_session(_args: Dictionary) -> Dictionary:
	var previous: Dictionary = {
		"currency": GameManager.currency,
		"upgrade_levels": GameManager._upgrade_levels.duplicate(),
		"ascension_count": GameManager.ascension_count,
		"combo_multiplier": GameManager._combo_multiplier,
	}

	GameManager.currency = 0
	for id: String in GameManager._upgrade_levels:
		GameManager._upgrade_levels[id] = 0
	GameManager.ascension_count = 0
	GameManager._combo_multiplier = 1.0
	GameManager._last_milestone = 0

	if GameManager.frenzy_active and GameManager._frenzy_timer != null:
		GameManager._frenzy_timer.stop()
		GameManager.frenzy_active = false
		GameManager.frenzy_ended.emit()

	GameManager.currency_changed.emit(0)
	GameManager.upgrade_purchased.emit("")
	GameManager.combo_multiplier_changed.emit(1.0)

	return {
		"success": true,
		"message": "Session reset to fresh state",
		"data": {"previous": previous},
	}
```

- [ ] **Step 4: Run headless lint**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script res://tools/lint_project.gd`
Expected: No errors mentioning `dev_tools.gd`

---

### Task 4: Time Control Commands (GDScript)

**Files:**
- Modify: `scripts/dev_tools.gd` — register 2 handlers, implement 2 `_cmd_*` functions

- [ ] **Step 1: Register the 2 time control handlers in `_ready()`**

Add after the state shortcut handler registrations:
```gdscript
	_handlers["set_game_speed"] = _cmd_set_game_speed
	_handlers["wait_frames"] = _cmd_wait_frames
```

- [ ] **Step 2: Implement `_cmd_set_game_speed`**

```gdscript
func _cmd_set_game_speed(args: Dictionary) -> Dictionary:
	var prev: float = Engine.time_scale
	var scale: float = clampf(float(args.get("scale", 1.0)), 0.0, 100.0)
	Engine.time_scale = scale

	return {
		"success": true,
		"message": "Game speed: %.1f -> %.1f" % [prev, scale],
		"data": {"previous_scale": prev, "current_scale": scale},
	}
```

- [ ] **Step 3: Implement `_cmd_wait_frames` (async)**

This is the only async handler. It uses `await get_tree().process_frame` in a loop:
```gdscript
func _cmd_wait_frames(args: Dictionary) -> Dictionary:
	var count: int = int(args.get("count", 1))
	var start_time := Time.get_ticks_msec()
	for i in range(count):
		await get_tree().process_frame
	var elapsed_ms := Time.get_ticks_msec() - start_time

	return {
		"success": true,
		"message": "Waited %d frames" % count,
		"data": {"frames": count, "elapsed_ms": elapsed_ms},
	}
```

- [ ] **Step 4: Run headless lint**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script res://tools/lint_project.gd`
Expected: No errors mentioning `dev_tools.gd`

---

### Task 5: Composite Query Command (GDScript)

**Files:**
- Modify: `scripts/dev_tools.gd` — register 1 handler, implement 1 `_cmd_*` function

- [ ] **Step 1: Register the composite query handler in `_ready()`**

Add after the time control handler registrations:
```gdscript
	_handlers["get_catcher_state"] = _cmd_get_catcher_state
```

- [ ] **Step 2: Implement `_cmd_get_catcher_state`**

Uses `get()` to access private vars (prefixed with `_`). Public vars like `speed` are read directly:
```gdscript
func _cmd_get_catcher_state(_args: Dictionary) -> Dictionary:
	var catchers := get_tree().get_nodes_in_group("catcher")
	if catchers.is_empty():
		return {"success": false, "message": "No catcher node found"}

	var catcher: Node2D = catchers[0]

	return {
		"success": true,
		"message": "Catcher state retrieved",
		"data": {
			"position_x": catcher.position.x,
			"width": GameManager.get_catcher_width(),
			"speed": GameManager.get_catcher_speed(),
			"tier": catcher.get("_catcher_tier"),
			"combo": catcher.get("_combo"),
			"combo_multiplier": catcher.get("_combo_multiplier"),
			"bomb_shrink_active": catcher.get("_bomb_shrink_active"),
			"game_paused": catcher.get("_game_paused"),
		},
	}
```

- [ ] **Step 3: Run headless lint**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script res://tools/lint_project.gd`
Expected: No errors mentioning `dev_tools.gd`

---

### Task 6: Python CLI Extensions

**Files:**
- Modify: `tools/devtools.py` — add 9 `cmd_*` functions and 9 argparse subcommand registrations

- [ ] **Step 1: Add coin control Python functions**

Add after the `cmd_input_sequence` function (after line 408):
```python
# ==================== DEBUG COMMANDS ====================


def cmd_spawn_coin(args, project_path: Path):
    """Spawn a coin at a specific position."""
    cmd_args = {"type": args.type}
    if args.x is not None:
        cmd_args["x"] = args.x
    if args.y is not None:
        cmd_args["y"] = args.y

    result = send_command(project_path, "spawn_coin", cmd_args)
    if result["success"]:
        data = result["data"]
        print(f"Spawned {data['type']} coin at ({data['position']['x']:.0f}, {data['position']['y']:.0f}), value={data['value']}")
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)


def cmd_spawn_coin_on_catcher(args, project_path: Path):
    """Spawn a coin directly above the catcher."""
    cmd_args = {}
    if args.type:
        cmd_args["type"] = args.type

    result = send_command(project_path, "spawn_coin_on_catcher", cmd_args)
    if result["success"]:
        data = result["data"]
        print(f"Spawned {data['type']} coin above catcher at ({data['position']['x']:.0f}, {data['position']['y']:.0f}), value={data['value']}")
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)


def cmd_get_active_coins(args, project_path: Path):
    """List all active coins in the scene."""
    result = send_command(project_path, "get_active_coins")
    if result["success"]:
        data = result["data"]
        print(f"Active coins: {data['count']}")
        for coin in data.get("coins", []):
            print(f"  {coin['type']} at ({coin['position']['x']:.0f}, {coin['position']['y']:.0f}) value={coin['value']} collected={coin['collected']}")
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)


def cmd_clear_coins(args, project_path: Path):
    """Remove all active coins."""
    result = send_command(project_path, "clear_coins")
    if result["success"]:
        print(f"Cleared {result['data']['cleared']} coins")
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)
```

- [ ] **Step 2: Add state shortcut Python functions**

```python
def cmd_set_upgrade_levels(args, project_path: Path):
    """Bulk-set upgrade levels."""
    cmd_args = {}
    for key in ["spawn_rate", "coin_value", "catcher_speed", "catcher_width", "magnet"]:
        val = getattr(args, key, None)
        if val is not None:
            cmd_args[key] = val

    if not cmd_args:
        print("Error: Specify at least one upgrade level", file=sys.stderr)
        sys.exit(1)

    result = send_command(project_path, "set_upgrade_levels", cmd_args)
    if result["success"]:
        data = result["data"]
        print("Upgrade levels:")
        for key, level in data["levels"].items():
            print(f"  {key}: {level}")
        for warn in data.get("warnings", []):
            print(f"  WARNING: {warn}")
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)


def cmd_reset_session(args, project_path: Path):
    """Reset game to fresh state."""
    result = send_command(project_path, "reset_session")
    if result["success"]:
        print("Session reset")
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)
```

- [ ] **Step 3: Add time control Python functions**

```python
def cmd_set_game_speed(args, project_path: Path):
    """Set game speed (time scale)."""
    result = send_command(project_path, "set_game_speed", {"scale": args.scale})
    if result["success"]:
        data = result["data"]
        print(f"Game speed: {data['previous_scale']:.1f} -> {data['current_scale']:.1f}")
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)


def cmd_wait_frames(args, project_path: Path):
    """Wait for N physics frames."""
    timeout = max(30, args.count / 10)
    result = send_command(project_path, "wait_frames", {"count": args.count}, timeout=timeout)
    if result["success"]:
        data = result["data"]
        print(f"Waited {data['frames']} frames ({data['elapsed_ms']}ms)")
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)
```

- [ ] **Step 4: Add composite query Python function**

```python
def cmd_get_catcher_state(args, project_path: Path):
    """Get catcher state."""
    result = send_command(project_path, "get_catcher_state")
    if result["success"]:
        data = result["data"]
        print(f"Position X:         {data['position_x']:.1f}")
        print(f"Width:              {data['width']:.1f}")
        print(f"Speed:              {data['speed']:.1f}")
        print(f"Tier:               {data['tier']}")
        print(f"Combo:              {data['combo']}")
        print(f"Combo multiplier:   {data['combo_multiplier']:.1f}")
        print(f"Bomb shrink:        {data['bomb_shrink_active']}")
        print(f"Game paused:        {data['game_paused']}")
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)
```

- [ ] **Step 5: Register all 9 argparse subcommands**

Add after the `input sequence` subparser registration (after line 509, before `args = parser.parse_args()`):
```python
    # ==================== DEBUG COMMANDS ====================

    # spawn-coin
    p = subparsers.add_parser("spawn-coin", help="Spawn a coin at a position")
    p.add_argument("--type", "-t", default="SILVER", help="Coin type: SILVER, GOLD, FRENZY, BOMB")
    p.add_argument("--x", type=float, help="X position (default: random)")
    p.add_argument("--y", type=float, help="Y position (default: -50)")
    p.set_defaults(func=cmd_spawn_coin)

    # spawn-coin-on-catcher
    p = subparsers.add_parser("spawn-coin-on-catcher", help="Spawn a coin above the catcher")
    p.add_argument("--type", "-t", default="SILVER", help="Coin type: SILVER, GOLD, FRENZY, BOMB")
    p.set_defaults(func=cmd_spawn_coin_on_catcher)

    # get-active-coins
    p = subparsers.add_parser("get-active-coins", help="List all active coins")
    p.set_defaults(func=cmd_get_active_coins)

    # clear-coins
    p = subparsers.add_parser("clear-coins", help="Remove all active coins")
    p.set_defaults(func=cmd_clear_coins)

    # set-upgrade-levels
    p = subparsers.add_parser("set-upgrade-levels", help="Bulk-set upgrade levels")
    p.add_argument("--spawn-rate", type=int, help="Spawn rate level")
    p.add_argument("--coin-value", type=int, help="Coin value level")
    p.add_argument("--catcher-speed", type=int, help="Catcher speed level")
    p.add_argument("--catcher-width", type=int, help="Catcher width level")
    p.add_argument("--magnet", type=int, help="Magnet level")
    p.set_defaults(func=cmd_set_upgrade_levels)

    # reset-session
    p = subparsers.add_parser("reset-session", help="Reset to fresh game state")
    p.set_defaults(func=cmd_reset_session)

    # set-game-speed
    p = subparsers.add_parser("set-game-speed", help="Set game speed (time scale)")
    p.add_argument("scale", type=float, help="Time scale (0=pause, 1=normal, 10=fast)")
    p.set_defaults(func=cmd_set_game_speed)

    # wait-frames
    p = subparsers.add_parser("wait-frames", help="Wait for N physics frames")
    p.add_argument("count", type=int, help="Number of frames to wait")
    p.set_defaults(func=cmd_wait_frames)

    # get-catcher-state
    p = subparsers.add_parser("get-catcher-state", help="Get catcher state")
    p.set_defaults(func=cmd_get_catcher_state)
```

- [ ] **Step 6: Verify Python syntax**

Run: `python3 -c "import ast; ast.parse(open('tools/devtools.py').read()); print('OK')"` from project root.
Expected: `OK`

---

### Task 7: CLAUDE.md Documentation

**Files:**
- Modify: `CLAUDE.md` — add debug commands subsection

- [ ] **Step 1: Add debug commands documentation**

Add a new subsection after the existing DevTools CLI commands section (after the `python3 tools/devtools.py logs --category input` line) and before the "### Pre-change Validation Checklist" section:

```markdown
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
```
```

---

### Task 8: Full Validation

**Files:**
- All modified files

- [ ] **Step 1: Run headless lint**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script res://tools/lint_project.gd`
Expected: Clean output, no errors in `dev_tools.gd`

- [ ] **Step 2: Verify Python syntax**

Run: `python3 -c "import ast; ast.parse(open('tools/devtools.py').read()); print('OK')"`
Expected: `OK`

- [ ] **Step 3: Launch game and test each command**

Launch: `/Applications/Godot.app/Contents/MacOS/Godot --path /Users/jherr/Documents/GitHub/flexcoins &`
Wait: `sleep 5 && python3 tools/devtools.py ping`

Then run each command in sequence:
```bash
python3 tools/devtools.py reset-session
python3 tools/devtools.py get-state --node "/root/GameManager"
# Verify currency=0, all levels=0

python3 tools/devtools.py spawn-coin --type GOLD --x 360 --y 500
python3 tools/devtools.py get-active-coins
# Verify 1 GOLD coin present

python3 tools/devtools.py clear-coins
python3 tools/devtools.py get-active-coins
# Verify count=0 (or only spawner-created coins)

python3 tools/devtools.py set-upgrade-levels --spawn-rate 10
python3 tools/devtools.py get-state --node "/root/GameManager"
# Verify spawn_rate=10

python3 tools/devtools.py set-game-speed 10
python3 tools/devtools.py wait-frames 60
# Verify elapsed_ms is ~100ms (not ~1000ms)

python3 tools/devtools.py set-game-speed 1
# Restore normal speed

python3 tools/devtools.py spawn-coin-on-catcher --type SILVER
python3 tools/devtools.py wait-frames 120
python3 tools/devtools.py get-state --node "/root/GameManager"
# Verify currency increased

python3 tools/devtools.py get-catcher-state
# Verify all 8 fields present

python3 tools/devtools.py quit
```

- [ ] **Step 4: Review CLAUDE.md for formatting**

Read `CLAUDE.md` and verify the new debug commands section renders correctly and sits in the right place.
