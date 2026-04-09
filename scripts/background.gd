extends ColorRect

var _time: float = 0.0
var _color_a := Color(0.08, 0.08, 0.18, 1.0)
var _color_b := Color(0.12, 0.06, 0.22, 1.0)
var _base_color_a: Color
var _base_color_b: Color
var _cycle_speed: float = CYCLE_SPEED

const PALETTES: Array[Array] = [
	[Color(0.08, 0.08, 0.18, 1.0), Color(0.12, 0.06, 0.22, 1.0)],   # Navy/purple (base)
	[Color(0.15, 0.08, 0.02, 1.0), Color(0.22, 0.12, 0.0, 1.0)],    # Deep bronze
	[Color(0.02, 0.1, 0.15, 1.0), Color(0.0, 0.15, 0.22, 1.0)],     # Ocean teal
	[Color(0.15, 0.02, 0.08, 1.0), Color(0.22, 0.0, 0.12, 1.0)],    # Crimson
	[Color(0.08, 0.15, 0.02, 1.0), Color(0.05, 0.2, 0.08, 1.0)],    # Emerald
]
const CYCLE_SPEED: float = 0.15


func _ready() -> void:
	GameManager.ascended.connect(_on_ascended)
	GameManager.frenzy_started.connect(_on_frenzy_started)
	GameManager.frenzy_ended.connect(_on_frenzy_ended)
	_set_palette(GameManager.ascension_count)


func _process(delta: float) -> void:
	_time += delta * _cycle_speed
	var t := (sin(_time) + 1.0) * 0.5
	color = _color_a.lerp(_color_b, t)


func _on_ascended(count: int) -> void:
	_set_palette(count)


func _set_palette(ascension: int) -> void:
	var idx: int = ascension % PALETTES.size()
	_color_a = PALETTES[idx][0]
	_color_b = PALETTES[idx][1]
	_base_color_a = _color_a
	_base_color_b = _color_b


func _on_frenzy_started() -> void:
	_color_a = Color(0.02, 0.1, 0.04, 1.0)
	_color_b = Color(0.06, 0.18, 0.08, 1.0)
	_cycle_speed = 0.5


func _on_frenzy_ended() -> void:
	_color_a = _base_color_a
	_color_b = _base_color_b
	_cycle_speed = CYCLE_SPEED
