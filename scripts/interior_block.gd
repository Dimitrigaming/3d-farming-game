extends StaticBody3D

@onready var game_state: Node = get_node("/root/GameState")
@onready var hud = get_tree().get_first_node_in_group("hud")

func _ready() -> void:
	add_to_group("interactable")

func get_interact_hint() -> String:
	return "Unlock Wall - $%d" % game_state.get_next_unlock_price()

func interact() -> void:
	if game_state.unlock_block():
		get_parent().queue_free()
	else:
		hud.show_notification("Not enough money!")

func show_tooltip() -> void:
	pass

func hide_tooltip() -> void:
	pass
