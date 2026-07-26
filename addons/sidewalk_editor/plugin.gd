@tool
extends EditorPlugin

var _gizmo_plugin: EditorNode3DGizmoPlugin

func _enter_tree() -> void:
	_gizmo_plugin = preload("res://addons/sidewalk_editor/gizmo_plugin.gd").new()
	_gizmo_plugin.create_material("main", Color(0.4, 0.85, 0.85))
	_gizmo_plugin.create_handle_material("handles")
	add_node_3d_gizmo_plugin(_gizmo_plugin)

func _exit_tree() -> void:
	remove_node_3d_gizmo_plugin(_gizmo_plugin)
