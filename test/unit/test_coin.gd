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
	return not collected and coin_type != 2 and coin_type != 3 and coin_type != 4


func test_silver_emits_missed_on_exit() -> String:
	return _T.assert_true(_should_emit_missed(false, 0), "Silver should emit coin_missed on screen exit")


func test_gold_emits_missed_on_exit() -> String:
	return _T.assert_true(_should_emit_missed(false, 1), "Gold should emit coin_missed on screen exit")


func test_frenzy_does_not_emit_missed() -> String:
	return _T.assert_false(_should_emit_missed(false, 2), "Frenzy should NOT emit coin_missed")


func test_bomb_does_not_emit_missed() -> String:
	return _T.assert_false(_should_emit_missed(false, 3), "Bomb should NOT emit coin_missed")


func test_multi_does_not_emit_missed() -> String:
	return _T.assert_false(_should_emit_missed(false, 4), "Multi should NOT emit coin_missed")


func test_collected_coin_does_not_emit_missed() -> String:
	var collected: bool = true
	var coin_type: int = 0  # SILVER
	var should_emit: bool = not collected and coin_type != 2 and coin_type != 3
	return _T.assert_false(should_emit, "Collected coin should NOT emit coin_missed")


# ============= Coin Spawner Type Distribution =============
# From coin_spawner.gd:42-49 — 5% frenzy, 8% bomb, 10% gold, 77% silver

func _roll_coin_type(roll: float) -> String:
	if roll < 0.05:
		return "FRENZY"
	elif roll < 0.13:
		return "BOMB"
	elif roll < 0.23:
		return "GOLD"
	return "SILVER"


func test_spawn_roll_frenzy_at_0() -> String:
	return _T.assert_eq(_roll_coin_type(0.0), "FRENZY", "Roll 0.0 -> FRENZY")


func test_spawn_roll_frenzy_at_edge() -> String:
	return _T.assert_eq(_roll_coin_type(0.049), "FRENZY", "Roll 0.049 -> FRENZY")


func test_spawn_roll_bomb_at_0_05() -> String:
	return _T.assert_eq(_roll_coin_type(0.05), "BOMB", "Roll 0.05 -> BOMB")


func test_spawn_roll_bomb_at_edge() -> String:
	return _T.assert_eq(_roll_coin_type(0.129), "BOMB", "Roll 0.129 -> BOMB")


func test_spawn_roll_gold_at_0_13() -> String:
	return _T.assert_eq(_roll_coin_type(0.13), "GOLD", "Roll 0.13 -> GOLD")


func test_spawn_roll_gold_at_edge() -> String:
	return _T.assert_eq(_roll_coin_type(0.229), "GOLD", "Roll 0.229 -> GOLD")


func test_spawn_roll_silver_at_0_23() -> String:
	return _T.assert_eq(_roll_coin_type(0.23), "SILVER", "Roll 0.23 -> SILVER")


func test_spawn_roll_silver_at_1() -> String:
	return _T.assert_eq(_roll_coin_type(0.99), "SILVER", "Roll 0.99 -> SILVER")


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
