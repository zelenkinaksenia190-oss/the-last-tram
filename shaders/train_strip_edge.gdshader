shader_type canvas_item;
render_mode unshaded;

// Только пространственный стык соседних участков. Никакого растворения экрана по времени.
uniform float overlap : hint_range(0.01, 0.4) = 0.19;
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 paint = texture(TEXTURE, UV) * tint;
	paint.a *= smoothstep(0.0, overlap, UV.x);
	COLOR = paint;
}
