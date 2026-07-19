extends Node3D

# Tiers expand width (X axis) — both Z ends are door connections so only X is free.
# Width goes 10 → 16 → 22 units.
const _HALF_WIDTHS: Array[float] = [5.0, 8.0, 11.0]

func _ready() -> void:
	add_to_group("shop_floor")
	if GameState.shop_floor_tier > 0:
		apply_tier(GameState.shop_floor_tier)

func apply_tier(tier: int) -> void:
	tier = clampi(tier, 0, _HALF_WIDTHS.size() - 1)
	var hw: float = _HALF_WIDTHS[tier]

	# Front wall (invisible, connects to main store)
	var front = get_node_or_null("CSGBox3D")
	if front:
		front.size = Vector3(hw * 2.0, 4.0, 0.1)

	# Left/right side walls — just shift X, depth stays 10
	var left_wall = get_node_or_null("CSGBox3D4")
	if left_wall:
		left_wall.position.x = -hw

	var right_wall = get_node_or_null("CSGBox3D3")
	if right_wall:
		right_wall.position.x = hw

	# Back wall panels flank the door (door gap = 2 units centered at x=0)
	var panel_w: float = hw - 1.0          # each panel spans from wall edge to x=±1
	var panel_cx: float = -(hw + 1.0) / 2.0  # center of left panel

	var bl = get_node_or_null("CSGBox3D2")
	if bl:
		bl.position.x = panel_cx
		bl.size = Vector3(panel_w, 4.0, 0.1)
		_set_col_shape(bl, "StaticBody3D2/CollisionShape3D", Vector3(panel_w, 4.0, 0.1))

	var br = get_node_or_null("CSGBox3D5")
	if br:
		br.position.x = -panel_cx
		br.size = Vector3(panel_w, 4.0, 0.1)
		_set_col_shape(br, "StaticBody3D2/CollisionShape3D", Vector3(panel_w, 4.0, 0.1))

func _set_col_shape(parent: Node3D, path: String, new_size: Vector3) -> void:
	var col = parent.get_node_or_null(path)
	if col == null:
		return
	var shape = BoxShape3D.new()
	shape.size = new_size
	col.shape = shape
