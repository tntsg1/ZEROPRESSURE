extends RefCounted
# 102 号: the cargo district drawn as the warehouse it is (user 2026-10-28: "继续做仓库"). A hall:
# columns, roof trusses, high-bay lamps; two banks of pallet racking (A1–A4 left, B1–B4 right) with
# their uprights, orange beams, mesh decks, row plates and lamps; the stacker crane's runway; the
# floor's lanes, the hatch's frame and its cargo lift, the roller line, the forklifts' chargers, a
# pallet stack; and on the back wall the warehouse board, its rows read from the real stock and
# jobs. The still parts are one mesh per (power, level of detail); the reach trucks, the crane, the
# lift and the rollers are meshes built once and placed each frame (scripts/mesh_pen.gd); beacons,
# blue spots and the lamps brightening over a working truck are an additive layer. What moves and
# why: scripts/cargo_works.gd. Box-local metres (60 × 28, floor at 26.8).

const MeshPen = preload("res://scripts/mesh_pen.gd")
const FastDraw = preload("res://scripts/fast_draw.gd")
const W = preload("res://scripts/cargo_works.gd")

const FLOOR := 26.8
const HALL_COLS := [0.8, 18.6, 30.0, 39.6, 59.2]   # the hall's columns (0.6 m), from the truss down
const BAYS := [6.0, 42.0]          # the racks' left uprights; each bank 10 m, two 5 m bays
const BEAMS := [12.0, 15.0, 18.0, 21.0]
const RACK_TOP := 9.0
const BOARD := Rect2(19.4, 3.4, 21.2, 5.2)
const PALLETS := Rect2(53.0, 21.0, 5.0, 5.8)
const ROLLERS := Rect2(34.0, 25.4, 18.0, 0.5)
const HATCH := Rect2(27.5, FLOOR, 5.0, 1.2)
const CHARGERS := [23.4, 36.6]
const LAMPS := [6.0, 18.0, 30.0, 42.0, 54.0]

const FACE := Color(0.118, 0.124, 0.136)
const FACE2 := Color(0.15, 0.158, 0.172)
const DARK := Color(0.06, 0.064, 0.072)
const VOID := Color(0.025, 0.027, 0.031)
const BEAM_COL := Color(0.78, 0.42, 0.16)

var font: Font
var r := Rect2()
var m := 1.0
var _meshes := {}


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


func _ink(a: float) -> Color:
	# 2026-11-12: the solid look's line art (DistrictStyle.ink: faint lines dark into the faces,
	# outlines light round them; opaque, never white in alpha under hdr_2d)
	return DistrictStyle.ink(a)


func _p(v: Vector2) -> Vector2:
	return r.position + v * m


func _mesh(key: String, build: Callable) -> ArrayMesh:
	# 2026-11-12 (user: "纯2D、纯扁平，没有一点质感"): the casings as lit steel (scripts/solid_pen.gd)
	if DistrictStyle.solid():
		key = "solid/" + key
	if not _meshes.has(key):
		var pen = preload("res://scripts/solid_pen.gd").new() if DistrictStyle.solid() else MeshPen.new()
		if DistrictStyle.solid():
			pen.tinted = true
		build.call(pen)
		_meshes[key] = pen.mesh()
	return _meshes[key]


func _put(ci: CanvasItem, mesh: ArrayMesh, at: Vector2, rot := 0.0, mod := Color.WHITE, k := Vector2.ONE) -> void:
	if mesh.get_surface_count() == 0:
		return
	ci.draw_mesh(mesh, null, Transform2D(rot, Vector2(m * k.x, m * k.y), 0.0, _p(at)), mod)


func _text(ci, at: Vector2, s: String, size_m: float, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width_m := -1.0) -> void:
	ci.draw_string(font, _p(at), s, align, width_m * m if width_m > 0.0 else -1.0, int(size_m * m), col)


static func lamp_col(state: String, t: float) -> Color:
	match state:
		"ok": return Pal.tint(Pal.FLUID, 0.95, 1.3)
		"work": return Pal.heat(0.65 + 0.35 * absf(sin(t * 4.0)), 1.3)
	return Pal.ink(0.22)


# goods carried by a truck or the crane: GoodsArt's picture (dozens of polygons and circles, each a
# dear draw call) recorded once into a mesh per goods, then placed in a rect
class GoodsPen:
	var pen = preload("res://scripts/mesh_pen.gd").new()

	func draw_colored_polygon(pts: PackedVector2Array, col: Color, _uv = null, _tex = null) -> void:
		if pts.size() >= 3:
			pen.poly(pts, col)

	func draw_polygon(pts: PackedVector2Array, cols: PackedColorArray, _uv = null, _tex = null) -> void:
		if pts.size() >= 3:
			var c := Color(0, 0, 0, 0)
			for k in cols:
				c += k
			pen.poly(pts, c / maxf(1.0, cols.size()))

	func draw_polyline(pts: PackedVector2Array, col: Color, w := 1.0, _aa := false) -> void:
		pen.polyline(pts, col, maxf(w, 0.8))

	func draw_line(a: Vector2, b: Vector2, col: Color, w := 1.0, _aa := false) -> void:
		pen.line(a, b, col, maxf(w, 0.8))

	func draw_circle(c: Vector2, rr: float, col: Color, _filled := true, _w := -1.0, _aa := false) -> void:
		pen.circle(c, rr, col, 12)

	func draw_arc(c: Vector2, rr: float, a0: float, a1: float, n: int, col: Color, w := 1.0, _aa := false) -> void:
		pen.arc(c, rr, a0, a1, col, maxf(w, 0.8), maxi(4, n))

	func draw_string(_f, _p, _s, _a = 0, _w = -1.0, _sz = 16, _c = Color.WHITE) -> void:
		pass


func _goods(ci: CanvasItem, key: String, rect: Rect2, rot := 0.0) -> void:
	if not _meshes.has("goods/" + key):
		var gp := GoodsPen.new()
		var parts: PackedStringArray = key.split(":")
		GoodsArt.draw(gp, Rect2(0, 0, 160, 100), parts[0], int(parts[1]) if parts.size() > 1 else 0)
		_meshes["goods/" + key] = gp.pen.mesh()
	var mesh: ArrayMesh = _meshes["goods/" + key]
	var k := minf(rect.size.x / 160.0, rect.size.y / 100.0)
	var c := rect.get_center()
	ci.draw_mesh(mesh, null, Transform2D(rot, Vector2(k, k), 0.0, c) * Transform2D(0.0, -Vector2(80, 50)))


# ================================================================== the still parts
func still(ci: CanvasItem, on: bool, lod: int) -> void:
	ci.draw_rect(r, Color(0, 0, 0, 0), false, 1.0)
	var open := DistrictStyle.on() and DistrictStyle.halls
	_put(ci, _mesh("still%d%d%d" % [int(on), lod, int(open)], func(p): _still(p, on, lod)), Vector2.ZERO)
	for b in 2:
		for lv in 4:
			_text(ci, Vector2(float(BAYS[b]) - 1.55, BEAMS[lv] + 0.12), Warehouse.ROWS[b * 4 + lv], 0.5, _ink(0.85))
	# 106 号: the ingots kept to be processed, by ship, beside the first ingot row
	var kept: Array = []
	for e in ProcessQueue.entries():
		if float(e.t) - float(e.melted) >= ProcessQueue.HEAT_MIN:
			kept.append("%s %.1f t" % [Methods.ship_label(str(e.ship)), float(e.t) - float(e.melted)])
	if not kept.is_empty():
		var rows: Array = Warehouse.rows()
		for i in rows.size():
			if str(rows[i]) == "ingot":
				_text(ci, Vector2(float(BAYS[i / 4]) + 0.4, BEAMS[i % 4] + 0.12), w("待加工 ", "TO PROCESS ") + " · ".join(kept.slice(0, 3)), 0.42, Pal.tint(Pal.AIR, 0.9, 1.2))
				break
	_text(ci, Vector2(33.2, FLOOR - 0.35), w("叉车通道 限速 5 km/h", "FORKLIFT LANE 5 km/h"), 0.34, Pal.heat(0.6, 1.0))
	_text(ci, Vector2(BOARD.position.x + 0.4, BOARD.position.y + 0.62), w("仓储看板 · WMS", "WAREHOUSE BOARD · WMS"), 0.42, Pal.tint(Pal.AIR, 0.85, 1.2))


func _still(p, on: bool, lod: int) -> void:
	var lit := 1.0 if on else 0.35
	# ---- the hall
	# 2026-11-12 (user: "我能走的地方应该没有柱子才对，是空的"): with the districts' halls on, a column
	# is drawn only where it stands in something that really collides (DistrictStyle.column_spans); the
	# two at the end walls are the shell's
	var open := DistrictStyle.on() and DistrictStyle.halls
	for cx: float in HALL_COLS:
		var spans: Array = [Vector2(1.3, FLOOR)] if not open or cx < 1.0 or cx > 59.0 else DistrictStyle.column_spans("cargo", cx, 1.3, FLOOR)
		for sp: Vector2 in spans:
			p.rect(Rect2(cx - 0.3, sp.x, 0.6, sp.y - sp.x), Color(0.07, 0.074, 0.082))
			p.line(Vector2(cx - 0.3, sp.x), Vector2(cx - 0.3, sp.y), _ink(0.12), 0.04)
			p.line(Vector2(cx + 0.3, sp.x), Vector2(cx + 0.3, sp.y), _ink(0.12), 0.04)
		if not spans.is_empty() and (spans[-1] as Vector2).y >= FLOOR - 0.01:
			p.rect(Rect2(cx - 0.6, FLOOR - 0.22, 1.2, 0.22), DARK)
	p.line(Vector2(0.3, 0.4), Vector2(59.7, 0.4), _ink(0.17), 0.12)
	p.line(Vector2(0.3, 1.3), Vector2(59.7, 1.3), _ink(0.17), 0.1)
	var tx := 0.3
	var up := true
	while tx < 59.7:
		var nx := minf(tx + 1.25, 59.7)
		p.line(Vector2(tx, 1.3 if up else 0.4), Vector2(nx, 0.4 if up else 1.3), _ink(0.1), 0.05)
		tx = nx
		up = not up
	# the stacker crane's runway under the trusses
	p.rect(Rect2(5.4, 1.75, 49.2, 0.5), Color(0.09, 0.094, 0.104))
	p.line(Vector2(5.4, 1.75), Vector2(54.6, 1.75), _ink(0.4), 0.05)
	p.rect(Rect2(5.4, 1.62, 49.2, 0.13), _ink(0.5))
	for hx: float in [8.0, 18.6, 30.0, 39.6, 52.0]:
		p.line(Vector2(hx, 1.3), Vector2(hx, 1.75), _ink(0.35), 0.08)
	for lx: float in LAMPS:
		p.poly(PackedVector2Array([Vector2(lx - 0.32, 1.72), Vector2(lx + 0.32, 1.72), Vector2(lx + 3.6, FLOOR), Vector2(lx - 3.6, FLOOR)]), Color(0.85, 0.92, 1.0, 0.026 * lit))
		p.poly(PackedVector2Array([Vector2(lx - 0.45, 1.3), Vector2(lx + 0.45, 1.3), Vector2(lx + 0.34, 1.72), Vector2(lx - 0.34, 1.72)]), FACE2)
		p.line(Vector2(lx - 0.3, 1.72), Vector2(lx + 0.3, 1.72), Color(0.92, 0.96, 1.0, 0.95 if on else 0.2), 0.06)
	# ---- the floor: the slab, the lanes, the hatch's striped frame
	p.rect(Rect2(0.0, FLOOR, 60.0, 1.2), Color(0.055, 0.058, 0.066))
	p.line(Vector2(0.0, FLOOR), Vector2(HATCH.position.x, FLOOR), _ink(0.36), 0.06)
	p.line(Vector2(HATCH.end.x, FLOOR), Vector2(60.0, FLOOR), _ink(0.36), 0.06)
	var dx := 5.0
	while dx < 56.0:
		if dx < HATCH.position.x - 1.0 or dx > HATCH.end.x + 1.0:
			p.line(Vector2(dx, FLOOR - 0.04), Vector2(dx + 0.9, FLOOR - 0.04), Pal.heat(0.6, 0.95), 0.07)
		dx += 1.5
	p.hatch(Rect2(HATCH.position.x - 0.9, FLOOR - 0.12, 0.9, 0.12), Pal.heat(0.85, 1.0), 0.06, 0.2)
	p.hatch(Rect2(HATCH.end.x, FLOOR - 0.12, 0.9, 0.12), Pal.heat(0.85, 1.0), 0.06, 0.2)
	p.rect(Rect2(HATCH.position.x - 0.15, FLOOR, 0.15, 1.2), DARK)
	p.rect(Rect2(HATCH.end.x, FLOOR, 0.15, 1.2), DARK)
	p.rect(Rect2(HATCH.position.x, FLOOR + 0.05, HATCH.size.x, 1.15), VOID)
	# ---- the racks
	for b in 2:
		var x0: float = BAYS[b]
		var solid := DistrictStyle.solid()
		for k in 3:
			var ux := x0 + k * 5.0
			p.rect(Rect2(ux - 0.13, RACK_TOP, 0.26, FLOOR - RACK_TOP), Color(0.26, 0.28, 0.31))
			p.line(Vector2(ux - 0.13, RACK_TOP), Vector2(ux - 0.13, FLOOR), _ink(0.55), 0.03)
			# 2026-11-12 (the solid look, user: "看不到任何改动"): where the rack collides, the upright a
			# solid steel column 0.5 m wide (scripts/solid_pen.gd shades it: lit edge, dark side, shadow),
			# its bolt holes down its face; the thin upright as before where the bank stands open
			if solid:
				for sp: Vector2 in DistrictStyle.column_spans("cargo", ux, RACK_TOP, FLOOR):
					p.rect(Rect2(ux - 0.25, sp.x, 0.5, sp.y - sp.x), Color(0.1, 0.104, 0.115))
					var hy2 := sp.x + 0.3
					while hy2 < sp.y - 0.2:
						p.rect(Rect2(ux - 0.05, hy2, 0.1, 0.12), Color(0.03, 0.032, 0.036))
						hy2 += 0.4
			p.rect(Rect2(ux - 0.3, FLOOR - 0.12, 0.6, 0.12), DARK)
			if lod > 0:
				var hy := RACK_TOP + 0.3
				while hy < FLOOR - 0.3:
					p.rect(Rect2(ux - 0.04, hy, 0.08, 0.12), Color(0.12, 0.13, 0.14))
					hy += 0.35
		p.rect(Rect2(x0 - 0.13, RACK_TOP - 0.2, 10.26, 0.2), Color(0.26, 0.28, 0.31))
		# (the solid look: the bank's top ring beam, within its collision 8.8 m down)
		if DistrictStyle.solid():
			p.rect(Rect2(x0 - 0.13, 8.8, 10.26, 0.5), Color(0.1, 0.104, 0.115))
		for by: float in BEAMS:
			# the beam pair's face, its mesh deck behind, the load sign
			# (the solid look: a box beam as deep as the rack's collision there allows, up to 0.45 m —
			# shaded in its orange by the pen — its end plates bolted to the uprights)
			var bh := 0.26
			if solid:
				var sps: Array = DistrictStyle.column_spans("cargo", x0 + 5.0, by, by + 0.45)
				if not sps.is_empty() and (sps[0] as Vector2).x <= by + 0.001:
					bh = maxf(0.26, (sps[0] as Vector2).y - by)
			p.rect(Rect2(x0, by, 10.0, bh), BEAM_COL)
			if solid and bh > 0.3:
				for ex: float in [x0 + 0.25, x0 + 9.75]:
					p.rect(Rect2(ex - 0.12, by - 0.04, 0.24, bh + 0.08), Color(0.12, 0.125, 0.135))
			p.line(Vector2(x0, by), Vector2(x0 + 10.0, by), Color(1.0, 0.7, 0.45, 0.9), 0.035)
			p.rect(Rect2(x0 + 0.15, by - 0.08, 9.7, 0.08), Color(0.2, 0.21, 0.23))
			if lod > 0:
				var gx := x0 + 0.4
				while gx < x0 + 9.8:
					p.line(Vector2(gx, by - 0.08), Vector2(gx, by), _ink(0.25), 0.015)
					gx += 0.3
			# the row's plate at its left, the lamp beside it is drawn each frame
			p.rect(Rect2(x0 - 1.65, by + 0.0, 1.45, 0.62), Color(0.02, 0.022, 0.026))
			p.rect(Rect2(x0 - 1.65, by + 0.0, 1.45, 0.62), _ink(0.45), false, 0.03)
		# the bank's anchor plate and its column guards
		for k in 3:
			var gx2 := x0 + k * 5.0
			p.poly(PackedVector2Array([Vector2(gx2 - 0.32, FLOOR), Vector2(gx2 + 0.32, FLOOR), Vector2(gx2 + 0.32, FLOOR - 0.7), Vector2(gx2 - 0.32, FLOOR - 0.7)]), Color(0.8, 0.62, 0.15, 0.8))
			p.hatch(Rect2(gx2 - 0.32, FLOOR - 0.7, 0.64, 0.7), Color(0.08, 0.08, 0.08), 0.08, 0.22)
	# ---- the roller line on its stands
	p.rect(Rect2(ROLLERS.position.x, ROLLERS.position.y + 0.35, ROLLERS.size.x, 0.3), Color(0.09, 0.094, 0.104))
	p.line(Vector2(ROLLERS.position.x, ROLLERS.position.y + 0.35), Vector2(ROLLERS.end.x, ROLLERS.position.y + 0.35), _ink(0.45), 0.04)
	var lx2 := ROLLERS.position.x + 0.5
	while lx2 < ROLLERS.end.x:
		p.line(Vector2(lx2, ROLLERS.position.y + 0.65), Vector2(lx2, FLOOR), _ink(0.35), 0.1)
		lx2 += 3.0
	p.rect(Rect2(ROLLERS.end.x - 1.2, ROLLERS.position.y + 0.7, 1.0, 0.6), FACE2)
	# ---- the forklifts' chargers by their parking spots
	for cx2: float in CHARGERS:
		p.rect(Rect2(cx2 - 0.4, FLOOR - 1.7, 0.8, 1.7), FACE2)
		p.rect(Rect2(cx2 - 0.4, FLOOR - 1.7, 0.8, 1.7), _ink(0.45), false, 0.035)
		p.rect(Rect2(cx2 - 0.25, FLOOR - 1.5, 0.5, 0.35), Color(0.04, 0.1, 0.11))
		p.line(Vector2(cx2, FLOOR - 0.3), Vector2(cx2 + (1.2 if cx2 < 30.0 else -1.2), FLOOR - 0.8), Color(0.15, 0.15, 0.16), 0.07)
	# ---- a stack of empty pallets (it stands where the solid is)
	var pl := PALLETS
	for k in 9:
		var py := FLOOR - 0.6 - k * 0.6
		p.rect(Rect2(pl.position.x + 0.2, py, pl.size.x - 0.4, 0.14), Color(0.42, 0.33, 0.22))
		for bx: float in [pl.position.x + 0.3, pl.get_center().x - 0.25, pl.end.x - 0.8]:
			p.rect(Rect2(bx, py + 0.14, 0.5, 0.32), Color(0.34, 0.26, 0.17))
		p.rect(Rect2(pl.position.x + 0.2, py + 0.46, pl.size.x - 0.4, 0.14), Color(0.42, 0.33, 0.22))
		p.line(Vector2(pl.position.x + 0.2, py), Vector2(pl.end.x - 0.2, py), Color(0.6, 0.5, 0.36), 0.03)
	p.line(Vector2(pl.get_center().x - 1.0, pl.position.y + 1.4), Vector2(pl.get_center().x - 1.0, FLOOR), Color(0.2, 0.22, 0.25), 0.05)
	# ---- the board's frame (its screen is drawn four times a second)
	p.rect(BOARD.grow(0.15), FACE2)
	p.rect(BOARD, Color(0.02, 0.035, 0.04))
	p.rect(BOARD.grow(0.15), _ink(0.5), false, 0.05)
	for bx2: float in [BOARD.position.x + 3.0, BOARD.end.x - 3.0]:
		p.line(Vector2(bx2, 1.3), Vector2(bx2, BOARD.position.y - 0.15), _ink(0.35), 0.06)


# ================================================================== the moving parts
# the hatch's lift and doors (in the floor, behind the trucks)
func moving_back(ci: CanvasItem, t: float, on: bool, game) -> void:
	var h := HATCH
	var deck_y := FLOOR + 1.1 - 1.1 * W.lift
	if W.lift > 0.01:
		ci.draw_rect(Rect2(_p(Vector2(h.position.x + 0.15, deck_y)), Vector2(h.size.x - 0.3, 0.22) * m), Color(0.2, 0.21, 0.23))
		ci.draw_rect(Rect2(_p(Vector2(h.position.x + 0.15, deck_y)), Vector2(h.size.x - 0.3, 0.05) * m), Pal.heat(0.8, 1.0))
		ci.draw_line(_p(Vector2(h.get_center().x, deck_y + 0.22)), _p(Vector2(h.get_center().x, FLOOR + 1.2)), _ink(0.45), 0.18 * m)
	var dw := h.size.x * 0.5 * (1.0 - W.doors)
	ci.draw_rect(Rect2(_p(Vector2(h.position.x, FLOOR - 0.06)), Vector2(dw, 0.12) * m), FACE2)
	ci.draw_rect(Rect2(_p(Vector2(h.end.x - dw, FLOOR - 0.06)), Vector2(dw, 0.12) * m), FACE2)
	if W.doors > 0.02 and fmod(t, 0.5) < 0.25:
		FastDraw.circle(ci, _p(Vector2(h.position.x - 0.5, FLOOR - 0.5)), 0.14 * m, Pal.heat(1.0, 1.6))
		FastDraw.circle(ci, _p(Vector2(h.end.x + 0.5, FLOOR - 0.5)), 0.14 * m, Pal.heat(1.0, 1.6))
	# the rows' lamps: lit while a truck works at the row
	for i in 8:
		var b := i / 4
		var by: float = BEAMS[i % 4]
		var col: Color = lamp_col("work" if W.busy_rows.has(i) else ("ok" if on else ""), t)
		FastDraw.circle(ci, _p(Vector2(float(BAYS[b]) - 0.42, by + 0.31)), 0.13 * m, col)
	# the board's lamp by each row a truck works on
	if on:
		var jobs: Array = Warehouse.data().jobs
		for i2 in 8:
			if fmod(t, 0.5) < 0.25 and jobs.any(func(j): return int(j.row) == i2):
				var cx := BOARD.position.x + 0.5 + (i2 / 4) * (BOARD.size.x * 0.5)
				var cy := BOARD.position.y + 1.25 + (i2 % 4) * 0.95
				FastDraw.circle(ci, _p(Vector2(cx - 0.25, cy + 0.2)), 0.12 * m, Pal.heat(1.0, 1.6))
	# the chargers' lamps: green while their truck is home
	for i in 2:
		var home: bool = i < W.trucks.size() and absf(float(W.trucks[i].x) - W.PARK[i]) < 0.2 and str(W.trucks[i].job) == ""
		ci.draw_rect(Rect2(_p(Vector2(CHARGERS[i] - 0.2, FLOOR - 1.42)), Vector2(0.4, 0.2) * m), Pal.tint(Pal.FLUID, 0.9, 1.3) if home and on else Color(0.1, 0.18, 0.18))


# in front: the reach trucks, the stacker crane and its load, the rollers
func front(ci: CanvasItem, t: float, on: bool, lod: int, game) -> void:
	ci.draw_rect(r, Color(0, 0, 0, 0), false, 1.0)
	var roller := _mesh("roller", func(p):
		p.circle(Vector2.ZERO, 0.22, Color(0.2, 0.205, 0.215), 12)
		p.ring(Vector2.ZERO, 0.22, _ink(0.55), 0.03, 12)
		p.line(Vector2(-0.18, 0.0), Vector2(0.18, 0.0), _ink(0.5), 0.035))
	var rx := ROLLERS.position.x + 0.5
	var k := 0
	while rx < ROLLERS.end.x:
		_put(ci, roller, Vector2(rx, ROLLERS.position.y + 0.15), W.rollers + k * 0.6)
		rx += 1.0
		k += 1
	_crane(ci, t)
	for i in W.trucks.size():
		_truck(ci, t, i, lod)


func _crane(ci: CanvasItem, t: float) -> void:
	var trolley := _mesh("trolley", func(p):
		p.rect(Rect2(-1.6, -0.55, 3.2, 0.9), FACE2)
		p.rect(Rect2(-1.6, -0.55, 3.2, 0.9), _ink(0.6), false, 0.045)
		p.hatch(Rect2(-1.55, -0.5, 0.45, 0.8), Pal.heat(0.75, 1.0), 0.06, 0.2)
		p.hatch(Rect2(1.1, -0.5, 0.45, 0.8), Pal.heat(0.75, 1.0), 0.06, 0.2)
		p.circle(Vector2(0.0, 0.0), 0.3, DARK, 14)
		p.ring(Vector2(0.0, 0.0), 0.3, _ink(0.45), 0.03, 14)
		for wx: float in [-1.0, 1.0]:
			p.circle(Vector2(wx, -0.62), 0.16, _ink(0.45), 10))
	_put(ci, trolley, Vector2(W.cx, 2.75))
	var top := Vector2(W.cx, 3.1)
	var hook := top + Vector2(0.0, W.hook - 3.1).rotated(W.sway)
	ci.draw_line(_p(top + Vector2(-0.15, 0.0)), _p(hook + Vector2(-0.15, -0.5).rotated(W.sway)), _ink(0.65), maxf(1.0, 0.035 * m))
	ci.draw_line(_p(top + Vector2(0.15, 0.0)), _p(hook + Vector2(0.15, -0.5).rotated(W.sway)), _ink(0.65), maxf(1.0, 0.035 * m))
	var block := _mesh("block", func(p):
		p.rect(Rect2(-0.4, -0.55, 0.8, 0.45), Color(0.85, 0.62, 0.2))
		p.rect(Rect2(-0.4, -0.55, 0.8, 0.45), _ink(0.6), false, 0.03)
		# the spreader the goods hang from
		p.rect(Rect2(-1.3, -0.1, 2.6, 0.18), DARK)
		p.rect(Rect2(-1.3, -0.1, 2.6, 0.18), _ink(0.55), false, 0.03)
		for sx: float in [-1.2, 1.2]:
			p.line(Vector2(sx, 0.08), Vector2(sx, 0.35), _ink(0.5), 0.04))
	_put(ci, block, hook, W.sway)
	if W.crane_load != "":
		var hh := 2.4 * 100.0 / 160.0
		var c := hook + Vector2(0.0, 0.3 + hh * 0.5).rotated(W.sway)
		_goods(ci, W.crane_load, Rect2(_p(c - Vector2(1.2, hh * 0.5)), Vector2(2.4, hh) * m), W.sway)
	if absf(W.vcx) > 0.05 and fmod(t, 0.6) < 0.3:
		FastDraw.circle(ci, _p(Vector2(W.cx, 2.0)), 0.12 * m, Pal.heat(1.0, 1.6))


# a reach truck in profile, facing its rack (+x right): the chassis and cab, the counterweight, the
# drive wheel and the outriggers' load wheels; the mast in three stages telescoping to the forks'
# height; the carriage reaching forward on its pantograph; what it carries on the forks
func _truck(ci: CanvasItem, t: float, i: int, lod: int) -> void:
	var tr: Dictionary = W.trucks[i]
	var x: float = tr.x
	var face: float = tr.face
	var fork: float = tr.fork
	var body := _mesh("truck_body", func(p):
		# counterweight and chassis (the rear to the left), the battery's lid, the cab's guard
		p.poly(PackedVector2Array([Vector2(-1.7, -0.25), Vector2(-1.7, -1.15), Vector2(-1.45, -1.35), Vector2(0.55, -1.35), Vector2(0.55, -0.25)]), Color(0.86, 0.6, 0.18))
		p.polyline(PackedVector2Array([Vector2(-1.7, -0.25), Vector2(-1.7, -1.15), Vector2(-1.45, -1.35), Vector2(0.55, -1.35), Vector2(0.55, -0.25)]), _ink(0.7), 0.04, true)
		p.rect(Rect2(-1.6, -0.75, 0.9, 0.42), Color(0.18, 0.18, 0.19))
		p.hatch(Rect2(-1.6, -0.75, 0.9, 0.42), Color(0.08, 0.08, 0.08), 0.05, 0.16)
		for px: float in [-1.35, 0.3]:
			p.line(Vector2(px, -1.35), Vector2(px, -2.45), _ink(0.6), 0.07)
		p.line(Vector2(-1.45, -2.45), Vector2(0.45, -2.45), _ink(0.65), 0.08)
		p.hatch(Rect2(-1.35, -2.5, 1.65, 0.12), _ink(0.35), 0.03, 0.15)
		# the operator's seat and wheel
		p.rect(Rect2(-0.95, -1.75, 0.45, 0.4), Color(0.1, 0.1, 0.11))
		p.line(Vector2(-0.1, -1.35), Vector2(0.05, -1.7), _ink(0.5), 0.04)
		p.line(Vector2(-0.05, -1.72), Vector2(0.18, -1.68), _ink(0.6), 0.05)
		# the outriggers forward to the load wheels
		p.rect(Rect2(0.5, -0.32, 1.25, 0.18), Color(0.25, 0.26, 0.28))
		p.line(Vector2(0.5, -0.32), Vector2(1.75, -0.32), _ink(0.55), 0.03)
		# the beacon's dome, the headlamp
		p.rect(Rect2(-0.6, -2.66, 0.28, 0.16), Color(0.5, 0.3, 0.1))
		p.circle(Vector2(0.55, -1.05), 0.08, Color(0.95, 0.95, 0.9), 8)
		# the mast's outer stage, fixed to the chassis
		p.rect(Rect2(0.62, -4.8, 0.12, 4.6), Color(0.3, 0.31, 0.33))
		p.rect(Rect2(0.86, -4.8, 0.12, 4.6), Color(0.3, 0.31, 0.33))
		p.line(Vector2(0.62, -4.8), Vector2(0.98, -4.8), _ink(0.55), 0.05))
	var wheel := _mesh("truck_wheel", func(p):
		p.circle(Vector2.ZERO, 0.3, Color(0.08, 0.08, 0.085), 14)
		p.ring(Vector2.ZERO, 0.3, _ink(0.55), 0.04, 14)
		p.line(Vector2(-0.22, 0.0), Vector2(0.22, 0.0), _ink(0.5), 0.04)
		p.circle(Vector2.ZERO, 0.08, _ink(0.6), 6))
	var stage := _mesh("truck_stage", func(p):
		p.rect(Rect2(0.0, -4.6, 0.1, 4.6), Color(0.4, 0.41, 0.43))
		p.line(Vector2(0.0, -4.6), Vector2(0.0, 0.0), _ink(0.65), 0.025)
		p.line(Vector2(-0.02, -4.6), Vector2(0.12, -4.6), _ink(0.7), 0.05))
	var forks := _mesh("truck_forks", func(p):
		# the carriage with its backrest, the two forks seen as one
		p.rect(Rect2(0.0, -1.2, 0.16, 1.25), Color(0.32, 0.33, 0.35))
		for ry in 4:
			p.line(Vector2(0.0, -1.15 + ry * 0.3), Vector2(0.16, -1.15 + ry * 0.3), _ink(0.4), 0.03)
		p.rect(Rect2(0.0, -0.06, 1.25, 0.1), Color(0.55, 0.56, 0.58))
		p.line(Vector2(0.0, -0.06), Vector2(1.25, -0.06), _ink(0.75), 0.025))
	var sx := Vector2(face, 1.0)
	var base := Vector2(x, FLOOR)
	_put(ci, body, base, 0.0, Color.WHITE, sx)
	_put(ci, wheel, base + Vector2(-1.1 * face, -0.3), float(tr.wheel) * face)
	_put(ci, wheel, base + Vector2(1.55 * face, -0.12), float(tr.wheel) * 2.0 * face, Color.WHITE, Vector2(0.45, 0.45))
	# a four-stage high-reach mast: the carriage's free lift inside the inner stage, then the three
	# inner stages share the rest, each overlapping the one it slides in
	var lift := maxf(0.0, (FLOOR - 0.25) - fork - 4.0)
	for k2 in 3:
		_put(ci, stage, base + Vector2((0.68 + 0.08 * k2) * face, -0.2 - lift * (k2 + 1) / 3.0), 0.0, Color.WHITE, sx)
	var reach := float(tr.reach) * 0.9
	var fork_at := Vector2(x + (1.0 + reach) * face, fork)
	if reach > 0.02:
		ci.draw_line(_p(Vector2(x + 0.95 * face, fork - 0.6)), _p(fork_at + Vector2(0.0, -0.6)), _ink(0.5), maxf(1.0, 0.05 * m))
	_put(ci, forks, fork_at, 0.0, Color.WHITE, sx)
	# the lift chains from the mast's head to the carriage
	ci.draw_line(_p(Vector2(x + 0.92 * face, FLOOR - 0.2 - 4.6 - lift)), _p(fork_at + Vector2(0.02 * face, -1.2)), Color(0.18, 0.18, 0.2), maxf(1.0, 0.04 * m))
	var load := str(tr.load)
	if load != "":
		var hh := 2.0 * 100.0 / 160.0
		var lx := fork_at.x + 0.1 * face + (0.0 if face > 0.0 else -2.0)
		_goods(ci, load, Rect2(_p(Vector2(lx, fork - 0.06 - hh)), Vector2(2.0, hh) * m))
	# the beacon turning while it moves
	if absf(float(tr.vx)) > 0.05 or absf(float(tr.vf)) > 0.05:
		var b := 0.5 + 0.5 * sin(float(tr.beacon) * 2.0)
		FastDraw.circle(ci, _p(base + Vector2(-0.46 * face, -2.68)), 0.13 * m, Pal.heat(0.5 + 0.5 * b, 1.7))
	if lod > 0:
		_text(ci, base + Vector2(-1.5 * face - (0.0 if face > 0.0 else 0.9), -0.45), "FL-%d" % (i + 1), 0.3, Color(0.1, 0.08, 0.05))


# ================================================================== the light
func glow(ci: CanvasItem, tex: Texture2D, t: float, game) -> void:
	var on := Port.stage("cargo") >= 1
	for lx: float in LAMPS:
		ci.draw_texture_rect(tex, Rect2(_p(Vector2(lx - 1.2, 1.2)), Vector2(2.4, 1.2) * m), false, Color(0.85, 0.92, 1.0, 0.18 if on else 0.0))
	for tr in W.trucks:
		var x: float = tr.x
		var moving: bool = absf(float(tr.vx)) > 0.05 or absf(float(tr.vf)) > 0.05
		# the lamp over a working truck brightens its stretch of aisle
		for lx: float in LAMPS:
			if absf(lx - x) < 6.0 and on:
				var k := 1.0 - absf(lx - x) / 6.0
				ci.draw_texture_rect(tex, Rect2(_p(Vector2(lx - 3.0, 8.0)), Vector2(6.0, FLOOR - 8.0) * m), false, Color(0.85, 0.92, 1.0, 0.07 * k))
		if moving:
			# the beacon's sweep and the blue spot thrown on the floor ahead
			var b := 0.5 + 0.5 * sin(float(tr.beacon) * 2.0)
			var face: float = tr.face
			var bp := _p(Vector2(x - 0.46 * face, FLOOR - 2.68))
			ci.draw_texture_rect(tex, Rect2(bp - Vector2(1.6, 1.6) * m, Vector2(3.2, 3.2) * m), false, Color(1.0, 0.55, 0.15, 0.35 * b))
			var dirx := signf(float(tr.vx)) if absf(float(tr.vx)) > 0.05 else face
			var spot := _p(Vector2(x + dirx * 3.2, FLOOR - 0.12))
			ci.draw_texture_rect(tex, Rect2(spot - Vector2(0.9, 0.25) * m, Vector2(1.8, 0.5) * m), false, Color(0.3, 0.6, 1.0, 0.75))


# ================================================================== the board and plates (four times a second)
func _row_t(i: int) -> float:
	var st: Dictionary = Career.data.get("exchange", {}).get("actors", {}).get("company", {}).get("stock", {})
	var s := 0.0
	for k in st:
		if Warehouse.row_for(str(k)) == i:
			s += float(st[k])
	return s


# what the board and the plates show: they are drawn again only when it changes (shaped text is dear)
func plates_sig(game) -> String:
	var parts: Array = [int(Port.stage("cargo") >= 1), Warehouse.forklifts(), str(Warehouse.rows())]
	for i in 8:
		parts.append("%.1f" % _row_t(i))
		parts.append(int(round(2.0 * Warehouse.dist(i) / (Warehouse.speed() * maxf(0.05, W._k)) + Warehouse.HANDLE)))
	for i in W.trucks.size():
		parts.append(str(W.truck_state(i)[0]))
	return "|".join(parts.map(func(x): return str(x)))


func plates(ci: CanvasItem, t: float, on: bool, game) -> void:
	ci.draw_rect(r, Color(0, 0, 0, 0), false, 1.0)
	if not on:
		return
	var b := BOARD
	var col := Pal.tint(Pal.AIR, 0.9, 1.3)
	var rows := Warehouse.rows()
	var jobs: Array = Warehouse.data().jobs
	for i in 8:
		var cx := b.position.x + 0.5 + (i / 4) * (b.size.x * 0.5)
		var cy := b.position.y + 1.25 + (i % 4) * 0.95
		var tons := _row_t(i)
		var job_on := jobs.any(func(j): return int(j.row) == i)
		var pick := int(round(2.0 * Warehouse.dist(i) / (Warehouse.speed() * maxf(0.05, Warehouse.k(game))) + Warehouse.HANDLE))
		_text(ci, Vector2(cx, cy + 0.36), "%s %s · %ds" % [Warehouse.ROWS[i], Warehouse.use_name(str(rows[i])), pick], 0.34, col if not job_on else Pal.heat(0.95, 1.3))
		var bar := Rect2(cx + 4.4, cy, 3.6, 0.36)
		ci.draw_rect(Rect2(_p(bar.position), bar.size * m), Color(0.1, 0.16, 0.17))
		ci.draw_rect(Rect2(_p(bar.position), Vector2(bar.size.x * clampf(tons / 6.0, 0.0, 1.0), bar.size.y) * m), Pal.tint(Pal.AIR, 0.75, 1.2))
		_text(ci, Vector2(cx + 8.2, cy + 0.34), "%.1f t" % tons, 0.32, Color(col, 0.85))
	_text(ci, Vector2(b.end.x - 6.6, b.position.y + 0.62), w("在途 %d 单 · 叉车 %d 台", "%d MOVES · %d TRUCKS") % [jobs.size(), Warehouse.forklifts()], 0.34, Color(col, 0.8))
	# the trucks' plates by their chargers
	for i in W.trucks.size():
		var st: Array = W.truck_state(i)
		var px: float = CHARGERS[i] - (5.6 if i == 0 else -0.6)
		var pr := Rect2(_p(Vector2(px, FLOOR - 4.95)), Vector2(5.0, 0.8) * m)
		ci.draw_rect(pr, Color(0.02, 0.022, 0.026, 0.9))
		var lc := lamp_col(str(st[1]), t)
		ci.draw_rect(Rect2(pr.position, Vector2(0.12 * m, pr.size.y)), lc)
		_text(ci, Vector2(px + 0.3, FLOOR - 4.4), "FL-%d  %s" % [i + 1, str(st[0])], 0.32, _ink(0.85), HORIZONTAL_ALIGNMENT_LEFT, 4.6)


# ================================================================== the hover cards
func hover_items(game) -> Array:
	var out: Array = []
	var add := func(rects: Array, title: String, use: String, now: Array, can: String) -> void:
		for rr in rects:
			out.append({"rect": Rect2(_p((rr as Rect2).position), (rr as Rect2).size * m), "title": title, "use": use, "now": str(now[0]), "can": can, "lamp": str(now[1])})
	var jobs: Array = Warehouse.data().jobs
	for b in 2:
		var rows_t := []
		for lv in 4:
			rows_t.append("%s %s %.1f t" % [Warehouse.ROWS[b * 4 + lv], Warehouse.use_name(str(Warehouse.rows()[b * 4 + lv])), _row_t(b * 4 + lv)])
		add.call([Rect2(float(BAYS[b]) - 1.7, RACK_TOP - 0.2, 11.9, FLOOR - RACK_TOP)], w("货架 %s（%s）" % ["A" if b == 0 else "B", "左" if b == 0 else "右"], "RACKS %s" % ["A" if b == 0 else "B"]),
			w("四层托盘货架，每层一排、各有用途。货物按真实库存放在对应的排上：%s。" % "；".join(rows_t), "Four levels of pallet racking, one row each with its use; the goods sit on their rows as the stock really stands: %s." % "; ".join(rows_t)),
			[w("%d 单在这一侧" % jobs.filter(func(j): return (int(j.row) < 4) == (b == 0)).size(), "%d moves this side" % jobs.filter(func(j): return (int(j.row) < 4) == (b == 0)).size()), "work" if jobs.any(func(j): return (int(j.row) < 4) == (b == 0)) else "ok"],
			w("飞到下面的货架口按 E 只看这一侧的货；在业务终端可以改每一排的用途。", "E at the mouth below opens this side's racks only; the business console changes what each row holds."))
	for i in W.trucks.size():
		var tr: Dictionary = W.trucks[i]
		add.call([Rect2(float(tr.x) - 1.8, minf(float(tr.fork) - 1.4, FLOOR - 3.4), 3.8, FLOOR - minf(float(tr.fork) - 1.4, FLOOR - 3.4))], w("前移式叉车 FL-%d" % (i + 1), "REACH TRUCK FL-%d" % (i + 1)),
			w("从地面舱口开到对应货架下，门架三级伸缩把货叉升到那一层，取货或上架后降下开回。出库和送料要等它把货搬到舱口。%s时开得慢。" % Grid.short_label(0).get_slice("—", 0), "Drives from the floor hatch to under its row, telescopes its mast up to the shelf, picks or puts away, lowers and comes back. Sales and the furnace's feed wait for it to bring goods to the hatch; short of power it crawls."),
			W.truck_state(i), w("货运区升到 1 级有两台叉车，2 级开得更快。", "Stage 1 of the cargo district gives two trucks, stage 2 faster ones."))
	add.call([Rect2(W.cx - 1.6, 1.6, 3.2, maxf(1.6, W.hook - 0.8))], w("堆垛吊车", "STACKER CRANE"),
		w("库存有变化时，从舱口把货吊上对应的货架（或从货架吊下），吊具随起停轻轻摆动。", "When the stock changes it lifts the goods from the hatch up to their row (or down from it), the spreader swinging a little as it starts and stops."),
		[w("吊运中", "lifting"), "work"] if W.crane_load != "" else [w("待命", "parked"), "ok"], w("不用操作。", "Nothing to do."))
	add.call([Rect2(HATCH.position.x - 1.0, FLOOR - 1.6, HATCH.size.x + 2.0, 2.8)], w("舱口升降台", "HATCH LIFT"),
		w("货物从下面的货场经这里进出仓库：叉车到舱口交接时舱门打开，升降台把货送上来或降下去。", "Goods come in and leave through here from the yard below: as a truck hands over, the doors open and the lift brings the goods up or takes them down."),
		[w("升起", "up"), "work"] if W.lift > 0.5 else [w("落下", "down"), "ok"], w("不用操作。", "Nothing to do."))
	add.call([BOARD], w("仓储看板", "WAREHOUSE BOARD"),
		w("八排货架各自的用途、存量和正在进行的出入库，数据都是实时的。", "Each of the eight rows' use, what it holds and the moves under way, live."),
		[w("在途 %d 单" % jobs.size(), "%d moves" % jobs.size()), "work" if not jobs.is_empty() else "ok"], w("改用途在业务终端。", "Change a row's use at the business console."))
	return out
