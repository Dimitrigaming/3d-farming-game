extends PanelContainer

@export var is_hotbar_slot: bool = false
var slot_index: int = -1

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)

func _get_array() -> Array:
	return Inventory.hotbar_slots if is_hotbar_slot else Inventory.slots

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
				Inventory.inventory_changed.emit()
				chest_ui.refresh_chest()
				return
		return
	# Default: move between hotbar and main inventory
	if is_hotbar_slot:
		for i in Inventory.slots.size():
			if Inventory.slots[i]["item_id"] == "":
				Inventory.slots[i] = data.duplicate()
				Inventory.hotbar_slots[slot_index] = {"item_id": "", "amount": 0}
				Inventory.inventory_changed.emit()
				return
	else:
		for i in Inventory.hotbar_slots.size():
			if Inventory.hotbar_slots[i]["item_id"] == "":
				Inventory.hotbar_slots[i] = data.duplicate()
				Inventory.slots[slot_index] = {"item_id": "", "amount": 0}
				Inventory.inventory_changed.emit()
				return

func _get_drag_data(_pos: Vector2) -> Variant:
	if slot_index < 0:
		return null
	var data = _get_array()[slot_index]
	if data["item_id"] == "":
		return null

	# Ghost preview
	var preview = TextureRect.new()
	preview.texture = get_node("Icon").texture
	preview.custom_minimum_size = Vector2(40, 40)
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	set_drag_preview(preview)

	return {"from_slot": slot_index, "source": "hotbar" if is_hotbar_slot else "inventory"}

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
		Inventory.inventory_changed.emit()
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
		Inventory.inventory_changed.emit()
		crafting_ui.refresh_output()
	elif source == "hotbar" and not is_hotbar_slot:
		# Hotbar → main inventory cross-swap
		var hotbar_data = Inventory.hotbar_slots[from].duplicate()
		var inv_data = Inventory.slots[slot_index].duplicate()
		Inventory.hotbar_slots[from] = inv_data
		Inventory.slots[slot_index] = hotbar_data
		Inventory.inventory_changed.emit()
	elif source == "inventory" and is_hotbar_slot:
		# Main inventory → hotbar cross-swap
		var inv_data = Inventory.slots[from].duplicate()
		var hotbar_data = Inventory.hotbar_slots[slot_index].duplicate()
		Inventory.slots[from] = hotbar_data
		Inventory.hotbar_slots[slot_index] = inv_data
		Inventory.inventory_changed.emit()
	elif from != slot_index:
		var tmp = array[from].duplicate()
		array[from] = array[slot_index]
		array[slot_index] = tmp
		Inventory.inventory_changed.emit()
