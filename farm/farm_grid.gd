@tool
extends Node3D

const GRASS = 0
const DIRT = 1
const TILLED = 2
const GRID_SIZE = 20
const LIB_PATH = "res://farm/farm_mesh_library.tres"

## Terrain3D texture asset index for "dirt" (models/textures/dirt.png) --
## painted onto the ground surface under a cell the moment it becomes
## farmable, so the terrain itself reads as tilled dirt, not just the
## GridMap tile mesh sitting on top of it (matters most where the ground
## isn't flat, e.g. a FarmExpansionArea dropped onto biome-generated
## terrain).
const DIRT_TERRAIN_TEXTURE_ID = 7

## The painted farm area is split into a 2x2 layout of parcels (see
## _compute_bounds/_parcel_index below). Parcel 0 (bottom-left of the
## bounding box) starts unlocked; the rest require
## GameState.unlock_farm_parcel() (money + shop level gate). The visual
## fence/sign pieces (farm_fence_post.tscn / farm_parcel_sign.tscn) are
## hand-placed in the editor around each locked parcel's border rather
## than spawned here -- set each instance's parcel_index in the Inspector
## to match which quadrant it belongs to (1-3).

var cell_state: Dictionary = {}
var _plots: Dictionary = {}
var _crops: Dictionary = {}

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

## Bounding box of the farm's actual DIRT footprint, computed at runtime.
## Deliberately scoped to DIRT cells only (the only tile type till_cell()
## ever accepts) rather than every painted cell on this GridMap -- the same
## grid also carries decorative grass/road tiles well outside the farm, and
## including those skewed the bounds badly enough last time that every real
## farm cell landed in a locked parcel. Coordinates themselves are whatever
## was hand-painted in the editor (can be offset/negative), so this is
## computed relative to the DIRT bounding box, never assumed absolute.
var _bounds_min: Vector3i = Vector3i.ZERO
var _bounds_max: Vector3i = Vector3i.ZERO
var _parcels_active: bool = false

## Cells covered by the quadrant-math gate above (the *original* hand-painted
## farm only). Cells added later via unlock_area_as_dirt() (from a
## FarmExpansionArea unlocking) are deliberately NOT added here -- that math
## is relative to the original farm's own bounding box, so a disconnected
## expansion placed elsewhere on the map would get nonsense quadrant results.
## Those cells are already correctly gated by *when* they get painted, so
## they skip this check entirely once added.
var _quadrant_gated_cells: Dictionary = {}

## Cells the FARM SYSTEM has actually painted as DIRT/TILLED (initial scan +
## every set_cell() call since). Deliberately separate from cell_state,
## which mirrors the raw GridMap and therefore also picks up anything else
## painted with the same "dirt" mesh index elsewhere on this shared
## GridMap (e.g. a decorative dirt road/path) -- using cell_state directly
## to decide "is this already farmland" caused unlock_area_as_dirt() to
## silently skip real expansion cells that happened to sit under an
## unrelated dirt-textured tile.
var _farm_dirt_registry: Dictionary = {}

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("farm_grid")
	var used_cells = grid_map.get_used_cells()
	var dirt_cells: Array = []
	for cell in used_cells:
		var item = grid_map.get_cell_item(cell)
		cell_state[cell] = item
		if item == DIRT:
			dirt_cells.append(cell)
			_quadrant_gated_cells[cell] = true
			_farm_dirt_registry[cell] = true
	_compute_bounds(dirt_cells)
	print("FarmGrid: %d DIRT cells found, bounds min=%s max=%s" % [dirt_cells.size(), _bounds_min, _bounds_max])
	if dirt_cells.is_empty():
		# Fail-safe: if we can't find the farm's real DIRT footprint for
		# some reason, don't lock anything rather than risk blocking
		# tilling entirely again.
		push_warning("FarmGrid: no DIRT cells found -- parcel locking disabled.")
	else:
		_parcels_active = true

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

func _is_parcel_unlocked(x: int, z: int) -> bool:
	if not _parcels_active:
		return true
	return _parcel_index(x, z) < GameState.farm_parcels_unlocked

func till_cell(x: int, z: int) -> void:
	var key = Vector3i(x, 0, z)
	if _quadrant_gated_cells.has(key) and not _is_parcel_unlocked(x, z):
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
	if _quadrant_gated_cells.has(key) and not _is_parcel_unlocked(x, z):
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
	crop.cell = key
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

## Called by FarmExpansionArea once its parcel unlocks -- paints DIRT into
## whatever cells that area covers so it becomes real, tillable farmland
## instead of just a decorative unfenced patch. Cells that are already
## DIRT/TILLED (e.g. overlapping the original farm) are left untouched.
func unlock_area_as_dirt(cells: Array) -> void:
	var painted := 0
	for cell in cells:
		if _farm_dirt_registry.has(cell):
			continue
		set_cell(cell.x, cell.z, DIRT)
		painted += 1
	print("FarmGrid: unlock_area_as_dirt painted %d/%d cells" % [painted, cells.size()])

func set_cell(x: int, z: int, state: int) -> void:
	var key = Vector3i(x, 0, z)
	cell_state[key] = state
	grid_map.set_cell_item(key, state)
	if state == DIRT or state == TILLED:
		_farm_dirt_registry[key] = true
		_paint_terrain_dirt(key)

## Writes the dirt texture directly onto Terrain3D's ground at this cell.
## Uses the granular set_control_base_id/overlay_id/blend setters rather
## than hand bit-packing a float for set_control() directly -- the raw
## set_control() write was confirmed (via readback) to silently not
## stick, while these paired get/set_control_* accessors are Terrain3D's
## own scripting-friendly API for exactly this (matching getters exist
## for each), so they're far more likely to handle whatever region/dirty
## bookkeeping the raw path needs and I was missing.
## Sample points per cell (NxN grid) and how far past the cell's own 1m
## edges they spread -- painting only the center left thin grass strips
## between/around tiles, since the control map's texel resolution doesn't
## guarantee one point fills the whole 1m cell. 0.75 = each cell's paint
## spans 1.5m (centered), overlapping into its neighbors' margins so
## adjacent tilled cells blend into one continuous dirt patch.
const DIRT_PAINT_SAMPLES = 3
const DIRT_PAINT_HALF_EXTENT = 0.75

func _paint_terrain_dirt(key: Vector3i) -> void:
	var terrain = _find_terrain()
	if terrain == null or terrain.data == null:
		print("FarmGrid: _paint_terrain_dirt(%s) -- terrain=%s terrain.data=%s, aborting" % [key, terrain, (terrain.data if terrain else "n/a")])
		return
	var center: Vector3 = grid_map.to_global(grid_map.map_to_local(key))
	for ix in DIRT_PAINT_SAMPLES:
		for iz in DIRT_PAINT_SAMPLES:
			var fx := (float(ix) / (DIRT_PAINT_SAMPLES - 1) - 0.5) * 2.0 * DIRT_PAINT_HALF_EXTENT
			var fz := (float(iz) / (DIRT_PAINT_SAMPLES - 1) - 0.5) * 2.0 * DIRT_PAINT_HALF_EXTENT
			var sample_pos := center + Vector3(fx, 0.0, fz)
			terrain.data.set_control_base_id(sample_pos, DIRT_TERRAIN_TEXTURE_ID)
			terrain.data.set_control_overlay_id(sample_pos, DIRT_TERRAIN_TEXTURE_ID)
			terrain.data.set_control_blend(sample_pos, 0.0)
	# GPU-side control texture needs an explicit refresh after scripted
	# per-point edits, same as Terrain3D's own importer.gd does after
	# import_images().
	terrain.data.update_maps(Terrain3DRegion.TYPE_CONTROL, true, false)

## Same lookup as world/nodes/node_painter.gd's _find_terrain().
func _find_terrain() -> Node:
	var root = get_tree().edited_scene_root if Engine.is_editor_hint() else get_tree().root
	if root == null:
		return null
	var found: Array = root.find_children("", "Terrain3D", true, false)
	return found[0] if found.size() > 0 else null

## Same bit-packing as world/terrain_seed_generator.gd's _encode_control()
## -- base id bits 27-31, overlay id bits 22-26, blend bits 14-21, packed
## into a float whose raw bits (not numeric value) Terrain3D's shader
## reads back via floatBitsToUint.
func _encode_control(base_id: int, over_id: int, blend: float) -> float:
	var blend_u8 := int(clampf(blend, 0.0, 1.0) * 255.0)
	var value := 0
	value |= (base_id & 0x1F) << 27
	value |= (over_id & 0x1F) << 22
	value |= (blend_u8 & 0xFF) << 14
	var bytes := PackedByteArray()
	bytes.resize(4)
	bytes.encode_u32(0, value)
	return bytes.decode_float(0)

func get_cell(x: int, z: int) -> int:
	return cell_state.get(Vector3i(x, 0, z), -1)
