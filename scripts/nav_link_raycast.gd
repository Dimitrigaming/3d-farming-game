extends NavigationLink3D

# Collision mask matching the Interior Block blocker walls (collision_layer = 4)
@export var wall_mask: int = 4
@export var check_interval: float = 0.5

var _timer: float = 0.0

func _ready() -> void:
	enabled = false
	await get_tree().physics_frame
	_check()

func _physics_process(delta: float) -> void:
	_timer += delta
	if _timer >= check_interval:
		_timer = 0.0
		_check()

func _check() -> void:
	var space = get_world_3d().direct_space_state
	var from = to_global(start_position)
	var to_pos = to_global(end_position)
	var query = PhysicsRayQueryParameters3D.create(from, to_pos, wall_mask)
	enabled = space.intersect_ray(query).is_empty()
