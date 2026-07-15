extends NavigationLink3D

@export var wall_mask: int = 4

var _ray: RayCast3D

func _ready() -> void:
	enabled = false
	_ray = get_node_or_null("RayCast3D")
	if not _ray:
		push_warning(name + ": no RayCast3D child found")
		return
	# aim the ray from start to end in local space
	_ray.position = start_position
	_ray.target_position = end_position - start_position
	_ray.collision_mask = wall_mask
	_ray.collide_with_bodies = true
	_ray.collide_with_areas = false
	_ray.enabled = true

func _physics_process(_delta: float) -> void:
	if not _ray:
		return
	if _ray.is_colliding():
		var hit = _ray.get_collider()
		print("[NavLink %s] hitting: %s at %s" % [name, hit.name, _ray.get_collision_point()])
		enabled = false
	else:
		enabled = true
