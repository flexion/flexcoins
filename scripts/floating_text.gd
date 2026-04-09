extends Label


func _ready() -> void:
	var narrow_font: Font = preload("res://assets/fonts/kenney_future_narrow.ttf")
	add_theme_font_override("font", narrow_font)
	await get_tree().process_frame
	position.x -= size.x / 2.0
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - 60.0, 0.7)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.7)
	tween.tween_callback(queue_free)
