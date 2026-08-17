class_name CuttableGrass
extends Area3D

## Mirrors farm/fruit_pickable.gd's shape: an Area3D + CollisionShape3D
## sibling to the visual mesh, detected by the player's raycast via
## collide_with_areas. Cut with the scythe, regrows after regrow_time.

@export var mesh_node_name: String = "Grass_Patch_1A"
@export var yield_item_id: String = ""
@export var yield_amount: int = 1
@export var regrow_time: float = 30.0

var _regrowing: bool = false
var _timer: float = 0.0

func _ready() -> void:
	add_to_group("cuttable_grass")

func _process(delta: float) -> void:
	if not _regrowing:
		return
	_timer += delta
	if _timer >= regrow_time:
		_finish_regrow()

func cut() -> void:
	if _regrowing:
		return
	if yield_item_id != "":
		var inventory = get_tree().get_first_node_in_group("player_inventory_data")
		if inventory:
			inventory.add_item(yield_item_id, yield_amount)
	_start_regrow()

func _get_mesh() -> Node3D:
	return get_parent().get_node_or_null(mesh_node_name)

func _start_regrow() -> void:
	_regrowing = true
	_timer = 0.0
	var mesh = _get_mesh()
	if mesh:
		mesh.visible = false
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", true)

func _finish_regrow() -> void:
	_regrowing = false
	var mesh = _get_mesh()
	if mesh:
		mesh.visible = true
	for child in get_children():
		if child is CollisionShape3D:
			child.disabled = false
