extends PanelContainer

const SEGMENTS: int = 5
const TIER_COLORS: Array[Color] = [
	Color(0.5, 0.5, 0.5, 1.0),    # Grey (tier 0)
	Color(1.0, 0.84, 0.0, 1.0),   # Gold (tier 1)
	Color(0.4, 0.7, 1.0, 1.0),    # Diamond blue (tier 2)
	Color(0.8, 0.4, 1.0, 1.0),    # Purple (tier 3+)
]
const EMPTY_COLOR := Color(0.2, 0.2, 0.2, 1.0)
const AFFORD_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const UNAFFORD_COLOR := Color(0.65, 0.65, 0.65, 1.0)
const UPGRADE_ICONS: Dictionary = {
	"spawn_rate": preload("res://assets/textures/icon_repeat.png"),
	"coin_value": preload("res://assets/textures/icon_star.png"),
	"catcher_speed": preload("res://assets/textures/icon_arrow_up.png"),
	"catcher_width": preload("res://assets/textures/icon_arrow_right.png"),
	"magnet": preload("res://assets/textures/icon_circle.png"),
}
# Flexion brand colors for buy button states
const COLOR_CTA_ORANGE := Color(0.812, 0.291, 0.008, 1.0)      # #CF4A02
const COLOR_CTA_ORANGE_HOVER := Color(0.878, 0.373, 0.102, 1.0) # #E05F1A
const COLOR_GREEN := Color(0.231, 0.698, 0.451, 1.0)            # #3BB273
const COLOR_CHARCOAL := Color(0.294, 0.333, 0.388, 1.0)         # #4B5563
const COLOR_CHARCOAL_DARK := Color(0.2, 0.24, 0.3, 1.0)

var upgrade_id: String = ""
var _segment_rects: Array[ColorRect] = []
var _display_font: Font = preload("res://assets/fonts/kenney_future.ttf")
var _narrow_font: Font = preload("res://assets/fonts/kenney_future_narrow.ttf")
var _was_affordable: bool = false
var _pulse_tween: Tween
var _shake_tween: Tween
var _purchase_sound: AudioStreamPlayer
var _reject_sound: AudioStreamPlayer
var _style_afford: StyleBoxFlat
var _style_unafford: StyleBoxFlat
var _style_green: StyleBoxFlat

@onready var name_label: Label = %NameLabel
@onready var effect_label: Label = %EffectLabel
@onready var buy_button: Button = %BuyButton


func setup(id: String) -> void:
	upgrade_id = id


func _ready() -> void:
	name_label.add_theme_font_override("font", _display_font)
	effect_label.add_theme_font_override("font", _narrow_font)
	buy_button.add_theme_font_override("font", _narrow_font)
	buy_button.pressed.connect(_on_buy_pressed)
	GameManager.currency_changed.connect(_on_currency_changed)
	GameManager.upgrade_purchased.connect(_on_upgrade_changed)
	# Order matters: segment bar must be created before icon reparents NameLabel
	_create_segment_bar()
	_setup_icon()
	_setup_sounds()
	_style_afford = _create_flat_style(COLOR_CTA_ORANGE, COLOR_CTA_ORANGE.darkened(0.3))
	_style_unafford = _create_flat_style(COLOR_CHARCOAL, COLOR_CHARCOAL_DARK)
	_style_green = _create_flat_style(COLOR_GREEN, COLOR_GREEN.darkened(0.3))
	_apply_buy_style(_style_unafford)
	_update_display()


func _on_buy_pressed() -> void:
	if GameManager.try_purchase_upgrade(upgrade_id):
		_animate_purchase()
	else:
		_animate_reject()


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
	buy_button.text = _format_cost(cost)
	var affordable := GameManager.currency >= cost
	_update_afford_cue(affordable)
	_update_segments(level)


func _setup_icon() -> void:
	if not UPGRADE_ICONS.has(upgrade_id):
		return
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	var info_vbox: VBoxContainer = name_label.get_parent()
	var idx: int = name_label.get_index()
	info_vbox.add_child(name_row)
	info_vbox.move_child(name_row, idx)
	info_vbox.remove_child(name_label)
	var icon := TextureRect.new()
	icon.texture = UPGRADE_ICONS[upgrade_id]
	icon.custom_minimum_size = Vector2(40.0, 40.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	name_row.add_child(icon)
	name_row.add_child(name_label)


func _setup_sounds() -> void:
	_purchase_sound = AudioStreamPlayer.new()
	_purchase_sound.stream = preload("res://assets/sounds/click_purchase.ogg")
	_purchase_sound.volume_db = -6.0
	add_child(_purchase_sound)

	_reject_sound = AudioStreamPlayer.new()
	_reject_sound.stream = preload("res://assets/sounds/tap_reject.ogg")
	_reject_sound.volume_db = -6.0
	add_child(_reject_sound)


func _create_segment_bar() -> void:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0.0, 10.0)
	bar.add_theme_constant_override("separation", 5)
	# Insert between name and effect labels
	var info_vbox: VBoxContainer = name_label.get_parent()
	info_vbox.add_child(bar)
	info_vbox.move_child(bar, name_label.get_index() + 1)
	for i: int in range(SEGMENTS):
		var seg := ColorRect.new()
		seg.custom_minimum_size = Vector2(28.0, 10.0)
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


func _create_flat_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_width_bottom = 3
	style.border_color = border_color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.content_margin_left = 8.0
	style.content_margin_top = 4.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 4.0
	return style


func _apply_buy_style(style: StyleBoxFlat) -> void:
	buy_button.add_theme_stylebox_override("normal", style)
	buy_button.add_theme_stylebox_override("hover", style)
	buy_button.add_theme_stylebox_override("pressed", style)


func _update_afford_cue(affordable: bool) -> void:
	if affordable:
		modulate.a = 1.0
		buy_button.add_theme_color_override("font_color", AFFORD_COLOR)
		_apply_buy_style(_style_afford)
		if not _was_affordable:
			_was_affordable = true
			_start_pulse()
	else:
		modulate.a = 0.7
		buy_button.add_theme_color_override("font_color", UNAFFORD_COLOR)
		_apply_buy_style(_style_unafford)
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
	_apply_buy_style(_style_green)
	pivot_offset = size / 2.0
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.08).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.12).set_ease(Tween.EASE_IN_OUT)
	var original_color: Color = buy_button.get_theme_color("font_color")
	buy_button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	tween.tween_callback(func() -> void:
		scale = Vector2(1.0, 1.0)
		buy_button.add_theme_color_override("font_color", original_color)
		var affordable := GameManager.currency >= GameManager.get_upgrade_cost(upgrade_id)
		_apply_buy_style(_style_afford if affordable else _style_unafford)
	)
	if _purchase_sound:
		_purchase_sound.play()
	_flash_segments()


func _animate_reject() -> void:
	if _shake_tween and _shake_tween.is_running():
		_shake_tween.kill()
	var original_x: float = buy_button.position.x
	_shake_tween = create_tween()
	for i: int in range(4):
		_shake_tween.tween_property(buy_button, "position:x", original_x + 6.0, 0.037)
		_shake_tween.tween_property(buy_button, "position:x", original_x - 6.0, 0.037)
	_shake_tween.tween_property(buy_button, "position:x", original_x, 0.037)
	buy_button.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2, 1.0))
	_shake_tween.tween_callback(func() -> void:
		buy_button.get_parent().queue_sort()
		var affordable := GameManager.currency >= GameManager.get_upgrade_cost(upgrade_id)
		buy_button.add_theme_color_override("font_color", AFFORD_COLOR if affordable else UNAFFORD_COLOR)
	)
	if _reject_sound:
		_reject_sound.play()


func _format_cost(cost: int) -> String:
	if cost >= 1000000:
		return "Buy: %.1fM" % (cost / 1000000.0)
	elif cost >= 10000:
		return "Buy: %.1fK" % (cost / 1000.0)
	return "Buy: %d" % cost


func _flash_segments() -> void:
	var level: int = GameManager.get_upgrade_level(upgrade_id)
	var filled: int = level % SEGMENTS
	if level > 0 and filled == 0:
		filled = SEGMENTS
	var tier: int = (level - 1) / SEGMENTS if level > 0 else 0
	var fill_color: Color = TIER_COLORS[mini(tier, TIER_COLORS.size() - 1)]
	for i: int in range(filled):
		_segment_rects[i].color = Color.WHITE
	var flash_tween := create_tween()
	flash_tween.tween_interval(0.1)
	flash_tween.tween_callback(func() -> void:
		for i: int in range(filled):
			_segment_rects[i].color = fill_color
	)
