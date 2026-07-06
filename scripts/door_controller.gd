extends Node3D

var _open: bool = false
var _tweening: bool = false

@onready var _door: Node3D = $DoorFrame/Door
@onready var _door2: Node3D = $DoorFrame/Door2

const OPEN_ROT_1: float = 130.0
const CLOSE_ROT_1: float = 0.0
const OPEN_ROT_2: float = 50.0
const CLOSE_ROT_2: float = 180.0
const TWEEN_TIME: float = 0.5

func _ready() -> void:
	add_to_group("interactable")
	_door.rotation_degrees.y = CLOSE_ROT_1
	_door2.rotation_degrees.y = CLOSE_ROT_2

func show_tooltip() -> void:
	pass

func hide_tooltip() -> void:
	pass

func get_click_hint(_player_inventory) -> String:
	return "Close Door" if _open else "Open Door"

func interact() -> void:
	if _tweening:
		return
	_open = not _open
	_tween_doors()

func _tween_doors() -> void:
	_tweening = true
	var target1 = OPEN_ROT_1 if _open else CLOSE_ROT_1
	var target2 = OPEN_ROT_2 if _open else CLOSE_ROT_2

	var t = create_tween().set_parallel(true)
	t.tween_property(_door, "rotation_degrees:y", target1, TWEEN_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(_door2, "rotation_degrees:y", target2, TWEEN_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await t.finished
	_tweening = false
