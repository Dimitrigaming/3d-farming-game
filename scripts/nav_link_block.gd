extends Node3D

var _rays: Array = []
var _nav_link: NavigationLink3D
var _last_blocked: bool = true  # assume blocked until proven clear

func _ready() -> void:
	_rays = find_children("*", "RayCast3D", true, false)
	_nav_link = find_child("*", true, false) as NavigationLink3D
	if not _nav_link:
		push_warning("NavLinkBlock: no NavigationLink3D found")

func _physics_process(_delta: float) -> void:
	var blocked = false
	var hit_name := ""
	for ray in _rays:
		if (ray as RayCast3D).is_colliding():
			blocked = true
			hit_name = ray.name + " → " + str((ray as RayCast3D).get_collider().name)
			break

	if blocked != _last_blocked:
		_last_blocked = blocked
		if blocked:
			_log("BLOCKED by " + hit_name)
		else:
			_log("CLEAR — enabling nav link")
		if _nav_link:
			_nav_link.enabled = not blocked

func _log(msg: String) -> void:
	var full = "[NavLinkBlock %s] %s" % [name, msg]
	if has_node("/root/DebugConsole"):
		get_node("/root/DebugConsole").print_line(full)
	print(full)
