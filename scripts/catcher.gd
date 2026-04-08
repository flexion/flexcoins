extends Area2D

@export var floating_text_scene: PackedScene

const MAX_COMBO_PITCH: float = 2.0
const PITCH_STEP: float = 0.08
const COMBO_MULTIPLIER_50: float = 1.5
const COMBO_MULTIPLIER_100: float = 2.0
const COMBO_THRESHOLD_50: int = 50
const COMBO_THRESHOLD_100: int = 100

var speed: float = 600.0

var _prev_x: float = 0.0
var _trail_particles: CPUParticles2D
var _combo: int = 0
var _combo_label: Label
var _combo_fade_timer: Timer
var _combo_multiplier: float = 1.0
var _bomb_shrink_active: bool = false
var _stripe: ColorRect
var _catcher_tier: int = -1
var _rainbow_time: float = 0.0
var _game_paused: bool = false

@onready var color_rect: ColorRect = $ColorRect
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var bling_sound: AudioStreamPlayer = $BlingSound


func _ready() -> void:
	add_to_group("catcher")
	collision_shape.shape = collision_shape.shape.duplicate()

	# Read initial state from GameManager (signal may have already fired)
	_combo_multiplier = 1.0
	_update_combo_multiplier()

	GameManager.upgrade_purchased.connect(_on_upgrade_purchased)
	_apply_upgrades()
	_prev_x = position.x
	_setup_trail()
	_setup_combo_label()
	GameManager.coin_missed.connect(_on_coin_missed)
	GameManager.bomb_hit.connect(_on_bomb_hit)
	GameManager.shop_opened.connect(_on_shop_opened)
	GameManager.shop_closed.connect(_on_shop_closed)
	GameManager.game_loaded.connect(_on_game_loaded)
	GameManager.ascended.connect(_on_ascension)


func _process(delta: float) -> void:
	if _game_paused:
		return
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

	# Horizontal stretch when moving fast
	var stretch_x := lerpf(1.0, 1.15, speed_ratio)
	var stretch_y := lerpf(1.0, 0.85, speed_ratio)
	color_rect.scale = color_rect.scale.lerp(Vector2(stretch_x, stretch_y), 10.0 * delta)

	# Rainbow animation for tier 3+
	if _catcher_tier >= 3:
		_rainbow_time += delta * 1.5
		color_rect.color = Color.from_hsv(fmod(_rainbow_time, 1.0), 0.7, 0.9)
		if _stripe:
			_stripe.color = Color.from_hsv(fmod(_rainbow_time + 0.3, 1.0), 0.5, 1.0, 0.5)


func _on_area_entered(area: Area2D) -> void:
	if area.has_method("collect"):
		var value: int = area.value
		var pos: Vector2 = area.global_position
		_combo += 1
		bling_sound.pitch_scale = minf(1.0 + (_combo - 1) * PITCH_STEP, MAX_COMBO_PITCH)

		# Update combo multiplier based on threshold and apply via GameManager
		_update_combo_multiplier()

		# Coin value is now multiplied in GameManager.get_coin_value()
		GameManager.coin_collected.emit(value, pos)
		# Track quest progress
		GameManager.update_quest_catch_coins(1)
		GameManager.update_quest_combo(_combo)
		_spawn_floating_text(pos, value)
		_spawn_collect_burst(pos)
		_squash_bounce()
		_update_combo_label()
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
	_update_catcher_visual()


func _update_catcher_visual() -> void:
	var level: int = GameManager.get_upgrade_level("catcher_width")
	var new_tier: int = level / 10
	if new_tier == _catcher_tier:
		return
	_catcher_tier = new_tier
	# Remove old stripe
	if _stripe:
		_stripe.queue_free()
		_stripe = null

	match _catcher_tier:
		0:
			# Blue (default)
			color_rect.color = Color(0.29, 0.56, 0.85, 1.0)
		1:
			# Wooden brown with grain stripe
			color_rect.color = Color(0.55, 0.35, 0.17, 1.0)
			_stripe = ColorRect.new()
			_stripe.color = Color(0.65, 0.45, 0.25, 0.6)
			_stripe.offset_left = color_rect.offset_left
			_stripe.offset_right = color_rect.offset_right
			_stripe.offset_top = -2.0
			_stripe.offset_bottom = 2.0
			add_child(_stripe)
		2:
			# Chrome/silver metallic with white highlight
			color_rect.color = Color(0.7, 0.72, 0.75, 1.0)
			_stripe = ColorRect.new()
			_stripe.color = Color(1.0, 1.0, 1.0, 0.4)
			_stripe.offset_left = color_rect.offset_left
			_stripe.offset_right = color_rect.offset_right
			_stripe.offset_top = -6.0
			_stripe.offset_bottom = -2.0
			add_child(_stripe)
		_:
			# Rainbow (animated in _process)
			_stripe = ColorRect.new()
			_stripe.offset_left = color_rect.offset_left
			_stripe.offset_right = color_rect.offset_right
			_stripe.offset_top = -3.0
			_stripe.offset_bottom = 3.0
			add_child(_stripe)


func _squash_bounce() -> void:
	var tween := create_tween()
	tween.tween_property(color_rect, "scale", Vector2(1.2, 0.7), 0.06).set_ease(Tween.EASE_OUT)
	tween.tween_property(color_rect, "scale", Vector2(0.95, 1.1), 0.08).set_ease(Tween.EASE_OUT)
	tween.tween_property(color_rect, "scale", Vector2(1.0, 1.0), 0.1).set_ease(Tween.EASE_IN_OUT)


func _spawn_floating_text(at_position: Vector2, value: int) -> void:
	if floating_text_scene:
		var ft: Label = floating_text_scene.instantiate()
		ft.text = "+%d" % value
		ft.position = at_position + Vector2(0.0, -20.0)
		ft.z_index = 250
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


func _setup_combo_label() -> void:
	_combo_label = Label.new()
	_combo_label.add_theme_font_size_override("font_size", 20)
	_combo_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
	_combo_label.position = Vector2(30.0, -30.0)
	_combo_label.modulate.a = 0.0
	add_child(_combo_label)
	_combo_fade_timer = Timer.new()
	_combo_fade_timer.one_shot = true
	_combo_fade_timer.wait_time = 2.0
	_combo_fade_timer.timeout.connect(_fade_combo_label)
	add_child(_combo_fade_timer)


func _update_combo_label() -> void:
	if _combo >= 2:
		_combo_label.text = "x%d" % _combo
		_combo_label.modulate.a = 1.0
		_combo_fade_timer.start()
	else:
		_combo_label.modulate.a = 0.0


func _fade_combo_label() -> void:
	var tween := create_tween()
	tween.tween_property(_combo_label, "modulate:a", 0.0, 0.5)


func _on_coin_missed() -> void:
	_combo = 0
	_reset_combo_multiplier()
	bling_sound.pitch_scale = 1.0
	_combo_label.modulate.a = 0.0


func _on_bomb_hit() -> void:
	if _bomb_shrink_active:
		return
	_bomb_shrink_active = true
	# Reset combo and multiplier on bomb hit (hard reset)
	_combo = 0
	_reset_combo_multiplier()
	# Shrink to 60% width
	var normal_w := GameManager.get_catcher_width()
	var shrunk_w := normal_w * 0.6
	color_rect.offset_left = -shrunk_w / 2.0
	color_rect.offset_right = shrunk_w / 2.0
	collision_shape.shape.size = Vector2(shrunk_w, 20.0)
	# Flash red (restore happens via _apply_upgrades after timer)
	color_rect.color = Color(1.0, 0.2, 0.1, 1.0)
	# Restore after 3 seconds
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		_bomb_shrink_active = false
		_catcher_tier = -1
		_apply_upgrades()
	)


func _update_combo_multiplier() -> void:
	var old_multiplier := _combo_multiplier
	if _combo >= COMBO_THRESHOLD_100:
		_combo_multiplier = COMBO_MULTIPLIER_100
	elif _combo >= COMBO_THRESHOLD_50:
		_combo_multiplier = COMBO_MULTIPLIER_50
	else:
		_combo_multiplier = 1.0

	# Apply multiplier to GameManager and emit signal if changed
	if _combo_multiplier != old_multiplier:
		GameManager.set_combo_multiplier(_combo_multiplier)
		GameManager.combo_multiplier_changed.emit(_combo_multiplier)


func _reset_combo_multiplier() -> void:
	if _combo_multiplier != 1.0:
		_combo_multiplier = 1.0
		GameManager.set_combo_multiplier(1.0)
		GameManager.combo_multiplier_changed.emit(1.0)


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


func _on_shop_opened() -> void:
	_game_paused = true
	monitoring = false


func _on_shop_closed() -> void:
	_game_paused = false
	monitoring = true
	add_child(_trail_particles)


func _on_game_loaded() -> void:
	_combo_multiplier = 1.0
	_update_combo_multiplier()


func _on_ascension(count: int) -> void:
	_combo = 0
	_reset_combo_multiplier()
	bling_sound.pitch_scale = 1.0
	_combo_label.modulate.a = 0.0
