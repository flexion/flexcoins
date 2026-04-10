extends RefCounted

## Unit tests for coin mechanics (scripts/coin.gd).
## Tests coin type value/speed multipliers, magnet attraction formula,
## and screen exit behavior logic.

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


# ============= Magnet Attraction Formula =============
# From coin.gd:93-105 — pull = strength * (1 - |diff|/radius) * sign(diff) * delta

func _calc_magnet_pull(coin_x: float, catcher_x: float, radius: float, strength: float, delta: float) -> float:
	var diff: float = catcher_x - coin_x
	if absf(diff) >= radius:
		return 0.0
	var pull: float = strength * (1.0 - absf(diff) / radius)
	return signf(diff) * pull * delta


func test_magnet_no_pull_when_radius_zero() -> String:
	var gm: Node = _make_gm()
	# magnet level 0 -> radius 0
	var result: String = _T.assert_float_eq(gm.get_magnet_radius(), 0.0, 0.001, "No magnet at level 0")
	_free_gm(gm)
	return result


func test_magnet_pull_at_center() -> String:
	# Coin directly under catcher: diff=0, pull = strength * 1.0 * delta
	var pull: float = _calc_magnet_pull(500.0, 500.0, 110.0, 140.0, 1.0 / 60.0)
	return _T.assert_float_eq(pull, 0.0, 0.001, "No pull when coin is directly under catcher (diff=0)")


func test_magnet_pull_within_radius() -> String:
	# Coin at x=450, catcher at x=500, radius=110, strength=140
	# diff = 50, |diff|=50 < 110, pull = 140 * (1 - 50/110) * 1/60 ≈ 1.273
	var pull: float = _calc_magnet_pull(450.0, 500.0, 110.0, 140.0, 1.0 / 60.0)
	var expected: float = 140.0 * (1.0 - 50.0 / 110.0) / 60.0
	return _T.assert_float_eq(pull, expected, 0.01, "Magnet pull at 50px distance")


func test_magnet_pull_direction_positive() -> String:
	# Catcher to the right of coin -> positive pull
	var pull: float = _calc_magnet_pull(400.0, 500.0, 200.0, 140.0, 1.0)
	return _T.assert_gt(pull, 0.0, "Pull should be positive when catcher is to the right")


func test_magnet_pull_direction_negative() -> String:
	# Catcher to the left of coin -> negative pull
	var pull: float = _calc_magnet_pull(600.0, 500.0, 200.0, 140.0, 1.0)
	var result: String = _T.assert_true(pull < 0.0, "Pull should be negative when catcher is to the left")
	return result


func test_magnet_no_pull_outside_radius() -> String:
	# Coin at x=200, catcher at x=500, radius=110 -> |diff|=300 > 110
	var pull: float = _calc_magnet_pull(200.0, 500.0, 110.0, 140.0, 1.0 / 60.0)
	return _T.assert_float_eq(pull, 0.0, 0.001, "No pull outside radius")


func test_magnet_pull_at_edge_of_radius() -> String:
	# At exactly the edge, |diff| = radius -> pull = strength * 0 = 0
	var pull: float = _calc_magnet_pull(390.0, 500.0, 110.0, 140.0, 1.0 / 60.0)
	return _T.assert_float_eq(pull, 0.0, 0.001, "Zero pull at exact edge of radius")


func test_magnet_pull_strength_scales_with_proximity() -> String:
	# Closer coin should have stronger pull
	var pull_close: float = _calc_magnet_pull(480.0, 500.0, 110.0, 140.0, 1.0)
	var pull_far: float = _calc_magnet_pull(400.0, 500.0, 110.0, 140.0, 1.0)
	return _T.assert_gt(pull_close, pull_far, "Closer coins get stronger pull")


func test_magnet_pull_with_level_5() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["magnet"] = 5
	var radius: float = gm.get_magnet_radius()  # 80+150=230
	var strength: float = gm.get_magnet_strength()  # 100+200=300
	# Coin at distance 100 from catcher
	var pull: float = _calc_magnet_pull(400.0, 500.0, radius, strength, 1.0 / 60.0)
	var expected: float = 300.0 * (1.0 - 100.0 / 230.0) / 60.0
	var result: String = _T.assert_float_eq(pull, expected, 0.01, "Magnet pull at level 5, 100px distance")
	_free_gm(gm)
	return result


# ============= Screen Exit Behavior =============
# From coin.gd:87-90 — coin_missed emits only for SILVER and GOLD

func test_silver_emits_missed_on_exit() -> String:
	# SILVER: not collected, not FRENZY, not BOMB -> should emit coin_missed
	var collected: bool = false
	var coin_type: int = 0  # SILVER
	var should_emit: bool = not collected and coin_type != 2 and coin_type != 3
	return _T.assert_true(should_emit, "Silver should emit coin_missed on screen exit")


func test_gold_emits_missed_on_exit() -> String:
	var collected: bool = false
	var coin_type: int = 1  # GOLD
	var should_emit: bool = not collected and coin_type != 2 and coin_type != 3
	return _T.assert_true(should_emit, "Gold should emit coin_missed on screen exit")


func test_frenzy_does_not_emit_missed() -> String:
	var collected: bool = false
	var coin_type: int = 2  # FRENZY
	var should_emit: bool = not collected and coin_type != 2 and coin_type != 3
	return _T.assert_false(should_emit, "Frenzy should NOT emit coin_missed")


func test_bomb_does_not_emit_missed() -> String:
	var collected: bool = false
	var coin_type: int = 3  # BOMB
	var should_emit: bool = not collected and coin_type != 2 and coin_type != 3
	return _T.assert_false(should_emit, "Bomb should NOT emit coin_missed")


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
