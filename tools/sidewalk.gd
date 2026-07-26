@tool
class_name Sidewalk
extends Node3D

## Sidewalk tile placer. Drag width/depth in the Inspector — they snap to
## the nearest 4 m increment. Add PackedScenes to `tiles`; one is chosen
## at random (with a random Y rotation) for every cell in the grid.

const TILE_SIZE: float = 4.0

## Scenes to pick from randomly. Add your 4×4 pavement scenes here.
@export var tiles: Array[PackedScene] = [] : set = _on_tiles_changed

## Total width in metres. Snaps to the nearest multiple of 4.
@export var width: float = 8.0 : set = _on_width_changed

## Total depth in metres. Snaps to the nearest multiple of 4.
@export var depth: float = 8.0 : set = _on_depth_changed

## Change this to get a different random arrangement without moving tiles.
@export var random_seed: int = 0 : set = _on_seed_changed

# ── setters ──────────────────────────────────────────────────────────────────

func _on_tiles_changed(v: Array[PackedScene]) -> void:
	tiles = v
	_rebuild()

func _on_width_changed(v: float) -> void:
	width = maxf(TILE_SIZE, snappedf(v, TILE_SIZE))
	_rebuild()

func _on_depth_changed(v: float) -> void:
	depth = maxf(TILE_SIZE, snappedf(v, TILE_SIZE))
	_rebuild()

func _on_seed_changed(v: int) -> void:
	random_seed = v
	_rebuild()

# ── lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_rebuild()

# ── core ─────────────────────────────────────────────────────────────────────

func _rebuild() -> void:
	if not is_inside_tree():
		return
	if tiles.is_empty():
		return

	# Remove previously generated tiles.
	for child in get_children():
		child.free()

	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed

	var cols := int(width  / TILE_SIZE)
	var rows := int(depth  / TILE_SIZE)
	var root := get_tree().get_edited_scene_root() if Engine.is_editor_hint() else null

	for row in range(rows):
		for col in range(cols):
			var packed: PackedScene = tiles[rng.randi() % tiles.size()]
			if packed == null:
				continue

			var tile: Node3D = packed.instantiate()
			add_child(tile)

			# Assign owner so the instances are visible in the editor tree.
			if root != null:
				tile.owner = root

			# Centre the tile within its cell, centred on this node's origin.
			var x := (col + 0.5) * TILE_SIZE - width  * 0.5
			var z := (row + 0.5) * TILE_SIZE - depth  * 0.5
			tile.position = Vector3(x, 0.0, z)

			# Random 90-degree Y rotation so tiles don't all face the same way.
			tile.rotation_degrees.y = float(rng.randi() % 4) * 90.0
