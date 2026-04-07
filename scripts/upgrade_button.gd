extends PanelContainer

var upgrade_id: String = ""

@onready var name_label: Label = %NameLabel
@onready var effect_label: Label = %EffectLabel
@onready var buy_button: Button = %BuyButton


func setup(id: String) -> void:
	upgrade_id = id


func _ready() -> void:
	buy_button.pressed.connect(_on_buy_pressed)
	GameManager.currency_changed.connect(_on_currency_changed)
	GameManager.upgrade_purchased.connect(_on_upgrade_changed)
	_update_display()


func _on_buy_pressed() -> void:
	GameManager.try_purchase_upgrade(upgrade_id)


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
	name_label.text = "%s  Lv.%d" % [data.name, level]
	effect_label.text = data.description
	buy_button.text = "Buy: %d" % cost
	buy_button.disabled = GameManager.currency < cost
