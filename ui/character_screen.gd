extends CanvasLayer

## Skill badges are placed directly in this scene (see SectionsVBox in
## character_screen.tscn) rather than spawned from code -- to add a new
## station, instance ui/skill_badge.tscn in the editor and set its
## station_type/display_name in the Inspector.

@onready var shop_level_label: Label = $MainPanel/MainVBox/ShopLevelLabel
@onready var sections_vbox: VBoxContainer = $MainPanel/MainVBox/Scroll/SectionsVBox
@onready var main_panel: PanelContainer = $MainPanel
@onready var list_panel: PanelContainer = $ListPanel
@onready var list_title: Label = $ListPanel/ListVBox/HeaderRow/ListTitle
@onready var back_button: Button = $ListPanel/ListVBox/HeaderRow/BackButton
@onready var recipe_list: VBoxContainer = $ListPanel/ListVBox/Scroll/RecipeList
@onready var perk_panel: PanelContainer = $PerkPanel
@onready var perk_back_button: Button = $PerkPanel/PerkVBox/HeaderRow/PerkBackButton
@onready var points_label: Label = $PerkPanel/PerkVBox/PointsLabel
@onready var perk_list: VBoxContainer = $PerkPanel/PerkVBox/Scroll/PerkList
@onready var controller: Node = get_parent()

var _reenable_controller: bool = false

func _ready() -> void:
	# Exempt from the parent ProtoController's process_mode, same reasoning
	# as InventoryUI/Hotbar -- this UI's own input must keep working while
	# it disables player movement.
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("character_screen")
	back_button.pressed.connect(_show_main_panel)
	perk_back_button.pressed.connect(_show_main_panel)
	$TabRow/InventoryTabButton.pressed.connect(_on_inventory_tab_pressed)
	$TabRow/SkillsTabButton.pressed.connect(_on_skills_tab_pressed)
	for badge in _get_badges():
		badge.badge_clicked.connect(_show_skill_list)
	GameState.shop_xp_gained.connect(func(_a, _x): if visible: _refresh_shop_label())
	GameState.shop_level_up.connect(func(_l): if visible: _refresh_shop_label())

func _on_inventory_tab_pressed() -> void:
	var inventory_ui = get_node_or_null("../InventoryUI")
	if inventory_ui == null:
		return
	close(false)
	inventory_ui.open()

func _on_skills_tab_pressed() -> void:
	_show_main_panel()

func _get_badges() -> Array:
	var result: Array = []
	for node in get_tree().get_nodes_in_group("skill_badge"):
		if sections_vbox.is_ancestor_of(node):
			result.append(node)
	return result

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("character") or (visible and event.is_action_pressed("ui_cancel")):
		toggle()
		get_viewport().set_input_as_handled()
		return
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		toggle()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func open() -> void:
	visible = true
	_show_main_panel()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_set_player_enabled(false)
	_set_crosshair_visible(false)

## recapture: false when switching straight into another menu (e.g. the
## Inventory tab) so the deferred mouse-recapture from closing doesn't race
## against the panel that's opening right after and steal the mouse back.
func close(recapture: bool = true) -> void:
	visible = false
	if recapture:
		call_deferred("_recapture_mouse")
		_reenable_controller = true
	_set_crosshair_visible(true)

func _process(_delta: float) -> void:
	if _reenable_controller and not Input.is_key_pressed(KEY_ESCAPE):
		_reenable_controller = false
		_set_player_enabled(true)

func _show_main_panel() -> void:
	list_panel.visible = false
	perk_panel.visible = false
	main_panel.visible = true
	_refresh_shop_label()
	_refresh_badges()

func _refresh_shop_label() -> void:
	shop_level_label.text = "Shop Level: %d  (%d / %d XP)" % [
		GameState.shop_level, GameState.shop_xp, GameState.shop_xp_to_next_level()
	]

func _refresh_badges() -> void:
	var levels_node = get_node_or_null("../PlayerStationLevels")
	for badge in _get_badges():
		var level = levels_node.get_level(badge.station_type) if levels_node else 1
		var xp = levels_node.get_xp(badge.station_type) if levels_node else 0
		var xp_to_next = levels_node.xp_to_next_level(badge.station_type) if levels_node else 100
		badge.refresh(level, xp, xp_to_next)

func _show_skill_list(badge: Button) -> void:
	var station_type: String = badge.station_type
	if station_type == "gathering":
		main_panel.visible = false
		list_panel.visible = false
		perk_panel.visible = true
		_refresh_perk_list()
		return
	main_panel.visible = false
	list_panel.visible = true
	list_title.text = badge.display_name

	for child in recipe_list.get_children():
		child.queue_free()

	var levels_node = get_node_or_null("../PlayerStationLevels")
	var current_level = levels_node.get_level(station_type) if levels_node else 1

	var recipes = RecipeDB.recipes_for_station(station_type)
	recipes.sort_custom(func(a, b): return a.required_level < b.required_level)

	if recipes.is_empty():
		var lbl = Label.new()
		lbl.text = "No recipes for this station yet."
		lbl.add_theme_color_override("font_color", Color(0.7, 0.68, 0.65, 1))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		recipe_list.add_child(lbl)
		return

	for recipe in recipes:
		recipe_list.add_child(_build_recipe_row(recipe, current_level))

func _build_recipe_row(recipe: RecipeDefinition, current_level: int) -> Control:
	var unlocked = current_level >= recipe.required_level

	var row = PanelContainer.new()
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	row.add_child(hbox)

	var icon = TextureRect.new()
	icon.texture = recipe.icon
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = Color(1, 1, 1, 1) if unlocked else Color(0.4, 0.4, 0.4, 1)
	hbox.add_child(icon)

	var name_label = Label.new()
	name_label.text = recipe.name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", Color(0.9, 0.88, 0.85, 1) if unlocked else Color(0.55, 0.53, 0.5, 1))
	hbox.add_child(name_label)

	var level_label = Label.new()
	level_label.text = "Lv %d" % recipe.required_level
	level_label.add_theme_color_override("font_color", Color(0.4, 0.85, 0.4, 1) if unlocked else Color(0.85, 0.3, 0.3, 1))
	hbox.add_child(level_label)

	return row

func _refresh_perk_list() -> void:
	var perks = get_node_or_null("../PlayerGatheringPerks")
	points_label.text = "Available Points: %d" % (perks.available_points() if perks else 0)

	for child in perk_list.get_children():
		child.queue_free()

	if perks == null:
		return

	for perk in GatherPerkDB.all_perks():
		perk_list.add_child(_build_perk_row(perk, perks))

## Overrides for stat keys whose display name isn't just a capitalized
## version of the internal key (e.g. "speed" reads as "Harvest Speed" so
## it isn't confused with tool swing/attack speed).
const STAT_LABELS := {
	"speed": "Harvest Speed",
}

func _stat_label(stat: String) -> String:
	return STAT_LABELS.get(stat, stat.capitalize())

func _build_perk_row(perk: GatherPerkDefinition, perks: Node) -> Control:
	var spent = perks.get_points_spent(perk.id)
	var row = PanelContainer.new()
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	row.add_child(hbox)

	var name_label = Label.new()
	name_label.text = "%s (%s)" % [perk.name, _stat_label(perk.stat)]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.tooltip_text = perk.description
	name_label.add_theme_color_override("font_color", Color(0.9, 0.88, 0.85, 1))
	hbox.add_child(name_label)

	var points_spent_label = Label.new()
	points_spent_label.text = "%d pts (+%.0f%%)" % [spent, spent * perk.value_per_point * 100.0]
	points_spent_label.add_theme_color_override("font_color", Color(0.65, 0.63, 0.6, 1))
	hbox.add_child(points_spent_label)

	var add_button = Button.new()
	add_button.focus_mode = Control.FOCUS_NONE
	add_button.text = "+"
	add_button.disabled = perks.available_points() <= 0
	add_button.pressed.connect(func():
		perks.spend_point(perk.id)
		_refresh_perk_list()
	)
	hbox.add_child(add_button)

	return row

func _recapture_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if controller:
		controller.mouse_captured = true

func _set_player_enabled(enabled: bool) -> void:
	if controller:
		controller.set_input_enabled(enabled)

func _set_crosshair_visible(v: bool) -> void:
	if controller:
		var crosshair = controller.get_node_or_null("HUD/Crosshair")
		if crosshair:
			crosshair.visible = v
