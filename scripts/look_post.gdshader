shader_type canvas_item;
// 91 号: the full-screen pass over the world (after the glow, under the HUD).
// Vignette always; with the "film" setting a fine moving grain and a slight colour
// fringe that grows toward the corners. The buffer is linear HDR: grain is added in
// a perceptual space so the darks don't get lifted into grey.
// 遥控与沉浸: on site the picture is the drone's camera feed — a faint rolling band of
// the sensor read-out; when the link to the bay weakens (interference 0..1) rows tear
// sideways, blocks of the picture coarsen and noise bursts through; while the zoom changes
// the stream breaks into big pixel blocks (focus 0..1) and resolves as it settles.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float grain = 0.022;
uniform float fringe = 0.0016;
uniform float vignette = 0.42;
uniform float t = 0.0;
uniform float feed = 0.0;
uniform float interference = 0.0;
uniform float focus = 0.0;
// AX-40 逆火 · the annihilation (scripts/annihilation.gd): all zero = untouched.
//   a_pull   the collapse: the picture drawn in toward a_c and wound round it, a thin lens ring
//            (negative: the release, pushed back out as a ring)
//   a_inv    the gamma shell's one frame of negative, inside a_inv_r (uv, height units)
//   a_dark   the world blacked out behind the bubble-chamber tracks
//   a_edge   the berth burnt into glowing outlines; a_cut puts them out cell by cell from a_wc out
uniform vec2 a_c = vec2(0.5);
uniform float a_pull = 0.0;
uniform float a_lens = 0.12;
uniform float a_inv = 0.0;
uniform float a_inv_r = 0.0;
uniform float a_dark = 0.0;
uniform float a_edge = 0.0;
uniform float a_cut = 0.0;
uniform vec2 a_wo = vec2(0.0);
uniform vec2 a_ws = vec2(1920.0, 1080.0);
uniform vec2 a_wc = vec2(0.0);
uniform float a_rmax = 3000.0;
uniform vec3 a_edge_col = vec3(0.55, 1.25, 1.75);

float hash(vec2 p) {
	p = fract(p * vec2(443.897, 441.423));
	p += dot(p, p.yx + 19.19);
	return fract((p.x + p.y) * p.x);
}

float lum(vec2 uv) {
	return dot(texture(screen_tex, uv).rgb, vec3(0.3, 0.55, 0.15));
}

vec3 sample_at(vec2 uv, vec2 d, float r2) {
	vec3 c;
	if (fringe > 0.0 || focus > 0.06) {
		// and while the wheel turns, a slight colour split across the whole frame
		vec2 o = d * fringe * smoothstep(0.08, 0.32, r2) * 3.0 + vec2(0.0022 * clamp(focus, 0.0, 1.0), 0.0);
		c.r = texture(screen_tex, uv + o).r;
		c.g = texture(screen_tex, uv).g;
		c.b = texture(screen_tex, uv - o).b;
	} else {
		c = texture(screen_tex, uv).rgb;
	}
	return c;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	// user: zooming — "滚轮上下滑的时候稍微有一点点就可以了，参考《赛博朋克》": while the wheel
	// turns, a few thin slices of the picture slip sideways and small blocks flicker; that's all
	if (focus > 0.06) {
		float k = clamp(focus, 0.0, 1.0);
		float slice = floor(uv.y * 64.0);
		float on = step(1.0 - 0.18 * k, hash(vec2(slice, floor(t * 20.0))));
		uv.x += on * (hash(vec2(slice, 7.7)) - 0.5) * 0.012 * k;
		float blk = step(1.0 - 0.06 * k, hash(floor(uv / (px * 10.0)) + floor(t * 20.0)));
		uv = mix(uv, (floor(uv / (px * 5.0)) + 0.5) * px * 5.0, blk);
	}
	// the link breaking up: whole rows pushed sideways in bands that come and go
	if (interference > 0.0) {
		float band = floor(uv.y * 38.0 + floor(t * 9.0) * 7.0);
		float on = step(1.0 - 0.45 * interference, hash(vec2(band, floor(t * 12.0))));
		uv.x += on * (hash(vec2(band, 3.1)) - 0.5) * 0.06 * interference;
		// coarse blocks, as a compressed stream starved of bits
		float blk = step(1.0 - 0.3 * interference, hash(floor(uv / (px * 16.0)) + floor(t * 6.0)));
		uv = mix(uv, (floor(uv / (px * 8.0)) + 0.5) * px * 8.0, blk);
	}
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 av = (uv - a_c) * vec2(aspect, 1.0);
	float ar = length(av);
	float lens_glow = 0.0;
	if (a_pull != 0.0) {
		// sampled from further out (and turned a little): everything slides in and winds round the point
		float k = a_pull;
		float pull = k > 0.0 ? 1.0 + 3.2 * k * exp(-ar / (0.10 + 0.25 * k)) : 1.0 + 0.6 * k * exp(-pow((ar + 0.35 * k) / 0.06, 2.0));
		float tw = 1.7 * max(k, 0.0) * exp(-ar / 0.16);
		vec2 v = av * pull;
		v = vec2(v.x * cos(tw) - v.y * sin(tw), v.x * sin(tw) + v.y * cos(tw));
		uv = a_c + v / vec2(aspect, 1.0);
		float re = a_lens * max(k, 0.0);
		lens_glow = max(k, 0.0) * exp(-pow((ar - re) / 0.0045, 2.0));
	}
	vec2 d = uv - 0.5;
	float r2 = dot(d * vec2(1.0, 0.75), d * vec2(1.0, 0.75));
	vec3 c = sample_at(uv, d, r2);
	if (a_pull > 0.0) {
		// the point itself: a hole of nothing, the thin bent light round its rim
		c *= smoothstep(0.002, max(0.004, 0.03 * a_pull), ar);
		c += vec3(0.55, 0.85, 1.6) * lens_glow * 1.6;
	}
	if (a_dark > 0.0 || a_edge > 0.0) {
		vec3 glow = vec3(0.0);
		if (a_edge > 0.0) {
			float e = abs(lum(uv + vec2(px.x, 0.0)) - lum(uv - vec2(px.x, 0.0))) + abs(lum(uv + vec2(0.0, px.y)) - lum(uv - vec2(0.0, px.y)));
			e = smoothstep(0.012, 0.14, e);
			vec2 w = a_wo + SCREEN_UV * a_ws;
			vec2 cell = floor(w / 120.0);
			float h = hash(cell + 0.37);
			float off_at = 0.62 * clamp(length(w - a_wc) / a_rmax, 0.0, 1.0) + 0.38 * h;
			float left = off_at - a_cut;
			float alive = step(0.0, left);
			float stut = left < 0.035 ? step(0.5, hash(cell + floor(t * 28.0))) * 2.2 : 1.0;
			glow = a_edge_col * e * a_edge * alive * stut;
		}
		c = c * (1.0 - 0.93 * clamp(a_dark, 0.0, 1.0)) + glow;
	}
	c *= 1.0 - vignette * smoothstep(0.05, 0.42, r2);
	vec3 s = pow(max(c, vec3(0.0)), vec3(1.0 / 2.2));
	if (feed > 0.0) {
		// the sensor's slow rolling band and a whisper of line structure
		float roll = smoothstep(0.0, 0.08, abs(fract(uv.y * 0.5 - t * 0.07) - 0.5) - 0.42);
		s *= 1.0 - 0.015 * feed * (1.0 - roll);
	}
	if (interference > 0.0) {
		float n = hash(floor(FRAGCOORD.xy * 0.5) + floor(t * 30.0) * 13.7);
		s = mix(s, vec3(n * 0.6), 0.22 * interference * step(0.55, hash(vec2(floor(uv.y * 90.0), floor(t * 20.0)))));
	}
	if (grain > 0.0) {
		float n = hash(floor(FRAGCOORD.xy) + floor(t * 24.0) * 17.31) - 0.5;
		s += n * grain * (0.6 + 0.4 * (1.0 - s.g));
	}
	if (a_inv > 0.0) {
		float inside = 1.0 - smoothstep(a_inv_r - 0.01, a_inv_r, ar);
		s = mix(s, vec3(1.0) - clamp(s, 0.0, 1.0) * vec3(1.0, 0.97, 0.9), inside * a_inv);
	}
	c = pow(max(s, vec3(0.0)), vec3(2.2));
	COLOR = vec4(c, 1.0);
}
