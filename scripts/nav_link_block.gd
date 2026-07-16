extends Node3D

class_name NavLinkBlockManager

var _links: Array = []

func _ready() -> void:
	set_physics_process(false)
	for link in find_children("*", "NavigationLink3D", true, false):
		link.enabled = false
		var ray = link.find_child("*", true, false)
		if ray is RayCast3D:
			_links.append({ "link": link, "ray": ray })
		else:
			push_warning("NavLinkBlock: NavigationLink3D '%s' has no RayCast3D child" % link.name)
	await get_tree().physics_frame
	await get_tree().physics_frame
	set_physics_process(true)

func _physics_process(_delta: float) -> void:
	var still_pending: Array = []
	for entry in _links:
		var ray: RayCast3D = entry["ray"]
		var link: NavigationLink3D = entry["link"]
		if ray.is_colliding():
			still_pending.append(entry)
		else:
			link.enabled = true
			ray.enabled = false
			_log(link.name + " CLEAR — enabled")
	_links = still_pending
	if _links.is_empty():
		set_physics_process(false)

func _log(msg: String) -> void:
	var full = "[NavLinkBlock] " + msg
	if has_node("/root/DebugConsole"):
		get_node("/root/DebugConsole").print_line(full)
	print(full)
