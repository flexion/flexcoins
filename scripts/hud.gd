extends CanvasLayer

@export var upgrade_button_scene: PackedScene

var _gold_flash: ColorRect
var _milestone_label: Label
var _ascension_label: Label
var _ascend_button: Button
var _combo_multiplier_label: Label
var _combo_multiplier_glow_tween: Tween
var _flash_tween: Tween
var _milestone_tween: Tween
var _shop_open: bool = false
var _shop_tween: Tween
var _currency_pop_tween: Tween
var _currency_flash_tween: Tween
var _frenzy_label: Label
var _frenzy_tween: Tween
var _shake_tween: Tween
var _gear_button: Button
var _settings_panel: PanelContainer
var _settings_backdrop: Control
var _settings_open: bool = false
var _settings_tween: Tween
var _sound_toggle: Button
var _fullscreen_toggle: Button
var _display_font: Font = preload("res://assets/fonts/kenney_future.ttf")
var _narrow_font: Font = preload("res://assets/fonts/kenney_future_narrow.ttf")

@onready var currency_label: Label = %CurrencyLabel
@onready var upgrade_container: VBoxContainer = %UpgradeContainer
@onready var upgrade_panel: PanelContainer = %UpgradePanel
@onready var shop_toggle: Button = %ShopToggle


func _ready() -> void:
	GameManager.currency_changed.connect(_on_currency_changed)
	GameManager.upgrade_purchased.connect(_on_upgrade_purchased)
	GameManager.milestone_reached.connect(_on_milestone_reached)
	GameManager.coin_collected.connect(_on_coin_collected)
	GameManager.frenzy_started.connect(_on_frenzy_started)
	GameManager.frenzy_ended.connect(_on_frenzy_ended)
	GameManager.bomb_hit.connect(_on_bomb_hit)
	GameManager.combo_multiplier_changed.connect(_on_combo_multiplier_changed)
	currency_label.add_theme_font_override("font", _display_font)
	currency_label.add_theme_font_size_override("font_size", 48)
	_on_currency_changed(GameManager.currency)
	_create_upgrade_buttons()
	shop_toggle.pressed.connect(_on_shop_toggle_pressed)
	_create_settings_ui()
	# Start with shop hidden off-screen
	upgrade_panel.visible = false
	upgrade_panel.offset_top = 0.0
	_create_gold_flash_overlay()
	_create_milestone_label()
	_create_ascension_ui()
	_create_combo_multiplier_badge()


func _on_currency_changed(new_amount: int) -> void:
	currency_label.text = "Coins: %d" % new_amount
	currency_label.pivot_offset = currency_label.size / 2.0
	_update_ascend_button()


func _create_upgrade_buttons() -> void:
	for id: String in GameManager.UPGRADE_DATA:
		if upgrade_button_scene:
			var btn: PanelContainer = upgrade_button_scene.instantiate()
			btn.setup(id)
			upgrade_container.add_child(btn)


func _on_shop_toggle_pressed() -> void:
	if _shop_tween and _shop_tween.is_running():
		return
	# Close settings panel if open (mutual exclusion)
	if _settings_open:
		_close_settings()
	_shop_open = not _shop_open
	shop_toggle.text = "Close" if _shop_open else "Shop"
	if _shop_open:
		GameManager.shop_opened.emit()
	else:
		GameManager.shop_closed.emit()
	_shop_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	if _shop_open:
		upgrade_panel.visible = true
		upgrade_panel.offset_top = 0.0
		_shop_tween.tween_property(upgrade_panel, "offset_top", -260.0, 0.3)
	else:
		_shop_tween.set_trans(Tween.TRANS_QUAD)
		_shop_tween.tween_property(upgrade_panel, "offset_top", 0.0, 0.2)
		_shop_tween.tween_callback(func() -> void: upgrade_panel.visible = false)


func _create_ascension_ui() -> void:
	# Ascension display label (top-left area, below currency)
	_ascension_label = Label.new()
	_ascension_label.add_theme_font_override("font", _display_font)
	_ascension_label.add_theme_font_size_override("font_size", 18)
	_ascension_label.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0, 1.0))
	_ascension_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ascension_label)
	_ascension_label.anchors_preset = Control.PRESET_TOP_LEFT
	_ascension_label.offset_left = 20.0
	_ascension_label.offset_top = 55.0
	_ascension_label.offset_right = 400.0
	_update_ascension_label()
	# Ascend button in shop area
	_ascend_button = Button.new()
	_ascend_button.theme = preload("res://assets/ui_theme.tres")
	_ascend_button.text = "ASCEND"
	_ascend_button.custom_minimum_size = Vector2(200.0, 40.0)
	_ascend_button.add_theme_font_size_override("font_size", 18)
	_ascend_button.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0, 1.0))
	_ascend_button.pressed.connect(_on_ascend_pressed)
	upgrade_container.add_child(_ascend_button)
	_update_ascend_button()


func _update_ascension_label() -> void:
	if GameManager.ascension_count > 0:
		_ascension_label.text = "Ascension %d  (%.1fx)" % [GameManager.ascension_count, GameManager.get_ascension_multiplier()]
		_ascension_label.visible = true
	else:
		_ascension_label.visible = false


func _update_ascend_button() -> void:
	if _ascend_button:
		_ascend_button.visible = GameManager.can_ascend()


func _create_combo_multiplier_badge() -> void:
	# Combo multiplier badge (top-right)
	_combo_multiplier_label = Label.new()
	_combo_multiplier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_multiplier_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_combo_multiplier_label.add_theme_font_override("font", _display_font)
	_combo_multiplier_label.add_theme_font_size_override("font_size", 36)
	_combo_multiplier_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.0, 1.0))
	_combo_multiplier_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo_multiplier_label.visible = false
	_combo_multiplier_label.z_index = 150
	add_child(_combo_multiplier_label)
	# Set anchors_preset after add_child so anchors resolve against parent size
	_combo_multiplier_label.anchors_preset = Control.PRESET_TOP_RIGHT
	_combo_multiplier_label.offset_left = -190.0
	_combo_multiplier_label.offset_right = -80.0
	_combo_multiplier_label.offset_top = 20.0
	_combo_multiplier_label.offset_bottom = 60.0
	# Wait one frame for layout to resolve, then set pivot for center-scaling
	await get_tree().process_frame
	if not is_instance_valid(_combo_multiplier_label):
		return
	_combo_multiplier_label.pivot_offset = _combo_multiplier_label.size / 2.0


func _on_combo_multiplier_changed(new_multiplier: float) -> void:
	if new_multiplier == 1.0:
		# Hide badge when multiplier resets to 1.0x
		_combo_multiplier_label.visible = false
		if _combo_multiplier_glow_tween and _combo_multiplier_glow_tween.is_running():
			_combo_multiplier_glow_tween.kill()
	else:
		# Show and animate badge when multiplier activates
		_combo_multiplier_label.visible = true
		_combo_multiplier_label.text = "%.1fx" % new_multiplier
		_animate_combo_multiplier_glow()


func _animate_combo_multiplier_glow() -> void:
	# Kill any existing tween
	if _combo_multiplier_glow_tween and _combo_multiplier_glow_tween.is_running():
		_combo_multiplier_glow_tween.kill()

	# Start fresh scale and color animation loop
	_combo_multiplier_label.scale = Vector2(0.8, 0.8)
	_combo_multiplier_glow_tween = create_tween().set_loops()
	_combo_multiplier_glow_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_combo_multiplier_glow_tween.tween_property(_combo_multiplier_label, "scale", Vector2(1.2, 1.2), 0.4)
	_combo_multiplier_glow_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_combo_multiplier_glow_tween.tween_property(_combo_multiplier_label, "scale", Vector2(0.8, 0.8), 0.4)


func _on_ascend_pressed() -> void:
	if GameManager.try_ascend():
		_update_ascension_label()
		# Big celebration
		_show_milestone_celebration(0)
		_milestone_label.text = "ASCENDED!"
		_milestone_label.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0, 1.0))


func _on_coin_collected(value: int, world_position: Vector2) -> void:
	if value <= 0:
		return
	if GameManager.frenzy_active:
		_screen_shake(4.0, 4, 0.03)
	# Spawn a small gold circle that arcs up to the currency label
	var icon := ColorRect.new()
	icon.custom_minimum_size = Vector2(12.0, 12.0)
	icon.size = Vector2(12.0, 12.0)
	icon.color = Color(1.0, 0.84, 0.0, 1.0)
	icon.position = world_position - Vector2(6.0, 6.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.z_index = 20
	add_child(icon)
	# Target: currency label center (in screen coords, which match CanvasLayer)
	var target := Vector2(currency_label.global_position.x + currency_label.size.x / 2.0,
			currency_label.global_position.y + currency_label.size.y / 2.0)
	# Arc via a midpoint above
	var mid := (icon.position + target) / 2.0 - Vector2(0.0, 150.0)
	var tween := create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_method(func(t: float) -> void:
		# Quadratic bezier: P = (1-t)^2*P0 + 2*(1-t)*t*P1 + t^2*P2
		var start_pos := world_position - Vector2(6.0, 6.0)
		var p := (1.0 - t) * (1.0 - t) * start_pos + 2.0 * (1.0 - t) * t * mid + t * t * target
		icon.position = p
		icon.scale = Vector2(1.0, 1.0).lerp(Vector2(0.5, 0.5), t)
	, 0.0, 1.0, 0.4)
	tween.tween_callback(func() -> void:
		GameManager.add_currency(value)
		_pop_currency_label()
		icon.queue_free()
	)


func _pop_currency_label() -> void:
	if _currency_pop_tween and _currency_pop_tween.is_running():
		_currency_pop_tween.kill()
	if _currency_flash_tween and _currency_flash_tween.is_running():
		_currency_flash_tween.kill()
	currency_label.pivot_offset = currency_label.size / 2.0
	_currency_pop_tween = create_tween()
	_currency_pop_tween.tween_property(currency_label, "scale", Vector2(1.15, 1.15), 0.06).set_ease(Tween.EASE_OUT)
	_currency_pop_tween.tween_property(currency_label, "scale", Vector2(1.0, 1.0), 0.08).set_ease(Tween.EASE_IN)


func _on_frenzy_started() -> void:
	# Clean up any existing frenzy label (handles rapid re-frenzy)
	if _frenzy_label:
		if _frenzy_tween and _frenzy_tween.is_running():
			_frenzy_tween.kill()
		_frenzy_label.queue_free()
		_frenzy_label = null
	var lbl := Label.new()
	lbl.text = "FRENZY!"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", _display_font)
	lbl.add_theme_font_size_override("font_size", 64)
	lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4, 1.0))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.z_index = 200
	add_child(lbl)
	# Set anchors_preset after add_child so anchors resolve against parent size
	lbl.anchors_preset = Control.PRESET_CENTER_TOP
	lbl.offset_left = -200.0
	lbl.offset_right = 200.0
	lbl.offset_top = 80.0
	_frenzy_label = lbl
	# Wait one frame for layout to resolve, then set pivot for center-scaling
	await get_tree().process_frame
	if not is_instance_valid(lbl):
		return
	lbl.pivot_offset = lbl.size / 2.0
	# Intro animation: scale pop
	var intro_tween := create_tween()
	intro_tween.tween_property(lbl, "scale", Vector2(1.2, 1.2), 0.15).from(Vector2(0.5, 0.5)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	intro_tween.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.1)
	# Start looping pulse after intro
	intro_tween.tween_callback(func() -> void:
		_frenzy_tween = create_tween().set_loops()
		_frenzy_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		_frenzy_tween.tween_property(lbl, "scale", Vector2(1.1, 1.1), 0.3)
		_frenzy_tween.tween_property(lbl, "scale", Vector2(0.95, 0.95), 0.3)
	)


func _on_frenzy_ended() -> void:
	if _frenzy_label:
		if _frenzy_tween and _frenzy_tween.is_running():
			_frenzy_tween.kill()
		var fade_tween := create_tween()
		var lbl_ref: Label = _frenzy_label
		fade_tween.tween_property(lbl_ref, "modulate:a", 0.0, 0.4)
		fade_tween.tween_callback(func() -> void:
			lbl_ref.queue_free()
		)
		_frenzy_label = null


func _on_bomb_hit() -> void:
	# Red screen flash
	if _flash_tween and _flash_tween.is_running():
		_flash_tween.kill()
	_gold_flash.color = Color(1.0, 0.1, 0.0, 0.3)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_gold_flash, "color:a", 0.0, 0.4).set_ease(Tween.EASE_OUT)
	# Screen shake
	_screen_shake(8.0, 8, 0.04)


func _screen_shake(intensity: float, iterations: int, step_time: float) -> void:
	if _shake_tween and _shake_tween.is_running():
		_shake_tween.kill()
	var main_node := get_tree().current_scene
	if not main_node:
		return
	_shake_tween = create_tween()
	for i: int in range(iterations):
		var offset := Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		_shake_tween.tween_property(main_node, "position", offset, step_time)
	_shake_tween.tween_property(main_node, "position", Vector2.ZERO, step_time)


func _create_settings_ui() -> void:
	# Gear button (top-right, replacing mute button position)
	_gear_button = Button.new()
	_gear_button.theme = preload("res://assets/ui_theme.tres")
	_gear_button.add_theme_font_size_override("font_size", 22)
	_gear_button.text = "⚙"
	_gear_button.pressed.connect(_on_gear_pressed)
	add_child(_gear_button)
	_gear_button.anchors_preset = Control.PRESET_TOP_RIGHT
	_gear_button.anchor_left = 1.0
	_gear_button.anchor_right = 1.0
	_gear_button.offset_left = -70.0
	_gear_button.offset_top = 15.0
	_gear_button.offset_right = -15.0
	_gear_button.offset_bottom = 55.0
	_gear_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	# Transparent backdrop for outside-tap detection
	_settings_backdrop = Control.new()
	_settings_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_backdrop.visible = false
	_settings_backdrop.z_index = 159
	add_child(_settings_backdrop)
	_settings_backdrop.anchors_preset = Control.PRESET_FULL_RECT
	_settings_backdrop.gui_input.connect(_on_backdrop_input)

	# Settings panel
	_settings_panel = PanelContainer.new()
	_settings_panel.theme = preload("res://assets/ui_theme.tres")
	_settings_panel.z_index = 160
	_settings_panel.visible = false
	_settings_panel.scale = Vector2(0.8, 0.8)
	_settings_panel.modulate.a = 0.0
	add_child(_settings_panel)
	_settings_panel.anchors_preset = Control.PRESET_TOP_RIGHT
	_settings_panel.anchor_left = 1.0
	_settings_panel.anchor_right = 1.0
	_settings_panel.offset_left = -220.0
	_settings_panel.offset_top = 60.0
	_settings_panel.offset_right = -15.0
	_settings_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_settings_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# Sound toggle
	_sound_toggle = Button.new()
	_sound_toggle.theme = preload("res://assets/ui_theme.tres")
	_sound_toggle.add_theme_font_override("font", _narrow_font)
	_sound_toggle.add_theme_font_size_override("font_size", 14)
	_update_sound_toggle_text()
	_sound_toggle.pressed.connect(_on_sound_toggle_pressed)
	vbox.add_child(_sound_toggle)

	# Fullscreen toggle
	_fullscreen_toggle = Button.new()
	_fullscreen_toggle.theme = preload("res://assets/ui_theme.tres")
	_fullscreen_toggle.add_theme_font_override("font", _narrow_font)
	_fullscreen_toggle.add_theme_font_size_override("font_size", 14)
	_update_fullscreen_toggle_text()
	_fullscreen_toggle.pressed.connect(_on_fullscreen_toggle_pressed)
	vbox.add_child(_fullscreen_toggle)

	# Set pivot for scale animation (top-right corner)
	await get_tree().process_frame
	if is_instance_valid(_settings_panel):
		_settings_panel.pivot_offset = Vector2(_settings_panel.size.x, 0.0)


func _on_gear_pressed() -> void:
	if _settings_tween and _settings_tween.is_running():
		return
	if _settings_open:
		_close_settings()
	else:
		_open_settings()


func _open_settings() -> void:
	# Close shop if open (mutual exclusion)
	if _shop_open:
		_shop_open = false
		shop_toggle.text = "Shop"
		GameManager.shop_closed.emit()
		if _shop_tween and _shop_tween.is_running():
			_shop_tween.kill()
		_shop_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		_shop_tween.tween_property(upgrade_panel, "offset_top", 0.0, 0.2)
		_shop_tween.tween_callback(func() -> void: upgrade_panel.visible = false)
	_settings_open = true
	_settings_backdrop.visible = true
	_settings_panel.visible = true
	_settings_panel.scale = Vector2(0.8, 0.8)
	_settings_panel.modulate.a = 0.0
	_settings_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_settings_tween.tween_property(_settings_panel, "scale", Vector2(1.0, 1.0), 0.15)
	_settings_tween.parallel().tween_property(_settings_panel, "modulate:a", 1.0, 0.15)


func _close_settings() -> void:
	_settings_open = false
	_settings_backdrop.visible = false
	_settings_tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_settings_tween.tween_property(_settings_panel, "scale", Vector2(0.8, 0.8), 0.1)
	_settings_tween.parallel().tween_property(_settings_panel, "modulate:a", 0.0, 0.1)
	_settings_tween.tween_callback(func() -> void: _settings_panel.visible = false)


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close_settings()


func _on_sound_toggle_pressed() -> void:
	var bus_index := AudioServer.get_bus_index("Master")
	var muted := not AudioServer.is_bus_mute(bus_index)
	AudioServer.set_bus_mute(bus_index, muted)
	_update_sound_toggle_text()


func _on_fullscreen_toggle_pressed() -> void:
	_toggle_fullscreen()


func _update_sound_toggle_text() -> void:
	var bus_index := AudioServer.get_bus_index("Master")
	_sound_toggle.text = "Sound: OFF" if AudioServer.is_bus_mute(bus_index) else "Sound: ON"


func _update_fullscreen_toggle_text() -> void:
	var current_mode := DisplayServer.window_get_mode()
	if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		_fullscreen_toggle.text = "Fullscreen: ON"
	else:
		_fullscreen_toggle.text = "Fullscreen: OFF"


func _update_settings_toggles() -> void:
	if _fullscreen_toggle:
		_update_fullscreen_toggle_text()
	if _sound_toggle:
		_update_sound_toggle_text()


func _toggle_fullscreen() -> void:
	var current_mode := DisplayServer.window_get_mode()
	if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_update_settings_toggles()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F11:
		_toggle_fullscreen()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_update_settings_toggles()


func _on_upgrade_purchased(_upgrade_id: String) -> void:
	_flash_currency_label()
	_flash_gold_overlay()


func _flash_currency_label() -> void:
	if _currency_flash_tween and _currency_flash_tween.is_running():
		_currency_flash_tween.kill()
	if _currency_pop_tween and _currency_pop_tween.is_running():
		_currency_pop_tween.kill()
	currency_label.pivot_offset = currency_label.size / 2.0
	_currency_flash_tween = create_tween()
	currency_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	_currency_flash_tween.tween_property(currency_label, "scale", Vector2(1.3, 1.3), 0.1).set_ease(Tween.EASE_OUT)
	_currency_flash_tween.tween_property(currency_label, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_IN)
	_currency_flash_tween.tween_callback(func() -> void:
		currency_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0, 1.0))
	)


func _create_gold_flash_overlay() -> void:
	_gold_flash = ColorRect.new()
	_gold_flash.color = Color(1.0, 0.84, 0.0, 0.0)
	_gold_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_gold_flash)
	_gold_flash.anchors_preset = Control.PRESET_FULL_RECT


func _flash_gold_overlay() -> void:
	if _flash_tween and _flash_tween.is_running():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_gold_flash.color = Color(1.0, 0.84, 0.0, 0.15)
	_flash_tween.tween_property(_gold_flash, "color:a", 0.0, 0.3).set_ease(Tween.EASE_OUT)


func _create_milestone_label() -> void:
	_milestone_label = Label.new()
	_milestone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_milestone_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_milestone_label.add_theme_font_override("font", _display_font)
	_milestone_label.add_theme_font_size_override("font_size", 64)
	_milestone_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0, 1.0))
	_milestone_label.modulate.a = 0.0
	_milestone_label.visible = false
	_milestone_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_milestone_label)
	# Set anchors_preset after add_child so anchors resolve against parent size
	_milestone_label.anchors_preset = Control.PRESET_CENTER
	_milestone_label.offset_left = -300.0
	_milestone_label.offset_right = 300.0
	_milestone_label.offset_top = -60.0
	_milestone_label.offset_bottom = 60.0
	# Wait one frame for layout to resolve, then set pivot for center-scaling
	await get_tree().process_frame
	if not is_instance_valid(_milestone_label):
		return
	_milestone_label.pivot_offset = _milestone_label.size / 2.0


func _on_milestone_reached(amount: int) -> void:
	_show_milestone_celebration(amount)


func _show_milestone_celebration(amount: int) -> void:
	_milestone_label.visible = true
	_milestone_label.text = "%d COINS!" % amount
	_milestone_label.scale = Vector2(0.5, 0.5)

	# Update pivot after text change for center-scaling
	await get_tree().process_frame
	if not is_instance_valid(_milestone_label):
		return
	_milestone_label.pivot_offset = _milestone_label.size / 2.0

	# Big gold screen flash
	if _flash_tween and _flash_tween.is_running():
		_flash_tween.kill()
	_gold_flash.color = Color(1.0, 0.84, 0.0, 0.3)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_gold_flash, "color:a", 0.0, 0.6).set_ease(Tween.EASE_OUT)

	# Animated milestone text
	if _milestone_tween and _milestone_tween.is_running():
		_milestone_tween.kill()
	_milestone_tween = create_tween()
	_milestone_tween.tween_property(_milestone_label, "modulate:a", 1.0, 0.15)
	_milestone_tween.parallel().tween_property(_milestone_label, "scale", Vector2(1.2, 1.2), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_milestone_tween.tween_property(_milestone_label, "scale", Vector2(1.0, 1.0), 0.15)
	_milestone_tween.tween_interval(1.0)
	_milestone_tween.tween_property(_milestone_label, "modulate:a", 0.0, 0.4)
	_milestone_tween.tween_callback(func() -> void: _milestone_label.visible = false)
	_milestone_tween.tween_property(_milestone_label, "scale", Vector2(0.5, 0.5), 0.01)

	# Spawn celebration particles across the screen
	_spawn_celebration_particles()


func _spawn_celebration_particles() -> void:
	for i: int in range(3):
		var burst := CPUParticles2D.new()
		burst.emitting = true
		burst.one_shot = true
		burst.explosiveness = 0.8
		burst.amount = 20
		burst.lifetime = 1.2
		burst.direction = Vector2(0, -1)
		burst.spread = 180.0
		burst.initial_velocity_min = 150.0
		burst.initial_velocity_max = 350.0
		burst.gravity = Vector2(0, 300)
		burst.scale_amount_min = 3.0
		burst.scale_amount_max = 7.0
		burst.color = Color(1.0, 0.84, 0.0, 0.9)
		# Need to add to a Node2D parent since CanvasLayer can't position particles directly
		# Use offset positions by setting emission shape
		burst.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		burst.emission_rect_extents = Vector2(200.0, 20.0)
		var vp_size := get_viewport().get_visible_rect().size
		burst.position = Vector2(vp_size.x / 2.0, vp_size.y / 2.0 + i * 200.0 - 200.0)
		# CanvasLayer children need a Control or Node2D wrapper
		var wrapper := Node2D.new()
		wrapper.position = Vector2.ZERO
		add_child(wrapper)
		wrapper.add_child(burst)
		get_tree().create_timer(burst.lifetime + 0.2).timeout.connect(wrapper.queue_free)
