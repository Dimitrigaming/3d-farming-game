extends PanelContainer

var slot_index: int = -1

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
