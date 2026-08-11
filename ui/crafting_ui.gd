extends CanvasLayer

const RECIPE_ICON_SLOT_SCENE = preload("res://ui/recipe_icon_slot.tscn")

@onready var background: ColorRect = $Background
@onready var inventory_grid_bg: PanelContainer = $InventoryGridBg
@onready var inventory_slots: Array = $InventoryGridBg/InventoryGrid.get_children()

@onready var workbench_layout: VBoxContainer = $WorkbenchLayout
@onready var wb_recipe_grid: GridContainer = $WorkbenchLayout/TopRow/ItemsPanel/VBox/RecipeGridBg/RecipeGrid
@onready var wb_recipes_label: Label = $WorkbenchLayout/TopRow/ItemsPanel/VBox/Title
@onready var wb_inventory_anchor: Control = $WorkbenchLayout/InventoryPanel/InventoryVBox/GridAnchor
@onready var wb_icon: TextureRect = $WorkbenchLayout/TopRow/DetailPanel/DetailVBox/Header/Icon
@onready var wb_name: Label = $WorkbenchLayout/TopRow/DetailPanel/DetailVBox/Header/Name
@onready var wb_desc: Label = $WorkbenchLayout/TopRow/DetailPanel/DetailVBox/Description
@onready var wb_ingredients: VBoxContainer = $WorkbenchLayout/TopRow/DetailPanel/DetailVBox/Ingredients

@onready var forge_layout: HBoxContainer = $ForgeLayout
@onready var forge_recipe_grid: GridContainer = $ForgeLayout/RightPanel/RightVBox/RecipeGridBg/RecipeGrid
@onready var forge_recipes_label: Label = $ForgeLayout/RightPanel/RightVBox/RecipesLabel
@onready var forge_inventory_anchor: Control = $ForgeLayout/LeftPanel/LeftVBox/GridAnchor
@onready var forge_output_grid: GridContainer = $ForgeLayout/LeftPanel/LeftVBox/OutputGridBg/OutputGrid
@onready var forge_icon: TextureRect = $ForgeLayout/RightPanel/RightVBox/DetailVBox/Header/Icon
@onready var forge_name: Label = $ForgeLayout/RightPanel/RightVBox/DetailVBox/Header/Name
@onready var forge_desc: Label = $ForgeLayout/RightPanel/RightVBox/DetailVBox/Description
@onready var forge_ingredients: VBoxContainer = $ForgeLayout/RightPanel/RightVBox/DetailVBox/Ingredients

var current_station = null
var _is_open: bool = false
var _uses_output_buffer: bool = false
var _recipe_slots: Array = []
var _active_recipe_grid: GridContainer = null
var _active_recipes_label: Label = null
var _detail_icon: TextureRect = null
var _detail_name: Label = null
var _detail_desc: Label = null
var _detail_ingredients: VBoxContainer = null
var _reenable_controller: bool = false

func _ready() -> void:
	add_to_group("crafting_ui")
	visible = false
	for i in inventory_slots.size():
		inventory_slots[i].slot_index = i
	var output_nodes = forge_output_grid.get_children()
	for i in output_nodes.size():
		output_nodes[i].slot_index = i

func _get_inventory() -> PlayerInventoryData:
	return get_tree().get_first_node_in_group("player_inventory_data")

func _process(_delta: float) -> void:
	if _reenable_controller and not Input.is_key_pressed(KEY_ESCAPE):
		_reenable_controller = false
		_set_player_enabled(true)

func _unhandled_input(event: InputEvent) -> void:
	if _is_open and (event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("inventory")):
		close_crafting()
		get_viewport().set_input_as_handled()

func open_crafting(station) -> void:
	if current_station and current_station != station:
		if current_station.queue_changed.is_connected(_on_queue_changed):
			current_station.queue_changed.disconnect(_on_queue_changed)
		if current_station.output_changed.is_connected(_refresh_output):
			current_station.output_changed.disconnect(_refresh_output)
	current_station = station
	if not station.queue_changed.is_connected(_on_queue_changed):
		station.queue_changed.connect(_on_queue_changed)
	if not station.output_changed.is_connected(_refresh_output):
		station.output_changed.connect(_refresh_output)

	_uses_output_buffer = _station_uses_output_buffer(station)
	visible = true
	background.visible = true
	if _uses_output_buffer:
		workbench_layout.visible = false
		forge_layout.visible = true
		_active_recipe_grid = forge_recipe_grid
		_active_recipes_label = forge_recipes_label
		_detail_icon = forge_icon
		_detail_name = forge_name
		_detail_desc = forge_desc
		_detail_ingredients = forge_ingredients
		_place_inventory_grid(forge_inventory_anchor)
		_refresh_output()
	else:
		forge_layout.visible = false
		workbench_layout.visible = true
		_active_recipe_grid = wb_recipe_grid
		_active_recipes_label = wb_recipes_label
		_detail_icon = wb_icon
		_detail_name = wb_name
		_detail_desc = wb_desc
		_detail_ingredients = wb_ingredients
		_place_inventory_grid(wb_inventory_anchor)

	var inventory = _get_inventory()
	for slot_node in inventory_slots:
		slot_node.player_inventory = inventory

	_refresh_inventory()
	_populate_recipes()
	_is_open = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_set_crosshair_visible(false)
	_set_player_enabled(false)
	if inventory and not inventory.inventory_changed.is_connected(_refresh_inventory):
		inventory.inventory_changed.connect(_refresh_inventory)

func close_crafting() -> void:
	_is_open = false
	visible = false
	background.visible = false
	workbench_layout.visible = false
	forge_layout.visible = false
	var inventory = _get_inventory()
	if inventory and inventory.inventory_changed.is_connected(_refresh_inventory):
		inventory.inventory_changed.disconnect(_refresh_inventory)
	_set_crosshair_visible(true)
	call_deferred("_recapture_mouse")
	_reenable_controller = true

func _station_uses_output_buffer(station) -> bool:
	for r in RecipeDB.recipes_for_station(station.station_type):
		if r.craft_time > 0.0:
			return true
	return false

func _place_inventory_grid(anchor: Control) -> void:
	if inventory_grid_bg.get_parent() != null:
		inventory_grid_bg.get_parent().remove_child(inventory_grid_bg)
	var target_parent = anchor.get_parent()
	target_parent.add_child(inventory_grid_bg)
	target_parent.move_child(inventory_grid_bg, anchor.get_index())

func _refresh_inventory() -> void:
	var inventory = _get_inventory()
	if inventory == null:
		return
	for i in inventory_slots.size():
		var slot_data = inventory.slots[i]
		var slot_node = inventory_slots[i]
		var icon = slot_node.get_node("Icon")
		var count = slot_node.get_node("Overlay/Count")
		var has_item = slot_data["item_id"] != ""
		icon.visible = has_item
		count.visible = has_item and slot_data["amount"] > 1
		if has_item:
			count.text = str(slot_data["amount"])
			var def = ItemDB.get_item(slot_data["item_id"])
			icon.texture = def.icon if def else null
			slot_node.tooltip_text = def.name if def else slot_data["item_id"]
		else:
			slot_node.tooltip_text = ""

func _populate_recipes() -> void:
	for child in _active_recipe_grid.get_children():
		child.queue_free()
	_recipe_slots.clear()
	var recipes = RecipeDB.recipes_for_station(current_station.station_type)
	recipes.sort_custom(func(a, b): return a.name < b.name)
	var station_levels = get_tree().get_first_node_in_group("player_station_levels")
	for r in recipes:
		var slot = RECIPE_ICON_SLOT_SCENE.instantiate()
		_active_recipe_grid.add_child(slot)
		slot.setup(r)
		var locked = station_levels != null and not station_levels.meets_requirement(current_station.station_type, r.required_level)
		slot.set_locked(locked, r.required_level)
		slot.hovered.connect(_show_recipe_detail)
		slot.clicked.connect(_on_recipe_clicked)
		_recipe_slots.append(slot)
	_update_queue_badges()
	_update_level_label()
	if recipes.size() > 0:
		_show_recipe_detail(recipes[0])
	else:
		_show_recipe_detail(null)

func _show_recipe_detail(recipe: RecipeDefinition) -> void:
	for child in _detail_ingredients.get_children():
		child.queue_free()
	for slot in _recipe_slots:
		slot.set_highlighted(recipe != null and slot.recipe == recipe)
	if recipe == null:
		_detail_icon.texture = null
		_detail_name.text = ""
		_detail_desc.text = ""
		return
	_detail_icon.texture = recipe.icon
	_detail_name.text = recipe.name
	var station_levels = get_tree().get_first_node_in_group("player_station_levels")
	if station_levels != null and not station_levels.meets_requirement(current_station.station_type, recipe.required_level):
		_detail_desc.text = "Requires %s level %d." % [current_station.station_type.capitalize(), recipe.required_level]
	else:
		_detail_desc.text = recipe.description
	for ing in recipe.ingredients:
		var have = _count_item(ing.item_id)
		var def = ItemDB.get_item(ing.item_id)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var icon = TextureRect.new()
		icon.texture = def.icon if def else null
		icon.custom_minimum_size = Vector2(20, 20)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var label = Label.new()
		label.text = "%s  %d / %d" % [def.name if def else ing.item_id, have, ing.amount]
		label.add_theme_color_override("font_color", Color(0.4, 0.85, 0.4, 1) if have >= ing.amount else Color(0.85, 0.3, 0.3, 1))
		row.add_child(label)
		_detail_ingredients.add_child(row)

func _count_item(item_id: String) -> int:
	var inventory = _get_inventory()
	if inventory == null:
		return 0
	var total := 0
	for slot in inventory.slots:
		if slot["item_id"] == item_id:
			total += slot["amount"]
	for slot in inventory.hotbar_slots:
		if slot["item_id"] == item_id:
			total += slot["amount"]
	return total

func _on_recipe_clicked(recipe: RecipeDefinition) -> void:
	if recipe == null or current_station == null:
		return
	current_station.craft(recipe.id, 1)
	_show_recipe_detail(recipe)

func _update_level_label() -> void:
	if _active_recipes_label == null or current_station == null:
		return
	var station_levels = get_tree().get_first_node_in_group("player_station_levels")
	var level = station_levels.get_level(current_station.station_type) if station_levels else 1
	_active_recipes_label.text = "%s (Lv %d)" % [_active_recipes_label.text.get_slice(" (Lv", 0), level]

func _on_queue_changed() -> void:
	_update_queue_badges()

func _update_queue_badges() -> void:
	if current_station == null:
		return
	var counts := {}
	for entry in current_station.queue:
		counts[entry["recipe_id"]] = entry["count"]
	var active_recipe_id = current_station.queue[0]["recipe_id"] if not current_station.queue.is_empty() else ""
	var progress = current_station.get_craft_progress()
	var station_levels = get_tree().get_first_node_in_group("player_station_levels")
	for slot in _recipe_slots:
		if not slot.recipe:
			continue
		slot.set_queue_count(counts.get(slot.recipe.id, 0))
		var locked = station_levels != null and not station_levels.meets_requirement(current_station.station_type, slot.recipe.required_level)
		slot.set_locked(locked, slot.recipe.required_level)
		if active_recipe_id != "" and slot.recipe.id == active_recipe_id:
			var remaining = max(slot.recipe.craft_time * (1.0 - progress), 0.0)
			slot.set_progress(true, progress, remaining)
		else:
			slot.set_progress(false)
	_update_level_label()

func _refresh_output() -> void:
	if current_station == null:
		return
	var output_slots: Array = current_station.output_slots
	var slot_nodes = forge_output_grid.get_children()
	for i in slot_nodes.size():
		if i >= output_slots.size():
			break
		var data = output_slots[i]
		var slot_node = slot_nodes[i]
		var icon = slot_node.get_node("Icon")
		var count = slot_node.get_node("Overlay/Count")
		var has_item = data["item_id"] != ""
		icon.visible = has_item
		count.visible = has_item and data["amount"] > 1
		if has_item:
			count.text = str(data["amount"])
			var def = ItemDB.get_item(data["item_id"])
			icon.texture = def.icon if def else null
			slot_node.tooltip_text = def.name if def else data["item_id"]
		else:
			slot_node.tooltip_text = ""

func refresh_output() -> void:
	_refresh_output()

func _set_crosshair_visible(v: bool) -> void:
	var controller = get_tree().get_first_node_in_group("proto_controller")
	if controller:
		var crosshair = controller.get_node_or_null("HUD/Crosshair")
		if crosshair:
			crosshair.visible = v

func _set_player_enabled(enabled: bool) -> void:
	var controller = get_tree().get_first_node_in_group("proto_controller")
	if controller:
		controller.set_input_enabled(enabled)

func _recapture_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	var controller = get_tree().get_first_node_in_group("proto_controller")
	if controller:
		controller.mouse_captured = true
