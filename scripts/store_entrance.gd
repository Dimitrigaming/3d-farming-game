@tool
extends Area3D

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("store_entrance")
	var visual = get_node_or_null("Visual")
	if visual:
		visual.visible = false
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("npc") and body.has_method("try_enter_store"):
		var entry_point = get_node_or_null("/root/Map/City/Player_Building/StoreEntryPoint")
		if entry_point == null:
			Logger.warning("StoreEntrance", "StoreEntryPoint not found — using entrance position")
		var target = entry_point.global_position if entry_point else global_position
		body.try_enter_store(target)
