extends Node2D

@export var coin_scene: PackedScene
@export var spawn_interval: float = 0.8
@export var margin: float = 40.0


func _ready() -> void:
	$Timer.wait_time = spawn_interval
	$Timer.start()


func _on_timer_timeout() -> void:
	if coin_scene == null:
		return
	var coin := coin_scene.instantiate()
	var viewport_width := get_viewport_rect().size.x
	coin.position = Vector2(randf_range(margin, viewport_width - margin), -50.0)
	get_parent().add_child(coin)
