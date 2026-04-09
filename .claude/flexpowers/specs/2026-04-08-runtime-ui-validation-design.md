# Runtime UI Validation for DevTools

**Issue:** #12 -- Add runtime UI validation to DevTools
**Date:** 2026-04-08
**Status:** Design

## Summary

Add 3 DevTools commands (`validate_ui`, `get_ui_snapshot`, `get_node_bounds`) that inspect live Control nodes at runtime for layout issues: viewport overflow, zero-size visible elements, fully transparent nodes, text overflow, and negative positions. Also add 3 matching Python CLI subcommands and CLAUDE.md documentation.

## Motivation

The existing `scene_validator.gd` checks static scene structure (missing textures, broken signals, null resources) but cannot detect runtime UI layout problems. Many HUD elements are created dynamically in code (`Label.new()`, `Button.new()` in `hud.gd`) and never appear in `.tscn` files. Problems like text rendering off-screen, overlapping labels, invisible elements, or zero-sized controls go undetected. These commands give E2E tests deterministic UI assertions.

## Scope

### In scope
- 3 new DevTools commands (GDScript handlers in `dev_tools.gd`)
- 3 private helper functions for shared logic
- 3 new Python CLI subcommands in `devtools.py`
- CLAUDE.md documentation updates

### Out of scope
- Changes to `validate-all` — stays static-only; `validate-ui` is a separate command. Tests chain them: `validate-all && validate-ui`. The `--include-ui` flag from the original issue was dropped to keep runtime and static validation cleanly separated.
- Orphan Control detection — dropped because the only Controls outside CanvasLayer in this codebase are intentional (e.g., catcher combo label in world space). Would produce only false positives.
- Transient node filtering — snapshot returns everything; consumers filter on the Python side by path/name.
- Vertical text overflow on wrapped labels — out of scope for this iteration.
- Changes to `scene_validator.gd` or game logic

## Changes

### 1. `scripts/dev_tools.gd` — Helper Functions

Three private helpers shared by the command handlers:

**`_get_effective_alpha(node: Node) -> float`**
Walk the parent chain from `node` upward, multiplying both `modulate.a` and `self_modulate.a` at each level. Both properties independently affect transparency — a node with `modulate.a = 1.0` but `self_modulate.a = 0.0` is fully transparent. Stop at the root or at a CanvasLayer (CanvasLayer resets the rendering context). Returns the cumulative alpha.

```gdscript
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
```

**`_is_effectively_visible(node: Node) -> bool`**
Walk the parent chain checking `visible`. A node is effectively visible only if every ancestor up to the CanvasLayer is visible.

```gdscript
func _is_effectively_visible(node: Node) -> bool:
    var current: Node = node
    while current != null:
        if current is CanvasItem and not current.visible:
            return false
        if current is CanvasLayer:
            break
        current = current.get_parent()
    return true
```

**`_get_control_text(node: Control) -> String`**
Return the text content for Label, Button, and RichTextLabel nodes. Returns empty string for other Control types.

```gdscript
func _get_control_text(node: Control) -> String:
    if node is Label:
        return node.text
    if node is Button:
        return node.text
    if node is RichTextLabel:
        return node.get_parsed_text()
    return ""
```

### 2. `scripts/dev_tools.gd` — `validate_ui` Command

**Registration:** Add in `_ready()` after the existing debug command handlers (after line 60 in current `dev_tools.gd`):
```gdscript
_handlers["validate_ui"] = _cmd_validate_ui
_handlers["get_ui_snapshot"] = _cmd_get_ui_snapshot
_handlers["get_node_bounds"] = _cmd_get_node_bounds
```

**Args:** none

**Implementation:**
- Get viewport size: `get_tree().root.size` (Vector2i, 720x1280)
- Recursively walk the scene tree starting from `get_tree().current_scene`
- For each node that `is Control` and is effectively visible (`_is_effectively_visible(node)`):
  - Run 5 checks (details below)
- Return: `{success: bool, message: String, data: {issues: Array}}`
- `success` is `true` only when zero issues found

**5 Checks:**

**Check 1: Viewport overflow (`ui_overflow`, warning)**
```gdscript
var rect: Rect2 = control.get_global_rect()
var vp: Vector2 = Vector2(get_tree().root.size)
if rect.position.x + rect.size.x > vp.x or rect.position.y + rect.size.y > vp.y:
    # Report: node name, rect bounds, viewport size
```

**Check 2: Zero-size visible (`ui_zero_size`, warning)**
```gdscript
if control.size.x == 0.0 or control.size.y == 0.0:
    # Report: node name, size
```

**Check 3: Fully transparent (`ui_transparent`, info)**
```gdscript
var effective_alpha: float = _get_effective_alpha(control)
if effective_alpha == 0.0:
    # Report: node name, modulate.a, effective alpha
```

**Check 4: Text overflow (`ui_text_overflow`, warning)**
Only applies to Label nodes with wrapping disabled (`TextServer.AUTOWRAP_OFF`, value `0`). Wrapped labels handle text overflow gracefully by flowing to multiple lines, so we only check labels with wrapping disabled. Vertical overflow on wrapped labels is out of scope.
```gdscript
if control is Label and control.autowrap_mode == TextServer.AUTOWRAP_OFF:
    var font: Font = control.get_theme_font("font")
    if font == null:
        continue  # Skip if font is missing
    var font_size: int = control.get_theme_font_size("font_size")
    if font_size <= 0:
        font_size = control.get_theme_default_font_size()
    var text_width: float = font.get_string_size(control.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
    if text_width > control.size.x and control.size.x > 0.0:
        # Report: node name, text content (truncated to 50 chars), text_width, label width
        var display_text: String = control.text
        if display_text.length() > 50:
            display_text = display_text.substr(0, 47) + "..."
```

**Check 5: Negative position (`ui_negative_pos`, info)**
```gdscript
var rect: Rect2 = control.get_global_rect()
if rect.position.x < 0.0 or rect.position.y < 0.0:
    # Report: node name, global rect position
```

**Issue format** matches `scene_validator.gd`:
```gdscript
{"severity": severity, "code": code, "message": message}
```

**Example return:**
```json
{
  "success": false,
  "message": "3 UI issues found",
  "data": {
    "issues": [
      {"severity": "warning", "code": "ui_overflow", "message": "Label 'AscensionLabel' extends past viewport (rect: 20,55 -> 780,75, viewport: 720x1280)"},
      {"severity": "warning", "code": "ui_text_overflow", "message": "Label 'ComboMultiplierLabel' text '1234.5x' exceeds width (text: 95px, label: 80px)"},
      {"severity": "info", "code": "ui_transparent", "message": "Label 'MilestoneLabel' is visible but fully transparent (effective alpha: 0.0)"}
    ]
  }
}
```

### 3. `scripts/dev_tools.gd` — `get_ui_snapshot` Command

**Args:** none

**Implementation:**
- Get viewport size from `get_tree().root.size`
- Recursively walk the scene tree from `get_tree().current_scene`
- For each node that `is Control`:
  - **Include** if ANY of: effectively visible (`_is_effectively_visible` returns true) OR has non-zero effective alpha (`_get_effective_alpha > 0.0`). This catches misconfigured nodes where visibility and alpha are inconsistent.
  - **Skip** only if BOTH: not effectively visible AND effective alpha == 0.0 (fully hidden from all perspectives)
- Build element dictionary for each included node
- Return viewport dimensions + elements array

**Per-element fields:**
```gdscript
{
    "name": control.name,
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
}
```

**Return structure:**
```json
{
  "success": true,
  "message": "12 UI elements captured",
  "data": {
    "viewport": {"width": 720, "height": 1280},
    "elements": [...]
  }
}
```

### 4. `scripts/dev_tools.gd` — `get_node_bounds` Command

**Args:** `{node_path: String}`

**Implementation:**
- Resolve node via `get_node_or_null(node_path)`
- Verify it's a Control node
- Return rect, visibility, alpha, and in-viewport status

**Return structure:**
```json
{
  "success": true,
  "message": "Bounds for CurrencyLabel",
  "data": {
    "name": "CurrencyLabel",
    "type": "Label",
    "path": "/root/Main/HUD/TopBar/CurrencyLabel",
    "global_rect": {"x": 20, "y": 15, "w": 680, "h": 40},
    "visible": true,
    "modulate_a": 1.0,
    "text": "Coins: 523",
    "in_viewport": true
  }
}
```

**Error cases** (error responses omit `data` field, consistent with other command error responses):
- Missing `node_path` arg: `{success: false, message: "No node_path provided"}`
- Node not found: `{success: false, message: "Node not found: ..."}`
- Node is not a Control: `{success: false, message: "Node is not a Control: ..."}`

### 5. `tools/devtools.py` — Python CLI Extensions

Add 3 new subcommands:

| Subcommand | Args | Maps to action |
|---|---|---|
| `validate-ui` | (none) | `validate_ui` |
| `ui-snapshot` | `--json` flag | `get_ui_snapshot` |
| `node-bounds` | `NODE_PATH` (positional) | `get_node_bounds` |

**`validate-ui` output:** Reuse existing `print_validation_result()` function. The return format is compatible — `data.issues` is an array of `{severity, code, message}` dictionaries.

**`ui-snapshot` output (default, human-readable):**
```
Viewport: 720x1280
UI Elements: 12

  CurrencyLabel (Label) [20,15 680x40] visible alpha=1.0 "Coins: 523"
  MuteButton (Button) [650,15 55x40] visible alpha=1.0 "🔊"
  AscensionLabel (Label) [20,55 380x20] hidden alpha=0.0 ""
  ...
```

**`ui-snapshot --json` output:** Raw JSON from the command result.

**`node-bounds` output:**
```
CurrencyLabel (Label)
  Rect:       20, 15, 680x40
  Visible:    True
  Alpha:      1.0
  In viewport: True
  Text:       "Coins: 523"
```

### 6. `CLAUDE.md` — Documentation

Add under the existing "Debug Commands (for E2E testing)" section:

```markdown
# UI validation
python3 tools/devtools.py validate-ui
python3 tools/devtools.py ui-snapshot
python3 tools/devtools.py ui-snapshot --json
python3 tools/devtools.py node-bounds "/root/Main/HUD/TopBar/CurrencyLabel"
```

## Validation Plan

1. **Headless lint:** `godot --headless --script res://tools/lint_project.gd` — verify no parse errors
2. **Python syntax:** `python3 -c "import ast; ast.parse(open('tools/devtools.py').read())"`
3. **Launch game and test each command:**
   - `validate-ui` → verify issues array returned (may have 0 or more)
   - `set-state --node "/root/GameManager" --property currency --value 999999999` → `validate-ui` → check for text overflow on currency label
   - `ui-snapshot` → verify human-readable output with element count
   - `ui-snapshot --json` → verify valid JSON with viewport and elements
   - `node-bounds "/root/Main/HUD/TopBar/CurrencyLabel"` → verify rect/visible/alpha/text
   - `node-bounds "/nonexistent"` → verify error message
4. **Clean shutdown:** `python3 tools/devtools.py quit`

## Risk Assessment

**Low risk.** All changes are additive — new command handlers in `dev_tools.gd`, new subcommands in `devtools.py`. No game logic is modified. The tree-walking logic uses only read-only Godot APIs (`get_global_rect()`, `get_theme_font()`, `modulate.a`, `self_modulate.a`). The `validate-ui` output format is compatible with `print_validation_result()` so no Python changes needed for display. Scene tree walking is performant for this game's typical tree size (<100 nodes).
