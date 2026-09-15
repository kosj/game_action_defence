shader_type canvas_item;
render_mode unshaded;

uniform vec4 tint : source_color = vec4(1.0, 0.42, 0.08, 1.0);
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float phase = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float slow = phase * 0.42;
	float broad = noise(p * 2.7 + vec2(slow, -slow * 0.73));
	float detail = noise(p * 6.2 + vec2(-slow * 1.31, slow));
	float edge_radius = 0.82 + (broad - 0.5) * 0.20 + (detail - 0.5) * 0.07;
	float d = length(p);
	float mask = 1.0 - smoothstep(edge_radius - 0.08, edge_radius + 0.08, d);

	// 어두운 그을음 위로 주황 열점이 살아 움직인다. 밝은 원판처럼 보이지 않도록
	// 중심 전체를 채우지 않고 노이즈가 높은 곳만 뜨겁게 만든다.
	float hot = smoothstep(0.48, 0.86, broad * 0.66 + detail * 0.52);
	vec3 coal = vec3(0.105, 0.025, 0.012);
	vec3 ember = mix(vec3(0.62, 0.075, 0.008), tint.rgb, 0.45);
	vec3 color = mix(coal, ember, hot);
	float rim = smoothstep(edge_radius - 0.16, edge_radius, d) * mask;
	color += tint.rgb * rim * (0.12 + hot * 0.18);
	float alpha = mask * (0.34 + hot * 0.30 + rim * 0.12) * fade;
	COLOR = vec4(color, alpha);
}
