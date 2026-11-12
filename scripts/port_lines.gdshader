// The still port's lines keep their width on screen (scripts/port_mesh.gd): each vertex
// carries its stroke offset in screen px in UV; the camera's zoom turns it into world px.
// 无缝进出 (scripts/backdrop.gd veil): the shell the drone is going into is seen through a soft
// round hole round it, a thin light line where the plating is cut; hole_r < 0 leaves it whole.
shader_type canvas_item;

uniform float zoom = 1.0;
uniform float width_k = 1.0;   // 118 号: the port as far scenery seen from the berth draws its lines finer
uniform vec2 hole_c = vec2(0.0);
uniform float hole_r = -1.0;   // world px
uniform float hole_soft = 1.0; // world px
uniform float edge_w = 1.0;    // world px
uniform vec4 edge_col = vec4(0.86, 0.84, 0.78, 0.55);
varying vec2 wpos;

void vertex() {
	// our mesh's UVs carry a 1000 px mark; text drawn between the shapes has glyph UVs (0..1)
	if (UV.x > 100.0) {
		VERTEX += (UV - vec2(1000.0)) / zoom * width_k;
	}
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	if (hole_r >= 0.0) {
		float d = distance(wpos, hole_c);
		float keep = smoothstep(hole_r - hole_soft, hole_r, d);
		float edge = (1.0 - smoothstep(0.0, edge_w, abs(d - hole_r + edge_w))) * step(0.5, hole_r);
		COLOR.rgb = mix(COLOR.rgb, edge_col.rgb, edge * edge_col.a * step(0.02, COLOR.a));
		COLOR.a *= max(keep, edge * step(0.02, COLOR.a));
	}
}
