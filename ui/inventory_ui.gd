extends CanvasLayer

@onready var grid = $Panel/VBox/GridBg/Grid
@onready var hotbar = $Panel/VBox/HotbarBg/Hotbar

var _hovered_slot: int = -1

func _ready() -> void:
	Inventory.inventory_changed.connect(_refresh)
	_assign_indices()
	call_deferred("_refresh")

func _assign_indices() -> void:
	var grid_slots = grid.get_children()
	for i in grid_slots.size():
		var slot = grid_slots[i]
		slot.slot_index = i
		slot.mouse_entered.connect(func(): _hovered_slot = slot.slot_index)
		slot.mouse_exited.connect(func(): if _hovered_slot == slot.slot_index: _hovered_slot = -1)
	var hotbar_slots = hotbar.get_children()
	for i in hotbar_slots.size():
		var slot = hotbar_slots[i]
		slot.slot_index = Inventory.HOTBAR_START + i
		slot.mouse_entered.connect(func(): _hovered_slot = slot.slot_index)
		slot.mouse_exited.connect(func(): if _hovered_slot == slot.slot_index: _hovered_slot = -1)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo:
		var key = event.keycode
		if key >= KEY_1 and key <= KEY_9:
			var hotbar_index = Inventory.HOTBAR_START + (key - KEY_1)
			if _hovered_slot >= 0 and _hovered_slot != hotbar_index and Inventory.slots[_hovered_slot]["item_id"] != "":
				Inventory.swap_slots(_hovered_slot, hotbar_index)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("inventory") or (visible and event.is_action_pressed("ui_cancel")):
		visible = not visible
		if visible:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		_set_player_enabled(not visible)
		_set_crosshair_visible(not visible)
		get_viewport().set_input_as_handled()

func _set_player_enabled(enabled: bool) -> void:
	var controller = get_tree().get_first_node_in_group("proto_controller")
	if controller:
		controller.process_mode = Node.PROCESS_MODE_DISABLED if not enabled else Node.PROCESS_MODE_INHERIT

func _set_crosshair_visible(visible: bool) -> void:
	var controller = get_tree().get_first_node_in_group("proto_controller")
	if controller:
		var crosshair = controller.get_node_or_null("HUD/Crosshair")
		if crosshair:
			crosshair.visible = visible

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
