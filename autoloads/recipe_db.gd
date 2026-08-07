extends Node

const RECIPES_PATH = "res://data/recipes/"

var _db: Dictionary = {}

func _ready() -> void:
	_load_all()

func _load_all() -> void:
	_db.clear()
	_scan_dir(RECIPES_PATH)

func _scan_dir(path: String) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		push_warning("RecipeDB: folder not found: " + path)
		return
	dir.list_dir_begin()
	var entry = dir.get_next()
	while entry != "":
		if dir.current_is_dir() and entry != "." and entry != "..":
			_scan_dir(path + entry + "/")
		elif entry.ends_with(".tres"):
			var res = load(path + entry) as RecipeDefinition
			if res and res.id != "":
				_db[res.id] = res
		entry = dir.get_next()
	dir.list_dir_end()

func get_recipe(id: String) -> RecipeDefinition:
	return _db.get(id, null)

func all_recipes() -> Array:
	return _db.values()

func recipes_for_station(station_type: String) -> Array:
	return _db.values().filter(func(r): return r.station_type == station_type)
