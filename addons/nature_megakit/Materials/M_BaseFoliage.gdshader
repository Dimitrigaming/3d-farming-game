shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_schlick_ggx, depth_prepass_alpha;

uniform sampler2D texture_albedo : source_color;
uniform float WindSpeed : hint_range(0.1, 10.0) = 2.0;
uniform float WindIntensity : hint_range(0.0, 2.0) = 0.2;
uniform sampler2D GeneratedNoise : hint_default_white;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.5;

varying vec2 world_uv;
varying vec3 world_pos;
varying float vertex_r;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_uv = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz * 0.1; // Scale down for better noise sampling
    
    float wind_time = TIME * WindSpeed;
    float wind_strength = WindIntensity * COLOR.r;
    vec3 generated_noise = texture(GeneratedNoise, world_uv).rgb;
    
    vec3 wind_offset = vec3(
        sin(wind_time + world_pos.z) * generated_noise.r,
        sin(wind_time * 0.5 + world_pos.x) * generated_noise.g,
        cos(wind_time + world_pos.x) * generated_noise.b
    ) * wind_strength;
    
    VERTEX += wind_offset;
    vertex_r = COLOR.r;
}

void fragment() {
    vec4 albedo_tex = texture(texture_albedo, UV);
    vec3 final_color = albedo_tex.rgb* vertex_r;
    
    ALBEDO = final_color;
    ALPHA = albedo_tex.a;
    ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
    
    if (!FRONT_FACING) {
        NORMAL = -NORMAL;
    }
}