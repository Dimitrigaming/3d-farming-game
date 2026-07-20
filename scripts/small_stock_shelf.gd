extends Node3D

enum PlacementRoom { ANYWHERE, SHOP_ONLY, PRODUCTION_ONLY }
@export var placement_room: PlacementRoom = PlacementRoom.ANYWHERE

const PACKING_CRATE_SCENE = preload("res://models/packing_crate.tscn")
const OWN_SCENE = preload("res://models/small_stock_shelf.tscn")

func _ready() -> void:
	add_to_group("interactable")

func show_tooltip() -> void:
	pass

func hide_tooltip() -> void:
	pass

var _aim_point: Vector3 = Vector3.ZERO

func set_aim_point(pos: Vector3) -> void:
	_aim_point = pos

func get_click_hint(player_inventory) -> String:
	var held = player_inventory.held_item
	if held != null and held.has_method("store"):
		for child in get_children():
			if child.has_method("is_occupied") and not child.is_occupied():
				return "Store Box"
	elif held == null:
		for child in get_children():
			if child.has_method("is_occupied") and child.is_occupied() and child.stored_box != null:
				return "Pick Up"
	return ""

func interact() -> void:
	var player_inv = get_tree().get_first_node_in_group("player")
	if player_inv == null:
		return

	if player_inv.held_item == null:
		var best_box = null
		var best_y_dist = INF
		for child in get_children():
			if child.has_method("is_occupied") and child.is_occupied() and child.stored_box != null:
				var y_dist = abs(child.global_position.y - _aim_point.y)
				if y_dist < best_y_dist:
					best_y_dist = y_dist
					best_box = child.stored_box
		if best_box != null:
			best_box.interact()
		return

	var box = player_inv.held_item
	if not box.has_method("store"):
		return

	var best_zone = null
	var best_dist = INF
	for child in get_children():
		if child.has_method("is_occupied") and not child.is_occupied():
			var dist = child.global_position.distance_to(_aim_point)
			if dist < best_dist:
				best_dist = dist
				best_zone = child
	if best_zone == null:
		return

	player_inv.held_item = null
	var target_pos = best_zone.global_position
	target_pos.y = best_zone.global_position.y - best_zone.size.y / 2.0 + 0.35
	var target_rot = Vector3(0, global_rotation.y + PI / 2.0, 0)
	box.reparent(get_tree().current_scene)
	box.store(best_zone)
	best_zone.stored_box = box

	if box.is_open:
		box._toggle_lid()
	box.tween_to(target_pos, target_rot)

func get_move_hint() -> String:
	return "Move"

func get_hidden_passengers() -> Array:
	var passengers = []
	for child in get_children():
		if child.has_method("is_occupied") and child.stored_box != null and is_instance_valid(child.stored_box):
			passengers.append(child.stored_box)
	return passengers

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
