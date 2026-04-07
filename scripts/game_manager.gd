extends Node

signal currency_changed(new_amount: int)

var currency: int = 0


func add_currency(amount: int) -> void:
	currency += amount
	currency_changed.emit(currency)
