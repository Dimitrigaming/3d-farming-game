extends Node3D

const SIDE_DELTA: float = 1.64   # each side wall moves out on Z per tier
const BACK_DELTA: float = 2.5    # back wall moves in -X per tier

# Tier 0 geometry
const RIGHT_BASE_Z: float   = 4.3
const LEFT_BASE_Z: float    = -4.3
const BACK_BASE_X: float    = 2.0
const RIGHT_FRONT_X: float  = 10.565   # front (door-side) edge of RightWall, stays fixed
const LEFT_FRONT_X: float   = 10.603   # front edge of LeftWall, stays fixed
const SIDE_BASE_SIZE_X: float = 8.6    # depth of side walls at tier 0

# Back wall panels flank a fixed-width doorway centered at Z=0.
# Inner edges of the two panels are fixed; outer edges track the side walls.
const BACK_INNER_Z: float   = 2.6     # inner edge of each back panel (half doorway gap)

const MAX_TIER: int = 5

@export var current_tier: int = 0 : set = set_tier

@onready var _right:   CSGBox3D = $RightWall
@onready var _left:    CSGBox3D = $LeftWall
@onready var _back:    CSGBox3D = $BackWall
@onready var _back2:   CSGBox3D = $BackWall2
@onready var _doorway: Node3D   = $ShopFloorDoorway

func _ready() -> void:
	add_to_group("building_tiers")
	set_tier(current_tier)

func set_tier(tier: int) -> void:
	current_tier = clamp(tier, 0, MAX_TIER)
	var t = current_tier

	# --- Side walls ---
	# Move outward on Z; extend deeper on X so they stay flush with the back wall.
	var new_size_x = SIDE_BASE_SIZE_X + BACK_DELTA * t
	_right.position.z = RIGHT_BASE_Z + SIDE_DELTA * t
	_right.position.x = RIGHT_FRONT_X - new_size_x / 2.0
	_right.size.x     = new_size_x

	_left.position.z = LEFT_BASE_Z - SIDE_DELTA * t
	_left.position.x = LEFT_FRONT_X - new_size_x / 2.0
	_left.size.x     = new_size_x

	# --- Back wall X ---
	var back_x = BACK_BASE_X - BACK_DELTA * t

	# --- Back panels ---
	# Outer edges track the side walls; inner edges stay fixed at ±BACK_INNER_Z.
	# panel_size_z = outer_z - BACK_INNER_Z = (base + SIDE_DELTA*t) - BACK_INNER_Z
	var outer_z    = RIGHT_BASE_Z + SIDE_DELTA * t          # 4.3 + 1.64*t
	var panel_sz   = outer_z - BACK_INNER_Z                 # 1.7 + 1.64*t

	# Right panel (BackWall2, positive Z): center between inner and outer edges
	_back2.position.x = back_x
	_back2.position.z = (BACK_INNER_Z + outer_z) / 2.0     # 3.45 + 0.82*t
	_back2.size.z     = panel_sz

	# Left panel (BackWall, negative Z): mirror of right panel
	_back.position.x = back_x
	_back.position.z = -((BACK_INNER_Z + outer_z) / 2.0)   # -(3.45 + 0.82*t)
	_back.size.z     = panel_sz

	# --- Doorway ---
	# Stays centered at Z=0, moves back in X with the back wall.
	_doorway.position.x = back_x

	# --- Shift ProductionTiers to keep its front face aligned with ShopFloorDoorway ---
	var prod = get_tree().get_first_node_in_group("production_tiers")
	if prod:
		prod.position.x = -BACK_DELTA * t

func upgrade() -> bool:
	if current_tier >= MAX_TIER:
		return false
	set_tier(current_tier + 1)
	return true
