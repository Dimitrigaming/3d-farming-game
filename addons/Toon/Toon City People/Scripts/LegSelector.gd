@tool
extends Node3D

const MAX_LEGS = 5

@export_range(0, MAX_LEGS - 1) var leg: int = 0:
	set(v):
		leg = v
		_apply()

@export var legs: Array[Node3D] = []

func _apply() -> void:
	for i in legs.size():
		if legs[i] != null:
			legs[i].visible = (i == leg)
