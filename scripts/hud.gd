extends CanvasLayer


func _ready() -> void:
	GameManager.currency_changed.connect(_on_currency_changed)
	_on_currency_changed(0)


func _on_currency_changed(new_amount: int) -> void:
	%CurrencyLabel.text = "Coins: %d" % new_amount
