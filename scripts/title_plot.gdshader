shader_type canvas_item;
render_mode unshaded;

uniform vec4 clip_box;
uniform vec2 pointer;
uniform float hot = 0.0;
uniform float opening = 1.0;
uniform float clock = 0.0;
uniform float motion = 1.0;
varying vec2 canvas_point;

void vertex() {
	canvas_point = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 p = canvas_point;
	if (p.x < clip_box.x || p.y < clip_box.y || p.x > clip_box.z || p.y > clip_box.w) discard;
	float width = max(clip_box.z - clip_box.x, 1.0);
	float x = (p.x - clip_box.x) / width;
	float front = opening * 1.12 - 0.06;
	float reveal = 1.0 - smoothstep(front - 0.04, front, x);
	float head = exp(-abs(x - front + 0.025) * 100.0) * (1.0 - step(0.999, opening));
	float sweep_x = fract(clock * 0.075) * 1.3 - 0.15;
	float sweep = exp(-pow((x - sweep_x) * 28.0, 2.0)) * motion;
	float proximity = exp(-pow(distance(p, pointer) / (width * 0.14), 2.0)) * hot;
	vec4 base = COLOR;
	COLOR.rgb = mix(base.rgb, vec3(1.0, 0.39, 0.13), proximity * 0.65 + head * 0.6);
	COLOR.a = min(1.0, base.a * (0.85 + sweep * 1.5 + proximity * 2.4) + head * 0.55) * reveal;
}
