extends Node2D

@export var coin_scene: PackedScene
@export var margin: float = 40.0

var _normal_interval: float = 0.0
var _spawn_sound: AudioStreamPlayer


func _ready() -> void:
	_spawn_sound = AudioStreamPlayer.new()
	_spawn_sound.stream = preload("res://assets/sounds/coin.wav")
	_spawn_sound.volume_db = -30.0
	add_child(_spawn_sound)
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

	coin.coin_type = _roll_coin_type(coin)

	get_parent().add_child(coin)
	_spawn_sound.play()


func _roll_coin_type(coin: Area2D) -> int:
	var level: int = GameManager.get_coin_type_unlock_level()
	var roll := randf()
	# Bombs always spawn; other types descend by unlock order: Copper > Silver > Frenzy > Gold > Multi
	match level:
		0:
			if roll < 0.08:
				return coin.CoinType.BOMB
			return coin.CoinType.COPPER
		1:
			if roll < 0.08:
				return coin.CoinType.BOMB
			elif roll < 0.74:
				return coin.CoinType.COPPER
			return coin.CoinType.SILVER
		2:
			if roll < 0.12:
				return coin.CoinType.FRENZY
			elif roll < 0.20:
				return coin.CoinType.BOMB
			elif roll < 0.75:
				return coin.CoinType.COPPER
			return coin.CoinType.SILVER
		3:
			if roll < 0.10:
				return coin.CoinType.FRENZY
			elif roll < 0.18:
				return coin.CoinType.BOMB
			elif roll < 0.25:
				return coin.CoinType.GOLD
			elif roll < 0.70:
				return coin.CoinType.COPPER
			return coin.CoinType.SILVER
		_:
			if roll < 0.10:
				return coin.CoinType.FRENZY
			elif roll < 0.18:
				return coin.CoinType.BOMB
			elif roll < 0.23:
				return coin.CoinType.MULTI
			elif roll < 0.30:
				return coin.CoinType.GOLD
			elif roll < 0.70:
				return coin.CoinType.COPPER
			return coin.CoinType.SILVER


func _on_shop_opened() -> void:
	$Timer.paused = true


func _on_shop_closed() -> void:
	$Timer.paused = false
