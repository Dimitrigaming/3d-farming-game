@tool
extends EditorScript

func _run() -> void:
	var root = get_scene()
	if root == null:
		push_error("No scene open.")
		return

	var save_dir = root.scene_file_path.get_base_dir()
	if save_dir == "":
		push_error("Scene has no file path — save the parent scene first.")
		return

	var packed = PackedScene.new()
	var fs = EditorInterface.get_resource_filesystem()

	for child in root.get_children():
		# Already an instanced scene — skip
		if child.scene_file_path != "":
			print("SKIP (already scene): ", child.name)
			continue

		var out_path = save_dir.path_join(child.name + ".tscn")

		# Already saved on disk — skip
		if ResourceLoader.exists(out_path):
			print("SKIP (file exists): ", out_path)
			continue

		# Wrap in a Node3D so the saved scene has the right root type
		var wrapper = Node3D.new()
		wrapper.name = child.name
		var clone = child.duplicate()
		wrapper.add_child(clone)
		clone.owner = wrapper
		packed.pack(wrapper)
		wrapper.free()
		var err = ResourceSaver.save(packed, out_path)
		if err != OK:
			push_error("Failed to save: " + out_path + " (err " + str(err) + ")")
		else:
			print("Saved: ", out_path)

	fs.scan()
	print("Done.")
