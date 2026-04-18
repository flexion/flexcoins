---
description: Run runtime devtools verification on the FlexCoins game. Use after modifying scripts, scenes, or gameplay before committing.
---

Run the FlexCoins runtime verification workflow. Execute each phase sequentially, stopping on failures.

## Phase 1: Headless Lint & Unit Tests

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/lint_project.gd
```

Stop if lint reports errors.

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/run_tests.gd
```

Stop if any tests fail.

## Phase 2: Launch Game

```bash
# --mute suppresses audio during automated testing
/Applications/Godot.app/Contents/MacOS/Godot --path . --mute &
```

Wait for startup, then confirm connection:

```bash
sleep 5 && python3 tools/devtools.py ping
```

If ping fails, retry once:

```bash
sleep 3 && python3 tools/devtools.py ping
```

If it fails twice, check Godot terminal output for errors and stop.

### Skip Start Screen

After ping succeeds, check if the game launched to StartScreen instead of Main:

```bash
python3 tools/devtools.py scene-tree | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('name','?'))"
```

If the output is "StartScreen", transition to Main:

```bash
python3 tools/devtools.py run-method --node "/root/StartScreen" --method _go_to_main --args "[]"
sleep 3
```

Then re-check scene-tree to confirm the root scene name is "Main". If the scene name is anything other than "Main" (including unexpected values like "?" or other scene names), stop and report the failure.

## Phase 3: Validation

Run in order:

1. `python3 tools/devtools.py validate-all` -- 0 issues required
2. `python3 tools/devtools.py validate-ui` -- 0 issues required (CurrencyLabel pivot_offset warnings are acceptable)
3. `python3 tools/devtools.py screenshot` -- visual verification
4. `python3 tools/devtools.py performance` -- must show 0 orphan nodes, FPS >= 60 (if running on CI or resource-constrained hardware, FPS >= 30 is acceptable)

## Phase 4: Feature Tests (diff-aware)

Phase 4 has two parts: **baseline regression recipes** (static) and **change-specific tests** (dynamic). Both must pass.

### Part A: Baseline Regression Recipes

Before running recipes, determine what changed:

```bash
git diff --name-only HEAD
```

If no files changed in the working tree, use your knowledge of what was modified in this session. Select recipes based on this mapping:

| Files changed | Recipes to run |
|---|---|
| `coin.gd`, `coin_spawner.gd` | Coin collection, Frenzy mode, Bomb |
| `catcher.gd`, `auto_catcher_manager.gd` | Coin collection |
| `hud.gd`, `upgrade_button.gd` | Shop UI, Purchase |
| `game_manager.gd` | Coin collection, Shop UI, Purchase |
| `start_screen.gd` | (none -- covered by Phase 2 skip) |
| Scene files (`*.tscn`) | Run all recipes |
| Other / unclear | Run all recipes |

Recipes:

**Coin collection:** `python3 tools/devtools.py spawn-coin-on-catcher --type SILVER`

**Frenzy mode:** `python3 tools/devtools.py spawn-coin-on-catcher --type FRENZY` then `sleep 2` and screenshot

**Bomb:** `python3 tools/devtools.py spawn-coin-on-catcher --type BOMB` then `sleep 1` and screenshot

**Shop UI (only toggle once per launch; if already toggled, quit and relaunch):**
```bash
python3 tools/devtools.py run-method --node "/root/GameManager" --method add_currency --args "[500]"
python3 tools/devtools.py run-method --node "/root/Main/HUD" --method _on_shop_toggle_pressed --args "[]"
sleep 1 && python3 tools/devtools.py screenshot
```

**Purchase (requires currency; add first if needed):**
```bash
python3 tools/devtools.py run-method --node "/root/GameManager" --method add_currency --args "[500]"
python3 tools/devtools.py run-method --node "/root/GameManager" --method try_purchase_upgrade --args '["spawn_rate"]'
python3 tools/devtools.py get-state --node "/root/GameManager"
```
Verify `upgrade_levels.spawn_rate` incremented and currency decreased.

### Part B: Change-Specific Tests

After running baseline recipes, design and execute tests that specifically exercise the new or modified behavior from this session. These tests are **not** pre-written — you must create them dynamically each run.

**Step 1: Analyze the diff.** Read the actual code changes (not just file names):

```bash
git diff HEAD
```

If no working tree changes, use your knowledge of what was modified in this session. Identify:
- What new code paths were added (new functions, new branches in existing functions)
- What conditions trigger them (upgrade levels, game states, input actions, timers)
- What observable effects they produce (position changes, currency changes, visual changes, node creation/removal)

**Step 2: Design tests.** For each significant new behavior, design a test that:
- Sets up the required preconditions using devtools (e.g., `set-upgrade-levels`, `run-method`, `add_currency`, `input`)
- Triggers the behavior (e.g., spawn coins in specific positions, simulate input, toggle game states)
- Verifies the outcome through observable state (e.g., `get-catcher-state`, `get-state`, `get-active-coins`, `node-bounds`, `screenshot`, position comparisons)

**Step 3: Execute and verify.** Run each test, check results, and report pass/fail. Use `reset-session` between tests if they require conflicting game states.

**Available devtools for building tests:**

| Command | Use for |
|---|---|
| `set-upgrade-levels --spawn-rate N --coin-value N ...` | Set upgrade preconditions |
| `run-method --node PATH --method NAME --args "[...]"` | Call any game method (add_currency, toggle_auto_mode, etc.) |
| `get-catcher-state` | Check catcher position, width, speed |
| `get-state --node PATH` | Read any node's properties |
| `spawn-coin --type TYPE --x N` | Spawn coin at specific X position |
| `spawn-coin-on-catcher --type TYPE` | Spawn coin directly above catcher |
| `get-active-coins` | List all coins with positions and types |
| `input tap ACTION --hold N` | Simulate input actions |
| `set-game-speed N` | Speed up game for time-dependent tests |
| `wait-frames N` | Wait for physics frames to elapse |
| `screenshot` | Visual verification |
| `node-bounds PATH` | Get exact position/size of any node |
| `reset-session` | Reset to fresh game state |

**Example** — if the diff added auto-boost behavior to the catcher when auto-mode is active and boost_power is purchased:
```bash
# Setup: purchase boost_power, enable auto-mode
python3 tools/devtools.py set-upgrade-levels --boost-power 3
python3 tools/devtools.py run-method --node "/root/GameManager" --method toggle_auto_mode --args "[]"
# Record catcher starting position
python3 tools/devtools.py get-catcher-state
# Spawn a coin far from catcher in danger zone (lower 40% of screen)
python3 tools/devtools.py spawn-coin --type SILVER --x 200
# Wait for the auto-boost to fire
sleep 1
# Verify catcher moved significantly toward the coin
python3 tools/devtools.py get-catcher-state
# Take screenshot for visual verification
python3 tools/devtools.py screenshot
```

**Guidelines:**
- Design at least 1 test per significant new behavior in the diff
- Test both the happy path AND at least one guard/edge case (e.g., feature should NOT activate when a prerequisite is missing)
- If the change is purely visual, use screenshots before/after and inspect them
- Report each test with a name, what it verified, and pass/fail

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

**StartScreen blocks DevTools input** -- DevTools input simulation does not trigger `_unhandled_input` on StartScreen. To bypass, call:
```bash
python3 tools/devtools.py run-method --node "/root/StartScreen" --method _go_to_main --args "[]"
```
Then `sleep 3` before issuing further commands. Phase 2 handles this automatically, but if re-launching mid-run, apply manually.

**Common node paths:**
| Node | Path |
|------|------|
| GameManager | `/root/GameManager` |
| HUD | `/root/Main/HUD` |
| Shop toggle | `/root/Main/HUD` (call `_on_shop_toggle_pressed`; ShopToggle is reparented at runtime) |
| Currency label | `/root/Main/HUD/TopBar/CurrencyLabel` |

## Self-Improvement (Post-Run)

After writing the Pass/Fail Summary, reflect on the entire run and identify improvements to this file. **Do not edit verify.md directly.** Instead, present proposals to the user for approval.

### What to Look For

Review the run for any of these signals:

| Signal | Example |
|---|---|
| **Workflow friction** | A phase required manual workarounds, retries, or unexpected steps not in the instructions |
| **Silent failures** | A command succeeded (exit 0) but produced wrong results, or a recipe ran without validating its outcome |
| **Stale references** | Node paths, method names, or argument formats that no longer match the codebase |
| **Missing recipes** | A feature was modified but no Phase 4 recipe exists to test it |
| **Timing / ordering** | A recipe that only works before/after another, or a sleep that's too short and causes flaky results |
| **Unclear instructions** | You had to guess what to do because the instructions were ambiguous |
| **Unnecessary steps** | A check that always passes and adds no value |

### How to Propose

For each issue found, present a recommendation in this format:

```
**Issue:** [What went wrong — quote the specific command output or describe the friction]
**Proposal:** [Which section to change, plus the literal text to insert or replace as a code block — so approval is a single yes/no]
**Rationale:** [Why this improves future runs]
```

### Rules

1. **Evidence required.** Every proposal must cite specific output from this run (quote error messages, unexpected results, or describe the exact friction point). No speculative improvements.

2. **Max 3 proposals per run.** If more than 3 issues surface, prioritize: silent failures > workflow blockers > stale references > polish.

3. **No transient issues.** Do not propose changes for issues that resolved by retrying the same command. One-off timeouts are not improvements.

4. **No re-proposals.** Do not re-propose an issue the user declined in this session unless new evidence changes the rationale.

5. **Nothing is off-limits.** Any section of this file — phases, commands, thresholds, pitfalls, recipes, even this section — can be proposed for change. The user decides what gets applied.

6. **Wait for approval.** Present proposals after the Pass/Fail Summary (so the user sees results first). Ask the user which (if any) to apply. Only edit verify.md after explicit approval. Apply all approved changes in a single edit.

7. **Soft cap.** If Critical Pitfalls or Phase 4 Recipes exceeds 10 entries, propose consolidation or removal of entries not triggered in recent runs.

8. **Keep recipes concise.** Each recipe entry must be 5 lines or fewer, including the command block.

## Pass/Fail Summary

Report results as a table: lint status, validate-all, validate-ui, performance (FPS + orphan nodes), baseline recipe outcomes, change-specific test outcomes (name + pass/fail for each), and any verify.md updates made. Also check Godot terminal output for GDScript runtime errors or warnings. If all pass, the commit is safe to proceed.
