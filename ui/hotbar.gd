extends CanvasLayer

@onready var grid = $Panel/Grid

func _ready() -> void:
	Inventory.inventory_changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	var slot_nodes = grid.get_children()
	for i in slot_nodes.size():
		var slot_data = Inventory.slots[Inventory.HOTBAR_START + i]
		var slot_node = slot_nodes[i]
		var icon = slot_node.get_node("Icon")
		var count = slot_node.get_node("Count")
		var has_item = slot_data["item_id"] != ""
		icon.visible = has_item
		count.visible = has_item and slot_data["amount"] > 1
		if has_item:
			count.text = str(slot_data["amount"])
			var def = ItemDB.get_item(slot_data["item_id"])
			icon.texture = def.icon if def else null
