extends Node3D

# half-widths per tier: 10 → 16 → 22 units wide
const _HALF_WIDTHS = [5.0, 8.0, 11.0]

func _ready() -> void:
	add_to_group("shop_floor")
	var logger = get_node_or_null("/root/GameLogger")
	if logger:
		logger.info("ShopFloor", "_ready — tier=%d" % GameState.shop_floor_tier)
	if GameState.shop_floor_tier > 0:
		apply_tier(GameState.shop_floor_tier)

func apply_tier(tier: int) -> void:
	tier = clampi(tier, 0, _HALF_WIDTHS.size() - 1)
	var hw: float = _HALF_WIDTHS[tier]
	var logger = get_node_or_null("/root/GameLogger")
	if logger:
		logger.info("ShopFloor", "apply_tier %d — half_width=%.1f" % [tier, hw])

	# Front wall (invisible, connects to main store)
	var front = get_node_or_null("CSGBox3D")
	if front:
		front.size = Vector3(hw * 2.0, 4.0, 0.1)
	else:
		if logger: logger.warning("ShopFloor", "CSGBox3D (front) not found")

	# Side walls — shift X, size stays same
	var left_wall = get_node_or_null("CSGBox3D4")
	if left_wall:
		left_wall.position.x = -hw
	else:
		if logger: logger.warning("ShopFloor", "CSGBox3D4 (left wall) not found")

	var right_wall = get_node_or_null("CSGBox3D3")
	if right_wall:
		right_wall.position.x = hw
	else:
		if logger: logger.warning("ShopFloor", "CSGBox3D3 (right wall) not found")

	# Back panels flank the door (door gap = 2 units centered at x=0)
	var panel_w: float = hw - 1.0
	var panel_cx: float = -(hw + 1.0) / 2.0

	var bl = get_node_or_null("CSGBox3D2")
	if bl:
		bl.position.x = panel_cx
		bl.size = Vector3(panel_w, 4.0, 0.1)
		_set_col_shape(bl, "StaticBody3D2/CollisionShape3D", Vector3(panel_w, 4.0, 0.1))
	else:
		if logger: logger.warning("ShopFloor", "CSGBox3D2 (back left) not found")

	var br = get_node_or_null("CSGBox3D5")
	if br:
		br.position.x = -panel_cx
		br.size = Vector3(panel_w, 4.0, 0.1)
		_set_col_shape(br, "StaticBody3D2/CollisionShape3D", Vector3(panel_w, 4.0, 0.1))
	else:
		if logger: logger.warning("ShopFloor", "CSGBox3D5 (back right) not found")

func _set_col_shape(parent: Node3D, path: String, new_size: Vector3) -> void:
	var col = parent.get_node_or_null(path)
	if col == null:
		return
	var shape = BoxShape3D.new()
	shape.size = new_size
	col.shape = shape
