@tool
class_name TiledPlaneGizmo
extends EditorNode3DGizmoPlugin

const TILED_PLANE_SCRIPT = "res://scripts/TiledPlane.gd"

func _init():
	create_handle_material("handles")

func _get_gizmo_name() -> String:
	return "TiledPlane"

func _has_gizmo(node: Node3D) -> bool:
	var s = node.get_script()
	return s != null and s.resource_path == TILED_PLANE_SCRIPT

func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var node = gizmo.get_node_3d()
	var hw: float = node.tile_count.x * node.tile_size * 0.5
	var hd: float = node.tile_count.y * node.tile_size * 0.5
	var handles := PackedVector3Array([
		Vector3(hw,  0.0,  0.0),
		Vector3(-hw, 0.0,  0.0),
		Vector3(0.0, 0.0,  hd),
		Vector3(0.0, 0.0, -hd),
	])
	gizmo.add_handles(handles, get_material("handles", gizmo), [])

func _get_handle_name(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool) -> String:
	return ["Width +X", "Width -X", "Depth +Z", "Depth -Z"][handle_id]

func _get_handle_value(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool) -> Variant:
	return gizmo.get_node_3d().tile_count

func _set_handle(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool, camera: Camera3D, screen_pos: Vector2) -> void:
	var node = gizmo.get_node_3d()
	var ray_o := camera.project_ray_origin(screen_pos)
	var ray_d := camera.project_ray_normal(screen_pos)
	# intersect the Y=0 plane in world space
	if abs(ray_d.y) < 0.0001:
		return
	var t := -ray_o.y / ray_d.y
	var hit_world := ray_o + ray_d * t
	var local: Vector3 = node.global_transform.affine_inverse() * hit_world
	var ts: float = node.tile_size
	var new_count: Vector2i = node.tile_count
	match handle_id:
		0: new_count.x = max(1, int(round(local.x * 2.0 / ts)))
		1: new_count.x = max(1, int(round(-local.x * 2.0 / ts)))
		2: new_count.y = max(1, int(round(local.z * 2.0 / ts)))
		3: new_count.y = max(1, int(round(-local.z * 2.0 / ts)))
	node.tile_count = new_count

func _commit_handle(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool, restore: Variant, cancel: bool) -> void:
	var node = gizmo.get_node_3d()
	if cancel:
		node.tile_count = restore
	else:
		var undo := EditorInterface.get_editor_undo_redo()
		undo.create_action("Resize TiledPlane")
		undo.add_do_property(node, "tile_count", node.tile_count)
		undo.add_undo_property(node, "tile_count", restore)
		undo.commit_action()
