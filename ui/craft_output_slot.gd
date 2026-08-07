extends PanelContainer

var slot_index: int = -1

func _get_crafting_ui():
	return get_tree().get_first_node_in_group("crafting_ui")

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
	var crafting_ui = _get_crafting_ui()
	if crafting_ui == null or crafting_ui.current_station == null or slot_index < 0:
		return
	var output_slots = crafting_ui.current_station.output_slots
	var data = output_slots[slot_index]
	if data["item_id"] == "":
		return
	for i in Inventory.slots.size():
		if Inventory.slots[i]["item_id"] == "":
			Inventory.slots[i] = data.duplicate()
			output_slots[slot_index] = {"item_id": "", "amount": 0}
			Inventory.inventory_changed.emit()
			crafting_ui.refresh_output()
			return

func _get_drag_data(_pos: Vector2) -> Variant:
	if slot_index < 0:
		return null
	var crafting_ui = _get_crafting_ui()
	if crafting_ui == null or crafting_ui.current_station == null:
		return null
	var data = crafting_ui.current_station.output_slots[slot_index]
	if data["item_id"] == "":
		return null
	var preview = TextureRect.new()
	preview.texture = get_node("Icon").texture
	preview.custom_minimum_size = Vector2(40, 40)
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	set_drag_preview(preview)
	return {"from_slot": slot_index, "source": "craft_output"}

func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("from_slot") and data.has("source")

func _drop_data(_pos: Vector2, data: Variant) -> void:
	var crafting_ui = _get_crafting_ui()
	if crafting_ui == null or crafting_ui.current_station == null:
		return
	var output_slots = crafting_ui.current_station.output_slots
	var from = data["from_slot"]
	var source = data.get("source", "inventory")
	if source == "craft_output":
		if from != slot_index:
			var tmp = output_slots[from].duplicate()
			output_slots[from] = output_slots[slot_index].duplicate()
			output_slots[slot_index] = tmp
			crafting_ui.refresh_output()
	else:
		# Only allow pulling items OUT of output (crafted goods), not depositing into it.
		return
