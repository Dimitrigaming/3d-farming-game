@tool
extends EditorScript

## One-off batch export: every ItemDefinition resource under data/items/ that
## has an icon set gets its equip_scene (falling back to place_scene)
## exported as a .glb into res://glb_export/, named after the item's id.
## Items with an icon but no scene (or vice versa) are reported, not
## exported, since there's nothing complete to export.
##
## Safe to re-run any time new items get their icon/scene filled in -- an
## item whose .glb already exists in glb_export/ is skipped entirely (not
## re-exported/overwritten), so only genuinely new or newly-completed items
## do any work on a repeat run.
##
## Run from the Script Editor: open this file, then File > Run (Ctrl+Shift+X).
## Only scans resources that actually cast to ItemDefinition -- other
## data/items/ resource types (FertilizerDefinition, CropDefinition) are a
## different schema entirely and are skipped, not flagged as broken.

const ITEMS_PATH = "res://data/items/"
const EXPORT_PATH = "res://glb_export/"

func _run() -> void:
	var results := {
		"exported": [],
		"skipped": [],
		"missing_scene": [],
		"missing_everything": [],
	}
	_scan_dir(ITEMS_PATH, results)

	print("--- export_item_glbs: done ---")
	print("Exported %d item(s) to %s:" % [results["exported"].size(), EXPORT_PATH])
	for id in results["exported"]:
		print("  " + id)
	print("")
	print("Already had a .glb, skipped (%d):" % results["skipped"].size())
	for id in results["skipped"]:
		print("  " + id)
	print("")
	print("Has icon but NO equip_scene/place_scene (%d):" % results["missing_scene"].size())
	for id in results["missing_scene"]:
		print("  " + id)
	print("")
	print("Has NEITHER icon NOR scene (%d):" % results["missing_everything"].size())
	for id in results["missing_everything"]:
		print("  " + id)

func _scan_dir(path: String, results: Dictionary) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		push_warning("export_item_glbs: folder not found: " + path)
		return
	dir.list_dir_begin()
	var entry = dir.get_next()
	while entry != "":
		if dir.current_is_dir() and entry != "." and entry != "..":
			_scan_dir(path + entry + "/", results)
		elif entry.ends_with(".tres"):
			_process_item(path + entry, results)
		entry = dir.get_next()
	dir.list_dir_end()

func _process_item(file_path: String, results: Dictionary) -> void:
	var res = load(file_path) as ItemDefinition
	if res == null or res.id == "":
		return  # Not an ItemDefinition (FertilizerDefinition/CropDefinition/etc) -- different schema, not in scope.

	var scene: PackedScene = res.equip_scene if res.equip_scene else res.place_scene
	if res.icon == null and scene == null:
		results["missing_everything"].append(res.id)
		return
	if res.icon == null or scene == null:
		results["missing_scene"].append(res.id)
		return

	var out_path := ProjectSettings.globalize_path(EXPORT_PATH + res.id + ".glb")
	if FileAccess.file_exists(out_path):
		results["skipped"].append(res.id)
		return

	var inst = scene.instantiate()
	var gltf_document := GLTFDocument.new()
	var gltf_state := GLTFState.new()
	var err := gltf_document.append_from_scene(inst, gltf_state)
	if err == OK:
		gltf_document.write_to_filesystem(gltf_state, out_path)
		results["exported"].append(res.id)
	else:
		push_warning("export_item_glbs: failed to convert %s (scene %s) to glTF, error %d" % [res.id, scene.resource_path, err])
	inst.free()
