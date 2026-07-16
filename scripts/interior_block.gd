extends StaticBody3D

@onready var game_state: Node = get_node("/root/GameState")
@onready var hud = get_tree().get_first_node_in_group("hud")

func _ready() -> void:
	add_to_group("interactable")

func get_interact_hint() -> String:
	return "Unlock Wall - $%d" % game_state.get_next_unlock_price()

func interact() -> void:
	if game_state.unlock_block():
		var block = get_parent()
		block.visible = false
		block.remove_from_group("interior_block")
		for body in block.find_children("*", "StaticBody3D", true, false):
			body.collision_layer = 0
			body.collision_mask = 0
		var interior = get_tree().get_first_node_in_group("interior_manager")
		if interior:
			interior.spawn_nav_link(block.global_position)
		var manager = get_tree().get_first_node_in_group("nav_links_store")
		if manager:
			manager.refresh_at(block.global_position)
		await get_tree().create_timer(5.0).timeout
		block.queue_free()
	else:
		hud.show_notification("Not enough money!")


func show_tooltip() -> void:
	pass

func hide_tooltip() -> void:
	pass
