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
		var inv = get_tree().get_first_node_in_group("inventory_ui")
		if inv and inv.visible:
			inv.visible = false
			inv._set_crosshair_visible(true)
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
	var card = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.1, 0.13, 0.18)
	card_style.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", card_style)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var outer = HBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	card.add_child(outer)

	# --- Left: icon + name + market price ---
	var left = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 4)
	var left_margin = MarginContainer.new()
	left_margin.add_theme_constant_override("margin_left", 10)
	left_margin.add_theme_constant_override("margin_top", 10)
	left_margin.add_theme_constant_override("margin_right", 8)
	left_margin.add_theme_constant_override("margin_bottom", 10)
	left_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_margin.add_child(left)
	outer.add_child(left_margin)

	var name_row = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	left.add_child(name_row)

	if item.icon:
		var icon = TextureRect.new()
		icon.texture = item.icon
		icon.custom_minimum_size = Vector2(40, 40)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		name_row.add_child(icon)

	var name_lbl = _make_label(item.name, Color.WHITE)
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(name_lbl)

	var market_lbl = _make_label("Market Price: $%d" % item.sell_price, Color(0.55, 0.65, 0.75))
	market_lbl.add_theme_font_size_override("font_size", 12)
	left.add_child(market_lbl)

	# --- Divider ---
	var vsep = VSeparator.new()
	vsep.custom_minimum_size = Vector2(2, 0)
	outer.add_child(vsep)

	# --- Right: price control + demand + active button ---
	var right_margin = MarginContainer.new()
	right_margin.add_theme_constant_override("margin_left", 10)
	right_margin.add_theme_constant_override("margin_top", 10)
	right_margin.add_theme_constant_override("margin_right", 10)
	right_margin.add_theme_constant_override("margin_bottom", 10)
	right_margin.custom_minimum_size = Vector2(150, 0)
	outer.add_child(right_margin)

	var right = VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right_margin.add_child(right)

	# Price row
	var price_row = HBoxContainer.new()
	price_row.add_theme_constant_override("separation", 4)
	right.add_child(price_row)

	var price_title = _make_label("Price:", Color(0.7, 0.7, 0.8))
	price_title.add_theme_font_size_override("font_size", 12)
	price_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	price_row.add_child(price_title)

	var btn_minus = Button.new()
	btn_minus.text = "-"
	btn_minus.focus_mode = Control.FOCUS_NONE
	btn_minus.custom_minimum_size = Vector2(24, 24)
	price_row.add_child(btn_minus)

	var price_val_lbl = _make_label("$%d" % int(DeliveryManager.get_product_price(item.id)), Color.WHITE)
	price_val_lbl.add_theme_font_size_override("font_size", 13)
	price_val_lbl.custom_minimum_size = Vector2(40, 0)
	price_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_row.add_child(price_val_lbl)

	var btn_plus = Button.new()
	btn_plus.text = "+"
	btn_plus.focus_mode = Control.FOCUS_NONE
	btn_plus.custom_minimum_size = Vector2(24, 24)
	price_row.add_child(btn_plus)

	# Demand label
	var demand_pct = DeliveryManager.get_demand_percent(item.id)
	var demand_color = Color(0.3, 1.0, 0.4) if demand_pct >= 75.0 else \
					   Color(1.0, 0.85, 0.2) if demand_pct >= 40.0 else Color(1.0, 0.4, 0.4)
	var demand_lbl = _make_label("%.0f%% demand" % demand_pct, demand_color)
	demand_lbl.add_theme_font_size_override("font_size", 12)
	demand_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(demand_lbl)

	# Active toggle button
	var is_enabled = DeliveryManager.is_product_enabled(item.id)
	var active_btn = Button.new()
	active_btn.text = "Active" if is_enabled else "Inactive"
	active_btn.focus_mode = Control.FOCUS_NONE
	active_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_active_btn(active_btn, is_enabled)
	right.add_child(active_btn)

	# Wire up buttons
	btn_minus.pressed.connect(func():
		DeliveryManager.set_product_price(item.id, DeliveryManager.get_product_price(item.id) - 1.0)
		_refresh_products()
	)
	btn_plus.pressed.connect(func():
		DeliveryManager.set_product_price(item.id, DeliveryManager.get_product_price(item.id) + 1.0)
		_refresh_products()
	)
	active_btn.pressed.connect(func():
		DeliveryManager.set_product_enabled(item.id, not DeliveryManager.is_product_enabled(item.id))
		_refresh_products()
	)

	return card

func _style_active_btn(btn: Button, enabled: bool) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.6, 0.2) if enabled else Color(0.55, 0.15, 0.15)
	style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", style)
	var style_hover = style.duplicate()
	style_hover.bg_color = Color(0.2, 0.75, 0.25) if enabled else Color(0.7, 0.18, 0.18)
	btn.add_theme_stylebox_override("hover", style_hover)

func _on_fulfill_order(order: Dictionary) -> void:
	DeliveryManager.try_fulfill_order(order)
	_refresh_orders()

func _make_label(text: String, color: Color) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	return lbl
