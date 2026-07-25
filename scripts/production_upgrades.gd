extends Node3D

const SIDE_DELTA: float = 1.64
const BACK_DELTA: float = 2.5

# Tier 0 geometry (local to ProductionTiers node)
const RIGHT_BASE_Z: float    = 4.3
const LEFT_BASE_Z: float     = -4.3
const RIGHT_FRONT_X: float   = 1.965   # fixed front edge of RightWall
const LEFT_FRONT_X: float    = 1.903   # fixed front edge of LeftWall
const BACK3_BASE_X: float    = -6.707  # BackWall3 starting X
const BACK3_BASE_SIZE_Z: float = 8.6   # BackWall3 starting width

# Doorway gap: inner edges of front panels are fixed at ±BACK_INNER_Z
const BACK_INNER_Z: float = 2.6

const MAX_TIER: int = 5

@export var current_tier: int = 0 : set = set_tier

@onready var _right:   CSGBox3D = $RightWall
@onready var _left:    CSGBox3D = $LeftWall
@onready var _back3:   CSGBox3D = $BackWall3
@onready var _front:   CSGBox3D = $BackWall
@onready var _front2:  CSGBox3D = $BackWall2
@onready var _doorway: Node3D   = $ProductionFloorDoorway

func _ready() -> void:
	add_to_group("production_tiers")
	set_tier(current_tier)

func set_tier(tier: int) -> void:
	current_tier = clamp(tier, 0, MAX_TIER)
	var t = current_tier

	# Back wall moves in -X and widens to track side walls
	var back_x = BACK3_BASE_X - BACK_DELTA * t
	_back3.position.x = back_x
	_back3.size.z = BACK3_BASE_SIZE_Z + SIDE_DELTA * 2.0 * t

	# Side walls: front edge fixed, back edge tracks BackWall3
	var new_size_x = RIGHT_FRONT_X - back_x
	_right.position.x = RIGHT_FRONT_X - new_size_x / 2.0
	_right.position.z = RIGHT_BASE_Z + SIDE_DELTA * t
	_right.size.x = new_size_x

	new_size_x = LEFT_FRONT_X - back_x
	_left.position.x = LEFT_FRONT_X - new_size_x / 2.0
	_left.position.z = LEFT_BASE_Z - SIDE_DELTA * t
	_left.size.x = new_size_x

	# Front face panels: inner edge fixed at ±BACK_INNER_Z, outer tracks side walls
	var outer_z  = RIGHT_BASE_Z + SIDE_DELTA * t
	var panel_sz = outer_z - BACK_INNER_Z
	_front2.position.z = (BACK_INNER_Z + outer_z) / 2.0
	_front2.size.z     = panel_sz
	_front.position.z  = -((BACK_INNER_Z + outer_z) / 2.0)
	_front.size.z      = panel_sz

func upgrade() -> bool:
	if current_tier >= MAX_TIER:
		return false
	set_tier(current_tier + 1)
	return true
