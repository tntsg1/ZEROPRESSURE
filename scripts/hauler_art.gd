extends RefCounted
# The berth's hauling drones (2026-11-12, user: "最多 5 个无人机，每个无人机都长得完全不一样"):
# five airframes of their own, none of them the operator's drone family. Each has its own
# outline, its own thruster layout and its own way of holding a load:
#   0 桁架绞车  an open truss frame, four corner thruster blocks, a winch paying out a hook
#   1 环辐磁吸  a spoked ring with nozzles round its rim, a telescoping boom and a magnet pad
#   2 双体叉架  two pontoons on cross-beams, bell mains astern, fork tines and a clamp bar
#   3 花瓣抓斗  an octagonal hub on a gimballed main, a four-petal grab that curls shut
#   4 重型吸盘  a long spine with a cab, side tanks on an H-frame, a bar of three suction cups
# (the user then kept the first two haulers' old airframes, core-claw and tripod: these five are the
# third to the seventh, in this order — hauler.gd)
# Everything is drawn in the drone's own frame (x where it looks) in art units, like
# drone_art.gd, and fires only the jets that push the way it really accelerates
# (strict inertia: speeding up blows back, slowing down is a reverse burn).
#   st: {"heading", "t", "thrust" (world, |.|<=1), "reach" 0..1 (the grip reaching out),
#        "grip" 0..1 (shut on a load), "base_xf"}

const Art = preload("res://scripts/drone_art.gd")
const FastDraw = preload("res://scripts/fast_draw.gd")
const N := 5
const HULL := Art.HULL
const HULL_HI := Art.HULL_HI
const DARK := Color(0.03, 0.032, 0.036)
# each drawn to about the same span as the old airframes (some 50 art units across)
const SIZE := [1.2, 1.15, 1.15, 1.45, 1.1]


static func draw(ci: CanvasItem, idx: int, st: Dictionary) -> void:
	var base: Transform2D = st.get("base_xf", Transform2D.IDENTITY)
	var k: float = SIZE[idx % N]
	ci.draw_set_transform_matrix(base * Transform2D(float(st.heading), Vector2(k, k), 0.0, Vector2.ZERO))
	var lth: Vector2 = (st.get("thrust", Vector2.ZERO) as Vector2).rotated(-float(st.heading))
	match idx % N:
		0: _truss(ci, st, lth)
		1: _wheel(ci, st, lth)
		2: _twin(ci, st, lth)
		3: _petal(ci, st, lth)
		4: _heavy(ci, st, lth)
	ci.draw_set_transform_matrix(base)


# a nozzle exhausting along d (local) fires as much as it helps push along lth
static func _fire(lth: Vector2, d: Vector2) -> float:
	return clampf(-d.dot(lth) * 1.25, 0.0, 1.0)


static func ink(a: float, k: float = 1.0) -> Color:
	return Art.ink(a, k)


static func lamp(a: float, k: float = 1.0) -> Color:
	return Art.air(a, k)


static func _box(ci: CanvasItem, r: Rect2, fill: Color, edge: Color, w: float) -> void:
	FastDraw.poly(ci, PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), fill)
	Art.outline(ci, PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), edge, w)


static func _ring(ci: CanvasItem, c: Vector2, r: float, col: Color, w: float, n: int = 18) -> void:
	FastDraw.arc(ci, c, r, 0.0, TAU, n, col, w, true)


# a small bell nozzle at p exhausting along d, its flame f
static func _bell(ci: CanvasItem, p: Vector2, d: Vector2, s: float, f: float, t: float) -> void:
	var n := Vector2(-d.y, d.x)
	var bell := PackedVector2Array([p - d * 2.2 * s + n * 1.3 * s, p + d * 1.6 * s + n * 2.4 * s, p + d * 1.6 * s - n * 2.4 * s, p - d * 2.2 * s - n * 1.3 * s])
	FastDraw.poly(ci, bell, HULL_HI)
	Art.outline(ci, bell, ink(0.85), 0.9)
	Art.flame(ci, p + d * 1.8 * s, d, f, 2.0 * s, t + p.x * 0.37 + p.y, false)


# ------------------------------------------------------------ 0 · 桁架绞车 TRUSS WINCH

static func _truss(ci: CanvasItem, st: Dictionary, lth: Vector2) -> void:
	var t: float = st.t
	var reach: float = Pal.ease_io(clampf(float(st.get("reach", 0.0)), 0.0, 1.0))
	var grip: float = clampf(float(st.get("grip", 0.0)), 0.0, 1.0)
	var lite := Art.lite
	var hx := 15.0
	var hy := 11.0
	# the deck plate under the truss (dark, so the bracing reads)
	_box(ci, Rect2(-hx, -hy, hx * 2.0, hy * 2.0), DARK, ink(0.0), 0.1)
	# the truss: double rails round the frame, X bracing in its two bays
	for s: float in [-1.0, 1.0]:
		ci.draw_line(Vector2(-hx, hy * s), Vector2(hx, hy * s), ink(0.9), 1.6, true)
		ci.draw_line(Vector2(hx * s, -hy), Vector2(hx * s, hy), ink(0.9), 1.6, true)
		if not lite:
			ci.draw_line(Vector2(-hx + 2.5, (hy - 2.5) * s), Vector2(hx - 2.5, (hy - 2.5) * s), ink(0.4), 0.8, true)
	ci.draw_line(Vector2(0, -hy), Vector2(0, hy), ink(0.6), 1.1, true)
	if not lite:
		for bx: float in [-hx, 0.0]:
			ci.draw_line(Vector2(bx, -hy), Vector2(bx + hx, hy), ink(0.45), 0.9, true)
			ci.draw_line(Vector2(bx, hy), Vector2(bx + hx, -hy), ink(0.45), 0.9, true)
	# four corner thruster blocks: an axial nozzle and an outboard one each
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			var c := Vector2(hx * sx, hy * sy)
			_box(ci, Rect2(c - Vector2(3.4, 3.4), Vector2(6.8, 6.8)), HULL_HI, ink(0.95), 1.1)
			if not lite:
				ci.draw_line(c + Vector2(-1.6, -1.6), c + Vector2(1.6, 1.6), ink(0.35), 0.7, true)
				FastDraw.circle(ci, c, 0.9, lamp(0.5 + 0.4 * sin(t * 4.0 + sx * 2.0 + sy), 1.4))
			var da := Vector2(sx, 0)                # fore/aft
			var dl := Vector2(0, sy)                # outboard
			Art.flame(ci, c + da * 3.6, da, _fire(lth, da), 1.6, t + sx + sy * 2.0, false)
			Art.flame(ci, c + dl * 3.6, dl, _fire(lth, dl), 1.6, t + sx * 3.0 + sy, false)
	# the winch: a drum across the middle bay, its ribs rolling as the cable pays out
	var drum := Rect2(-6.0, -6.5, 8.0, 13.0)
	_box(ci, drum, HULL, ink(0.95), 1.3)
	if not lite:
		var roll := fposmod(reach * 9.0 + t * (0.0 if grip > 0.5 else 0.15), 2.6)
		for k in 5:
			var y := drum.position.y + fposmod(roll + k * 2.6, 13.0)
			ci.draw_line(Vector2(drum.position.x + 0.8, y), Vector2(drum.end.x - 0.8, y), ink(0.4), 0.7, true)
		_box(ci, Rect2(-9.0, -3.0, 2.6, 6.0), HULL_HI, ink(0.8), 0.9)   # its motor
	# the fairlead at the front rail, the cable, and the hook on it
	var lead := Vector2(hx, 0)
	_box(ci, Rect2(lead - Vector2(1.6, 2.8), Vector2(3.2, 5.6)), HULL_HI, ink(0.9), 1.0)
	ci.draw_line(Vector2(drum.end.x, 0), lead, ink(0.7), 1.0, true)
	var sway := 0.8 * sin(t * 1.7) * (1.0 - grip)
	var hook := lead + Vector2(4.0 + 9.0 * reach, sway)
	ci.draw_line(lead, hook, ink(0.85), 1.1, true)
	# the hook: a shank, a throat that turns back, and its latch shut on a load
	var shank := hook + Vector2(4.0, 0)
	ci.draw_line(hook, shank, ink(0.95), 2.2, true)
	FastDraw.arc(ci, shank + Vector2(0, 3.4), 3.4, -PI * 0.5, PI * 0.85, 12, ink(0.95), 2.0, true)
	FastDraw.circle(ci, shank + Vector2.from_angle(PI * 0.85) * 3.4 + Vector2(0, 3.4), 1.0, ink(0.95))
	var latch_a := lerpf(-0.9, 0.35, grip)
	ci.draw_line(shank, shank + Vector2.from_angle(PI * 0.5 + latch_a) * 5.6, lamp(0.6 + 0.4 * grip, 1.0 + grip), 1.2, true)
	if not lite:
		_ring(ci, hook, 1.2, ink(0.9), 0.8, 8)


# ------------------------------------------------------------ 1 · 环辐磁吸 SPOKED RING, MAGNET

static func _wheel(ci: CanvasItem, st: Dictionary, lth: Vector2) -> void:
	var t: float = st.t
	var reach: float = Pal.ease_io(clampf(float(st.get("reach", 0.0)), 0.0, 1.0))
	var grip: float = clampf(float(st.get("grip", 0.0)), 0.0, 1.0)
	var lite := Art.lite
	var ro := 17.0
	var ri := 13.0
	# the ring: a band between two circles, eight nozzle ports round the rim
	for i in 24:
		var d0 := Vector2.from_angle(TAU * i / 24.0)
		var d1 := Vector2.from_angle(TAU * (i + 1) / 24.0)
		FastDraw.poly(ci, PackedVector2Array([d0 * ri, d0 * ro, d1 * ro, d1 * ri]), HULL)
	_ring(ci, Vector2.ZERO, ro, ink(0.95), 1.5, 28)
	_ring(ci, Vector2.ZERO, ri, ink(0.7), 1.0, 24)
	for k in 8:
		var a := TAU * k / 8.0 + PI / 8.0
		var d := Vector2.from_angle(a)
		var p := d * ro
		var port := PackedVector2Array([p - d * 1.2 + Vector2(-d.y, d.x) * 1.8, p + d * 1.6 + Vector2(-d.y, d.x) * 2.2, p + d * 1.6 - Vector2(-d.y, d.x) * 2.2, p - d * 1.2 - Vector2(-d.y, d.x) * 1.8])
		FastDraw.poly(ci, port, HULL_HI)
		Art.outline(ci, port, ink(0.85), 0.9)
		Art.flame(ci, p + d * 1.8, d, _fire(lth, d), 1.5, t + k * 1.3, false)
		if not lite:
			# a lit segment on the band between the ports, running round
			var lit := 0.5 + 0.5 * sin(t * 3.0 - k * 0.79)
			FastDraw.arc(ci, Vector2.ZERO, (ro + ri) * 0.5, a + 0.18, a + 0.6, 4, lamp(0.18 + 0.5 * lit, 1.0 + lit), 1.0, true)
	# six spokes to the hub
	for k in 6:
		var d := Vector2.from_angle(TAU * k / 6.0)
		ci.draw_line(d * 5.5, d * ri, ink(0.65), 1.4, true)
	# the hub and its reaction wheel turning under a slotted cover
	FastDraw.circle(ci, Vector2.ZERO, 6.0, HULL_HI)
	_ring(ci, Vector2.ZERO, 6.0, ink(0.95), 1.2, 18)
	if not lite:
		var sp := t * 2.6
		for k in 3:
			var a0 := sp + TAU * k / 3.0
			FastDraw.arc(ci, Vector2.ZERO, 3.8, a0, a0 + 1.4, 6, ink(0.55), 0.9, true)
	FastDraw.circle(ci, Vector2.ZERO, 1.4, lamp(0.9, 1.5))
	# the telescoping boom forward: three nested tubes, run out as it reaches
	var base_x := ri - 1.0
	var segs := [7.0, 6.0, 5.0]
	var x := base_x
	for i in 3:
		var w := 3.0 - i * 0.6
		var ln: float = segs[i] * (0.35 + 0.65 * reach) if i > 0 else segs[i]
		_box(ci, Rect2(x, -w, ln + 1.0, w * 2.0), HULL_HI, ink(0.9), 0.9)
		x += ln
	# the magnet: a flat pad with its coil, lit when it holds
	var pad := Rect2(x + 0.5, -5.5, 3.0, 11.0)
	_box(ci, pad, HULL, ink(0.95), 1.3)
	var on := grip
	ci.draw_line(Vector2(pad.end.x, pad.position.y + 0.6), Vector2(pad.end.x, pad.end.y - 0.6), lamp(0.35 + 0.6 * on, 1.0 + 1.3 * on), 1.4, true)
	if not lite:
		for k in 4:
			var y := pad.position.y + 1.8 + k * 2.5
			ci.draw_line(Vector2(pad.position.x + 0.6, y), Vector2(pad.end.x - 0.6, y), ink(0.4), 0.7, true)
		if on > 0.5:
			# the field: two faint arcs off the face, pulsing
			var pu := fposmod(t * 1.8, 1.0)
			FastDraw.arc(ci, Vector2(pad.end.x - 1.0, 0), 4.0 + 5.0 * pu, -0.9, 0.9, 8, lamp(0.45 * (1.0 - pu), 1.6), 0.9, true)


# ------------------------------------------------------------ 2 · 双体叉架 TWIN PONTOON, FORKS

static func _twin(ci: CanvasItem, st: Dictionary, lth: Vector2) -> void:
	var t: float = st.t
	var reach: float = Pal.ease_io(clampf(float(st.get("reach", 0.0)), 0.0, 1.0))
	var grip: float = clampf(float(st.get("grip", 0.0)), 0.0, 1.0)
	var lite := Art.lite
	var py := 10.0
	# the fork tines first (they slide out under the cross-beams)
	var tx := lerpf(4.0, 14.0, reach)
	for s: float in [-1.0, 1.0]:
		var tine := PackedVector2Array([Vector2(-6, (3.6 + 0.0) * s), Vector2(tx + 6.0, 3.2 * s), Vector2(tx + 8.0, 2.4 * s), Vector2(-6, 2.0 * s)])
		FastDraw.poly(ci, tine, HULL_HI)
		Art.outline(ci, tine, ink(0.9), 0.9)
	# the clamp bar comes down along the tines onto the load
	var cx := lerpf(-4.0, tx + 2.0, grip)
	_box(ci, Rect2(cx - 1.2, -6.0, 2.4, 12.0), HULL, ink(0.95), 1.1)
	if not lite:
		ci.draw_line(Vector2(-6, 0), Vector2(cx - 1.2, 0), ink(0.5), 0.8, true)   # its ram
		ci.draw_line(Vector2(cx + 1.2, -4.5), Vector2(cx + 1.2, 4.5), lamp(0.3 + 0.6 * grip, 1.0 + grip), 1.0, true)
	# two pontoons: long capsules with a seam and portholes, lamp strips on their inner edges
	for s: float in [-1.0, 1.0]:
		var c := Vector2(0, py * s)
		var cap := PackedVector2Array()
		for i in 9:
			cap.append(c + Vector2(14.0, 0) + Vector2.from_angle(-PI * 0.5 + PI * i / 8.0) * 4.2)
		for i in 9:
			cap.append(c + Vector2(-14.0, 0) + Vector2.from_angle(PI * 0.5 + PI * i / 8.0) * 4.2)
		FastDraw.poly(ci, cap, HULL)
		Art.outline(ci, cap, ink(0.95), 1.4)
		if not lite:
			ci.draw_line(c + Vector2(-12, 0), c + Vector2(12, 0), ink(0.3), 0.8, true)
			for k in 3:
				_ring(ci, c + Vector2(-6 + k * 6.0, 0), 1.2, ink(0.6), 0.7, 8)
		ci.draw_line(c + Vector2(-10, -3.6 * s), c + Vector2(12, -3.6 * s), lamp(0.45 + 0.25 * sin(t * 2.2 + s), 1.3), 1.0, true)
		# a bell main astern, a retro at the bow, a puffer outboard
		_bell(ci, c + Vector2(-19.0, 0), Vector2.LEFT, 1.15, _fire(lth, Vector2.LEFT), t + s)
		Art.flame(ci, c + Vector2(18.4, 0), Vector2.RIGHT, _fire(lth, Vector2.RIGHT) * 0.8, 1.4, t + s * 2.0, false)
		Art.flame(ci, c + Vector2(0, 4.4 * s), Vector2(0, s), _fire(lth, Vector2(0, s)) * 0.8, 1.4, t + s * 4.0, false)
		if not lite:
			FastDraw.circle(ci, c + Vector2(18.2, 0), 0.9, HULL_HI)
	# the cross-beams and the operator-less control pod between them
	for bx: float in [-8.0, 2.0]:
		_box(ci, Rect2(bx - 1.6, -py + 3.0, 3.2, (py - 3.0) * 2.0), HULL_HI, ink(0.85), 1.0)
	var podp := PackedVector2Array([Vector2(-13, -4.2), Vector2(-6, -4.2), Vector2(-4.5, 0), Vector2(-6, 4.2), Vector2(-13, 4.2)])
	FastDraw.poly(ci, podp, HULL)
	Art.outline(ci, podp, ink(0.95), 1.2)
	FastDraw.circle(ci, Vector2(-8.0, 0), 1.6, lamp(0.85, 1.4))


# ------------------------------------------------------------ 3 · 花瓣抓斗 OCTAGON HUB, PETAL GRAB

static func _petal(ci: CanvasItem, st: Dictionary, lth: Vector2) -> void:
	var t: float = st.t
	var reach: float = Pal.ease_io(clampf(float(st.get("reach", 0.0)), 0.0, 1.0))
	var grip: float = clampf(float(st.get("grip", 0.0)), 0.0, 1.0)
	var lite := Art.lite
	# the gimballed main astern: it swings to push the way it is told (its bell turned off-axis)
	var want := -lth
	var ga := clampf(want.angle_to(Vector2.LEFT) * -1.0, -0.5, 0.5) if want.length() > 0.05 else 0.0
	var gd := Vector2.LEFT.rotated(ga)
	var gp := Vector2(-11.0, 0)
	ci.draw_line(Vector2(-8, 0), gp, ink(0.6), 2.4, true)
	_bell(ci, gp + gd * 3.0, gd, 1.6, clampf(-gd.dot(lth) * 1.3, 0.0, 1.0), t)
	# four cold-gas puffer clusters on the diagonals (side push and braking)
	for k in 4:
		var d := Vector2.from_angle(PI * 0.25 + PI * 0.5 * k)
		var p := d * 11.5
		ci.draw_line(d * 7.0, p, ink(0.55), 1.3, true)
		FastDraw.circle(ci, p, 2.0, HULL_HI)
		_ring(ci, p, 2.0, ink(0.85), 0.9, 10)
		var dx := Vector2(signf(d.x), 0)
		var dy := Vector2(0, signf(d.y))
		Art.flame(ci, p + dx * 2.0, dx, _fire(lth, dx) * 0.7, 1.1, t + k, false)
		Art.flame(ci, p + dy * 2.0, dy, _fire(lth, dy) * 0.7, 1.1, t + k * 2.0, false)
	# the octagonal armoured hub
	var oct := PackedVector2Array()
	for i in 8:
		oct.append(Vector2.from_angle(TAU * i / 8.0 + PI / 8.0) * 9.0)
	FastDraw.poly(ci, oct, HULL)
	Art.outline(ci, oct, ink(0.95), 1.5)
	if not lite:
		var inner := PackedVector2Array()
		for i in 8:
			inner.append(oct[i] * 0.62)
		Art.outline(ci, inner, ink(0.35), 0.8)
		for i in 8:
			ci.draw_line(oct[i] * 0.62, oct[i], ink(0.25), 0.7, true)
	FastDraw.circle(ci, Vector2(-1.0, 0), 2.0, lamp(0.75 + 0.2 * sin(t * 2.0), 1.5))
	# the grab head ahead of the hub, on its neck, with the two hydraulic lines
	var gc := Vector2(15.0 + 3.0 * reach, 0)
	ci.draw_line(Vector2(8.5, 0), gc - Vector2(3.5, 0), ink(0.8), 3.0, true)
	if not lite:
		for s: float in [-1.0, 1.0]:
			FastDraw.polyline(ci, PackedVector2Array([Vector2(6, 3.0 * s), Vector2(10, 4.2 * s), gc + Vector2(-3, 2.2 * s)]), ink(0.45), 0.8, true)
	FastDraw.circle(ci, gc - Vector2(2.0, 0), 3.0, HULL_HI)
	_ring(ci, gc - Vector2(2.0, 0), 3.0, ink(0.95), 1.0, 12)
	# four petals hinged round the head: splayed wide reaching, curled shut on a load
	var open := (1.0 - grip) * (0.35 + 0.65 * reach)
	for k in 4:
		var a := PI * 0.5 * k + PI * 0.25
		var dir := Vector2.from_angle(a)
		var hinge := gc + dir * 3.2
		# a quadratic curve: out along its own diagonal, then forward to the tip
		var ctrl := hinge + dir * (3.0 + 2.5 * open) + Vector2(2.5, 0)
		var shut := gc + Vector2(6.0, 0) + dir * 0.9
		var wide := hinge + dir * 6.5 + Vector2(4.5, 0)
		var tip := shut.lerp(wide, open)
		var pts := PackedVector2Array()
		for j in 6:
			var u := j / 5.0
			pts.append(hinge.lerp(ctrl, u).lerp(ctrl.lerp(tip, u), u))
		FastDraw.polyline(ci, pts, ink(0.95), 1.6, true)
		if not lite:
			ci.draw_line(tip, tip - (tip - ctrl).normalized().rotated(0.6 * signf(dir.y)) * 1.8, ink(0.95), 1.1, true)
		if not lite:
			FastDraw.circle(ci, hinge, 1.0, HULL_HI)
			_ring(ci, hinge, 1.0, ink(0.8), 0.6, 8)
	if grip > 0.5:
		FastDraw.circle(ci, gc + Vector2(3.0, 0), 1.1, lamp(0.9, 1.8))


# ------------------------------------------------------------ 4 · 重型吸盘 HEAVY SPINE, SUCTION BAR

static func _heavy(ci: CanvasItem, st: Dictionary, lth: Vector2) -> void:
	var t: float = st.t
	var reach: float = Pal.ease_io(clampf(float(st.get("reach", 0.0)), 0.0, 1.0))
	var grip: float = clampf(float(st.get("grip", 0.0)), 0.0, 1.0)
	var lite := Art.lite
	# the H-frame beams and the two side tanks, each with a lateral puffer
	ci.draw_line(Vector2(-4, -15), Vector2(-4, 15), ink(0.7), 2.2, true)
	for s: float in [-1.0, 1.0]:
		var c := Vector2(-4, 15.5 * s)
		var tank := PackedVector2Array()
		for i in 7:
			tank.append(c + Vector2(6.0, 0) + Vector2.from_angle(-PI * 0.5 + PI * i / 6.0) * 4.0)
		for i in 7:
			tank.append(c + Vector2(-6.0, 0) + Vector2.from_angle(PI * 0.5 + PI * i / 6.0) * 4.0)
		FastDraw.poly(ci, tank, HULL)
		Art.outline(ci, tank, ink(0.95), 1.3)
		if not lite:
			for bx: float in [-3.5, 3.5]:
				ci.draw_line(c + Vector2(bx, -4.0), c + Vector2(bx, 4.0), ink(0.4), 0.8, true)
		FastDraw.circle(ci, c + Vector2(0, 0), 1.0, lamp(0.5 + 0.4 * sin(t * 1.6 + s * 1.5), 1.3))
		var dl := Vector2(0, s)
		Art.flame(ci, c + dl * 4.2, dl, _fire(lth, dl) * 0.85, 1.6, t + s * 3.0, false)
		# its fore retro
		Art.flame(ci, c + Vector2(10.2, 0), Vector2.RIGHT, _fire(lth, Vector2.RIGHT) * 0.8, 1.5, t + s, false)
	# the spine: a long hexagonal hull, a cab at the front with a lit visor slit
	var spine := PackedVector2Array([Vector2(20, -3.2), Vector2(22, 0), Vector2(20, 3.2), Vector2(-15, 5.5), Vector2(-18, 0), Vector2(-15, -5.5)])
	FastDraw.poly(ci, spine, HULL)
	Art.outline(ci, spine, ink(0.95), 1.6)
	var cab := PackedVector2Array([Vector2(19.5, -2.8), Vector2(21.2, 0), Vector2(19.5, 2.8), Vector2(11, 4.2), Vector2(11, -4.2)])
	FastDraw.poly(ci, cab, HULL_HI)
	Art.outline(ci, cab, ink(0.8), 1.0)
	ci.draw_line(Vector2(17.5, -2.4), Vector2(17.5, 2.4), lamp(0.95, 1.6), 1.3, true)
	if not lite:
		for k in 4:
			var x := -12.0 + k * 5.5
			ci.draw_line(Vector2(x, -4.6 + k * 0.1), Vector2(x, 4.6 - k * 0.1), ink(0.3), 0.8, true)
		ci.draw_line(Vector2(-15, 0), Vector2(10, 0), ink(0.22), 0.7, true)
	# three bell mains in a row astern
	for k in 3:
		var p := Vector2(-19.5, (k - 1) * 3.6)
		_bell(ci, p, Vector2.LEFT, 0.95, _fire(lth, Vector2.LEFT), t + k * 1.7)
	# the suction bar under the nose: a manifold across, three cups run out on rams
	var bx := 12.0 + 8.0 * reach
	for k in 3:
		var y := (k - 1) * 7.0
		ci.draw_line(Vector2(12.0, y * 0.6), Vector2(bx, y), ink(0.75), 1.2, true)
	_box(ci, Rect2(bx - 1.2, -9.0, 2.4, 18.0), HULL_HI, ink(0.95), 1.1)
	for k in 3:
		var cc := Vector2(bx + 3.4, (k - 1) * 7.0)
		FastDraw.circle(ci, cc, 2.8, HULL)
		_ring(ci, cc, 2.8, ink(0.95), 1.1, 14)
		var vac := grip * (0.6 + 0.4 * sin(t * 6.0 + k * 2.1))
		if not lite:
			_ring(ci, cc, 1.6, ink(0.45), 0.7, 10)
		FastDraw.circle(ci, cc, 0.9, lamp(0.3 + 0.65 * vac, 1.0 + 1.2 * vac))

