extends CanvasLayer

signal slot_selected(index: int)

var selected_slot: int = 0

@onready var grid = $Panel/Grid

func _ready() -> void:
	Inventory.inventory_changed.connect(_refresh)
	var slots = grid.get_children()
	for i in slots.size():
		slots[i].slot_index = Inventory.HOTBAR_START + i
	_refresh()
	_update_highlight()
	call_deferred("_notify_equipper")
	call_deferred("_cache_inventory_ui")

func _unhandled_input(event: InputEvent) -> void:
	if _inventory_ui and _inventory_ui.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key = event.keycode
		if key >= KEY_1 and key <= KEY_9:
			selected_slot = key - KEY_1
			_update_highlight()
			slot_selected.emit(selected_slot)
			_notify_equipper()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if _inventory_ui and _inventory_ui.visible:
			return
		var build_mode = get_tree().get_first_node_in_group("build_mode")
		if build_mode and build_mode.active:
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			selected_slot = (selected_slot - 1 + 9) % 9
			_update_highlight()
			slot_selected.emit(selected_slot)
			_notify_equipper()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			selected_slot = (selected_slot + 1) % 9
			_update_highlight()
			slot_selected.emit(selected_slot)
			_notify_equipper()
			get_viewport().set_input_as_handled()

var _slot_default_style: StyleBox = null
var _inventory_ui: CanvasLayer = null

func _update_highlight() -> void:
	var slots = grid.get_children()
	if _slot_default_style == null:
		if slots.size() > 0:
			_slot_default_style = slots[0].get_theme_stylebox("panel")
	for i in slots.size():
		var panel = slots[i]
		if i == selected_slot:
			var style = StyleBoxFlat.new()
			style.bg_color = Color(0.35, 0.35, 0.35, 0.9)
			style.set_border_width_all(2)
			style.border_color = Color(1, 0.85, 0.2, 1)
			panel.add_theme_stylebox_override("panel", style)
		else:
			if _slot_default_style:
				panel.add_theme_stylebox_override("panel", _slot_default_style)
			else:
				panel.remove_theme_stylebox_override("panel")

func _cache_inventory_ui() -> void:
	_inventory_ui = get_tree().get_root().find_child("InventoryUI", true, false)

func _notify_equipper() -> void:
	var equipper = get_tree().get_first_node_in_group("tool_equipper")
	if not equipper:
		return
	var slot_data = Inventory.slots[Inventory.HOTBAR_START + selected_slot]
	equipper.equip(slot_data["item_id"])

func _refresh() -> void:
	var slot_nodes = grid.get_children()
	for i in slot_nodes.size():
		var slot_data = Inventory.slots[Inventory.HOTBAR_START + i]
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
	_notify_equipper()
