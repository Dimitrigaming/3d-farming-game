@tool
extends EditorScript

const MESHES_DIR = "res://addons/city_megakit/downtowncitymegakit/Meshes/"

func _run() -> void:
	var dir = DirAccess.open(MESHES_DIR)
	if dir == null:
		push_error("Could not open Meshes directory")
		return

	var converted := 0
	var failed := 0

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".gltf"):
			var gltf_path = MESHES_DIR + file_name
			var tscn_path = MESHES_DIR + file_name.get_basename() + ".tscn"

			# Skip if tscn already exists
			if ResourceLoader.exists(tscn_path):
				file_name = dir.get_next()
				continue

			var packed = load(gltf_path)
			if packed == null:
				push_error("Failed to load: " + gltf_path)
				failed += 1
				file_name = dir.get_next()
				continue

			var err = ResourceSaver.save(packed, tscn_path)
			if err == OK:
				converted += 1
				print("Converted: " + file_name)
			else:
				push_error("Failed to save: " + tscn_path + " (error " + str(err) + ")")
				failed += 1

		file_name = dir.get_next()

	dir.list_dir_end()
	print("Done. Converted: %d  Failed: %d" % [converted, failed])
