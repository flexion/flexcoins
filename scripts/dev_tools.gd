extends Node

## DevTools autoload providing a file-based command interface for Claude Code automation.
## Commands are read from a JSON file on disk, executed, and results written back.
## Designed for headless automation, testing, and CI integration.

# --- Constants ---

const COMMANDS_PATH: String = "user://devtools_commands.json"
const RESULTS_PATH: String = "user://devtools_results.json"
const LOG_PATH: String = "user://devtools_log.jsonl"
const COIN_TYPE_MAP: Dictionary = {
	"COPPER": 0,
	"SILVER": 1,
	"GOLD": 2,
	"FRENZY": 3,
	"BOMB": 4,
	"MULTI": 5,
}

# --- Variables ---

var _commands_abs_path: String
var _results_abs_path: String
var _log_abs_path: String
var _last_command_check_msec: int = 0
var _handlers: Dictionary = {}
var _active_simulated_inputs: Array[String] = []


# --- Lifecycle ---

func _ready() -> void:
	_commands_abs_path = ProjectSettings.globalize_path(COMMANDS_PATH)
	_results_abs_path = ProjectSettings.globalize_path(RESULTS_PATH)
	_log_abs_path = ProjectSettings.globalize_path(LOG_PATH)

	_handlers["ping"] = _cmd_ping
	_handlers["screenshot"] = _cmd_screenshot
	_handlers["scene_tree"] = _cmd_scene_tree
	_handlers["validate_scene"] = _cmd_validate_scene
	_handlers["validate_all"] = _cmd_validate_all
	_handlers["get_state"] = _cmd_get_state
	_handlers["set_state"] = _cmd_set_state
	_handlers["run_method"] = _cmd_run_method
	_handlers["performance"] = _cmd_performance
	_handlers["quit"] = _cmd_quit
	_handlers["input_press"] = _cmd_input_press
	_handlers["input_release"] = _cmd_input_release
	_handlers["input_tap"] = _cmd_input_tap
	_handlers["input_clear"] = _cmd_input_clear
	_handlers["input_actions"] = _cmd_input_actions
	_handlers["input_sequence"] = _cmd_input_sequence
	_handlers["spawn_coin"] = _cmd_spawn_coin
	_handlers["spawn_coin_on_catcher"] = _cmd_spawn_coin_on_catcher
	_handlers["get_active_coins"] = _cmd_get_active_coins
	_handlers["clear_coins"] = _cmd_clear_coins
	_handlers["set_upgrade_levels"] = _cmd_set_upgrade_levels
	_handlers["reset_session"] = _cmd_reset_session
	_handlers["ascend"] = _cmd_ascend
	_handlers["set_game_speed"] = _cmd_set_game_speed
	_handlers["wait_frames"] = _cmd_wait_frames
	_handlers["get_catcher_state"] = _cmd_get_catcher_state
	_handlers["validate_ui"] = _cmd_validate_ui
	_handlers["validate_ui_interactive"] = _cmd_validate_ui_interactive
	_handlers["get_ui_snapshot"] = _cmd_get_ui_snapshot
	_handlers["get_node_bounds"] = _cmd_get_node_bounds
	_handlers["save_ui_baseline"] = _cmd_save_ui_baseline
	_handlers["ui_snapshot_diff"] = _cmd_ui_snapshot_diff

	_clear_stale_files()
	_write_log("system", "DevTools initialized", {
		"commands_path": _commands_abs_path,
		"results_path": _results_abs_path,
	})

	_process_command_line_args()


func _process(delta: float) -> void:
	var now_msec: int = Time.get_ticks_msec()
	if now_msec - _last_command_check_msec >= 100:
		_last_command_check_msec = now_msec
		_check_for_commands()


func _exit_tree() -> void:
	_clear_all_simulated_inputs()


# --- Command Processing ---

func _check_for_commands() -> void:
	if not FileAccess.file_exists(COMMANDS_PATH):
		return

	var json_text: String = FileAccess.get_file_as_string(COMMANDS_PATH)
	DirAccess.remove_absolute(_commands_abs_path)

	if json_text.is_empty():
		_write_log("error", "Empty command file")
		return

	var parsed: Variant = JSON.parse_string(json_text)
	if parsed == null or not parsed is Dictionary:
		_write_log("error", "Failed to parse command JSON", {"raw": json_text.substr(0, 200)})
		return

	var command: Dictionary = parsed
	var action: String = command.get("action", "")
	var args: Dictionary = command.get("args", {})

	if action.is_empty():
		_write_result("unknown", {"success": false, "message": "No action specified"})
		return

	if not _handlers.has(action):
		_write_result(action, {"success": false, "message": "Unknown action: %s" % action})
		_write_log("error", "Unknown action: %s" % action)
		return

	_write_log("command", "Executing: %s" % action, args)

	var handler: Callable = _handlers[action]
	var result: Dictionary = await handler.call(args)
	_write_result(action, result)


func _write_result(action: String, result: Dictionary) -> void:
	var response: Dictionary = {
		"action": action,
		"success": result.get("success", false),
		"message": result.get("message", ""),
		"data": result.get("data"),
		"timestamp": Time.get_unix_time_from_system(),
	}
	var file: FileAccess = FileAccess.open(RESULTS_PATH, FileAccess.WRITE)
	if file == null:
		_write_log("error", "Failed to write result file", {"error": FileAccess.get_open_error()})
		return
	file.store_string(JSON.stringify(response, "  "))
	file.close()


func _process_command_line_args() -> void:
	var args: PackedStringArray = OS.get_cmdline_args()
	for arg in args:
		match arg:
			"--devtools-screenshot":
				# Take a screenshot on the next frame so the scene is rendered.
				await get_tree().process_frame
				var result: Dictionary = _cmd_screenshot({})
				_write_log("cli", "CLI screenshot", result)
			"--devtools-validate":
				# Validate after the scene tree is ready.
				await get_tree().process_frame
				var result: Dictionary = _cmd_validate_all({})
				_write_result("validate_all", result)
				_write_log("cli", "CLI validate_all", {"success": result.get("success", false)})


# --- Command Handlers ---

func _cmd_ping(_args: Dictionary) -> Dictionary:
	return {
		"success": true,
		"message": "pong",
		"data": {"timestamp": Time.get_unix_time_from_system()},
	}


func _cmd_screenshot(args: Dictionary) -> Dictionary:
	var default_name: String = "screenshot_%s.png" % Time.get_datetime_string_from_system().replace(":", "-")
	var filename: String = args.get("filename", default_name)
	var screenshots_dir: String = ProjectSettings.globalize_path("user://screenshots")
	DirAccess.make_dir_recursive_absolute(screenshots_dir)

	var abs_path: String = screenshots_dir.path_join(filename)
	var image: Image = get_viewport().get_texture().get_image()
	if image == null:
		return {"success": false, "message": "Failed to capture viewport image"}

	var err: Error = image.save_png(abs_path)
	if err != OK:
		return {"success": false, "message": "Failed to save PNG: error %d" % err}

	return {
		"success": true,
		"message": "Screenshot saved",
		"data": {
			"path": abs_path,
			"width": image.get_width(),
			"height": image.get_height(),
			"size_bytes": FileAccess.get_file_as_bytes(abs_path).size() if FileAccess.file_exists(abs_path) else -1,
		},
	}


func _cmd_scene_tree(args: Dictionary) -> Dictionary:
	var depth: int = args.get("depth", 10)
	var root: Node = get_tree().current_scene
	if root == null:
		return {"success": false, "message": "No current scene"}

	var tree_data: Dictionary = _serialize_node(root, depth)
	return {
		"success": true,
		"message": "Scene tree captured",
		"data": tree_data,
	}


func _serialize_node(node: Node, depth: int) -> Dictionary:
	var data: Dictionary = {
		"name": node.name,
		"type": node.get_class(),
		"path": str(node.get_path()),
	}

	if node is Node2D:
		var n2d: Node2D = node as Node2D
		data["position"] = {"x": n2d.position.x, "y": n2d.position.y}
		data["rotation"] = n2d.rotation
		data["visible"] = n2d.visible

	if node is Control:
		var ctrl: Control = node as Control
		data["position"] = {"x": ctrl.position.x, "y": ctrl.position.y}
		data["size"] = {"x": ctrl.size.x, "y": ctrl.size.y}
		data["visible"] = ctrl.visible

	if depth > 0 and node.get_child_count() > 0:
		var children: Array = []
		for child in node.get_children():
			children.append(_serialize_node(child, depth - 1))
		data["children"] = children

	return data


func _cmd_validate_scene(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	if path.is_empty():
		return {"success": false, "message": "No scene path provided"}

	var validator_script: GDScript = load("res://scripts/scene_validator.gd") as GDScript
	if validator_script == null:
		return {"success": false, "message": "SceneValidator script not found"}

	var issues: Array = validator_script.validate_scene(path)
	return {
		"success": issues.is_empty(),
		"message": "%d issues found" % issues.size() if not issues.is_empty() else "No issues found",
		"data": {"path": path, "issues": issues},
	}


func _cmd_validate_all(_args: Dictionary) -> Dictionary:
	var validator_script: GDScript = load("res://scripts/scene_validator.gd") as GDScript
	if validator_script == null:
		return {"success": false, "message": "SceneValidator script not found"}

	var scenes: Array[String] = _find_all_scenes("res://")
	var all_issues: Array = []
	var scene_results: Array = []

	for scene_path in scenes:
		var issues: Array = validator_script.validate_scene(scene_path)
		scene_results.append({
			"path": scene_path,
			"issues": issues,
			"valid": issues.is_empty(),
		})
		all_issues.append_array(issues)

	return {
		"success": all_issues.is_empty(),
		"message": "%d scenes validated, %d total issues" % [scenes.size(), all_issues.size()],
		"data": {
			"total_scenes": scenes.size(),
			"total_issues": all_issues.size(),
			"scenes": scene_results,
		},
	}


func _cmd_get_state(args: Dictionary) -> Dictionary:
	var node_path: String = args.get("node_path", "")
	if node_path.is_empty():
		return {"success": false, "message": "No node_path provided"}

	var node: Node = get_node_or_null(node_path)
	if node == null:
		return {"success": false, "message": "Node not found: %s" % node_path}

	var state: Dictionary = {}
	for prop in node.get_property_list():
		var usage: int = prop.get("usage", 0)
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE or usage & PROPERTY_USAGE_STORAGE:
			var prop_name: String = prop["name"]
			state[prop_name] = _serialize_variant(node.get(prop_name))

	return {
		"success": true,
		"message": "State retrieved for %s" % node_path,
		"data": state,
	}


func _cmd_set_state(args: Dictionary) -> Dictionary:
	var node_path: String = args.get("node_path", "")
	if node_path.is_empty():
		return {"success": false, "message": "No node_path provided"}

	var node: Node = get_node_or_null(node_path)
	if node == null:
		return {"success": false, "message": "Node not found: %s" % node_path}

	var property: String = args.get("property", "")
	if property.is_empty():
		return {"success": false, "message": "No property specified"}

	var value: Variant = args.get("value")
	node.set(property, value)

	return {
		"success": true,
		"message": "Set %s.%s" % [node_path, property],
		"data": {"property": property, "value": _serialize_variant(node.get(property))},
	}


func _cmd_run_method(args: Dictionary) -> Dictionary:
	var node_path: String = args.get("node_path", "")
	if node_path.is_empty():
		return {"success": false, "message": "No node_path provided"}

	var node: Node = get_node_or_null(node_path)
	if node == null:
		return {"success": false, "message": "Node not found: %s" % node_path}

	var method: String = args.get("method", "")
	if method.is_empty():
		return {"success": false, "message": "No method specified"}

	if not node.has_method(method):
		return {"success": false, "message": "Node %s has no method: %s" % [node_path, method]}

	var method_args: Array = args.get("args", [])
	var result: Variant = node.callv(method, method_args)

	return {
		"success": true,
		"message": "Called %s.%s()" % [node_path, method],
		"data": {"result": _serialize_variant(result)},
	}


func _cmd_performance(_args: Dictionary) -> Dictionary:
	var fps: float = Engine.get_frames_per_second()
	var data: Dictionary = {
		"fps": fps,
		"frame_time_ms": 1000.0 / maxf(1.0, fps),
		"physics_fps": Engine.physics_ticks_per_second,
		"static_memory_mb": OS.get_static_memory_usage() / (1024.0 * 1024.0),
		"video_memory_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / (1024.0 * 1024.0),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects": Performance.get_monitor(Performance.OBJECT_COUNT),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"orphan_nodes": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		"physics_2d_active_objects": Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS),
		"physics_3d_active_objects": Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS),
	}

	return {
		"success": true,
		"message": "Performance metrics collected",
		"data": data,
	}


func _cmd_quit(args: Dictionary) -> Dictionary:
	var exit_code: int = args.get("exit_code", 0)
	_write_log("system", "Quit requested", {"exit_code": exit_code})
	# Write result before quitting so the caller can read it.
	_write_result("quit", {"success": true, "message": "Quitting with code %d" % exit_code})
	get_tree().quit(exit_code)
	# Return value won't be used since we quit, but needed for type safety.
	return {"success": true, "message": "Quitting"}


# --- Input Simulation Handlers ---

func _cmd_input_press(args: Dictionary) -> Dictionary:
	var action: String = args.get("action", "")
	if action.is_empty():
		return {"success": false, "message": "No action specified"}

	if not InputMap.has_action(action):
		return {"success": false, "message": "Unknown input action: %s" % action}

	var strength: float = args.get("strength", 1.0)
	Input.action_press(action, strength)
	if action not in _active_simulated_inputs:
		_active_simulated_inputs.append(action)

	return {
		"success": true,
		"message": "Pressed: %s" % action,
		"data": {"action": action, "strength": strength, "active_inputs": _active_simulated_inputs.duplicate()},
	}


func _cmd_input_release(args: Dictionary) -> Dictionary:
	var action: String = args.get("action", "")
	if action.is_empty():
		return {"success": false, "message": "No action specified"}

	if not InputMap.has_action(action):
		return {"success": false, "message": "Unknown input action: %s" % action}

	Input.action_release(action)
	_active_simulated_inputs.erase(action)

	return {
		"success": true,
		"message": "Released: %s" % action,
		"data": {"action": action, "active_inputs": _active_simulated_inputs.duplicate()},
	}


func _cmd_input_tap(args: Dictionary) -> Dictionary:
	var action: String = args.get("action", "")
	if action.is_empty():
		return {"success": false, "message": "No action specified"}

	if not InputMap.has_action(action):
		return {"success": false, "message": "Unknown input action: %s" % action}

	var hold: float = args.get("seconds", args.get("hold", 0.0))
	var strength: float = args.get("strength", 1.0)

	Input.action_press(action, strength)
	_active_simulated_inputs.append(action)

	get_tree().create_timer(maxf(hold, 0.0)).timeout.connect(func() -> void:
		Input.action_release(action)
		_active_simulated_inputs.erase(action)
	)

	return {
		"success": true,
		"message": "Tapped: %s (hold %.2fs)" % [action, hold],
		"data": {"action": action, "hold": hold, "strength": strength},
	}


func _cmd_input_clear(_args: Dictionary) -> Dictionary:
	var cleared: Array[String] = _clear_all_simulated_inputs()
	return {
		"success": true,
		"message": "Cleared %d simulated inputs" % cleared.size(),
		"data": {"cleared": cleared},
	}


func _cmd_input_actions(args: Dictionary) -> Dictionary:
	var include_builtin: bool = args.get("include_builtin", false)
	var actions: Array = []

	for action in InputMap.get_actions():
		var action_str: String = str(action)
		if not include_builtin and action_str.begins_with("ui_"):
			continue

		var events: Array = []
		for event in InputMap.action_get_events(action_str):
			events.append(event.as_text())

		actions.append({
			"name": action_str,
			"events": events,
			"pressed": Input.is_action_pressed(action_str),
		})

	return {
		"success": true,
		"message": "%d actions found" % actions.size(),
		"data": {"actions": actions},
	}


func _cmd_input_sequence(args: Dictionary) -> Dictionary:
	var steps: Variant = args.get("steps", [])
	if not steps is Array or steps.is_empty():
		return {"success": false, "message": "No steps provided or steps is not an array"}

	var timeout: float = args.get("timeout", 30.0)
	var sequence_id: String = str(randi())

	# Validate all steps before executing.
	for i in steps.size():
		var step: Variant = steps[i]
		if not step is Dictionary:
			return {"success": false, "message": "Step %d is not a dictionary" % i}
		var step_dict: Dictionary = step
		var step_type: String = step_dict.get("type", "")
		if step_type.is_empty():
			return {"success": false, "message": "Step %d has no type" % i}
		if step_type not in ["press", "release", "tap", "hold", "wait", "wait_frames", "screenshot", "assert", "clear", "command"]:
			return {"success": false, "message": "Step %d has unknown type: %s" % [i, step_type]}
		# Validate action exists for input steps.
		if step_type in ["press", "release", "tap", "hold"]:
			var action: String = step_dict.get("action", "")
			if action.is_empty():
				return {"success": false, "message": "Step %d (%s) has no action" % [i, step_type]}
			if not InputMap.has_action(action):
				return {"success": false, "message": "Step %d: unknown action: %s" % [i, action]}

	# Launch the async sequence.
	_execute_sequence(sequence_id, steps as Array, timeout)

	return {
		"success": true,
		"message": "Sequence %s started with %d steps" % [sequence_id, steps.size()],
		"data": {"sequence_id": sequence_id, "step_count": steps.size()},
	}


func _execute_sequence(sequence_id: String, steps: Array, timeout: float) -> void:
	var start_time: float = Time.get_unix_time_from_system()

	for i in steps.size():
		if Time.get_unix_time_from_system() - start_time > timeout:
			_write_log("input", "Sequence %s timed out at step %d" % [sequence_id, i])
			return

		var step: Dictionary = steps[i]
		match step["type"]:
			"press":
				var action: String = step["action"]
				var strength: float = step.get("strength", 1.0)
				Input.action_press(action, strength)
				_active_simulated_inputs.append(action)

			"release":
				var action: String = step["action"]
				Input.action_release(action)
				_active_simulated_inputs.erase(action)

			"tap":
				var action: String = step["action"]
				var hold: float = step.get("seconds", step.get("hold", 0.0))
				var strength: float = step.get("strength", 1.0)
				Input.action_press(action, strength)
				_active_simulated_inputs.append(action)
				await get_tree().create_timer(maxf(hold, get_process_delta_time())).timeout
				Input.action_release(action)
				_active_simulated_inputs.erase(action)

			"hold":
				var action: String = step["action"]
				var strength: float = step.get("strength", 1.0)
				Input.action_press(action, strength)
				_active_simulated_inputs.append(action)
				await get_tree().create_timer(step["seconds"]).timeout
				Input.action_release(action)
				_active_simulated_inputs.erase(action)

			"wait":
				await get_tree().create_timer(step["seconds"]).timeout

			"screenshot":
				var filename: String = step.get("filename", "seq_%s_%d.png" % [sequence_id, i])
				_cmd_screenshot({"filename": filename})

			"assert":
				var target: Node = get_node_or_null(step["node"])
				if target == null:
					_write_log("input", "Sequence %s assert failed: node not found %s" % [sequence_id, step["node"]])
					return
				var actual: Variant = target.get(step["property"])
				var expected: Variant = step["equals"]
				var values_match: bool = false
				if typeof(actual) in [TYPE_INT, TYPE_FLOAT] and typeof(expected) in [TYPE_INT, TYPE_FLOAT]:
					values_match = is_equal_approx(float(actual), float(expected))
				else:
					values_match = str(actual) == str(expected)
				if not values_match:
					_write_log("input", "Sequence %s assert failed: %s.%s = %s, expected %s" % [
						sequence_id, step["node"], step["property"], str(actual), str(expected)
					])
					return

			"wait_frames":
				var count: int = step.get("count", 1)
				for _f: int in range(count):
					await get_tree().process_frame

			"command":
				var cmd_name: String = step.get("name", "")
				if cmd_name.is_empty():
					_write_log("input", "Sequence %s step %d: command has no name" % [sequence_id, i])
					return
				var cmd_args: Dictionary = {}
				for key: String in step:
					if key not in ["type", "name", "comment"]:
						cmd_args[key] = step[key]
				var handler: String = "_cmd_" + cmd_name.replace("-", "_")
				if has_method(handler):
					var result: Variant = call(handler, cmd_args)
					if result is Dictionary and result.get("status", "") == "error":
						_write_log("input", "Sequence %s step %d: command '%s' failed: %s" % [sequence_id, i, cmd_name, result.get("message", "")])
						return
				else:
					_write_log("input", "Sequence %s step %d: unknown command '%s'" % [sequence_id, i, cmd_name])
					return

			"clear":
				_clear_all_simulated_inputs()

	_write_log("input", "Sequence %s completed (%d steps)" % [sequence_id, steps.size()])


# --- Debug Command Handlers ---


func _cmd_spawn_coin(args: Dictionary) -> Dictionary:
	var type_str: String = args.get("type", args.get("coin_type", "SILVER")).to_upper()
	if not COIN_TYPE_MAP.has(type_str):
		return {"success": false, "message": "Unknown coin type: %s" % type_str}

	if get_tree().current_scene == null:
		return {"success": false, "message": "No current scene"}

	var coin_scene: PackedScene = load("res://scenes/coin.tscn")
	var coin: Area2D = coin_scene.instantiate()
	coin.coin_type = COIN_TYPE_MAP[type_str]

	var viewport_width := get_tree().root.size.x
	var x: float = args.get("x", randf_range(40.0, viewport_width - 40.0))
	var y: float = args.get("y", -50.0)
	coin.position = Vector2(x, y)

	get_tree().current_scene.add_child(coin)

	return {
		"success": true,
		"message": "Spawned %s coin at (%.0f, %.0f)" % [type_str, x, y],
		"data": {
			"type": type_str,
			"position": {"x": coin.position.x, "y": coin.position.y},
			"value": coin.value,
		},
	}


func _cmd_spawn_coin_on_catcher(args: Dictionary) -> Dictionary:
	var catchers := get_tree().get_nodes_in_group("catcher")
	if catchers.is_empty():
		return {"success": false, "message": "No catcher node found"}

	var catcher: Node2D = catchers[0]
	var type_str: String = args.get("type", args.get("coin_type", "SILVER")).to_upper()
	if not COIN_TYPE_MAP.has(type_str):
		return {"success": false, "message": "Unknown coin type: %s" % type_str}

	if get_tree().current_scene == null:
		return {"success": false, "message": "No current scene"}

	var coin_scene: PackedScene = load("res://scenes/coin.tscn")
	var coin: Area2D = coin_scene.instantiate()
	coin.coin_type = COIN_TYPE_MAP[type_str]
	coin.position = Vector2(catcher.position.x, catcher.position.y - 100)

	get_tree().current_scene.add_child(coin)

	return {
		"success": true,
		"message": "Spawned %s coin above catcher at (%.0f, %.0f)" % [type_str, coin.position.x, coin.position.y],
		"data": {
			"type": type_str,
			"position": {"x": coin.position.x, "y": coin.position.y},
			"value": coin.value,
		},
	}


func _cmd_get_active_coins(_args: Dictionary) -> Dictionary:
	var coins: Array = []
	for child in get_tree().current_scene.get_children():
		if child.has_method("collect"):
			var type_name: String = "SILVER"
			for key: String in COIN_TYPE_MAP:
				if COIN_TYPE_MAP[key] == child.coin_type:
					type_name = key
					break
			coins.append({
				"type": type_name,
				"position": {"x": child.position.x, "y": child.position.y},
				"value": child.value,
				"collected": child.get("_collected"),
			})

	return {
		"success": true,
		"message": "%d active coins" % coins.size(),
		"data": {"count": coins.size(), "coins": coins},
	}


func _cmd_clear_coins(_args: Dictionary) -> Dictionary:
	var cleared: int = 0
	for child in get_tree().current_scene.get_children():
		if child.has_method("collect"):
			child.queue_free()
			cleared += 1

	return {
		"success": true,
		"message": "Cleared %d coins" % cleared,
		"data": {"cleared": cleared},
	}


func _cmd_set_upgrade_levels(args: Dictionary) -> Dictionary:
	var warnings: Array = []
	for key: String in args:
		if GameManager.UPGRADE_DATA.has(key):
			GameManager._upgrade_levels[key] = maxi(0, int(args[key]))
			GameManager.upgrade_purchased.emit(key)
		else:
			warnings.append("Unknown upgrade key: %s" % key)

	var result: Dictionary = {
		"success": true,
		"message": "Upgrade levels updated",
		"data": {"levels": GameManager._upgrade_levels.duplicate()},
	}
	if not warnings.is_empty():
		result["data"]["warnings"] = warnings
	return result


func _cmd_reset_session(_args: Dictionary) -> Dictionary:
	var previous: Dictionary = {
		"currency": GameManager.currency,
		"upgrade_levels": GameManager._upgrade_levels.duplicate(),
		"ascension_count": GameManager.ascension_count,
		"combo_multiplier": GameManager._combo_multiplier,
	}

	GameManager.currency = 0
	for id: String in GameManager._upgrade_levels:
		GameManager._upgrade_levels[id] = 0
	GameManager.ascension_count = 0
	GameManager._combo_multiplier = 1.0
	GameManager._last_milestone = 0

	if GameManager.frenzy_active and GameManager._frenzy_timer != null:
		GameManager._frenzy_timer.stop()
		GameManager.frenzy_active = false
		GameManager.frenzy_ended.emit()

	GameManager.currency_changed.emit(0)
	GameManager.upgrade_purchased.emit("")
	GameManager.combo_multiplier_changed.emit(1.0)

	return {
		"success": true,
		"message": "Session reset to fresh state",
		"data": {"previous": previous},
	}


func _cmd_ascend(_args: Dictionary) -> Dictionary:
	var eligible: bool = GameManager.can_ascend()
	if not eligible:
		var levels: Dictionary = {}
		for id: String in GameManager.CORE_UPGRADES:
			levels[id] = GameManager.get_upgrade_level(id)
		return {
			"success": false,
			"message": "Cannot ascend — not all core upgrades at level %d" % GameManager.ASCEND_MIN_LEVEL,
			"data": {
				"eligible": false,
				"required_level": GameManager.ASCEND_MIN_LEVEL,
				"current_levels": levels,
			},
		}

	var prev_count: int = GameManager.ascension_count
	GameManager.try_ascend()
	return {
		"success": true,
		"message": "Ascended! Count: %d -> %d" % [prev_count, GameManager.ascension_count],
		"data": {
			"eligible": true,
			"ascension_count": GameManager.ascension_count,
			"multiplier": GameManager.get_ascension_multiplier(),
			"currency": GameManager.currency,
		},
	}


func _cmd_set_game_speed(args: Dictionary) -> Dictionary:
	var prev: float = Engine.time_scale
	var scale: float = clampf(float(args.get("scale", 1.0)), 0.0, 100.0)
	Engine.time_scale = scale

	return {
		"success": true,
		"message": "Game speed: %.1f -> %.1f" % [prev, scale],
		"data": {"previous_scale": prev, "current_scale": scale},
	}


func _cmd_wait_frames(args: Dictionary) -> Dictionary:
	var count: int = int(args.get("count", 1))
	var start_time := Time.get_ticks_msec()
	for i in range(count):
		await get_tree().process_frame
	var elapsed_ms := Time.get_ticks_msec() - start_time

	return {
		"success": true,
		"message": "Waited %d frames" % count,
		"data": {"frames": count, "elapsed_ms": elapsed_ms},
	}


func _cmd_get_catcher_state(_args: Dictionary) -> Dictionary:
	var catchers := get_tree().get_nodes_in_group("catcher")
	if catchers.is_empty():
		return {"success": false, "message": "No catcher node found"}

	var catcher: Node2D = catchers[0]

	return {
		"success": true,
		"message": "Catcher state retrieved",
		"data": {
			"position_x": catcher.position.x,
			"width": GameManager.get_catcher_width(),
			"speed": GameManager.get_catcher_speed(),
			"tier": catcher.get("_catcher_tier"),
			"combo": catcher.get("_combo"),
			"combo_multiplier": catcher.get("_combo_multiplier"),
			"bomb_shrink_active": catcher.get("_bomb_shrink_active"),
			"game_paused": catcher.get("_game_paused"),
		},
	}


# --- UI Validation Helpers ---


func _get_effective_alpha(node: Node) -> float:
	var alpha: float = 1.0
	var current: Node = node
	while current != null:
		if current is CanvasItem:
			alpha *= current.modulate.a * current.self_modulate.a
		if current is CanvasLayer:
			break
		current = current.get_parent()
	return alpha


func _is_effectively_visible(node: Node) -> bool:
	var current: Node = node
	while current != null:
		if current is CanvasItem and not current.visible:
			return false
		if current is CanvasLayer:
			break
		current = current.get_parent()
	return true


func _get_control_text(node: Control) -> String:
	if node is Label:
		return node.text
	if node is Button:
		return node.text
	if node is RichTextLabel:
		return node.get_parsed_text()
	return ""


# --- UI Validation Command Handlers ---


func _cmd_validate_ui(_args: Dictionary) -> Dictionary:
	var issues: Array = []
	var interactive_controls: Array = []
	var vp: Vector2 = Vector2(get_tree().root.size)
	_validate_ui_recursive(get_tree().current_scene, vp, issues, interactive_controls)

	# Check for overlapping interactive controls
	var overlaps: Array = _check_interactive_overlaps(interactive_controls)
	for overlap: Dictionary in overlaps:
		issues.append({
			"severity": "warning",
			"code": "interactive_overlap",
			"message": "Interactive controls overlap: '%s' and '%s' (overlap area: %.0fpx)" % [
				overlap["node_a"], overlap["node_b"], overlap["overlap_area"],
			],
		})

	return {
		"success": issues.is_empty(),
		"message": "%d UI issues found" % issues.size() if not issues.is_empty() else "No UI issues found",
		"data": {"issues": issues},
	}


func _validate_ui_recursive(node: Node, vp: Vector2, issues: Array, interactive_controls: Array = []) -> void:
	if node is Control and _is_effectively_visible(node):
		var control: Control = node as Control
		var rect: Rect2 = control.get_global_rect()

		# Collect interactive controls for overlap detection
		if (control is Button or control is TextureButton or control is LinkButton) and control.visible:
			interactive_controls.append({"path": str(control.get_path()), "rect": rect})

		# Check 1: Viewport overflow
		if rect.position.x + rect.size.x > vp.x or rect.position.y + rect.size.y > vp.y:
			issues.append({
				"severity": "warning",
				"code": "ui_overflow",
				"message": "%s '%s' extends past viewport (rect: %.0f,%.0f -> %.0f,%.0f, viewport: %.0fx%.0f)" % [
					control.get_class(), control.name,
					rect.position.x, rect.position.y,
					rect.position.x + rect.size.x, rect.position.y + rect.size.y,
					vp.x, vp.y,
				],
			})

		# Check 2: Zero-size visible
		if control.size.x == 0.0 or control.size.y == 0.0:
			issues.append({
				"severity": "warning",
				"code": "ui_zero_size",
				"message": "%s '%s' is visible but has zero size (%.0fx%.0f)" % [
					control.get_class(), control.name, control.size.x, control.size.y,
				],
			})

		# Check 3: Fully transparent
		var effective_alpha: float = _get_effective_alpha(control)
		if effective_alpha == 0.0:
			issues.append({
				"severity": "info",
				"code": "ui_transparent",
				"message": "%s '%s' is visible but fully transparent (effective alpha: %.2f)" % [
					control.get_class(), control.name, effective_alpha,
				],
			})

		# Check 4: Text overflow (Label only, autowrap disabled)
		if control is Label and control.autowrap_mode == TextServer.AUTOWRAP_OFF:
			var font: Font = control.get_theme_font("font")
			if font != null:
				var font_size: int = control.get_theme_font_size("font_size")
				if font_size <= 0:
					font_size = control.get_theme_default_font_size()
				var text_width: float = font.get_string_size(control.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
				if text_width > control.size.x and control.size.x > 0.0:
					var display_text: String = control.text
					if display_text.length() > 50:
						display_text = display_text.substr(0, 47) + "..."
					issues.append({
						"severity": "warning",
						"code": "ui_text_overflow",
						"message": "%s '%s' text '%s' exceeds width (text: %.0fpx, label: %.0fpx)" % [
							control.get_class(), control.name, display_text, text_width, control.size.x,
						],
					})

		# Check 5: Negative position
		if rect.position.x < 0.0 or rect.position.y < 0.0:
			issues.append({
				"severity": "warning",
				"code": "ui_negative_pos",
				"message": "%s '%s' has negative position (%.0f, %.0f)" % [
					control.get_class(), control.name, rect.position.x, rect.position.y,
				],
			})

		# Check 6: Button text overflow
		if control is Button and control.text.length() > 0:
			var btn_font: Font = control.get_theme_font("font")
			var btn_font_size: int = control.get_theme_font_size("font_size")
			if btn_font:
				var btn_text_width: float = btn_font.get_string_size(control.text, HORIZONTAL_ALIGNMENT_LEFT, -1, btn_font_size).x
				var padding: float = 16.0
				if btn_text_width + padding > control.size.x and control.size.x > 0.0:
					issues.append({
						"severity": "warning",
						"code": "button_text_overflow",
						"message": "Button '%s' text '%s' (%.0fpx) exceeds button width (%.0fpx)" % [
							control.name, control.text, btn_text_width, control.size.x,
						],
					})

		# Check 7: Minimum tap target size for interactive controls
		if (control is Button or control is TextureButton or control is LinkButton) and control.visible:
			var min_tap: float = 40.0
			if control.size.x < min_tap or control.size.y < min_tap:
				issues.append({
					"severity": "warning",
					"code": "small_tap_target",
					"message": "Interactive control '%s' size %.0fx%.0f below minimum %.0fx%.0f" % [
						control.name, control.size.x, control.size.y, min_tap, min_tap,
					],
				})

		# Check 8: Container child position consistency
		# If a node is inside a BoxContainer (HBox/VBox) with layout_mode 2,
		# its position should be within the container's bounds
		if node.get_parent() is BoxContainer:
			var parent_container: BoxContainer = node.get_parent() as BoxContainer
			var parent_rect: Rect2 = parent_container.get_global_rect()
			var node_rect: Rect2 = control.get_global_rect()
			var path: String = str(control.get_path())
			# Check if child extends beyond parent bounds (layout corruption)
			if node_rect.position.x < parent_rect.position.x - 2.0:
				issues.append({
					"severity": "warning",
					"code": "container_layout_drift",
					"message": "Node '%s' position (%.0f) is left of parent container (%.0f) - possible layout corruption" % [
						path, node_rect.position.x, parent_rect.position.x,
					],
				})
			if node_rect.end.x > parent_rect.end.x + 2.0:
				issues.append({
					"severity": "warning",
					"code": "container_layout_drift",
					"message": "Node '%s' extends past parent container right edge (%.0f > %.0f) - possible layout corruption" % [
						path, node_rect.end.x, parent_rect.end.x,
					],
				})

	for child in node.get_children():
		_validate_ui_recursive(child, vp, issues, interactive_controls)


func _cmd_get_ui_snapshot(_args: Dictionary) -> Dictionary:
	var vp: Vector2 = Vector2(get_tree().root.size)
	var elements: Array = []
	_snapshot_ui_recursive(get_tree().current_scene, vp, elements)

	return {
		"success": true,
		"message": "%d UI elements captured" % elements.size(),
		"data": {
			"viewport": {"width": int(vp.x), "height": int(vp.y)},
			"elements": elements,
		},
	}


func _snapshot_ui_recursive(node: Node, vp: Vector2, elements: Array) -> void:
	if node is Control:
		var control: Control = node as Control
		var eff_visible: bool = _is_effectively_visible(control)
		var eff_alpha: float = _get_effective_alpha(control)

		if eff_visible or eff_alpha > 0.0:
			var rect: Rect2 = control.get_global_rect()
			elements.append({
				"name": str(control.name),
				"type": control.get_class(),
				"path": str(control.get_path()),
				"global_rect": {
					"x": rect.position.x,
					"y": rect.position.y,
					"w": rect.size.x,
					"h": rect.size.y,
				},
				"visible": eff_visible,
				"modulate_a": eff_alpha,
				"text": _get_control_text(control),
				"in_viewport": rect.position.x >= 0.0 and rect.position.y >= 0.0
					and rect.position.x + rect.size.x <= vp.x
					and rect.position.y + rect.size.y <= vp.y,
			})

	for child in node.get_children():
		_snapshot_ui_recursive(child, vp, elements)


func _cmd_get_node_bounds(args: Dictionary) -> Dictionary:
	var node_path: String = args.get("node_path", "")
	if node_path.is_empty():
		return {"success": false, "message": "No node_path provided"}

	var node: Node = get_node_or_null(node_path)
	if node == null:
		return {"success": false, "message": "Node not found: %s" % node_path}

	if not node is Control:
		return {"success": false, "message": "Node is not a Control: %s" % node_path}

	var control: Control = node as Control
	var vp: Vector2 = Vector2(get_tree().root.size)
	var rect: Rect2 = control.get_global_rect()

	return {
		"success": true,
		"message": "Bounds for %s" % control.name,
		"data": {
			"name": str(control.name),
			"type": control.get_class(),
			"path": str(control.get_path()),
			"global_rect": {
				"x": rect.position.x,
				"y": rect.position.y,
				"w": rect.size.x,
				"h": rect.size.y,
			},
			"visible": _is_effectively_visible(control),
			"modulate_a": _get_effective_alpha(control),
			"text": _get_control_text(control),
			"in_viewport": rect.position.x >= 0.0 and rect.position.y >= 0.0
				and rect.position.x + rect.size.x <= vp.x
				and rect.position.y + rect.size.y <= vp.y,
		},
	}


# --- Interactive UI Validation ---


func _cmd_validate_ui_interactive(_args: Dictionary) -> Dictionary:
	var results: Array = []
	var errors: Array = []

	# Step 1: Find HUD and shop toggle
	var hud: Node = _find_hud_node()
	if not hud:
		return {"success": false, "message": "HUD not found"}

	var shop_toggle: Button = hud.get_node_or_null("%ShopToggle")
	if not shop_toggle:
		return {"success": false, "message": "ShopToggle not found"}

	# Record pre-state
	var pre_currency: int = GameManager.currency

	# Open shop
	shop_toggle.pressed.emit()
	await get_tree().create_timer(0.5).timeout

	# Verify shop opened
	var upgrade_panel: PanelContainer = hud.get_node_or_null("%UpgradePanel")
	if upgrade_panel and upgrade_panel.visible:
		results.append({"check": "shop_opens", "status": "pass"})
	else:
		errors.append({"check": "shop_opens", "status": "fail", "message": "Panel not visible after toggle"})

	# Check button bounds
	var upgrade_container: VBoxContainer = hud.get_node_or_null("%UpgradeContainer")
	if upgrade_container:
		for child in upgrade_container.get_children():
			if child is PanelContainer:
				var rect: Rect2 = child.get_global_rect()
				if rect.size.x < 44.0 or rect.size.y < 44.0:
					errors.append({"check": "min_tap_target", "status": "fail", "node": str(child.name), "size": [rect.size.x, rect.size.y]})
				# Check button text fits
				var buy_btn: Button = child.get_node_or_null("%BuyButton")
				if buy_btn:
					var font: Font = buy_btn.get_theme_font("font")
					var font_size: int = buy_btn.get_theme_font_size("font_size")
					if font:
						var text_width: float = font.get_string_size(buy_btn.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
						if text_width > buy_btn.size.x:
							errors.append({"check": "button_text_overflow", "status": "fail", "node": str(buy_btn.name), "text": buy_btn.text, "text_width": text_width, "button_width": buy_btn.size.x})
		results.append({"check": "button_bounds", "status": "pass" if errors.size() == 0 else "fail"})

	# Give currency and attempt purchase
	GameManager.add_currency(10000)
	await get_tree().process_frame
	var post_add_currency: int = GameManager.currency

	# Try purchase
	var purchased: bool = GameManager.try_purchase_upgrade("spawn_rate")
	await get_tree().create_timer(0.3).timeout

	if purchased:
		var post_purchase_currency: int = GameManager.currency
		if post_purchase_currency < post_add_currency:
			results.append({"check": "purchase_deducts_currency", "status": "pass"})
		else:
			errors.append({"check": "purchase_deducts_currency", "status": "fail", "message": "Currency did not decrease after purchase"})

		# Check button text updated (cost should have changed)
		if upgrade_container:
			for child in upgrade_container.get_children():
				if child is PanelContainer and child.has_method("setup"):
					var buy_btn: Button = child.get_node_or_null("%BuyButton")
					if buy_btn and buy_btn.text.length() > 0:
						results.append({"check": "button_text_updated", "status": "pass", "text": buy_btn.text})
						break

		# Check for layout corruption after purchase animation
		var post_purchase_ui: Dictionary = _cmd_validate_ui({})
		var layout_drift_issues: Array = []
		for issue: Dictionary in post_purchase_ui.get("data", {}).get("issues", []):
			if issue.get("code", "") == "container_layout_drift":
				layout_drift_issues.append(issue)
		if layout_drift_issues.is_empty():
			results.append({"check": "post_purchase_layout", "status": "pass"})
		else:
			for drift_issue: Dictionary in layout_drift_issues:
				errors.append({"check": "post_purchase_layout", "status": "fail", "message": drift_issue.get("message", "Layout drift detected")})
	else:
		errors.append({"check": "purchase_attempt", "status": "fail", "message": "Purchase failed despite adding currency"})

	# Close shop
	shop_toggle.pressed.emit()
	await get_tree().create_timer(0.5).timeout

	# Verify shop closed
	if upgrade_panel and not upgrade_panel.visible:
		results.append({"check": "shop_closes", "status": "pass"})
	else:
		errors.append({"check": "shop_closes", "status": "fail", "message": "Panel still visible after toggle"})

	return {
		"success": errors.size() == 0,
		"message": "%d checks passed, %d failed" % [results.size(), errors.size()],
		"data": {
			"status": "pass" if errors.size() == 0 else "fail",
			"results": results,
			"errors": errors,
			"checks_run": results.size() + errors.size(),
		},
	}


func _find_hud_node() -> Node:
	var scene: Node = get_tree().current_scene
	if not scene:
		return null
	for child in scene.get_children():
		if child is CanvasLayer and child.name == "HUD":
			return child
	# Also check autoloads / root children
	for child in get_tree().root.get_children():
		if child is CanvasLayer and child.name == "HUD":
			return child
	return null


# --- UI Baseline & Diff ---


func _cmd_save_ui_baseline(_args: Dictionary) -> Dictionary:
	var snapshot: Array = _capture_ui_snapshot_flat()
	var json_str: String = JSON.stringify(snapshot, "\t")
	var file: FileAccess = FileAccess.open("user://ui_baseline.json", FileAccess.WRITE)
	if file == null:
		return {"success": false, "message": "Failed to write baseline file"}
	file.store_string(json_str)
	file.close()
	return {
		"success": true,
		"message": "Baseline saved with %d nodes" % snapshot.size(),
		"data": {"nodes_saved": snapshot.size()},
	}


func _cmd_ui_snapshot_diff(_args: Dictionary) -> Dictionary:
	if not FileAccess.file_exists("user://ui_baseline.json"):
		return {"success": false, "message": "No baseline found. Run save_ui_baseline first."}

	var file: FileAccess = FileAccess.open("user://ui_baseline.json", FileAccess.READ)
	var baseline_text: String = file.get_as_text()
	file.close()
	var baseline: Variant = JSON.parse_string(baseline_text)
	if baseline == null or not baseline is Array:
		return {"success": false, "message": "Failed to parse baseline JSON"}

	var current: Array = _capture_ui_snapshot_flat()
	var diffs: Array = []
	var threshold: float = 5.0

	# Build lookup by node path
	var baseline_map: Dictionary = {}
	for node_data: Dictionary in baseline:
		baseline_map[node_data["path"]] = node_data

	for node_data: Dictionary in current:
		var path: String = node_data["path"]
		if baseline_map.has(path):
			var base: Dictionary = baseline_map[path]
			var dx: float = absf(node_data["x"] - base["x"])
			var dy: float = absf(node_data["y"] - base["y"])
			var dw: float = absf(node_data["w"] - base["w"])
			var dh: float = absf(node_data["h"] - base["h"])
			if dx > threshold or dy > threshold or dw > threshold or dh > threshold:
				diffs.append({
					"path": path,
					"type": "changed",
					"position_delta": [dx, dy],
					"size_delta": [dw, dh],
					"baseline": {"x": base["x"], "y": base["y"], "w": base["w"], "h": base["h"]},
					"current": {"x": node_data["x"], "y": node_data["y"], "w": node_data["w"], "h": node_data["h"]},
				})
		else:
			diffs.append({"path": path, "type": "new_node"})

	for path: String in baseline_map:
		var found: bool = false
		for node_data: Dictionary in current:
			if node_data["path"] == path:
				found = true
				break
		if not found:
			diffs.append({"path": path, "type": "removed_node"})

	return {
		"success": diffs.size() == 0,
		"message": "%d diffs found" % diffs.size() if diffs.size() > 0 else "No layout drift detected",
		"data": {
			"status": "pass" if diffs.size() == 0 else "drift_detected",
			"diffs": diffs,
		},
	}


func _capture_ui_snapshot_flat() -> Array:
	var elements: Array = []
	var scene: Node = get_tree().current_scene
	if scene:
		_snapshot_flat_recursive(scene, elements)
	return elements


func _snapshot_flat_recursive(node: Node, elements: Array) -> void:
	if node is Control and _is_effectively_visible(node):
		var control: Control = node as Control
		var rect: Rect2 = control.get_global_rect()
		elements.append({
			"path": str(control.get_path()),
			"name": str(control.name),
			"type": control.get_class(),
			"x": rect.position.x,
			"y": rect.position.y,
			"w": rect.size.x,
			"h": rect.size.y,
		})
	for child in node.get_children():
		_snapshot_flat_recursive(child, elements)


# --- UI Overlap Detection ---


func _check_interactive_overlaps(controls: Array) -> Array:
	var overlaps: Array = []
	for i in range(controls.size()):
		for j in range(i + 1, controls.size()):
			var rect_a: Rect2 = controls[i]["rect"]
			var rect_b: Rect2 = controls[j]["rect"]
			if rect_a.intersects(rect_b):
				var intersection: Rect2 = rect_a.intersection(rect_b)
				overlaps.append({
					"type": "interactive_overlap",
					"node_a": controls[i]["path"],
					"node_b": controls[j]["path"],
					"overlap_area": intersection.get_area(),
					"overlap_rect": {"x": intersection.position.x, "y": intersection.position.y, "w": intersection.size.x, "h": intersection.size.y},
				})
	return overlaps


# --- Utility Functions ---

func _serialize_variant(value: Variant) -> Variant:
	match typeof(value):
		TYPE_NIL:
			return null
		TYPE_BOOL:
			return value
		TYPE_INT:
			return value
		TYPE_FLOAT:
			return value
		TYPE_STRING:
			return value
		TYPE_VECTOR2:
			return {"x": value.x, "y": value.y}
		TYPE_VECTOR3:
			return {"x": value.x, "y": value.y, "z": value.z}
		TYPE_COLOR:
			return {"r": value.r, "g": value.g, "b": value.b, "a": value.a}
		TYPE_RECT2:
			return {"x": value.position.x, "y": value.position.y, "w": value.size.x, "h": value.size.y}
		TYPE_DICTIONARY:
			var result: Dictionary = {}
			for key in value:
				result[str(key)] = _serialize_variant(value[key])
			return result
		TYPE_ARRAY:
			var result: Array = []
			for item in value:
				result.append(_serialize_variant(item))
			return result
		_:
			return str(value)


func _write_log(category: String, message: String, data: Variant = null) -> void:
	var entry: Dictionary = {
		"timestamp": Time.get_unix_time_from_system(),
		"frame": Engine.get_process_frames(),
		"category": category,
		"message": message,
	}
	if data != null:
		entry["data"] = data

	var file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
	if file == null:
		# File may not exist yet; create it.
		file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(JSON.stringify(entry))
	file.close()


func _find_all_scenes(path: String) -> Array[String]:
	var scenes: Array[String] = []
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return scenes

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name == ".godot" or file_name.begins_with("."):
			file_name = dir.get_next()
			continue

		var full_path: String = path.path_join(file_name)
		if dir.current_is_dir():
			scenes.append_array(_find_all_scenes(full_path))
		elif file_name.ends_with(".tscn") or file_name.ends_with(".scn"):
			scenes.append(full_path)

		file_name = dir.get_next()
	dir.list_dir_end()

	return scenes


func _clear_all_simulated_inputs() -> Array[String]:
	var cleared: Array[String] = _active_simulated_inputs.duplicate()
	for action in cleared:
		Input.action_release(action)
	_active_simulated_inputs.clear()
	return cleared


func _clear_stale_files() -> void:
	if FileAccess.file_exists(COMMANDS_PATH):
		DirAccess.remove_absolute(_commands_abs_path)
	if FileAccess.file_exists(RESULTS_PATH):
		DirAccess.remove_absolute(_results_abs_path)
