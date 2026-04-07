extends Label


func _ready() -> void:
	await get_tree().process_frame
	position.x -= size.x / 2.0
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - 60.0, 0.7)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.7)
	tween.tween_callback(queue_free)
