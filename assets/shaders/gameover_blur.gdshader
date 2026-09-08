shader_type canvas_item;
// 게임오버 패널 뒤 화면을 흐리게(+살짝 어둡게) 처리해 패널 시인성을 높인다.
// 화면 텍스처를 13탭으로 두 번 가중 샘플링한 부드러운 블러.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float blur_radius = 3.5;   // 픽셀 단위 샘플 간격 배수
uniform float darken = 0.55;       // 1.0=원본 밝기, 낮을수록 어둡게

// 결과별 비네트(패배=핏빛 · 승리=금빛). 화면 가장자리로 갈수록 이 색으로 물든다.
// 색만으로 승패를 읽히게 하는 장치라, 기본값은 0(=안 씀)으로 두고 HUD 가 켠다 —
// 이 셰이더는 부활 후에도 같은 재질을 재사용하므로 꺼진 상태가 기본이어야 한다.
uniform vec3 tint : source_color = vec3(0.0);
uniform float tint_amount = 0.0;   // 0=없음, 1=가장자리가 완전히 tint 색
uniform float tint_inner = 0.30;   // 이 반경 안쪽은 물들지 않는다(패널이 놓이는 자리)
uniform float tint_outer = 0.90;   // 이 반경 바깥이 가장 짙다

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
	vec3 rgb = c.rgb * darken;
	// UV 를 그대로 쓰면 비네트가 화면과 같은 비율의 타원이 된다 — 세로 화면에서
	// 종횡비를 보정해 정원으로 만들면 좌우 가장자리에는 아무것도 닿지 않는다.
	float d = length(SCREEN_UV - vec2(0.5)) * 2.0;
	float v = smoothstep(tint_inner, tint_outer, d);
	rgb = mix(rgb, tint, v * tint_amount);
	COLOR = vec4(rgb, 1.0);
}
