extends Area2D

@export var floating_text_scene: PackedScene

const BURST_COLORS: Dictionary = {
	0: Color(0.8, 0.5, 0.2, 0.9),    # COPPER -> copper brown
	1: Color(1.0, 0.84, 0.0, 0.9),   # SILVER -> gold
	2: Color(1.0, 0.95, 0.4, 0.9),   # GOLD -> bright yellow
	3: Color(0.3, 1.0, 0.4, 0.9),    # FRENZY -> green
	4: Color(1.0, 0.2, 0.1, 0.9),    # BOMB -> red
	5: Color(0.3, 0.85, 1.0, 0.9),   # MULTI -> cyan
}
const BURST_TEXTURES: Dictionary = {
	0: preload("res://assets/textures/star_yellow.png"),
	1: preload("res://assets/textures/star_yellow.png"),
	2: preload("res://assets/textures/star_yellow.png"),
	3: preload("res://assets/textures/star_green.png"),
	4: preload("res://assets/textures/star_red.png"),
	5: preload("res://assets/textures/star_blue.png"),
}
const TRAIL_TEXTURE_BLUE: Texture2D = preload("res://assets/textures/star_blue.png")
const TRAIL_TEXTURE_GREEN: Texture2D = preload("res://assets/textures/star_green.png")

const MAX_COMBO_PITCH: float = 2.0
const PITCH_STEP: float = 0.08
const COMBO_MULTIPLIER_50: float = 1.5
const COMBO_MULTIPLIER_100: float = 2.0
const COMBO_THRESHOLD_50: int = 50
const COMBO_THRESHOLD_100: int = 100
const BOOST_TWEEN_DURATION: float = 0.12
const COOLDOWN_BAR_HEIGHT: float = 4.0
const COOLDOWN_BAR_Y_OFFSET: float = 14.0
const COOLDOWN_COLOR_ACTIVE := Color(0.878, 0.373, 0.102, 0.8)
const COOLDOWN_COLOR_READY := Color(0.231, 0.698, 0.451, 0.8)
const COOLDOWN_COLOR_BG := Color(0.294, 0.333, 0.388, 0.3)
const AUTO_DEADZONE: float = 10.0
const AUTO_BOOST_MIN_DIST_RATIO: float = 0.5
const AUTO_BOOST_DANGER_ZONE_Y: float = 0.6
const COIN_SCRIPT: GDScript = preload("res://scripts/coin.gd")
var speed: float = 600.0

var _prev_x: float = 0.0
var _trail_particles: CPUParticles2D
var _combo: int = 0
var _combo_multiplier: float = 1.0
var _bomb_shrink_active: bool = false
var _catcher_tier: int = -1
var _rainbow_time: float = 0.0
var _game_paused: bool = false
var _frenzy_active: bool = false
var _base_scale: Vector2 = Vector2.ONE
var _squash_tween: Tween
var _last_move_direction: float = 1.0
var _boost_cooldown_remaining: float = 0.0
var _boost_active: bool = false
var _boost_tween: Tween
var _cooldown_bar: ColorRect
var _cooldown_bar_bg: ColorRect
var _cooldown_hide_tween: Tween

const SPRITE_NATIVE_W: float = 128.0
const SPRITE_NATIVE_H: float = 8.0
const CATCHER_HEIGHT: float = 20.0
const CATCHER_BOTTOM_OFFSET: float = 240.0
const BOMB_SHRINK_FACTOR: float = 0.6

@onready var sprite: Sprite2D = $Sprite2D
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
	var vp_size: Vector2 = get_viewport_rect().size
	position.x = vp_size.x / 2.0
	position.y = vp_size.y - CATCHER_BOTTOM_OFFSET
	_prev_x = position.x
	_setup_trail()
	_setup_cooldown_bar()
	GameManager.coin_missed.connect(_on_coin_missed)
	GameManager.bomb_hit.connect(_on_bomb_hit)
	GameManager.shop_opened.connect(_on_shop_opened)
	GameManager.shop_closed.connect(_on_shop_closed)
	GameManager.frenzy_started.connect(_on_frenzy_started)
	GameManager.frenzy_ended.connect(_on_frenzy_ended)


func _process(delta: float) -> void:
	if _game_paused:
		return
	if not _boost_active:
		var direction: float = 0.0
		var auto_target: Node = null
		if GameManager.auto_mode_active:
			auto_target = _get_auto_target_coin()
			if auto_target:
				var diff: float = auto_target.position.x - position.x
				direction = 0.0 if absf(diff) < AUTO_DEADZONE else signf(diff)
		else:
			direction = Input.get_axis("move_left", "move_right")
		if direction != 0.0:
			_last_move_direction = direction
		var half_width := GameManager.get_catcher_width() / 2.0
		var viewport_width := get_viewport_rect().size.x
		var unclamped_x := position.x + direction * speed * delta
		position.x = clamp(unclamped_x, half_width, viewport_width - half_width)
		if unclamped_x != position.x:
			scale = Vector2.ONE
		# Auto-boost: dash toward distant coins in danger zone
		if GameManager.auto_mode_active and auto_target and _should_auto_boost(auto_target):
			var boost_dir: float = signf(auto_target.position.x - position.x)
			_try_boost(boost_dir)

	# Motion trail intensity based on speed
	var velocity := absf(position.x - _prev_x) / delta
	_prev_x = position.x
	var speed_ratio := clampf(velocity / speed, 0.0, 1.0)
	if _trail_particles:
		_trail_particles.emitting = speed_ratio > 0.3
		if _frenzy_active:
			_trail_particles.amount = int(lerpf(8.0, 20.0, speed_ratio))
		else:
			_trail_particles.amount = int(lerpf(3.0, 12.0, speed_ratio))

	# Reset to base scale when no squash is active
	if not (_squash_tween and _squash_tween.is_running()):
		sprite.scale = _base_scale

	_update_cooldown(delta)

	# Rainbow animation for tier 3+
	if _catcher_tier >= 3:
		_rainbow_time += delta * 1.5
		sprite.modulate = Color.from_hsv(fmod(_rainbow_time, 1.0), 0.7, 0.9)


func _on_area_entered(area: Area2D) -> void:
	if area.has_method("collect") and not area.get("_collected"):
		area._collected = true
		var value: int = area.value
		var pos: Vector2 = area.global_position
		_combo += 1
		bling_sound.pitch_scale = minf(1.0 + (_combo - 1) * PITCH_STEP, MAX_COMBO_PITCH)

		# Update combo multiplier based on threshold and apply via GameManager
		_update_combo_multiplier()

		# Coin value is now multiplied in GameManager.get_coin_value()
		GameManager.coin_collected.emit(value, pos)
		GameManager.combo_changed.emit(_combo)
		_spawn_floating_text(pos, value, area.coin_type)
		_spawn_collect_burst(pos, area.coin_type)
		_squash_bounce()
		bling_sound.play()
		area.collect()


func _on_upgrade_purchased(_upgrade_id: String) -> void:
	_apply_upgrades()


func _apply_upgrades() -> void:
	speed = GameManager.get_catcher_speed()
	var w := GameManager.get_catcher_width()
	_base_scale = Vector2(w / SPRITE_NATIVE_W, CATCHER_HEIGHT / SPRITE_NATIVE_H)
	sprite.scale = _base_scale
	collision_shape.shape.size = Vector2(w, CATCHER_HEIGHT)
	_update_catcher_visual()
	if _cooldown_bar_bg:
		_cooldown_bar_bg.size.x = w
		_cooldown_bar_bg.position.x = -w / 2.0
		_cooldown_bar.size.x = w
		_cooldown_bar.position.x = -w / 2.0


func _update_catcher_visual() -> void:
	var level: int = GameManager.get_upgrade_level("catcher_width")
	var new_tier: int = level / 10
	if new_tier == _catcher_tier:
		return
	_catcher_tier = new_tier

	match _catcher_tier:
		0:
			sprite.modulate = Color(0.29, 0.56, 0.85, 1.0)
		1:
			sprite.modulate = Color(0.55, 0.35, 0.17, 1.0)
		2:
			sprite.modulate = Color(0.7, 0.72, 0.75, 1.0)
		_:
			# Rainbow (animated in _process)
			sprite.modulate = Color.WHITE


func _squash_bounce() -> void:
	if _squash_tween and _squash_tween.is_running():
		_squash_tween.kill()
	_squash_tween = create_tween()
	_squash_tween.tween_property(sprite, "scale", _base_scale * Vector2(1.2, 0.7), 0.06).set_ease(Tween.EASE_OUT)
	_squash_tween.tween_property(sprite, "scale", _base_scale * Vector2(0.95, 1.1), 0.08).set_ease(Tween.EASE_OUT)
	_squash_tween.tween_property(sprite, "scale", _base_scale, 0.1).set_ease(Tween.EASE_IN_OUT)



func _spawn_floating_text(at_position: Vector2, value: int, coin_type: int = 0) -> void:
	if value == 0:
		return
	if floating_text_scene:
		var ft: Label = floating_text_scene.instantiate()
		ft.text = "+%d" % value
		ft.coin_type = coin_type
		if _combo_multiplier >= 2.0:
			ft.combo_level = 2
		elif _combo_multiplier >= 1.5:
			ft.combo_level = 1
		else:
			ft.combo_level = 0
		ft.position = at_position + Vector2(randf_range(-10.0, 10.0), -10.0)
		ft.z_index = 250
		get_parent().add_child(ft)


func _spawn_collect_burst(at_position: Vector2, coin_type: int = 0) -> void:
	var burst := CPUParticles2D.new()
	burst.emitting = true
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.lifetime = 0.5
	burst.direction = Vector2(0, -1)
	burst.gravity = Vector2(0, 200)
	burst.position = at_position
	burst.z_index = 15
	burst.color = BURST_COLORS.get(coin_type, BURST_COLORS[0])
	if BURST_TEXTURES.has(coin_type):
		burst.texture = BURST_TEXTURES[coin_type]
		burst.scale_amount_min = 0.1
		burst.scale_amount_max = 0.25
	else:
		burst.scale_amount_min = 2.0
		burst.scale_amount_max = 5.0
	# Per-type tuning
	match coin_type:
		2:  # GOLD — more particles
			burst.amount = 18
			burst.spread = 180.0
			burst.initial_velocity_min = 80.0
			burst.initial_velocity_max = 180.0
		3:  # FRENZY — faster burst
			burst.amount = 12
			burst.spread = 180.0
			burst.initial_velocity_min = 120.0
			burst.initial_velocity_max = 250.0
		4:  # BOMB — wider spread, heavier gravity
			burst.amount = 12
			burst.spread = 360.0
			burst.initial_velocity_min = 60.0
			burst.initial_velocity_max = 200.0
			burst.gravity = Vector2(0, 400)
		5:  # MULTI — wide cyan burst
			burst.amount = 20
			burst.spread = 360.0
			burst.initial_velocity_min = 100.0
			burst.initial_velocity_max = 220.0
		_:  # COPPER/SILVER — default
			burst.amount = 12
			burst.spread = 180.0
			burst.initial_velocity_min = 80.0
			burst.initial_velocity_max = 180.0
	get_parent().add_child(burst)
	get_tree().create_timer(burst.lifetime + 0.1).timeout.connect(burst.queue_free)



func _on_coin_missed() -> void:
	_combo = 0
	_reset_combo_multiplier()
	GameManager.combo_changed.emit(0)
	bling_sound.pitch_scale = 1.0


func _on_bomb_hit() -> void:
	if _bomb_shrink_active:
		return
	_bomb_shrink_active = true
	# Reset combo and multiplier on bomb hit (hard reset)
	_combo = 0
	_reset_combo_multiplier()
	GameManager.combo_changed.emit(0)
	# Shrink to 60% width
	var normal_w := GameManager.get_catcher_width()
	var shrunk_w := normal_w * BOMB_SHRINK_FACTOR
	_base_scale = Vector2(shrunk_w / SPRITE_NATIVE_W, CATCHER_HEIGHT / SPRITE_NATIVE_H)
	sprite.scale = _base_scale
	collision_shape.shape.size = Vector2(shrunk_w, CATCHER_HEIGHT)
	# Flash red (restore happens via _apply_upgrades after timer)
	sprite.modulate = Color(1.0, 0.2, 0.1, 1.0)
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
	_trail_particles.texture = TRAIL_TEXTURE_BLUE
	_trail_particles.scale_amount_min = 0.08
	_trail_particles.scale_amount_max = 0.15
	_trail_particles.color = Color(0.4, 0.65, 1.0, 0.4)
	add_child(_trail_particles)


func _on_frenzy_started() -> void:
	_frenzy_active = true
	if _trail_particles:
		_trail_particles.texture = TRAIL_TEXTURE_GREEN
		_trail_particles.color = Color(0.3, 1.0, 0.4, 0.6)
		_trail_particles.lifetime = 0.5


func _on_frenzy_ended() -> void:
	_frenzy_active = false
	if _trail_particles:
		_trail_particles.texture = TRAIL_TEXTURE_BLUE
		_trail_particles.color = Color(0.4, 0.65, 1.0, 0.4)
		_trail_particles.lifetime = 0.3


func _on_shop_opened() -> void:
	_game_paused = true
	monitoring = false


func _on_shop_closed() -> void:
	_game_paused = false
	monitoring = true



func _unhandled_input(event: InputEvent) -> void:
	if _game_paused:
		return
	if event.is_action_pressed("boost"):
		var direction := Input.get_axis("move_left", "move_right")
		if direction == 0.0:
			direction = _last_move_direction
		_try_boost(direction)


func _try_boost(direction: float) -> void:
	if _boost_cooldown_remaining > 0.0:
		return
	if _boost_active:
		return
	_boost_active = true
	var boost_dist: float = GameManager.get_boost_distance()
	var half_width: float = GameManager.get_catcher_width() / 2.0
	if _bomb_shrink_active:
		half_width = GameManager.get_catcher_width() * BOMB_SHRINK_FACTOR / 2.0
	var viewport_width: float = get_viewport_rect().size.x
	var target_x: float = clampf(
		position.x + direction * boost_dist,
		half_width,
		viewport_width - half_width
	)
	if _boost_tween and _boost_tween.is_running():
		_boost_tween.kill()
	_boost_tween = create_tween()
	_boost_tween.tween_property(self, "position:x", target_x, BOOST_TWEEN_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_boost_tween.tween_callback(_on_boost_finished)
	_boost_cooldown_remaining = GameManager.BOOST_COOLDOWN
	_show_cooldown_bar()
	_squash_bounce()
	GameManager.boost_used.emit()


func _on_boost_finished() -> void:
	_boost_active = false
	var half_width: float = GameManager.get_catcher_width() / 2.0
	if _bomb_shrink_active:
		half_width = GameManager.get_catcher_width() * BOMB_SHRINK_FACTOR / 2.0
	var viewport_width: float = get_viewport_rect().size.x
	position.x = clampf(position.x, half_width, viewport_width - half_width)


func _update_cooldown(delta: float) -> void:
	if _boost_cooldown_remaining <= 0.0:
		return
	_boost_cooldown_remaining -= delta
	if _boost_cooldown_remaining <= 0.0:
		_boost_cooldown_remaining = 0.0
		_hide_cooldown_bar()
		GameManager.boost_ready.emit()
	else:
		_update_cooldown_bar_width()


func _setup_cooldown_bar() -> void:
	_cooldown_bar_bg = ColorRect.new()
	_cooldown_bar_bg.color = COOLDOWN_COLOR_BG
	_cooldown_bar_bg.size = Vector2(GameManager.get_catcher_width(), COOLDOWN_BAR_HEIGHT)
	_cooldown_bar_bg.position = Vector2(-GameManager.get_catcher_width() / 2.0, COOLDOWN_BAR_Y_OFFSET)
	_cooldown_bar_bg.visible = false
	add_child(_cooldown_bar_bg)

	_cooldown_bar = ColorRect.new()
	_cooldown_bar.color = COOLDOWN_COLOR_ACTIVE
	_cooldown_bar.size = Vector2(GameManager.get_catcher_width(), COOLDOWN_BAR_HEIGHT)
	_cooldown_bar.position = Vector2(-GameManager.get_catcher_width() / 2.0, COOLDOWN_BAR_Y_OFFSET)
	_cooldown_bar.visible = false
	add_child(_cooldown_bar)


func _show_cooldown_bar() -> void:
	if _cooldown_hide_tween and _cooldown_hide_tween.is_running():
		_cooldown_hide_tween.kill()
	_cooldown_bar_bg.modulate.a = 1.0
	_cooldown_bar.modulate.a = 1.0
	_cooldown_bar_bg.visible = true
	_cooldown_bar.visible = true
	_cooldown_bar.color = COOLDOWN_COLOR_ACTIVE
	_update_cooldown_bar_width()


func _hide_cooldown_bar() -> void:
	_cooldown_bar.color = COOLDOWN_COLOR_READY
	if _cooldown_hide_tween and _cooldown_hide_tween.is_running():
		_cooldown_hide_tween.kill()
	var tween := create_tween()
	_cooldown_hide_tween = tween
	tween.tween_interval(0.2)
	tween.tween_property(_cooldown_bar, "modulate:a", 0.0, 0.15)
	tween.parallel().tween_property(_cooldown_bar_bg, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func() -> void:
		_cooldown_bar.visible = false
		_cooldown_bar_bg.visible = false
		_cooldown_bar.modulate.a = 1.0
		_cooldown_bar_bg.modulate.a = 1.0
	)


func _update_cooldown_bar_width() -> void:
	var current_w: float = GameManager.get_catcher_width()
	if _bomb_shrink_active:
		current_w *= BOMB_SHRINK_FACTOR
	var ratio: float = _boost_cooldown_remaining / GameManager.BOOST_COOLDOWN
	_cooldown_bar_bg.size.x = current_w
	_cooldown_bar_bg.position.x = -current_w / 2.0
	_cooldown_bar.size.x = current_w * ratio
	_cooldown_bar.position.x = -current_w / 2.0


func _get_auto_target_coin() -> Node:
	var best_coin: Node = null
	var best_y: float = -INF
	var bomb_type: int = COIN_SCRIPT.CoinType.BOMB
	for node: Node in get_tree().get_nodes_in_group("coins"):
		if node.get("_collected"):
			continue
		var ct: Variant = node.get("coin_type")
		if ct != null and int(ct) == bomb_type:
			continue
		if node.position.y > best_y:
			best_y = node.position.y
			best_coin = node
	return best_coin


func _should_auto_boost(coin: Node) -> bool:
	if _boost_active or _boost_cooldown_remaining > 0.0:
		return false
	if _bomb_shrink_active:
		return false
	if GameManager.get_upgrade_level("boost_power") <= 0:
		return false
	var dist: float = absf(coin.position.x - position.x)
	var boost_dist: float = GameManager.get_boost_distance()
	if dist < boost_dist * AUTO_BOOST_MIN_DIST_RATIO:
		return false
	var viewport_h: float = get_viewport_rect().size.y
	if coin.position.y < viewport_h * AUTO_BOOST_DANGER_ZONE_Y:
		return false
	return true
