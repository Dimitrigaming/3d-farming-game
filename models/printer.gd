extends Node3D

const PRINT_MODEL = preload("res://models/print_model.tscn")
const PRINT_SHADER = preload("res://shaders/print_reveal.gdshader")

@onready var tooltip: Label3D = $Tooltip
@onready var print_start: Marker3D = $PrintStart

var print_duration: float = 5.0
var is_printing: bool = false

func _ready() -> void:
	tooltip.visible = false
	add_to_group("interactable")

func show_tooltip() -> void:
	tooltip.visible = true

func hide_tooltip() -> void:
	tooltip.visible = false

func interact() -> void:
	start_print()

func start_print() -> void:
	if is_printing:
		return
	is_printing = true

	var model: Node3D = PRINT_MODEL.instantiate()
	add_child(model)

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
	tween.tween_callback(func(): is_printing = false)
