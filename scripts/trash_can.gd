extends Node3D

@onready var lid: Node3D = $Lid

var _lid_open: bool = false

func _ready() -> void:
	add_to_group("interactable")

func show_tooltip() -> void:
	pass

func hide_tooltip() -> void:
	pass

func interact() -> void:
	pass

func on_aimed_at(player_inventory) -> void:
	if player_inventory.held_box != null and not _lid_open:
		_set_lid(true)

func on_look_away() -> void:
	if _lid_open:
		_set_lid(false)

func try_trash(player_inventory) -> void:
	if player_inventory.held_box == null:
		return
	var box = player_inventory.held_box
	player_inventory.held_box = null
	box.get_parent().remove_child(box)
	box.queue_free()
	_set_lid(false)

func _set_lid(open: bool) -> void:
	_lid_open = open
	var tween = get_tree().create_tween()
	var target_x = -35.0 if open else 0.0
	tween.tween_property(lid, "rotation_degrees:x", target_x, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
