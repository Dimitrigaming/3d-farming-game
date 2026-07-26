@tool
extends EditorNode3DGizmoPlugin

func _get_gizmo_name() -> String:
	return "Sidewalk"

func _has_gizmo(node: Node3D) -> bool:
	var script = node.get_script()
	return script != null and "sidewalk" in (script.resource_path as String).to_lower()

func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var node: Node3D = gizmo.get_node_3d()
	var w: float = node.get("width")
	var d: float = node.get("depth")
	if w == null or d == null:
		return

	var hw := w * 0.5
	var hd := d * 0.5

	# Wireframe outline on the ground plane.
	var lines := PackedVector3Array([
		Vector3(-hw, 0.0, -hd), Vector3( hw, 0.0, -hd),
		Vector3( hw, 0.0, -hd), Vector3( hw, 0.0,  hd),
		Vector3( hw, 0.0,  hd), Vector3(-hw, 0.0,  hd),
		Vector3(-hw, 0.0,  hd), Vector3(-hw, 0.0, -hd),
	])
	gizmo.add_lines(lines, get_material("main", gizmo))

	# Four mid-edge handles — one per side, just like CSGBox3D.
	var handles := PackedVector3Array([
		Vector3( hw, 0.0,  0.0),  # 0  +X  (right)
		Vector3(-hw, 0.0,  0.0),  # 1  -X  (left)
		Vector3( 0.0, 0.0,  hd),  # 2  +Z  (front)
		Vector3( 0.0, 0.0, -hd),  # 3  -Z  (back)
	])
	gizmo.add_handles(handles, get_material("handles", gizmo), [0, 1, 2, 3])

# ── handle metadata ───────────────────────────────────────────────────────────

func _get_handle_name(_gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool) -> String:
	return "Width" if handle_id <= 1 else "Depth"

func _get_handle_value(gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool) -> Variant:
	var node: Node3D = gizmo.get_node_3d()
	return node.get("width") if handle_id <= 1 else node.get("depth")

# ── live drag ─────────────────────────────────────────────────────────────────

func _set_handle(gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool,
		camera: Camera3D, screen_pos: Vector2) -> void:
	var node: Node3D = gizmo.get_node_3d()
	var gt   := node.global_transform
	var from := camera.project_ray_origin(screen_pos)
	var dir  := camera.project_ray_normal(screen_pos)

	# Intersect a horizontal plane at the node's world Y.
	var plane := Plane(Vector3.UP, gt.origin.y)
	var hit   = plane.intersects_ray(from, dir)
	if hit == null:
		return

	var local := gt.affine_inverse() * hit

	match handle_id:
		0: node.width =  local.x * 2.0   # +X handle
		1: node.width = -local.x * 2.0   # -X handle
		2: node.depth =  local.z * 2.0   # +Z handle
		3: node.depth = -local.z * 2.0   # -Z handle

# ── commit (undo support) ─────────────────────────────────────────────────────

func _commit_handle(gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool,
		restore: Variant, cancel: bool) -> void:
	var node: Node3D = gizmo.get_node_3d()
	if cancel:
		if handle_id <= 1:
			node.width  = restore
		else:
			node.depth  = restore
		return

	var undo := EditorInterface.get_editor_undo_redo()
	if handle_id <= 1:
		undo.create_action("Resize Sidewalk Width")
		undo.add_do_property(node, "width",  node.get("width"))
		undo.add_undo_property(node, "width", restore)
	else:
		undo.create_action("Resize Sidewalk Depth")
		undo.add_do_property(node, "depth",  node.get("depth"))
		undo.add_undo_property(node, "depth", restore)
	undo.commit_action()
