shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform vec4 Color_Top : source_color = vec4(0.545, 0.659, 0.0, 1.0);  // #8BA800
uniform vec4 Color_Bottom : source_color = vec4(0.09, 0.239, 0.0, 1.0);  // #173D00
uniform vec4 wind_line_color : source_color = vec4(0.549, 0.588, 0.0, 1.0);  // #8C9600
uniform float WindSpeed : hint_range(1.0, 10.0) = 2.0;
uniform float WindIntensity : hint_range(0.0, 2.0) = 0.2;
uniform sampler2D NoiseTexture : hint_default_white;
uniform vec2 NoisePanSpeed = vec2(0.03, 0.0);
uniform float NoiseScale : hint_range(1, 100.0) = 50.0;
uniform float WindLineStrength : hint_range(0.0, 2.0) = 1;
uniform float WindLineSaturation : hint_range(1.0, 10.0) = 5.0;
uniform vec3 World_Color_Variation : source_color = vec3(0.0, 0.514, 0.306);  // #00834E
uniform sampler2D GeneratedNoise;

varying vec2 world_uv;
varying vec3 world_pos;
varying float vertex_r;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_uv = (world_pos.xz / NoiseScale) + (TIME * NoisePanSpeed);
    
    float noise = texture(NoiseTexture, world_uv).r;
    noise = clamp(pow(noise, WindLineSaturation), 0.0, 1.0);
    
    float wind_time = TIME * WindSpeed;
    float wind_strength = WindIntensity * COLOR.r;
    vec3 generated_noise = texture(GeneratedNoise, world_uv).rgb;
    
    vec3 wind_offset = vec3(
        sin(wind_time + world_pos.z) * generated_noise.r,
        sin(wind_time * 0.5 + world_pos.x) * generated_noise.g + sin(wind_time + world_pos.x + world_pos.z) * WindLineStrength * noise,
        cos(wind_time + world_pos.x) * generated_noise.b
    ) * wind_strength;
    
    VERTEX += wind_offset;
    vertex_r = COLOR.r;
}

void fragment() {
    float noise = texture(NoiseTexture, world_uv).r;
    noise = clamp(pow(noise, WindLineSaturation), 0.0, 1.0);
    
    vec3 base_color = mix(Color_Bottom.rgb, Color_Top.rgb, vertex_r);
    float world_noise = texture(GeneratedNoise, world_pos.xz / NoiseScale).r;
    vec3 final_color = mix(base_color, wind_line_color.rgb, noise * WindLineStrength) * mix(vec3(1.0), World_Color_Variation, world_noise);
    
    NORMAL *= float(FRONT_FACING) * 2.0 - 1.0;
    ALBEDO = final_color;
}