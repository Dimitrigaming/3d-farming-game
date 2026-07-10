@tool
extends Area3D

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("store_entrance")
	var visual = get_node_or_null("Visual")
	if visual:
		visual.visible = false
