extends CanvasLayer

signal closed

const COLOR_ACCENT := Color(0.784, 0.573, 0.165, 1.0)
const COLOR_DIM    := Color(0.541, 0.529, 0.600, 1.0)
const COLOR_TEXT   := Color(0.929, 0.910, 0.875, 1.0)
const ROW_SCENE    := preload("res://ui/item_row.tscn")

@onready var item_list   = $Panel/VBox/ScrollBg/ScrollContainer/ItemList
@onready var money_label = $Panel/VBox/Header/HeaderRow/MoneyBadge/MoneyRow/MoneyLabel
@onready var close_btn   = $Panel/VBox/Header/HeaderRow/CloseButton
@onready var count_label = $Panel/VBox/Footer/FooterRow/CountLabel
@onready var tab_all      = $Panel/VBox/TabBar/TabRow/TabAll
@onready var tab_seeds    = $Panel/VBox/TabBar/TabRow/TabSeeds
@onready var tab_tools    = $Panel/VBox/TabBar/TabRow/TabTools
@onready var tab_materials = $Panel/VBox/TabBar/TabRow/TabMaterials

var _active_tab: String = "all"

func _ready() -> void:
	visible = false
	close_btn.pressed.connect(close_shop)
	GameState.money_changed.connect(_on_money_changed)
	tab_all.pressed.connect(func(): _set_tab("all"))
	tab_seeds.pressed.connect(func(): _set_tab("seeds"))
	tab_tools.pressed.connect(func(): _set_tab("tools"))
	tab_materials.pressed.connect(func(): _set_tab("materials"))

func _get_inventory_ui() -> CanvasLayer:
	return get_tree().get_root().find_child("InventoryUI", true, false)

func open_shop() -> void:
	_populate()
	_on_money_changed(GameState.money)
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_set_crosshair_visible(false)
	var inv = _get_inventory_ui()
	if inv:
		inv.show_for_shop()
	_set_panel_position(true)
	var controller = get_tree().get_first_node_in_group("proto_controller")
	if controller:
		controller.process_mode = Node.PROCESS_MODE_DISABLED

func close_shop() -> void:
	visible = false
	_set_crosshair_visible(true)
	var inv = _get_inventory_ui()
	if inv:
		inv.hide_for_shop()
	_set_panel_position(false)
	closed.emit()
	call_deferred("_finish_close")

func _finish_close() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	var controller = get_tree().get_first_node_in_group("proto_controller")
	if controller:
		controller.process_mode = Node.PROCESS_MODE_INHERIT

func _set_panel_position(shop_mode: bool) -> void:
	var panel = $Panel
	if shop_mode:
		panel.offset_left = 12.0
		panel.offset_right = 572.0
	else:
		panel.offset_left = -280.0
		panel.offset_right = 280.0

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("inventory") or event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel")):
		close_shop()
		get_viewport().set_input_as_handled()

func _set_crosshair_visible(crosshair_visible: bool) -> void:
	var controller = get_tree().get_first_node_in_group("proto_controller")
	if controller:
		var crosshair = controller.get_node_or_null("HUD/Crosshair")
		if crosshair:
			crosshair.visible = crosshair_visible

func _on_money_changed(amount: float) -> void:
	money_label.text = "$%.2f" % amount

func _set_tab(tab: String) -> void:
	_active_tab = tab
	_update_tab_styles()
	_populate()

func _update_tab_styles() -> void:
	var tabs = {
		"all": tab_all,
		"seeds": tab_seeds,
		"tools": tab_tools,
		"materials": tab_materials,
	}
	for key in tabs:
		var btn: Button = tabs[key]
		if key == _active_tab:
			btn.add_theme_color_override("font_color", COLOR_ACCENT)
		else:
			btn.add_theme_color_override("font_color", COLOR_DIM)

func _item_matches_tab(item: ItemDefinition) -> bool:
	match _active_tab:
		"all":       return true
		"seeds":     return item.type == ItemDefinition.ItemType.SEED
		"tools":     return item.type == ItemDefinition.ItemType.TOOL
		"materials": return item.type == ItemDefinition.ItemType.MATERIAL
		_:           return true

func _populate() -> void:
	for child in item_list.get_children():
		child.queue_free()

	var items = ItemDB.all_items()
	items.sort_custom(func(a, b): return a.name < b.name)

	var count := 0
	for item in items:
		if item.buy_price <= 0:
			continue
		if not _item_matches_tab(item):
			continue
		item_list.add_child(_make_row(item))
		count += 1

	count_label.text = "%d item%s available" % [count, "s" if count != 1 else ""]

func _make_row(item: ItemDefinition) -> PanelContainer:
	var row = ROW_SCENE.instantiate()
	row.get_node("HBox/Icon").texture = item.icon
	row.get_node("HBox/ItemName").text = item.name
	row.get_node("HBox/Price").text = "$%d" % item.buy_price
	var qty_box = row.get_node("HBox/Qty") as SpinBox
	var buy_btn = row.get_node("HBox/BuyButton") as Button
	buy_btn.pressed.connect(_on_buy.bind(item, qty_box))
	return row

func _on_buy(item: ItemDefinition, qty_box: SpinBox) -> void:
	var qty = int(qty_box.value)
	var total = item.buy_price * qty
	if not GameState.spend_money(total):
		return
	for i in qty:
		Inventory.add_item(item.id)
