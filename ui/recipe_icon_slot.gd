extends PanelContainer

signal hovered(recipe)
signal clicked(recipe)

var recipe: RecipeDefinition = null
var is_locked: bool = false

@onready var icon: TextureRect = $Icon
@onready var count_label: Label = $Overlay/Count
@onready var cooldown_overlay: ColorRect = $Overlay/CooldownOverlay
@onready var timer_label: Label = $Overlay/TimerLabel

func setup(r: RecipeDefinition) -> void:
	recipe = r
	icon.texture = r.icon
	icon.visible = true

func set_queue_count(count: int) -> void:
	count_label.visible = count > 0
	count_label.text = str(count)

## Greys out the icon and shows the required station level instead of a
## queue/progress indicator when the player hasn't reached it yet.
func set_locked(locked: bool, required_level: int = 1) -> void:
	is_locked = locked
	icon.modulate = Color(0.4, 0.4, 0.4, 1.0) if locked else Color(1, 1, 1, 1)
	if locked:
		cooldown_overlay.visible = false
		timer_label.visible = true
		timer_label.text = "Lv %d" % required_level
		timer_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4, 1))
	else:
		timer_label.remove_theme_color_override("font_color")

## While actively crafting, darkens the icon and wipes the darkness away
## top-to-bottom as progress (0..1) advances, with a countdown label.
func set_progress(active: bool, progress: float = 0.0, seconds_remaining: float = 0.0) -> void:
	if is_locked and not active:
		return
	cooldown_overlay.visible = active
	timer_label.visible = active
	if active:
		cooldown_overlay.anchor_top = clamp(progress, 0.0, 1.0)
		timer_label.text = "%.1fs" % max(seconds_remaining, 0.0)

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
