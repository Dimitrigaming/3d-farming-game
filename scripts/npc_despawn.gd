@tool
extends Area3D

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("npc_despawn")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("npc"):
		body.queue_free()
