extends Node2D

const AUTO_PLATFORM_SCENE: PackedScene = preload("res://scenes/auto_platform.tscn")
const PLATFORM_BOTTOM_OFFSET: float = 150.0

@export var floating_text_scene: PackedScene

var _platforms: Array[Area2D] = []


func _ready() -> void:
	GameManager.upgrade_purchased.connect(_on_upgrade_purchased)
	_sync_platforms()


func _on_upgrade_purchased(_id: String) -> void:
	_sync_platforms()


func _sync_platforms() -> void:
	var target: int = GameManager.get_auto_catcher_count()
	var current: int = _platforms.size()
	if current == target:
		return
	if current > target:
		for i: int in range(current - 1, target - 1, -1):
			_platforms[i].queue_free()
			_platforms.remove_at(i)
	elif current < target:
		for i: int in range(current, target):
			var platform: Area2D = AUTO_PLATFORM_SCENE.instantiate()
			platform.floating_text_scene = floating_text_scene
			get_parent().add_child(platform)
			_platforms.append(platform)
	_reposition_platforms()


func _reposition_platforms() -> void:
	var platform_y: float = get_viewport_rect().size.y - PLATFORM_BOTTOM_OFFSET
	for p: Area2D in _platforms:
		p.position.y = platform_y


