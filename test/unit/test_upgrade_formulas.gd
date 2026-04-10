extends RefCounted

## Exhaustive formula verification for all upgrade calculations.
## Tests exact values at multiple levels to catch rounding/precision issues.

var _T: GDScript
var _gm_script: GDScript


func setup() -> void:
	_gm_script = load("res://scripts/game_manager.gd") as GDScript


func _make_gm() -> Node:
	var gm: Node = _gm_script.new()
	gm._ready()
	return gm


func _free_gm(gm: Node) -> void:
	# Clean up frenzy timer if it exists
	if gm.get("_frenzy_timer") != null:
		var timer: Timer = gm._frenzy_timer
		if timer != null and is_instance_valid(timer):
			timer.queue_free()
	gm.free()


# ============= Spawn Rate Cost Formula: int(10 * 1.15^level) =============

func test_spawn_rate_cost_level_0() -> String:
	var gm: Node = _make_gm()
	var result: String = _T.assert_eq(gm.get_upgrade_cost("spawn_rate"), 10, "spawn_rate cost L0")
	_free_gm(gm)
	return result


func test_spawn_rate_cost_level_1() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["spawn_rate"] = 1
	var expected: int = int(10 * pow(1.15, 1))  # 11
	var result: String = _T.assert_eq(gm.get_upgrade_cost("spawn_rate"), expected, "spawn_rate cost L1")
	_free_gm(gm)
	return result


func test_spawn_rate_cost_level_5() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["spawn_rate"] = 5
	var expected: int = int(10 * pow(1.15, 5))  # 20
	var result: String = _T.assert_eq(gm.get_upgrade_cost("spawn_rate"), expected, "spawn_rate cost L5")
	_free_gm(gm)
	return result


func test_spawn_rate_cost_level_10() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["spawn_rate"] = 10
	var expected: int = int(10 * pow(1.15, 10))
	var result: String = _T.assert_eq(gm.get_upgrade_cost("spawn_rate"), expected, "spawn_rate cost L10")
	_free_gm(gm)
	return result


func test_spawn_rate_cost_level_20() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["spawn_rate"] = 20
	var expected: int = int(10 * pow(1.15, 20))
	var result: String = _T.assert_eq(gm.get_upgrade_cost("spawn_rate"), expected, "spawn_rate cost L20")
	_free_gm(gm)
	return result


# ============= Coin Value Cost Formula: int(15 * 1.12^level) =============

func test_coin_value_cost_level_0() -> String:
	var gm: Node = _make_gm()
	var result: String = _T.assert_eq(gm.get_upgrade_cost("coin_value"), 15, "coin_value cost L0")
	_free_gm(gm)
	return result


func test_coin_value_cost_level_1() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["coin_value"] = 1
	var expected: int = int(15 * pow(1.12, 1))
	var result: String = _T.assert_eq(gm.get_upgrade_cost("coin_value"), expected, "coin_value cost L1")
	_free_gm(gm)
	return result


func test_coin_value_cost_level_5() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["coin_value"] = 5
	var expected: int = int(15 * pow(1.12, 5))
	var result: String = _T.assert_eq(gm.get_upgrade_cost("coin_value"), expected, "coin_value cost L5")
	_free_gm(gm)
	return result


func test_coin_value_cost_level_10() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["coin_value"] = 10
	var expected: int = int(15 * pow(1.12, 10))
	var result: String = _T.assert_eq(gm.get_upgrade_cost("coin_value"), expected, "coin_value cost L10")
	_free_gm(gm)
	return result


func test_coin_value_cost_level_20() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["coin_value"] = 20
	var expected: int = int(15 * pow(1.12, 20))
	var result: String = _T.assert_eq(gm.get_upgrade_cost("coin_value"), expected, "coin_value cost L20")
	_free_gm(gm)
	return result


# ============= Catcher Speed Cost Formula: int(10 * 1.15^level) =============

func test_catcher_speed_cost_level_0() -> String:
	var gm: Node = _make_gm()
	var result: String = _T.assert_eq(gm.get_upgrade_cost("catcher_speed"), 10, "catcher_speed cost L0")
	_free_gm(gm)
	return result


func test_catcher_speed_cost_level_1() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["catcher_speed"] = 1
	var expected: int = int(10 * pow(1.15, 1))
	var result: String = _T.assert_eq(gm.get_upgrade_cost("catcher_speed"), expected, "catcher_speed cost L1")
	_free_gm(gm)
	return result


func test_catcher_speed_cost_level_5() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["catcher_speed"] = 5
	var expected: int = int(10 * pow(1.15, 5))
	var result: String = _T.assert_eq(gm.get_upgrade_cost("catcher_speed"), expected, "catcher_speed cost L5")
	_free_gm(gm)
	return result


func test_catcher_speed_cost_level_10() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["catcher_speed"] = 10
	var expected: int = int(10 * pow(1.15, 10))
	var result: String = _T.assert_eq(gm.get_upgrade_cost("catcher_speed"), expected, "catcher_speed cost L10")
	_free_gm(gm)
	return result


func test_catcher_speed_cost_level_20() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["catcher_speed"] = 20
	var expected: int = int(10 * pow(1.15, 20))
	var result: String = _T.assert_eq(gm.get_upgrade_cost("catcher_speed"), expected, "catcher_speed cost L20")
	_free_gm(gm)
	return result


# ============= Catcher Width Cost Formula: int(20 * 1.18^level) =============

func test_catcher_width_cost_level_0() -> String:
	var gm: Node = _make_gm()
	var result: String = _T.assert_eq(gm.get_upgrade_cost("catcher_width"), 20, "catcher_width cost L0")
	_free_gm(gm)
	return result


func test_catcher_width_cost_level_1() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["catcher_width"] = 1
	var expected: int = int(20 * pow(1.18, 1))
	var result: String = _T.assert_eq(gm.get_upgrade_cost("catcher_width"), expected, "catcher_width cost L1")
	_free_gm(gm)
	return result


func test_catcher_width_cost_level_5() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["catcher_width"] = 5
	var expected: int = int(20 * pow(1.18, 5))
	var result: String = _T.assert_eq(gm.get_upgrade_cost("catcher_width"), expected, "catcher_width cost L5")
	_free_gm(gm)
	return result


func test_catcher_width_cost_level_10() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["catcher_width"] = 10
	var expected: int = int(20 * pow(1.18, 10))
	var result: String = _T.assert_eq(gm.get_upgrade_cost("catcher_width"), expected, "catcher_width cost L10")
	_free_gm(gm)
	return result


func test_catcher_width_cost_level_20() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["catcher_width"] = 20
	var expected: int = int(20 * pow(1.18, 20))
	var result: String = _T.assert_eq(gm.get_upgrade_cost("catcher_width"), expected, "catcher_width cost L20")
	_free_gm(gm)
	return result


# ============= Spawn Interval Formula: max(0.1, 0.8 * 0.95^level) =============

func test_spawn_interval_level_0() -> String:
	var gm: Node = _make_gm()
	var result: String = _T.assert_float_eq(gm.get_spawn_interval(), 0.8, 0.0001, "interval L0")
	_free_gm(gm)
	return result


func test_spawn_interval_level_1() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["spawn_rate"] = 1
	var expected: float = 0.8 * pow(0.95, 1)
	var result: String = _T.assert_float_eq(gm.get_spawn_interval(), expected, 0.0001, "interval L1")
	_free_gm(gm)
	return result


func test_spawn_interval_level_5() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["spawn_rate"] = 5
	var expected: float = 0.8 * pow(0.95, 5)
	var result: String = _T.assert_float_eq(gm.get_spawn_interval(), expected, 0.0001, "interval L5")
	_free_gm(gm)
	return result


func test_spawn_interval_level_10() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["spawn_rate"] = 10
	var expected: float = 0.8 * pow(0.95, 10)
	var result: String = _T.assert_float_eq(gm.get_spawn_interval(), expected, 0.0001, "interval L10")
	_free_gm(gm)
	return result


func test_spawn_interval_level_20() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["spawn_rate"] = 20
	var expected: float = 0.8 * pow(0.95, 20)
	var result: String = _T.assert_float_eq(gm.get_spawn_interval(), expected, 0.0001, "interval L20")
	_free_gm(gm)
	return result


func test_spawn_interval_level_40() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["spawn_rate"] = 40
	var raw: float = 0.8 * pow(0.95, 40)
	var expected: float = maxf(0.1, raw)
	var result: String = _T.assert_float_eq(gm.get_spawn_interval(), expected, 0.0001, "interval L40")
	_free_gm(gm)
	return result


func test_spawn_interval_level_50_capped() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["spawn_rate"] = 50
	# 0.8 * 0.95^50 = ~0.058, capped to 0.1
	var result: String = _T.assert_float_eq(gm.get_spawn_interval(), 0.1, 0.0001, "interval L50 capped")
	_free_gm(gm)
	return result


# ============= Coin Value Formula: int((1 + level) * ascension_mult * combo_mult) =============

func test_coin_value_formula_level_0() -> String:
	var gm: Node = _make_gm()
	var result: String = _T.assert_eq(gm.get_coin_value(), 1, "coin value L0")
	_free_gm(gm)
	return result


func test_coin_value_formula_level_1() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["coin_value"] = 1
	var result: String = _T.assert_eq(gm.get_coin_value(), 2, "coin value L1")
	_free_gm(gm)
	return result


func test_coin_value_formula_level_10() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["coin_value"] = 10
	var result: String = _T.assert_eq(gm.get_coin_value(), 11, "coin value L10")
	_free_gm(gm)
	return result


func test_coin_value_formula_level_20() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["coin_value"] = 20
	var result: String = _T.assert_eq(gm.get_coin_value(), 21, "coin value L20")
	_free_gm(gm)
	return result


func test_coin_value_ascension_2() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["coin_value"] = 9  # base = 10
	gm.ascension_count = 2  # mult = 2.25
	# int(10 * 2.25 * 1.0) = 22
	var result: String = _T.assert_eq(gm.get_coin_value(), 22, "coin value L9 + 2 ascensions")
	_free_gm(gm)
	return result


func test_coin_value_combo_1_5() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["coin_value"] = 9  # base = 10
	gm.set_combo_multiplier(1.5)
	# int(10 * 1.0 * 1.5) = 15
	var result: String = _T.assert_eq(gm.get_coin_value(), 15, "coin value L9 + 1.5x combo")
	_free_gm(gm)
	return result


# ============= Catcher Speed Formula: 600.0 + level * 50.0 =============

func test_catcher_speed_formula_level_0() -> String:
	var gm: Node = _make_gm()
	var result: String = _T.assert_float_eq(gm.get_catcher_speed(), 600.0, 0.001, "speed L0")
	_free_gm(gm)
	return result


func test_catcher_speed_formula_level_1() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["catcher_speed"] = 1
	var result: String = _T.assert_float_eq(gm.get_catcher_speed(), 650.0, 0.001, "speed L1")
	_free_gm(gm)
	return result


func test_catcher_speed_formula_level_5() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["catcher_speed"] = 5
	var result: String = _T.assert_float_eq(gm.get_catcher_speed(), 850.0, 0.001, "speed L5")
	_free_gm(gm)
	return result


func test_catcher_speed_formula_level_10() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["catcher_speed"] = 10
	var result: String = _T.assert_float_eq(gm.get_catcher_speed(), 1100.0, 0.001, "speed L10")
	_free_gm(gm)
	return result


func test_catcher_speed_formula_level_20() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["catcher_speed"] = 20
	var result: String = _T.assert_float_eq(gm.get_catcher_speed(), 1600.0, 0.001, "speed L20")
	_free_gm(gm)
	return result


# ============= Catcher Width Formula: 100.0 + level * 15.0 =============

func test_catcher_width_formula_level_0() -> String:
	var gm: Node = _make_gm()
	var result: String = _T.assert_float_eq(gm.get_catcher_width(), 100.0, 0.001, "width L0")
	_free_gm(gm)
	return result


func test_catcher_width_formula_level_1() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["catcher_width"] = 1
	var result: String = _T.assert_float_eq(gm.get_catcher_width(), 115.0, 0.001, "width L1")
	_free_gm(gm)
	return result


func test_catcher_width_formula_level_5() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["catcher_width"] = 5
	var result: String = _T.assert_float_eq(gm.get_catcher_width(), 175.0, 0.001, "width L5")
	_free_gm(gm)
	return result


func test_catcher_width_formula_level_10() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["catcher_width"] = 10
	var result: String = _T.assert_float_eq(gm.get_catcher_width(), 250.0, 0.001, "width L10")
	_free_gm(gm)
	return result


func test_catcher_width_formula_level_20() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["catcher_width"] = 20
	var result: String = _T.assert_float_eq(gm.get_catcher_width(), 400.0, 0.001, "width L20")
	_free_gm(gm)
	return result


# ============= Ascension Multiplier Formula: 1.5^count =============

func test_ascension_multiplier_0() -> String:
	var gm: Node = _make_gm()
	var result: String = _T.assert_float_eq(gm.get_ascension_multiplier(), 1.0, 0.0001, "ascension mult 0")
	_free_gm(gm)
	return result


func test_ascension_multiplier_1() -> String:
	var gm: Node = _make_gm()
	gm.ascension_count = 1
	var result: String = _T.assert_float_eq(gm.get_ascension_multiplier(), 1.5, 0.0001, "ascension mult 1")
	_free_gm(gm)
	return result


func test_ascension_multiplier_2() -> String:
	var gm: Node = _make_gm()
	gm.ascension_count = 2
	var result: String = _T.assert_float_eq(gm.get_ascension_multiplier(), 2.25, 0.0001, "ascension mult 2")
	_free_gm(gm)
	return result


func test_ascension_multiplier_3() -> String:
	var gm: Node = _make_gm()
	gm.ascension_count = 3
	var result: String = _T.assert_float_eq(gm.get_ascension_multiplier(), 3.375, 0.0001, "ascension mult 3")
	_free_gm(gm)
	return result


func test_ascension_multiplier_5() -> String:
	var gm: Node = _make_gm()
	gm.ascension_count = 5
	var expected: float = pow(1.5, 5)  # 7.59375
	var result: String = _T.assert_float_eq(gm.get_ascension_multiplier(), expected, 0.0001, "ascension mult 5")
	_free_gm(gm)
	return result


func test_ascension_multiplier_10() -> String:
	var gm: Node = _make_gm()
	gm.ascension_count = 10
	var expected: float = pow(1.5, 10)  # ~57.665
	var result: String = _T.assert_float_eq(gm.get_ascension_multiplier(), expected, 0.01, "ascension mult 10")
	_free_gm(gm)
	return result


# ============= Earn Rate Formula: coin_value / spawn_interval =============

func test_earn_rate_level_0() -> String:
	var gm: Node = _make_gm()
	# value=1, interval=0.8 => 1.25
	var result: String = _T.assert_float_eq(gm.get_earn_rate(), 1.25, 0.01, "earn rate L0")
	_free_gm(gm)
	return result


func test_earn_rate_upgraded() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["coin_value"] = 9  # base = 10
	gm._upgrade_levels["spawn_rate"] = 10
	var expected_interval: float = maxf(0.1, 0.8 * pow(0.95, 10))
	var expected_rate: float = 10.0 / expected_interval
	var result: String = _T.assert_float_eq(gm.get_earn_rate(), expected_rate, 0.1, "earn rate upgraded")
	_free_gm(gm)
	return result


func test_earn_rate_with_ascension() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["coin_value"] = 4  # base = 5
	gm.ascension_count = 1  # 1.5x
	# value = int(5 * 1.5) = 7, interval = 0.8
	var expected_rate: float = 7.0 / 0.8
	var result: String = _T.assert_float_eq(gm.get_earn_rate(), expected_rate, 0.01, "earn rate with ascension")
	_free_gm(gm)
	return result


# ============= Cost Growth Monotonicity =============

func test_all_costs_monotonically_increase() -> String:
	var gm: Node = _make_gm()
	var result: String = ""
	for id: String in ["spawn_rate", "coin_value", "catcher_speed", "catcher_width", "auto_catcher"]:
		var prev_cost: int = 0
		for level: int in range(0, 25):
			gm._upgrade_levels[id] = level
			var cost: int = gm.get_upgrade_cost(id)
			if level > 0 and cost <= prev_cost:
				result = "%s cost not monotonic: L%d=%d <= L%d=%d" % [id, level, cost, level - 1, prev_cost]
				_free_gm(gm)
				return result
			prev_cost = cost
		gm._upgrade_levels[id] = 0
	_free_gm(gm)
	return result


# ============= Auto Catcher Cost Formula: int(500 * 1.35^level) =============

func test_auto_catcher_cost_level_0() -> String:
	var gm: Node = _make_gm()
	var result: String = _T.assert_eq(gm.get_upgrade_cost("auto_catcher"), 500, "auto_catcher cost L0")
	_free_gm(gm)
	return result


func test_auto_catcher_cost_level_1() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["auto_catcher"] = 1
	var expected: int = int(500 * pow(1.35, 1))
	var result: String = _T.assert_eq(gm.get_upgrade_cost("auto_catcher"), expected, "auto_catcher cost L1")
	_free_gm(gm)
	return result


func test_auto_catcher_cost_level_5() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["auto_catcher"] = 5
	var expected: int = int(500 * pow(1.35, 5))
	var result: String = _T.assert_eq(gm.get_upgrade_cost("auto_catcher"), expected, "auto_catcher cost L5")
	_free_gm(gm)
	return result


func test_auto_catcher_cost_level_10() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["auto_catcher"] = 10
	var expected: int = int(500 * pow(1.35, 10))
	var result: String = _T.assert_eq(gm.get_upgrade_cost("auto_catcher"), expected, "auto_catcher cost L10")
	_free_gm(gm)
	return result


func test_auto_catcher_cost_level_20() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["auto_catcher"] = 20
	var expected: int = int(500 * pow(1.35, 20))
	var result: String = _T.assert_eq(gm.get_upgrade_cost("auto_catcher"), expected, "auto_catcher cost L20")
	_free_gm(gm)
	return result


func test_auto_catcher_count_level_0() -> String:
	var gm: Node = _make_gm()
	var result: String = _T.assert_eq(gm.get_auto_catcher_count(), 0, "auto_catcher count L0")
	_free_gm(gm)
	return result


func test_auto_catcher_count_level_3() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["auto_catcher"] = 3
	var result: String = _T.assert_eq(gm.get_auto_catcher_count(), 3, "auto_catcher count L3")
	_free_gm(gm)
	return result


func test_auto_catcher_not_core_upgrade() -> String:
	var gm: Node = _make_gm()
	var is_core: bool = "auto_catcher" in gm.CORE_UPGRADES
	var result: String = _T.assert_eq(is_core, false, "auto_catcher not in CORE_UPGRADES")
	_free_gm(gm)
	return result
