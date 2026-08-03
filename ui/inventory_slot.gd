extends PanelContainer

var slot_index: int = -1

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.shift_pressed:
		_shift_click()
		accept_event()

func _shift_click() -> void:
	if slot_index < 0:
		return
	var data = Inventory.slots[slot_index]
	if data["item_id"] == "":
		return
	var target_start: int
	var target_end: int
	if slot_index >= Inventory.HOTBAR_START:
		target_start = 0
		target_end = Inventory.HOTBAR_START - 1
	else:
		target_start = Inventory.HOTBAR_START
		target_end = Inventory.HOTBAR_START + Inventory.HOTBAR_SIZE - 1
	for i in range(target_start, target_end + 1):
		if Inventory.slots[i]["item_id"] == "":
			Inventory.swap_slots(slot_index, i)
			return

func _get_drag_data(_pos: Vector2) -> Variant:
	if slot_index < 0:
		return null
	var data = Inventory.slots[slot_index]
	if data["item_id"] == "":
		return null

	# Ghost preview
	var preview = TextureRect.new()
	preview.texture = get_node("Icon").texture
	preview.custom_minimum_size = Vector2(40, 40)
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	set_drag_preview(preview)

	return {"from_slot": slot_index}

func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("from_slot")

func _drop_data(_pos: Vector2, data: Variant) -> void:
	var from = data["from_slot"]
	if from != slot_index:
		Inventory.swap_slots(from, slot_index)
