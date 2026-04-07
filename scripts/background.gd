extends ColorRect

var _time: float = 0.0

const COLOR_A := Color(0.08, 0.08, 0.18, 1.0)   # Deep navy
const COLOR_B := Color(0.12, 0.06, 0.22, 1.0)    # Deep purple
const CYCLE_SPEED: float = 0.15


func _process(delta: float) -> void:
	_time += delta * CYCLE_SPEED
	var t := (sin(_time) + 1.0) * 0.5
	color = COLOR_A.lerp(COLOR_B, t)
