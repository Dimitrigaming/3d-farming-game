extends CanvasLayer

const TAB_STORE = 0
const TAB_QUEUE = 1

var _current_tab: int = TAB_STORE

# UI nodes built in _ready
var _root: Control
var _tab_btns: Array[Button] = []
var _panels: Array[Control] = []

# Store tab
var _money_label: Label
var _blocks_label: Label
var _licenses_label: Label

# Queue tab
var _queue_container: VBoxContainer

func _ready() -> void:
	layer = 20
	visible = false
	_build_ui()
	GameState.money_changed.connect(_on_money_changed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("tablet"):
		_toggle()
		get_viewport().set_input_as_handled()

# ── toggle ──────────────────────────────────────────────────────────────────

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

# ── tab switching ────────────────────────────────────────────────────────────

func _show_tab(idx: int) -> void:
	_current_tab = idx
	for i in _panels.size():
		_panels[i].visible = (i == idx)
	for i in _tab_btns.size():
		_tab_btns[i].button_pressed = (i == idx)
	match idx:
		TAB_STORE: _refresh_store()
		TAB_QUEUE: _refresh_queue()

# ── data refresh ─────────────────────────────────────────────────────────────

func _refresh_store() -> void:
	_money_label.text = "$%.2f" % GameState.money
	_blocks_label.text = str(GameState.blocks_unlocked)
	if GameState.licenses.is_empty():
		_licenses_label.text = "None"
	else:
		_licenses_label.text = "\n".join(GameState.licenses)

func _refresh_queue() -> void:
	for child in _queue_container.get_children():
		child.queue_free()

	var printers = get_tree().get_nodes_in_group("printer")
	if printers.is_empty():
		_queue_container.add_child(_row_label("No printers placed.", Color(0.6, 0.6, 0.6)))
		return

	for printer in printers:
		var status: String
		var color: Color
		if printer.is_printing:
			status = "Printing…"
			color = Color(1.0, 0.85, 0.2)
		elif printer.print_finished:
			status = "Ready to collect"
			color = Color(0.3, 1.0, 0.4)
		else:
			status = "Idle"
			color = Color(0.6, 0.6, 0.6)

		var row = HBoxContainer.new()
		var name_lbl = Label.new()
		name_lbl.text = "Printer"
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_color_override("font_color", Color.WHITE)
		var status_lbl = Label.new()
		status_lbl.text = status
		status_lbl.add_theme_color_override("font_color", color)
		row.add_child(name_lbl)
		row.add_child(status_lbl)
		_queue_container.add_child(row)

	# GameState queued jobs (future use)
	if not GameState.print_queue.is_empty():
		_queue_container.add_child(_row_label("— Queued jobs —", Color(0.7, 0.7, 0.7)))
		for job in GameState.print_queue:
			var lbl = _row_label(str(job.get("model", "Unknown")), Color.WHITE)
			_queue_container.add_child(lbl)

func _on_money_changed(new_amount: float) -> void:
	if visible and _current_tab == TAB_STORE:
		_money_label.text = "$%.2f" % new_amount

# ── UI construction ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	# dim background
	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.55)
	_root.add_child(bg)

	# tablet panel — centered, fixed size
	var panel = Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(600, 420)
	panel.offset_left = -300
	panel.offset_top = -210
	panel.offset_right = 300
	panel.offset_bottom = 210
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.12, 0.15)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.border_color = Color(0.25, 0.28, 0.35)
	panel_style.border_width_bottom = 2
	panel_style.border_width_top = 2
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel.add_theme_stylebox_override("panel", panel_style)
	_root.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 16
	vbox.offset_top = 12
	vbox.offset_right = -16
	vbox.offset_bottom = -12
	panel.add_child(vbox)

	# title
	var title = Label.new()
	title.text = "Store Tablet"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	vbox.add_child(title)

	# tab bar
	var tab_bar = HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 4)
	vbox.add_child(tab_bar)

	var tab_names = ["Store Management", "Print Queue"]
	for i in tab_names.size():
		var btn = Button.new()
		btn.text = tab_names[i]
		btn.toggle_mode = true
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_show_tab.bind(i))
		tab_bar.add_child(btn)
		_tab_btns.append(btn)

	# separator
	var sep = HSeparator.new()
	vbox.add_child(sep)

	# content area
	var content = Control.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(content)

	_panels.append(_build_store_panel(content))
	_panels.append(_build_queue_panel(content))

	# close hint
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
	p.add_child(_kv_row("Balance", ""))
	_money_label = p.get_child(p.get_child_count() - 1).get_child(1)

	p.add_child(_section_label("Store"))
	p.add_child(_kv_row("Blocks Unlocked", ""))
	_blocks_label = p.get_child(p.get_child_count() - 1).get_child(1)

	p.add_child(_section_label("Licenses"))
	var lic_row = _kv_row("Active", "")
	p.add_child(lic_row)
	_licenses_label = lic_row.get_child(1)

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

# ── helpers ──────────────────────────────────────────────────────────────────

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

func _row_label(text: String, color: Color) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	return lbl
