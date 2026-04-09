# Runtime UI Validation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use flexpowers:subagent-driven-development (recommended) or flexpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 3 DevTools commands (`validate_ui`, `get_ui_snapshot`, `get_node_bounds`) for runtime UI layout validation, plus 3 Python CLI subcommands and CLAUDE.md docs.

**Architecture:** All new code goes inline in `dev_tools.gd` and `devtools.py`, following the Issue #11 pattern.

**Tech Stack:** GDScript (Godot 4.6), Python 3 (argparse CLI)

---

## File Map

| Action | File | Responsibility |
|--------|------|---------------|
| Modify | `scripts/dev_tools.gd` (after line 60) | Register 3 new handler mappings |
| Modify | `scripts/dev_tools.gd` (before utility functions) | Add 3 helper functions + 3 command handlers |
| Modify | `tools/devtools.py` (before `main()`) | Add 3 new `cmd_*` Python functions |
| Modify | `tools/devtools.py` (in `main()`) | Register 3 new argparse subcommands |
| Modify | `CLAUDE.md` | Add UI validation documentation |

---

### Task 1: Helper Functions (GDScript)

**Files:**
- Modify: `scripts/dev_tools.gd` — add 3 helper functions before the utility functions section

- [ ] **Step 1: Add `_get_effective_alpha` helper**

Add before the `# --- Utility Functions ---` section (before `func _serialize_variant`), with a new section header:

```gdscript
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
```

- [ ] **Step 2: Run headless lint**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script res://tools/lint_project.gd`

---

### Task 2: `validate_ui` Command (GDScript)

**Files:**
- Modify: `scripts/dev_tools.gd` — register handler + implement command

- [ ] **Step 1: Register handler in `_ready()`**

Add after line 60 (after `_handlers["get_catcher_state"]`):
```gdscript
	_handlers["validate_ui"] = _cmd_validate_ui
	_handlers["get_ui_snapshot"] = _cmd_get_ui_snapshot
	_handlers["get_node_bounds"] = _cmd_get_node_bounds
```

- [ ] **Step 2: Implement `_cmd_validate_ui`**

Add after the debug command handlers section (after `_cmd_get_catcher_state`), with a new section header:

```gdscript
# --- UI Validation Command Handlers ---


func _cmd_validate_ui(_args: Dictionary) -> Dictionary:
	var issues: Array = []
	# get_tree().root.size is Vector2i; cast to Vector2 for float comparisons
	var vp: Vector2 = Vector2(get_tree().root.size)

	_validate_ui_recursive(get_tree().current_scene, vp, issues)

	return {
		"success": issues.is_empty(),
		"message": "%d UI issues found" % issues.size() if not issues.is_empty() else "No UI issues found",
		"data": {"issues": issues},
	}


func _validate_ui_recursive(node: Node, vp: Vector2, issues: Array) -> void:
	if node is Control and _is_effectively_visible(node):
		var control: Control = node as Control
		var rect: Rect2 = control.get_global_rect()

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
				"severity": "info",
				"code": "ui_negative_pos",
				"message": "%s '%s' has negative position (%.0f, %.0f)" % [
					control.get_class(), control.name, rect.position.x, rect.position.y,
				],
			})

	for child in node.get_children():
		_validate_ui_recursive(child, vp, issues)
```

- [ ] **Step 3: Run headless lint**

---

### Task 3: `get_ui_snapshot` Command (GDScript)

**Files:**
- Modify: `scripts/dev_tools.gd` — implement command

- [ ] **Step 1: Implement `_cmd_get_ui_snapshot`**

Add after `_validate_ui_recursive`:

```gdscript
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

		# Include if effectively visible OR has non-zero alpha
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
```

- [ ] **Step 2: Run headless lint**

---

### Task 4: `get_node_bounds` Command (GDScript)

**Files:**
- Modify: `scripts/dev_tools.gd` — implement command

- [ ] **Step 1: Implement `_cmd_get_node_bounds`**

Add after `_snapshot_ui_recursive`:

```gdscript
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
```

- [ ] **Step 2: Run headless lint**

---

### Task 5: Python CLI Extensions

**Files:**
- Modify: `tools/devtools.py` — add 3 `cmd_*` functions + 3 argparse subcommands

- [ ] **Step 1: Add 3 Python command functions**

Add after the debug commands section (after `cmd_get_catcher_state`), before `main()`:

```python
# ==================== UI VALIDATION ====================


def cmd_validate_ui(args, project_path: Path):
    """Run all UI layout checks."""
    result = send_command(project_path, "validate_ui")
    print_validation_result(result)


def cmd_ui_snapshot(args, project_path: Path):
    """Get snapshot of all visible UI elements."""
    result = send_command(project_path, "get_ui_snapshot")
    if not result["success"]:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)

    if args.json:
        print(json.dumps(result["data"], indent=2))
        return

    data = result["data"]
    vp = data["viewport"]
    elements = data.get("elements", [])
    print(f"Viewport: {vp['width']}x{vp['height']}")
    print(f"UI Elements: {len(elements)}")
    print()
    for el in elements:
        r = el["global_rect"]
        vis = "visible" if el["visible"] else "hidden"
        text_preview = f' "{el["text"]}"' if el.get("text") else ""
        if len(text_preview) > 53:
            text_preview = text_preview[:50] + '..."'
        print(f"  {el['name']} ({el['type']}) [{r['x']:.0f},{r['y']:.0f} {r['w']:.0f}x{r['h']:.0f}] {vis} alpha={el['modulate_a']:.1f}{text_preview}")


def cmd_node_bounds(args, project_path: Path):
    """Get bounds for a specific node."""
    result = send_command(project_path, "get_node_bounds", {"node_path": args.node_path})
    if not result["success"]:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)

    data = result["data"]
    r = data["global_rect"]
    print(f"{data['name']} ({data['type']})")
    print(f"  Rect:         {r['x']:.0f}, {r['y']:.0f}, {r['w']:.0f}x{r['h']:.0f}")
    print(f"  Visible:      {data['visible']}")
    print(f"  Alpha:        {data['modulate_a']:.1f}")
    print(f"  In viewport:  {data['in_viewport']}")
    if data.get("text"):
        print(f"  Text:         \"{data['text']}\"")
```

- [ ] **Step 2: Register 3 argparse subcommands in `main()`**

Add after the debug commands subparsers (after `get-catcher-state`), before `args = parser.parse_args()`:

```python
    # ==================== UI VALIDATION ====================

    # validate-ui
    p = subparsers.add_parser("validate-ui", help="Run UI layout validation checks")
    p.set_defaults(func=cmd_validate_ui)

    # ui-snapshot
    p = subparsers.add_parser("ui-snapshot", help="Get snapshot of all visible UI elements")
    p.add_argument("--json", "-j", action="store_true", help="Output raw JSON")
    p.set_defaults(func=cmd_ui_snapshot)

    # node-bounds
    p = subparsers.add_parser("node-bounds", help="Get bounds for a specific node")
    p.add_argument("node_path", help="Node path (e.g., /root/Main/HUD/TopBar/CurrencyLabel)")
    p.set_defaults(func=cmd_node_bounds)
```

- [ ] **Step 3: Verify Python syntax**

Run: `python3 -c "import ast; ast.parse(open('tools/devtools.py').read()); print('OK')"`

---

### Task 6: CLAUDE.md Documentation

**Files:**
- Modify: `CLAUDE.md` — add UI validation commands

- [ ] **Step 1: Add UI validation subsection**

Add to the existing "Debug Commands (for E2E testing)" code block, before the closing triple-backtick:

```bash

# UI validation
python3 tools/devtools.py validate-ui
python3 tools/devtools.py ui-snapshot
python3 tools/devtools.py ui-snapshot --json
python3 tools/devtools.py node-bounds "/root/Main/HUD/TopBar/CurrencyLabel"
```

---

### Task 7: Full Validation

- [ ] **Step 1: Run headless lint**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script res://tools/lint_project.gd`

- [ ] **Step 2: Verify Python syntax**

Run: `python3 -c "import ast; ast.parse(open('tools/devtools.py').read()); print('OK')"`

- [ ] **Step 3: Launch game and test all commands**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/jherr/Documents/GitHub/flexcoins &
sleep 5 && python3 tools/devtools.py ping

# Test validate-ui
python3 tools/devtools.py validate-ui

# Test with edge case: huge currency for text overflow
python3 tools/devtools.py set-state --node "/root/GameManager" --property currency --value 999999999
python3 tools/devtools.py validate-ui

# Test ui-snapshot
python3 tools/devtools.py ui-snapshot
python3 tools/devtools.py ui-snapshot --json

# Test node-bounds
python3 tools/devtools.py node-bounds "/root/Main/HUD/TopBar/CurrencyLabel"
python3 tools/devtools.py node-bounds "/nonexistent"

# Reset and quit
python3 tools/devtools.py reset-session
python3 tools/devtools.py quit
```
