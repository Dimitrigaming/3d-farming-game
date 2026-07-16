extends Node
class_name GameLogger

enum Level { DEBUG, INFO, WARNING, ERROR }

const CONSOLE_MIN_LEVEL := Level.WARNING

static var _file: FileAccess
static var _path: String

func _ready() -> void:
	DirAccess.make_dir_absolute("user://logs")
	var dt = Time.get_datetime_dict_from_system()
	var filename = "session_%04d-%02d-%02d_%02d-%02d-%02d.log" % [
		dt["year"], dt["month"], dt["day"],
		dt["hour"], dt["minute"], dt["second"]
	]
	Logger._path = "user://logs/" + filename
	Logger._file = FileAccess.open(Logger._path, FileAccess.WRITE)
	if not Logger._file:
		push_warning("Logger: could not open log file at " + Logger._path)
	Logger._write(Level.INFO, "Logger", "Session started — " + Logger._path)

static func debug(category: String, msg: String) -> void:
	_write(Level.DEBUG, category, msg)

static func info(category: String, msg: String) -> void:
	_write(Level.INFO, category, msg)

static func warning(category: String, msg: String) -> void:
	_write(Level.WARNING, category, msg)

static func error(category: String, msg: String) -> void:
	_write(Level.ERROR, category, msg)

static func _write(level: int, category: String, msg: String) -> void:
	var level_str: String = ["DEBUG", "INFO ", "WARN ", "ERROR"][level]
	var time := Time.get_time_string_from_system()
	var line := "[%s] [%s] [%s] %s" % [time, level_str, category, msg]

	if _file:
		_file.store_line(line)
		_file.flush()

	print(line)

	if level >= CONSOLE_MIN_LEVEL:
		var tree := Engine.get_main_loop() as SceneTree
		if tree:
			var console = tree.root.get_node_or_null("DebugConsole")
			if console:
				console.print_line(line)

func _notification(what: int) -> void:
	if what == NOTIFICATION_CRASH or what == NOTIFICATION_WM_CLOSE_REQUEST:
		Logger._write(Level.ERROR, "Logger", "Session ended — " + ("CRASH" if what == NOTIFICATION_CRASH else "quit"))
		if Logger._file:
			Logger._file.flush()
			Logger._file.close()
