class_name FruitPickable
extends Area3D

@export var crop_id: String = ""
@export var unripe_node_name: String = "SM_Apple_Unripe"
@export var regrow_time: float = 60.0

var _regrowing: bool = false
var _timer: float = 0.0

func _ready() -> void:
	add_to_group("fruit_pickable")
	# Unripe sibling starts hidden
	var unripe = _get_unripe()
	if unripe:
		unripe.visible = false

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

func _get_unripe() -> Node3D:
	# Unripe is a sibling of our parent mesh, both under the AppleN group node
	var group_node = get_parent().get_parent()
	return group_node.get_node_or_null(unripe_node_name)

func _start_regrow() -> void:
	_regrowing = true
	_timer = 0.0
	get_parent().visible = false
	var unripe = _get_unripe()
	if unripe:
		unripe.visible = true
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", true)

func _finish_regrow() -> void:
	_regrowing = false
	get_parent().visible = true
	var unripe = _get_unripe()
	if unripe:
		unripe.visible = false
	for child in get_children():
		if child is CollisionShape3D:
			child.disabled = false
