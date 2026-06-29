extends RayCast3D

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
