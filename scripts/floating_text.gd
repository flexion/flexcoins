extends Label

# Maps to coin.gd CoinType enum (int for autoload compatibility)
var coin_type: int = 0

# Only SILVER and GOLD have colors — FRENZY/BOMB have value=0 so no text is spawned
const COIN_COLORS: Dictionary = {
	0: Color(1.0, 0.84, 0.0),    # SILVER -> gold
	1: Color(1.0, 0.95, 0.3),    # GOLD -> bright yellow-gold
}


func _ready() -> void:
	var narrow_font: Font = preload("res://assets/fonts/kenney_future_narrow.ttf")
	add_theme_font_override("font", narrow_font)
	add_theme_color_override("font_color", COIN_COLORS.get(coin_type, COIN_COLORS[0]))
	# Set small scale before awaiting layout to avoid a one-frame flash at full size
	scale = Vector2(0.3, 0.3)
	await get_tree().process_frame
	pivot_offset = size / 2.0
	position.x -= size.x / 2.0
	var tween := create_tween()
	# Float upward 80px over 0.8s (starts immediately at 0.0s)
	tween.tween_property(self, "position:y", position.y - 80.0, 0.8)
	# Scale pop with overshoot (parallel — also starts at 0.0s)
	tween.parallel().tween_property(self, "scale", Vector2(1.1, 1.1), 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# Scale settle after pop completes (parallel with 0.1s delay to sequence after pop)
	tween.parallel().tween_property(self, "scale", Vector2(1.0, 1.0), 0.05).set_delay(0.1)
	# Fade out after float completes, then self-free
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)
