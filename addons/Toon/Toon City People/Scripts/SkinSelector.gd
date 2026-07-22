@tool
extends Node3D

const MAX_SKINS = 5

@export_range(0, MAX_SKINS - 1) var skin: int = 0:
	set(v):
		skin = v
		_apply()

@export var skins: Array[Node3D] = []

func _apply() -> void:
	for i in skins.size():
		if skins[i] != null:
			skins[i].visible = (i == skin)
