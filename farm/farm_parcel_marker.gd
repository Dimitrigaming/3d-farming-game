extends StaticBody3D

## Procedural "purchase sign" for a locked farm parcel -- built entirely in
## code (mirrors register.gd's Label3D.new() pattern) since there's no
## dedicated fence/sign art asset yet. Follows the same unlock-and-remove
## shape as scripts/interior_block.gd.

var parcel_index: int = 0

func _ready() -> void:
	add_to_group("interactable")
	_build_visual()

func _cost() -> float:
	return GameState.FARM_PARCEL_COSTS[parcel_index - 1]

func _level_req() -> int:
	return GameState.FARM_PARCEL_LEVEL_REQ[parcel_index - 1]

func _label_text() -> String:
	return "Unlock Parcel - $%d (Shop Lv %d)" % [int(_cost()), _level_req()]

func _build_visual() -> void:
	var post_mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.3, 2.0, 0.3)
	post_mesh.mesh = box
	post_mesh.position = Vector3(0, 1.0, 0)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.55, 0.15, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	post_mesh.material_override = mat
	add_child(post_mesh)

	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.3, 2.0, 0.3)
	collision.shape = shape
	collision.position = Vector3(0, 1.0, 0)
	add_child(collision)

	var label = Label3D.new()
	label.text = _label_text()
	label.position = Vector3(0, 2.3, 0)
	label.pixel_size = 0.005
	label.font_size = 32
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = Color(1, 0.85, 0.4, 1)
	add_child(label)

func get_interact_hint() -> String:
	return _label_text()

func interact() -> void:
	if GameState.unlock_farm_parcel():
		queue_free()
		return
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		if GameState.shop_level < _level_req():
			hud.show_notification("Requires Shop Level %d!" % _level_req())
		else:
			hud.show_notification("Not enough money!")
