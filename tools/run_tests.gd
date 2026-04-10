@tool
extends SceneTree

## Headless unit test runner for FlexCoins.
## Run: godot --headless --script res://tools/run_tests.gd
## Args: -- --json          Output results as JSON
##       -- --filter NAME   Run only tests matching NAME

const TEST_SCRIPTS: Array[String] = [
	"res://test/unit/test_game_manager.gd",
	"res://test/unit/test_upgrade_formulas.gd",
	"res://test/unit/test_upgrade_button.gd",
	"res://test/unit/test_catcher.gd",
	"res://test/unit/test_coin.gd",
]

var _passed: int = 0
var _failed: int = 0
var _skipped: int = 0
var _errors: Array[Dictionary] = []
var _results: Array[Dictionary] = []
var _json_output: bool = false
var _filter: String = ""


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in args.size():
		match args[i]:
			"--json":
				_json_output = true
			"--filter":
				if i + 1 < args.size():
					_filter = args[i + 1]

	_run_all_tests()
	_print_results()

	var exit_code: int = 0 if _failed == 0 else 1
	quit(exit_code)


func _run_all_tests() -> void:
	for script_path: String in TEST_SCRIPTS:
		var script: GDScript = load(script_path) as GDScript
		if script == null:
			_errors.append({"script": script_path, "error": "Failed to load script"})
			_failed += 1
			continue

		var test_obj: RefCounted = script.new()
		if test_obj == null:
			_errors.append({"script": script_path, "error": "Failed to instantiate"})
			_failed += 1
			continue

		# Inject assertion helper script reference
		var runner_script: GDScript = get_script() as GDScript
		test_obj.set("_T", runner_script)

		var methods: Array[Dictionary] = script.get_script_method_list()
		for method: Dictionary in methods:
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			if _filter != "" and not method_name.contains(_filter):
				_skipped += 1
				continue

			_run_single_test(test_obj, method_name, script_path)


func _run_single_test(test_obj: RefCounted, method_name: String, script_path: String) -> void:
	# Call setup if it exists
	if test_obj.has_method("setup"):
		test_obj.call("setup")

	var result: Dictionary = {"script": script_path, "test": method_name, "status": "PASS", "message": ""}
	var start_time: int = Time.get_ticks_msec()

	# Run the test - catch assertion failures via return value
	var error_msg: String = test_obj.call(method_name) as String
	if error_msg == null:
		error_msg = ""

	var elapsed: int = Time.get_ticks_msec() - start_time

	if error_msg != "":
		result["status"] = "FAIL"
		result["message"] = error_msg
		_failed += 1
	else:
		_passed += 1

	result["elapsed_ms"] = elapsed
	_results.append(result)

	# Call teardown if it exists
	if test_obj.has_method("teardown"):
		test_obj.call("teardown")


func _print_results() -> void:
	if _json_output:
		var output: Dictionary = {
			"passed": _passed,
			"failed": _failed,
			"skipped": _skipped,
			"total": _passed + _failed + _skipped,
			"errors": _errors,
			"results": _results,
		}
		print(JSON.stringify(output, "  "))
		return

	# Pretty-print
	print("")
	print("=" .repeat(60))
	print("  FlexCoins Unit Tests")
	print("=" .repeat(60))
	print("")

	for result: Dictionary in _results:
		var status: String = result["status"]
		var icon: String = "[PASS]" if status == "PASS" else "[FAIL]"
		var test_name: String = result["test"]
		var elapsed: int = result.get("elapsed_ms", 0)
		print("  %s %s (%dms)" % [icon, test_name, elapsed])
		if status == "FAIL":
			print("         %s" % result.get("message", ""))

	for err: Dictionary in _errors:
		print("  [ERR]  %s: %s" % [err["script"], err["error"]])

	print("")
	print("-" .repeat(60))
	var total: int = _passed + _failed + _skipped
	print("  Total: %d  |  Passed: %d  |  Failed: %d  |  Skipped: %d" % [total, _passed, _failed, _skipped])
	print("-" .repeat(60))

	if _failed == 0:
		print("  ALL TESTS PASSED")
	else:
		print("  SOME TESTS FAILED")
	print("")


# ============= Assertion Helpers (static) =============
# These are called by test scripts via the _runner reference.

static func assert_eq(actual: Variant, expected: Variant, context: String = "") -> String:
	if actual == expected:
		return ""
	var msg: String = "Expected %s but got %s" % [str(expected), str(actual)]
	if context != "":
		msg = "%s: %s" % [context, msg]
	return msg


static func assert_true(condition: bool, context: String = "") -> String:
	if condition:
		return ""
	var msg: String = "Expected true but got false"
	if context != "":
		msg = "%s: %s" % [context, msg]
	return msg


static func assert_false(condition: bool, context: String = "") -> String:
	if not condition:
		return ""
	var msg: String = "Expected false but got true"
	if context != "":
		msg = "%s: %s" % [context, msg]
	return msg


static func assert_float_eq(actual: float, expected: float, tolerance: float = 0.001, context: String = "") -> String:
	if absf(actual - expected) <= tolerance:
		return ""
	var msg: String = "Expected %.6f but got %.6f (tolerance: %.6f)" % [expected, actual, tolerance]
	if context != "":
		msg = "%s: %s" % [context, msg]
	return msg


static func assert_gt(actual: Variant, threshold: Variant, context: String = "") -> String:
	if actual > threshold:
		return ""
	var msg: String = "Expected %s > %s" % [str(actual), str(threshold)]
	if context != "":
		msg = "%s: %s" % [context, msg]
	return msg


static func assert_gte(actual: Variant, threshold: Variant, context: String = "") -> String:
	if actual >= threshold:
		return ""
	var msg: String = "Expected %s >= %s" % [str(actual), str(threshold)]
	if context != "":
		msg = "%s: %s" % [context, msg]
	return msg
