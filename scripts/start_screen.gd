extends Node2D

const COIN_COUNT: int = 360
const BG_TEXTURE: Texture2D = preload("res://assets/textures/bg-dark-abstract-wide.png")
const COIN_TEXTURE_GOLD: Texture2D = preload("res://assets/textures/coins/flexcoin.png")
const COIN_TEXTURE_SILVER: Texture2D = preload("res://assets/textures/coins/flexcoin-silver.png")
const COIN_TEXTURE_COPPER: Texture2D = preload("res://assets/textures/coins/flexcoin-copper.png")
const LOGO_TEXTURE: Texture2D = preload("res://assets/textures/logo.png")
const DISPLAY_FONT: Font = preload("res://assets/fonts/kenney_future.ttf")
const UI_THEME: Theme = preload("res://assets/ui_theme.tres")
const COIN_SCALE_GOLD: float = 2.0       # 128 * 2.0 = 256px (5x normal)
const COIN_SCALE_LARGE: float = 2.0      # 128 * 2.0 = 256px (matches gold)
const MIN_SPEED: float = 60.0
const MAX_SPEED: float = 160.0

const PANEL_WIDTH: float = 1300.0
const PANEL_HEIGHT: float = 760.0

var coins: Array[Sprite2D] = []
var coin_speeds: Array[float] = []
var coin_rotation_speeds: Array[float] = []
var fade_overlay: ColorRect
var _bg: TextureRect
var _panel: PanelContainer
var transitioning: bool = false
var _click_sound: AudioStreamPlayer
var _panel_tween: Tween


func _ready() -> void:
	var vp_size: Vector2 = get_viewport_rect().size

	# Background
	_bg = TextureRect.new()
	_bg.texture = BG_TEXTURE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.position = Vector2.ZERO
	_bg.size = vp_size
	_bg.z_index = -1
	add_child(_bg)

	# Coin container
	var coin_container: Node2D = Node2D.new()
	coin_container.z_index = 0
	add_child(coin_container)

	# Spawn coins
	for i: int in range(COIN_COUNT):
		var coin: Sprite2D = Sprite2D.new()
		coin.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		coin.position = Vector2(randf_range(-80.0, vp_size.x + 80.0), randf_range(-200.0, vp_size.y))
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

	# Centered panel (same style as shop menu)
	_panel = PanelContainer.new()
	_panel.theme = UI_THEME
	_panel.self_modulate = Color(0.15, 0.17, 0.22, 0.95)
	_panel.position = Vector2((vp_size.x - PANEL_WIDTH) / 2.0, (vp_size.y - PANEL_HEIGHT) / 2.0)
	_panel.size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	_panel.z_index = 5
	_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	_panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_theme_constant_override("separation", 40)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	# Logo inside panel
	var logo_rect: TextureRect = TextureRect.new()
	logo_rect.texture = LOGO_TEXTURE
	logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	logo_rect.custom_minimum_size = Vector2(1100, 350)
	logo_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	logo_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	logo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vbox.add_child(logo_rect)

	var tap_label: Label = Label.new()
	tap_label.text = "Continue"
	tap_label.add_theme_font_override("font", DISPLAY_FONT)
	tap_label.add_theme_font_size_override("font_size", 42)
	tap_label.add_theme_color_override("font_color", Color(0.98, 0.682, 0.231, 1.0))
	tap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tap_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tap_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vbox.add_child(tap_label)

	# Panel bob animation
	_start_panel_bob(vp_size)

	# Pulse animation on tap label
	var pulse_tween: Tween = create_tween().set_loops()
	pulse_tween.tween_property(tap_label, "modulate:a", 0.3, 0.6).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	pulse_tween.tween_property(tap_label, "modulate:a", 1.0, 0.6).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	# Click sound
	_click_sound = AudioStreamPlayer.new()
	_click_sound.stream = preload("res://assets/sounds/click-b.ogg")
	_click_sound.volume_db = -30.0
	add_child(_click_sound)

	# Fade overlay
	fade_overlay = ColorRect.new()
	fade_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	fade_overlay.position = Vector2.ZERO
	fade_overlay.size = vp_size
	fade_overlay.z_index = 100
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade_overlay)



func _process(delta: float) -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	for i: int in range(coins.size()):
		var coin: Sprite2D = coins[i]
		coin.position.y += coin_speeds[i] * delta
		coin.rotation += coin_rotation_speeds[i] * delta
		if coin.position.y > vp_size.y + 200.0:
			coin.position.y = -200.0
			coin.position.x = randf_range(-80.0, vp_size.x + 80.0)


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
		_click_sound.play()
		var fade_tween: Tween = create_tween()
		fade_tween.tween_property(fade_overlay, "color:a", 1.0, 0.5)
		fade_tween.tween_callback(_go_to_main)



func _start_panel_bob(vp_size: Vector2) -> void:
	if _panel_tween and _panel_tween.is_running():
		_panel_tween.kill()
	var center_y: float = (vp_size.y - PANEL_HEIGHT) / 2.0
	_panel_tween = create_tween().set_loops()
	_panel_tween.tween_property(_panel, "position:y", center_y - 10.0, 1.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_panel_tween.tween_property(_panel, "position:y", center_y + 10.0, 1.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _go_to_main() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")
