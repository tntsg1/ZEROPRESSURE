extends RefCounted
# 101 号: the processing district drawn as the steelworks it is (user 2026-10-28: "用拖船区、拆船区，
# 还有无人机那种极高精度的，把加工区给做完了……很惊艳"). A hall: columns, roof trusses, the crane
# runway, high-bay lamps throwing their light down; the fume system from the furnace's hood along
# the roof to the baghouse and its fan and stack; the furnace transformer with its radiators, fans,
# bushings and the bus to the electrode mast; the furnace deck with the control pulpit under it;
# the mill deck with the reheating furnace, its pusher, the descaler and a four-high stand. The
# still parts are one mesh per (power, level of detail), drawn only when those change; every part
# that moves — the crane and its basket, the fans, the reheating furnace's door and ram, the
# rolls and rollers — is a mesh built once and placed each frame (scripts/mesh_pen.gd); sparks,
# smoke and steam are particles (scripts/process_works.gd); the arcs light the hall through an
# additive layer. Box-local metres (60 × 28, floor at 26.8), as scripts/tug_station_art.gd.

const MeshPen = preload("res://scripts/mesh_pen.gd")
const FastDraw = preload("res://scripts/fast_draw.gd")
const W = preload("res://scripts/process_works.gd")

const FLOOR := 26.8
const DY := 2.65               # the furnace sits this far below the pre-processing line
const DECK_Y := 18.4           # the furnace deck's top
const MILL_DECK := 12.3        # the mill deck's top
const REHEAT := Rect2(38.8, 6.6, 4.4, 3.8)
const PASS_Y := 9.45           # the tables' top: the pass line
const FEED := Rect2(43.4, 9.5, 3.8, 0.8)
const STAND := Rect2(47.5, 5.4, 2.6, 6.8)
const RUNOUT := Rect2(50.4, 9.5, 5.0, 0.8)
const ROLL_Y := [8.53, 10.12]
const ROLL_R := 0.62
const BACKUP_R := 0.82
const PULPIT := Rect2(21.0, 21.0, 8.0, 5.8)
const TRAFO := Rect2(2.0, 20.0, 6.0, 6.8)
const BAG := Rect2(31.0, 19.0, 8.0, 7.8)
const FAN := Vector2(37.6, 16.9)
const STACK_X := 37.6

const FACE := Color(0.118, 0.124, 0.136)
const FACE2 := Color(0.15, 0.158, 0.172)
const DARK := Color(0.06, 0.064, 0.072)
const VOID := Color(0.025, 0.027, 0.031)
const GLASS := Color(0.05, 0.085, 0.1)

var font: Font
var r := Rect2()       # the box, world px
var m := 1.0           # px a metre
var _meshes := {}


func _ink(a: float) -> Color:
	return Pal.ink(a)


func _p(v: Vector2) -> Vector2:
	return r.position + v * m


func _mesh(key: String, build: Callable) -> ArrayMesh:
	if not _meshes.has(key):
		var pen := MeshPen.new()
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
		"warn": return Color(1.0, 0.3, 0.22, 0.6 + 0.4 * absf(sin(t * 2.5)))
	return Pal.ink(0.22)


# ================================================================== the still parts
func still(ci: CanvasItem, on: bool, lod: int) -> void:
	# the layer's bounds round the hall (a draw_mesh alone is culled by its untransformed box)
	ci.draw_rect(r, Color(0, 0, 0, 0), false, 1.0)
	_put(ci, _mesh("still%d%d" % [int(on), lod], func(p): _still(p, on, lod)), Vector2.ZERO)
	# stencils on the walls
	var dim := _ink(0.16)
	_text(ci, Vector2(39.0, 25.9), "PRC", 1.6, Color(dim, 0.2))
	if not Pal.labels:
		return
	_text(ci, Vector2(TRAFO.position.x + 0.7, 23.95), "EAF-T 36 MVA", 0.34, _ink(0.5))
	_text(ci, Vector2(REHEAT.position.x + 0.25, REHEAT.position.y + 0.55), w("加热炉 RH-1", "REHEAT RH-1"), 0.32, _ink(0.55))


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


func _still(p, on: bool, lod: int) -> void:
	var lit := 1.0 if on else 0.35
	# ---- the hall: columns, the roof truss, wall girts, the crane runway on its brackets
	for cx: float in [0.8, 10.0, 20.0, 30.0, 40.0, 50.0, 59.2]:
		p.rect(Rect2(cx - 0.3, 1.3, 0.6, FLOOR - 1.3), Color(0.07, 0.074, 0.082))
		p.line(Vector2(cx - 0.3, 1.3), Vector2(cx - 0.3, FLOOR), _ink(0.13), 0.04)
		p.line(Vector2(cx + 0.3, 1.3), Vector2(cx + 0.3, FLOOR), _ink(0.13), 0.04)
		p.line(Vector2(cx, 1.3), Vector2(cx, FLOOR), _ink(0.05), 0.03)
		p.rect(Rect2(cx - 0.6, FLOOR - 0.22, 1.2, 0.22), DARK)
		p.poly(PackedVector2Array([Vector2(cx + 0.3, 3.3), Vector2(cx + 0.9, 3.3), Vector2(cx + 0.3, 4.2)]), Color(0.08, 0.084, 0.094))
		p.poly(PackedVector2Array([Vector2(cx - 0.3, 3.3), Vector2(cx - 0.9, 3.3), Vector2(cx - 0.3, 4.2)]), Color(0.08, 0.084, 0.094))
		if lod > 0:
			for bx: float in [-0.42, 0.42]:
				p.bolt(Vector2(cx + bx, FLOOR - 0.11), 0.05, _ink(0.35))
	for gy: float in [9.5, 16.5, 22.5]:
		p.line(Vector2(0.3, gy), Vector2(59.7, gy), _ink(0.05), 0.08)
	p.line(Vector2(0.3, 0.4), Vector2(59.7, 0.4), _ink(0.17), 0.12)
	p.line(Vector2(0.3, 1.3), Vector2(59.7, 1.3), _ink(0.17), 0.1)
	var tx := 0.3
	var up := true
	while tx < 59.7:
		var nx := minf(tx + 1.25, 59.7)
		p.line(Vector2(tx, 1.3 if up else 0.4), Vector2(nx, 0.4 if up else 1.3), _ink(0.1), 0.05)
		tx = nx
		up = not up
	p.rect(Rect2(0.3, 2.6, 59.4, 0.7), Color(0.09, 0.094, 0.104))
	p.line(Vector2(0.3, 2.6), Vector2(59.7, 2.6), _ink(0.34), 0.05)
	p.line(Vector2(0.3, 3.3), Vector2(59.7, 3.3), _ink(0.22), 0.04)
	var sx := 1.0
	while sx < 59.5:
		p.line(Vector2(sx, 2.65), Vector2(sx, 3.25), _ink(0.1), 0.04)
		sx += 1.5
	p.rect(Rect2(0.3, 2.42, 59.4, 0.18), _ink(0.5))
	# ---- the high-bay lamps and the light they throw down
	for lx: float in [6.0, 18.0, 30.0, 42.0, 54.0]:
		p.poly(PackedVector2Array([Vector2(lx - 0.32, 1.72), Vector2(lx + 0.32, 1.72), Vector2(lx + 3.8, FLOOR), Vector2(lx - 3.8, FLOOR)]), Color(0.85, 0.92, 1.0, 0.028 * lit))
		p.poly(PackedVector2Array([Vector2(lx - 0.45, 1.3), Vector2(lx + 0.45, 1.3), Vector2(lx + 0.34, 1.72), Vector2(lx - 0.34, 1.72)]), FACE2)
		p.polyline(PackedVector2Array([Vector2(lx - 0.45, 1.3), Vector2(lx + 0.45, 1.3), Vector2(lx + 0.34, 1.72), Vector2(lx - 0.34, 1.72)]), _ink(0.45), 0.03, true)
		p.line(Vector2(lx - 0.3, 1.72), Vector2(lx + 0.3, 1.72), Color(0.92, 0.96, 1.0, 0.95 if on else 0.2), 0.06)
	# ---- the floor: the slab, its trench grating, the walkway's yellow edge
	p.rect(Rect2(0.0, FLOOR, 60.0, 1.2), Color(0.055, 0.058, 0.066))
	p.line(Vector2(0.0, FLOOR), Vector2(60.0, FLOOR), _ink(0.36), 0.06)
	p.hatch(Rect2(9.2, FLOOR + 0.12, 11.0, 0.4), _ink(0.1), 0.03, 0.18)
	var dx := 0.4
	while dx < 59.6:
		if not (dx > TRAFO.position.x - 0.2 and dx < TRAFO.end.x + 0.2) and not (dx > BAG.position.x - 0.2 and dx < BAG.end.x + 0.2) and not (dx > PULPIT.position.x and dx < PULPIT.end.x):
			p.line(Vector2(dx, FLOOR - 0.05), Vector2(dx + 0.6, FLOOR - 0.05), Pal.heat(0.55, 0.9), 0.07)
		dx += 1.0
	# ---- the cable tray along the wall, its cables
	p.rect(Rect2(8.4, 19.3, 12.0, 0.28), DARK)
	for k in 4:
		p.line(Vector2(8.5, 19.36 + k * 0.05), Vector2(20.3, 19.36 + k * 0.05), Color(0.16, 0.17, 0.18), 0.035)
	# ---- the scrap basket's stand: a platform on wall brackets over the transformer
	p.rect(Rect2(1.4, 7.4, 5.4, 0.26), FACE2)
	p.hatch(Rect2(1.5, 7.43, 5.2, 0.2), _ink(0.12), 0.025, 0.15)
	p.line(Vector2(1.4, 7.4), Vector2(6.8, 7.4), _ink(0.5), 0.04)
	for bx: float in [1.6, 6.6]:
		p.line(Vector2(bx, 7.4), Vector2(bx, 6.3), _ink(0.4), 0.05)
	p.line(Vector2(1.6, 6.3), Vector2(6.6, 6.3), _ink(0.4), 0.05)
	p.line(Vector2(0.8, 9.2), Vector2(2.6, 7.66), _ink(0.3), 0.08)
	p.line(Vector2(0.8, 9.2), Vector2(5.8, 7.66), _ink(0.22), 0.06)
	for sx2: float in [-1.0, 1.0]:
		p.rect(Rect2(W.STAND_X + sx2 * 1.0 - 0.25, 7.15, 0.5, 0.25), DARK)
	_duct(p, on, lod)
	_baghouse(p, on, lod)
	_transformer(p, on, lod)
	_decks(p, on, lod)
	_pulpit(p, on, lod)
	_reheat(p, on, lod)
	_mill_still(p, on, lod)
	# ---- the pre-processing line's outer frame: its hangers off the runway girder
	for hx: float in [6.6, 12.2, 22.6, 26.2]:
		p.line(Vector2(hx, 3.3), Vector2(hx, 7.9), _ink(0.22), 0.07)
		p.rect(Rect2(hx - 0.25, 7.75, 0.5, 0.18), DARK)


# the fume duct: hood over the furnace, up, along under the runway, down into the baghouse; flanges,
# a bellows by the hood, the damper and the spark box
func _duct(p, on: bool, lod: int) -> void:
	var d := 1.1
	var pts := [Vector2(16.0, 6.2), Vector2(16.0, 3.9), Vector2(35.0, 3.9), Vector2(35.0, BAG.position.y + 0.6)]
	var body := Color(0.105, 0.11, 0.122)
	for i in range(1, pts.size()):
		var a: Vector2 = pts[i - 1]
		var b: Vector2 = pts[i]
		var dir := (b - a).normalized()
		var n := dir.orthogonal() * d * 0.5
		var a2 := a - dir * (d * 0.5 if i > 1 else 0.0)
		var b2 := b + dir * (d * 0.5 if i < pts.size() - 1 else 0.0)
		p.poly(PackedVector2Array([a2 + n, b2 + n, b2 - n, a2 - n]), body)
		p.line(a2 + n, b2 + n, _ink(0.4), 0.045)
		p.line(a2 - n, b2 - n, _ink(0.28), 0.045)
		# a highlight along the lit side, flanges every 2.4 m
		p.line(a2 + n * 0.6, b2 + n * 0.6, _ink(0.08), 0.12)
		var len := a2.distance_to(b2)
		var k := 1.2
		while k < len - 0.6:
			var q := a2 + dir * k
			p.line(q + n * 1.12, q - n * 1.12, _ink(0.42), 0.12)
			if lod > 0:
				p.bolt(q + n * 1.05, 0.04, _ink(0.6))
				p.bolt(q - n * 1.05, 0.04, _ink(0.6))
			k += 2.4
	# the elbows' cheeks
	p.circle(Vector2(16.0, 3.9), d * 0.5, body, 16)
	p.circle(Vector2(35.0, 3.9), d * 0.5, body, 16)
	# the hood over the furnace
	var hood := PackedVector2Array([Vector2(12.6, 8.15), Vector2(19.4, 8.15), Vector2(16.8, 6.1), Vector2(15.2, 6.1)])
	p.poly(hood, Color(0.09, 0.094, 0.104))
	p.polyline(hood, _ink(0.5), 0.05, true)
	for k2 in 5:
		var f := (k2 + 1) / 6.0
		p.line(Vector2(lerpf(12.6, 19.4, f), 8.15), Vector2(lerpf(15.2, 16.8, f), 6.1), _ink(0.12), 0.03)
	p.line(Vector2(12.6, 8.15), Vector2(19.4, 8.15), Pal.heat(0.35 if on else 0.15, 1.0), 0.08)
	# the bellows above the hood
	for k3 in 6:
		var y := 5.0 + k3 * 0.13
		p.line(Vector2(15.38, y), Vector2(16.62, y), _ink(0.35), 0.05)
	# the damper on the run, its actuator and lever
	p.rect(Rect2(24.0, 3.2, 0.5, 1.4), DARK)
	p.rect(Rect2(23.6, 2.0, 1.3, 0.6), FACE2)
	p.rect(Rect2(23.6, 2.0, 1.3, 0.6), _ink(0.4), false, 0.03)
	p.line(Vector2(24.25, 2.6), Vector2(24.25, 3.25), _ink(0.5), 0.05)
	# the spark box before the baghouse, its cleanout door
	p.rect(Rect2(31.6, 3.05, 2.2, 1.7), Color(0.1, 0.105, 0.116))
	p.rect(Rect2(31.6, 3.05, 2.2, 1.7), _ink(0.45), false, 0.04)
	p.rect(Rect2(32.1, 3.4, 1.2, 1.0), _ink(0.18), false, 0.03)
	if lod > 0:
		for c: Vector2 in [Vector2(32.2, 3.5), Vector2(33.2, 3.5), Vector2(32.2, 4.3), Vector2(33.2, 4.3)]:
			p.bolt(c, 0.04, _ink(0.5))
	# the clamp bands holding the run under the girder
	var hx := 19.0
	while hx < 34.0:
		p.line(Vector2(hx, 3.3), Vector2(hx, 3.35), _ink(0.5), 0.12)
		p.line(Vector2(hx, 3.34), Vector2(hx, 4.46), _ink(0.2), 0.04)
		hx += 3.0


func _baghouse(p, on: bool, lod: int) -> void:
	var c := BAG
	var top := c.position.y + 0.6
	var casing := Rect2(c.position.x + 0.2, top, c.size.x - 0.4, 4.4)
	p.rect(casing, Color(0.1, 0.104, 0.115))
	p.rect(casing, _ink(0.5), false, 0.05)
	for k in 7:
		var x := casing.position.x + 0.5 + k * 1.1
		p.line(Vector2(x, casing.position.y), Vector2(x, casing.end.y), _ink(0.1), 0.06)
	# the cut-away: the bags hanging from the tube sheet
	var win := Rect2(casing.position.x + 0.55, top + 0.75, casing.size.x - 1.1, 3.2)
	p.rect(win, VOID)
	p.line(Vector2(win.position.x, win.position.y + 0.05), Vector2(win.end.x, win.position.y + 0.05), _ink(0.45), 0.08)
	for k in 5:
		var bx := win.position.x + 0.65 + k * 1.2
		p.rect(Rect2(bx - 0.32, win.position.y + 0.12, 0.64, 2.75), Color(0.2, 0.205, 0.215))
		p.line(Vector2(bx - 0.32, win.position.y + 0.12), Vector2(bx - 0.32, win.position.y + 2.87), _ink(0.35), 0.03)
		p.circle(Vector2(bx, win.position.y + 2.87), 0.32, Color(0.2, 0.205, 0.215), 10)
		for ring in 4:
			p.line(Vector2(bx - 0.32, win.position.y + 0.6 + ring * 0.6), Vector2(bx + 0.32, win.position.y + 0.6 + ring * 0.6), _ink(0.12), 0.025)
	p.rect(win, _ink(0.4), false, 0.05)
	# the pulse header along the top, its diaphragm valves
	p.rect(Rect2(casing.position.x + 0.3, top - 0.55, casing.size.x - 0.6, 0.32), FACE2)
	p.rect(Rect2(casing.position.x + 0.3, top - 0.55, casing.size.x - 0.6, 0.32), _ink(0.4), false, 0.03)
	for k in 5:
		var bx := win.position.x + 0.65 + k * 1.2
		p.rect(Rect2(bx - 0.18, top - 0.3, 0.36, 0.3), DARK)
		p.line(Vector2(bx, top), Vector2(bx, win.position.y + 0.1), _ink(0.3), 0.05)
	# the hopper, the rotary valve's body, the dust bin
	var hb := casing.end.y
	p.poly(PackedVector2Array([Vector2(casing.position.x, hb), Vector2(casing.end.x, hb), Vector2(35.55, 25.55), Vector2(34.45, 25.55)]), Color(0.09, 0.094, 0.104))
	p.polyline(PackedVector2Array([Vector2(casing.position.x, hb), Vector2(casing.end.x, hb), Vector2(35.55, 25.55), Vector2(34.45, 25.55)]), _ink(0.45), 0.05, true)
	p.circle(Vector2(35.0, 25.95), 0.42, DARK, 14)
	p.ring(Vector2(35.0, 25.95), 0.42, _ink(0.45), 0.04, 14)
	p.rect(Rect2(33.9, 26.3, 2.2, 0.5), FACE2)
	p.rect(Rect2(33.9, 26.3, 2.2, 0.5), _ink(0.4), false, 0.03)
	for lx: float in [31.5, 38.5]:
		p.line(Vector2(lx, hb), Vector2(lx, FLOOR), _ink(0.42), 0.14)
	p.line(Vector2(31.5, hb + 0.4), Vector2(38.5, FLOOR - 0.3), _ink(0.14), 0.05)
	p.line(Vector2(38.5, hb + 0.4), Vector2(31.5, FLOOR - 0.3), _ink(0.14), 0.05)
	# the differential pressure gauge's dial
	p.circle(Vector2(37.9, top + 4.0), 0.3, VOID, 14)
	p.ring(Vector2(37.9, top + 4.0), 0.3, _ink(0.5), 0.035, 14)
	# the clean side: up into the induced-draught fan, the stack through the roof
	var sd := 0.8
	p.rect(Rect2(STACK_X - sd * 0.5, 0.0, sd, FAN.y - 0.9), Color(0.1, 0.104, 0.115))
	p.line(Vector2(STACK_X - sd * 0.5, 0.0), Vector2(STACK_X - sd * 0.5, FAN.y - 0.9), _ink(0.4), 0.04)
	p.line(Vector2(STACK_X + sd * 0.5, 0.0), Vector2(STACK_X + sd * 0.5, FAN.y - 0.9), _ink(0.26), 0.04)
	var fy := 1.4
	while fy < FAN.y - 1.2:
		p.line(Vector2(STACK_X - 0.5, fy), Vector2(STACK_X + 0.5, fy), _ink(0.35), 0.09)
		fy += 2.4
	p.rect(Rect2(STACK_X - sd * 0.5, FAN.y + 0.9, sd, top - FAN.y - 0.9 - 0.55), Color(0.1, 0.104, 0.115))
	p.circle(FAN, 1.0, Color(0.1, 0.104, 0.115), 24)
	p.ring(FAN, 1.0, _ink(0.5), 0.06, 24)
	p.circle(FAN, 0.82, VOID, 24)
	p.rect(Rect2(FAN.x + 0.9, FAN.y - 0.45, 1.3, 0.9), FACE2)
	p.rect(Rect2(FAN.x + 0.9, FAN.y - 0.45, 1.3, 0.9), _ink(0.4), false, 0.03)
	for k in 4:
		p.line(Vector2(FAN.x + 1.05 + k * 0.3, FAN.y - 0.35), Vector2(FAN.x + 1.05 + k * 0.3, FAN.y + 0.35), _ink(0.16), 0.04)


func _transformer(p, on: bool, lod: int) -> void:
	var t := TRAFO
	var tank := Rect2(t.position.x + 0.6, t.position.y + 1.6, t.size.x - 1.2, 4.8)
	p.rect(Rect2(t.position.x + 0.2, FLOOR - 0.4, t.size.x - 0.4, 0.4), DARK)
	p.rect(tank, Color(0.1, 0.104, 0.115))
	p.rect(tank, _ink(0.5), false, 0.05)
	# the radiators: fin panels on both sides
	for side: float in [-1.0, 1.0]:
		var x0 := tank.position.x - 0.55 if side < 0.0 else tank.end.x
		p.rect(Rect2(x0, tank.position.y + 0.5, 0.55, 3.6), FACE)
		for k in 8:
			var fx := x0 + 0.04 + k * 0.065
			p.line(Vector2(fx, tank.position.y + 0.55), Vector2(fx, tank.position.y + 4.05), _ink(0.26), 0.025)
		p.line(Vector2(x0, tank.position.y + 0.5), Vector2(x0 + 0.55, tank.position.y + 0.5), _ink(0.4), 0.05)
		p.line(Vector2(x0, tank.position.y + 4.1), Vector2(x0 + 0.55, tank.position.y + 4.1), _ink(0.4), 0.05)
	# stiffeners, the fan shrouds' rings (their blades move), the tap changer
	for k in 3:
		p.line(Vector2(tank.position.x + 1.2 + k * 1.2, tank.position.y), Vector2(tank.position.x + 1.2 + k * 1.2, tank.end.y), _ink(0.12), 0.06)
	for fc: Vector2 in [Vector2(3.9, 25.35), Vector2(6.1, 25.35)]:
		p.ring(fc, 0.48, _ink(0.45), 0.05, 20)
		p.circle(fc, 0.43, VOID, 20)
	p.rect(Rect2(tank.position.x + 0.3, tank.position.y + 0.4, 1.0, 1.4), FACE2)
	p.rect(Rect2(tank.position.x + 0.3, tank.position.y + 0.4, 1.0, 1.4), _ink(0.35), false, 0.03)
	# the conservator on its legs, its sight glass; the bushings: three tall high-voltage, the low side's bars
	p.rect(Rect2(t.position.x + 0.6, t.position.y + 0.2, 2.1, 0.75), FACE2)
	p.rect(Rect2(t.position.x + 0.6, t.position.y + 0.2, 2.1, 0.75), _ink(0.45), false, 0.035)
	p.rect(Rect2(t.position.x + 1.4, t.position.y + 0.35, 0.5, 0.45), Color(0.15, 0.2, 0.18))
	for lx: float in [t.position.x + 0.9, t.position.x + 2.4]:
		p.line(Vector2(lx, t.position.y + 0.95), Vector2(lx, tank.position.y), _ink(0.35), 0.06)
	for k in 3:
		var bx := t.position.x + 3.3 + k * 0.7
		for s in 5:
			p.rect(Rect2(bx - 0.18 + s * 0.0, tank.position.y - 0.3 - s * 0.27, 0.36, 0.2), Color(0.32, 0.33, 0.35))
		p.line(Vector2(bx, tank.position.y - 1.65), Vector2(bx, tank.position.y - 1.4), _ink(0.7), 0.05)
		p.circle(Vector2(bx, tank.position.y - 1.68), 0.07, Pal.tint(Pal.AIR, 0.7 * (1.0 if on else 0.4), 1.2), 6)
	# the low side: the copper bus out of the side, along and up to the electrode mast's cables
	var cu := Color(0.62, 0.38, 0.22) if on else Color(0.3, 0.22, 0.17)
	p.rect(Rect2(tank.end.x + 0.55, 22.1, 11.0 - tank.end.x - 0.1, 1.0), Color(0.08, 0.084, 0.094))
	p.rect(Rect2(10.5, 16.0, 1.0, 7.1), Color(0.08, 0.084, 0.094))
	for k in 3:
		var o := -0.3 + k * 0.3
		p.polyline(PackedVector2Array([Vector2(tank.end.x + 0.55, 22.6 + o), Vector2(11.0 + o, 22.6 + o), Vector2(11.0 + o, 16.0)]), cu, 0.1)
	p.rect(Rect2(10.3, 15.6, 1.4, 0.5), FACE2)
	p.rect(Rect2(10.3, 15.6, 1.4, 0.5), _ink(0.45), false, 0.03)


func _decks(p, on: bool, lod: int) -> void:
	# the furnace deck: grating on beams, columns to the floor, braced; a ladder by the baghouse
	var deck := Rect2(9.0, DECK_Y, 21.4, 0.45)
	p.rect(deck, FACE2)
	p.hatch(Rect2(deck.position.x, deck.position.y + 0.05, deck.size.x, 0.35), _ink(0.1), 0.025, 0.16)
	p.line(deck.position, Vector2(deck.end.x, deck.position.y), _ink(0.5), 0.05)
	p.rect(Rect2(9.0, DECK_Y + 0.45, 21.4, 0.35), Color(0.075, 0.078, 0.088))
	for cx: float in [9.6, 19.6, 29.8]:
		p.rect(Rect2(cx - 0.2, DECK_Y + 0.8, 0.4, FLOOR - DECK_Y - 0.8), Color(0.085, 0.09, 0.1))
		p.line(Vector2(cx - 0.2, DECK_Y + 0.8), Vector2(cx - 0.2, FLOOR), _ink(0.25), 0.03)
	p.line(Vector2(9.8, DECK_Y + 0.8), Vector2(19.4, FLOOR - 0.4), _ink(0.13), 0.06)
	p.line(Vector2(19.4, DECK_Y + 0.8), Vector2(9.8, FLOOR - 0.4), _ink(0.13), 0.06)
	# a handrail on the deck's back edge from the mould line's end to the ladder
	p.line(Vector2(27.3, DECK_Y - 1.05), Vector2(30.4, DECK_Y - 1.05), _ink(0.4), 0.05)
	for hx: float in [27.4, 28.9, 30.3]:
		p.line(Vector2(hx, DECK_Y - 1.05), Vector2(hx, DECK_Y), _ink(0.35), 0.04)
	var ry := DECK_Y + 0.6
	while ry < FLOOR:
		p.line(Vector2(30.25, ry), Vector2(30.75, ry), _ink(0.3), 0.04)
		ry += 0.35
	p.line(Vector2(30.25, DECK_Y), Vector2(30.25, FLOOR), _ink(0.35), 0.04)
	p.line(Vector2(30.75, DECK_Y), Vector2(30.75, FLOOR), _ink(0.35), 0.04)
	# the mill deck, its columns and a ladder
	var md := Rect2(37.4, MILL_DECK, 17.8, 0.45)
	p.rect(md, FACE2)
	p.hatch(Rect2(md.position.x, md.position.y + 0.05, md.size.x, 0.35), _ink(0.1), 0.025, 0.16)
	p.line(md.position, Vector2(md.end.x, md.position.y), _ink(0.5), 0.05)
	p.rect(Rect2(37.4, MILL_DECK + 0.45, 17.8, 0.35), Color(0.075, 0.078, 0.088))
	for cx: float in [38.0, 45.6, 53.4]:
		p.rect(Rect2(cx - 0.2, MILL_DECK + 0.8, 0.4, FLOOR - MILL_DECK - 0.8), Color(0.085, 0.09, 0.1))
		p.line(Vector2(cx - 0.2, MILL_DECK + 0.8), Vector2(cx - 0.2, FLOOR), _ink(0.25), 0.03)
	p.line(Vector2(38.2, MILL_DECK + 0.8), Vector2(45.4, MILL_DECK + 7.0), _ink(0.12), 0.06)
	p.line(Vector2(45.4, MILL_DECK + 0.8), Vector2(38.2, MILL_DECK + 7.0), _ink(0.12), 0.06)
	var ly := MILL_DECK + 0.6
	while ly < FLOOR:
		p.line(Vector2(36.75, ly), Vector2(37.25, ly), _ink(0.3), 0.04)
		ly += 0.35
	p.line(Vector2(36.75, MILL_DECK), Vector2(36.75, FLOOR), _ink(0.35), 0.04)
	p.line(Vector2(37.25, MILL_DECK), Vector2(37.25, FLOOR), _ink(0.35), 0.04)


func _pulpit(p, on: bool, lod: int) -> void:
	var c := PULPIT
	p.rect(c, Color(0.085, 0.09, 0.1))
	p.rect(c, _ink(0.5), false, 0.05)
	p.rect(Rect2(c.position.x - 0.15, c.position.y - 0.12, c.size.x + 0.3, 0.2), FACE2)
	# the window band and its mullions; the screens behind it light up each frame
	var win := Rect2(c.position.x + 1.3, c.position.y + 0.9, c.size.x - 1.6, 1.9)
	p.rect(win, GLASS)
	var mx := win.position.x
	while mx <= win.end.x + 0.01:
		p.line(Vector2(mx, win.position.y), Vector2(mx, win.end.y), _ink(0.4), 0.06)
		mx += win.size.x / 3.0
	p.rect(win, _ink(0.45), false, 0.05)
	p.line(Vector2(win.position.x, win.end.y + 0.3), Vector2(win.end.x, win.end.y + 0.3), _ink(0.2), 0.12)
	# the door, the air conditioner on the roof, a vent
	var door := Rect2(c.position.x + 0.25, c.position.y + 2.4, 0.85, c.size.y - 2.4)
	p.rect(door, FACE)
	p.rect(door, _ink(0.4), false, 0.035)
	p.circle(Vector2(door.end.x - 0.15, door.position.y + 1.6), 0.05, _ink(0.6), 6)
	p.rect(Rect2(c.end.x - 2.0, c.position.y - 0.62, 1.6, 0.5), FACE2)
	p.rect(Rect2(c.end.x - 2.0, c.position.y - 0.62, 1.6, 0.5), _ink(0.4), false, 0.03)
	p.ring(Vector2(c.end.x - 1.2, c.position.y - 0.37), 0.18, _ink(0.35), 0.03, 12)
	p.hatch(Rect2(c.position.x + 1.6, c.end.y - 1.1, 2.0, 0.6), _ink(0.12), 0.03, 0.15)


func _reheat(p, on: bool, lod: int) -> void:
	var c := REHEAT
	p.rect(c, Color(0.1, 0.104, 0.115))
	p.rect(c, _ink(0.5), false, 0.05)
	# buckstays, the refractory's skin lines, two burners on the roof and the flue
	for k in 4:
		var x := c.position.x + 0.5 + k * 1.15
		p.line(Vector2(x, c.position.y), Vector2(x, c.end.y), _ink(0.2), 0.12)
	p.line(Vector2(c.position.x, c.position.y + 0.35), Vector2(c.end.x, c.position.y + 0.35), _ink(0.18), 0.05)
	for bx: float in [c.position.x + 1.2, c.position.x + 3.0]:
		p.rect(Rect2(bx - 0.25, c.position.y - 0.7, 0.5, 0.7), FACE2)
		p.rect(Rect2(bx - 0.25, c.position.y - 0.7, 0.5, 0.7), _ink(0.4), false, 0.03)
		p.line(Vector2(bx, c.position.y - 0.7), Vector2(bx, c.position.y - 1.3), _ink(0.35), 0.06)
	p.line(Vector2(c.position.x + 1.2, c.position.y - 1.3), Vector2(c.position.x + 3.6, c.position.y - 1.3), _ink(0.35), 0.06)
	p.rect(Rect2(c.position.x + 3.7, 3.4, 0.45, c.position.y - 3.4), Color(0.1, 0.104, 0.115))
	p.line(Vector2(c.position.x + 3.7, 3.4), Vector2(c.position.x + 3.7, c.position.y), _ink(0.3), 0.035)
	# the door's frame (the door slides in it) and the slot where the billet comes out
	p.rect(Rect2(c.end.x - 0.05, c.position.y + 0.3, 0.3, c.size.y - 0.3), DARK)
	p.rect(Rect2(c.end.x - 0.05, c.position.y - 1.6, 0.3, 1.9), Color(0.08, 0.084, 0.094))
	# the legs onto the mill deck, the pusher's cylinder on its bracket behind
	for lx: float in [c.position.x + 0.3, c.end.x - 0.3]:
		p.line(Vector2(lx, c.end.y), Vector2(lx, MILL_DECK), _ink(0.42), 0.14)
	p.rect(Rect2(36.0, 8.55, 2.8, 0.7), FACE2)
	p.rect(Rect2(36.0, 8.55, 2.8, 0.7), _ink(0.45), false, 0.035)
	p.line(Vector2(36.3, 9.25), Vector2(36.3, MILL_DECK), _ink(0.35), 0.1)
	p.line(Vector2(36.0, 8.9), Vector2(35.5, 8.9), _ink(0.4), 0.06)
	# peep holes
	for k in 3:
		p.circle(Vector2(c.position.x + 0.9 + k * 1.3, c.end.y - 0.9), 0.12, VOID, 8)


func _mill_still(p, on: bool, lod: int) -> void:
	# the tables' frames and side guides; their rollers turn each frame
	for tb in [FEED, RUNOUT]:
		var rr: Rect2 = tb
		p.rect(Rect2(rr.position.x, rr.position.y + 0.35, rr.size.x, 0.45), Color(0.09, 0.094, 0.104))
		p.rect(Rect2(rr.position.x, rr.position.y + 0.35, rr.size.x, 0.45), _ink(0.45), false, 0.04)
		for lx: float in [rr.position.x + 0.3, rr.end.x - 0.3]:
			p.line(Vector2(lx, rr.end.y), Vector2(lx, MILL_DECK), _ink(0.42), 0.14)
		p.line(Vector2(rr.position.x + 0.3, rr.end.y + 0.6), Vector2(rr.end.x - 0.3, MILL_DECK - 0.2), _ink(0.14), 0.05)
		p.line(Vector2(rr.position.x, rr.position.y - 0.9), Vector2(rr.end.x, rr.position.y - 0.9), _ink(0.18), 0.05)
	# the stand: two housings with their windows, the cap, the screw-down and its motor
	var s := STAND
	for hx: float in [s.position.x, s.end.x - 0.45]:
		p.rect(Rect2(hx, s.position.y, 0.45, s.size.y), FACE2)
		p.rect(Rect2(hx, s.position.y, 0.45, s.size.y), _ink(0.55), false, 0.05)
	p.rect(Rect2(s.position.x - 0.2, s.position.y - 0.8, s.size.x + 0.4, 0.8), FACE2)
	p.rect(Rect2(s.position.x - 0.2, s.position.y - 0.8, s.size.x + 0.4, 0.8), _ink(0.55), false, 0.05)
	p.rect(Rect2(s.position.x - 0.2, s.end.y, s.size.x + 0.4, 0.3), FACE2)
	p.line(Vector2(s.get_center().x, s.position.y - 0.8), Vector2(s.get_center().x, s.position.y + 0.4), _ink(0.5), 0.12)
	p.rect(Rect2(s.get_center().x - 0.7, s.position.y - 2.0, 1.4, 1.2), Color(0.1, 0.104, 0.115))
	p.rect(Rect2(s.get_center().x - 0.7, s.position.y - 2.0, 1.4, 1.2), _ink(0.45), false, 0.04)
	for k in 4:
		p.line(Vector2(s.get_center().x - 0.55 + k * 0.36, s.position.y - 1.9), Vector2(s.get_center().x - 0.55 + k * 0.36, s.position.y - 0.9), _ink(0.15), 0.04)
	p.line(Vector2(s.end.x - 0.2, s.position.y + 1.0), Vector2(s.end.x + 0.6, s.position.y + 1.0), _ink(0.3), 0.06)
	# the chocks round the rolls
	for ry: float in [ROLL_Y[0] - ROLL_R - BACKUP_R, ROLL_Y[0], ROLL_Y[1], ROLL_Y[1] + ROLL_R + BACKUP_R]:
		p.rect(Rect2(s.position.x + 0.1, ry - 0.35, 0.3, 0.7), DARK)
		p.rect(Rect2(s.end.x - 0.4, ry - 0.35, 0.3, 0.7), DARK)
	# the descaler: its header down from the wall, nozzle bars over and under the pass
	var dx := 46.9
	p.line(Vector2(dx, 3.5), Vector2(dx, PASS_Y - 0.65), _ink(0.4), 0.14)
	p.line(Vector2(dx, 3.5), Vector2(44.0, 3.5), _ink(0.3), 0.12)
	p.rect(Rect2(dx - 0.45, PASS_Y - 0.75, 0.9, 0.2), FACE2)
	p.rect(Rect2(dx - 0.45, PASS_Y + 0.95, 0.9, 0.2), FACE2)
	p.rect(Rect2(dx - 0.6, 7.2, 1.2, 0.5), FACE2)
	p.rect(Rect2(dx - 0.6, 7.2, 1.2, 0.5), _ink(0.4), false, 0.03)


# ================================================================== the moving parts
# behind the furnace and the line: the fans, the fan's impeller, the valve, the baghouse's pulses,
# the bus's cables to the arms, the reheating furnace, the pulpit's screens
func moving_back(ci: CanvasItem, t: float, on: bool, lod: int, game) -> void:
	var fan := _mesh("fan", func(p):
		for k in 5:
			var a := TAU * k / 5.0
			p.poly(PackedVector2Array([Vector2.ZERO, Vector2.from_angle(a - 0.22) * 0.4, Vector2.from_angle(a + 0.22) * 0.4]), Color(0.3, 0.31, 0.33))
		p.circle(Vector2.ZERO, 0.09, _ink(0.55), 8))
	for fc: Vector2 in [Vector2(3.9, 25.35), Vector2(6.1, 25.35)]:
		_put(ci, fan, fc, W.fans)
	var imp := _mesh("impeller", func(p):
		for k in 8:
			var a := TAU * k / 8.0
			p.line(Vector2.from_angle(a) * 0.15, Vector2.from_angle(a + 0.5) * 0.76, Color(0.34, 0.35, 0.37), 0.08)
		p.circle(Vector2.ZERO, 0.18, _ink(0.6), 10))
	_put(ci, imp, FAN, W.fans * 1.6)
	var valve := _mesh("valve", func(p):
		for k in 6:
			var a := TAU * k / 6.0
			p.line(Vector2.ZERO, Vector2.from_angle(a) * 0.36, _ink(0.45), 0.05)
		p.circle(Vector2.ZERO, 0.08, _ink(0.6), 6))
	_put(ci, valve, Vector2(35.0, 25.95), W.valve)
	# the baghouse's pulse-jet: each valve in turn, a puff of dust off its bag
	if W.arc_k > 0.05:
		var cyc := fmod(W.pulse, 3.0) / 3.0
		var k := int(cyc * 5.0)
		var f := fmod(cyc * 5.0, 1.0)
		var bx := BAG.position.x + 0.2 + 0.55 + 0.65 + k * 1.2
		var top := BAG.position.y + 0.6
		if f < 0.35:
			FastDraw.circle(ci, _p(Vector2(bx, top - 0.15)), 0.14 * m, Pal.tint(Pal.AIR, 0.9, 1.6))
			ci.draw_line(_p(Vector2(bx, top + 0.85)), _p(Vector2(bx, top + 3.6)), Pal.tint(Pal.AIR, 0.5 * (1.0 - f / 0.35), 1.2), 0.12 * m)
		for q in 3:
			var pf := clampf(f * 1.4 - q * 0.12, 0.0, 1.0)
			if pf > 0.0 and pf < 1.0:
				FastDraw.circle(ci, _p(Vector2(bx + (q - 1) * 0.25, top + 3.75 + pf * 0.6)), (0.15 + 0.35 * pf) * m, Color(0.45, 0.43, 0.4, 0.3 * (1.0 - pf)))
	# the gauge's needle: the bags' pressure drop, higher while the furnace fumes
	var gc := _p(Vector2(37.9, BAG.position.y + 0.6 + 4.0))
	ci.draw_line(gc, gc + Vector2.from_angle(PI * 0.8 + PI * (0.25 + 0.5 * W.arc_k)) * 0.26 * m, Pal.heat(0.9, 1.3), 0.04 * m)
	# the water-cooled cables from the bus's head up to the electrode arm, swinging with it
	var f2 = W.furnace(game)
	if f2 != null:
		var ly := W.line_y(game)
		var fx := W.furnace_x(game)
		var arm_y: float = ly + DY + float(f2.tip_y()) - 3.4
		var root := Vector2(fx - 3.4 + 0.25, arm_y - 0.2)
		var cu := Color(0.55, 0.36, 0.22) if on else Color(0.3, 0.22, 0.17)
		for k2 in 3:
			var a := Vector2(10.6 + k2 * 0.35, 15.6)
			var b := root + Vector2(0.0, -0.1 + k2 * 0.1)
			var pts := PackedVector2Array()
			var sag := 1.4 + 0.2 * k2 + 0.08 * sin(t * 1.3 + k2)
			for q in 9:
				var u := q / 8.0
				pts.append(_p(a.lerp(b, u) + Vector2(0.0, sag * 4.0 * u * (1.0 - u))))
			ci.draw_polyline(pts, cu, 0.12 * m)
			ci.draw_polyline(pts, Color(0.1, 0.1, 0.11, 0.6), 0.04 * m)
	# the reheating furnace: its glow through the seams while a billet heats, the door, the ram
	var j := Mill.job()
	var st := str(j.get("state", "")) if not j.is_empty() else ""
	var heating: bool = st == "fetch" or (st == "roll" and Mill.progress() < 0.08)
	var c := REHEAT
	if heating or W.door > 0.01:
		var g := 0.55 + 0.25 * sin(t * 3.0)
		for k3 in 3:
			FastDraw.circle(ci, _p(Vector2(c.position.x + 0.9 + k3 * 1.3, c.end.y - 0.9)), 0.1 * m, Pal.heat(g, 1.6))
		ci.draw_line(_p(Vector2(c.end.x + 0.02, c.position.y + 0.5)), _p(Vector2(c.end.x + 0.02, c.end.y - 0.2)), Pal.heat(0.5 * g, 1.4), 0.06 * m)
	var door := _mesh("rh_door", func(p):
		p.rect(Rect2(0.0, 0.0, 0.32, 2.4), FACE2)
		p.rect(Rect2(0.0, 0.0, 0.32, 2.4), _ink(0.6), false, 0.04)
		p.hatch(Rect2(0.0, 1.8, 0.32, 0.6), Pal.heat(0.6, 1.0), 0.04, 0.16)
		p.line(Vector2(0.16, 0.0), Vector2(0.16, -0.5), _ink(0.5), 0.05))
	var open_h := 1.6 * W.door
	if W.door > 0.02:
		# the open mouth: the furnace's inside, the billet in it, light pouring out
		ci.draw_rect(Rect2(_p(Vector2(c.end.x - 0.05, PASS_Y - 1.0)), Vector2(0.3, 1.0 * W.door) * m), Pal.heat(0.9, 1.7))
	_put(ci, door, Vector2(c.end.x - 0.06, c.position.y + 0.9 - open_h))
	# the pusher: its piston rod coming out of the cylinder as the ram drives into the furnace
	var rod := 36.15 + 2.4 * W.push
	ci.draw_rect(Rect2(_p(Vector2(36.1, 8.68)), Vector2(rod - 36.1, 0.44) * m), Color(0.55, 0.57, 0.6))
	ci.draw_rect(Rect2(_p(Vector2(rod - 0.12, 8.6)), Vector2(0.18, 0.6) * m), Pal.heat(0.8, 1.2) if absf(W.vpush) > 0.05 else _ink(0.6))
	# the billet in the furnace while it heats (it leaves on the feed table, scripts/mill_line.gd)
	if heating and W.push < 0.05:
		ci.draw_rect(Rect2(_p(Vector2(c.position.x + 0.8, PASS_Y - 0.82)), Vector2(2.6, 0.8) * m), Pal.heat(0.75 + 0.15 * sin(t * 2.0), 1.5))
	# the pulpit's screens: the furnace's power trace, its heat, the crane
	_screens(ci, t, on, lod, game)


func _screens(ci: CanvasItem, t: float, on: bool, lod: int, game) -> void:
	var win := Rect2(PULPIT.position.x + 1.3, PULPIT.position.y + 0.9, PULPIT.size.x - 1.6, 1.9)
	if not on:
		return
	var sw := win.size.x / 3.0
	var f = W.furnace(game)
	for k in 3:
		var sr := Rect2(win.position.x + k * sw + 0.25, win.position.y + 0.35, sw - 0.5, 1.15)
		ci.draw_rect(Rect2(_p(sr.position), sr.size * m), Color(0.04, 0.12, 0.13))
		var col := Pal.tint(Pal.AIR, 0.85, 1.3)
		match k:
			0:
				# the arcs' power: a trace scrolling left
				var pts := PackedVector2Array()
				for q in 12:
					var u := q / 11.0
					var v := 0.5 + 0.35 * W.arc_k * sin(t * 2.0 + u * 9.0) * sin(t * 0.7 + u * 3.0)
					pts.append(_p(sr.position + Vector2(u * sr.size.x, sr.size.y * (1.0 - v * W.arc_k - 0.1))))
				ci.draw_polyline(pts, col, 0.04 * m)
			1:
				if f != null:
					var hk := clampf((float(f.T) - 20.0) / 1700.0, 0.0, 1.0)
					ci.draw_rect(Rect2(_p(sr.position + Vector2(0.15, sr.size.y - 0.15 - (sr.size.y - 0.3) * hk)), Vector2(0.35, (sr.size.y - 0.3) * hk) * m), Pal.heat(0.9, 1.3))
					if lod > 0:
						_text(ci, sr.position + Vector2(0.65, 0.5), "%d°C" % int(f.T), 0.32, col)
						_text(ci, sr.position + Vector2(0.65, 0.95), "%.0fMW" % float(f.power), 0.28, Color(col, 0.7))
			2:
				ci.draw_rect(Rect2(_p(sr.position + Vector2(0.15 + (W.x / 60.0) * (sr.size.x - 0.5), 0.2)), Vector2(0.2, 0.2) * m), col)
				ci.draw_line(_p(sr.position + Vector2(0.1, 0.42)), _p(sr.position + Vector2(sr.size.x - 0.1, 0.42)), Color(col, 0.4), 0.03 * m)
				if lod > 0:
					_text(ci, sr.position + Vector2(0.15, 0.95), W.crane_state()[0], 0.24, Color(col, 0.8))
	# a flicker of the arcs on the glass
	if W.arc_k > 0.05:
		ci.draw_rect(Rect2(_p(win.position), win.size * m), Color(0.8, 0.78, 1.0, 0.05 * W.arc_k * W.flick))


# in front of everything: the crane and its basket, the basket on its stand, the sparks, smoke,
# steam and falling scrap, the descaler's jets, the machines' plates
func front(ci: CanvasItem, t: float, on: bool, lod: int, game) -> void:
	ci.draw_rect(r, Color(0, 0, 0, 0), false, 1.0)
	_crane(ci, t, on, lod)
	if W.basket == "stand":
		var full: bool = W.step in ["to_stand", "pick", "latch"]
		_basket(ci, Vector2(W.STAND_X, W.STAND_LUG), 0.0, 1.0 if full else 0.0)
	_particles(ci)
	_sprays(ci, t)


# the plates on their own layer, redrawn four times a second
func plates(ci: CanvasItem, t: float, on: bool, game) -> void:
	ci.draw_rect(r, Color(0, 0, 0, 0), false, 1.0)
	_plates(ci, t, on, game)


func _crane(ci: CanvasItem, t: float, on: bool, lod: int) -> void:
	var x := W.x
	var carriage := _mesh("carriage", func(p):
		p.rect(Rect2(-1.9, -0.85, 3.8, 0.85), FACE2)
		p.rect(Rect2(-1.9, -0.85, 3.8, 0.85), _ink(0.6), false, 0.05)
		p.hatch(Rect2(-1.85, -0.8, 0.5, 0.75), Pal.heat(0.75, 1.0), 0.06, 0.2)
		p.hatch(Rect2(1.35, -0.8, 0.5, 0.75), Pal.heat(0.75, 1.0), 0.06, 0.2)
		# the bridge's box girder end, its diaphragm
		p.rect(Rect2(-0.75, -1.95, 1.5, 1.1), Color(0.13, 0.136, 0.148))
		p.rect(Rect2(-0.75, -1.95, 1.5, 1.1), _ink(0.55), false, 0.04)
		p.line(Vector2(-0.75, -1.95), Vector2(0.75, -0.85), _ink(0.2), 0.03)
		p.line(Vector2(0.75, -1.95), Vector2(-0.75, -0.85), _ink(0.2), 0.03)
		# the drive motor and the festoon's cable trolley
		p.rect(Rect2(0.85, -1.5, 0.8, 0.6), FACE)
		p.rect(Rect2(0.85, -1.5, 0.8, 0.6), _ink(0.4), false, 0.03)
		p.line(Vector2(-1.4, -0.85), Vector2(-1.4, -1.25), _ink(0.4), 0.04))
	var wheel := _mesh("wheel", func(p):
		p.circle(Vector2.ZERO, 0.28, DARK, 14)
		p.ring(Vector2.ZERO, 0.28, _ink(0.6), 0.04, 14)
		p.line(Vector2(-0.22, 0.0), Vector2(0.22, 0.0), _ink(0.5), 0.04))
	var hoist := _mesh("hoist", func(p):
		p.rect(Rect2(-0.7, 0.0, 1.4, 0.8), Color(0.11, 0.114, 0.126))
		p.rect(Rect2(-0.7, 0.0, 1.4, 0.8), _ink(0.55), false, 0.04)
		p.circle(Vector2(0.0, 0.42), 0.3, DARK, 14)
		p.ring(Vector2(0.0, 0.42), 0.3, _ink(0.45), 0.03, 14))
	_put(ci, carriage, Vector2(x, 2.42))
	for wx: float in [-1.25, 1.25]:
		_put(ci, wheel, Vector2(x + wx, 2.14), W.wheel)
	_put(ci, hoist, Vector2(x, 2.55))
	ci.draw_line(_p(Vector2(x, 2.97)), _p(Vector2(x, 2.97) + Vector2.from_angle(W.drum) * 0.25), _ink(0.6), maxf(1.0, 0.04 * m))
	# the warning lamp blinks while it moves; the ropes and the hook block swing as one
	if absf(W.vx) > 0.05 or absf(W.vh) > 0.05:
		FastDraw.circle(ci, _p(Vector2(x - 1.4, 1.27)), 0.12 * m, Pal.heat(1.0 if fmod(t, 0.6) < 0.3 else 0.3, 1.6))
	var top := Vector2(x, 3.35)
	var hook := top + Vector2(0.0, W.hook - 3.35).rotated(W.sway)
	var side := Vector2(0.18, 0.0).rotated(W.sway)
	var block_top := top + Vector2(0.0, W.hook - 3.35 - 0.95).rotated(W.sway)
	ci.draw_line(_p(top + Vector2(-0.18, 0.0)), _p(block_top - side), _ink(0.65), maxf(1.0, 0.035 * m))
	ci.draw_line(_p(top + Vector2(0.18, 0.0)), _p(block_top + side), _ink(0.65), maxf(1.0, 0.035 * m))
	var block := _mesh("block", func(p):
		p.rect(Rect2(-0.38, -0.95, 0.76, 0.6), Color(0.85, 0.62, 0.2))
		p.rect(Rect2(-0.38, -0.95, 0.76, 0.6), _ink(0.6), false, 0.035)
		p.hatch(Rect2(-0.38, -0.95, 0.76, 0.6), Color(0.1, 0.1, 0.1, 0.6), 0.06, 0.2)
		p.line(Vector2(0.0, -0.35), Vector2(0.0, -0.1), _ink(0.7), 0.08)
		p.arc(Vector2(0.0, -0.05), 0.12, 0.0, PI, _ink(0.75), 0.06, 8))
	_put(ci, block, hook, W.sway)
	if W.basket == "hook":
		_basket(ci, hook, W.sway, W.basket_fill)


# the charging basket by its lugs: a box with ribs, its bail, the scrap it holds, the clam bottom
func _basket(ci: CanvasItem, lug: Vector2, rot: float, fill: float) -> void:
	var body := _mesh("basket", func(p):
		p.line(Vector2(0.0, 0.0), Vector2(-1.0, 0.35), _ink(0.5), 0.05)
		p.line(Vector2(0.0, 0.0), Vector2(1.0, 0.35), _ink(0.5), 0.05)
		p.rect(Rect2(-1.3, 0.35, 2.6, 2.0), Color(0.07, 0.072, 0.08))
		p.rect(Rect2(-1.3, 0.35, 2.6, 2.0), _ink(0.6), false, 0.05)
		for k in 4:
			p.line(Vector2(-1.3 + (k + 1) * 0.52, 0.35), Vector2(-1.3 + (k + 1) * 0.52, 2.35), _ink(0.18), 0.04)
		p.line(Vector2(-1.3, 2.35), Vector2(0.0, 2.6), _ink(0.45), 0.05)
		p.line(Vector2(1.3, 2.35), Vector2(0.0, 2.6), _ink(0.45), 0.05)
		p.hatch(Rect2(-1.3, 0.35, 2.6, 0.22), Pal.heat(0.7, 1.0), 0.05, 0.22))
	var scrap := _mesh("scrap", func(p):
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var pts := PackedVector2Array([Vector2(-1.15, 0.0)])
		for k in 12:
			pts.append(Vector2(-1.15 + 2.3 * (k + 0.5) / 12.0, -rng.randf_range(0.75, 1.0)))
		pts.append(Vector2(1.15, 0.0))
		p.poly(pts, Color(0.26, 0.25, 0.23))
		for k in 9:
			var a := Vector2(rng.randf_range(-1.0, 1.0), -rng.randf_range(0.1, 0.8))
			p.line(a, a + Vector2.from_angle(rng.randf_range(0.0, TAU)) * 0.3, Color(0.42, 0.4, 0.37), 0.05))
	if fill > 0.01:
		ci.draw_mesh(scrap, null, Transform2D(rot, Vector2(m, m * 1.8 * fill), 0.0, _p(lug + Vector2(0.0, 2.3).rotated(rot))))
	_put(ci, body, lug, rot)


func _particles(ci: CanvasItem) -> void:
	# sparks: streaks along their flight, white-hot to orange as they cool
	if not W.sparks.is_empty():
		var seg := PackedVector2Array()
		var cols := PackedColorArray()
		for s in W.sparks:
			var at: Vector2 = s[0]
			var v: Vector2 = s[1]
			var k: float = float(s[2]) / float(s[3])
			seg.append(_p(at))
			seg.append(_p(at - v * 0.035))
			var c := Color(1.0, 0.92, 0.7, k).lerp(Color(1.0, 0.45, 0.12, k), 1.0 - k)
			cols.append(c)
		ci.draw_multiline_colors(seg, cols, maxf(1.0, 0.045 * m))
	for s in W.smoke:
		var k: float = float(s[2]) / float(s[3])
		FastDraw.circle(ci, _p(s[0]), (0.25 + 0.9 * (1.0 - k)) * m, Color(0.42, 0.4, 0.38, 0.16 * k * float(s[4])))
	for s in W.steam:
		var k: float = float(s[2]) / float(s[3])
		FastDraw.circle(ci, _p(s[0]), (0.15 + 0.6 * (1.0 - k)) * m, Color(0.85, 0.9, 0.95, 0.2 * k * float(s[4])))
	for s in W.bits:
		var at: Vector2 = s[0]
		ci.draw_rect(Rect2(_p(at - Vector2(0.1, 0.06)), Vector2(0.2, 0.12) * m), Color(0.36, 0.34, 0.31))


func _sprays(ci: CanvasItem, t: float) -> void:
	if W.spray < 0.02:
		return
	var seg := PackedVector2Array()
	for k in 5:
		var x := 46.55 + k * 0.18
		var j := 0.04 * sin(t * 40.0 + k)
		seg.append(_p(Vector2(x, PASS_Y - 0.55)))
		seg.append(_p(Vector2(x + 0.35 + j, PASS_Y - 0.05)))
		seg.append(_p(Vector2(x, PASS_Y + 0.95)))
		seg.append(_p(Vector2(x + 0.35 - j, PASS_Y + 0.3)))
	ci.draw_multiline(seg, Color(0.75, 0.9, 1.0, 0.75 * W.spray), maxf(1.0, 0.03 * m))


# the plates: a lamp, the name, what it is doing (as the tug station's)
const PLATES := {
	"crane": [Vector2(10.4, 4.25), 8.6], "furnace": [Vector2(4.6, 13.6), 7.6], "trafo": [Vector2(2.0, 18.85), 6.8],
	"bag": [Vector2(31.0, 17.75), 5.6], "mill": [Vector2(43.4, 3.75), 8.8], "pulpit": [Vector2(21.0, 19.6), 6.8],
}


func plate(ci: CanvasItem, at: Vector2, width: float, name: String, st: Array, t: float) -> void:
	var rr := Rect2(_p(at), Vector2(width, 0.9) * m)
	var lc := lamp_col(str(st[1]), t)
	if not Pal.labels:
		FastDraw.circle(ci, _p(at + Vector2(0.42, 0.45)), 0.15 * m, lc)
		return
	ci.draw_rect(rr, Color(0.02, 0.022, 0.026, 0.9))
	ci.draw_rect(Rect2(rr.position, Vector2(0.12 * m, rr.size.y)), lc)
	FastDraw.circle(ci, _p(at + Vector2(0.42, 0.45)), 0.15 * m, lc)
	_text(ci, at + Vector2(0.75, 0.64), name, 0.44, _ink(0.92))
	var nw := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.44 * m)).x / m
	_text(ci, at + Vector2(1.1 + nw, 0.64), str(st[0]), 0.4, _ink(0.66))


func _plates(ci: CanvasItem, t: float, on: bool, game) -> void:
	var off := [w("未通电", "no power"), ""]
	plate(ci, PLATES.crane[0], PLATES.crane[1], w("天车 20 t", "CRANE 20 t"), W.crane_state() if on else off, t)
	plate(ci, PLATES.furnace[0], PLATES.furnace[1], w("电弧炉 EAF-3", "ARC FURNACE"), W.furnace_state(game), t)
	plate(ci, PLATES.trafo[0], PLATES.trafo[1], w("炉用变压器", "FURNACE TRANSFORMER"), [w("负载 %d%%" % int(W.arc_k * 100.0), "load %d%%" % int(W.arc_k * 100.0)), "work" if W.arc_k > 0.05 else "ok"] if on else off, t)
	plate(ci, PLATES.bag[0], PLATES.bag[1], w("除尘", "BAGHOUSE"), [w("脉冲清灰", "pulsing"), "work"] if W.arc_k > 0.05 else ([w("待机", "standby"), "ok"] if on else off), t)
	plate(ci, PLATES.mill[0], PLATES.mill[1], w("轧机 ROLL-1", "ROLLING MILL"), W.mill_state(), t)
	plate(ci, PLATES.pulpit[0], PLATES.pulpit[1], w("主控室", "CONTROL PULPIT"), [w("监控中", "watching"), "ok"] if on else off, t)


# ================================================================== the light (additive layer)
func glow(ci: CanvasItem, tex: Texture2D, t: float, game) -> void:
	var f = W.furnace(game)
	if f == null:
		return
	var fx := W.furnace_x(game)
	var ly := W.line_y(game)
	# the arcs light the hall: a wide violet-white flicker round the furnace, brighter near it
	if W.arc_k > 0.02:
		var k := W.arc_k * (0.55 + 0.45 * W.flick)
		var c := _p(Vector2(fx, ly + DY + 3.0))
		ci.draw_texture_rect(tex, Rect2(c - Vector2(16.0, 11.0) * m, Vector2(32.0, 22.0) * m), false, Color(0.55, 0.5, 0.95, 0.16 * k))
		ci.draw_texture_rect(tex, Rect2(c - Vector2(5.0, 3.5) * m, Vector2(10.0, 7.0) * m), false, Color(0.8, 0.78, 1.0, 0.3 * k))
		# where it falls on the duct's hood and the line's underside
		ci.draw_texture_rect(tex, Rect2(_p(Vector2(fx - 4.0, 7.0)), Vector2(8.0, 2.4) * m), false, Color(0.75, 0.72, 1.0, 0.18 * k))
	# the tap's stream and the moulds glow orange over the deck
	if str(f.phase) == "pour" and float(f.gate) > 0.2:
		var land := _p(Vector2(fx + 2.65, ly + DY + 5.6))
		ci.draw_texture_rect(tex, Rect2(land - Vector2(5.0, 4.0) * m, Vector2(10.0, 8.0) * m), false, Color(1.0, 0.5, 0.15, 0.28 * float(f.gate)))
	# the reheating furnace's open door
	if W.door > 0.02:
		var dp := _p(Vector2(REHEAT.end.x + 0.4, PASS_Y - 0.5))
		ci.draw_texture_rect(tex, Rect2(dp - Vector2(3.0, 2.2) * m, Vector2(6.0, 4.4) * m), false, Color(1.0, 0.45, 0.12, 0.45 * W.door))
	# the hot steel on the mill's tables
	var j := Mill.job()
	if not j.is_empty() and str(j.state) == "roll":
		var head := lerpf(FEED.position.x + 2.4, RUNOUT.end.x - 0.3, Mill.progress())
		var hp := _p(Vector2(head - 1.5, PASS_Y - 0.3))
		ci.draw_texture_rect(tex, Rect2(hp - Vector2(3.5, 1.6) * m, Vector2(7.0, 3.2) * m), false, Color(1.0, 0.42, 0.1, 0.32))
	# the lamps' own glow
	for lx: float in [6.0, 18.0, 30.0, 42.0, 54.0]:
		ci.draw_texture_rect(tex, Rect2(_p(Vector2(lx - 1.2, 1.2)), Vector2(2.4, 1.2) * m), false, Color(0.85, 0.92, 1.0, 0.18 if Port.stage("process") >= 1 else 0.0))


# ================================================================== the mill (drawn by scripts/mill_line.gd)
# the tables' rollers, the four rolls turning, the steel on its pass: a thick billet before the stand,
# thin plate (or a section's web and flanges) after it, cooling from white-orange to dark along the run
func mill(ci: CanvasItem, t: float, on: bool, game) -> void:
	var roller := _mesh("roller", func(p):
		p.circle(Vector2.ZERO, 0.24, Color(0.16, 0.165, 0.175), 12)
		p.ring(Vector2.ZERO, 0.24, _ink(0.55), 0.035, 12)
		p.line(Vector2(-0.2, 0.0), Vector2(0.2, 0.0), _ink(0.5), 0.04)
		p.circle(Vector2.ZERO, 0.06, _ink(0.6), 6))
	for tb in [FEED, RUNOUT]:
		var rr: Rect2 = tb
		var n := int(rr.size.x / 0.8)
		for i in n:
			_put(ci, roller, Vector2(rr.position.x + 0.4 + i * 0.8, rr.position.y + 0.25), W.rollers + i * 0.7)
	var work := _mesh("work_roll", func(p):
		p.circle(Vector2.ZERO, ROLL_R, Color(0.2, 0.205, 0.215), 22)
		p.ring(Vector2.ZERO, ROLL_R, _ink(0.75), 0.05, 22)
		for k in 3:
			p.line(Vector2.ZERO, Vector2.from_angle(TAU * k / 3.0) * ROLL_R * 0.85, _ink(0.45), 0.05)
		p.circle(Vector2.ZERO, 0.12, _ink(0.6), 8))
	var backup := _mesh("backup_roll", func(p):
		p.circle(Vector2.ZERO, BACKUP_R, Color(0.14, 0.145, 0.155), 24)
		p.ring(Vector2.ZERO, BACKUP_R, _ink(0.6), 0.05, 24)
		for k in 4:
			p.line(Vector2.from_angle(TAU * k / 4.0) * 0.2, Vector2.from_angle(TAU * k / 4.0) * BACKUP_R * 0.85, _ink(0.3), 0.04)
		p.circle(Vector2.ZERO, 0.16, _ink(0.5), 8))
	var cx := STAND.get_center().x
	var spin := W.rollers * 0.9
	_put(ci, backup, Vector2(cx, ROLL_Y[0] - ROLL_R - BACKUP_R + 0.02), spin * ROLL_R / BACKUP_R)
	_put(ci, backup, Vector2(cx, ROLL_Y[1] + ROLL_R + BACKUP_R - 0.02), -spin * ROLL_R / BACKUP_R)
	_put(ci, work, Vector2(cx, ROLL_Y[0]), -spin)
	_put(ci, work, Vector2(cx, ROLL_Y[1]), spin)
	# the pass
	var j := Mill.job()
	if j.is_empty() or str(j.state) != "roll":
		return
	var p := Mill.progress()
	var y := FEED.position.y - 0.05
	# out of the reheating furnace onto the feed table, then on through the stand
	var head := lerpf(FEED.position.x + 2.4, RUNOUT.end.x - 0.3, p)
	if p < 0.08:
		head = lerpf(REHEAT.position.x + 3.4, FEED.position.x + 2.4, clampf(W.push, 0.0, 1.0))
	var tail := head - lerpf(2.2, 4.4, p)
	var gap := cx
	var hot := Pal.heat(0.95, 1.7)
	if tail < gap:
		ci.draw_rect(Rect2(_p(Vector2(tail, y - 0.8)), Vector2(minf(head, gap) - tail, 0.8) * m), hot)
		ci.draw_rect(Rect2(_p(Vector2(tail, y - 0.8)), Vector2(minf(head, gap) - tail, 0.12) * m), Color(1.0, 0.95, 0.75, 0.8))
	if head > gap:
		var x0 := maxf(tail, gap)
		var steps := 8
		for k in steps:
			var a := lerpf(x0, head, float(k) / steps)
			var b := lerpf(x0, head, float(k + 1) / steps)
			# cooler the further from the rolls
			var cool := clampf((a - gap) / 7.0, 0.0, 1.0)
			var col := Pal.heat(0.95, 1.7).lerp(Color(0.45, 0.2, 0.12), cool * 0.7)
			if str(j.product) == "plate":
				ci.draw_rect(Rect2(_p(Vector2(a, y - 0.32)), Vector2(b - a, 0.32) * m), col)
			else:
				ci.draw_rect(Rect2(_p(Vector2(a, y - 0.7)), Vector2(b - a, 0.14) * m), col)
				ci.draw_rect(Rect2(_p(Vector2(a, y - 0.14)), Vector2(b - a, 0.14) * m), col)
				ci.draw_rect(Rect2(_p(Vector2(a, y - 0.7)), Vector2(b - a, 0.7) * m), Color(col, 0.3))
		FastDraw.circle(ci, _p(Vector2(gap, y - 0.4)), 0.5 * m, Color(1.0, 0.85, 0.55, 0.3 + 0.15 * sin(t * 30.0)))


# ================================================================== the hover cards
func hover_items(game) -> Array:
	var out: Array = []
	var add := func(rects: Array, title: String, use: String, now: Array, can: String) -> void:
		for rr in rects:
			out.append({"rect": Rect2(_p((rr as Rect2).position), (rr as Rect2).size * m), "title": title, "use": use, "now": str(now[0]), "can": can, "lamp": str(now[1])})
	var pr := func(id: String) -> Rect2: return Rect2(PLATES[id][0], Vector2(PLATES[id][1], 0.9))
	var fx := W.furnace_x(game)
	var ly := W.line_y(game)
	add.call([pr.call("crane"), Rect2(W.x - 1.9, 0.6, 3.8, 3.2)], w("天车 20 t", "HALL CRANE 20 t"),
		w("跨在整个厂房上方的桥式天车。电弧炉料仓里有废钢在等时，它从左上方的料篮架吊起料篮，送到电弧炉右侧的加料口上方，料篮里的废钢随加料一点点变少，加完把空篮送回去。", "The bridge crane over the whole hall. While scrap waits in the furnace's bunker it lifts the charging basket off its stand (top left), hangs it over the furnace's side chute and lets the scrap feed in, then takes the empty basket back."),
		W.crane_state(), w("不用操作。往电弧炉加废钢（炉体操作台或终端）它就会去吊料。", "Nothing to do: charge the furnace (at its desk or the terminal) and it brings the basket."))
	add.call([pr.call("furnace"), Rect2(fx - 3.6, ly + DY - 1.8, 7.4, 9.0)], w("电弧炉 EAF-3", "ARC FURNACE EAF-3"),
		w("把废钢熔成钢水。三根石墨电极从炉盖伸进去起弧（满功率 24 MW），钢水到出钢温度后炉体倾转，从偏心底出钢口浇进右边的锭模线，冷却成钢坯。", "Melts scrap into steel: three graphite electrodes strike arcs through the roof (24 MW flat out); at tapping heat the vessel tilts and taps from its eccentric bottom hole into the mould line on the right, where billets cool."),
		W.furnace_state(game), w("在炉体操作台（E）一键熔炼；电价、电网余量决定功率。", "One button at the furnace desk (E); the power follows the price and the grid's spare."))
	add.call([pr.call("trafo"), TRAFO], w("炉用变压器", "FURNACE TRANSFORMER"),
		w("把港区电网的高压降成电弧需要的大电流低电压，经铜母线和水冷电缆送到电极横臂。散热风扇随负载加速。", "Steps the port's high voltage down to the arcs' heavy current, through the copper bus and the water-cooled cables to the electrode arms. Its fans speed up with the load."),
		[w("负载 %d%%" % int(W.arc_k * 100.0), "load %d%%" % int(W.arc_k * 100.0)), "work" if W.arc_k > 0.05 else "ok"], w("不用操作。动力区的供电决定电弧炉能开多大功率。", "Nothing to do; the power district's supply sets how hard the furnace can burn."))
	add.call([pr.call("bag"), BAG], w("除尘布袋室 BH-1", "BAGHOUSE BH-1"),
		w("电弧炉的烟气经炉顶烟罩和排烟道进来，滤袋截住粉尘，脉冲喷吹按顺序把灰抖进灰斗，引风机把净化后的气从烟囱排出。", "The furnace's fume comes along the duct from its hood; the bags catch the dust, pulses shake it down in turn into the hopper, and the fan sends the clean air up the stack."),
		[w("脉冲清灰", "pulsing"), "work"] if W.arc_k > 0.05 else [w("待机", "standby"), "ok"], w("不用操作，跟电弧炉一起运行。", "Nothing to do; it runs with the furnace."))
	add.call([pr.call("mill"), Rect2(REHEAT.position.x, 3.4, RUNOUT.end.x - REHEAT.position.x, 6.9)], w("加热炉 + 轧机 ROLL-1", "REHEAT FURNACE + ROLLING MILL"),
		w("钢坯先在加热炉里烧透，开轧时炉门升起、推钢机把它推上进料辊道；除鳞喷水打掉氧化皮，四辊轧机把它轧成钢板或型材，在出料辊道上冷却后入库。", "A billet heats through in the reheating furnace; at the pass the door lifts and the pusher sends it out onto the feed table, the descaler blasts its scale off, the four-high stand rolls it into plate or sections, and it cools on the run-out on its way to the racks."),
		W.mill_state(), w("在轧机操作台（E）选配方、开轧；钢坯从货运区自动送来。", "At the mill pedestal (E) pick the recipe and roll; billets come up from the cargo district."))
	add.call([pr.call("pulpit"), PULPIT], w("主控室", "CONTROL PULPIT"),
		w("电弧炉下方的控制室：屏幕上是电弧功率曲线、炉温和天车位置。", "The control room under the furnace deck: the arcs' power trace, the bath's heat and where the crane is."),
		[w("监控中", "watching"), "ok"], w("只是看的。操作在各自的操作台上。", "Only to watch; the controls are at each machine's desk."))
	return out
