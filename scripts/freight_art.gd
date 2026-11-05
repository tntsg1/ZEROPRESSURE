extends RefCounted
# 130 号 (user 2026-11-04: "所有美术效果都要和无人机一样精细…新的货运火车要和现有接驳车一样多细节"): the
# freight trains' parts, drawn the shuttle's way (scripts/tram_art.gd): meshes in each car's own metres
# (cab or leading end towards +x), the same plate, machinery and glass tones, the same ink weights —
# outline 0.82, panel seams 0.2–0.35, hidden lines (the bogies under the body) at 0.13 alpha. The body
# sides show under the roof when the body leans on its springs; the bogies are the shuttle's own.
#   loco: a hood unit with a cab at +x — windscreen and pillars, the engine hood's louvres, two
#     radiator fans, the roof's marker lamps, handrails and the walkway; side panels ribbed.
#   wagon: a flat with a roller bed (rollers along the wagon, so a crate rolls off either side), a
#     push plate on each side that travels across behind a crate, twistlocks at the corners that swing
#     in when it locks, stake pockets down the side sills.
const MeshPen = preload("res://scripts/mesh_pen.gd")
const TramArt = preload("res://scripts/tram_art.gd")

const LOCO_L := 3.4
const LOCO_W := 2.5
const WAGON_L := 4.0
const WAGON_W := 3.0
const BOGIE := {"loco": 1.0, "wagon": 1.3}   # m from a car's centre to each bogie

const FACE := TramArt.FACE
const FACE2 := TramArt.FACE2
const DARK := TramArt.DARK
const VOID := TramArt.VOID

static var _m := {}


static func _cached(key: String, build: Callable) -> ArrayMesh:
	if not _m.has(key):
		var pen := MeshPen.new()
		build.call(pen)
		_m[key] = pen.mesh()
	return _m[key]


static func loco_outline() -> PackedVector2Array:
	var h := LOCO_L * 0.5
	var w := LOCO_W * 0.5
	return PackedVector2Array([Vector2(-h, -w + 0.12), Vector2(-h + 0.12, -w), Vector2(h - 0.5, -w), Vector2(h, -w + 0.36), Vector2(h, w - 0.36), Vector2(h - 0.5, w), Vector2(-h + 0.12, w), Vector2(-h, w - 0.12)])


static func wagon_outline() -> PackedVector2Array:
	var h := WAGON_L * 0.5
	var w := WAGON_W * 0.5
	return PackedVector2Array([Vector2(-h, -w), Vector2(h, -w), Vector2(h, w), Vector2(-h, w)])


static func shadow_mesh(kind: String) -> ArrayMesh:
	return _cached("shadow_" + kind, func(p):
		p.poly(loco_outline() if kind == "loco" else wagon_outline(), Color(0, 0, 0, 0.5)))


# the body's sides seen under the roof when it leans: ribbed plate, the loco's side windows
static func side_mesh(kind: String) -> ArrayMesh:
	return _cached("side_" + kind, func(p):
		var ol := loco_outline() if kind == "loco" else wagon_outline()
		p.poly(ol, FACE2)
		var h := (LOCO_L if kind == "loco" else WAGON_L) * 0.5
		var w := (LOCO_W if kind == "loco" else WAGON_W) * 0.5
		var x := -h + 0.25
		while x < h - 0.3:
			for s: float in [-1.0, 1.0]:
				p.line(Vector2(x, s * (w - 0.02)), Vector2(x, s * (w - 0.16)), Pal.ink(0.3), 0.03)
			x += 0.32
		if kind == "loco":
			for s: float in [-1.0, 1.0]:
				p.rect(Rect2(Vector2(h - 0.9, w - 0.18) if s > 0.0 else Vector2(h - 0.9, -w), Vector2(0.32, 0.18)), Color(0.3, 0.36, 0.4))
		p.polyline(ol, Pal.ink(0.5), 0.04, true))


# the loco from above
static func loco_mesh() -> ArrayMesh:
	return _cached("loco", func(p):
		var h := LOCO_L * 0.5
		var w := LOCO_W * 0.5
		var ol := loco_outline()
		p.poly(ol, FACE)
		# the walkways down both sides, their tread and the handrail stanchions
		for s: float in [-1.0, 1.0]:
			var y0: float = s * (w - 0.2)
			p.hatch(Rect2(Vector2(-h + 0.15, minf(y0, s * (w - 0.04))), Vector2(2.35, 0.16)), Pal.ink(0.1), 0.02, 0.09)
			p.line(Vector2(-h + 0.12, s * (w - 0.05)), Vector2(h - 0.55, s * (w - 0.05)), Pal.ink(0.42), 0.03)
			for k in 6:
				p.circle(Vector2(-h + 0.2 + k * 0.46, s * (w - 0.05)), 0.03, Pal.ink(0.6), 6)
		# the long hood: louvred panels, two radiator fans at its rear, the exhaust stack
		var hood := Rect2(Vector2(-h + 0.12, -w + 0.3), Vector2(2.3, 2.0 * w - 0.6))
		p.rect(hood, FACE2)
		p.rect(hood, Pal.ink(0.34), false, 0.03)
		for k in 9:
			var lx := hood.position.x + 1.05 + k * 0.13
			p.line(Vector2(lx, hood.position.y + 0.12), Vector2(lx, hood.end.y - 0.12), DARK, 0.05)
		for fy: float in [-0.38, 0.38]:
			var fc := Vector2(hood.position.x + 0.45, fy)
			p.circle(fc, 0.3, VOID, 18)
			p.ring(fc, 0.3, Pal.ink(0.32), 0.025, 18)
			for k in 4:
				p.line(fc, fc + Vector2.from_angle(TAU * k / 4.0 + 0.3) * 0.26, Pal.ink(0.22), 0.035)
			p.circle(fc, 0.06, Pal.ink(0.4), 8)
		p.rect(Rect2(Vector2(hood.end.x - 0.4, -0.13), Vector2(0.26, 0.26)), DARK)
		p.ring(Vector2(hood.end.x - 0.27, 0.0), 0.09, Pal.ink(0.4), 0.02, 10)
		for c: Vector2 in [hood.position + Vector2(0.06, 0.06), Vector2(hood.end.x - 0.06, hood.position.y + 0.06), hood.end - Vector2(0.06, 0.06), Vector2(hood.position.x + 0.06, hood.end.y - 0.06)]:
			p.bolt(c, 0.035, Pal.ink(0.5))
		# the cab: roof seams, the windscreen across the nose, its pillars and wiper
		for k in 3:
			var cx := h - 1.0 + k * 0.17
			p.line(Vector2(cx, -w + 0.12), Vector2(cx, w - 0.12), Pal.ink(0.06), 0.02)
		var glass := PackedVector2Array([Vector2(h - 0.55, -w + 0.14), Vector2(h - 0.12, -w + 0.45), Vector2(h - 0.12, w - 0.45), Vector2(h - 0.55, w - 0.14)])
		p.poly(glass, Color(0.07, 0.11, 0.13))
		p.polyline(glass, Pal.ink(0.55), 0.035, true)
		p.line(Vector2(h - 0.33, -0.05), Vector2(h - 0.2, 0.26), Pal.ink(0.4), 0.025)
		# the freight livery: a heat band along each side of the hood, chevrons on the buffer beams
		for s: float in [-1.0, 1.0]:
			p.line(Vector2(-h + 0.15, s * (w - 0.24)), Vector2(h - 0.65, s * (w - 0.24)), Pal.heat(0.7, 1.05), 0.06)
		for e: float in [-1.0, 1.0]:
			var bx: float = e * (h - 0.04)
			p.line(Vector2(bx, -w + 0.2), Vector2(bx, w - 0.2), DARK, 0.08)
			for k in 4:
				var y := -0.7 + k * 0.42
				p.line(Vector2(bx, y), Vector2(bx - e * 0.1, y + 0.18), Pal.heat(0.75, 1.0), 0.04)
		p.polyline(ol, Pal.ink(0.82), 0.045, true))


# the flat from above: deck, side sills with stake pockets, the end beams; the rollers and push plates
# are their own meshes (they move)
static func wagon_mesh() -> ArrayMesh:
	return _cached("wagon", func(p):
		var h := WAGON_L * 0.5
		var w := WAGON_W * 0.5
		var ol := wagon_outline()
		p.poly(ol, FACE)
		p.rect(Rect2(Vector2(-h + 0.18, -w + 0.22), Vector2(2.0 * h - 0.36, 2.0 * w - 0.44)), VOID)
		# the roller frame: two long rails the rollers sit in, cross members
		for y: float in [-w + 0.3, w - 0.3]:
			p.line(Vector2(-h + 0.2, y), Vector2(h - 0.2, y), FACE2, 0.08)
		for x: float in [-h + 0.25, -0.65, 0.65, h - 0.25]:
			p.line(Vector2(x, -w + 0.25), Vector2(x, w - 0.25), Color(0.1, 0.105, 0.116), 0.06)
		# the side sills and their stake pockets, the end beams, coupler pockets
		for s: float in [-1.0, 1.0]:
			p.line(Vector2(-h, s * (w - 0.09)), Vector2(h, s * (w - 0.09)), FACE2, 0.18)
			p.line(Vector2(-h, s * (w - 0.01)), Vector2(h, s * (w - 0.01)), Pal.heat(0.55, 1.0), 0.03)
			for k in 6:
				p.rect(Rect2(Vector2(-h + 0.3 + k * 0.68, s * (w - 0.09) - 0.05), Vector2(0.12, 0.1)), DARK)
		for e: float in [-1.0, 1.0]:
			p.line(Vector2(e * (h - 0.06), -w), Vector2(e * (h - 0.06), w), FACE2, 0.12)
			p.rect(Rect2(Vector2(e * h - 0.12, -0.18), Vector2(0.24, 0.36)), DARK)
		p.polyline(ol, Pal.ink(0.82), 0.045, true))


# one roller: a tube along the wagon, its bearings at the ends
static func roller_mesh() -> ArrayMesh:
	return _cached("roller", func(p):
		var h := WAGON_L * 0.5 - 0.3
		p.line(Vector2(-h, 0.0), Vector2(h, 0.0), Color(0.2, 0.21, 0.23), 0.12)
		p.line(Vector2(-h, -0.04), Vector2(h, -0.04), Pal.ink(0.35), 0.02)
		for e: float in [-1.0, 1.0]:
			p.rect(Rect2(Vector2(e * h - 0.06, -0.08), Vector2(0.12, 0.16)), DARK)
			p.circle(Vector2(e * h, 0.0), 0.03, Pal.ink(0.5), 6))


# the push plate: a beam along the wagon on two arms, its pad facing the crate
static func plate_mesh() -> ArrayMesh:
	return _cached("plate", func(p):
		var h := WAGON_L * 0.5 - 0.45
		p.rect(Rect2(Vector2(-h, -0.08), Vector2(2.0 * h, 0.16)), FACE2)
		p.rect(Rect2(Vector2(-h, -0.08), Vector2(2.0 * h, 0.16)), Pal.ink(0.6), false, 0.025)
		p.line(Vector2(-h + 0.1, 0.08), Vector2(h - 0.1, 0.08), Pal.heat(0.7, 1.0), 0.03)
		for x: float in [-h * 0.6, h * 0.6]:
			p.rect(Rect2(Vector2(x - 0.06, -0.3), Vector2(0.12, 0.22)), DARK)
			p.rect(Rect2(Vector2(x - 0.06, -0.3), Vector2(0.12, 0.22)), Pal.ink(0.4), false, 0.02))


# a twistlock: its casting and the lever that swings in to lock
static func lock_mesh() -> ArrayMesh:
	return _cached("lock", func(p):
		p.rect(Rect2(Vector2(-0.1, -0.1), Vector2(0.2, 0.2)), FACE2)
		p.rect(Rect2(Vector2(-0.1, -0.1), Vector2(0.2, 0.2)), Pal.ink(0.55), false, 0.02)
		p.line(Vector2(0.0, 0.0), Vector2(0.2, 0.0), Pal.ink(0.7), 0.04))


# a coupler: the drawbar, its knuckle at each end
static func coupler_mesh() -> ArrayMesh:
	return _cached("coupler", func(p):
		p.line(Vector2(-0.5, 0.0), Vector2(0.5, 0.0), DARK, 0.14)
		p.line(Vector2(-0.5, 0.05), Vector2(0.5, 0.05), Pal.ink(0.4), 0.025)
		for e: float in [-1.0, 1.0]:
			p.rect(Rect2(Vector2(e * 0.38 - 0.08, -0.11), Vector2(0.16, 0.22)), FACE2)
			p.rect(Rect2(Vector2(e * 0.38 - 0.08, -0.11), Vector2(0.16, 0.22)), Pal.ink(0.5), false, 0.02)
		p.line(Vector2(-0.38, -0.16), Vector2(0.38, -0.16), Pal.ink(0.25), 0.02))
