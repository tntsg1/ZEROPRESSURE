// 118 号 层次纵深 Q3 A: the ship's shadow on the berth's back wall. The CanvasGroup draws the
// hull's silhouette (opaque, so overlapping plates do not darken twice); here it is read back a
// few mip levels down (soft edges, about a third of a metre) and laid on as a shade, only
// inside the wall's box on screen.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float lod = 2.0;
uniform float strength = 0.7;
uniform vec4 wall = vec4(0.0, 0.0, 1.0, 1.0);   // the wall's box in screen UV: x0, y0, x1, y1

void fragment() {
	float a = textureLod(screen_texture, SCREEN_UV, lod).a;
	vec2 e = vec2(0.004);
	float inside = smoothstep(wall.x - e.x, wall.x + e.x, SCREEN_UV.x) * (1.0 - smoothstep(wall.z - e.x, wall.z + e.x, SCREEN_UV.x))
		* smoothstep(wall.y - e.y, wall.y + e.y, SCREEN_UV.y) * (1.0 - smoothstep(wall.w - e.y, wall.w + e.y, SCREEN_UV.y));
	COLOR = vec4(0.0, 0.0, 0.0, clamp(a, 0.0, 1.0) * strength * inside);
}
