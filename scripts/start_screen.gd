extends Node2D

const COIN_COUNT: int = 360
const COIN_TEXTURE_GOLD: Texture2D = preload("res://flexcoin.png")
const COIN_TEXTURE_SILVER: Texture2D = preload("res://flexcoin-silver.png")
const COIN_TEXTURE_COPPER: Texture2D = preload("res://flexcoin-copper.png")
const LOGO_TEXTURE: Texture2D = preload("res://logo.png")
const DISPLAY_FONT: Font = preload("res://assets/fonts/kenney_future.ttf")
const COIN_SCALE_GOLD: float = 2.0       # 128 * 2.0 = 256px (5x normal)
const COIN_SCALE_LARGE: float = 0.25     # 1024 * 0.25 = 256px (matches gold)
const MIN_SPEED: float = 60.0
const MAX_SPEED: float = 160.0

var coins: Array[Sprite2D] = []
var coin_speeds: Array[float] = []
var coin_rotation_speeds: Array[float] = []
var fade_overlay: ColorRect
var transitioning: bool = false


func _ready() -> void:
	# Background
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.18)
	bg.position = Vector2.ZERO
	bg.size = Vector2(720, 1280)
	bg.z_index = -1
	add_child(bg)

	# Coin container
	var coin_container: Node2D = Node2D.new()
	coin_container.z_index = 0
	add_child(coin_container)

	# Spawn coins
	for i in range(COIN_COUNT):
		var coin: Sprite2D = Sprite2D.new()
		coin.position = Vector2(randf_range(-80.0, 800.0), randf_range(-200.0, 1280.0))
		coin.rotation = randf_range(0.0, TAU)

		# Weighted random texture: 40% copper, 35% silver, 25% gold
		var tex_roll: float = randf()
		if tex_roll < 0.4:
			coin.texture = COIN_TEXTURE_COPPER
			coin.scale = Vector2(COIN_SCALE_LARGE, COIN_SCALE_LARGE)
		elif tex_roll < 0.75:
			coin.texture = COIN_TEXTURE_SILVER
			coin.scale = Vector2(COIN_SCALE_LARGE, COIN_SCALE_LARGE)
		else:
			coin.texture = COIN_TEXTURE_GOLD
			coin.scale = Vector2(COIN_SCALE_GOLD, COIN_SCALE_GOLD)

		var speed: float = randf_range(MIN_SPEED, MAX_SPEED)
		var rot_speed: float = randf_range(-1.0, 1.0)

		coin_container.add_child(coin)
		coins.append(coin)
		coin_speeds.append(speed)
		coin_rotation_speeds.append(rot_speed)

	# Dark band behind logo for readability
	var logo_backdrop: ColorRect = ColorRect.new()
	logo_backdrop.color = Color(0.0, 0.0, 0.1, 0.6)
	logo_backdrop.position = Vector2(0, 250)
	logo_backdrop.size = Vector2(720, 200)
	logo_backdrop.z_index = 5
	add_child(logo_backdrop)

	# Logo (4352x992 source, scale to ~600px wide)
	var logo: Sprite2D = Sprite2D.new()
	logo.texture = LOGO_TEXTURE
	var logo_scale: float = 600.0 / LOGO_TEXTURE.get_width()
	logo.scale = Vector2(logo_scale, logo_scale)
	logo.position = Vector2(360, 350)
	logo.z_index = 10
	add_child(logo)

	# Logo bob animation
	var logo_tween: Tween = create_tween().set_loops()
	logo_tween.tween_property(logo, "position:y", 340.0, 1.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	logo_tween.tween_property(logo, "position:y", 360.0, 1.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	# Dark band behind "Tap to Play" for readability
	var tap_backdrop: ColorRect = ColorRect.new()
	tap_backdrop.color = Color(0.0, 0.0, 0.1, 0.6)
	tap_backdrop.position = Vector2(0, 720)
	tap_backdrop.size = Vector2(720, 80)
	tap_backdrop.z_index = 5
	add_child(tap_backdrop)

	# "Tap to Play" label
	var tap_label: Label = Label.new()
	tap_label.text = "Tap to Play"
	tap_label.add_theme_font_override("font", DISPLAY_FONT)
	tap_label.add_theme_font_size_override("font_size", 36)
	tap_label.add_theme_color_override("font_color", Color.WHITE)
	tap_label.add_theme_color_override("font_outline_color", Color(1.0, 0.85, 0.2))
	tap_label.add_theme_constant_override("outline_size", 4)
	tap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tap_label.position = Vector2(0, 730)
	tap_label.size = Vector2(720, 50)
	tap_label.z_index = 10
	add_child(tap_label)

	# Pulse animation
	var pulse_tween: Tween = create_tween().set_loops()
	pulse_tween.tween_property(tap_label, "modulate:a", 0.3, 0.6).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	pulse_tween.tween_property(tap_label, "modulate:a", 1.0, 0.6).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	# Fade overlay
	fade_overlay = ColorRect.new()
	fade_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	fade_overlay.position = Vector2.ZERO
	fade_overlay.size = Vector2(720, 1280)
	fade_overlay.z_index = 100
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade_overlay)


func _process(delta: float) -> void:
	for i in range(coins.size()):
		var coin: Sprite2D = coins[i]
		coin.position.y += coin_speeds[i] * delta
		coin.rotation += coin_rotation_speeds[i] * delta
		if coin.position.y > 1480.0:
			coin.position.y = -200.0
			coin.position.x = randf_range(-80.0, 800.0)


func _unhandled_input(event: InputEvent) -> void:
	if transitioning:
		return

	var should_transition: bool = (
		(event is InputEventMouseButton and event.pressed)
		or (event is InputEventKey and event.pressed)
		or (event is InputEventScreenTouch and event.pressed)
		or (event is InputEventJoypadButton and event.pressed)
	)

	if should_transition:
		transitioning = true
		var fade_tween: Tween = create_tween()
		fade_tween.tween_property(fade_overlay, "color:a", 1.0, 0.5)
		fade_tween.tween_callback(_go_to_main)


func _go_to_main() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")
