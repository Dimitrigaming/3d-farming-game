extends Node3D

## F3 toggles a Minecraft-style wireframe overlay over every nearby
## interactable's collision shape, so misaligned hitboxes (like the
## mining-node fit bug) are visible directly in-game instead of guessing.

const SCAN_RADIUS: float = 40.0
const BOX_EDGES := [
	[0, 1], [1, 5], [5, 4], [4, 0],
	[2, 3], [3, 7], [7, 6], [6, 2],
	[0, 2], [1, 3], [4, 6], [5, 7],
]

var _active: bool = false
var _mesh_instance: MeshInstance3D
var _immediate: ImmediateMesh

func _ready() -> void:
	_immediate = ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.15, 0.15, 1.0)
	material.no_depth_test = true
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = _immediate
	_mesh_instance.material_override = material
	_mesh_instance.top_level = true
	_mesh_instance.visible = false
	add_child(_mesh_instance)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		_active = not _active
		_mesh_instance.visible = _active

func _process(_delta: float) -> void:
	if not _active:
		return
	_redraw()

func _redraw() -> void:
	var player_nodes := get_tree().get_nodes_in_group("player")
	var origin := Vector3.ZERO
	if not player_nodes.is_empty():
		origin = player_nodes[0].global_position

	_immediate.clear_surfaces()
	_immediate.surface_begin(Mesh.PRIMITIVE_LINES)
	for body in get_tree().get_nodes_in_group("interactable"):
		if not body is Node3D:
			continue
		if body.global_position.distance_to(origin) > SCAN_RADIUS:
			continue
		for shape in _find_collision_shapes(body):
			_draw_shape(shape)
	_immediate.surface_end()

## Mining/tree nodes nest their collision under a PhysicsBody child (for
## the distance-based streaming that removes it from the tree entirely when
## far away, see resource_streamer.gd) instead of directly under the
## interactable root, so this needs to search recursively rather than just
## checking direct children.
func _find_collision_shapes(node: Node) -> Array:
	var result: Array = []
	for child in node.get_children():
		if child is CollisionShape3D and child.shape != null and not child.disabled:
			result.append(child)
		result.append_array(_find_collision_shapes(child))
	return result

func _draw_shape(col: CollisionShape3D) -> void:
	var shape := col.shape
	var half: Vector3
	if shape is BoxShape3D:
		half = shape.size / 2.0
	elif shape is CapsuleShape3D:
		half = Vector3(shape.radius, shape.height / 2.0, shape.radius)
	elif shape is SphereShape3D:
		half = Vector3.ONE * shape.radius
	elif shape is CylinderShape3D:
		half = Vector3(shape.radius, shape.height / 2.0, shape.radius)
	else:
		return
	_draw_box(col.global_transform, half)

func _draw_box(xform: Transform3D, half: Vector3) -> void:
	var corners: Array[Vector3] = []
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			for sz in [-1, 1]:
				corners.append(xform * Vector3(sx * half.x, sy * half.y, sz * half.z))
	for edge in BOX_EDGES:
		_immediate.surface_add_vertex(corners[edge[0]])
		_immediate.surface_add_vertex(corners[edge[1]])
