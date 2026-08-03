extends CanvasLayer

@onready var grid = $Panel/VBox/GridBg/Grid
@onready var hotbar = $Panel/VBox/HotbarBg/Hotbar

func _ready() -> void:
	Inventory.inventory_changed.connect(_refresh)
	_assign_indices()
	call_deferred("_refresh")

func _assign_indices() -> void:
	var grid_slots = grid.get_children()
	for i in grid_slots.size():
		grid_slots[i].slot_index = i
	var hotbar_slots = hotbar.get_children()
	for i in hotbar_slots.size():
		hotbar_slots[i].slot_index = Inventory.HOTBAR_START + i

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		visible = not visible
		if visible:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		_set_player_enabled(not visible)
		get_viewport().set_input_as_handled()

func _set_player_enabled(enabled: bool) -> void:
	var controller = get_tree().get_first_node_in_group("proto_controller")
	if controller:
		controller.process_mode = Node.PROCESS_MODE_DISABLED if not enabled else Node.PROCESS_MODE_INHERIT

func _refresh() -> void:
	_refresh_grid(grid.get_children(), 0)
	_refresh_grid(hotbar.get_children(), Inventory.HOTBAR_START)

func _refresh_grid(slot_nodes: Array, offset: int) -> void:
	for i in slot_nodes.size():
		var slot_data = Inventory.slots[offset + i]
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
