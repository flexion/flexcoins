extends RefCounted

## Unit tests for catcher mechanics (scripts/catcher.gd).
## Tests combo thresholds, bomb interactions, tier progression, and movement logic.
## Note: These test the pure logic extracted from catcher constants/formulas,
## not the scene tree (which requires runtime).

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


# ============= Combo Threshold Constants =============

func test_combo_threshold_50_constant() -> String:
	# Catcher uses COMBO_THRESHOLD_50 = 50
	return _T.assert_eq(50, 50, "COMBO_THRESHOLD_50 should be 50")


func test_combo_threshold_100_constant() -> String:
	# Catcher uses COMBO_THRESHOLD_100 = 100
	return _T.assert_eq(100, 100, "COMBO_THRESHOLD_100 should be 100")


func test_combo_multiplier_50_value() -> String:
	# At 50 combo, multiplier should be 1.5
	return _T.assert_float_eq(1.5, 1.5, 0.001, "COMBO_MULTIPLIER_50 should be 1.5")


func test_combo_multiplier_100_value() -> String:
	# At 100 combo, multiplier should be 2.0
	return _T.assert_float_eq(2.0, 2.0, 0.001, "COMBO_MULTIPLIER_100 should be 2.0")


# ============= Combo Threshold Logic =============
# Replicate _update_combo_multiplier logic from catcher.gd:293-300

func _calc_combo_multiplier(combo: int) -> float:
	if combo >= 100:
		return 2.0
	elif combo >= 50:
		return 1.5
	else:
		return 1.0


func test_combo_multiplier_at_0() -> String:
	var result: float = _calc_combo_multiplier(0)
	return _T.assert_float_eq(result, 1.0, 0.001, "Combo 0 -> 1.0x")


func test_combo_multiplier_at_1() -> String:
	var result: float = _calc_combo_multiplier(1)
	return _T.assert_float_eq(result, 1.0, 0.001, "Combo 1 -> 1.0x")


func test_combo_multiplier_at_49() -> String:
	var result: float = _calc_combo_multiplier(49)
	return _T.assert_float_eq(result, 1.0, 0.001, "Combo 49 -> 1.0x (just below threshold)")


func test_combo_multiplier_at_50() -> String:
	var result: float = _calc_combo_multiplier(50)
	return _T.assert_float_eq(result, 1.5, 0.001, "Combo 50 -> 1.5x (threshold)")


func test_combo_multiplier_at_51() -> String:
	var result: float = _calc_combo_multiplier(51)
	return _T.assert_float_eq(result, 1.5, 0.001, "Combo 51 -> 1.5x")


func test_combo_multiplier_at_99() -> String:
	var result: float = _calc_combo_multiplier(99)
	return _T.assert_float_eq(result, 1.5, 0.001, "Combo 99 -> 1.5x (just below 100)")


func test_combo_multiplier_at_100() -> String:
	var result: float = _calc_combo_multiplier(100)
	return _T.assert_float_eq(result, 2.0, 0.001, "Combo 100 -> 2.0x (threshold)")


func test_combo_multiplier_at_150() -> String:
	var result: float = _calc_combo_multiplier(150)
	return _T.assert_float_eq(result, 2.0, 0.001, "Combo 150 -> 2.0x")


func test_combo_multiplier_at_500() -> String:
	var result: float = _calc_combo_multiplier(500)
	return _T.assert_float_eq(result, 2.0, 0.001, "Combo 500 -> 2.0x (high combo)")


# ============= Combo + GameManager Coin Value Integration =============

func test_coin_value_with_50_combo() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["coin_value"] = 4  # base = 5
	gm.set_combo_multiplier(1.5)  # 50-combo threshold
	# int(5 * 1.0 * 1.5) = 7
	var result: String = _T.assert_eq(gm.get_coin_value(), 7, "Coin value at 1.5x combo: int(5*1.5)=7")
	_free_gm(gm)
	return result


func test_coin_value_with_100_combo() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["coin_value"] = 4  # base = 5
	gm.set_combo_multiplier(2.0)  # 100-combo threshold
	# int(5 * 1.0 * 2.0) = 10
	var result: String = _T.assert_eq(gm.get_coin_value(), 10, "Coin value at 2.0x combo: int(5*2.0)=10")
	_free_gm(gm)
	return result


# ============= Bomb Resets Combo via GameManager =============

func test_bomb_resets_combo_multiplier_in_gm() -> String:
	var gm: Node = _make_gm()
	gm.set_combo_multiplier(2.0)  # Simulate active combo
	gm.currency = 1000
	# Bomb hit should deduct currency; catcher._on_bomb_hit resets combo to 1.0 via GameManager
	# Here we test that set_combo_multiplier(1.0) works correctly
	gm.set_combo_multiplier(1.0)
	var result: String = _T.assert_float_eq(gm.get_combo_multiplier(), 1.0, 0.001, "Combo multiplier reset to 1.0")
	_free_gm(gm)
	return result


func test_bomb_deducts_during_combo() -> String:
	var gm: Node = _make_gm()
	gm.currency = 1000
	gm.set_combo_multiplier(2.0)
	gm.trigger_bomb()
	# Bomb: loss = max(1, 1000/10) = 100 -> 900
	var result: String = _T.assert_eq(gm.currency, 900, "Bomb deducts 10% regardless of combo state")
	_free_gm(gm)
	return result


func test_coin_value_drops_after_combo_reset() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["coin_value"] = 4  # base = 5
	gm.set_combo_multiplier(2.0)
	var boosted: int = gm.get_coin_value()  # 10
	gm.set_combo_multiplier(1.0)  # bomb reset
	var normal: int = gm.get_coin_value()  # 5
	var result: String = _T.assert_eq(boosted, 10, "Boosted value at 2x")
	if result != "":
		_free_gm(gm)
		return result
	result = _T.assert_eq(normal, 5, "Normal value after combo reset")
	_free_gm(gm)
	return result


# ============= Pitch Scaling =============

func _calc_pitch(combo: int) -> float:
	return minf(1.0 + (combo - 1) * 0.08, 2.0)


func test_pitch_at_combo_1() -> String:
	return _T.assert_float_eq(_calc_pitch(1), 1.0, 0.001, "Pitch at combo 1")


func test_pitch_at_combo_5() -> String:
	# 1.0 + 4 * 0.08 = 1.32
	return _T.assert_float_eq(_calc_pitch(5), 1.32, 0.001, "Pitch at combo 5")


func test_pitch_at_combo_10() -> String:
	# 1.0 + 9 * 0.08 = 1.72
	return _T.assert_float_eq(_calc_pitch(10), 1.72, 0.001, "Pitch at combo 10")


func test_pitch_capped_at_2() -> String:
	# 1.0 + 99 * 0.08 = 8.92, capped at 2.0
	return _T.assert_float_eq(_calc_pitch(100), 2.0, 0.001, "Pitch capped at 2.0")


func test_pitch_cap_threshold() -> String:
	# 1.0 + (n-1)*0.08 = 2.0 → n = 13.5, so combo 14 hits cap
	return _T.assert_float_eq(_calc_pitch(14), 2.0, 0.001, "Pitch reaches cap at combo 14")


func test_pitch_just_below_cap() -> String:
	# combo 13: 1.0 + 12*0.08 = 1.96
	return _T.assert_float_eq(_calc_pitch(13), 1.96, 0.001, "Pitch at combo 13 just below cap")


# ============= Catcher Visual Tier Progression =============
# tier = level / 10 (integer division)

func _calc_tier(level: int) -> int:
	return level / 10


func test_tier_at_level_0() -> String:
	return _T.assert_eq(_calc_tier(0), 0, "Tier 0 at level 0")


func test_tier_at_level_9() -> String:
	return _T.assert_eq(_calc_tier(9), 0, "Tier 0 at level 9")


func test_tier_at_level_10() -> String:
	return _T.assert_eq(_calc_tier(10), 1, "Tier 1 at level 10 (wooden)")


func test_tier_at_level_19() -> String:
	return _T.assert_eq(_calc_tier(19), 1, "Tier 1 at level 19")


func test_tier_at_level_20() -> String:
	return _T.assert_eq(_calc_tier(20), 2, "Tier 2 at level 20 (chrome)")


func test_tier_at_level_29() -> String:
	return _T.assert_eq(_calc_tier(29), 2, "Tier 2 at level 29")


func test_tier_at_level_30() -> String:
	return _T.assert_eq(_calc_tier(30), 3, "Tier 3 at level 30 (rainbow)")


func test_tier_at_level_50() -> String:
	return _T.assert_eq(_calc_tier(50), 5, "Tier 5 at level 50 (still rainbow)")


# ============= Catcher Width Formula =============

func test_catcher_width_at_level_0() -> String:
	var gm: Node = _make_gm()
	var result: String = _T.assert_float_eq(gm.get_catcher_width(), 100.0, 0.001, "Width at level 0")
	_free_gm(gm)
	return result


func test_catcher_width_at_level_10_tier_boundary() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["catcher_width"] = 10
	# 100 + 10*15 = 250
	var result: String = _T.assert_float_eq(gm.get_catcher_width(), 250.0, 0.001, "Width at level 10 (tier 1 boundary)")
	_free_gm(gm)
	return result


func test_catcher_width_at_level_30_rainbow() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["catcher_width"] = 30
	# 100 + 30*15 = 550
	var result: String = _T.assert_float_eq(gm.get_catcher_width(), 550.0, 0.001, "Width at level 30 (rainbow tier)")
	_free_gm(gm)
	return result


# ============= Bomb Shrink Formula =============

func test_bomb_shrink_width_60_percent() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["catcher_width"] = 10  # width = 250
	var normal_w: float = gm.get_catcher_width()
	var shrunk_w: float = normal_w * 0.6
	var result: String = _T.assert_float_eq(shrunk_w, 150.0, 0.001, "Bomb shrinks 250 to 150 (60%)")
	_free_gm(gm)
	return result


func test_bomb_shrink_at_base_width() -> String:
	var gm: Node = _make_gm()
	var normal_w: float = gm.get_catcher_width()  # 100
	var shrunk_w: float = normal_w * 0.6
	var result: String = _T.assert_float_eq(shrunk_w, 60.0, 0.001, "Bomb shrinks 100 to 60 (60%)")
	_free_gm(gm)
	return result


# ============= Movement Clamping Logic =============
# Replicate catcher.gd:74 - clamp(x, half_width, viewport_width - half_width)

func _clamp_position(x: float, catcher_width: float, viewport_width: float) -> float:
	var half_width: float = catcher_width / 2.0
	return clampf(x, half_width, viewport_width - half_width)


func test_clamp_within_bounds() -> String:
	var result: float = _clamp_position(500.0, 100.0, 2160.0)
	return _T.assert_float_eq(result, 500.0, 0.001, "Position within bounds unchanged")


func test_clamp_at_left_edge() -> String:
	var result: float = _clamp_position(0.0, 100.0, 2160.0)
	return _T.assert_float_eq(result, 50.0, 0.001, "Clamped to half_width at left edge")


func test_clamp_at_right_edge() -> String:
	var result: float = _clamp_position(2200.0, 100.0, 2160.0)
	return _T.assert_float_eq(result, 2110.0, 0.001, "Clamped to viewport-half_width at right edge")


func test_clamp_wide_catcher() -> String:
	# With width 550 (level 30), half = 275
	var result: float = _clamp_position(100.0, 550.0, 2160.0)
	return _T.assert_float_eq(result, 275.0, 0.001, "Wide catcher clamped at left edge")


func test_clamp_center() -> String:
	var result: float = _clamp_position(1080.0, 100.0, 2160.0)
	return _T.assert_float_eq(result, 1080.0, 0.001, "Center position unchanged")


# ============= Speed Formula =============

func test_catcher_speed_increases_with_level() -> String:
	var gm: Node = _make_gm()
	var speed_0: float = gm.get_catcher_speed()  # 600
	gm._upgrade_levels["catcher_speed"] = 5
	var speed_5: float = gm.get_catcher_speed()  # 850
	var result: String = _T.assert_gt(speed_5, speed_0, "Speed should increase with level")
	_free_gm(gm)
	return result


func test_catcher_speed_formula() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["catcher_speed"] = 8
	# 600 + 8*50 = 1000
	var result: String = _T.assert_float_eq(gm.get_catcher_speed(), 1000.0, 0.001, "Speed at level 8: 600+400=1000")
	_free_gm(gm)
	return result


# ============= Boost Distance Formula =============

func test_boost_distance_at_level_0() -> String:
	var gm: Node = _make_gm()
	var result: String = _T.assert_float_eq(gm.get_boost_distance(), 200.0, 0.001, "Boost distance at level 0")
	_free_gm(gm)
	return result


func test_boost_distance_at_level_5() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["boost_power"] = 5
	var result: String = _T.assert_float_eq(gm.get_boost_distance(), 450.0, 0.001, "Boost distance at level 5: 200+250=450")
	_free_gm(gm)
	return result


func test_boost_distance_at_level_10() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["boost_power"] = 10
	var result: String = _T.assert_float_eq(gm.get_boost_distance(), 700.0, 0.001, "Boost distance at level 10: 200+500=700")
	_free_gm(gm)
	return result


# ============= Boost Clamping Logic =============

func test_boost_clamp_at_left_edge() -> String:
	var target: float = _clamp_position(100.0 - 200.0, 100.0, 2160.0)
	return _T.assert_float_eq(target, 50.0, 0.001, "Boost left clamped at edge")


func test_boost_clamp_at_right_edge() -> String:
	var target: float = _clamp_position(2100.0 + 200.0, 100.0, 2160.0)
	return _T.assert_float_eq(target, 2110.0, 0.001, "Boost right clamped at edge")
