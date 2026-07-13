shader_type spatial;

render_mode cull_disabled,blend_mix,specular_schlick_ggx, depth_prepass_alpha;

uniform vec4 Leaf_Color : source_color = vec4(0.45, 0.64, 0.0, 1.0);
uniform vec4 ExtraColor : source_color = vec4(0.13, 0.33, 0.25, 1.0);
varying vec3 obj_vertex;
uniform sampler2D Alpha;
uniform vec4 SSS_Color : source_color = vec4(0.65, 0.70, 0.0, 1.0);
uniform float WindSpeed : hint_range(1.0, 20.0) = 10.0;
uniform float WindStrength : hint_range(0.0, 1.0) = 0.1;
uniform float SSS_Strength : hint_range(-0.5, 10.0) = 2;
uniform float SSS_Blend : hint_range(-1.0, 1.0) = 0.2;
uniform bool GlobalVariation = true;



vec3 calculate_wind_effect(vec3 vertex, float time, float speed, float strength) {
    float offset = fract(vertex.x - vertex.z + time * 0.001);
    offset = min(1.0 - offset, offset) * 2.0 * (1.0 - offset);
    
    float t = time + sin(time + offset + cos(time + offset * speed * 2.0) * speed);
    float mask = clamp(vertex.y, 0.0, 1.0) * strength;
    
    return vec3(
        vertex.x * sin(t) / 20.0 * speed * offset * mask,
        vertex.y * sin(t) / 20.0 * speed * offset * mask,
        vertex.z * cos(t) / 20.0 * speed * offset * mask
    );
}

void vertex() {
    vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    
   
    
    float contribution = float(GlobalVariation);
    vec3 effective_world_pos = world_pos * contribution;
    float positional_influence = -VERTEX.x + VERTEX.z - effective_world_pos.x + effective_world_pos.z;
    
    vec3 wind_offset = calculate_wind_effect(VERTEX, TIME, WindSpeed, WindStrength);
    
    COLOR = vec4(VERTEX.y, positional_influence, 1.0, 1.0);
    VERTEX += wind_offset;
    
    obj_vertex = VERTEX;
}

void fragment() {

    float height_factor = clamp(COLOR.r, 0.0, 1.0);
    vec3 albedo = mix(ExtraColor.rgb, Leaf_Color.rgb, height_factor);
    
    float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
    float fresnel_intensity = max(height_factor, 0.1);
    
    vec3 sss_color = mix(albedo, SSS_Color.rgb, SSS_Strength);
    vec3 emission = sss_color * fresnel * fresnel_intensity * SSS_Blend;
    
    vec4 tex = texture(Alpha, clamp(UV, 0.0, 1.0));
	
    ALPHA_SCISSOR_THRESHOLD = 0.5;
    ALBEDO = albedo;
    ALPHA = tex.a;
    EMISSION = emission;

}