shader_type canvas_item;
// liquid_surface.gd: the globules' summed field (r) and their liquid's place in the palette
// (g, b: u, v weighted by the field) read at the iso-line: a fill inside as clear or as opaque as
// the liquid is, a bright rim on the line, a highlight where the surface faces the light (up and
// a little left, like the rest of the berth). The palette (liquid_colors.gd): rgb the liquid's
// real colour, a how opaque it is (user 2026-11-10 "不同液体用它现实里的颜色").
uniform sampler2D field : filter_linear, repeat_disable;
uniform sampler2D palette : filter_nearest, repeat_disable;
uniform vec4 shine : source_color;
uniform vec2 texel = vec2(0.001);
const float ISO = 0.5;
const vec2 SUN_DIR = vec2(-0.45, -0.89);

void fragment() {
	vec3 f = texture(field, SCREEN_UV).rgb;
	float v = f.r;
	if (v < ISO * 0.7) {
		COLOR = vec4(0.0);
	} else {
		vec2 puv = clamp(vec2(f.g, f.b) / max(v, 0.0001), vec2(0.0), vec2(0.999));
		vec4 base = texture(palette, puv);
		float op = base.a;
		float fw = max(fwidth(v), 0.0005);
		float inside = smoothstep(ISO - fw, ISO + fw, v);
		// the rim: a line about two pixels wide just inside the iso-line
		float rim = inside * (1.0 - smoothstep(ISO + fw * 1.5, ISO + fw * 3.0, v));
		// the surface's slope from the field: its outward normal, and the light on it
		float gx = texture(field, SCREEN_UV + vec2(texel.x, 0.0)).r - texture(field, SCREEN_UV - vec2(texel.x, 0.0)).r;
		float gy = texture(field, SCREEN_UV + vec2(0.0, texel.y)).r - texture(field, SCREEN_UV - vec2(0.0, texel.y)).r;
		vec2 outward = -normalize(vec2(gx, gy) + vec2(0.00001));
		float near_edge = 1.0 - smoothstep(ISO, ISO + 0.6, v);
		float spec = pow(max(dot(outward, SUN_DIR), 0.0), 6.0) * near_edge * inside;
		// a deeper body reads a little denser toward its middle
		float body = inside * mix(0.07 + 0.06 * smoothstep(ISO, ISO * 3.0, v), 0.55 + 0.3 * smoothstep(ISO, ISO * 3.0, v), op);
		vec3 col = base.rgb;
		float a = max(body, rim * 0.85);
		col = mix(col, shine.rgb, clamp(spec * 0.8, 0.0, 1.0));
		a = max(a, spec * 0.55);
		COLOR = vec4(col, a);
	}
}
