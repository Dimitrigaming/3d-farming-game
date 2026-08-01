@tool
extends Node

@export_dir var folder: String = "res://"
@export_tool_button("Convert FBX → TSCN") var _convert_btn = _run

func _run() -> void:
	if folder == "":
		push_error("FBX Converter: no folder set.")
		return
	var converted := 0
	var skipped := 0
	var failed := 0
	_process_dir(folder.trim_suffix("/") + "/", converted, skipped, failed)
	print("Done. Converted: %d  Skipped: %d  Failed: %d" % [converted, skipped, failed])

func _process_dir(path: String, converted: int, skipped: int, failed: int) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		push_error("FBX Converter: could not open folder: " + path)
		return
	dir.list_dir_begin()
	var entry = dir.get_next()
	while entry != "":
		if dir.current_is_dir() and entry != "." and entry != "..":
			_process_dir(path + entry + "/", converted, skipped, failed)
		elif entry.ends_with(".fbx") or entry.ends_with(".FBX"):
			var fbx_path = path + entry
			var tscn_path = path + entry.get_basename() + ".tscn"
			if ResourceLoader.exists(tscn_path):
				skipped += 1
			else:
				var packed = load(fbx_path)
				if packed == null:
					push_error("FBX Converter: failed to load: " + fbx_path)
					failed += 1
				else:
					var err = ResourceSaver.save(packed, tscn_path)
					if err == OK:
						converted += 1
						print("Converted: " + fbx_path)
					else:
						push_error("FBX Converter: failed to save: " + tscn_path)
						failed += 1
		entry = dir.get_next()
	dir.list_dir_end()
