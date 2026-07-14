extends CanvasLayer

@onready var hints_container: VBoxContainer = $Hints
@onready var money_label: Label = $MoneyLabel
@onready var noclip_label: Label = $NoclipLabel

func _ready() -> void:
	add_to_group("hud")
	money_label.text = "$%.2f" % GameState.money
	GameState.money_changed.connect(_on_money_changed)

func _process(_delta: float) -> void:
	var controller = get_parent()
	if controller and "freeflying" in controller:
		noclip_label.visible = controller.freeflying

func _on_money_changed(new_amount: float) -> void:
	money_label.text = "$%.2f" % new_amount

func show_notification(text: String, duration: float = 2.5) -> void:
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(label)
	label.set_anchors_preset(Control.PRESET_CENTER)
	await get_tree().create_timer(duration).timeout
	label.queue_free()

func set_hints(hints: Array[String]) -> void:
	var existing := hints_container.get_children()
	for i in range(hints.size()):
		var label: Label
		if i < existing.size():
			label = existing[i]
		else:
			label = Label.new()
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			label.add_theme_font_size_override("font_size", 22)
			label.add_theme_color_override("font_color", Color.WHITE)
			label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
			label.add_theme_constant_override("shadow_offset_x", 1)
			label.add_theme_constant_override("shadow_offset_y", 1)
			hints_container.add_child(label)
		label.text = hints[i]
		label.visible = true
	for i in range(hints.size(), existing.size()):
		existing[i].visible = false
