extends Node3D

var _rays: Array = []

func _ready() -> void:
	_rays = find_children("*", "RayCast3D", true, false)

func _physics_process(_delta: float) -> void:
	for ray in _rays:
		if ray.is_colliding():
			_log(ray.name + " hit: " + str(ray.get_collider().name))

func _log(msg: String) -> void:
	var full = "[NavLinkBlock] " + msg
	if has_node("/root/DebugConsole"):
		get_node("/root/DebugConsole").print_line(full)
	print(full)
