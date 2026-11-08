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
const CastArt = preload("res://scripts/cast_art.gd")
const BalePress = preload("res://scripts/bale_press.gd")

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
const TRAFO := Rect2(2.0, 20.0, 6.0, 6.8)
# 128 号 第 4 段 (方案 A 改): the baghouse hangs between the hall's columns over the baler, its fan beside
# it, the clean air out through the back wall (nothing may rise into the gallery's corridor)
const BAG := Rect2(30.6, 10.2, 4.8, 7.0)
const FAN := Vector2(35.9, 13.4)
const Gal = preload("res://scripts/process_gallery.gd")
const JUNCTION_Y := 17.6       # the bus's junction box, where the water-cooled cables to the arms start

const FACE := Color(0.118, 0.124, 0.136)
const FACE2 := Color(0.15, 0.158, 0.172)
const DARK := Color(0.06, 0.064, 0.072)
const VOID := Color(0.025, 0.027, 0.031)
const GLASS := Color(0.05, 0.085, 0.1)

var font: Font
var r := Rect2()       # the box, world px
var m := 1.0           # px a metre
var _meshes := {}
var off := Vector2.ZERO   # 128 号 第 4 段: the part being drawn stands this far over (W.BAY_DY down, W.MILL_OFF)


func _ink(a: float) -> Color:
	return Pal.ink(a)


func _p(v: Vector2) -> Vector2:
	return r.position + (v + off) * m


func _bay() -> void:
	off = Vector2(0.0, W.BAY_DY)


func _mill() -> void:
	off = W.MILL_OFF


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
	off = Vector2.ZERO
	_put(ci, _mesh("still%d%d" % [int(on), lod], func(p): _still(p, on, lod)), Vector2.ZERO)
	# the district's code on the arrival lane's back wall, where nothing stands in front of it
	_text(ci, Vector2(41.6, 12.2), "PRC", 2.4, Color(_ink(0.3), 0.32))
	if not Pal.labels:
		return
	_text(ci, Vector2(TRAFO.position.x + 0.7, 23.95), "EAF-T 36 MVA", 0.34, _ink(0.5))
	_mill()
	_text(ci, Vector2(REHEAT.position.x + 0.25, REHEAT.position.y + 0.55), w("加热炉 RH-1", "REHEAT RH-1"), 0.32, _ink(0.55))
	off = Vector2.ZERO


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


func _still(p, on: bool, lod: int) -> void:
	var lit := 1.0 if on else 0.35
	var bay := Transform2D(0.0, Vector2(0.0, W.BAY_DY))
	# ---- the hall: the roof truss over the gallery's corridor (left clear), the columns from the walkway down
	var c0 := Gal.DECK_B
	for cx: float in [0.8, 10.0, 20.0, 30.0, 40.0, 50.0, 59.2]:
		p.rect(Rect2(cx - 0.3, c0, 0.6, FLOOR - c0), Color(0.07, 0.074, 0.082))
		p.line(Vector2(cx - 0.3, c0), Vector2(cx - 0.3, FLOOR), _ink(0.13), 0.04)
		p.line(Vector2(cx + 0.3, c0), Vector2(cx + 0.3, FLOOR), _ink(0.13), 0.04)
		p.line(Vector2(cx, c0), Vector2(cx, FLOOR), _ink(0.05), 0.03)
		p.rect(Rect2(cx - 0.6, FLOOR - 0.22, 1.2, 0.22), DARK)
		if lod > 0:
			for bx: float in [-0.42, 0.42]:
				p.bolt(Vector2(cx + bx, FLOOR - 0.11), 0.05, _ink(0.35))
	for gy: float in [16.5, 22.5]:
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
	# ---- the high-bay lamps under the truss and the light they throw down
	for lx: float in [6.0, 18.0, 30.0, 42.0, 54.0]:
		p.poly(PackedVector2Array([Vector2(lx - 0.32, 1.72), Vector2(lx + 0.32, 1.72), Vector2(lx + 3.8, FLOOR), Vector2(lx - 3.8, FLOOR)]), Color(0.85, 0.92, 1.0, 0.028 * lit))
		p.poly(PackedVector2Array([Vector2(lx - 0.45, 1.3), Vector2(lx + 0.45, 1.3), Vector2(lx + 0.34, 1.72), Vector2(lx - 0.34, 1.72)]), FACE2)
		p.polyline(PackedVector2Array([Vector2(lx - 0.45, 1.3), Vector2(lx + 0.45, 1.3), Vector2(lx + 0.34, 1.72), Vector2(lx - 0.34, 1.72)]), _ink(0.45), 0.03, true)
		p.line(Vector2(lx - 0.3, 1.72), Vector2(lx + 0.3, 1.72), Color(0.92, 0.96, 1.0, 0.95 if on else 0.2), 0.06)
	# ---- the floor: the slab, its trench grating, the walkway's yellow edge
	p.rect(Rect2(0.0, FLOOR, 60.0, 1.2), Color(0.055, 0.058, 0.066))
	p.line(Vector2(0.0, FLOOR), Vector2(60.0, FLOOR), _ink(0.36), 0.06)
	p.hatch(Rect2(9.2, FLOOR + 0.12, 11.0, 0.4), _ink(0.1), 0.03, 0.18)
	var press_x0 := BalePress.COL_L - 1.4
	var dx := 0.4
	while dx < 59.6:
		if not (dx > TRAFO.position.x - 0.2 and dx < TRAFO.end.x + 0.2) and not (dx > press_x0 and dx < BalePress.HATCH_X + 1.5) and not (dx > 8.8 and dx < 30.9) and not (dx > 40.6):
			p.line(Vector2(dx, FLOOR - 0.05), Vector2(dx + 0.6, FLOOR - 0.05), Pal.heat(0.55, 0.9), 0.07)
		dx += 1.0
	# ---- the furnace bay, in its own metres (it stands W.BAY_DY lower)
	p.xf = bay
	# the crane's runway under the gallery: its girder on brackets off the columns, the rail on top
	var rx1 := Gal.LANE_X - 0.2
	p.rect(Rect2(0.3, 2.6, rx1 - 0.3, 0.7), Color(0.09, 0.094, 0.104))
	p.line(Vector2(0.3, 2.6), Vector2(rx1, 2.6), _ink(0.34), 0.05)
	p.line(Vector2(0.3, 3.3), Vector2(rx1, 3.3), _ink(0.22), 0.04)
	var sx := 1.0
	while sx < rx1 - 0.4:
		p.line(Vector2(sx, 2.65), Vector2(sx, 3.25), _ink(0.1), 0.04)
		sx += 1.5
	p.rect(Rect2(0.3, 2.42, rx1 - 0.3, 0.18), _ink(0.5))
	p.rect(Rect2(rx1 - 0.3, 1.9, 0.3, 0.52), DARK)
	for cx: float in [0.8, 10.0, 20.0, 30.0]:
		p.poly(PackedVector2Array([Vector2(cx + 0.3, 3.3), Vector2(cx + 0.9, 3.3), Vector2(cx + 0.3, 4.2)]), Color(0.08, 0.084, 0.094))
		p.poly(PackedVector2Array([Vector2(cx - 0.3, 3.3), Vector2(cx - 0.9, 3.3), Vector2(cx - 0.3, 4.2)]), Color(0.08, 0.084, 0.094))
	# the scrap basket's stand: a platform on wall brackets over the transformer
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
	_decks(p, on, lod)
	_mould_rack(p, on, lod)
	p.xf = Transform2D.IDENTITY
	_baghouse(p, on, lod)
	_transformer(p, on, lod)
	# ---- the mill, in its own metres (under the freight spur)
	p.xf = Transform2D(0.0, W.MILL_OFF)
	_mill_deck(p, on, lod)
	_reheat(p, on, lod)
	_mill_still(p, on, lod)
	p.xf = Transform2D.IDENTITY


func _mould_rack(p, on: bool, lod: int) -> void:
	var top := W.RACK_TOP + 0.8
	var x0 := float(W.RACK_X[0]) - 0.25
	var x1 := float(W.RACK_X[2]) + 2.2 + 0.2
	p.rect(Rect2(x0, top, x1 - x0, 0.28), FACE2)
	p.rect(Rect2(x0, top + 0.28, x1 - x0, 0.14), DARK)
	p.line(Vector2(x0, top), Vector2(x1, top), _ink(0.55), 0.05)
	p.line(Vector2(x0, top + 0.42), Vector2(x1, top + 0.42), _ink(0.3), 0.04)
	# the hangers up to the runway girder, their turnbuckles, two light ones between
	for hx: float in [x0 + 0.3, x1 - 0.3]:
		p.line(Vector2(hx, 3.3), Vector2(hx, top), _ink(0.28), 0.06)
		p.rect(Rect2(hx - 0.07, 8.0, 0.14, 0.5), _ink(0.3))
	for hx2: float in [x0 + 2.4, x1 - 2.4]:
		p.line(Vector2(hx2, 3.3), Vector2(hx2, top), _ink(0.18), 0.04)
	# a knee to the column at 20 m: the shelf may not swing
	p.line(Vector2(20.3, top - 1.2), Vector2(x0 + 0.3, top + 0.2), _ink(0.22), 0.05)
	for sx: float in W.RACK_X:
		for cx: float in [sx + 0.25, sx + 1.75]:
			p.poly(PackedVector2Array([Vector2(cx, top), Vector2(cx + 0.2, top), Vector2(cx + 0.25, top - 0.08), Vector2(cx - 0.05, top - 0.08)]), Color(0.3, 0.24, 0.16))
		if lod > 0:
			p.bolt(Vector2(sx + 1.1, top + 0.14), 0.04, _ink(0.5))
	# the yellow edge and its hatching: a load is set down here
	p.hatch(Rect2(x0, top + 0.06, x1 - x0, 0.16), Pal.heat(0.6, 0.9), 0.04, 0.3)
	if Pal.labels:
		p.rect(Rect2(x1 - 2.0, top + 0.5, 1.7, 0.4), DARK)


func _duct(p, on: bool, lod: int) -> void:
	var d := 1.1
	var bag_in := BAG.position.x + 0.1
	var pts := [Vector2(16.0, 6.2), Vector2(16.0, 3.9), Vector2(bag_in, 3.9)]
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
	# the elbow's cheek, the flange into the baghouse
	p.circle(Vector2(16.0, 3.9), d * 0.5, body, 16)
	p.rect(Rect2(bag_in - 0.15, 3.9 - d * 0.62, 0.3, d * 1.24), FACE2)
	p.rect(Rect2(bag_in - 0.15, 3.9 - d * 0.62, 0.3, d * 1.24), _ink(0.45), false, 0.03)
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
	# the damper on the run, its actuator and lever (under the duct: the gallery is over it)
	p.rect(Rect2(24.0, 3.2, 0.5, 1.4), DARK)
	p.rect(Rect2(23.6, 4.75, 1.3, 0.6), FACE2)
	p.rect(Rect2(23.6, 4.75, 1.3, 0.6), _ink(0.4), false, 0.03)
	p.line(Vector2(24.25, 4.45), Vector2(24.25, 4.75), _ink(0.5), 0.05)
	# the spark box before the baghouse, its cleanout door
	p.rect(Rect2(27.4, 3.05, 2.2, 1.7), Color(0.1, 0.105, 0.116))
	p.rect(Rect2(27.4, 3.05, 2.2, 1.7), _ink(0.45), false, 0.04)
	p.rect(Rect2(27.9, 3.4, 1.2, 1.0), _ink(0.18), false, 0.03)
	if lod > 0:
		for c: Vector2 in [Vector2(28.0, 3.5), Vector2(29.0, 3.5), Vector2(28.0, 4.3), Vector2(29.0, 4.3)]:
			p.bolt(c, 0.04, _ink(0.5))
	# the clamp bands holding the run under the girder
	var hx := 19.0
	while hx < 27.0:
		p.line(Vector2(hx, 3.3), Vector2(hx, 3.35), _ink(0.5), 0.12)
		p.line(Vector2(hx, 3.34), Vector2(hx, 4.46), _ink(0.2), 0.04)
		hx += 3.0


func _baghouse(p, on: bool, lod: int) -> void:
	var c := BAG
	var top := c.position.y + 0.6
	var casing := Rect2(c.position.x, top, c.size.x, 3.9)
	# hung off the column at 30 m and the lane's glass frame: two brackets, the hangers
	p.rect(Rect2(c.position.x - 0.6, top + 0.4, 0.6, 0.3), DARK)
	p.poly(PackedVector2Array([Vector2(c.position.x - 0.3, top + 0.7), Vector2(c.position.x, top + 0.7), Vector2(c.position.x, top + 1.6)]), DARK)
	for hx: float in [c.position.x + 0.5, c.end.x - 0.5]:
		p.line(Vector2(hx, Gal.GLASS_B + 0.1), Vector2(hx, top - 0.55), _ink(0.3), 0.06)
	p.rect(casing, Color(0.1, 0.104, 0.115))
	p.rect(casing, _ink(0.5), false, 0.05)
	for k in 5:
		var x := casing.position.x + 0.5 + k * 0.95
		p.line(Vector2(x, casing.position.y), Vector2(x, casing.end.y), _ink(0.1), 0.06)
	# the cut-away: the bags hanging from the tube sheet
	var win := Rect2(casing.position.x + 0.45, top + 0.6, casing.size.x - 0.9, 2.9)
	p.rect(win, VOID)
	p.line(Vector2(win.position.x, win.position.y + 0.05), Vector2(win.end.x, win.position.y + 0.05), _ink(0.45), 0.08)
	for k in 4:
		var bx := win.position.x + 0.5 + k * 0.97
		p.rect(Rect2(bx - 0.28, win.position.y + 0.12, 0.56, 2.45), Color(0.2, 0.205, 0.215))
		p.line(Vector2(bx - 0.28, win.position.y + 0.12), Vector2(bx - 0.28, win.position.y + 2.57), _ink(0.35), 0.03)
		p.circle(Vector2(bx, win.position.y + 2.57), 0.28, Color(0.2, 0.205, 0.215), 10)
		for ring in 4:
			p.line(Vector2(bx - 0.28, win.position.y + 0.55 + ring * 0.52), Vector2(bx + 0.28, win.position.y + 0.55 + ring * 0.52), _ink(0.12), 0.025)
	p.rect(win, _ink(0.4), false, 0.05)
	# the pulse header along the top, its diaphragm valves
	p.rect(Rect2(casing.position.x + 0.25, top - 0.55, casing.size.x - 0.5, 0.32), FACE2)
	p.rect(Rect2(casing.position.x + 0.25, top - 0.55, casing.size.x - 0.5, 0.32), _ink(0.4), false, 0.03)
	for k in 4:
		var bx := win.position.x + 0.5 + k * 0.97
		p.rect(Rect2(bx - 0.16, top - 0.3, 0.32, 0.3), DARK)
		p.line(Vector2(bx, top), Vector2(bx, win.position.y + 0.1), _ink(0.3), 0.05)
	# the hopper, the rotary valve's body, the dust drum hung under it (the baler works below)
	var hb := casing.end.y
	var cx := casing.get_center().x
	var hop := PackedVector2Array([Vector2(casing.position.x, hb), Vector2(casing.end.x, hb), Vector2(cx + 0.5, hb + 1.5), Vector2(cx - 0.5, hb + 1.5)])
	p.poly(hop, Color(0.09, 0.094, 0.104))
	p.polyline(hop, _ink(0.45), 0.05, true)
	p.circle(Vector2(cx, hb + 1.88), 0.38, DARK, 14)
	p.ring(Vector2(cx, hb + 1.88), 0.38, _ink(0.45), 0.04, 14)
	# the differential pressure gauge's dial
	p.circle(Vector2(casing.end.x - 0.45, top + 3.45), 0.24, VOID, 14)
	p.ring(Vector2(casing.end.x - 0.45, top + 3.45), 0.24, _ink(0.5), 0.035, 14)
	# the clean side: across into the induced-draught fan, its outlet through the back wall
	p.rect(Rect2(casing.end.x, top + 0.4, FAN.x - casing.end.x, 0.7), Color(0.1, 0.104, 0.115))
	p.line(Vector2(casing.end.x, top + 0.4), Vector2(FAN.x - 0.4, top + 0.4), _ink(0.35), 0.04)
	p.circle(FAN, 0.78, Color(0.1, 0.104, 0.115), 24)
	p.ring(FAN, 0.78, _ink(0.5), 0.06, 24)
	p.circle(FAN, 0.62, VOID, 24)
	p.rect(Rect2(FAN.x - 0.35, FAN.y + 0.7, 0.7, 1.1), FACE2)
	p.rect(Rect2(FAN.x - 0.35, FAN.y + 0.7, 0.7, 1.1), _ink(0.4), false, 0.03)
	for k in 3:
		p.line(Vector2(FAN.x - 0.22 + k * 0.22, FAN.y + 0.82), Vector2(FAN.x - 0.22 + k * 0.22, FAN.y + 1.68), _ink(0.16), 0.04)
	# the outlet: up to a collar through the back wall (the clean air leaves the hall behind)
	p.rect(Rect2(FAN.x - 0.3, top - 0.3, 0.6, FAN.y - 0.7 - top + 0.3), Color(0.1, 0.104, 0.115))
	p.line(Vector2(FAN.x - 0.3, top - 0.3), Vector2(FAN.x - 0.3, FAN.y - 0.7), _ink(0.35), 0.035)
	p.circle(Vector2(FAN.x, top - 0.45), 0.5, DARK, 18)
	p.ring(Vector2(FAN.x, top - 0.45), 0.5, _ink(0.5), 0.05, 18)
	p.ring(Vector2(FAN.x, top - 0.45), 0.3, _ink(0.3), 0.03, 14)


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
	var jy := JUNCTION_Y
	p.rect(Rect2(tank.end.x + 0.55, 22.1, 11.0 - tank.end.x - 0.1, 1.0), Color(0.08, 0.084, 0.094))
	p.rect(Rect2(10.5, jy + 0.4, 1.0, 22.6 - jy), Color(0.08, 0.084, 0.094))
	for k in 3:
		var o := -0.3 + k * 0.3
		p.polyline(PackedVector2Array([Vector2(tank.end.x + 0.55, 22.6 + o), Vector2(11.0 + o, 22.6 + o), Vector2(11.0 + o, jy + 0.4)]), cu, 0.1)
	p.rect(Rect2(10.3, jy, 1.4, 0.5), FACE2)
	p.rect(Rect2(10.3, jy, 1.4, 0.5), _ink(0.45), false, 0.03)


func _decks(p, on: bool, lod: int) -> void:
	# the furnace deck: grating on beams, short columns to the floor, a ladder by its end
	var fl := FLOOR - W.BAY_DY
	var deck := Rect2(9.0, DECK_Y, 21.4, 0.45)
	p.rect(deck, FACE2)
	p.hatch(Rect2(deck.position.x, deck.position.y + 0.05, deck.size.x, 0.35), _ink(0.1), 0.025, 0.16)
	p.line(deck.position, Vector2(deck.end.x, deck.position.y), _ink(0.5), 0.05)
	p.rect(Rect2(9.0, DECK_Y + 0.45, 21.4, 0.35), Color(0.075, 0.078, 0.088))
	for cx: float in [9.6, 14.6, 19.6, 24.7, 29.8]:
		p.rect(Rect2(cx - 0.2, DECK_Y + 0.8, 0.4, fl - DECK_Y - 0.8), Color(0.085, 0.09, 0.1))
		p.line(Vector2(cx - 0.2, DECK_Y + 0.8), Vector2(cx - 0.2, fl), _ink(0.25), 0.03)
		p.rect(Rect2(cx - 0.35, fl - 0.12, 0.7, 0.12), DARK)
	# a handrail on the deck's back edge from the mould line's end to the ladder
	p.line(Vector2(27.3, DECK_Y - 1.05), Vector2(30.4, DECK_Y - 1.05), _ink(0.4), 0.05)
	for hx: float in [27.4, 28.9, 30.3]:
		p.line(Vector2(hx, DECK_Y - 1.05), Vector2(hx, DECK_Y), _ink(0.35), 0.04)
	var ry := DECK_Y + 0.3
	while ry < fl:
		p.line(Vector2(30.25, ry), Vector2(30.75, ry), _ink(0.3), 0.04)
		ry += 0.35
	p.line(Vector2(30.25, DECK_Y), Vector2(30.25, fl), _ink(0.35), 0.04)
	p.line(Vector2(30.75, DECK_Y), Vector2(30.75, fl), _ink(0.35), 0.04)


# the mill deck (its own metres): grating, columns to the floor, a ladder
func _mill_deck(p, on: bool, lod: int) -> void:
	var fl := FLOOR - W.MILL_OFF.y
	var md := Rect2(37.4, MILL_DECK, 17.8, 0.45)
	p.rect(md, FACE2)
	p.hatch(Rect2(md.position.x, md.position.y + 0.05, md.size.x, 0.35), _ink(0.1), 0.025, 0.16)
	p.line(md.position, Vector2(md.end.x, md.position.y), _ink(0.5), 0.05)
	p.rect(Rect2(37.4, MILL_DECK + 0.45, 17.8, fl - MILL_DECK - 0.45), Color(0.075, 0.078, 0.088))
	for cx: float in [38.0, 42.0, 45.6, 49.5, 53.4]:
		p.line(Vector2(cx, MILL_DECK + 0.45), Vector2(cx, fl), _ink(0.25), 0.05)
	p.line(Vector2(37.4, fl - 0.04), Vector2(55.2, fl - 0.04), _ink(0.3), 0.04)
	var ly := MILL_DECK + 0.3
	while ly < fl:
		p.line(Vector2(36.75, ly), Vector2(37.25, ly), _ink(0.3), 0.04)
		ly += 0.35
	p.line(Vector2(36.75, MILL_DECK), Vector2(36.75, fl), _ink(0.35), 0.04)
	p.line(Vector2(37.25, MILL_DECK), Vector2(37.25, fl), _ink(0.35), 0.04)


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
	var flue_top := c.position.y - 2.6
	p.rect(Rect2(c.position.x + 3.7, flue_top, 0.45, c.position.y - flue_top), Color(0.1, 0.104, 0.115))
	p.line(Vector2(c.position.x + 3.7, flue_top), Vector2(c.position.x + 3.7, c.position.y), _ink(0.3), 0.035)
	p.circle(Vector2(c.position.x + 3.92, flue_top), 0.42, DARK, 16)
	p.ring(Vector2(c.position.x + 3.92, flue_top), 0.42, _ink(0.5), 0.04, 16)
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
	p.line(Vector2(dx, 4.2), Vector2(dx, PASS_Y - 0.65), _ink(0.4), 0.14)
	p.line(Vector2(dx, 4.2), Vector2(44.4, 4.2), _ink(0.3), 0.12)
	p.circle(Vector2(44.4, 4.2), 0.2, DARK, 10)
	p.ring(Vector2(44.4, 4.2), 0.2, _ink(0.45), 0.03, 10)
	p.rect(Rect2(dx - 0.45, PASS_Y - 0.75, 0.9, 0.2), FACE2)
	p.rect(Rect2(dx - 0.45, PASS_Y + 0.95, 0.9, 0.2), FACE2)
	p.rect(Rect2(dx - 0.6, 7.2, 1.2, 0.5), FACE2)
	p.rect(Rect2(dx - 0.6, 7.2, 1.2, 0.5), _ink(0.4), false, 0.03)


# ================================================================== the moving parts
# behind the furnace and the line: the fans, the fan's impeller, the valve, the baghouse's pulses,
# the bus's cables to the arms, the reheating furnace, the pulpit's screens
func moving_back(ci: CanvasItem, t: float, on: bool, lod: int, game) -> void:
	off = Vector2.ZERO
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
	var bag_cx := BAG.get_center().x
	var bag_hb := BAG.position.y + 0.6 + 3.9
	_put(ci, valve, Vector2(bag_cx, bag_hb + 1.88), W.valve)
	# the baghouse's pulse-jet: each valve in turn, a puff of dust off its bag
	if W.arc_k > 0.05:
		var cyc := fmod(W.pulse, 3.0) / 3.0
		var k := int(cyc * 5.0)
		var f := fmod(cyc * 5.0, 1.0)
		var bx := BAG.position.x + 0.45 + 0.5 + mini(k, 3) * 0.97
		var top := BAG.position.y + 0.6
		if f < 0.35:
			FastDraw.circle(ci, _p(Vector2(bx, top - 0.15)), 0.14 * m, Pal.tint(Pal.AIR, 0.9, 1.6))
			ci.draw_line(_p(Vector2(bx, top + 0.7)), _p(Vector2(bx, top + 3.1)), Pal.tint(Pal.AIR, 0.5 * (1.0 - f / 0.35), 1.2), 0.12 * m)
		for q in 3:
			var pf := clampf(f * 1.4 - q * 0.12, 0.0, 1.0)
			if pf > 0.0 and pf < 1.0:
				FastDraw.circle(ci, _p(Vector2(bx + (q - 1) * 0.25, top + 3.3 + pf * 0.5)), (0.15 + 0.3 * pf) * m, Color(0.45, 0.43, 0.4, 0.3 * (1.0 - pf)))
	# the gauge's needle: the bags' pressure drop, higher while the furnace fumes
	var gc := _p(Vector2(BAG.end.x - 0.45, BAG.position.y + 0.6 + 3.45))
	ci.draw_line(gc, gc + Vector2.from_angle(PI * 0.8 + PI * (0.25 + 0.5 * W.arc_k)) * 0.26 * m, Pal.heat(0.9, 1.3), 0.04 * m)
	# the water-cooled cables from the bus's head up to the electrode arm, swinging with it
	var f2 = W.furnace(game)
	if f2 != null:
		var ly := W.line_y(game)
		var fx := W.furnace_x(game)
		var arm_y: float = ly + DY + float(f2.tip_y()) - 3.4
		var root := Vector2(fx - 3.4 + 0.25, arm_y - 0.2 + W.BAY_DY)
		var cu := Color(0.55, 0.36, 0.22) if on else Color(0.3, 0.22, 0.17)
		for k2 in 3:
			var a := Vector2(10.6 + k2 * 0.35, JUNCTION_Y)
			var b := root + Vector2(0.0, -0.1 + k2 * 0.1)
			var pts := PackedVector2Array()
			var sag := 1.4 + 0.2 * k2 + 0.08 * sin(t * 1.3 + k2)
			for q in 9:
				var u := q / 8.0
				pts.append(_p(a.lerp(b, u) + Vector2(0.0, sag * 4.0 * u * (1.0 - u))))
			ci.draw_polyline(pts, cu, 0.12 * m)
			ci.draw_polyline(pts, Color(0.1, 0.1, 0.11, 0.6), 0.04 * m)
	# the reheating furnace: its glow through the seams while a billet heats, the door, the ram
	_mill()
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
	off = Vector2.ZERO


# in front of everything: the crane and its basket, the basket on its stand, the sparks, smoke,
# steam and falling scrap, the descaler's jets, the machines' plates
func front(ci: CanvasItem, t: float, on: bool, lod: int, game) -> void:
	ci.draw_rect(r, Color(0, 0, 0, 0), false, 1.0)
	_bay()
	_crane(ci, t, on, lod)
	# 128 号 第 4 段: the blocks on the rack, and the rack's plate
	for i in 3:
		var mk := str(W.rack_m[i]) if i < W.rack_m.size() else ""
		if mk != "":
			CastArt.block(ci, mk, _p(Vector2(float(W.RACK_X[i]), W.RACK_TOP)), m, [], [], 0.0, mini(lod + 1, 2), 0.92)
	if W.basket == "stand":
		var full: bool = W.step in ["to_stand", "pick", "latch"]
		_basket(ci, Vector2(W.STAND_X, W.STAND_LUG), 0.0, 1.0 if full else 0.0)
	off = Vector2.ZERO
	BalePress.draw(ci, self, t, lod)
	_particles(ci)
	_mill()
	_sprays(ci, t)
	off = Vector2.ZERO


# the plates on their own layer, redrawn four times a second
func plates(ci: CanvasItem, t: float, on: bool, game) -> void:
	off = Vector2.ZERO
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
	# 128 号 第 4 段: a mould block on the spreader, or the bare spreader on the way to fetch one
	if W.hook_m != "":
		var o := _p(hook + Vector2(-CastArt.W * 0.5, 0.75))
		CastArt.slings(ci, _p(hook), o, m)
		CastArt.block(ci, W.hook_m, o, m, [], [], 0.0, mini(lod + 1, 2))
	elif W.mould_step():
		var bar := _p(hook + Vector2(0.0, 0.55))
		ci.draw_line(_p(hook), bar, _ink(0.6), maxf(1.0, 0.035 * m))
		ci.draw_rect(Rect2(bar + Vector2(-1.05, -0.05) * m, Vector2(2.1, 0.1) * m), Color(0.85, 0.62, 0.2))
		for lx: float in [-0.9, 0.9]:
			ci.draw_line(bar + Vector2(lx, 0.05) * m, bar + Vector2(lx, 0.3) * m, _ink(0.55), maxf(1.0, 0.03 * m))


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
	_bay()
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
	for s in W.bits:
		var at: Vector2 = s[0]
		ci.draw_rect(Rect2(_p(at - Vector2(0.1, 0.06)), Vector2(0.2, 0.12) * m), Color(0.36, 0.34, 0.31))
	_mill()
	for s in W.steam:
		var k: float = float(s[2]) / float(s[3])
		FastDraw.circle(ci, _p(s[0]), (0.15 + 0.6 * (1.0 - k)) * m, Color(0.85, 0.9, 0.95, 0.2 * k * float(s[4])))
	off = Vector2.ZERO


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
	"crane": [Vector2(12.4, 10.6), 8.6], "furnace": [Vector2(20.4, 15.4), 7.6], "trafo": [Vector2(2.0, 18.85), 6.8],
	"bag": [Vector2(30.6, 17.3), 5.2], "mill": [Vector2(41.0, 16.6), 5.6],
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


# ================================================================== the light (additive layer)
func glow(ci: CanvasItem, tex: Texture2D, t: float, game) -> void:
	off = Vector2.ZERO
	var f = W.furnace(game)
	if f == null:
		return
	var fx := W.furnace_x(game)
	var ly := W.line_y(game)
	_bay()
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
	_mill()
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
	off = Vector2.ZERO
	# the lamps' own glow
	for lx: float in [6.0, 18.0, 30.0, 42.0, 54.0]:
		ci.draw_texture_rect(tex, Rect2(_p(Vector2(lx - 1.2, 1.2)), Vector2(2.4, 1.2) * m), false, Color(0.85, 0.92, 1.0, 0.18 if Port.stage("process") >= 1 else 0.0))


# ================================================================== the mill (drawn by scripts/mill_line.gd)
# the tables' rollers, the four rolls turning, the steel on its pass: a thick billet before the stand,
# thin plate (or a section's web and flanges) after it, cooling from white-orange to dark along the run
func mill(ci: CanvasItem, t: float, on: bool, game) -> void:
	_mill()
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
	_mill()
	_put(ci, backup, Vector2(cx, ROLL_Y[0] - ROLL_R - BACKUP_R + 0.02), spin * ROLL_R / BACKUP_R)
	_put(ci, backup, Vector2(cx, ROLL_Y[1] + ROLL_R + BACKUP_R - 0.02), -spin * ROLL_R / BACKUP_R)
	_put(ci, work, Vector2(cx, ROLL_Y[0]), -spin)
	_put(ci, work, Vector2(cx, ROLL_Y[1]), spin)
	# the pass
	var j := Mill.job()
	if j.is_empty() or str(j.state) != "roll":
		off = Vector2.ZERO
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
	off = Vector2.ZERO


# ================================================================== the hover cards
func hover_items(game) -> Array:
	var out: Array = []
	var add := func(rects: Array, title: String, use: String, now: Array, can: String) -> void:
		for rr in rects:
			out.append({"rect": Rect2(r.position + (rr as Rect2).position * m, (rr as Rect2).size * m), "title": title, "use": use, "now": str(now[0]), "can": can, "lamp": str(now[1])})
	var pr := func(id: String) -> Rect2: return Rect2(PLATES[id][0], Vector2(PLATES[id][1], 0.9))
	var fx := W.furnace_x(game)
	var ly := W.line_y(game) + W.BAY_DY
	var mo := W.MILL_OFF
	add.call([pr.call("crane"), Rect2(W.x - 1.9, 0.6 + W.BAY_DY, 3.8, 3.2)], w("天车 20 t", "HALL CRANE 20 t"),
		w("跑在观察廊下面的桥式天车。电弧炉料仓里有废钢在等时，它从左边的料篮架吊起料篮，送到电弧炉右侧的加料口上方，料篮里的废钢随加料一点点变少，加完把空篮送回去；换模时它把模具在出钢口下的座和模具架之间对换。", "The bridge crane running under the gallery. While scrap waits in the furnace's bunker it lifts the charging basket off its stand on the left, hangs it over the furnace's side chute and lets the scrap feed in, then takes the empty basket back; on a mould change it swaps the blocks between the seat under the tap and the rack."),
		W.crane_state(), w("不用操作。往电弧炉加料、排了换模，它就会去吊。", "Nothing to do: it lifts when the furnace is charged or a mould change is due."))
	add.call([pr.call("furnace"), Rect2(fx - 3.6, ly + DY - 1.8, 7.4, 9.0)], w("电弧炉 EAF-3", "ARC FURNACE EAF-3"),
		w("把废钢熔成钢水。三根石墨电极从炉盖伸进去起弧（满功率 24 MW），钢水到出钢温度后炉体倾转，从偏心底出钢口浇进右边座上的模具，冷却后顶出成坯。", "Melts scrap into steel: three graphite electrodes strike arcs through the roof (24 MW flat out); at tapping heat the vessel tilts and taps from its eccentric bottom hole into the mould in the seat on the right, where the pieces cool and are pushed out."),
		W.furnace_state(game), w("在观察廊上的炉体操作台（E）打开加工队列。", "The furnace console on the gallery (E) opens the processing queue."))
	add.call([pr.call("trafo"), TRAFO], w("炉用变压器", "FURNACE TRANSFORMER"),
		w("把港区电网的高压降成电弧需要的大电流低电压，经铜母线和水冷电缆送到电极横臂。散热风扇随负载加速。", "Steps the port's high voltage down to the arcs' heavy current, through the copper bus and the water-cooled cables to the electrode arms. Its fans speed up with the load."),
		[w("负载 %d%%" % int(W.arc_k * 100.0), "load %d%%" % int(W.arc_k * 100.0)), "work" if W.arc_k > 0.05 else "ok"], w("不用操作。动力区的供电决定电弧炉能开多大功率。", "Nothing to do; the power district's supply sets how hard the furnace can burn."))
	add.call([pr.call("bag"), BAG], w("除尘布袋室 BH-1", "BAGHOUSE BH-1"),
		w("电弧炉的烟气经炉顶烟罩和行车梁下的排烟道进来，滤袋截住粉尘，脉冲喷吹按顺序把灰抖进灰斗，引风机把净化后的气从后墙排出去。", "The furnace's fume comes along the duct under the crane's runway; the bags catch the dust, pulses shake it down in turn into the hopper, and the fan sends the clean air out through the back wall."),
		[w("脉冲清灰", "pulsing"), "work"] if W.arc_k > 0.05 else [w("待机", "standby"), "ok"], w("不用操作，跟电弧炉一起运行。", "Nothing to do; it runs with the furnace."))
	add.call([pr.call("mill"), Rect2(REHEAT.position.x + mo.x, 3.4 + mo.y, RUNOUT.end.x - REHEAT.position.x, 6.9)], w("加热炉 + 轧机 ROLL-1", "REHEAT FURNACE + ROLLING MILL"),
		w("钢坯先在加热炉里烧透，开轧时炉门升起、推钢机把它推上进料辊道；除鳞喷水打掉氧化皮，四辊轧机把它轧成钢板或型材，在出料辊道上冷却后入库。", "A billet heats through in the reheating furnace; at the pass the door lifts and the pusher sends it out onto the feed table, the descaler blasts its scale off, the four-high stand rolls it into plate or sections, and it cools on the run-out on its way to the racks."),
		W.mill_state(), w("在观察廊上的轧机操作台（E）选配方、开轧；钢坯从货运区自动送来。", "At the mill console on the gallery (E) pick the recipe and roll; billets come up from the cargo district."))
	return out
