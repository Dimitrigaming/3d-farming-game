extends PanelContainer

var slot_index: int = -1

func _get_inventory() -> PlayerInventoryData:
	return get_tree().get_first_node_in_group("player_inventory_data")

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)

func _on_mouse_entered() -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.is_key_pressed(KEY_SHIFT):
		_shift_click()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.shift_pressed:
		_shift_click()
		accept_event()

func _shift_click() -> void:
	var chest_ui = get_tree().get_first_node_in_group("chest_ui")
	var inventory = _get_inventory()
	if chest_ui == null or inventory == null or slot_index < 0:
		return
	var data = chest_ui.chest_slots[slot_index]
	if data["item_id"] == "":
		return
	# Shift-click moves to first empty inventory slot
	for i in inventory.slots.size():
		if inventory.slots[i]["item_id"] == "":
			var inv_data = inventory.slots[i].duplicate()
			var chest_data = chest_ui.chest_slots[slot_index].duplicate()
			inventory.slots[i] = chest_data
			chest_ui.chest_slots[slot_index] = inv_data
			inventory.inventory_changed.emit()
			chest_ui.refresh_chest()
			return

func _get_drag_data(_pos: Vector2) -> Variant:
	if slot_index < 0:
		return null
	var chest_ui = get_tree().get_first_node_in_group("chest_ui")
	if chest_ui == null:
		return null
	var data = chest_ui.chest_slots[slot_index]
	if data["item_id"] == "":
		return null
	return {"from_slot": slot_index, "source": "chest", "icon": get_node("Icon").texture}

func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("from_slot") and data.has("source")

func _drop_data(_pos: Vector2, data: Variant) -> void:
	var chest_ui = get_tree().get_first_node_in_group("chest_ui")
	if chest_ui == null:
		return
	var from = data["from_slot"]
	var source = data.get("source", "inventory")
	if source == "chest":
		if from != slot_index:
			var tmp = chest_ui.chest_slots[from].duplicate()
			chest_ui.chest_slots[from] = chest_ui.chest_slots[slot_index].duplicate()
			chest_ui.chest_slots[slot_index] = tmp
			chest_ui.refresh_chest()
	else:
		# Inventory → chest
		var inventory = _get_inventory()
		if inventory == null:
			return
		var inv_data = inventory.slots[from].duplicate()
		var chest_data = chest_ui.chest_slots[slot_index].duplicate()
		inventory.slots[from] = chest_data
		chest_ui.chest_slots[slot_index] = inv_data
		inventory.inventory_changed.emit()
		chest_ui.refresh_chest()
