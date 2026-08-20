extends StaticBody3D

## Pooled, reusable interactive proxy for TreeField (world/nodes/trees/
## tree_field.gd) -- same pattern as RockField's rock_proxy.gd, just chop
## instead of mine. A tree can carry up to MAX_SHAPES collision shapes (some
## tree prop meshes use two -- a trunk box plus a root/base box), so this
## proxy always has that many CollisionShape3D slots and disables whichever
## ones a given variant doesn't use.

const MAX_SHAPES := 2

var field: TreeField = null
var point_index: int = -1

@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _shapes: Array = [$CollisionShape3D_0, $CollisionShape3D_1]

## Called by TreeField when this pool slot is assigned to point_index.
## shapes/shape_xforms are parallel arrays, up to MAX_SHAPES long.
func bind(idx: int, xform: Transform3D, mesh: Mesh, shapes: Array, shape_xforms: Array) -> void:
	point_index = idx
	global_transform = xform
	_mesh.mesh = mesh
	for i in _shapes.size():
		var cs: CollisionShape3D = _shapes[i]
		if i < shapes.size() and shapes[i] != null:
			cs.shape = shapes[i]
			cs.transform = shape_xforms[i]
			cs.disabled = false
		else:
			cs.shape = null
			cs.disabled = true
	if not is_in_group("interactable"):
		add_to_group("interactable")

## Called by TreeField when this pool slot is freed back up (point walked
## out of range, or was just felled). Doesn't free the node -- pool members
## are reused, not destroyed/recreated.
func release() -> void:
	point_index = -1
	_mesh.mesh = null
	for cs in _shapes:
		cs.disabled = true
	remove_from_group("interactable")

func get_click_hint(_inv) -> String:
	return "Chop (%s)" % field.required_tool_category.capitalize()

func interact() -> void:
	if point_index >= 0 and field:
		field.interact_point(point_index)
