extends RigidBody3D

const SPRITE_MAX_SIZE = 0.4

@onready var sprites: Array[Sprite3D] = [$SpriteFront, $SpriteBack, $SpriteLeft, $SpriteRight]
@onready var labels: Array[Label3D] = [$LabelFront, $LabelBack, $LabelLeft, $LabelRight]

var packed_item_name: String = ""
var packed_item_scene: PackedScene = null

func _ready() -> void:
	add_to_group("interactable")
	_update_display()

func pack(item_name: String, item_scene: PackedScene) -> void:
	packed_item_name = item_name
	packed_item_scene = item_scene
	_update_display()

func is_packed() -> bool:
	return packed_item_scene != null

func interact() -> void:
	var player_inventory = get_tree().get_first_node_in_group("player")
	if player_inventory:
		player_inventory.pick_up_item(self)

func show_tooltip() -> void:
	pass

func hide_tooltip() -> void:
	pass

func get_interact_hint() -> String:
	return "Pick Up"

func get_drop_hint() -> String:
	return "Store Here"

func get_unpack_hint() -> String:
	return "Unpack"

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

func unpack_at(floor_pos: Vector3, y_rotation: float) -> Node3D:
	if packed_item_scene == null:
		return null
	var item = packed_item_scene.instantiate()
	get_tree().current_scene.add_child(item)
	item.rotation = Vector3(0, y_rotation, 0)
	item.global_position = floor_pos
	item.global_position.y = floor_pos.y + _ground_offset(item)
	return item

func _ground_offset(item: Node3D) -> float:
	var collision_shape: CollisionShape3D = item.get_node_or_null("StaticBody3D/CollisionShape3D")
	if collision_shape == null or collision_shape.shape == null:
		return 0.0
	var shape = collision_shape.shape
	var local_bottom = collision_shape.transform.origin.y
	if shape is BoxShape3D:
		local_bottom -= shape.size.y * 0.5
	elif shape is CylinderShape3D:
		local_bottom -= shape.height * 0.5
	elif shape is CapsuleShape3D:
		local_bottom -= shape.height * 0.5
	return -local_bottom

func _update_display() -> void:
	if packed_item_name == "":
		for l in labels:
			l.text = ""
		for s in sprites:
			s.visible = false
		return

	for l in labels:
		l.text = packed_item_name

	var icon_path = "res://icons/%s.png" % packed_item_name.to_lower().replace(" ", "_")
	var tex: Texture2D
	if ResourceLoader.exists(icon_path):
		tex = load(icon_path)
	else:
		tex = load("res://icon.svg")

	for s in sprites:
		s.texture = tex
		s.pixel_size = SPRITE_MAX_SIZE / maxf(float(tex.get_width()), float(tex.get_height()))
		s.visible = true
