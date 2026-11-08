shader_type canvas_item;
render_mode unshaded;

uniform float wind_time = 2.0;
uniform float breeze_strength : hint_range(0.0, 2.0) = 0.85;
uniform float breath_time = 0.0;
uniform float breath_strength : hint_range(0.0, 8.0) = 4.5;

// Контур тела на рисунке. Мебель и стены не участвуют в дыхании.
const vec2 BODY[28] = vec2[](
	vec2(0.0, 668.0), vec2(102.0, 630.0), vec2(164.0, 521.0),
	vec2(212.0, 490.0), vec2(239.0, 495.0), vec2(251.0, 532.0),
	vec2(278.0, 493.0), vec2(307.0, 491.0), vec2(336.0, 522.0),
	vec2(349.0, 572.0), vec2(336.0, 625.0), vec2(305.0, 685.0),
	vec2(317.0, 715.0), vec2(383.0, 752.0), vec2(425.0, 744.0),
	vec2(457.0, 737.0), vec2(498.0, 736.0), vec2(550.0, 738.0),
	vec2(579.0, 755.0), vec2(605.0, 781.0), vec2(619.0, 799.0),
	vec2(606.0, 822.0), vec2(594.0, 835.0), vec2(615.0, 855.0),
	vec2(685.0, 867.0), vec2(779.0, 888.0), vec2(846.0, 941.0), vec2(0.0, 941.0));

float body_mask(vec2 p) {
	if (p.y < 485.0 || p.x > 850.0) { return 0.0; }
	bool inside = false;
	float distance = 10000.0;
	for (int i = 0; i < 28; i++) {
		vec2 a = BODY[i];
		vec2 b = BODY[(i + 27) % 28];
		vec2 edge = b - a;
		vec2 point = p - a;
		float along = clamp(dot(point, edge) / max(dot(edge, edge), 0.001), 0.0, 1.0);
		distance = min(distance, length(point - edge * along));
		if ((a.y > p.y) != (b.y > p.y)) {
			if (p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x) { inside = !inside; }
		}
	}
	return inside ? smoothstep(0.0, 7.0, distance) : 0.0;
}

float edge_distance(vec2 p, vec2 a, vec2 b) {
	vec2 e = b - a;
	return dot(vec2(-e.y, e.x), p - a) / max(length(e), 0.001);
}

float pane_mask(vec2 p, vec2 a, vec2 b, vec2 c, vec2 d) {
	float distance = min(min(edge_distance(p, a, b), edge_distance(p, b, c)),
		min(edge_distance(p, c, d), edge_distance(p, d, a)));
	return smoothstep(2.0, 9.0, distance);
}

void fragment() {
	vec2 source_size = 1.0 / TEXTURE_PIXEL_SIZE;
	// Координаты стекла на исходном рисунке. Рамы, шторы и горшки остаются неподвижны.
	vec2 p = UV * vec2(1672.0, 941.0);
	float left = pane_mask(p, vec2(526.0, 7.0), vec2(598.0, 27.0),
		vec2(597.0, 264.0), vec2(526.0, 264.0));
	float right = pane_mask(p, vec2(630.0, 34.0), vec2(753.0, 72.0),
		vec2(755.0, 263.0), vec2(629.0, 263.0));
	float mask = max(left, right);
	vec4 original = texture(TEXTURE, UV);
	if (mask > 0.0) {
		// Охристая листва и тёмные веточки двигаются сильнее светлого неба.
		float foliage = clamp((original.r - original.b) * 5.0 + (0.44 - original.g) * 1.3, 0.08, 1.0);
		float height = clamp((265.0 - p.y) / 240.0, 0.15, 1.0);
		float wave = sin(wind_time * 0.85 + p.y * 0.018) + sin(wind_time * 0.49 + p.x * 0.04) * 0.35;
		vec2 offset = vec2(wave * 5.2, sin(wind_time * 0.72 + p.y * 0.029) * 1.2);
		offset *= mask * foliage * height * breeze_strength;
		COLOR = texture(TEXTURE, UV + offset / source_size);
	} else {
		float body = body_mask(p);
		float breath = sin(breath_time * 6.2831853 / 4.7);
		float rise = mix(0.35, 1.0, smoothstep(500.0, 900.0, p.y));
		vec2 breathing = vec2(breath * 0.16, breath) * breath_strength * body * rise;
		COLOR = texture(TEXTURE, UV + breathing / source_size);
	}
}
