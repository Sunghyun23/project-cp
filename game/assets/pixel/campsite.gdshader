shader_type canvas_item;
uniform bool night = false;
uniform bool depth_enabled = true;
uniform vec2 parallax = vec2(0.0);
uniform vec2 source_offset = vec2(0.0);
uniform vec2 source_scale = vec2(1.0);
void fragment() {
    vec2 uv = source_offset + UV * source_scale;
    float t = floor(TIME * 10.0) / 10.0;
    if (depth_enabled) uv -= parallax * TEXTURE_PIXEL_SIZE * vec2(4.0, 2.0) * (0.35 + uv.y * 0.9);
    // Background coordinates stay fixed: animate water and exposed grass only.
    float lake = step(0.41, uv.y) * (1.0 - step(0.51, uv.y)) * (1.0 - step(0.54, uv.x));
    uv.x += sin(uv.y * 310.0 + t * 1.8) * TEXTURE_PIXEL_SIZE.x * 2.0 * lake;
    float grass = step(0.70, uv.y) * (1.0 - step(0.66, uv.x));
    uv.x += floor(sin(uv.x * 37.0 + t * 1.5) * 1.7) * TEXTURE_PIXEL_SIZE.x * grass;
    float fire = step(0.70, uv.x) * (1.0-step(0.77,uv.x)) * step(0.65,uv.y) * (1.0-step(0.76,uv.y));
    if (night) uv.x += sin(uv.y * 210.0 - t * 8.0) * TEXTURE_PIXEL_SIZE.x * 2.0 * fire;
    vec4 color = texture(TEXTURE, uv);
    float glint = step(0.985, sin(uv.x * 390.0 + floor(t * 2.0)) * sin(uv.y * 430.0));
    color.rgb += vec3(0.12, 0.15, 0.12) * lake * glint;
    if (night) color.rgb += vec3(0.055,0.025,0.0) * fire * (0.5+0.5*sin(t*11.0));
    if (depth_enabled) {
        // Layered depth cues, retaining the original pixel palette and hard edges.
        vec2 grid_uv = floor(uv * vec2(418.0, 235.0)) / vec2(418.0, 235.0);
        float distance_fog = (1.0 - smoothstep(0.30, 0.56, uv.y)) * 0.045;
        color.rgb = mix(color.rgb, night ? vec3(0.14,0.20,0.36) : vec3(0.68,0.82,0.76), distance_fog);
        if (!night) {
            float rays = pow(max(0.0, sin((grid_uv.x + grid_uv.y * 0.48) * 16.0 + 0.3)), 14.0);
            float ray_mask = smoothstep(0.10,0.35,uv.y) * (1.0-smoothstep(0.62,0.90,uv.y));
            color.rgb += vec3(1.0,0.89,0.61) * rays * ray_mask * (0.055 + 0.012*sin(t*0.5));
        } else {
            vec2 to_fire = (uv - vec2(0.738,0.755)) * vec2(1.0,0.58);
            float pool = exp(-dot(to_fire,to_fire) * 160.0);
            color.rgb += vec3(0.13,0.065,0.008) * pool * (0.84+0.16*sin(t*7.0));
        }
    }
    COLOR = color;
}
