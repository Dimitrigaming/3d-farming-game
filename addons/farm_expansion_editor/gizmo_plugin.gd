@tool
class_name FarmExpansionGizmo
extends EditorNode3DGizmoPlugin

func _init():
	create_material("main", Color(0.85, 0.55, 0.15))
	create_handle_material("handles")

func _get_gizmo_name() -> String:
	return "Farm Expansion Area"

func _has_gizmo(node: Node3D) -> bool:
	var s = node.get_script()
	return s != null and s.resource_path == "res://farm/farm_expansion_area.gd"

func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var node = gizmo.get_node_3d()
	var w: float = node.width
	var d: float = node.depth

	# Outline of the rect extending from the origin (0,0) -- where the sign
	# sits -- toward -X/-Z only. NOT centered/symmetric.
	var lines := PackedVector3Array([
		Vector3(0.0, 0.0, 0.0), Vector3(-w, 0.0, 0.0),
		Vector3(-w, 0.0, 0.0), Vector3(-w, 0.0, -d),
		Vector3(-w, 0.0, -d), Vector3(0.0, 0.0, -d),
		Vector3(0.0, 0.0, -d), Vector3(0.0, 0.0, 0.0),
	])
	gizmo.add_lines(lines, get_material("main", gizmo))

	# One handle per axis, on the far edge only -- dragging either moves
	# just that edge; the origin corner (and the sign there) never moves.
	var handles := PackedVector3Array([
		Vector3(-w, 0.0, -d * 0.5),
		Vector3(-w * 0.5, 0.0, -d),
	])
	gizmo.add_handles(handles, get_material("handles", gizmo), [])

func _get_handle_name(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool) -> String:
	return ["Width -X", "Depth -Z"][handle_id]

func _get_handle_value(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool) -> Variant:
	var node = gizmo.get_node_3d()
	return Vector2(node.width, node.depth)

func _set_handle(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool, camera: Camera3D, screen_pos: Vector2) -> void:
	var node = gizmo.get_node_3d()
	var ray_o := camera.project_ray_origin(screen_pos)
	var ray_d := camera.project_ray_normal(screen_pos)
	if abs(ray_d.y) < 0.0001:
		return
	var t := -ray_o.y / ray_d.y
	var hit_world := ray_o + ray_d * t
	var local: Vector3 = node.global_transform.affine_inverse() * hit_world
	# No doubling -- the origin corner is fixed, so the drag distance IS the
	# new width/depth directly (unlike a symmetric resize where both edges
	# move and the drag distance is only half the total change).
	match handle_id:
		0: node.width = max(1.0, -local.x)
		1: node.depth = max(1.0, -local.z)

func _commit_handle(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool, restore: Variant, cancel: bool) -> void:
	var node = gizmo.get_node_3d()
	if cancel:
		node.width = restore.x
		node.depth = restore.y
	else:
		var undo := EditorInterface.get_editor_undo_redo()
		undo.create_action("Resize Farm Expansion Area")
		undo.add_do_property(node, "width", node.width)
		undo.add_do_property(node, "depth", node.depth)
		undo.add_undo_property(node, "width", restore.x)
		undo.add_undo_property(node, "depth", restore.y)
		undo.commit_action()
