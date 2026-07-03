extends Node3D

var active: bool = false
var grid_snap: bool = false

var _furniture: Node3D = null
var _furniture_body: CollisionObject3D = null
var _ghost: Node3D = null
var _ghost_y_rotation: float = 0.0
var _camera: Camera3D = null
var _ground_clearance: float = 0.0
var _blocked: bool = false
var _ghost_arrow_nodes: Array[Node] = []
var _passengers: Array[Node3D] = []
var _hidden_passengers: Array[Node3D] = []

const GRID_SIZE: float = 0.5
const ROTATE_STEP: float = PI / 12.0

func enter(furniture: Node3D) -> void:
	active = true
	_blocked = false
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
	_ghost.visible = true
	_ghost_arrow_nodes.clear()
	_clean_ghost(_ghost)
	_apply_ghost_material(_ghost, false)
	_add_forward_arrow(_ghost)
	get_tree().current_scene.add_child(_ghost)
	_ghost.global_position = furniture.global_position
	_ghost.rotation = Vector3(0, _ghost_y_rotation, 0)

	# Add ghost copies of any passengers (e.g. printers on a station)
	_passengers.clear()
	if furniture.has_method("get_move_passengers"):
		var inv = furniture.global_transform.affine_inverse()
		for passenger in furniture.get_move_passengers():
			if not is_instance_valid(passenger):
				continue
			# Duplicate while still visible so the ghost inherits visible = true
			var p_ghost = passenger.duplicate()
			p_ghost.set_script(null)
			_clean_ghost(p_ghost)
			_clear_scripts(p_ghost)
			_apply_ghost_material(p_ghost, false)
			_ghost.add_child(p_ghost)
			p_ghost.position = inv * passenger.global_position
			p_ghost.rotation.y = passenger.rotation.y - furniture.rotation.y
			# Hide original after ghost is created
			_passengers.append(passenger)
			passenger.visible = false
			var pb = passenger.get_node_or_null("StaticBody3D")
			if pb:
				pb.process_mode = Node.PROCESS_MODE_DISABLED

	# Hide passengers that don't need ghost images (prints on shelves, boxes)
	_hidden_passengers.clear()
	if furniture.has_method("get_hidden_passengers"):
		for passenger in furniture.get_hidden_passengers():
			if not is_instance_valid(passenger):
				continue
			_hidden_passengers.append(passenger)
			passenger.visible = false
			passenger.process_mode = Node.PROCESS_MODE_DISABLED

func exit(confirm: bool) -> void:
	if _furniture:
		_furniture.visible = true
		if _furniture_body:
			_furniture_body.process_mode = Node.PROCESS_MODE_INHERIT
		if confirm and _ghost and not _blocked:
			var old_transform = _furniture.global_transform
			_furniture.global_position = _ghost.global_position
			_furniture.rotation.y = _ghost_y_rotation
			_move_passengers(old_transform)
	for passenger in _passengers:
		if is_instance_valid(passenger):
			passenger.visible = true
			var pb = passenger.get_node_or_null("StaticBody3D")
			if pb:
				pb.process_mode = Node.PROCESS_MODE_INHERIT
	_passengers.clear()
	for passenger in _hidden_passengers:
		if is_instance_valid(passenger):
			passenger.visible = true
			passenger.process_mode = Node.PROCESS_MODE_INHERIT
	_hidden_passengers.clear()
	if _ghost:
		_ghost.queue_free()
		_ghost = null
	active = false
	_blocked = false
	_furniture = null
	_furniture_body = null
	_camera = null
	_ghost_arrow_nodes.clear()

func _move_passengers(old_transform: Transform3D) -> void:
	if _passengers.is_empty() and _hidden_passengers.is_empty():
		return
	var old_inv = old_transform.affine_inverse()
	var new_transform = _furniture.global_transform
	var delta_rot_y = _ghost_y_rotation - old_transform.basis.get_euler().y
	for passenger in _passengers + _hidden_passengers:
		if not is_instance_valid(passenger):
			continue
		var local_pos = old_inv * passenger.global_position
		passenger.global_position = new_transform * local_pos
		passenger.rotation.y += delta_rot_y

func _cast_placement_zone_ray() -> Node3D:
	if _camera == null:
		return null
	var space_state = get_world_3d().direct_space_state
	var from = _camera.global_position
	var dir = -_camera.global_transform.basis.z
	var ray = PhysicsRayQueryParameters3D.create(from, from + dir * 6.0, 8)
	ray.collide_with_areas = true
	ray.collide_with_bodies = false
	var result = space_state.intersect_ray(ray)
	if not result:
		return null
	var col = result.get("collider")
	if col == null:
		return null
	var zone = col.get_parent() if col is Area3D else col
	if zone.is_in_group("placement_zone") and not _is_descendant_of(zone, _furniture):
		return zone
	return null

func _is_descendant_of(node: Node, ancestor: Node) -> bool:
	var parent = node.get_parent()
	while parent != null:
		if parent == ancestor:
			return true
		parent = parent.get_parent()
	return false

func snap_to_zone(zone: Node3D) -> void:
	_ghost_y_rotation = zone.global_rotation.y
	if _ghost:
		_ghost.global_position = zone.global_position
		_ghost.rotation.y = _ghost_y_rotation

func rotate_ghost(delta_y: float) -> void:
	_ghost_y_rotation += delta_y
	if _ghost:
		_ghost.rotation.y = _ghost_y_rotation

func _process(_delta: float) -> void:
	if not active or _ghost == null or _camera == null:
		return
	var space_state = get_world_3d().direct_space_state

	# Snap to placement zone if aiming at one — checked before normal positioning
	var snap_zone = _cast_placement_zone_ray()
	if snap_zone != null:
		var down = PhysicsRayQueryParameters3D.create(
			snap_zone.global_position + Vector3(0, 2, 0),
			snap_zone.global_position - Vector3(0, 2, 0),
			1
		)
		var down_result = space_state.intersect_ray(down)
		var surface_y = snap_zone.global_position.y
		if down_result:
			surface_y = down_result.position.y
		_ghost.global_position = Vector3(snap_zone.global_position.x, surface_y + _ground_clearance, snap_zone.global_position.z)
		_ghost_y_rotation = snap_zone.global_rotation.y
		_ghost.rotation = Vector3(0, _ghost_y_rotation, 0)
		if _blocked:
			_blocked = false
			_apply_ghost_material(_ghost, false)
		return

	var from = _camera.global_position
	var dir = -_camera.global_transform.basis.z
	var ray = PhysicsRayQueryParameters3D.create(from, from + dir * 8.0)
	var result = space_state.intersect_ray(ray)
	if result:
		var pos = result.position
		if grid_snap:
			pos.x = round(pos.x / GRID_SIZE) * GRID_SIZE
			pos.z = round(pos.z / GRID_SIZE) * GRID_SIZE
		_ghost.global_position = Vector3(pos.x, pos.y + _ground_clearance, pos.z)
	_ghost.rotation = Vector3(0, _ghost_y_rotation, 0)

	var now_blocked = _is_blocked(result)
	if now_blocked != _blocked:
		_blocked = now_blocked
		_apply_ghost_material(_ghost, _blocked)

func _is_blocked(ray_result: Dictionary) -> bool:
	# Block if the position raycast hit an interactable (e.g. placing on a box or shelf)
	if not ray_result.is_empty():
		var hit = ray_result.get("collider")
		if hit != null:
			if hit.is_in_group("interactable") or (hit.get_parent() and hit.get_parent().is_in_group("interactable")):
				return true

	# Block if the ghost shape overlaps any interactable
	if _furniture_body == null:
		return false
	var cs: CollisionShape3D = _furniture_body.get_node_or_null("CollisionShape3D")
	if cs == null or cs.shape == null:
		return false
	var space_state = get_world_3d().direct_space_state
	var sq = PhysicsShapeQueryParameters3D.new()
	sq.shape = cs.shape
	sq.transform = _ghost.global_transform * _furniture_body.transform * cs.transform
	sq.exclude = [_furniture_body.get_rid()]
	sq.collision_mask = 1
	for r in space_state.intersect_shape(sq, 8):
		var col = r["collider"]
		if col.is_in_group("interactable") or (col.get_parent() and col.get_parent().is_in_group("interactable")):
			return true
	return false

func _get_ground_clearance(item: Node3D) -> float:
	var static_body: Node3D = item.get_node_or_null("StaticBody3D")
	var collision_shape: CollisionShape3D = item.get_node_or_null("StaticBody3D/CollisionShape3D")
	if collision_shape == null or collision_shape.shape == null:
		return 0.0
	var shape = collision_shape.shape
	var body_y = static_body.transform.origin.y if static_body != null else 0.0
	var local_bottom = body_y + collision_shape.transform.origin.y
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
	_clear_scripts(ghost)

func _clear_scripts(node: Node) -> void:
	for child in node.get_children():
		if child.get_script():
			child.set_script(null)
		_clear_scripts(child)

func _apply_ghost_material(node: Node, blocked: bool) -> void:
	if node in _ghost_arrow_nodes:
		return
	var mat = _ghost_material(blocked)
	if node is CSGShape3D and not node is CSGCombiner3D:
		(node as CSGShape3D).material = mat
	elif node is MeshInstance3D:
		(node as MeshInstance3D).material_override = mat
	for child in node.get_children():
		_apply_ghost_material(child, blocked)

func _ghost_material(blocked: bool) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.0, 0.0, 0.4) if blocked else Color(0.0, 1.0, 0.2, 0.4)
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

	_ghost_arrow_nodes.append(shaft)
	_ghost_arrow_nodes.append(head)
