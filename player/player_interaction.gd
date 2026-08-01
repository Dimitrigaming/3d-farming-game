extends Node

const RAY_LENGTH = 10.0

var _camera: Camera3D = null
var _highlight: MeshInstance3D = null
var _hovered_cell: Vector3i = Vector3i(-1, -1, -1)
var _hovered_farm = null

func _ready() -> void:
	_camera = _find_camera(get_parent())
	if not _camera:
		push_warning("PlayerInteraction: no Camera3D found.")
	_setup_highlight()

func _setup_highlight() -> void:
	_highlight = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(1.0, 0.02, 1.0)
	_highlight.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.2, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	_highlight.material_override = mat
	_highlight.visible = false
	_highlight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().get_root().call_deferred("add_child", _highlight)

func _process(_delta: float) -> void:
	_hovered_cell = Vector3i(-1, -1, -1)
	_hovered_farm = null

	if not _highlight or Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		if _highlight:
			_highlight.visible = false
		return

	var equipper = get_tree().get_first_node_in_group("tool_equipper")
	if not equipper:
		_highlight.visible = false
		return

	var item_id = equipper.current_item_id
	var target_state: int
	var highlight_color: Color
	match item_id:
		"hoe":
			target_state = 1  # DIRT
			highlight_color = Color(1.0, 0.85, 0.2, 0.5)
		"shovel":
			target_state = 2  # TILLED
			highlight_color = Color(1.0, 0.35, 0.2, 0.5)
		_:
			_highlight.visible = false
			return

	var farm = get_tree().get_first_node_in_group("farm_grid")
	if not farm:
		_highlight.visible = false
		return

	var hit_pos = _raycast_position()
	if hit_pos == Vector3.INF:
		_highlight.visible = false
		return

	var cell = _world_to_cell(farm, hit_pos)
	if farm.cell_state.get(cell, -1) != target_state:
		_highlight.visible = false
		return

	(_highlight.material_override as StandardMaterial3D).albedo_color = highlight_color
	var cell_world = _cell_to_world(farm, cell)
	_highlight.global_position = cell_world
	_highlight.visible = true
	_hovered_cell = cell
	_hovered_farm = farm

func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return
	if _hovered_farm == null or _hovered_cell == Vector3i(-1, -1, -1):
		return
	var equipper = get_tree().get_first_node_in_group("tool_equipper")
	if not equipper:
		return
	match equipper.current_item_id:
		"hoe":
			_hovered_farm.till_cell(_hovered_cell.x, _hovered_cell.z)
		"shovel":
			_hovered_farm.untill_cell(_hovered_cell.x, _hovered_cell.z)

func _raycast_position() -> Vector3:
	if not _camera:
		return Vector3.INF
	var viewport = get_viewport()
	var center = viewport.get_visible_rect().size / 2.0
	var origin = _camera.project_ray_origin(center)
	var direction = _camera.project_ray_normal(center)
	var query = PhysicsRayQueryParameters3D.create(origin, origin + direction * RAY_LENGTH)
	query.collision_mask = 0xFFFFFFFF
	query.exclude = [get_parent()]
	var space = viewport.get_world_3d().direct_space_state
	var result = space.intersect_ray(query)
	if result:
		return result["position"]
	return Vector3.INF

func _world_to_cell(farm: Node3D, world_pos: Vector3) -> Vector3i:
	var local = farm.grid_map.to_local(world_pos)
	return farm.grid_map.local_to_map(local)

func _cell_to_world(farm: Node3D, cell: Vector3i) -> Vector3:
	var local = farm.grid_map.map_to_local(cell)
	return farm.grid_map.to_global(Vector3(local.x, local.y + 0.04, local.z))

func _find_camera(node: Node) -> Camera3D:
	if node is Camera3D:
		return node
	for child in node.get_children():
		var result = _find_camera(child)
		if result:
			return result
	return null
