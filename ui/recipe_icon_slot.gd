extends PanelContainer

signal hovered(recipe)
signal clicked(recipe)

var recipe: RecipeDefinition = null

@onready var icon: TextureRect = $Icon
@onready var count_label: Label = $Overlay/Count

func setup(r: RecipeDefinition) -> void:
	recipe = r
	icon.texture = r.icon
	icon.visible = true

func set_queue_count(count: int) -> void:
	count_label.visible = count > 0
	count_label.text = str(count)

func set_highlighted(is_highlighted: bool) -> void:
	if is_highlighted:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.784, 0.573, 0.165, 0.18)
		style.set_border_width_all(2)
		style.border_color = Color(0.784, 0.573, 0.165, 0.8)
		add_theme_stylebox_override("panel", style)
	else:
		remove_theme_stylebox_override("panel")

func _ready() -> void:
	mouse_entered.connect(func(): hovered.emit(recipe))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(recipe)
		accept_event()
