extends Label

# Maps to coin.gd CoinType enum (int for autoload compatibility)
var coin_type: int = 0
var combo_level: int = 0  # 0=no combo, 1=1.5x active, 2=2.0x active

# Only COPPER, SILVER, and GOLD have colors — FRENZY/BOMB/MULTI have value=0 so no text is spawned
const COIN_COLORS: Dictionary = {
	0: Color(1.0, 1.0, 1.0),     # COPPER -> white
	1: Color(1.0, 1.0, 1.0),     # SILVER -> white
	2: Color(1.0, 1.0, 1.0),     # GOLD -> white
}

const FLOAT_COMBO_COLORS: Array[Color] = [
	Color(1.0, 0.84, 0.0),    # base (same as coin gold)
	Color(1.0, 0.7, 0.1),     # 1.5x: warm orange-gold
	Color(1.0, 0.3, 0.1),     # 2.0x: hot red-orange
]


func _ready() -> void:
	var narrow_font: Font = preload("res://assets/fonts/kenney_future_narrow.ttf")
	add_theme_font_override("font", narrow_font)

	# Color based on combo level
	if combo_level > 0:
		add_theme_color_override("font_color", FLOAT_COMBO_COLORS[combo_level])
		add_theme_constant_override("outline_size", 3)
		add_theme_color_override("font_outline_color", Color(1.0, 1.0, 0.5, 0.4))
	else:
		add_theme_color_override("font_color", COIN_COLORS.get(coin_type, COIN_COLORS[0]))

	# Font size scales with combo
	var base_size: int = 32 + combo_level * 6  # 32, 38, 44
	add_theme_font_size_override("font_size", base_size)

	# Random rotation for variety
	rotation = randf_range(-0.15, 0.15)

	# Set small scale before awaiting layout to avoid a one-frame flash at full size
	scale = Vector2(0.3, 0.3)
	await get_tree().process_frame
	pivot_offset = size / 2.0
	position.x -= size.x / 2.0

	var tween := create_tween()

	# Float upward (longer for combo)
	var float_dist: float = 80.0 + combo_level * 20.0
	tween.tween_property(self, "position:y", position.y - float_dist, 0.8)

	# Horizontal drift
	var drift_x: float = randf_range(-25.0, 25.0)
	tween.parallel().tween_property(self, "position:x", position.x + drift_x, 0.8)

	# Scale pop (bigger for combo)
	var pop_target: float = 1.1 + combo_level * 0.15
	tween.parallel().tween_property(self, "scale", Vector2(pop_target, pop_target), 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(self, "scale", Vector2(1.0, 1.0), 0.08).set_delay(0.1)

	# Fade out and free
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)
