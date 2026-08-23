class_name TerrainScatterRule
extends Resource

## One scatter rule for TerrainScatterSystem: mesh_variants get placed
## wherever the terrain matches BOTH require_texture_id (Terrain3D control
## map, -1 = any) and the [min_height, max_height] world-Y range (defaults
## to unbounded = any height) -- driven purely by terrain data, not a
## hand-placed area, so the same rule scales to however much terrain
## actually exists (see TerrainScatterSystem's class doc for why that
## matters for a real procedural open world).

@export var rule_name: String = "Rule"
@export var mesh_variants: Array[TerrainMeshVariant] = []
## Uniform, non-random scale applied to every instance this rule places.
## Terrain3D mesh scale is a fraction of the mesh's native size (0.2 =
## 20%), not world units, so this is usually well under 1.0.
@export var mesh_scale: float = 1.0

## Terrain3D control-map texture id to require (see world/terrain_biome.gd
## for the index list: 0=grass, 1=gravel, 2=dirt_path, 3=asphalt, 4=rocks,
## 5=grass_2, 6=grass_leaves, 7=dirt). -1 matches any texture.
@export var require_texture_id: int = -1
## World-space height (Y) range this rule applies within. Defaults to
## unbounded ("any height") -- narrow this for e.g. snow-only or
## lowland-only resources later.
@export var min_height: float = -INF
@export var max_height: float = INF

@export_group("Area Fill")
## Scatter attempts per 100 square meters of matching terrain -- scales
## with however much terrain actually exists (see
## TerrainScatterSystem.scatter_all()) instead of a fixed attempt count,
## so density stays consistent whether the map is one Terrain3D region or
## a thousand.
@export var attempts_per_100_sqm: float = 40.0
@export var noise_scale: float = 0.05
@export_range(-1.0, 1.0, 0.01) var density_threshold: float = -0.2
@export var noise_seed: int = 0
@export var placement_seed: int = 0
## Minimum distance between two points from the general scatter (see
## cluster_min_spacing for the tighter distance used within a cluster).
@export var min_spacing: float = 3.0
## Square keep-out zone centered on WORLD origin (e.g. to keep clear of a
## fixed home base/farm) -- 0 disables it.
@export var avoid_center_square: float = 0.0

@export_group("Clustering")
## Chance, per successfully placed point, that it also spawns a tight
## cluster of extras right around it -- on top of the general scatter
## above, not instead of it. Same behavior as RockField's own clustering.
@export_range(0.0, 1.0, 0.01) var cluster_chance: float = 0.0
@export var cluster_size_min: int = 10
@export var cluster_size_max: int = 25
@export var cluster_radius: float = 5.0
## Minimum distance enforced only within cluster infill -- deliberately
## tighter than min_spacing so a cluster reads as a dense clump instead of
## more of the same general spread.
@export var cluster_min_spacing: float = 1.0
