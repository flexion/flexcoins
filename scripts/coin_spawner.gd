extends Node2D

@export var coin_scene: PackedScene
@export var margin: float = 40.0


func _ready() -> void:
	$Timer.wait_time = GameManager.get_spawn_interval()
	$Timer.start()
	GameManager.upgrade_purchased.connect(_on_upgrade_purchased)


func _on_upgrade_purchased(upgrade_id: String) -> void:
	if upgrade_id == "spawn_rate":
		$Timer.wait_time = GameManager.get_spawn_interval()


func _on_timer_timeout() -> void:
	if coin_scene == null:
		return
	var coin := coin_scene.instantiate()
	var viewport_width := get_viewport_rect().size.x
	coin.position = Vector2(randf_range(margin, viewport_width - margin), -50.0)
	get_parent().add_child(coin)
