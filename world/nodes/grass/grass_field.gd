@tool
class_name GrassField
extends CSGBox3D

## Renders a dense field of grass via a single MultiMeshInstance3D (one
## draw call, no per-blade Node3D/collision cost) instead of NodePainter's
## "instantiate one real scene per point" approach -- that worked fine for
## hundreds of mining/tree nodes but fell over at Minecraft/7D2D grass
## density (thousands of always-existing nodes tanked FPS even after
## distance-culling their collision and visibility, since just being in
## the scene tree costs CPU regardless).
##
## A small fixed pool of real, interactive CuttableGrass instances gets
## repositioned onto whichever grass points are currently within
## claim_radius of the player -- interaction only ever needs melee range,
## so the pool stays tiny (pool_size) no matter how dense the field is.
## Everything else is pure MultiMesh rendering with no per-instance
## overhead at all.
##
## Same box-resize-in-editor workflow and seeded-noise placement algorithm
## as NodePainter, so existing presets ported over with just their
## transform/size/noise/seed values copied across.

@export var grass_scene: PackedScene

@export var min_spacing: float = 0.5

@export_group("Area Fill")
## Candidate points tried across this box's own footprint -- actual placed
## count will be lower once density/spacing rejects some of them.
@export var fill_attempts: int = 1000
@export var noise_scale: float = 0.04
@export_range(-1.0, 1.0, 0.01) var density_threshold: float = -0.3
@export var noise_seed: int = 0
@export var placement_seed: int = 0
## Square keep-out zone centered on WORLD origin -- see NodePainter's own
## avoid_center_square for the full reasoning (same idea, ported as-is).
@export var avoid_center_square: float = 0.0
## When true, candidates that don't land on grass-textured terrain (the same
## check that already drives can_regrow below) are rejected at placement
## time instead of just spawning non-regrowable -- for biomes like the
## gravel fields where grass should only appear on the actual grassy
## patches, not scattered across gravel/rock ground too.
@export var require_grass_terrain: bool = false

@export_group("Interactive Pool")
## How many real, cuttable grass instances exist at once -- repositioned
## onto whatever's nearest the player, not one per point. Interaction only
## ever needs melee range, so this stays small no matter how dense the
## field is, but needs to comfortably exceed however many points can
## actually fit inside claim_radius at this field's min_spacing (a 6m-
## radius circle can hold ~2800 points at the farm's current 0.2m
## spacing) -- keep this ahead of density increases or nearby grass gets
## stuck visual-only (no live proxy left to claim it) until a slot frees.
@export var pool_size: int = 600
@export var claim_radius: float = 6.0
## Slightly larger than claim_radius so hovering right at the boundary
## doesn't rapidly claim/release the same point every check.
@export var release_radius: float = 8.0
const CLAIM_CHECK_INTERVAL: float = 0.2
## Walking into a dense area can bring hundreds of new points inside
## claim_radius in a single tick -- claiming (or releasing) them all in
## one frame is what caused stutter while moving (fine while standing
## still, since nothing new enters range then). Capping how much of that
## work happens per tick spreads a big batch across a few tenths of a
## second instead of one frame; the MultiMesh already renders every point
## at full density regardless, so the only visible effect is a brief delay
## before newly-nearby grass becomes individually cuttable.
const MAX_CLAIMS_PER_TICK: int = 20
const MAX_RELEASES_PER_TICK: int = 20

@export_group("Rendering")
## The field's grass is split across one MultiMeshInstance3D per chunk_size
## square instead of one giant multimesh for the whole field. Godot re-
## uploads a MultiMesh's ENTIRE transform buffer to the GPU whenever ANY
## single instance in it changes (there's no partial/dirty-region update --
## see godot-proposals#957), and _set_multimesh_visible() below is called on
## every claim/release, i.e. every time the player moves near new grass.
## At farm density (tens of thousands of points in one buffer) that
## per-claim reupload of the WHOLE field was the actual stutter source --
## worse the denser the field, exactly matching what got reported. Chunking
## means a claim/release only reuploads the small buffer for the one chunk
## it's in, and this also gets real frustum culling as a side effect (each
## chunk's AABB is culled independently, unlike one field-wide multimesh).
@export var chunk_size: float = 40.0
## Same idea as tree_node.gd's own visibility_range -- past this many
## meters from the camera, a chunk's grass just isn't drawn. Applied
## directly to each chunk's MultiMeshInstance3D (GeometryInstance3D.
## visibility_range_end), so it's a renderer-level cutoff, not a per-frame
## script check -- grass blades are imperceptible at range anyway, so this
## is pure savings with no visible loss.
@export var visibility_range: float = 60.0

@warning_ignore("unused_private_class_variable")
@export_tool_button("Regenerate", "Reload") var _regen_btn = generate
@warning_ignore("unused_private_class_variable")
@export_tool_button("Clear", "Clear") var _clear_btn = clear_generated

## One entry per grass point: {transform, can_regrow, cut, regrow_at}.
var _points: Array = []
var _hidden_transform := Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO)

## chunk_cell (Vector2i) -> that chunk's MultiMesh.
var _chunks: Dictionary = {}
## point_index -> [chunk_cell, local_index_within_that_chunk's_multimesh].
## Lets _set_multimesh_visible() go straight to the right small buffer
## instead of needing to know which chunk a point landed in.
var _point_chunk: Array = []

## Point indices bucketed by a claim_radius-sized grid cell, built once at
## generation time -- _update_claims() used to scan every single point in
## the whole field every 0.2s just to find which ones are near the player,
## which was cheap at hundreds of points but became the actual stutter
## source at tens of thousands. Cell size == claim_radius means anything
## within claim_radius of a query position is guaranteed to be in that
## position's cell or one of its 8 neighbors, so a lookup only ever
## touches points actually nearby instead of the entire field.
var _claim_grid: Dictionary = {}

var _pool: Array = []  # root "Grass" instances, fixed size, reused
var _pool_cuttables: Array = []  # parallel CuttableGrass refs, cached once
var _free_pool_indices: Array = []
var _claims: Dictionary = {}  # point_index -> pool_index

var _regrowing_indices: Array = []
var _claim_timer: float = 0.0

func _ready() -> void:
	if Engine.is_editor_hint():
		generate()
		return
	# Same reasoning as NodePainter: capture the real footprint before
	# zeroing size/collision for rendering, and defer generation so
	# Terrain3D has finished initializing by the time it runs.
	var area_size = size
	size = Vector3.ZERO
	use_collision = false
	call_deferred("generate", area_size)

func clear_generated() -> void:
	for child in get_children():
		child.free()
	_points.clear()
	_claim_grid.clear()
	_pool.clear()
	_pool_cuttables.clear()
	_free_pool_indices.clear()
	_claims.clear()
	_regrowing_indices.clear()
	_chunks.clear()
	_point_chunk.clear()

func generate(area_size: Vector3 = size) -> void:
	clear_generated()
	if grass_scene == null or not is_inside_tree():
		return

	# Sourced once up front and baked directly into each point's stored
	# transform below -- that's the ONE transform used both for the
	# MultiMesh instance and for repositioning a pooled proxy onto this
	# point (see cuttable_grass.gd's bind()), so they can't drift out of
	# sync the way a separately-applied scale would (a pooled proxy
	# rendering at the wrong size compared to its MultiMesh neighbors).
	var template = grass_scene.instantiate()
	var base_scale: Vector3 = template.transform.basis.get_scale() if template is Node3D else Vector3.ONE
	var mesh_instance := _find_mesh_instance(template)
	var mesh: Mesh = mesh_instance.mesh if mesh_instance else null
	template.free()
	if mesh == null:
		push_warning("GrassField: grass_scene has no MeshInstance3D to source a mesh from.")
		return

	var noise = FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = noise_scale
	var rng = RandomNumberGenerator.new()
	rng.seed = placement_seed
	var terrain = _find_terrain()

	var half_w = area_size.x / 2.0
	var half_d = area_size.z / 2.0
	# Cell size == min_spacing, so two points closer than min_spacing can
	# only ever land in the same cell or an immediately adjacent one --
	# checking just that 3x3 neighborhood instead of every placed point so
	# far is what keeps this an O(N) scan instead of the O(N^2) a flat
	# "check every existing point" list turns into at these counts (tens
	# of thousands of points), which was the actual cause of load taking
	# so long once density went up this far.
	var spatial_grid: Dictionary = {}

	for i in fill_attempts:
		var x = rng.randf_range(-half_w, half_w)
		var z = rng.randf_range(-half_d, half_d)
		if noise.get_noise_2d(x, z) < density_threshold:
			continue

		var world_xz: Vector3 = global_transform * Vector3(x, 0.0, z)
		if avoid_center_square > 0.0:
			var half_avoid = avoid_center_square / 2.0
			if absf(world_xz.x) < half_avoid and absf(world_xz.z) < half_avoid:
				continue
		var ground = _sample_ground(terrain, world_xz)
		if ground == null:
			continue
		var on_grass_terrain := _is_grass_terrain(terrain, ground)
		if require_grass_terrain and not on_grass_terrain:
			continue
		if _too_close(ground, spatial_grid):
			continue

		_record_position(ground, spatial_grid)
		var xform := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(base_scale), ground)
		_points.append({
			"transform": xform,
			"can_regrow": on_grass_terrain,
			"cut": false,
			"regrow_at": -1.0,
		})
		_record_claim_grid(_points.size() - 1, ground)

	_build_multimeshes(mesh)
	_build_pool()
	print("GrassField: generated %d grass points across %d chunks (pool=%d) using %s" % [_points.size(), _chunks.size(), pool_size, ("Terrain3D height data" if terrain else "physics raycast fallback")])

func _build_multimeshes(mesh: Mesh) -> void:
	if _points.is_empty():
		return

	# Bucket point indices by chunk first so each chunk's MultiMesh can be
	# allocated at its final instance_count up front, then fill _point_chunk
	# as each point's slot is assigned.
	var buckets: Dictionary = {}  # chunk_cell -> Array[int] of point_index
	_point_chunk.resize(_points.size())
	for i in _points.size():
		var cell := _chunk_cell(_points[i]["transform"].origin)
		if not buckets.has(cell):
			buckets[cell] = []
		buckets[cell].append(i)

	for cell in buckets:
		var indices: Array = buckets[cell]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = indices.size()
		for local_i in indices.size():
			var point_index: int = indices[local_i]
			mm.set_instance_transform(local_i, _points[point_index]["transform"])
			_point_chunk[point_index] = [cell, local_i]

		var mm_instance := MultiMeshInstance3D.new()
		mm_instance.name = "GrassMultiMesh_%d_%d" % [cell.x, cell.y]
		mm_instance.multimesh = mm
		mm_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mm_instance.visibility_range_end = visibility_range
		add_child(mm_instance)
		# Per-instance MultiMesh transforms are relative to this node's OWN
		# transform, not world space -- but _points stores world-space
		# transforms (ground is a world position from _sample_ground()).
		# Without this, every instance renders offset by this field's own box
		# position/height on top of its already-correct world position (e.g.
		# floating up by the box's y=20), while the pooled proxy looks
		# correctly placed since Node3D.global_transform's setter already
		# accounts for the parent offset that a raw MultiMesh transform does
		# not -- top_level + identity transform makes this node's local space
		# equal world space, matching what _points already stores.
		mm_instance.top_level = true
		mm_instance.global_transform = Transform3D.IDENTITY

		_chunks[cell] = mm

func _build_pool() -> void:
	for i in pool_size:
		var proxy = grass_scene.instantiate()
		add_child(proxy)
		var area := _find_cuttable(proxy)
		if area:
			area.field = self
			area.release()
		_pool.append(proxy)
		_pool_cuttables.append(area)
		_free_pool_indices.append(i)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_update_regrowth()
	_claim_timer += delta
	if _claim_timer < CLAIM_CHECK_INTERVAL:
		return
	_claim_timer = 0.0
	_update_claims()

## Regrowth runs on an absolute timestamp, independent of whether a point
## is currently claimed -- grass keeps growing whether you're standing
## next to it or not, it just doesn't get a live proxy (and therefore a
## visible "regrowing" mesh state) until you're close enough again.
func _update_regrowth() -> void:
	if _regrowing_indices.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	var done: Array = []
	for point_index in _regrowing_indices:
		var point = _points[point_index]
		if now >= point["regrow_at"]:
			point["cut"] = false
			point["regrow_at"] = -1.0
			_set_multimesh_visible(point_index, true)
			if _claims.has(point_index):
				_pool_cuttables[_claims[point_index]].show_uncut()
			done.append(point_index)
	for point_index in done:
		_regrowing_indices.erase(point_index)

func _update_claims() -> void:
	var player_nodes = get_tree().get_nodes_in_group("player")
	if player_nodes.is_empty():
		return
	var player_pos: Vector3 = player_nodes[0].global_position

	var to_release: Array = []
	for point_index in _claims:
		var dist: float = _points[point_index]["transform"].origin.distance_to(player_pos)
		if dist > release_radius:
			to_release.append(point_index)
	# Nearest-released-last doesn't matter here, just cap how many happen
	# this tick -- the rest will get picked up on a later tick.
	for i in mini(to_release.size(), MAX_RELEASES_PER_TICK):
		_release_point(to_release[i])

	if _free_pool_indices.is_empty():
		return

	# Nearest-first so a full pool always favors what's actually closest to
	# the player, not whatever happened to be checked first. Only scans the
	# 3x3 claim-grid neighborhood around the player instead of every point
	# in the field -- see _claim_grid's declaration for why.
	var candidates: Array = []
	var player_cell := _claim_grid_cell(player_pos)
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			var neighbor := player_cell + Vector2i(dx, dz)
			if not _claim_grid.has(neighbor):
				continue
			for point_index in _claim_grid[neighbor]:
				if _claims.has(point_index):
					continue
				var point = _points[point_index]
				if point["cut"]:
					continue
				var dist: float = point["transform"].origin.distance_to(player_pos)
				if dist <= claim_radius:
					candidates.append([dist, point_index])
	candidates.sort_custom(func(a, b): return a[0] < b[0])

	var claimed_this_tick := 0
	for entry in candidates:
		if _free_pool_indices.is_empty() or claimed_this_tick >= MAX_CLAIMS_PER_TICK:
			break
		_claim_point(entry[1])
		claimed_this_tick += 1

func _claim_point(point_index: int) -> void:
	var pool_index = _free_pool_indices.pop_back()
	_claims[point_index] = pool_index
	_pool_cuttables[pool_index].bind(point_index, _points[point_index]["transform"])
	_set_multimesh_visible(point_index, false)

func _release_point(point_index: int) -> void:
	var pool_index = _claims[point_index]
	_claims.erase(point_index)
	_free_pool_indices.append(pool_index)
	_pool_cuttables[pool_index].release()
	# Only restore multimesh visibility if it's not sitting mid-regrow --
	# _update_regrowth() is what restores it once that actually finishes.
	if not _points[point_index]["cut"]:
		_set_multimesh_visible(point_index, true)

func _set_multimesh_visible(point_index: int, is_visible: bool) -> void:
	var info = _point_chunk[point_index]
	var mm: MultiMesh = _chunks[info[0]]
	var local_i: int = info[1]
	if is_visible:
		mm.set_instance_transform(local_i, _points[point_index]["transform"])
	else:
		mm.set_instance_transform(local_i, _hidden_transform)

## Called by a pooled CuttableGrass instance (world/nodes/grass/
## cuttable_grass.gd) when it's cut. regrow_time comes from the proxy's own
## export (grass.tscn's existing per-instance config), not duplicated here.
func notify_cut(point_index: int, regrow_time: float) -> void:
	var point = _points[point_index]
	point["cut"] = true
	_set_multimesh_visible(point_index, false)
	if point["can_regrow"]:
		point["regrow_at"] = Time.get_ticks_msec() / 1000.0 + regrow_time
		_regrowing_indices.append(point_index)
	else:
		# Nothing left to interact with here -- free the proxy back to the
		# pool immediately instead of waiting for it to walk out of range.
		_release_point(point_index)

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found = _find_mesh_instance(child)
		if found:
			return found
	return null

func _find_cuttable(node: Node) -> CuttableGrass:
	if node is CuttableGrass:
		return node
	for child in node.get_children():
		var found = _find_cuttable(child)
		if found:
			return found
	return null

func _chunk_cell(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / chunk_size), floori(pos.z / chunk_size))

func _claim_grid_cell(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / claim_radius), floori(pos.z / claim_radius))

func _record_claim_grid(point_index: int, pos: Vector3) -> void:
	var cell := _claim_grid_cell(pos)
	if not _claim_grid.has(cell):
		_claim_grid[cell] = []
	_claim_grid[cell].append(point_index)

func _grid_cell(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / min_spacing), floori(pos.z / min_spacing))

func _too_close(pos: Vector3, spatial_grid: Dictionary) -> bool:
	var cell := _grid_cell(pos)
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			var neighbor := cell + Vector2i(dx, dz)
			if not spatial_grid.has(neighbor):
				continue
			for p in spatial_grid[neighbor]:
				if p.distance_to(pos) < min_spacing:
					return true
	return false

func _record_position(pos: Vector3, spatial_grid: Dictionary) -> void:
	var cell := _grid_cell(pos)
	if not spatial_grid.has(cell):
		spatial_grid[cell] = []
	spatial_grid[cell].append(pos)

## Same lookup as world/nodes/node_painter.gd's _find_terrain().
func _find_terrain() -> Node:
	var root = get_tree().edited_scene_root if Engine.is_editor_hint() else get_tree().root
	if root == null:
		return null
	var found: Array = root.find_children("", "Terrain3D", true, false)
	return found[0] if found.size() > 0 else null

## Same lookup as world/nodes/node_painter.gd's _sample_ground().
func _sample_ground(terrain, world_xz: Vector3) -> Variant:
	if terrain and terrain.data:
		var local_xz: Vector3 = terrain.to_local(world_xz)
		var h: float = terrain.data.get_height(Vector3(local_xz.x, 0.0, local_xz.z))
		if not is_nan(h):
			return terrain.to_global(Vector3(local_xz.x, h, local_xz.z))
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		Vector3(world_xz.x, world_xz.y + 200.0, world_xz.z),
		Vector3(world_xz.x, world_xz.y - 200.0, world_xz.z)
	)
	var result = space_state.intersect_ray(query)
	return result.position if not result.is_empty() else null

## Indices into Terrain3D's real texture list -- 0=Map(grass), 5=grass_2
## (see world/terrain_biome.gd for the full list). Both are grass textures;
## grass landing on anything else (rock/dirt/gravel biomes, the farm's
## dirt-textured core) is a one-time cleanup, not a renewable resource --
## see cuttable_grass.gd's cut() for the actual behavior this drives.
func _is_grass_terrain(terrain, pos: Vector3) -> bool:
	if terrain == null or terrain.data == null:
		return true
	var base_id: int = terrain.data.get_control_base_id(pos)
	return base_id == 0 or base_id == 5
