extends RefCounted
# Cheap stand-ins for the draw calls that are dear in Godot 4's renderer (60 FPS work 2026-10-27,
# measured on the GTX 1080 with D3D12, tests/_draw_bench.gd): every draw_circle, draw_arc,
# draw_colored_polygon and antialiased draw_polyline makes a vertex buffer of its own, 14-47 µs a
# call, where a line, a primitive of up to four points or a mesh already built is 0.2-0.3 µs. The
# HUD, the drone and the overlays drawn again every frame used them by the dozen.
#   circle: one unit disc mesh, placed and scaled (the 2D MSAA smooths its edge)
#   arc: the unit arc's points kept per point count and sweep, placed, drawn as one multiline;
#        an arc too tight for its width (segments shorter than twice it) a band mesh, kept per shape
#   poly: up to four corners one primitive; a small outline its triangles as primitives
#   polyline: its segments as one multiline, squared off at the ends
# Anything that is not a real CanvasItem (CanvasBatch, PortMesh: recorders with the same calls)
# is passed the call as it was. A thick arc or line keeps the engine's own call: segments would
# show their joints.

const THICK := 2.6          # px: an arc or line wider than this is left to the engine
# what the engine's antialiasing feather adds to how thick a line looks, measured side by side
# (tests/_fast_draw_shot.gd, 2026-10-27): draw_arc and draw_polyline about a unit, an unfilled
# draw_circle less
const AA_W := 0.0
const AA_RING := 0.0
const MAX_TRI := 16         # corners: a larger outline is left to the engine (fewer, bigger calls)

static var _disc: ArrayMesh
static var _bands := {}     # Vector3i(points, sweep, inner radius in 1/1024) -> band mesh
static var _arcs := {}      # Vector2i(points, sweep in 1/4096 turns) -> segment pairs on the unit circle


static func _disc_mesh() -> ArrayMesh:
	if _disc == null:
		var v := PackedVector2Array([Vector2.ZERO])
		var ix := PackedInt32Array()
		var n := 64
		for i in n + 1:
			v.append(Vector2.from_angle(TAU * i / n))
		for i in n:
			ix.append_array([0, i + 1, i + 2])
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = v
		a[Mesh.ARRAY_INDEX] = ix
		_disc = ArrayMesh.new()
		_disc.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	return _disc


static func circle(ci, c: Vector2, r: float, col: Color, filled: bool = true, w: float = -1.0, aa: bool = false) -> void:
	if not ci is CanvasItem:
		ci.draw_circle(c, r, col, filled, w, aa)
		return
	if not filled:
		_arc(ci, c, r, 0.0, TAU, 64, col, w, aa, AA_RING)
		return
	if r <= 0.0:
		return
	ci.draw_mesh(_disc_mesh(), null, Transform2D(0.0, Vector2(r, r), 0.0, c), col)


static func arc(ci, c: Vector2, r: float, a0: float, a1: float, n: int, col: Color, w: float = -1.0, aa: bool = false) -> void:
	_arc(ci, c, r, a0, a1, n, col, w, aa, AA_W)


static func _arc(ci, c: Vector2, r: float, a0: float, a1: float, n: int, col: Color, w: float, aa: bool, feather: float) -> void:
	if not ci is CanvasItem or w > THICK or w <= 0.0 or n < 2:
		ci.draw_arc(c, r, a0, a1, n, col, w, aa)
		return
	var sweep := clampi(roundi((a1 - a0) / TAU * 4096.0), -4096, 4096)
	if sweep == 0:
		return
	var lw := w + (feather if aa else 0.0)
	# short segments next to the line's width would show as teeth: a band of triangles instead
	if lw > r * absf(sweep / 4096.0 * TAU) / (n - 1) * 0.5:
		var ro := r + lw * 0.5
		var q := clampi(roundi(maxf(0.0, r - lw * 0.5) / ro * 1024.0), 0, 1023)
		ci.draw_mesh(_band(n, sweep, q), null, Transform2D(a0, Vector2(ro, ro), 0.0, c), col)
		return
	var key := Vector2i(n, sweep)
	var segs: PackedVector2Array = _arcs.get(key, PackedVector2Array())
	if segs.is_empty():
		var s := sweep / 4096.0 * TAU
		var prev := Vector2.RIGHT
		for i in range(1, n):
			var p := Vector2.from_angle(s * i / (n - 1))
			segs.append(prev)
			segs.append(p)
			prev = p
		if _arcs.size() > 2048:
			_arcs.clear()
		_arcs[key] = segs
	ci.draw_multiline(Transform2D(a0, Vector2(r, r), 0.0, c) * segs, col, lw)


# an arc's band on the unit circle: n points over the sweep (1/4096 turns), inner edge at q/1024
static func _band(n: int, sweep: int, q: int) -> ArrayMesh:
	var key := Vector3i(n, sweep, q)
	var m: ArrayMesh = _bands.get(key)
	if m != null:
		return m
	var v := PackedVector2Array()
	var ix := PackedInt32Array()
	var s := sweep / 4096.0 * TAU
	var ri := q / 1024.0
	for i in n:
		var d := Vector2.from_angle(s * i / (n - 1))
		v.append(d)
		v.append(d * ri)
		if i > 0:
			var k := i * 2
			ix.append_array([k - 2, k - 1, k, k - 1, k + 1, k])
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = v
	a[Mesh.ARRAY_INDEX] = ix
	m = ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	if _bands.size() > 1024:
		_bands.clear()
	_bands[key] = m
	return m


static func poly(ci, pts: PackedVector2Array, col: Color, uvs: PackedVector2Array = PackedVector2Array(), tex: Texture2D = null) -> void:
	var n := pts.size()
	if not ci is CanvasItem or n > MAX_TRI or not uvs.is_empty() or tex != null:
		ci.draw_colored_polygon(pts, col, uvs, tex)
		return
	if n < 3:
		return
	if n == 3 or n == 4 and _convex4(pts):
		ci.draw_primitive(pts, PackedColorArray([col]), PackedVector2Array())
		return
	var ix := Geometry2D.triangulate_polygon(pts)
	var one := PackedColorArray([col])
	var none := PackedVector2Array()
	for k in range(0, ix.size(), 3):
		ci.draw_primitive(PackedVector2Array([pts[ix[k]], pts[ix[k + 1]], pts[ix[k + 2]]]), one, none)


static func _convex4(p: PackedVector2Array) -> bool:
	var s := 0.0
	for i in 4:
		var c := (p[(i + 1) % 4] - p[i]).cross(p[(i + 2) % 4] - p[(i + 1) % 4])
		if c != 0.0:
			if s == 0.0:
				s = signf(c)
			elif signf(c) != s:
				return false
	return true


static func polyline(ci, pts: PackedVector2Array, col: Color, w: float = -1.0, aa: bool = false) -> void:
	if not ci is CanvasItem or w > THICK or w <= 0.0 or pts.size() < 2:
		ci.draw_polyline(pts, col, w, aa)
		return
	# square ends half the width long, so a corner is not left notched
	var segs := PackedVector2Array()
	segs.resize((pts.size() - 1) * 2)
	var lw := w + (AA_W if aa else 0.0)
	var h := lw * 0.5
	for i in pts.size() - 1:
		var d := (pts[i + 1] - pts[i]).normalized() * h
		segs[i * 2] = pts[i] - d
		segs[i * 2 + 1] = pts[i + 1] + d
	ci.draw_multiline(segs, col, lw)
