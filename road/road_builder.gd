@tool
class_name RoadBuilder
extends Node3D

## Places road_pieces end-to-end in a straight line from StartingPoint to
## EndingPoint. Move the two markers in the editor, assign one or more
## road piece scenes, then press the "Render Road" button in the
## Inspector to bake the path. Re-pressing clears and regenerates.
##
## Each piece is assumed to face forward along its local -Z axis (Godot's
## look_at convention) -- rotate your source .tscn so its "travel"
## direction is -Z if it comes out sideways after rendering.

@export var road_pieces: Array[PackedScene] = []
@export var piece_length: float = 4.0
@export_tool_button("Render Road", "Reload") var render_action: Callable = render_road
@export_tool_button("Clear Road", "Clear") var clear_action: Callable = clear_road

var start_point: Marker3D
var end_point: Marker3D
var _pieces_root: Node3D

func _ready() -> void:
	_ensure_markers()
	_ensure_pieces_root()

func _ensure_markers() -> void:
	start_point = get_node_or_null("StartingPoint")
	if start_point == null:
		start_point = Marker3D.new()
		start_point.name = "StartingPoint"
		add_child(start_point)
		start_point.position = Vector3(0.0, 0.0, 0.0)
		_bake_owner(start_point)
	end_point = get_node_or_null("EndingPoint")
	if end_point == null:
		end_point = Marker3D.new()
		end_point.name = "EndingPoint"
		add_child(end_point)
		end_point.position = Vector3(0.0, 0.0, 10.0)
		_bake_owner(end_point)

func _ensure_pieces_root() -> void:
	_pieces_root = get_node_or_null("RoadPieces")
	if _pieces_root == null:
		_pieces_root = Node3D.new()
		_pieces_root.name = "RoadPieces"
		add_child(_pieces_root)
		_bake_owner(_pieces_root)

func _bake_owner(node: Node) -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		var root := get_tree().edited_scene_root
		if root != null:
			node.owner = root

func render_road() -> void:
	_ensure_markers()
	_ensure_pieces_root()
	clear_road()

	if road_pieces.is_empty():
		push_warning("RoadBuilder: assign at least one scene to road_pieces before rendering.")
		return

	var from: Vector3 = start_point.position
	var to: Vector3 = end_point.position
	var diff := to - from
	var dist := diff.length()
	if dist < 0.01:
		push_warning("RoadBuilder: Starting Point and Ending Point are too close together.")
		return

	var dir := diff.normalized()
	var facing := Basis.looking_at(dir, Vector3.UP)
	var count: int = maxi(1, int(round(dist / piece_length)))
	var spacing: float = dist / count

	for i in count:
		var t := (i + 0.5) * spacing
		var pos := from + dir * t
		var scene: PackedScene = road_pieces[i % road_pieces.size()]
		var piece := scene.instantiate()
		_pieces_root.add_child(piece)
		piece.transform = Transform3D(facing, pos)
		_bake_owner(piece)
		for child in piece.get_children():
			_bake_owner_recursive(child)

func _bake_owner_recursive(node: Node) -> void:
	_bake_owner(node)
	for child in node.get_children():
		_bake_owner_recursive(child)

func clear_road() -> void:
	_ensure_pieces_root()
	for child in _pieces_root.get_children():
		_pieces_root.remove_child(child)
		child.free()
