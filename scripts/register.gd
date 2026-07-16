extends Node3D

const PACKING_CRATE_SCENE = preload("res://models/packing_crate.tscn")
const OWN_SCENE = preload("res://models/register.tscn")
const PRINT_MODEL = preload("res://models/default_model.tscn")

const QUEUE_SPACING: float = 1.5

var _pending_items: Array[String] = []
var _counter_models: Array[Node3D] = []
var _npc: Node3D = null
var _transaction_total: float = 0.0
var _scanned_total: float = 0.0
var _total_label: Label3D = null
var _queue: Array[Node3D] = []
var _operator: Node3D = null
const OPERATOR_LEAVE_DIST: float = 2.5

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("register")
	var zone = get_node_or_null("RegisterZone")
	if zone:
		zone.visible = false
	_setup_total_label()

func _setup_total_label() -> void:
	var screen = get_node_or_null("RegisterScreen")
	_total_label = Label3D.new()
	_total_label.pixel_size = 0.002
	_total_label.font_size = 28
	_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_total_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_total_label.modulate = Color(0.2, 1.0, 0.4, 1)
	_total_label.no_depth_test = true
	_total_label.visible = false
	if screen:
		_total_label.position = Vector3(0, 0, 0.06)
		_total_label.rotation_degrees = Vector3(0, 180, 0)
		screen.add_child(_total_label)
	else:
		_total_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_total_label.position = Vector3(0, 1.2, 0)
		add_child(_total_label)

func _update_total_label() -> void:
	if _total_label == null:
		return
	if _transaction_total <= 0.0:
		_total_label.visible = false
		return
	_total_label.visible = true
	_total_label.text = "$%.2f\n$%.2f total" % [_scanned_total, _transaction_total]

func show_tooltip() -> void:
	pass

func hide_tooltip() -> void:
	pass

func get_move_hint() -> String:
	return "Move"

func get_click_hint(_player_inventory) -> String:
	if _operator != null:
		return ""
	return "Go to Register"

func interact() -> void:
	if _operator != null:
		return
	var body = _get_player_body()
	if body == null:
		return
	var spot = get_node_or_null("RegisterSpot")
	if spot == null:
		return
	_operator = body
	body.global_position = spot.global_position
	body.look_rotation.y = spot.global_rotation.y
	body.rotate_look(Vector2.ZERO)
	_notify_front_npc()

func _process(_delta: float) -> void:
	if _operator == null or not is_instance_valid(_operator):
		_operator = null
		return
	var spot = get_node_or_null("RegisterSpot")
	if spot == null:
		return
	var diff = _operator.global_position - spot.global_position
	var dist = Vector2(diff.x, diff.z).length()
	if dist > OPERATOR_LEAVE_DIST:
		_operator = null

func scan_item(item: Node3D) -> void:
	var idx = _counter_models.find(item)
	if idx == -1:
		return
	var item_name = _pending_items[idx]
	_scanned_total += GameState.get_price(item_name)
	_counter_models.remove_at(idx)
	_pending_items.remove_at(idx)
	item.queue_free()
	_update_total_label()
	if _pending_items.is_empty():
		_checkout_complete()

func is_staffed() -> bool:
	return _operator != null and is_instance_valid(_operator)

func receive_npc_items(items: Array[String], npc: Node3D) -> void:
	if _pending_items.size() > 0:
		return
	GameLogger.info("Register", "NPC %d handing off %d item(s)" % [npc.get_instance_id() % 10000, items.size()])
	_pending_items = items.duplicate()
	_npc = npc
	_counter_models.clear()
	_transaction_total = 0.0
	_scanned_total = 0.0
	for item_name in _pending_items:
		_transaction_total += GameState.get_price(item_name)
	for i in range(_pending_items.size()):
		var model = _spawn_counter_model(i)
		_counter_models.append(model)
	_update_total_label()

func _checkout_complete() -> void:
	GameLogger.info("Register", "checkout complete — earned $%.2f" % _transaction_total)
	GameState.add_money(_transaction_total)
	_transaction_total = 0.0
	_scanned_total = 0.0
	_update_total_label()
	var departing = _npc
	_npc = null
	if departing and is_instance_valid(departing):
		departing.checkout_complete()

func _spawn_counter_model(index: int) -> Node3D:
	var zone = get_node_or_null("CounterZone")
	var zone_x = zone.position.x if zone else 0.75
	var zone_z = zone.position.z if zone else 0.0
	var spread_x = randf_range(-0.3, 0.3)
	var spread_z = randf_range(-0.15, 0.15)
	var drop_height = randf_range(0.3, 0.5) + index * 0.1
	var spawn_pos = to_global(Vector3(zone_x + spread_x, 0.5 + drop_height, zone_z + spread_z))

	var body = RigidBody3D.new()
	body.set_script(preload("res://scripts/counter_item.gd"))
	body.collision_layer = 2  # detected by layer-2 ray, invisible to layer-1 ray
	body.collision_mask = 1   # still rests physically on the counter
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.2, 0.4, 0.2)
	col.shape = shape
	body.add_child(col)

	var model = PRINT_MODEL.instantiate()
	body.add_child(model)

	get_tree().current_scene.add_child(body)
	body.setup(self)
	body.global_position = spawn_pos
	body.linear_velocity = Vector3(randf_range(-0.4, 0.4), 0.0, randf_range(-0.2, 0.2))
	return body

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
	_transaction_total = 0.0
	_scanned_total = 0.0
	_queue.clear()
	var crate = PACKING_CRATE_SCENE.instantiate()
	get_tree().current_scene.add_child(crate)
	crate.pack("Register", OWN_SCENE)
	player_inventory.pick_up_item(crate)
	queue_free()

func join_queue(npc: Node3D) -> int:
	_queue.append(npc)
	return _queue.size() - 1

func leave_queue(npc: Node3D) -> void:
	var idx = _queue.find(npc)
	if idx == -1:
		return
	_queue.remove_at(idx)
	for i in range(idx, _queue.size()):
		var queued = _queue[i]
		if is_instance_valid(queued):
			queued.update_queue_slot(i, get_queue_spot(i))
	if is_staffed():
		_notify_front_npc()

func get_queue_member(index: int) -> Node3D:
	if index < 0 or index >= _queue.size():
		return null
	return _queue[index]

func _notify_front_npc() -> void:
	if _queue.size() > 0 and is_instance_valid(_queue[0]) and _pending_items.is_empty():
		_queue[0].register_is_staffed()

func get_queue_spot(index: int) -> Vector3:
	var spot = get_node_or_null("CustomerSpot")
	if spot == null:
		return global_position
	var base = spot.global_position
	var dir := _get_queue_direction()
	return base + dir * index * QUEUE_SPACING

func _get_queue_direction() -> Vector3:
	var scene = get_tree().current_scene
	var front = scene.get_node_or_null("StoreFront")
	var back  = scene.get_node_or_null("StoreFront/StoreBack")
	if front and back:
		var d = back.global_position - front.global_position
		d.y = 0
		if d.length_squared() > 0.001:
			return d.normalized()
	# Fallback: direction from register toward CustomerSpot
	var spot = get_node_or_null("CustomerSpot")
	if spot:
		var d = spot.global_position - global_position
		d.y = 0
		if d.length_squared() > 0.001:
			return d.normalized()
	return Vector3.FORWARD

func queue_length() -> int:
	return _queue.size()

func is_front_of_queue(npc: Node3D) -> bool:
	return _queue.size() > 0 and _queue[0] == npc

func _get_player_body() -> Node3D:
	var inv = get_tree().get_first_node_in_group("player")
	if inv == null:
		return null
	return inv.get_parent() as Node3D
