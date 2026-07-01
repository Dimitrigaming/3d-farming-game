extends Node3D

const BOX_SCENE = preload("res://models/box.tscn")

@onready var hold_point: Marker3D = $"../Head/Camera3D/HoldPoint"

var held_item: Node3D = null

func _ready() -> void:
	add_to_group("player")

func collect_item(item_type: String, from_global_pos: Vector3 = Vector3.ZERO) -> bool:
	if held_item == null:
		held_item = BOX_SCENE.instantiate()
		get_tree().current_scene.add_child(held_item)
		_attach_to_hold_point()
		return held_item.add_item(item_type, from_global_pos)
	if not held_item.has_method("add_item"):
		return false
	return held_item.add_item(item_type, from_global_pos)

func pick_up_item(item: Node3D) -> void:
	if held_item != null:
		return
	held_item = item
	_attach_to_hold_point()

const THROW_SPEED_MAX: float = 12.0

func throw_item(speed: float = THROW_SPEED_MAX) -> void:
	if held_item == null or not held_item is RigidBody3D:
		return
	var camera = hold_point.get_parent()
	var throw_dir = -camera.global_transform.basis.z + Vector3(0, 0.15, 0)
	held_item.get_parent().remove_child(held_item)
	get_tree().current_scene.add_child(held_item)
	held_item.global_position = hold_point.global_position
	held_item.set_held(false)
	held_item.linear_velocity = throw_dir.normalized() * speed
	held_item = null

func place_box() -> void:
	if held_item == null:
		return
	var player = get_parent()
	var forward = -player.global_transform.basis.z
	var drop_pos = player.global_position + forward * 0.8 + Vector3(0, 1.0, 0)
	held_item.get_parent().remove_child(held_item)
	get_tree().current_scene.add_child(held_item)
	held_item.global_position = drop_pos
	held_item.rotation = Vector3(0, player.rotation.y + PI, 0)
	held_item.set_held(false)
	held_item = null

func unpack_held_item() -> Node3D:
	if held_item == null or not held_item.has_method("unpack_at"):
		return null
	var player = get_parent()
	var forward = -player.global_transform.basis.z
	var drop_pos = player.global_position + forward * 1.0
	drop_pos.y = _find_floor_y(drop_pos)
	var item = held_item.unpack_at(drop_pos, player.rotation.y)
	held_item.queue_free()
	held_item = null
	return item

func _find_floor_y(pos: Vector3) -> float:
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(pos + Vector3(0, 3, 0), pos + Vector3(0, -3, 0))
	var result = space_state.intersect_ray(query)
	if result:
		return result.position.y
	return pos.y

func _attach_to_hold_point() -> void:
	if held_item.get_parent():
		held_item.get_parent().remove_child(held_item)
	hold_point.add_child(held_item)
	held_item.transform = Transform3D.IDENTITY
	held_item.set_held(true)
