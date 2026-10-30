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

float hash(vec2 p) {
	p = fract(p * vec2(443.897, 441.423));
	p += dot(p, p.yx + 19.19);
	return fract((p.x + p.y) * p.x);
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
	vec2 d = uv - 0.5;
	float r2 = dot(d * vec2(1.0, 0.75), d * vec2(1.0, 0.75));
	vec3 c = sample_at(uv, d, r2);
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
	c = pow(max(s, vec3(0.0)), vec3(2.2));
	COLOR = vec4(c, 1.0);
}
