extends CanvasLayer

const DISPLAY_TIME: float = 2.5
const FADE_TIME: float = 0.5

@onready var _list: VBoxContainer = $List
@onready var _inventory: PlayerInventoryData = get_node("../PlayerInventoryData")

# Tracks active notifications: item_id -> {label, timer, amount}
var _active: Dictionary = {}

func _ready() -> void:
	_inventory.item_acquired.connect(_on_item_acquired)

func _on_item_acquired(item_id: String, amount: int) -> void:
	if item_id in _active:
		var entry = _active[item_id]
		entry["amount"] += amount
		var def = ItemDB.get_item(item_id)
		var name = def.name if def else item_id
		entry["label"].text = "+%d  %s" % [entry["amount"], name]
		entry["timer"] = DISPLAY_TIME
		entry["label"].modulate.a = 1.0
		return

	var def = ItemDB.get_item(item_id)
	var label = Label.new()
	label.text = "+%d  %s" % [amount, def.name if def else item_id]
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.9, 1.0, 0.75))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	_list.add_child(label)

	_active[item_id] = {"label": label, "timer": DISPLAY_TIME, "amount": amount}

func _process(delta: float) -> void:
	var to_remove: Array[String] = []
	for item_id in _active:
		var entry = _active[item_id]
		entry["timer"] -= delta
		if entry["timer"] <= 0.0:
			to_remove.append(item_id)
		elif entry["timer"] < FADE_TIME:
			entry["label"].modulate.a = entry["timer"] / FADE_TIME
	for item_id in to_remove:
		_active[item_id]["label"].queue_free()
		_active.erase(item_id)
