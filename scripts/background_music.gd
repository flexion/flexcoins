extends AudioStreamPlayer

var _music_paused: bool = false


func _ready() -> void:
	GameManager.shop_opened.connect(_on_shop_opened)
	GameManager.shop_closed.connect(_on_shop_closed)


func _on_shop_opened() -> void:
	if playing and not _music_paused:
		stream_paused = true
		_music_paused = true


func _on_shop_closed() -> void:
	if _music_paused:
		stream_paused = false
		_music_paused = false
