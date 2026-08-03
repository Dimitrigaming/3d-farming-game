extends Node3D

var current_item_id: String = ""
var _equipped: Node3D = null
var _hand: Node3D = null

func _ready() -> void:
	add_to_group("tool_equipper")
_hand = Node3D.new()
	_hand.name = "Hand"
	_hand.position = Vector3(0.35, -0.3, -0.5)
	var camera = _find_camera(get_parent())
	if camera:
		camera.add_child(_hand)
	else:
		push_warning("ToolEquipper: no Camera3D found in parent.")

func equip(item_id: String) -> void:
	current_item_id = item_id
	if _equipped:
		_equipped.queue_free()
		_equipped = null
	if item_id == "" or _hand == null:
		return
	var def = ItemDB.get_item(item_id)
	if def == null or def.equip_scene == null:
		return
	_equipped = def.equip_scene.instantiate()
	_hand.add_child(_equipped)

func _find_camera(node: Node) -> Camera3D:
	if node is Camera3D:
		return node
	for child in node.get_children():
		var result = _find_camera(child)
		if result:
			return result
	return null
