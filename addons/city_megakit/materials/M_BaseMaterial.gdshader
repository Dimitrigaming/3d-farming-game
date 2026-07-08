shader_type spatial;
uniform sampler2D albedo : source_color;
uniform sampler2D base_normal : hint_normal;
uniform sampler2D detail_normal : hint_normal;
uniform sampler2D orm : hint_roughness_g;
uniform sampler2D wear_texture : hint_default_white;
uniform vec4 color_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 wear_color : source_color = vec4(0.292, 0.292, 0.292, 1.0);
uniform bool use_wear_color = true;
uniform bool use_detail_normal = true;
uniform float detail_normal_intensity : hint_range(0.0, 1.0) = 1.0;
uniform vec2 uv_scale = vec2(1.0, 1.0);
void fragment() {
    vec2 scaled_uv = UV * uv_scale;
    vec3 base = texture(albedo, scaled_uv).rgb * color_tint.rgb;
    float wear_mask = texture(wear_texture, scaled_uv).r;
    float vertex_wear = (1.0 - COLOR.g) * (1.0 - COLOR.b);
    float wear_amount = wear_mask * vertex_wear;
    vec3 worn = base * wear_color.rgb;
    ALBEDO = use_wear_color ? mix(base, worn, wear_amount) : base;
    vec3 orm_tex = texture(orm, scaled_uv).rgb;
    AO = orm_tex.r;
    ROUGHNESS = orm_tex.g;
    METALLIC = orm_tex.b;
    vec3 t = texture(base_normal, scaled_uv).rgb * 2.0 - 1.0;
    if (use_detail_normal) {
        vec3 u = texture(detail_normal, UV2).rgb * 2.0 - 1.0;
        u = mix(vec3(0.0, 0.0, 1.0), u, detail_normal_intensity);
        u = u * vec3(-1.0, -1.0, 1.0);
        t = t + vec3(0.0, 0.0, 1.0);
        vec3 blended = t * dot(t, u) - u * t.z;
        NORMAL_MAP = normalize(blended) * 0.5 + 0.5;
    } else {
        NORMAL_MAP = texture(base_normal, UV).rgb;
    }
}