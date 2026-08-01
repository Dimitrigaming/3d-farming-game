extends Node

const ITEMS_PATH = "res://data/items/"

var _db: Dictionary = {}

func _ready() -> void:
	_load_all()

func _load_all() -> void:
	_db.clear()
	var dir = DirAccess.open(ITEMS_PATH)
	if not dir:
		push_warning("ItemDB: items folder not found at " + ITEMS_PATH)
		return
	dir.list_dir_begin()
	var file = dir.get_next()
	while file != "":
		if file.ends_with(".tres"):
			var res = load(ITEMS_PATH + file) as ItemDefinition
			if res and res.id != "":
				_db[res.id] = res
		file = dir.get_next()
	dir.list_dir_end()

func get_item(id: String) -> ItemDefinition:
	return _db.get(id, null)

func all_items() -> Array:
	return _db.values()
