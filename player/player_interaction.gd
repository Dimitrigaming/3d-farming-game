extends RayCast3D

@onready var inventory: PlayerInventoryData = get_node("../../../PlayerInventoryData")

var _highlight: MeshInstance3D = null
var _prompt_label: Label = null
var _hovered_cell: Vector3i = Vector3i(-1, -1, -1)
var _hovered_farm = null
var _hovered_is_harvestable: bool = false
var _current_interactable = null
var _left_held: bool = false
var _right_held: bool = false
var _last_acted_cell: Vector3i = Vector3i(-1, -1, -1)
var _hovered_fruit: FruitPickable = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	target_position = Vector3(0, 0, -10.0)
	collision_mask = 0xFFFFFFFF
	collide_with_areas = true
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
		_hovered_fruit = null
		_left_held = false
		_right_held = false
		return

	var hit = get_collider()

	_hovered_fruit = null
	_current_interactable = _find_interactable(hit)
	if _current_interactable != null:
		if _prompt_label and _current_interactable.has_method("get_interact_hint"):
			_prompt_label.text = "[E] %s" % _current_interactable.get_interact_hint()
			_prompt_label.visible = true
		return

	if hit is FruitPickable:
		_hovered_fruit = hit
		if _prompt_label:
			_prompt_label.text = "[LMB] Pick"
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

	# Crop interaction — driven by the crop's own harvest_tools list
	if not valid and state == farm.TILLED:
		var crop = farm.get_crop(cell.x, cell.z)
		if crop and crop.crop_def:
			var effective_id = item_id if item_id != "" else "hand"
			if effective_id in crop.crop_def.harvest_tools:
				if crop.crop_def.is_tree:
					# Tree: axe chops and destroys
					highlight_color = Color(0.6, 0.35, 0.1, 0.6)
					valid = true
					if _prompt_label:
						_prompt_label.text = "[LMB] Chop"
						_prompt_label.visible = true
				elif crop.is_ready_to_harvest():
					highlight_color = Color(1.0, 0.9, 0.1, 0.6)
					valid = true
					_hovered_is_harvestable = true
					var is_primary = crop.crop_def.harvest_tools.size() > 0 and effective_id == crop.crop_def.harvest_tools[0]
					if _prompt_label:
						_prompt_label.text = "[LMB] Harvest" + (" +" + str(crop.crop_def.primary_yield_bonus) if is_primary and crop.crop_def.primary_yield_bonus > 0 else "")
						_prompt_label.visible = true

	if valid:
		(_highlight.material_override as StandardMaterial3D).albedo_color = highlight_color
		_highlight.global_position = _cell_to_world(farm, cell)
		_highlight.visible = true
		_hovered_cell = cell
		_hovered_farm = farm

	# Held-button continuous use — only fires when moving to a new cell
	if _hovered_farm != null and _hovered_cell != Vector3i(-1, -1, -1) and _hovered_cell != _last_acted_cell:
		var held_item_id = equipper.current_item_id if equipper else ""
		if _left_held:
			_do_left_action(held_item_id)
		elif _right_held:
			_do_right_action(held_item_id)

func _do_left_action(item_id: String) -> void:
	var effective_id = item_id if item_id != "" else "hand"
	var equipper = get_tree().get_first_node_in_group("tool_equipper")

	# Gate on the same swing-in-progress check every other tool uses, so
	# sweeping your look across cells while holding LMB can't bypass the
	# swing animation's timing and till/harvest instantly.
	if equipper and equipper.has_method("can_swing") and not equipper.can_swing():
		return

	var farm = _hovered_farm
	var cell = _hovered_cell
	var action: Callable

	match effective_id:
		"hoe":
			action = func(): farm.till_cell(cell.x, cell.z)
		"shovel":
			action = func(): farm.untill_cell(cell.x, cell.z)
		_:
			if effective_id.ends_with("_seed"):
				return
			# Check if the hovered crop accepts this tool
			var crop = farm.get_crop(cell.x, cell.z)
			if crop == null or crop.crop_def == null or effective_id not in crop.crop_def.harvest_tools:
				return
			if crop.crop_def.is_tree:
				action = func():
					var result = farm.chop_tree(cell.x, cell.z)
					if not result.is_empty():
						_grant_gather_result(result)
			elif _hovered_is_harvestable:
				action = func():
					var result = farm.harvest_crop(cell.x, cell.z, effective_id)
					if not result.is_empty():
						_grant_gather_result(result)
			else:
				return

	_last_acted_cell = cell
	# play_swing() no-ops (and never emits swing_hit) when nothing's equipped,
	# so only defer through the signal when there's an actual tool to animate.
	# Hoe/shovel till/untill at the top of the windup (the visual "peak")
	# instead of swing_hit, which fires later at the end of the outward
	# swing motion -- that read as extra delay after the peak for tilling.
	if equipper and effective_id != "hand" and equipper.has_method("play_swing") and equipper.has_signal("swing_hit"):
		equipper.play_swing()
		if effective_id == "hoe" or effective_id == "shovel":
			get_tree().create_timer(equipper.WINDUP_DURATION).timeout.connect(action, CONNECT_ONE_SHOT)
		else:
			equipper.swing_hit.connect(action, CONNECT_ONE_SHOT)
	else:
		action.call()

func _grant_gather_result(result: Dictionary) -> void:
	var equipper = get_tree().get_first_node_in_group("tool_equipper")
	var perks = get_tree().get_first_node_in_group("player_gathering_perks")
	var amount = GatherBonuses.apply_yield(result["amount"], inventory, equipper, perks)
	inventory.add_item(result["item_id"], amount)
	GatherBonuses.grant_gather_xp(result["item_id"], amount)
	GatherBonuses.roll_and_grant_crystal(inventory, perks)

func _do_right_action(item_id: String) -> void:
	if item_id.ends_with("_seed") and inventory.has_item(item_id):
		_hovered_farm.plant_crop(_hovered_cell.x, _hovered_cell.z, item_id)
		inventory.remove_item(item_id)
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
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _hovered_fruit != null:
			_hovered_fruit.pick()
			_hovered_fruit = null
			get_viewport().set_input_as_handled()
			return
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
