extends NavigationLink3D

# Collision mask matching the Interior Block blocker walls (collision_layer = 4)
@export var wall_mask: int = 4
# Sphere radius for the sweep — large enough to catch the thin blocker walls
@export var sweep_radius: float = 1.5
@export var check_interval: float = 0.5

var _timer: float = 0.0
var _shape: SphereShape3D

func _ready() -> void:
	enabled = false
	_shape = SphereShape3D.new()
	_shape.radius = sweep_radius
	await get_tree().physics_frame
	_check()

func _physics_process(delta: float) -> void:
	_timer += delta
	if _timer >= check_interval:
		_timer = 0.0
		_check()

func _check() -> void:
	var from = to_global(start_position)
	var to_pos = to_global(end_position)

	var params = PhysicsShapeQueryParameters3D.new()
	params.shape = _shape
	params.transform = Transform3D(Basis.IDENTITY, from)
	params.motion = to_pos - from
	params.collision_mask = wall_mask

	var result = get_world_3d().direct_space_state.cast_motion(params)
	# result is [safe_fraction, unsafe_fraction]; safe < 1.0 means a wall was hit
	enabled = result.is_empty() or result[0] >= 1.0
