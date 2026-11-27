shader_type canvas_item;
// 정적인 배경 크롭 전용. 물결/풀/불빛/시차/화면 입자 효과는 사용하지 않는다.
uniform vec2 source_offset = vec2(0.0);
uniform vec2 source_scale = vec2(1.0);
void fragment() {
    COLOR = texture(TEXTURE, source_offset + UV * source_scale);
}
