shader_type canvas_item;
// 게임오버 패널 뒤 화면을 흐리게(+살짝 어둡게) 처리해 패널 시인성을 높인다.
// 화면 텍스처를 13탭으로 두 번 가중 샘플링한 부드러운 블러.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float blur_radius = 3.5;   // 픽셀 단위 샘플 간격 배수
uniform float darken = 0.55;       // 1.0=원본 밝기, 낮을수록 어둡게

void fragment() {
	vec2 ps = SCREEN_PIXEL_SIZE * blur_radius;
	vec4 c = vec4(0.0);
	// 중심 + 8방향(가까운 고리) + 4방향(먼 고리) 가중합
	c += texture(screen_tex, SCREEN_UV) * 0.20;
	c += texture(screen_tex, SCREEN_UV + vec2( ps.x, 0.0)) * 0.10;
	c += texture(screen_tex, SCREEN_UV + vec2(-ps.x, 0.0)) * 0.10;
	c += texture(screen_tex, SCREEN_UV + vec2( 0.0,  ps.y)) * 0.10;
	c += texture(screen_tex, SCREEN_UV + vec2( 0.0, -ps.y)) * 0.10;
	c += texture(screen_tex, SCREEN_UV + vec2( ps.x,  ps.y)) * 0.06;
	c += texture(screen_tex, SCREEN_UV + vec2(-ps.x,  ps.y)) * 0.06;
	c += texture(screen_tex, SCREEN_UV + vec2( ps.x, -ps.y)) * 0.06;
	c += texture(screen_tex, SCREEN_UV + vec2(-ps.x, -ps.y)) * 0.06;
	c += texture(screen_tex, SCREEN_UV + vec2( 2.0 * ps.x, 0.0)) * 0.04;
	c += texture(screen_tex, SCREEN_UV + vec2(-2.0 * ps.x, 0.0)) * 0.04;
	c += texture(screen_tex, SCREEN_UV + vec2( 0.0,  2.0 * ps.y)) * 0.04;
	c += texture(screen_tex, SCREEN_UV + vec2( 0.0, -2.0 * ps.y)) * 0.04;
	COLOR = vec4(c.rgb * darken, 1.0);
}
