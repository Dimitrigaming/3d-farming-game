extends RayCast3D

@onready var player_inventory: Node = get_node("../../../PlayerInventory")

var current_target = null

func _process(_delta: float) -> void:
	var hit = get_collider()
	var interactable = _find_interactable(hit)

	if interactable:
		if interactable != current_target:
			if current_target:
				current_target.hide_tooltip()
				if current_target.has_method("on_look_away"):
					current_target.on_look_away()
			current_target = interactable
			current_target.show_tooltip()
		if current_target.has_method("on_aimed_at"):
			current_target.on_aimed_at(player_inventory)
	else:
		if current_target:
			current_target.hide_tooltip()
			if current_target.has_method("on_look_away"):
				current_target.on_look_away()
			current_target = null

func _find_interactable(hit) -> Node:
	if hit == null:
		return null
	if hit.is_in_group("interactable"):
		return hit
	if hit.get_parent() and hit.get_parent().is_in_group("interactable"):
		return hit.get_parent()
	return null

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and current_target:
		current_target.interact()

	if event.is_action_pressed("drop"):
		player_inventory.place_box()

	if event.is_action_pressed("open_close_box"):
		if player_inventory.held_box != null:
			player_inventory.held_box._toggle_lid()
		elif current_target and current_target.has_method("_toggle_lid"):
			current_target._toggle_lid()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if current_target and current_target.has_method("try_trash"):
			current_target.try_trash(player_inventory)
		elif current_target and current_target.has_method("get_collectable_item_type"):
			var item_type: String = current_target.get_collectable_item_type()
			if item_type != "" and player_inventory.collect_item(item_type, current_target.global_position):
				current_target.clear_print()
