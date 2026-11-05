extends RefCounted
# 星图的 GPU 层（用户 2026-11-04：“酷炫……让人一看就觉得在太空中”）。旧版每帧在 CPU 上逐段重画
# 星空、网格、小行星带和轨道，约 10.5 ms；这里全部交给着色器：
#   space    全屏：三层视差星空（亮星带衍射芒）、银河星尘、太阳日冕与横向光晕、导航网格
#            （平时很淡，鼠标附近亮起细网格）、边缘方位刻度与扫掠、暗角、抖动去色带
#   belt     小行星带：一次建好的网格，顶点着色器按开普勒周期转，鼠标附近的石头泛冰蓝
#   orbit    轨道：一次建好的带状网格，线宽在屏幕像素里恒定，彗尾式拖尾在着色器里算
#   chart    特效：扇区环、选中扇区（虚线环/旋转弧/声呐扇）、港口信标、扫描波、分析光束、
#            悬停锁定环、点击涟漪、十字准线
#   radar    局部雷达的底盘：网格、距离环、刻度、带余辉的扫掠线、杂波
# hdr_2d 下着色器里的颜色是线性值：常量都写成线性，主题色走 source_color。

const ACCENT := Color("ff8a50")
const DATA := Color("6fd3ff")


static var _shaders := {}


static func shader(name: String) -> Shader:
	if not _shaders.has(name):
		var s := Shader.new()
		s.code = COMMON_HEAD + {"space": SPACE, "belt": BELT, "orbit": ORBIT, "chart": CHART, "radar": RADAR, "sheen": SHEEN}[name]
		_shaders[name] = s
	return _shaders[name]


static func material(name: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader(name)
	m.set_shader_parameter("accent", ACCENT)
	m.set_shader_parameter("data", DATA)
	return m


# the belt: every rock a quad; VERTEX holds (r AU, angle at day 0), UV the corner's sign with its
# size and brightness packed behind it (|uv| - 1)
static func belt_mesh(rocks: Array) -> ArrayMesh:
	var v := PackedVector2Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	for b in rocks:
		var base := v.size()
		var sz := clampf((float(b[2]) - 0.8) / 1.1, 0.0, 0.999)
		var al := clampf(float(b[3]), 0.0, 0.999)
		for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			v.append(Vector2(float(b[0]), float(b[1])))
			uv.append(Vector2(c.x * (1.0 + sz), c.y * (1.0 + al)))
		idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	return _mesh(v, uv, idx)


# an orbit as a strip: VERTEX the point in AU, UV.x its phase (0..1 of the period), UV.y the side
# (sign) with the normal's angle packed behind it (|uv.y| - 2)
static func orbit_mesh(el: Array, n := 240) -> ArrayMesh:
	var per := Orbits.period(el)
	var pts: Array = []
	for i in n + 1:
		pts.append(Orbits.pos(el, per * i / n))
	var v := PackedVector2Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in n + 1:
		var a: Vector2 = pts[i - 1] if i > 0 else pts[n - 1]
		var b: Vector2 = pts[i + 1] if i < n else pts[1]
		var tg := (b - a).normalized()
		var th := fposmod(Vector2(-tg.y, tg.x).angle(), TAU)
		v.append(pts[i])
		v.append(pts[i])
		uv.append(Vector2(float(i) / n, -(2.0 + th)))
		uv.append(Vector2(float(i) / n, 2.0 + th))
		if i < n:
			var q := i * 2
			idx.append_array([q, q + 1, q + 2, q + 1, q + 3, q + 2])
	return _mesh(v, uv, idx)


static func _mesh(v: PackedVector2Array, uv: PackedVector2Array, idx: PackedInt32Array) -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


const COMMON_HEAD := """
shader_type canvas_item;
uniform vec4 accent : source_color = vec4(1.0, 0.54, 0.31, 1.0);
uniform vec4 data : source_color = vec4(0.43, 0.83, 1.0, 1.0);
// an integer hash of the lattice cell (a float hash came out differently for the same cell from
// different call sites on the GPU, and the noise broke into blocks)
uint hu(uvec2 v) {
	v = v * 1664525u + 1013904223u;
	v.x += v.y * 1664525u; v.y += v.x * 1664525u;
	v ^= v >> 16u;
	v.x += v.y * 1664525u; v.y += v.x * 1664525u;
	v ^= v >> 16u;
	return v.x ^ v.y;
}
float h21(vec2 p) { uvec2 q = uvec2(ivec2(floor(p)) + ivec2(65536)); return float(hu(q) & 16777215u) / 16777216.0; }
vec2 h22(vec2 p) { return vec2(h21(p), h21(p + vec2(17.0, 59.0))); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), u.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) { float a = 0.5; float s = 0.0; for (int i = 0; i < 5; i++) { s += a * vnoise(p); p = p * 2.03 + vec2(1.7, 9.2); a *= 0.5; } return s; }
float ln(float d, float w) { return 1.0 - smoothstep(w * 0.5 - 0.5, w * 0.5 + 0.7, d); }
"""


const SPACE := """
uniform vec2 size = vec2(1920.0, 1080.0);
uniform vec2 sun_px;
uniform vec2 chart_c;
uniform float k = 130.0;
uniform float rim_au = 3.7;
uniform vec2 par;
uniform vec2 mouse = vec2(-9999.0);
uniform float t;
uniform float zoom = 1.0;
uniform float grid_on = 1.0;

vec3 stars(vec2 p, float cell, float dens, float bright, float spikes) {
	vec2 c = floor(p / cell);
	if (h21(c) > dens) return vec3(0.0);
	vec2 o = (0.18 + 0.64 * h22(c + vec2(3001.0, 11.0))) * cell;
	vec2 d = p - c * cell - o;
	float r2 = dot(d, d);
	float m = h21(c + vec2(7001.0, 23.0));
	float tw = 0.7 + 0.3 * sin(t * (0.5 + 1.6 * m) + h21(c + vec2(2001.0, 37.0)) * 60.0);
	float b = bright * (0.2 + 0.8 * m * m) * tw;
	float core = exp(-r2 * (1.5 - 0.9 * m));
	float halo = exp(-sqrt(r2) * 0.45) * 0.10 * m;
	float sp = 0.0;
	if (spikes > 0.0 && m > 0.86) {
		sp = (exp(-abs(d.y) * 1.4) * exp(-abs(d.x) * 0.22) + exp(-abs(d.x) * 1.4) * exp(-abs(d.y) * 0.22)) * spikes * (m - 0.8) * 2.5;
	}
	vec3 tint = h21(c + vec2(1001.0, 53.0)) > 0.5 ? vec3(0.78, 0.88, 1.0) : vec3(1.0, 0.86, 0.72);
	return mix(vec3(1.0), tint, 0.45) * b * (core + halo + sp);
}

void fragment() {
	vec2 px = UV * size;
	vec3 col = vec3(0.0011, 0.0013, 0.0021);
	// the galaxy: a soft diagonal band of dust and dense stars, dark lanes through it
	vec2 q = px - chart_c;
	float bd = dot(q, normalize(vec2(0.52, 1.0))) + 120.0;
	float band = exp(-bd * bd / (2.0 * 300.0 * 300.0));
	// the nebula: two depths of cloud (#016 factors 0.1 and 0.28), barely tinted, dark lanes through it
	vec2 p1 = px + par * 0.1;
	vec2 p2 = px + par * 0.28 + 300.0;
	float n1 = fbm(p1 * 0.0016 + vec2(t * 0.002, 3.0));
	float n2 = fbm(p2 * 0.0042 + 7.0);
	float w1 = smoothstep(0.34, 0.95, n1) * (0.3 + 0.7 * band);
	float w2 = smoothstep(0.48, 0.92, n2) * (0.15 + 0.85 * band) * smoothstep(0.3, 0.7, n1);
	float hue = smoothstep(0.3, 0.7, vnoise(p1 * 0.0009 + 5.0));
	col += mix(vec3(0.0110, 0.0122, 0.0155), vec3(0.0140, 0.0118, 0.0100), hue) * w1 * 1.5;
	col += vec3(0.0125, 0.0130, 0.0145) * w2 * 1.1;
	float lanes = smoothstep(0.55, 0.76, fbm(p2 * 0.007 + 3.0));
	col *= 1.0 - 0.6 * band * lanes;
	// three layers of stars, each moving at its own depth
	vec2 zc = chart_c;
	col += stars((px - zc) * (1.0 + (zoom - 1.0) * 0.02) + zc + par * 0.05, 7.0, 0.05 + 0.35 * band, 0.07, 0.0);
	col += stars((px - zc) * (1.0 + (zoom - 1.0) * 0.05) + zc + par * 0.28 + 517.0, 21.0, 0.30, 0.28, 0.0);
	col += stars((px - zc) * (1.0 + (zoom - 1.0) * 0.12) + zc + par * 0.6 + 911.0, 61.0, 0.30, 0.8, 0.55);
	// the sun's light on the inner system
	vec2 ds = px - sun_px;
	float dsun = length(ds);
	float sz = sqrt(zoom);
	col += accent.rgb * 0.05 * exp(-dsun / (80.0 * sz));
	col += accent.rgb * 0.010 * exp(-dsun / (380.0 * sz));
	float rau = dsun / k;
	// the belt's dust: a faint ring, lumpy
	float beltz = exp(-pow((rau - 2.7) / 0.32, 2.0));
	vec2 dn = ds / max(dsun, 1.0);
	col += vec3(0.0055, 0.0055, 0.0062) * beltz * (0.4 + 1.1 * fbm(dn * 9.0 + rau * 3.0));
	// the navigation plot: faint everywhere, lit up round the pointer
	float rim = rim_au * k;
	float inside = 1.0 - smoothstep(rim - 1.0, rim + 1.0, dsun);
	float mr = mouse.x > -9000.0 ? exp(-dot(px - mouse, px - mouse) / (2.0 * 150.0 * 150.0)) : 0.0;
	if (grid_on > 0.5) {
		float rr = rau * 2.0;
		float nr = floor(rr + 0.5);
		float fr = abs(rr - nr) * k * 0.5;
		float whole = 1.0 - mod(nr, 2.0);
		float ring = nr > 0.5 ? ln(fr, 1.0) : 0.0;
		col += mix(vec3(1.0), data.rgb, mr) * ring * ((whole > 0.5 ? 0.03 : 0.012) + 0.22 * mr) * inside;
		float a = atan(-ds.y, ds.x);
		float st = 3.14159265 / 12.0;
		float da = abs(fract(a / st + 0.5) - 0.5) * st * dsun;
		float spoke = ln(da, 1.0) * step(1.0, rau) * (1.0 - smoothstep(rim - 16.0, rim - 14.0, dsun));
		col += mix(vec3(1.0), data.rgb, mr) * spoke * (0.010 + 0.14 * mr);
		// the fine plot only where the pointer is
		float rf = rau * 10.0;
		float ff = abs(rf - floor(rf + 0.5)) * k * 0.1;
		float st5 = 3.14159265 / 36.0;
		float d5 = abs(fract(a / st5 + 0.5) - 0.5) * st5 * dsun;
		col += data.rgb * (ln(ff, 1.0) + ln(d5, 1.0) * step(0.6, rau)) * 0.05 * mr * mr * inside;
		// the rim, its ticks every 5 degrees and the long ones every 15
		col += vec3(1.0) * ln(abs(dsun - rim), 1.0) * 0.12;
		col += data.rgb * exp(-abs(dsun - rim) / 18.0) * 0.012;
		float tick = abs(fract(a / st5 + 0.5) - 0.5) * st5 * dsun;
		float longt = step(abs(fract(a / st + 0.5) - 0.5) * st * dsun, 0.8);
		float tl = mix(5.0, 12.0, longt);
		col += vec3(1.0) * ln(tick, 1.0) * step(rim - tl, dsun) * step(dsun, rim) * mix(0.08, 0.2, longt);
		// a bearing scan turning slowly round the rim
		float sw = mod(t * 0.35, 6.2831853);
		float sa = atan(ds.y, ds.x);
		float behind = mod(sw - sa, 6.2831853);
		col += data.rgb * exp(-behind * 9.0) * 0.16 * step(rim - 10.0, dsun) * step(dsun, rim);
	}
	// the sun: a white-hot core, a corona of slow rays, an anamorphic streak
	float rays = fbm(dn * 3.2 + vec2(t * 0.05, -t * 0.04));
	float r0 = 6.5 * sz;
	float cor = exp(-max(dsun - r0, 0.0) / (8.0 * sz * (0.45 + 1.1 * rays)));
	col += mix(accent.rgb, vec3(1.0, 0.82, 0.62), 0.35) * cor * 1.3;
	col += accent.rgb * 0.30 * exp(-abs(ds.y) / 1.1) * exp(-abs(ds.x) / (150.0 * sz));
	col += accent.rgb * 0.08 * exp(-abs(ds.y) / 4.0) * exp(-abs(ds.x) / (60.0 * sz));
	col = mix(col, vec3(1.6, 1.32, 1.05), smoothstep(r0 + 0.8, r0 - 0.8, dsun));
	// a vignette, and grain against banding in the dark
	float vg = length((px - chart_c) / (size * vec2(0.55, 0.62)));
	col *= mix(1.0, 0.45, smoothstep(0.55, 1.35, vg));
	col += (h21(px + fract(t * 7.0) * 91.0) - 0.5) * 0.0012;
	COLOR = vec4(col, 1.0);
}
"""


const BELT := """
render_mode blend_add;
uniform vec2 sun_px;
uniform float k = 130.0;
uniform float day;
uniform vec2 mouse = vec2(-9999.0);
uniform float zoom = 1.0;
uniform float bright = 1.0;
varying vec2 v_c;
varying float v_a;
varying float v_glow;
void vertex() {
	vec2 c = sign(UV);
	float sz = mix(0.8, 1.9, abs(UV.x) - 1.0);
	v_a = abs(UV.y) - 1.0;
	float r = VERTEX.x;
	float a = VERTEX.y + day / (365.25 * pow(r, 1.5)) * 6.2831853;
	vec2 p = sun_px + vec2(cos(a), -sin(a)) * r * k;
	float s = sz * (0.65 + 0.35 * sqrt(zoom));
	float pad = s + 1.5;
	VERTEX = p + c * pad;
	v_c = c * pad / s;
	vec2 dm = p - mouse;
	v_glow = exp(-dot(dm, dm) / (2.0 * 130.0 * 130.0));
}
void fragment() {
	float d = length(v_c);
	float a = (1.0 - smoothstep(0.55, 1.25, d)) * v_a * bright;
	vec3 c = mix(vec3(0.82, 0.83, 0.88), data.rgb * 1.5, v_glow);
	COLOR = vec4(c, a * (0.85 + v_glow * 1.6));
}
"""


const ORBIT := """
render_mode blend_add;
uniform vec2 sun_px;
uniform float k = 130.0;
uniform vec4 col : source_color = vec4(1.0);
uniform float base_a = 0.08;
uniform float width = 1.0;
uniform float glow_px = 5.0;
uniform float glow_a = 0.0;
uniform float body_u = 0.0;
uniform float trail = 0.0;
uniform float trail_a = 0.0;
uniform float trail_w = 2.2;
uniform float flow = 0.0;
uniform float t;
varying float v_side;
varying float v_u;
float hw() { return max(width, trail_w) * 0.5 + 1.2 + glow_px * 2.2; }
void vertex() {
	float th = abs(UV.y) - 2.0;
	v_side = sign(UV.y);
	v_u = UV.x;
	vec2 n = vec2(cos(th), -sin(th));
	vec2 p = sun_px + vec2(VERTEX.x, -VERTEX.y) * k;
	VERTEX = p + n * v_side * hw();
}
void fragment() {
	float d = abs(v_side) * hw();
	float du = fract(body_u - v_u);
	float tr = trail > 0.0 ? max(0.0, 1.0 - du / trail) : 0.0;
	tr *= tr;
	float w = mix(width, trail_w * (0.4 + 0.6 * tr), step(0.001, tr));
	float core = ln(d, w);
	float glow = exp(-d * d / (glow_px * glow_px + 0.001));
	float a = core * base_a + tr * (core * trail_a + glow * glow_a);
	// a faint pulse running along the line, as if data were flowing round it
	if (flow > 0.0) a += core * flow * pow(max(0.0, sin((v_u * 6.0 - t * 0.08) * 6.2831853)), 24.0);
	COLOR = vec4(col.rgb, a);
}
"""


const CHART := """
render_mode blend_add;
uniform vec2 size = vec2(1400.0, 1080.0);
uniform float t;
uniform int n_st = 0;
uniform vec2 st[16];
uniform float st_s[16];
uniform int sel = -1;
uniform float ring_r = 30.0;
uniform vec2 port = vec2(-9999.0);
uniform vec2 mouse = vec2(-9999.0);
uniform vec2 hov = vec2(-9999.0);
uniform float hov_k = 0.0;
uniform float sw_on = 0.0;
uniform vec2 sw_to;
uniform float sw_k = 0.0;
uniform float an_on = 0.0;
uniform vec2 an_to;
uniform vec3 rip[4];
uniform float sel_t = 9.0;

float seg(vec2 p, vec2 a, vec2 b, out float h) {
	vec2 pa = p - a; vec2 ba = b - a;
	h = clamp(dot(pa, ba) / max(dot(ba, ba), 1.0), 0.0, 1.0);
	return length(pa - ba * h);
}

void fragment() {
	vec2 px = UV * size;
	vec3 acc = vec3(0.0);
	// the sectors: a thin ring round each station in reach; the picked one turning and lit
	for (int i = 0; i < 16; i++) {
		if (i >= n_st) break;
		vec2 dv = px - st[i];
		float d = length(dv);
		if (d > ring_r + 60.0) continue;
		float ang = atan(dv.y, dv.x);
		if (i == sel) {
			// it lands: the ring drops in from wide, a flash on the way
			float e = clamp(sel_t / 0.45, 0.0, 1.0);
			float ee = 1.0 - pow(1.0 - e, 3.0);
			float rr = mix(ring_r * 1.9, ring_r, ee);
			float flash = (1.0 - e) * 1.5;
			float dash = step(0.42, fract((ang + t * 0.3) / 6.2831853 * 24.0));
			acc += accent.rgb * ln(abs(d - rr), 2.0) * mix(dash, 1.0, flash * 0.6) * (1.0 + flash);
			acc += accent.rgb * exp(-abs(d - rr) / 6.0) * (0.12 + 0.3 * flash);
			acc += accent.rgb * 0.03 * (1.0 - smoothstep(rr * 0.15, rr, d));
			float a2 = mod(ang + t * 0.2, 6.2831853);
			acc += accent.rgb * 0.55 * ln(abs(d - rr - 7.0), 1.0) * step(a2, 1.5708);
			float a3 = mod(-ang + t * 0.5 + 2.0, 6.2831853);
			acc += accent.rgb * 0.35 * ln(abs(d - rr - 12.0), 1.0) * step(a3, 0.6);
			// the sonar fan sweeping inside the sector
			float behind = mod(t * 1.1 - ang, 6.2831853);
			acc += accent.rgb * 0.10 * exp(-behind * 2.5) * step(d, rr) * smoothstep(0.0, rr * 0.4, d);
			// four ticks on the cardinal points
			float qa = abs(fract(ang / 1.5707963 + 0.5) - 0.5) * 1.5707963 * d;
			acc += accent.rgb * 0.8 * ln(qa, 1.5) * step(rr + 3.0, d) * step(d, rr + 10.0);
		} else if (st_s[i] > 0.0) {
			vec3 c = st_s[i] > 0.5 ? data.rgb : vec3(1.0);
			float lit = st_s[i] > 1.5 ? 1.0 : 0.0;
			acc += c * ln(abs(d - ring_r), 1.0) * (st_s[i] > 0.5 ? 0.3 + 0.5 * lit : 0.06);
			acc += c * exp(-abs(d - ring_r) / 5.0) * 0.05 * (st_s[i] > 0.5 ? 1.0 + 3.0 * lit : 0.0);
		}
	}
	// the port's beacon
	if (port.x > -9000.0) {
		float dp = length(px - port);
		for (int n = 0; n < 2; n++) {
			float pu = fract(t * 0.5 + float(n) * 0.5);
			acc += data.rgb * ln(abs(dp - (9.0 + 34.0 * pu)), 1.5) * 0.55 * (1.0 - pu) * (1.0 - pu);
		}
		acc += data.rgb * 0.18 * exp(-dp / 10.0);
	}
	// the sweep: wavefronts racing from the port to the sector, a beam, the sector ringing
	if (sw_on > 0.5) {
		vec2 dir = sw_to - port;
		float dist = length(dir);
		dir /= max(dist, 1.0);
		vec2 dv = px - port;
		float d = length(dv);
		float ca = dot(dv / max(d, 1.0), dir);
		float wedge = smoothstep(0.975, 0.995, ca);
		for (int n = 0; n < 4; n++) {
			float kk = fract(sw_k * 3.0 + float(n) / 4.0);
			float fd = abs(d - dist * kk);
			acc += data.rgb * (ln(fd, 2.0) * 1.3 + exp(-fd / 7.0) * 0.35) * wedge * (1.0 - kk);
		}
		float h;
		float sd = seg(px, port, sw_to, h);
		float dash = step(0.5, fract(h * dist / 14.0 - t * 2.5));
		acc += data.rgb * (ln(sd, 1.0) * (0.12 + 0.25 * dash) + exp(-sd / 5.0) * 0.05);
		float dt = length(px - sw_to);
		for (int n = 0; n < 3; n++) {
			float pk = fract(sw_k * 4.0 + float(n) / 3.0);
			float rr = ring_r * (1.4 - 1.1 * pk);
			acc += data.rgb * ln(abs(dt - rr), 1.5) * 0.8 * pk;
		}
		// interference shimmer inside the sector while it listens
		float sh = vnoise(px * 0.15 + vec2(t * 6.0, 0.0)) * vnoise(px * 0.05 - t);
		acc += data.rgb * sh * 0.25 * (1.0 - smoothstep(0.0, ring_r, dt));
	}
	if (an_on > 0.5) {
		float h;
		float sd = seg(px, port, an_to, h);
		float L = length(an_to - port);
		float dash = step(0.6, fract(h * L / 10.0 - t * 3.0));
		acc += accent.rgb * (ln(sd, 1.0) * (0.15 + 0.35 * dash) + exp(-sd / 4.0) * 0.06);
	}
	// the lock on what the pointer is over: three arcs closing in and turning
	if (hov.x > -9000.0) {
		vec2 dv = px - hov;
		float d = length(dv);
		float e = 1.0 - pow(1.0 - hov_k, 3.0);
		float r = mix(34.0, 18.0, e);
		float ang = atan(dv.y, dv.x);
		float sg = step(fract((ang - t * 1.6) / 6.2831853 * 3.0), 0.62);
		acc += accent.rgb * (exp(-abs(d - r) / 6.0) * 0.08 + 0.10 * exp(-d / 14.0)) * e;
	}
	// clicks: a shock ring and an echo inside it
	for (int i = 0; i < 4; i++) {
		float age = rip[i].z;
		if (age < 0.0 || age > 0.9) continue;
		float d = length(px - rip[i].xy);
		float r = 260.0 * (1.0 - pow(1.0 - age / 0.9, 2.5));
		float a = pow(1.0 - age / 0.9, 2.0);
		acc += data.rgb * (ln(abs(d - r), 1.5 + age * 4.0) * 0.9 + exp(-abs(d - r) / 10.0) * 0.18) * a;
		acc += data.rgb * ln(abs(d - r * 0.55), 1.0) * 0.4 * a;
		acc += vec3(1.0) * exp(-d / 8.0) * max(0.0, 1.0 - age / 0.18) * 0.8;
	}
	// the pointer: crosshairs fading away from it, a soft light round it
	if (mouse.x > -9000.0) {
		vec2 dm = abs(px - mouse);
		float hx = ln(dm.y, 1.0) * step(16.0, dm.x) * exp(-dm.x / 260.0);
		float vy = ln(dm.x, 1.0) * step(16.0, dm.y) * exp(-dm.y / 260.0);
		float tk = ln(abs(fract(dm.x / 24.0 + 0.5) - 0.5) * 24.0, 1.0) * step(dm.y, 3.0) * step(dm.x, 150.0) * step(16.0, dm.x);
		float tk2 = ln(abs(fract(dm.y / 24.0 + 0.5) - 0.5) * 24.0, 1.0) * step(dm.x, 3.0) * step(dm.y, 150.0) * step(16.0, dm.y);
		acc += data.rgb * ((hx + vy) * 0.22 + (tk + tk2) * 0.22);
		acc += data.rgb * 0.035 * exp(-length(px - mouse) / 90.0);
	}
	COLOR = vec4(acc, 1.0);
}
"""


const RADAR := """
uniform vec2 size = vec2(400.0, 320.0);
uniform vec2 c = vec2(200.0, 174.0);
uniform float R = 136.0;
uniform float ang;
uniform float sweeping = 0.0;
uniform float t;
uniform float open_k = 1.0;
void fragment() {
	vec2 px = UV * size;
	vec2 dv = px - c;
	float d = length(dv);
	vec3 col = vec3(0.0010, 0.0014, 0.0020);
	col += data.rgb * 0.006 * (1.0 - smoothstep(0.0, R * 1.4, d));
	vec2 g = abs(fract(px / 16.0 - 0.5) - 0.5) * 16.0;
	col += data.rgb * 0.0045 * (ln(g.x, 1.0) + ln(g.y, 1.0));
	float ins = 1.0 - smoothstep(R - 0.5, R + 0.5, d);
	for (int i = 1; i <= 4; i++) {
		col += data.rgb * ln(abs(d - R * float(i) / 4.0), 1.0) * (i < 4 ? 0.07 : 0.32);
	}
	col += data.rgb * 0.06 * (ln(abs(dv.x), 1.0) + ln(abs(dv.y), 1.0)) * ins;
	float a = atan(dv.y, dv.x);
	float s10 = 3.14159265 / 18.0;
	float tick = abs(fract(a / s10 + 0.5) - 0.5) * s10 * d;
	float lg = step(abs(fract(a / (s10 * 3.0) + 0.5) - 0.5) * s10 * 3.0 * d, 0.8);
	col += data.rgb * ln(tick, 1.0) * step(R - mix(4.0, 9.0, lg), d) * step(d, R) * 0.45;
	// the sweep with its phosphor afterglow, clutter flickering in the glow
	float behind = mod(ang - a, 6.2831853);
	float gl = exp(-behind * mix(3.6, 1.9, sweeping)) * mix(0.22, 0.55, sweeping) * ins;
	float clutter = step(0.975, h21(floor(px / 2.0) + floor(t * 9.0) * 13.0));
	col += data.rgb * gl * (0.7 + 0.6 * clutter);
	col += data.rgb * ln(behind * d, 1.5) * mix(0.5, 1.1, sweeping) * ins;
	col += data.rgb * exp(-max(d - R, 0.0) / 6.0) * 0.05 * (1.0 - ins);
	// the glass: faint scanlines and an edge
	col *= 0.93 + 0.07 * sin(px.y * 3.14159);
	float e = min(min(px.x, size.x - px.x), min(px.y, size.y - px.y));
	col += data.rgb * 0.32 * ln(e - 0.5, 1.0);
	vec2 cd = min(px, size - px);
	float corner = step(cd.x, 18.0) * step(cd.y, 18.0) * ln(min(cd.x, cd.y) - 1.0, 2.0);
	col += data.rgb * corner * 0.9;
	// opening: the scope wipes on from the middle line
	float wipe = step(abs(px.y - size.y * 0.5), size.y * 0.5 * open_k + 0.5);
	COLOR = vec4(col, 0.97 * wipe);
}
"""


# a button's light (#154 Spotlight hover, Motion Prompt · MIT License (c) 2026 Shohei Ohtaki ·
# https://showheyohtaki.github.io/motion-prompt/#154): inside the button only, a white radial light of
# radius 115 at the pointer (0.34 at the centre, here scaled by `amt` for the dark glass), the edge
# glowing orange by its distance to the pointer (radius 120); plus a flash from the click point, a slow
# breath on the page's one action, and a single light as a new row arrives
const SHEEN := """
render_mode blend_add;
uniform vec2 size = vec2(400.0, 40.0);
uniform float radius = 12.0;
uniform vec2 mouse = vec2(-9999.0);
uniform float amt = 0.35;
uniform float press = 9.0;
uniform vec2 press_at;
uniform float breathe = 0.0;
uniform float born = 9.0;
uniform float t;
float rbox(vec2 p, vec2 b, float r) { vec2 q = abs(p) - b + r; return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r; }
void fragment() {
	vec2 px = UV * size;
	float sd = rbox(px - size * 0.5, size * 0.5, radius);
	float inside = 1.0 - smoothstep(-0.5, 0.5, sd);
	float edge = ln(abs(sd + 1.0), 2.0);
	vec3 acc = vec3(0.0);
	float dm = length(px - mouse);
	acc += vec3(1.0) * 0.34 * amt * max(0.0, 1.0 - dm / 115.0) * inside;
	acc += accent.rgb * max(0.0, 1.0 - dm / 120.0) * edge;
	float pr = press * 900.0;
	float pd = length(px - press_at);
	float pa = max(0.0, 1.0 - press / 0.4);
	acc += vec3(1.0) * (exp(-abs(pd - pr) / 10.0) * 0.35 + 0.08) * pa * pa * inside;
	acc += accent.rgb * breathe * (0.5 + 0.5 * sin(t * 2.6)) * edge * 0.7;
	float x = (px.x - px.y * 0.6) / (size.x + size.y * 0.6);
	float ba = max(0.0, 1.0 - born / 0.9);
	float bx = mix(-0.2, 1.2, clamp(born / 0.6, 0.0, 1.0));
	acc += vec3(1.0) * (exp(-pow((x - bx) / 0.08, 2.0)) * 0.3) * ba * inside + accent.rgb * edge * ba * 0.8;
	COLOR = vec4(acc, 1.0);
}
"""
