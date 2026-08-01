@tool
extends Node3D

@export var width: float = 1.0:
	set(v):
		width = v
		_rebuild()

@export var length: float = 1.0:
	set(v):
		length = v
		_rebuild()

@export var cols: int = 20:
	set(v):
		cols = v
		_rebuild()

@export var rows: int = 40:
	set(v):
		rows = v
		_rebuild()

@export var amplitude: float = 0.03:
	set(v):
		amplitude = v
		_rebuild()

@export var frequency: float = 12.0:
	set(v):
		frequency = v
		_rebuild()

func _ready() -> void:
	_rebuild()

func _rebuild() -> void:
	var surface = get_node_or_null("Surface") as MeshInstance3D
	if not surface:
		return
	surface.mesh = _make_wave_mesh()

func _make_wave_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var indices := PackedInt32Array()

	for r in range(rows + 1):
		for c in range(cols + 1):
			var x := (c / float(cols)) * width - width * 0.5
			var z := (r / float(rows)) * length - length * 0.5
			var y := sin(z * frequency) * amplitude
			verts.append(Vector3(x, y, z))
			norms.append(_calc_normal(z))

	for r in range(rows):
		for c in range(cols):
			var i := r * (cols + 1) + c
			indices.append(i)
			indices.append(i + 1)
			indices.append(i + cols + 1)
			indices.append(i + 1)
			indices.append(i + cols + 2)
			indices.append(i + cols + 1)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _calc_normal(z: float) -> Vector3:
	var slope := cos(z * frequency) * amplitude * frequency
	return Vector3(0.0, 1.0, -slope).normalized()
