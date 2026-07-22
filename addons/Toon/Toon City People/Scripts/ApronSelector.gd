@tool
extends Node3D

const MAX_APRONS = 5

@export_range(0, MAX_APRONS - 1) var apron: int = 0:
	set(v):
		apron = v
		_apply()

@export var aprons: Array[Node3D] = []

func _apply() -> void:
	for i in aprons.size():
		if aprons[i] != null:
			aprons[i].visible = (i == apron)
