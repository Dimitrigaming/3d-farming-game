@tool
extends Node3D

const MAX_HEADPHONES = 6

@export_range(0, MAX_HEADPHONES - 1) var headphone: int = 0:
	set(v):
		headphone = v
		_apply()

@export var headphones: Array[Node3D] = []

func _apply() -> void:
	for i in headphones.size():
		if headphones[i] != null:
			headphones[i].visible = (i == headphone)
