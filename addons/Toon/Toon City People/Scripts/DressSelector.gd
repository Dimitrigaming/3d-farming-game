@tool
extends Node3D

const MAX_DRESSES = 5

@export_range(0, MAX_DRESSES - 1) var dress: int = 0:
	set(v):
		dress = v
		_apply()

@export var dresses: Array[Node3D] = []

func _apply() -> void:
	for i in dresses.size():
		if dresses[i] != null:
			dresses[i].visible = (i == dress)
