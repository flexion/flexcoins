extends Node

signal currency_changed(new_amount: int)
signal upgrade_purchased(upgrade_id: String)
signal milestone_reached(amount: int)
signal coin_collected(value: int, world_position: Vector2)
signal coin_missed
signal frenzy_started
signal frenzy_ended
signal bomb_hit
signal ascended(count: int)
signal shop_opened
signal shop_closed
signal combo_multiplier_changed(new_multiplier: float)
signal streak_updated(new_streak_count: int)
signal quest_completed(quest_id: String, reward_multiplier: float)
signal quest_progress_updated(quest_id: String, progress: int, target: int)
signal game_loaded

const SAVE_PATH: String = "user://save.json"
const MAX_OFFLINE_SECONDS: float = 28800.0  # 8 hours
const OFFLINE_EFFICIENCY: float = 0.5
const MILESTONES: Array[int] = [100, 500, 1000, 5000, 10000, 50000, 100000]

const ASCEND_MIN_LEVEL: int = 15
const ASCEND_MULTIPLIER: float = 1.5
const CORE_UPGRADES: Array[String] = ["spawn_rate", "coin_value", "catcher_speed", "catcher_width"]

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

const UPGRADE_DATA: Dictionary = {
	"spawn_rate": {"name": "Spawn Rate", "description": "More coins fall", "base_cost": 10, "cost_growth": 1.15},
	"coin_value": {"name": "Coin Value", "description": "Each coin worth more", "base_cost": 15, "cost_growth": 1.12},
	"catcher_speed": {"name": "Catcher Speed", "description": "Move faster", "base_cost": 10, "cost_growth": 1.15},
	"catcher_width": {"name": "Catcher Width", "description": "Wider catcher", "base_cost": 20, "cost_growth": 1.18},
	"magnet": {"name": "Magnet", "description": "Attract nearby coins", "base_cost": 25, "cost_growth": 1.20},
}

var currency: int = 0
var _upgrade_levels: Dictionary = {}
var _last_played: float = 0.0
var _offline_earnings: int = 0
var _last_milestone: int = 0
var ascension_count: int = 0
var frenzy_active: bool = false
var _frenzy_timer: Timer

# Streak & Quest tracking
var _streak_count: int = 0
var _last_played_date: int = 0
var _quest_progress: Dictionary = {}
var _active_quest_multiplier: float = 1.0
var _quest_multiplier_end_time: int = 0
var _quest_session_earnings: int = 0

# Combo Multiplier tracking
var _combo_multiplier: float = 1.0

func _ready() -> void:
	get_tree().auto_accept_quit = false
	for id: String in UPGRADE_DATA:
		_upgrade_levels[id] = 0
	for quest_id: String in QUEST_DEFINITIONS:
		_quest_progress[quest_id] = 0
	load_game()
	_check_daily_reset()
	# Auto-save every 30 seconds as a safety net
	var autosave_timer := Timer.new()
	autosave_timer.wait_time = 30.0
	autosave_timer.timeout.connect(save_game)
	add_child(autosave_timer)
	autosave_timer.start()
	# Set initial milestone based on loaded currency
	for m: int in MILESTONES:
		if currency >= m:
			_last_milestone = m

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		get_tree().quit()

func add_currency(amount: int) -> void:
	var old_currency := currency
	currency += amount
	currency_changed.emit(currency)
	_check_milestones(old_currency, currency)
	# Track quest 2 progress (earn currency)
	_update_quest_progress("earn_currency", _quest_progress.get("earn_currency", 0) + amount)

func get_upgrade_level(upgrade_id: String) -> int:
	return _upgrade_levels.get(upgrade_id, 0)

func get_upgrade_cost(upgrade_id: String) -> int:
	var data: Dictionary = UPGRADE_DATA[upgrade_id]
	return int(data.base_cost * pow(data.cost_growth, _upgrade_levels[upgrade_id]))

func try_purchase_upgrade(upgrade_id: String) -> bool:
	var cost := get_upgrade_cost(upgrade_id)
	if currency >= cost:
		currency -= cost
		_upgrade_levels[upgrade_id] += 1
		currency_changed.emit(currency)
		upgrade_purchased.emit(upgrade_id)
		save_game()
		return true
	return false

func get_spawn_interval() -> float:
	return maxf(0.1, 0.8 * pow(0.95, _upgrade_levels.get("spawn_rate", 0)))

func get_coin_value() -> int:
	var base: int = 1 + int(_upgrade_levels.get("coin_value", 0))
	var ascension_mult := get_ascension_multiplier()
	var quest_mult := get_active_quest_multiplier()
	var combo_mult := _combo_multiplier
	var streak_mult := get_streak_bonus()
	return int(base * ascension_mult * quest_mult * combo_mult * streak_mult)

func get_catcher_speed() -> float:
	return 600.0 + _upgrade_levels.get("catcher_speed", 0) * 50.0

func get_catcher_width() -> float:
	return 100.0 + _upgrade_levels.get("catcher_width", 0) * 15.0

func get_magnet_radius() -> float:
	var level: int = _upgrade_levels.get("magnet", 0)
	if level == 0:
		return 0.0
	return 80.0 + level * 30.0

func get_magnet_strength() -> float:
	var level: int = _upgrade_levels.get("magnet", 0)
	if level == 0:
		return 0.0
	return 100.0 + level * 40.0

func start_frenzy() -> void:
	if not _frenzy_timer:
		_frenzy_timer = Timer.new()
		_frenzy_timer.one_shot = true
		_frenzy_timer.timeout.connect(_end_frenzy)
		add_child(_frenzy_timer)
	frenzy_active = true
	_frenzy_timer.start(5.0)
	frenzy_started.emit()

func trigger_bomb() -> void:
	var loss := maxi(1, currency / 10)
	currency = maxi(0, currency - loss)
	currency_changed.emit(currency)
	bomb_hit.emit()

func _end_frenzy() -> void:
	frenzy_active = false
	frenzy_ended.emit()

func get_ascension_multiplier() -> float:
	if ascension_count == 0:
		return 1.0
	return pow(ASCEND_MULTIPLIER, ascension_count)

func can_ascend() -> bool:
	for id: String in CORE_UPGRADES:
		if _upgrade_levels.get(id, 0) < ASCEND_MIN_LEVEL:
			return false
	return true

func try_ascend() -> bool:
	if not can_ascend():
		return false
	ascension_count += 1
	currency = 0
	for id: String in _upgrade_levels:
		_upgrade_levels[id] = 0
	_last_milestone = 0
	# Reset quests but keep streak
	_reset_daily_quests()
	currency_changed.emit(currency)
	upgrade_purchased.emit("")
	ascended.emit(ascension_count)
	save_game()
	return true

func get_earn_rate() -> float:
	return float(get_coin_value()) / get_spawn_interval()

func get_offline_earnings() -> int:
	return _offline_earnings

func clear_offline_earnings() -> void:
	_offline_earnings = 0

# ============= Combo Multiplier System =============

func set_combo_multiplier(mult: float) -> void:
	_combo_multiplier = mult

func get_combo_multiplier() -> float:
	return _combo_multiplier

# ============= Streak & Quest System =============

func _get_unix_day() -> int:
	var local_time := Time.get_datetime_dict_from_system()
	var year: int = local_time["year"]
	var month: int = local_time["month"]
	var day: int = local_time["day"]
	return year * 10000 + month * 100 + day

func _check_daily_reset() -> void:
	var current_day := _get_unix_day()
	if _last_played_date == 0:
		# First session
		_last_played_date = current_day
		_streak_count = 1
		_reset_daily_quests()
		return
	if current_day == _last_played_date:
		# Same day, no reset needed
		return
	if current_day == _last_played_date + 1:
		# Next day, increment streak
		_streak_count += 1
	else:
		# More than 1 day has passed, streak resets
		_streak_count = 1
	_last_played_date = current_day
	# Only reset if multiplier has expired
	var current_time := int(Time.get_unix_time_from_system())
	if _quest_multiplier_end_time <= current_time:
		_reset_daily_quests()
	else:
		# Multiplier still active, only reset progress
		_quest_progress.clear()
		for quest_id: String in QUEST_DEFINITIONS:
			_quest_progress[quest_id] = 0
	streak_updated.emit(_streak_count)

func _reset_daily_quests() -> void:
	_quest_progress["catch_coins"] = 0
	_quest_progress["earn_currency"] = 0
	_quest_progress["reach_combo"] = 0
	_quest_session_earnings = 0
	_active_quest_multiplier = 1.0
	_quest_multiplier_end_time = 0

func get_streak_bonus() -> float:
	var capped_streak := mini(_streak_count, MAX_STREAK_CAP)
	return 1.0 + (capped_streak * STREAK_BONUS_PER_DAY)

func get_streak_count() -> int:
	return _streak_count

func get_active_quest_multiplier() -> float:
	if _quest_multiplier_end_time == 0:
		return 1.0
	var current_time := int(Time.get_unix_time_from_system())
	if current_time >= _quest_multiplier_end_time:
		_active_quest_multiplier = 1.0
		_quest_multiplier_end_time = 0
		return 1.0
	return 1.0 + QUEST_MULTIPLIER_BOOST

func get_quest_multiplier_time_remaining() -> int:
	if _quest_multiplier_end_time == 0:
		return 0
	var current_time := int(Time.get_unix_time_from_system())
	if current_time >= _quest_multiplier_end_time:
		_active_quest_multiplier = 1.0
		_quest_multiplier_end_time = 0
		return 0
	return _quest_multiplier_end_time - current_time

func get_quest_progress(quest_id: String) -> int:
	return _quest_progress.get(quest_id, 0)

func _update_quest_progress(quest_id: String, new_value: int) -> void:
	if quest_id not in QUEST_DEFINITIONS:
		return
	var target: int = QUEST_DEFINITIONS[quest_id].target
	new_value = mini(new_value, target)
	_quest_progress[quest_id] = new_value
	quest_progress_updated.emit(quest_id, new_value, target)
	# Check if quest is completed
	if new_value >= target and _quest_multiplier_end_time == 0:
		_check_quest_completion()

func _check_quest_completion() -> void:
	# Award multiplier for individual quest completion
	for quest_id: String in QUEST_DEFINITIONS:
		var target: int = QUEST_DEFINITIONS[quest_id].target
		var progress: int = _quest_progress.get(quest_id, 0)
		if progress >= target:
			_grant_quest_multiplier_for_quest(quest_id)

func _grant_quest_multiplier_for_quest(quest_id: String) -> void:
	if _quest_multiplier_end_time > int(Time.get_unix_time_from_system()):
		return  # Already active
	_active_quest_multiplier = 1.0 + QUEST_MULTIPLIER_BOOST
	_quest_multiplier_end_time = int(Time.get_unix_time_from_system()) + QUEST_BOOST_DURATION_SEC
	quest_completed.emit(quest_id, _active_quest_multiplier)

func update_quest_catch_coins(count: int) -> void:
	_update_quest_progress("catch_coins", _quest_progress.get("catch_coins", 0) + count)

func update_quest_combo(combo_level: int) -> void:
	if combo_level > _quest_progress.get("reach_combo", 0):
		_update_quest_progress("reach_combo", combo_level)

func save_game() -> void:
	var data: Dictionary = {
		"save_version": 2,
		"currency": currency,
		"upgrade_levels": _upgrade_levels,
		"ascension_count": ascension_count,
		"last_played": Time.get_unix_time_from_system(),
		"streak_count": _streak_count,
		"last_played_date": _last_played_date,
		"quest_progress": _quest_progress,
		"active_quest_multiplier": _active_quest_multiplier,
		"quest_multiplier_end_time": _quest_multiplier_end_time,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		game_loaded.emit()
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		game_loaded.emit()
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is not Dictionary:
		game_loaded.emit()
		return
	var data: Dictionary = parsed
	var save_version: int = int(data.get("save_version", 1))
	if save_version < 2:
		print("Migrated save from v1 to v2 (added quest system)")
	currency = 0
	var saved_levels: Variant = data.get("upgrade_levels", {})
	if saved_levels is Dictionary:
		for id: String in _upgrade_levels:
			if id in saved_levels:
				_upgrade_levels[id] = int(saved_levels[id])
	ascension_count = int(data.get("ascension_count", 0))
	# Load streak and quest data
	_streak_count = int(data.get("streak_count", 0))
	_last_played_date = int(data.get("last_played_date", 0))
	var saved_quest_progress: Variant = data.get("quest_progress", {})
	if saved_quest_progress is Dictionary:
		for quest_id: String in QUEST_DEFINITIONS:
			_quest_progress[quest_id] = int(saved_quest_progress.get(quest_id, 0))
	_active_quest_multiplier = float(data.get("active_quest_multiplier", 1.0))
	_quest_multiplier_end_time = int(data.get("quest_multiplier_end_time", 0))
	# Validate multiplier not expired
	var current_time := int(Time.get_unix_time_from_system())
	if _quest_multiplier_end_time > 0 and current_time >= _quest_multiplier_end_time:
		_active_quest_multiplier = 1.0
		_quest_multiplier_end_time = 0
	var last_played: float = data.get("last_played", 0.0)
	if last_played > 0.0:
		var elapsed: float = clampf(Time.get_unix_time_from_system() - last_played, 0.0, MAX_OFFLINE_SECONDS)
		if elapsed > 60.0:
			_offline_earnings = int(elapsed * get_earn_rate() * OFFLINE_EFFICIENCY)
			currency += _offline_earnings
	# This fires before scene nodes connect signals. Consumers must read
	# GameManager.currency in their own _ready() for the initial value.
	currency_changed.emit(currency)
	game_loaded.emit()

func _check_milestones(old_amount: int, new_amount: int) -> void:
	for m: int in MILESTONES:
		if old_amount < m and new_amount >= m and m > _last_milestone:
			_last_milestone = m
			milestone_reached.emit(m)
