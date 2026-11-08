shader_type canvas_item;
render_mode unshaded;

// Вырез стекла в нарисованном вагоне; фон за ним — отдельный движущийся мир.
const vec2 PANE[13] = vec2[](
	vec2(120.0, 54.0), vec2(1102.0, 165.0), vec2(1131.0, 180.0),
	vec2(1145.0, 213.0), vec2(1145.0, 545.0), vec2(1130.0, 579.0),
	vec2(1103.0, 593.0), vec2(130.0, 676.0), vec2(101.0, 674.0),
	vec2(80.0, 656.0), vec2(71.0, 633.0), vec2(71.0, 103.0), vec2(84.0, 76.0));

void fragment() {
	vec2 p = UV * vec2(1659.0, 948.0);
	float distance = 10000.0;
	for (int i = 0; i < 13; i++) {
		vec2 a = PANE[i];
		vec2 edge = PANE[(i + 1) % 13] - a;
		distance = min(distance, dot(vec2(-edge.y, edge.x), p - a) / length(edge));
	}
	vec4 paint = texture(TEXTURE, UV);
	paint.a *= 1.0 - smoothstep(-1.5, 1.5, distance);
	COLOR = paint;
}
