extends Node3D

@export var ore_type: String = "stone"
@export var drops_min: int = 2
@export var drops_max: int = 4
## HP shared across all stages; resets each time a stage advances
@export var stage_hp: int = 10
## Percentage of tool damage dealt when using the wrong tool (0.0 - 1.0)
@export_range(0.0, 1.0, 0.01) var wrong_tool_percent: float = 0.1
## Tool category required for full damage (e.g. "pickaxe")
@export var required_tool_category: String = "pickaxe"
## Scenes for each stage, index 0 = largest/full, last = nearly depleted
@export var stage_scenes: Array[PackedScene] = []
## Seconds before the node respawns after being fully mined
@export var respawn_time: float = 20.0
## See tree_node.gd's own visibility_range for the full reasoning -- same
## fix, same default, applied here too.
@export var visibility_range: float = 100.0
## Same idea as grass_field.gd's own fade_margin -- fades out smoothly over
## the last fade_margin meters instead of popping instantly.
@export var fade_margin: float = 8.0

@onready var _visual: Node3D = $Visual
@onready var _physics_body: StaticBody3D = $PhysicsBody
@onready var _collision: CollisionShape3D = $PhysicsBody/CollisionShape3D

var _stage: int = 0
var _hp: int = 0

## Every body that should exist only while a player is nearby: this node's
## own PhysicsBody plus any decorative walk-block StaticBody3D nested
## inside whatever mesh got instantiated under _visual (e.g. the farm rock
## overlays' own inner collision). Each entry remembers its real parent so
## it can be re-added correctly, since it stops showing up via a tree walk
## the moment it's removed. Refreshed on every stage change since _visual's
## content is replaced then.
var _stream_bodies: Array = []
var _physics_active: bool = true

func _ready() -> void:
	add_to_group("interactable")
	_hp = stage_hp
	_apply_stage()
	ResourceStreamer.register(self)

func _apply_stage() -> void:
	for child in _visual.get_children():
		child.queue_free()
	if _stage < stage_scenes.size() and stage_scenes[_stage] != null:
		var mesh = stage_scenes[_stage].instantiate()
		_visual.add_child(mesh)
		_fit_collision_to_visual()
		_apply_visibility_range()
	_refresh_stream_bodies()

func _apply_visibility_range() -> void:
	for inst in _find_mesh_instances(_visual):
		if inst is GeometryInstance3D:
			inst.visibility_range_end = visibility_range
			inst.visibility_range_end_margin = fade_margin
			inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF

func _refresh_stream_bodies() -> void:
	_stream_bodies = [{"body": _physics_body, "parent": self}]
	for body in _find_static_bodies(_visual):
		_stream_bodies.append({"body": body, "parent": body.get_parent()})

func _find_static_bodies(node: Node) -> Array:
	var result: Array = []
	for child in node.get_children():
		if child is StaticBody3D:
			result.append(child)
		result.append_array(_find_static_bodies(child))
	return result

## Called by ResourceStreamer (scripts/resource_streamer.gd) roughly every
## 0.4s based on distance to the player. Removing a body from the scene
## tree is what actually unregisters it from Jolt -- disabling its
## CollisionShape3D does not, the body stays registered with zero active
## shapes and still counts toward jolt_physics_3d/limits/max_bodies, which
## was the whole point of this (see the "too many bodies" crash from
## scattering thousands of these across the map).
func update_streaming(should_be_active: bool) -> void:
	if should_be_active == _physics_active:
		return
	_physics_active = should_be_active
	for entry in _stream_bodies:
		var body = entry["body"]
		if not is_instance_valid(body):
			continue
		if should_be_active:
			if body.get_parent() == null and is_instance_valid(entry["parent"]):
				entry["parent"].add_child(body)
		elif body.get_parent() != null:
			body.get_parent().remove_child(body)

## Different stage meshes (esp. the MiningPack ore stages, which visually
## shrink as HP drops) don't share a bounding box, so a collision shape sized
## for stage 0 stops lining up with what the player is actually looking at
## by stage 1+ -- this was the "hit it once then can't hit it again" bug.
## Refit to whatever mesh is currently visible instead of trusting a static
## shape across every stage. This shape is purely physical now (targeting
## is proximity-based, see interaction_manager.gd's _find_best_interactable),
## so it only needs to match what the player can see and walk into.
func _fit_collision_to_visual() -> void:
	var instances := _find_mesh_instances(_visual)
	if instances.is_empty():
		return
	var combined: AABB
	var first := true
	for inst in instances:
		var to_self: Transform3D = global_transform.affine_inverse() * inst.global_transform
		var world_aabb: AABB = to_self * inst.get_aabb()
		if first:
			combined = world_aabb
			first = false
		else:
			combined = combined.merge(world_aabb)
	if first:
		return

	combined = combined.grow(0.05)
	var box := BoxShape3D.new()
	box.size = combined.size
	_collision.shape = box
	_collision.transform = Transform3D(Basis(), combined.get_center())

func _find_mesh_instances(node: Node) -> Array:
	var result: Array = []
	if node is VisualInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_mesh_instances(child))
	return result

func get_click_hint(_inv) -> String:
	return "Mine (%s)" % required_tool_category.capitalize()

func interact() -> void:
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

	_hp -= damage
	if equipper.current_slot_index >= 0 and not GatherBonuses.should_spare_durability(inventory, equipper, perks):
		inventory.damage_hotbar_tool(equipper.current_slot_index)
	_update_hp_bar()

	if _hp > 0:
		return

	var amount = GatherBonuses.apply_yield(randi_range(drops_min, drops_max), inventory, equipper, perks)
	inventory.add_item(ore_type, amount)
	GatherBonuses.grant_gather_xp(ore_type, amount)
	GatherBonuses.roll_and_grant_crystal(inventory, perks)
	_stage += 1
	if _stage >= stage_scenes.size():
		_despawn()
	else:
		_hp = stage_hp
		_apply_stage()

func _despawn() -> void:
	_visual.visible = false
	_collision.disabled = true
	remove_from_group("interactable")
	await get_tree().create_timer(respawn_time).timeout
	_respawn()

func _respawn() -> void:
	_stage = 0
	_hp = stage_hp
	_visual.visible = true
	_collision.disabled = false
	add_to_group("interactable")
	_apply_stage()

func _update_hp_bar() -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud == null:
		return
	var def = ItemDB.get_item(ore_type)
	hud.show_node_hp(def.name if def else ore_type.capitalize(), _hp, stage_hp)
