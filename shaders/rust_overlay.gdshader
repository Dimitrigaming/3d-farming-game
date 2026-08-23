shader_type spatial;

// Procedural rust overlay -- for a "rusty tier" tool look without needing an
// externally-painted texture (Godot has no in-editor mesh paint tool, see
// wood_grain.gdshader for the same trick applied to wood). Blotches come
// from layered value noise, not a uniform tint, so it reads as worn/patchy
// rust instead of a flat color change. Keeps the mesh's own vertex-color
// shading as the base (same source these tool materials already use via
// vertex_color_use_as_albedo) and blends rust color/roughness on top
// wherever the noise crosses rust_amount.

uniform vec4 rust_color : source_color = vec4(0.42, 0.20, 0.07, 1.0);
// Roughly how much of the surface ends up rusty, 0 = none, 1 = fully rusted.
uniform float rust_amount : hint_range(0.0, 1.0) = 0.35;
// Blotch size -- lower is bigger patches, higher is finer speckling.
uniform float noise_scale : hint_range(0.5, 40.0) = 8.0;
// Edge feather between clean metal and rust -- 0 is a hard stencil edge.
uniform float blotch_softness : hint_range(0.01, 0.5) = 0.12;
uniform float rust_roughness : hint_range(0.0, 1.0) = 0.95;
uniform float base_roughness : hint_range(0.0, 1.0) = 0.35;
uniform float base_metallic : hint_range(0.0, 1.0) = 0.7;

float hash2(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 uv) {
	vec2 i = floor(uv);
	vec2 f = fract(uv);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash2(i);
	float b = hash2(i + vec2(1.0, 0.0));
	float c = hash2(i + vec2(0.0, 1.0));
	float d = hash2(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	// Two octaves so blotches have both broad patches and finer speckling
	// instead of uniform-sized dots.
	float n = value_noise(UV * noise_scale) * 0.65 + value_noise(UV * noise_scale * 3.1) * 0.35;
	float rust_mask = smoothstep(1.0 - rust_amount - blotch_softness, 1.0 - rust_amount + blotch_softness, n);

	ALBEDO = mix(COLOR.rgb, rust_color.rgb, rust_mask);
	ROUGHNESS = mix(base_roughness, rust_roughness, rust_mask);
	METALLIC = mix(base_metallic, 0.0, rust_mask);
}
