extends Node3D

# Per-tier deltas
const SIDE_DELTA: float = 1.64   # each side wall moves out this much per tier
const BACK_DELTA: float = 2.5    # back wall moves this much per tier

# Base geometry (tier 0)
const RIGHT_BASE_Z: float = 4.3
const LEFT_BASE_Z: float = -4.3
const BACK_BASE_X: float = 2.0
const RIGHT_FRONT_X: float = 10.565  # front edge of RightWall, stays fixed
const LEFT_FRONT_X: float = 10.603   # front edge of LeftWall, stays fixed
const SIDE_BASE_SIZE_X: float = 8.6
const BACK_BASE_SIZE_Z: float = 8.6

const MAX_TIER: int = 5

@export var current_tier: int = 0 : set = set_tier

@onready var _right: CSGBox3D = $RightWall
@onready var _left: CSGBox3D = $LeftWall
@onready var _back: CSGBox3D = $BackWall

func _ready() -> void:
	set_tier(current_tier)

func set_tier(tier: int) -> void:
	current_tier = clamp(tier, 0, MAX_TIER)
	var t = current_tier

	# Side walls: move out on Z, extend deeper on X as back moves back
	var new_size_x = SIDE_BASE_SIZE_X + BACK_DELTA * t
	var right_center_x = RIGHT_FRONT_X - new_size_x / 2.0
	var left_center_x = LEFT_FRONT_X - new_size_x / 2.0

	_right.position.z = RIGHT_BASE_Z + SIDE_DELTA * t
	_right.position.x = right_center_x
	_right.size.x = new_size_x

	_left.position.z = LEFT_BASE_Z - SIDE_DELTA * t
	_left.position.x = left_center_x
	_left.size.x = new_size_x

	# Back wall: move in -X, extend wider on Z as sides move out
	_back.position.x = BACK_BASE_X - BACK_DELTA * t
	_back.size.z = BACK_BASE_SIZE_Z + SIDE_DELTA * 2.0 * t

func upgrade() -> bool:
	if current_tier >= MAX_TIER:
		return false
	set_tier(current_tier + 1)
	return true
