extends CSGBox3D

const MAX_PRINTS: int = 6

var stored_box: Node3D = null
var stored_print_type: String = ""
var stored_print_nodes: Array[Node3D] = []

func _ready() -> void:
	visible = false
	add_to_group("interactable")
	add_to_group("placement_zone")
	_sync_collision()

func _sync_collision() -> void:
	var area = get_node_or_null("Area3D")
	if area == null:
		return
	var cs = area.get_node_or_null("CollisionShape3D")
	if cs == null or not cs.shape is BoxShape3D:
		return
	cs.shape.size = size

func is_occupied() -> bool:
	return stored_box != null or stored_print_nodes.size() >= MAX_PRINTS

func has_prints() -> bool:
	return stored_print_nodes.size() > 0

func show_tooltip() -> void:
	pass

func hide_tooltip() -> void:
	pass

func get_click_hint(player_inventory) -> String:
	var held = player_inventory.held_item
	if held != null and held.has_method("unpack_at"):
		return "Place Here"
	return ""

func interact() -> void:
	var player_inv = get_tree().get_first_node_in_group("player")
	if player_inv == null:
		return
	var held = player_inv.held_item
	if held == null or not held.has_method("unpack_at"):
		return
	var build_mode = player_inv.get_parent().get_node_or_null("BuildMode")
	if build_mode == null or build_mode.active:
		return
	var unpacked = player_inv.unpack_held_item()
	if unpacked:
		build_mode.enter(unpacked)
		build_mode.snap_to_zone(self)
