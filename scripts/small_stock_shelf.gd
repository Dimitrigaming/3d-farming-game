extends Node3D

const PACKING_CRATE_SCENE = preload("res://models/packing_crate.tscn")
const OWN_SCENE = preload("res://models/small_stock_shelf.tscn")

func _ready() -> void:
	add_to_group("interactable")

func show_tooltip() -> void:
	pass

func hide_tooltip() -> void:
	pass

func interact() -> void:
	pass

func get_move_hint() -> String:
	return "Move"

func get_pack_hint(player_inventory) -> String:
	if player_inventory.held_item == null:
		return "Pack Away"
	return ""

func pack_away(player_inventory) -> void:
	if player_inventory.held_item != null:
		return
	var crate = PACKING_CRATE_SCENE.instantiate()
	get_tree().current_scene.add_child(crate)
	crate.pack("Small Stock Shelf", OWN_SCENE)
	player_inventory.pick_up_item(crate)
	queue_free()
