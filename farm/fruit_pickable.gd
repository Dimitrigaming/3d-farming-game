class_name FruitPickable
extends Area3D

@export var crop_id: String = ""

func _ready() -> void:
	add_to_group("fruit_pickable")

func pick() -> void:
	if crop_id != "":
		Inventory.add_item(crop_id, 1)
	get_parent().queue_free()
