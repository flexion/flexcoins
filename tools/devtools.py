#!/usr/bin/env python3
"""
devtools.py - CLI for interacting with running Godot instance via DevTools autoload.

Commands send JSON to user://devtools_commands.json and read results from
user://devtools_results.json. The DevTools autoload polls for commands.

Usage:
    python3 tools/devtools.py ping                     # Check if game is running
    python3 tools/devtools.py screenshot               # Capture screenshot
    python3 tools/devtools.py validate-all             # Validate all scenes
    python3 tools/devtools.py scene-tree               # Get node hierarchy
    python3 tools/devtools.py performance              # Get FPS, memory, etc.
    python3 tools/devtools.py get-state --node "/root/GameManager"
    python3 tools/devtools.py set-state --node "/root/GameManager" --property currency --value 10000
    python3 tools/devtools.py quit

Environment:
    Set project path via --project or run from project root.
"""

import argparse
import json
import os
import sys
import time
from pathlib import Path
from typing import Optional  # noqa: F401


COMMANDS_FILE = "devtools_commands.json"
RESULTS_FILE = "devtools_results.json"
LOG_FILE = "devtools_log.jsonl"


def get_user_data_path(project_path: Path) -> Path:
    """Get the user:// directory for the Godot project."""
    project_file = project_path / "project.godot"
    if not project_file.exists():
        raise FileNotFoundError(f"No project.godot found in {project_path}")

    project_name = None
    with open(project_file, encoding="utf-8") as f:
        for line in f:
            if line.startswith("config/name="):
                project_name = line.split("=", 1)[1].strip().strip('"')
                break

    if not project_name:
        project_name = project_path.name

    # Platform-specific user data location
    if sys.platform == "win32":
        base = Path(os.environ.get("APPDATA", ""))
        return base / "Godot" / "app_userdata" / project_name
    elif sys.platform == "darwin":
        return Path.home() / "Library" / "Application Support" / "Godot" / "app_userdata" / project_name
    else:  # Linux
        return Path.home() / ".local" / "share" / "godot" / "app_userdata" / project_name


def send_command(project_path: Path, action: str, args: dict = None, timeout: float = 30.0) -> dict:
    """Send a command to the running Godot instance and wait for result."""
    user_data = get_user_data_path(project_path)
    user_data.mkdir(parents=True, exist_ok=True)

    commands_path = user_data / COMMANDS_FILE
    results_path = user_data / RESULTS_FILE

    # Clear any existing result
    if results_path.exists():
        results_path.unlink()

    # Write command
    command = {"action": action, "args": args or {}}
    commands_path.write_text(json.dumps(command), encoding="utf-8")

    # Wait for result
    start_time = time.time()
    while time.time() - start_time < timeout:
        if results_path.exists():
            try:
                result = json.loads(results_path.read_text(encoding="utf-8"))
                results_path.unlink()
                return result
            except json.JSONDecodeError:
                pass
        time.sleep(0.1)

    raise TimeoutError(f"No response from Godot after {timeout}s. Is the game running with DevTools?")


def cmd_screenshot(args, project_path: Path):
    """Take a screenshot of the running game."""
    result = send_command(project_path, "screenshot", {"filename": args.filename} if args.filename else {})
    if result["success"]:
        print(f"Screenshot saved: {result['data']['path']}")
        print(f"Size: {result['data']['width']}x{result['data']['height']}")
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)


def cmd_validate(args, project_path: Path):
    """Validate a specific scene."""
    if not args.scene:
        print("Error: --scene is required", file=sys.stderr)
        sys.exit(1)
    result = send_command(project_path, "validate_scene", {"path": args.scene})
    print_validation_result(result)


def cmd_validate_all(args, project_path: Path):
    """Validate all scenes in the project."""
    result = send_command(project_path, "validate_all", timeout=60.0)
    print_validation_result(result)


def print_validation_result(result: dict):
    """Pretty-print validation results."""
    if result["success"]:
        print("[OK] " + result["message"])
    else:
        print("[FAIL] " + result["message"])

    data = result.get("data", {})

    # Handle validate_all response: data.scenes is an array of {path, issues, valid}
    scenes = data.get("scenes", [])
    if scenes:
        for scene in scenes:
            if scene.get("issues"):
                print(f"\n{scene['path']}:")
                for issue in scene["issues"]:
                    severity = {"error": "ERROR", "warning": "WARN", "info": "INFO"}.get(issue["severity"], "???")
                    print(f"  [{severity}] {issue['code']}: {issue['message']}")
    else:
        # Handle single scene validate response: data.issues is a list
        issues = data.get("issues", [])
        if isinstance(issues, list):
            for issue in issues:
                severity = {"error": "ERROR", "warning": "WARN", "info": "INFO"}.get(issue["severity"], "???")
                print(f"  [{severity}] {issue['code']}: {issue['message']}")

    if not result["success"]:
        sys.exit(1)


def cmd_scene_tree(args, project_path: Path):
    """Get the current scene tree."""
    result = send_command(project_path, "scene_tree", {"depth": args.depth})
    if result["success"]:
        print(json.dumps(result["data"], indent=2))
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)


def cmd_performance(args, project_path: Path):
    """Get performance metrics."""
    result = send_command(project_path, "performance")
    if result["success"]:
        data = result["data"]
        print(f"FPS:              {data['fps']:.1f}")
        print(f"Frame time:       {data['frame_time_ms']:.2f} ms")
        print(f"Physics FPS:      {int(data['physics_fps'])}")
        print(f"Draw calls:       {int(data['draw_calls'])}")
        print(f"Objects:          {int(data['objects'])}")
        print(f"Static memory:    {data['static_memory_mb']:.1f} MB")
        print(f"Video memory:     {data['video_memory_mb']:.1f} MB")
        print(f"Total nodes:      {int(data['nodes'])}")
        print(f"Orphan nodes:     {int(data['orphan_nodes'])}")
        print(f"Physics 2D objs:  {int(data['physics_2d_active_objects'])}")
        print(f"Physics 3D objs:  {int(data['physics_3d_active_objects'])}")
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)


def cmd_get_state(args, project_path: Path):
    """Get node state."""
    result = send_command(project_path, "get_state", {"node_path": args.node} if args.node else {})
    if result["success"]:
        print(json.dumps(result["data"], indent=2))
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)


def cmd_set_state(args, project_path: Path):
    """Set a node property."""
    value = args.value
    try:
        value = json.loads(args.value)
    except json.JSONDecodeError:
        try:
            value = int(args.value)
        except ValueError:
            try:
                value = float(args.value)
            except ValueError:
                pass

    result = send_command(project_path, "set_state", {
        "node_path": args.node,
        "property": args.property,
        "value": value
    })
    if result["success"]:
        print("State updated")
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)


def cmd_run_method(args, project_path: Path):
    """Call a method on a node."""
    method_args = []
    if args.args:
        try:
            method_args = json.loads(args.args)
            if not isinstance(method_args, list):
                print("Error: --args must be a JSON array, e.g., '[25, \"name\"]'", file=sys.stderr)
                sys.exit(1)
        except json.JSONDecodeError as e:
            print(f"Error: Invalid JSON in --args: {e}", file=sys.stderr)
            sys.exit(1)

    result = send_command(project_path, "run_method", {
        "node_path": args.node,
        "method": args.method,
        "args": method_args
    })
    if result["success"]:
        print(f"Result: {result['data'].get('result')}")
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)


def cmd_logs(args, project_path: Path):
    """View DevTools logs."""
    user_data = get_user_data_path(project_path)
    log_path = user_data / LOG_FILE

    if not log_path.exists():
        print("No logs found")
        return

    lines = log_path.read_text(encoding="utf-8").strip().split("\n")

    if args.category:
        lines = [l for l in lines if f'"category":"{args.category}"' in l or f'"category": "{args.category}"' in l]

    if args.tail:
        lines = lines[-args.tail:]

    for line in lines:
        try:
            entry = json.loads(line)
            ts = time.strftime("%H:%M:%S", time.localtime(entry["timestamp"]))
            cat = entry["category"]
            msg = entry["message"]
            print(f"[{ts}] [{cat}] {msg}")
        except json.JSONDecodeError:
            print(line)


def cmd_ping(args, project_path: Path):
    """Check if Godot DevTools is responding."""
    try:
        result = send_command(project_path, "ping", timeout=5.0)
        if result["success"]:
            print(f"DevTools is running (timestamp: {result['data']['timestamp']:.0f})")
        else:
            print("DevTools responded but with error")
            sys.exit(1)
    except TimeoutError:
        print("No response - is the game running with DevTools autoload?")
        sys.exit(1)


def cmd_quit(args, project_path: Path):
    """Quit the running Godot instance."""
    try:
        send_command(project_path, "quit", {"exit_code": args.exit_code or 0}, timeout=5.0)
        print("Quit command sent")
    except TimeoutError:
        print("Quit command sent (no response expected)")


# ==================== INPUT SIMULATION ====================


def cmd_input_press(args, project_path: Path):
    """Press and hold an input action."""
    cmd_args = {"action": args.action}
    if args.strength is not None:
        cmd_args["strength"] = args.strength

    result = send_command(project_path, "input_press", cmd_args)
    if result["success"]:
        print(f"Pressed: {args.action}")
        if result.get("data", {}).get("active_inputs"):
            print(f"Active inputs: {', '.join(result['data']['active_inputs'])}")
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)


def cmd_input_release(args, project_path: Path):
    """Release an input action."""
    result = send_command(project_path, "input_release", {"action": args.action})
    if result["success"]:
        print(f"Released: {args.action}")
        if result.get("data", {}).get("active_inputs"):
            print(f"Active inputs: {', '.join(result['data']['active_inputs'])}")
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)


def cmd_input_tap(args, project_path: Path):
    """Tap (press and release) an input action."""
    cmd_args = {"action": args.action}
    if args.hold:
        cmd_args["seconds"] = args.hold
    if args.strength is not None:
        cmd_args["strength"] = args.strength

    result = send_command(project_path, "input_tap", cmd_args)
    if result["success"]:
        hold_info = f" (hold: {args.hold}s)" if args.hold else ""
        print(f"Tapped: {args.action}{hold_info}")
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)


def cmd_input_clear(args, project_path: Path):
    """Release all simulated inputs."""
    result = send_command(project_path, "input_clear")
    if result["success"]:
        cleared = result.get("data", {}).get("cleared", [])
        if cleared:
            print(f"Cleared {len(cleared)} inputs: {', '.join(cleared)}")
        else:
            print("No active inputs to clear")
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)


def cmd_input_list(args, project_path: Path):
    """List available input actions."""
    cmd_args = {"include_builtin": args.all}
    result = send_command(project_path, "input_actions", cmd_args)
    if result["success"]:
        actions = result.get("data", {}).get("actions", [])
        if not actions:
            print("No actions found")
            return

        print(f"Available actions ({len(actions)}):")
        for action in actions:
            pressed = " [PRESSED]" if action.get("pressed") else ""
            events = ", ".join(action.get("events", [])) or "(no keys)"
            print(f"  {action['name']}{pressed}: {events}")
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)


def cmd_input_sequence(args, project_path: Path):
    """Execute an input sequence from a JSON file."""
    seq_path = Path(args.file)
    if not seq_path.exists():
        print(f"Error: Sequence file not found: {args.file}", file=sys.stderr)
        sys.exit(1)

    try:
        with open(seq_path, encoding="utf-8") as f:
            seq_data = json.load(f)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in sequence file: {e}", file=sys.stderr)
        sys.exit(1)

    steps = seq_data.get("steps", [])
    if not steps:
        print("Error: Sequence has no steps", file=sys.stderr)
        sys.exit(1)

    description = seq_data.get("description", "")
    if description:
        print(f"Running sequence: {description}")
    print(f"Executing {len(steps)} steps...")

    cmd_args = {"steps": steps}
    if args.timeout:
        cmd_args["timeout"] = args.timeout

    result = send_command(project_path, "input_sequence", cmd_args, timeout=args.timeout + 10 if args.timeout else 70)
    if result["success"]:
        print(f"Sequence started: {result.get('data', {}).get('sequence_id', 'unknown')}")
        print("Note: Sequence runs asynchronously. Check logs for completion.")
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)


# ==================== DEBUG COMMANDS ====================


def cmd_spawn_coin(args, project_path: Path):
    """Spawn a coin at a specific position."""
    cmd_args = {"type": args.type}
    if args.x is not None:
        cmd_args["x"] = args.x
    if args.y is not None:
        cmd_args["y"] = args.y

    result = send_command(project_path, "spawn_coin", cmd_args)
    if result["success"]:
        data = result["data"]
        print(f"Spawned {data['type']} coin at ({data['position']['x']:.0f}, {data['position']['y']:.0f}), value={data['value']}")
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)


def cmd_spawn_coin_on_catcher(args, project_path: Path):
    """Spawn a coin directly above the catcher."""
    cmd_args = {"type": args.type}

    result = send_command(project_path, "spawn_coin_on_catcher", cmd_args)
    if result["success"]:
        data = result["data"]
        print(f"Spawned {data['type']} coin above catcher at ({data['position']['x']:.0f}, {data['position']['y']:.0f}), value={data['value']}")
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)


def cmd_get_active_coins(args, project_path: Path):
    """List all active coins in the scene."""
    result = send_command(project_path, "get_active_coins")
    if result["success"]:
        data = result["data"]
        print(f"Active coins: {data['count']}")
        for coin in data.get("coins", []):
            print(f"  {coin['type']} at ({coin['position']['x']:.0f}, {coin['position']['y']:.0f}) value={coin['value']} collected={coin['collected']}")
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)


def cmd_clear_coins(args, project_path: Path):
    """Remove all active coins."""
    result = send_command(project_path, "clear_coins")
    if result["success"]:
        print(f"Cleared {result['data']['cleared']} coins")
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)


def cmd_set_upgrade_levels(args, project_path: Path):
    """Bulk-set upgrade levels."""
    cmd_args = {}
    for key in ["spawn_rate", "coin_value", "catcher_speed", "catcher_width", "magnet"]:
        val = getattr(args, key, None)
        if val is not None:
            cmd_args[key] = val

    if not cmd_args:
        print("Error: Specify at least one upgrade level", file=sys.stderr)
        sys.exit(1)

    result = send_command(project_path, "set_upgrade_levels", cmd_args)
    if result["success"]:
        data = result["data"]
        print("Upgrade levels:")
        for key, level in data["levels"].items():
            print(f"  {key}: {level}")
        for warn in data.get("warnings", []):
            print(f"  WARNING: {warn}")
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)


def cmd_reset_session(args, project_path: Path):
    """Reset game to fresh state."""
    result = send_command(project_path, "reset_session")
    if result["success"]:
        print("Session reset")
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)


def cmd_set_game_speed(args, project_path: Path):
    """Set game speed (time scale)."""
    result = send_command(project_path, "set_game_speed", {"scale": args.scale})
    if result["success"]:
        data = result["data"]
        print(f"Game speed: {data['previous_scale']:.1f} -> {data['current_scale']:.1f}")
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)


def cmd_wait_frames(args, project_path: Path):
    """Wait for N physics frames."""
    timeout = max(30, args.count / 10)
    result = send_command(project_path, "wait_frames", {"count": args.count}, timeout=timeout)
    if result["success"]:
        data = result["data"]
        print(f"Waited {data['frames']} frames ({data['elapsed_ms']}ms)")
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)


def cmd_get_catcher_state(args, project_path: Path):
    """Get catcher state."""
    result = send_command(project_path, "get_catcher_state")
    if result["success"]:
        data = result["data"]
        print(f"Position X:         {data['position_x']:.1f}")
        print(f"Width:              {data['width']:.1f}")
        print(f"Speed:              {data['speed']:.1f}")
        print(f"Tier:               {data['tier']}")
        print(f"Combo:              {data['combo']}")
        print(f"Combo multiplier:   {data['combo_multiplier']:.1f}")
        print(f"Bomb shrink:        {data['bomb_shrink_active']}")
        print(f"Game paused:        {data['game_paused']}")
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="DevTools CLI - interact with running Godot instance")
    parser.add_argument("--project", "-p", help="Path to Godot project", default=".")

    subparsers = parser.add_subparsers(dest="command", required=True)

    # ping
    p = subparsers.add_parser("ping", help="Check if DevTools is running")
    p.set_defaults(func=cmd_ping)

    # screenshot
    p = subparsers.add_parser("screenshot", help="Take a screenshot")
    p.add_argument("--filename", "-f", help="Output filename")
    p.set_defaults(func=cmd_screenshot)

    # validate
    p = subparsers.add_parser("validate", help="Validate a scene")
    p.add_argument("--scene", "-s", help="Scene path (res://...)")
    p.set_defaults(func=cmd_validate)

    # validate-all
    p = subparsers.add_parser("validate-all", help="Validate all scenes")
    p.set_defaults(func=cmd_validate_all)

    # scene-tree
    p = subparsers.add_parser("scene-tree", help="Get scene tree")
    p.add_argument("--depth", "-d", type=int, default=10, help="Max depth")
    p.set_defaults(func=cmd_scene_tree)

    # performance
    p = subparsers.add_parser("performance", help="Get performance metrics")
    p.set_defaults(func=cmd_performance)

    # get-state
    p = subparsers.add_parser("get-state", help="Get node state")
    p.add_argument("--node", "-n", help="Node path")
    p.set_defaults(func=cmd_get_state)

    # set-state
    p = subparsers.add_parser("set-state", help="Set node property")
    p.add_argument("--node", "-n", required=True, help="Node path")
    p.add_argument("--property", required=True, help="Property name")
    p.add_argument("--value", required=True, help="Property value")
    p.set_defaults(func=cmd_set_state)

    # run-method
    p = subparsers.add_parser("run-method", help="Call a method")
    p.add_argument("--node", "-n", required=True, help="Node path")
    p.add_argument("--method", "-m", required=True, help="Method name")
    p.add_argument("--args", "-a", help="Method arguments as JSON array")
    p.set_defaults(func=cmd_run_method)

    # logs
    p = subparsers.add_parser("logs", help="View logs")
    p.add_argument("--tail", "-t", type=int, help="Show last N entries")
    p.add_argument("--category", "-c", help="Filter by category")
    p.set_defaults(func=cmd_logs)

    # quit
    p = subparsers.add_parser("quit", help="Quit Godot")
    p.add_argument("--exit-code", type=int, help="Exit code")
    p.set_defaults(func=cmd_quit)

    # input - nested subcommands
    input_parser = subparsers.add_parser("input", help="Simulate input actions")
    input_sub = input_parser.add_subparsers(dest="input_command", required=True)

    # input press
    p = input_sub.add_parser("press", help="Press and hold an action")
    p.add_argument("action", help="Action name (e.g., move_left)")
    p.add_argument("--strength", type=float, help="Pressure strength 0.0-1.0 (default: 1.0)")
    p.set_defaults(func=cmd_input_press)

    # input release
    p = input_sub.add_parser("release", help="Release a held action")
    p.add_argument("action", help="Action name to release")
    p.set_defaults(func=cmd_input_release)

    # input tap
    p = input_sub.add_parser("tap", help="Press and release an action")
    p.add_argument("action", help="Action name to tap")
    p.add_argument("--hold", type=float, default=0, help="Hold duration in seconds before release")
    p.add_argument("--strength", type=float, help="Pressure strength 0.0-1.0 (default: 1.0)")
    p.set_defaults(func=cmd_input_tap)

    # input clear
    p = input_sub.add_parser("clear", help="Release all simulated inputs")
    p.set_defaults(func=cmd_input_clear)

    # input list
    p = input_sub.add_parser("list", help="List available input actions")
    p.add_argument("--all", "-a", action="store_true", help="Include built-in ui_* actions")
    p.set_defaults(func=cmd_input_list)

    # input sequence
    p = input_sub.add_parser("sequence", help="Execute input sequence from JSON file")
    p.add_argument("file", help="Path to sequence JSON file")
    p.add_argument("--timeout", type=float, default=60, help="Sequence timeout in seconds (default: 60)")
    p.set_defaults(func=cmd_input_sequence)

    # ==================== DEBUG COMMANDS ====================

    # spawn-coin
    p = subparsers.add_parser("spawn-coin", help="Spawn a coin at a position")
    p.add_argument("--type", "-t", default="SILVER", help="Coin type: SILVER, GOLD, FRENZY, BOMB")
    p.add_argument("--x", type=float, help="X position (default: random)")
    p.add_argument("--y", type=float, help="Y position (default: -50)")
    p.set_defaults(func=cmd_spawn_coin)

    # spawn-coin-on-catcher
    p = subparsers.add_parser("spawn-coin-on-catcher", help="Spawn a coin above the catcher")
    p.add_argument("--type", "-t", default="SILVER", help="Coin type: SILVER, GOLD, FRENZY, BOMB")
    p.set_defaults(func=cmd_spawn_coin_on_catcher)

    # get-active-coins
    p = subparsers.add_parser("get-active-coins", help="List all active coins")
    p.set_defaults(func=cmd_get_active_coins)

    # clear-coins
    p = subparsers.add_parser("clear-coins", help="Remove all active coins")
    p.set_defaults(func=cmd_clear_coins)

    # set-upgrade-levels
    p = subparsers.add_parser("set-upgrade-levels", help="Bulk-set upgrade levels")
    p.add_argument("--spawn-rate", type=int, help="Spawn rate level")
    p.add_argument("--coin-value", type=int, help="Coin value level")
    p.add_argument("--catcher-speed", type=int, help="Catcher speed level")
    p.add_argument("--catcher-width", type=int, help="Catcher width level")
    p.add_argument("--magnet", type=int, help="Magnet level")
    p.set_defaults(func=cmd_set_upgrade_levels)

    # reset-session
    p = subparsers.add_parser("reset-session", help="Reset to fresh game state")
    p.set_defaults(func=cmd_reset_session)

    # set-game-speed
    p = subparsers.add_parser("set-game-speed", help="Set game speed (time scale)")
    p.add_argument("scale", type=float, help="Time scale (0=pause, 1=normal, 10=fast)")
    p.set_defaults(func=cmd_set_game_speed)

    # wait-frames
    p = subparsers.add_parser("wait-frames", help="Wait for N physics frames")
    p.add_argument("count", type=int, help="Number of frames to wait")
    p.set_defaults(func=cmd_wait_frames)

    # get-catcher-state
    p = subparsers.add_parser("get-catcher-state", help="Get catcher state")
    p.set_defaults(func=cmd_get_catcher_state)

    args = parser.parse_args()

    project_path = Path(args.project).resolve()
    args.func(args, project_path)


if __name__ == "__main__":
    main()
