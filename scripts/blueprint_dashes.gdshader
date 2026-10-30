shader_type canvas_item;
// Cached dash endpoints, with signed half-width offsets in negative UVs.
// Ordinary labels and symbols retain their normal UVs and default rendering.
uniform float dash_width = 1.0;
void vertex() {
	if (UV.x < -5.0) {
		VERTEX += vec2(UV.x + 10.0, UV.y) * dash_width;
		UV = vec2(0.0);
	}
}
