extends RefCounted
# 103 号 (user 2026-10-28, a screenshot of the mill pedestal and a business console: the names lay on
# the screens and ran off the view — "优化终端"; Q1 A, Q2 A, Q3 A, Q4 A): every console in the port
# drawn as one floor-standing industrial console — a foot and column with the cable down into the
# floor, a cabinet, the sloped operating desk (keys, lamps, the emergency stop), the screen under its
# hood — built once as meshes. On the screen the district's own figures, live; over it a name plate
# that keeps to the screen's edge and never covers the console, the key's hint on it when the
# operator is close, and then the floor under the console lit. Metres from the console's spot (the
# screen's centre), y down.
#   ConsoleArt.draw(ci, at, foot_m, title, hint, on, info, t)   info: {lines: [[text, colour]], bar, lamp}

const MeshPen = preload("res://scripts/mesh_pen.gd")
const FastDraw = preload("res://scripts/fast_draw.gd")
const PowerWorks = preload("res://scripts/power_works.gd")

const SCREEN := Rect2(-0.95, -1.4, 1.9, 1.15)
const FACE := Color(0.118, 0.124, 0.136)
const FACE2 := Color(0.15, 0.158, 0.172)
const DARK := Color(0.05, 0.054, 0.062)

static var _meshes := {}


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


static func lamp_col(state: String, t: float) -> Color:
	match state:
		"ok", "run": return Pal.tint(Pal.FLUID, 0.95, 1.3)
		"work", "wait", "short": return Pal.heat(0.65 + 0.35 * absf(sin(t * 4.0)), 1.3)
		"warn": return Color(1.0, 0.3, 0.22, 0.6 + 0.4 * absf(sin(t * 2.5)))
		"idle": return Pal.tint(Pal.AIR, 0.8, 1.2)
	return Pal.ink(0.25)


static func _mesh(key: String, build: Callable) -> ArrayMesh:
	if not _meshes.has(key):
		var pen := MeshPen.new()
		build.call(pen)
		_meshes[key] = pen.mesh()
	return _meshes[key]


# 105 号 (user 2026-10-28 "各个站的工作台优化"; Q1 A, Q2 B, Q3 A): the same screen, name plate and
# lit floor for every work desk in the port, the body as what the desk is for:
#   console  the districts' business consoles (103 号) and the mill pedestal
#   furnace  the furnace desk: wider, a heat shield towards the furnace with its viewing port, the
#            start button, the power dial, the emergency stop
#   sort     the sorting desk: a joystick, and the emergency pull cord along the line
#   assay    the assay bench: a lab bench with drawers; the spectrometer's read-out is its screen,
#            the sample carousel on the bench top
#   wall     the berth terminal: a cabinet on the tower wall, its bracket and conduit, a keypad
#   rack     the parts rack: a frame of nine cubbies (the parts drawn in it live), no screen
#   store    131 号: the stores terminal in the berth — the berth terminal's little brother on the
#            tower wall (its bracket, a keypad, the cable gland on its hood where the line to the
#            cargo district leaves); drawn with info.scale < 1
const KINDS := ["console", "furnace", "sort", "assay", "wall", "rack", "store"]


# the foot plate and column down to the floor (foot below the spot), the cable into the floor
static func _stand(p, top: float, foot: float, w := 0.52) -> void:
	var edge := Pal.ink(0.62)
	p.rect(Rect2(-1.1, foot - 0.22, 2.2, 0.22), FACE2)
	p.rect(Rect2(-1.1, foot - 0.22, 2.2, 0.22), edge, false, 0.04)
	for bx in [-0.85, 0.85]:
		p.bolt(Vector2(bx, foot - 0.11), 0.06, Pal.ink(0.55))
	if foot - 0.22 > top:
		p.rect(Rect2(-w * 0.5, top, w, foot - 0.22 - top), FACE)
		p.line(Vector2(-w * 0.5, top), Vector2(-w * 0.5, foot - 0.22), edge, 0.04)
		p.line(Vector2(w * 0.5, top), Vector2(w * 0.5, foot - 0.22), edge, 0.04)
	var cable := PackedVector2Array([Vector2(0.7, top), Vector2(0.78, top + 0.45), Vector2(0.95, maxf(top + 0.5, foot - 0.5)), Vector2(1.25, foot)])
	p.polyline(cable, Color(0.02, 0.022, 0.026), 0.16)
	p.polyline(cable, Pal.tint(Pal.VOLT, 0.4, 1.0), 0.08)


# a cabinet: door seam, vents, its handle
static func _cabinet(p, r: Rect2) -> void:
	var edge := Pal.ink(0.62)
	p.rect(r, FACE)
	p.rect(r, edge, false, 0.05)
	p.line(Vector2(r.get_center().x, r.position.y + 0.05), Vector2(r.get_center().x, r.end.y - 0.05), Pal.ink(0.3), 0.03)
	for k in 4:
		p.line(Vector2(r.position.x + 0.2, r.position.y + 0.3 + k * 0.16), Vector2(r.get_center().x - 0.2, r.position.y + 0.3 + k * 0.16), Pal.ink(0.28), 0.04)
	p.rect(Rect2(r.get_center().x + 0.15, r.position.y + 0.45, 0.08, 0.3), Pal.ink(0.55))


# the sloped desk between x0 and x1 (wider at the operator's edge)
static func _desk(p, x0: float, x1: float) -> void:
	var desk := PackedVector2Array([Vector2(x0, 0.25), Vector2(x1, 0.25), Vector2(x1 + 0.2, 0.85), Vector2(x0 - 0.2, 0.85)])
	p.poly(desk, FACE2)
	p.polyline(desk, Pal.ink(0.62), 0.05, true)


static func _keys(p, x0: float, n: int) -> void:
	for row in 2:
		for k in n:
			var kx := x0 + k * 0.32 + row * 0.06
			p.rect(Rect2(kx, 0.38 + row * 0.22, 0.24, 0.14), Color(0.2, 0.21, 0.225))
			p.rect(Rect2(kx, 0.38 + row * 0.22, 0.24, 0.14), Pal.ink(0.4), false, 0.02)


static func _estop(p, c: Vector2) -> void:
	p.circle(c, 0.2, Pal.heat(0.85, 1.0), 14)
	p.circle(c, 0.12, Color(0.75, 0.16, 0.12), 12)
	p.ring(c, 0.2, Pal.ink(0.7), 0.03, 14)


# the screen's housing and hood, the neck under it
static func _head(p, neck := true) -> void:
	var edge := Pal.ink(0.62)
	if neck:
		p.rect(Rect2(-0.15, -0.08, 0.3, 0.35), FACE)
	p.rect(Rect2(-1.1, -1.55, 2.2, 1.5), DARK)
	p.rect(Rect2(-1.1, -1.55, 2.2, 1.5), edge, false, 0.06)
	p.rect(SCREEN, Color(0.012, 0.016, 0.02))
	p.poly(PackedVector2Array([Vector2(-1.25, -1.78), Vector2(1.25, -1.78), Vector2(1.1, -1.55), Vector2(-1.1, -1.55)]), FACE2)
	p.line(Vector2(-1.25, -1.78), Vector2(1.25, -1.78), edge, 0.05)
	for bx in [-1.0, 1.0]:
		p.bolt(Vector2(bx, -0.18), 0.04, Pal.ink(0.45))


static func _body(p, kind: String, foot: float) -> void:
	var edge := Pal.ink(0.62)
	match kind:
		"rail":
			# 128 号 第 4 段: a low console clamped to a walkway's front railing — the screen on a short neck,
			# a sloped key desk, the bracket down to the walkway with two clamps round the rails, the cable
			# along the toe board
			_head(p)
			_desk(p, -0.85, 0.85)
			_keys(p, -0.6, 3)
			p.rect(Rect2(-0.14, 0.85, 0.28, foot - 0.97), FACE)
			p.line(Vector2(-0.14, 0.85), Vector2(-0.14, foot - 0.12), edge, 0.035)
			p.line(Vector2(0.14, 0.85), Vector2(0.14, foot - 0.12), edge, 0.035)
			for cy in [foot - 1.05, foot - 0.55]:
				if cy > 0.9:
					p.rect(Rect2(-0.32, cy - 0.07, 0.64, 0.14), FACE2)
					p.rect(Rect2(-0.32, cy - 0.07, 0.64, 0.14), edge, false, 0.025)
					p.bolt(Vector2(-0.22, cy), 0.03, Pal.ink(0.55))
					p.bolt(Vector2(0.22, cy), 0.03, Pal.ink(0.55))
			p.rect(Rect2(-0.55, foot - 0.12, 1.1, 0.12), FACE2)
			p.rect(Rect2(-0.55, foot - 0.12, 1.1, 0.12), edge, false, 0.03)
			var cable := PackedVector2Array([Vector2(0.14, 0.95), Vector2(0.3, foot - 0.4), Vector2(0.75, foot - 0.08)])
			p.polyline(cable, Color(0.02, 0.022, 0.026), 0.1)
			p.polyline(cable, Pal.tint(Pal.VOLT, 0.4, 1.0), 0.05)
		"furnace":
			_stand(p, 2.1, foot, 0.7)
			_cabinet(p, Rect2(-1.3, 0.85, 2.6, 1.25))
			_desk(p, -1.6, 1.6)
			_keys(p, -0.75, 3)
			# start (green), the power dial, the emergency stop
			p.circle(Vector2(-1.15, 0.55), 0.2, Pal.tint(Pal.FLUID, 0.8, 1.0), 14)
			p.ring(Vector2(-1.15, 0.55), 0.2, Pal.ink(0.7), 0.03, 14)
			p.circle(Vector2(0.55, 0.55), 0.22, Color(0.2, 0.21, 0.225), 16)
			p.ring(Vector2(0.55, 0.55), 0.22, Pal.ink(0.7), 0.03, 16)
			p.arc(Vector2(0.55, 0.55), 0.3, PI * 0.8, PI * 2.2, Pal.heat(0.6, 1.0), 0.03, 14)
			_estop(p, Vector2(1.3, 0.55))
			# the heat shield towards the furnace (to the right), hatched, its viewing port
			var sh := Rect2(1.95, -2.1, 0.32, 4.1)
			p.rect(sh, FACE2)
			p.hatch(sh, Pal.heat(0.55, 1.0), 0.06, 0.35)
			p.rect(sh, edge, false, 0.05)
			p.circle(Vector2(2.11, -0.75), 0.24, Color(0.02, 0.02, 0.022), 14)
			p.ring(Vector2(2.11, -0.75), 0.24, Pal.ink(0.75), 0.05, 14)
			p.line(Vector2(1.95, 1.2), Vector2(1.3, 1.2), edge, 0.06)
			_head(p)
		"sort":
			_stand(p, 1.95, foot)
			_cabinet(p, Rect2(-1.0, 0.85, 2.0, 1.1))
			_desk(p, -1.3, 1.3)
			_keys(p, -1.05, 3)
			# the joystick, the stop button
			p.circle(Vector2(0.15, 0.62), 0.14, Color(0.2, 0.21, 0.225), 12)
			p.line(Vector2(0.15, 0.62), Vector2(0.3, 0.3), Pal.ink(0.7), 0.06)
			p.circle(Vector2(0.3, 0.3), 0.08, Pal.ink(0.8), 10)
			_estop(p, Vector2(1.0, 0.55))
			# the pull cord along the line, its pull handle
			p.line(Vector2(1.45, 0.2), Vector2(4.6, 0.2), Pal.heat(0.75, 1.0), 0.05)
			for kx in [2.4, 3.5, 4.6]:
				p.rect(Rect2(kx - 0.05, 0.12, 0.1, 0.16), Pal.ink(0.55))
			p.line(Vector2(3.0, 0.2), Vector2(3.0, 0.75), Pal.heat(0.75, 1.0), 0.04)
			p.rect(Rect2(2.85, 0.75, 0.3, 0.14), Pal.heat(0.9, 1.0))
			_head(p)
		"assay":
			# the bench: a top across, a drawer stack under the screen, legs to the floor
			p.rect(Rect2(-2.0, 0.3, 4.4, 0.18), FACE2)
			p.rect(Rect2(-2.0, 0.3, 4.4, 0.18), edge, false, 0.04)
			var dr := Rect2(-1.8, 0.48, 1.7, minf(1.6, foot - 0.7))
			p.rect(dr, FACE)
			p.rect(dr, edge, false, 0.04)
			for k in 3:
				var dy := dr.position.y + (k + 0.5) * dr.size.y / 3.0
				p.line(Vector2(dr.position.x, dr.position.y + k * dr.size.y / 3.0), Vector2(dr.end.x, dr.position.y + k * dr.size.y / 3.0), edge, 0.03)
				p.rect(Rect2(dr.get_center().x - 0.2, dy - 0.03, 0.4, 0.06), Pal.ink(0.55))
			for lx in [-1.85, 2.25]:
				p.rect(Rect2(lx, 0.48, 0.12, foot - 0.48), FACE)
			p.rect(Rect2(-2.0, foot - 0.12, 4.4, 0.12), FACE2)
			# the spectrometer's body under its read-out, the carousel's plinth on the right
			p.rect(Rect2(-1.0, 0.0, 2.0, 0.3), DARK)
			p.rect(Rect2(1.15, 0.12, 1.0, 0.18), FACE2)
			_head(p, false)
		"wall":
			# the bracket to the tower (left), the conduit up, the keypad under the screen
			p.rect(Rect2(-1.9, -1.0, 0.8, 0.18), FACE2)
			p.line(Vector2(-1.9, -0.4), Vector2(-1.1, -0.9), edge, 0.06)
			p.rect(Rect2(-1.98, -1.2, 0.12, 1.0), FACE)
			p.rect(Rect2(-0.08, -3.2, 0.16, 1.42), Pal.tint(Pal.VOLT, 0.35, 1.0))
			p.rect(Rect2(-1.1, -0.05, 2.2, 0.62), DARK)
			p.rect(Rect2(-1.1, -0.05, 2.2, 0.62), edge, false, 0.05)
			_keys_row(p)
			_head(p, false)
		"store":
			# the arm to the tower wall (left, 1.95 m to it at 0.72), its foot plate and two braces
			p.rect(Rect2(-3.05, -0.95, 1.95, 0.2), FACE2)
			p.rect(Rect2(-3.05, -0.95, 1.95, 0.2), edge, false, 0.035)
			p.line(Vector2(-2.95, -0.2), Vector2(-1.15, -0.85), edge, 0.06)
			p.line(Vector2(-2.95, -1.55), Vector2(-1.15, -1.0), Pal.ink(0.4), 0.04)
			p.rect(Rect2(-3.15, -1.75, 0.16, 1.75), FACE)
			p.rect(Rect2(-3.15, -1.75, 0.16, 1.75), edge, false, 0.03)
			for by in [-1.5, -0.3]:
				p.bolt(Vector2(-3.07, by), 0.045, Pal.ink(0.55))
			# the keypad box under the screen: a row of keys, the card slot, its lamp's bezel
			p.rect(Rect2(-1.1, -0.05, 2.2, 0.62), DARK)
			p.rect(Rect2(-1.1, -0.05, 2.2, 0.62), edge, false, 0.05)
			for k in 5:
				p.rect(Rect2(-0.95 + k * 0.28, 0.1, 0.21, 0.15), Color(0.2, 0.21, 0.225))
				p.rect(Rect2(-0.95 + k * 0.28, 0.31, 0.21, 0.15), Color(0.2, 0.21, 0.225))
			p.rect(Rect2(0.5, 0.12, 0.42, 0.06), Color(0.01, 0.012, 0.016))
			p.rect(Rect2(0.5, 0.12, 0.42, 0.06), Pal.ink(0.45), false, 0.02)
			p.ring(Vector2(0.75, 0.38), 0.11, Pal.ink(0.5), 0.025, 12)
			# the gland on the housing's right side: a hex nut round the cable going out to the right
			p.rect(Rect2(1.1, -1.12, 0.24, 0.36), FACE2)
			p.rect(Rect2(1.1, -1.12, 0.24, 0.36), edge, false, 0.03)
			p.rect(Rect2(1.34, -1.06, 0.12, 0.24), Pal.ink(0.45))
			_head(p, false)
			# the screen's maker plate under the hood's lip
			p.rect(Rect2(-0.3, -1.7, 0.6, 0.06), Pal.ink(0.35))
		"rack":
			# 107 号: a pallet rack of four shelves (sail, power, thermal, drive — top to bottom), its
			# crates drawn on it live (scripts/consoles.gd); punched uprights, orange beams, wall brackets
			var fr := Rect2(-1.0, -1.0, 2.0, 2.0)
			p.rect(fr, Color(0.035, 0.038, 0.044))
			for k in 9:
				p.line(Vector2(fr.position.x + 0.1 + k * 0.225, fr.position.y), Vector2(fr.position.x + 0.1 + k * 0.225, fr.end.y), Color(1, 1, 1, 0.03), 0.015)
			for ux in [fr.position.x - 0.08, fr.end.x - 0.04]:
				p.rect(Rect2(ux, fr.position.y - 0.08, 0.12, fr.size.y + 0.08), FACE2)
				p.rect(Rect2(ux, fr.position.y - 0.08, 0.12, fr.size.y + 0.08), edge, false, 0.025)
				for h in 10:
					p.rect(Rect2(ux + 0.045, fr.position.y + 0.04 + h * 0.2, 0.03, 0.07), DARK)
			for k in 5:
				var by := fr.position.y + k * 0.5 - 0.05
				p.rect(Rect2(fr.position.x - 0.04, by, fr.size.x + 0.04, 0.07), Pal.heat(0.75, 0.95))
				p.line(Vector2(fr.position.x - 0.04, by), Vector2(fr.end.x, by), Color(1.0, 0.78, 0.6, 0.6), 0.015)
			p.rect(Rect2(-1.9, -0.7, 0.82, 0.16), FACE2)
			p.rect(Rect2(-1.9, 0.6, 0.82, 0.16), FACE2)
		_:
			_stand(p, 1.95, foot)
			_cabinet(p, Rect2(-1.0, 0.85, 2.0, 1.1))
			_desk(p, -1.3, 1.3)
			_keys(p, -1.05, 5)
			_estop(p, Vector2(1.0, 0.55))
			_head(p)


static func _keys_row(p) -> void:
	for k in 6:
		p.rect(Rect2(-0.95 + k * 0.32, 0.1, 0.24, 0.16), Color(0.2, 0.21, 0.225))
		p.rect(Rect2(-0.95 + k * 0.32, 0.32, 0.24, 0.16), Color(0.2, 0.21, 0.225))


# metres from a desk's spot down to the floor it stands on: the district's floor strip when it is
# inside a district, else the berth's floor
static func foot_at(at: Vector2) -> float:
	var m := PortStructure.M()
	# 128 号 第 4 段: in the processing district's gallery the terminals stand on its floor
	var G = preload("res://scripts/process_gallery.gd")
	if G.on() and G.inside(at):
		return (PortStructure.box("process").position.y + G.FLOOR * m - at.y) / m
	var zone := PortStructure.zone_at(at)
	if zone != "" and zone != "ring":
		return (PortStructure.box(zone).end.y - 1.2 * m - at.y) / m
	return (Dock.FLOOR_Y * Geom.M - at.y) / m


# the extent a kind takes round its spot (m), for culling and its card
static func extent(kind: String, foot: float) -> Rect2:
	match kind:
		"rail": return Rect2(-1.3, -1.9, 2.6, foot + 1.9)
		"furnace": return Rect2(-2.0, -2.2, 4.4, foot + 2.2)
		"sort": return Rect2(-1.6, -1.9, 6.4, foot + 1.9)
		"assay": return Rect2(-2.1, -1.9, 4.6, foot + 1.9)
		"wall": return Rect2(-2.0, -3.2, 3.2, 3.8)
		"rack": return Rect2(-2.0, -1.1, 3.1, 2.2)
		"store": return Rect2(-3.2, -2.2, 4.4, 2.8)
	return Rect2(-1.6, -1.9, 3.2, foot + 1.9)


static func draw(ci: CanvasItem, at: Vector2, foot: float, title: String, hint: String, on: bool, info: Dictionary, t: float, kind := "console") -> void:
	var m := PortStructure.M() * float(info.get("scale", 1.0))
	var z := maxf(ci.get_canvas_transform().get_scale().x, 0.02)
	var px := m * z
	var col := Pal.tint(Pal.AIR, 1.0, 1.3)
	foot = clampf(foot, 1.2, 14.0)
	# 128 号 第 4 段: on the processing district's walkway every console is a low one on its railing
	if preload("res://scripts/process_gallery.gd").on() and preload("res://scripts/process_gallery.gd").inside(at):
		kind = "rail"
		foot = preload("res://scripts/process_gallery.gd").HEAD
	var ext := extent(kind, foot)
	# out of the view: nothing (and no name plate pinned to the view's edge)
	var xf := ci.get_canvas_transform()
	var body := Rect2(xf * (at + (ext.position - Vector2(0.5, 0.5)) * m), (ext.size + Vector2(1.0, 1.0)) * m * z)
	if not ci.get_viewport_rect().intersects(body):
		return
	var floored := kind not in ["wall", "rack", "store"]
	# the floor under it lit while the operator is at it (a wall or rack: a glow round it)
	if on:
		var pulse := 0.55 + 0.25 * sin(t * 3.0)
		if floored:
			for k in 4:
				var hgt := (0.15 + k * 0.35) * m
				ci.draw_rect(Rect2(at + Vector2(ext.position.x - 0.4, 0.0) * m + Vector2(0, foot * m - hgt), Vector2((ext.size.x + 0.8) * m, hgt)), Color(col.r, col.g, col.b, 0.05 * pulse))
			ci.draw_rect(Rect2(at + Vector2((ext.position.x - 0.4) * m, foot * m - 0.07 * m), Vector2((ext.size.x + 0.8) * m, 0.14 * m)), Color(col.r, col.g, col.b, 0.9 * pulse))
		else:
			# a thin lit frame round the unit itself (its screen and keypad, or the rack)
			var fr := Rect2(-1.25, -1.85, 2.5, 2.55) if kind in ["wall", "store"] else Rect2(-1.15, -1.15, 2.3, 2.3)
			ci.draw_rect(Rect2(at + fr.position * m, fr.size * m), Color(col.r, col.g, col.b, 0.8 * pulse), false, maxf(1.0, 0.05 * m))
	var mesh := _mesh("%s/%d" % [kind, int(round(foot * 10.0))], func(p): _body(p, kind, foot))
	if kind == "store":
		# under the body: a soft dark shadow on the tower wall, so it stands off it
		ci.draw_rect(Rect2(at + Vector2(-1.0, -1.6) * m + Vector2(0.12, 0.14) * m, Vector2(2.2, 2.2) * m), Color(0, 0, 0, 0.35))
	ci.draw_mesh(mesh, null, Transform2D(0.0, Vector2(m, m), 0.0, at), Color.WHITE)
	var lamp := str(info.get("lamp", "ok"))
	if kind == "rack":
		_name_plate(ci, at + Vector2(0.0, -1.15) * m, title, hint if on else "", lamp, on, t, z)
		return
	# the desk's lamps: its state, and the power on
	var lamp_at := Vector2(0.75, 0.33) if kind not in ["wall", "store"] else Vector2(0.75, -0.0)
	if kind == "store":
		lamp_at = Vector2(0.75, 0.38)
	if kind != "assay":
		FastDraw.circle(ci, at + lamp_at * m, 0.07 * m, lamp_col(lamp, t))
		FastDraw.circle(ci, at + (lamp_at - Vector2(0.2, 0.0)) * m, 0.07 * m, Pal.tint(Pal.FLUID, 0.9, 1.2))
	# the screen: brighter with the operator at it; its figures (or its own drawing), or bars when too far to read
	var sr := Rect2(at + SCREEN.position * m, SCREEN.size * m)
	ci.draw_rect(sr, Color(col.r, col.g, col.b, (0.16 if on else 0.07) + 0.02 * sin(t * 2.0)))
	ci.draw_rect(Rect2(sr.position, Vector2(sr.size.x, 0.18 * m)), Color(col.r, col.g, col.b, 0.35 if on else 0.2))
	var custom = info.get("screen")
	if custom is Callable:
		(custom as Callable).call(ci, Rect2(sr.position + Vector2(0.05, 0.22) * m, sr.size - Vector2(0.1, 0.27) * m))
	var lines: Array = info.get("lines", [])
	var bar := float(info.get("bar", -1.0))
	# with a bar, two lines over it; without, three
	var shown := lines.slice(0, 2 if bar >= 0.0 else 3)
	var fs := int(0.21 * px)
	if fs >= 7:
		var font := Fonts.get_font("Medium")
		var y := SCREEN.position.y + 0.45
		for ln in shown:
			ci.draw_set_transform(at + Vector2(SCREEN.position.x + 0.1, y) * m, 0.0, Vector2.ONE / z)
			ci.draw_string(font, Vector2.ZERO, str(ln[0]), HORIZONTAL_ALIGNMENT_LEFT, (SCREEN.size.x - 0.2) * px, fs, ln[1])
			y += 0.29
		ci.draw_set_transform(Vector2.ZERO)
	elif not custom is Callable:
		for k in shown.size():
			ci.draw_rect(Rect2(sr.position + Vector2(0.1, 0.3 + k * 0.25) * m, Vector2((0.5 + 0.35 * ((k + 1) % 3)) * m, 0.1 * m)), Color(col.r, col.g, col.b, 0.5))
	if bar >= 0.0:
		var br := Rect2(sr.position + Vector2(0.1 * m, sr.size.y - 0.22 * m), Vector2(sr.size.x - 0.2 * m, 0.1 * m))
		ci.draw_rect(br, Pal.ink(0.15))
		ci.draw_rect(Rect2(br.position, Vector2(br.size.x * clampf(bar, 0.0, 1.0), br.size.y)), Pal.heat(0.9, 1.2) if bar > 0.85 else Color(UiSkin.DATA))
	# the furnace desk's viewing port: as bright as the furnace burns
	if kind == "furnace":
		var glow := clampf(float(info.get("glow", 0.0)), 0.0, 1.0)
		FastDraw.circle(ci, at + Vector2(2.11, -0.75) * m, 0.19 * m, Pal.heat(0.12 + 0.8 * glow, 1.0 + 0.8 * glow))
	_name_plate(ci, at + Vector2(0.0, -1.9 if kind != "wall" else -3.3) * m, title, hint if on else "", lamp, on, t, z)


# the name over the hood: screen-sized, centred over it, kept inside the view; the key's hint
# under the name while the operator is at it
static func _name_plate(ci: CanvasItem, anchor: Vector2, title: String, hint: String, lamp: String, on: bool, t: float, z: float) -> void:
	if z < 0.12 and not on:
		return
	var font := Fonts.get_font("Medium")
	var xf := ci.get_canvas_transform()
	var sp: Vector2 = xf * anchor
	# its desk out of the view: no plate pinned to the view's edge
	if not ci.get_viewport_rect().grow(60.0).has_point(sp):
		return
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var hw := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x if hint != "" else 0.0
	var size := Vector2(maxf(tw + 30.0, hw + 16.0), 22.0 + (20.0 if hint != "" else 0.0))
	var pos := sp - Vector2(size.x * 0.5, size.y + 4.0)
	var vs := ci.get_viewport_rect().size
	pos.x = clampf(pos.x, 8.0, vs.x - size.x - 8.0)
	pos.y = clampf(pos.y, 8.0, vs.y - size.y - 8.0)
	var col := Pal.tint(Pal.AIR, 1.0 if on else 0.75, 1.3)
	ci.draw_set_transform_matrix(xf.affine_inverse())
	ci.draw_rect(Rect2(pos, size), Color(0.02, 0.022, 0.026, 0.88))
	ci.draw_rect(Rect2(pos, Vector2(3.0, size.y)), col)
	ci.draw_rect(Rect2(pos, size), Color(col.r, col.g, col.b, 0.5 if on else 0.25), false, 1.0)
	FastDraw.circle(ci, pos + Vector2(12.0, 11.0), 3.5, lamp_col(lamp, t))
	ci.draw_string(font, pos + Vector2(21.0, 16.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)
	if hint != "":
		ci.draw_string(font, pos + Vector2(8.0, 36.0), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.ink(0.95))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


# ---------------------------------------------------------------- each district's console: its figures and card
static func summary(zone: String, game) -> Dictionary:
	var st := Port.stage(zone) if zone != "ring" else Port.stage("power")
	var dim := Pal.ink(0.7)
	var hi := Pal.tint(Pal.AIR, 0.95, 1.2)
	match zone:
		"power":
			return {"lines": [["%.1f / %.0f MW" % [PowerWorks.own, PowerWorks.cap], hi], [w("负荷 %d%% · %s", "LOAD %d%% · %s") % [int(PowerWorks.frac() * 100.0), ("%.2f Hz" % PowerWorks.hz) if PowerWorks.units > 0 else w("燃料电池", "FUEL CELLS")], dim],
				[w("岸电 %.1f MW", "SHORE %.1f MW") % PowerWorks.shore if PowerWorks.shore > 0.05 else w("岸电 未用", "SHORE OFF"), dim]], "bar": PowerWorks.frac(), "lamp": "ok" if st >= 1 else "warn",
				"use": w("动力区业务：看全港发电和用电，打开动力控制屏（单线图、仪表、电不够时谁先用、供电线路）。", "The power district's business: the port's power made and used, and the power control screen (lines, gauges, who comes first, the supply line)."),
				"now": "%.1f / %.0f MW" % [PowerWorks.own, PowerWorks.cap], "can": w("飞到台前按 [%s] 打开。", "At the console press [%s].") % Keys.label("use")}
		"trade":
			var vis := TradePeople.here().size()
			var open := 0
			for tr in Career.data.get("exchange", {}).get("trades", []):
				if str(tr.get("state", "")) in ["awaiting_dispatch", "loading", "in_transit"]:
					open += 1
			return {"lines": [[w("客人 %d 位", "%d VISITORS") % vis, hi if vis > 0 else dim], [w("交货中 %d 笔", "%d HANDING OVER") % open, dim]], "bar": -1.0, "lamp": "work" if vis > 0 else ("ok" if st >= 1 else "off"),
				"use": w("贸易港业务：打开交易行买入卖出，接待开船来的客人。", "The trade port's business: the exchange to buy and sell, and the visitors who come in."),
				"now": w("客人 %d 位 · 交货中 %d 笔", "%d VISITORS · %d HANDING OVER") % [vis, open], "can": w("飞到台前按 [%s] 打开；平时任何地方按 F8 也能开交易行。", "At the console press [%s]; F8 opens the exchange anywhere.") % Keys.label("use")}
		"cargo":
			var tons := 0.0
			for k in Career.data.get("exchange", {}).get("actors", {}).get("company", {}).get("stock", {}).values():
				tons += float(k)
			var jobs: int = Warehouse.data().get("jobs", []).size()
			return {"lines": [[w("库存 %.1f t", "STOCK %.1f t") % tons, hi], [w("叉车任务 %d", "%d FORKLIFT JOBS") % jobs, dim]], "bar": -1.0, "lamp": "work" if jobs > 0 else ("ok" if st >= 1 else "off"),
				"use": w("货运区业务：公司仓库的库存、在途货物和货位。", "The cargo district's business: the company's stock, goods in transit, the rows."),
				"now": w("库存 %.1f t · 叉车任务 %d" % [tons, jobs], "STOCK %.1f t · %d JOBS" % [tons, jobs]), "can": w("飞到台前按 [%s] 打开。", "At the console press [%s].") % Keys.label("use")}
		"tug":
			var n := TugFleet.count()
			var ch := TugYard.charging().size()
			return {"lines": [[w("拖船 %d 艘", "%d TUGS") % n, hi], [w("充电 %d 艘", "%d CHARGING") % ch, dim]], "bar": -1.0, "lamp": "work" if ch > 0 else ("ok" if st >= 1 else "off"),
				"use": w("拖船站业务：调度自家拖船，把大船拖进港。", "The tug station's business: the company's tugs, big ships towed in."),
				"now": w("拖船 %d 艘 · 充电 %d" % [n, ch], "%d TUGS · %d CHARGING" % [n, ch]), "can": w("飞到台前按 [%s] 打开。", "At the console press [%s].") % Keys.label("use")}
		"process":
			var heat: Dictionary = Career.data.get("industrial_heat", {})
			var hs := str(heat.get("state", ""))
			var phase := {"raw_transport": w("送料中", "FEEDING"), "raw_return": w("原料返仓", "RETURNING"), "processing": w("炼钢中", "MELTING"), "product_transport": w("钢坯返仓", "BILLETS OUT")}
			var line := w("炉：空闲", "FURNACE IDLE") if hs == "" or hs in ["complete", "cancelled", "written_off"] else w("炉：%s", "FURNACE: %s") % str(phase.get(hs, w("工作中", "WORKING")))
			return {"lines": [[line, hi], [(w("轧机：", "MILL: ") + str(Mill.lamp(game)[1])) if game != null else "", dim]], "bar": -1.0, "lamp": "work" if hs == "processing" else ("ok" if st >= 1 else "off"),
				"use": w("加工区业务：炉次与加工队列，钢锭变成钢坯。轧机在它自己的操作台上开。", "The processing district's business: heats and the processing queue. The mill is run at its own console."),
				"now": line, "can": w("飞到台前按 [%s] 打开。", "At the console press [%s].") % Keys.label("use")}
		"ring":
			var fixed := 0
			for zz in ["power", "tug", "process", "trade", "cargo", "salvage"]:
				if Port.stage(zz) >= 1:
					fixed += 1
			return {"lines": [[w("已修 %d / 6 区", "%d / 6 DISTRICTS MENDED") % fixed, hi], [Pal.money(float(Career.data.get("money", 0.0))) if not Career.data.is_empty() else "", dim]], "bar": fixed / 6.0, "lamp": "ok",
				"use": w("港口总览：七个区、现金、待办，船坞终端（合同与建设）。", "The port at a glance: the districts, cash, what to do, and the berth terminal."),
				"now": w("已修 %d / 6 区" % fixed, "%d / 6 MENDED" % fixed), "can": w("飞到台前按 [%s] 打开。", "At the console press [%s].") % Keys.label("use")}
	return {"lines": [], "bar": -1.0, "lamp": "off", "use": "", "now": "", "can": ""}
