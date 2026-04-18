extends Area2D

enum CoinType { COPPER, SILVER, GOLD, FRENZY, BOMB, MULTI }

const TEXTURE_GOLD: Texture2D = preload("res://assets/textures/coins/flexcoin.png")
const TEXTURE_SILVER: Texture2D = preload("res://assets/textures/coins/flexcoin-silver.png")
const TEXTURE_MULTI: Texture2D = preload("res://assets/textures/coins/flexcoin-multi.png")
const TEXTURE_COPPER: Texture2D = preload("res://assets/textures/coins/flexcoin-copper.png")
const TEXTURE_BOMB: Texture2D = preload("res://assets/textures/coins/flexcoin-bomb.png")
const COIN_SCENE: PackedScene = preload("res://scenes/coin.tscn")
const SHIMMER_MIN_INTERVAL: float = 2.0
const SHIMMER_MAX_INTERVAL: float = 4.0
const SHIMMER_FLASH_ALPHA: float = 0.85
const SHIMMER_DURATION: float = 0.25

@export var fall_speed: float = 300.0
var value: int = 1
var coin_type: CoinType = CoinType.COPPER

var _collected: bool = false
var _current_speed: float = 0.0
var _rotation_speed: float = 0.0
var _glow_sprite: Sprite2D
var _shimmer_timer: float = 0.0
var _shimmer_interval: float = 0.0
var _glow_base_alpha: float = 0.0
var _shimmer_tween: Tween
var _split_delay: float = -1.0
var _split_timer: float = 0.0
var _horizontal_speed: float = 0.0
var _trail: CPUParticles2D
var _ember_trail: CPUParticles2D
var _has_fire_trail: bool = false

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("coins")
	value = GameManager.get_coin_value()
	rotation = randf_range(0.0, TAU)
	_rotation_speed = randf_range(-1.5, 1.5)
	_current_speed = fall_speed * 0.15

	if coin_type == CoinType.COPPER:
		sprite.texture = TEXTURE_COPPER
	elif coin_type == CoinType.SILVER:
		sprite.texture = TEXTURE_SILVER
	elif coin_type == CoinType.BOMB:
		sprite.texture = TEXTURE_BOMB
	elif coin_type == CoinType.MULTI:
		sprite.texture = TEXTURE_MULTI

	match coin_type:
		CoinType.COPPER:
			pass
		CoinType.SILVER:
			value *= 2
		CoinType.GOLD:
			value *= 5
			fall_speed *= 1.5
		CoinType.FRENZY:
			value = 0
		CoinType.BOMB:
			value = 0
			fall_speed *= 0.8
		CoinType.MULTI:
			value = 0
			fall_speed *= 0.9
			_split_delay = randf_range(1.5, 2.5)

	_add_glow()
	_add_trail()
	GameManager.shop_opened.connect(func(): set_process(false))
	GameManager.shop_closed.connect(func(): set_process(true))


func _process(delta: float) -> void:
	_current_speed = move_toward(_current_speed, fall_speed, fall_speed * delta * 0.8)
	position.y += _current_speed * delta
	if _horizontal_speed != 0.0:
		position.x += _horizontal_speed * delta
		_horizontal_speed = move_toward(_horizontal_speed, 0.0, 200.0 * delta)
	rotation += _rotation_speed * delta
	if _split_delay > 0.0:
		_split_timer += delta
		var split_progress: float = _split_timer / _split_delay
		if split_progress > 0.4:
			_update_split_buildup(split_progress)
		if _split_timer >= _split_delay:
			_spawn_split_burst()
			_spawn_split_coins()
			queue_free()
			return
	# Counter-rotate fire emitters so fire always rises upward despite coin spin
	if _has_fire_trail:
		if is_instance_valid(_trail):
			_trail.global_rotation = 0.0
		if is_instance_valid(_ember_trail):
			_ember_trail.global_rotation = 0.0
	_shimmer_timer += delta
	if _shimmer_timer >= _shimmer_interval:
		_shimmer_timer = 0.0
		_shimmer_interval = randf_range(SHIMMER_MIN_INTERVAL, SHIMMER_MAX_INTERVAL)
		_trigger_shimmer()


func collect() -> void:
	_collected = true
	if coin_type == CoinType.FRENZY:
		GameManager.start_frenzy()
	elif coin_type == CoinType.BOMB:
		GameManager.trigger_bomb()
	_release_fire_emitters()
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	set_process(false)
	var pop_scale: Vector2 = sprite.scale * 1.4
	var tween := create_tween()
	tween.tween_property(sprite, "scale", pop_scale, 0.07).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", Vector2(0.0, 0.0), 0.09).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.09)
	tween.tween_callback(queue_free)


func _on_screen_exited() -> void:
	_release_fire_emitters()
	if not _collected and coin_type != CoinType.FRENZY and coin_type != CoinType.BOMB and coin_type != CoinType.MULTI:
		GameManager.coin_missed.emit()
	queue_free()


func _add_glow() -> void:
	var glow := Sprite2D.new()
	glow.texture = sprite.texture
	glow.scale = Vector2(0.66, 0.66)
	match coin_type:
		CoinType.COPPER:
			glow.modulate = Color(0.8, 0.5, 0.2, 0.25)
		CoinType.GOLD:
			glow.modulate = Color(1.0, 0.9, 0.3, 0.3)
		CoinType.FRENZY:
			glow.modulate = Color(0.3, 1.0, 0.4, 0.3)
		CoinType.BOMB:
			glow.modulate = Color(1.0, 0.5, 0.1, 0.5)
			glow.scale = Vector2(0.9, 0.9)
		CoinType.MULTI:
			glow.modulate = Color(0.3, 0.85, 1.0, 0.35)
		CoinType.SILVER:
			glow.modulate = Color(1.0, 0.84, 0.0, 0.25)
	glow.z_index = -1
	add_child(glow)
	_glow_sprite = glow
	_glow_base_alpha = glow.modulate.a
	_shimmer_interval = randf_range(SHIMMER_MIN_INTERVAL, SHIMMER_MAX_INTERVAL)
	_shimmer_timer = randf_range(0.0, _shimmer_interval)


func _trigger_shimmer() -> void:
	if not is_instance_valid(_glow_sprite):
		return
	if _shimmer_tween and _shimmer_tween.is_valid():
		_shimmer_tween.kill()
	_shimmer_tween = create_tween()
	var half: float = SHIMMER_DURATION * 0.5
	_shimmer_tween.tween_property(_glow_sprite, "modulate:a", SHIMMER_FLASH_ALPHA, half).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_shimmer_tween.tween_property(_glow_sprite, "modulate:a", _glow_base_alpha, half).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


func _add_trail() -> void:
	var trail := CPUParticles2D.new()
	trail.emitting = true
	trail.amount = 8
	trail.lifetime = 0.5
	trail.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	trail.emission_rect_extents = Vector2(24.0, 4.0)
	trail.direction = Vector2(0, -1)
	trail.spread = 45.0
	trail.initial_velocity_min = 5.0
	trail.initial_velocity_max = 15.0
	trail.gravity = Vector2.ZERO
	trail.scale_amount_min = 0.3
	trail.scale_amount_max = 0.5
	trail.scale_amount_curve = _make_shrink_curve()
	trail.angular_velocity_min = -120.0
	trail.angular_velocity_max = 120.0
	match coin_type:
		CoinType.COPPER:
			trail.texture = preload("res://assets/textures/star_yellow.png")
			trail.color_ramp = _make_sparkle_gradient(Color(0.9, 0.6, 0.3, 0.8), Color(0.7, 0.4, 0.1, 0.0))
		CoinType.GOLD:
			trail.texture = preload("res://assets/textures/star_yellow.png")
			trail.color_ramp = _make_sparkle_gradient(Color(1.0, 0.95, 0.5, 0.9), Color(1.0, 0.85, 0.3, 0.0))
		CoinType.FRENZY:
			trail.texture = preload("res://assets/textures/star_green.png")
			trail.color_ramp = _make_sparkle_gradient(Color(0.4, 1.0, 0.6, 0.9), Color(0.2, 0.9, 0.3, 0.0))
		CoinType.BOMB:
			trail.texture = preload("res://assets/textures/soft_circle.png")
			trail.color_ramp = _make_fire_gradient()
		CoinType.MULTI:
			trail.texture = preload("res://assets/textures/star_blue.png")
			trail.color_ramp = _make_sparkle_gradient(Color(0.3, 0.85, 1.0, 0.9), Color(0.2, 0.7, 1.0, 0.0))
		CoinType.SILVER:
			trail.texture = preload("res://assets/textures/star_yellow.png")
			trail.color_ramp = _make_sparkle_gradient(Color(1.0, 0.9, 0.3, 0.8), Color(1.0, 0.7, 0.1, 0.0))
	# Fire-specific overrides for bomb coins
	if coin_type == CoinType.BOMB:
		trail.amount = 24
		trail.lifetime = 0.8
		trail.emission_rect_extents = Vector2(20.0, 12.0)
		trail.spread = 42.0
		trail.initial_velocity_min = 25.0
		trail.initial_velocity_max = 55.0
		trail.gravity = Vector2(0, -60)
		trail.scale_amount_min = 0.4
		trail.scale_amount_max = 0.7
		trail.scale_amount_curve = _make_fire_scale_curve()
		trail.angular_velocity_min = -15.0
		trail.angular_velocity_max = 15.0
		trail.hue_variation_min = -0.03
		trail.hue_variation_max = 0.05
		trail.damping_min = 5.0
		trail.damping_max = 15.0
		trail.explosiveness = 0.15
		_has_fire_trail = true
	trail.show_behind_parent = true
	add_child(trail)
	_trail = trail
	# Add ember/spark sub-emitter for bomb coins
	if coin_type == CoinType.BOMB:
		_add_ember_trail()


func _make_sparkle_gradient(start: Color, end: Color) -> Gradient:
	var grad := Gradient.new()
	grad.set_color(0, start)
	grad.add_point(0.3, Color(start.r, start.g, start.b, start.a * 0.5))
	grad.add_point(0.6, Color(end.r, end.g, end.b, start.a * 0.3))
	grad.set_color(1, end)
	return grad


func _make_shrink_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(0.3, 0.6))
	curve.add_point(Vector2(1.0, 0.05))
	return curve


func _make_fire_gradient() -> Gradient:
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 0.9, 1.0))  # White-yellow core
	grad.add_point(0.2, Color(1.0, 0.9, 0.3, 0.95))  # Intense yellow
	grad.add_point(0.45, Color(1.0, 0.5, 0.1, 0.8))  # Hot orange
	grad.add_point(0.7, Color(0.8, 0.15, 0.0, 0.5))  # Dark red
	grad.set_color(1, Color(0.4, 0.0, 0.0, 0.0))  # Fades to transparent
	return grad


func _make_fire_scale_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.8))
	curve.add_point(Vector2(0.15, 1.0))
	curve.add_point(Vector2(0.5, 0.5))
	curve.add_point(Vector2(1.0, 0.05))
	return curve


func _add_ember_trail() -> void:
	var embers := CPUParticles2D.new()
	embers.emitting = true
	embers.amount = 8
	embers.lifetime = 1.1
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(12.0, 6.0)
	embers.direction = Vector2(0, -1)
	embers.spread = 45.0
	embers.initial_velocity_min = 15.0
	embers.initial_velocity_max = 40.0
	embers.gravity = Vector2(0, -45)
	embers.scale_amount_min = 0.08
	embers.scale_amount_max = 0.18
	embers.scale_amount_curve = _make_ember_scale_curve()
	embers.angular_velocity_min = -180.0
	embers.angular_velocity_max = 180.0
	embers.damping_min = 8.0
	embers.damping_max = 20.0
	embers.texture = preload("res://assets/textures/star_red.png")
	embers.color_ramp = _make_ember_gradient()
	embers.show_behind_parent = true
	add_child(embers)
	_ember_trail = embers


func _make_ember_gradient() -> Gradient:
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.9, 0.4, 1.0))  # Bright yellow-white spark
	grad.add_point(0.3, Color(1.0, 0.6, 0.1, 0.9))  # Orange
	grad.add_point(0.7, Color(1.0, 0.3, 0.0, 0.6))  # Red-orange
	grad.set_color(1, Color(0.5, 0.1, 0.0, 0.0))  # Fades out
	return grad


func _make_ember_scale_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(0.6, 0.8))
	curve.add_point(Vector2(1.0, 0.0))
	return curve


func _release_fire_emitters() -> void:
	if not _has_fire_trail:
		return
	var parent: Node = get_parent()
	if not is_instance_valid(parent):
		return
	if is_instance_valid(_trail):
		_trail.emitting = false
		var trail_pos: Vector2 = _trail.global_position
		remove_child(_trail)
		parent.add_child(_trail)
		_trail.global_position = trail_pos
		get_tree().create_timer(_trail.lifetime).timeout.connect(_trail.queue_free)
		_trail = null
	if is_instance_valid(_ember_trail):
		_ember_trail.emitting = false
		var ember_pos: Vector2 = _ember_trail.global_position
		remove_child(_ember_trail)
		parent.add_child(_ember_trail)
		_ember_trail.global_position = ember_pos
		get_tree().create_timer(_ember_trail.lifetime).timeout.connect(_ember_trail.queue_free)
		_ember_trail = null


func _update_split_buildup(progress: float) -> void:
	# Ramp from 0.0 at progress=0.4 to 1.0 at progress=1.0
	var t: float = clampf((progress - 0.4) / 0.6, 0.0, 1.0)
	# Pulsing glow — faster and brighter as split approaches
	var pulse_speed: float = lerpf(6.0, 30.0, t)
	var pulse_alpha: float = lerpf(_glow_base_alpha, 1.0, t)
	if is_instance_valid(_glow_sprite):
		var pulse: float = (sin(_split_timer * pulse_speed) + 1.0) * 0.5
		_glow_sprite.modulate.a = lerpf(_glow_base_alpha, pulse_alpha, pulse)
		_glow_sprite.scale = Vector2.ONE * lerpf(0.66, 1.44, t * pulse)
	# Coin shakes with increasing intensity
	if t > 0.3:
		var shake: float = lerpf(0.0, 5.0, (t - 0.3) / 0.7)
		sprite.position = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	# Final flash — coin goes white-hot in the last 15%
	if t > 0.85:
		var flash: float = (t - 0.85) / 0.15
		modulate = Color(1.0, 1.0, 1.0, lerpf(1.0, 1.5, flash))


func _spawn_split_burst() -> void:
	var burst := CPUParticles2D.new()
	burst.emitting = true
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 32
	burst.lifetime = 0.7
	burst.direction = Vector2(0, -1)
	burst.spread = 360.0
	burst.initial_velocity_min = 120.0
	burst.initial_velocity_max = 300.0
	burst.gravity = Vector2(0, 100)
	burst.texture = preload("res://assets/textures/star_blue.png")
	burst.scale_amount_min = 0.1
	burst.scale_amount_max = 0.25
	burst.color_ramp = _make_sparkle_gradient(Color(1.0, 1.0, 1.0, 1.0), Color(0.3, 0.85, 1.0, 0.0))
	burst.position = global_position
	burst.z_index = 15
	get_parent().add_child(burst)
	get_tree().create_timer(burst.lifetime + 0.1).timeout.connect(burst.queue_free)


func _spawn_split_coins() -> void:
	for i: int in range(3):
		var angle: float = randf_range(0.0, TAU)
		var split: Area2D = COIN_SCENE.instantiate()
		split.coin_type = CoinType.SILVER
		split.position = global_position
		split.scale = Vector2(0.78, 0.78)
		get_parent().add_child(split)
		split.sprite.texture = TEXTURE_MULTI
		if split._trail:
			split._trail.scale_amount_min *= 0.5
			split._trail.scale_amount_max *= 0.5
			split._trail.amount = 5
		split._current_speed = randf_range(-300.0, -100.0)
		split._horizontal_speed = cos(angle) * randf_range(200.0, 400.0)
