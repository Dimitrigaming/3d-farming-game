@tool
extends Node3D

enum ZoneType { UNASSIGNED, SALES, PRODUCTION, STORAGE }

const COLOR_UNASSIGNED = Color(1.0, 1.0, 1.0, 0.35)
const COLOR_SALES      = Color(1.0, 0.1, 0.1, 0.45)
const COLOR_PRODUCTION = Color(0.1, 0.3, 1.0, 0.45)
const COLOR_STORAGE    = Color(0.1, 0.8, 0.2, 0.45)

const CELL_SIZE: float = 4.0

@export var zones_unassigned: Array[NodePath] = []:
	set(v):
		zones_unassigned = v
		_refresh_editor()

@export var zones_sales: Array[NodePath] = []:
	set(v):
		zones_sales = v
		_refresh_editor()

var _zone_nodes: Dictionary = {}
var _zone_data: Dictionary = {}
var _door_anchor_cell: Vector2i
var _mats: Array[StandardMaterial3D] = []

func _ready() -> void:
	_build_mats()
	if Engine.is_editor_hint():
		_refresh_editor()
		return
	var anchor_node = get_node_or_null("DoorAnchor")
	var anchor_pos = anchor_node.global_position if anchor_node else Vector3.ZERO
	_door_anchor_cell = _world_to_cell(anchor_pos)
	_register_zones(zones_unassigned, ZoneType.UNASSIGNED)
	_register_zones(zones_sales, ZoneType.SALES)
	_set_zone(_door_anchor_cell, ZoneType.SALES)
	_check_connectivity()

func _build_mats() -> void:
	_mats.resize(4)
	for i in 4:
		var mat = StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		match i:
			ZoneType.UNASSIGNED: mat.albedo_color = COLOR_UNASSIGNED
			ZoneType.SALES:      mat.albedo_color = COLOR_SALES
			ZoneType.PRODUCTION: mat.albedo_color = COLOR_PRODUCTION
			ZoneType.STORAGE:    mat.albedo_color = COLOR_STORAGE
		_mats[i] = mat

func _refresh_editor() -> void:
	if not is_inside_tree():
		return
	if _mats.is_empty():
		_build_mats()
	_apply_paths(zones_unassigned, ZoneType.UNASSIGNED)
	_apply_paths(zones_sales, ZoneType.SALES)

func _apply_paths(paths: Array[NodePath], type: ZoneType) -> void:
	for path in paths:
		var node = get_node_or_null(path)
		if node is MeshInstance3D:
			node.set_surface_override_material(0, _mats[type])

func paint_zone(world_pos: Vector3, type: ZoneType) -> void:
	var cell = _world_to_cell(world_pos)
	if cell == _door_anchor_cell:
		return
	if not _zone_data.has(cell):
		return
	_set_zone(cell, type)
	_check_connectivity()

func get_zone_type(world_pos: Vector3) -> ZoneType:
	var cell = _world_to_cell(world_pos)
	return _zone_data.get(cell, ZoneType.UNASSIGNED)

func _set_zone(cell: Vector2i, type: ZoneType) -> void:
	_zone_data[cell] = type
	if _zone_nodes.has(cell):
		_apply_material(_zone_nodes[cell], type)

func _register_zones(paths: Array[NodePath], type: ZoneType) -> void:
	for path in paths:
		var node = get_node_or_null(path)
		if not node is MeshInstance3D:
			continue
		var cell = _world_to_cell(node.global_position)
		_zone_nodes[cell] = node
		_zone_data[cell] = type
		node.set_surface_override_material(0, _mats[type])

func _world_to_cell(world_pos: Vector3) -> Vector2i:
	return Vector2i(int(floor(world_pos.x / CELL_SIZE)), int(floor(world_pos.z / CELL_SIZE)))

func _apply_material(node: MeshInstance3D, type: ZoneType) -> void:
	node.set_surface_override_material(0, _mats[type])

func _check_connectivity() -> void:
	var sales_cells: Array = _zone_data.keys().filter(func(c): return _zone_data[c] == ZoneType.SALES)
	if sales_cells.is_empty():
		return
	var visited: Dictionary = {}
	var queue: Array = [_door_anchor_cell]
	visited[_door_anchor_cell] = true
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for neighbor in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var next = current + neighbor
			if not visited.has(next) and _zone_data.get(next, ZoneType.UNASSIGNED) == ZoneType.SALES:
				visited[next] = true
				queue.append(next)
	for cell in sales_cells:
		if not visited.has(cell):
			push_warning("ZoneManager: Sales floor cell %s is not connected to the front door!" % cell)
			return
