extends RefCounted
# 97 号 (user 2026-10-28: "把它安装到接驳车和铁轨上" — the tug station's way of drawing and moving
# put on the shuttle and its rails): the rails as track — sleepers, tie plates and spikes, two
# running rails, the overhead line on its masts, the switches' points and their machines, the
# stations' platforms and buffer stops — built once into meshes in the port's own frame (the
# port centre at the origin), so the port moving with a new ship moves them for nothing and only
# the berth's lift rebuilds them. Each stroke keeps its width in metres plus a pixel in UV
# (scripts/port_lines.gdshader), so at any zoom a rail is never thinner than a pixel. The train's
# parts — the two car bodies and their roofs, bogies, doors — are meshes in
# their own metres (scripts/mesh_pen.gd), placed each frame with one draw_mesh apiece.

const MeshPen = preload("res://scripts/mesh_pen.gd")

const GAUGE := 1.1            # m between the running rails' centres
const SLEEPER := 0.7          # m from one sleeper to the next
const BLADE := 3.0            # m: the switch points' length
const CAR_L := 3.2
const CAR_W := 1.6
const DOORS := [-0.85, 0.55]  # doorways along a car (its cab towards +x)
const DOOR_W := 0.5

# plate steel, its lit side, the dark of machinery, glass (as scripts/tug_station_art.gd)
const FACE := Color(0.118, 0.124, 0.136)
const FACE2 := Color(0.17, 0.178, 0.192)
const DARK := Color(0.06, 0.064, 0.072)
const VOID := Color(0.025, 0.027, 0.031)


# ---------------------------------------------------------------- strokes with a pixel in UV

class Pen:
	const MARK := Vector2(1000.0, 1000.0)
	var p := PackedVector2Array()
	var c := PackedColorArray()
	var u := PackedVector2Array()
	var ix := PackedInt32Array()
	var m := 48.0

	func quad(a: Vector2, b: Vector2, cc: Vector2, d: Vector2, col: Color, ua := Vector2.ZERO, ub := Vector2.ZERO, uc := Vector2.ZERO, ud := Vector2.ZERO) -> void:
		var n := p.size()
		p.append_array([a, b, cc, d])
		c.append_array([col, col, col, col])
		u.append_array([ua + MARK, ub + MARK, uc + MARK, ud + MARK])
		ix.append_array([n, n + 1, n + 2, n, n + 2, n + 3])

	# a stroke wm metres wide plus px pixels
	func seg(a: Vector2, b: Vector2, col: Color, wm: float, px := 0.0) -> void:
		var d := b - a
		if d.length_squared() < 1e-8:
			return
		var nn := d.normalized().orthogonal()
		var hw := nn * wm * m * 0.5
		var hu := nn * px * 0.5
		quad(a + hw, b + hw, b - hw, a - hw, col, hu, hu, -hu, -hu)

	func line(pts: PackedVector2Array, col: Color, wm: float, px := 0.0) -> void:
		for i in range(1, pts.size()):
			seg(pts[i - 1], pts[i], col, wm, px)

	# a small square mark rm metres across, never under px pixels
	func dot(at: Vector2, rm: float, col: Color, px := 0.0, ang := 0.0) -> void:
		var a := Vector2.from_angle(ang)
		var b := a.orthogonal()
		var h := rm * m * 0.5
		var q := px * 0.5
		quad(at + (-a - b) * h, at + (a - b) * h, at + (a + b) * h, at + (-a + b) * h, col, (-a - b) * q, (a - b) * q, (a + b) * q, (-a + b) * q)

	func disc(at: Vector2, rm: float, col: Color, n := 8) -> void:
		var base := p.size()
		p.append(at)
		c.append(col)
		u.append(MARK)
		for k in n:
			p.append(at + Vector2.from_angle(TAU * k / n) * rm * m)
			c.append(col)
			u.append(MARK + Vector2.from_angle(TAU * k / n) * 0.5)
		for k in n:
			ix.append_array([base, base + 1 + k, base + 1 + (k + 1) % n])

	func rect(centre: Vector2, along: Vector2, len_m: float, wid_m: float, col: Color) -> void:
		var a := along * len_m * m * 0.5
		var b := along.orthogonal() * wid_m * m * 0.5
		quad(centre - a - b, centre + a - b, centre + a + b, centre - a + b, col)

	func mesh() -> ArrayMesh:
		var out := ArrayMesh.new()
		if p.is_empty():
			return out
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = p
		arr[Mesh.ARRAY_COLOR] = c
		arr[Mesh.ARRAY_TEX_UV] = u
		arr[Mesh.ARRAY_INDEX] = ix
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return out


# ---------------------------------------------------------------- polylines

static func length(pts: Array) -> float:
	var s := 0.0
	for i in range(1, pts.size()):
		s += (pts[i - 1] as Vector2).distance_to(pts[i])
	return s


# the point and the direction at arc length s along a polyline
static func at_len(pts: Array, s: float) -> Array:
	var left := s
	for i in range(1, pts.size()):
		var a: Vector2 = pts[i - 1]
		var b: Vector2 = pts[i]
		var d := a.distance_to(b)
		if d >= left or i == pts.size() - 1:
			var k := clampf(left / maxf(d, 1e-4), 0.0, 1.0)
			return [a.lerp(b, k), (b - a).normalized()]
		left -= d
	return [pts[0] if not pts.is_empty() else Vector2.ZERO, Vector2.RIGHT]


# points every `step` px along a polyline from `start`, each with its direction, in one pass
static func walk(pts: Array, start: float, step: float) -> Array:
	var out: Array = []
	var want := start
	var run := 0.0
	for i in range(1, pts.size()):
		var a: Vector2 = pts[i - 1]
		var b: Vector2 = pts[i]
		var d := a.distance_to(b)
		if d < 1e-6:
			continue
		var dir := (b - a) / d
		while want <= run + d + 1e-3:
			out.append([a + dir * (want - run), dir, want])
			want += step
		run += d
	return out


# the polyline again at even steps (a curve's corners would show in rails offset from it)
static func resample(pts: Array, step: float) -> Array:
	var total := length(pts)
	var n := maxi(1, int(ceil(total / step)))
	var out: Array = walk(pts, 0.0, total / n).map(func(e): return e[0])
	if out.size() < n + 1:
		out.append(pts[-1])
	return out


# a polyline offset sideways by d px, each point along the mean of its two segments' normals
static func offset(pts: Array, d: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := pts.size()
	for i in n:
		var a: Vector2 = pts[maxi(0, i - 1)]
		var b: Vector2 = pts[mini(n - 1, i + 1)]
		var nn := (b - a).normalized().orthogonal()
		out.append((pts[i] as Vector2) + nn * d)
	return out


# ---------------------------------------------------------------- the track (still, port frame)

# lines: [{pts (port frame px), "skip_a": m at the start without sleepers, "skip_b": … at the end}]
# switches: the toes (long timbers there); stations: [{at, d (along the track, away from the dead
# end), n (the platform's side), end (a dead end: buffer stop), post, sign}]
# The whole track is some 57 000 vertices, 30–50 ms of script in one go: a hitch where the port
# first shows and again when the berth lifts (user 2026-10-28: "改成分帧"). So it is built as a
# list of small jobs run a slice of a frame at a time (TrackJob.step), into meshes of at most
# CHUNK vertices each (one big mesh's upload was a slice by itself), drawn in order once all done.
static func track_job(lines: Array, switches: Array, stations: Array, m: float) -> TrackJob:
	var job := TrackJob.new()
	job.m = m
	job.pen.m = m
	var even: Array = []
	even.resize(lines.size())
	# each line at even steps and its offsets first, then the bed under everything, the sleepers,
	# the rails — each in runs of RUN segments or sleepers, so no one job takes long
	for li in lines.size():
		job.jobs.append(func(): even[li] = _prep(lines[li].pts, m))
	var runs: Array = []
	for li in lines.size():
		runs.append(int(length(lines[li].pts) / (0.5 * m)) + 3)
	for li in lines.size():
		for k0 in range(0, runs[li], RUN):
			job.jobs.append(func(): _bed(job.pen, even[li], k0, k0 + RUN))
	for li in lines.size():
		var n := int(length(lines[li].pts) / (SLEEPER * m)) + 2
		for k0 in range(0, n, RUN):
			job.jobs.append(func(): _sleepers(job.pen, even[li].pts, lines[li], switches, k0, mini(k0 + RUN, n), m))
	for li in lines.size():
		for k0 in range(0, runs[li], RUN):
			job.jobs.append(func(): _rails(job.pen, even[li], k0, k0 + RUN))
	for st in stations:
		job.jobs.append(func(): _station(job.pen, st, m))
	return job


const RUN := 30               # segments or sleepers a job draws


# a line at even half-metre steps, with the bed's edges and the two rails offset from it
static func _prep(pts: Array, m: float) -> Dictionary:
	var even := resample(pts, 0.5 * m)
	return {"pts": even, "e0": offset(even, 1.05 * m), "e1": offset(even, -1.05 * m), "r0": offset(even, GAUGE * 0.5 * m), "r1": offset(even, -GAUGE * 0.5 * m)}


# segments k0 … k1 of a polyline
static func _run(pen: Pen, pts, k0: int, k1: int, col: Color, wm: float, px: float) -> void:
	for i in range(k0 + 1, mini(k1 + 1, pts.size())):
		pen.seg(pts[i - 1], pts[i], col, wm, px)


class TrackJob:
	const CHUNK := 6000
	var jobs: Array = []
	var i := 0
	var m := 48.0
	var pen := Pen.new()
	var meshes: Array = []
	var slowest_us := 0     # the longest slice a frame gave it, job, mesh made (tests)
	var slowest_job_us := 0
	var slowest_cut_us := 0
	var total_us := 0

	func done() -> bool:
		return i >= jobs.size() and pen.p.is_empty()

	# run jobs for up to budget_us; true once every one has run and its meshes are made
	func step(budget_us: int) -> bool:
		var t0 := Time.get_ticks_usec()
		while i < jobs.size():
			var tj := Time.get_ticks_usec()
			(jobs[i] as Callable).call()
			slowest_job_us = maxi(slowest_job_us, Time.get_ticks_usec() - tj)
			i += 1
			if pen.p.size() >= CHUNK:
				_cut()
			if Time.get_ticks_usec() - t0 >= budget_us:
				break
		if i >= jobs.size() and not pen.p.is_empty():
			_cut()
		var took := Time.get_ticks_usec() - t0
		slowest_us = maxi(slowest_us, took)
		total_us += took
		return done()

	func _cut() -> void:
		var tc := Time.get_ticks_usec()
		meshes.append(pen.mesh())
		slowest_cut_us = maxi(slowest_cut_us, Time.get_ticks_usec() - tc)
		var nxt := Pen.new()
		nxt.m = m
		pen = nxt


static func _bed(pen: Pen, ln: Dictionary, k0: int, k1: int) -> void:
	_run(pen, ln.pts, k0, k1, Color(0.052, 0.056, 0.063, 0.85), 2.1, 0.0)
	_run(pen, ln.e0, k0, k1, Pal.ink(0.07), 0.03, 0.6)
	_run(pen, ln.e1, k0, k1, Pal.ink(0.07), 0.03, 0.6)


# sleepers k0 … k1 along a line: each on its tie plates with two spikes a rail, the long timbers
# under a switch
static func _sleepers(pen: Pen, pts: Array, ln: Dictionary, switches: Array, k0: int, k1: int, m: float) -> void:
	var sleeper := Color(0.15, 0.155, 0.165)
	var plate := Color(0.085, 0.09, 0.098)
	var spike := Pal.ink(0.34)
	var total := length(pts)
	var skip_a: float = float(ln.get("skip_a", 0.0)) * m
	var skip_b: float = float(ln.get("skip_b", 0.0)) * m
	var start := (0.35 + k0 * SLEEPER) * m
	var k := k0
	for ad in walk(pts, start, SLEEPER * m):
		if k >= k1:
			break
		var s := (0.35 + k * SLEEPER) * m
		k += 1
		if s < skip_a or s > total - skip_b:
			continue
		var q: Vector2 = ad[0]
		var dir: Vector2 = ad[1]
		var nn := dir.orthogonal()
		var long := false
		for sw in switches:
			if q.distance_to(sw) < (BLADE + 1.0) * m:
				long = true
				break
		var half: float = 1.45 if long else 0.95
		pen.seg(q - nn * half * m, q + nn * half * m, sleeper, 0.2, 0.5)
		for side: float in [-1.0, 1.0]:
			var rp := q + nn * side * GAUGE * 0.5 * m
			pen.dot(rp, 0.2, plate, 0.0, dir.angle())
			pen.dot(rp + nn * 0.08 * m - dir * 0.05 * m, 0.045, spike, 0.0)
			pen.dot(rp - nn * 0.08 * m + dir * 0.05 * m, 0.045, spike, 0.0)


static func _rails(pen: Pen, ln: Dictionary, k0: int, k1: int) -> void:
	for r in [ln.r0, ln.r1]:
		_run(pen, r, k0, k1, Color(0.09, 0.094, 0.104), 0.13, 0.4)
		_run(pen, r, k0, k1, Pal.ink(0.6), 0.055, 0.7)


# a stop: a platform beside the track, its yellow edge and tactile strip, the sign on its post,
# a buffer stop at a dead end
static func _station(pen: Pen, st: Dictionary, m: float) -> void:
	var d: Vector2 = st.d
	var n: Vector2 = st.n
	# (接驳站穿模修复: a stop's platform may sit along from its point, scripts/tram.gd PLATFORM_SHIFT)
	var at: Vector2 = (st.at as Vector2) + d * float(st.get("shift", 0.0)) * m
	var mid := at + n * 1.55 * m + d * 0.2 * m
	pen.rect(mid, d, 4.4, 1.1, FACE)
	var e0 := at + n * 1.0 * m - d * 2.0 * m
	var e1 := at + n * 1.0 * m + d * 2.4 * m
	pen.seg(e0, e1, Pal.heat(0.7, 0.9), 0.1, 0.6)
	pen.seg(e0 + n * 0.22 * m, e1 + n * 0.22 * m, Pal.ink(0.22), 0.08, 0.4)
	var k := 0.0
	while k < 4.3:
		var g0 := e0 + n * 0.45 * m + d * k * m
		pen.seg(g0, g0 + n * 0.6 * m, Pal.ink(0.06), 0.03, 0.3)
		k += 0.3
	pen.seg(e0 + n * 1.1 * m, e1 + n * 1.1 * m, Pal.ink(0.3), 0.04, 0.6)
	pen.seg(e0, e0 + n * 1.1 * m, Pal.ink(0.3), 0.04, 0.6)
	pen.seg(e1, e1 + n * 1.1 * m, Pal.ink(0.3), 0.04, 0.6)
	# the sign on its post: a dark plate, the line's colour along its top (lit when the drone is there)
	var post: Vector2 = st.post
	pen.seg(post, post + n * 0.5 * m, Pal.ink(0.5), 0.06, 1.0)
	var sg: Rect2 = st.sign
	pen.quad(sg.position, Vector2(sg.end.x, sg.position.y), sg.end, Vector2(sg.position.x, sg.end.y), Color(0.03, 0.04, 0.045))
	var band := Pal.tint(Pal.FLUID, 0.5, 1.2)
	pen.quad(sg.position, Vector2(sg.end.x, sg.position.y), Vector2(sg.end.x, sg.position.y + 0.14 * m), Vector2(sg.position.x, sg.position.y + 0.14 * m), band)
	for e in [[sg.position, Vector2(sg.end.x, sg.position.y)], [Vector2(sg.end.x, sg.position.y), sg.end], [sg.end, Vector2(sg.position.x, sg.end.y)], [Vector2(sg.position.x, sg.end.y), sg.position]]:
		pen.seg(e[0], e[1], band, 0.0, 1.0)
	if st.end:
		# the buffer stop: a beam across the dead end on two struts, striped, its red lamp
		var b := (st.at as Vector2) - d * 2.35 * m
		pen.seg(b - n * 0.9 * m, b + n * 0.9 * m, DARK, 0.34, 0.6)
		for j in 6:
			var x0 := -0.9 + j * 0.3
			pen.seg(b + n * x0 * m, b + n * (x0 + 0.15) * m, Pal.heat(0.85, 0.9), 0.3)
		for side: float in [-1.0, 1.0]:
			pen.seg(b + n * side * GAUGE * 0.5 * m, b - d * 0.9 * m + n * side * GAUGE * 0.5 * m, Pal.ink(0.32), 0.1, 0.5)
			pen.dot(b + n * side * GAUGE * 0.5 * m + d * 0.22 * m, 0.16, Pal.ink(0.5), 0.6)


# a switch's points at `pos` (0 on branch a, 1 on branch b): the two blades, the throw rod, the
# machine beside the toe with its lamp. Branches are polylines from the toe (port frame px).
static func draw_switch(pen: Pen, sw: Dictionary, pos: float, moving: bool, t: float, m: float) -> void:
	var a: Array = sw.a
	var b: Array = sw.b
	var n := a.size()
	for side: float in [-1.0, 1.0]:
		var oa := offset(a, side * GAUGE * 0.5 * m)
		var ob := offset(b, side * GAUGE * 0.5 * m)
		var pts := PackedVector2Array()
		for i in n:
			pts.append(oa[i].lerp(ob[i], pos))
		pen.line(pts, Pal.ink(0.82), 0.075, 0.9)
	var toe: Vector2 = a[0]
	var dir: Vector2 = ((a[1] as Vector2) - toe).normalized()
	var nn: Vector2 = sw.side
	var box := toe + nn * 1.75 * m + dir * 0.5 * m
	# the rod from the machine to the blades' tips, moving with them
	var tip: Vector2 = (a[1] as Vector2).lerp(b[1], pos)
	pen.seg(box - nn * 0.35 * m, tip + nn * 0.4 * m * (0.5 - pos), Pal.ink(0.42), 0.06, 0.6)
	pen.rect(box, dir, 0.9, 0.55, DARK)
	pen.rect(box, dir, 0.75, 0.4, FACE2)
	pen.seg(box - dir * 0.3 * m, box + dir * 0.3 * m, Pal.ink(0.2), 0.03, 0.4)
	var lamp: Color
	if moving:
		lamp = Pal.heat(1.0, 1.5) if fmod(t, 0.3) < 0.15 else Pal.heat(0.35, 1.0)
	else:
		lamp = Pal.tint(Pal.AIR, 1.0, 1.6) if pos > 0.5 else Pal.ink(0.95, 1.4)
	pen.disc(box + dir * 0.22 * m, 0.13, lamp, 6)
	# which way it is set: a short arrow on the machine's lid
	var aim_at: Vector2 = b[2] if pos > 0.5 else a[2]
	var aim := (aim_at - toe).normalized()
	pen.seg(box - dir * 0.2 * m, box - dir * 0.2 * m + aim * 0.28 * m, lamp, 0.05, 0.6)


# ---------------------------------------------------------------- the train (car metres, cab +x)

static var _cars := {}


static func _outline() -> PackedVector2Array:
	var h := CAR_L * 0.5
	var w := CAR_W * 0.5
	return PackedVector2Array([Vector2(-h, -w), Vector2(h - 0.45, -w), Vector2(h, -w + 0.32), Vector2(h, w - 0.32), Vector2(h - 0.45, w), Vector2(-h, w)])


static func _cached(key: String, build: Callable) -> ArrayMesh:
	if not _cars.has(key):
		var pen := MeshPen.new()
		build.call(pen)
		_cars[key] = pen.mesh()
	return _cars[key]


# the body's sides: what shows under the roof when the body leans on its springs, the windows lit
# when the drone rides
static func side_mesh(lit: bool) -> ArrayMesh:
	return _cached("side%d" % int(lit), func(p):
		p.poly(_outline(), FACE2)
		var w := CAR_W * 0.5
		var glow: Color = Pal.tint(Pal.AIR, 0.95, 1.5) if lit else Color(0.3, 0.36, 0.4)
		for side: float in [-1.0, 1.0]:
			for k in 5:
				var x0 := -1.45 + k * 0.52
				p.rect(Rect2(Vector2(x0, w - 0.2) if side > 0 else Vector2(x0, -w), Vector2(0.38, 0.2)), glow)
		p.polyline(_outline(), Pal.ink(0.5), 0.04, true))


static func shadow_mesh() -> ArrayMesh:
	return _cached("shadow", func(p):
		p.poly(_outline(), Color(0, 0, 0, 0.5)))


# the roof: a cab at +x with its windscreen, gutters, seams; car 0 carries the traction inverter
# and its resistor box, car 1 two air-conditioning units and a hatch
static func roof_mesh(car: int) -> ArrayMesh:
	return _cached("roof%d" % car, func(p):
		var h := CAR_L * 0.5
		var w := CAR_W * 0.5
		p.poly(_outline(), FACE)
		for k in 8:
			var x := -1.35 + k * 0.33
			p.line(Vector2(x, -w + 0.06), Vector2(x, w - 0.06), Pal.ink(0.05), 0.02)
		p.line(Vector2(-h + 0.05, -w + 0.12), Vector2(h - 0.5, -w + 0.12), Pal.ink(0.2), 0.025)
		p.line(Vector2(-h + 0.05, w - 0.12), Vector2(h - 0.5, w - 0.12), Pal.ink(0.2), 0.025)
		# the windscreen across the nose, its pillars and wiper
		var glass := PackedVector2Array([Vector2(h - 0.52, -w + 0.12), Vector2(h - 0.12, -w + 0.4), Vector2(h - 0.12, w - 0.4), Vector2(h - 0.52, w - 0.12)])
		p.poly(glass, Color(0.07, 0.11, 0.13))
		p.polyline(glass, Pal.ink(0.55), 0.035, true)
		p.line(Vector2(h - 0.3, -0.05), Vector2(h - 0.18, 0.22), Pal.ink(0.4), 0.025)
		# the door headers along both edges
		for x: float in DOORS:
			for side: float in [-1.0, 1.0]:
				var y: float = side * (w - 0.03)
				p.line(Vector2(x - DOOR_W * 0.5, y), Vector2(x + DOOR_W * 0.5, y), DARK, 0.06)
				p.line(Vector2(x - DOOR_W * 0.5, y - side * 0.06), Vector2(x - DOOR_W * 0.5, y), Pal.ink(0.35), 0.025)
				p.line(Vector2(x + DOOR_W * 0.5, y - side * 0.06), Vector2(x + DOOR_W * 0.5, y), Pal.ink(0.35), 0.025)
		if car == 0:
			# the traction inverter under its louvred cover, the cable run to the resistor box
			var inv := Rect2(Vector2(-0.95, -0.4), Vector2(1.1, 0.8))
			p.rect(inv, FACE2)
			p.rect(inv, Pal.ink(0.34), false, 0.03)
			for k in 7:
				var lx := inv.position.x + 0.12 + k * 0.14
				p.line(Vector2(lx, inv.position.y + 0.1), Vector2(lx, inv.end.y - 0.1), DARK, 0.05)
			for c: Vector2 in [inv.position + Vector2(0.06, 0.06), Vector2(inv.end.x - 0.06, inv.position.y + 0.06), inv.end - Vector2(0.06, 0.06), Vector2(inv.position.x + 0.06, inv.end.y - 0.06)]:
				p.bolt(c, 0.035, Pal.ink(0.5))
			p.line(Vector2(inv.end.x, 0.3), Vector2(0.35, 0.3), Pal.ink(0.3), 0.03)
			var rb := Rect2(Vector2(0.35, -0.42), Vector2(0.6, 0.84))
			p.rect(rb, DARK)
			p.rect(rb, Pal.ink(0.3), false, 0.03)
			for k in 6:
				var gx := rb.position.x + 0.07 + k * 0.09
				p.line(Vector2(gx, rb.position.y + 0.08), Vector2(gx, rb.end.y - 0.08), Pal.ink(0.16), 0.03)
			# the walkway beside the gear
			p.hatch(Rect2(Vector2(-1.5, w - 0.3), Vector2(1.45, 0.14)), Pal.ink(0.1), 0.02, 0.09)
		else:
			for cx: float in [-0.75, 0.3]:
				var ac := Rect2(Vector2(cx - 0.36, -0.44), Vector2(0.72, 0.88))
				p.rect(ac, FACE2)
				p.rect(ac, Pal.ink(0.34), false, 0.03)
				for fy: float in [-0.2, 0.2]:
					var fc := Vector2(cx, fy)
					p.circle(fc, 0.17, VOID, 14)
					p.ring(fc, 0.17, Pal.ink(0.32), 0.025, 14)
					for k in 3:
						var a := TAU * k / 3.0 + 0.4
						p.line(fc, fc + Vector2.from_angle(a) * 0.14, Pal.ink(0.22), 0.03)
					p.circle(fc, 0.04, Pal.ink(0.4), 6)
			var hatch := Rect2(Vector2(0.85, -0.25), Vector2(0.3, 0.5))
			p.rect(hatch, DARK)
			p.rect(hatch, Pal.ink(0.3), false, 0.025)
			p.line(Vector2(0.92, 0.0), Vector2(1.08, 0.0), Pal.ink(0.5), 0.03)
		p.polyline(_outline(), Pal.ink(0.82), 0.045, true))


# a bogie as a hidden line seen through the roof: two side frames, two wheelsets on the rails, the
# pivot, the traction motor
static func bogie_mesh(motor: bool) -> ArrayMesh:
	return _cached("bogie%d" % int(motor), func(p):
		var g := GAUGE * 0.5
		var col := Pal.ink(0.75)
		for y: float in [-0.68, 0.68]:
			p.rect(Rect2(Vector2(-0.58, y - 0.07), Vector2(1.16, 0.14)), col, false, 0.025)
		for x: float in [-0.36, 0.36]:
			p.line(Vector2(x, -0.74), Vector2(x, 0.74), col, 0.03)
			for y: float in [-g, g]:
				p.rect(Rect2(Vector2(x - 0.17, y - 0.04), Vector2(0.34, 0.08)), col)
		p.line(Vector2(-0.36, 0.0), Vector2(0.36, 0.0), Color(col, 0.6), 0.02)
		p.ring(Vector2.ZERO, 0.13, col, 0.03, 12)
		if motor:
			p.rect(Rect2(Vector2(-0.28, -0.38), Vector2(0.24, 0.5)), col, false, 0.025))


# a door leaf, 0.25 m along the wall, seen edge-on from above
static func leaf_mesh() -> ArrayMesh:
	return _cached("leaf", func(p):
		p.rect(Rect2(Vector2(0.0, -0.035), Vector2(0.25, 0.07)), FACE2)
		p.rect(Rect2(Vector2(0.0, -0.035), Vector2(0.25, 0.07)), Pal.ink(0.75), false, 0.02))
