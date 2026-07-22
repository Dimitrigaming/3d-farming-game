@tool
extends Node3D

const MAX_HATS = 26

@export_range(0, MAX_HATS - 1) var hat: int = 0:
	set(v):
		hat = v
		_apply()

@export var hats: Array[Node3D] = []

func _apply() -> void:
	for i in hats.size():
		if hats[i] != null:
			hats[i].visible = (i == hat)
