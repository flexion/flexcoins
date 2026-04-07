extends PanelContainer

const SEGMENTS: int = 5
const TIER_COLORS: Array[Color] = [
	Color(0.5, 0.5, 0.5, 1.0),    # Grey (tier 0)
	Color(1.0, 0.84, 0.0, 1.0),   # Gold (tier 1)
	Color(0.4, 0.7, 1.0, 1.0),    # Diamond blue (tier 2)
	Color(0.8, 0.4, 1.0, 1.0),    # Purple (tier 3+)
]
const EMPTY_COLOR := Color(0.2, 0.2, 0.2, 1.0)
const AFFORD_COLOR := Color(1.0, 0.84, 0.0, 1.0)
const UNAFFORD_COLOR := Color(0.5, 0.5, 0.5, 1.0)

var upgrade_id: String = ""
var _segment_rects: Array[ColorRect] = []
var _was_affordable: bool = false
var _pulse_tween: Tween

@onready var name_label: Label = %NameLabel
@onready var effect_label: Label = %EffectLabel
@onready var buy_button: Button = %BuyButton


func setup(id: String) -> void:
	upgrade_id = id


func _ready() -> void:
	buy_button.pressed.connect(_on_buy_pressed)
	GameManager.currency_changed.connect(_on_currency_changed)
	GameManager.upgrade_purchased.connect(_on_upgrade_changed)
	_create_segment_bar()
	_update_display()


func _on_buy_pressed() -> void:
	if GameManager.try_purchase_upgrade(upgrade_id):
		_animate_purchase()


func _on_currency_changed(_amount: int) -> void:
	_update_display()


func _on_upgrade_changed(_id: String) -> void:
	_update_display()


func _update_display() -> void:
	if upgrade_id == "" or not is_inside_tree():
		return
	var data: Dictionary = GameManager.UPGRADE_DATA[upgrade_id]
	var level: int = GameManager.get_upgrade_level(upgrade_id)
	var cost: int = GameManager.get_upgrade_cost(upgrade_id)
	name_label.text = data.name
	effect_label.text = data.description
	buy_button.text = "Buy: %d" % cost
	var affordable := GameManager.currency >= cost
	buy_button.disabled = not affordable
	_update_afford_cue(affordable)
	_update_segments(level)


func _create_segment_bar() -> void:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0.0, 6.0)
	bar.add_theme_constant_override("separation", 3)
	# Insert between name and effect labels
	var info_vbox: VBoxContainer = name_label.get_parent()
	info_vbox.add_child(bar)
	info_vbox.move_child(bar, name_label.get_index() + 1)
	for i: int in range(SEGMENTS):
		var seg := ColorRect.new()
		seg.custom_minimum_size = Vector2(16.0, 6.0)
		seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seg.color = EMPTY_COLOR
		bar.add_child(seg)
		_segment_rects.append(seg)


func _update_segments(level: int) -> void:
	var filled: int = level % SEGMENTS
	# If level is a multiple of SEGMENTS and > 0, show full bar at previous tier
	if level > 0 and filled == 0:
		filled = SEGMENTS
	var tier: int = (level - 1) / SEGMENTS if level > 0 else 0
	var fill_color: Color = TIER_COLORS[mini(tier, TIER_COLORS.size() - 1)]
	for i: int in range(SEGMENTS):
		_segment_rects[i].color = fill_color if i < filled else EMPTY_COLOR


func _update_afford_cue(affordable: bool) -> void:
	if affordable:
		buy_button.add_theme_color_override("font_color", AFFORD_COLOR)
		if not _was_affordable:
			# Just became affordable — start pulse
			_was_affordable = true
			_start_pulse()
	else:
		buy_button.add_theme_color_override("font_color", UNAFFORD_COLOR)
		if _was_affordable:
			_was_affordable = false
			_stop_pulse()


func _start_pulse() -> void:
	_stop_pulse()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(buy_button, "modulate:a", 0.6, 0.5).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(buy_button, "modulate:a", 1.0, 0.5).set_ease(Tween.EASE_IN_OUT)


func _stop_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_running():
		_pulse_tween.kill()
	buy_button.modulate.a = 1.0


func _animate_purchase() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.08).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.12).set_ease(Tween.EASE_IN_OUT)
	var original_color: Color = buy_button.get_theme_color("font_color")
	buy_button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	tween.tween_callback(func() -> void:
		buy_button.add_theme_color_override("font_color", original_color)
	)
