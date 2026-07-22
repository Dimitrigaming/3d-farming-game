@tool
extends Node3D

const MAX_SHOES = 5

@export_range(0, MAX_SHOES - 1) var shoe: int = 0:
	set(v):
		shoe = v
		_apply()

@export var shoes: Array[Node3D] = []

func _apply() -> void:
	for i in shoes.size():
		if shoes[i] != null:
			shoes[i].visible = (i == shoe)
