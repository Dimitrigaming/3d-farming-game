extends Node3D

const PACKING_CRATE_SCENE = preload("res://models/packing_crate.tscn")
const OWN_SCENE = preload("res://models/register.tscn")
const PRINT_MODEL = preload("res://models/default_model.tscn")

var _pending_items: Array[String] = []
var _counter_models: Array[Node3D] = []
var _npc: Node3D = null

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("register")
	var zone = get_node_or_null("RegisterZone")
	if zone:
		zone.visible = false

func show_tooltip() -> void:
	pass

func hide_tooltip() -> void:
	pass

func get_move_hint() -> String:
	return "Move"

func get_click_hint(_player_inventory) -> String:
	if _is_player_in_zone():
		if _pending_items.size() > 0:
			return "Scan Item (%d left)" % _pending_items.size()
		return ""
	return "Go to Register"

func interact() -> void:
	if _is_player_in_zone():
		if _pending_items.size() > 0:
			_scan_next_item()
		return
	var body = _get_player_body()
	if body == null:
		return
	var spot = get_node_or_null("RegisterSpot")
	if spot == null:
		return
	body.global_position = spot.global_position
	body.look_rotation.y = spot.global_rotation.y
	body.rotate_look(Vector2.ZERO)

func is_staffed() -> bool:
	return _is_player_in_zone()

func receive_npc_items(items: Array[String], npc: Node3D) -> void:
	if _pending_items.size() > 0:
		return
	_pending_items = items.duplicate()
	_npc = npc
	_counter_models.clear()
	for i in range(_pending_items.size()):
		var model = _spawn_counter_model(_counter_slot_pos(i))
		_counter_models.append(model)

func _scan_next_item() -> void:
	_pending_items.pop_back()
	if _counter_models.size() > 0:
		_counter_models.pop_back().queue_free()
	if _pending_items.is_empty():
		_checkout_complete()

func _checkout_complete() -> void:
	if _npc and is_instance_valid(_npc):
		_npc.checkout_complete()
	_npc = null

func _counter_slot_pos(index: int) -> Vector3:
	var zone = get_node_or_null("CounterZone")
	var total = _pending_items.size()
	var offset_x = (index - (total - 1) / 2.0) * 0.35
	var zone_x = zone.position.x if zone else 0.75
	var zone_z = zone.position.z if zone else 0.0
	# Place on counter top surface (local y=0.5) + small model half-height
	return to_global(Vector3(zone_x + offset_x, 0.56, zone_z))

func _spawn_counter_model(pos: Vector3) -> Node3D:
	var model = PRINT_MODEL.instantiate()
	get_tree().current_scene.add_child(model)
	model.global_position = pos
	if model is RigidBody3D:
		model.freeze = true
	model.remove_from_group("interactable")
	return model

func get_pack_hint(player_inventory) -> String:
	if player_inventory.held_item == null:
		return "Pack Away"
	return ""

func pack_away(player_inventory) -> void:
	if player_inventory.held_item != null:
		return
	for model in _counter_models:
		if model:
			model.queue_free()
	_counter_models.clear()
	_pending_items.clear()
	var crate = PACKING_CRATE_SCENE.instantiate()
	get_tree().current_scene.add_child(crate)
	crate.pack("Register", OWN_SCENE)
	player_inventory.pick_up_item(crate)
	queue_free()

func _is_player_in_zone() -> bool:
	var body = _get_player_body()
	var zone = get_node_or_null("RegisterZone")
	if body == null or zone == null:
		return false
	var half = zone.size / 2.0
	var local_pos = zone.to_local(body.global_position)
	return (abs(local_pos.x) <= half.x and
			abs(local_pos.y) <= half.y and
			abs(local_pos.z) <= half.z)

func _get_player_body() -> Node3D:
	var inv = get_tree().get_first_node_in_group("player")
	if inv == null:
		return null
	return inv.get_parent() as Node3D
