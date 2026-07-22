@tool
extends Node3D

const MAX_EARRINGS = 19

@export_range(0, MAX_EARRINGS - 1) var earring: int = 0:
	set(v):
		earring = v
		_apply()

@export var earrings: Array[Node3D] = []

func _apply() -> void:
	for i in earrings.size():
		if earrings[i] != null:
			earrings[i].visible = (i == earring)
