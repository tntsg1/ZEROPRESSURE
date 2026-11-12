// AX-40 逆火 · the annihilation's particle spectrum and the ship's glowing ghost (scripts/annihilation.gd).
// One mesh baked once, played back here: every vertex carries when the track's tip passes it
// (CUSTOM0.x), what it is (CUSTOM0.y: 0 e+, 1 e-, 2 pion/muon, 3 the ship's ghost), a parameter
// (CUSTOM0.z: a track's fade time, a ghost edge's moment it goes out) and which side of the stroke
// it is on (CUSTOM0.w: 0 or 1). UV is the stroke's half-width offset in screen px, so the lines
// keep their width on screen while the camera pulls back. Drawn twice: the thin line and a wide
// faint halo (halo = 1) — this layer sits above the post pass and the engine's glow.
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float T = 0.0;
uniform float zoom = 1.0;
uniform float fade = 1.0;
uniform float halo = 0.0;
uniform float width_k = 1.0;
uniform float gain = 1.0;
varying vec4 cu;

float hash(float x) {
	return fract(sin(x * 91.3458) * 47453.5453);
}

void vertex() {
	cu = CUSTOM0;
	VERTEX += UV * width_k / zoom;
}

void fragment() {
	float age = T - cu.x;
	if (age < 0.0) {
		discard;
	}
	float across = abs(cu.w * 2.0 - 1.0);
	float prof = halo > 0.5 ? (1.0 - across) * (1.0 - across) : 1.0 - smoothstep(0.35, 1.0, across);
	float a;
	if (cu.y < 2.5) {
		// the tip: a white-hot bead running along the track, then the trail cooling to its own colour
		float head = exp(-age / 0.05);
		float life = exp(-age / max(cu.z, 0.05));
		a = 0.1 + 0.6 * life + 2.4 * head;
		COLOR.rgb = mix(COLOR.rgb, vec3(1.0), clamp(head * 1.4, 0.0, 1.0));
	} else {
		// the ship's ghost: lit white by the shell, cooling to a cold line, a stutter, then out
		float flash = exp(-age / 0.1);
		float left = cu.z - T;
		float on = step(0.0, left);
		float stut = left < 0.22 ? step(0.45, hash(floor(T * 30.0) + cu.z * 13.0)) : 1.0;
		a = (0.42 + 3.2 * flash + 1.4 * (1.0 - smoothstep(0.0, 0.22, left)) * stut) * on * stut;
		COLOR.rgb = mix(COLOR.rgb, vec3(1.0), clamp(flash * 1.5, 0.0, 1.0));
	}
	COLOR = vec4(COLOR.rgb * a * prof * fade * gain, 1.0);
}
