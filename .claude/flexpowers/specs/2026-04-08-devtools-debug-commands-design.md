# DevTools Debug Commands for E2E Testing

**Issue:** #11 -- Add DevTools debug commands for E2E test suite
**Date:** 2026-04-08
**Status:** Design

## Summary

Add 9 debug commands to DevTools that give E2E tests direct control over game state: spawning coins at specific positions, bulk-setting upgrade levels, resetting sessions, controlling game speed, waiting for frames, and querying composite state. Also make the command dispatcher async-aware so `wait_frames` can block until frames complete.

## Motivation

The DevTools infrastructure supports runtime validation and input simulation, but testing core gameplay flows (coin collection, upgrades, frenzy, bombs, ascension) is either flaky (coin-catching depends on spawn position and timing) or slow (5s frenzy, 3s bomb shrink in real time). Debug commands give tests deterministic control.

## Scope

### In scope
- 9 new DevTools commands (GDScript handlers in `dev_tools.gd`)
- Async-aware command dispatcher (one-line change)
- 9 new Python CLI subcommands in `devtools.py`
- CLAUDE.md documentation updates

### Out of scope
- E2E test suite itself (separate future work)
- UI validation commands (Issue #12)
- Changes to game logic or scene structure

## Changes

### 1. `scripts/dev_tools.gd` — Async Dispatcher

**Modify `_check_for_commands()` (line 101):**

Change:
```gdscript
var result: Dictionary = handler.call(args)
```
To:
```gdscript
var result: Dictionary = await handler.call(args)
```

In GDScript, `await` on a non-async function returns immediately, so all 16 existing handlers are unaffected. Only new async handlers (like `wait_frames`) will actually yield.

### 2. `scripts/dev_tools.gd` — Coin Control Commands

**`spawn_coin`** — Spawn a specific coin type at a given position.

Args: `{type: String, x: float?, y: float?}`
- `type`: one of `"SILVER"`, `"GOLD"`, `"FRENZY"`, `"BOMB"` (default: `"SILVER"`)
- `x`: horizontal position (default: random within margins, matching spawner logic)
- `y`: vertical position (default: `-50.0`, top of screen)

Implementation:
- Load coin scene: `load("res://scenes/coin.tscn")`
- Convert type string to enum using a lookup dictionary:
  ```gdscript
  const COIN_TYPE_MAP: Dictionary = {
      "SILVER": 0,  # CoinType.SILVER
      "GOLD": 1,    # CoinType.GOLD
      "FRENZY": 2,  # CoinType.FRENZY
      "BOMB": 3,    # CoinType.BOMB
  }
  ```
  (GDScript has no automatic string-to-enum conversion; the int values match the enum declaration order in `coin.gd`)
- Instantiate coin, set `coin.coin_type = COIN_TYPE_MAP[type_str]`
- Set position
- Add to `Main` node (same parent as spawner uses): `get_tree().current_scene.add_child(coin)`
- Return: `{position: {x, y}, type: String, value: int}`

Error cases:
- Invalid type string: return `{success: false, message: "Unknown coin type: ..."}`

**`spawn_coin_on_catcher`** — Spawn a coin directly above the catcher for guaranteed collection.

Args: `{type: String?}` (default: `"SILVER"`)

Implementation:
- Find catcher: `get_tree().get_nodes_in_group("catcher")[0]`
- Spawn coin at `{x: catcher.position.x, y: catcher.position.y - 100}`
- Same instantiation logic as `spawn_coin`
- Return: same as `spawn_coin`

Error cases:
- No catcher found: return `{success: false, message: "No catcher node found"}`

**`get_active_coins`** — List all coins currently in the scene.

Args: none

Implementation:
- Walk children of `get_tree().current_scene`
- Filter nodes that `has_method("collect")` (duck-type check, matches project conventions)
- Return: `{count: int, coins: [{type: String, position: {x, y}, value: int, collected: bool}]}`

**`clear_coins`** — Remove all active coins.

Args: none

Implementation:
- Same walk as `get_active_coins`, call `queue_free()` on each
- Return: `{cleared: int}`

### 3. `scripts/dev_tools.gd` — State Shortcut Commands

**`set_upgrade_levels`** — Bulk-set upgrade levels.

Args: `{spawn_rate: int?, coin_value: int?, catcher_speed: int?, catcher_width: int?, magnet: int?}`

Implementation:
- For each key present in args that exists in `GameManager.UPGRADE_DATA`:
  - Set `GameManager._upgrade_levels[key] = int(value)`
  - Emit `GameManager.upgrade_purchased.emit(key)`
- Return: `{levels: Dictionary}` (full upgrade levels after change)

Error cases:
- Unknown upgrade key: skip it, include in `{warnings: [...]}`

**`reset_session`** — Reset to fresh state without restarting the game.

Args: none

Implementation:
- Capture previous state for return value
- `GameManager.currency = 0`
- Reset all `GameManager._upgrade_levels` to 0
- `GameManager.ascension_count = 0`
- `GameManager._combo_multiplier = 1.0`
- `GameManager._last_milestone = 0`
- If `GameManager.frenzy_active` and `GameManager._frenzy_timer != null`: stop frenzy timer, set `frenzy_active = false`, emit `frenzy_ended`
- Emit `GameManager.currency_changed.emit(0)`
- Emit `GameManager.upgrade_purchased.emit("")` (triggers UI/catcher/spawner refresh)
- Emit `GameManager.combo_multiplier_changed.emit(1.0)`
- Return: `{previous: {currency, upgrade_levels, ascension_count, combo_multiplier}}`

### 4. `scripts/dev_tools.gd` — Time Control Commands

**`set_game_speed`** — Control `Engine.time_scale`.

Args: `{scale: float}`
- `scale`: 0.0 pauses, 1.0 normal, 10.0 fast-forward

Implementation:
- Store previous: `var prev := Engine.time_scale`
- Set: `Engine.time_scale = clampf(args.get("scale", 1.0), 0.0, 100.0)`
- Return: `{previous_scale: float, current_scale: float}`

**`wait_frames`** — Wait N physics frames before returning. Async.

Args: `{count: int}`

Implementation:
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

### 5. `scripts/dev_tools.gd` — Composite Query Commands

**`get_catcher_state`** — All catcher state in one call.

Args: none

Implementation:
- Find catcher via `get_tree().get_nodes_in_group("catcher")[0]`
- Read properties using `catcher.get()` for private vars (prefixed `_`): `_bomb_shrink_active`, `_game_paused`, `_combo`, `_catcher_tier`, `_combo_multiplier`. Public vars (`speed`) can be read directly.
- Get derived values from GameManager: `get_catcher_width()`, `get_catcher_speed()`
- Return:
```json
{
  "position_x": 360.0,
  "width": 130.0,
  "speed": 650.0,
  "tier": 1,
  "combo": 12,
  "combo_multiplier": 1.0,
  "bomb_shrink_active": false,
  "game_paused": false
}
```

Error cases:
- No catcher found: return `{success: false, message: "No catcher node found"}`

### 6. `tools/devtools.py` — Python CLI Extensions

Add 9 new subcommands to the argparse tree, following the existing pattern:

| Subcommand | Args | Maps to action |
|---|---|---|
| `spawn-coin` | `--type TYPE --x X --y Y` | `spawn_coin` |
| `spawn-coin-on-catcher` | `--type TYPE` | `spawn_coin_on_catcher` |
| `get-active-coins` | (none) | `get_active_coins` |
| `clear-coins` | (none) | `clear_coins` |
| `set-upgrade-levels` | `--spawn-rate N --coin-value N --catcher-speed N --catcher-width N --magnet N` | `set_upgrade_levels` |
| `reset-session` | (none) | `reset_session` |
| `set-game-speed` | `SCALE` (positional) | `set_game_speed` |
| `wait-frames` | `COUNT` (positional) | `wait_frames` |
| `get-catcher-state` | (none) | `get_catcher_state` |

**Timeout handling for `wait_frames`:** The Python client should compute timeout as `max(30, count / 10)` seconds to account for potentially slow game speeds.

**Output formatting:**
- `spawn-coin` / `spawn-coin-on-catcher`: print type, position, value
- `get-active-coins`: print count, then each coin on a line
- `clear-coins`: print count cleared
- `set-upgrade-levels`: print final levels
- `reset-session`: print "Session reset"
- `set-game-speed`: print previous and current scale
- `wait-frames`: print frames waited and elapsed time
- `get-catcher-state`: print each property on a line (like `performance` command)

### 7. `CLAUDE.md` — Documentation

Add a new subsection under "DevTools CLI (requires game running)":

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

## Validation Plan

1. **Headless lint:** `godot --headless --script res://tools/lint_project.gd` — verify no parse errors in modified `dev_tools.gd`
2. **Launch game and ping:** verify DevTools still responds
3. **Test each command:**
   - `reset-session` → `get-state GameManager` → verify currency=0, levels=0
   - `spawn-coin --type GOLD --x 360 --y 500` → `get-active-coins` → verify 1 gold coin
   - `clear-coins` → `get-active-coins` → verify count=0
   - `set-upgrade-levels --spawn-rate 10` → `get-state GameManager` → verify spawn_rate=10
   - `set-game-speed 10` → `wait-frames 60` → verify elapsed_ms ~100ms (not ~1000ms)
   - `set-game-speed 1` → restore normal speed
   - `spawn-coin-on-catcher --type SILVER` → `wait-frames 120` → `get-state GameManager` → verify currency increased
   - `get-catcher-state` → verify all fields present
4. **Clean shutdown:** `python3 tools/devtools.py quit`

## Risk Assessment

**Low risk.** All changes are additive — new command handlers in `dev_tools.gd`, new subcommands in `devtools.py`. The one-line dispatcher change (`await handler.call(args)`) is safe because `await` on non-async functions is a no-op in GDScript. No game logic is modified.

The `spawn_coin` commands load `res://scenes/coin.tscn` directly rather than going through the spawner, which means they bypass the spawner's probability roll — this is intentional for deterministic testing.
