extends Area2D

@export var floating_text_scene: PackedScene

var speed: float = 600.0

@onready var color_rect: ColorRect = $ColorRect
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var bling_sound: AudioStreamPlayer = $BlingSound


func _ready() -> void:
	collision_shape.shape = collision_shape.shape.duplicate()
	GameManager.upgrade_purchased.connect(_on_upgrade_purchased)
	_apply_upgrades()


func _process(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	position.x += direction * speed * delta
	var half_width := GameManager.get_catcher_width() / 2.0
	var viewport_width := get_viewport_rect().size.x
	position.x = clamp(position.x, half_width, viewport_width - half_width)


func _on_area_entered(area: Area2D) -> void:
	if area.has_method("collect"):
		GameManager.add_currency(area.value)
		_spawn_floating_text(area.global_position, area.value)
		bling_sound.play()
		area.collect()


func _on_upgrade_purchased(_upgrade_id: String) -> void:
	_apply_upgrades()


func _apply_upgrades() -> void:
	speed = GameManager.get_catcher_speed()
	var w := GameManager.get_catcher_width()
	color_rect.offset_left = -w / 2.0
	color_rect.offset_right = w / 2.0
	color_rect.offset_top = -10.0
	color_rect.offset_bottom = 10.0
	collision_shape.shape.size = Vector2(w, 20.0)


func _spawn_floating_text(at_position: Vector2, value: int) -> void:
	if floating_text_scene:
		var ft: Label = floating_text_scene.instantiate()
		ft.text = "+%d" % value
		ft.position = at_position + Vector2(0.0, -20.0)
		get_parent().add_child(ft)
