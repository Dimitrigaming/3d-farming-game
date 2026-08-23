@tool
class_name TerrainScatterSystem
extends Node3D

## Editor-time (for now) driver for texture/height-classified terrain
## scatter -- replaces TerrainMeshScatter's CSGBox3D design, which had a
## real problem: a hand-placed, hand-sized box can't be the unit of
## "where foliage/resources go" in an actually-procedural open world,
## since nobody places a box for terrain that's generated at runtime.
##
## Instead, each entry in `rules` (TerrainScatterRule) describes a
## condition -- "this Terrain3D control-map texture, this height range" --
## and a result -- "these Terrain3D mesh_list ids, at this density/
## clustering." scatter_all() finds every active Terrain3D region via
## terrain.data.get_region_locations() and evaluates every rule across the
## FULL world-space bounds of every one of them -- there's no area to
## configure because the terrain itself defines the area. Add one rule for
## gravel, another for rocks, etc.; one node covers the whole map.
##
## This is still an editor-triggered bake for THIS project's static,
## hand-built terrain (frees itself at runtime like GroundPainter). For a
## true procedurally-streamed open world, _apply_rule() is the part that
## ports directly: call it once per newly-generated terrain region/chunk
## (instead of once per rule across every region up front) and the same
## texture/height-driven scatter falls out automatically as new terrain
## streams in -- no per-chunk hand-authoring required.

@export var rules: Array[TerrainScatterRule] = []

## Toggle these checkboxes in the Inspector to trigger an action -- plain
## bool + inline setter instead of @export_tool_button, because that
## annotation's exported Callable property came back Nil after this node
## was saved and reloaded as part of a scene (a real bug, not just a
## runtime-only quirk), which silently broke the button entirely. Each
## checkbox resets itself back to false immediately after firing, so it
## behaves like a momentary button rather than a persistent toggle.
@export var run_scatter: bool = false:
	set(value):
		if value:
			scatter_all()
		run_scatter = false

@export var run_clear: bool = false:
	set(value):
		if value:
			clear_all()
		run_clear = false

func _ready() -> void:
	if not Engine.is_editor_hint():
		queue_free()

func scatter_all() -> void:
	var terrain = _find_terrain()
	if terrain == null or terrain.data == null or terrain.instancer == null:
		push_warning("TerrainScatterSystem: no Terrain3D (with data/instancer) found.")
		return

	var region_locations: Array = terrain.data.get_region_locations()
	if region_locations.is_empty():
		push_warning("TerrainScatterSystem: Terrain3D has no active regions to scatter onto.")
		return
	var region_world_size: float = float(terrain.region_size) * terrain.vertex_spacing

	var total_placed := 0
	for rule in rules:
		if rule == null or not _has_variants(rule):
			continue
		var per_mesh: Dictionary = _apply_rule(terrain, rule, region_locations, region_world_size)
		var rule_placed := 0
		for mesh_id in per_mesh:
			var transforms: Array[Transform3D] = per_mesh[mesh_id]
			terrain.instancer.add_transforms(mesh_id, transforms)
			rule_placed += transforms.size()
		total_placed += rule_placed
		print("TerrainScatterSystem: rule '%s' placed %d instances across %d region(s)" % [rule.rule_name, rule_placed, region_locations.size()])

	terrain.instancer.update_mmis(true)
	print("TerrainScatterSystem: done, %d total instances placed" % total_placed)

## Clears every mesh id used by any rule on this node -- terrain-wide (see
## class doc on TerrainMeshVariant / Terrain3D's API: there's no per-area
## clear), so this assumes one TerrainScatterSystem owns the whole map's
## rule-driven scatter rather than sharing mesh ids with something else.
func clear_all() -> void:
	var terrain = _find_terrain()
	if terrain == null or terrain.instancer == null:
		push_warning("TerrainScatterSystem: no Terrain3D (with instancer) found.")
		return
	var ids := []
	for rule in rules:
		if rule == null:
			continue
		for variant in rule.mesh_variants:
			if variant == null or ids.has(variant.mesh_id):
				continue
			ids.append(variant.mesh_id)
			terrain.instancer.clear_by_mesh(variant.mesh_id)
	terrain.instancer.update_mmis(true)
	print("TerrainScatterSystem: cleared mesh id(s) %s (terrain-wide)" % [ids])

## One rule, evaluated across every region's real world-space bounds --
## same noise-gated-scatter + tight-clustering technique proven in
## world/nodes/rocks/rock_field.gd, extended with the texture/height gate
## that makes this rule-driven instead of area-driven.
func _apply_rule(terrain, rule: TerrainScatterRule, region_locations: Array, region_world_size: float) -> Dictionary:
	var rng = RandomNumberGenerator.new()
	rng.seed = rule.placement_seed
	var noise = FastNoiseLite.new()
	noise.seed = rule.noise_seed
	noise.frequency = rule.noise_scale

	var spatial_grid: Dictionary = {}
	var per_mesh: Dictionary = {}
	var half_avoid = rule.avoid_center_square / 2.0
	var attempts_per_region = maxi(1, roundi((region_world_size * region_world_size / 100.0) * rule.attempts_per_100_sqm))

	for region_loc in region_locations:
		var origin_x: float = region_loc.x * region_world_size
		var origin_z: float = region_loc.y * region_world_size
		for i in attempts_per_region:
			var x = origin_x + rng.randf_range(0.0, region_world_size)
			var z = origin_z + rng.randf_range(0.0, region_world_size)
			if noise.get_noise_2d(x, z) < rule.density_threshold:
				continue
			if rule.avoid_center_square > 0.0 and absf(x) < half_avoid and absf(z) < half_avoid:
				continue
			var ground = _sample_ground(terrain, Vector3(x, 0.0, z))
			if ground == null:
				continue
			if ground.y < rule.min_height or ground.y > rule.max_height:
				continue
			if not _matches_texture(terrain, ground, rule.require_texture_id):
				continue
			if _too_close(ground, spatial_grid, rule.min_spacing):
				continue
			_record_position(ground, spatial_grid, rule.min_spacing)
			_add_instance(per_mesh, rule, rng, ground)

			if rng.randf() < rule.cluster_chance:
				_spawn_cluster(terrain, rule, rng, ground, per_mesh, spatial_grid, half_avoid)
	return per_mesh

## Same clustering shape as world/nodes/rocks/rock_field.gd's
## _spawn_cluster(), extended with the texture/height/avoid-square filters.
func _spawn_cluster(terrain, rule: TerrainScatterRule, rng: RandomNumberGenerator, center: Vector3, per_mesh: Dictionary, spatial_grid: Dictionary, half_avoid: float) -> void:
	var count = rng.randi_range(rule.cluster_size_min, rule.cluster_size_max)
	for i in count:
		var angle = rng.randf() * TAU
		var dist = sqrt(rng.randf()) * rule.cluster_radius
		var x = center.x + cos(angle) * dist
		var z = center.z + sin(angle) * dist
		if rule.avoid_center_square > 0.0 and absf(x) < half_avoid and absf(z) < half_avoid:
			continue
		var ground = _sample_ground(terrain, Vector3(x, 0.0, z))
		if ground == null:
			continue
		if ground.y < rule.min_height or ground.y > rule.max_height:
			continue
		if not _matches_texture(terrain, ground, rule.require_texture_id):
			continue
		if _too_close(ground, spatial_grid, rule.cluster_min_spacing):
			continue
		_record_position(ground, spatial_grid, rule.cluster_min_spacing)
		_add_instance(per_mesh, rule, rng, ground)

func _add_instance(per_mesh: Dictionary, rule: TerrainScatterRule, rng: RandomNumberGenerator, ground: Vector3) -> void:
	var mesh_id = _pick_variant(rule, rng)
	if mesh_id < 0:
		return
	if not per_mesh.has(mesh_id):
		per_mesh[mesh_id] = [] as Array[Transform3D]
	var basis = Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rule.mesh_scale)
	per_mesh[mesh_id].append(Transform3D(basis, ground))

## Same weighted-pick shape as world/nodes/rocks/rock_field.gd's
## _pick_variant(), returning a mesh_id directly instead of an index.
func _pick_variant(rule: TerrainScatterRule, rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for entry in rule.mesh_variants:
		if entry:
			total += max(0.0, entry.weight)
	if total <= 0.0:
		return -1
	var roll = rng.randf() * total
	var acc := 0.0
	for entry in rule.mesh_variants:
		if entry == null:
			continue
		acc += max(0.0, entry.weight)
		if roll < acc:
			return entry.mesh_id
	return -1

func _has_variants(rule: TerrainScatterRule) -> bool:
	for entry in rule.mesh_variants:
		if entry:
			return true
	return false

## world/terrain_seed_generator.gd always paints a biome's grass-family
## texture as the control map's BASE id and its rock texture as the
## OVERLAY, blended in by height/slope (final_base = grass_id, final_over
## = rock_id) -- so deep in a rocky biome's interior the ground can be
## visually 100% rock while get_control_base_id() still reports the grass
## id. The rock id only becomes the actual base id at biome-boundary
## "rock-to-rock" blends (see that file's generate(), around
## grass_blend_factor > 0.001 and rockiness > 0.5). Checking base OR a
## dominant (blend > 0.5) overlay is what actually matches "this reads as
## texture_id", not just base -- without it, texture-filtered rules only
## ever hit biome borders and skip their own interiors.
func _matches_texture(terrain, pos: Vector3, texture_id: int) -> bool:
	if texture_id < 0:
		return true
	if terrain.data.get_control_base_id(pos) == texture_id:
		return true
	return terrain.data.get_control_overlay_id(pos) == texture_id and terrain.data.get_control_blend(pos) > 0.5

func _grid_cell(pos: Vector3, spacing: float) -> Vector2i:
	return Vector2i(floori(pos.x / spacing), floori(pos.z / spacing))

func _too_close(pos: Vector3, spatial_grid: Dictionary, spacing: float) -> bool:
	var cell := _grid_cell(pos, spacing)
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			var neighbor := cell + Vector2i(dx, dz)
			if not spatial_grid.has(neighbor):
				continue
			for p in spatial_grid[neighbor]:
				if p.distance_to(pos) < spacing:
					return true
	return false

func _record_position(pos: Vector3, spatial_grid: Dictionary, spacing: float) -> void:
	var cell := _grid_cell(pos, spacing)
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
