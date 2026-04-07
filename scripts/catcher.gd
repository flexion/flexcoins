extends Area2D

@export var speed: float = 600.0


func _process(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	position.x += direction * speed * delta
	var viewport_width := get_viewport_rect().size.x
	position.x = clamp(position.x, 50.0, viewport_width - 50.0)


func _on_area_entered(area: Area2D) -> void:
	if area.has_method("collect"):
		GameManager.add_currency(area.value)
		area.collect()
