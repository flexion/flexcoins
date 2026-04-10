extends TextureRect


func _ready() -> void:
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_resize_to_viewport()
	get_viewport().size_changed.connect(_resize_to_viewport)


func _resize_to_viewport() -> void:
	var vp_size := get_viewport_rect().size
	position = Vector2.ZERO
	size = vp_size
