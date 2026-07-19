extends Node

enum Level { DEBUG, INFO, WARNING, ERROR }

const CONSOLE_MIN_LEVEL := Level.WARNING

var _file: FileAccess
var _path: String

func _ready() -> void:
	DirAccess.make_dir_absolute("user://logs")
	var dt = Time.get_datetime_dict_from_system()
	var filename = "session_%04d-%02d-%02d_%02d-%02d-%02d.log" % [
		dt["year"], dt["month"], dt["day"],
		dt["hour"], dt["minute"], dt["second"]
	]
	_path = "user://logs/" + filename
	_file = FileAccess.open(_path, FileAccess.WRITE)
	if not _file:
		push_warning("GameLogger: could not open log file at " + _path)
	_write(Level.INFO, "GameLogger", "Session started -- " + _path)

func debug(category: String, msg: String) -> void:
	_write(Level.DEBUG, category, msg)

func info(category: String, msg: String) -> void:
	_write(Level.INFO, category, msg)

func warning(category: String, msg: String) -> void:
	_write(Level.WARNING, category, msg)

func error(category: String, msg: String) -> void:
	_write(Level.ERROR, category, msg)

func _write(level: int, category: String, msg: String) -> void:
	var level_str: String = ["DEBUG", "INFO ", "WARN ", "ERROR"][level]
	var time := Time.get_time_string_from_system()
	var line := "[%s] [%s] [%s] %s" % [time, level_str, category, msg]

	if _file:
		_file.store_line(line)
		_file.flush()

	print(line)

	if level >= CONSOLE_MIN_LEVEL:
		var console = get_node_or_null("/root/DebugConsole")
		if console:
			console.print_line(line)

func _notification(what: int) -> void:
	if what == NOTIFICATION_CRASH or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_write(Level.ERROR, "GameLogger", "Session ended -- " + ("CRASH" if what == NOTIFICATION_CRASH else "quit"))
		if _file:
			_file.flush()
			_file.close()
