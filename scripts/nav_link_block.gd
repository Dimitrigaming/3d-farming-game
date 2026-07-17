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
			var collider_name: String = ray.get_collider().name
			if not entry.get("logged_blocked", false):
				entry["logged_blocked"] = true
				_log(link.name + " BLOCKED by " + collider_name)
			if collider_name == "RaycastBlocker_StaticBody3D":
				_log(link.name + " — permanent wall, removing")
				ray.queue_free()
				link.queue_free()
			else:
				still_pending.append(entry)
		else:
			link.enabled = true
			ray.enabled = false
			_log(link.name + " CLEAR — enabled")
	_links = still_pending
	if _links.is_empty():
		set_physics_process(false)

func _log(msg: String) -> void:
	var logger = get_node_or_null("/root/GameLogger")
	if logger:
		logger.debug("NavLinkBlock", msg)
	else:
		print("[NavLinkBlock] " + msg)
