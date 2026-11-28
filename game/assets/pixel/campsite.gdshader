shader_type canvas_item;
// 정적인 배경 크롭 전용. 물결/풀/불빛/시차/화면 입자 효과는 사용하지 않는다.
uniform vec2 source_offset = vec2(0.0);
uniform vec2 source_scale = vec2(1.0);
// 크롭된 텍스처와 CanvasItem의 낮/밤 색을 별도로 결합한다.
// fragment의 COLOR를 그대로 곱하면 기본 UV 텍스처가 중복 곱해진다.
varying vec4 scenery_tint;
void vertex() {
    scenery_tint = COLOR;
}
void fragment() {
    COLOR = texture(TEXTURE, source_offset + UV * source_scale) * scenery_tint;
}
