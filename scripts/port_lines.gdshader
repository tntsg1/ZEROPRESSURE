// The still port's lines keep their width on screen (scripts/port_mesh.gd): each vertex
// carries its stroke offset in screen px in UV; the camera's zoom turns it into world px.
shader_type canvas_item;

uniform float zoom = 1.0;
uniform float width_k = 1.0;   // 118 号: the port as far scenery seen from the berth draws its lines finer

void vertex() {
	// our mesh's UVs carry a 1000 px mark; text drawn between the shapes has glyph UVs (0..1)
	if (UV.x > 100.0) {
		VERTEX += (UV - vec2(1000.0)) / zoom * width_k;
	}
}
