extends CanvasLayer

@onready var hints_container: VBoxContainer = $Hints
@onready var money_label: Label = $MoneyLabel
@onready var noclip_label: Label = $NoclipLabel
@onready var node_hp_bar: VBoxContainer = $NodeHpBar
@onready var node_hp_name_label: Label = $NodeHpBar/NameLabel
@onready var node_hp_progress: ProgressBar = $NodeHpBar/Bar

const NODE_HP_HIDE_DELAY: float = 2.0
var _node_hp_hide_timer: float = 0.0

func _ready() -> void:
	add_to_group("hud")
	money_label.text = "$%.2f" % GameState.money
	GameState.money_changed.connect(_on_money_changed)

func _process(delta: float) -> void:
	var controller = get_parent()
	if controller and "freeflying" in controller:
		noclip_label.visible = controller.freeflying
	if node_hp_bar.visible:
		_node_hp_hide_timer -= delta
		if _node_hp_hide_timer <= 0.0:
			node_hp_bar.visible = false

## Shows the shared top-center HP bar for whatever node the player just hit.
## `node_name` is display text (e.g. "Stone", "Oak Tree"); `current`/`max_hp`
## drive the fill percentage. Replaces per-node SubViewport HP bars so we're
## not paying a live render target per scattered mining/tree node.
func show_node_hp(node_name: String, current: int, max_hp: int) -> void:
	if current <= 0:
		node_hp_bar.visible = false
		return
	node_hp_name_label.text = node_name
	node_hp_progress.value = clampf(float(current) / float(max_hp), 0.0, 1.0) * 100.0
	node_hp_bar.visible = true
	_node_hp_hide_timer = NODE_HP_HIDE_DELAY

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
