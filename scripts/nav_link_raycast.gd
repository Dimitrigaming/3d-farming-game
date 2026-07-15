extends NavigationLink3D

@export var wall_mask: int = 4

var _ray: RayCast3D
var _tick: float = 0.0

func _ready() -> void:
	enabled = false
	_ray = get_node_or_null("RayCast3D")
	if not _ray:
		_log("ERROR: no RayCast3D child found on " + name)
		return
	_ray.position = start_position
	_ray.target_position = end_position - start_position
	_ray.collision_mask = wall_mask
	_ray.collide_with_bodies = true
	_ray.collide_with_areas = false
	_ray.enabled = true
	_log("ready — ray from %s to %s mask=%d" % [start_position, end_position, wall_mask])

func _physics_process(delta: float) -> void:
	if not _ray:
		return
	_tick += delta
	if _ray.is_colliding():
		enabled = false
		if _tick >= 1.0:
			_tick = 0.0
			_log("BLOCKED by: " + str(_ray.get_collider().name))
	else:
		if not enabled:
			_log("CLEAR — enabling link")
		enabled = true

func _log(msg: String) -> void:
	var full = "[NavLink %s] %s" % [name, msg]
	if has_node("/root/DebugConsole"):
		get_node("/root/DebugConsole").print_line(full)
	print(full)
