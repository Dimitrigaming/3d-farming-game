@tool
class_name TreeField
extends CSGBox3D

## Same fix as world/nodes/rocks/rock_field.gd (chunked MultiMesh rendering
## + a small pool of live interactive proxies), applied to trees. Trees were
## the last remaining "one real scripted node per instance" system in the
## world -- NodePainter spawning a real tree_node.gd-scripted TreeNode per
## point was fine in the hundreds but became the actual FPS cost once
## density went up to 5000/biome (each one a full Node3D with its own HP,
## StaticBody, mesh instance, and ResourceStreamer registration, all always
## in the tree regardless of distance -- visibility_range_end only stopped
## rendering them, not the underlying node/script cost).
##
## Differences from RockField, both from how the tree prop scenes
## (world/props/*.tscn) are actually built:
##   - Their root node carries its own uniform scale (e.g. 2x) rather than
##     sitting at identity -- same as GrassField's own base_scale handling,
##     baked into each point's stored transform so the MultiMesh copy and
##     the pooled proxy's mesh render at the same size.
##   - Some of them use TWO collision shapes (trunk + a root/base box)
##     instead of one, so variant collision data is a list per variant, and
##     TreeProxy (tree_proxy.gd) always has MAX_SHAPES slots rather than
##     just one.
## The old dynamically-fit, trunk-width-clamped hitbox that tree_node.gd
## used to compute per-instance is gone -- every tree just uses its own
## prop scene's already-authored collision shape(s) instead, same as every
## other resource field. Simpler, and one less per-instance computation.

@export var scenes: Array[WeightedScene] = []
@export var min_spacing: float = 4.0

@export_group("Area Fill")
@export var fill_attempts: int = 900
@export var noise_scale: float = 0.05
@export_range(-1.0, 1.0, 0.01) var density_threshold: float = -0.5
@export var noise_seed: int = 0
@export var placement_seed: int = 0
## Square keep-out zone centered on WORLD origin -- see NodePainter's own
## avoid_center_square for the full reasoning (same idea, ported as-is).
@export var avoid_center_square: float = 0.0

@export_group("Clustering")
@export_range(0.0, 1.0, 0.01) var cluster_chance: float = 0.0
@export var cluster_size_min: int = 2
@export var cluster_size_max: int = 3
@export var cluster_radius: float = 4.0

@export_group("Rendering")
## See grass_field.gd's own chunk_size export for the full reasoning
## (independent per-chunk AABB culling instead of one field-wide multimesh).
@export var chunk_size: float = 40.0
## Same as tree_node.gd's own visibility_range -- past this many meters from
## the camera, a chunk's tree instances just aren't drawn. Applied directly
## to each chunk's MultiMeshInstance3D (GeometryInstance3D.
## visibility_range_end), so it's a renderer-level cutoff, not a per-frame
## script check.
@export var visibility_range: float = 100.0
## Same idea as grass_field.gd's own fade_margin -- dithers a chunk out
## smoothly over its last fade_margin meters instead of popping the whole
## chunk at once (VISIBILITY_RANGE_FADE_SELF).
@export var fade_margin: float = 8.0

@export_group("Chopping")
## Same fields/behavior as tree_node.gd's own interact(), applied uniformly
## to every tree in this field -- except hp/drops, which a variant can
## override individually (see WeightedScene.hp_override/drops_*_override).
@export var wood_type: String = "wood"
@export var drops_min: int = 2
@export var drops_max: int = 4
## Default HP for any variant that doesn't set its own hp_override.
@export var hp: int = 30
@export_range(0.0, 1.0, 0.01) var wrong_tool_percent: float = 0.1
@export var required_tool_category: String = "axe"
@export var respawn_time: float = 30.0

@export_group("Interactive Pool")
## How many real, interactive proxies exist at once -- repositioned onto
## whatever's nearest the player, not one per tree. Stays small no matter
## how dense the field is; needs to comfortably exceed however many points
## can actually fit inside activate_radius at this field's min_spacing.
@export var pool_size: int = 150
@export var activate_radius: float = 15.0
## Slightly larger than activate_radius so hovering right at the boundary
## doesn't rapidly activate/deactivate the same point every check.
@export var deactivate_radius: float = 20.0
const CHECK_INTERVAL: float = 0.2
const MAX_ACTIVATIONS_PER_TICK: int = 20
const MAX_DEACTIVATIONS_PER_TICK: int = 20

@warning_ignore("unused_private_class_variable")
@export_tool_button("Regenerate", "Reload") var _regen_btn = generate
@warning_ignore("unused_private_class_variable")
@export_tool_button("Clear", "Clear") var _clear_btn = clear_generated

## One entry per tree point: {transform, variant, hp, felled, regrow_at}.
var _points: Array = []
var _hidden_transform := Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO)

## Index-aligned with `scenes`, extracted once from each variant's own
## template scene instead of instantiating a real copy per placed point.
var _variant_meshes: Array = []
var _variant_shapes: Array = []  # Array[Array[Shape3D]], up to MAX_SHAPES each
var _variant_shape_xforms: Array = []  # Array[Array[Transform3D]]
## The tree prop scene's own root scale (e.g. 2x) -- see class doc comment.
var _variant_scale: Array = []
var _variant_hp: Array = []
var _variant_drops_min: Array = []
var _variant_drops_max: Array = []

## chunk_cell (Vector2i) -> {variant_index -> MultiMesh}.
var _chunks: Dictionary = {}
## chunk_cell (Vector2i) -> {variant_index -> centroid Vector3}. Mirrors
## _chunks' own keying -- see _build_multimeshes() for why each variant's
## MultiMeshInstance3D needs its own real centroid instead of a shared
## world-origin transform.
var _chunk_centers: Dictionary = {}
## point_index -> [chunk_cell, variant, local_index_within_that_chunk's_
## multimesh]. Lets _set_multimesh_visible() go straight to the right slot.
var _point_chunk: Array = []

## Point indices bucketed by an activate_radius-sized grid cell -- same
## reasoning as grass_field.gd's _claim_grid, so the proximity check below
## only ever scans points actually near the player instead of the whole
## field every tick.
var _claim_grid: Dictionary = {}

var _pool: Array = []  # TreeProxy, fixed size, reused
var _free_pool_indices: Array = []
var _claims: Dictionary = {}  # point_index -> pool_index
var _claim_timer: float = 0.0

var _regrowing_indices: Array = []

func _ready() -> void:
	if Engine.is_editor_hint():
		generate()
		return
	# Same reasoning as NodePainter/GrassField: capture the real footprint
	# before zeroing size/collision for rendering, and defer generation so
	# Terrain3D has finished initializing by the time it runs.
	var area_size = size
	size = Vector3.ZERO
	use_collision = false
	call_deferred("generate", area_size)

func clear_generated() -> void:
	for child in get_children():
		child.free()
	_points.clear()
	_variant_meshes.clear()
	_variant_shapes.clear()
	_variant_shape_xforms.clear()
	_variant_scale.clear()
	_variant_hp.clear()
	_variant_drops_min.clear()
	_variant_drops_max.clear()
	_chunks.clear()
	_chunk_centers.clear()
	_point_chunk.clear()
	_claim_grid.clear()
	_pool.clear()
	_free_pool_indices.clear()
	_claims.clear()
	_regrowing_indices.clear()

func generate(area_size: Vector3 = size) -> void:
	clear_generated()
	if not _has_scenes() or not is_inside_tree():
		return
	_build_variant_assets()

	var noise = FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = noise_scale
	var rng = RandomNumberGenerator.new()
	rng.seed = placement_seed
	var terrain = _find_terrain()

	var half_w = area_size.x / 2.0
	var half_d = area_size.z / 2.0
	# Cell size == min_spacing -- see grass_field.gd's generate() for why
	# this spatial grid (instead of a flat "check every placed point" list)
	# is what keeps this an O(N) scan instead of O(N^2) at high counts.
	var spatial_grid: Dictionary = {}
	var placed := 0
	var clusters := 0

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
		if _too_close(ground, spatial_grid):
			continue

		var variant = _pick_variant(rng)
		if variant < 0:
			continue
		_record_position(ground, spatial_grid)
		_add_point(variant, ground, rng)
		placed += 1

		if rng.randf() < cluster_chance:
			# Same variant as the point that seeded the cluster, not a fresh
			# weighted pick per member -- reads as one stand of a single
			# tree type, not a mixed grab-bag.
			var extra = _spawn_cluster(variant, ground, rng, terrain, spatial_grid)
			if extra > 0:
				clusters += 1
				placed += extra

	var chunk_count := _build_multimeshes()
	_build_pool()
	print("TreeField: generated %d tree points (%d clusters, %d chunks, pool=%d) using %s" % [_points.size(), clusters, chunk_count, pool_size, ("Terrain3D height data" if terrain else "physics raycast fallback")])

func _spawn_cluster(variant: int, center: Vector3, rng: RandomNumberGenerator, terrain, spatial_grid: Dictionary) -> int:
	var count = rng.randi_range(cluster_size_min, cluster_size_max)
	var landed := 0
	for i in count:
		var angle = rng.randf() * TAU
		var dist = sqrt(rng.randf()) * cluster_radius
		var offset = Vector3(cos(angle), 0.0, sin(angle)) * dist
		var ground = _sample_ground(terrain, center + offset)
		if ground == null:
			continue
		if _too_close(ground, spatial_grid):
			continue
		_record_position(ground, spatial_grid)
		_add_point(variant, ground, rng)
		landed += 1
	return landed

func _add_point(variant: int, ground: Vector3, rng: RandomNumberGenerator) -> void:
	var xform := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(_variant_scale[variant]), ground)
	_points.append({
		"transform": xform,
		"variant": variant,
		"hp": _variant_hp[variant],
		"felled": false,
		"regrow_at": -1.0,
	})
	_record_claim_grid(_points.size() - 1, ground)

## Instantiates each weighted scene exactly once, up front, purely to pull
## its mesh, collision shape(s), and root scale out -- every placed point
## after this reuses these shared resources instead of ever instantiating
## scenes[i].scene again, which is what let generation scale from hundreds
## to thousands of points (see class doc comment).
func _build_variant_assets() -> void:
	for entry in scenes:
		if entry == null or entry.scene == null:
			_variant_meshes.append(null)
			_variant_shapes.append([])
			_variant_shape_xforms.append([])
			_variant_scale.append(Vector3.ONE)
			_variant_hp.append(hp)
			_variant_drops_min.append(drops_min)
			_variant_drops_max.append(drops_max)
			continue
		var template = entry.scene.instantiate()
		var mesh_instance := _find_mesh_instance(template)
		var shapes := _find_all_collision_shapes(template)
		_variant_meshes.append(mesh_instance.mesh if mesh_instance else null)
		var shape_list: Array = []
		var xform_list: Array = []
		for cs in shapes:
			shape_list.append(cs.shape)
			xform_list.append(cs.transform)
		_variant_shapes.append(shape_list)
		_variant_shape_xforms.append(xform_list)
		_variant_scale.append(template.transform.basis.get_scale() if template is Node3D else Vector3.ONE)
		_variant_hp.append(entry.hp_override if entry.hp_override >= 0 else hp)
		_variant_drops_min.append(entry.drops_min_override if entry.drops_min_override >= 0 else drops_min)
		_variant_drops_max.append(entry.drops_max_override if entry.drops_max_override >= 0 else drops_max)
		template.free()

func _build_multimeshes() -> int:
	if _points.is_empty():
		return 0
	_point_chunk.resize(_points.size())

	# Bucket by (chunk, variant) -- one MultiMesh can only hold a single
	# mesh, so each distinct tree type needs its own buffer per chunk.
	var buckets: Dictionary = {}  # chunk_cell -> {variant -> Array[point_index]}
	for i in _points.size():
		var point = _points[i]
		var cell := _chunk_cell(point["transform"].origin)
		if not buckets.has(cell):
			buckets[cell] = {}
		var by_variant: Dictionary = buckets[cell]
		if not by_variant.has(point["variant"]):
			by_variant[point["variant"]] = []
		by_variant[point["variant"]].append(i)

	for cell in buckets:
		var by_variant: Dictionary = buckets[cell]
		var chunk_meshes: Dictionary = {}
		var chunk_centers: Dictionary = {}
		for variant in by_variant:
			var mesh: Mesh = _variant_meshes[variant]
			if mesh == null:
				continue
			var indices: Array = by_variant[variant]
			# See grass_field.gd's _build_multimeshes() for why this exists:
			# Godot's visibility_range hard cutoff measures from the camera
			# to the NODE'S OWN ORIGIN, not its content (godotengine/godot#
			# 79471) -- a shared global_transform = IDENTITY across every
			# chunk put that origin at world (0,0,0) for all of them, so the
			# cutoff was really keyed to distance from world origin, not
			# from each chunk's actual trees.
			var centroid := Vector3.ZERO
			for point_index in indices:
				centroid += _points[point_index]["transform"].origin
			centroid /= indices.size()

			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh
			mm.instance_count = indices.size()
			for local_i in indices.size():
				var point_index: int = indices[local_i]
				mm.set_instance_transform(local_i, _relative_transform(_points[point_index]["transform"], centroid))
				_point_chunk[point_index] = [cell, variant, local_i]

			var mm_instance := MultiMeshInstance3D.new()
			mm_instance.name = "TreeMultiMesh_%d_%d_v%d" % [cell.x, cell.y, variant]
			mm_instance.multimesh = mm
			mm_instance.visibility_range_end = visibility_range
			mm_instance.visibility_range_end_margin = fade_margin
			mm_instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			add_child(mm_instance)
			# top_level so this node's own transform (the variant's own
			# centroid within this chunk) is authoritative -- per-instance
			# transforms are then relative to THIS, matching _relative_transform().
			mm_instance.top_level = true
			mm_instance.global_transform = Transform3D(Basis(), centroid)

			chunk_meshes[variant] = mm
			chunk_centers[variant] = centroid
		_chunks[cell] = chunk_meshes
		_chunk_centers[cell] = chunk_centers

	return buckets.size()

## Same idea as grass_field.gd's own _set_multimesh_visible() -- a hidden
## instance is one written with a zero-scale transform, since MultiMesh has
## no real per-instance visibility flag.
func _set_multimesh_visible(point_index: int, is_visible: bool) -> void:
	var info = _point_chunk[point_index]
	var mm: MultiMesh = _chunks[info[0]][info[1]]
	var local_i: int = info[2]
	if is_visible:
		var centroid: Vector3 = _chunk_centers[info[0]][info[1]]
		mm.set_instance_transform(local_i, _relative_transform(_points[point_index]["transform"], centroid))
	else:
		mm.set_instance_transform(local_i, _hidden_transform)

## Per-instance MultiMesh transforms are relative to the chunk/variant's own
## MultiMeshInstance3D (its origin sits at that variant's own centroid
## within the chunk, see _build_multimeshes()), not raw world space --
## _points stores world-space transforms, so this subtracts the centroid
## back out. Basis (rotation/scale) is unaffected, only the translation is
## centroid-relative.
func _relative_transform(world_transform: Transform3D, chunk_center: Vector3) -> Transform3D:
	return Transform3D(world_transform.basis, world_transform.origin - chunk_center)

const TreeProxyScript = preload("res://world/nodes/trees/tree_proxy.gd")
const MAX_SHAPES_PER_PROXY := 2

func _build_pool() -> void:
	for i in pool_size:
		# Untyped on purpose: set_script() below attaches tree_proxy.gd's
		# properties (field, point_index, bind/release) at runtime, which a
		# `:= StaticBody3D.new()` static type wouldn't know about and would
		# fail to compile against.
		var proxy = StaticBody3D.new()
		proxy.set_script(TreeProxyScript)
		proxy.field = self
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "MeshInstance3D"
		proxy.add_child(mesh_instance)
		for s in MAX_SHAPES_PER_PROXY:
			var shape := CollisionShape3D.new()
			shape.name = "CollisionShape3D_%d" % s
			shape.disabled = true
			proxy.add_child(shape)
		add_child(proxy)
		_pool.append(proxy)
		_free_pool_indices.append(i)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_update_regrowth()
	_claim_timer += delta
	if _claim_timer < CHECK_INTERVAL:
		return
	_claim_timer = 0.0
	_update_claims()

## Same shape as grass_field.gd's own _update_regrowth() -- runs on an
## absolute timestamp independent of claim state, restoring the multimesh
## copy once a felled tree's respawn_time has elapsed.
func _update_regrowth() -> void:
	if _regrowing_indices.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	var done: Array = []
	for point_index in _regrowing_indices:
		var point = _points[point_index]
		if now >= point["regrow_at"]:
			point["felled"] = false
			point["hp"] = _variant_hp[point["variant"]]
			point["regrow_at"] = -1.0
			_set_multimesh_visible(point_index, true)
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
		if dist > deactivate_radius:
			to_release.append(point_index)
	for i in mini(to_release.size(), MAX_DEACTIVATIONS_PER_TICK):
		_release_point(to_release[i])

	if _free_pool_indices.is_empty():
		return

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
				if _points[point_index]["felled"]:
					continue
				var dist: float = _points[point_index]["transform"].origin.distance_to(player_pos)
				if dist <= activate_radius:
					candidates.append([dist, point_index])
	candidates.sort_custom(func(a, b): return a[0] < b[0])

	var claimed_this_tick := 0
	for entry in candidates:
		if _free_pool_indices.is_empty() or claimed_this_tick >= MAX_ACTIVATIONS_PER_TICK:
			break
		_claim_point(entry[1])
		claimed_this_tick += 1

func _claim_point(point_index: int) -> void:
	var pool_index = _free_pool_indices.pop_back()
	_claims[point_index] = pool_index
	var point = _points[point_index]
	var variant: int = point["variant"]
	_pool[pool_index].bind(point_index, point["transform"], _variant_meshes[variant], _variant_shapes[variant], _variant_shape_xforms[variant])
	_set_multimesh_visible(point_index, false)

func _release_point(point_index: int) -> void:
	var pool_index = _claims[point_index]
	_claims.erase(point_index)
	_free_pool_indices.append(pool_index)
	_pool[pool_index].release()
	# Only restore multimesh visibility if it's not sitting mid-respawn --
	# _update_regrowth() is what restores it once that actually finishes.
	if not _points[point_index]["felled"]:
		_set_multimesh_visible(point_index, true)

## Called by a pooled TreeProxy (world/nodes/trees/tree_proxy.gd) when the
## player interacts with it -- same damage/drop math as tree_node.gd's own
## interact(), just centralized here since a single tree point has no
## script of its own to hold that logic (the proxy is shared across every
## variant).
func interact_point(point_index: int) -> void:
	var point = _points[point_index]
	var equipper = get_tree().get_first_node_in_group("tool_equipper")
	if equipper == null:
		return
	var inventory = get_tree().get_first_node_in_group("player_inventory_data")
	if inventory == null:
		return
	var perks = get_tree().get_first_node_in_group("player_gathering_perks")

	var damage = 1
	if equipper.current_item_id != "":
		var def = ItemDB.get_item(equipper.current_item_id)
		if def and def.mining_damage > 0:
			if def.tool_category == required_tool_category:
				damage = def.mining_damage
			else:
				damage = max(1, int(def.mining_damage * wrong_tool_percent))
	damage = GatherBonuses.apply_damage(damage, inventory, equipper, perks)

	point["hp"] -= damage
	if equipper.current_slot_index >= 0 and not GatherBonuses.should_spare_durability(inventory, equipper, perks):
		inventory.damage_hotbar_tool(equipper.current_slot_index)
	_update_hp_bar(point["hp"], _variant_hp[point["variant"]])

	if point["hp"] > 0:
		return

	var variant: int = point["variant"]
	var amount = GatherBonuses.apply_yield(randi_range(_variant_drops_min[variant], _variant_drops_max[variant]), inventory, equipper, perks)
	inventory.add_item(wood_type, amount)
	GatherBonuses.grant_gather_xp(wood_type, amount)
	GatherBonuses.roll_and_grant_crystal(inventory, perks)
	_notify_felled(point_index)

func _notify_felled(point_index: int) -> void:
	var point = _points[point_index]
	point["felled"] = true
	point["regrow_at"] = Time.get_ticks_msec() / 1000.0 + respawn_time
	_regrowing_indices.append(point_index)
	_set_multimesh_visible(point_index, false)
	if _claims.has(point_index):
		_release_point(point_index)

func _update_hp_bar(current_hp: int, max_hp: int) -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud == null:
		return
	var def = ItemDB.get_item(wood_type)
	hud.show_node_hp(def.name if def else wood_type.capitalize(), current_hp, max_hp)

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found = _find_mesh_instance(child)
		if found:
			return found
	return null

func _find_all_collision_shapes(node: Node) -> Array:
	var result: Array = []
	if node is CollisionShape3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_all_collision_shapes(child))
	return result

## Weighted random pick from scenes -- same normalization as NodePainter's
## own _pick_scene(), returning an index into scenes/_variant_meshes/
## _variant_shapes instead of instantiating anything.
func _pick_variant(rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for entry in scenes:
		if entry and entry.scene:
			total += max(0.0, entry.weight)
	if total <= 0.0:
		return -1
	var roll = rng.randf() * total
	var acc := 0.0
	for i in scenes.size():
		var entry = scenes[i]
		if entry == null or entry.scene == null:
			continue
		acc += max(0.0, entry.weight)
		if roll < acc:
			return i
	return -1

func _has_scenes() -> bool:
	for entry in scenes:
		if entry and entry.scene:
			return true
	push_warning("TreeField: add at least one entry to scenes before generating.")
	return false

func _chunk_cell(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / chunk_size), floori(pos.z / chunk_size))

func _claim_grid_cell(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / activate_radius), floori(pos.z / activate_radius))

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
