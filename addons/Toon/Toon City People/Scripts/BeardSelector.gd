@tool
extends Node3D

const MAX_BEARDS = 46

@export_range(0, MAX_BEARDS - 1) var beard: int = 0:
	set(v):
		beard = v
		_apply()

@export var beards: Array[Node3D] = []

func _apply() -> void:
	for i in beards.size():
		if beards[i] != null:
			beards[i].visible = (i == beard)
