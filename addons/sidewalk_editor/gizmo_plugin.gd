@tool
class_name SidewalkGizmo
extends EditorNode3DGizmoPlugin

const SIDEWALK_SCRIPT = "res://tools/sidewalk.gd"

func _init():
	create_material("main", Color(0.4, 0.85, 0.85))
	create_handle_material("handles")

func _get_gizmo_name() -> String:
	return "Sidewalk"

func _has_gizmo(node: Node3D) -> bool:
	var s = node.get_script()
	return s != null and s.resource_path == SIDEWALK_SCRIPT

func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var node = gizmo.get_node_3d()
	var hw: float = node.width * 0.5
	var hd: float = node.depth * 0.5

	var lines := PackedVector3Array([
		Vector3(-hw, 0.0, -hd), Vector3( hw, 0.0, -hd),
		Vector3( hw, 0.0, -hd), Vector3( hw, 0.0,  hd),
		Vector3( hw, 0.0,  hd), Vector3(-hw, 0.0,  hd),
		Vector3(-hw, 0.0,  hd), Vector3(-hw, 0.0, -hd),
	])
	gizmo.add_lines(lines, get_material("main", gizmo))

	var handles := PackedVector3Array([
		Vector3( hw, 0.0,  0.0),
		Vector3(-hw, 0.0,  0.0),
		Vector3( 0.0, 0.0,  hd),
		Vector3( 0.0, 0.0, -hd),
	])
	gizmo.add_handles(handles, get_material("handles", gizmo), [])

func _get_handle_name(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool) -> String:
	return ["Width +X", "Width -X", "Depth +Z", "Depth -Z"][handle_id]

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
	match handle_id:
		0: node.width  = max(4.0,  local.x * 2.0)
		1: node.width  = max(4.0, -local.x * 2.0)
		2: node.depth  = max(4.0,  local.z * 2.0)
		3: node.depth  = max(4.0, -local.z * 2.0)

func _commit_handle(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool, restore: Variant, cancel: bool) -> void:
	var node = gizmo.get_node_3d()
	if cancel:
		node.width = restore.x
		node.depth = restore.y
	else:
		var undo := EditorInterface.get_editor_undo_redo()
		undo.create_action("Resize Sidewalk")
		undo.add_do_property(node, "width", node.width)
		undo.add_do_property(node, "depth", node.depth)
		undo.add_undo_property(node, "width", restore.x)
		undo.add_undo_property(node, "depth", restore.y)
		undo.commit_action()
