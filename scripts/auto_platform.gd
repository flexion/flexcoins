extends Area2D

const SPRITE_NATIVE_W: float = 128.0
const SPRITE_NATIVE_H: float = 8.0
const PLATFORM_HEIGHT: float = 14.0
const WIDTH_FRACTION: float = 0.6
const PATROL_SPEED: float = 250.0
const TINT_COLOR := Color(0.2, 0.8, 0.7, 0.6)

var floating_text_scene: PackedScene
var _direction: float = 1.0
var _game_paused: bool = false
var _base_scale: Vector2 = Vector2.ONE

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("catcher")
	collision_shape.shape = collision_shape.shape.duplicate()
	_direction = [-1.0, 1.0].pick_random()
	position.x = randf_range(200.0, get_viewport_rect().size.x - 200.0)
	sprite.modulate = TINT_COLOR
	GameManager.shop_opened.connect(_on_shop_opened)
	GameManager.shop_closed.connect(_on_shop_closed)
	GameManager.upgrade_purchased.connect(_on_upgrade_purchased)
	_apply_size()


func _process(delta: float) -> void:
	if _game_paused:
		return
	var w: float = GameManager.get_catcher_width() * WIDTH_FRACTION
	var half_width: float = w / 2.0
	var viewport_width: float = get_viewport_rect().size.x
	position.x += _direction * PATROL_SPEED * delta
	if position.x <= half_width:
		position.x = half_width
		_direction = 1.0
	elif position.x >= viewport_width - half_width:
		position.x = viewport_width - half_width
		_direction = -1.0


func _on_area_entered(area: Area2D) -> void:
	if area.has_method("collect") and not area.get("_collected"):
		area._collected = true
		var value: int = area.value
		var pos: Vector2 = area.global_position
		GameManager.coin_collected.emit(value, pos)
		_spawn_floating_text(pos, value, area.coin_type)
		area.collect()


func _spawn_floating_text(at_position: Vector2, value: int, coin_type: int = 0) -> void:
	if value == 0:
		return
	if floating_text_scene:
		var ft: Label = floating_text_scene.instantiate()
		ft.text = "+%d" % value
		ft.coin_type = coin_type
		ft.combo_level = 0
		ft.position = at_position + Vector2(randf_range(-10.0, 10.0), -10.0)
		ft.z_index = 250
		get_parent().add_child(ft)


func _apply_size() -> void:
	var w: float = GameManager.get_catcher_width() * WIDTH_FRACTION
	_base_scale = Vector2(w / SPRITE_NATIVE_W, PLATFORM_HEIGHT / SPRITE_NATIVE_H)
	sprite.scale = _base_scale
	collision_shape.shape.size = Vector2(w, PLATFORM_HEIGHT)


func _on_upgrade_purchased(_id: String) -> void:
	_apply_size()


func _on_shop_opened() -> void:
	_game_paused = true
	monitoring = false


func _on_shop_closed() -> void:
	_game_paused = false
	monitoring = true
