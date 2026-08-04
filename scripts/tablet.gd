extends CanvasLayer

const PACKING_CRATE = preload("res://models/packing_crate.tscn")

const SHOP_ITEMS: Array[Dictionary] = [
	{ "name": "3D Printer",          "price": 150.0, "scene": "res://models/printer.tscn",             "desc": "Prints products to sell to customers." },
	{ "name": "Small Product Shelf", "price":  75.0, "scene": "res://models/small_product_shelf.tscn", "desc": "Display printed products for customers." },
	{ "name": "Small Station",       "price": 100.0, "scene": "res://models/small_station.tscn",       "desc": "A compact workstation for your store." },
	{ "name": "Small Stock Shelf",   "price":  60.0, "scene": "res://models/small_stock_shelf.tscn",   "desc": "Store extra stock in the back." },
	{ "name": "Register",            "price": 200.0, "scene": "res://models/register.tscn",            "desc": "Process customer purchases." },
]

const TAB_STORE    = 0
const TAB_ORDERS   = 1
const TAB_PRODUCTS = 2
const TAB_QUEUE    = 3
const TAB_SHOP     = 4

var _current_tab: int = TAB_STORE

var _root: Control
var _tab_btns: Array[Button] = []
var _panels: Array[Control] = []

# Store tab
var _money_label: Label
var _blocks_label: Label
var _licenses_label: Label
var _shop_floor_tier_label: Label
var _shop_floor_upgrade_btn: Button
var _production_floor_tier_label: Label
var _production_floor_upgrade_btn: Button

# Orders tab
var _orders_container: VBoxContainer

# Products tab
var _products_container: VBoxContainer

# Queue tab
var _queue_container: VBoxContainer

# Shop tab
var _shop_container: VBoxContainer

func _ready() -> void:
	layer = 20
	visible = false
	_build_ui()
	GameState.money_changed.connect(_on_money_changed)
	DeliveryManager.orders_changed.connect(_on_orders_changed)
	DeliveryManager.products_changed.connect(_on_products_changed)
	await get_tree().process_frame
	_apply_shop_floor_tier(GameState.shop_floor_tier)
	_apply_production_floor_tier(GameState.production_floor_tier)

var _order_refresh_timer: float = 0.0

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

# --- toggle ---

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

# --- tabs ---

func _show_tab(idx: int) -> void:
	_current_tab = idx
	for i in _panels.size():
		_panels[i].visible = (i == idx)
	for i in _tab_btns.size():
		_tab_btns[i].button_pressed = (i == idx)
	match idx:
		TAB_STORE:    _refresh_store()
		TAB_ORDERS:   _refresh_orders()
		TAB_PRODUCTS: _refresh_products()
		TAB_QUEUE:    _refresh_queue()
		TAB_SHOP:     _refresh_shop()

# --- refresh ---

func _refresh_store() -> void:
	_money_label.text = "$%.2f" % GameState.money
	_blocks_label.text = str(GameState.blocks_unlocked)
	_licenses_label.text = "None" if GameState.licenses.is_empty() else "\n".join(GameState.licenses)
	_refresh_upgrade_row(_shop_floor_tier_label, _shop_floor_upgrade_btn,
		GameState.shop_floor_tier, GameState.SHOP_FLOOR_COSTS)
	_refresh_upgrade_row(_production_floor_tier_label, _production_floor_upgrade_btn,
		GameState.production_floor_tier, GameState.PRODUCTION_FLOOR_COSTS)

func _refresh_upgrade_row(tier_lbl: Label, btn: Button, tier: int, costs: Array) -> void:
	if tier_lbl == null or btn == null:
		return
	var max_tier: int = GameState.MAX_ROOM_TIER
	tier_lbl.text = "Tier %d / %d" % [tier, max_tier]
	if tier >= max_tier:
		btn.text = "Maxed"
		btn.disabled = true
	else:
		var cost: float = costs[tier]
		btn.text = "$%.0f" % cost
		btn.disabled = GameState.money < cost

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

func _refresh_queue() -> void:
	for child in _queue_container.get_children():
		child.queue_free()
	var printers = get_tree().get_nodes_in_group("printer")
	if printers.is_empty():
		_queue_container.add_child(_make_label("No printers placed.", Color(0.6, 0.6, 0.6)))
		return
	for printer in printers:
		var status: String
		var color: Color
		if printer.is_printing:
			status = "Printing"
			color = Color(1.0, 0.85, 0.2)
		elif printer.print_finished:
			status = "Ready to collect"
			color = Color(0.3, 1.0, 0.4)
		else:
			status = "Idle"
			color = Color(0.6, 0.6, 0.6)
		var row = HBoxContainer.new()
		var name_lbl = _make_label("Printer", Color.WHITE)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)
		row.add_child(_make_label(status, color))
		_queue_container.add_child(row)
	if not GameState.print_queue.is_empty():
		_queue_container.add_child(_make_label(" Queued jobs ", Color(0.7, 0.7, 0.7)))
		for job in GameState.print_queue:
			_queue_container.add_child(_make_label(str(job.get("model", "Unknown")), Color.WHITE))

func _refresh_shop() -> void:
	for child in _shop_container.get_children():
		child.queue_free()
	for item in SHOP_ITEMS:
		_shop_container.add_child(_make_shop_row(item))

func _on_money_changed(_new_amount: float) -> void:
	if visible and _current_tab == TAB_STORE:
		_refresh_store()
	if visible and _current_tab == TAB_SHOP:
		_refresh_shop()

func _on_orders_changed() -> void:
	if visible and _current_tab == TAB_ORDERS:
		_refresh_orders()

func _on_products_changed() -> void:
	if visible and _current_tab == TAB_PRODUCTS:
		_refresh_products()

# --- purchase ---

func _purchase(item: Dictionary) -> void:
	if not GameState.spend_money(item.price):
		get_node_or_null("/root/GameLogger").warning("Tablet", "not enough money to buy: " + item.name)
		return
	var scene: PackedScene = load(item.scene)
	var crate = PACKING_CRATE.instantiate()
	get_tree().current_scene.add_child(crate)
	crate.pack(item.name, scene)
	var player_inv = get_tree().get_first_node_in_group("player")
	if player_inv:
		player_inv.pick_up_item(crate)
	get_node_or_null("/root/GameLogger").info("Tablet", "purchased %s for $%.2f" % [item.name, item.price])

# --- UI construction ---

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
	title.text = "Store Tablet"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	vbox.add_child(title)

	var tab_bar = HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 4)
	vbox.add_child(tab_bar)

	for i in ["Store Management", "Delivery Orders", "Products", "Print Queue", "Shop"]:
		var btn = Button.new()
		btn.text = i
		btn.toggle_mode = true
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_show_tab.bind(_tab_btns.size()))
		tab_bar.add_child(btn)
		_tab_btns.append(btn)

	vbox.add_child(HSeparator.new())

	var content = Control.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(content)

	_panels.append(_build_store_panel(content))
	_panels.append(_build_orders_panel(content))
	_panels.append(_build_products_panel(content))
	_panels.append(_build_queue_panel(content))
	_panels.append(_build_shop_panel(content))

	var hint = Label.new()
	hint.text = "Press Tab to close"
	hint.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
	hint.add_theme_font_size_override("font_size", 13)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(hint)

func _build_store_panel(parent: Control) -> Control:
	var p = VBoxContainer.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(p)

	p.add_child(_section_label("Finances"))
	var row_bal = _kv_row("Balance", "")
	p.add_child(row_bal)
	_money_label = row_bal.get_child(1)

	p.add_child(_section_label("Store"))
	var row_blk = _kv_row("Blocks Unlocked", "")
	p.add_child(row_blk)
	_blocks_label = row_blk.get_child(1)

	p.add_child(_section_label("Licenses"))
	var row_lic = _kv_row("Active", "")
	p.add_child(row_lic)
	_licenses_label = row_lic.get_child(1)

	p.add_child(_section_label("Room Upgrades"))
	var shop_row = _upgrade_row("Shop Floor")
	p.add_child(shop_row)
	_shop_floor_tier_label = shop_row.get_node("TierLabel")
	_shop_floor_upgrade_btn = shop_row.get_node("UpgradeBtn")
	_shop_floor_upgrade_btn.pressed.connect(_on_upgrade_shop_floor)

	var prod_row = _upgrade_row("Production Floor")
	p.add_child(prod_row)
	_production_floor_tier_label = prod_row.get_node("TierLabel")
	_production_floor_upgrade_btn = prod_row.get_node("UpgradeBtn")
	_production_floor_upgrade_btn.pressed.connect(_on_upgrade_production_floor)

	return p

func _build_orders_panel(parent: Control) -> Control:
	var p = VBoxContainer.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.visible = false
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

func _build_queue_panel(parent: Control) -> Control:
	var p = VBoxContainer.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.visible = false
	parent.add_child(p)

	p.add_child(_section_label("Printers"))
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p.add_child(scroll)

	_queue_container = VBoxContainer.new()
	_queue_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_queue_container)

	return p

func _build_shop_panel(parent: Control) -> Control:
	var p = VBoxContainer.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.visible = false
	parent.add_child(p)

	p.add_child(_section_label("Available Items"))
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p.add_child(scroll)

	_shop_container = VBoxContainer.new()
	_shop_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_container.add_theme_constant_override("separation", 8)
	scroll.add_child(_shop_container)

	return p

func _make_shop_row(item: Dictionary) -> Control:
	var row = PanelContainer.new()
	var row_style = StyleBoxFlat.new()
	row_style.bg_color = Color(0.15, 0.17, 0.2)
	row_style.set_corner_radius_all(6)
	row.add_theme_stylebox_override("panel", row_style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	row.add_child(hbox)

	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)

	var name_lbl = Label.new()
	name_lbl.text = item.name
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	info.add_child(name_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = item.desc
	desc_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	desc_lbl.add_theme_font_size_override("font_size", 13)
	info.add_child(desc_lbl)

	var right = VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(right)

	var price_lbl = Label.new()
	price_lbl.text = "$%.0f" % item.price
	price_lbl.add_theme_font_size_override("font_size", 18)
	var can_afford = GameState.money >= item.price
	price_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4) if can_afford else Color(1.0, 0.4, 0.4))
	right.add_child(price_lbl)

	var btn = Button.new()
	btn.text = "Buy"
	btn.disabled = not can_afford
	btn.custom_minimum_size = Vector2(80, 0)
	btn.pressed.connect(_purchase.bind(item))
	right.add_child(btn)

	return row

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
	var name_lbl = _make_label("%s  ×%d" % [item_name, order["amount"]], Color.WHITE)
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
	var success = DeliveryManager.try_fulfill_order(order)
	if not success:
		# Flash the button or show a hint — for now just refresh so the timer updates
		pass
	_refresh_orders()

# --- helpers ---

func _section_label(text: String) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.5, 0.75, 1.0))
	return lbl

func _kv_row(key: String, value: String) -> HBoxContainer:
	var row = HBoxContainer.new()
	var k = Label.new()
	k.text = key
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	k.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	var v = Label.new()
	v.text = value
	v.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(k)
	row.add_child(v)
	return row

func _upgrade_row(room_name: String) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var name_lbl = Label.new()
	name_lbl.text = room_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	row.add_child(name_lbl)

	var tier_lbl = Label.new()
	tier_lbl.name = "TierLabel"
	tier_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	tier_lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(tier_lbl)

	var btn = Button.new()
	btn.name = "UpgradeBtn"
	btn.text = "Upgrade"
	btn.custom_minimum_size = Vector2(90, 0)
	row.add_child(btn)

	return row

func _on_upgrade_shop_floor() -> void:
	if not GameState.upgrade_shop_floor():
		return
	_apply_shop_floor_tier(GameState.shop_floor_tier)
	_refresh_store()

func _on_upgrade_production_floor() -> void:
	if not GameState.upgrade_production_floor():
		return
	_apply_production_floor_tier(GameState.production_floor_tier)
	_refresh_store()

func _get_floor_node(floor_name: String) -> Node3D:
	var interior = get_tree().get_first_node_in_group("interior_manager")
	if interior == null:
		print("[Tablet] interior_manager group not found")
		return null
	var node = interior.get_node_or_null(floor_name)
	if node == null:
		print("[Tablet] %s not found under Interior" % floor_name)
	return node

func _apply_shop_floor_tier(tier: int) -> void:
	var tiers_node = get_tree().get_first_node_in_group("building_tiers")
	if tiers_node == null:
		print("[Tablet] building_tiers group not found")
		return
	tiers_node.set_tier(tier)

func _apply_production_floor_tier(tier: int) -> void:
	var prod_node = get_tree().get_first_node_in_group("production_tiers")
	if prod_node == null:
		print("[Tablet] production_tiers group not found")
		return
	prod_node.set_tier(tier)

func _make_label(text: String, color: Color) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	return lbl
