extends CharacterBody3D

enum State { IDLE, GOING_TO_SHELF, GOING_TO_REGISTER, WAITING, LEAVING }

const SPEED: float = 3.0
const ARRIVE_DIST: float = 1.2

var state: int = State.IDLE
var _items: Array[String] = []
var _target_pos: Vector3 = Vector3.ZERO
var _shelf: Node3D = null
var _register: Node3D = null
var _idle_timer: float = 0.0
const IDLE_RECHECK: float = 2.0

func _ready() -> void:
	add_to_group("npc")
	_build_arrow()
	await get_tree().process_frame
	_shelf = _find_shelf_with_prints()
	_register = get_tree().get_first_node_in_group("register")
	if _shelf != null:
		_target_pos = _shelf.global_position
		state = State.GOING_TO_SHELF

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += get_gravity().y * delta

	match state:
		State.GOING_TO_SHELF:
			if _navigate_to(_target_pos, delta):
				_on_arrive_at_shelf()
		State.GOING_TO_REGISTER:
			if _navigate_to(_target_pos, delta):
				velocity.x = 0
				velocity.z = 0
				state = State.WAITING
		State.WAITING:
			if _register != null and _register.is_staffed():
				_register.receive_npc_items(_items, self)
				_items.clear()
				state = State.IDLE
		State.LEAVING:
			if _navigate_to(_target_pos, delta):
				queue_free()
				return
		State.IDLE:
			velocity.x = 0
			velocity.z = 0
			_idle_timer += delta
			if _idle_timer >= IDLE_RECHECK:
				_idle_timer = 0.0
				_shelf = _find_shelf_with_prints()
				if _shelf != null:
					_target_pos = _shelf.global_position
					state = State.GOING_TO_SHELF

	move_and_slide()

func _on_arrive_at_shelf() -> void:
	var count = randi_range(1, 3)
	_items = _shelf.npc_take_prints(count)
	if _items.is_empty():
		state = State.IDLE
		return
	var spot = _register.get_node_or_null("CustomerSpot") if _register else null
	_target_pos = spot.global_position if spot else _register.global_position + Vector3(0, 0, 2)
	state = State.GOING_TO_REGISTER

func checkout_complete() -> void:
	var despawner = get_tree().current_scene.get_node_or_null("NPCDespawner")
	_target_pos = despawner.global_position if despawner else global_position + Vector3(0, 0, 20)
	state = State.LEAVING

func _navigate_to(target: Vector3, delta: float) -> bool:
	var to_target = target - global_position
	to_target.y = 0
	var dist = to_target.length()
	if dist <= ARRIVE_DIST:
		velocity.x = 0
		velocity.z = 0
		return true
	var dir = to_target / dist
	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), delta * 8.0)
	return false

func _find_shelf_with_prints() -> Node3D:
	for shelf in get_tree().get_nodes_in_group("product_shelf"):
		if shelf.has_method("has_any_prints") and shelf.has_any_prints():
			return shelf
	return null

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
