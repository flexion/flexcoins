extends Node2D

@export var coin_scene: PackedScene
@export var margin: float = 40.0

var _normal_interval: float = 0.0


func _ready() -> void:
	_normal_interval = GameManager.get_spawn_interval()
	$Timer.wait_time = _normal_interval
	$Timer.start()
	GameManager.upgrade_purchased.connect(_on_upgrade_purchased)
	GameManager.frenzy_started.connect(_on_frenzy_started)
	GameManager.frenzy_ended.connect(_on_frenzy_ended)
	GameManager.shop_opened.connect(_on_shop_opened)
	GameManager.shop_closed.connect(_on_shop_closed)


func _on_upgrade_purchased(upgrade_id: String) -> void:
	if upgrade_id == "spawn_rate":
		_normal_interval = GameManager.get_spawn_interval()
		if not GameManager.frenzy_active:
			$Timer.wait_time = _normal_interval


func _on_frenzy_started() -> void:
	$Timer.wait_time = _normal_interval / 3.0


func _on_frenzy_ended() -> void:
	$Timer.wait_time = _normal_interval


func _on_timer_timeout() -> void:
	if coin_scene == null:
		return
	var coin: Area2D = coin_scene.instantiate()
	var viewport_width := get_viewport_rect().size.x
	coin.position = Vector2(randf_range(margin, viewport_width - margin), -50.0)

	# Determine coin type: 5% frenzy, 8% bomb, 10% gold, rest silver
	var roll := randf()
	if roll < 0.05:
		coin.coin_type = coin.CoinType.FRENZY
	elif roll < 0.13:
		coin.coin_type = coin.CoinType.BOMB
	elif roll < 0.23:
		coin.coin_type = coin.CoinType.GOLD

	get_parent().add_child(coin)


func _on_shop_opened() -> void:
	$Timer.paused = true


func _on_shop_closed() -> void:
	$Timer.paused = false
