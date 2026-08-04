extends CanvasLayer

const TAB_ORDERS   = 0
const TAB_PRODUCTS = 1

var _current_tab: int = TAB_ORDERS

var _root: Control
var _tab_btns: Array[Button] = []
var _panels: Array[Control] = []

var _orders_container: VBoxContainer
var _products_container: VBoxContainer

var _order_refresh_timer: float = 0.0

func _ready() -> void:
	layer = 20
	visible = false
	_build_ui()
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
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var controller = _get_controller()
	if controller:
		controller.can_move = true
		controller.can_jump = true
		controller.mouse_captured = true

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

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.55)
	_root.add_child(bg)

	var panel = Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.15)
	style.border_color = Color(0.25, 0.28, 0.35)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_border_width(side, 2)
	panel.add_theme_stylebox_override("panel", style)
	_root.add_child(panel)

	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	margin.add_child(vbox)

	var title = Label.new()
	title.text = "Delivery Tablet"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	vbox.add_child(title)

	var tab_bar = HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 4)
	vbox.add_child(tab_bar)

	for tab_name in ["Delivery Orders", "Products"]:
		var btn = Button.new()
		btn.text = tab_name
		btn.toggle_mode = true
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_show_tab.bind(_tab_btns.size()))
		tab_bar.add_child(btn)
		_tab_btns.append(btn)

	vbox.add_child(HSeparator.new())

	var content = Control.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(content)

	_panels.append(_build_orders_panel(content))
	_panels.append(_build_products_panel(content))

	var hint = Label.new()
	hint.text = "Press Tab to close"
	hint.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
	hint.add_theme_font_size_override("font_size", 13)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(hint)

func _build_orders_panel(parent: Control) -> Control:
	var p = VBoxContainer.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(p)

	p.add_child(_section_label("Active Orders"))
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p.add_child(scroll)

	_orders_container = VBoxContainer.new()
	_orders_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_orders_container.add_theme_constant_override("separation", 8)
	scroll.add_child(_orders_container)

	return p

func _build_products_panel(parent: Control) -> Control:
	var p = VBoxContainer.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.visible = false
	parent.add_child(p)

	p.add_child(_section_label("Products Available for Orders"))
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p.add_child(scroll)

	_products_container = VBoxContainer.new()
	_products_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_products_container.add_theme_constant_override("separation", 4)
	scroll.add_child(_products_container)

	return p

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
	fulfill_btn.custom_minimum_size = Vector2(80, 0)
	fulfill_btn.pressed.connect(_on_fulfill_order.bind(order))
	hbox.add_child(fulfill_btn)

	return row

func _make_product_row(item: ItemDefinition) -> Control:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var enabled = item.id in DeliveryManager.enabled_products
	var check = CheckButton.new()
	check.button_pressed = enabled
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

func _section_label(text: String) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.5, 0.75, 1.0))
	return lbl

func _make_label(text: String, color: Color) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	return lbl
