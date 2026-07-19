extends Node3D

const _HALF_WIDTHS = [5.0, 8.0, 11.0]

func _ready() -> void:
	add_to_group("shop_floor")
	print("[ShopFloor] _ready, tier=", GameState.shop_floor_tier)
	if GameState.shop_floor_tier > 0:
		apply_tier(GameState.shop_floor_tier)

func apply_tier(tier: int) -> void:
	tier = clampi(tier, 0, _HALF_WIDTHS.size() - 1)
	var hw: float = _HALF_WIDTHS[tier]
	print("[ShopFloor] apply_tier ", tier, " hw=", hw)

	var front = get_node_or_null("CSGBox3D")
	print("[ShopFloor] front=", front)
	if front:
		front.size = Vector3(hw * 2.0, 4.0, 0.1)

	var left_wall = get_node_or_null("CSGBox3D4")
	print("[ShopFloor] left_wall=", left_wall)
	if left_wall:
		left_wall.position = Vector3(-hw, left_wall.position.y, left_wall.position.z)

	var right_wall = get_node_or_null("CSGBox3D3")
	print("[ShopFloor] right_wall=", right_wall)
	if right_wall:
		right_wall.position = Vector3(hw, right_wall.position.y, right_wall.position.z)

	var panel_w: float = hw - 1.0
	var panel_cx: float = -(hw + 1.0) / 2.0

	var bl = get_node_or_null("CSGBox3D2")
	print("[ShopFloor] back_left=", bl)
	if bl:
		bl.position = Vector3(panel_cx, bl.position.y, bl.position.z)
		bl.size = Vector3(panel_w, 4.0, 0.1)
		_set_col_shape(bl, "StaticBody3D2/CollisionShape3D", Vector3(panel_w, 4.0, 0.1))

	var br = get_node_or_null("CSGBox3D5")
	print("[ShopFloor] back_right=", br)
	if br:
		br.position = Vector3(-panel_cx, br.position.y, br.position.z)
		br.size = Vector3(panel_w, 4.0, 0.1)
		_set_col_shape(br, "StaticBody3D2/CollisionShape3D", Vector3(panel_w, 4.0, 0.1))

func _set_col_shape(parent: Node3D, path: String, new_size: Vector3) -> void:
	var col = parent.get_node_or_null(path)
	if col == null:
		return
	var shape = BoxShape3D.new()
	shape.size = new_size
	col.shape = shape
