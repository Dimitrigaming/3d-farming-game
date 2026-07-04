shader_type spatial;

uniform vec4 color_light : source_color = vec4(0.97, 0.89, 0.77, 1.0);
uniform vec4 color_dark  : source_color = vec4(0.70, 0.44, 0.26, 1.0);
uniform float grain_scale    : hint_range(5.0, 60.0) = 28.0;
uniform float grain_angle    : hint_range(-1.57, 1.57) = 0.28;
uniform vec2  knot_pos       = vec2(0.52, 0.58);
uniform float knot_radius    : hint_range(0.01, 0.5)  = 0.16;
uniform float knot_strength  : hint_range(0.0, 6.0)   = 3.2;
uniform float line_sharpness : hint_range(1.0, 8.0)   = 3.5;
uniform float roughness      : hint_range(0.0, 1.0)   = 0.85;

float wood_rings(vec2 uv) {
	// Rotate for grain angle
	float ca = cos(grain_angle);
	float sa = sin(grain_angle);
	vec2 ruv = vec2(uv.x * ca - uv.y * sa, uv.x * sa + uv.y * ca);

	// --- Knot distortion ---
	vec2 delta  = uv - knot_pos;
	float dist  = length(delta);
	float falloff = exp(-dist / max(knot_radius, 0.001));

	// Tangential swirl around the knot centre
	vec2 tangent = vec2(-delta.y, delta.x) / max(dist, 0.001);
	ruv += tangent * knot_strength * falloff * 0.12;

	// Oval rings radiating out from the knot
	ruv.x += (dist / max(knot_radius, 0.001)) * falloff * 0.18;

	// --- Ring value ---
	return ruv.x * grain_scale;
}

void fragment() {
	float g = wood_rings(UV);

	// Main rings
	float ring  = sin(g * 6.28318) * 0.5 + 0.5;
	// Finer grain lines layered on top
	float fine  = sin(g * 25.13274) * 0.5 + 0.5;
	// Medium frequency for variety
	float mid   = sin(g * 12.56637) * 0.5 + 0.5;

	// Combine — fine lines dominate, rings add depth
	float pattern = ring * 0.35 + mid * 0.35 + fine * 0.30;

	// Sharpen so lines are thin, not wide bands
	pattern = pow(pattern, line_sharpness);

	ALBEDO   = mix(color_light.rgb, color_dark.rgb, pattern);
	ROUGHNESS = roughness;
	METALLIC  = 0.0;
}
