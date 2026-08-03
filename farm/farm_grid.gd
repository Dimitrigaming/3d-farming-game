@tool
extends Node3D

const GRASS = 0
const DIRT = 1
const TILLED = 2
const GRID_SIZE = 20
const LIB_PATH = "res://farm/farm_mesh_library.tres"

var cell_state: Dictionary = {}
var _plots: Dictionary = {}

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

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("farm_grid")
	for cell in grid_map.get_used_cells():
		cell_state[cell] = grid_map.get_cell_item(cell)

func till_cell(x: int, z: int) -> void:
	var key = Vector3i(x, 0, z)
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

func untill_cell(x: int, z: int) -> void:
	var key = Vector3i(x, 0, z)
	if cell_state.get(key, -1) != TILLED:
		return
	if _plots.has(key):
		_plots[key].queue_free()
		_plots.erase(key)
	cell_state[key] = DIRT

func set_cell(x: int, z: int, state: int) -> void:
	var key = Vector3i(x, 0, z)
	cell_state[key] = state
	grid_map.set_cell_item(key, state)

func get_cell(x: int, z: int) -> int:
	return cell_state.get(Vector3i(x, 0, z), -1)
