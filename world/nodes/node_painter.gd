@tool
class_name NodePainter
extends CSGBox3D

## Scatters a weighted mix of scenes across this box's own footprint --
## resize the CSGBox3D itself to define the area, add entries to scenes,
## and it generates automatically:
##   - In the editor, _ready() generates a live preview as soon as this
##     node is in the tree (or press "Regenerate" after tweaking settings).
##   - At actual game runtime, _ready() generates the real spawn the same
##     way, fresh, from scratch.
## Nothing is ever baked into the .tscn (no owner= is set) -- generation
## uses a seeded RandomNumberGenerator, so the SAME noise_seed/
## placement_seed always produces the SAME layout, meaning what you see
## in the editor preview is exactly what spawns in-game. This replaces an
## earlier "bake it into the scene file" version that corrupted shared
## rendering resources once there were more than a handful of instances
## (confirmed: hand-placed instances of the same scenes never showed this
## corruption, only baked ones did) -- generating everything fresh at
## runtime sidesteps that category of bug entirely, the same fix already
## proven for farm/farm_expansion_area.gd's "node name clashes" bug.
## The box itself is an editor-only placement aid -- hidden and
## collision-free at runtime.

## Scenes to scatter, each with a relative weight (e.g. Stone=70, Copper=30
## reads the same as Stone=7, Copper=3 -- these get normalized against
## their total, not treated as a strict percentage that must sum to 100).
@export var scenes: Array[WeightedScene] = []
## Minimum distance kept between placed instances -- this is what stops
## anything from landing on top of another.
@export var min_spacing: float = 2.0

@export_group("Area Fill")
## Candidate points tried across this box's own footprint (its size.x x
## size.z, centered on the node) -- actual placed count will be lower once
## density/spacing rejects some of them.
@export var fill_attempts: int = 200
## FastNoiseLite frequency. Lower = broader clumps/clearings, higher =
## tighter, patchier variation.
@export var noise_scale: float = 0.08
## Candidate points are only placed where noise exceeds this (-1..1) --
## raise it to thin the scatter out into sparser clumps, lower it (toward
## -1) to fill in almost everywhere.
@export_range(-1.0, 1.0, 0.01) var density_threshold: float = 0.0
@export var noise_seed: int = 0
## Seeds which candidate points, scene picks, and rotations get chosen --
## keep this fixed for a reproducible layout, or change it to reroll.
@export var placement_seed: int = 0
## Square keep-out zone centered on WORLD origin (0,0), not this node's own
## position -- any candidate point inside it is skipped regardless of the
## box's own footprint. Lets a box be sized generously (even reaching past
## world center) to close gaps between adjacent boxes, while still never
## scattering onto a specific center area -- e.g. a flat/dirt farm core --
## that a plain rectangular box can't avoid without leaving a gap along
## its own edge (a rectangle can't hug a square hole in the middle of a
## shared border). 0 disables.
@export var avoid_center_square: float = 0.0

@export_group("Clustering")
## Chance, per successfully placed instance, that it also spawns a tight
## cluster of extras right around it -- on top of the general scatter
## above, not instead of it.
@export_range(0.0, 1.0, 0.01) var cluster_chance: float = 0.0
@export var cluster_size_min: int = 2
@export var cluster_size_max: int = 5
## How tightly cluster members gather around the point that spawned them.
@export var cluster_radius: float = 3.0

@warning_ignore("unused_private_class_variable")
@export_tool_button("Regenerate", "Reload") var _regen_btn = generate
@warning_ignore("unused_private_class_variable")
@export_tool_button("Clear", "Clear") var _clear_btn = clear_generated

func _ready() -> void:
	if Engine.is_editor_hint():
		generate()
		return
	# Capture the real footprint BEFORE zeroing size below -- generate()
	# reads this explicitly instead of the live size property, since by
	# the time the deferred call below actually runs, size has already
	# been zeroed out for rendering purposes (zeroing it first and then
	# letting generate() default to reading live size briefly produced a
	# 0x0 fill area, collapsing every candidate point onto the exact same
	# spot -- only the first one survived the min_spacing check).
	var area_size = size
	# NOT visible = false -- Node3D visibility is hierarchical, so hiding
	# this node would also hide every generated child underneath it (they
	# were being created fine, just invisible along with their invisible
	# parent). Zeroing the box's own size removes its geometry instead,
	# without touching visibility at all.
	size = Vector3.ZERO
	use_collision = false
	# Deferred, not called directly: Terrain3D may not have finished
	# initializing its height data yet at the exact moment sibling nodes'
	# _ready() calls fire during scene load. call_deferred runs after
	# every node's _ready() this frame has completed, by which point
	# Terrain3D should be fully ready -- matches how it behaves in the
	# editor, where you're always triggering generation well after
	# everything's already settled.
	call_deferred("generate", area_size)

func clear_generated() -> void:
	for child in get_children():
		child.free()

## Scatters the weighted scene mix across area_size.x x area_size.z
## (centered on the node) weighted by FastNoiseLite so placement reads as
## natural clumps and clearings instead of an evenly-sprayed grid. Height
## comes from Terrain3D's own heightmap data (terrain.data.get_height()),
## queried through the Terrain3D node's own transform in case it's nested
## under an offset parent. Falls back to a physics raycast if no
## Terrain3D node is found.
##
## area_size defaults to this box's own live size (editor preview / the
## "Regenerate" button); the runtime path in _ready() passes it explicitly
## since by the time its deferred call fires, size has already been
## zeroed out for rendering.
func generate(area_size: Vector3 = size) -> void:
	clear_generated()
	if not _has_scenes():
		return
	if not is_inside_tree():
		return

	var noise = FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = noise_scale
	var rng = RandomNumberGenerator.new()
	rng.seed = placement_seed
	var terrain = _find_terrain()
	var root = get_tree().edited_scene_root if Engine.is_editor_hint() else null

	var half_w = area_size.x / 2.0
	var half_d = area_size.z / 2.0
	var placed_positions: Array[Vector3] = []
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
		if _too_close(ground, placed_positions):
			continue

		var scene = _pick_scene(rng)
		if scene == null:
			continue
		_spawn_at(scene, ground, rng, root, placed_positions)
		placed += 1

		if rng.randf() < cluster_chance:
			# Same scene as the point that seeded the cluster, not a fresh
			# weighted pick per member -- reads as one ore vein of a single
			# type clumped together, not a mixed grab-bag.
			var extra = _spawn_cluster(scene, ground, rng, root, terrain, placed_positions)
			if extra > 0:
				clusters += 1
				placed += extra

	print("NodePainter: generated %d/%d (%d clusters) using %s, box center=%s size=%s" % [placed, fill_attempts, clusters, ("Terrain3D height data" if terrain else "physics raycast fallback"), global_transform.origin, area_size])

## Spawns cluster_size_min-max extra instances of `scene` (the same one
## the cluster's seed point already used) within cluster_radius of center,
## each individually height-sampled and spacing-checked same as the main
## scatter. Returns how many actually landed.
func _spawn_cluster(scene: PackedScene, center: Vector3, rng: RandomNumberGenerator, root: Node, terrain, placed_positions: Array[Vector3]) -> int:
	var count = rng.randi_range(cluster_size_min, cluster_size_max)
	var landed := 0
	for i in count:
		var angle = rng.randf() * TAU
		var dist = sqrt(rng.randf()) * cluster_radius
		var offset = Vector3(cos(angle), 0.0, sin(angle)) * dist
		var ground = _sample_ground(terrain, center + offset)
		if ground == null:
			continue
		if _too_close(ground, placed_positions):
			continue
		_spawn_at(scene, ground, rng, root, placed_positions)
		landed += 1
	return landed

## Instantiates `scene` at ground and records the position in
## placed_positions so later spacing checks (main scatter or cluster
## members) see it too.
func _spawn_at(scene: PackedScene, ground: Vector3, rng: RandomNumberGenerator, root: Node, placed_positions: Array[Vector3]) -> void:
	var inst = scene.instantiate()
	add_child(inst)
	if root:
		inst.owner = root
	if inst is Node3D:
		inst.global_position = ground
		inst.rotation.y = rng.randf() * TAU
	placed_positions.append(ground)

func _too_close(pos: Vector3, existing: Array[Vector3]) -> bool:
	for p in existing:
		if p.distance_to(pos) < min_spacing:
			return true
	return false

## Weighted random pick from scenes -- weights are relative, normalized
## against their total, so they don't need to add up to any particular
## number.
func _pick_scene(rng: RandomNumberGenerator) -> PackedScene:
	var total := 0.0
	for entry in scenes:
		if entry and entry.scene:
			total += max(0.0, entry.weight)
	if total <= 0.0:
		return null
	var roll = rng.randf() * total
	var acc := 0.0
	for entry in scenes:
		if entry == null or entry.scene == null:
			continue
		acc += max(0.0, entry.weight)
		if roll < acc:
			return entry.scene
	return null

func _has_scenes() -> bool:
	for entry in scenes:
		if entry and entry.scene:
			return true
	push_warning("NodePainter: add at least one entry to scenes before generating.")
	return false

## First Terrain3D node found in the edited scene, or null if there isn't
## one -- same lookup Terrain3D's own terrain_3d_objects.gd uses.
func _find_terrain() -> Node:
	var root = get_tree().edited_scene_root if Engine.is_editor_hint() else get_tree().root
	if root == null:
		return null
	var found: Array = root.find_children("", "Terrain3D", true, false)
	return found[0] if found.size() > 0 else null

## Vector3 world position on the ground below world_xz, or null if nothing
## was found there. Uses Terrain3D's heightmap directly when available;
## otherwise falls back to a straight-down physics raycast.
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
