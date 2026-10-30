extends RefCounted
# 109 号: the central transfer ring drawn as the machine it is, seen from above (user 2026-10-29:
# "优化中央转运区，变得更酷炫一点"; Q1 the carousel with its arms and the power gallery both). From the
# rim in: the hall's wall with its lamps; the shuttle's track bed; the service deck with a hatch and
# a transfer arm at each spoke; the ring main's cable tray and the coolant pipes round it; the safety
# stripe and bollards at the pit's edge; the carousel — twelve cradles on a slewing ring with its gear
# teeth inside — turning over the pit; the core: four drives on their mounts (two gone till the ring
# is mended), their pinions in the ring's teeth, the coolers, the lock pins, the bus ring and the slip
# ring at the very centre; and the feeder bridge from the power spoke over the carousel to the core.
# The still parts are one mesh per stage, drawn only when that changes; the carousel, the pinions, the
# fans, the slip ring's rotor, the pins, the hatches and the arms are meshes built once and placed
# each frame (scripts/mesh_pen.gd); the lights are an additive layer. Hub-local metres, the station's
# centre at 0 (scripts/hub_works.gd runs it).

const MeshPen = preload("res://scripts/mesh_pen.gd")
const W = preload("res://scripts/hub_works.gd")

const R_CORE := 7.6
const R_CAR_IN := 8.4
const R_CAR_OUT := 14.6
const R_SAFE := 15.25
const R_TRAY := 15.8
const R_DECK := 20.2
const R_WALL := 22.7
const R_OUT := 24.3
const DRIVES := [PI * 0.25, PI * 0.75, PI * 1.25, PI * 1.75]
const R_MOTOR := 5.55
const R_PINION := 7.82
const PINION_R := 0.5
const TEETH_R := 8.32          # the ring's teeth: their pitch circle, inside the inner rim
const PINS := [0.0, PI]        # the lock pins, at the core's rim
const COOLERS := [0.0, PI]

const FACE := Color(0.118, 0.124, 0.136)
const FACE2 := Color(0.15, 0.158, 0.172)
const DARK := Color(0.06, 0.064, 0.072)
const VOID := Color(0.022, 0.024, 0.028)
const DECK := Color(0.068, 0.072, 0.08)
const STEEL := Color(0.42, 0.44, 0.47)

var font: Font
var c := Vector2.ZERO  # the hub's centre, world px
var m := 1.0           # px a metre
var _meshes := {}


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


func _ink(a: float) -> Color:
	return Pal.ink(a)


func _p(v: Vector2) -> Vector2:
	return c + v * m


func _mesh(key: String, build: Callable) -> ArrayMesh:
	if not _meshes.has(key):
		var pen := MeshPen.new()
		build.call(pen)
		_meshes[key] = pen.mesh()
	return _meshes[key]


func _put(ci: CanvasItem, mesh: ArrayMesh, at: Vector2, rot := 0.0, mod := Color.WHITE, k := 1.0) -> void:
	ci.draw_mesh(mesh, null, Transform2D(rot, Vector2(m * k, m * k), 0.0, _p(at)), mod)


func _text(ci, at: Vector2, s: String, size_m: float, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width_m := -1.0) -> void:
	ci.draw_string(font, _p(at), s, align, width_m * m if width_m > 0.0 else -1.0, maxi(1, int(size_m * m)), col)


# the drives on their mounts at this stage: two till the ring is mended
static func has_drive(i: int, st: int) -> bool:
	return st >= 2 or i % 2 == 0


static func lamp_col(state: String, t: float) -> Color:
	match state:
		"ok": return Pal.tint(Pal.FLUID, 0.95, 1.3)
		"work": return Pal.heat(0.65 + 0.35 * absf(sin(t * 4.0)), 1.3)
		"warn": return Color(1.0, 0.3, 0.22, 0.6 + 0.4 * absf(sin(t * 2.5)))
	return Pal.ink(0.22)


# ---- pen helpers
func _box(p, at: Vector2, a: float, size: Vector2, col: Color, edge := Color(0, 0, 0, 0), ew := 0.05) -> void:
	var u := Vector2.from_angle(a)
	var v := u.orthogonal()
	var hx := u * size.x * 0.5
	var hy := v * size.y * 0.5
	var pts := PackedVector2Array([at - hx - hy, at + hx - hy, at + hx + hy, at - hx + hy])
	p.poly(pts, col)
	if edge.a > 0.0:
		p.polyline(pts, edge, ew, true)


# seven-segment figures, as stencilled on the carousel (text can't go in a mesh)
const SEG := {"0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc", "5": "afgcd", "6": "afgedc", "7": "abc", "8": "abcdefg", "9": "abcfgd"}
func _digits(p, s: String, at: Vector2, a: float, h: float, col: Color, lw: float) -> void:
	var u := Vector2.from_angle(a)
	var v := u.orthogonal()
	var cw := h * 0.55
	for i in s.length():
		var o := at + u * (i * cw * 1.45)
		var pt := {"tl": o, "tr": o + u * cw, "ml": o + v * h * 0.5, "mr": o + u * cw + v * h * 0.5, "bl": o + v * h, "br": o + u * cw + v * h}
		var segs := {"a": ["tl", "tr"], "b": ["tr", "mr"], "c": ["mr", "br"], "d": ["bl", "br"], "e": ["ml", "bl"], "f": ["tl", "ml"], "g": ["ml", "mr"]}
		for sg in str(SEG.get(s[i], "")):
			p.line(pt[segs[sg][0]], pt[segs[sg][1]], col, lw)


# a light's fall on the floor: a fan from bright to nothing (vertex colours; additive layer)
func _fan(p, apex: Vector2, pts: PackedVector2Array, ca: Color, ce: Color) -> void:
	for i in range(1, pts.size()):
		var n: int = p._v.size()
		p._v.append_array([p.xf * apex, p.xf * pts[i - 1], p.xf * pts[i]])
		p._c.append_array([ca, ce, ce])
		p._ix.append_array([n, n + 1, n + 2])


# ================================================================== the still parts
func _gaps() -> Array:
	var out: Array = []
	for z in W.spokes():
		out.append(float(W.spokes()[z]))
	return out


func _in_gap(a: float, r: float, half_m: float) -> bool:
	for g: float in _gaps():
		if absf(wrapf(a - g, -PI, PI)) < half_m / r:
			return true
	return false


func still_mesh(st: int) -> ArrayMesh:
	return _mesh("still%d" % st, func(p): _still(p, st))


func _still(p, st: int) -> void:
	var lit := st >= 1
	var sp := W.spokes()
	# the floor under everything (the station's own drawing of the hub lies under this)
	p.circle(Vector2.ZERO, R_OUT + 0.15, VOID, 120)
	# ---- the wall, open at each spoke; its ribs and the lamps on its face
	var n := 240
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var am := (a0 + a1) * 0.5
		if _in_gap(am, R_WALL, PortStructure.HALF + 0.3):
			continue
		p.arc(Vector2.ZERO, (R_WALL + R_OUT) * 0.5, a0, a1, Color(0.085, 0.09, 0.1), R_OUT - R_WALL, 1)
		p.arc(Vector2.ZERO, R_WALL + 0.05, a0, a1, _ink(0.42), 0.1, 1)
		p.arc(Vector2.ZERO, R_WALL + 0.45, a0, a1, _ink(0.1), 0.05, 1)
		p.arc(Vector2.ZERO, R_OUT - 0.05, a0, a1, _ink(0.18), 0.08, 1)
		if i % 4 == 0:
			var u := Vector2.from_angle(a0)
			p.line(u * (R_WALL + 0.5), u * (R_OUT - 0.1), _ink(0.12), 0.07)
	for z in sp:
		var g: float = sp[z]
		var u := Vector2.from_angle(g)
		var v := u.orthogonal()
		# the mouth's jambs and the corridor's threshold plate
		for s: float in [-1.0, 1.0]:
			var j := u * (R_WALL + R_OUT) * 0.5 + v * s * (PortStructure.HALF + 0.55)
			_box(p, j, g, Vector2(R_OUT - R_WALL + 0.4, 0.75), FACE2, _ink(0.45), 0.06)
		for k in 7:
			var q := u * (R_WALL + 0.2 + k * 0.28)
			p.line(q + v * (PortStructure.HALF - 0.1), q - v * (PortStructure.HALF - 0.1), _ink(0.09), 0.06)
	for i in 12:
		var a := TAU * i / 12.0 + PI / 12.0
		if _in_gap(a, R_WALL, PortStructure.HALF + 1.6):
			continue
		var u := Vector2.from_angle(a)
		_box(p, u * (R_WALL - 0.22), a, Vector2(0.44, 1.3), FACE2, _ink(0.5), 0.04)
		p.line(u * (R_WALL - 0.46) + u.orthogonal() * 0.5, u * (R_WALL - 0.46) - u.orthogonal() * 0.5, Color(0.92, 0.96, 1.0, 0.95) if lit else _ink(0.2), 0.08)
	# ---- the shuttle's track bed (the rails are scripts/tram.gd's)
	p.arc(Vector2.ZERO, (R_DECK + R_WALL) * 0.5, 0.0, TAU, Color(0.034, 0.037, 0.043), R_WALL - R_DECK, 160)
	p.arc(Vector2.ZERO, R_DECK, 0.0, TAU, _ink(0.22), 0.07, 160)
	# keep-clear dashes on the deck's edge
	for i in 96:
		if i % 2 == 0:
			p.arc(Vector2.ZERO, R_DECK - 0.25, TAU * i / 96.0, TAU * (i + 1) / 96.0, Pal.heat(0.32, 0.9), 0.12, 2)
	# ---- the service deck: plates, seams, bolts
	p.arc(Vector2.ZERO, (R_SAFE + R_DECK) * 0.5, 0.0, TAU, DECK, R_DECK - R_SAFE, 160)
	for i in 48:
		var a := TAU * i / 48.0
		var u := Vector2.from_angle(a)
		p.line(u * (R_SAFE + 1.45), u * (R_DECK - 0.45), Color(0.04, 0.043, 0.05), 0.05)
		p.line(u * (R_SAFE + 1.45) + u.orthogonal() * 0.05, u * (R_DECK - 0.45) + u.orthogonal() * 0.05, _ink(0.07), 0.025)
		for rr: float in [17.5, 19.3]:
			p.bolt(Vector2.from_angle(a + 0.012) * rr, 0.06, _ink(0.24))
	for rr: float in [17.0, 18.6]:
		p.arc(Vector2.ZERO, rr, 0.0, TAU, Color(0.04, 0.043, 0.05), 0.05, 160)
	# the carousel's way round, chevrons on the deck between the spokes
	for i in 12:
		var a := TAU * i / 12.0
		if _in_gap(a, 18.0, 3.4):
			continue
		var u := Vector2.from_angle(a)
		var v := u.orthogonal()
		var q := u * 18.0
		for k in 2:
			var o := q + v * (k * 0.55)
			p.polyline(PackedVector2Array([o + u * 0.45 - v * 0.25, o + v * 0.3, o - u * 0.45 - v * 0.25]), Pal.heat(0.22, 0.9), 0.1)
	# ---- the ring main: a ladder tray of power cables, two coolant pipes beside it
	p.arc(Vector2.ZERO, R_TRAY, 0.0, TAU, Color(0.045, 0.048, 0.055), 0.6, 160)
	p.arc(Vector2.ZERO, R_TRAY - 0.27, 0.0, TAU, _ink(0.34), 0.07, 160)
	p.arc(Vector2.ZERO, R_TRAY + 0.27, 0.0, TAU, _ink(0.34), 0.07, 160)
	for i in 100:
		var u := Vector2.from_angle(TAU * i / 100.0)
		p.line(u * (R_TRAY - 0.27), u * (R_TRAY + 0.27), _ink(0.16), 0.05)
	for k in 3:
		p.arc(Vector2.ZERO, R_TRAY - 0.13 + k * 0.13, 0.0, TAU, Pal.tint(Pal.VOLT, 0.16 if lit else 0.08, 0.9), 0.07, 160)
	for rr: float in [16.42, 16.72]:
		p.arc(Vector2.ZERO, rr, 0.0, TAU, Color(0.1, 0.112, 0.124), 0.2, 160)
		p.arc(Vector2.ZERO, rr - 0.07, 0.0, TAU, Pal.tint(Pal.AIR, 0.2, 1.0), 0.03, 160)
	for i in 72:
		var a := TAU * i / 72.0
		var u := Vector2.from_angle(a)
		p.line(u * 16.26, u * 16.88, _ink(0.32), 0.09)
	# taps: a junction box on the tray at each spoke, its cable out along the spoke to the wall
	for z in sp:
		var g: float = sp[z]
		var u := Vector2.from_angle(g)
		var v := u.orthogonal()
		var side := -1.0 if z == "power" else W.side_of(z)
		var jb := u * R_TRAY + W.across(g) * side * 2.3
		_box(p, jb, g, Vector2(1.0, 0.8), FACE2, _ink(0.5), 0.05)
		p.rect(Rect2(jb - Vector2(0.12, 0.12), Vector2(0.24, 0.24)), Pal.tint(Pal.VOLT, 0.5 if lit else 0.15, 1.0))
		var wcol := Pal.tint(Pal.VOLT, 0.3 if lit else 0.12, 0.95)
		if z == "power":
			# the feeder in from the power district: three heavy cores
			for k in 3:
				var o := v * (k - 1) * 0.28
				p.line(jb + u * 0.4 + o, u * (R_OUT + 0.2) + W.across(g) * side * 2.3 + o, wcol, 0.18)
		else:
			p.line(jb + u * 0.4, u * R_WALL + W.across(g) * side * 2.3, wcol, 0.12)
	# ---- the safety line at the pit's edge: stripes and bollards
	p.arc(Vector2.ZERO, R_CAR_OUT + 0.1, 0.0, TAU, VOID, 0.2, 160)
	for i in 160:
		var a0 := TAU * i / 160.0
		p.arc(Vector2.ZERO, (R_CAR_OUT + 0.2 + R_SAFE) * 0.5, a0, a0 + TAU / 160.0, Pal.heat(0.5, 0.9) if i % 2 == 0 else Color(0.05, 0.05, 0.055), R_SAFE - R_CAR_OUT - 0.2, 1)
	p.arc(Vector2.ZERO, R_SAFE, 0.0, TAU, _ink(0.36), 0.05, 160)
	for i in 36:
		var u := Vector2.from_angle(TAU * i / 36.0 + PI / 36.0)
		var q := u * (R_SAFE + 0.32)
		p.circle(q, 0.16, Color(0.05, 0.052, 0.058), 8)
		p.circle(q, 0.11, Pal.heat(0.55, 1.0), 8)
	# ---- the pit: dark, the support rollers' tracks in it, drain gratings
	p.arc(Vector2.ZERO, (R_CORE + R_CAR_OUT) * 0.5, 0.0, TAU, Color(0.03, 0.032, 0.037), R_CAR_OUT - R_CORE, 160)
	for rr: float in [8.75, 11.5, 14.2]:
		p.arc(Vector2.ZERO, rr, 0.0, TAU, Color(0.05, 0.053, 0.06), 0.3, 160)
		p.arc(Vector2.ZERO, rr, 0.0, TAU, _ink(0.08), 0.04, 160)
	for i in 24:
		var a := TAU * i / 24.0 + PI / 24.0
		for rr: float in [8.75, 14.2]:
			_box(p, Vector2.from_angle(a) * rr, a, Vector2(0.5, 0.9), Color(0.07, 0.074, 0.082), _ink(0.2), 0.03)
		var u := Vector2.from_angle(a)
		p.line(u * 9.4, u * 13.6, Color(0.04, 0.042, 0.048), 0.16)
	# ---- the core: the plinth, its rim
	p.circle(Vector2.ZERO, R_CORE, Color(0.058, 0.062, 0.07), 96)
	p.arc(Vector2.ZERO, R_CORE - 0.18, 0.0, TAU, FACE2, 0.36, 120)
	p.arc(Vector2.ZERO, R_CORE, 0.0, TAU, _ink(0.42), 0.06, 120)
	p.arc(Vector2.ZERO, R_CORE - 0.36, 0.0, TAU, _ink(0.16), 0.04, 120)
	for i in 36:
		p.bolt(Vector2.from_angle(TAU * i / 36.0) * (R_CORE - 0.18), 0.06, _ink(0.3))
	# deck seams on the plinth
	for i in 8:
		var u := Vector2.from_angle(TAU * i / 8.0 + PI / 8.0)
		p.line(u * 2.9, u * (R_CORE - 0.4), Color(0.04, 0.043, 0.05), 0.04)
	# ---- the bus ring round the slip ring: three bars on insulators, a tap to each drive
	for k in 3:
		p.arc(Vector2.ZERO, 3.15 + k * 0.26, 0.0, TAU, Pal.tint(Pal.VOLT, 0.42 if lit else 0.14, 1.0), 0.1, 96)
	for i in 18:
		var u := Vector2.from_angle(TAU * i / 18.0)
		_box(p, u * 3.41, TAU * i / 18.0, Vector2(0.86, 0.18), Color(0.17, 0.16, 0.14), _ink(0.4), 0.025)
	# the slip ring's stator and its brush holders
	p.arc(Vector2.ZERO, 2.35, 0.0, TAU, FACE2, 0.3, 64)
	p.arc(Vector2.ZERO, 2.5, 0.0, TAU, _ink(0.45), 0.04, 64)
	for i in 6:
		var a := TAU * i / 6.0
		var u := Vector2.from_angle(a)
		_box(p, u * 2.2, a, Vector2(0.75, 0.42), FACE, _ink(0.55), 0.04)
		p.line(u * 2.5, u * 3.15, Pal.tint(Pal.VOLT, 0.3 if lit else 0.1, 1.0), 0.07)
	# ---- the drives: a mount each; a motor and its gearbox on it, or the bolts it stood on
	for i in DRIVES.size():
		var a: float = DRIVES[i]
		var u := Vector2.from_angle(a)
		var v := u.orthogonal()
		_box(p, u * 5.9, a, Vector2(3.6, 3.0), Color(0.08, 0.084, 0.094), _ink(0.28), 0.05)
		for s: Vector2 in [Vector2(-1.45, -1.15), Vector2(1.45, -1.15), Vector2(-1.45, 1.15), Vector2(1.45, 1.15)]:
			p.bolt(u * (5.9 + s.x) + v * s.y, 0.11, _ink(0.42))
		if has_drive(i, st):
			# gearbox to the pinion
			_box(p, u * 7.0, a, Vector2(1.5, 1.35), Color(0.11, 0.116, 0.128), _ink(0.45), 0.05)
			p.line(u * 6.35 + v * 0.55, u * 7.65 + v * 0.55, _ink(0.2), 0.04)
			p.line(u * 6.35 - v * 0.55, u * 7.65 - v * 0.55, _ink(0.2), 0.04)
			# the motor, standing: a finned drum and its fan cowl
			p.circle(u * R_MOTOR, 1.12, Color(0.1, 0.106, 0.118), 28)
			for f in 28:
				var fu := Vector2.from_angle(TAU * f / 28.0)
				p.line(u * R_MOTOR + fu * 0.86, u * R_MOTOR + fu * 1.16, _ink(0.3), 0.05)
			p.circle(u * R_MOTOR, 0.86, Color(0.03, 0.032, 0.036), 24)
			p.ring(u * R_MOTOR, 0.86, _ink(0.5), 0.05, 24)
			# the terminal box and the cable from the bus ring
			_box(p, u * R_MOTOR - v * 1.2, a, Vector2(0.7, 0.5), FACE2, _ink(0.45), 0.03)
			p.line(u * 3.7 - v * 0.4, u * R_MOTOR - v * 1.2, Pal.tint(Pal.VOLT, 0.3 if lit else 0.1, 1.0), 0.1)
		else:
			# gone: four bolt holes, the cables cut off
			for s: Vector2 in [Vector2(-0.8, -0.8), Vector2(0.8, -0.8), Vector2(-0.8, 0.8), Vector2(0.8, 0.8)]:
				p.circle(u * (R_MOTOR + s.x) + v * s.y, 0.13, Color(0.02, 0.02, 0.024), 8)
			p.ring(u * R_MOTOR, 1.12, Color(0.13, 0.13, 0.14, 0.6), 0.04, 28)
			p.line(u * 3.7 - v * 0.4, u * 4.65 - v * 0.9, Pal.tint(Pal.VOLT, 0.12, 0.8), 0.1)
			p.line(u * 4.65 - v * 0.9, u * 4.75 - v * 1.05, Pal.heat(0.45, 1.0), 0.08)
	# ---- the coolers (with the ring mended), or the capped pipe stubs they will hang on
	for a: float in COOLERS:
		var u := Vector2.from_angle(a)
		var v := u.orthogonal()
		if st >= 2:
			_box(p, u * 5.4, a, Vector2(2.3, 2.6), Color(0.09, 0.095, 0.105), _ink(0.4), 0.05)
			for k in 9:
				var o := v * (-1.1 + k * 0.275)
				p.line(u * 4.35 + o, u * 6.45 + o, _ink(0.2), 0.04)
			p.circle(u * 5.4, 0.92, Color(0.03, 0.032, 0.036), 24)
			p.ring(u * 5.4, 0.92, _ink(0.45), 0.05, 24)
			for s: float in [-1.0, 1.0]:
				p.line(u * 4.2 + v * s * 0.9, Vector2.from_angle(a + s * PI * 0.25) * 4.5, Pal.tint(Pal.AIR, 0.35, 1.0), 0.12)
		else:
			for s: float in [-1.0, 1.0]:
				p.line(Vector2.from_angle(a + s * PI * 0.25) * 4.5, u * 4.9 + v * s * 0.6, Pal.tint(Pal.AIR, 0.18, 0.9), 0.12)
				p.circle(u * 4.9 + v * s * 0.6, 0.12, Pal.heat(0.4, 1.0), 8)
			p.rect(Rect2(u * 5.4 - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), Color(0.13, 0.13, 0.14, 0.5), false, 0.04)
	# ---- the lock pins' housings at the rim
	for a: float in PINS:
		var u := Vector2.from_angle(a)
		_box(p, u * 7.05, a, Vector2(1.1, 0.95), FACE2, _ink(0.5), 0.05)
		p.line(u * 6.55 + u.orthogonal() * 0.3, u * 7.55 + u.orthogonal() * 0.3, Pal.heat(0.4, 1.0), 0.05)
	# ---- the switchgear where the feeder lands (the power spoke) and the control cabinet opposite
	var gp := float(sp.get("power", -PI * 0.5))
	var ug := Vector2.from_angle(gp)
	_box(p, ug * 5.6, gp, Vector2(2.4, 3.0), Color(0.1, 0.106, 0.118), _ink(0.5), 0.06)
	for k in 3:
		var o := ug.orthogonal() * (-0.95 + k * 0.95)
		_box(p, ug * 5.6 + o, gp, Vector2(1.9, 0.75), Color(0.07, 0.074, 0.082), _ink(0.3), 0.03)
	var uc := -ug
	_box(p, uc * 5.6, gp + PI, Vector2(2.2, 3.4), Color(0.1, 0.106, 0.118), _ink(0.5), 0.06)
	_box(p, uc * 5.75, gp + PI, Vector2(1.25, 2.6), Color(0.04, 0.07, 0.085), _ink(0.35), 0.04)
	# ---- at each spoke but the power one: the hatch's frame and the arm's plinth
	for z in sp:
		if z == "power":
			continue
		var g: float = sp[z]
		var h := W.hatch_at(z)
		_box(p, h, g, Vector2(4.0, 4.0), Color(0.05, 0.05, 0.055))
		var hr := 1.85
		var u := Vector2.from_angle(g)
		var v := u.orthogonal()
		# hazard border
		for k in 16:
			var f := (k + 0.5) / 16.0 * 4.0 - 2.0
			if k % 2 == 0:
				for s: float in [-1.0, 1.0]:
					p.line(h + u * f * 0.92 + v * s * 1.88, h + u * (f + 0.25) * 0.92 + v * s * 1.88, Pal.heat(0.55, 0.9), 0.2)
					p.line(h + v * f * 0.92 + u * s * 1.88, h + v * (f + 0.25) * 0.92 + u * s * 1.88, Pal.heat(0.55, 0.9), 0.2)
		_box(p, h, g, Vector2(hr * 2.0, hr * 2.0), Color(0, 0, 0, 0), _ink(0.5), 0.12)
		_box(p, h, g, Vector2(3.2, 3.2), Color(0.018, 0.02, 0.024), _ink(0.25), 0.05)
		var b := W.base_at(z)
		var oct := PackedVector2Array()
		for k in 8:
			oct.append(b + Vector2.from_angle(TAU * k / 8.0 + PI / 8.0) * 1.3)
		p.poly(oct, Color(0.09, 0.094, 0.104))
		p.polyline(oct, _ink(0.38), 0.06, true)
		for k in 8:
			p.bolt(b + Vector2.from_angle(TAU * k / 8.0) * 1.08, 0.07, _ink(0.38))
		# the arm's conduit from the tray
		p.line(b + (Vector2.ZERO - b).normalized() * 1.3, (b.normalized()) * (R_TRAY + 0.3), Pal.tint(Pal.VOLT, 0.22 if lit else 0.08, 0.9), 0.1)


# the bridge from the power spoke over the carousel to the core, its cable tray on top
func bridge_mesh(st: int) -> ArrayMesh:
	return _mesh("bridge%d" % st, func(p): _bridge(p, st))


func _bridge(p, st: int) -> void:
	var lit := st >= 1
	var g := float(W.spokes().get("power", -PI * 0.5))
	var u := Vector2.from_angle(g)
	var v := u.orthogonal()
	var r0 := 6.6
	var r1 := R_SAFE + 0.6
	# piers
	for rr: float in [R_CORE - 0.2, R_SAFE - 0.1]:
		_box(p, u * rr, g, Vector2(0.8, 3.1), Color(0.1, 0.106, 0.118), _ink(0.45), 0.05)
	# the deck grating, then the chords and the web over it
	_box(p, u * (r0 + r1) * 0.5, g, Vector2(r1 - r0, 2.2), Color(0.05, 0.053, 0.06, 0.55))
	var x := r0
	while x < r1:
		p.line(u * x + v * 1.0, u * x - v * 1.0, _ink(0.08), 0.03)
		x += 0.25
	for s: float in [-1.0, 1.0]:
		p.line(u * r0 + v * s * 1.1, u * r1 + v * s * 1.1, Color(0.16, 0.168, 0.184), 0.26)
		p.line(u * r0 + v * s * 1.24, u * r1 + v * s * 1.24, _ink(0.48), 0.04)
	x = r0
	var flip := 1.0
	while x + 1.5 <= r1:
		p.line(u * x + v * 1.05 * flip, u * (x + 1.5) - v * 1.05 * flip, Color(0.13, 0.136, 0.15), 0.12)
		p.line(u * (x + 1.5) + v * 1.1, u * (x + 1.5) - v * 1.1, Color(0.13, 0.136, 0.15), 0.1)
		x += 1.5
		flip = -flip
	# the tray down its middle: the feeder's three cores
	_box(p, u * (r0 + r1) * 0.5, g, Vector2(r1 - r0 + 0.6, 0.8), Color(0.06, 0.063, 0.07), _ink(0.4), 0.04)
	for k in 3:
		p.line(u * (r0 - 0.3) + v * (k - 1) * 0.22, u * (r1 + 0.3) + v * (k - 1) * 0.22, Pal.tint(Pal.VOLT, 0.42 if lit else 0.14, 1.0), 0.11)
	# the walkway's lamp posts
	for rr: float in [9.0, 12.0, 15.0]:
		for s: float in [-1.0, 1.0]:
			p.circle(u * rr + v * s * 1.24, 0.12, _ink(0.6), 8)


# ================================================================== the moving parts
func carousel_mesh() -> ArrayMesh:
	return _mesh("carousel", _carousel)


func _carousel(p) -> void:
	# the inner rim with its gear teeth (the drives' pinions run in them)
	p.arc(Vector2.ZERO, (R_CAR_IN + 9.15) * 0.5, 0.0, TAU, FACE2, 9.15 - R_CAR_IN, 120)
	var nt := 132
	for i in nt:
		var a := TAU * (i + 0.5) / nt
		var u := Vector2.from_angle(a)
		var v := u.orthogonal()
		var hw := PI * R_CAR_IN / nt * 0.55
		p.poly(PackedVector2Array([u * R_CAR_IN - v * hw, u * R_CAR_IN + v * hw, u * (TEETH_R - 0.2) + v * hw * 0.55, u * (TEETH_R - 0.2) - v * hw * 0.55]), Color(0.13, 0.136, 0.15))
	p.arc(Vector2.ZERO, R_CAR_IN + 0.02, 0.0, TAU, _ink(0.3), 0.04, 120)
	p.arc(Vector2.ZERO, 9.15, 0.0, TAU, _ink(0.38), 0.05, 120)
	# the outer rim, its running-light sockets
	p.arc(Vector2.ZERO, (13.85 + R_CAR_OUT) * 0.5, 0.0, TAU, FACE2, R_CAR_OUT - 13.85, 160)
	p.arc(Vector2.ZERO, R_CAR_OUT - 0.02, 0.0, TAU, _ink(0.5), 0.06, 160)
	p.arc(Vector2.ZERO, 13.85, 0.0, TAU, _ink(0.3), 0.04, 160)
	for i in 48:
		var a := TAU * (i + 0.5) / 48.0
		_box(p, Vector2.from_angle(a) * 14.22, a, Vector2(0.22, 0.4), Color(0.03, 0.03, 0.035))
	for i in 96:
		var a := TAU * i / 96.0
		if i % 2 == 1:
			p.bolt(Vector2.from_angle(a) * 14.0, 0.05, _ink(0.32))
			p.bolt(Vector2.from_angle(a) * 8.85, 0.05, _ink(0.32))
	# the lock pins' sockets in the inner rim, one at every index
	for k in W.SLOTS:
		var a := k * W.PITCH
		_box(p, Vector2.from_angle(a) * 8.75, a, Vector2(0.5, 0.42), Color(0.02, 0.02, 0.024), _ink(0.4), 0.03)
	# the girders between the cradles: box beams with lightening holes
	for k in W.SLOTS:
		var a := k * W.PITCH + W.PITCH * 0.5
		var u := Vector2.from_angle(a)
		var v := u.orthogonal()
		_box(p, u * 11.5, a, Vector2(4.8, 0.64), Color(0.095, 0.1, 0.11), _ink(0.26), 0.04)
		p.line(u * 9.2, u * 13.8, _ink(0.1), 0.03)
		for rr: float in [10.2, 11.5, 12.8]:
			p.circle(u * rr, 0.17, Color(0.03, 0.032, 0.036), 10)
		for s: float in [-1.0, 1.0]:
			p.line(u * 9.15 + v * s * 0.32, u * 9.6 + v * s * 1.0, Color(0.11, 0.116, 0.128), 0.12)
			p.line(u * 13.85 + v * s * 0.32, u * 13.4 + v * s * 1.0, Color(0.11, 0.116, 0.128), 0.12)
	# the cradles: a deck, its ribs, the guide horns and twistlocks at the corners, its number
	for k in W.SLOTS:
		var a := k * W.PITCH
		var u := Vector2.from_angle(a)
		var v := u.orthogonal()
		var ctr := u * W.R_CRADLE
		_box(p, ctr, a, Vector2(4.1, 4.5), Color(0.074, 0.078, 0.087), _ink(0.2), 0.04)
		for x: float in [-1.2, 0.0, 1.2]:
			p.line(ctr + u * x - v * 2.2, ctr + u * x + v * 2.2, Color(0.05, 0.053, 0.06), 0.1)
		for s: float in [-1.0, 1.0]:
			p.line(ctr - u * 2.05 + v * s * 2.25, ctr + u * 2.05 + v * s * 2.25, _ink(0.32), 0.1)
		for cx: float in [-1.0, 1.0]:
			for cy: float in [-1.0, 1.0]:
				var q := ctr + u * cx * 1.85 + v * cy * 1.62
				p.polyline(PackedVector2Array([q - u * cx * 0.55, q + u * cx * 0.08 + v * cy * 0.08, q - v * cy * 0.55]), _ink(0.34), 0.09)
				p.rect(Rect2(q - Vector2(0.11, 0.11) - (u * cx + v * cy) * 0.2, Vector2(0.22, 0.22)), Color(0.02, 0.02, 0.024))
		_digits(p, "%02d" % (k + 1), ctr - u * 1.55 + v * 1.95, a - PI * 0.5, 0.42, _ink(0.42), 0.06)


func pinion_mesh() -> ArrayMesh:
	return _mesh("pinion", func(p):
		p.circle(Vector2.ZERO, PINION_R - 0.06, Color(0.16, 0.168, 0.184), 16)
		for i in 12:
			var u := Vector2.from_angle(TAU * i / 12.0)
			var v := u.orthogonal()
			p.poly(PackedVector2Array([u * (PINION_R - 0.08) - v * 0.09, u * (PINION_R - 0.08) + v * 0.09, u * (PINION_R + 0.12) + v * 0.05, u * (PINION_R + 0.12) - v * 0.05]), Color(0.16, 0.168, 0.184))
		p.ring(Vector2.ZERO, 0.2, _ink(0.5), 0.05, 12)
		p.line(Vector2(-0.2, 0), Vector2(0.2, 0), _ink(0.45), 0.05))


func fan_mesh(r: float) -> ArrayMesh:
	return _mesh("fan%.2f" % r, func(p):
		for i in 5:
			var a := TAU * i / 5.0
			var u := Vector2.from_angle(a)
			var v := u.orthogonal()
			p.poly(PackedVector2Array([u * 0.12 - v * 0.06, u * r * 0.95 - v * 0.05, u * r * 0.9 + v * r * 0.32, u * 0.12 + v * 0.1]), Color(0.2, 0.21, 0.23))
		p.circle(Vector2.ZERO, r * 0.2, Color(0.12, 0.126, 0.14), 10)
		# the cowl's guard over the blades
		for k in 3:
			p.ring(Vector2.ZERO, r * (0.42 + k * 0.22), Color(0.3, 0.31, 0.33, 0.45), 0.025, 20)
		for k in 6:
			var u := Vector2.from_angle(TAU * k / 6.0)
			p.line(u * r * 0.2, u * r, Color(0.3, 0.31, 0.33, 0.45), 0.025))


func rotor_mesh() -> ArrayMesh:
	return _mesh("rotor", func(p):
		p.circle(Vector2.ZERO, 2.05, Color(0.07, 0.074, 0.082), 40)
		for k in 4:
			p.ring(Vector2.ZERO, 0.75 + k * 0.33, Color(0.42, 0.26, 0.15), 0.1, 40)
			p.ring(Vector2.ZERO, 0.75 + k * 0.33 + 0.07, Color(0.62, 0.42, 0.26), 0.025, 40)
		p.circle(Vector2.ZERO, 0.52, Color(0.13, 0.136, 0.15), 24)
		for i in 8:
			p.bolt(Vector2.from_angle(TAU * i / 8.0) * 0.36, 0.05, _ink(0.5))
		# the cable arms out to the carousel's spokes
		for i in 3:
			var u := Vector2.from_angle(TAU * i / 3.0)
			p.line(u * 0.5, u * 2.0, _ink(0.35), 0.08))


func pin_mesh() -> ArrayMesh:
	return _mesh("pin", func(p):
		p.rect(Rect2(-0.32, -0.17, 0.64, 0.34), Color(0.36, 0.37, 0.4))
		p.rect(Rect2(0.28, -0.17, 0.06, 0.34), Pal.heat(0.7, 1.1)))


# the hatch's two leaves, each sliding out sideways (local: x along the spoke, y across)
func leaf_mesh() -> ArrayMesh:
	return _mesh("leaf", func(p):
		p.rect(Rect2(-1.55, 0.0, 3.1, 1.55), Color(0.11, 0.116, 0.128))
		p.rect(Rect2(-1.55, 0.0, 3.1, 1.55), _ink(0.4), false, 0.05)
		for k in 6:
			p.line(Vector2(-1.4 + k * 0.56, 0.12), Vector2(-1.4 + k * 0.56, 1.42), Color(0.07, 0.074, 0.082), 0.06)
		p.line(Vector2(-1.55, 1.5), Vector2(1.55, 1.5), Pal.heat(0.55, 1.0), 0.07))


func lift_mesh() -> ArrayMesh:
	return _mesh("lift", func(p):
		p.rect(Rect2(-1.5, -1.5, 3.0, 3.0), Color(0.1, 0.106, 0.118))
		for k in 7:
			p.line(Vector2(-1.4, -1.2 + k * 0.4), Vector2(1.4, -1.2 + k * 0.4), _ink(0.16), 0.08)
		p.rect(Rect2(-1.5, -1.5, 3.0, 3.0), _ink(0.35), false, 0.06))


# ---- the goods, seen from above, by what they are (Warehouse.use_of); x along the cradle
func goods_mesh(use: String) -> ArrayMesh:
	return _mesh("goods_" + use, func(p): _goods(p, use))


func _goods(p, use: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(use)
	match use:
		"ingot":
			# a pallet of ingots, three rows of four, bevelled tops
			p.rect(Rect2(-1.75, -1.45, 3.5, 2.9), Color(0.14, 0.12, 0.09))
			for ix in 4:
				for iy in 3:
					var q := Vector2(-1.32 + ix * 0.88, -0.96 + iy * 0.96)
					p.rect(Rect2(q - Vector2(0.4, 0.42), Vector2(0.8, 0.84)), Color(0.3, 0.31, 0.33))
					p.rect(Rect2(q - Vector2(0.28, 0.3), Vector2(0.56, 0.6)), Color(0.46, 0.47, 0.5))
		"scrap", "nonferrous":
			# a skip of loose metal
			var tone := Color(0.55, 0.38, 0.22) if use == "nonferrous" else Color(0.4, 0.4, 0.43)
			p.poly(PackedVector2Array([Vector2(-1.8, -1.5), Vector2(1.8, -1.5), Vector2(1.8, 1.5), Vector2(-1.8, 1.5)]), Color(0.2, 0.17, 0.12))
			p.rect(Rect2(-1.55, -1.25, 3.1, 2.5), Color(0.08, 0.075, 0.07))
			for i in 26:
				var q := Vector2(rng.randf_range(-1.35, 1.35), rng.randf_range(-1.05, 1.05))
				var pts := PackedVector2Array()
				var nv := rng.randi_range(3, 5)
				var rr := rng.randf_range(0.16, 0.42)
				for k in nv:
					pts.append(q + Vector2.from_angle(TAU * k / nv + rng.randf() * 0.6) * rr * rng.randf_range(0.6, 1.0))
				var sh := rng.randf_range(0.6, 1.1)
				p.poly(pts, Color(tone.r * sh, tone.g * sh, tone.b * sh))
			p.rect(Rect2(-1.8, -1.5, 3.6, 3.0), Pal.heat(0.4, 0.9), false, 0.08)
		"billet":
			# a bundle of long square bars, strapped
			p.rect(Rect2(-1.85, -1.3, 3.7, 2.6), Color(0.05, 0.05, 0.055))
			for iy in 5:
				var y := -1.08 + iy * 0.54
				p.rect(Rect2(-1.8, y - 0.23, 3.6, 0.46), Color(0.33, 0.34, 0.36))
				p.line(Vector2(-1.8, y - 0.12), Vector2(1.8, y - 0.12), Color(0.48, 0.49, 0.52), 0.06)
			for x: float in [-1.1, 0.0, 1.1]:
				p.line(Vector2(x, -1.3), Vector2(x, 1.3), Pal.tint(Pal.AIR, 0.5, 0.9), 0.07)
		"stock":
			# plate in a stack, each sheet a little off the last, chalk marks
			for k in 3:
				var o := Vector2(k * 0.08, k * 0.07)
				p.rect(Rect2(Vector2(-1.75, -1.35) + o, Vector2(3.4, 2.6)), Color(0.24 + k * 0.05, 0.25 + k * 0.05, 0.27 + k * 0.05))
				p.rect(Rect2(Vector2(-1.75, -1.35) + o, Vector2(3.4, 2.6)), _ink(0.3), false, 0.03)
			p.line(Vector2(-1.0, -0.6), Vector2(0.4, -0.6), Color(0.9, 0.9, 0.85, 0.6), 0.06)
			p.line(Vector2(-1.0, -0.35), Vector2(-0.2, -0.35), Color(0.9, 0.9, 0.85, 0.6), 0.06)
		"hazard":
			# a tank in its frame
			p.rect(Rect2(-1.8, -1.4, 3.6, 2.8), Color(0.08, 0.084, 0.094))
			p.rect(Rect2(-1.8, -1.4, 3.6, 2.8), _ink(0.45), false, 0.1)
			p.rect(Rect2(-1.45, -1.05, 2.9, 2.1), Color(0.3, 0.31, 0.33))
			p.circle(Vector2(-1.45, 0), 1.05, Color(0.3, 0.31, 0.33), 16)
			p.circle(Vector2(1.45, 0), 1.05, Color(0.3, 0.31, 0.33), 16)
			p.line(Vector2(-1.45, -0.6), Vector2(1.45, -0.6), Color(0.42, 0.43, 0.46), 0.14)
			p.poly(PackedVector2Array([Vector2(0, -0.45), Vector2(0.45, 0), Vector2(0, 0.45), Vector2(-0.45, 0)]), Pal.heat(0.85, 1.1))
		_:
			# a box container, corrugated, its corner castings, a band in the district's colour
			p.rect(Rect2(-1.8, -1.45, 3.6, 2.9), Color(0.2, 0.21, 0.23) if use != "parts" else Color(0.17, 0.2, 0.22))
			for k in 15:
				var x := -1.6 + k * 0.23
				p.line(Vector2(x, -1.35), Vector2(x, 1.35), Color(0.13, 0.14, 0.155), 0.07)
			p.rect(Rect2(-1.8, -1.45, 3.6, 2.9), _ink(0.45), false, 0.06)
			for cx: float in [-1.0, 1.0]:
				for cy: float in [-1.0, 1.0]:
					p.rect(Rect2(Vector2(cx * 1.66, cy * 1.31) - Vector2(0.14, 0.14), Vector2(0.28, 0.28)), Color(0.06, 0.06, 0.065))
			p.rect(Rect2(1.2, -1.45, 0.24, 2.9), Pal.tint(Pal.AIR, 0.55, 1.0) if use == "parts" else Pal.heat(0.5, 1.0))


func shadow_mesh() -> ArrayMesh:
	return _mesh("shadow", func(p): p.rect(Rect2(-1.9, -1.55, 3.8, 3.1), Color(0, 0, 0, 0.42)))


# ---- the transfer arm: the turret, the two links, the spreader
func turret_mesh() -> ArrayMesh:
	return _mesh("turret", func(p):
		p.circle(Vector2.ZERO, 0.95, Color(0.15, 0.158, 0.172), 24)
		p.ring(Vector2.ZERO, 0.95, _ink(0.55), 0.06, 24)
		p.rect(Rect2(-0.7, -0.62, 0.9, 1.24), Color(0.1, 0.106, 0.118))
		p.rect(Rect2(-0.7, -0.62, 0.9, 1.24), _ink(0.35), false, 0.04)
		for k in 4:
			p.line(Vector2(-0.6 + k * 0.22, -0.5), Vector2(-0.6 + k * 0.22, 0.5), _ink(0.2), 0.04)
		p.circle(Vector2.ZERO, 0.42, Color(0.2, 0.21, 0.23), 16)
		p.ring(Vector2.ZERO, 0.42, _ink(0.6), 0.04, 16))


func link_mesh(l: float, w0: float, w1: float) -> ArrayMesh:
	return _mesh("link%.1f" % l, func(p):
		p.poly(PackedVector2Array([Vector2(0, -w0 * 0.5), Vector2(l, -w1 * 0.5), Vector2(l, w1 * 0.5), Vector2(0, w0 * 0.5)]), Color(0.17, 0.178, 0.194))
		p.polyline(PackedVector2Array([Vector2(0, -w0 * 0.5), Vector2(l, -w1 * 0.5), Vector2(l, w1 * 0.5), Vector2(0, w0 * 0.5)]), _ink(0.6), 0.05, true)
		p.line(Vector2(0.3, 0), Vector2(l - 0.3, 0), _ink(0.22), 0.04)
		# the hydraulic ram along its side, its rod polished
		p.line(Vector2(0.4, -w0 * 0.5 - 0.1), Vector2(l * 0.6, -w1 * 0.5 - 0.1), Color(0.1, 0.106, 0.118), 0.16)
		p.line(Vector2(l * 0.6, -w1 * 0.5 - 0.1), Vector2(l * 0.85, -w1 * 0.5 - 0.1), Pal.tint(Pal.AIR, 0.6, 1.1), 0.06)
		# hazard bands at the joint
		for k in 3:
			p.line(Vector2(l - 0.55 + k * 0.16, -w1 * 0.5), Vector2(l - 0.45 + k * 0.16, w1 * 0.5), Pal.heat(0.6, 1.0), 0.06)
		p.circle(Vector2(l, 0), w1 * 0.62, Color(0.2, 0.21, 0.23), 16)
		p.ring(Vector2(l, 0), w1 * 0.62, _ink(0.6), 0.04, 16)
		p.circle(Vector2(l, 0), w1 * 0.22, Color(0.04, 0.04, 0.045), 10))


func spreader_mesh() -> ArrayMesh:
	return _mesh("spreader", func(p):
		# the frame over a crate's top, a beam across, a twistlock at each corner
		var hx := 1.85
		var hy := 1.55
		p.rect(Rect2(-hx, -hy, hx * 2.0, hy * 2.0), Color(0.19, 0.2, 0.22), false, 0.2)
		p.rect(Rect2(-hx - 0.1, -hy - 0.1, hx * 2.0 + 0.2, hy * 2.0 + 0.2), _ink(0.5), false, 0.04)
		p.line(Vector2(0, -hy), Vector2(0, hy), Color(0.19, 0.2, 0.22), 0.34)
		p.line(Vector2(-0.6, -0.2), Vector2(0.6, -0.2), Color(0.12, 0.126, 0.14), 0.25)
		p.circle(Vector2.ZERO, 0.32, Color(0.24, 0.25, 0.27), 14)
		for cx: float in [-1.0, 1.0]:
			for cy: float in [-1.0, 1.0]:
				p.rect(Rect2(Vector2(cx * hx, cy * hy) - Vector2(0.2, 0.2), Vector2(0.4, 0.4)), Color(0.24, 0.25, 0.27))
		for k in 4:
			p.line(Vector2(-hx + 0.3 + k * 0.2, -hy), Vector2(-hx + 0.4 + k * 0.2, -hy + 0.22), Pal.heat(0.6, 1.0), 0.05))


# ================================================================== the passes
func _frame(ci: CanvasItem) -> void:
	# the layer's bounds round the hub (a draw_mesh alone is culled by its untransformed box)
	ci.draw_rect(Rect2(_p(Vector2(-R_OUT, -R_OUT)), Vector2(R_OUT, R_OUT) * 2.0 * m), Color(0, 0, 0, 0), false, 1.0)


func still(ci: CanvasItem, st: int) -> void:
	_frame(ci)
	_put(ci, still_mesh(st), Vector2.ZERO)


# on the floor and the carousel: everything under the bridge and the arms
func back(ci: CanvasItem, t: float) -> void:
	_frame(ci)
	var st := W.stage
	var th := W.theta
	# the slip ring's rotor turns with the carousel
	_put(ci, rotor_mesh(), Vector2.ZERO, th)
	# the carousel
	_put(ci, carousel_mesh(), Vector2.ZERO, th)
	# what the cradles hold
	for k in W.SLOTS:
		var pc = W.cradles[k] if k < W.cradles.size() else null
		var a := th + k * W.PITCH
		if pc != null:
			_put(ci, goods_mesh(str(pc.use)), Vector2.from_angle(a) * W.R_CRADLE, a)
	if st == 0:
		# the crate knocked askew when the ring died, one corner over the cradle's rail
		var a := th + W.ASKEW * W.PITCH
		var u := Vector2.from_angle(a)
		_put(ci, goods_mesh("misc"), u * (W.R_CRADLE + 0.55) + u.orthogonal() * 0.7, a + 0.21)
	# the drives' pinions in the ring's teeth, their fans; the coolers' fans
	var spin := th * (TEETH_R / PINION_R)
	for i in DRIVES.size():
		if not has_drive(i, st):
			continue
		var u := Vector2.from_angle(DRIVES[i])
		_put(ci, pinion_mesh(), u * R_PINION, spin)
		_put(ci, fan_mesh(0.84), u * R_MOTOR, spin * 9.0)
	if st >= 2:
		for a: float in COOLERS:
			_put(ci, fan_mesh(0.9), Vector2.from_angle(a) * 5.4, t * 9.0 + a)
	# the lock pins
	for a: float in PINS:
		_put(ci, pin_mesh(), Vector2.from_angle(a) * (7.15 + 0.55 * W.pins), a)
	# each hatch: its lift (and what stands on it) under the two leaves
	for z in W.spokes():
		if z == "power":
			continue
		var g: float = W.spokes()[z]
		var hp := W.hatch_at(z)
		var hz := W._hatch(z)
		var lift := float(hz.lift)
		var doors := float(hz.doors)
		if doors > 0.02:
			var shade := lerpf(0.35, 1.0, lift)
			_put(ci, lift_mesh(), hp, g, Color(shade, shade, shade), 0.86 + 0.14 * lift)
			if hz.parcel != null:
				_put(ci, goods_mesh(str(hz.parcel.use)), hp, g, Color(shade, shade, shade), (0.86 + 0.14 * lift) * 0.82)
		var v := Vector2.from_angle(g).orthogonal()
		var slide := 1.5 * doors
		_put(ci, leaf_mesh(), hp + v * (0.05 + slide), g)
		_put(ci, leaf_mesh(), hp - v * (0.05 + slide), g + PI)


# over the carousel: the arms and their loads, the bridge
func front(ci: CanvasItem, t: float) -> void:
	_frame(ci)
	var st := W.stage
	for z in W.spokes():
		if z == "power":
			continue
		var a := W._arm(z)
		var b := W.base_at(z)
		var e := W.elbow_at(z)
		var wr := W.wrist(z)
		var h := float(a.h)
		var k := 1.0 + 0.07 * h
		# the load and its shadow (higher, further from it)
		if a.parcel != null:
			_put(ci, shadow_mesh(), wr + Vector2(0.35, 0.5) * (0.3 + h), float(a.yaw))
			_put(ci, goods_mesh(str(a.parcel.use)), wr, float(a.yaw), Color.WHITE, k * 0.98)
		_put(ci, turret_mesh(), b, float(a.q1))
		_put(ci, link_mesh(W.L1, 0.8, 0.62), b, float(a.q1))
		_put(ci, link_mesh(W.L2, 0.6, 0.46), e, float(a.q2))
		var dim := 1.0 if st >= 1 else 0.7
		_put(ci, spreader_mesh(), wr, float(a.yaw), Color(dim, dim, dim), k)
	_put(ci, bridge_mesh(st), Vector2.ZERO)


# ================================================================== the light
# the steady light: the wall lamps' fall on the deck (one mesh a stage), the slip ring's warmth
func glow_mesh(st: int) -> ArrayMesh:
	return _mesh("glow%d" % st, func(p):
		if st < 1:
			return
		for i in 12:
			var a := TAU * i / 12.0 + PI / 12.0
			if _in_gap(a, R_WALL, PortStructure.HALF + 1.6):
				continue
			var u := Vector2.from_angle(a)
			var v := u.orthogonal()
			var apex := u * (R_WALL - 0.5)
			var pts := PackedVector2Array()
			for k in 9:
				var f := (k / 8.0) * 2.0 - 1.0
				pts.append(u * (R_WALL - 5.0 + 1.2 * f * f) + v * f * 3.0)
			_fan(p, apex, pts, Color(0.85, 0.92, 1.0, 0.07), Color(0.85, 0.92, 1.0, 0.0))
		# the bus ring's faint glow
		for k in 24:
			var a0 := TAU * k / 24.0
			var a1 := TAU * (k + 1) / 24.0
			var vc := Pal.tint(Pal.VOLT, 0.05, 1.0)
			_fan(p, Vector2.from_angle((a0 + a1) * 0.5) * 3.41, PackedVector2Array([Vector2.from_angle(a0) * 2.7, Vector2.from_angle(a1) * 2.7]), vc, Color(vc, 0.0))
			_fan(p, Vector2.from_angle((a0 + a1) * 0.5) * 3.41, PackedVector2Array([Vector2.from_angle(a0) * 4.2, Vector2.from_angle(a1) * 4.2]), vc, Color(vc, 0.0)))


func _spot(ci: CanvasItem, tex: Texture2D, at: Vector2, r: float, col: Color) -> void:
	ci.draw_texture_rect(tex, Rect2(_p(at) - Vector2(r, r) * m, Vector2(r, r) * 2.0 * m), false, col)


# a rotating beacon's two beams swept round it (vertex colours)
func _beam(ci: CanvasItem, at: Vector2, a: float, len: float, col: Color) -> void:
	for s: float in [0.0, PI]:
		var u := Vector2.from_angle(a + s)
		var v := u.orthogonal()
		ci.draw_polygon(PackedVector2Array([_p(at), _p(at + u * len + v * len * 0.22), _p(at + u * len - v * len * 0.22)]), PackedColorArray([col, Color(col, 0.0), Color(col, 0.0)]))


func glow(ci: CanvasItem, tex: Texture2D, t: float, game) -> void:
	_frame(ci)
	var st := W.stage
	_put(ci, glow_mesh(st), Vector2.ZERO)
	var th := W.theta
	if st == 0:
		# the dead ring: emergency beacons turning on the core's two cabinets, a lamp or two flickering
		var g := float(W.spokes().get("power", -PI * 0.5))
		for s: float in [0.0, PI]:
			var at := Vector2.from_angle(g + s) * 5.6
			_beam(ci, at, t * 3.4 + s, 9.0, Color(1.0, 0.42, 0.12, 0.13))
			_spot(ci, tex, at, 1.1, Color(1.0, 0.45, 0.15, 0.55))
		for i: int in [2, 7]:
			var a := TAU * i / 12.0 + PI / 12.0
			if fmod(t * 0.7 + i * 0.31, 1.0) < 0.12 and fmod(t * 9.0, 1.0) < 0.6:
				_spot(ci, tex, Vector2.from_angle(a) * (R_WALL - 2.5), 3.4, Color(0.85, 0.92, 1.0, 0.18))
		return
	# the carousel's running lights: chasing while it turns, steady while it stands
	var moving := absf(W.omega) > 0.002
	for i in 48:
		var a := th + TAU * (i + 0.5) / 48.0
		var on := 0.35
		if moving:
			on = 1.0 if (i + int(t * 10.0)) % 6 == 0 else 0.15
		_spot(ci, tex, Vector2.from_angle(a) * 14.22, 0.42, Color(Pal.AIR, 0.6 * on) if not moving else Color(1.0, 0.6, 0.25, 0.75 * on))
	# the slip ring: warmer the harder the drives pull
	var load := clampf(absf(W.omega) / 0.26, 0.0, 1.0)
	_spot(ci, tex, Vector2.ZERO, 2.4, Pal.heat(0.05 + 0.16 * load, 1.0))
	# drives: status lamps, the pinions' mesh catching the light
	for i in DRIVES.size():
		if not has_drive(i, st):
			continue
		var u := Vector2.from_angle(DRIVES[i])
		_spot(ci, tex, u * R_MOTOR - u.orthogonal() * 1.2, 0.35, Pal.tint(Pal.FLUID, 0.8, 1.2) if not moving else Pal.heat(0.9, 1.2))
	# the lock pins' lamps: amber while they travel
	for a: float in PINS:
		if W.pins > 0.02 and W.pins < 0.98:
			_spot(ci, tex, Vector2.from_angle(a) * 7.05, 0.7, Pal.heat(0.7, 1.2))
	# the hatches' lamps while their lifts move; the arms' beacons and work lights
	for z in W.spokes():
		if z == "power":
			continue
		var hz := W._hatch(z)
		if float(hz.lamp) > 0.0 and fmod(float(hz.lamp), 1.0) < 0.5:
			var g: float = W.spokes()[z]
			var hp := W.hatch_at(z)
			var u := Vector2.from_angle(g)
			for s: float in [-1.0, 1.0]:
				_spot(ci, tex, hp + u * 1.9 + u.orthogonal() * s * 1.9, 0.55, Pal.heat(0.9, 1.3))
		var a := W._arm(z)
		var b := W.base_at(z)
		if str(a.phase) != "park" or a.parcel != null:
			_beam(ci, b, float(a.beacon), 2.6, Color(1.0, 0.55, 0.2, 0.09))
			_spot(ci, tex, b, 0.35, Pal.heat(0.9, 1.3))
			_spot(ci, tex, W.wrist(z), 2.4, Color(0.85, 0.92, 1.0, 0.1))
	# power: pulses round the ring main from the feeder to each spoke by what that district draws,
	# and up the bridge to the core while the drives pull
	var gp := float(W.spokes().get("power", -PI * 0.5))
	for z in W.spokes():
		if z == "power":
			continue
		var mw := PortArt._feeder_mw(z)
		if mw <= 0.005:
			continue
		var to: float = W.spokes()[z]
		var span := wrapf(to - gp, -PI, PI)
		var n := maxi(1, int(absf(span) * R_TRAY / 3.0))
		var spd := 0.25 + 0.15 * sqrt(mw)
		for k in n:
			var f := fmod(float(k) / n + t * spd / maxf(0.3, absf(span)), 1.0)
			_spot(ci, tex, Vector2.from_angle(gp + span * f) * R_TRAY, 0.3, Pal.tint(Pal.VOLT, 0.55 + 0.4 * clampf(mw / 12.0, 0.0, 1.0), 1.4))
	if moving or W.dwell < 0.5:
		var ug := Vector2.from_angle(gp)
		for k in 4:
			var f := fmod(k / 4.0 + t * 0.8, 1.0)
			_spot(ci, tex, ug * lerpf(R_SAFE + 0.4, 6.6, f), 0.32, Pal.tint(Pal.VOLT, 0.8, 1.4))


# ================================================================== the words
func plates_sig() -> String:
	var a := absf(W.omega)
	return "%d/%d/%d/%d/%s" % [W.stage, roundi(rad_to_deg(a)), W.loaded(), int(W.settled()), Txt.zh]


func plates(ci: CanvasItem, t: float) -> void:
	_frame(ci)
	var st := W.stage
	var sp := W.spokes()
	var dim := _ink(0.55)
	var hi := _ink(0.85)
	# the hall's stencil on the deck
	var sa := float(sp.get("power", -PI * 0.5)) - 0.42
	_text(ci, Vector2.from_angle(sa) * 17.6 + Vector2(-1.5, 0.5), "TR-0", 1.1, Color(_ink(0.16), 0.2))
	# each spoke's district on the wall beside its mouth, on the side away from the arm
	var codes := {"power": "PWR-1", "salvage": "SLV-2", "process": "PRC-3", "tug": "TUG-4", "trade": "TRD-5", "cargo": "CGO-6"}
	for z in sp:
		var g: float = sp[z]
		var side := -W.side_of(z) if z != "power" else 1.0
		var a := g + side * (PortStructure.HALF + 2.6) / 23.5
		var at := Vector2.from_angle(a) * 23.5 + Vector2(-1.0, -0.15)
		_text(ci, at, codes.get(z, ""), 0.46, hi if Port.stage(z) >= 1 else dim)
		_text(ci, at + Vector2(0, 0.56), Port.name_of(z), 0.4, dim)
	# the drives' plates
	for i in DRIVES.size():
		var u := Vector2.from_angle(DRIVES[i])
		var at := u * 3.9 + Vector2(-0.9, 0.2 if u.y > 0.0 else -0.2)
		var word := w("缺失", "GONE") if not has_drive(i, st) else (w("停转", "DEAD") if st == 0 else (w("运行", "RUN") if absf(W.omega) > 0.002 else w("待机", "READY")))
		_text(ci, at, "M%d %s" % [i + 1, word], 0.36, Pal.heat(0.85, 1.1) if st == 0 or not has_drive(i, st) else dim)
	# the control cabinet's screen: what the carousel is doing
	var g := float(sp.get("power", -PI * 0.5)) + PI
	var sc := Vector2.from_angle(g) * 5.75 + Vector2(-0.55, -0.9)
	var lines: Array = []
	if st == 0:
		lines = [[w("转盘 停转", "CAROUSEL DEAD"), Color(1.0, 0.36, 0.24)], [w("驱动缺失 2/4", "DRIVES 2/4 GONE"), dim]]
	else:
		var state := w("转位", "INDEXING") if absf(W.omega) > 0.002 else (w("定位锁止", "LOCKED") if W.settled() else w("等待", "WAITING"))
		lines = [[w("转盘 ", "CAROUSEL ") + state, hi], ["%.0f°/s · %d/12" % [rad_to_deg(absf(W.omega)), W.loaded()], dim]]
	for k in lines.size():
		_text(ci, sc + Vector2(0, k * 0.42), lines[k][0], 0.3, lines[k][1])


# ================================================================== the hover cards
func hover_items(game) -> Array:
	c = PortStructure.centre()
	m = PortStructure.M()
	var st := W.stage
	var out: Array = []
	var dead := st == 0
	var sp := W.spokes()
	for z in sp:
		if z == "power":
			continue
		var b := W.base_at(z)
		var hp := W.hatch_at(z)
		var r := Rect2(_p(b), Vector2.ZERO).expand(_p(hp)).grow(1.8 * m)
		var s := W.arm_state(z)
		out.append({"rect": r, "title": w("转运臂 · ", "TRANSFER ARM · ") + Port.name_of(z),
			"use": w("在这条走廊的升降口和转盘托架之间搬货：从%s来的货放上转盘，转到这里的货卸下送进%s。", "Moves goods between this spoke's hatch and the carousel's cradles: what comes up from %s goes onto the carousel, what comes round for %s is set down into it.") % [Port.name_of(z), Port.name_of(z)],
			"now": str(s[0]), "can": w("货由各区真实作业产生：仓库出入库、加工排队、贸易装货。修好中央环后转得更快。", "The goods come from the districts' real work: the warehouse's jobs, the heats queued, trades being loaded. Mend the ring and it runs faster."),
			"lamp": str(s[1])})
	for i in DRIVES.size():
		var u := Vector2.from_angle(DRIVES[i])
		var r := Rect2(_p(u * R_MOTOR) - Vector2(1.4, 1.4) * m, Vector2(2.8, 2.8) * m)
		var have := has_drive(i, st)
		out.append({"rect": r, "title": w("转盘驱动 M%d", "CAROUSEL DRIVE M%d") % (i + 1),
			"use": w("立式电机经减速箱带小齿轮，啮合转盘内圈齿圈，四台一起让转盘一格一格转位。", "A standing motor through its gearbox to a pinion in the carousel's inner gear ring; the four index the carousel a pitch at a time."),
			"now": w("拆走了，只剩底座螺栓和剪断的电缆", "Gone: the bolts it stood on and its cut cables") if not have else (w("断电停转", "No power") if dead else (w("运行中", "Running") if absf(W.omega) > 0.002 else w("待机", "Ready"))),
			"can": w("中央环修到 2 档（需驱动件）会把缺的两台装回去。", "Stage 2 of the ring (it needs drive parts) puts the missing two back.") if not have else w("中央环 1 档通电就能转。", "Stage 1 of the ring powers it."),
			"lamp": "warn" if not have or dead else ("work" if absf(W.omega) > 0.002 else "ok")})
	out.append({"rect": Rect2(_p(Vector2(-4.3, -4.3)), Vector2(8.6, 8.6) * m), "title": w("滑环与母线环", "SLIP RING AND BUS RING"),
		"use": w("动力区的电经供电桥进母线环，分给四台驱动；中间的滑环把电送上一直在转的转盘。", "The power district's feed comes over the bridge into the bus ring and on to the four drives; the slip ring in the middle carries it onto the turning carousel."),
		"now": w("无电", "Dead") if dead else w("负载 %d%%", "LOAD %d%%") % roundi(clampf(absf(W.omega) / 0.26, 0.0, 1.0) * 100.0),
		"can": w("中央环 1 档需要动力区先修好。", "Stage 1 of the ring needs the power district mended first."), "lamp": "off" if dead else "ok"})
	var gp := float(sp.get("power", -PI * 0.5))
	var ug := Vector2.from_angle(gp)
	var mw := 0.0
	for z in sp:
		mw += PortArt._feeder_mw(z) if z != "power" else 0.0
	out.append({"rect": Rect2(_p(ug * 6.6), Vector2.ZERO).expand(_p(ug * (R_SAFE + 0.6))).grow(1.4 * m), "title": w("供电桥 · 环网主管廊", "FEEDER BRIDGE · RING MAIN"),
		"use": w("从动力区来的馈线一路过桥进核心，一路沿环网电缆槽分到每条走廊。旁边两根是冷却水管。", "The feeder from the power district: one way over the bridge into the core, the other round the ring main's tray to every spoke. The two pipes beside it are the coolant."),
		"now": w("各区共用电 %.1f MW", "THE DISTRICTS DRAW %.1f MW") % mw, "can": w("在动力区的电网调度里分电。", "Share the power out at the power district's grid."), "lamp": "work" if mw > 0.01 else "off"})
	out.append({"rect": Rect2(_p(Vector2(-R_CAR_OUT, -R_CAR_OUT)), Vector2(R_CAR_OUT, R_CAR_OUT) * 2.0 * m), "title": w("中央转运转盘 TR-0", "CENTRAL CAROUSEL TR-0"),
		"use": w("12 个托架的大转盘，每次转 30° 停住锁销，各走廊的转运臂趁停的时候装卸，把货在各区之间转运。", "Twelve cradles on a slewing ring: it turns 30°, the pins lock it, and each spoke's arm loads or unloads while it stands, carrying the goods between the districts."),
		"now": w("停转：转盘卡在半格上，一个货箱撞歪了", "Dead: stopped half a pitch round, a crate knocked askew") if dead else w("在转 %d 箱 · 已送 %d 箱", "%d CRATES ON IT · %d DELIVERED") % [W.loaded(), W.moved],
		"can": w("在业务终端的建设里修中央环：1 档通电慢转，2 档装回驱动和冷却全速转。", "Mend the ring under building at the console: stage 1 powers it slowly, stage 2 puts the drives and coolers back for full speed."),
		"lamp": "warn" if dead else ("work" if W.loaded() > 0 else "ok")})
	return out
