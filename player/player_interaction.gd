extends RayCast3D

@onready var inventory: PlayerInventoryData = get_node("../../../PlayerInventoryData")
## General "interactable" targeting (chests, shelves, mining/tree nodes,
## etc.) now lives in interaction_manager.gd as a proximity+facing check,
## not a raycast -- reading its current_target here instead of running a
## second, separate raycast-based lookup keeps this prompt in sync with
## whatever you can actually press [E] on, including standing still.
@onready var _interaction_manager = get_node("../InteractionAnchor")

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
var _hovered_grass: CuttableGrass = null

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
		_hovered_grass = null
		_left_held = false
		_right_held = false
		return

	var hit = get_collider()

	_hovered_fruit = null
	_hovered_grass = null
	_current_interactable = _interaction_manager.current_target
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

	if hit is CuttableGrass:
		var equipper_tool = get_tree().get_first_node_in_group("tool_equipper")
		if equipper_tool and _tool_category(equipper_tool.current_item_id) == "scythe":
			_hovered_grass = hit
			if _prompt_label:
				_prompt_label.text = "[LMB] Cut"
				_prompt_label.visible = true
		return

	# Crop interaction -- crops carry their own Area3D collider now (see
	# planted_crop.gd), so you have to actually be looking at the plant,
	# not just at whichever farm tile the raycast happens to land on.
	if hit is PlantedCrop:
		_hover_crop(hit)
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
			if crop == null or crop.crop_def == null or not _tool_can_harvest(crop.crop_def, effective_id):
				return
			if crop.crop_def.is_tree:
				action = func():
					var result = farm.chop_tree(cell.x, cell.z)
					if not result.is_empty():
						_grant_gather_result(result)
			elif _hovered_is_harvestable and _tool_category(effective_id) == "scythe":
				action = func(): _harvest_scythe_area(farm, cell, effective_id)
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

## True if tool_id can harvest crop_def -- either it's listed by exact item
## id (existing per-crop data), or its tool_category matches an entry,
## which is what lets scythe_rusty/scythe_copper/scythe_iron etc. all
## satisfy a crop's harvest_tools = ["scythe", "hand"] without editing
## every crop resource for each new tier.
func _tool_can_harvest(crop_def: CropDefinition, tool_id: String) -> bool:
	for entry in crop_def.harvest_tools:
		if tool_id == entry or _tool_category(tool_id) == entry:
			return true
	return false

func _tool_category(tool_id: String) -> String:
	var def = ItemDB.get_item(tool_id)
	return def.tool_category if def else ""

## Scythe harvests the hovered crop plus any other ready, scythe-harvestable
## crop inside a width x depth rectangle centered on the hovered crop and
## oriented to the camera's look direction (width = side-to-side, depth =
## toward/away from the player). Dimensions come from the equipped scythe
## tier's own ItemDefinition (harvest_sweep_width/depth) -- everything else
## (axe, hand, other tools) stays single-target via harvest_crop() directly.
func _harvest_scythe_area(farm, center: Vector3i, tool_id: String) -> void:
	var item_def = ItemDB.get_item(tool_id)
	var width: float = item_def.harvest_sweep_width if item_def else 1.0
	var depth: float = item_def.harvest_sweep_depth if item_def else 1.0

	var center_world: Vector3 = farm.grid_map.map_to_local(center)
	var cam_basis := global_transform.basis
	var right := Vector3(cam_basis.x.x, 0.0, cam_basis.x.z).normalized()
	var forward := Vector3(-cam_basis.z.x, 0.0, -cam_basis.z.z).normalized()

	var reach := int(ceil(maxf(width, depth) / 2.0)) + 1
	for dx in range(-reach, reach + 1):
		for dz in range(-reach, reach + 1):
			var cell = center + Vector3i(dx, 0, dz)
			var crop = farm.get_crop(cell.x, cell.z)
			if crop == null or crop.crop_def == null or not _tool_can_harvest(crop.crop_def, tool_id):
				continue
			if crop.crop_def.is_tree or not crop.is_ready_to_harvest():
				continue
			var offset: Vector3 = farm.grid_map.map_to_local(cell) - center_world
			if absf(offset.dot(right)) > width / 2.0 + 0.01:
				continue
			if absf(offset.dot(forward)) > depth / 2.0 + 0.01:
				continue
			var result = farm.harvest_crop(cell.x, cell.z, tool_id)
			if not result.is_empty():
				_grant_gather_result(result)

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

	# "interact" (chests, shelves, mining/tree nodes, etc.) is handled by
	# interaction_manager.gd against the same current_target this script
	# reads for its prompt label -- no need to also fire it here.

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
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _hovered_grass != null:
			var grass = _hovered_grass
			var equipper = get_tree().get_first_node_in_group("tool_equipper")
			if equipper and equipper.has_method("play_swing") and equipper.has_signal("swing_hit"):
				equipper.play_swing()
				equipper.swing_hit.connect(func(): grass.cut(), CONNECT_ONE_SHOT)
			else:
				grass.cut()
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

## Resolves hover state for a crop hit directly via its own collider
## (see planted_crop.gd) -- driven by the crop's own harvest_tools list,
## same rules the old tile-scan crop branch used.
func _hover_crop(crop: PlantedCrop) -> void:
	var farm = get_tree().get_first_node_in_group("farm_grid")
	if farm == null or crop.crop_def == null:
		return
	var equipper = get_tree().get_first_node_in_group("tool_equipper")
	var item_id = equipper.current_item_id if equipper else ""
	var effective_id = item_id if item_id != "" else "hand"
	if not _tool_can_harvest(crop.crop_def, effective_id):
		return

	var highlight_color: Color
	var valid := false

	if crop.crop_def.is_tree:
		highlight_color = Color(0.6, 0.35, 0.1, 0.6)
		valid = true
		if _prompt_label:
			_prompt_label.text = "[LMB] Chop"
			_prompt_label.visible = true
	elif crop.is_ready_to_harvest():
		highlight_color = Color(1.0, 0.9, 0.1, 0.6)
		valid = true
		_hovered_is_harvestable = true
		var is_primary = crop.crop_def.harvest_tools.size() > 0 and (effective_id == crop.crop_def.harvest_tools[0] or _tool_category(effective_id) == crop.crop_def.harvest_tools[0])
		if _prompt_label:
			_prompt_label.text = "[LMB] Harvest" + (" +" + str(crop.crop_def.primary_yield_bonus) if is_primary and crop.crop_def.primary_yield_bonus > 0 else "")
			_prompt_label.visible = true

	if valid:
		(_highlight.material_override as StandardMaterial3D).albedo_color = highlight_color
		_highlight.global_position = _cell_to_world(farm, crop.cell)
		_highlight.visible = true
		_hovered_cell = crop.cell
		_hovered_farm = farm

func _world_to_cell(farm: Node3D, world_pos: Vector3) -> Vector3i:
	var local = farm.grid_map.to_local(world_pos)
	return farm.grid_map.local_to_map(local)

func _cell_to_world(farm: Node3D, cell: Vector3i) -> Vector3:
	var local = farm.grid_map.map_to_local(cell)
	return farm.grid_map.to_global(Vector3(local.x, local.y + 0.04, local.z))
