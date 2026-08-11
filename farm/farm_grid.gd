@tool
extends Node3D

const GRASS = 0
const DIRT = 1
const TILLED = 2
const GRID_SIZE = 20
const LIB_PATH = "res://farm/farm_mesh_library.tres"

## The painted farm area is split into a 2x2 layout of parcels (see
## _compute_bounds/_parcel_index below). Parcel 0 (bottom-left of the
## bounding box) starts unlocked; the rest require
## GameState.unlock_farm_parcel() (money + shop level gate).
const PARCEL_COUNT = 4

var cell_state: Dictionary = {}
var _plots: Dictionary = {}
var _crops: Dictionary = {}
var _parcel_markers: Dictionary = {}

@onready var grid_map: GridMap = $GridMap

@warning_ignore("unused_private_class_variable")
@export_tool_button("1. Build Mesh Library") var _build_btn = _build_and_save_library
@warning_ignore("unused_private_class_variable")
@export_tool_button("2. Fill Grass Chunk") var _fill_btn = _fill_grass

func _build_and_save_library() -> void:
	var lib = _make_library()
	var err = ResourceSaver.save(lib, LIB_PATH)
	if err == OK:
		print("Saved MeshLibrary to ", LIB_PATH)
		grid_map.mesh_library = load(LIB_PATH)
	else:
		push_error("Failed to save MeshLibrary: " + str(err))

func _make_library() -> MeshLibrary:
	var lib = MeshLibrary.new()

	var grass_mat = StandardMaterial3D.new()
	grass_mat.albedo_texture = load("res://materials/grass.png")
	var grass_mesh = BoxMesh.new()
	grass_mesh.size = Vector3(1.0, 0.05, 1.0)
	grass_mesh.material = grass_mat
	lib.create_item(GRASS)
	lib.set_item_name(GRASS, "grass")
	lib.set_item_mesh(GRASS, grass_mesh)

	var dirt_mat = StandardMaterial3D.new()
	dirt_mat.albedo_texture = load("res://materials/dirt.png")
	var dirt_mesh = BoxMesh.new()
	dirt_mesh.size = Vector3(1.0, 0.05, 1.0)
	dirt_mesh.material = dirt_mat
	lib.create_item(DIRT)
	lib.set_item_name(DIRT, "dirt")
	lib.set_item_mesh(DIRT, dirt_mesh)

	return lib

func _fill_grass() -> void:
	if grid_map.mesh_library == null:
		push_error("FarmGrid: run 'Build Mesh Library' first.")
		return
	for x in GRID_SIZE:
		for z in GRID_SIZE:
			grid_map.set_cell_item(Vector3i(x, 0, z), GRASS)

## Bounding box of the actually-painted farm area, computed at runtime --
## the GridMap's real cell coordinates are whatever was hand-painted in the
## editor (can be offset/negative), not necessarily 0..GRID_SIZE-1, so the
## parcel split below is relative to this bounding box instead of assuming
## fixed absolute coordinates.
var _bounds_min: Vector3i = Vector3i.ZERO
var _bounds_max: Vector3i = Vector3i.ZERO

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("farm_grid")
	var used_cells = grid_map.get_used_cells()
	for cell in used_cells:
		cell_state[cell] = grid_map.get_cell_item(cell)
	_compute_bounds(used_cells)
	# Parcel locking is temporarily disabled -- the bounding-box split doesn't
	# reliably line up with the real painted farm shape, and this blocked
	# tilling entirely last time it was tried. Re-enable _spawn_parcel_marker
	# below (and the _is_parcel_unlocked() short-circuit) once the real DIRT
	# cell coordinates have been verified in the editor.
	# for parcel_index in range(1, PARCEL_COUNT):
	# 	_spawn_parcel_marker(parcel_index)
	GameState.farm_parcel_unlocked.connect(_on_farm_parcel_unlocked)

func _compute_bounds(used_cells: Array) -> void:
	if used_cells.is_empty():
		return
	_bounds_min = used_cells[0]
	_bounds_max = used_cells[0]
	for cell in used_cells:
		_bounds_min.x = min(_bounds_min.x, cell.x)
		_bounds_min.z = min(_bounds_min.z, cell.z)
		_bounds_max.x = max(_bounds_max.x, cell.x)
		_bounds_max.z = max(_bounds_max.z, cell.z)

func _parcel_index(x: int, z: int) -> int:
	var width = max(1, _bounds_max.x - _bounds_min.x + 1)
	var depth = max(1, _bounds_max.z - _bounds_min.z + 1)
	var px = 0 if (x - _bounds_min.x) < width / 2.0 else 1
	var pz = 0 if (z - _bounds_min.z) < depth / 2.0 else 1
	return px + pz * 2

func _is_parcel_unlocked(_x: int, _z: int) -> bool:
	# Temporarily disabled -- see the note in _ready(). Always unlocked until
	# the parcel split is verified against the real farm layout.
	return true

func _parcel_center_cell(parcel_index: int) -> Vector3i:
	var width = max(1, _bounds_max.x - _bounds_min.x + 1)
	var depth = max(1, _bounds_max.z - _bounds_min.z + 1)
	var px = parcel_index % 2
	var pz = parcel_index / 2
	var cx = _bounds_min.x + int(px * width / 2.0 + width / 4.0)
	var cz = _bounds_min.z + int(pz * depth / 2.0 + depth / 4.0)
	return Vector3i(cx, 0, cz)

func _spawn_parcel_marker(parcel_index: int) -> void:
	var marker_scene = load("res://farm/farm_parcel_marker.gd")
	if marker_scene == null:
		return
	var marker = StaticBody3D.new()
	marker.set_script(marker_scene)
	marker.parcel_index = parcel_index
	add_child(marker)
	var cell = _parcel_center_cell(parcel_index)
	var local_pos = grid_map.map_to_local(cell)
	marker.position = Vector3(local_pos.x, 0.0, local_pos.z)
	_parcel_markers[parcel_index] = marker

func _on_farm_parcel_unlocked(new_count: int) -> void:
	var unlocked_index = new_count - 1
	if _parcel_markers.has(unlocked_index):
		_parcel_markers[unlocked_index].queue_free()
		_parcel_markers.erase(unlocked_index)

func till_cell(x: int, z: int) -> void:
	var key = Vector3i(x, 0, z)
	if not _is_parcel_unlocked(x, z):
		return
	if cell_state.get(key, -1) != DIRT:
		return
	var plot_scene = load("res://models/farm/SM_Plot_1x1.tscn") as PackedScene
	if plot_scene == null:
		push_error("FarmGrid: SM_Plot_1x1.tscn not found.")
		return
	cell_state[key] = TILLED
	var plot = plot_scene.instantiate()
	add_child(plot)
	var local_pos = grid_map.map_to_local(key)
	plot.position = Vector3(local_pos.x, 0.0, local_pos.z)
	_plots[key] = plot

func plant_crop(x: int, z: int, seed_item_id: String) -> void:
	var key = Vector3i(x, 0, z)
	if not _is_parcel_unlocked(x, z):
		return
	if cell_state.get(key, -1) != TILLED:
		return
	if _crops.has(key):
		return
	var crop_def = CropDB.get_crop_for_seed(seed_item_id)
	if crop_def == null:
		return
	var crop = PlantedCrop.new()
	add_child(crop)
	var local_pos = grid_map.map_to_local(key)
	crop.position = Vector3(local_pos.x, 0.05, local_pos.z)
	crop.setup(crop_def)
	_crops[key] = crop

func harvest_crop(x: int, z: int, tool_id: String = "") -> Dictionary:
	var key = Vector3i(x, 0, z)
	var crop = _crops.get(key) as PlantedCrop
	if crop == null or not crop.is_ready_to_harvest():
		return {}
	var result = crop.harvest(tool_id)
	if not (crop.crop_def and crop.crop_def.can_regrow):
		crop.queue_free()
		_crops.erase(key)
	return result

func chop_tree(x: int, z: int) -> Dictionary:
	var key = Vector3i(x, 0, z)
	var crop = _crops.get(key) as PlantedCrop
	if crop == null or crop.crop_def == null or not crop.crop_def.is_tree:
		return {}
	var result = crop.chop()
	crop.queue_free()
	_crops.erase(key)
	return result

func get_crop(x: int, z: int) -> PlantedCrop:
	return _crops.get(Vector3i(x, 0, z), null)

func untill_cell(x: int, z: int) -> void:
	var key = Vector3i(x, 0, z)
	if cell_state.get(key, -1) != TILLED:
		return
	if _plots.has(key):
		_plots[key].queue_free()
		_plots.erase(key)
	if _crops.has(key):
		_crops[key].queue_free()
		_crops.erase(key)
	cell_state[key] = DIRT

func set_cell(x: int, z: int, state: int) -> void:
	var key = Vector3i(x, 0, z)
	cell_state[key] = state
	grid_map.set_cell_item(key, state)

func get_cell(x: int, z: int) -> int:
	return cell_state.get(Vector3i(x, 0, z), -1)
