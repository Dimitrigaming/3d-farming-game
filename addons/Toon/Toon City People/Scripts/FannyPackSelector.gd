@tool
extends Node3D

const MAX_FANNY_PACKS = 6

@export_range(0, MAX_FANNY_PACKS - 1) var fanny_pack: int = 0:
	set(v):
		fanny_pack = v
		_apply()

@export var fanny_packs: Array[Node3D] = []

func _apply() -> void:
	for i in fanny_packs.size():
		if fanny_packs[i] != null:
			fanny_packs[i].visible = (i == fanny_pack)
