class_name FruitPickable
extends Area3D

@export var crop_id: String = ""
@export var unripe_scene: PackedScene
@export var regrow_time: float = 60.0

var _regrowing: bool = false
var _timer: float = 0.0
var _unripe_instance: Node3D = null

func _ready() -> void:
	add_to_group("fruit_pickable")

func _process(delta: float) -> void:
	if not _regrowing:
		return
	_timer += delta
	if _timer >= regrow_time:
		_finish_regrow()

func pick() -> void:
	if _regrowing:
		return
	if crop_id != "":
		Inventory.add_item(crop_id, 1)
	_start_regrow()

func _start_regrow() -> void:
	_regrowing = true
	_timer = 0.0
	# Hide the ripe fruit mesh
	var fruit_mesh = get_parent()
	if fruit_mesh:
		fruit_mesh.visible = false
	# Disable collision so it can't be picked again while regrowing
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", true)
	# Spawn unripe model at the same world position
	if unripe_scene and fruit_mesh:
		_unripe_instance = unripe_scene.instantiate()
		fruit_mesh.get_parent().add_child(_unripe_instance)
		_unripe_instance.global_transform = fruit_mesh.global_transform

func _finish_regrow() -> void:
	_regrowing = false
	# Remove unripe model
	if _unripe_instance:
		_unripe_instance.queue_free()
		_unripe_instance = null
	# Show ripe fruit again
	var fruit_mesh = get_parent()
	if fruit_mesh:
		fruit_mesh.visible = true
	# Re-enable collision
	for child in get_children():
		if child is CollisionShape3D:
			child.disabled = false
