extends Node

signal currency_changed(new_amount: int)
signal upgrade_purchased(upgrade_id: String)
signal milestone_reached(amount: int)
signal coin_collected(value: int, world_position: Vector2)

const SAVE_PATH: String = "user://save.json"
const MAX_OFFLINE_SECONDS: float = 28800.0  # 8 hours
const OFFLINE_EFFICIENCY: float = 0.5
const MILESTONES: Array[int] = [100, 500, 1000, 5000, 10000, 50000, 100000]

const UPGRADE_DATA: Dictionary = {
	"spawn_rate": {"name": "Spawn Rate", "description": "More coins fall", "base_cost": 10, "cost_growth": 1.15},
	"coin_value": {"name": "Coin Value", "description": "Each coin worth more", "base_cost": 15, "cost_growth": 1.12},
	"catcher_speed": {"name": "Catcher Speed", "description": "Move faster", "base_cost": 10, "cost_growth": 1.15},
	"catcher_width": {"name": "Catcher Width", "description": "Wider catcher", "base_cost": 20, "cost_growth": 1.18},
}

var currency: int = 0
var _upgrade_levels: Dictionary = {}
var _last_played: float = 0.0
var _offline_earnings: int = 0
var _last_milestone: int = 0

func _ready() -> void:
	get_tree().auto_accept_quit = false
	for id: String in UPGRADE_DATA:
		_upgrade_levels[id] = 0
	load_game()
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
	return 1 + _upgrade_levels.get("coin_value", 0)

func get_catcher_speed() -> float:
	return 600.0 + _upgrade_levels.get("catcher_speed", 0) * 50.0

func get_catcher_width() -> float:
	return 100.0 + _upgrade_levels.get("catcher_width", 0) * 15.0

func get_earn_rate() -> float:
	return float(get_coin_value()) / get_spawn_interval()

func get_offline_earnings() -> int:
	return _offline_earnings

func clear_offline_earnings() -> void:
	_offline_earnings = 0

func save_game() -> void:
	var data: Dictionary = {
		"currency": currency,
		"upgrade_levels": _upgrade_levels,
		"last_played": Time.get_unix_time_from_system(),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is not Dictionary:
		return
	var data: Dictionary = parsed
	currency = 0
	var saved_levels: Variant = data.get("upgrade_levels", {})
	if saved_levels is Dictionary:
		for id: String in _upgrade_levels:
			if id in saved_levels:
				_upgrade_levels[id] = int(saved_levels[id])
	var last_played: float = data.get("last_played", 0.0)
	if last_played > 0.0:
		var elapsed: float = clampf(Time.get_unix_time_from_system() - last_played, 0.0, MAX_OFFLINE_SECONDS)
		if elapsed > 60.0:
			_offline_earnings = int(elapsed * get_earn_rate() * OFFLINE_EFFICIENCY)
			currency += _offline_earnings
	# This fires before scene nodes connect signals. Consumers must read
	# GameManager.currency in their own _ready() for the initial value.
	currency_changed.emit(currency)

func _check_milestones(old_amount: int, new_amount: int) -> void:
	for m: int in MILESTONES:
		if old_amount < m and new_amount >= m and m > _last_milestone:
			_last_milestone = m
			milestone_reached.emit(m)
