@tool
class_name FarmExpansionArea
extends Node3D

## Farm expansion fence/sign placer. Anchored at this node's own origin
## (where the sign sits) and grows toward -X/-Z only as width/depth
## increase -- unlike tools/sidewalk.gd, which grows symmetrically from
## its center, this keeps the sign's corner fixed while only the far
## edge moves (see the matching gizmo in addons/farm_expansion_editor).

## CELL_SIZE is the farm grid's tile size (used only for the farmland
## dirt-conversion below); FENCE_SPAN is fence.tscn's own post-to-post
## length (its two built-in posts sit at local x=0 and x=2). These are
## deliberately separate -- the fence panels tile at 2m, but the farmland
## underneath still converts in 1m cells regardless of fence spacing.
const CELL_SIZE: float = 1.0
const FENCE_SPAN: float = 2.0
const FENCE_SCENE: PackedScene = preload("res://models/building/fence.tscn")
const PARCEL_SIGN_SCENE: PackedScene = preload("res://farm/farm_parcel_sign.tscn")

## Snapped to FENCE_SPAN (not CELL_SIZE) so a whole number of fence panels
## always tiles the perimeter exactly, with no gap or overlap at the end.
@export var width: float = 6.0 : set = _on_width_changed
@export var depth: float = 6.0 : set = _on_depth_changed
@export var parcel_index: int = 1 : set = _on_parcel_index_changed
## When off, cost uses GameState's default geometric formula. Toggle on to
## hand-price this specific parcel with price_override instead.
@export var use_price_override: bool = false : set = _on_use_price_override_changed
@export var price_override: float = 1000.0 : set = _on_price_override_changed

func _on_width_changed(v: float) -> void:
	width = maxf(FENCE_SPAN, snappedf(v, FENCE_SPAN))
	_rebuild()

func _on_depth_changed(v: float) -> void:
	depth = maxf(FENCE_SPAN, snappedf(v, FENCE_SPAN))
	_rebuild()

func _on_parcel_index_changed(v: int) -> void:
	parcel_index = max(1, v)
	_rebuild()

func _on_use_price_override_changed(v: bool) -> void:
	use_price_override = v
	_rebuild()

func _on_price_override_changed(v: float) -> void:
	price_override = v
	_rebuild()

func _ready() -> void:
	_rebuild()
	if not Engine.is_editor_hint():
		_setup_farmland_unlock()

func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		child.free()

	var cols := int(width / FENCE_SPAN)   # panels along the top/bottom (X) edges
	var rows := int(depth / FENCE_SPAN)   # panels along the left/right (Z) edges

	# Top edge (z=0) and bottom edge (z=-depth), running along -X. fence.tscn's
	# local x:[0,2] is unrotated here, so placing a panel's origin at the far
	# (more negative) end of its segment makes it span back toward the near end.
	for i in cols:
		_spawn_fence_panel(Vector3(-(i + 1) * FENCE_SPAN, 0.0, 0.0), 0.0)
		_spawn_fence_panel(Vector3(-(i + 1) * FENCE_SPAN, 0.0, -depth), 0.0)

	# Left edge (x=0) and right edge (x=-width), running along -Z. Rotated 90
	# degrees around Y so local x:[0,2] maps to world -Z instead of +X.
	for i in rows:
		_spawn_fence_panel(Vector3(0.0, 0.0, -i * FENCE_SPAN), 90.0)
		_spawn_fence_panel(Vector3(-width, 0.0, -i * FENCE_SPAN), 90.0)

	_spawn_sign(Vector3.ZERO)

## Deliberately NOT setting `owner` on these -- this whole node regenerates
## its children from width/depth/parcel_index every time it loads (_ready()
## always calls _rebuild() first), so there's nothing to gain by persisting
## them into the scene file, and doing so is what caused the "node name
## clashes" load error: every save baked another generation of panels into
## Map.tscn, which then collided with the next runtime-generated set.
func _spawn_fence_panel(local_pos: Vector3, y_rot_degrees: float) -> void:
	var panel = FENCE_SCENE.instantiate()
	add_child(panel)
	panel.position = local_pos
	panel.rotation_degrees.y = y_rot_degrees

func _spawn_sign(local_pos: Vector3) -> void:
	var sign_node = PARCEL_SIGN_SCENE.instantiate()
	# Set every property BEFORE add_child() -- add_child() runs the sign's
	# _ready() synchronously (since this node is already in the tree), so
	# anything set after add_child() arrives too late for the label text
	# it builds in _ready().
	sign_node.position = local_pos
	sign_node.parcel_index = parcel_index
	sign_node.use_price_override = use_price_override
	sign_node.price_override = price_override
	add_child(sign_node)

## Once this area's parcel unlocks, its footprint becomes real tillable
## farmland (grass -> DIRT), not just a fenced-off patch. Reuses whatever
## FarmGrid is in the scene via the "farm_grid" group.
func _setup_farmland_unlock() -> void:
	if parcel_index < GameState.farm_parcels_unlocked:
		_convert_to_farmland()
		queue_free()
	else:
		GameState.farm_parcel_unlocked.connect(_on_farmland_unlock)

func _on_farmland_unlock(new_count: int) -> void:
	if parcel_index < new_count:
		_convert_to_farmland()
		GameState.farm_parcel_unlocked.disconnect(_on_farmland_unlock)
		# Fence + sign have done their job -- the footprint is now real
		# farmland, so remove the whole node (fence panels included; the
		# sign also frees itself independently via its own script, but
		# freeing here is what actually clears the fence panels).
		queue_free()

func _convert_to_farmland() -> void:
	var farm_node = get_tree().get_first_node_in_group("farm_grid")
	if farm_node == null:
		push_warning("FarmExpansionArea(parcel %d): no node in group 'farm_grid' -- farmland conversion skipped." % parcel_index)
		return
	if not farm_node.has_method("unlock_area_as_dirt"):
		push_warning("FarmExpansionArea(parcel %d): farm_grid node has no unlock_area_as_dirt() -- farmland conversion skipped." % parcel_index)
		return
	var grid_map: GridMap = farm_node.grid_map
	var cols := int(width / CELL_SIZE)
	var rows := int(depth / CELL_SIZE)
	var cells: Array = []
	for col in range(cols):
		for row in range(rows):
			# Anchored at the origin corner (same as the fence panels above),
			# extending toward -X/-Z -- NOT centered on the node origin.
			var x := -(col + 0.5) * CELL_SIZE
			var z := -(row + 0.5) * CELL_SIZE
			var world_pos = global_transform * Vector3(x, 0.0, z)
			var grid_local = grid_map.to_local(world_pos)
			cells.append(grid_map.local_to_map(grid_local))
	print("FarmExpansionArea(parcel %d): anchor global_transform.origin=%s width=%s depth=%s" % [parcel_index, global_transform.origin, width, depth])
	print("FarmExpansionArea(parcel %d): converting %d cells to farmland, e.g. %s" % [parcel_index, cells.size(), cells.slice(0, min(3, cells.size()))])
	farm_node.unlock_area_as_dirt(cells)
