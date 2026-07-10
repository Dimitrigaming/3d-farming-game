@tool
extends CSGBox3D

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("walking_path")
	visible = false

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	var a = get_node_or_null("PointA")
	var b = get_node_or_null("PointB")
	if a:
		a.position = Vector3(0, 0, -size.z * 0.5)
	if b:
		b.position = Vector3(0, 0, size.z * 0.5)

func get_exit_point(from_world_pos: Vector3) -> Vector3:
	var local_from = global_transform.affine_inverse() * from_world_pos
	var exit_z: float
	if local_from.z >= 0.0:
		exit_z = -size.z * 0.5
	else:
		exit_z = size.z * 0.5
	return global_transform * Vector3(0, 0, exit_z)
