shader_type canvas_item;
// 128 号 第 3 段: a district's grime and frost, peeled back from the cable as the power runs
// along it (scripts/district_revive.gd). TEXTURE is the baked field: r = how far along the cable
// the nearest point is (0..1 of the longest way), g = how far from the cable (0..1 of 30 m).
uniform float front = 0.0;      // how far the power has got, same units as r (1.2 = all)
uniform float t = 0.0;
uniform vec2 box_m = vec2(60.0, 28.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	return vnoise(p) * 0.55 + vnoise(p * 2.1 + 5.0) * 0.3 + vnoise(p * 4.3 + 9.0) * 0.15;
}

void fragment() {
	vec2 m = UV * box_m;
	vec4 fd = texture(TEXTURE, UV);
	// grime: soft blotches and faint runs down from the ledges — it dims, it does not hide
	float blot = fbm(m * 0.35);
	float runs = fbm(vec2(m.x * 2.4, m.y * 0.18));
	float grime = clamp(blot * 0.7 + runs * 0.45 - 0.35, 0.0, 1.0);
	// farther from the cable, reached a little later; the edge eaten unevenly, like dirt peeling
	float reach = fd.r + fd.g * 0.35 + (blot - 0.5) * 0.06;
	float dirty = smoothstep(front - 0.035, front + 0.005, reach);
	// frost: fine crystals near the ceiling and the cold outer wall, sparse
	float cold = clamp(1.0 - m.y / 7.0, 0.0, 1.0) * 0.8 + clamp((m.x - 54.0) / 6.0, 0.0, 1.0) * 0.5;
	float frost = smoothstep(0.86, 0.98, vnoise(m * 11.0 + 3.0)) * cold;
	vec3 col = mix(vec3(0.0), vec3(0.06, 0.055, 0.05), grime);
	col = mix(col, vec3(0.7, 0.76, 0.82), frost);
	float a = dirty * (0.5 + 0.18 * grime + 0.35 * frost);
	// the clean edge: a faint warm breath, not a line
	float seam = (1.0 - smoothstep(0.0, 0.03, abs(reach - front))) * step(0.001, front) * step(front, 1.15);
	col = mix(col, vec3(1.0, 0.62, 0.3), seam * 0.22);
	a = max(a, seam * 0.18);
	COLOR = vec4(col, a);
}
