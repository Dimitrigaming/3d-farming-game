extends CharacterBody3D

const NPC_LOGGING: bool = true

func _log(msg: String) -> void:
	if not NPC_LOGGING:
		return
	var cat := "NPC %d" % (get_instance_id() % 10000)
	var logger = get_node_or_null("/root/GameLogger")
	if logger:
		logger.debug(cat, msg)
	else:
		print("[%s] %s" % [cat, msg])

enum State {
	WALKING_PATH,
	CHOOSING_NEXT,
	ENTERING_STORE,
	IDLE,
	GOING_TO_SHELF,
	GOING_TO_REGISTER,
	WAITING,
	LEAVING
}

const SPEED: float = 3.0
const ARRIVE_DIST: float = 1.2
const ARRIVE_DIST_SHELF: float = 0.35

var state: int = State.IDLE
var store_interest: float = 0.0

var _nav: NavigationAgent3D
var _street_destination: Vector3 = Vector3.ZERO
var _nav_frames: int = 0
var _shelf: Node3D = null
var _register: Node3D = null
var _items: Array[String] = []
var _idle_timer: float = 0.0
var _handed_off: bool = false
var _queue_slot: int = 0
var _queue_target: Vector3 = Vector3.ZERO
var _store_interest_checked: bool = false
var _exited_store: bool = false

const IDLE_RECHECK: float = 2.0
const IDLE_RECHECK_FAIL: float = 8.0
const IDLE_RECHECK_SHELF_EMPTY: float = 3.0

func _ready() -> void:
	add_to_group("npc")
	_nav = $NavigationAgent3D
	_build_arrow()
	_idle_timer = randf_range(0.0, IDLE_RECHECK)
	await get_tree().process_frame

func set_street_destination(destination: Vector3, debug_interest: float = 0.0) -> void:
	_street_destination = destination
	store_interest = debug_interest if debug_interest > 0.0 else randf()
	_store_interest_checked = false
	_nav_frames = 0
	_set_nav_target(destination)
	state = State.WALKING_PATH
	_log("spawned — interest=%.2f dest=%s" % [store_interest, destination])

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += get_gravity().y * delta

	match state:
		State.WALKING_PATH:
			_nav_frames += 1
			if _nav_frames > 5 and _nav.is_navigation_finished():
				queue_free()
				return
			else:
				_move_along_nav(delta)
		State.ENTERING_STORE:
			if _nav.is_navigation_finished():
				_log("[color=cyan]arrived inside store[/color]")
				_shelf = _find_shelf_with_prints()
				if _shelf != null:
					var stand = _shelf.get_npc_stand_pos() if _shelf.has_method("get_npc_stand_pos") else _shelf.global_position
					_set_nav_target(stand)
					state = State.GOING_TO_SHELF
				else:
					state = State.IDLE
					_idle_timer = 0.0
			else:
				_move_along_nav(delta)
		State.GOING_TO_SHELF:
			if _nav.is_navigation_finished():
				_log("arrived at shelf")
				_on_arrive_at_shelf()
			else:
				_move_along_nav(delta)
		State.GOING_TO_REGISTER:
			if _nav.is_navigation_finished():
				state = State.WAITING
				_tween_face_queue_direction()
				if _register != null and _register.is_staffed() and _register.is_front_of_queue(self):
					register_is_staffed()
			else:
				_move_along_nav(delta)
		State.WAITING:
			if global_position.distance_to(_queue_target) > ARRIVE_DIST:
				_set_nav_target(_queue_target)
				_move_along_nav(delta)
			else:
				velocity.x = 0
				velocity.z = 0
				if not _handed_off and _register != null and _register.is_staffed() and _register.is_front_of_queue(self):
					register_is_staffed()
		State.LEAVING:
			if _nav.is_navigation_finished():
				if not _exited_store:
					_exited_store = true
					var dest = _street_destination if _street_destination != Vector3.ZERO else global_position + Vector3(0, 0, 20)
					_log("reached exit — heading to street")
					_set_nav_target(dest)
				else:
					_log("left store — freeing")
					queue_free()
					return
			else:
				_move_along_nav(delta)
		State.IDLE:
			velocity.x = 0
			velocity.z = 0
			_idle_timer += delta
			if _idle_timer >= IDLE_RECHECK:
				_idle_timer = randf_range(0.0, 1.0)
				if not _items.is_empty():
					_register = _find_shortest_queue_register()
					if _register != null:
						_queue_slot = _register.join_queue(self)
						_queue_target = _register.get_queue_spot(_queue_slot)
						_set_nav_target(_queue_target)
						state = State.GOING_TO_REGISTER
					else:
						_idle_timer = -IDLE_RECHECK_FAIL
				else:
					_shelf = _find_shelf_with_prints()
					if _shelf != null:
						var stand = _shelf.get_npc_stand_pos() if _shelf.has_method("get_npc_stand_pos") else _shelf.global_position
						_set_nav_target(stand)
						state = State.GOING_TO_SHELF

	move_and_slide()

func _set_nav_target(pos: Vector3) -> void:
	_nav.set_target_position(pos)

func _move_along_nav(delta: float) -> void:
	var next = _nav.get_next_path_position()
	var dir = (next - global_position)
	dir.y = 0
	var dist = dir.length()
	if dist > 0.01:
		dir = dir / dist
		velocity.x = dir.x * SPEED
		velocity.z = dir.z * SPEED
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), delta * 8.0)
	else:
		velocity.x = 0
		velocity.z = 0

func try_enter_store(entry_pos: Vector3) -> void:
	if _store_interest_checked or state != State.WALKING_PATH:
		return
	_store_interest_checked = true
	if store_interest >= _get_store_attractiveness():
		if _find_shelf_with_prints() == null:
			_log("passed store — no products on shelves")
			return
		var in_store = get_tree().get_nodes_in_group("npc").filter(func(n): return n.state != State.WALKING_PATH and n.state != State.CHOOSING_NEXT and n.state != State.IDLE and n != self)
		if in_store.size() >= 6:
			_log("passed store — full (6 customers)")
			return
		_log("[color=green]entering store (interest=%.2f)[/color]" % store_interest)
		_log("nav target set to %s" % entry_pos)
		_set_nav_target(entry_pos)
		state = State.ENTERING_STORE
	else:
		_log("passed store (interest=%.2f too low)" % store_interest)

func _get_store_attractiveness() -> float:
	return 0.3


func _on_arrive_at_shelf() -> void:
	if _shelf == null or not is_instance_valid(_shelf):
		state = State.IDLE
		_idle_timer = 0.0
		return
	var stand = _shelf.get_npc_stand_pos() if _shelf.has_method("get_npc_stand_pos") else _shelf.global_position
	if global_position.distance_to(stand) > 2.0:
		_log("nav failed to reach shelf — retrying")
		_idle_timer = -IDLE_RECHECK_FAIL
		state = State.IDLE
		return
	velocity = Vector3.ZERO
	_idle_timer = -30.0
	state = State.IDLE
	_tween_face_target(_shelf.global_position)
	await get_tree().create_timer(randf_range(0.8, 1.5)).timeout
	if _shelf == null or not is_instance_valid(_shelf):
		state = State.IDLE
		_idle_timer = 0.0
		return
	var count = randi_range(1, 3)
	_items = _shelf.npc_take_prints(count)
	if _items.is_empty():
		if _find_shelf_with_prints() == null:
			_log("shelf empty and no stock anywhere — leaving")
			_leave_store()
		else:
			_idle_timer = -IDLE_RECHECK_SHELF_EMPTY
			_set_nav_target(global_position + Vector3(randf_range(-3.0, 3.0), 0, randf_range(-3.0, 3.0)))
			state = State.IDLE
		return
	_register = _find_shortest_queue_register()
	if _register == null:
		_idle_timer = -IDLE_RECHECK_FAIL
		state = State.IDLE
		return
	_queue_slot = _register.join_queue(self)
	_queue_target = _register.get_queue_spot(_queue_slot)
	_set_nav_target(_queue_target)
	state = State.GOING_TO_REGISTER

func _leave_store() -> void:
	var exit_point = get_node_or_null("/root/Map/City/Player_Building/StoreExitPoint")
	var dest = exit_point.global_position if exit_point else _street_destination
	_set_nav_target(dest)
	state = State.LEAVING

func checkout_complete() -> void:
	if _register and is_instance_valid(_register):
		_register.leave_queue(self)
	_log("checkout done — heading to exit")
	_leave_store()

func register_is_staffed() -> void:
	if state != State.WAITING or _handed_off or _register == null:
		return
	_handed_off = true
	await get_tree().create_timer(1.0).timeout
	if _register == null or not is_instance_valid(_register):
		return
	_register.receive_npc_items(_items, self)
	_items.clear()

func update_queue_slot(slot: int, new_pos: Vector3) -> void:
	_queue_slot = slot
	_queue_target = new_pos
	_tween_face_queue_direction()

func _find_shortest_queue_register() -> Node3D:
	var best: Node3D = null
	var best_len: float = INF
	for reg in get_tree().get_nodes_in_group("register"):
		var l = reg.queue_length() as float
		if l < best_len:
			best_len = l
			best = reg
	return best

func _find_shelf_with_prints() -> Node3D:
	for shelf in get_tree().get_nodes_in_group("product_shelf"):
		if shelf.has_method("has_any_prints") and shelf.has_any_prints():
			return shelf
	return null

func _tween_face_target(world_pos: Vector3) -> void:
	var to_target = world_pos - global_position
	to_target.y = 0
	if to_target.length_squared() < 0.01:
		return
	var target_angle = atan2(to_target.x, to_target.z)
	var start_angle = rotation.y
	var t = create_tween()
	t.tween_method(
		func(a: float): rotation.y = lerp_angle(start_angle, target_angle, a),
		0.0, 1.0, 0.3
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _tween_face_queue_direction() -> void:
	if _register == null:
		return
	var look_pos: Vector3
	if _queue_slot == 0:
		look_pos = _register.global_position
	else:
		look_pos = _register.get_queue_spot(_queue_slot - 1)
	_tween_face_target(look_pos)

func _build_arrow() -> void:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0, 0, 1)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var shaft = MeshInstance3D.new()
	var shaft_mesh = CylinderMesh.new()
	shaft_mesh.top_radius = 0.04
	shaft_mesh.bottom_radius = 0.04
	shaft_mesh.height = 0.4
	shaft.mesh = shaft_mesh
	shaft.material_override = mat
	shaft.position = Vector3(0, 2.1, 0.2)
	shaft.rotation_degrees = Vector3(-90, 180, 0)
	add_child(shaft)

	var head = MeshInstance3D.new()
	var head_mesh = CylinderMesh.new()
	head_mesh.top_radius = 0.0
	head_mesh.bottom_radius = 0.1
	head_mesh.height = 0.25
	head.mesh = head_mesh
	head.material_override = mat
	head.position = Vector3(0, 2.1, 0.55)
	head.rotation_degrees = Vector3(-90, 180, 0)
	add_child(head)
