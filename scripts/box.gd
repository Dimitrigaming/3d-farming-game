extends Node3D

const SPRITE_MAX_SIZE := 0.28

@onready var static_body: StaticBody3D = $StaticBody3D
@onready var sprites: Array[Sprite3D] = [$SpriteFront, $SpriteBack, $SpriteLeft, $SpriteRight]
@onready var labels: Array[Label3D] = [$LabelFront, $LabelBack, $LabelLeft, $LabelRight]

var item_type: String = ""
var count: int = 0
var max_count: int = 10

func _ready() -> void:
	add_to_group("interactable")
	_update_display()

func add_item(type: String) -> bool:
	if is_full():
		return false
	if item_type == "":
		item_type = type
	elif item_type != type:
		return false
	count += 1
	_update_display()
	return true

func is_full() -> bool:
	return item_type != "" and count >= max_count

func is_empty() -> bool:
	return count <= 0

func interact() -> void:
	var player_inventory = get_tree().get_first_node_in_group("player")
	if player_inventory:
		player_inventory.pick_up_box(self)

func show_tooltip() -> void:
	pass

func hide_tooltip() -> void:
	pass

func set_held(held: bool) -> void:
	static_body.set_collision_layer_value(1, not held)
	static_body.set_collision_mask_value(1, not held)
	if held:
		remove_from_group("interactable")
	else:
		add_to_group("interactable")

func _update_display() -> void:
	if item_type == "":
		for l in labels:
			l.text = ""
		for s in sprites:
			s.visible = false
		return

	for l in labels:
		l.text = "%d/%d" % [count, max_count]

	var icon_path := "res://icons/%s.png" % item_type.to_lower().replace(" ", "_")
	var tex: Texture2D
	if ResourceLoader.exists(icon_path):
		tex = load(icon_path)
	else:
		tex = load("res://icon.svg")

	for s in sprites:
		s.texture = tex
		s.pixel_size = SPRITE_MAX_SIZE / maxf(float(tex.get_width()), float(tex.get_height()))
		s.visible = true
