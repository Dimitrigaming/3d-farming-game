extends Node3D

const BOX_SCENE = preload("res://models/box.tscn")

@onready var hold_point: Marker3D = $"../Head/Camera3D/HoldPoint"

var held_box: Node3D = null

func _ready() -> void:
	add_to_group("player")

func collect_item(item_type: String) -> bool:
	if held_box == null:
		held_box = BOX_SCENE.instantiate()
		get_tree().current_scene.add_child(held_box)
		_attach_to_hold_point()
		return held_box.add_item(item_type)
	return held_box.add_item(item_type)

func pick_up_box(box: Node3D) -> void:
	if held_box != null:
		return
	held_box = box
	_attach_to_hold_point()

func place_box() -> void:
	if held_box == null:
		return
	var drop_xform: Transform3D = held_box.global_transform
	held_box.get_parent().remove_child(held_box)
	get_tree().current_scene.add_child(held_box)
	held_box.global_transform = drop_xform
	held_box.set_held(false)
	held_box = null

func _attach_to_hold_point() -> void:
	if held_box.get_parent():
		held_box.get_parent().remove_child(held_box)
	hold_point.add_child(held_box)
	held_box.transform = Transform3D.IDENTITY
	held_box.set_held(true)
