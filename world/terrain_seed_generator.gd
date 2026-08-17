@tool
class_name TerrainSeedGenerator
extends Node3D

## Bakes a seeded, procedurally-generated heightmap into a Terrain3D node
## via its scriptable import API (Terrain3DData.import_images() -- the
## same method Terrain3D's own tools/importer.gd uses to load height
## files, just fed a heightmap built in-memory from noise instead of read
## off disk). Press "Generate World" to (re)bake.
##
## The center of the world (world_seed's origin, matching this node's own
## global_position) stays a perfectly flat flat_core_size x flat_core_size
## square -- for the hand-placed farm/GridMap/market -- with height
## blending smoothly in from there out to full noise over transition_width
## meters beyond the square's edge. Distance is measured from the SQUARE's
## nearest edge (not a circular radius from the center point), so the
## entire flat area including its corners stays exactly flat; only ground
## past the boundary starts easing toward the noisy terrain.
##
## Beyond the flat core, biomes vary elevation, roughness, and texture
## across the map in one of two ways (see _sample_biome dispatcher):
##   - Quadrant mode (biome_pos_x_pos_z etc. all assigned): splits the map
##     into four regions by the world-space sign of (x, z) relative to
##     this node, bilinear-blended near the two axes.
##   - Gradient mode (biomes array non-empty): blends smoothly along a
##     single low-frequency noise field through an ORDERED list -- only
##     adjacent entries blend into each other.
## Quadrant mode takes priority if both are set. Leave both unset to use
## the single Noise/Texture Painting settings below for the whole map.

@export var world_seed: int = 0
## Heightmap resolution in pixels -- with import_scale left at 1.0 (see
## generate()), 1 pixel = 1 meter, so this is also the world's total
## width/depth in meters, centered on this node.
@export var world_size: int = 2048

@export_group("Flat Core")
@export var flat_core_size: float = 150.0
@export var transition_width: float = 60.0
@export var flat_height: float = 0.0

@export_group("Noise")
## Shared detail-noise frequency/octaves for the whole map -- biomes vary
## amplitude and baseline height on top of this, not the noise's own
## character, so this stays one shared sample per pixel regardless of how
## many biomes are defined.
@export var noise_frequency: float = 0.01
## Used directly when no biomes are set; otherwise scaled per-pixel by
## whichever biome(s) blend in at that point (see TerrainBiome.
## amplitude_multiplier).
@export var noise_amplitude: float = 30.0
## Extra octaves of detail on top of the base noise -- 0 disables.
@export_range(0, 6) var noise_octaves: int = 3

@export_group("Texture Painting")
## Fallback texture/threshold settings used when no biomes are set --
## indices into Terrain3D's own texture asset list (the order they appear
## in Terrain3DAssets), NOT scene/mesh references, so double check them
## against your actual asset list.
@export var grass_texture_id: int = 5
@export var rock_texture_id: int = 4
@export var rock_height_threshold: float = 15.0
@export_range(0.0, 1.0, 0.01) var rock_slope_threshold: float = 0.4
## Height/slope range the grass<->rock blend eases across -- higher =
## softer transition, lower = sharper line.
@export var blend_smoothness: float = 5.0
## Shared frequency/seed for every biome's accent_texture_ids patches
## (see TerrainBiome) -- one shared noise field rather than per-biome, to
## avoid allocating a FastNoiseLite per pixel.
@export var accent_noise_scale: float = 0.12
@export var accent_seed: int = 777

@export_group("Biomes (Gradient)")
## Ordered list of regions blended smoothly across a low-frequency noise
## gradient -- order matters, since only ADJACENT entries blend into each
## other (e.g. [Plains, Hills, Mountains] eases low-flat -> rolling ->
## tall; putting Mountains next to Plains directly would blend those two
## instead). Ignored if the four Quadrant Biomes below are all assigned.
@export var biomes: Array[TerrainBiome] = []
## Much lower than noise_frequency -- this controls how large each biome
## region is, not terrain detail.
@export var biome_noise_frequency: float = 0.003
@export var biome_seed: int = 0

@export_group("Biomes (Quadrant)")
## Assign all four to split the map into quadrants by world-space sign of
## (x, z) relative to this node's own position, instead of the noise
## gradient above. Takes priority over Biomes (Gradient) when set.
@export var biome_pos_x_pos_z: TerrainBiome  ## +X, +Z
@export var biome_pos_x_neg_z: TerrainBiome  ## +X, -Z
@export var biome_neg_x_pos_z: TerrainBiome  ## -X, +Z
@export var biome_neg_x_neg_z: TerrainBiome  ## -X, -Z
## How far out from each axis the blend between neighboring quadrants
## spans -- wider means a softer seam along the X=0/Z=0 lines.
@export var quadrant_blend_width: float = 80.0

@export_group("Biome Blending")
## Perturbs the coordinates used for biome selection (quadrant or
## gradient) before blending, so the boundary between biomes bends into
## organic splotches instead of following a perfectly straight/geometric
## line -- 0 disables (back to a clean boundary).
@export var biome_warp_amplitude: float = 60.0
## Lower = broad, sweeping waves in the boundary; higher = tighter, more
## frequent wiggles/splotches.
@export var biome_warp_scale: float = 0.008
@export var biome_warp_seed: int = 999

@warning_ignore("unused_private_class_variable")
@export_tool_button("Generate World", "Reload") var _generate_btn = generate

func generate() -> void:
	var terrain = _find_terrain()
	if terrain == null:
		push_warning("TerrainSeedGenerator: no Terrain3D node found in this scene.")
		return

	var noise = FastNoiseLite.new()
	noise.seed = world_seed
	noise.frequency = noise_frequency
	noise.fractal_octaves = noise_octaves

	var use_quadrants = _quadrants_ready()
	var biome_noise: FastNoiseLite = null
	if not use_quadrants and biomes.size() > 0:
		biome_noise = FastNoiseLite.new()
		biome_noise.seed = biome_seed
		biome_noise.frequency = biome_noise_frequency

	var warp_noise: FastNoiseLite = null
	if (use_quadrants or biome_noise) and biome_warp_amplitude > 0.0:
		warp_noise = FastNoiseLite.new()
		warp_noise.seed = biome_warp_seed
		warp_noise.frequency = biome_warp_scale
		warp_noise.fractal_octaves = 2

	var img = Image.create(world_size, world_size, false, Image.FORMAT_RF)
	var half_core = flat_core_size / 2.0
	var half_world = world_size / 2.0

	for pz in world_size:
		var wz = pz - half_world
		for px in world_size:
			var wx = px - half_world

			# Distance from the flat square's nearest edge (0 = inside it).
			var dx = maxf(absf(wx) - half_core, 0.0)
			var dz = maxf(absf(wz) - half_core, 0.0)
			var dist_outside = sqrt(dx * dx + dz * dz)
			var t = smoothstep(0.0, transition_width, dist_outside)

			var amplitude = noise_amplitude
			var region_base = 0.0
			if use_quadrants:
				var b = _sample_quadrant(wx, wz, warp_noise)
				amplitude = noise_amplitude * b.amplitude_multiplier
				region_base = b.base_height
			elif biome_noise:
				var b = _sample_gradient(wx, wz, biome_noise, warp_noise)
				amplitude = noise_amplitude * b.amplitude_multiplier
				region_base = b.base_height

			var noise_h = noise.get_noise_2d(wx, wz) * amplitude
			var h = lerp(flat_height, flat_height + region_base + noise_h, t)
			img.set_pixel(px, pz, Color(h, h, h, h))

	var accent_noise = FastNoiseLite.new()
	accent_noise.seed = accent_seed
	accent_noise.frequency = accent_noise_scale

	var control_img = _paint_control_map(img, use_quadrants, biome_noise, accent_noise, warp_noise)

	var imported_images: Array[Image]
	imported_images.resize(Terrain3DRegion.TYPE_MAX)
	imported_images[Terrain3DRegion.TYPE_HEIGHT] = img
	imported_images[Terrain3DRegion.TYPE_CONTROL] = control_img

	var import_pos: Vector3 = global_position + Vector3(-half_world, 0.0, -half_world)
	terrain.data.import_images(imported_images, import_pos, 0.0, 1.0)

	# import_images() only updates the live in-memory Terrain3DData, which
	# is why the editor viewport looks right immediately -- without an
	# explicit save, a fresh game session loads whatever's still on disk
	# in data_directory (stale or empty), not what the editor is currently
	# holding, which is why it showed correct in-editor but blank/white
	# when actually played.
	if terrain.data_directory != "":
		terrain.data.save_directory(terrain.data_directory)
	else:
		push_warning("TerrainSeedGenerator: Terrain3D node has no data_directory set -- generated terrain won't persist to disk, so it'll look wrong outside the editor.")

	print("TerrainSeedGenerator: generated %dx%d heightmap (seed=%d), flat core=%sm, transition=%sm, mode=%s" % [world_size, world_size, world_seed, flat_core_size, transition_width, ("quadrant" if use_quadrants else ("gradient(%d)" % biomes.size()) if biome_noise else "single")])

func _quadrants_ready() -> bool:
	return biome_pos_x_pos_z != null and biome_pos_x_neg_z != null and biome_neg_x_pos_z != null and biome_neg_x_neg_z != null

## Bilinear blend of the four quadrant biomes based on (wx, wz)'s position
## relative to the two axes -- fx/fz are 0 on the negative side, 1 on the
## positive side, easing smoothly across quadrant_blend_width around 0
## instead of jumping at the exact axis. warp_noise (optional) perturbs
## (wx, wz) first so the X=0/Z=0 boundary itself bends into organic
## splotches instead of a straight line.
func _sample_quadrant(wx: float, wz: float, warp_noise: FastNoiseLite = null) -> Dictionary:
	if warp_noise:
		wx += warp_noise.get_noise_2d(wx, wz) * biome_warp_amplitude
		wz += warp_noise.get_noise_2d(wx + 5000.0, wz + 5000.0) * biome_warp_amplitude

	var fx = smoothstep(-quadrant_blend_width, quadrant_blend_width, wx)
	var fz = smoothstep(-quadrant_blend_width, quadrant_blend_width, wz)
	var w_pp = fx * fz             # +X +Z
	var w_pn = fx * (1.0 - fz)     # +X -Z
	var w_np = (1.0 - fx) * fz     # -X +Z
	var w_nn = (1.0 - fx) * (1.0 - fz)  # -X -Z

	var dominant: TerrainBiome = biome_neg_x_neg_z
	var best_w = w_nn
	if w_pp > best_w:
		dominant = biome_pos_x_pos_z
		best_w = w_pp
	if w_pn > best_w:
		dominant = biome_pos_x_neg_z
		best_w = w_pn
	if w_np > best_w:
		dominant = biome_neg_x_pos_z
		best_w = w_np

	return {
		"base_height": biome_pos_x_pos_z.base_height * w_pp + biome_pos_x_neg_z.base_height * w_pn + biome_neg_x_pos_z.base_height * w_np + biome_neg_x_neg_z.base_height * w_nn,
		"amplitude_multiplier": biome_pos_x_pos_z.amplitude_multiplier * w_pp + biome_pos_x_neg_z.amplitude_multiplier * w_pn + biome_neg_x_pos_z.amplitude_multiplier * w_np + biome_neg_x_neg_z.amplitude_multiplier * w_nn,
		"grass_texture_id": dominant.grass_texture_id,
		"rock_texture_id": dominant.rock_texture_id,
		"rock_height_threshold": biome_pos_x_pos_z.rock_height_threshold * w_pp + biome_pos_x_neg_z.rock_height_threshold * w_pn + biome_neg_x_pos_z.rock_height_threshold * w_np + biome_neg_x_neg_z.rock_height_threshold * w_nn,
		"rock_slope_threshold": biome_pos_x_pos_z.rock_slope_threshold * w_pp + biome_pos_x_neg_z.rock_slope_threshold * w_pn + biome_neg_x_pos_z.rock_slope_threshold * w_np + biome_neg_x_neg_z.rock_slope_threshold * w_nn,
		"accent_texture_ids": dominant.accent_texture_ids,
		"accent_coverage": dominant.accent_coverage,
	}

## Blends the two biomes adjacent to biome_noise's value at (wx, wz) into
## one Dictionary of interpolated parameters. A single biome returns
## itself unblended.
func _sample_gradient(wx: float, wz: float, biome_noise: FastNoiseLite, warp_noise: FastNoiseLite = null) -> Dictionary:
	var count = biomes.size()
	if count == 1:
		return _blend_two(biomes[0], biomes[0], 0.0)

	if warp_noise:
		wx += warp_noise.get_noise_2d(wx, wz) * biome_warp_amplitude
		wz += warp_noise.get_noise_2d(wx + 5000.0, wz + 5000.0) * biome_warp_amplitude

	var bt = (biome_noise.get_noise_2d(wx, wz) + 1.0) / 2.0  # [-1,1] -> [0,1]
	var scaled = clampf(bt, 0.0, 1.0) * (count - 1)
	var idx = clampi(int(floor(scaled)), 0, count - 2)
	var frac = smoothstep(0.0, 1.0, clampf(scaled - idx, 0.0, 1.0))
	return _blend_two(biomes[idx], biomes[idx + 1], frac)

## Interpolates two biomes -- continuous fields (height/amplitude/
## thresholds) blend smoothly; texture ids are integers so they can't
## fractionally blend, they just switch over at the midpoint (a visible
## texture line at biome boundaries reads as normal biome transition,
## unlike an elevation seam which would look like a bug).
func _blend_two(a: TerrainBiome, b: TerrainBiome, frac: float) -> Dictionary:
	var tex_a = a if frac < 0.5 else b
	return {
		"base_height": lerp(a.base_height, b.base_height, frac),
		"amplitude_multiplier": lerp(a.amplitude_multiplier, b.amplitude_multiplier, frac),
		"grass_texture_id": tex_a.grass_texture_id,
		"rock_texture_id": tex_a.rock_texture_id,
		"rock_height_threshold": lerp(a.rock_height_threshold, b.rock_height_threshold, frac),
		"rock_slope_threshold": lerp(a.rock_slope_threshold, b.rock_slope_threshold, frac),
		"accent_texture_ids": tex_a.accent_texture_ids,
		"accent_coverage": tex_a.accent_coverage,
	}

## Second pass over the already-generated height image: paints grass vs.
## rock based on the FINAL height data (post flat-core blending, so the
## flat core naturally reads as ~zero slope) and a numerical slope
## estimate from neighboring height texels. Uses biome-blended texture
## ids/thresholds when biomes are set (quadrant or gradient), otherwise
## this generator's own grass_texture_id/rock_texture_id/threshold
## settings.
func _paint_control_map(height_img: Image, use_quadrants: bool, biome_noise: FastNoiseLite, accent_noise: FastNoiseLite, warp_noise: FastNoiseLite) -> Image:
	var control_img = Image.create(world_size, world_size, false, Image.FORMAT_RF)
	var last = world_size - 1
	var half_world = world_size / 2.0
	for pz in world_size:
		var wz = pz - half_world
		for px in world_size:
			var wx = px - half_world
			var h = height_img.get_pixel(px, pz).r
			var h_x = height_img.get_pixel(mini(px + 1, last), pz).r
			var h_z = height_img.get_pixel(px, mini(pz + 1, last)).r
			var slope = Vector2(h_x - h, h_z - h).length()

			var grass_id = grass_texture_id
			var rock_id = rock_texture_id
			var height_threshold = rock_height_threshold
			var slope_threshold = rock_slope_threshold
			var accent_ids: Array = []
			var accent_coverage := 0.0
			if use_quadrants:
				var b = _sample_quadrant(wx, wz, warp_noise)
				grass_id = b.grass_texture_id
				rock_id = b.rock_texture_id
				height_threshold = b.rock_height_threshold
				slope_threshold = b.rock_slope_threshold
				accent_ids = b.accent_texture_ids
				accent_coverage = b.accent_coverage
			elif biome_noise:
				var b = _sample_gradient(wx, wz, biome_noise, warp_noise)
				grass_id = b.grass_texture_id
				rock_id = b.rock_texture_id
				height_threshold = b.rock_height_threshold
				slope_threshold = b.rock_slope_threshold
				accent_ids = b.accent_texture_ids
				accent_coverage = b.accent_coverage

			var smoothness = maxf(blend_smoothness, 0.001)
			var height_factor = clampf((h - height_threshold) / smoothness, 0.0, 1.0)
			var slope_factor = clampf((slope - slope_threshold) / 0.2, 0.0, 1.0)
			var rockiness = maxf(height_factor, slope_factor)
			var over_id = rock_id

			# Accent patches (e.g. gravel/leaves scattered over grass_2) --
			# a second noise sample decides IF a patch exists here at all
			# (coverage), a third, decorrelated sample (offset by a large
			# constant on the same generator, cheaper than a second
			## FastNoiseLite) decides WHICH accent texture. A triggered
			# patch fully overrides the normal height/slope rock blend for
			# that texel, with a soft-centered fade at its edge.
			if accent_ids.size() > 0 and accent_coverage > 0.0:
				var cov01 = (accent_noise.get_noise_2d(wx, wz) + 1.0) / 2.0
				if cov01 < accent_coverage:
					var sel01 = (accent_noise.get_noise_2d(wx + 10000.0, wz + 10000.0) + 1.0) / 2.0
					var idx = clampi(int(sel01 * accent_ids.size()), 0, accent_ids.size() - 1)
					over_id = accent_ids[idx]
					rockiness = clampf(1.0 - cov01 / accent_coverage, 0.0, 1.0)

			var control_value = _encode_control(grass_id, over_id, rockiness)
			control_img.set_pixel(px, pz, Color(control_value, control_value, control_value, control_value))
	return control_img

## Packs Terrain3D's control map bit layout into a float whose raw bits
## (not numeric value) the shader reads back via floatBitsToUint --
## confirmed directly from the shipped shader's decode macros and the
## compiled extension's control-map sampling code:
##   base id    = bits 27-31 (5 bits)
##   overlay id = bits 22-26 (5 bits)
##   blend      = bits 14-21 (8 bits, 0-255)
## auto-shader (bit 0) and hole (bit 2) are left off so these painted
## values always take effect instead of Terrain3D's own auto-texturing.
func _encode_control(base_id: int, over_id: int, blend: float) -> float:
	var blend_u8 := int(clampf(blend, 0.0, 1.0) * 255.0)
	var value := 0
	value |= (base_id & 0x1F) << 27
	value |= (over_id & 0x1F) << 22
	value |= (blend_u8 & 0xFF) << 14
	var bytes := PackedByteArray()
	bytes.resize(4)
	bytes.encode_u32(0, value)
	return bytes.decode_float(0)

## Same lookup as world/nodes/node_painter.gd's _find_terrain().
func _find_terrain() -> Node:
	var root = get_tree().edited_scene_root if Engine.is_editor_hint() else get_tree().root
	if root == null:
		return null
	var found: Array = root.find_children("", "Terrain3D", true, false)
	return found[0] if found.size() > 0 else null
