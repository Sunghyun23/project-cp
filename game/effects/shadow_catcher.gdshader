shader_type spatial;
render_mode shadow_to_opacity, cull_disabled, diffuse_lambert, specular_disabled;
void fragment() {
    ALBEDO = vec3(0.025, 0.035, 0.06);
    ROUGHNESS = 1.0;
    ALPHA = 0.48;
}
