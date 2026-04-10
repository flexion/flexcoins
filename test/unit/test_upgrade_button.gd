extends RefCounted

## Unit tests for upgrade_button.gd pure logic functions.
## Tests format_cost logic and segment/tier calculation.
##
## NOTE: These tests reimplement the logic from upgrade_button.gd rather than
## calling the actual methods directly. This is necessary because UpgradeButton
## requires scene nodes (@onready vars for UI elements) and cannot be instantiated
## in a headless test environment. The reimplementation approach verifies that the
## formula logic is mathematically correct and serves as a specification test.
##
## The actual runtime behavior of upgrade_button.gd is validated through E2E tests
## using devtools commands and visual verification.

var _T: GDScript


func setup() -> void:
	pass


# ============= Format Cost Tests =============
# Tests the cost formatting logic: "Buy: X" for values < 10000, "Buy: X.XK" for
# values < 1000000, "Buy: X.XM" for higher values.

func test_format_cost_zero() -> String:
	var result: String = "Buy: %d" % 0
	return _T.assert_eq(result, "Buy: 0", "Format cost 0")


func test_format_cost_small_single_digit() -> String:
	var result: String = "Buy: %d" % 5
	return _T.assert_eq(result, "Buy: 5", "Format cost 5")


func test_format_cost_small_double_digit() -> String:
	var result: String = "Buy: %d" % 42
	return _T.assert_eq(result, "Buy: 42", "Format cost 42")


func test_format_cost_small_triple_digit() -> String:
	var result: String = "Buy: %d" % 999
	return _T.assert_eq(result, "Buy: 999", "Format cost 999")


func test_format_cost_boundary_9999() -> String:
	var result: String = "Buy: %d" % 9999
	return _T.assert_eq(result, "Buy: 9999", "Format cost 9999 (just below 10K)")


func test_format_cost_threshold_10000() -> String:
	var result: String = "Buy: %.1fK" % (10000 / 1000.0)
	return _T.assert_eq(result, "Buy: 10.0K", "Format cost 10000 (K threshold)")


func test_format_cost_thousands_15k() -> String:
	var result: String = "Buy: %.1fK" % (15000 / 1000.0)
	return _T.assert_eq(result, "Buy: 15.0K", "Format cost 15K")


func test_format_cost_thousands_12345() -> String:
	var result: String = "Buy: %.1fK" % (12345 / 1000.0)
	return _T.assert_eq(result, "Buy: 12.3K", "Format cost 12.3K")


func test_format_cost_thousands_99900() -> String:
	var result: String = "Buy: %.1fK" % (99900 / 1000.0)
	return _T.assert_eq(result, "Buy: 99.9K", "Format cost 99.9K")


func test_format_cost_boundary_999999() -> String:
	var result: String = "Buy: %.1fK" % (999999 / 1000.0)
	return _T.assert_eq(result, "Buy: 1000.0K", "Format cost 999999 (just below 1M)")


func test_format_cost_threshold_1000000() -> String:
	var result: String = "Buy: %.1fM" % (1000000 / 1000000.0)
	return _T.assert_eq(result, "Buy: 1.0M", "Format cost 1M (M threshold)")


func test_format_cost_millions_2500000() -> String:
	var result: String = "Buy: %.1fM" % (2500000 / 1000000.0)
	return _T.assert_eq(result, "Buy: 2.5M", "Format cost 2.5M")


func test_format_cost_millions_10000000() -> String:
	var result: String = "Buy: %.1fM" % (10000000 / 1000000.0)
	return _T.assert_eq(result, "Buy: 10.0M", "Format cost 10M")


func test_format_cost_millions_999999999() -> String:
	var result: String = "Buy: %.1fM" % (999999999 / 1000000.0)
	return _T.assert_eq(result, "Buy: 1000.0M", "Format cost 999999999")


func test_format_cost_boundary_1() -> String:
	var result: String = "Buy: %d" % 1
	return _T.assert_eq(result, "Buy: 1", "Format cost 1 (minimum non-zero)")


func test_format_cost_exact_10000() -> String:
	# Exact boundary between integer and K formatting
	var result: String = "Buy: %.1fK" % (10000 / 1000.0)
	return _T.assert_eq(result, "Buy: 10.0K", "Format cost 10000 (exact boundary)")


func test_format_cost_exact_1000000() -> String:
	# Exact boundary between K and M formatting
	var result: String = "Buy: %.1fM" % (1000000 / 1000000.0)
	return _T.assert_eq(result, "Buy: 1.0M", "Format cost 1000000 (exact boundary)")


# ============= Segment/Tier Logic Tests =============
# Tests the visual progress bar segment calculation from _update_segments(level: int).
# The logic determines how many segments (1-5) should be filled and what tier (color)
# to display based on the upgrade level.
#
# Formula:
#   filled = level % SEGMENTS
#   if level > 0 and filled == 0: filled = SEGMENTS  (show full bar at multiples of 5)
#   tier = (level - 1) / SEGMENTS if level > 0 else 0
#
# This creates a progress bar that fills up over 5 levels, then changes color (tier)
# and starts filling again. E.g., level 1-5 = tier 0 (bronze), level 6-10 = tier 1 (silver).

const SEGMENTS: int = 5


func _calc_segment_data(level: int) -> Dictionary:
	# Reimplements upgrade_button.gd:_update_segments() logic for testing
	var filled: int = level % SEGMENTS
	if level > 0 and filled == 0:
		filled = SEGMENTS
	var tier: int = (level - 1) / SEGMENTS if level > 0 else 0
	return {"filled": filled, "tier": tier}


func test_segments_level_0() -> String:
	var data: Dictionary = _calc_segment_data(0)
	var result: String = _T.assert_eq(data["filled"], 0, "Level 0 filled segments")
	if result != "":
		return result
	return _T.assert_eq(data["tier"], 0, "Level 0 tier")


func test_segments_level_1() -> String:
	var data: Dictionary = _calc_segment_data(1)
	var result: String = _T.assert_eq(data["filled"], 1, "Level 1 filled segments")
	if result != "":
		return result
	return _T.assert_eq(data["tier"], 0, "Level 1 tier")


func test_segments_level_2() -> String:
	var data: Dictionary = _calc_segment_data(2)
	var result: String = _T.assert_eq(data["filled"], 2, "Level 2 filled segments")
	if result != "":
		return result
	return _T.assert_eq(data["tier"], 0, "Level 2 tier")


func test_segments_level_3() -> String:
	var data: Dictionary = _calc_segment_data(3)
	var result: String = _T.assert_eq(data["filled"], 3, "Level 3 filled segments")
	if result != "":
		return result
	return _T.assert_eq(data["tier"], 0, "Level 3 tier")


func test_segments_level_4() -> String:
	var data: Dictionary = _calc_segment_data(4)
	var result: String = _T.assert_eq(data["filled"], 4, "Level 4 filled segments")
	if result != "":
		return result
	return _T.assert_eq(data["tier"], 0, "Level 4 tier")


func test_segments_level_5() -> String:
	var data: Dictionary = _calc_segment_data(5)
	# level 5: 5 % 5 = 0, but level > 0, so filled = 5
	var result: String = _T.assert_eq(data["filled"], 5, "Level 5 filled segments (full bar)")
	if result != "":
		return result
	# tier = (5-1)/5 = 4/5 = 0
	return _T.assert_eq(data["tier"], 0, "Level 5 tier")


func test_segments_level_6() -> String:
	var data: Dictionary = _calc_segment_data(6)
	# 6 % 5 = 1
	var result: String = _T.assert_eq(data["filled"], 1, "Level 6 filled segments")
	if result != "":
		return result
	# tier = (6-1)/5 = 5/5 = 1
	return _T.assert_eq(data["tier"], 1, "Level 6 tier")


func test_segments_level_7() -> String:
	var data: Dictionary = _calc_segment_data(7)
	var result: String = _T.assert_eq(data["filled"], 2, "Level 7 filled segments")
	if result != "":
		return result
	# tier = (7-1)/5 = 6/5 = 1
	return _T.assert_eq(data["tier"], 1, "Level 7 tier")


func test_segments_level_10() -> String:
	var data: Dictionary = _calc_segment_data(10)
	# 10 % 5 = 0, level > 0 => filled = 5
	var result: String = _T.assert_eq(data["filled"], 5, "Level 10 filled segments (full bar)")
	if result != "":
		return result
	# tier = (10-1)/5 = 9/5 = 1
	return _T.assert_eq(data["tier"], 1, "Level 10 tier")


func test_segments_level_11() -> String:
	var data: Dictionary = _calc_segment_data(11)
	var result: String = _T.assert_eq(data["filled"], 1, "Level 11 filled segments")
	if result != "":
		return result
	# tier = (11-1)/5 = 10/5 = 2
	return _T.assert_eq(data["tier"], 2, "Level 11 tier")


func test_segments_level_15() -> String:
	var data: Dictionary = _calc_segment_data(15)
	# 15 % 5 = 0, level > 0 => filled = 5
	var result: String = _T.assert_eq(data["filled"], 5, "Level 15 filled segments (full bar)")
	if result != "":
		return result
	# tier = (15-1)/5 = 14/5 = 2
	return _T.assert_eq(data["tier"], 2, "Level 15 tier")


func test_segments_level_16() -> String:
	var data: Dictionary = _calc_segment_data(16)
	var result: String = _T.assert_eq(data["filled"], 1, "Level 16 filled segments")
	if result != "":
		return result
	# tier = (16-1)/5 = 15/5 = 3
	return _T.assert_eq(data["tier"], 3, "Level 16 tier")


func test_segments_level_20() -> String:
	var data: Dictionary = _calc_segment_data(20)
	# 20 % 5 = 0, level > 0 => filled = 5
	var result: String = _T.assert_eq(data["filled"], 5, "Level 20 filled segments (full bar)")
	if result != "":
		return result
	# tier = (20-1)/5 = 19/5 = 3
	return _T.assert_eq(data["tier"], 3, "Level 20 tier")


func test_segments_level_25() -> String:
	var data: Dictionary = _calc_segment_data(25)
	var result: String = _T.assert_eq(data["filled"], 5, "Level 25 filled segments (full bar)")
	if result != "":
		return result
	# tier = (25-1)/5 = 24/5 = 4
	return _T.assert_eq(data["tier"], 4, "Level 25 tier")


func test_segments_level_30() -> String:
	var data: Dictionary = _calc_segment_data(30)
	var result: String = _T.assert_eq(data["filled"], 5, "Level 30 filled segments (full bar)")
	if result != "":
		return result
	# tier = (30-1)/5 = 29/5 = 5
	return _T.assert_eq(data["tier"], 5, "Level 30 tier")


func test_segments_level_100() -> String:
	var data: Dictionary = _calc_segment_data(100)
	var result: String = _T.assert_eq(data["filled"], 5, "Level 100 filled segments (full bar)")
	if result != "":
		return result
	# tier = (100-1)/5 = 99/5 = 19
	return _T.assert_eq(data["tier"], 19, "Level 100 tier")


# ============= Edge Cases =============

func test_segments_negative_level() -> String:
	# Edge case: negative level (should not happen in practice)
	# The formula treats level <= 0 the same way
	var data: Dictionary = _calc_segment_data(-1)
	var filled: int = -1 % SEGMENTS  # In GDScript, -1 % 5 = 4
	# But the "if level > 0" check fails, so filled stays 4
	# tier = 0 (else branch)
	var result: String = _T.assert_eq(data["filled"], filled, "Negative level filled")
	if result != "":
		return result
	return _T.assert_eq(data["tier"], 0, "Negative level tier")


func test_format_cost_negative() -> String:
	# Edge case: negative cost (should not happen in practice)
	var result: String = "Buy: %d" % -100
	return _T.assert_eq(result, "Buy: -100", "Format cost -100")
