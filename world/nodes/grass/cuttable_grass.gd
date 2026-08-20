class_name CuttableGrass
extends Area3D

## Pooled, reusable interactive proxy for GrassField (world/nodes/grass/
## grass_field.gd) -- NOT one instance per grass point. GrassField owns all
## the real point data (position, cut state, regrow timing) for
## potentially thousands of points and renders them all via a single
## MultiMeshInstance3D; it repositions a small fixed pool of these onto
## whatever's within melee range of the player. This script just forwards
## interaction (cut()) back to whichever point it's currently bound to,
## and shows/hides its own visual + collision accordingly. Detected by the
## player's raycast via collide_with_areas, same as before.

@export var mesh_node_name: String = "Grass_Patch_1A"
@export var yield_item_id: String = ""
@export var yield_amount: int = 1
@export var regrow_time: float = 30.0

var field: GrassField = null
var point_index: int = -1

## The mesh+collision move together as this "Grass" wrapper's transform --
## cached once since get_parent() is still valid however this node's own
## tree membership is handled.
@onready var _parent_node: Node3D = get_parent()
@onready var _mesh: Node3D = _parent_node.get_node_or_null(mesh_node_name)
@onready var _collision: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	add_to_group("cuttable_grass")

## Called by GrassField when this pool slot is assigned to point_index.
func bind(index: int, xform: Transform3D) -> void:
	point_index = index
	_parent_node.global_transform = xform
	show_uncut()

## Called by GrassField when this pool slot is freed back up (point walked
## out of range, or was permanently removed). Doesn't free the node --
## pool members are reused, not destroyed/recreated.
func release() -> void:
	point_index = -1
	if _mesh:
		_mesh.visible = false
	if _collision:
		_collision.disabled = true

func show_uncut() -> void:
	if _mesh:
		_mesh.visible = true
	if _collision:
		_collision.disabled = false

func show_cut() -> void:
	if _mesh:
		_mesh.visible = false
	if _collision:
		_collision.set_deferred("disabled", true)

func cut() -> void:
	if point_index < 0:
		return
	if yield_item_id != "":
		var inventory = get_tree().get_first_node_in_group("player_inventory_data")
		if inventory:
			inventory.add_item(yield_item_id, yield_amount)
	show_cut()
	if field:
		field.notify_cut(point_index, regrow_time)
