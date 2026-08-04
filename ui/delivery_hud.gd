extends CanvasLayer

var _locked: bool = true
var _collapsed: bool = false
var _dragging: bool = false
var _drag_offset: Vector2
var _refresh_timer: float = 0.0

@onready var _panel: PanelContainer = $Panel
@onready var _orders_list: VBoxContainer = %OrdersList
@onready var _btn_collapse: Button = %BtnCollapse
@onready var _btn_lock: Button = %BtnLock
@onready var _header: Control = $Panel/VBox/Header

func _ready() -> void:
	_btn_lock.toggled.connect(_on_btn_lock_toggled)
	_btn_collapse.pressed.connect(_on_btn_collapse_pressed)
	_header.gui_input.connect(_on_header_gui_input)
	_header.mouse_filter = Control.MOUSE_FILTER_STOP
	DeliveryManager.orders_changed.connect(_refresh)
	_refresh()

func _process(delta: float) -> void:
	if _dragging:
		_panel.position = get_viewport().get_mouse_position() - _drag_offset

	_refresh_timer += delta
	if _refresh_timer >= 1.0:
		_refresh_timer = 0.0
		_refresh()

func _refresh() -> void:
	for child in _orders_list.get_children():
		child.queue_free()
	if DeliveryManager.active_orders.is_empty():
		var lbl = Label.new()
		lbl.text = "No active orders"
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		lbl.add_theme_font_size_override("font_size", 12)
		_orders_list.add_child(lbl)
		return
	for order in DeliveryManager.active_orders:
		_orders_list.add_child(_make_row(order))

func _make_row(order: Dictionary) -> Control:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	var def = ItemDB.get_item(order["item_id"])
	var name_lbl = Label.new()
	name_lbl.text = "%s x%d" % [def.name if def else order["item_id"], order["amount"]]
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	hbox.add_child(name_lbl)

	var secs = int(order["time_remaining"])
	var time_lbl = Label.new()
	time_lbl.text = "%d:%02d" % [secs / 60, secs % 60]
	time_lbl.add_theme_font_size_override("font_size", 12)
	time_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4) if secs < 60 else Color(1.0, 0.85, 0.2))
	hbox.add_child(time_lbl)

	return hbox

func _on_btn_lock_toggled(pressed: bool) -> void:
	_locked = pressed
	_btn_lock.text = "L"

func _on_btn_collapse_pressed() -> void:
	_collapsed = not _collapsed
	_orders_list.visible = not _collapsed
	_btn_collapse.text = "▲" if _collapsed else "▼"

func _on_header_gui_input(event: InputEvent) -> void:
	if _locked:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_offset = get_viewport().get_mouse_position() - _panel.position
		else:
			_dragging = false
	if event is InputEventMouseMotion and _dragging:
		_panel.position = get_viewport().get_mouse_position() - _drag_offset
