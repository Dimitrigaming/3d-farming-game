extends Node3D

const PRINT_MODEL = preload("res://models/print_model.tscn")
const PRINT_SHADER = preload("res://shaders/print_reveal.gdshader")
const PACKING_CRATE_SCENE = preload("res://models/packing_crate.tscn")
const OWN_SCENE = preload("res://models/printer.tscn")

@onready var tooltip: Label3D = $Tooltip
@onready var print_start: Marker3D = $PrintStart

var print_duration: float = 5.0
var is_printing: bool = false
var print_finished: bool = false
var current_model: Node3D = null

func _ready() -> void:
	tooltip.visible = false
	add_to_group("interactable")

func show_tooltip() -> void:
	tooltip.visible = true
	_update_tooltip()

func hide_tooltip() -> void:
	tooltip.visible = false

func interact() -> void:
	start_print()

func get_interact_hint() -> String:
	if is_printing or print_finished:
		return ""
	return "Print"

func get_click_hint(player_inventory) -> String:
	if print_finished:
		return "Collect"
	return ""

func get_move_hint() -> String:
	return "Move"

func get_pack_hint(player_inventory) -> String:
	if player_inventory.held_item == null and not is_printing and not print_finished:
		return "Pack Away"
	return ""

func pack_away(player_inventory) -> void:
	if player_inventory.held_item != null or is_printing or print_finished:
		return
	var crate = PACKING_CRATE_SCENE.instantiate()
	get_tree().current_scene.add_child(crate)
	crate.pack("3D Printer", OWN_SCENE)
	player_inventory.pick_up_item(crate)
	queue_free()

func get_collectable_item_type() -> String:
	if print_finished:
		return "Print Model"
	return ""

func clear_print() -> void:
	if not print_finished:
		return
	if current_model:
		current_model.queue_free()
		current_model = null
	print_finished = false
	_update_tooltip()

func start_print() -> void:
	if is_printing or print_finished:
		return
	is_printing = true

	var model: Node3D = PRINT_MODEL.instantiate()
	add_child(model)
	current_model = model

	# Find the mesh node and get its height so we can align base to PrintStart
	var mesh_node: MeshInstance3D = model.get_child(0)
	var model_height: float = mesh_node.mesh.size.y

	# Place model so its base sits at PrintStart
	model.global_position = print_start.global_position + Vector3(0, model_height * 0.5, 0)

	# Apply the print reveal shader, preserving the model's original color
	var original_color := Color.WHITE
	if mesh_node.material_override and mesh_node.material_override is StandardMaterial3D:
		original_color = (mesh_node.material_override as StandardMaterial3D).albedo_color

	var shader_mat = ShaderMaterial.new()
	shader_mat.shader = PRINT_SHADER
	shader_mat.set_shader_parameter("albedo", original_color)
	mesh_node.material_override = shader_mat

	# Animate clip_height from base to top in world space
	var base_y: float = print_start.global_position.y
	var top_y: float = base_y + model_height

	shader_mat.set_shader_parameter("clip_height", base_y)

	var tween = create_tween()
	tween.tween_method(
		func(h: float): shader_mat.set_shader_parameter("clip_height", h),
		base_y,
		top_y,
		print_duration
	)
	tween.tween_callback(_on_print_complete)

func _on_print_complete() -> void:
	is_printing = false
	print_finished = true
	_update_tooltip()

func _update_tooltip() -> void:
	if print_finished:
		tooltip.text = "3D Printer\nLeft click to collect"
	else:
		tooltip.text = "3D Printer\nPress E to print"
