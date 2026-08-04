extends CanvasLayer

const CHEST_SLOT_COUNT = 27

var chest_slots: Array[Dictionary] = []
var _current_crate = null
var _reenable_controller: bool = false
var _panel: Control = null
var _is_open: bool = false

var chest_grid: GridContainer = null

func _ready() -> void:
	add_to_group("chest_ui")

	# Grab references before reparenting
	_panel = $Panel
	chest_grid = $Panel/VBox/ChestSection/ChestGrid

	# Move panel into inventory_ui's CanvasLayer so both panels share one
	# render context — drag previews then always land on top of both panels
	var inv_ui = _get_inventory_ui()
	if inv_ui:
		remove_child(_panel)
		inv_ui.add_child(_panel)

	# Assign slot indices from the scene's baked-in slots
	var slots = chest_grid.get_children()
	for i in slots.size():
		slots[i].slot_index = i

	_panel.visible = false

func _get_inventory_ui() -> CanvasLayer:
	return get_tree().get_root().find_child("InventoryUI", true, false)

func open(crate) -> void:
	_current_crate = crate
	chest_slots.clear()
	chest_slots.resize(CHEST_SLOT_COUNT)
	for i in CHEST_SLOT_COUNT:
		if i < crate.chest_slots.size():
			chest_slots[i] = crate.chest_slots[i].duplicate()
		else:
			chest_slots[i] = {"item_id": "", "amount": 0}
	refresh_chest()
	_is_open = true
	_panel.visible = true
	var inv = _get_inventory_ui()
	if inv:
		inv.show_for_chest()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_set_player_enabled(false)
	_set_crosshair_visible(false)

func close() -> void:
	if _current_crate != null:
		_current_crate.chest_slots.resize(CHEST_SLOT_COUNT)
		for i in CHEST_SLOT_COUNT:
			_current_crate.chest_slots[i] = chest_slots[i].duplicate()
		if _current_crate.has_method("_toggle_lid") and _current_crate._open:
			_current_crate._toggle_lid()
	_current_crate = null
	_is_open = false
	_panel.visible = false
	var inv = _get_inventory_ui()
	if inv:
		inv.hide_for_chest()
	call_deferred("_recapture_mouse")
	_reenable_controller = true
	_set_crosshair_visible(true)

func refresh_chest() -> void:
	for slot in chest_grid.get_children():
		_update_slot(slot, chest_slots[slot.slot_index])

func _update_slot(slot: Control, data: Dictionary) -> void:
	var icon = slot.get_node("Icon")
	var count = slot.get_node("Overlay/Count")
	var has_item = data["item_id"] != ""
	icon.visible = has_item
	count.visible = has_item and data["amount"] > 1
	if has_item:
		count.text = str(data["amount"])
		var def = ItemDB.get_item(data["item_id"])
		icon.texture = def.icon if def else null

func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("inventory"):
		close()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if _reenable_controller and not Input.is_key_pressed(KEY_ESCAPE):
		_reenable_controller = false
		_set_player_enabled(true)

func _recapture_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _set_player_enabled(enabled: bool) -> void:
	var controller = get_tree().get_first_node_in_group("proto_controller")
	if controller:
		controller.process_mode = Node.PROCESS_MODE_DISABLED if not enabled else Node.PROCESS_MODE_INHERIT

func _set_crosshair_visible(show: bool) -> void:
	var controller = get_tree().get_first_node_in_group("proto_controller")
	if controller:
		var crosshair = controller.get_node_or_null("HUD/Crosshair")
		if crosshair:
			crosshair.visible = show
