@tool
extends EditorScript

const MESHES_DIR = "res://addons/city_megakit/downtowncitymegakit/Meshes/"

func _run() -> void:
	var dir = DirAccess.open(MESHES_DIR)
	if dir == null:
		push_error("Could not open Meshes directory")
		return

	var fixed := 0

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tscn"):
			var path = MESHES_DIR + file_name
			var packed = load(path) as PackedScene
			if packed == null:
				file_name = dir.get_next()
				continue

			var scene = packed.instantiate()
			var removed = _strip_static_bodies(scene)

			if removed > 0:
				var new_packed = PackedScene.new()
				new_packed.pack(scene)
				ResourceSaver.save(new_packed, path)
				print("Stripped %d StaticBody3D(s) from: %s" % [removed, file_name])
				fixed += 1

			scene.free()

		file_name = dir.get_next()

	dir.list_dir_end()
	print("Done. Fixed %d files." % fixed)

func _strip_static_bodies(node: Node) -> int:
	var count := 0
	for child in node.get_children():
		if child is StaticBody3D:
			node.remove_child(child)
			child.free()
			count += 1
		else:
			count += _strip_static_bodies(child)
	return count
