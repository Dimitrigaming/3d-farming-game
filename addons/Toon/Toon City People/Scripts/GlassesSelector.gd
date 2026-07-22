@tool
extends Node3D

const MAX_GLASSES = 21

@export_range(0, MAX_GLASSES - 1) var glass: int = 0:
	set(v):
		glass = v
		_apply()

@export var glasses: Array[Node3D] = []

func _apply() -> void:
	for i in glasses.size():
		if glasses[i] != null:
			glasses[i].visible = (i == glass)
