shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform vec4 tint : source_color = vec4(1.0, 0.55, 0.12, 0.7);
uniform float energy = 1.0;
uniform bool shaft = false;
void fragment() {
    vec2 p = UV * 2.0 - 1.0;
    float mask = shaft ? pow(max(0.0, 1.0 - abs(p.x)), 2.0) * (1.0-smoothstep(0.55,1.0,abs(p.y))) : pow(max(0.0, 1.0-dot(p,p)), 2.4);
    float opacity = tint.a * mask;
    ALBEDO = vec3(0.0);
    EMISSION = tint.rgb * energy * opacity;
    ALPHA = opacity;
}
