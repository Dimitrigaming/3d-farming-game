extends Node

const CROPS_PATH = "res://data/items/crops/"

var _db: Dictionary = {}

func _ready() -> void:
	_load_all()

func _load_all() -> void:
	_db.clear()
	var dir = DirAccess.open(CROPS_PATH)
	if not dir:
		push_warning("CropDB: folder not found: " + CROPS_PATH)
		return
	dir.list_dir_begin()
	var entry = dir.get_next()
	while entry != "":
		if entry.ends_with(".tres"):
			var res = load(CROPS_PATH + entry)
			if res is CropDefinition and res.id != "":
				_db[res.id] = res
		entry = dir.get_next()
	dir.list_dir_end()

func get_crop(id: String) -> CropDefinition:
	return _db.get(id, null)

func get_crop_for_seed(seed_item_id: String) -> CropDefinition:
	for crop in _db.values():
		if crop.seed_item_id == seed_item_id:
			return crop
	return null

func all_crops() -> Array:
	return _db.values()
