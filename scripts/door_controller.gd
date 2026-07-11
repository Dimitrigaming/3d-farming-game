extends Node3D

var _open: bool = false
var _tweening: bool = false
var _bodies_inside: int = 0

@onready var _door: Node3D = $Door
@onready var _door2: Node3D = $Door2
@onready var _area: Area3D = $DoorEntrance

const OPEN_X_1: float = 2.0
const CLOSE_X_1: float = 1.0
const OPEN_X_2: float = -2.0
const CLOSE_X_2: float = -1.0
const TWEEN_TIME: float = 0.4

func _ready() -> void:
	_door.position.x = CLOSE_X_1
	_door2.position.x = CLOSE_X_2
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		_bodies_inside += 1
		if not _open:
			_open = true
			_tween_doors()

func _on_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D:
		_bodies_inside = max(0, _bodies_inside - 1)
		if _bodies_inside == 0 and _open:
			_open = false
			_tween_doors()

func _tween_doors() -> void:
	_tweening = true
	var target1 = OPEN_X_1 if _open else CLOSE_X_1
	var target2 = OPEN_X_2 if _open else CLOSE_X_2
	var t = create_tween().set_parallel(true)
	t.tween_property(_door, "position:x", target1, TWEEN_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(_door2, "position:x", target2, TWEEN_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await t.finished
	_tweening = false
