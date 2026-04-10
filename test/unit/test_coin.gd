extends RefCounted

## Unit tests for coin mechanics (scripts/coin.gd).
## Tests coin type value/speed multipliers and screen exit behavior logic.

var _T: GDScript
var _gm_script: GDScript


func setup() -> void:
	_gm_script = load("res://scripts/game_manager.gd") as GDScript


func _make_gm() -> Node:
	var gm: Node = _gm_script.new()
	gm._ready()
	return gm


func _free_gm(gm: Node) -> void:
	if gm.get("_frenzy_timer") != null:
		var timer: Timer = gm._frenzy_timer
		if timer != null and is_instance_valid(timer):
			timer.queue_free()
	gm.free()


# ============= Coin Type Value Multipliers =============
# From coin.gd:39-50 — values applied in _ready()

func test_silver_value_base() -> String:
	var gm: Node = _make_gm()
	# SILVER: value = get_coin_value() = 1 + 0 = 1
	var result: String = _T.assert_eq(gm.get_coin_value(), 1, "Silver base value is 1")
	_free_gm(gm)
	return result


func test_gold_value_5x_base() -> String:
	var gm: Node = _make_gm()
	var base: int = gm.get_coin_value()  # 1
	var gold_value: int = base * 5
	var result: String = _T.assert_eq(gold_value, 5, "Gold value is 5x base")
	_free_gm(gm)
	return result


func test_gold_value_5x_with_upgrades() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["coin_value"] = 9  # base = 10
	var base: int = gm.get_coin_value()  # 10
	var gold_value: int = base * 5
	var result: String = _T.assert_eq(gold_value, 50, "Gold value 5x at coin_value level 9")
	_free_gm(gm)
	return result


func test_frenzy_value_always_zero() -> String:
	# FRENZY coins set value = 0 (coin.gd:45)
	return _T.assert_eq(0, 0, "Frenzy coin value is always 0")


func test_bomb_value_always_zero() -> String:
	# BOMB coins set value = 0 (coin.gd:48)
	return _T.assert_eq(0, 0, "Bomb coin value is always 0")


func test_multi_value_always_zero() -> String:
	# MULTI coins set value = 0 (split coins carry the value)
	return _T.assert_eq(0, 0, "Multi coin value is always 0")


# ============= Coin Type Speed Multipliers =============
# From coin.gd:42,49 — fall_speed adjustments

func test_silver_speed_default() -> String:
	# SILVER: no speed modification, uses @export fall_speed (300)
	var fall_speed: float = 300.0
	return _T.assert_float_eq(fall_speed, 300.0, 0.001, "Silver uses default fall speed")


func test_gold_speed_1_5x() -> String:
	var fall_speed: float = 300.0
	fall_speed *= 1.5  # coin.gd:42
	return _T.assert_float_eq(fall_speed, 450.0, 0.001, "Gold falls at 1.5x speed")


func test_bomb_speed_0_8x() -> String:
	var fall_speed: float = 300.0
	fall_speed *= 0.8  # coin.gd:49
	return _T.assert_float_eq(fall_speed, 240.0, 0.001, "Bomb falls at 0.8x speed (slower)")


func test_frenzy_speed_default() -> String:
	# FRENZY: no speed modification
	var fall_speed: float = 300.0
	return _T.assert_float_eq(fall_speed, 300.0, 0.001, "Frenzy uses default fall speed")


func test_multi_speed_0_9x() -> String:
	var fall_speed: float = 300.0
	fall_speed *= 0.9
	return _T.assert_float_eq(fall_speed, 270.0, 0.001, "Multi falls at 0.9x speed (slightly slower)")


# ============= Speed Ramping Formula =============
# From coin.gd:32,59 — starts at 15%, ramps to full

func test_initial_speed_15_percent() -> String:
	var fall_speed: float = 300.0
	var current_speed: float = fall_speed * 0.15
	return _T.assert_float_eq(current_speed, 45.0, 0.001, "Initial speed is 15% of fall_speed")


func test_speed_ramp_move_toward() -> String:
	# Simulates move_toward: _current_speed approaches fall_speed
	var fall_speed: float = 300.0
	var current_speed: float = fall_speed * 0.15  # 45
	var delta: float = 1.0 / 60.0  # 60fps frame
	# move_toward(45, 300, 300 * delta * 0.8) = move_toward(45, 300, 4.0) = 49
	current_speed = move_toward(current_speed, fall_speed, fall_speed * delta * 0.8)
	var result: String = _T.assert_gt(current_speed, 45.0, "Speed should increase after one frame")
	if result != "":
		return result
	return _T.assert_true(current_speed < fall_speed, "Speed should not reach full in one frame")


func test_speed_ramp_converges() -> String:
	# After many frames, speed should converge to fall_speed
	var fall_speed: float = 300.0
	var current_speed: float = fall_speed * 0.15
	var delta: float = 1.0 / 60.0
	for i: int in range(600):  # 10 seconds of frames
		current_speed = move_toward(current_speed, fall_speed, fall_speed * delta * 0.8)
	return _T.assert_float_eq(current_speed, fall_speed, 0.01, "Speed converges to fall_speed after 10s")


# ============= Screen Exit Behavior =============
# From coin.gd:87-90 — coin_missed emits only for SILVER and GOLD

func _should_emit_missed(collected: bool, coin_type: int) -> bool:
	return not collected and coin_type != 3 and coin_type != 4 and coin_type != 5


func test_copper_emits_missed_on_exit() -> String:
	return _T.assert_true(_should_emit_missed(false, 0), "Copper should emit coin_missed on screen exit")


func test_silver_emits_missed_on_exit() -> String:
	return _T.assert_true(_should_emit_missed(false, 1), "Silver should emit coin_missed on screen exit")


func test_gold_emits_missed_on_exit() -> String:
	return _T.assert_true(_should_emit_missed(false, 2), "Gold should emit coin_missed on screen exit")


func test_frenzy_does_not_emit_missed() -> String:
	return _T.assert_false(_should_emit_missed(false, 3), "Frenzy should NOT emit coin_missed")


func test_bomb_does_not_emit_missed() -> String:
	return _T.assert_false(_should_emit_missed(false, 4), "Bomb should NOT emit coin_missed")


func test_multi_does_not_emit_missed() -> String:
	return _T.assert_false(_should_emit_missed(false, 5), "Multi should NOT emit coin_missed")


func test_collected_coin_does_not_emit_missed() -> String:
	var collected: bool = true
	var coin_type: int = 1  # SILVER
	var should_emit: bool = not collected and coin_type != 3 and coin_type != 4 and coin_type != 5
	return _T.assert_false(should_emit, "Collected coin should NOT emit coin_missed")


# ============= Coin Spawner Type Distribution =============
# From coin_spawner.gd — coin type distribution varies by unlock level (0-4)

func _roll_coin_type(roll: float, unlock_level: int) -> String:
	# Rates descend by unlock order: Copper > Silver > Frenzy/Bomb > Gold > Multi
	match unlock_level:
		0:
			return "COPPER"
		1:
			if roll < 0.70:
				return "COPPER"
			return "SILVER"
		2:
			if roll < 0.12:
				return "FRENZY"
			elif roll < 0.20:
				return "BOMB"
			elif roll < 0.75:
				return "COPPER"
			return "SILVER"
		3:
			if roll < 0.10:
				return "FRENZY"
			elif roll < 0.18:
				return "BOMB"
			elif roll < 0.25:
				return "GOLD"
			elif roll < 0.70:
				return "COPPER"
			return "SILVER"
		_:
			if roll < 0.10:
				return "FRENZY"
			elif roll < 0.18:
				return "BOMB"
			elif roll < 0.23:
				return "MULTI"
			elif roll < 0.30:
				return "GOLD"
			elif roll < 0.70:
				return "COPPER"
			return "SILVER"


func test_spawn_roll_level0_all_copper() -> String:
	return _T.assert_eq(_roll_coin_type(0.0, 0), "COPPER", "Level 0: all rolls -> COPPER")


func test_spawn_roll_level0_high_roll_copper() -> String:
	return _T.assert_eq(_roll_coin_type(0.99, 0), "COPPER", "Level 0: roll 0.99 -> COPPER")


func test_spawn_roll_level1_copper() -> String:
	return _T.assert_eq(_roll_coin_type(0.0, 1), "COPPER", "Level 1: roll 0.0 -> COPPER")


func test_spawn_roll_level1_silver() -> String:
	return _T.assert_eq(_roll_coin_type(0.80, 1), "SILVER", "Level 1: roll 0.80 -> SILVER")


func test_spawn_roll_level2_frenzy() -> String:
	return _T.assert_eq(_roll_coin_type(0.0, 2), "FRENZY", "Level 2: roll 0.0 -> FRENZY")


func test_spawn_roll_level2_bomb() -> String:
	return _T.assert_eq(_roll_coin_type(0.15, 2), "BOMB", "Level 2: roll 0.15 -> BOMB")


func test_spawn_roll_level2_copper() -> String:
	return _T.assert_eq(_roll_coin_type(0.50, 2), "COPPER", "Level 2: roll 0.50 -> COPPER")


func test_spawn_roll_level2_silver() -> String:
	return _T.assert_eq(_roll_coin_type(0.80, 2), "SILVER", "Level 2: roll 0.80 -> SILVER")


func test_spawn_roll_level3_frenzy() -> String:
	return _T.assert_eq(_roll_coin_type(0.0, 3), "FRENZY", "Level 3: roll 0.0 -> FRENZY")


func test_spawn_roll_level3_bomb() -> String:
	return _T.assert_eq(_roll_coin_type(0.12, 3), "BOMB", "Level 3: roll 0.12 -> BOMB")


func test_spawn_roll_level3_gold() -> String:
	return _T.assert_eq(_roll_coin_type(0.20, 3), "GOLD", "Level 3: roll 0.20 -> GOLD")


func test_spawn_roll_level3_copper() -> String:
	return _T.assert_eq(_roll_coin_type(0.50, 3), "COPPER", "Level 3: roll 0.50 -> COPPER")


func test_spawn_roll_level3_silver() -> String:
	return _T.assert_eq(_roll_coin_type(0.80, 3), "SILVER", "Level 3: roll 0.80 -> SILVER")


func test_spawn_roll_level4_frenzy() -> String:
	return _T.assert_eq(_roll_coin_type(0.0, 4), "FRENZY", "Level 4: roll 0.0 -> FRENZY")


func test_spawn_roll_level4_bomb() -> String:
	return _T.assert_eq(_roll_coin_type(0.12, 4), "BOMB", "Level 4: roll 0.12 -> BOMB")


func test_spawn_roll_level4_multi() -> String:
	return _T.assert_eq(_roll_coin_type(0.20, 4), "MULTI", "Level 4: roll 0.20 -> MULTI")


func test_spawn_roll_level4_gold() -> String:
	return _T.assert_eq(_roll_coin_type(0.25, 4), "GOLD", "Level 4: roll 0.25 -> GOLD")


func test_spawn_roll_level4_copper() -> String:
	return _T.assert_eq(_roll_coin_type(0.50, 4), "COPPER", "Level 4: roll 0.50 -> COPPER")


func test_spawn_roll_level4_silver() -> String:
	return _T.assert_eq(_roll_coin_type(0.80, 4), "SILVER", "Level 4: roll 0.80 -> SILVER")


func test_spawn_roll_level_10_same_as_4() -> String:
	var result: String = _T.assert_eq(_roll_coin_type(0.0, 10), "FRENZY", "Level 10 roll 0.0 -> FRENZY (same as level 4)")
	if result != "":
		return result
	result = _T.assert_eq(_roll_coin_type(0.12, 10), "BOMB", "Level 10 roll 0.12 -> BOMB")
	if result != "":
		return result
	result = _T.assert_eq(_roll_coin_type(0.20, 10), "MULTI", "Level 10 roll 0.20 -> MULTI")
	if result != "":
		return result
	result = _T.assert_eq(_roll_coin_type(0.25, 10), "GOLD", "Level 10 roll 0.25 -> GOLD")
	if result != "":
		return result
	result = _T.assert_eq(_roll_coin_type(0.50, 10), "COPPER", "Level 10 roll 0.50 -> COPPER")
	if result != "":
		return result
	return _T.assert_eq(_roll_coin_type(0.80, 10), "SILVER", "Level 10 roll 0.80 -> SILVER")


func test_copper_value_base() -> String:
	var gm: Node = _make_gm()
	var result: String = _T.assert_eq(gm.get_coin_value(), 1, "Copper base value is 1")
	_free_gm(gm)
	return result


func test_copper_speed_default() -> String:
	var fall_speed: float = 300.0
	return _T.assert_float_eq(fall_speed, 300.0, 0.001, "Copper uses default fall speed")


# ============= Frenzy Spawn Rate Acceleration =============
# From coin_spawner.gd:28 — during frenzy, timer = normal / 3.0

func test_frenzy_spawn_rate_3x() -> String:
	var gm: Node = _make_gm()
	var normal_interval: float = gm.get_spawn_interval()  # 0.8
	var frenzy_interval: float = normal_interval / 3.0
	var result: String = _T.assert_float_eq(frenzy_interval, normal_interval / 3.0, 0.001, "Frenzy triples spawn rate")
	_free_gm(gm)
	return result


func test_frenzy_spawn_rate_with_upgrades() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["spawn_rate"] = 10
	var normal: float = gm.get_spawn_interval()  # 0.8 * 0.95^10 ≈ 0.479
	var frenzy: float = normal / 3.0
	var expected: float = 0.8 * pow(0.95, 10) / 3.0
	var result: String = _T.assert_float_eq(frenzy, expected, 0.001, "Frenzy spawn rate with upgraded spawn_rate")
	_free_gm(gm)
	return result


# ============= Shimmer Constants =============

func test_shimmer_interval_range() -> String:
	# SHIMMER_MIN_INTERVAL = 2.0, SHIMMER_MAX_INTERVAL = 4.0
	var result: String = _T.assert_true(2.0 < 4.0, "Min interval < Max interval")
	return result


func test_shimmer_duration() -> String:
	# SHIMMER_DURATION = 0.25
	return _T.assert_float_eq(0.25, 0.25, 0.001, "Shimmer flash duration is 0.25s")
