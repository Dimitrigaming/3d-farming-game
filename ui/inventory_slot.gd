extends PanelContainer

@export var is_hotbar_slot: bool = false
var slot_index: int = -1
var player_inventory: PlayerInventoryData = null

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)

func _get_array() -> Array:
	return player_inventory.hotbar_slots if is_hotbar_slot else player_inventory.slots

func _on_mouse_entered() -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.is_key_pressed(KEY_SHIFT):
		_shift_click()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.shift_pressed:
		_shift_click()
		accept_event()

func _shift_click() -> void:
	if slot_index < 0:
		return
	var array = _get_array()
	var data = array[slot_index]
	if data["item_id"] == "":
		return
	# If chest is open, prioritize moving to chest
	var chest_ui = get_tree().get_first_node_in_group("chest_ui")
	if chest_ui != null and chest_ui._is_open:
		for i in chest_ui.chest_slots.size():
			if chest_ui.chest_slots[i]["item_id"] == "":
				chest_ui.chest_slots[i] = data.duplicate()
				array[slot_index] = {"item_id": "", "amount": 0}
				player_inventory.inventory_changed.emit()
				chest_ui.refresh_chest()
				return
		return
	# Default: move between hotbar and main inventory
	if is_hotbar_slot:
		for i in player_inventory.slots.size():
			if player_inventory.slots[i]["item_id"] == "":
				player_inventory.slots[i] = data.duplicate()
				player_inventory.hotbar_slots[slot_index] = {"item_id": "", "amount": 0}
				player_inventory.inventory_changed.emit()
				return
	else:
		for i in player_inventory.hotbar_slots.size():
			if player_inventory.hotbar_slots[i]["item_id"] == "":
				player_inventory.hotbar_slots[i] = data.duplicate()
				player_inventory.slots[slot_index] = {"item_id": "", "amount": 0}
				player_inventory.inventory_changed.emit()
				return

func _get_drag_data(_pos: Vector2) -> Variant:
	if slot_index < 0:
		return null
	var data = _get_array()[slot_index]
	if data["item_id"] == "":
		return null

	return {"from_slot": slot_index, "source": "hotbar" if is_hotbar_slot else "inventory", "icon": get_node("Icon").texture}

func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("from_slot")

func _drop_data(_pos: Vector2, data: Variant) -> void:
	var from = data["from_slot"]
	var source = data.get("source", "inventory")
	var array = _get_array()
	if source == "chest":
		# Chest → inventory/hotbar cross-swap
		var chest_ui = get_tree().get_first_node_in_group("chest_ui")
		if chest_ui == null:
			return
		var chest_data = chest_ui.chest_slots[from].duplicate()
		var local_data = array[slot_index].duplicate()
		chest_ui.chest_slots[from] = local_data
		array[slot_index] = chest_data
		player_inventory.inventory_changed.emit()
		chest_ui.refresh_chest()
	elif source == "craft_output":
		# Craft output → inventory/hotbar (one-way: only pull crafted goods out)
		var crafting_ui = get_tree().get_first_node_in_group("crafting_ui")
		if crafting_ui == null or crafting_ui.current_station == null:
			return
		if array[slot_index]["item_id"] != "":
			return
		var output_slots = crafting_ui.current_station.output_slots
		array[slot_index] = output_slots[from].duplicate()
		output_slots[from] = {"item_id": "", "amount": 0}
		player_inventory.inventory_changed.emit()
		crafting_ui.refresh_output()
	elif source == "hotbar" and not is_hotbar_slot:
		# Hotbar → main inventory cross-swap
		var hotbar_data = player_inventory.hotbar_slots[from].duplicate()
		var inv_data = player_inventory.slots[slot_index].duplicate()
		player_inventory.hotbar_slots[from] = inv_data
		player_inventory.slots[slot_index] = hotbar_data
		player_inventory.inventory_changed.emit()
	elif source == "inventory" and is_hotbar_slot:
		# Main inventory → hotbar cross-swap
		var inv_data = player_inventory.slots[from].duplicate()
		var hotbar_data = player_inventory.hotbar_slots[slot_index].duplicate()
		player_inventory.slots[from] = hotbar_data
		player_inventory.hotbar_slots[slot_index] = inv_data
		player_inventory.inventory_changed.emit()
	elif from != slot_index:
		var tmp = array[from].duplicate()
		array[from] = array[slot_index]
		array[slot_index] = tmp
		player_inventory.inventory_changed.emit()
