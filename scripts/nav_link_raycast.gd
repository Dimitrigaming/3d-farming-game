extends NavigationLink3D

# How close an interior block must be to end_position to count as blocking
@export var block_radius: float = 2.5
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
	var end_global = to_global(end_position)
	for block in get_tree().get_nodes_in_group("interior_block"):
		if (block as Node3D).global_position.distance_to(end_global) < block_radius:
			enabled = false
			return
	enabled = true
