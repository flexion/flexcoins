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
signal combo_changed(count: int)

const MILESTONES: Array[int] = [100, 500, 1000, 5000, 10000, 50000, 100000]

const ASCEND_MIN_LEVEL: int = 15
const ASCEND_MULTIPLIER: float = 1.5
const CORE_UPGRADES: Array[String] = ["spawn_rate", "coin_value", "catcher_speed", "catcher_width"]

const UPGRADE_DATA: Dictionary = {
	"spawn_rate": {"name": "Spawn Rate", "description": "More coins fall", "base_cost": 10, "cost_growth": 1.15},
	"coin_value": {"name": "Coin Value", "description": "Each coin worth more", "base_cost": 15, "cost_growth": 1.12},
	"catcher_speed": {"name": "Catcher Speed", "description": "Move faster", "base_cost": 10, "cost_growth": 1.15},
	"catcher_width": {"name": "Catcher Width", "description": "Wider catcher", "base_cost": 20, "cost_growth": 1.18},
	"magnet": {"name": "Magnet", "description": "Attract nearby coins", "base_cost": 25, "cost_growth": 1.20},
}

var currency: int = 0
var _upgrade_levels: Dictionary = {}
var _last_milestone: int = 0
var ascension_count: int = 0
var frenzy_active: bool = false
var _frenzy_timer: Timer
var _combo_multiplier: float = 1.0

func _ready() -> void:
	for id: String in UPGRADE_DATA:
		_upgrade_levels[id] = 0
	for m: int in MILESTONES:
		if currency >= m:
			_last_milestone = m

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
		return true
	return false

func get_spawn_interval() -> float:
	return maxf(0.1, 0.8 * pow(0.95, _upgrade_levels.get("spawn_rate", 0)))

func get_coin_value() -> int:
	var base: int = 1 + int(_upgrade_levels.get("coin_value", 0))
	var ascension_mult := get_ascension_multiplier()
	var combo_mult := _combo_multiplier
	return int(base * ascension_mult * combo_mult)

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
	currency_changed.emit(currency)
	upgrade_purchased.emit("")
	ascended.emit(ascension_count)
	return true

func get_earn_rate() -> float:
	return float(get_coin_value()) / get_spawn_interval()

# ============= Combo Multiplier System =============

func set_combo_multiplier(mult: float) -> void:
	_combo_multiplier = mult

func get_combo_multiplier() -> float:
	return _combo_multiplier

func _check_milestones(old_amount: int, new_amount: int) -> void:
	for m: int in MILESTONES:
		if old_amount < m and new_amount >= m and m > _last_milestone:
			_last_milestone = m
			milestone_reached.emit(m)
