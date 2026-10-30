shader_type canvas_item;
uniform float clock_time = 0.0;
uniform vec4 liquid_color : source_color;
uniform vec4 highlight_color : source_color;
uniform vec4 ice_color : source_color;

vec2 shape(float index, float feature, vec4 data) {
	float r = data.x;
	if (data.w >= 24.0) {
		float k = feature == 2.0 ? clamp(index, 0.0, 1.0) * 3.0 : (feature == 3.0 ? 1.0 + clamp(index, 0.0, 1.0) * 4.0 : clamp(index, 0.0, 7.0));
		float a = k * TAU / 7.0 + data.z;
		return vec2(cos(a), sin(a)) * r * (0.9 + 0.12 * sin(a * 3.0 + data.z));
	}
	float n = r < 4.0 ? 10.0 : (r < 10.0 ? 16.0 : 24.0);
	float state = data.w >= 8.0 ? data.w - 16.0 : data.w;
	if (feature == 2.0) {
		float a = (1.05 + 0.5 * clamp(index, 0.0, 5.0) / 5.0) * PI;
		return (vec2(-0.28) + vec2(cos(a), sin(a)) * 0.42) * r;
	}
	if (feature == 3.0) {
		float a = clamp(index, 0.0, n - 1.0) * TAU / (n - 1.0);
		return vec2(cos(a), sin(a)) * r * 0.78;
	}
	float a = clamp(index, 0.0, n) * TAU / n;
	float amp = r < 2.5 ? 0.0 : clamp(0.02 + r * 0.004, 0.0, 0.12) * exp(-data.y * 0.15) + (r > 6.0 ? 0.03 : 0.0);
	float freq = 9.0 / sqrt(max(r, 1.0));
	float rr = r * (1.0 + amp * sin(2.0 * a + clock_time * freq + data.z) + amp * 0.5 * sin(3.0 * a - clock_time * freq * 1.4 + data.z * 2.0));
	vec2 p = index < 0.0 ? vec2(0.0) : vec2(cos(a), sin(a)) * rr;
	if (state > -3.0) {
		vec2 normal = vec2(cos(state - 4.0), sin(state - 4.0));
		vec2 tangent = vec2(-normal.y, normal.x);
		p = tangent * dot(p, tangent) * 1.5 + normal * (dot(p, normal) * 0.45 + r * 0.1);
	}
	return p;
}

vec2 edge(vec2 next, vec2 prev) {
	vec2 bisector = prev * length(next) - next * length(prev);
	if (length(bisector) > 0.00001) bisector = normalize(bisector);
	float sine = sin(atan(bisector.x * prev.y - bisector.y * prev.x, dot(bisector, prev)));
	if (abs(sine) > 0.00001 && distance(next, prev) > 0.00001) {
		return bisector * clamp(1.0 / sine, -3.0, 3.0);
	}
	return vec2(next.y, -next.x);
}

void vertex() {
	vec4 data = INSTANCE_CUSTOM;
	bool ice = data.w >= 24.0;
	float feature = VERTEX.y;
	float n = data.x < 4.0 ? 10.0 : (data.x < 10.0 ? 16.0 : 24.0);
	float last = ice ? (feature >= 2.0 ? 1.0 : 7.0) : (feature == 2.0 ? 5.0 : (feature == 3.0 ? n - 1.0 : n));
	float index = min(VERTEX.x, last);
	vec2 pos = shape(index, feature, data);
	bool hidden_feature = ice ? feature == 0.0 : ((feature == 0.0 && data.x <= 2.5) || (feature >= 2.0 && data.x < 3.0) || (feature == 3.0 && data.w < 8.0));
	if (hidden_feature) {
		VERTEX = vec2(0.0);
	} else {
		if (feature != 0.0) {
			bool loop = feature != 2.0 && !(ice && feature == 3.0);
			float before = index == 0.0 ? (loop ? last - 1.0 : 0.0) : index - 1.0;
			float after = index == last ? (loop ? 1.0 : last) : index + 1.0;
			vec2 prev = pos - shape(before, feature, data);
			vec2 next = shape(after, feature, data) - pos;
			if (length(prev) > 0.00001) prev = normalize(prev);
			if (length(next) > 0.00001) next = normalize(next);
			vec2 offset;
			if (!loop && index == 0.0) offset = vec2(next.y, -next.x);
			else if (!loop && index == last) offset = vec2(prev.y, -prev.x);
			else offset = edge(next, prev);
			pos += offset * UV.x * (feature == 1.0 ? (ice ? 1.1 : 1.2) : 1.0) * 0.5;
		}
		VERTEX = pos;
	}
	COLOR = feature == 2.0 ? highlight_color : liquid_color;
	if (feature == 0.0) COLOR.a = 0.07;
	else if (feature == 3.0) COLOR.a = 0.3;
	if (ice) {
		COLOR = ice_color;
		COLOR.a = feature == 1.0 ? 0.7 : (feature == 2.0 ? 0.25 : 0.2);
	}
	UV = vec2(0.0);
}
