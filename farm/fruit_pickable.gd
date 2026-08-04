class_name FruitPickable
extends Area3D

@export var crop_id: String = ""
@export var unripe_node_name: String = "SM_Apple_Unripe"
@export var regrow_time: float = 60.0
## Fraction of regrow_time at which the unripe model appears (0.0-1.0)
@export_range(0.0, 1.0) var unripe_at: float = 0.5

var _regrowing: bool = false
var _timer: float = 0.0
var _unripe_shown: bool = false

func _ready() -> void:
	add_to_group("fruit_pickable")
	var unripe = _get_unripe()
	if unripe:
		unripe.visible = false

func _process(delta: float) -> void:
	if not _regrowing:
		return
	_timer += delta
	# Show unripe once we hit the threshold
	if not _unripe_shown and _timer >= regrow_time * unripe_at:
		_unripe_shown = true
		var unripe = _get_unripe()
		if unripe:
			unripe.visible = true
	if _timer >= regrow_time:
		_finish_regrow()

func pick() -> void:
	if _regrowing:
		return
	if crop_id != "":
		Inventory.add_item(crop_id, 1)
	_start_regrow()

func _get_unripe() -> Node3D:
	var group_node = get_parent().get_parent()
	return group_node.get_node_or_null(unripe_node_name)

func _start_regrow() -> void:
	_regrowing = true
	_timer = 0.0
	_unripe_shown = false
	get_parent().visible = false
	var unripe = _get_unripe()
	if unripe:
		unripe.visible = false
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", true)

func _finish_regrow() -> void:
	_regrowing = false
	_unripe_shown = false
	get_parent().visible = true
	var unripe = _get_unripe()
	if unripe:
		unripe.visible = false
	for child in get_children():
		if child is CollisionShape3D:
			child.disabled = false
