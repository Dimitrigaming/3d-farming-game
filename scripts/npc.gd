extends CharacterBody3D

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
const PATH_SEARCH_RADIUS: float = 15.0
const STORE_TRIGGER_RADIUS: float = 8.0

var state: int = State.WALKING_PATH
var store_interest: float = 0.0

var _current_path: Node3D = null
var _exit_point: Vector3 = Vector3.ZERO
var _paths_walked: int = 0
var _target_pos: Vector3 = Vector3.ZERO
var _queue_target: Vector3 = Vector3.ZERO
var _shelf: Node3D = null
var _register: Node3D = null
var _items: Array[String] = []
var _idle_timer: float = 0.0
var _handed_off: bool = false
var _queue_slot: int = 0
var _store_interest_checked: bool = false

const IDLE_RECHECK: float = 2.0
const IDLE_RECHECK_FAIL: float = 8.0
const IDLE_RECHECK_SHELF_EMPTY: float = 3.0

func _ready() -> void:
	add_to_group("npc")
	_build_arrow()
	_idle_timer = randf_range(0.0, IDLE_RECHECK)
	await get_tree().process_frame

func assign_path(path: Node3D, debug_interest: float = 0.0) -> void:
	_current_path = path
	store_interest = debug_interest if debug_interest > 0.0 else randf()
	_exit_point = path.get_exit_point(global_position)
	_target_pos = _exit_point
	state = State.WALKING_PATH

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += get_gravity().y * delta

	match state:
		State.WALKING_PATH:
			_check_store_trigger()
			if _navigate_to(_target_pos, delta):
				_paths_walked += 1
				state = State.CHOOSING_NEXT
		State.CHOOSING_NEXT:
			_choose_next()
		State.ENTERING_STORE:
			if _navigate_to(_target_pos, delta):
				state = State.IDLE
				_idle_timer = 0.0
		State.GOING_TO_SHELF:
			if _navigate_to_dist(_target_pos, delta, ARRIVE_DIST_SHELF):
				_on_arrive_at_shelf()
		State.GOING_TO_REGISTER:
			if _navigate_to(_target_pos, delta):
				state = State.WAITING
				_tween_face_queue_direction()
				if _register != null and _register.is_staffed() and _register.is_front_of_queue(self):
					register_is_staffed()
		State.WAITING:
			if global_position.distance_to(_queue_target) > ARRIVE_DIST:
				_navigate_to(_queue_target, delta)
			else:
				velocity.x = 0
				velocity.z = 0
				if not _handed_off and _register != null and _register.is_staffed() and _register.is_front_of_queue(self):
					register_is_staffed()
		State.LEAVING:
			if _navigate_to(_target_pos, delta):
				queue_free()
				return
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
						_target_pos = _queue_target
						state = State.GOING_TO_REGISTER
					else:
						_idle_timer = -IDLE_RECHECK_FAIL
				else:
					_shelf = _find_shelf_with_prints()
					if _shelf != null:
						_target_pos = _shelf.get_npc_stand_pos() if _shelf.has_method("get_npc_stand_pos") else _shelf.global_position
						state = State.GOING_TO_SHELF

	move_and_slide()

func _check_store_trigger() -> void:
	if _store_interest_checked:
		return
	for trigger in get_tree().get_nodes_in_group("store_entrance"):
		if trigger.overlaps_body(self):
			_store_interest_checked = true
			if store_interest <= _get_store_attractiveness():
				var entrance = trigger.global_position
				entrance.y = global_position.y
				_target_pos = entrance
				state = State.ENTERING_STORE
			return

func _get_store_attractiveness() -> float:
	# Will be driven by game_state later (total earnings, products, decorations)
	return 0.3

func _choose_next() -> void:
	var nearest_path: Node3D = null
	var nearest_path_dist: float = INF
	for path in get_tree().get_nodes_in_group("walking_path"):
		if path == _current_path:
			continue
		var d = global_position.distance_to(path.global_position)
		if d < nearest_path_dist and d <= PATH_SEARCH_RADIUS:
			nearest_path_dist = d
			nearest_path = path

	if nearest_path != null:
		_current_path = nearest_path
		_exit_point = nearest_path.get_exit_point(_exit_point)
		_target_pos = _exit_point
		state = State.WALKING_PATH
	else:
		queue_free()

func _on_arrive_at_shelf() -> void:
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
		_idle_timer = -IDLE_RECHECK_SHELF_EMPTY
		_target_pos = global_position + Vector3(randf_range(-3.0, 3.0), 0, randf_range(-3.0, 3.0))
		state = State.IDLE
		return
	_register = _find_shortest_queue_register()
	if _register == null:
		_idle_timer = -IDLE_RECHECK_FAIL
		state = State.IDLE
		return
	_queue_slot = _register.join_queue(self)
	_queue_target = _register.get_queue_spot(_queue_slot)
	_target_pos = _queue_target
	state = State.GOING_TO_REGISTER

func checkout_complete() -> void:
	if _register and is_instance_valid(_register):
		_register.leave_queue(self)
	_target_pos = global_position + Vector3(0, 0, 20)
	state = State.LEAVING

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

func _navigate_to_dist(target: Vector3, delta: float, arrive_dist: float) -> bool:
	var to_target = target - global_position
	to_target.y = 0
	var dist = to_target.length()
	if dist <= arrive_dist:
		velocity.x = 0
		velocity.z = 0
		return true
	var dir = to_target / dist
	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), delta * 8.0)
	return false

func _navigate_to(target: Vector3, delta: float) -> bool:
	return _navigate_to_dist(target, delta, ARRIVE_DIST)

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
