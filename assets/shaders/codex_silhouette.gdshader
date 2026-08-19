shader_type canvas_item;
// 도감 미발견 칸 — 아이콘을 **단색 실루엣**으로 눌러 형태만 남긴다.
//
// modulate 로는 이걸 못 한다. modulate 는 곱셈이라 원본 색이 비율로 살아남는다 —
// 어둡게 곱하면 배경에 묻힌 얼룩이 되고, 밝게 곱하면 색이 그대로 읽혀 실루엣이 아니게 된다
// (둘 다 실렌더로 확인했다). 알파만 남기고 RGB 를 통째로 갈아끼우는 것이 유일한 방법이다.

uniform vec4 tint : source_color = vec4(0.32, 0.35, 0.44, 1.0);

void fragment() {
	COLOR = vec4(tint.rgb, texture(TEXTURE, UV).a * tint.a);
}
