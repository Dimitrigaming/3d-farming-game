@tool
extends CSGBox3D

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("walking_path")
	visible = false

func get_random_point() -> Vector3:
	var half_x = size.x * 0.5
	var half_z = size.z * 0.5
	var local_point = Vector3(
		randf_range(-half_x, half_x),
		0.0,
		randf_range(-half_z, half_z)
	)
	return global_transform * local_point

func get_exit_toward(world_dir: Vector3) -> Vector3:
	var half_x = size.x * 0.5
	var half_z = size.z * 0.5
	var local_dir = global_transform.basis.inverse() * world_dir
	var exit_local: Vector3
	if abs(local_dir.x) > abs(local_dir.z):
		exit_local = Vector3(half_x * sign(local_dir.x), 0, randf_range(-half_z, half_z))
	else:
		exit_local = Vector3(randf_range(-half_x, half_x), 0, half_z * sign(local_dir.z))
	return global_transform * exit_local

func get_nearest_point(world_pos: Vector3) -> Vector3:
	var local = global_transform.affine_inverse() * world_pos
	local.x = clamp(local.x, -size.x * 0.5, size.x * 0.5)
	local.y = 0.0
	local.z = clamp(local.z, -size.z * 0.5, size.z * 0.5)
	return global_transform * local
