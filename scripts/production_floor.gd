extends Node3D

const _DEPTHS = [10.0, 16.0, 22.0]

func _ready() -> void:
	add_to_group("production_floor")
	print("[ProductionFloor] _ready, tier=", GameState.production_floor_tier)
	if GameState.production_floor_tier > 0:
		apply_tier(GameState.production_floor_tier)

func apply_tier(tier: int) -> void:
	tier = clampi(tier, 0, _DEPTHS.size() - 1)
	var d: float = _DEPTHS[tier]
	print("[ProductionFloor] apply_tier ", tier, " depth=", d)

	var back = get_node_or_null("CSGBox3D")
	print("[ProductionFloor] back_wall=", back)
	if back:
		back.position = Vector3(back.position.x, back.position.y, -(d + 0.1))

	var left_wall = get_node_or_null("CSGBox3D4")
	print("[ProductionFloor] left_wall=", left_wall)
	if left_wall:
		left_wall.position = Vector3(left_wall.position.x, left_wall.position.y, -(d / 2.0 + 0.1))
		left_wall.size = Vector3(d, 4.0, 0.1)
		_set_col_shape(left_wall, "StaticBody3D4/CollisionShape3D", Vector3(d, 4.0, 0.1))

	var right_wall = get_node_or_null("CSGBox3D3")
	print("[ProductionFloor] right_wall=", right_wall)
	if right_wall:
		right_wall.position = Vector3(right_wall.position.x, right_wall.position.y, -(d / 2.0 + 0.1))
		right_wall.size = Vector3(d, 4.0, 0.1)
		_set_col_shape(right_wall, "StaticBody3D3/CollisionShape3D", Vector3(d, 4.0, 0.1))

func _set_col_shape(parent: Node3D, path: String, new_size: Vector3) -> void:
	var col = parent.get_node_or_null(path)
	if col == null:
		return
	var shape = BoxShape3D.new()
	shape.size = new_size
	col.shape = shape
