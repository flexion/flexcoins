---
description: Run runtime devtools verification on the FlexCoins game. Use after modifying scripts, scenes, or gameplay before committing.
---

Run the FlexCoins runtime verification workflow. Execute each phase sequentially, stopping on failures.

## Phase 1: Headless Lint

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/lint_project.gd
```

Stop if lint reports errors.

## Phase 2: Launch Game

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . &
```

Wait for startup, then confirm connection:

```bash
sleep 5 && python3 tools/devtools.py ping
```

If ping fails, run `sleep 3 && python3 tools/devtools.py ping` once more. If it fails twice, check Godot terminal output for errors and stop.

## Phase 3: Validation

Run in order:

1. `python3 tools/devtools.py validate-all` -- 0 issues required
2. `python3 tools/devtools.py validate-ui` -- 0 issues required (CurrencyLabel pivot_offset warnings are acceptable)
3. `python3 tools/devtools.py screenshot` -- visual verification
4. `python3 tools/devtools.py performance` -- must show 0 orphan nodes, FPS >= 60

## Phase 4: Feature Tests (if applicable)

Run feature-specific tests based on what was modified. Common recipes:

**Coin collection:** `python3 tools/devtools.py spawn-coin-on-catcher --type SILVER`

**Frenzy mode:** `python3 tools/devtools.py spawn-coin-on-catcher --type FRENZY` then `sleep 2` and screenshot

**Bomb:** `python3 tools/devtools.py spawn-coin-on-catcher --type BOMB` then `sleep 1` and screenshot

**Shop UI (fresh launch only):**
```bash
python3 tools/devtools.py run-method --node "/root/GameManager" --method add_currency --args "[500]"
python3 tools/devtools.py run-method --node "/root/Main/HUD/ShopToggle" --method emit_signal --args '["pressed"]'
sleep 1 && python3 tools/devtools.py screenshot
```

**Purchase:** `python3 tools/devtools.py run-method --node "/root/GameManager" --method try_purchase_upgrade --args '["spawn_rate"]'`

## Phase 5: Clean Shutdown

```bash
python3 tools/devtools.py quit
```

## Critical Pitfalls

**NEVER use `set-state --property currency`** -- it bypasses the `currency_changed` signal and UI will not update. ALWAYS use:
```bash
python3 tools/devtools.py run-method --node "/root/GameManager" --method add_currency --args "[N]"
```

**Shop toggle is fragile** -- has a tween guard that blocks rapid calls. Only toggle ONCE per game launch. If state corrupts, quit and relaunch.

**Screenshots need delay** -- always `sleep 0.5` or `sleep 1` after state changes before taking screenshots. For ground truth, use `node-bounds` or `ui-snapshot` instead.

**Signal-aware methods** -- `add_currency`, `try_purchase_upgrade`, `start_frenzy`, `trigger_bomb` all emit signals. Direct `set-state` on GameManager properties does NOT.

**Common node paths:**
| Node | Path |
|------|------|
| GameManager | `/root/GameManager` |
| HUD | `/root/Main/HUD` |
| Shop toggle | `/root/Main/HUD/ShopToggle` |
| Currency label | `/root/Main/HUD/TopBar/CurrencyLabel` |

## Pass/Fail Summary

Report results as a table: lint status, validate-all, validate-ui, performance (FPS + orphan nodes), and any feature test outcomes. Also check Godot terminal output for GDScript runtime errors or warnings. If all pass, the commit is safe to proceed.
