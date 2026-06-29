shader_type spatial;
render_mode cull_back;

uniform float clip_height : hint_range(-10.0, 10.0) = -100.0;
uniform vec4 albedo : source_color = vec4(1.0, 1.0, 1.0, 1.0);

varying float world_y;

void vertex() {
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	if (world_y > clip_height) {
		discard;
	}
	ALBEDO = albedo.rgb;
}
