extends Node3D

var active: bool = false
var grid_snap: bool = false

var _furniture: Node3D = null
var _furniture_body: CollisionObject3D = null
var _ghost: Node3D = null
var _ghost_y_rotation: float = 0.0
var _camera: Camera3D = null
var _ground_clearance: float = 0.0

const GRID_SIZE: float = 0.5
const ROTATE_STEP: float = PI / 12.0

func enter(furniture: Node3D) -> void:
	active = true
	_furniture = furniture
	_ghost_y_rotation = furniture.rotation.y
	_camera = get_viewport().get_camera_3d()
	_ground_clearance = _get_ground_clearance(furniture)
	_furniture_body = furniture.get_node_or_null("StaticBody3D")
	if _furniture_body:
		_furniture_body.process_mode = Node.PROCESS_MODE_DISABLED
	furniture.visible = false

	_ghost = furniture.duplicate()
	_ghost.set_script(null)
	_clean_ghost(_ghost)
	_apply_ghost_material(_ghost)
	_add_forward_arrow(_ghost)
	get_tree().current_scene.add_child(_ghost)
	_ghost.global_position = furniture.global_position
	_ghost.rotation = Vector3(0, _ghost_y_rotation, 0)

func exit(confirm: bool) -> void:
	if _furniture:
		_furniture.visible = true
		if _furniture_body:
			_furniture_body.process_mode = Node.PROCESS_MODE_INHERIT
		if confirm and _ghost:
			_furniture.global_position = _ghost.global_position
			_furniture.rotation.y = _ghost_y_rotation
	if _ghost:
		_ghost.queue_free()
		_ghost = null
	active = false
	_furniture = null
	_furniture_body = null
	_camera = null

func rotate_ghost(delta_y: float) -> void:
	_ghost_y_rotation += delta_y
	if _ghost:
		_ghost.rotation.y = _ghost_y_rotation

func _process(_delta: float) -> void:
	if not active or _ghost == null or _camera == null:
		return
	var space_state = get_world_3d().direct_space_state
	var from = _camera.global_position
	var dir = -_camera.global_transform.basis.z
	var query = PhysicsRayQueryParameters3D.create(from, from + dir * 8.0)
	var result = space_state.intersect_ray(query)
	if result:
		var pos = result.position
		if grid_snap:
			pos.x = round(pos.x / GRID_SIZE) * GRID_SIZE
			pos.z = round(pos.z / GRID_SIZE) * GRID_SIZE
		_ghost.global_position = Vector3(pos.x, pos.y + _ground_clearance, pos.z)
	_ghost.rotation = Vector3(0, _ghost_y_rotation, 0)

func _get_ground_clearance(item: Node3D) -> float:
	var collision_shape: CollisionShape3D = item.get_node_or_null("StaticBody3D/CollisionShape3D")
	if collision_shape == null or collision_shape.shape == null:
		return 0.0
	var shape = collision_shape.shape
	var local_bottom = collision_shape.transform.origin.y
	if shape is BoxShape3D:
		local_bottom -= shape.size.y * 0.5
	elif shape is CylinderShape3D:
		local_bottom -= shape.height * 0.5
	elif shape is CapsuleShape3D:
		local_bottom -= shape.height * 0.5
	return -local_bottom

func _clean_ghost(ghost: Node3D) -> void:
	var to_remove: Array[Node] = []
	for child in ghost.get_children():
		if child is StaticBody3D or child is Label3D or child is Marker3D:
			to_remove.append(child)
	for node in to_remove:
		ghost.remove_child(node)
		node.free()

func _apply_ghost_material(node: Node) -> void:
	var mat = _ghost_material()
	if node is CSGShape3D and not node is CSGCombiner3D:
		(node as CSGShape3D).material = mat
	elif node is MeshInstance3D:
		(node as MeshInstance3D).material_override = mat
	for child in node.get_children():
		_apply_ghost_material(child)

func _ghost_material() -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.0, 1.0, 0.2, 0.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

func _add_forward_arrow(ghost: Node3D) -> void:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0, 0, 1)

	var shaft = MeshInstance3D.new()
	var shaft_mesh = CylinderMesh.new()
	shaft_mesh.top_radius = 0.025
	shaft_mesh.bottom_radius = 0.025
	shaft_mesh.height = 0.4
	shaft.mesh = shaft_mesh
	shaft.material_override = mat
	shaft.rotation_degrees = Vector3(90, 0, 0)
	shaft.position = Vector3(0, 0.15, 0.2)
	ghost.add_child(shaft)

	var head = MeshInstance3D.new()
	var head_mesh = CylinderMesh.new()
	head_mesh.top_radius = 0.0
	head_mesh.bottom_radius = 0.08
	head_mesh.height = 0.2
	head.mesh = head_mesh
	head.material_override = mat
	head.rotation_degrees = Vector3(90, 0, 0)
	head.position = Vector3(0, 0.15, 0.5)
	ghost.add_child(head)
