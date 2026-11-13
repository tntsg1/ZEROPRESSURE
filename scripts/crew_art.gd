extends RefCounted
# The works crew's drones (2026-11-12, user: "施工队的动画确实需要搞一下"; earlier: "硬核的修复就是无人机
# 真的修复那个位置"). Six trades, six airframes, each telling its job by its outline:
#   bot     isolation tech   a boxy cab with a beacon, a two-finger hand that throws the isolator
#   cutter  cutter           a long hull, a hatched heat shield, two gas bottles, a torch on an arm
#   hauler  rigger           an H frame, a winch drum under the cross-beam paying out the tether
#   torque  fitter           a squat octagon, a hydraulic motor on its back, a socket on an arm
#   cable   cable layer      a round hull round a big reel that turns as the cable pays out
#   tester  commissioning    a slim diamond, an aerial mast, a five-step meter that fills as it proves
# The crew's livery: dark hull, white line, a chevron band on the nose plate (no words on the work),
# its trade lamp. Thrusters fire only as it really accelerates (strict inertia, as hauler_art.gd).
# The tool arm is drawn in world space from its shoulder to what it works on (tip on the work).
#   st: {"heading", "t", "thrust" (local-free, world |.|<=1), "role", "busy" 0..1, "lamp", "reel" (turns)}

const Art = preload("res://scripts/drone_art.gd")
const FastDraw = preload("res://scripts/fast_draw.gd")
const HULL := Art.HULL
const HULL_HI := Art.HULL_HI
const DARK := Color(0.03, 0.032, 0.036)
const BAND := Color(1.0, 0.62, 0.22)       # the works crew's chevron band (theme orange, a shade warmer)


static func ink(a: float, k: float = 1.0) -> Color:
	return Art.ink(a, k)


static func _fire(lth: Vector2, d: Vector2) -> float:
	return clampf(-d.dot(lth) * 1.25, 0.0, 1.0)


static func _box(ci: CanvasItem, r: Rect2, fill: Color, edge: Color, w: float) -> void:
	var p := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	FastDraw.poly(ci, p, fill)
	Art.outline(ci, p, edge, w)


static func _shape(ci: CanvasItem, p: PackedVector2Array, fill: Color, edge: Color, w: float) -> void:
	FastDraw.poly(ci, p, fill)
	Art.outline(ci, p, edge, w)


# a thruster pod at c with nozzles along each of dirs, each lit as it pushes the way it accelerates
static func _pod(ci: CanvasItem, c: Vector2, dirs: Array, lth: Vector2, t: float, s: float = 1.0) -> void:
	_box(ci, Rect2(c - Vector2(3.0, 3.0) * s, Vector2(6.0, 6.0) * s), HULL_HI, ink(0.9), 1.0)
	for d: Vector2 in dirs:
		var n := Vector2(-d.y, d.x)
		var p := c + d * 3.0 * s
		FastDraw.poly(ci, PackedVector2Array([p + n * 1.3 * s, p + d * 1.8 * s + n * 1.9 * s, p + d * 1.8 * s - n * 1.9 * s, p - n * 1.3 * s]), HULL)
		Art.flame(ci, p + d * 1.9 * s, d, _fire(lth, d), 1.5 * s, t + c.x * 0.31 + c.y, false)


# the chevron band across a nose plate from a to b (local), its depth h
static func _band(ci: CanvasItem, a: Vector2, b: Vector2, h: float) -> void:
	var d := (b - a)
	var n := Vector2(-d.y, d.x).normalized() * h
	FastDraw.poly(ci, PackedVector2Array([a, b, b + n, a + n]), Color(BAND, 0.9))
	if Art.lite:
		return
	var k := 4
	for i in k:
		var f0 := (i + 0.15) / float(k)
		var f1 := (i + 0.55) / float(k)
		ci.draw_line(a + d * f0, a + d * f1 + n, DARK, 1.0, true)


static func draw(ci: CanvasItem, st: Dictionary) -> void:
	var base: Transform2D = st.get("base_xf", Transform2D.IDENTITY)
	ci.draw_set_transform_matrix(base * Transform2D(float(st.heading), Vector2.ZERO))
	var lth: Vector2 = (st.get("thrust", Vector2.ZERO) as Vector2).rotated(-float(st.heading))
	match str(st.role):
		"bot": _bot(ci, st, lth)
		"cutter": _cutter(ci, st, lth)
		"hauler": _hauler(ci, st, lth)
		"torque": _torque(ci, st, lth)
		"cable": _cable(ci, st, lth)
		_: _tester(ci, st, lth)
	ci.draw_set_transform_matrix(base)


static func _lamp(ci: CanvasItem, p: Vector2, st: Dictionary, r: float = 1.6) -> void:
	var t: float = st.t
	var blink := 1.0 if fmod(t + float(st.get("seed", 0.0)), 1.2) < 0.75 else 0.3
	FastDraw.circle(ci, p, r * 2.2, Color(st.lamp, 0.18 * blink))
	FastDraw.circle(ci, p, r, Color(st.lamp, blink))


# ------------------------------------------------------------ bot · isolation tech

static func _bot(ci: CanvasItem, st: Dictionary, lth: Vector2) -> void:
	var t: float = st.t
	var cab := PackedVector2Array([Vector2(-11, -8), Vector2(7, -8), Vector2(12, -4), Vector2(12, 4), Vector2(7, 8), Vector2(-11, 8)])
	_shape(ci, cab, HULL, ink(0.95), 1.4)
	_band(ci, Vector2(8.5, -6.5), Vector2(8.5, 6.5), 2.6)
	if not Art.lite:
		ci.draw_line(Vector2(-8, -4.5), Vector2(3, -4.5), ink(0.35), 0.8, true)
		ci.draw_line(Vector2(-8, 4.5), Vector2(3, 4.5), ink(0.35), 0.8, true)
		_box(ci, Rect2(-6, -2.2, 7, 4.4), DARK, ink(0.6), 0.8)       # the isolator kit
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			_pod(ci, Vector2(sx * 11.0 - (2.0 if sx < 0 else -2.0), sy * 10.5), [Vector2(sx, 0), Vector2(0, sy)], lth, t, 0.9)
	_lamp(ci, Vector2(-4, 0), st, 1.8)


# ------------------------------------------------------------ cutter

static func _cutter(ci: CanvasItem, st: Dictionary, lth: Vector2) -> void:
	var t: float = st.t
	var hull := PackedVector2Array([Vector2(-15, -5), Vector2(9, -5), Vector2(14, 0), Vector2(9, 5), Vector2(-15, 5), Vector2(-17, 0)])
	# the two gas bottles slung either side (oxygen, fuel gas)
	for s: float in [-1.0, 1.0]:
		var c := Vector2(-3, 8.2 * s)
		_box(ci, Rect2(c - Vector2(9, 2.4), Vector2(18, 4.8)), HULL_HI, ink(0.85), 1.0)
		FastDraw.circle(ci, c + Vector2(9.2, 0), 1.3, ink(0.8))
		if not Art.lite:
			ci.draw_line(c + Vector2(-6, 0), c + Vector2(5, 0), ink(0.3), 0.7, true)
	_shape(ci, hull, HULL, ink(0.95), 1.4)
	# the heat shield on the nose, hatched
	var sh := PackedVector2Array([Vector2(6, -6.5), Vector2(10, -6.5), Vector2(16, 0), Vector2(10, 6.5), Vector2(6, 6.5)])
	_shape(ci, sh, DARK, ink(0.9), 1.1)
	if not Art.lite:
		for k in 4:
			var x := 7.0 + k * 2.0
			ci.draw_line(Vector2(x, -5.5), Vector2(x + 2.5, 5.5), Color(BAND, 0.55), 0.8, true)
	_pod(ci, Vector2(-15, -8.5), [Vector2(-1, 0), Vector2(0, -1)], lth, t, 0.85)
	_pod(ci, Vector2(-15, 8.5), [Vector2(-1, 0), Vector2(0, 1)], lth, t, 0.85)
	_pod(ci, Vector2(10, -9.5), [Vector2(1, 0), Vector2(0, -1)], lth, t, 0.75)
	_pod(ci, Vector2(10, 9.5), [Vector2(1, 0), Vector2(0, 1)], lth, t, 0.75)
	_lamp(ci, Vector2(-9, 0), st)


# ------------------------------------------------------------ hauler · rigger

static func _hauler(ci: CanvasItem, st: Dictionary, lth: Vector2) -> void:
	var t: float = st.t
	for s: float in [-1.0, 1.0]:
		_box(ci, Rect2(-16, 9.0 * s - 2.6, 32, 5.2), HULL, ink(0.95), 1.3)
		if not Art.lite:
			for k in 5:
				var x := -13.0 + k * 6.5
				ci.draw_line(Vector2(x, 9.0 * s - 2.0), Vector2(x + 3.0, 9.0 * s + 2.0), ink(0.35), 0.7, true)
	_box(ci, Rect2(-4, -7, 8, 14), HULL, ink(0.9), 1.2)
	# the winch drum across the middle, its ribs rolling as the tether pays out
	var drum := Rect2(-6.5, -4.2, 13, 8.4)
	_box(ci, drum, HULL_HI, ink(0.95), 1.2)
	if not Art.lite:
		var roll := fposmod(float(st.get("reel", 0.0)) * 6.0, 2.6)
		for k in 5:
			var x := drum.position.x + fposmod(roll + k * 2.6, 13.0)
			ci.draw_line(Vector2(x, drum.position.y + 0.8), Vector2(x, drum.end.y - 0.8), ink(0.4), 0.7, true)
	_band(ci, Vector2(16, -11.6), Vector2(16, -6.4), -2.4)
	_band(ci, Vector2(16, 6.4), Vector2(16, 11.6), -2.4)
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			_pod(ci, Vector2(sx * 18.5, sy * 9.0), [Vector2(sx, 0), Vector2(0, sy)], lth, t, 0.95)
	_lamp(ci, Vector2(0, -5.5), st, 1.4)


# ------------------------------------------------------------ torque · fitter

static func _torque(ci: CanvasItem, st: Dictionary, lth: Vector2) -> void:
	var t: float = st.t
	var oct := PackedVector2Array()
	for k in 8:
		oct.append(Vector2.from_angle(TAU * (k + 0.5) / 8.0) * 11.5)
	_shape(ci, oct, HULL, ink(0.95), 1.4)
	# the hydraulic motor on its back, the hoses to the arm root
	_box(ci, Rect2(-7, -4.5, 10, 9), HULL_HI, ink(0.9), 1.1)
	if not Art.lite:
		var sp := float(st.get("busy", 0.0)) * t * 9.0
		for k in 3:
			var a := sp + TAU * k / 3.0
			ci.draw_line(Vector2(-2, 0), Vector2(-2, 0) + Vector2.from_angle(a) * 3.2, ink(0.5), 0.8, true)
		FastDraw.arc(ci, Vector2(5, 0), 5.5, -1.2, 1.2, 8, ink(0.45), 0.8, true)
	_band(ci, Vector2(10.6, -4.5), Vector2(10.6, 4.5), -2.4)
	for k in 4:
		var a := TAU * k / 4.0 + PI * 0.25
		var d := Vector2.from_angle(a)
		_pod(ci, d * 13.5, [Vector2(signf(d.x), 0), Vector2(0, signf(d.y))], lth, t, 0.85)
	_lamp(ci, Vector2(-7.5, -7.5), st, 1.4)


# ------------------------------------------------------------ cable layer

static func _cable(ci: CanvasItem, st: Dictionary, lth: Vector2) -> void:
	var t: float = st.t
	var ring := PackedVector2Array()
	for k in 12:
		ring.append(Vector2.from_angle(TAU * k / 12.0) * 12.5)
	_shape(ci, ring, HULL, ink(0.95), 1.4)
	# the reel: a drum of coiled cable, turning as it pays out
	var turn := float(st.get("reel", 0.0))
	FastDraw.circle(ci, Vector2.ZERO, 8.5, DARK)
	FastDraw.arc(ci, Vector2.ZERO, 8.5, 0.0, TAU, 18, ink(0.9), 1.2, true)
	if not Art.lite:
		for r in [6.8, 5.4, 4.0]:
			FastDraw.arc(ci, Vector2.ZERO, r, 0.0, TAU, 16, Color(0.42, 0.44, 0.48), 1.0, true)
		for k in 4:
			var a := turn + TAU * k / 4.0
			ci.draw_line(Vector2.from_angle(a) * 2.0, Vector2.from_angle(a) * 8.0, ink(0.55), 0.8, true)
	FastDraw.circle(ci, Vector2.ZERO, 2.0, HULL_HI)
	# the fairlead it pays out through, at the tail
	_box(ci, Rect2(-15.5, -2.2, 4, 4.4), HULL_HI, ink(0.9), 1.0)
	_band(ci, Vector2(11.5, -3.5), Vector2(11.5, 3.5), -2.0)
	for k in 4:
		var d := Vector2.from_angle(TAU * k / 4.0 + PI * 0.25)
		_pod(ci, d * 14.0, [Vector2(signf(d.x), 0), Vector2(0, signf(d.y))], lth, t, 0.8)
	_lamp(ci, Vector2(0, -10.5), st, 1.3)


# ------------------------------------------------------------ tester · commissioning

static func _tester(ci: CanvasItem, st: Dictionary, lth: Vector2) -> void:
	var t: float = st.t
	var hull := PackedVector2Array([Vector2(-13, 0), Vector2(-2, -8), Vector2(13, 0), Vector2(-2, 8)])
	_shape(ci, hull, HULL, ink(0.95), 1.4)
	# the aerial mast at the tail
	ci.draw_line(Vector2(-11, 0), Vector2(-20, -6), ink(0.8), 1.1, true)
	FastDraw.circle(ci, Vector2(-20, -6), 1.2, Color(st.lamp, 0.9))
	# the meter: five steps that fill as the work proves out
	var lit := clampf(float(st.get("busy", 0.0)), 0.0, 1.0)
	for k in 5:
		var on := lit * 5.0 > k + 0.3
		_box(ci, Rect2(-6.5 + k * 2.6, -1.4, 1.9, 2.8), Color(st.lamp, 0.95) if on else DARK, ink(0.5), 0.6)
	_band(ci, Vector2(6, -4.4), Vector2(11.2, -0.8), 1.6)
	_pod(ci, Vector2(-6, -9), [Vector2(-1, 0), Vector2(0, -1)], lth, t, 0.8)
	_pod(ci, Vector2(-6, 9), [Vector2(-1, 0), Vector2(0, 1)], lth, t, 0.8)
	_pod(ci, Vector2(7, -6.5), [Vector2(1, 0), Vector2(0, -1)], lth, t, 0.7)
	_pod(ci, Vector2(7, 6.5), [Vector2(1, 0), Vector2(0, 1)], lth, t, 0.7)


# ------------------------------------------------------------ the tool arm (world space)

# A two-link arm from the shoulder (world) to the work; the elbow bends up. Returns the tip (on the
# work when in reach). l: one link's length (px).
static func arm(ci: CanvasItem, sh: Vector2, to: Vector2, l: float, w: float) -> Vector2:
	var d := to - sh
	var dist := minf(d.length(), l * 1.96)
	var dir := d.normalized() if d.length() > 0.01 else Vector2.DOWN
	var tip := sh + dir * dist
	var h := sqrt(maxf(0.0, l * l - dist * dist * 0.25))
	var side := Vector2(-dir.y, dir.x)
	if side.y > 0.0:
		side = -side
	var elbow := sh + dir * dist * 0.5 + side * h
	ci.draw_line(sh, elbow, Color(0, 0, 0, 0.55), w + 2.0, true)
	ci.draw_line(elbow, tip, Color(0, 0, 0, 0.55), w + 1.6, true)
	ci.draw_line(sh, elbow, ink(0.9), w, true)
	ci.draw_line(elbow, tip, ink(0.85), w * 0.8, true)
	FastDraw.circle(ci, sh, w * 1.1, HULL_HI)
	FastDraw.arc(ci, sh, w * 1.1, 0.0, TAU, 10, ink(0.9), 0.9, true)
	FastDraw.circle(ci, elbow, w * 0.9, HULL_HI)
	FastDraw.arc(ci, elbow, w * 0.9, 0.0, TAU, 10, ink(0.9), 0.9, true)
	return tip


# the head at the tip, per trade; t its clock, k how hard it works (0..1)
static func head(ci: CanvasItem, role: String, tip: Vector2, from: Vector2, t: float, k: float, lamp: Color) -> void:
	var d := (tip - from).normalized() if tip.distance_to(from) > 0.1 else Vector2.DOWN
	var n := Vector2(-d.y, d.x)
	match role:
		"cutter":
			# the torch nozzle just off the work, its flame on it: a blue-white core in an orange cone
			var nz := tip - d * 5.0
			FastDraw.poly(ci, PackedVector2Array([nz - d * 4.0 + n * 2.0, nz + n * 1.2, nz - n * 1.2, nz - d * 4.0 - n * 2.0]), HULL_HI)
			Art.outline(ci, PackedVector2Array([nz - d * 4.0 + n * 2.0, nz + n * 1.2, nz - n * 1.2, nz - d * 4.0 - n * 2.0]), ink(0.9), 0.8)
			var fl := 0.8 + 0.2 * sin(t * 71.0)
			FastDraw.poly(ci, PackedVector2Array([nz + n * 2.4, tip + d * 2.0 * fl, nz - n * 2.4]), Pal.heat(0.75 * k, 2.2))
			FastDraw.poly(ci, PackedVector2Array([nz + n * 0.9, tip, nz - n * 0.9]), Color(0.8, 0.9, 1.6, 0.95 * k))
			FastDraw.circle(ci, tip, 4.5 * fl * k, Color(Pal.heat(1.0, 2.6), 0.55 * k))
		"torque":
			# the socket square on the bolt head, turning while it runs it home
			var a := t * 14.0 * k
			var hex := PackedVector2Array()
			for i in 6:
				hex.append(tip + Vector2.from_angle(a + TAU * i / 6.0) * 4.2)
			FastDraw.poly(ci, hex, HULL_HI)
			Art.outline(ci, hex, ink(0.95), 1.1)
			FastDraw.circle(ci, tip, 1.4, Color(lamp, 0.9))
		"cable":
			var plug := PackedVector2Array([tip - d * 5.0 + n * 2.2, tip + n * 2.2, tip - n * 2.2, tip - d * 5.0 - n * 2.2])
			FastDraw.poly(ci, plug, HULL_HI)
			Art.outline(ci, plug, ink(0.9), 0.9)
			ci.draw_line(tip + n * 1.0, tip + d * 2.0 + n * 1.0, ink(0.9), 0.8, true)
			ci.draw_line(tip - n * 1.0, tip + d * 2.0 - n * 1.0, ink(0.9), 0.8, true)
		"tester":
			ci.draw_line(tip - d * 4.0, tip, ink(0.95), 1.2, true)
			FastDraw.circle(ci, tip, 1.6 + 1.2 * k * (0.6 + 0.4 * sin(t * 9.0)), Color(lamp, 0.85))
		_:
			# a two-finger hand, shut on the handle while it works
			var o := 2.6 - 1.4 * k
			for s: float in [-1.0, 1.0]:
				ci.draw_line(tip - d * 2.5 + n * s * o, tip + d * 1.5 + n * s * (o - 0.8), ink(0.95), 1.3, true)
			FastDraw.circle(ci, tip - d * 2.5, 1.6, HULL_HI)
