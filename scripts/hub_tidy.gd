extends RefCounted
# 中央转运环 TR-0 极简体块 (user 2026-11-11: "中央转运环，你也提升一下质感"; the six districts' tidy
# hulls, scripts/port_art.gd hull_style 1). The same machine as scripts/hub_art.gd draws it, by
# subtraction: the carousel one lit steel ring with its thickness and its shadow in the pit, twelve
# solid girders and twelve cradles, no bolts, sockets or running-light chain; one lamp at each cradle,
# slow; the deck plain, the pit dark, the safety edge one quiet line; the arms and the feeder bridge
# solid pieces throwing shadows, every moving part moving as before (hub_works.gd runs them); the
# shuttle's tracks are scripts/tram.gd's and untouched. Drawn while Pal.solid (F9 shows the old
# picture). Hub-local metres; `a` is the HubArt drawing it (its pen helpers and its placing).
#   tests/hub_tidy_shot.gd

const W = preload("res://scripts/hub_works.gd")
const FW = preload("res://scripts/freight_works.gd")
const CA = preload("res://scripts/console_art.gd")

const TOP := Color(0.1, 0.104, 0.116)        # a lit flat face (the districts' tidy hull's)
const TOP2 := Color(0.165, 0.172, 0.19)      # the carousel's rim, the brightest steel down here
const LOW := Color(0.06, 0.063, 0.071)
const EAVE := Color(0.22, 0.227, 0.245)      # an edge facing the light
const SIDE := Color(0.024, 0.025, 0.03)      # an edge away from it
const PIT_SHADOW := 0.55                     # m the carousel stands above the pit's floor (its shadow's offset)


static func L() -> Vector2:
	return Look.LIGHT_DIR


# a ring's two edges seen from above: the one whose face turns to the light lit, the other dark
# (outer: the face's normal points out; inner: in)
static func _edges(p, r: float, outer: bool, w: float, n := 96, k := 1.0) -> void:
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var u := Vector2.from_angle((a0 + a1) * 0.5)
		var f := (u if outer else -u).dot(L())
		if f > 0.05:
			p.arc(Vector2.ZERO, r, a0, a1, Color(EAVE, 0.9 * f * k), w, 1)
		elif f < -0.05:
			p.arc(Vector2.ZERO, r, a0, a1, Color(0, 0, 0, 0.55 * -f * k), w, 1)


# ================================================================== the still parts
static func still(a, p, st: int) -> void:
	var lit := st >= 1
	var sp := W.spokes()
	var HALF := PortStructure.HALF
	p.circle(Vector2.ZERO, a.R_OUT + 0.15, a.VOID, 120)
	# ---- the wall: one solid band, open at each spoke, its inner edge lit on the far side from the light
	var n := 120
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var am := (a0 + a1) * 0.5
		if a._in_gap(am, a.R_WALL, HALF + 0.3):
			continue
		var u := Vector2.from_angle(am)
		var f := clampf(-u.dot(L()), 0.0, 1.0)
		p.arc(Vector2.ZERO, (a.R_WALL + a.R_OUT) * 0.5, a0, a1, TOP.lerp(LOW, 0.35), a.R_OUT - a.R_WALL, 1)
		p.arc(Vector2.ZERO, a.R_WALL + 0.1, a0, a1, LOW.lerp(EAVE, f * 0.8), 0.2, 1)
		p.arc(Vector2.ZERO, a.R_OUT - 0.04, a0, a1, a._ink(0.1), 0.06, 1)
	for z in sp:
		var g: float = sp[z]
		var u := Vector2.from_angle(g)
		var v := u.orthogonal()
		for s: float in [-1.0, 1.0]:
			var j: Vector2 = u * (a.R_WALL + a.R_OUT) * 0.5 + v * s * (PortStructure.half(z) + 0.55)
			a._box(p, j, g, Vector2(a.R_OUT - a.R_WALL + 0.4, 0.75), TOP, a._ink(0.28), 0.05)
	# the wall's twelve lamps: a dark housing, a short pale bar when the hall has power
	for i in 12:
		var aa := TAU * i / 12.0 + PI / 12.0
		if a._in_gap(aa, a.R_WALL, HALF + 1.6):
			continue
		var u := Vector2.from_angle(aa)
		a._box(p, u * (a.R_WALL - 0.2), aa, Vector2(0.4, 1.1), LOW, a._ink(0.22), 0.04)
		if lit:
			p.line(u * (a.R_WALL - 0.42) + u.orthogonal() * 0.4, u * (a.R_WALL - 0.42) - u.orthogonal() * 0.4, Color(0.85, 0.88, 0.9, 0.55), 0.07)
	# ---- the shuttle's track bed (the rails are scripts/tram.gd's), its edge
	p.arc(Vector2.ZERO, (a.R_DECK + a.R_WALL) * 0.5, 0.0, TAU, Color(0.032, 0.034, 0.04), a.R_WALL - a.R_DECK, 160)
	p.arc(Vector2.ZERO, a.R_DECK, 0.0, TAU, a._ink(0.16), 0.06, 160)
	# ---- the service deck: one plain floor, twelve faint seams
	p.arc(Vector2.ZERO, (a.R_SAFE + a.R_DECK) * 0.5, 0.0, TAU, a.DECK, a.R_DECK - a.R_SAFE, 160)
	for i in 12:
		var u := Vector2.from_angle(TAU * i / 12.0 + PI / 12.0)
		p.line(u * (a.R_SAFE + 1.45), u * (a.R_DECK - 0.45), Color(0.05, 0.053, 0.06), 0.05)
	# ---- the ring main: one solid tray, a single dim core of light in it; the two coolant pipes solid
	p.arc(Vector2.ZERO, a.R_TRAY, 0.0, TAU, Color(0.048, 0.051, 0.058), 0.62, 160)
	p.arc(Vector2.ZERO, a.R_TRAY, 0.0, TAU, Pal.tint(Pal.VOLT, 0.12 if lit else 0.05, 0.9), 0.09, 160)
	_edges(p, a.R_TRAY + 0.31, true, 0.06, 96, 0.6)
	_edges(p, a.R_TRAY - 0.31, false, 0.06, 96, 0.6)
	for rr: float in [16.42, 16.72]:
		p.arc(Vector2.ZERO, rr, 0.0, TAU, Color(0.085, 0.092, 0.102), 0.2, 160)
		_edges(p, rr + 0.08, true, 0.04, 96, 0.5)
	# taps: a junction box on the tray at each spoke, its cable out along the spoke
	for z in sp:
		var g: float = sp[z]
		var u := Vector2.from_angle(g)
		var v := u.orthogonal()
		var side := -1.0 if z == "power" else -W.side_of(z)
		var off := 2.3 if z == "power" else 2.75
		var jb: Vector2 = u * a.R_TRAY + W.across(g) * side * off
		a._box(p, jb, g, Vector2(1.0, 0.8), TOP, a._ink(0.3), 0.04)
		var wcol := Pal.tint(Pal.VOLT, 0.2 if lit else 0.08, 0.9)
		if z == "power":
			for k in 3:
				var o := v * (k - 1) * 0.28
				p.line(jb + u * 0.4 + o, u * (a.R_OUT + 0.2) + W.across(g) * side * off + o, Color(0.07, 0.074, 0.084), 0.2)
			p.line(jb + u * 0.4, u * (a.R_OUT + 0.2) + W.across(g) * side * off, wcol, 0.08)
		else:
			p.line(jb + u * 0.4, u * a.R_WALL + W.across(g) * side * off, Color(0.07, 0.074, 0.084), 0.14)
	# ---- the pit's edge: a dark kerb, one quiet keep-clear line
	p.arc(Vector2.ZERO, (a.R_CAR_OUT + a.R_SAFE) * 0.5, 0.0, TAU, Color(0.04, 0.042, 0.048), a.R_SAFE - a.R_CAR_OUT, 160)
	p.arc(Vector2.ZERO, a.R_SAFE - 0.12, 0.0, TAU, Pal.heat(0.3, 0.85), 0.08, 160)
	_edges(p, a.R_SAFE, true, 0.05, 96, 0.5)
	# ---- the pit: dark, one roller track faint in it
	p.arc(Vector2.ZERO, (a.R_CORE + a.R_CAR_OUT) * 0.5, 0.0, TAU, Color(0.024, 0.026, 0.03), a.R_CAR_OUT - a.R_CORE, 160)
	p.arc(Vector2.ZERO, 11.5, 0.0, TAU, Color(0.036, 0.038, 0.044), 0.3, 160)
	# the carousel's shadow on the pit's floor: its two rims, off away from the light (the girders' and
	# cradles' turn with it: HubArt.back)
	var sh := -L() * PIT_SHADOW
	p.arc(sh, (13.85 + a.R_CAR_OUT) * 0.5, 0.0, TAU, Color(0, 0, 0, 0.55), a.R_CAR_OUT - 13.85, 120)
	p.arc(sh, (a.R_CAR_IN + 9.15) * 0.5, 0.0, TAU, Color(0, 0, 0, 0.55), 9.15 - a.R_CAR_IN, 96)
	# ---- the core: one lit plinth, its rim
	p.circle(Vector2.ZERO, a.R_CORE, Color(0.066, 0.07, 0.079), 96)
	p.arc(Vector2.ZERO, a.R_CORE - 0.18, 0.0, TAU, TOP, 0.36, 120)
	_edges(p, a.R_CORE - 0.02, true, 0.08, 96)
	# the bus ring: one bar, dim; the slip ring's stator, its six brush holders
	p.arc(Vector2.ZERO, 3.41, 0.0, TAU, Color(0.05, 0.053, 0.06), 0.62, 96)
	p.arc(Vector2.ZERO, 3.41, 0.0, TAU, Pal.tint(Pal.VOLT, 0.26 if lit else 0.1, 1.0), 0.12, 96)
	p.arc(Vector2.ZERO, 2.35, 0.0, TAU, TOP, 0.3, 64)
	_edges(p, 2.5, true, 0.05, 48)
	for i in 6:
		var aa := TAU * i / 6.0
		a._box(p, Vector2.from_angle(aa) * 2.2, aa, Vector2(0.75, 0.42), LOW, a._ink(0.3), 0.03)
	# ---- the drives: a mount each; a motor and its gearbox on it, or the bolt holes it stood on
	for i in a.DRIVES.size():
		var aa: float = a.DRIVES[i]
		var u := Vector2.from_angle(aa)
		var v := u.orthogonal()
		_slab(a, p, u * 5.9, aa, Vector2(3.6, 3.0), Color(0.075, 0.079, 0.088))
		if a.has_drive(i, st):
			_slab(a, p, u * 7.0, aa, Vector2(1.5, 1.35), TOP)
			p.circle(u * a.R_MOTOR + -L() * 0.25, 1.14, Color(0, 0, 0, 0.45), 28)
			p.circle(u * a.R_MOTOR, 1.12, TOP, 28)
			p.circle(u * a.R_MOTOR, 0.86, Color(0.03, 0.032, 0.036), 24)
			p.ring(u * a.R_MOTOR, 1.12, a._ink(0.3), 0.05, 28)
			a._box(p, u * a.R_MOTOR - v * 1.2, aa, Vector2(0.7, 0.5), LOW, a._ink(0.3), 0.03)
			p.line(u * 3.7 - v * 0.4, u * a.R_MOTOR - v * 1.2, Pal.tint(Pal.VOLT, 0.2 if lit else 0.08, 1.0), 0.09)
		else:
			for s: Vector2 in [Vector2(-0.8, -0.8), Vector2(0.8, -0.8), Vector2(-0.8, 0.8), Vector2(0.8, 0.8)]:
				p.circle(u * (a.R_MOTOR + s.x) + v * s.y, 0.13, Color(0.02, 0.02, 0.024), 8)
			p.ring(u * a.R_MOTOR, 1.12, Color(0.13, 0.13, 0.14, 0.45), 0.04, 28)
			p.line(u * 3.7 - v * 0.4, u * 4.65 - v * 0.9, Pal.tint(Pal.VOLT, 0.1, 0.8), 0.09)
			p.line(u * 4.65 - v * 0.9, u * 4.75 - v * 1.05, Pal.heat(0.4, 1.0), 0.08)
	# ---- the coolers (with the ring mended), or the capped stubs they will hang on
	for aa: float in a.COOLERS:
		var u := Vector2.from_angle(aa)
		var v := u.orthogonal()
		if st >= 2:
			_slab(a, p, u * 5.4, aa, Vector2(2.3, 2.6), TOP)
			p.circle(u * 5.4, 0.92, Color(0.03, 0.032, 0.036), 24)
			for s: float in [-1.0, 1.0]:
				p.line(u * 4.2 + v * s * 0.9, Vector2.from_angle(aa + s * PI * 0.25) * 4.5, Color(0.09, 0.098, 0.11), 0.14)
		else:
			for s: float in [-1.0, 1.0]:
				p.line(Vector2.from_angle(aa + s * PI * 0.25) * 4.5, u * 4.9 + v * s * 0.6, Color(0.09, 0.098, 0.11), 0.14)
				p.circle(u * 4.9 + v * s * 0.6, 0.12, Pal.heat(0.35, 1.0), 8)
	# ---- the lock pins' housings at the rim
	for aa: float in a.PINS:
		_slab(a, p, Vector2.from_angle(aa) * 7.05, aa, Vector2(1.1, 0.95), TOP)
	# ---- the switchgear where the feeder lands and the control cabinet opposite (its status window)
	var gp := float(sp.get("power", -PI * 0.5))
	var ug := Vector2.from_angle(gp)
	_slab(a, p, ug * 5.6, gp, Vector2(2.4, 3.0), TOP)
	for k in 3:
		p.line(ug * 4.6 + ug.orthogonal() * (-0.48 + k * 0.95), ug * 6.6 + ug.orthogonal() * (-0.48 + k * 0.95), Color(0, 0, 0, 0.5), 0.05)
	var uc := -ug
	_slab(a, p, uc * 5.6, gp + PI, Vector2(2.2, 3.4), TOP)
	a._box(p, uc * 5.75, gp + PI, Vector2(1.25, 2.6), CA.BG_GLASS, a._ink(0.16), 0.03)
	# ---- at each spoke but the power one: the hatch's frame, its apron, the arm's plinth
	for z in sp:
		if z == "power":
			continue
		var g: float = sp[z]
		var h := W.hatch_at(z)
		var u := Vector2.from_angle(g)
		var v := u.orthogonal()
		a._box(p, h, g, Vector2(4.0, 4.0), Color(0.05, 0.052, 0.058))
		a._box(p, h, g, Vector2(3.7, 3.7), Color(0, 0, 0, 0), Pal.heat(0.42, 0.9), 0.1)
		a._box(p, h, g, Vector2(3.2, 3.2), Color(0.018, 0.02, 0.024), a._ink(0.2), 0.04)
		var r0: float = W.R_HATCH + 2.0
		var r1: float = a.APRON_OUT
		a._box(p, u * (r0 + r1) * 0.5, g, Vector2(r1 - r0, 3.8), Color(0.036, 0.038, 0.044), a._ink(0.2), 0.04)
		var rr: float = r0 + 0.4
		while rr < r1 - 0.2:
			p.line(u * rr + v * 1.7, u * rr - v * 1.7, Color(0.06, 0.063, 0.071), 0.12)
			rr += 0.78
		var b := W.base_at(z)
		var oct := PackedVector2Array()
		var osh := PackedVector2Array()
		for k in 8:
			var q: Vector2 = b + Vector2.from_angle(TAU * k / 8.0 + PI / 8.0) * 1.3
			oct.append(q)
			osh.append(q - L() * 0.3)
		p.poly(osh, Color(0, 0, 0, 0.45))
		p.poly(oct, TOP)
		p.polyline(oct, a._ink(0.26), 0.05, true)
		p.line(b + (Vector2.ZERO - b).normalized() * 1.3, b.normalized() * (a.R_TRAY + 0.3), Color(0.07, 0.074, 0.084), 0.14)


# a solid box: its shadow off away from the light, the face, a lit edge on the side toward it
static func _slab(a, p, at: Vector2, ang: float, size: Vector2, col: Color, h := 0.3) -> void:
	a._box(p, at - L() * h, ang, size, Color(0, 0, 0, 0.45))
	a._box(p, at, ang, size, col, a._ink(0.2), 0.04)
	var u := Vector2.from_angle(ang)
	var v := u.orthogonal()
	# the edge whose face turns most to the light: [its normal, how far out, how long]
	var best: Array = [u, size.x * 0.5, size.y]
	for e: Array in [[-u, size.x * 0.5, size.y], [v, size.y * 0.5, size.x], [-v, size.y * 0.5, size.x]]:
		if (e[0] as Vector2).dot(L()) > (best[0] as Vector2).dot(L()):
			best = e
	var nrm: Vector2 = best[0]
	var mid: Vector2 = at + nrm * float(best[1])
	var tg := nrm.orthogonal() * float(best[2]) * 0.5
	p.line(mid - tg, mid + tg, Color(EAVE, 0.85), 0.08)


# ================================================================== the carousel (turns: hub_art.back)
static func carousel(a, p) -> void:
	# the inner rim: one band, the gear teeth inside it (the pinions run in them)
	p.arc(Vector2.ZERO, (a.R_CAR_IN + 9.15) * 0.5, 0.0, TAU, TOP2, 9.15 - a.R_CAR_IN, 120)
	var nt := 132
	for i in nt:
		var aa := TAU * (i + 0.5) / nt
		var u := Vector2.from_angle(aa)
		var v := u.orthogonal()
		var hw: float = PI * a.R_CAR_IN / nt * 0.55
		p.poly(PackedVector2Array([u * a.R_CAR_IN - v * hw, u * a.R_CAR_IN + v * hw, u * (a.TEETH_R - 0.2) + v * hw * 0.55, u * (a.TEETH_R - 0.2) - v * hw * 0.55]), Color(0.1, 0.105, 0.116))
	# the outer rim: one thick lit steel ring
	p.arc(Vector2.ZERO, (13.85 + a.R_CAR_OUT) * 0.5, 0.0, TAU, TOP2, a.R_CAR_OUT - 13.85, 160)
	# the lock pins' sockets in the inner rim, one at every index
	for k in W.SLOTS:
		var aa := k * W.PITCH
		a._box(p, Vector2.from_angle(aa) * 8.75, aa, Vector2(0.5, 0.42), Color(0.02, 0.02, 0.024))
	# the girders between the cradles: solid box beams
	for k in W.SLOTS:
		var aa := k * W.PITCH + W.PITCH * 0.5
		var u := Vector2.from_angle(aa)
		a._box(p, u * 11.5, aa, Vector2(4.8, 0.7), TOP, Color(0, 0, 0, 0.5), 0.04)
		p.line(u * 9.2, u * 13.8, Color(0.13, 0.136, 0.15), 0.12)
	# the cradles: a plain deck, its two rails, a dark lock at each corner, its number stencilled small
	for k in W.SLOTS:
		var aa := k * W.PITCH
		var u := Vector2.from_angle(aa)
		var v := u.orthogonal()
		var ctr := u * W.R_CRADLE
		a._box(p, ctr, aa, Vector2(4.1, 4.5), Color(0.082, 0.086, 0.096), Color(0, 0, 0, 0.5), 0.05)
		for s: float in [-1.0, 1.0]:
			p.line(ctr - u * 2.05 + v * s * 2.12, ctr + u * 2.05 + v * s * 2.12, Color(0.15, 0.157, 0.172), 0.22)
		for cx: float in [-1.0, 1.0]:
			for cy: float in [-1.0, 1.0]:
				var q := ctr + u * cx * 1.85 + v * cy * 1.62
				a._box(p, q, aa, Vector2(0.3, 0.3), Color(0.025, 0.026, 0.03))
		a._digits(p, "%02d" % (k + 1), ctr - u * 1.55 + v * 1.7, aa - PI * 0.5, 0.42, a._ink(0.2), 0.06)


# the girders' and cradles' shadow in the pit: turned with the carousel, set off by a fixed offset
static func carousel_shadow(a, p) -> void:
	for k in W.SLOTS:
		var aa := k * W.PITCH + W.PITCH * 0.5
		a._box(p, Vector2.from_angle(aa) * 11.5, aa, Vector2(4.8, 0.7), Color(0, 0, 0, 0.5))
		a._box(p, Vector2.from_angle(k * W.PITCH) * W.R_CRADLE, k * W.PITCH, Vector2(4.1, 4.5), Color(0, 0, 0, 0.5))


# the light on the carousel's rims, fixed to the world while it turns
static func carousel_light(a, p) -> void:
	_edges(p, a.R_CAR_OUT - 0.07, true, 0.14, 96, 1.2)
	_edges(p, 13.92, false, 0.08, 96)
	_edges(p, 9.1, true, 0.08, 72)
	_edges(p, a.R_CAR_IN + 0.05, false, 0.07, 72)


static func rotor(a, p) -> void:
	p.circle(Vector2.ZERO, 2.05, Color(0.07, 0.074, 0.082), 40)
	p.ring(Vector2.ZERO, 1.35, Color(0.34, 0.24, 0.16), 0.14, 40)
	p.circle(Vector2.ZERO, 0.52, TOP2, 24)
	for i in 3:
		var u := Vector2.from_angle(TAU * i / 3.0)
		p.line(u * 0.5, u * 2.0, Color(0.13, 0.136, 0.15), 0.16)


static func fan(a, p, r: float) -> void:
	for i in 5:
		var aa := TAU * i / 5.0
		var u := Vector2.from_angle(aa)
		var v := u.orthogonal()
		p.poly(PackedVector2Array([u * 0.12 - v * 0.06, u * r * 0.95 - v * 0.05, u * r * 0.9 + v * r * 0.32, u * 0.12 + v * 0.1]), Color(0.16, 0.168, 0.184))
	p.circle(Vector2.ZERO, r * 0.22, TOP2, 10)


# ================================================================== the arm and the bridge: solid
static func turret(a, p) -> void:
	p.circle(Vector2.ZERO, 0.95, Color(0.14, 0.147, 0.16), 24)
	p.ring(Vector2.ZERO, 0.95, a._ink(0.32), 0.05, 24)
	p.rect(Rect2(-0.7, -0.62, 0.9, 1.24), Color(0.09, 0.095, 0.106))
	p.circle(Vector2.ZERO, 0.42, Color(0.2, 0.21, 0.23), 16)


static func link(a, p, l: float, w0: float, w1: float) -> void:
	var pts := PackedVector2Array([Vector2(0, -w0 * 0.5), Vector2(l, -w1 * 0.5), Vector2(l, w1 * 0.5), Vector2(0, w0 * 0.5)])
	p.poly(pts, Color(0.15, 0.157, 0.172))
	p.polyline(pts, Color(0, 0, 0, 0.5), 0.05, true)
	# a raised spine down the middle catching the light, the ram along its side
	p.line(Vector2(0.3, 0), Vector2(l - 0.3, 0), Color(0.22, 0.228, 0.248), (w0 + w1) * 0.18)
	p.line(Vector2(0.4, -w0 * 0.5 - 0.1), Vector2(l * 0.6, -w1 * 0.5 - 0.1), Color(0.08, 0.084, 0.094), 0.16)
	p.line(Vector2(l * 0.6, -w1 * 0.5 - 0.1), Vector2(l * 0.85, -w1 * 0.5 - 0.1), Color(0.42, 0.44, 0.47), 0.06)
	p.line(Vector2(l - 0.42, -w1 * 0.5), Vector2(l - 0.42, w1 * 0.5), Pal.heat(0.45, 1.0), 0.12)
	p.circle(Vector2(l, 0), w1 * 0.62, Color(0.19, 0.2, 0.218), 16)
	p.circle(Vector2(l, 0), w1 * 0.22, Color(0.04, 0.04, 0.045), 10)


static func link_shadow(a, p, l: float, w0: float, w1: float) -> void:
	p.poly(PackedVector2Array([Vector2(0, -w0 * 0.5), Vector2(l, -w1 * 0.5), Vector2(l, w1 * 0.5), Vector2(0, w0 * 0.5)]), Color(0, 0, 0, 0.42))
	p.circle(Vector2(l, 0), w1 * 0.62, Color(0, 0, 0, 0.42), 12)
	p.circle(Vector2.ZERO, 0.95 if w0 > 0.7 else w0 * 0.62, Color(0, 0, 0, 0.42), 16)


static func spreader(a, p) -> void:
	var hx := 1.85
	var hy := 1.55
	p.rect(Rect2(-hx, -hy, hx * 2.0, hy * 2.0), Color(0.17, 0.178, 0.194), false, 0.24)
	p.line(Vector2(0, -hy), Vector2(0, hy), Color(0.17, 0.178, 0.194), 0.36)
	p.circle(Vector2.ZERO, 0.32, Color(0.22, 0.23, 0.25), 14)
	for cx: float in [-1.0, 1.0]:
		for cy: float in [-1.0, 1.0]:
			p.rect(Rect2(Vector2(cx * hx, cy * hy) - Vector2(0.2, 0.2), Vector2(0.4, 0.4)), Color(0.22, 0.23, 0.25))
	p.line(Vector2(-hx + 0.3, -hy), Vector2(-hx + 1.0, -hy), Pal.heat(0.45, 1.0), 0.1)


static func bridge(a, p, st: int) -> void:
	var lit := st >= 1
	var g := float(W.spokes().get("power", -PI * 0.5))
	var u := Vector2.from_angle(g)
	var v := u.orthogonal()
	var r0: float = 6.6
	var r1: float = a.R_SAFE + 0.6
	for rr: float in [a.R_CORE - 0.2, a.R_SAFE - 0.1]:
		a._box(p, u * rr, g, Vector2(0.8, 3.1), TOP, a._ink(0.26), 0.05)
	# the deck, solid; the two chords, the one toward the light lit along its top
	a._box(p, u * (r0 + r1) * 0.5, g, Vector2(r1 - r0, 2.2), Color(0.068, 0.072, 0.081))
	for s: float in [-1.0, 1.0]:
		var lit_side := (v * s).dot(L()) > 0.0
		p.line(u * r0 + v * s * 1.12, u * r1 + v * s * 1.12, Color(0.15, 0.157, 0.172), 0.3)
		p.line(u * r0 + v * s * 1.25, u * r1 + v * s * 1.25, Color(EAVE, 0.85) if lit_side else Color(0, 0, 0, 0.6), 0.06)
	# crossbeams, few
	var x := r0 + 1.5
	while x < r1 - 0.5:
		p.line(u * x + v * 1.0, u * x - v * 1.0, Color(0.1, 0.105, 0.116), 0.14)
		x += 3.0
	# the tray down its middle, the feeder in it
	a._box(p, u * (r0 + r1) * 0.5, g, Vector2(r1 - r0 + 0.6, 0.8), Color(0.05, 0.053, 0.06), Color(0, 0, 0, 0.5), 0.04)
	p.line(u * (r0 - 0.3), u * (r1 + 0.3), Pal.tint(Pal.VOLT, 0.26 if lit else 0.1, 1.0), 0.12)


static func bridge_shadow(a, p) -> void:
	var g := float(W.spokes().get("power", -PI * 0.5))
	var u := Vector2.from_angle(g)
	var r0: float = 6.6
	var r1: float = a.R_SAFE + 0.6
	a._box(p, u * (r0 + r1) * 0.5, g, Vector2(r1 - r0, 2.7), Color(0, 0, 0, 0.42))


# ================================================================== the light (additive)
static func glow_mesh(a, p, st: int) -> void:
	if st < 1:
		return
	for i in 12:
		var aa := TAU * i / 12.0 + PI / 12.0
		if a._in_gap(aa, a.R_WALL, PortStructure.HALF + 1.6):
			continue
		var u := Vector2.from_angle(aa)
		var v := u.orthogonal()
		var apex: Vector2 = u * (a.R_WALL - 0.5)
		var pts := PackedVector2Array()
		for k in 9:
			var f := (k / 8.0) * 2.0 - 1.0
			pts.append(u * (a.R_WALL - 4.2 + 1.0 * f * f) + v * f * 2.6)
		a._fan(p, apex, pts, Color(0.85, 0.9, 0.95, 0.045), Color(0.85, 0.9, 0.95, 0.0))


static func glow(a, ci: CanvasItem, tex: Texture2D, t: float) -> void:
	var st := W.stage
	var th := W.theta
	if st == 0:
		# the dead ring: a slow amber on the two cabinets, no sweeping beams
		var g := float(W.spokes().get("power", -PI * 0.5))
		for s: float in [0.0, PI]:
			var b := 0.25 + 0.3 * pow(maxf(0.0, sin(t * 1.6 + s)), 4.0)
			a._spot(ci, tex, Vector2.from_angle(g + s) * 5.6, 0.55, Color(1.0, 0.5, 0.2, b))
		return
	var moving := absf(W.omega) > 0.002
	# one lamp at each cradle on the rim: warm where a crate rides, cool where it's empty; slow
	for k in W.SLOTS:
		var aa := th + k * W.PITCH
		var full: bool = k < W.cradles.size() and W.cradles[k] != null
		var b := 0.45 + 0.35 * sin(t * (1.6 if moving else 0.8) + k * 0.52)
		var col := Color(1.0, 0.62, 0.3) if full else Color(Pal.AIR)
		a._spot(ci, tex, Vector2.from_angle(aa) * 14.22, 0.3, Color(col, b * (0.8 if full else 0.5)))
	# the slip ring: a little warmth the harder the drives pull
	var load := clampf(absf(W.omega) / 0.26, 0.0, 1.0)
	a._spot(ci, tex, Vector2.ZERO, 1.1, Pal.heat(0.03 + 0.08 * load, 1.0))
	for i in a.DRIVES.size():
		if not a.has_drive(i, st):
			continue
		var u := Vector2.from_angle(a.DRIVES[i])
		a._spot(ci, tex, u * a.R_MOTOR - u.orthogonal() * 1.2, 0.28, Pal.tint(Pal.FLUID, 0.6, 1.1) if not moving else Pal.heat(0.75, 1.1))
	for aa: float in a.PINS:
		if W.pins > 0.02 and W.pins < 0.98:
			a._spot(ci, tex, Vector2.from_angle(aa) * 7.05, 0.5, Pal.heat(0.6, 1.1))
	for z in W.spokes():
		if z == "power":
			continue
		var hz := W._hatch(z)
		if float(hz.lamp) > 0.0 and fmod(float(hz.lamp), 1.0) < 0.5:
			var g: float = W.spokes()[z]
			var hp := W.hatch_at(z)
			var u := Vector2.from_angle(g)
			for s: float in [-1.0, 1.0]:
				a._spot(ci, tex, hp + u * 1.9 + u.orthogonal() * s * 1.9, 0.4, Pal.heat(0.75, 1.1))
		var arm := W._arm(z)
		if str(arm.phase) != "park" or arm.parcel != null:
			a._spot(ci, tex, W.base_at(z), 0.26, Pal.heat(0.6 + 0.3 * absf(sin(t * 2.0)), 1.1))
			a._spot(ci, tex, W.wrist(z), 1.8, Color(0.85, 0.9, 0.95, 0.06))
	# the feeder over the bridge: two quiet pulses while the drives pull
	if moving:
		var ug := Vector2.from_angle(float(W.spokes().get("power", -PI * 0.5)))
		for k in 2:
			var f := fmod(k / 2.0 + t * 0.5, 1.0)
			a._spot(ci, tex, ug * lerpf(a.R_SAFE + 0.4, 6.6, f), 0.26, Pal.tint(Pal.VOLT, 0.55, 1.1))
