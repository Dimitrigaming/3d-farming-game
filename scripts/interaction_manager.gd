extends RayCast3D

@onready var player_inventory: Node = get_node("../../../PlayerInventory")
@onready var hud = get_node("../../../HUD")

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

	_update_hud()

func _find_interactable(hit) -> Node:
	if hit == null:
		return null
	if hit.is_in_group("interactable"):
		return hit
	if hit.get_parent() and hit.get_parent().is_in_group("interactable"):
		return hit.get_parent()
	return null

func _update_hud() -> void:
	var hints: Array[String] = []
	var held = player_inventory.held_item

	if held:
		if held.has_method("get_unpack_hint"):
			hints.append("[E] %s" % held.get_unpack_hint())
		if held.has_method("_toggle_lid"):
			hints.append("[F] Open/Close")
		var drop_text = "Drop"
		if held.has_method("get_drop_hint"):
			drop_text = held.get_drop_hint()
		hints.append("[G] %s" % drop_text)

	if current_target:
		if current_target.has_method("get_click_hint"):
			var click_text: String = current_target.get_click_hint(player_inventory)
			if click_text != "":
				hints.append("[Click] %s" % click_text)
		if current_target.has_method("get_pack_hint"):
			var pack_text: String = current_target.get_pack_hint(player_inventory)
			if pack_text != "":
				hints.append("[R] %s" % pack_text)
		if held == null:
			if current_target.has_method("get_interact_hint"):
				var interact_text: String = current_target.get_interact_hint()
				if interact_text != "":
					hints.append("[E] %s" % interact_text)
			if current_target.has_method("get_lid_hint"):
				hints.append("[F] %s" % current_target.get_lid_hint())

	hud.set_hints(hints)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if current_target:
			current_target.interact()
		elif player_inventory.held_item and player_inventory.held_item.has_method("unpack_at"):
			player_inventory.unpack_held_item()

	if event.is_action_pressed("pack_item") and current_target and current_target.has_method("pack_away"):
		current_target.pack_away(player_inventory)

	if event.is_action_pressed("drop"):
		player_inventory.place_box()

	if event.is_action_pressed("open_close_box"):
		if player_inventory.held_item != null and player_inventory.held_item.has_method("_toggle_lid"):
			player_inventory.held_item._toggle_lid()
		elif current_target and current_target.has_method("_toggle_lid"):
			current_target._toggle_lid()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if current_target and current_target.has_method("try_trash"):
			current_target.try_trash(player_inventory)
		elif current_target and current_target.has_method("get_collectable_item_type"):
			var item_type: String = current_target.get_collectable_item_type()
			if item_type != "" and player_inventory.collect_item(item_type, current_target.global_position):
				current_target.clear_print()
