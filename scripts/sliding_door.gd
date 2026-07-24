extends Node3D

const SLIDE_DIST: float = 1.2
const TWEEN_TIME: float = 0.4

var _open: bool = false
var _bodies: int = 0
var _left_closed_z: float
var _right_closed_z: float

@onready var _left: Node3D = $DoorMesh_Left
@onready var _right: Node3D = $DoorMesh_Right
@onready var _area: Area3D = $DoorTrigger

func _ready() -> void:
	_left_closed_z = _left.position.z
	_right_closed_z = _right.position.z
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		_bodies += 1
		if not _open:
			_open = true
			_slide(true)

func _on_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D:
		_bodies = max(0, _bodies - 1)
		if _bodies == 0 and _open:
			_open = false
			_slide(false)

func _slide(opening: bool) -> void:
	var lz = (_left_closed_z + SLIDE_DIST) if opening else _left_closed_z
	var rz = (_right_closed_z - SLIDE_DIST) if opening else _right_closed_z
	var t = create_tween().set_parallel(true)
	t.tween_property(_left, "position:z", lz, TWEEN_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(_right, "position:z", rz, TWEEN_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
