@tool
extends MeshInstance3D

@export var tile_size: float = 3.0:
	set(v):
		tile_size = max(0.01, v)
		_update()

@export var tile_count: Vector2i = Vector2i(1, 1):
	set(v):
		tile_count = Vector2i(max(1, v.x), max(1, v.y))
		_update()

@export var collision_height: float = 0.2:
	set(v):
		collision_height = max(0.01, v)
		_update()

func _ready():
	_update()

func _update():
	if not mesh:
		mesh = PlaneMesh.new()
	var plane = mesh as PlaneMesh
	if plane:
		plane.size = Vector2(tile_count.x * tile_size, tile_count.y * tile_size)
	var mat = get_active_material(0) as ShaderMaterial
	if mat:
		mat.set_shader_parameter("uv_scale", Vector2(tile_count))
	_update_collision()

func _update_collision():
	if not is_inside_tree():
		return
	var body = get_node_or_null("TiledCollider") as StaticBody3D
	if not body:
		body = StaticBody3D.new()
		body.name = "TiledCollider"
		add_child(body)
		if Engine.is_editor_hint() and get_tree().edited_scene_root:
			body.owner = get_tree().edited_scene_root
	var shape_node = body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if not shape_node:
		shape_node = CollisionShape3D.new()
		body.add_child(shape_node)
		if Engine.is_editor_hint() and get_tree().edited_scene_root:
			shape_node.owner = get_tree().edited_scene_root
	var box = BoxShape3D.new()
	box.size = Vector3(tile_count.x * tile_size, collision_height, tile_count.y * tile_size)
	shape_node.shape = box
	shape_node.position = Vector3(0, -collision_height * 0.5, 0)
