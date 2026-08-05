extends PanelContainer

@onready var _icon: TextureRect = %ProductIcon
@onready var _name_lbl: Label = %ProductName
@onready var _market_lbl: Label = %MarketPrice
@onready var _price_lbl: Label = %PriceValue
@onready var _demand_lbl: Label = %DemandLabel
@onready var _active_btn: Button = %ActiveBtn
@onready var _btn_minus: Button = %BtnMinus
@onready var _btn_plus: Button = %BtnPlus

var _item_id: String = ""

func setup(item: ItemDefinition) -> void:
	_item_id = item.id
	_icon.texture = item.icon
	_icon.visible = item.icon != null
	_name_lbl.text = item.name
	_market_lbl.text = "Market Price: $%d" % item.sell_price
	_btn_minus.pressed.connect(_on_minus)
	_btn_plus.pressed.connect(_on_plus)
	_active_btn.pressed.connect(_on_active_toggle)
	_refresh()

func _refresh() -> void:
	var price = DeliveryManager.get_product_price(_item_id)
	_price_lbl.text = "$%d" % int(price)

	var demand = DeliveryManager.get_demand_percent(_item_id)
	_demand_lbl.text = "%.0f%% demand" % demand
	if demand >= 75.0:
		_demand_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	elif demand >= 40.0:
		_demand_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	else:
		_demand_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))

	var enabled = DeliveryManager.is_product_enabled(_item_id)
	_active_btn.text = "Active" if enabled else "Inactive"
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.6, 0.2) if enabled else Color(0.55, 0.15, 0.15)
	style.set_corner_radius_all(4)
	_active_btn.add_theme_stylebox_override("normal", style)
	var style_hover = style.duplicate()
	style_hover.bg_color = Color(0.2, 0.75, 0.25) if enabled else Color(0.7, 0.18, 0.18)
	_active_btn.add_theme_stylebox_override("hover", style_hover)

func _on_minus() -> void:
	DeliveryManager.set_product_price(_item_id, DeliveryManager.get_product_price(_item_id) - 1.0)
	_refresh()

func _on_plus() -> void:
	DeliveryManager.set_product_price(_item_id, DeliveryManager.get_product_price(_item_id) + 1.0)
	_refresh()

func _on_active_toggle() -> void:
	DeliveryManager.set_product_enabled(_item_id, not DeliveryManager.is_product_enabled(_item_id))
	_refresh()
