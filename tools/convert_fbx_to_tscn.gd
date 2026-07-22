@tool
extends EditorScript

const TOON_DIR = "res://addons/Toon/"

func _run() -> void:
	var converted := 0
	var skipped := 0
	var failed := 0
	_process_dir(TOON_DIR, converted, skipped, failed)
	print("Done. Converted: %d  Skipped: %d  Failed: %d" % [converted, skipped, failed])

func _process_dir(path: String, converted: int, skipped: int, failed: int) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		push_error("Could not open: " + path)
		return

	dir.list_dir_begin()
	var name = dir.get_next()
	while name != "":
		if dir.current_is_dir() and name != "." and name != "..":
			_process_dir(path + name + "/", converted, skipped, failed)
		elif name.ends_with(".fbx") or name.ends_with(".FBX"):
			var fbx_path = path + name
			var tscn_path = path + name.get_basename() + ".tscn"
			if ResourceLoader.exists(tscn_path):
				skipped += 1
			else:
				var packed = load(fbx_path)
				if packed == null:
					push_error("Failed to load: " + fbx_path)
					failed += 1
				else:
					var err = ResourceSaver.save(packed, tscn_path)
					if err == OK:
						converted += 1
						print("Converted: " + fbx_path)
					else:
						push_error("Failed to save: " + tscn_path + " err=" + str(err))
						failed += 1
		name = dir.get_next()
	dir.list_dir_end()
