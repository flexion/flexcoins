extends CanvasLayer

@export var upgrade_button_scene: PackedScene

@onready var currency_label: Label = %CurrencyLabel
@onready var upgrade_container: VBoxContainer = %UpgradeContainer
@onready var upgrade_panel: PanelContainer = %UpgradePanel
@onready var shop_toggle: Button = %ShopToggle
@onready var welcome_panel: PanelContainer = %WelcomePanel
@onready var welcome_earnings_label: Label = %WelcomeEarningsLabel
@onready var welcome_button: Button = %WelcomeButton


func _ready() -> void:
	GameManager.currency_changed.connect(_on_currency_changed)
	_on_currency_changed(GameManager.currency)
	_create_upgrade_buttons()
	shop_toggle.pressed.connect(_on_shop_toggle_pressed)
	_check_offline_earnings()


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
