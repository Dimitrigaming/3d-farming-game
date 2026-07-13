shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

uniform sampler2D texture_albedo : source_color;
uniform sampler2D normal_map;
uniform vec3 Color_Bottom : source_color = vec3(0.545, 0.659, 0.0);  
varying float vertex_r;

void vertex() {
    

  
}

void fragment() {
	
    vec4 albedo_tex = texture(texture_albedo, UV);
	vec3 normal = texture(normal_map,UV).rgb;
	
    vec3 final_color = mix(albedo_tex.rgb * Color_Bottom,albedo_tex.rgb,COLOR.r) ;
  
    ALBEDO = final_color;
	NORMAL_MAP = normal;
}