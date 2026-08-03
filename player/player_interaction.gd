extends RayCast3D

var _highlight: MeshInstance3D = null
var _prompt_label: Label = null
var _hovered_cell: Vector3i = Vector3i(-1, -1, -1)
var _hovered_farm = null
var _current_interactable = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	target_position = Vector3(0, 0, -10.0)
	collision_mask = 0xFFFFFFFF
	enabled = true
	_setup_highlight()
	_setup_prompt()

func _setup_highlight() -> void:
	_highlight = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(1.0, 0.02, 1.0)
	_highlight.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.2, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	_highlight.material_override = mat
	_highlight.visible = false
	_highlight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().get_root().call_deferred("add_child", _highlight)

func _find_interactable(node: Node) -> Node:
	for _i in range(6):
		if node == null:
			break
		if node.is_in_group("interactable"):
			if node.has_meta("interact_owner"):
				return node.get_meta("interact_owner")
			return node
		node = node.get_parent()
	return null

func _setup_prompt() -> void:
	var canvas = CanvasLayer.new()
	canvas.layer = 10
	_prompt_label = Label.new()
	_prompt_label.text = "[E] Open Shop"
	_prompt_label.add_theme_font_size_override("font_size", 20)
	_prompt_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_prompt_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	_prompt_label.add_theme_constant_override("shadow_offset_x", 2)
	_prompt_label.add_theme_constant_override("shadow_offset_y", 2)
	_prompt_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_prompt_label.offset_top = 60
	_prompt_label.offset_bottom = 90
	_prompt_label.visible = false
	canvas.add_child(_prompt_label)
	get_tree().get_root().call_deferred("add_child", canvas)

func _process(_delta: float) -> void:
	_hovered_cell = Vector3i(-1, -1, -1)
	_hovered_farm = null

	if _prompt_label:
		_prompt_label.visible = false
	if _highlight:
		_highlight.visible = false

	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		_current_interactable = null
		return

	var hit = get_collider()

	# Check for interactable (shop, NPC, etc.)
	_current_interactable = _find_interactable(hit)

	if _current_interactable != null:
		if _prompt_label and _current_interactable.has_method("get_interact_hint"):
			_prompt_label.text = "[E] %s" % _current_interactable.get_interact_hint()
			_prompt_label.visible = true
		return

	# Farm tile highlighting
	if hit == null:
		return

	var equipper = get_tree().get_first_node_in_group("tool_equipper")
	if not equipper:
		return

	var item_id = equipper.current_item_id
	var target_state: int
	var highlight_color: Color
	match item_id:
		"hoe":
			target_state = 1
			highlight_color = Color(1.0, 0.85, 0.2, 0.5)
		"shovel":
			target_state = 2
			highlight_color = Color(1.0, 0.35, 0.2, 0.5)
		_:
			return

	var farm = get_tree().get_first_node_in_group("farm_grid")
	if not farm:
		return

	var hit_pos = get_collision_point()
	var cell = _world_to_cell(farm, hit_pos)
	if farm.cell_state.get(cell, -1) != target_state:
		return

	(_highlight.material_override as StandardMaterial3D).albedo_color = highlight_color
	_highlight.global_position = _cell_to_world(farm, cell)
	_highlight.visible = true
	_hovered_cell = cell
	_hovered_farm = farm

func _unhandled_input(event: InputEvent) -> void:
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return

	if event.is_action_pressed("interact") and _current_interactable != null:
		_current_interactable.interact()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _hovered_farm == null or _hovered_cell == Vector3i(-1, -1, -1):
			return
		var equipper = get_tree().get_first_node_in_group("tool_equipper")
		if not equipper:
			return
		match equipper.current_item_id:
			"hoe":
				_hovered_farm.till_cell(_hovered_cell.x, _hovered_cell.z)
			"shovel":
				_hovered_farm.untill_cell(_hovered_cell.x, _hovered_cell.z)

func _world_to_cell(farm: Node3D, world_pos: Vector3) -> Vector3i:
	var local = farm.grid_map.to_local(world_pos)
	return farm.grid_map.local_to_map(local)

func _cell_to_world(farm: Node3D, cell: Vector3i) -> Vector3:
	var local = farm.grid_map.map_to_local(cell)
	return farm.grid_map.to_global(Vector3(local.x, local.y + 0.04, local.z))
