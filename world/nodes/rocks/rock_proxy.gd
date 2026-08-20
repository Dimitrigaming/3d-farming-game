extends StaticBody3D

## Pooled, reusable interactive proxy for RockField (world/nodes/rocks/
## rock_field.gd) -- NOT one instance per rock. RockField owns all the real
## point data (transform, variant, hp, mined state) for potentially tens of
## thousands of points and renders them all via chunked MultiMeshes; it
## repositions a small fixed pool of these onto whatever's near the player,
## same pattern as GrassField's CuttableGrass pool. Uses the standard
## "interactable" group + interact()/get_click_hint() that mining_node.gd
## and tree_node.gd already use (proximity-based targeting, not a raycast/
## Area3D setup like the older CuttableGrass) since a mineable rock is the
## same kind of thing as an ore node, not grass.
##
## Built entirely in code by RockField._build_pool() (MeshInstance3D +
## CollisionShape3D children, no authored scene) since which mesh/shape this
## slot shows swaps every time it's bound to a different rock variant.

var field: RockField = null
var point_index: int = -1

@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _collision: CollisionShape3D = $CollisionShape3D

## Called by RockField when this pool slot is assigned to point_index.
func bind(idx: int, xform: Transform3D, mesh: Mesh, shape: Shape3D, shape_xform: Transform3D) -> void:
	point_index = idx
	global_transform = xform
	_mesh.mesh = mesh
	_collision.shape = shape
	_collision.transform = shape_xform
	_collision.disabled = shape == null
	if not is_in_group("interactable"):
		add_to_group("interactable")

## Called by RockField when this pool slot is freed back up (point walked
## out of range, or was just mined). Doesn't free the node -- pool members
## are reused, not destroyed/recreated.
func release() -> void:
	point_index = -1
	_mesh.mesh = null
	_collision.disabled = true
	remove_from_group("interactable")

func get_click_hint(_inv) -> String:
	return "Mine (%s)" % field.required_tool_category.capitalize()

func interact() -> void:
	if point_index >= 0 and field:
		field.interact_point(point_index)
