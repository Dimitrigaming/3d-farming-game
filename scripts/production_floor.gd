extends Node3D

# depths per tier: 10 → 16 → 22 units deep
const _DEPTHS = [10.0, 16.0, 22.0]

func _ready() -> void:
	add_to_group("production_floor")
	var logger = get_node_or_null("/root/GameLogger")
	if logger:
		logger.info("ProductionFloor", "_ready — tier=%d" % GameState.production_floor_tier)
	if GameState.production_floor_tier > 0:
		apply_tier(GameState.production_floor_tier)

func apply_tier(tier: int) -> void:
	tier = clampi(tier, 0, _DEPTHS.size() - 1)
	var d: float = _DEPTHS[tier]
	var logger = get_node_or_null("/root/GameLogger")
	if logger:
		logger.info("ProductionFloor", "apply_tier %d — depth=%.1f" % [tier, d])

	# Back wall slides further back
	var back = get_node_or_null("CSGBox3D")
	if back:
		back.position.z = -(d + 0.1)
	else:
		if logger: logger.warning("ProductionFloor", "CSGBox3D (back wall) not found")

	# Side walls stretch in Z (rotated 90° so local size.x = world depth)
	var left_wall = get_node_or_null("CSGBox3D4")
	if left_wall:
		left_wall.position.z = -(d / 2.0 + 0.1)
		left_wall.size = Vector3(d, 4.0, 0.1)
		_set_col_shape(left_wall, "StaticBody3D4/CollisionShape3D", Vector3(d, 4.0, 0.1))
	else:
		if logger: logger.warning("ProductionFloor", "CSGBox3D4 (left wall) not found")

	var right_wall = get_node_or_null("CSGBox3D3")
	if right_wall:
		right_wall.position.z = -(d / 2.0 + 0.1)
		right_wall.size = Vector3(d, 4.0, 0.1)
		_set_col_shape(right_wall, "StaticBody3D3/CollisionShape3D", Vector3(d, 4.0, 0.1))
	else:
		if logger: logger.warning("ProductionFloor", "CSGBox3D3 (right wall) not found")

func _set_col_shape(parent: Node3D, path: String, new_size: Vector3) -> void:
	var col = parent.get_node_or_null(path)
	if col == null:
		return
	var shape = BoxShape3D.new()
	shape.size = new_size
	col.shape = shape
