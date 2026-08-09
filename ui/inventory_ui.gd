extends CanvasLayer

@onready var grid = $Panel/VBox/GridBg/Grid
@onready var inventory: PlayerInventoryData = get_node("../PlayerInventoryData")
@onready var controller: Node = get_parent()

const IDLE_TOP := -318.0
const IDLE_BOTTOM := -20.0
const IDLE_RIGHT := 288.0
const IDLE_LEFT := -304.0

var _hovered_slot: int = -1
var _reenable_controller: bool = false

func _ready() -> void:
	# Exempt from the parent ProtoController's process_mode so this UI's own
	# input (close key, shift-click, drag/drop) keeps working while it's
	# disabling player movement.
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("inventory_ui")
	inventory.inventory_changed.connect(_refresh)
	_assign_indices()
	call_deferred("_refresh")

func _assign_indices() -> void:
	var grid_slots = grid.get_children()
	for i in grid_slots.size():
		var slot = grid_slots[i]
		slot.slot_index = i
		slot.player_inventory = inventory
		slot.mouse_entered.connect(func(): _hovered_slot = slot.slot_index)
		slot.mouse_exited.connect(func(): if _hovered_slot == slot.slot_index: _hovered_slot = -1)

func _process(_delta: float) -> void:
	if _reenable_controller and not Input.is_key_pressed(KEY_ESCAPE):
		_reenable_controller = false
		_set_player_enabled(true)

var _chest_mode: bool = false

func _unhandled_input(event: InputEvent) -> void:
	if _chest_mode:
		return
	if visible and event is InputEventKey and event.pressed and not event.echo:
		var key = event.keycode
		if key >= KEY_1 and key <= KEY_9:
			var hotbar_index = key - KEY_1
			if _hovered_slot >= 0 and inventory.slots[_hovered_slot]["item_id"] != "":
				var inv_data = inventory.slots[_hovered_slot].duplicate()
				var hotbar_data = inventory.hotbar_slots[hotbar_index].duplicate()
				inventory.slots[_hovered_slot] = hotbar_data
				inventory.hotbar_slots[hotbar_index] = inv_data
				inventory.inventory_changed.emit()
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("inventory") or (visible and event.is_action_pressed("ui_cancel")):
		var tablet = get_tree().get_first_node_in_group("tablet")
		if tablet and tablet.visible:
			tablet._toggle()
			get_viewport().set_input_as_handled()
			return
		# CraftingUI isn't a singleton -- every station spawns its own
		# instance, so check all of them for one that's actually open.
		for crafting_ui in get_tree().get_nodes_in_group("crafting_ui"):
			if crafting_ui._is_open:
				# Let the crafting UI close itself on this same key instead
				# of also opening the plain inventory behind it.
				return
		visible = not visible
		if visible:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			_set_player_enabled(false)
		else:
			call_deferred("_recapture_mouse")
			_reenable_controller = true
		_set_crosshair_visible(not visible)
		get_viewport().set_input_as_handled()

func _recapture_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if controller:
		controller.mouse_captured = true

func _set_player_enabled(enabled: bool) -> void:
	if controller:
		controller.process_mode = Node.PROCESS_MODE_DISABLED if not enabled else Node.PROCESS_MODE_INHERIT

func show_for_shop() -> void:
	visible = true
	var panel = $Panel
	panel.offset_left = -600.0
	panel.offset_top = -260.0
	panel.offset_right = -12.0

func hide_for_shop() -> void:
	visible = false
	var panel = $Panel
	panel.offset_left = IDLE_LEFT
	panel.offset_top = IDLE_TOP
	panel.offset_right = IDLE_RIGHT

func show_for_chest() -> void:
	_chest_mode = true
	visible = true
	var panel = $Panel
	panel.offset_left = IDLE_LEFT
	panel.offset_top = -88.0
	panel.offset_right = IDLE_RIGHT
	panel.offset_bottom = 289.0

func hide_for_chest() -> void:
	_chest_mode = false
	visible = false
	var panel = $Panel
	panel.offset_left = IDLE_LEFT
	panel.offset_top = IDLE_TOP
	panel.offset_right = IDLE_RIGHT
	panel.offset_bottom = IDLE_BOTTOM

func _set_crosshair_visible(crosshair_visible: bool) -> void:
	if controller:
		var crosshair = controller.get_node_or_null("HUD/Crosshair")
		if crosshair:
			crosshair.visible = crosshair_visible

func _refresh() -> void:
	_refresh_grid(grid.get_children(), 0)

func _refresh_grid(slot_nodes: Array, slot_offset: int) -> void:
	for i in slot_nodes.size():
		var slot_data = inventory.slots[slot_offset + i]
		var slot_node = slot_nodes[i]
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
