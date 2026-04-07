extends Area2D

@export var fall_speed: float = 300.0
var value: int = 1

var _collected: bool = false
var _current_speed: float = 0.0
var _rotation_speed: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	value = GameManager.get_coin_value()
	rotation = randf_range(0.0, TAU)
	_rotation_speed = randf_range(-1.5, 1.5)
	_current_speed = fall_speed * 0.15
	_add_glow()
	_add_trail()


func _process(delta: float) -> void:
	_current_speed = move_toward(_current_speed, fall_speed, fall_speed * delta * 0.8)
	position.y += _current_speed * delta
	rotation += _rotation_speed * delta


func collect() -> void:
	_collected = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	set_process(false)
	# Scale-up pop before disappearing
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2(0.55, 0.55), 0.07).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", Vector2(0.0, 0.0), 0.09).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.09)
	tween.tween_callback(queue_free)


func _on_screen_exited() -> void:
	if not _collected:
		GameManager.coin_missed.emit()
	queue_free()


func _add_glow() -> void:
	# Faint glow behind the coin using a scaled-up tinted copy of the sprite
	var glow := Sprite2D.new()
	glow.texture = sprite.texture
	glow.scale = Vector2(0.55, 0.55)
	glow.modulate = Color(1.0, 0.84, 0.0, 0.2)
	glow.z_index = -1
	add_child(glow)


func _add_trail() -> void:
	var trail := CPUParticles2D.new()
	trail.emitting = true
	trail.amount = 5
	trail.lifetime = 0.35
	trail.direction = Vector2(0, -1)
	trail.spread = 15.0
	trail.initial_velocity_min = 8.0
	trail.initial_velocity_max = 20.0
	trail.gravity = Vector2.ZERO
	trail.scale_amount_min = 1.5
	trail.scale_amount_max = 3.0
	trail.color = Color(1.0, 0.84, 0.0, 0.35)
	add_child(trail)
