@tool
extends Node3D

const MAX_SKIRTS = 5

@export_range(0, MAX_SKIRTS - 1) var skirt: int = 0:
	set(v):
		skirt = v
		_apply()

@export var skirts: Array[Node3D] = []

func _apply() -> void:
	for i in skirts.size():
		if skirts[i] != null:
			skirts[i].visible = (i == skirt)
