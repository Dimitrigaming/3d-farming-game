extends NavigationLink3D

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
	var from = to_global(start_position)
	var to_pos = to_global(end_position)
	for block in get_tree().get_nodes_in_group("interior_block"):
		if _xz_dist_to_segment((block as Node3D).global_position, from, to_pos) < block_radius:
			enabled = false
			return
	enabled = true

func _xz_dist_to_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ap = Vector2(p.x - a.x, p.z - a.z)
	var ab = Vector2(b.x - a.x, b.z - a.z)
	var len_sq = ab.length_squared()
	if len_sq < 0.0001:
		return ap.length()
	var t = clamp(ap.dot(ab) / len_sq, 0.0, 1.0)
	return (ap - ab * t).length()
