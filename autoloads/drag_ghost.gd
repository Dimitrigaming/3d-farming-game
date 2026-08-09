extends CanvasLayer

## Godot's built-in set_drag_preview() attaches to the base viewport, which
## renders *below* any CanvasLayer (Hotbar, InventoryUI, ChestUI, CraftingUI),
## so the preview icon gets visually stuck underneath those panels. This
## overlay sits on a high CanvasLayer instead and manually follows the mouse
## for the duration of any drag, reading the icon from the drag payload.

var _icon: TextureRect

func _ready() -> void:
	layer = 1000
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(40, 40)
	_icon.size = Vector2(40, 40)
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.visible = false
	add_child(_icon)

func _process(_delta: float) -> void:
	var vp = get_viewport()
	var data = vp.gui_get_drag_data()
	var tex = data.get("icon") if data is Dictionary else null
	if tex:
		_icon.texture = tex
		_icon.visible = true
		_icon.global_position = vp.get_mouse_position() - _icon.size / 2.0
	else:
		_icon.visible = false
