extends Node3D

enum PlacementRoom { ANYWHERE, SHOP_ONLY, PRODUCTION_ONLY }
@export var placement_room: PlacementRoom = PlacementRoom.SHOP_ONLY

const PACKING_CRATE_SCENE = preload("res://models/packing_crate.tscn")
const OWN_SCENE = preload("res://models/small_product_shelf.tscn")
const PRINT_MODEL = preload("res://models/default_model.tscn")
const PRINT_HALF_HEIGHT = 0.2

var _aim_point: Vector3 = Vector3.ZERO

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("product_shelf")

func set_aim_point(pos: Vector3) -> void:
	_aim_point = pos

func show_tooltip() -> void:
	pass

func hide_tooltip() -> void:
	pass

func get_move_hint() -> String:
	return "Move"

func get_hidden_passengers() -> Array:
	var passengers = []
	for child in get_children():
		if child.has_method("has_prints"):
			for node in child.stored_print_nodes:
				if is_instance_valid(node):
					passengers.append(node)
	return passengers

func get_pack_hint(player_inventory) -> String:
	if player_inventory.held_item == null:
		return "Pack Away"
	return ""

func pack_away(player_inventory) -> void:
	if player_inventory.held_item != null:
		return
	for child in get_children():
		if child.has_method("has_prints"):
			for node in child.stored_print_nodes:
				if node:
					node.queue_free()
			child.stored_print_nodes.clear()
			child.stored_print_type = ""
	var crate = PACKING_CRATE_SCENE.instantiate()
	get_tree().current_scene.add_child(crate)
	crate.pack("Small Product Shelf", OWN_SCENE)
	player_inventory.pick_up_item(crate)
	queue_free()

func get_click_hint(player_inventory) -> String:
	var held = player_inventory.held_item
	if held != null and held.has_method("remove_item") and not held.is_empty():
		if _aimed_zone(held.item_type) != null:
			return "Stock Shelf"
	return ""

func get_retrieve_hint() -> String:
	if _nearest_occupied_zone() != null:
		return "Retrieve Print"
	return ""

# LMB: send one print from held box to shelf
func interact() -> void:
	var player_inv = get_tree().get_first_node_in_group("player")
	if player_inv == null:
		return
	var held = player_inv.held_item
	if held != null and held.has_method("remove_item") and not held.is_empty():
		_send_box_item_to_shelf(held)

# RMB: pull one print from shelf into box (spawns box if none held)
func retrieve_print(player_inv) -> void:
	var zone = _nearest_occupied_zone()
	if zone == null:
		return
	var held = player_inv.held_item
	if held != null and held.has_method("is_full") and held.is_full():
		return
	var item_type = zone.stored_print_type
	var print_node: Node3D = zone.stored_print_nodes.pop_back()
	if zone.stored_print_nodes.is_empty():
		zone.stored_print_type = ""

	if held == null or not held.has_method("add_item"):
		# Spawn a box via collect_item; animate from shelf position
		var from_pos = print_node.global_position if print_node else global_position
		if print_node:
			print_node.queue_free()
		player_inv.collect_item(item_type, from_pos)
		return

	if held.is_full():
		# Put the print back
		zone.stored_print_nodes.append(print_node)
		if zone.stored_print_type == "":
			zone.stored_print_type = item_type
		return

	if print_node:
		var target = held.global_position
		var tween = get_tree().create_tween()
		tween.tween_property(print_node, "global_position", target, 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		tween.tween_callback(func():
			if held.add_item(item_type):
				print_node.queue_free()
			else:
				zone.stored_print_nodes.append(print_node)
				if zone.stored_print_type == "":
					zone.stored_print_type = item_type
				print_node.global_position = _slot_world_pos(zone, zone.stored_print_nodes.size() - 1)
		)
	else:
		held.add_item(item_type)

# Called by printer shelve action
func add_print(item_type: String, existing_model: Node3D = null) -> bool:
	var zone = _first_available_zone(item_type)
	if zone == null:
		return false
	var index = zone.stored_print_nodes.size()
	var model: Node3D
	if existing_model != null:
		model = existing_model
	else:
		model = PRINT_MODEL.instantiate()
		get_tree().current_scene.add_child(model)
	zone.stored_print_type = item_type
	zone.stored_print_nodes.append(model)
	var target_pos = _slot_world_pos(zone, index)
	get_tree().create_tween().tween_property(model, "global_position", target_pos, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	return true

func _send_box_item_to_shelf(box: Node3D) -> void:
	var zone = _aimed_zone(box.item_type)
	if zone == null:
		return
	var item_type = box.remove_item()
	if item_type == "":
		return
	var index = zone.stored_print_nodes.size()
	var model = PRINT_MODEL.instantiate()
	get_tree().current_scene.add_child(model)
	model.global_position = box.global_position
	zone.stored_print_type = item_type
	zone.stored_print_nodes.append(model)
	get_tree().create_tween().tween_property(model, "global_position", _slot_world_pos(zone, index), 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func _slot_world_pos(zone, index: int) -> Vector3:
	var col = index % 3
	var row = index / 3
	var lx = (col - 1) * (zone.size.x / 3.0)
	var lz = (row - 0.5) * (zone.size.z / 2.0)
	var ly = -zone.size.y / 2.0 + PRINT_HALF_HEIGHT
	return zone.to_global(Vector3(lx, ly, lz))

func _aimed_zone(item_type: String = "") -> Node:
	# Find the closest zone to the aim point regardless of capacity
	var best = null
	var best_dist = INF
	for child in get_children():
		if not child.has_method("is_occupied"):
			continue
		var dist = child.global_position.distance_to(_aim_point)
		if dist < best_dist:
			best_dist = dist
			best = child
	# Only return it if that specific zone has room and accepts this item type
	if best == null or best.is_occupied():
		return null
	if best.stored_print_type != "" and best.stored_print_type != item_type:
		return null
	return best

func _first_available_zone(item_type: String = "") -> Node:
	for child in get_children():
		if not child.has_method("is_occupied") or child.is_occupied():
			continue
		if child.stored_print_type != "" and child.stored_print_type != item_type:
			continue
		return child
	return null

func get_npc_stand_pos() -> Vector3:
	var spot = get_node_or_null("NPCSpot")
	if spot != null:
		return spot.global_position
	return global_position

func has_any_prints() -> bool:
	for child in get_children():
		if child.has_method("has_prints") and child.has_prints():
			return true
	return false

func npc_take_prints(count: int) -> Array[String]:
	var taken: Array[String] = []
	for i in range(count):
		var zone = _any_occupied_zone()
		if zone == null:
			break
		var item_type = zone.stored_print_type
		var node: Node3D = zone.stored_print_nodes.pop_back()
		if zone.stored_print_nodes.is_empty():
			zone.stored_print_type = ""
		if node:
			node.queue_free()
		taken.append(item_type)
	get_node_or_null("/root/GameLogger").debug("Shelf", "NPC took %d/%d prints" % [taken.size(), count])
	return taken

func _any_occupied_zone() -> Node:
	for child in get_children():
		if child.has_method("has_prints") and child.has_prints():
			return child
	return null

func _nearest_occupied_zone() -> Node:
	var best = null
	var best_dist = INF
	for child in get_children():
		if not child.has_method("has_prints"):
			continue
		var dist = child.global_position.distance_to(_aim_point)
		if dist < best_dist:
			best_dist = dist
			best = child
	if best == null or not best.has_prints():
		return null
	return best

