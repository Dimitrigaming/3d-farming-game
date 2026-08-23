class_name TerrainMeshVariant
extends Resource

## One weighted entry in TerrainMeshScatter's mesh_variants list -- lets a
## single scatter pass mix several Terrain3D mesh_list ids (e.g. rock_mesh_1
## through rock_mesh_4) instead of placing just one. weight is relative,
## not a strict percentage, same convention as world/nodes/weighted_scene.gd.
@export var mesh_id: int = 0
@export var weight: float = 1.0
