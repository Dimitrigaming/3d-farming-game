@tool
extends Node3D

const MAX_BRACELETS = 13

@export_range(0, MAX_BRACELETS - 1) var bracelet: int = 0:
	set(v):
		bracelet = v
		_apply()

@export var bracelets: Array[Node3D] = []

func _apply() -> void:
	for i in bracelets.size():
		if bracelets[i] != null:
			bracelets[i].visible = (i == bracelet)
