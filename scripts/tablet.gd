extends CanvasLayer

const TAB_ORDERS   = 0
const TAB_PRODUCTS = 1

var _current_tab: int = TAB_ORDERS
var _order_refresh_timer: float = 0.0

@onready var _panels: Array[Control] = [
	$Control/Panel/MarginContainer/VBox/Content/OrdersPanel,
	$Control/Panel/MarginContainer/VBox/Content/ProductsPanel,
]
@onready var _tab_btns: Array[Button] = [
	%BtnOrders,
	%BtnProducts,
]
@onready var _orders_container: VBoxContainer = %OrdersContainer
@onready var _products_container: VBoxContainer = %ProductsContainer

func _ready() -> void:
	visible = false
	add_to_group("tablet")
	%BtnOrders.pressed.connect(_show_tab.bind(TAB_ORDERS))
	%BtnProducts.pressed.connect(_show_tab.bind(TAB_PRODUCTS))
	DeliveryManager.orders_changed.connect(_on_orders_changed)
	DeliveryManager.products_changed.connect(_on_products_changed)

func _process(delta: float) -> void:
	if visible and _current_tab == TAB_ORDERS:
		_order_refresh_timer += delta
		if _order_refresh_timer >= 1.0:
			_order_refresh_timer = 0.0
			_refresh_orders()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("tablet"):
		_toggle()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible:
		_toggle()
		get_viewport().set_input_as_handled()

func _toggle() -> void:
	visible = not visible
	if visible:
		_on_open()
	else:
		_on_close()

func _on_open() -> void:
	_show_tab(_current_tab)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var controller = _get_controller()
	if controller:
		controller.can_move = false
		controller.can_jump = false
		controller.mouse_captured = false

func _on_close() -> void:
	call_deferred("_recapture_mouse")
	var controller = _get_controller()
	if controller:
		controller.can_move = true
		controller.can_jump = true
		controller.mouse_captured = true

func _recapture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _get_controller() -> CharacterBody3D:
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0].get_parent() as CharacterBody3D

func _show_tab(idx: int) -> void:
	_current_tab = idx
	for i in _panels.size():
		_panels[i].visible = (i == idx)
	for i in _tab_btns.size():
		_tab_btns[i].button_pressed = (i == idx)
	match idx:
		TAB_ORDERS:   _refresh_orders()
		TAB_PRODUCTS: _refresh_products()

func _refresh_orders() -> void:
	for child in _orders_container.get_children():
		child.queue_free()
	if DeliveryManager.active_orders.is_empty():
		_orders_container.add_child(_make_label("No active delivery orders.", Color(0.6, 0.6, 0.6)))
		return
	for order in DeliveryManager.active_orders:
		_orders_container.add_child(_make_order_row(order))

func _refresh_products() -> void:
	for child in _products_container.get_children():
		child.queue_free()
	var items = DeliveryManager.get_sellable_items()
	if items.is_empty():
		_products_container.add_child(_make_label("No sellable products found.", Color(0.6, 0.6, 0.6)))
		return
	for item in items:
		_products_container.add_child(_make_product_row(item))

func _on_orders_changed() -> void:
	if visible and _current_tab == TAB_ORDERS:
		_refresh_orders()

func _on_products_changed() -> void:
	if visible and _current_tab == TAB_PRODUCTS:
		_refresh_products()

func _make_order_row(order: Dictionary) -> Control:
	var row = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.15, 0.18)
	style.set_corner_radius_all(6)
	row.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	row.add_child(hbox)

	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)

	var def = ItemDB.get_item(order["item_id"])
	var item_name = def.name if def else order["item_id"]
	var name_lbl = _make_label("%s  x%d" % [item_name, order["amount"]], Color.WHITE)
	name_lbl.add_theme_font_size_override("font_size", 16)
	info.add_child(name_lbl)

	var reward_lbl = _make_label("Reward: $%.0f" % order["reward"], Color(0.3, 1.0, 0.4))
	reward_lbl.add_theme_font_size_override("font_size", 13)
	info.add_child(reward_lbl)

	var secs = int(order["time_remaining"])
	var time_str = "%d:%02d" % [secs / 60, secs % 60]
	var time_color = Color(1.0, 0.4, 0.4) if secs < 60 else Color(1.0, 0.85, 0.2)
	var time_lbl = _make_label(time_str, time_color)
	time_lbl.add_theme_font_size_override("font_size", 18)
	hbox.add_child(time_lbl)

	var fulfill_btn = Button.new()
	fulfill_btn.text = "Fulfill"
	fulfill_btn.focus_mode = Control.FOCUS_NONE
	fulfill_btn.custom_minimum_size = Vector2(80, 0)
	fulfill_btn.pressed.connect(_on_fulfill_order.bind(order))
	hbox.add_child(fulfill_btn)

	return row

func _make_product_row(item: ItemDefinition) -> Control:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var check = CheckButton.new()
	check.button_pressed = item.id in DeliveryManager.enabled_products
	check.focus_mode = Control.FOCUS_NONE
	check.toggled.connect(func(on): DeliveryManager.set_product_enabled(item.id, on))
	row.add_child(check)

	if item.icon:
		var icon = TextureRect.new()
		icon.texture = item.icon
		icon.custom_minimum_size = Vector2(24, 24)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)

	var name_lbl = _make_label(item.name, Color.WHITE)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	var price_lbl = _make_label("$%d ea." % item.sell_price, Color(0.6, 0.6, 0.6))
	price_lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(price_lbl)

	return row

func _on_fulfill_order(order: Dictionary) -> void:
	DeliveryManager.try_fulfill_order(order)
	_refresh_orders()

func _make_label(text: String, color: Color) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	return lbl
