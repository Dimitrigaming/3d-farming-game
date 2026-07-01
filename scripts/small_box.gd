extends RigidBody3D

const SPRITE_MAX_SIZE = 0.14
const ITEM_SCENE = preload("res://models/small_default_model.tscn")
const ITEM_SIZE = Vector3(0.1, 0.2, 0.1)
const ITEM_GAP = 0.015
const ITEMS_PER_ROW = 3
const ITEMS_PER_LAYER = 9
const INTERIOR_BOTTOM = -0.175 + 0.0125

@onready var sprites: Array[Sprite3D] = [$SpriteFront, $SpriteBack]
@onready var labels: Array[Label3D] = [$LabelFront, $LabelBack]

var item_type: String = ""
var count: int = 0
var max_count: int = 9
var is_open: bool = false
var item_nodes: Array[Node3D] = []

@onready var lid_left: Node3D = $BoxLidLeft
@onready var lid_right: Node3D = $BoxLidRight

func _ready() -> void:
	add_to_group("interactable")
	_update_display()


func add_item(type: String, from_global_pos: Vector3 = Vector3.ZERO) -> bool:
	if is_full():
		return false
	if item_type == "":
		item_type = type
	elif item_type != type:
		return false
	if not is_open:
		_toggle_lid()
	count += 1
	if from_global_pos != Vector3.ZERO:
		_spawn_item_animated(count - 1, from_global_pos)
	else:
		_spawn_item(count - 1)
	_update_display()
	return true

func is_full() -> bool:
	return item_type != "" and count >= max_count

func is_empty() -> bool:
	return count <= 0

func interact() -> void:
	var player_inventory = get_tree().get_first_node_in_group("player")
	if player_inventory:
		player_inventory.pick_up_item(self)

func show_tooltip() -> void:
	pass

func hide_tooltip() -> void:
	pass

func get_click_hint(_player_inventory) -> String:
	return "Pick Up"

func get_lid_hint() -> String:
	return "Open/Close"

func get_drop_hint() -> String:
	return "Drop"

func set_held(held: bool) -> void:
	if held:
		process_mode = Node.PROCESS_MODE_DISABLED
		collision_layer = 0
		collision_mask = 0
		remove_from_group("interactable")
	else:
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		collision_layer = 1
		collision_mask = 1
		process_mode = Node.PROCESS_MODE_INHERIT
		add_to_group("interactable")

func _toggle_lid() -> void:
	is_open = !is_open
	var tween = get_tree().create_tween().set_parallel(true)
	if is_open:
		tween.tween_property(lid_left, "rotation_degrees:z", -230.0, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(lid_right, "rotation_degrees:z", 230.0, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	else:
		tween.tween_property(lid_left, "rotation_degrees:z", 0.0, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(lid_right, "rotation_degrees:z", 0.0, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func _spawn_item_animated(index: int, from_global_pos: Vector3) -> void:
	var flying = ITEM_SCENE.instantiate()
	get_tree().current_scene.add_child(flying)
	flying.global_position = from_global_pos
	var target_pos = global_position + Vector3(0, 0.2, 0)
	var tween = get_tree().create_tween()
	tween.tween_property(flying, "global_position", target_pos, 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(func():
		flying.queue_free()
		_spawn_item(index)
	)

func _spawn_item(index: int) -> void:
	var item = ITEM_SCENE.instantiate()
	add_child(item)
	item.position = _grid_position(index)
	var mesh = item.get_child(0) as MeshInstance3D
	if mesh and mesh.material_override is ShaderMaterial:
		var mat = mesh.material_override.duplicate() as ShaderMaterial
		mat.set_shader_parameter("clip_height", 999.0)
		mesh.material_override = mat
	item_nodes.append(item)

func _grid_position(index: int) -> Vector3:
	var layer = index / ITEMS_PER_LAYER
	var pos_in_layer = index % ITEMS_PER_LAYER
	var row = pos_in_layer / ITEMS_PER_ROW
	var col = pos_in_layer % ITEMS_PER_ROW
	var x = float(col - 1) * (ITEM_SIZE.x + ITEM_GAP)
	var y = INTERIOR_BOTTOM + ITEM_SIZE.y * 0.5 + float(layer) * (ITEM_SIZE.y + ITEM_GAP)
	var z = float(row - 1) * (ITEM_SIZE.z + ITEM_GAP)
	return Vector3(x, y, z)

func _update_display() -> void:
	if item_type == "":
		for l in labels:
			l.text = ""
		for s in sprites:
			s.visible = false
		return

	for l in labels:
		l.text = "%d/%d" % [count, max_count]

	var icon_path = "res://icons/%s.png" % item_type.to_lower().replace(" ", "_")
	var tex: Texture2D
	if ResourceLoader.exists(icon_path):
		tex = load(icon_path)
	else:
		tex = load("res://icon.svg")

	for s in sprites:
		s.texture = tex
		s.pixel_size = SPRITE_MAX_SIZE / maxf(float(tex.get_width()), float(tex.get_height()))
		s.visible = true
