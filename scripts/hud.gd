extends CanvasLayer

@export var upgrade_button_scene: PackedScene

var _gold_flash: ColorRect
var _milestone_label: Label

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
	_on_currency_changed(GameManager.currency)
	_create_upgrade_buttons()
	shop_toggle.pressed.connect(_on_shop_toggle_pressed)
	mute_button.pressed.connect(_on_mute_pressed)
	_check_offline_earnings()
	_create_gold_flash_overlay()
	_create_milestone_label()


func _on_currency_changed(new_amount: int) -> void:
	currency_label.text = "Coins: %d" % new_amount


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
	upgrade_panel.visible = not upgrade_panel.visible
	shop_toggle.text = "Close" if upgrade_panel.visible else "Shop"


func _on_welcome_dismissed() -> void:
	welcome_panel.visible = false
	GameManager.clear_offline_earnings()


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
