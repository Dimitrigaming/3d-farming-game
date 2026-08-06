@tool
extends Node3D

@export_tool_button("Save All Children as Scenes") var _btn: Callable = save_children

func save_children() -> void:
	var scene_path = get_tree().edited_scene_root.scene_file_path
	if scene_path == "":
		push_error("Save the parent scene to disk first.")
		return

	var save_dir = scene_path.get_base_dir()
	var saved := 0

	for child in get_children():
		if child.scene_file_path != "":
			print("SKIP (already a scene): ", child.name)
			continue

		var out_path = save_dir.path_join(child.name + ".tscn")

		var wrapper := Node3D.new()
		wrapper.name = child.name
		var clone := child.duplicate()
		wrapper.add_child(clone)
		clone.owner = wrapper

		var packed := PackedScene.new()
		packed.pack(wrapper)
		wrapper.free()

		var err := ResourceSaver.save(packed, out_path)
		if err == OK:
			print("Saved: ", out_path)
			saved += 1
		else:
			push_error("Failed to save %s (err %d)" % [out_path, err])

	EditorInterface.get_resource_filesystem().scan()
	print("Done — %d scenes saved." % saved)
