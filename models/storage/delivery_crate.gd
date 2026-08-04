class_name DeliveryCrate
extends Node3D

const CHEST_UI_SCENE = preload("res://ui/chest_ui.tscn")
const CRATE_SLOT_COUNT = 27

@export var open_angle: float = 40.0

var crate_slots: Array[Dictionary] = []
var _open: bool = false
var _tween: Tween = null
var _chest_ui = null

@onready var _lid: Node3D = $Crate_base/Crate_Lid

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("delivery_crate")
	crate_slots.resize(CRATE_SLOT_COUNT)
	for i in CRATE_SLOT_COUNT:
		crate_slots[i] = {"item_id": "", "amount": 0}

func get_interact_hint() -> String:
	return "Open Delivery Crate"

func interact() -> void:
	var chest_ui = get_tree().get_first_node_in_group("chest_ui")
	if chest_ui != null and chest_ui.visible and chest_ui._current_crate == self:
		chest_ui.close()
		return
	if chest_ui == null:
		chest_ui = CHEST_UI_SCENE.instantiate()
		get_tree().get_root().add_child(chest_ui)
	_chest_ui = chest_ui
	chest_ui.open(self)
	if not _open:
		_toggle_lid()

func refresh_ui() -> void:
	var chest_ui = get_tree().get_first_node_in_group("chest_ui")
	if chest_ui and chest_ui._current_crate == self:
		chest_ui.chest_slots = []
		for s in crate_slots:
			chest_ui.chest_slots.append(s.duplicate())
		chest_ui.refresh_chest()

func get_move_hint() -> String:
	return "Move"

func get_lid_hint() -> String:
	return "Close" if _open else "Open"

func _toggle_lid() -> void:
	_open = not _open
	if _tween:
		_tween.kill()
	_tween = create_tween()
	var target_angle = open_angle if _open else 0.0
	_tween.tween_property(_lid, "rotation_degrees:x", target_angle, 0.3) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
