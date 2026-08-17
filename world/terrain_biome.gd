class_name TerrainBiome
extends Resource

## One entry in TerrainSeedGenerator's biomes list. Biomes blend smoothly
## into their neighbors in the list (see generator's _sample_biome()) --
## order them so adjacent entries make sense next to each other, e.g.
## [Plains, Hills, Mountains] rather than [Plains, Mountains, Hills].

@export var biome_name: String = "Biome"
## Added on top of the generator's own flat_height for this region's
## baseline elevation -- e.g. 40 for a raised plateau/mountain biome, -10
## for a sunken valley, 0 for normal ground level.
@export var base_height: float = 0.0
## Multiplies the generator's global noise_amplitude -- under 1.0 for
## gentler/flatter regions, over 1.0 for rougher/taller ones.
@export var amplitude_multiplier: float = 1.0

## Indices into Terrain3D's real texture list -- as of this project's
## Map.tscn: 0=Map(grass), 1=gravel, 2=dirt_path2, 3=asphalt_2048x2048,
## 4=rocks, 5=grass_2, 6=grass_leaves. Defaults here point at grass_2/
## rocks rather than 0/1 -- an earlier version of this generator assumed
## only 2 textures existed and defaulted to 0/1, which silently painted
## "gravel" (id 1) everywhere a slope/height triggered the overlay instead
## of an actual rock texture, since id 1 stopped meaning "rock" once more
## textures were added to the asset list.
@export_group("Texture")
@export var grass_texture_id: int = 5
@export var rock_texture_id: int = 4
@export var rock_height_threshold: float = 15.0
@export_range(0.0, 1.0, 0.01) var rock_slope_threshold: float = 0.4

@export_group("Accent Textures")
## Extra textures patched in on top of the normal grass/rock blend via a
## separate noise field (see TerrainSeedGenerator's accent_noise_scale) --
## e.g. [gravel, leaves] scatters occasional gravel and leaf-litter
## patches across an otherwise grass_2 biome. Each triggered patch fully
## replaces the overlay for that patch (one accent texture at a time, not
## blended together), chosen by noise. Empty = no accents.
@export var accent_texture_ids: Array[int] = []
## Roughly what fraction of the biome's area ends up covered by SOME
## accent patch (any of accent_texture_ids combined), 0-1.
@export_range(0.0, 1.0, 0.01) var accent_coverage: float = 0.0
