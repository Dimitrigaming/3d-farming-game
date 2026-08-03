extends RayCast3D

var _highlight: MeshInstance3D = null
var _prompt_label: Label = null
var _hovered_cell: Vector3i = Vector3i(-1, -1, -1)
var _hovered_farm = null
var _hovered_is_harvestable: bool = false
var _current_interactable = null
var _left_held: bool = false
var _right_held: bool = false
var _last_acted_cell: Vector3i = Vector3i(-1, -1, -1)

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
	_hovered_is_harvestable = false

	if _prompt_label:
		_prompt_label.visible = false
	if _highlight:
		_highlight.visible = false

	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		_current_interactable = null
		_left_held = false
		_right_held = false
		return

	var hit = get_collider()

	_current_interactable = _find_interactable(hit)
	if _current_interactable != null:
		if _prompt_label and _current_interactable.has_method("get_interact_hint"):
			_prompt_label.text = "[E] %s" % _current_interactable.get_interact_hint()
			_prompt_label.visible = true
		return

	if hit == null:
		return

	var farm = get_tree().get_first_node_in_group("farm_grid")
	if not farm:
		return

	var hit_pos = get_collision_point()
	var cell = _world_to_cell(farm, hit_pos)
	var state = farm.cell_state.get(cell, -1)

	var equipper = get_tree().get_first_node_in_group("tool_equipper")
	var item_id = equipper.current_item_id if equipper else ""

	var highlight_color: Color
	var valid := false

	match item_id:
		"hoe":
			if state == farm.DIRT:
				highlight_color = Color(1.0, 0.85, 0.2, 0.5)
				valid = true
		"shovel":
			if state == farm.TILLED:
				highlight_color = Color(1.0, 0.35, 0.2, 0.5)
				valid = true
		_:
			if item_id.ends_with("_seed") and state == farm.TILLED and farm.get_crop(cell.x, cell.z) == null:
				highlight_color = Color(0.2, 1.0, 0.4, 0.5)
				valid = true

	# Harvestable crop — show when scythe equipped
	if not valid and item_id == "scythe" and state == farm.TILLED:
		var crop = farm.get_crop(cell.x, cell.z)
		if crop and crop.is_ready_to_harvest():
			highlight_color = Color(1.0, 0.9, 0.1, 0.6)
			valid = true
			_hovered_is_harvestable = true
			if _prompt_label:
				_prompt_label.text = "[LMB] Harvest"
				_prompt_label.visible = true

	if valid:
		(_highlight.material_override as StandardMaterial3D).albedo_color = highlight_color
		_highlight.global_position = _cell_to_world(farm, cell)
		_highlight.visible = true
		_hovered_cell = cell
		_hovered_farm = farm

	# Held-button continuous use — only fires when moving to a new cell
	if _hovered_farm != null and _hovered_cell != Vector3i(-1, -1, -1) and _hovered_cell != _last_acted_cell:
		var equipper = get_tree().get_first_node_in_group("tool_equipper")
		var item_id = equipper.current_item_id if equipper else ""
		if _left_held:
			_do_left_action(item_id)
		elif _right_held:
			_do_right_action(item_id)

func _do_left_action(item_id: String) -> void:
	match item_id:
		"hoe":
			_hovered_farm.till_cell(_hovered_cell.x, _hovered_cell.z)
			_last_acted_cell = _hovered_cell
		"shovel":
			_hovered_farm.untill_cell(_hovered_cell.x, _hovered_cell.z)
			_last_acted_cell = _hovered_cell
		"scythe":
			if _hovered_is_harvestable:
				var yield_id = _hovered_farm.harvest_crop(_hovered_cell.x, _hovered_cell.z)
				if yield_id != "":
					Inventory.add_item(yield_id)
				_last_acted_cell = _hovered_cell

func _do_right_action(item_id: String) -> void:
	if item_id.ends_with("_seed") and Inventory.has_item(item_id):
		_hovered_farm.plant_crop(_hovered_cell.x, _hovered_cell.z, item_id)
		Inventory.remove_item(item_id)
		_last_acted_cell = _hovered_cell

func _unhandled_input(event: InputEvent) -> void:
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return

	if event.is_action_pressed("interact") and _current_interactable != null:
		_current_interactable.interact()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_left_held = event.pressed
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_right_held = event.pressed
		if event.pressed:
			if _hovered_farm == null or _hovered_cell == Vector3i(-1, -1, -1):
				return
			var equipper = get_tree().get_first_node_in_group("tool_equipper")
			if not equipper:
				return
			var item_id = equipper.current_item_id
			if event.button_index == MOUSE_BUTTON_LEFT:
				_do_left_action(item_id)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				_do_right_action(item_id)

func _world_to_cell(farm: Node3D, world_pos: Vector3) -> Vector3i:
	var local = farm.grid_map.to_local(world_pos)
	return farm.grid_map.local_to_map(local)

func _cell_to_world(farm: Node3D, cell: Vector3i) -> Vector3:
	var local = farm.grid_map.map_to_local(cell)
	return farm.grid_map.to_global(Vector3(local.x, local.y + 0.04, local.z))
