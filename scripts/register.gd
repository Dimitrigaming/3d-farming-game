extends Node3D

const PACKING_CRATE_SCENE = preload("res://models/packing_crate.tscn")
const OWN_SCENE = preload("res://models/register.tscn")
const PRINT_MODEL = preload("res://models/default_model.tscn")

var _pending_items: Array[String] = []
var _counter_models: Array[Node3D] = []
var _npc: Node3D = null
var _transaction_total: float = 0.0
var _scanned_total: float = 0.0
var _total_label: Label3D = null

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
	if not _is_player_in_zone():
		return "Go to Register"
	return ""

func interact() -> void:
	if _is_player_in_zone():
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
	return _is_player_in_zone()

func receive_npc_items(items: Array[String], npc: Node3D) -> void:
	if _pending_items.size() > 0:
		return
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
	GameState.add_money(_transaction_total)
	_transaction_total = 0.0
	_scanned_total = 0.0
	_update_total_label()
	if _npc and is_instance_valid(_npc):
		_npc.checkout_complete()
	_npc = null

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
