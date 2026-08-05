# HOW TO RUN: Open this file in Godot's Script editor, then click File > Run (or the ▶ Run button).
# Do NOT attach this script to a node — it extends EditorScript, not Node.
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
	var saved := 0

	for child in root.get_children():
		if child.scene_file_path != "":
			print("SKIP (already scene): ", child.name)
			continue

		var out_path = save_dir.path_join(child.name + ".tscn")
		if ResourceLoader.exists(out_path):
			print("SKIP (file exists): ", child.name)
			continue

		var wrapper = Node3D.new()
		wrapper.name = child.name
		var clone = child.duplicate()
		wrapper.add_child(clone)
		clone.owner = wrapper
		packed.pack(wrapper)
		wrapper.free()

		var err = ResourceSaver.save(packed, out_path)
		if err != OK:
			push_error("Failed to save: " + out_path + " (err %d)" % err)
		else:
			print("Saved: ", out_path)
			saved += 1

	fs.scan()
	print("Done — saved %d scenes." % saved)
