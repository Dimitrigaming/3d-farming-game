@tool
class_name GroundPainter
extends CSGBox3D

## Editor-only tool: resize this box over an area (same workflow as
## NodePainter/GrassField/RockField/TreeField), pick a Terrain3D texture
## index, and press "Paint" to write that texture directly onto the ground
## under the box's footprint -- e.g. a clean asphalt walkway instead of
## the blocky placeholder gravel path it's replacing.
##
## Unlike every *Field/NodePainter tool in this project, this does NOT
## regenerate on _ready() -- painting the terrain is a PERSISTENT edit to
## Terrain3D's own region data (same as using its manual brush), not
## something to redo every time the game runs. Press "Paint" once in the
## editor for each box/leg of the path, then this node has done its job --
## safe to leave in the scene (it frees itself at runtime and does nothing)
## or delete it, since the paint already lives in the terrain data.
##
## For an L/U-shaped path, place one box per straight leg and paint each
## (same "chain rectangles together" pattern tools/sidewalk.gd already uses
## for the city's sidewalks) -- a single box is always a rectangle.

## Terrain3D texture indices, from world/terrain_biome.gd:
## 0=Map(grass), 1=gravel, 2=dirt_path2, 3=asphalt, 4=rocks, 5=grass_2,
## 6=grass_leaves, 7=dirt(farm-tilled)
@export var texture_id: int = 3
## Grid resolution the box's footprint gets sampled at when painting --
## 0.5m matches farm_grid.gd's own proven dirt-painting spacing.
@export var sample_spacing: float = 0.5

@warning_ignore("unused_private_class_variable")
@export_tool_button("Paint", "Play") var _paint_btn = paint_terrain

func _ready() -> void:
	if not Engine.is_editor_hint():
		queue_free()

## Samples the box's own X/Z footprint (centered on this node, same
## half-extent convention as NodePainter's area_size) on a sample_spacing
## grid and writes texture_id at every point via Terrain3D's own
## get/set_control_* scripting API -- see farm_grid.gd's _paint_terrain_dirt
## for why these paired accessors are used instead of hand-packing
## set_control() directly (confirmed via readback that the raw path
## silently doesn't stick).
func paint_terrain() -> void:
	var terrain = _find_terrain()
	if terrain == null or terrain.data == null:
		push_warning("GroundPainter: no Terrain3D found, aborting.")
		return

	var half_w = size.x / 2.0
	var half_d = size.z / 2.0
	var nx = maxi(1, roundi(size.x / sample_spacing))
	var nz = maxi(1, roundi(size.z / sample_spacing))
	var painted := 0
	for ix in range(nx + 1):
		for iz in range(nz + 1):
			var x = lerp(-half_w, half_w, float(ix) / nx)
			var z = lerp(-half_d, half_d, float(iz) / nz)
			var world_pos: Vector3 = global_transform * Vector3(x, 0.0, z)
			terrain.data.set_control_base_id(world_pos, texture_id)
			terrain.data.set_control_overlay_id(world_pos, texture_id)
			terrain.data.set_control_blend(world_pos, 0.0)
			painted += 1
	# GPU-side control texture needs an explicit refresh after scripted
	# per-point edits, same as Terrain3D's own importer.gd does.
	terrain.data.update_maps(Terrain3DRegion.TYPE_CONTROL, true, false)
	print("GroundPainter: painted %d points with texture_id=%d over size=%s at %s" % [painted, texture_id, size, global_transform.origin])

## Same lookup as world/nodes/node_painter.gd's _find_terrain().
func _find_terrain() -> Node:
	var root = get_tree().edited_scene_root if Engine.is_editor_hint() else get_tree().root
	if root == null:
		return null
	var found: Array = root.find_children("", "Terrain3D", true, false)
	return found[0] if found.size() > 0 else null
