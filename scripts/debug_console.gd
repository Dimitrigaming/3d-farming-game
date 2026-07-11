extends CanvasLayer

const MAX_LINES: int = 200

var c_lines: PackedStringArray = []
var c_commands: Dictionary = {}
var c_history: Array[String] = []
var c_history_index: int = -1
var c_visible: bool = false

@onready var c_panel: PanelContainer = $Panel
@onready var c_output: RichTextLabel = $Panel/VBox/Output
@onready var c_line_edit: LineEdit = $Panel/VBox/Input

func _ready() -> void:
	c_panel.visible = false
	c_line_edit.text_submitted.connect(_on_submit)
	c_line_edit.gui_input.connect(_on_line_edit_gui_input)
	register_command("help", _cmd_help, "List all commands")
	register_command("clear", _cmd_clear, "Clear the console")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("console"):
		c_visible = not c_visible
		c_panel.visible = c_visible
		if c_visible:
			c_line_edit.grab_focus()
			_set_player_input(false)
		else:
			_set_player_input(true)
		get_viewport().set_input_as_handled()

func _set_player_input(enabled: bool) -> void:
	var controller = get_tree().get_first_node_in_group("proto_controller")
	if controller == null:
		return
	if enabled:
		controller.capture_mouse()
	else:
		controller.release_mouse()
		controller.set_physics_process(false)
		controller.set_process_unhandled_input(false)
	if not enabled:
		return
	controller.set_physics_process(true)
	controller.set_process_unhandled_input(true)

func print_line(text: String) -> void:
	c_lines.append(text)
	if c_lines.size() > MAX_LINES:
		c_lines = c_lines.slice(c_lines.size() - MAX_LINES)
	c_output.text = "\n".join(c_lines)
	await get_tree().process_frame
	c_output.scroll_to_line(c_output.get_line_count())

func register_command(name: String, callable: Callable, description: String = "") -> void:
	c_commands[name] = {callable = callable, description = description}

func _on_submit(text: String) -> void:
	var trimmed = text.strip_edges()
	c_line_edit.clear()
	if trimmed.is_empty():
		return
	c_history.push_front(trimmed)
	c_history_index = -1
	print_line("> " + trimmed)
	_execute(trimmed)

func _execute(text: String) -> void:
	var parts = text.split(" ", false)
	if parts.is_empty():
		return
	var cmd = parts[0].to_lower()
	if not c_commands.has(cmd):
		print_line("[color=red]Unknown command: %s[/color]" % cmd)
		return
	c_commands[cmd].callable.call(parts.slice(1))

func _on_line_edit_gui_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	if event.keycode == KEY_UP:
		if c_history.is_empty():
			return
		c_history_index = mini(c_history_index + 1, c_history.size() - 1)
		c_line_edit.text = c_history[c_history_index]
		c_line_edit.caret_column = c_line_edit.text.length()
	elif event.keycode == KEY_DOWN:
		if c_history_index <= 0:
			c_history_index = -1
			c_line_edit.clear()
			return
		c_history_index -= 1
		c_line_edit.text = c_history[c_history_index]
		c_line_edit.caret_column = c_line_edit.text.length()

func _cmd_help(_args: Array) -> void:
	print_line("[color=yellow]Available commands:[/color]")
	for cmd_name in c_commands:
		print_line("  [color=cyan]%s[/color] — %s" % [cmd_name, c_commands[cmd_name].description])

func _cmd_clear(_args: Array) -> void:
	c_lines.clear()
	c_output.text = ""
