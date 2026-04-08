extends CanvasLayer

@export var upgrade_button_scene: PackedScene

var _gold_flash: ColorRect
var _milestone_label: Label
var _ascension_label: Label
var _ascend_button: Button
var _shop_open: bool = false
var _shop_tween: Tween

@onready var currency_label: Label = %CurrencyLabel
@onready var upgrade_container: VBoxContainer = %UpgradeContainer
@onready var upgrade_panel: PanelContainer = %UpgradePanel
@onready var shop_toggle: Button = %ShopToggle
@onready var welcome_panel: PanelContainer = %WelcomePanel
@onready var welcome_earnings_label: Label = %WelcomeEarningsLabel
@onready var welcome_button: Button = %WelcomeButton
@onready var mute_button: Button = %MuteButton


func _ready() -> void:
	GameManager.currency_changed.connect(_on_currency_changed)
	GameManager.upgrade_purchased.connect(_on_upgrade_purchased)
	GameManager.milestone_reached.connect(_on_milestone_reached)
	GameManager.coin_collected.connect(_on_coin_collected)
	GameManager.frenzy_started.connect(_on_frenzy_started)
	GameManager.bomb_hit.connect(_on_bomb_hit)
	_on_currency_changed(GameManager.currency)
	_create_upgrade_buttons()
	shop_toggle.pressed.connect(_on_shop_toggle_pressed)
	mute_button.pressed.connect(_on_mute_pressed)
	# Start with shop hidden off-screen
	upgrade_panel.visible = false
	upgrade_panel.offset_top = 0.0
	_check_offline_earnings()
	_create_gold_flash_overlay()
	_create_milestone_label()
	_create_ascension_ui()


func _on_currency_changed(new_amount: int) -> void:
	currency_label.text = "Coins: %d" % new_amount
	_update_ascend_button()


func _create_upgrade_buttons() -> void:
	for id: String in GameManager.UPGRADE_DATA:
		if upgrade_button_scene:
			var btn: PanelContainer = upgrade_button_scene.instantiate()
			btn.setup(id)
			upgrade_container.add_child(btn)


func _check_offline_earnings() -> void:
	var earnings := GameManager.get_offline_earnings()
	if earnings > 0:
		welcome_panel.visible = true
		welcome_earnings_label.text = "You earned %d coins while away!" % earnings
		welcome_button.pressed.connect(_on_welcome_dismissed, CONNECT_ONE_SHOT)
	else:
		welcome_panel.visible = false


func _on_shop_toggle_pressed() -> void:
	if _shop_tween and _shop_tween.is_running():
		return
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
	_ascension_label.anchors_preset = Control.PRESET_TOP_LEFT
	_ascension_label.offset_left = 20.0
	_ascension_label.offset_top = 55.0
	_ascension_label.offset_right = 400.0
	_ascension_label.add_theme_font_size_override("font_size", 16)
	_ascension_label.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0, 1.0))
	_ascension_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ascension_label)
	_update_ascension_label()
	# Ascend button in shop area
	_ascend_button = Button.new()
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


func _on_ascend_pressed() -> void:
	if GameManager.try_ascend():
		_update_ascension_label()
		# Big celebration
		_show_milestone_celebration(0)
		_milestone_label.text = "ASCENDED!"
		_milestone_label.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0, 1.0))


func _on_welcome_dismissed() -> void:
	welcome_panel.visible = false
	GameManager.clear_offline_earnings()


func _on_coin_collected(value: int, world_position: Vector2) -> void:
	if value <= 0:
		return
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
		icon.queue_free()
	)


func _on_frenzy_started() -> void:
	var lbl := Label.new()
	lbl.text = "FRENZY!"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.anchors_preset = Control.PRESET_CENTER_TOP
	lbl.offset_left = -200.0
	lbl.offset_right = 200.0
	lbl.offset_top = 80.0
	lbl.add_theme_font_size_override("font_size", 42)
	lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4, 1.0))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)
	var tween := create_tween()
	tween.tween_property(lbl, "scale", Vector2(1.2, 1.2), 0.15).from(Vector2(0.5, 0.5)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.1)
	tween.tween_interval(1.5)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.5)
	tween.tween_callback(lbl.queue_free)


func _on_bomb_hit() -> void:
	# Red screen flash
	_gold_flash.color = Color(1.0, 0.1, 0.0, 0.3)
	var flash_tween := create_tween()
	flash_tween.tween_property(_gold_flash, "color:a", 0.0, 0.4).set_ease(Tween.EASE_OUT)
	# Screen shake via camera or offset on the Main node
	var main_node := get_tree().current_scene
	if main_node:
		var shake_tween := create_tween()
		for i: int in range(8):
			var offset := Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))
			shake_tween.tween_property(main_node, "position", offset, 0.04)
		shake_tween.tween_property(main_node, "position", Vector2.ZERO, 0.04)


func _on_mute_pressed() -> void:
	var bus_index := AudioServer.get_bus_index("Master")
	var muted := not AudioServer.is_bus_mute(bus_index)
	AudioServer.set_bus_mute(bus_index, muted)
	mute_button.text = "🔇" if muted else "🔊"


func _on_upgrade_purchased(_upgrade_id: String) -> void:
	_flash_currency_label()
	_flash_gold_overlay()


func _flash_currency_label() -> void:
	var tween := create_tween()
	currency_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	tween.tween_property(currency_label, "scale", Vector2(1.3, 1.3), 0.1).set_ease(Tween.EASE_OUT)
	tween.tween_property(currency_label, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		currency_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0, 1.0))
	)


func _create_gold_flash_overlay() -> void:
	_gold_flash = ColorRect.new()
	_gold_flash.anchors_preset = Control.PRESET_FULL_RECT
	_gold_flash.offset_right = 720.0
	_gold_flash.offset_bottom = 1280.0
	_gold_flash.color = Color(1.0, 0.84, 0.0, 0.0)
	_gold_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_gold_flash)


func _flash_gold_overlay() -> void:
	var tween := create_tween()
	_gold_flash.color.a = 0.15
	tween.tween_property(_gold_flash, "color:a", 0.0, 0.3).set_ease(Tween.EASE_OUT)


func _create_milestone_label() -> void:
	_milestone_label = Label.new()
	_milestone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_milestone_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_milestone_label.anchors_preset = Control.PRESET_CENTER
	_milestone_label.offset_left = -300.0
	_milestone_label.offset_right = 300.0
	_milestone_label.offset_top = -60.0
	_milestone_label.offset_bottom = 60.0
	_milestone_label.add_theme_font_size_override("font_size", 48)
	_milestone_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0, 1.0))
	_milestone_label.modulate.a = 0.0
	_milestone_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_milestone_label)


func _on_milestone_reached(amount: int) -> void:
	_show_milestone_celebration(amount)


func _show_milestone_celebration(amount: int) -> void:
	_milestone_label.text = "%d COINS!" % amount
	_milestone_label.scale = Vector2(0.5, 0.5)

	# Big gold screen flash
	_gold_flash.color.a = 0.3
	var flash_tween := create_tween()
	flash_tween.tween_property(_gold_flash, "color:a", 0.0, 0.6).set_ease(Tween.EASE_OUT)

	# Animated milestone text
	var tween := create_tween()
	tween.tween_property(_milestone_label, "modulate:a", 1.0, 0.15)
	tween.parallel().tween_property(_milestone_label, "scale", Vector2(1.2, 1.2), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_milestone_label, "scale", Vector2(1.0, 1.0), 0.15)
	tween.tween_interval(1.0)
	tween.tween_property(_milestone_label, "modulate:a", 0.0, 0.4)
	tween.tween_property(_milestone_label, "scale", Vector2(0.5, 0.5), 0.01)

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
		burst.position = Vector2(360.0, 640.0 + i * 200.0 - 200.0)
		# CanvasLayer children need a Control or Node2D wrapper
		var wrapper := Node2D.new()
		wrapper.position = Vector2.ZERO
		add_child(wrapper)
		wrapper.add_child(burst)
		get_tree().create_timer(burst.lifetime + 0.2).timeout.connect(wrapper.queue_free)
