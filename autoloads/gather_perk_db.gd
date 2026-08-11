extends Node

const PERKS_PATH = "res://data/perks/"

var _db: Dictionary = {}

func _ready() -> void:
	_load_all()

func _load_all() -> void:
	_db.clear()
	_scan_dir(PERKS_PATH)

func _scan_dir(path: String) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		push_warning("GatherPerkDB: folder not found: " + path)
		return
	dir.list_dir_begin()
	var entry = dir.get_next()
	while entry != "":
		if dir.current_is_dir() and entry != "." and entry != "..":
			_scan_dir(path + entry + "/")
		elif entry.ends_with(".tres"):
			var res = load(path + entry) as GatherPerkDefinition
			if res and res.id != "":
				_db[res.id] = res
		entry = dir.get_next()
	dir.list_dir_end()

func get_perk(id: String) -> GatherPerkDefinition:
	return _db.get(id, null)

func all_perks() -> Array:
	return _db.values()

func perks_for_stat(stat: String) -> Array:
	return _db.values().filter(func(p): return p.stat == stat)
