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

# ProductionArea base geometry (tier 0) — matches Map.tscn CollisionShape3D
const PROD_BASE_SIZE_X: float   = 21.1
const PROD_BASE_SIZE_Z: float   = 24.8
const PROD_BASE_CENTER_X: float = -31.85

@export var current_tier: int = 0 : set = set_tier

const _MAT_GLASS:  Material = preload("res://materials/mat_Glass.tres")
const _MAT_OPAQUE: Material = preload("res://materials/mat_Opaque_Glass.tres")

@export_group("Tier 1 Glass")
@export var tier1_glass_a: MeshInstance3D
@export var tier1_glass_b: MeshInstance3D

@export_group("Tier 2 Glass")
@export var tier2_glass_a: MeshInstance3D
@export var tier2_glass_b: MeshInstance3D

@export_group("Tier 3 Glass")
@export var tier3_glass_a: MeshInstance3D
@export var tier3_glass_b: MeshInstance3D

@export_group("Tier 4 Glass")
@export var tier4_glass_a: MeshInstance3D
@export var tier4_glass_b: MeshInstance3D

@export_group("Tier 5 Glass")
@export var tier5_glass_a: MeshInstance3D
@export var tier5_glass_b: MeshInstance3D

@export_group("")

@onready var _right:   CSGBox3D = $RightWall
@onready var _left:    CSGBox3D = $LeftWall
@onready var _back3:   CSGBox3D = $BackWall3
@onready var _front:   CSGBox3D = $BackWall
@onready var _front2:  CSGBox3D = $BackWall2

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

	_sync_wall_collision(_right)
	_sync_wall_collision(_left)
	_sync_wall_collision(_back3)
	_sync_wall_collision(_front)
	_sync_wall_collision(_front2)

	_apply_glass_tiers(t)
	_resize_production_area(t)

func _sync_wall_collision(wall: CSGBox3D) -> void:
	var body = wall.get_node_or_null("StaticBody3D")
	if body == null:
		return
	var cs = body.get_node_or_null("CollisionShape3D")
	if cs == null:
		return
	var shape = BoxShape3D.new()
	shape.size = wall.size
	cs.shape = shape

func _resize_production_area(t_p: int) -> void:
	var area = get_tree().get_first_node_in_group("ProductionFloorArea")
	if area == null:
		return
	var cs = area.get_node_or_null("CollisionShape3D")
	if cs == null:
		return
	var t_s = GameState.shop_floor_tier
	var shape = BoxShape3D.new()
	shape.size = Vector3(
		PROD_BASE_SIZE_X + BACK_DELTA * t_p,
		6.0,
		PROD_BASE_SIZE_Z + SIDE_DELTA * 2.0 * t_p)
	cs.shape = shape
	cs.position.x = PROD_BASE_CENTER_X - (BACK_DELTA / 2.0) * t_p - BACK_DELTA * t_s

func _set_glass(node: MeshInstance3D, unlocked: bool) -> void:
	if node == null:
		return
	node.set_surface_override_material(0, _MAT_GLASS if unlocked else _MAT_OPAQUE)

func _apply_glass_tiers(t: int) -> void:
	_set_glass(tier1_glass_a, t >= 1); _set_glass(tier1_glass_b, t >= 1)
	_set_glass(tier2_glass_a, t >= 2); _set_glass(tier2_glass_b, t >= 2)
	_set_glass(tier3_glass_a, t >= 3); _set_glass(tier3_glass_b, t >= 3)
	_set_glass(tier4_glass_a, t >= 4); _set_glass(tier4_glass_b, t >= 4)
	_set_glass(tier5_glass_a, t >= 5); _set_glass(tier5_glass_b, t >= 5)

func upgrade() -> bool:
	if current_tier >= MAX_TIER:
		return false
	set_tier(current_tier + 1)
	return true
