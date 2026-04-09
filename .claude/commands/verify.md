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

## Self-Improvement (Post-Run)

After Phase 5 shutdown (but before writing the Pass/Fail Summary), review the run for lessons that should persist. Update verify.md in a **single edit** at the end of the run -- never incrementally during phases. If no issues meet the evidence threshold below, make no changes.

### What to Update

Updates target the **existing sections** of this file (Critical Pitfalls, Common node paths, Phase 4 recipes) -- not new tables within this section. This section is instructions only, not a data store.

| Category | Where to edit | What to record |
|---|---|---|
| **Pitfalls** | "Critical Pitfalls" section | Commands or patterns that cause silent failures, signal bypasses, or corrupt state |
| **Node Paths** | "Common node paths" table | Node paths that changed due to refactoring or scene restructuring |
| **Broken Recipes** | "Phase 4: Feature Tests" section | Existing recipes whose command syntax, method signatures, or argument formats no longer work |
| **Acceptable Warnings** | Phase 3 validation notes | New warning types from `validate-ui` or `validate-all` that are confirmed acceptable (like the existing CurrencyLabel pivot_offset note) |

### Rules

1. **Evidence required.** Before adding or modifying any entry, verify it against the current run's command output (quote the specific error message or output line). Do not record speculative fixes.

2. **Max 3 total updates per run** across all categories. If more than 3 issues surface, prioritize: silent failures over wrong output over inconvenience.

3. **Correct in place.** If a pitfall description is wrong or a recipe's syntax changed, update the existing entry directly. Only mark an entry `[DEPRECATED YYYY-MM-DD]` if its entire concept no longer applies (e.g., a removed feature). Do not accumulate stale entries.

4. **Each recipe entry must be 5 lines or fewer**, including the command block.

5. **No transient issues.** Do NOT add entries for issues that resolved by retrying the same command without changes. One-off ping timeouts and startup races are not pitfalls.

6. **Phases 1-3 are protected.** Do NOT modify command syntax or validation thresholds (FPS >= 60, 0 issues required) in Phases 1-3. Those require explicit human approval. Only the acceptable-warnings notes (e.g., "X warnings are acceptable") may be added.

7. **Soft cap.** If any section exceeds 10 entries, consolidate or remove entries that have not been relevant in recent runs.

8. **No meta-changes.** Do not modify this Self-Improvement section's own rules.

## Pass/Fail Summary

Report results as a table: lint status, validate-all, validate-ui, performance (FPS + orphan nodes), any feature test outcomes, and any verify.md updates made. Also check Godot terminal output for GDScript runtime errors or warnings. If all pass, the commit is safe to proceed.
