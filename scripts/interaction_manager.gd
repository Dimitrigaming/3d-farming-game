extends RayCast3D

@onready var player_inventory: Node = get_node("../../../PlayerInventory")

var current_target = null

func _process(_delta: float) -> void:
	var hit = get_collider()

	if hit and hit.get_parent().is_in_group("interactable"):
		var interactable = hit.get_parent()
		if interactable != current_target:
			if current_target:
				current_target.hide_tooltip()
			current_target = interactable
			current_target.show_tooltip()
	else:
		if current_target:
			current_target.hide_tooltip()
			current_target = null

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and current_target:
		current_target.interact()

	if event.is_action_pressed("place_box"):
		player_inventory.place_box()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if current_target and current_target.has_method("get_collectable_item_type"):
			var item_type: String = current_target.get_collectable_item_type()
			if item_type != "" and player_inventory.collect_item(item_type):
				current_target.clear_print()
