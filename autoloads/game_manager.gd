extends Node

func _ready() -> void:
	_give_starter_tools()
	Inventory.add_item("wood", 99)
	Inventory.add_item("stone", 99)

func _give_starter_tools() -> void:
	var tools = ["hoe", "shovel", "axe", "pickaxe", "hammer", "scythe", "crafting_workbench"]
	for i in tools.size():
		var slot = Inventory.hotbar_slots[i]
		slot["item_id"] = tools[i]
		slot["amount"] = 1
	Inventory.inventory_changed.emit()
