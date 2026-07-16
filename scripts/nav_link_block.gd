extends Node3D

class_name NavLinkBlockManager

# Each entry: { link, ray, last_blocked }
var _links: Array = []

func _ready() -> void:
	for link in find_children("*", "NavigationLink3D", true, false):
		var ray = link.find_child("*", true, false)
		if ray is RayCast3D:
			_links.append({ "link": link, "ray": ray, "last_blocked": true })
		else:
			push_warning("NavLinkBlock: NavigationLink3D '%s' has no RayCast3D child" % link.name)

func _physics_process(_delta: float) -> void:
	for entry in _links:
		var ray: RayCast3D = entry["ray"]
		var link: NavigationLink3D = entry["link"]
		var blocked: bool = ray.is_colliding()

		if blocked != entry["last_blocked"]:
			entry["last_blocked"] = blocked
			link.enabled = not blocked
			if blocked:
				_log(link.name + " BLOCKED by " + str(ray.get_collider().name))
			else:
				_log(link.name + " CLEAR — enabled")
				ray.enabled = false

func _log(msg: String) -> void:
	var full = "[NavLinkBlock] " + msg
	if has_node("/root/DebugConsole"):
		get_node("/root/DebugConsole").print_line(full)
	print(full)
