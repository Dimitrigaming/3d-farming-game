extends Node

func _ready() -> void:
	_give_starter_tools()

func _give_starter_tools() -> void:
	var tools = ["hoe", "shovel", "axe", "pickaxe", "hammer"]
	for i in tools.size():
		var slot = Inventory.slots[Inventory.HOTBAR_START + i]
		slot["item_id"] = tools[i]
		slot["amount"] = 1
	Inventory.inventory_changed.emit()
