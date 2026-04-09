# Remove Offline Earnings, Save/Load, Streaks & Quests — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use flexpowers:subagent-driven-development (recommended) or flexpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove all persistence (save/load), offline earnings, welcome panel, daily streaks, and quest system so every session starts fresh.

**Architecture:** Strip persistence and daily-engagement systems from GameManager, HUD, and Catcher. Simplify `get_coin_value()` to `base * ascension_mult * combo_mult`. Remove WelcomePanel from `hud.tscn`. Update CLAUDE.md to reflect the new state.

**Tech Stack:** Godot 4.6, GDScript

---

## File Map

| Action | File | Responsibility |
|---|---|---|
| Modify | `scripts/game_manager.gd` | Remove 4 signals, 11 constants, 8 variables, ~15 functions; simplify `get_coin_value()`, `add_currency()`, `try_ascend()`, `_ready()` |
| Modify | `scripts/hud.gd` | Remove welcome panel refs, streak/quest UI, signal connections, 10+ functions |
| Modify | `scripts/catcher.gd` | Remove `game_loaded` signal connection, quest tracking calls, `_on_game_loaded()` |
| Modify | `scenes/hud.tscn` | Remove WelcomePanel subtree (lines 78-123) |
| Modify | `CLAUDE.md` | Remove all persistence/offline/streak/quest/welcome panel references |

---

### Task 1: Strip game_manager.gd — Signals, Constants, Variables

**Files:**
- Modify: `scripts/game_manager.gd:15-64`

- [ ] **Step 1: Remove persistence/streak/quest signals (lines 15-18)**

Remove these four lines:
```gdscript
signal streak_updated(new_streak_count: int)
signal quest_completed(quest_id: String, reward_multiplier: float)
signal quest_progress_updated(quest_id: String, progress: int, target: int)
signal game_loaded
```

- [ ] **Step 2: Remove persistence constants (lines 20-22)**

Remove these three lines:
```gdscript
const SAVE_PATH: String = "user://save.json"
const MAX_OFFLINE_SECONDS: float = 28800.0  # 8 hours
const OFFLINE_EFFICIENCY: float = 0.5
```

- [ ] **Step 3: Remove streak & quest constants (lines 29-39)**

Remove the entire block from `# Streak & Quest Constants` through the closing `}` of `QUEST_DEFINITIONS`:
```gdscript
# Streak & Quest Constants
const STREAK_BONUS_PER_DAY: float = 0.05
const QUEST_MULTIPLIER_BOOST: float = 0.25
const QUEST_BOOST_DURATION_SEC: int = 3600
const DAILY_RESET_HOUR: int = 0
const MAX_STREAK_CAP: int = 20
const QUEST_DEFINITIONS: Dictionary = {
	"catch_coins": {"name": "Catch Coins", "target": 100, "description": "Catch 100 coins"},
	"earn_currency": {"name": "Earn Currency", "target": 1000, "description": "Earn 1000 currency"},
	"reach_combo": {"name": "Reach Combo", "target": 50, "description": "Reach 50x combo"},
}
```

- [ ] **Step 4: Remove persistence/streak/quest variables (lines 51-52, 58-64)**

Remove `_last_played` and `_offline_earnings`:
```gdscript
var _last_played: float = 0.0
var _offline_earnings: int = 0
```

Remove the entire streak/quest tracking block:
```gdscript
# Streak & Quest tracking
var _streak_count: int = 0
var _last_played_date: int = 0
var _quest_progress: Dictionary = {}
var _active_quest_multiplier: float = 1.0
var _quest_multiplier_end_time: int = 0
var _quest_session_earnings: int = 0
```

- [ ] **Step 5: Run headless lint to verify no syntax errors**

Run: `godot --headless --script res://tools/lint_project.gd`
Expected: May show errors about references to removed variables (expected at this stage), but no parse errors.

---

### Task 2: Strip game_manager.gd — Simplify _ready() and Remove _notification()

**Files:**
- Modify: `scripts/game_manager.gd:69-91`

- [ ] **Step 1: Simplify `_ready()` (lines 69-86)**

Replace the current `_ready()` with this simplified version that only initializes upgrade levels and milestones:
```gdscript
func _ready() -> void:
	for id: String in UPGRADE_DATA:
		_upgrade_levels[id] = 0
	# Set initial milestone based on loaded currency
	for m: int in MILESTONES:
		if currency >= m:
			_last_milestone = m
```

This removes:
- `get_tree().auto_accept_quit = false` (line 70)
- Quest progress init loop (lines 73-74)
- `load_game()` call (line 75)
- `_check_daily_reset()` call (line 76)
- Auto-save timer creation (lines 77-82)

- [ ] **Step 2: Remove `_notification()` handler (lines 88-91)**

Remove the entire function:
```gdscript
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		get_tree().quit()
```

- [ ] **Step 3: Run headless lint**

Run: `godot --headless --script res://tools/lint_project.gd`
Expected: No parse errors. Remaining references to removed functions will be cleaned up in next tasks.

---

### Task 3: Strip game_manager.gd — Simplify Core Functions

**Files:**
- Modify: `scripts/game_manager.gd` (lines 93-202 area, after prior edits shifted line numbers)

- [ ] **Step 1: Simplify `add_currency()` — remove quest tracking**

Change from:
```gdscript
func add_currency(amount: int) -> void:
	var old_currency := currency
	currency += amount
	currency_changed.emit(currency)
	_check_milestones(old_currency, currency)
	# Track quest 2 progress (earn currency)
	_update_quest_progress("earn_currency", _quest_progress.get("earn_currency", 0) + amount)
```

To:
```gdscript
func add_currency(amount: int) -> void:
	var old_currency := currency
	currency += amount
	currency_changed.emit(currency)
	_check_milestones(old_currency, currency)
```

- [ ] **Step 2: Remove `save_game()` call from `try_purchase_upgrade()` (line 115)**

Change from:
```gdscript
		currency_changed.emit(currency)
		upgrade_purchased.emit(upgrade_id)
		save_game()
		return true
```

To:
```gdscript
		currency_changed.emit(currency)
		upgrade_purchased.emit(upgrade_id)
		return true
```

- [ ] **Step 3: Simplify `get_coin_value()` — remove quest_mult and streak_mult**

Change from:
```gdscript
func get_coin_value() -> int:
	var base: int = 1 + int(_upgrade_levels.get("coin_value", 0))
	var ascension_mult := get_ascension_multiplier()
	var quest_mult := get_active_quest_multiplier()
	var combo_mult := _combo_multiplier
	var streak_mult := get_streak_bonus()
	return int(base * ascension_mult * quest_mult * combo_mult * streak_mult)
```

To:
```gdscript
func get_coin_value() -> int:
	var base: int = 1 + int(_upgrade_levels.get("coin_value", 0))
	var ascension_mult := get_ascension_multiplier()
	var combo_mult := _combo_multiplier
	return int(base * ascension_mult * combo_mult)
```

- [ ] **Step 4: Simplify `try_ascend()` — remove quest reset and save**

Change from:
```gdscript
	_last_milestone = 0
	# Reset quests but keep streak
	_reset_daily_quests()
	currency_changed.emit(currency)
	upgrade_purchased.emit("")
	ascended.emit(ascension_count)
	save_game()
	return true
```

To:
```gdscript
	_last_milestone = 0
	currency_changed.emit(currency)
	upgrade_purchased.emit("")
	ascended.emit(ascension_count)
	return true
```

- [ ] **Step 5: Remove `get_offline_earnings()` and `clear_offline_earnings()` (lines 198-202)**

Remove:
```gdscript
func get_offline_earnings() -> int:
	return _offline_earnings

func clear_offline_earnings() -> void:
	_offline_earnings = 0
```

- [ ] **Step 6: Run headless lint**

Run: `godot --headless --script res://tools/lint_project.gd`
Expected: No parse errors in game_manager.gd.

---

### Task 4: Strip game_manager.gd — Remove Streak, Quest, and Save/Load Functions

**Files:**
- Modify: `scripts/game_manager.gd` (lines 212-391 area)

- [ ] **Step 1: Remove entire Streak & Quest System section (lines 212-319)**

Remove everything from `# ============= Streak & Quest System =============` through the end of `update_quest_combo()`:
```gdscript
# ============= Streak & Quest System =============

func _get_unix_day() -> int:
...
func update_quest_combo(combo_level: int) -> void:
	if combo_level > _quest_progress.get("reach_combo", 0):
		_update_quest_progress("reach_combo", combo_level)
```

This removes: `_get_unix_day()`, `_check_daily_reset()`, `_reset_daily_quests()`, `get_streak_bonus()`, `get_streak_count()`, `get_active_quest_multiplier()`, `get_quest_multiplier_time_remaining()`, `get_quest_progress()`, `_update_quest_progress()`, `_check_quest_completion()`, `_grant_quest_multiplier_for_quest()`, `update_quest_catch_coins()`, `update_quest_combo()`.

- [ ] **Step 2: Remove `save_game()` and `load_game()` functions (lines 321-384)**

Remove both functions entirely, from `func save_game()` through the end of `func load_game()`.

- [ ] **Step 3: Verify final game_manager.gd structure**

The file should now contain only:
- Signals: `currency_changed`, `upgrade_purchased`, `milestone_reached`, `coin_collected`, `coin_missed`, `frenzy_started`, `frenzy_ended`, `bomb_hit`, `ascended`, `shop_opened`, `shop_closed`, `combo_multiplier_changed`
- Constants: `MILESTONES`, `ASCEND_MIN_LEVEL`, `ASCEND_MULTIPLIER`, `CORE_UPGRADES`, `UPGRADE_DATA`
- Variables: `currency`, `_upgrade_levels`, `_last_milestone`, `ascension_count`, `frenzy_active`, `_frenzy_timer`, `_combo_multiplier`
- Functions: `_ready()`, `add_currency()`, `get_upgrade_level()`, `get_upgrade_cost()`, `try_purchase_upgrade()`, `get_spawn_interval()`, `get_coin_value()`, `get_catcher_speed()`, `get_catcher_width()`, `get_magnet_radius()`, `get_magnet_strength()`, `start_frenzy()`, `trigger_bomb()`, `_end_frenzy()`, `get_ascension_multiplier()`, `can_ascend()`, `try_ascend()`, `get_earn_rate()`, `set_combo_multiplier()`, `get_combo_multiplier()`, `_check_milestones()`

- [ ] **Step 4: Run headless lint**

Run: `godot --headless --script res://tools/lint_project.gd`
Expected: Clean pass for game_manager.gd. HUD and catcher may still have errors (fixed in next tasks).

---

### Task 5: Strip hud.gd — Remove Variables, References, and Signal Connections

**Files:**
- Modify: `scripts/hud.gd:1-61`

- [ ] **Step 1: Remove streak/quest variables (lines 8-12)**

Remove:
```gdscript
var _streak_label: Label
var _quest_panel: PanelContainer
var _quest_labels: Dictionary = {}
var _quest_multiplier_timer_label: Label
var _quest_multiplier_timer_tween: Tween
```

- [ ] **Step 2: Remove welcome panel `@onready` references (lines 23-25)**

Remove:
```gdscript
@onready var welcome_panel: PanelContainer = %WelcomePanel
@onready var welcome_earnings_label: Label = %WelcomeEarningsLabel
@onready var welcome_button: Button = %WelcomeButton
```

- [ ] **Step 3: Remove streak/quest signal connections from `_ready()` (lines 37-39)**

Remove:
```gdscript
	GameManager.streak_updated.connect(_on_streak_updated)
	GameManager.quest_progress_updated.connect(_on_quest_progress_updated)
	GameManager.quest_completed.connect(_on_quest_completed)
```

- [ ] **Step 4: Remove offline/streak/quest calls from `_ready()` (lines 47, 52-60)**

Remove `_check_offline_earnings()` call (line 47):
```gdscript
	_check_offline_earnings()
```

Remove streak/quest creation and timer (lines 52-60):
```gdscript
	_create_streak_display()
	_create_quest_panel()
	_update_quest_multiplier_timer()
	# Start timer to update quest multiplier countdown
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_update_quest_multiplier_timer)
	add_child(timer)
	timer.start()
```

- [ ] **Step 5: Run headless lint**

Run: `godot --headless --script res://tools/lint_project.gd`
Expected: No parse errors. References to removed functions will be cleaned in next task.

---

### Task 6: Strip hud.gd — Remove Functions

**Files:**
- Modify: `scripts/hud.gd` (lines 76-83, 196-198, 376-511)

- [ ] **Step 1: Remove `_check_offline_earnings()` function (lines 76-83)**

Remove:
```gdscript
func _check_offline_earnings() -> void:
	var earnings := GameManager.get_offline_earnings()
	if earnings > 0:
		welcome_panel.visible = true
		welcome_earnings_label.text = "You earned %d coins while away!" % earnings
		welcome_button.pressed.connect(_on_welcome_dismissed, CONNECT_ONE_SHOT)
	else:
		welcome_panel.visible = false
```

- [ ] **Step 2: Remove `_on_welcome_dismissed()` function (lines 196-198)**

Remove:
```gdscript
func _on_welcome_dismissed() -> void:
	welcome_panel.visible = false
	GameManager.clear_offline_earnings()
```

- [ ] **Step 3: Remove entire Streak & Quest UI section (lines 376-511)**

Remove everything from `# ============= Streak & Quest UI =============` to end of file. This includes:
- `_create_streak_display()`
- `_update_streak_label()`
- `_on_streak_updated()`
- `_show_streak_milestone()`
- `_create_quest_panel()`
- `_update_quest_displays()`
- `_on_quest_progress_updated()`
- `_on_quest_completed()`
- `_update_quest_multiplier_timer()`

- [ ] **Step 4: Run headless lint**

Run: `godot --headless --script res://tools/lint_project.gd`
Expected: Clean pass for hud.gd.

---

### Task 7: Strip catcher.gd — Remove game_loaded and Quest Tracking

**Files:**
- Modify: `scripts/catcher.gd:48,94-96,311-313`

- [ ] **Step 1: Remove `game_loaded` signal connection (line 48)**

Remove:
```gdscript
	GameManager.game_loaded.connect(_on_game_loaded)
```

- [ ] **Step 2: Remove quest tracking calls (lines 94-96)**

Remove these two lines from `_on_area_entered()`:
```gdscript
		# Track quest progress
		GameManager.update_quest_catch_coins(1)
		GameManager.update_quest_combo(_combo)
```

- [ ] **Step 3: Remove `_on_game_loaded()` function (lines 311-313)**

Remove:
```gdscript
func _on_game_loaded() -> void:
	_combo_multiplier = 1.0
	_update_combo_multiplier()
```

- [ ] **Step 4: Run headless lint**

Run: `godot --headless --script res://tools/lint_project.gd`
Expected: Clean pass for catcher.gd.

---

### Task 8: Remove WelcomePanel from hud.tscn

**Files:**
- Modify: `scenes/hud.tscn:78-123`

- [ ] **Step 1: Remove WelcomePanel subtree (lines 78-123)**

Remove the entire block from `[node name="WelcomePanel"` to the end of the file (line 123):
```
[node name="WelcomePanel" type="PanelContainer" parent="."]
unique_name_in_owner = true
visible = false
anchors_preset = 8
...
text = "Collect!"
```

The file should end after the ShopToggle node (line 77, `text = "Shop"`).

- [ ] **Step 2: Run headless lint**

Run: `godot --headless --script res://tools/lint_project.gd`
Expected: Clean pass. No broken UID references, no missing node paths.

---

### Task 9: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Update Project Overview (line 7)**

Change:
```
Includes an upgrade shop, save/load persistence, and offline earnings.
```
To:
```
Includes an upgrade shop and combo multiplier system. Every session starts fresh.
```

- [ ] **Step 2: Remove save file location from Development Commands (line 21)**

Remove:
```
- **Save file location**: `user://save.json` (auto-saves every 30s + on quit)
```

- [ ] **Step 3: Update Autoloads section — remove persistence/offline lines (lines 117-118)**

Remove these two bullet points:
```
  - Persistence: `save_game()`, `load_game()`, auto-save Timer (30s), save-on-quit via `NOTIFICATION_WM_CLOSE_REQUEST`
  - Offline: `get_offline_earnings()`, `clear_offline_earnings()`, 50% efficiency, 8hr cap, 60s minimum threshold
```

- [ ] **Step 4: Remove WelcomePanel from Scene Tree diagrams**

In the first scene tree (line 107), remove:
```
    └── WelcomePanel (centered popup for offline earnings)
```

In the expanded scene tree (lines 270-271), remove:
```
    └── WelcomePanel (PanelContainer, anchors: center, z_index: 200)
        └── [Popup content for offline earnings]
```

- [ ] **Step 5: Update Key Scenes — hud.tscn description (line 123)**

Change:
```
- **hud.tscn**: CanvasLayer with currency label, upgrade panel (4 buttons created programmatically), and welcome-back popup.
```
To:
```
- **hud.tscn**: CanvasLayer with currency label and upgrade panel (4 buttons created programmatically).
```

- [ ] **Step 6: Update Ascension Effects — remove persistence references (lines 163, 167)**

Change line 163:
```
- **Currency reset:** Resets to 0 coins (offline earnings and welcome panel not affected)
```
To:
```
- **Currency reset:** Resets to 0 coins
```

Remove line 167:
```
- **Ascension count:** Increments by 1 and persists across saves (stored in save file)
```
Replace with:
```
- **Ascension count:** Increments by 1 (session-only, resets on restart)
```

- [ ] **Step 7: Update z_index conventions — remove welcome panel reference (line 225)**

Change:
```
- **200–299**: Overlays (welcome panel, floating text)
```
To:
```
- **200–299**: Overlays (floating text)
```

- [ ] **Step 8: Update CanvasLayer section — remove welcome panel reference (line 237)**

Change:
```
- **Transient popups (layer 2)**: welcome panel, pause menus
```
To:
```
- **Transient popups (layer 2)**: pause menus, modals
```

- [ ] **Step 9: Update Ordering Rationale — remove welcome panel line (line 279)**

Change:
```
- Welcome panel (`z_index: 200`) and floating text (`z_index: 250`) appear on top.
```
To:
```
- Floating text (`z_index: 250`) appears on top.
```

- [ ] **Step 10: Update UI Testing Protocol — remove welcome/persistence tests (lines 292, 294)**

Change line 292 (layering stress test):
```
2. **Layering stress test**: Trigger welcome panel while coins are falling. Coins should pass behind panel if it has `z_index: 200`. Floating text spawned during this should appear above both.
```
To:
```
2. **Layering stress test**: Spawn coins while upgrade panel is open. Verify floating text appears above the panel.
```

Remove line 294 (persistence test):
```
4. **Persistence**: Save, quit, relaunch. HUD should render identically. Check `user://save.json` to confirm state.
```

- [ ] **Step 11: Update Signal Timing section (line 192)**

Change:
```
GameManager `_ready()` runs before scene nodes (autoload ordering). The `currency_changed` emit in `load_game()` fires before listeners connect. All consumers must read `GameManager.currency` directly in their own `_ready()`.
```
To:
```
GameManager `_ready()` runs before scene nodes (autoload ordering). All consumers must read `GameManager.currency` directly in their own `_ready()` for the initial value.
```

- [ ] **Step 12: Run headless lint**

Run: `godot --headless --script res://tools/lint_project.gd`
Expected: Clean pass.

---

### Task 10: Full Validation

**Files:**
- All modified files

- [ ] **Step 1: Run headless lint (full project)**

Run: `godot --headless --script res://tools/lint_project.gd -- --all --fail-on-warn`
Expected: 0 errors, 0 warnings related to removed nodes/references.

- [ ] **Step 2: Launch game and run runtime validation**

Run: `godot --path . &` (start game in background)
Wait 3 seconds, then: `python3 tools/devtools.py ping`
Then: `python3 tools/devtools.py validate-all`
Expected: All scenes validate cleanly.

- [ ] **Step 3: Inspect GameManager state**

Run: `python3 tools/devtools.py get-state --node "/root/GameManager"`
Expected: No `_offline_earnings`, `_streak_count`, `_quest_progress`, `_last_played`, `_last_played_date`, `_active_quest_multiplier`, `_quest_multiplier_end_time`, or `_quest_session_earnings` in the output.

- [ ] **Step 4: Run gameplay input sequence**

Run: `python3 tools/devtools.py input sequence test/sequences/move_catcher.json`
Expected: Sequence executes without errors. Catcher moves, coins are collected.

- [ ] **Step 5: Check performance**

Run: `python3 tools/devtools.py performance`
Expected: Stable FPS (>30), no orphan node growth.

- [ ] **Step 6: Quit game**

Run: `python3 tools/devtools.py quit`
Expected: Game closes cleanly without hanging (no `auto_accept_quit = false` blocking).
