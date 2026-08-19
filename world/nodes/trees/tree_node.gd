extends Node3D

@export var wood_type: String = "wood"
@export var drops_min: int = 2
@export var drops_max: int = 4
@export var tree_hp: int = 30
## Percentage of tool damage dealt when using the wrong tool (0.0 - 1.0)
@export_range(0.0, 1.0, 0.01) var wrong_tool_percent: float = 0.1
## Tool category required for full damage (e.g. "axe")
@export var required_tool_category: String = "axe"
## Seconds before the tree respawns after being chopped down
@export var respawn_time: float = 30.0
## The tree's visual scene, instantiated fresh under Visual (same pattern as
## mining_node.gd's stage_scenes, just a single entry).
@export var tree_scene: PackedScene

@onready var _visual: Node3D = $Visual
@onready var _physics_body: StaticBody3D = $PhysicsBody
@onready var _collision: CollisionShape3D = $PhysicsBody/CollisionShape3D

var _hp: int = 0

## See mining_node.gd for the full explanation -- this node's own
## PhysicsBody plus any decorative collision nested inside whatever mesh
## got instantiated under _visual (tree.tscn's own trunk StaticBody3D is
## exactly this: it's what actually blew through the Jolt body limit).
var _stream_bodies: Array = []
var _physics_active: bool = true

func _ready() -> void:
	add_to_group("interactable")
	_hp = tree_hp
	_apply_tree()
	ResourceStreamer.register(self)

func _apply_tree() -> void:
	for child in _visual.get_children():
		child.queue_free()
	if tree_scene != null:
		var mesh = tree_scene.instantiate()
		_visual.add_child(mesh)
		_fit_collision_to_visual()
	_refresh_stream_bodies()

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

## Called by ResourceStreamer (scripts/resource_streamer.gd) -- see
## mining_node.gd's version for why removal from the tree (not just
## disabling the shape) is what actually matters here.
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

## Max hitbox footprint (X/Z) for a tree, regardless of how wide the canopy
## mesh is -- trees are one combined trunk+canopy mesh with no separate
## trunk node to target, so instead of hugging the whole crown (which made
## chopping trivially easy from any angle and got in the way of movement),
## clamp the width/depth down to trunk-sized and keep it centered on the
## mesh's own AABB center, which sits on the trunk axis.
const TRUNK_HITBOX_WIDTH: float = 1.1

## See mining_node.gd's _fit_collision_to_visual for why: a static collision
## shape can drift out of alignment with whatever mesh is actually showing.
## Purely physical now (targeting is proximity-based -- see
## interaction_manager.gd's _find_best_interactable), so a small margin is
## enough; it no longer needs to be generous for aim reliability.
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
	var center := combined.get_center()
	var size := combined.size
	size.x = minf(size.x, TRUNK_HITBOX_WIDTH)
	size.z = minf(size.z, TRUNK_HITBOX_WIDTH)
	var box := BoxShape3D.new()
	box.size = size
	_collision.shape = box
	_collision.transform = Transform3D(Basis(), center)

func _find_mesh_instances(node: Node) -> Array:
	var result: Array = []
	if node is VisualInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_mesh_instances(child))
	return result

func get_click_hint(_inv) -> String:
	return "Chop (%s)" % required_tool_category.capitalize()

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
	inventory.add_item(wood_type, amount)
	GatherBonuses.grant_gather_xp(wood_type, amount)
	GatherBonuses.roll_and_grant_crystal(inventory, perks)
	_despawn()

func _despawn() -> void:
	for child in _visual.get_children():
		child.queue_free()
	_collision.disabled = true
	remove_from_group("interactable")
	await get_tree().create_timer(respawn_time).timeout
	_respawn()

func _respawn() -> void:
	_hp = tree_hp
	_collision.disabled = false
	add_to_group("interactable")
	_apply_tree()

func _update_hp_bar() -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud == null:
		return
	var def = ItemDB.get_item(wood_type)
	hud.show_node_hp(def.name if def else wood_type.capitalize(), _hp, tree_hp)
