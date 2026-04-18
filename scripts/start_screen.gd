extends Node2D

const COIN_COUNT: int = 720
const COIN_TEXTURE_GOLD: Texture2D = preload("res://assets/textures/coins/flexcoin.png")
const COIN_TEXTURE_SILVER: Texture2D = preload("res://assets/textures/coins/flexcoin-silver.png")
const COIN_TEXTURE_COPPER: Texture2D = preload("res://assets/textures/coins/flexcoin-copper.png")
const SOFT_CIRCLE_TEXTURE: Texture2D = preload("res://assets/textures/soft_circle.png")
const LOGO_TEXTURE: Texture2D = preload("res://assets/textures/logo.png")
const STAR_TEXTURE: Texture2D = preload("res://assets/textures/star_yellow.png")
const DISPLAY_FONT: Font = preload("res://assets/fonts/kenney_future.ttf")
const MIN_SPEED: float = 60.0
const MAX_SPEED: float = 160.0
const OFFSCREEN_BUFFER: float = 200.0

var _coins: Array[Sprite2D] = []
var _coin_speeds: Array[float] = []
var _coin_rotation_speeds: Array[float] = []
var _fade_overlay: ColorRect
var _transitioning: bool = false
var _click_sound: AudioStreamPlayer

var _bg_container: Node2D
var _orb_container: Node2D
var _coin_container: Node2D
var _logo_container: Node2D
var _sparkle_particles: CPUParticles2D


func _ready() -> void:
	var vp_size: Vector2 = get_viewport_rect().size

	_bg_container = Node2D.new()
	add_child(_bg_container)

	_orb_container = Node2D.new()
	add_child(_orb_container)

	_coin_container = Node2D.new()
	add_child(_coin_container)

	_logo_container = Node2D.new()
	_logo_container.z_index = 5
	add_child(_logo_container)

	_sparkle_particles = CPUParticles2D.new()
	_sparkle_particles.z_index = 8
	add_child(_sparkle_particles)

	_create_background(vp_size)
	_create_glow_orbs()
	_create_coins(vp_size)
	_create_logo_area()
	_setup_sparkle_particles()

	# Click sound
	_click_sound = AudioStreamPlayer.new()
	_click_sound.stream = preload("res://assets/sounds/click-b.ogg")
	_click_sound.volume_db = -10.0
	add_child(_click_sound)

	# Control in Node2D: layout disabled, using explicit position (fixed viewport)
	_fade_overlay = ColorRect.new()
	_fade_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_overlay.position = Vector2.ZERO
	_fade_overlay.size = vp_size
	_fade_overlay.z_index = 100
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade_overlay)

	# Entrance animation: fade in elements sequentially
	_bg_container.modulate.a = 0.0
	_orb_container.modulate.a = 0.0
	_coin_container.modulate.a = 0.0
	_logo_container.modulate.a = 0.0
	_sparkle_particles.emitting = false

	var entrance_tween: Tween = create_tween()
	entrance_tween.tween_property(_bg_container, "modulate:a", 1.0, 0.5)
	entrance_tween.tween_property(_orb_container, "modulate:a", 1.0, 0.5).set_delay(0.3)
	entrance_tween.parallel().tween_property(_coin_container, "modulate:a", 1.0, 0.5).set_delay(0.6)
	entrance_tween.parallel().tween_property(_logo_container, "modulate:a", 1.0, 0.5).set_delay(0.9)
	entrance_tween.tween_callback(func() -> void: _sparkle_particles.emitting = true).set_delay(1.5)


func _process(delta: float) -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	for i: int in range(_coins.size()):
		var coin: Sprite2D = _coins[i]
		coin.position.y += _coin_speeds[i] * delta
		coin.rotation += _coin_rotation_speeds[i] * delta
		if coin.position.y > vp_size.y + OFFSCREEN_BUFFER:
			coin.position.y = -OFFSCREEN_BUFFER
			coin.position.x = randf_range(-80.0, vp_size.x + 80.0)


func _unhandled_input(event: InputEvent) -> void:
	if _transitioning:
		return

	var should_transition: bool = false

	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			should_transition = true
	elif event is InputEventKey:
		if event.pressed and not event.echo:
			if event.keycode in [KEY_ENTER, KEY_SPACE, KEY_KP_ENTER]:
				should_transition = true
	elif event is InputEventScreenTouch:
		if event.pressed:
			should_transition = true
	elif event is InputEventJoypadButton:
		if event.pressed:
			should_transition = true

	if should_transition:
		_transitioning = true
		set_process(false)
		_click_sound.play()
		var fade_tween: Tween = create_tween()
		fade_tween.tween_property(_fade_overlay, "color:a", 1.0, 0.5)
		fade_tween.tween_callback(_go_to_main)


func _create_background(vp_size: Vector2) -> void:
	# Navy base
	var base: ColorRect = ColorRect.new()
	base.color = Color(0.122, 0.161, 0.216)
	base.position = Vector2.ZERO
	base.size = vp_size
	base.z_index = -10
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_container.add_child(base)

	# Breathing overlay
	var breathing: ColorRect = ColorRect.new()
	breathing.color = Color(0.05, 0.08, 0.15)
	breathing.position = Vector2.ZERO
	breathing.size = vp_size
	breathing.modulate.a = 0.0
	breathing.z_index = -9
	breathing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_container.add_child(breathing)

	var breathing_tween: Tween = create_tween().set_loops()
	breathing_tween.tween_property(breathing, "modulate:a", 0.3, 3.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	breathing_tween.tween_property(breathing, "modulate:a", 0.0, 3.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	# Upper glow wash
	var glow_wash: Sprite2D = Sprite2D.new()
	glow_wash.texture = SOFT_CIRCLE_TEXTURE
	glow_wash.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	glow_wash.position = Vector2(1080.0, 150.0)
	glow_wash.scale = Vector2(18.0, 10.0)
	glow_wash.modulate = Color(0.082, 0.373, 0.784, 0.15)
	glow_wash.z_index = -8
	_bg_container.add_child(glow_wash)

	var wash_tween: Tween = create_tween().set_loops()
	wash_tween.tween_property(glow_wash, "position:y", 250.0, 4.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	wash_tween.tween_property(glow_wash, "position:y", 150.0, 4.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _create_glow_orbs() -> void:
	var orb_data: Array[Dictionary] = [
		{"pos": Vector2(400.0, 900.0), "scale": Vector2(8.0, 8.0), "color": Color(0.878, 0.373, 0.102, 0.08), "duration": 10.0},
		{"pos": Vector2(1700.0, 300.0), "scale": Vector2(10.0, 10.0), "color": Color(0.082, 0.373, 0.784, 0.10), "duration": 12.0},
		{"pos": Vector2(1080.0, 640.0), "scale": Vector2(14.0, 14.0), "color": Color(0.980, 0.682, 0.231, 0.06), "duration": 14.0},
		{"pos": Vector2(300.0, 200.0), "scale": Vector2(6.0, 6.0), "color": Color(0.231, 0.698, 0.451, 0.05), "duration": 9.0},
		{"pos": Vector2(1800.0, 900.0), "scale": Vector2(7.0, 7.0), "color": Color(0.980, 0.682, 0.231, 0.07), "duration": 11.0},
		{"pos": Vector2(600.0, 400.0), "scale": Vector2(9.0, 9.0), "color": Color(0.082, 0.373, 0.784, 0.06), "duration": 13.0},
	]

	for data: Dictionary in orb_data:
		var base_pos: Vector2 = data["pos"] as Vector2
		var dur: float = data["duration"] as float

		var orb: Sprite2D = Sprite2D.new()
		orb.texture = SOFT_CIRCLE_TEXTURE
		orb.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		orb.position = base_pos + Vector2(-60.0, -60.0)
		orb.scale = data["scale"] as Vector2
		orb.modulate = data["color"] as Color
		orb.z_index = -5
		_orb_container.add_child(orb)

		# Position drift
		var drift_tween: Tween = create_tween().set_loops()
		drift_tween.tween_property(orb, "position:x", base_pos.x + 60.0, dur / 2.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		drift_tween.tween_property(orb, "position:x", base_pos.x - 60.0, dur / 2.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

		var drift_y_tween: Tween = create_tween().set_loops()
		drift_y_tween.tween_property(orb, "position:y", base_pos.y + 60.0, dur / 2.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		drift_y_tween.tween_property(orb, "position:y", base_pos.y - 60.0, dur / 2.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

		# Alpha pulse
		var base_alpha: float = (data["color"] as Color).a
		var alpha_tween: Tween = create_tween().set_loops()
		alpha_tween.tween_property(orb, "modulate:a", base_alpha + 0.02, 3.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		alpha_tween.tween_property(orb, "modulate:a", base_alpha - 0.02, 3.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _create_coins(vp_size: Vector2) -> void:
	for i: int in range(COIN_COUNT):
		var coin: Sprite2D = Sprite2D.new()
		coin.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		coin.position = Vector2(randf_range(-80.0, vp_size.x + 80.0), randf_range(-OFFSCREEN_BUFFER, vp_size.y))
		coin.rotation = randf_range(0.0, TAU)

		var tex_roll: float = randf()
		if tex_roll < 0.4:
			coin.texture = COIN_TEXTURE_COPPER
		elif tex_roll < 0.75:
			coin.texture = COIN_TEXTURE_SILVER
		else:
			coin.texture = COIN_TEXTURE_GOLD

		coin.scale = Vector2(2.0, 2.0)

		var speed: float = randf_range(MIN_SPEED, MAX_SPEED)
		var rot_speed: float = randf_range(-1.0, 1.0)

		_coin_container.add_child(coin)
		_coins.append(coin)
		_coin_speeds.append(speed)
		_coin_rotation_speeds.append(rot_speed)


func _create_logo_area() -> void:
	var logo_size: Vector2 = Vector2(2160.0, 800.0)
	var label_size: Vector2 = Vector2(2160.0, 80.0)

	# Bob animation on the container
	var bob_tween: Tween = create_tween().set_loops()
	bob_tween.tween_property(_logo_container, "position:y", -10.0, 2.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	bob_tween.tween_property(_logo_container, "position:y", 10.0, 2.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	# Dark scrim behind logo for readability
	var scrim: Sprite2D = Sprite2D.new()
	scrim.texture = SOFT_CIRCLE_TEXTURE
	scrim.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	scrim.position = Vector2(1080.0, 560.0)
	scrim.scale = Vector2(30.0, 18.0)
	scrim.modulate = Color(0.0, 0.0, 0.0, 0.90)
	scrim.z_index = 4
	_logo_container.add_child(scrim)

	# Logo glow halo
	var halo: Sprite2D = Sprite2D.new()
	halo.texture = SOFT_CIRCLE_TEXTURE
	halo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	halo.position = Vector2(1080.0, 500.0)
	halo.scale = Vector2(18.0, 9.0)
	halo.modulate = Color(0.98, 0.682, 0.231, 0.18)
	halo.z_index = 5
	_logo_container.add_child(halo)

	# Halo alpha pulse
	var halo_alpha_tween: Tween = create_tween().set_loops()
	halo_alpha_tween.tween_property(halo, "modulate:a", 0.24, 1.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	halo_alpha_tween.tween_property(halo, "modulate:a", 0.14, 1.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	# Halo scale pulse
	var halo_scale_tween: Tween = create_tween().set_loops()
	halo_scale_tween.tween_property(halo, "scale", Vector2(19.0, 9.5), 1.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	halo_scale_tween.tween_property(halo, "scale", Vector2(18.0, 9.0), 1.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	# Control in Node2D: layout disabled, using explicit position (fixed viewport)
	var logo_wrapper: Control = Control.new()
	logo_wrapper.position = Vector2(0.0, 100.0)
	logo_wrapper.size = logo_size
	logo_wrapper.z_index = 6
	logo_wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo_container.add_child(logo_wrapper)

	var logo_rect: TextureRect = TextureRect.new()
	logo_rect.texture = LOGO_TEXTURE
	logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	logo_rect.custom_minimum_size = logo_size
	logo_rect.size = logo_size
	logo_rect.position = Vector2.ZERO
	logo_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo_wrapper.add_child(logo_rect)

	# Control in Node2D: layout disabled, using explicit position (fixed viewport)
	var label_wrapper: Control = Control.new()
	label_wrapper.position = Vector2(0.0, 850.0)
	label_wrapper.size = label_size
	label_wrapper.z_index = 7
	label_wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo_container.add_child(label_wrapper)

	var tap_label: Label = Label.new()
	tap_label.text = "Continue"
	tap_label.add_theme_font_override("font", DISPLAY_FONT)
	tap_label.add_theme_font_size_override("font_size", 48)
	tap_label.add_theme_color_override("font_color", Color(0.98, 0.682, 0.231))
	tap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tap_label.size = label_size
	tap_label.position = Vector2.ZERO
	tap_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_wrapper.add_child(tap_label)

	# Label pulse
	var pulse_tween: Tween = create_tween().set_loops()
	pulse_tween.tween_property(tap_label, "modulate:a", 0.5, 1.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	pulse_tween.tween_property(tap_label, "modulate:a", 1.0, 1.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _setup_sparkle_particles() -> void:
	_sparkle_particles.position = Vector2(1080.0, 640.0)
	_sparkle_particles.emitting = false
	_sparkle_particles.amount = 30
	_sparkle_particles.lifetime = 3.0
	_sparkle_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_sparkle_particles.emission_rect_extents = Vector2(1100.0, 660.0)
	_sparkle_particles.direction = Vector2(0.0, -1.0)
	_sparkle_particles.spread = 180.0
	_sparkle_particles.initial_velocity_min = 5.0
	_sparkle_particles.initial_velocity_max = 15.0
	_sparkle_particles.gravity = Vector2.ZERO
	_sparkle_particles.scale_amount_min = 0.3
	_sparkle_particles.scale_amount_max = 0.6
	_sparkle_particles.angular_velocity_min = -90.0
	_sparkle_particles.angular_velocity_max = 90.0
	_sparkle_particles.texture = STAR_TEXTURE

	# Color ramp
	var gradient: Gradient = Gradient.new()
	gradient.set_offset(0, 0.0)
	gradient.set_color(0, Color(1.0, 0.95, 0.5, 0.7))
	gradient.set_offset(1, 1.0)
	gradient.set_color(1, Color(1.0, 0.85, 0.3, 0.0))
	_sparkle_particles.color_ramp = gradient


func _go_to_main() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")
