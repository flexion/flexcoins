extends Area2D

@export var fall_speed: float = 300.0
@export var value: int = 1


func _process(delta: float) -> void:
	position.y += fall_speed * delta


func collect() -> void:
	queue_free()


func _on_screen_exited() -> void:
	queue_free()
