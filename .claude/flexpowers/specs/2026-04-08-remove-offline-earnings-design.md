# Remove Offline Earnings, Welcome Panel, Save/Load, Streaks, and Quests

**Issue:** #7 -- Remove offline earnings and welcome back panel  
**Date:** 2026-04-08  
**Status:** Design

## Summary

Remove all persistence (save/load), offline earnings, welcome back panel, daily streak system, and quest system. Every game session starts fresh with 0 currency and all upgrades at level 0.

## Motivation

The game should start fresh each session. The offline earnings, streak, and quest features add complexity without matching the desired gameplay loop. Removing the save system entirely simplifies the codebase.

## Scope

### In scope
- Remove offline earnings calculation and display
- Remove WelcomePanel from HUD
- Remove save/load system entirely (save_game, load_game, auto-save timer, save-on-quit)
- Remove daily streak system entirely
- Remove daily quest system entirely
- Remove all streak/quest HUD elements
- Update CLAUDE.md documentation

### Out of scope
- Core gameplay mechanics (coin spawning, catching, upgrades, ascension) remain unchanged
- In-session state (currency, upgrade levels, ascension) still works within a single session
- Combo multiplier system (session-only, no persistence) remains unchanged
- Frenzy system remains unchanged

## Changes

### 1. `scripts/game_manager.gd`

**Remove constants:**
- `SAVE_PATH` ("user://save.json")
- `MAX_OFFLINE_SECONDS` (28800.0)
- `OFFLINE_EFFICIENCY` (0.5)
- `STREAK_BONUS_PER_DAY` (0.05)
- `MAX_STREAK_CAP` (20)
- `QUEST_DEFINITIONS` (Dictionary)
- `QUEST_MULTIPLIER_BOOST` (0.25)
- `QUEST_BOOST_DURATION_SEC` (3600)
- `DAILY_RESET_HOUR` (0)

**Remove signals:**
- `game_loaded`
- `streak_updated`
- `quest_completed`
- `quest_progress_updated`

**Remove variables:**
- `_last_played: float`
- `_offline_earnings: int`
- `_streak_count: int`
- `_last_played_date: int`
- `_quest_progress: Dictionary`
- `_active_quest_multiplier: float`
- `_quest_multiplier_end_time: int`
- `_quest_session_earnings: int`

**Remove functions:**
- `save_game()` (lines 321-336)
- `load_game()` (lines 338-384)
- `get_offline_earnings()` (lines 198-199)
- `clear_offline_earnings()` (lines 201-202)
- `_check_daily_reset()` (lines 221-248)
- `_reset_daily_quests()` (lines 250-256)
- `get_streak_bonus()` (lines 258-260)
- `get_streak_count()` (lines 262-263)
- `get_active_quest_multiplier()` (lines 265+)
- `get_quest_progress()` and related quest functions
- `get_quest_multiplier_time_remaining()`
- `_update_quest_progress()`
- `_get_unix_day()`

**Remove `save_game()` call sites:**
- `try_purchase_upgrade()` line 115: remove `save_game()` call
- `try_ascend()` line 192: remove `save_game()` call

**Remove from `_ready()`:**
- `get_tree().auto_accept_quit = false` (line 70) -- removing this AND the `_notification` handler so the window closes normally
- `load_game()` call (line 75)
- `_check_daily_reset()` call (line 76)
- Quest progress initialization loop (lines 73-74)
- Auto-save Timer creation (lines 78-82)

**Remove `_notification()` handler** (lines 88-91) entirely -- with no save system, no need to intercept window close.

**Simplify `get_coin_value()`:**
- Remove `quest_mult` and `streak_mult` from the calculation (line 125-128)
- Formula becomes: `base * ascension_mult * combo_mult`

**Simplify `add_currency()`:**
- Remove quest progress tracking call (line 98-99)

**Simplify `try_ascend()`:**
- Remove `_reset_daily_quests()` call (line 188)

### 2. `scripts/hud.gd`

**Remove `@onready` references:**
- `welcome_panel: PanelContainer`
- `welcome_earnings_label: Label`
- `welcome_button: Button`

**Remove variables:**
- `_streak_label: Label`
- `_quest_panel: PanelContainer`
- `_quest_labels: Dictionary`
- `_quest_multiplier_timer_label: Label`
- `_quest_multiplier_timer_tween: Tween`

**Remove signal connections from `_ready()`:**
- `GameManager.streak_updated.connect(...)` (line 37)
- `GameManager.quest_progress_updated.connect(...)` (line 38)
- `GameManager.quest_completed.connect(...)` (line 39)

**Remove from `_ready()`:**
- `_check_offline_earnings()` call
- `_create_streak_display()` call (line 52)
- `_create_quest_panel()` call (line 53)
- `_update_quest_multiplier_timer()` call (line 54)
- Quest multiplier timer creation (lines 55-58)

**Remove functions:**
- `_check_offline_earnings()` (lines 76-83)
- `_on_welcome_dismissed()` (lines 196-198)
- `_create_streak_display()` (lines 378-389)
- `_update_streak_label()` (lines 392-398)
- `_on_streak_updated()` (lines 401-405)
- `_show_streak_milestone()` (lines 408+)
- `_create_quest_panel()` (lines 427-462)
- `_update_quest_displays()` (lines 467-478)
- `_on_quest_progress_updated()` (lines 479-480)
- `_on_quest_completed()` (lines 483+)
- `_update_quest_multiplier_timer()` (lines 503-511)

### 3. `scripts/catcher.gd`

**Remove:**
- `GameManager.game_loaded.connect(_on_game_loaded)` (line 48)
- Quest tracking calls (lines 94-96): `GameManager.update_quest_catch_coins(1)` and `GameManager.update_quest_combo(_combo)` plus comment
- `_on_game_loaded()` function (lines 311-313)

### 4. `scenes/hud.tscn`

**Remove entire WelcomePanel subtree** (lines 78-123):
- WelcomePanel (PanelContainer)
  - MarginContainer
    - VBoxContainer
      - WelcomeLabel
      - WelcomeEarningsLabel
      - WelcomeButton

### 5. `CLAUDE.md`

**Remove/update all persistence, offline, streak, quest, and welcome panel references:**
- Project overview: remove "save/load persistence, and offline earnings"
- Development Commands: remove save file location line
- Autoloads: remove offline earnings documentation line
- Scene Tree diagrams: remove WelcomePanel entries
- Key Scenes: remove "welcome-back popup" from hud.tscn description
- Ascension section: remove "offline earnings and welcome panel not affected"
- Ascension section: remove "persists across saves (stored in save file)"
- z_index conventions: remove welcome panel reference
- CanvasLayer section: remove "welcome panel, pause menus"
- Updated Scene Tree: remove WelcomePanel entry
- Node Placement rules: remove welcome panel mention
- UI Testing Protocol: remove welcome panel trigger test
- Persistence testing: remove save.json reference
- Signal Timing: remove note about `load_game()` firing before listeners
- Data Flow: remove any save/load references

**Keep:**
- All other architecture documentation
- Validation infrastructure documentation
- Combo multiplier documentation

## Validation Plan

After all changes, run the validation framework:

1. **Headless lint:** `godot --headless --script res://tools/lint_project.gd`
   - Verify no broken UIDs or NodePath references from removed WelcomePanel nodes
2. **Runtime validation:** `python3 tools/devtools.py validate-all`
   - Verify all scenes instantiate cleanly without the WelcomePanel
3. **State inspection:** `python3 tools/devtools.py get-state --node "/root/GameManager"`
   - Confirm removed variables (`_offline_earnings`, `_streak_count`, `_quest_progress`, etc.) are gone
4. **Input test:** `python3 tools/devtools.py input sequence test/sequences/move_catcher.json`
   - Verify basic gameplay still works after changes
5. **Performance check:** `python3 tools/devtools.py performance`
   - Verify game runs without errors and maintains FPS

## Risk Assessment

**Low-medium risk.** The streak and quest removal touches `get_coin_value()` which affects all coin earnings. The simplification (removing `streak_mult` and `quest_mult`) must be done carefully to preserve the remaining multiplier chain (`base * ascension_mult * combo_mult`). The catcher.gd `game_loaded` signal connection must be removed to avoid a runtime crash. The `auto_accept_quit = false` line must be removed alongside the `_notification` handler or the game window becomes unclosable.
