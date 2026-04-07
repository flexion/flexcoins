extends Area2D

@export var floating_text_scene: PackedScene

var speed: float = 600.0

var _prev_x: float = 0.0
var _trail_particles: CPUParticles2D

@onready var color_rect: ColorRect = $ColorRect
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var bling_sound: AudioStreamPlayer = $BlingSound


func _ready() -> void:
	collision_shape.shape = collision_shape.shape.duplicate()
	GameManager.upgrade_purchased.connect(_on_upgrade_purchased)
	_apply_upgrades()
	_prev_x = position.x
	_setup_trail()


func _process(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	position.x += direction * speed * delta
	var half_width := GameManager.get_catcher_width() / 2.0
	var viewport_width := get_viewport_rect().size.x
	position.x = clamp(position.x, half_width, viewport_width - half_width)

	# Motion trail intensity based on speed
	var velocity := absf(position.x - _prev_x) / delta
	_prev_x = position.x
	var speed_ratio := clampf(velocity / speed, 0.0, 1.0)
	if _trail_particles:
		_trail_particles.emitting = speed_ratio > 0.3
		_trail_particles.amount = int(lerpf(3.0, 12.0, speed_ratio))


func _on_area_entered(area: Area2D) -> void:
	if area.has_method("collect"):
		var value: int = area.value
		var pos: Vector2 = area.global_position
		GameManager.coin_collected.emit(value, pos)
		_spawn_floating_text(pos, value)
		_spawn_collect_burst(pos)
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
		ft.z_index = 10
		get_parent().add_child(ft)


func _spawn_collect_burst(at_position: Vector2) -> void:
	var burst := CPUParticles2D.new()
	burst.emitting = true
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 12
	burst.lifetime = 0.5
	burst.direction = Vector2(0, -1)
	burst.spread = 180.0
	burst.initial_velocity_min = 80.0
	burst.initial_velocity_max = 180.0
	burst.gravity = Vector2(0, 200)
	burst.scale_amount_min = 2.0
	burst.scale_amount_max = 5.0
	burst.color = Color(1.0, 0.84, 0.0, 0.9)
	burst.position = at_position
	burst.z_index = 5
	get_parent().add_child(burst)
	# Self-free after particles are done
	get_tree().create_timer(burst.lifetime + 0.1).timeout.connect(burst.queue_free)


func _setup_trail() -> void:
	_trail_particles = CPUParticles2D.new()
	_trail_particles.emitting = false
	_trail_particles.amount = 6
	_trail_particles.lifetime = 0.3
	_trail_particles.direction = Vector2(0, 1)
	_trail_particles.spread = 30.0
	_trail_particles.initial_velocity_min = 20.0
	_trail_particles.initial_velocity_max = 50.0
	_trail_particles.gravity = Vector2.ZERO
	_trail_particles.scale_amount_min = 2.0
	_trail_particles.scale_amount_max = 4.0
	_trail_particles.color = Color(0.4, 0.65, 1.0, 0.4)
	add_child(_trail_particles)
