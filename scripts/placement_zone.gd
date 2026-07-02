extends CSGBox3D

const MAX_PRINTS: int = 6

var stored_box: Node3D = null
var stored_print_type: String = ""
var stored_print_nodes: Array[Node3D] = []

func _ready() -> void:
	visible = false

func is_occupied() -> bool:
	return stored_box != null or stored_print_nodes.size() >= MAX_PRINTS

func has_prints() -> bool:
	return stored_print_nodes.size() > 0
