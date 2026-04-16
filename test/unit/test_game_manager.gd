extends RefCounted

## Unit tests for GameManager (scripts/game_manager.gd).
## Each test creates a fresh instance to ensure isolation.

var _T: GDScript
var _gm_script: GDScript
var _gm: Node


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


# ============= Currency Tests =============

func test_initial_currency_is_zero() -> String:
	var gm: Node = _make_gm()
	var result: String = _T.assert_eq(gm.currency, 0, "Initial currency")
	_free_gm(gm)
	return result


func test_add_currency_basic() -> String:
	var gm: Node = _make_gm()
	gm.add_currency(100)
	var result: String = _T.assert_eq(gm.currency, 100, "After adding 100")
	_free_gm(gm)
	return result


func test_add_currency_accumulates() -> String:
	var gm: Node = _make_gm()
	gm.add_currency(50)
	gm.add_currency(30)
	gm.add_currency(20)
	var result: String = _T.assert_eq(gm.currency, 100, "After adding 50+30+20")
	_free_gm(gm)
	return result


func test_add_currency_zero() -> String:
	var gm: Node = _make_gm()
	gm.add_currency(0)
	var result: String = _T.assert_eq(gm.currency, 0, "Adding zero")
	_free_gm(gm)
	return result


func test_add_currency_negative() -> String:
	var gm: Node = _make_gm()
	gm.add_currency(100)
	gm.add_currency(-30)
	var result: String = _T.assert_eq(gm.currency, 70, "After adding -30 to 100")
	_free_gm(gm)
	return result


func test_add_currency_large_value() -> String:
	var gm: Node = _make_gm()
	gm.add_currency(999999999)
	var result: String = _T.assert_eq(gm.currency, 999999999, "Large currency value")
	_free_gm(gm)
	return result


func test_add_currency_signal_emitted() -> String:
	var gm: Node = _make_gm()
	var received: Array = [-1]
	gm.currency_changed.connect(func(new_amount: int) -> void: received[0] = new_amount)
	gm.add_currency(42)
	var result: String = _T.assert_eq(received[0], 42, "Signal should emit new total")
	_free_gm(gm)
	return result


# ============= Upgrade Level Tests =============

func test_initial_upgrade_levels_zero() -> String:
	var gm: Node = _make_gm()
	var result: String = ""
	for id: String in ["spawn_rate", "coin_value", "catcher_speed", "catcher_width", "auto_catcher", "coin_types"]:
		result = _T.assert_eq(gm.get_upgrade_level(id), 0, "Initial level for %s" % id)
		if result != "":
			break
	_free_gm(gm)
	return result


func test_get_upgrade_level_unknown_id() -> String:
	var gm: Node = _make_gm()
	var result: String = _T.assert_eq(gm.get_upgrade_level("nonexistent"), 0, "Unknown upgrade ID")
	_free_gm(gm)
	return result


# ============= Upgrade Cost Tests =============
# NOTE: Level-0 cost formula tests live in test_upgrade_formulas.gd

func test_upgrade_cost_increases_with_level() -> String:
	var gm: Node = _make_gm()
	gm.currency = 100000
	var cost_0: int = gm.get_upgrade_cost("spawn_rate")
	gm.try_purchase_upgrade("spawn_rate")
	var cost_1: int = gm.get_upgrade_cost("spawn_rate")
	var result: String = _T.assert_gt(cost_1, cost_0, "Cost should increase after purchase")
	_free_gm(gm)
	return result


# ============= Purchase Flow Tests =============

func test_purchase_successful() -> String:
	var gm: Node = _make_gm()
	gm.currency = 100
	var success: bool = gm.try_purchase_upgrade("spawn_rate")
	var result: String = _T.assert_true(success, "Purchase should succeed with enough currency")
	_free_gm(gm)
	return result


func test_purchase_deducts_currency() -> String:
	var gm: Node = _make_gm()
	gm.currency = 100
	var cost: int = gm.get_upgrade_cost("spawn_rate")  # 25
	gm.try_purchase_upgrade("spawn_rate")
	var result: String = _T.assert_eq(gm.currency, 100 - cost, "Currency after purchase")
	_free_gm(gm)
	return result


func test_purchase_increments_level() -> String:
	var gm: Node = _make_gm()
	gm.currency = 100
	gm.try_purchase_upgrade("spawn_rate")
	var result: String = _T.assert_eq(gm.get_upgrade_level("spawn_rate"), 1, "Level after purchase")
	_free_gm(gm)
	return result


func test_purchase_insufficient_funds() -> String:
	var gm: Node = _make_gm()
	gm.currency = 5  # spawn_rate costs 25
	var success: bool = gm.try_purchase_upgrade("spawn_rate")
	var result: String = _T.assert_false(success, "Purchase should fail with insufficient funds")
	if result != "":
		_free_gm(gm)
		return result
	result = _T.assert_eq(gm.currency, 5, "Currency unchanged on failed purchase")
	if result != "":
		_free_gm(gm)
		return result
	result = _T.assert_eq(gm.get_upgrade_level("spawn_rate"), 0, "Level unchanged on failed purchase")
	_free_gm(gm)
	return result


func test_purchase_exact_funds() -> String:
	var gm: Node = _make_gm()
	gm.currency = 25  # Exactly spawn_rate cost
	var success: bool = gm.try_purchase_upgrade("spawn_rate")
	var result: String = _T.assert_true(success, "Purchase with exact funds")
	if result != "":
		_free_gm(gm)
		return result
	result = _T.assert_eq(gm.currency, 0, "Currency should be 0 after exact purchase")
	_free_gm(gm)
	return result


func test_purchase_emits_currency_changed() -> String:
	var gm: Node = _make_gm()
	gm.currency = 100
	var received: Array = [-1]
	gm.currency_changed.connect(func(amt: int) -> void: received[0] = amt)
	gm.try_purchase_upgrade("spawn_rate")
	var result: String = _T.assert_eq(received[0], 75, "currency_changed signal after purchase")
	_free_gm(gm)
	return result


func test_purchase_emits_upgrade_purchased() -> String:
	var gm: Node = _make_gm()
	gm.currency = 100
	var received: Array = [""]
	gm.upgrade_purchased.connect(func(id: String) -> void: received[0] = id)
	gm.try_purchase_upgrade("coin_value")
	var result: String = _T.assert_eq(received[0], "coin_value", "upgrade_purchased signal")
	_free_gm(gm)
	return result


# ============= Spawn Interval Tests =============
# NOTE: Level-0 interval formula tests live in test_upgrade_formulas.gd

func test_spawn_interval_level_1() -> String:
	var gm: Node = _make_gm()
	gm.currency = 100000
	gm.try_purchase_upgrade("spawn_rate")
	var expected: float = 0.8 / pow(1.3, 1)
	var result: String = _T.assert_float_eq(gm.get_spawn_interval(), expected, 0.001, "Spawn interval at level 1")
	_free_gm(gm)
	return result


func test_spawn_interval_min_cap() -> String:
	var gm: Node = _make_gm()
	# At very high levels, interval should floor at 0.1
	# 0.8 / 1.3^n < 0.1 when n > log(8)/log(1.3) ~ 7.9
	gm._upgrade_levels["spawn_rate"] = 100
	var result: String = _T.assert_float_eq(gm.get_spawn_interval(), 0.1, 0.001, "Spawn interval min cap")
	_free_gm(gm)
	return result


func test_spawn_interval_decreases_with_level() -> String:
	var gm: Node = _make_gm()
	var interval_0: float = gm.get_spawn_interval()
	gm._upgrade_levels["spawn_rate"] = 5
	var interval_5: float = gm.get_spawn_interval()
	var result: String = _T.assert_true(interval_5 < interval_0, "Interval should decrease with level")
	_free_gm(gm)
	return result


# ============= Coin Value Tests =============
# NOTE: Level-0 coin value formula tests live in test_upgrade_formulas.gd

func test_coin_value_level_5() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["coin_value"] = 5
	var result: String = _T.assert_eq(gm.get_coin_value(), 6, "Coin value at level 5: 1+5=6")
	_free_gm(gm)
	return result


func test_coin_value_with_combo() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["coin_value"] = 4  # base = 5
	gm.set_combo_multiplier(2.0)
	# int(5 * 1.0 * 2.0) = 10
	var result: String = _T.assert_eq(gm.get_coin_value(), 10, "Coin value with 2x combo")
	_free_gm(gm)
	return result


# ============= Catcher Speed Tests =============
# NOTE: Level-0 speed formula tests live in test_upgrade_formulas.gd

func test_catcher_speed_level_10() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["catcher_speed"] = 10
	var result: String = _T.assert_float_eq(gm.get_catcher_speed(), 1100.0, 0.001, "Speed at level 10")
	_free_gm(gm)
	return result


# ============= Catcher Width Tests =============
# NOTE: Level-0 width formula tests live in test_upgrade_formulas.gd

func test_catcher_width_level_20() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["catcher_width"] = 20
	var result: String = _T.assert_float_eq(gm.get_catcher_width(), 400.0, 0.001, "Width at level 20")
	_free_gm(gm)
	return result


# ============= Bomb Tests =============

func test_bomb_deducts_10_percent() -> String:
	var gm: Node = _make_gm()
	gm.currency = 1000
	gm.trigger_bomb()
	# loss = max(1, 1000/10) = 100, result = max(0, 1000-100) = 900
	var result: String = _T.assert_eq(gm.currency, 900, "Bomb should deduct 10%")
	_free_gm(gm)
	return result


func test_bomb_minimum_loss_is_1() -> String:
	var gm: Node = _make_gm()
	gm.currency = 5  # 5/10 = 0, but min is 1
	gm.trigger_bomb()
	var result: String = _T.assert_eq(gm.currency, 4, "Bomb minimum loss should be 1")
	_free_gm(gm)
	return result


func test_bomb_currency_floor_zero() -> String:
	var gm: Node = _make_gm()
	gm.currency = 0
	gm.trigger_bomb()
	# loss = max(1, 0/10) = 1, result = max(0, 0-1) = 0
	var result: String = _T.assert_eq(gm.currency, 0, "Bomb should not go below zero")
	_free_gm(gm)
	return result


func test_bomb_emits_signals() -> String:
	var gm: Node = _make_gm()
	gm.currency = 100
	var flags: Array = [false, false]  # [bomb_hit, currency_changed]
	gm.bomb_hit.connect(func() -> void: flags[0] = true)
	gm.currency_changed.connect(func(_amt: int) -> void: flags[1] = true)
	gm.trigger_bomb()
	var result: String = _T.assert_true(flags[0], "bomb_hit signal")
	if result != "":
		_free_gm(gm)
		return result
	result = _T.assert_true(flags[1], "currency_changed signal on bomb")
	_free_gm(gm)
	return result


func test_bomb_large_currency() -> String:
	var gm: Node = _make_gm()
	gm.currency = 100000
	gm.trigger_bomb()
	var result: String = _T.assert_eq(gm.currency, 90000, "Bomb on 100000 -> 90000")
	_free_gm(gm)
	return result


# ============= Milestone Tests =============

func test_milestone_100() -> String:
	var gm: Node = _make_gm()
	var triggered: Array = [0]
	gm.milestone_reached.connect(func(m: int) -> void: triggered[0] = m)
	gm.add_currency(100)
	var result: String = _T.assert_eq(triggered[0], 100, "Milestone at 100")
	_free_gm(gm)
	return result


func test_milestone_does_not_retrigger() -> String:
	var gm: Node = _make_gm()
	var counts: Array = [0]
	gm.milestone_reached.connect(func(_m: int) -> void: counts[0] += 1)
	gm.add_currency(100)
	gm.add_currency(50)  # Still above 100, should not retrigger
	# Only the 100 milestone should trigger, not again
	var result: String = _T.assert_eq(counts[0], 1, "Milestone should not re-trigger")
	_free_gm(gm)
	return result


func test_milestone_skips_to_higher() -> String:
	var gm: Node = _make_gm()
	var milestones_hit: Array = []
	gm.milestone_reached.connect(func(m: int) -> void: milestones_hit.append(m))
	gm.add_currency(600)  # Should trigger 100 and 500
	var result: String = _T.assert_eq(milestones_hit.size(), 2, "Should hit both 100 and 500")
	if result != "":
		_free_gm(gm)
		return result
	result = _T.assert_eq(milestones_hit[0], 100, "First milestone is 100")
	if result != "":
		_free_gm(gm)
		return result
	result = _T.assert_eq(milestones_hit[1], 500, "Second milestone is 500")
	_free_gm(gm)
	return result


func test_milestone_incremental_crossing() -> String:
	var gm: Node = _make_gm()
	var milestones_hit: Array = []
	gm.milestone_reached.connect(func(m: int) -> void: milestones_hit.append(m))
	gm.add_currency(50)   # No milestone
	gm.add_currency(50)   # Crosses 100
	gm.add_currency(400)  # Crosses 500
	var result: String = _T.assert_eq(milestones_hit.size(), 2, "Two milestones hit incrementally")
	_free_gm(gm)
	return result


# ============= Combo Tests =============

func test_combo_default_is_1() -> String:
	var gm: Node = _make_gm()
	var result: String = _T.assert_float_eq(gm.get_combo_multiplier(), 1.0, 0.001, "Default combo")
	_free_gm(gm)
	return result


func test_combo_set_and_get() -> String:
	var gm: Node = _make_gm()
	gm.set_combo_multiplier(3.5)
	var result: String = _T.assert_float_eq(gm.get_combo_multiplier(), 3.5, 0.001, "Combo after set")
	_free_gm(gm)
	return result


func test_combo_affects_coin_value() -> String:
	var gm: Node = _make_gm()
	var base_value: int = gm.get_coin_value()  # Should be 1
	gm.set_combo_multiplier(3.0)
	var boosted_value: int = gm.get_coin_value()  # Should be 3
	var result: String = _T.assert_eq(boosted_value, base_value * 3, "Combo 3x should triple coin value")
	_free_gm(gm)
	return result


# ============= Earn Rate Tests =============
# NOTE: Level-0 earn rate formula tests live in test_upgrade_formulas.gd

func test_earn_rate_with_upgrades() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["coin_value"] = 4   # base value = 5
	gm._upgrade_levels["spawn_rate"] = 5   # interval = 0.8 / 1.3^5
	var expected_interval: float = 0.8 / pow(1.3, 5)
	var expected_rate: float = 5.0 / expected_interval
	var result: String = _T.assert_float_eq(gm.get_earn_rate(), expected_rate, 0.1, "Earn rate with upgrades")
	_free_gm(gm)
	return result


# ============= Frenzy Tests =============

func test_frenzy_initially_inactive() -> String:
	var gm: Node = _make_gm()
	var result: String = _T.assert_false(gm.frenzy_active, "Frenzy should start inactive")
	_free_gm(gm)
	return result


func test_start_frenzy_sets_active_and_emits_signal() -> String:
	var gm: Node = _make_gm()
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(gm)
	var received: Array = [false]
	gm.frenzy_started.connect(func() -> void: received[0] = true)
	gm.start_frenzy()
	var result: String = _T.assert_true(gm.frenzy_active, "Frenzy should be active after start_frenzy")
	if result != "":
		tree.root.remove_child(gm)
		_free_gm(gm)
		return result
	result = _T.assert_true(received[0], "frenzy_started signal should be emitted")
	tree.root.remove_child(gm)
	_free_gm(gm)
	return result


# ============= Constants Verification =============

func test_milestones_sorted() -> String:
	var gm: Node = _make_gm()
	var milestones: Array[int] = gm.MILESTONES
	var sorted: bool = true
	for i: int in range(1, milestones.size()):
		if milestones[i] <= milestones[i - 1]:
			sorted = false
			break
	var result: String = _T.assert_true(sorted, "Milestones should be sorted ascending")
	_free_gm(gm)
	return result


func test_all_upgrade_data_present() -> String:
	var gm: Node = _make_gm()
	var expected_ids: Array[String] = ["spawn_rate", "coin_value", "catcher_speed", "catcher_width", "auto_catcher", "coin_types"]
	var result: String = ""
	for id: String in expected_ids:
		if not gm.UPGRADE_DATA.has(id):
			result = "Missing upgrade data for: %s" % id
			break
	_free_gm(gm)
	return result


# ============= Coin Types Upgrade Tests =============

func test_coin_type_unlock_level_initial() -> String:
	var gm: Node = _make_gm()
	var result: String = _T.assert_eq(gm.get_coin_type_unlock_level(), 0, "Initial coin type unlock level")
	_free_gm(gm)
	return result


func test_coin_type_unlock_after_purchase() -> String:
	var gm: Node = _make_gm()
	gm.currency = 1000
	gm.try_purchase_upgrade("coin_types")
	var result: String = _T.assert_eq(gm.get_coin_type_unlock_level(), 1, "Unlock level after purchase")
	_free_gm(gm)
	return result


func test_coin_type_max_level_blocks_purchase() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["coin_types"] = 4
	gm.currency = 100000
	var success: bool = gm.try_purchase_upgrade("coin_types")
	var result: String = _T.assert_false(success, "Should not purchase past max level")
	if result != "":
		_free_gm(gm)
		return result
	result = _T.assert_eq(gm.get_upgrade_level("coin_types"), 4, "Level unchanged at max")
	_free_gm(gm)
	return result


func test_coin_type_cost_progression() -> String:
	var gm: Node = _make_gm()
	var costs: Array[int] = []
	for i: int in range(4):
		costs.append(gm.get_upgrade_cost("coin_types"))
		gm._upgrade_levels["coin_types"] = i + 1
	# base_cost=100, cost_growth=2.5: 100, 250, 625, 1562
	var result: String = _T.assert_eq(costs[0], 100, "Coin types cost at level 0")
	if result != "":
		_free_gm(gm)
		return result
	result = _T.assert_eq(costs[1], 250, "Coin types cost at level 1")
	if result != "":
		_free_gm(gm)
		return result
	result = _T.assert_eq(costs[2], 625, "Coin types cost at level 2")
	if result != "":
		_free_gm(gm)
		return result
	result = _T.assert_eq(costs[3], 1562, "Coin types cost at level 3")
	_free_gm(gm)
	return result


# ============= Boost Power Upgrade Tests =============

func test_boost_power_in_upgrade_data() -> String:
	var gm: Node = _make_gm()
	var has_it: bool = gm.UPGRADE_DATA.has("boost_power")
	var result: String = _T.assert_true(has_it, "boost_power should be in UPGRADE_DATA")
	_free_gm(gm)
	return result


func test_boost_distance_initial() -> String:
	var gm: Node = _make_gm()
	var result: String = _T.assert_float_eq(gm.get_boost_distance(), 200.0, 0.001, "Initial boost distance")
	_free_gm(gm)
	return result


func test_boost_distance_at_level_5() -> String:
	var gm: Node = _make_gm()
	gm._upgrade_levels["boost_power"] = 5
	var result: String = _T.assert_float_eq(gm.get_boost_distance(), 450.0, 0.001, "Boost distance at level 5: 200+250=450")
	_free_gm(gm)
	return result


func test_boost_distance_increases_with_level() -> String:
	var gm: Node = _make_gm()
	var dist_0: float = gm.get_boost_distance()
	gm._upgrade_levels["boost_power"] = 3
	var dist_3: float = gm.get_boost_distance()
	var result: String = _T.assert_gt(dist_3, dist_0, "Boost distance should increase with level")
	_free_gm(gm)
	return result


func test_boost_power_cost_progression() -> String:
	var gm: Node = _make_gm()
	var cost_0: int = gm.get_upgrade_cost("boost_power")
	gm._upgrade_levels["boost_power"] = 1
	var cost_1: int = gm.get_upgrade_cost("boost_power")
	var result: String = _T.assert_eq(cost_0, 50, "Boost power cost at level 0")
	if result != "":
		_free_gm(gm)
		return result
	result = _T.assert_eq(cost_1, 67, "Boost power cost at level 1: int(50*1.35)=67")
	_free_gm(gm)
	return result


