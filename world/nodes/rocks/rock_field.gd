@tool
class_name RockField
extends CSGBox3D

## Same problem/fix as world/nodes/grass/grass_field.gd, applied to mineable
## rock scatter: NodePainter (or a real MiningNode per rock) instantiating
## one real scene per point is fine in the hundreds but tanks FPS in the
## thousands, and NodePainter's _too_close() is an O(N^2) scan that also
## makes generation itself slow at that count.
##
## Same fix as grass: a small fixed pool of real, interactive proxies
## (rock_proxy.gd) gets repositioned onto whichever points are currently
## near the player and handles mining (HP/damage/drops/respawn) exactly
## like mining_node.gd does, while every other point is pure chunked-
## MultiMesh rendering with zero per-instance node cost. Points also carry
## HP/mined/respawn state now (not just transform+variant), and their
## MultiMesh copy gets hidden while claimed or mined, same as GrassField's
## cut points -- see _set_multimesh_visible().

@export var scenes: Array[WeightedScene] = []
@export var min_spacing: float = 2.0

@export_group("Area Fill")
@export var fill_attempts: int = 200
@export var noise_scale: float = 0.08
@export_range(-1.0, 1.0, 0.01) var density_threshold: float = 0.0
@export var noise_seed: int = 0
@export var placement_seed: int = 0
## Square keep-out zone centered on WORLD origin -- see NodePainter's own
## avoid_center_square for the full reasoning (same idea, ported as-is).
@export var avoid_center_square: float = 0.0

@export_group("Clustering")
## Chance, per successfully placed point, that it also spawns a tight
## cluster of extras right around it -- on top of the general scatter
## above, not instead of it. Same behavior as NodePainter's own clustering.
@export_range(0.0, 1.0, 0.01) var cluster_chance: float = 0.0
@export var cluster_size_min: int = 2
@export var cluster_size_max: int = 5
@export var cluster_radius: float = 3.0

@export_group("Rendering")
## See grass_field.gd's own chunk_size export for the full reasoning
## (independent per-chunk AABB culling instead of one field-wide multimesh).
@export var chunk_size: float = 40.0
## Same idea as tree_node.gd's own visibility_range -- past this many
## meters from the camera, a chunk's rocks just aren't drawn. Applied
## directly to each chunk's MultiMeshInstance3D (GeometryInstance3D.
## visibility_range_end), so it's a renderer-level cutoff, not a per-frame
## script check.
@export var visibility_range: float = 100.0

@export_group("Mining")
## Same fields/behavior as mining_node.gd's own interact(), applied
## uniformly to every rock in this field -- except hp, which a variant can
## override individually (see WeightedScene.hp_override) since a boulder
## and a pebble in the same field shouldn't take the same number of hits.
@export var ore_type: String = "stone"
@export var drops_min: int = 1
@export var drops_max: int = 3
## Default HP for any variant that doesn't set its own hp_override.
@export var hp: int = 10
@export_range(0.0, 1.0, 0.01) var wrong_tool_percent: float = 0.1
@export var required_tool_category: String = "pickaxe"
@export var respawn_time: float = 20.0

@export_group("Interactive Pool")
## How many real, interactive proxies exist at once -- repositioned onto
## whatever's nearest the player, not one per rock. Stays small no matter
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

## One entry per rock point: {transform, variant, hp, mined, regrow_at} --
## variant indexes both _variant_meshes and _variant_shapes below.
var _points: Array = []
var _hidden_transform := Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO)

## Index-aligned with `scenes`, extracted once from each variant's own
## template scene instead of instantiating a real copy per placed point.
var _variant_meshes: Array = []
var _variant_shapes: Array = []
var _variant_shape_xforms: Array = []
## Resolved per-variant max HP -- scenes[i].hp_override if set, else the
## field's own `hp` default. A boulder and a pebble in the same field don't
## need the same number of hits.
var _variant_hp: Array = []
## Same idea as _variant_hp, for drops_min/drops_max -- a boulder should
## also yield more stone than a pebble.
var _variant_drops_min: Array = []
var _variant_drops_max: Array = []

## chunk_cell (Vector2i) -> that chunk's {variant -> MultiMesh}. Needed now
## (unlike a purely decorative field) since a mined rock's MultiMesh copy
## has to hide, same reason as grass_field.gd's own _chunks/_point_chunk.
var _chunks: Dictionary = {}
## point_index -> [chunk_cell, variant, local_index_within_that_chunk's_
## multimesh]. Lets _set_multimesh_visible() go straight to the right slot.
var _point_chunk: Array = []

## Point indices bucketed by an activate_radius-sized grid cell -- same
## reasoning as grass_field.gd's _claim_grid, so the proximity check below
## only ever scans points actually near the player instead of the whole
## field every tick.
var _claim_grid: Dictionary = {}

var _pool: Array = []  # RockProxy, fixed size, reused
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
	_variant_hp.clear()
	_variant_drops_min.clear()
	_variant_drops_max.clear()
	_chunks.clear()
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
			# weighted pick per member -- reads as one cluster of a single
			# rock type, not a mixed grab-bag.
			var extra = _spawn_cluster(variant, ground, rng, terrain, spatial_grid)
			if extra > 0:
				clusters += 1
				placed += extra

	var chunk_count := _build_multimeshes()
	_build_pool()
	print("RockField: generated %d rock points (%d clusters, %d chunks, pool=%d) using %s" % [_points.size(), clusters, chunk_count, pool_size, ("Terrain3D height data" if terrain else "physics raycast fallback")])

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
	var xform := Transform3D(Basis(Vector3.UP, rng.randf() * TAU), ground)
	_points.append({
		"transform": xform,
		"variant": variant,
		"hp": _variant_hp[variant],
		"mined": false,
		"regrow_at": -1.0,
	})
	_record_claim_grid(_points.size() - 1, ground)

## Instantiates each weighted scene exactly once, up front, purely to pull
## its mesh and collision shape out -- every placed point after this reuses
## these shared resources instead of ever instantiating scenes[i].scene
## again, which is what let generation scale from hundreds to thousands of
## points (see class doc comment).
func _build_variant_assets() -> void:
	for entry in scenes:
		if entry == null or entry.scene == null:
			_variant_meshes.append(null)
			_variant_shapes.append(null)
			_variant_shape_xforms.append(Transform3D.IDENTITY)
			_variant_hp.append(hp)
			_variant_drops_min.append(drops_min)
			_variant_drops_max.append(drops_max)
			continue
		var template = entry.scene.instantiate()
		var mesh_instance := _find_mesh_instance(template)
		var collision_shape := _find_collision_shape(template)
		_variant_meshes.append(mesh_instance.mesh if mesh_instance else null)
		_variant_shapes.append(collision_shape.shape if collision_shape else null)
		_variant_shape_xforms.append(collision_shape.transform if collision_shape else Transform3D.IDENTITY)
		_variant_hp.append(entry.hp_override if entry.hp_override >= 0 else hp)
		_variant_drops_min.append(entry.drops_min_override if entry.drops_min_override >= 0 else drops_min)
		_variant_drops_max.append(entry.drops_max_override if entry.drops_max_override >= 0 else drops_max)
		template.free()

func _build_multimeshes() -> int:
	if _points.is_empty():
		return 0
	_point_chunk.resize(_points.size())

	# Bucket by (chunk, variant) -- one MultiMesh can only hold a single
	# mesh, so each distinct rock type needs its own buffer per chunk.
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
		for variant in by_variant:
			var mesh: Mesh = _variant_meshes[variant]
			if mesh == null:
				continue
			var indices: Array = by_variant[variant]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh
			mm.instance_count = indices.size()
			for local_i in indices.size():
				var point_index: int = indices[local_i]
				mm.set_instance_transform(local_i, _points[point_index]["transform"])
				_point_chunk[point_index] = [cell, variant, local_i]

			var mm_instance := MultiMeshInstance3D.new()
			mm_instance.name = "RockMultiMesh_%d_%d_v%d" % [cell.x, cell.y, variant]
			mm_instance.multimesh = mm
			mm_instance.visibility_range_end = visibility_range
			add_child(mm_instance)
			# Same reasoning as grass_field.gd's _build_multimeshes(): per-
			# instance transforms are relative to this node's own transform,
			# not world space, but _points stores world-space transforms.
			mm_instance.top_level = true
			mm_instance.global_transform = Transform3D.IDENTITY

			chunk_meshes[variant] = mm
		_chunks[cell] = chunk_meshes

	return buckets.size()

## Same idea as grass_field.gd's own _set_multimesh_visible() -- a hidden
## instance is one written with a zero-scale transform, since MultiMesh has
## no real per-instance visibility flag.
func _set_multimesh_visible(point_index: int, is_visible: bool) -> void:
	var info = _point_chunk[point_index]
	var mm: MultiMesh = _chunks[info[0]][info[1]]
	var local_i: int = info[2]
	if is_visible:
		mm.set_instance_transform(local_i, _points[point_index]["transform"])
	else:
		mm.set_instance_transform(local_i, _hidden_transform)

const RockProxyScript = preload("res://world/nodes/rocks/rock_proxy.gd")

func _build_pool() -> void:
	for i in pool_size:
		# Untyped on purpose: set_script() below attaches rock_proxy.gd's
		# properties (field, point_index, bind/release) at runtime, which a
		# `:= StaticBody3D.new()` static type wouldn't know about and would
		# fail to compile against.
		var proxy = StaticBody3D.new()
		proxy.set_script(RockProxyScript)
		proxy.field = self
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "MeshInstance3D"
		var shape := CollisionShape3D.new()
		shape.name = "CollisionShape3D"
		shape.disabled = true
		proxy.add_child(mesh_instance)
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
## copy (and, if a proxy is still bound there, the live proxy) once a mined
## rock's respawn_time has elapsed.
func _update_regrowth() -> void:
	if _regrowing_indices.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	var done: Array = []
	for point_index in _regrowing_indices:
		var point = _points[point_index]
		if now >= point["regrow_at"]:
			point["mined"] = false
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
				if _points[point_index]["mined"]:
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
	if not _points[point_index]["mined"]:
		_set_multimesh_visible(point_index, true)

## Called by a pooled RockProxy (world/nodes/rocks/rock_proxy.gd) when the
## player interacts with it -- same damage/drop math as mining_node.gd's own
## interact(), just centralized here since a single rock point has no script
## of its own to hold that logic (the proxy is shared across every variant).
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
	inventory.add_item(ore_type, amount)
	GatherBonuses.grant_gather_xp(ore_type, amount)
	GatherBonuses.roll_and_grant_crystal(inventory, perks)
	_notify_mined(point_index)

func _notify_mined(point_index: int) -> void:
	var point = _points[point_index]
	point["mined"] = true
	point["regrow_at"] = Time.get_ticks_msec() / 1000.0 + respawn_time
	_regrowing_indices.append(point_index)
	_set_multimesh_visible(point_index, false)
	if _claims.has(point_index):
		_release_point(point_index)

func _update_hp_bar(current_hp: int, max_hp: int) -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud == null:
		return
	var def = ItemDB.get_item(ore_type)
	hud.show_node_hp(def.name if def else ore_type.capitalize(), current_hp, max_hp)

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found = _find_mesh_instance(child)
		if found:
			return found
	return null

func _find_collision_shape(node: Node) -> CollisionShape3D:
	if node is CollisionShape3D:
		return node
	for child in node.get_children():
		var found = _find_collision_shape(child)
		if found:
			return found
	return null

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
	push_warning("RockField: add at least one entry to scenes before generating.")
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
