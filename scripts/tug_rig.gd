extends RefCounted
# The company's own tug out on a tow, a push or a flight home (user 2026-11-05, the third time:
# "这尾部怎么不是拖船，还是这个推进器啊？" — every hulk brought in, pushed between berths or into the
# dock is moved by the real tug, not a block of a thruster). The tug is the tug station's own mesh,
# the one berthed on its deck (scripts/tug_station_art.gd), with its aft pod fitted, side on: nose +x
# when face = 1, -x when face = -1 (in between it is yawing round, seen edge on). Tug-local metres,
# origin the skid line under its middle, as on the deck. Its burns follow its real acceleration
# (m/s², world; strict inertia): along the nose, the main drive aft to speed up nose first, the bow
# retros to slow (or back); across, the RCS quads — the dorsal ones blow up to go down, the ventral
# ones blow down to go up. Meshes are built once; the tow line is one triangle array a frame.

const Art = preload("res://scripts/tug_station_art.gd")
const MeshPen = preload("res://scripts/mesh_pen.gd")
const W = preload("res://scripts/tug_works.gd")
const FastDraw = preload("res://scripts/fast_draw.gd")

const PLATE := 6.25                    # the push plate's face
const PAD := 6.55                      # the fenders' face, unloaded
const AXIS := -2.3                     # the thrust line (the pod's bell, the push plate's middle)
const BELL := Vector2(-7.85, -2.3)     # the main drive's exit
const HITCH := Vector2(-1.9, -5.45)    # the tow winch's drum: where the line or the arm leaves the tug
const POD := Vector2(-5.2, -3.65)      # the aft pod's lifting point (tug_works AFT, POD_ON_TUG)
const A_REF := 22.0                    # m/s²: a full burn
const FACE2 := Color(0.15, 0.158, 0.172)

static var _art
static var _tug_mesh: ArrayMesh
static var _pod_mesh: ArrayMesh
static var _track := {}                # key -> [p (px), v (px/s), ms] for a tug whose path is not a function


static func _meshes() -> void:
	if _tug_mesh != null:
		return
	_art = Art.new()
	var pen := MeshPen.new()
	_art._tug(pen, false)
	_tug_mesh = pen.mesh()
	pen = MeshPen.new()
	_art._pod(pen, false)
	_pod_mesh = pen.mesh()


# a point on the tug (local m) in world px
static func pt(at: Vector2, face: float, M: float, v: Vector2) -> Vector2:
	return at + Vector2(v.x * face, v.y) * M


# where the tug's skids are (px) for its fenders to bear on a face at `contact` (px), nose toward it
static func push_at(contact: Vector2, face: float, M: float, squeeze := 0.0) -> Vector2:
	return contact - Vector2((PAD - 0.14 * squeeze) * face, AXIS) * M


# the acceleration (m/s²) of a tug whose path is only known frame by frame (scripts/berth_build.gd)
static func track(key: String, p: Vector2, M: float) -> Vector2:
	var now := Time.get_ticks_msec()
	var acc := Vector2.ZERO
	if _track.has(key):
		var e: Array = _track[key]
		var dt := float(now - int(e[2])) / 1000.0
		if dt > 0.2:
			_track[key] = [p, Vector2.ZERO, now, Vector2.ZERO]
			return Vector2.ZERO
		if dt < 0.004:
			return e[3]
		var v: Vector2 = (p - (e[0] as Vector2)) / dt
		acc = (e[3] as Vector2).lerp((v - (e[1] as Vector2)) / dt / M, 0.35)
		_track[key] = [p, v, now, acc]
	else:
		_track[key] = [p, Vector2.ZERO, now, Vector2.ZERO]
	return acc


# the tug. o: mod (Color), squeeze 0…1 (the fenders under a push), hire (a contractor's tug: the
# same build, its own band), name + font (the plate, with labels on), seed (its flicker)
static func draw(ci, at: Vector2, face: float, M: float, acc: Vector2, t: float, o := {}) -> void:
	_meshes()
	var mod: Color = o.get("mod", Color.WHITE)
	var f := signf(face) if absf(face) > 0.01 else 1.0
	_burns(ci, at, face, M, acc, t + float(o.get("seed", 0.0)), mod.a)
	ci.draw_mesh(_tug_mesh, null, Transform2D(0.0, Vector2(M * face, M), 0.0, at), mod)
	ci.draw_mesh(_pod_mesh, null, Transform2D(0.0, Vector2(-M * face * W.POD_K, M * W.POD_K), 0.0, pt(at, face, M, POD)), mod)
	if bool(o.get("hire", false)):
		# a hired tug: the yard's band along its back in the contractor's white and heat
		for k in 4:
			var x0 := -4.6 + k * 2.3
			FastDraw.poly(ci, PackedVector2Array([pt(at, face, M, Vector2(x0, -4.2)), pt(at, face, M, Vector2(x0 + 1.15, -4.2)), pt(at, face, M, Vector2(x0 + 0.75, -3.7)), pt(at, face, M, Vector2(x0 - 0.4, -3.7))]), Pal.heat(0.7 * mod.a, 1.0) if k % 2 == 0 else Pal.ink(0.75 * mod.a))
	# the fenders, squeezed flat against what it pushes
	var sq := clampf(float(o.get("squeeze", 0.0)), 0.0, 1.0)
	var wf := 0.3 * (1.0 - 0.45 * sq)
	for k in 3:
		var y0 := -3.7 + k * 0.95 - 0.06 * sq
		var h := 0.7 + 0.12 * sq
		var q := PackedVector2Array([pt(at, face, M, Vector2(PLATE, y0)), pt(at, face, M, Vector2(PLATE + wf, y0 + 0.12)), pt(at, face, M, Vector2(PLATE + wf, y0 + h - 0.12)), pt(at, face, M, Vector2(PLATE, y0 + h))])
		FastDraw.poly(ci, q, Color(0.03, 0.03, 0.035, mod.a))
		ci.draw_line(q[1], q[2], Pal.ink(0.35 * mod.a), maxf(1.0, 0.05 * M))
	# nav lights (red to port aft, green at the bow), as berthed
	var blink := 0.5 + 0.5 * sin(t * 3.0 + float(o.get("seed", 0.0)) * 1.7)
	FastDraw.circle(ci, pt(at, face, M, Vector2(-5.5, -4.0)), 0.13 * M, Color(1.0, 0.25, 0.2, blink * mod.a))
	FastDraw.circle(ci, pt(at, face, M, Vector2(5.6, -3.4)), 0.13 * M, Color(0.3, 1.0, 0.45, blink * mod.a))
	if Pal.labels and o.has("name") and o.get("font") != null:
		ci.draw_string(o.font, pt(at, f, M, Vector2(-1.8 if f > 0.0 else 1.8, -2.15)) - Vector2(0.0 if f > 0.0 else 2.0 * M, 0.0), str(o.name), HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.62 * M), Pal.ink(0.85 * mod.a))


# a plume: base b (px), out along dir for ln px, half width hw at the base
static func _plume(ci, b: Vector2, dir: Vector2, ln: float, hw: float, col: Color) -> void:
	var s := dir.orthogonal() * hw
	FastDraw.poly(ci, PackedVector2Array([b + s, b + dir * ln, b - s]), col)


static func _burns(ci, at: Vector2, face: float, M: float, acc: Vector2, t: float, a: float) -> void:
	var f := signf(face) if absf(face) > 0.01 else 1.0
	var nose := Vector2(f, 0.0)
	var along := acc.x * f
	var fl := 0.78 + 0.22 * sin(t * 47.0)
	var fl2 := 0.8 + 0.2 * sin(t * 61.0 + 1.3)
	var main := clampf(along / A_REF, 0.0, 1.0)
	var retro := clampf(-along / A_REF, 0.0, 1.0)
	if main > 0.03:
		var b := pt(at, face, M, BELL + Vector2(0.1, 0.0))
		var ln := (1.4 + 5.2 * main) * fl * M
		_plume(ci, b, -nose, ln, 0.6 * M, Pal.heat(0.5 * main * a, 1.9))
		_plume(ci, b, -nose, ln * 0.55, 0.36 * M, Pal.heat(0.8 * main * a, 2.4))
		_plume(ci, b, -nose, ln * 0.25, 0.18 * M, Color(1.0, 0.95, 0.85, 0.9 * main * a))
		FastDraw.circle(ci, b, 0.75 * M, Pal.heat(0.18 * main * a, 1.6))
	if retro > 0.03:
		for c in [Vector2(4.0, -4.6), Vector2(4.3, -0.55)]:
			var b := pt(at, face, M, c + Vector2(0.6, 0.0))
			_plume(ci, b, nose, (0.5 + 2.6 * retro) * fl2 * M, 0.17 * M, Pal.tint(Pal.AIR, 0.85 * retro * a, 1.6))
			_plume(ci, b, nose, (0.25 + 1.0 * retro) * fl2 * M, 0.08 * M, Color(1.0, 1.0, 1.0, 0.8 * retro * a))
	var up := clampf(-acc.y / A_REF, 0.0, 1.0)
	var dn := clampf(acc.y / A_REF, 0.0, 1.0)
	for c in [Vector2(-4.8, -0.55), Vector2(4.3, -0.55)]:
		if up > 0.03:
			var b := pt(at, face, M, c + Vector2(0.0, 0.2))
			_plume(ci, b, Vector2.DOWN, (0.5 + 2.4 * up) * fl2 * M, 0.17 * M, Pal.tint(Pal.AIR, 0.85 * up * a, 1.6))
	for c in [Vector2(-4.6, -4.6), Vector2(4.0, -4.6)]:
		if dn > 0.03:
			var b := pt(at, face, M, c + Vector2(0.0, -0.2))
			_plume(ci, b, Vector2.UP, (0.5 + 2.4 * dn) * fl2 * M, 0.17 * M, Pal.tint(Pal.AIR, 0.85 * dn * a, 1.6))


# ---------------------------------------------------------------- the line and the arm

# a strip of quads along pts (px) of width w, one triangle array
static func _strip(ci, pts: PackedVector2Array, w: float, col: Color) -> void:
	var n := pts.size()
	if n < 2:
		return
	var v := PackedVector2Array()
	var c := PackedColorArray()
	var ix := PackedInt32Array()
	for i in n:
		var d: Vector2 = (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)])
		var nn := d.orthogonal().normalized() * w * 0.5 if d.length_squared() > 1e-8 else Vector2(0, w * 0.5)
		v.append(pts[i] + nn)
		v.append(pts[i] - nn)
		c.append(col)
		c.append(col)
		if i > 0:
			var k := i * 2
			ix.append_array([k - 2, k - 1, k, k - 1, k + 1, k])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), ix, v, c)


# the tow line from the tug's drum a to its shackle on the hulk b (px): taut it is straight; slack
# (0…1) it lies loose in a long curve to one side (no weight out here, only what it carries along)
static func cable(ci, a: Vector2, b: Vector2, slack: float, M: float, zoom: float, t: float) -> void:
	var d := b - a
	var L := d.length()
	if L < 1.0:
		return
	var side := d.orthogonal() / L
	var bow := clampf(slack, 0.0, 1.0) * L * 0.1
	var pts := PackedVector2Array()
	var n := 16 if bow > 0.5 else 2
	for i in n + 1:
		var u := float(i) / n
		var off := bow * 4.0 * u * (1.0 - u) + bow * 0.35 * sin(u * TAU) * sin(t * 1.7)
		pts.append(a.lerp(b, u) + side * off)
	var w := maxf(0.16 * M, 1.8 / maxf(zoom, 0.05))
	_strip(ci, pts, w * 1.9, Color(0.02, 0.022, 0.026))
	_strip(ci, pts, w, Pal.ink(0.82 if slack < 0.05 else 0.6))
	FastDraw.circle(ci, b, 0.28 * M, Pal.ink(0.75))
	FastDraw.circle(ci, a, 0.22 * M, Pal.heat(0.7, 1.2))


# the tow arm locked: a box boom between two swivels, its clamp head on the hulk at b (px), the
# sleeve where it telescopes; extension 0…1 shows how far the inner tube runs out
static func arm(ci, a: Vector2, b: Vector2, M: float, zoom: float) -> void:
	var d := b - a
	var L := d.length()
	if L < 1.0:
		return
	var u := d / L
	var nn := u.orthogonal()
	var w := 0.42 * M
	var lw := maxf(1.0, 1.2 / maxf(zoom, 0.05))
	var outer := a.lerp(b, 0.55)
	_strip(ci, PackedVector2Array([a, outer]), w, FACE2)
	_strip(ci, PackedVector2Array([outer, b - u * 0.5 * M]), w * 0.7, Color(0.2, 0.21, 0.225))
	for s in [-1.0, 1.0]:
		ci.draw_line(a + nn * w * 0.5 * s, outer + nn * w * 0.5 * s, Pal.ink(0.7), lw)
		ci.draw_line(outer + nn * w * 0.35 * s, b - u * 0.5 * M + nn * w * 0.35 * s, Pal.ink(0.55), lw)
	# the sleeve, the hazard band on the inner tube
	_strip(ci, PackedVector2Array([outer - u * 0.35 * M, outer + u * 0.1 * M]), w * 1.25, Color(0.11, 0.115, 0.125))
	_strip(ci, PackedVector2Array([outer + u * 0.6 * M, outer + u * 1.0 * M]), w * 0.7, Pal.heat(0.6, 1.0))
	# the swivels and the clamp head
	FastDraw.circle(ci, a, 0.36 * M, Color(0.1, 0.1, 0.11))
	FastDraw.circle(ci, a, 0.16 * M, Pal.ink(0.7))
	var head := b - u * 0.5 * M
	FastDraw.poly(ci, PackedVector2Array([head + nn * 0.9 * M, b + nn * 0.9 * M, b - nn * 0.9 * M, head - nn * 0.9 * M]), FACE2)
	ci.draw_line(b + nn * 0.9 * M, b - nn * 0.9 * M, Pal.tint(Pal.FLUID, 0.85, 1.1), maxf(lw, 0.14 * M))
	FastDraw.circle(ci, head, 0.2 * M, Pal.ink(0.7))
