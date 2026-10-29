extends RefCounted
# 96 号: the tug station drawn as the machines it holds (user 2026-10-28: as fine as the drone,
# smooth, each thing reading at a glance as what it is, what it is doing, what it is for). The still
# parts are one mesh per stage and level of detail, drawn only when those change; every machine
# that moves is a mesh built once and placed each frame (scripts/mesh_pen.gd), so the detail costs
# one draw_mesh a machine. What moves and why is scripts/tug_works.gd. Box-local metres (60 × 28,
# floor at 26.8), like scripts/district_interiors.gd. Two floors through the left wall: the tug
# deck above (the tug gate), the mouth below (a hulk's stern under the gantry).

const MeshPen = preload("res://scripts/mesh_pen.gd")
const FastDraw = preload("res://scripts/fast_draw.gd")
const W = preload("res://scripts/tug_works.gd")

const FLOOR := 26.8
const GIRDER := Vector2(0.35, 1.6)     # the gantry's box girder, top and bottom
const REEL := Vector2(19.6, 11.7)      # the drain hose's reel
const RISER_X := 22.9                  # the propellant main's riser to the reel
const TANK := Rect2(42.7, 12.4, 3.9, 14.4)
const PUMP_AT := Vector2(44.65, 25.7)
const TABLE := Vector2(23.2, 42.3)     # the service table's ends
const TABLE_TOP := 22.6
const BINS := Rect2(47.2, 19.4, 4.6, 7.4)
const RACK := Rect2(39.2, 0.5, 12.4, 5.2)
const COLS := [23.0, 37.6, 51.4]       # the deck's columns
const PROBE_RAIL := Vector2(31.2, 38.6)

const FACE := Color(0.118, 0.124, 0.136)
const FACE2 := Color(0.15, 0.158, 0.172)
const DARK := Color(0.06, 0.064, 0.072)
const VOID := Color(0.025, 0.027, 0.031)

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


func _put(ci: CanvasItem, mesh: ArrayMesh, at: Vector2, rot := 0.0, mod := Color.WHITE, k := 1.0, flip := false) -> void:
	if mesh.get_surface_count() == 0:
		return
	ci.draw_mesh(mesh, null, Transform2D(rot, Vector2(m * k * (-1.0 if flip else 1.0), m * k), 0.0, _p(at)), mod)


func _text(ci, at: Vector2, s: String, size_m: float, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width_m := -1.0) -> void:
	ci.draw_string(font, _p(at), s, align, width_m * m if width_m > 0.0 else -1.0, int(size_m * m), col)


func _lw(wm: float) -> float:
	return maxf(1.0, wm * m)


static func lamp_col(state: String, t: float) -> Color:
	match state:
		"ok": return Pal.tint(Pal.FLUID, 0.95, 1.3)
		"work": return Pal.heat(0.65 + 0.35 * absf(sin(t * 4.0)), 1.3)
		"warn": return Color(1.0, 0.3, 0.22, 0.6 + 0.4 * absf(sin(t * 2.5)))
	return Pal.ink(0.22)


# a plate: a lamp, the machine's name, what it is doing (one line)
func plate(ci: CanvasItem, at: Vector2, width: float, name: String, st: Array, t: float) -> void:
	var rr := Rect2(_p(at), Vector2(width, 0.9) * m)
	ci.draw_rect(rr, Color(0.02, 0.022, 0.026, 0.9))
	var lc := lamp_col(str(st[1]), t)
	ci.draw_rect(Rect2(rr.position, Vector2(0.12 * m, rr.size.y)), lc)
	FastDraw.circle(ci, _p(at + Vector2(0.42, 0.45)), 0.15 * m, lc)
	_text(ci, at + Vector2(0.75, 0.64), name, 0.44, _ink(0.92))
	var nw := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.44 * m)).x / m
	_text(ci, at + Vector2(1.1 + nw, 0.64), str(st[0]), 0.4, _ink(0.66))


# the plates' places (box-local m) and widths, for the drawing and the hover cards
const PLATES := {
	"gantry": [Vector2(3.0, 3.0), 9.4], "mouth": [Vector2(1.2, 11.55), 14.2],
	"t01": [Vector2(41.6, 11.55), 9.8], "t02": [Vector2(27.6, 11.55), 9.6],
	"table": [Vector2(23.4, 27.0), 13.0], "tank": [Vector2(42.4, 27.0), 9.4],
}


# ================================================================== the still parts
func still(ci: CanvasItem, on: bool, lod: int, stage: int) -> void:
	_put(ci, _mesh("still/%s/%d/%d" % [on, lod, stage], func(p): _still(p, on, lod, stage)), Vector2.ZERO)
	if lod >= 1:
		_text(ci, Vector2(9.4, 1.32), "SWL 40 t", 0.5, Pal.heat(0.75, 1.0))
		_text(ci, Vector2(14.0, 1.32), "MOUTH GANTRY", 0.34, _ink(0.45))
		_text(ci, Vector2(0.9, 4.75), w("拖船门", "TUG GATE"), 0.4, _ink(0.6))
		_text(ci, Vector2(TANK.position.x + 0.5, TANK.position.y + 7.7), "MMH", 0.62, Color(0.05, 0.05, 0.05))
		_text(ci, Vector2(TANK.position.x + 0.5, TANK.position.y + 8.4), w("甲基肼 · 剧毒易燃", "TOXIC · FLAMMABLE"), 0.28, Color(0.05, 0.05, 0.05))
		_text(ci, Vector2(RACK.position.x, RACK.position.y + 0.42), w("备件架 · 喷管 / 缆绳 / 电池模块 / 阀件", "SPARES · NOZZLES / CABLE / BATTERIES / VALVES"), 0.36, _ink(0.6))
		_text(ci, Vector2(BINS.position.x, BINS.position.y - 0.25), w("零件箱", "PARTS BINS"), 0.4, _ink(0.65))
		var names := [["阀件", "VALVES"], ["密封圈", "SEALS"], ["紧固件", "BOLTS"], ["线束", "LOOMS"]]
		for i in 4:
			var bp := _bin_rect(i)
			_text(ci, bp.position + Vector2(0.18, 0.62), names[i][0] if Txt.zh else names[i][1], 0.32, Color(0.05, 0.05, 0.05))
		for i in 2:
			_text(ci, Vector2(float(W.BERTH_X[i]) - 1.0, W.DECK_Y + 0.55), "T-0%d" % (i + 1), 0.42, Pal.heat(0.7, 1.0))
		_text(ci, Vector2(TABLE.x + 0.3, TABLE_TOP + 1.05), w("吊舱检修台", "POD SERVICE TABLE"), 0.36, _ink(0.55))
		_text(ci, Vector2(20.1, FLOOR - 0.15), w("夹具架", "FRAME STAND"), 0.3, _ink(0.5))


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


func _still(p, on: bool, lod: int, stage: int) -> void:
	_wall(p, lod, stage)
	_gantry_frame(p, lod)
	_deck(p, on, lod)
	_table_frame(p, lod)
	_tank_frame(p, lod)
	_bins(p, lod)
	_rack(p, lod, stage)
	_mains(p, lod)


# the left wall: the tug gate above, the mouth below, the pier between with its lamps
func _wall(p, lod: int, stage: int) -> void:
	var edge := _ink(0.62)
	var g: Vector2 = W.GATE
	var mo: Vector2 = W.MOUTH
	# the wall's thickness where it is not open, inside face hatched
	for seg in [Vector2(0.0, g.x), Vector2(g.y, mo.x), Vector2(mo.y, FLOOR)]:
		p.rect(Rect2(-0.4, seg.x, 1.1, seg.y - seg.x), FACE)
		p.line(Vector2(0.7, seg.x), Vector2(0.7, seg.y), edge, 0.08)
	# the gate's frame and guides
	for y in [g.x, g.y]:
		p.rect(Rect2(-0.5, y - 0.18, 1.5, 0.36), FACE2)
		p.hatch(Rect2(-0.4, y - 0.14, 1.3, 0.28), Pal.heat(0.55, 1.0), 0.08, 0.3)
	# the mouth: a heavy frame, its seal, the hazard chevrons; its size by the stage (a ring
	# narrows it at stage 1)
	p.rect(Rect2(-0.6, mo.x - 0.5, 1.8, 0.5), FACE2)
	p.rect(Rect2(-0.6, mo.y, 1.8, 0.25), FACE2)
	p.line(Vector2(1.2, mo.x - 0.5), Vector2(1.2, mo.x), edge, 0.06)
	p.hatch(Rect2(-0.5, mo.x - 0.42, 1.6, 0.34), Pal.heat(0.6, 1.0), 0.1, 0.36)
	p.line(Vector2(0.95, mo.x), Vector2(0.95, mo.y), Color(0.03, 0.03, 0.035), 0.16)   # the seal
	if lod >= 1:
		var y := mo.x + 0.5
		while y < mo.y - 0.3:
			p.bolt(Vector2(0.4, y), 0.06, _ink(0.45))
			y += 1.1
	# the pier between: its lamp housings
	p.rect(Rect2(0.8, g.y + 0.35, 0.5, 1.2), FACE2)
	# floor marks where the hulk lies: the stern line
	p.line(Vector2(0.0, FLOOR + 0.25), Vector2(TugYard.DOCK_IN, FLOOR + 0.25), Pal.heat(0.4, 1.0), 0.06)


# the gantry over the mouth: two lattice legs on bogies, the box girder, the festoon track
func _gantry_frame(p, lod: int) -> void:
	var edge := _ink(0.6)
	var g0 := GIRDER.x
	var g1 := GIRDER.y
	for lx: float in [W.LEGS.x, W.LEGS.y]:
		p.rect(Rect2(lx - 2.0, FLOOR - 0.12, 4.0, 0.12), _ink(0.4))
		var a := lx - 0.4
		var b := lx + 0.4
		p.rect(Rect2(a, g1, 0.8, 25.6 - g1), Color(0.05, 0.053, 0.06, 0.55))
		if lod >= 1:
			var y := g1 + 0.25
			var flip := false
			while y < 25.2:
				p.line(Vector2(a if not flip else b, y), Vector2(b if not flip else a, y + 0.8), _ink(0.24), 0.045)
				flip = not flip
				y += 0.8
		p.line(Vector2(a, g1), Vector2(a, 25.7), edge, 0.12)
		p.line(Vector2(b, g1), Vector2(b, 25.7), edge, 0.12)
		var s := 1.0 if lx < 10.0 else -1.0
		p.line(Vector2(lx + s * 0.4, 3.6), Vector2(lx + s * 2.0, g1), edge, 0.1)
		p.rect(Rect2(lx - 1.3, 25.6, 2.6, 0.66), FACE)
		p.rect(Rect2(lx - 1.3, 25.6, 2.6, 0.66), edge, false, 0.06)
		for wx in [lx - 0.8, lx + 0.8]:
			p.circle(Vector2(wx, FLOOR - 0.36), 0.24, Color(0.19, 0.195, 0.21), 14)
			p.ring(Vector2(wx, FLOOR - 0.36), 0.24, _ink(0.6), 0.05, 14)
			p.circle(Vector2(wx, FLOOR - 0.36), 0.07, _ink(0.7), 6)
		for bx in [lx - 1.5, lx + 1.3]:
			p.rect(Rect2(bx, 25.75, 0.2, 0.36), Pal.heat(0.55, 1.0))
	p.rect(Rect2(1.2, g0, 21.6, g1 - g0), FACE)
	if lod >= 1:
		var x := 1.6
		var k := 0
		while x < 22.6:
			p.line(Vector2(x, g0 + 0.1), Vector2(x, g1 - 0.1), _ink(0.22), 0.04)
			if k % 2 == 0 and x + 1.4 < 22.6:
				p.line(Vector2(x, g1 - 0.12), Vector2(x + 1.4, g0 + 0.12), _ink(0.13), 0.035)
			x += 1.4
			k += 1
	p.line(Vector2(1.1, g0), Vector2(22.9, g0), _ink(0.75), 0.13)
	p.line(Vector2(1.1, g1), Vector2(22.9, g1), _ink(0.75), 0.13)
	for hx in [1.3, 21.0]:
		p.hatch(Rect2(hx, g0 + 0.1, 1.6, g1 - g0 - 0.2), Pal.heat(0.45, 1.0), 0.1, 0.38)
	for sx in [3.1, 21.2]:
		p.rect(Rect2(sx - 0.22, g1, 0.44, 0.45), Pal.heat(0.6, 1.0))
	p.line(Vector2(2.4, g1 + 0.24), Vector2(21.6, g1 + 0.24), _ink(0.3), 0.05)
	# the push frame's stand on the floor right of the stern
	var st := W.FRAME_STAND
	p.rect(Rect2(st.x - 1.3, st.y - 0.5, 2.6, 0.5), FACE2)
	p.rect(Rect2(st.x - 1.3, st.y - 0.5, 2.6, 0.5), edge, false, 0.05)
	for sx in [st.x - 1.0, st.x + 1.0]:
		p.poly(PackedVector2Array([Vector2(sx - 0.25, st.y - 0.5), Vector2(sx + 0.25, st.y - 0.5), Vector2(sx, st.y - 1.4)]), FACE)


# the tug deck: its slab and grating, the columns down to the floor, each berth's posts (the
# propellant arm, the charging umbilical), the hatches' frames, the lift shafts below them
func _deck(p, on: bool, lod: int) -> void:
	var edge := _ink(0.65)
	var y0: float = W.DECK_Y
	var x0: float = W.DECK_X.x
	var x1: float = W.DECK_X.y
	for cx: float in COLS:
		p.rect(Rect2(cx - 0.32, y0 + 0.7, 0.64, FLOOR - y0 - 0.7), FACE)
		p.line(Vector2(cx - 0.32, y0 + 0.7), Vector2(cx - 0.32, FLOOR), edge, 0.05)
		p.line(Vector2(cx + 0.32, y0 + 0.7), Vector2(cx + 0.32, FLOOR), edge, 0.05)
	p.rect(Rect2(x0, y0, x1 - x0, 0.7), FACE2)
	if lod >= 1:
		var x := x0 + 0.3
		while x < x1:
			p.line(Vector2(x, y0 + 0.12), Vector2(x, y0 + 0.58), _ink(0.2), 0.03)
			x += 0.45
	p.line(Vector2(x0, y0), Vector2(x1, y0), _ink(0.8), 0.1)
	p.line(Vector2(x0, y0 + 0.7), Vector2(x1, y0 + 0.7), edge, 0.06)
	for i in 2:
		var bx: float = W.BERTH_X[i]
		# the lane marks and the landing pads
		for sx in [-3.6, 3.6]:
			p.rect(Rect2(bx + sx - 0.7, y0 - 0.12, 1.4, 0.12), Pal.heat(0.55, 1.0))
		# the hatch's frame under the aft pod, and the lift's shaft down from it
		var lx := W.lift_x(i)
		p.rect(Rect2(lx - 1.7, y0 - 0.05, 3.4, 0.8), DARK)
		p.rect(Rect2(lx - 1.7, y0 - 0.05, 3.4, 0.8), Pal.heat(0.5, 1.0), false, 0.05)
		for sx in [-1.55, 1.55]:
			p.line(Vector2(lx + sx, y0 + 0.75), Vector2(lx + sx, TABLE_TOP), _ink(0.42), 0.09)
		if lod >= 1:
			var yy := y0 + 1.2
			while yy < TABLE_TOP - 0.3:
				p.line(Vector2(lx - 1.55, yy), Vector2(lx + 1.55, yy + 0.6), _ink(0.13), 0.03)
				yy += 1.2
		# the services post at the berth's nose end: the arm's swivel, the umbilical's socket
		var px := bx + 6.6
		p.rect(Rect2(px - 0.3, y0 - 3.4, 0.6, 3.4), FACE)
		p.rect(Rect2(px - 0.3, y0 - 3.4, 0.6, 3.4), edge, false, 0.04)
		p.circle(Vector2(px, y0 - 3.2), 0.22, Pal.heat(0.6, 1.0), 10)
		p.rect(Rect2(px - 0.22, y0 - 1.4, 0.44, 0.44), Pal.tint(Pal.AIR, 0.6, 1.0) if on else _ink(0.3))
	# the deck's handrail along its open left end
	p.line(Vector2(x0, y0 - 1.0), Vector2(x0 + 0.6, y0 - 1.0), _ink(0.4), 0.05)
	p.line(Vector2(x0 + 0.1, y0), Vector2(x0 + 0.1, y0 - 1.0), _ink(0.4), 0.05)


func _table_frame(p, lod: int) -> void:
	var edge := _ink(0.62)
	var y := TABLE_TOP
	for lx in [TABLE.x + 0.5, (TABLE.x + TABLE.y) * 0.5, TABLE.y - 0.5]:
		p.rect(Rect2(lx - 0.25, y + 0.7, 0.5, FLOOR - y - 0.7), FACE)
		p.rect(Rect2(lx - 0.7, FLOOR - 0.22, 1.4, 0.22), FACE2)
	p.rect(Rect2(TABLE.x, y, TABLE.y - TABLE.x, 0.7), FACE2)
	p.rect(Rect2(TABLE.x, y, TABLE.y - TABLE.x, 0.7), edge, false, 0.05)
	p.line(Vector2(TABLE.x, y + 0.2), Vector2(TABLE.y, y + 0.2), _ink(0.45), 0.05)   # the slide's rail
	if lod >= 1:
		var x := TABLE.x + 0.6
		while x < TABLE.y:
			p.bolt(Vector2(x, y + 0.48), 0.05, _ink(0.45))
			x += 1.3
	# the saddles: the two lifts' and A (spare), B (overhaul)
	for sx in [W.lift_x(1), W.SLOT_A, W.SLOT_B, W.lift_x(0)]:
		for o in [-0.1, 1.0]:
			p.poly(PackedVector2Array([Vector2(sx + o - 0.4, y), Vector2(sx + o + 0.4, y), Vector2(sx + o + 0.25, y - 0.32), Vector2(sx + o - 0.25, y - 0.32)]), FACE)
	# the NDT probe's rail under the deck, over saddle B
	var ry: float = W.DECK_Y + 1.75
	for hx in [PROBE_RAIL.x + 0.3, PROBE_RAIL.y - 0.3]:
		p.line(Vector2(hx, W.DECK_Y + 0.7), Vector2(hx, ry), _ink(0.4), 0.06)
	p.rect(Rect2(PROBE_RAIL.x, ry, PROBE_RAIL.y - PROBE_RAIL.x, 0.3), FACE2)
	p.line(Vector2(PROBE_RAIL.x, ry + 0.3), Vector2(PROBE_RAIL.y, ry + 0.3), _ink(0.45), 0.04)


func _tank_frame(p, lod: int) -> void:
	var edge := _ink(0.72)
	var x0 := TANK.position.x
	var x1 := TANK.end.x
	var rx := (x1 - x0) * 0.5
	var mid := x0 + rx
	var top := TANK.position.y + rx
	var bot := TANK.end.y - 1.6 - rx
	# the legs and the skirt
	for lx in [x0 + 0.4, x1 - 0.4]:
		p.line(Vector2(lx, bot + rx * 0.6), Vector2(lx + (0.3 if lx > mid else -0.3), FLOOR), _ink(0.55), 0.14)
	p.rect(Rect2(x0 - 0.4, FLOOR - 0.2, x1 - x0 + 0.8, 0.2), FACE2)
	# the shell: dark inside (the liquid is drawn over it), the heads
	p.rect(Rect2(x0, top, x1 - x0, bot - top), Color(0.075, 0.08, 0.088))
	p.arc(Vector2(mid, top), rx, PI, TAU, edge, 0.1, 20)
	p.arc(Vector2(mid, bot), rx, 0.0, PI, edge, 0.1, 20)
	p.line(Vector2(x0, top), Vector2(x0, bot), edge, 0.1)
	p.line(Vector2(x1, top), Vector2(x1, bot), edge, 0.1)
	if lod >= 1:
		for k in 4:
			var y := top + 1.6 + k * 2.0
			p.line(Vector2(x0, y), Vector2(x1, y), _ink(0.18), 0.035)
	# the placard
	p.rect(Rect2(x0 + 0.35, TANK.position.y + 7.0, x1 - x0 - 0.7, 1.6), Pal.ink(0.78))
	p.rect(Rect2(x0 + 0.35, TANK.position.y + 7.0, 0.22, 1.6), Pal.heat(0.9, 1.0))
	# the sight glass (its level drawn moving), the relief valve and vent on top, the ladder
	p.rect(Rect2(x1 + 0.15, top + 0.4, 0.28, bot - top - 0.8), Color(0.04, 0.05, 0.055))
	p.rect(Rect2(x1 + 0.15, top + 0.4, 0.28, bot - top - 0.8), _ink(0.5), false, 0.03)
	p.line(Vector2(mid, top - rx), Vector2(mid, top - rx - 0.5), Pal.heat(0.6, 1.0), 0.16)
	p.rect(Rect2(mid - 0.3, top - rx - 0.75, 0.6, 0.25), _ink(0.65))
	p.line(Vector2(mid + 0.9, top - rx + 0.25), Vector2(mid + 0.9, top - rx - 0.3), _ink(0.5), 0.08)
	p.circle(Vector2(mid + 0.9, top - rx - 0.38), 0.14, Pal.heat(0.6, 1.0), 8)
	for s in [-1.0, 1.0]:
		p.line(Vector2(x0 - 0.55 + (s + 1.0) * 0.15, top), Vector2(x0 - 0.55 + (s + 1.0) * 0.15, FLOOR), _ink(0.3), 0.04)
	var ly := top + 0.3
	while ly < FLOOR - 0.2:
		p.line(Vector2(x0 - 0.55, ly), Vector2(x0 - 0.25, ly), _ink(0.3), 0.035)
		ly += 0.5
	# the transfer pump's skid at its foot: motor, volute (its impeller drawn moving)
	var pa := PUMP_AT
	p.rect(Rect2(pa.x - 1.6, pa.y + 0.55, 3.2, 0.55), FACE2)
	p.rect(Rect2(pa.x - 1.5, pa.y - 0.45, 1.3, 1.0), Color(0.17, 0.18, 0.19))
	p.rect(Rect2(pa.x - 1.5, pa.y - 0.45, 1.3, 1.0), _ink(0.55), false, 0.035)
	for i in 4:
		p.line(Vector2(pa.x - 1.35 + i * 0.3, pa.y - 0.4), Vector2(pa.x - 1.35 + i * 0.3, pa.y + 0.5), _ink(0.28), 0.03)
	p.circle(Vector2(pa.x + 0.55, pa.y + 0.05), 0.5, Color(0.12, 0.125, 0.135), 16)
	p.ring(Vector2(pa.x + 0.55, pa.y + 0.05), 0.5, _ink(0.6), 0.05, 16)


# the propellant main: the tank's foot out through the floor trench under the table to the
# riser and the reel over the mouth; up the deck's column to the two berths' arms
func _mains(p, lod: int) -> void:
	var col := Pal.heat(0.5, 1.0)
	var trench := FLOOR - 0.35
	p.polyline(PackedVector2Array([Vector2(TANK.position.x + 0.2, FLOOR - 0.6), Vector2(TANK.position.x + 0.2, trench), Vector2(RISER_X, trench), Vector2(RISER_X, REEL.y + 1.0)]), Color(0.02, 0.022, 0.026), 0.34)
	p.polyline(PackedVector2Array([Vector2(TANK.position.x + 0.2, FLOOR - 0.6), Vector2(TANK.position.x + 0.2, trench), Vector2(RISER_X, trench), Vector2(RISER_X, REEL.y + 1.0)]), col, 0.2)
	p.line(Vector2(RISER_X, REEL.y + 1.0), Vector2(REEL.x + 0.9, REEL.y + 1.0), col, 0.2)
	# up the middle column to the deck and along under it to both posts
	p.polyline(PackedVector2Array([Vector2(TANK.position.x + 0.2, TANK.position.y + 2.0), Vector2(38.2, TANK.position.y + 2.0), Vector2(38.2, W.DECK_Y + 0.95)]), col, 0.16)
	p.line(Vector2(float(W.BERTH_X[1]) + 6.6, W.DECK_Y + 0.95), Vector2(float(W.BERTH_X[0]) + 6.6, W.DECK_Y + 0.95), col, 0.14)
	for i in 2:
		p.line(Vector2(float(W.BERTH_X[i]) + 6.6, W.DECK_Y + 0.95), Vector2(float(W.BERTH_X[i]) + 6.6, W.DECK_Y), col, 0.14)
	# the valves on it: a handwheel each
	for vp in [Vector2(RISER_X, 18.0), Vector2(38.2, W.DECK_Y + 1.6)]:
		p.rect(Rect2(vp.x - 0.28, vp.y - 0.2, 0.56, 0.4), FACE2)
		p.ring(vp + Vector2(0.55, 0.0), 0.24, _ink(0.6), 0.05, 10)
	# the reel: its drum and stand (the hose on it is drawn moving)
	p.rect(Rect2(REEL.x - 0.2, REEL.y, 0.4, 1.2), FACE)
	p.circle(REEL, 0.95, Color(0.1, 0.105, 0.115), 20)
	p.ring(REEL, 0.95, _ink(0.6), 0.06, 20)
	p.ring(REEL, 0.35, _ink(0.45), 0.04, 12)
	if lod >= 1:
		var cx := RISER_X + 1.2
		while cx < TANK.position.x:
			p.rect(Rect2(cx, trench - 0.22, 0.12, 0.44), _ink(0.35))   # the pipe's clamps
			cx += 2.4


func _bin_rect(i: int) -> Rect2:
	var c := i % 2
	var row := i / 2
	return Rect2(BINS.position + Vector2(c * 2.35, row * 3.75), Vector2(2.2, 3.55))


# lidless totes, two by two, their fronts cut low so what is in them shows
func _bins(p, lod: int) -> void:
	for i in 4:
		var b := _bin_rect(i)
		p.rect(b, Color(0.11, 0.125, 0.135))
		p.rect(Rect2(b.position, Vector2(b.size.x, 0.25)), _ink(0.5))
		p.rect(Rect2(b.position + Vector2(0.15, 0.3), Vector2(1.2, 0.45)), Pal.ink(0.78))   # the label
		var inner := Rect2(b.position + Vector2(0.15, 1.0), Vector2(b.size.x - 0.3, b.size.y - 1.15))
		p.rect(inner, Color(0.05, 0.055, 0.06))
		if lod >= 1:
			match i:
				0:  # ball valves: body, handle
					for k in 3:
						var c := inner.position + Vector2(0.35 + k * 0.6, inner.size.y - 0.45 - (k % 2) * 0.5)
						p.circle(c, 0.24, _ink(0.55), 10)
						p.circle(c, 0.1, Color(0.05, 0.055, 0.06), 8)
						p.line(c + Vector2(0.0, -0.24), c + Vector2(0.35, -0.5), Pal.heat(0.7, 1.0), 0.07)
				1:  # O-rings
					for k in 5:
						p.ring(inner.position + Vector2(0.35 + (k % 3) * 0.6, inner.size.y - 0.35 - (k / 3) * 0.55), 0.22 - (k % 2) * 0.06, _ink(0.5), 0.06, 12)
				2:  # bolts: heads and shanks
					for k in 6:
						var c := inner.position + Vector2(0.3 + (k % 3) * 0.55, inner.size.y - 0.3 - (k / 3) * 0.6)
						p.circle(c, 0.16, _ink(0.6), 6)
						p.line(c, c + Vector2(0.28, -0.28), _ink(0.45), 0.06)
				3:  # looms: coiled cable with tied ends
					for k in 3:
						var c := inner.position + Vector2(0.9, inner.size.y - 0.5 - k * 0.42)
						p.arc(c, 0.55 - k * 0.08, PI, TAU, [Pal.tint(Pal.AIR, 0.6, 1.0), Pal.heat(0.6, 1.0), _ink(0.6)][k], 0.06, 12)
		p.rect(b, _ink(0.58), false, 0.05)


# the spares rack over T-01: posts, three boards, on them what a tug wears out — nozzle bells,
# cable reels, battery modules with their charge lamps, valve blocks; more of it at stage 2
func _rack(p, lod: int, stage: int) -> void:
	var rk := RACK
	var edge := _ink(0.55)
	for px in [rk.position.x + 0.2, rk.position.x + rk.size.x * 0.5, rk.end.x - 0.2]:
		p.line(Vector2(px, rk.position.y + 0.6), Vector2(px, rk.end.y), edge, 0.14)
	for by in [rk.position.y + 2.25, rk.position.y + 3.75, rk.end.y]:
		p.line(Vector2(rk.position.x, by), Vector2(rk.end.x, by), _ink(0.45), 0.1)
	# top board: two nozzle bells and a cable reel
	var b1 := rk.position.y + 2.2
	for k in (2 if stage >= 2 else 1):
		var bx := rk.position.x + 0.7 + k * 2.3
		var bell := PackedVector2Array([Vector2(bx, b1), Vector2(bx + 0.45, b1 - 1.3), Vector2(bx + 1.35, b1 - 1.3), Vector2(bx + 1.8, b1)])
		p.poly(bell, Color(0.11, 0.105, 0.1))
		p.polyline(bell, _ink(0.7), 0.05, true)
		if lod >= 1:
			for f in [0.3, 0.6]:
				p.line(Vector2(bx + 0.45 * (1.0 - f) + 0.0, b1 - 1.3 * (1.0 - f)), Vector2(bx + 1.8 - 0.45 * (1.0 - f), b1 - 1.3 * (1.0 - f)), _ink(0.2), 0.03)
	var rc := Vector2(rk.position.x + rk.size.x * 0.5 + 2.3, b1 - 0.85)
	p.circle(rc, 0.85, Color(0.1, 0.105, 0.115), 18)
	for k in 4:
		p.ring(rc, 0.75 - k * 0.12, Pal.heat(0.55, 1.0) if k % 2 == 0 else _ink(0.4), 0.05, 18)
	p.circle(rc, 0.22, _ink(0.6), 10)
	# middle board: battery modules (lamps drawn moving)
	var b2 := rk.position.y + 3.7
	for k in (8 if stage >= 2 else 5):
		var bp := Rect2(rk.position.x + 0.5 + k * 1.45, b2 - 1.15, 1.2, 1.1)
		p.rect(bp, Color(0.12, 0.135, 0.145))
		p.rect(bp, Pal.tint(Pal.AIR, 0.5, 1.0), false, 0.04)
		if lod >= 1:
			p.rect(Rect2(bp.position + Vector2(0.15, 0.2), Vector2(0.9, 0.25)), Color(0.05, 0.06, 0.065))
			p.rect(Rect2(bp.position + Vector2(0.2, 0.75), Vector2(0.25, 0.18)), Pal.heat(0.7, 1.0))
			p.rect(Rect2(bp.position + Vector2(0.75, 0.75), Vector2(0.25, 0.18)), _ink(0.6))
	# bottom board: valve blocks and a coiled hose
	var b3 := rk.end.y
	for k in 4:
		var vp := Rect2(rk.position.x + 0.5 + k * 1.6, b3 - 0.95, 1.2, 0.9)
		p.rect(vp, FACE2)
		p.rect(vp, _ink(0.5), false, 0.035)
		p.circle(vp.get_center() + Vector2(0, -0.05), 0.2, Pal.heat(0.6, 1.0), 8)
	var hc := Vector2(rk.end.x - 2.4, b3 - 0.75)
	for k in 3:
		p.ring(hc, 0.68 - k * 0.14, _ink(0.45), 0.08, 16)


# ================================================================== the meshes that move
func _trolley(p) -> void:
	# origin: the ropes' pivot under the drum; the frame hung from the girder's bottom flange
	var edge := _ink(0.7)
	var top := GIRDER.y - W.PIVOT_Y
	p.rect(Rect2(-1.75, top + 0.12, 3.5, 0.9), FACE2)
	p.rect(Rect2(-1.75, top + 0.12, 3.5, 0.9), edge, false, 0.06)
	var mo := Rect2(-1.6, top + 0.25, 1.05, 0.65)
	p.rect(mo, Color(0.17, 0.18, 0.19))
	p.rect(mo, edge, false, 0.04)
	for i in 5:
		p.line(Vector2(mo.position.x + 0.15 + i * 0.18, mo.position.y + 0.06), Vector2(mo.position.x + 0.15 + i * 0.18, mo.end.y - 0.06), _ink(0.3), 0.03)
	p.rect(Rect2(-0.55, top + 0.35, 0.12, 0.45), Pal.heat(0.5, 1.0))
	p.circle(Vector2(0.0, -0.4), 0.4, Color(0.1, 0.105, 0.115), 18)
	p.ring(Vector2(0.0, -0.4), 0.4, edge, 0.05, 18)
	p.rect(Rect2(0.5, top + 0.25, 0.75, 0.65), Color(0.14, 0.15, 0.16))
	p.rect(Rect2(0.5, top + 0.25, 0.75, 0.65), edge, false, 0.04)
	p.bolt(Vector2(0.88, top + 0.57), 0.08, _ink(0.6))
	# the hull scanner under it: a lidar head on a short arm
	p.rect(Rect2(1.0, top + 1.02, 0.12, 0.35), _ink(0.5))
	p.rect(Rect2(0.8, top + 1.35, 0.55, 0.3), Color(0.08, 0.09, 0.1))
	p.rect(Rect2(0.8, top + 1.35, 0.55, 0.3), Pal.tint(Pal.AIR, 0.6, 1.0), false, 0.03)


func _hook_block(p) -> void:
	var edge := _ink(0.75)
	var blk := Rect2(-0.55, -1.6, 1.1, 1.0)
	p.rect(blk, Color(0.14, 0.15, 0.16))
	p.hatch(Rect2(-0.5, -1.05, 1.0, 0.4), Pal.heat(0.55, 1.0), 0.09, 0.3)
	p.rect(blk, edge, false, 0.05)
	p.ring(Vector2(0.0, -1.25), 0.3, _ink(0.6), 0.05, 14)
	p.bolt(Vector2(0.0, -1.25), 0.08, _ink(0.75))
	p.line(Vector2(0.0, -0.6), Vector2(0.0, -0.02), _ink(0.85), 0.14)
	p.arc(Vector2(0.25, -0.02), 0.25, -PI * 0.38, PI, _ink(0.85), 0.13, 14)
	p.circle(Vector2(0.25 + 0.25 * cos(-PI * 0.38), -0.02 + 0.25 * sin(-PI * 0.38)), 0.07, _ink(0.85), 8)
	p.line(Vector2(0.0, -0.2), Vector2(0.33, -0.25), _ink(0.5), 0.035)


# the push frame: what the tug pushing the hulk to the berth bears on. Origin: its lifting lug;
# a top beam, two posts, braces; rubber pads on its left face against the stern, the jaws over
# the hull's top and under its bottom, the tug's socket on its right face
func _frame(p) -> void:
	var edge := _ink(0.75)
	var h := W.FRAME_H
	p.poly(PackedVector2Array([Vector2(-0.3, 0.45), Vector2(-0.12, 0.0), Vector2(0.12, 0.0), Vector2(0.3, 0.45)]), FACE2)
	p.circle(Vector2(0.0, 0.2), 0.08, VOID, 8)
	p.rect(Rect2(-1.2, 0.45, 2.4, 0.5), FACE2)
	p.rect(Rect2(-1.2, 0.45, 2.4, 0.5), edge, false, 0.05)
	for sx in [-0.95, 0.95]:
		p.rect(Rect2(sx - 0.18, 0.95, 0.36, h - 0.95), FACE)
		p.line(Vector2(sx - 0.18, 0.95), Vector2(sx - 0.18, h), edge, 0.05)
		p.line(Vector2(sx + 0.18, 0.95), Vector2(sx + 0.18, h), edge, 0.05)
	for k in 2:
		var y := 1.2 + k * 1.9
		p.line(Vector2(-0.8, y), Vector2(0.8, y + 1.7), _ink(0.4), 0.07)
		p.line(Vector2(0.8, y), Vector2(-0.8, y + 1.7), _ink(0.4), 0.07)
	p.hatch(Rect2(-1.2, 0.5, 2.4, 0.4), Pal.heat(0.6, 1.0), 0.08, 0.3)
	for k in 4:
		p.rect(Rect2(-1.42, 1.2 + k * 0.95, 0.26, 0.7), Color(0.03, 0.03, 0.035))
	for y in [0.65, h - 0.3]:
		p.poly(PackedVector2Array([Vector2(-1.2, y - 0.2), Vector2(-2.0, y - 0.2), Vector2(-2.2, y + 0.15), Vector2(-1.2, y + 0.15)]), FACE2)
	p.rect(Rect2(1.15, h * 0.5 - 0.7, 0.35, 1.4), FACE2)
	p.ring(Vector2(1.5, h * 0.5), 0.45, Pal.heat(0.75, 1.0), 0.09, 14)
	p.bolt(Vector2(1.5, h * 0.5), 0.12, _ink(0.7))


# a thruster pod (as tug_station's first sample); origin the lifting point, body x -3.6 … 2.0,
# y 1.4 … 4.0, the bell out to 5.3. Drawn at POD_K on the tugs, mirrored (the bell aft)
func _pod(p, worn: bool) -> void:
	var edge := _ink(0.72)
	var y0 := 1.4
	var y1 := 4.0
	var cy := (y0 + y1) * 0.5
	for lx in [-2.6, 1.4]:
		p.poly(PackedVector2Array([Vector2(lx - 0.3, y0), Vector2(lx - 0.1, y0 - 0.32), Vector2(lx + 0.1, y0 - 0.32), Vector2(lx + 0.3, y0)]), FACE2)
		p.circle(Vector2(lx, y0 - 0.17), 0.07, VOID, 8)
	var body := PackedVector2Array([Vector2(-3.9, y0 + 0.35), Vector2(-3.55, y0), Vector2(2.0, y0), Vector2(2.0, y1), Vector2(-3.55, y1), Vector2(-3.9, y1 - 0.35)])
	p.poly(body, Color(0.155, 0.165, 0.178))
	p.rect(Rect2(-3.55, y0 + 0.06, 5.5, 0.28), Color(0.2, 0.21, 0.225))
	p.rect(Rect2(-3.55, y1 - 0.45, 5.5, 0.39), Color(0.11, 0.115, 0.125))
	for sx in [-2.2, -0.6, 1.0]:
		p.line(Vector2(sx, y0 + 0.05), Vector2(sx, y1 - 0.05), _ink(0.26), 0.05)
	var ap := Rect2(-1.95, y0 + 0.6, 1.1, 1.25)
	p.rect(ap, Color(0.13, 0.14, 0.15))
	p.rect(ap, _ink(0.5), false, 0.05)
	p.line(Vector2(-3.5, y1 - 0.75), Vector2(2.1, y1 - 0.75), Pal.heat(0.55, 1.0), 0.1)
	p.line(Vector2(-3.5, y1 - 0.5), Vector2(2.1, y1 - 0.5), Pal.tint(Pal.AIR, 0.5, 1.0), 0.08)
	p.polyline(body, edge, 0.1, true)
	p.rect(Rect2(2.0, y0 + 0.15, 0.45, y1 - y0 - 0.3), Color(0.17, 0.18, 0.19))
	p.rect(Rect2(2.0, y0 + 0.15, 0.45, y1 - y0 - 0.3), edge, false, 0.07)
	for s in [-1.0, 1.0]:
		p.line(Vector2(1.5, cy + s * 0.95), Vector2(2.95, cy + s * 0.55), _ink(0.6), 0.14)
	var prof := func(u: float) -> float: return 0.42 + 0.88 * pow(u, 0.62)
	var up := PackedVector2Array()
	var dn := PackedVector2Array()
	for i in 13:
		var u := i / 12.0
		var x := lerpf(2.5, 5.3, u)
		up.append(Vector2(x, cy - prof.call(u)))
		dn.append(Vector2(x, cy + prof.call(u)))
	var bell := up.duplicate()
	for i in range(dn.size() - 1, -1, -1):
		bell.append(dn[i])
	p.poly(bell, Color(0.1, 0.098, 0.096))
	for k in [0.35, 0.7]:
		var ch := PackedVector2Array()
		for i in 13:
			var u := i / 12.0
			ch.append(Vector2(lerpf(2.5, 5.3, u), cy - prof.call(u) * k))
		p.polyline(ch, _ink(0.2), 0.05)
		for j in ch.size():
			ch[j].y = cy + (cy - ch[j].y)
		p.polyline(ch, _ink(0.2), 0.05)
	p.polyline(up, edge, 0.1)
	p.polyline(dn, edge, 0.1)
	p.line(Vector2(5.3, cy - prof.call(1.0) - 0.06), Vector2(5.3, cy + prof.call(1.0) + 0.06), _ink(0.85), 0.16)
	if worn:
		_soot(p)


func _soot(p) -> void:
	var y0 := 1.4
	var cy := (y0 + 4.0) * 0.5
	var prof := func(u: float) -> float: return 0.42 + 0.88 * pow(u, 0.62)
	for i in 6:
		var u0 := i / 6.0
		var u1 := (i + 1) / 6.0
		var x0 := lerpf(2.5, 5.3, u0)
		var x1 := lerpf(2.5, 5.3, u1)
		p.poly(PackedVector2Array([Vector2(x0, cy - prof.call(u0) * 0.9), Vector2(x1, cy - prof.call(u1) * 0.9), Vector2(x1, cy + prof.call(u1) * 0.9), Vector2(x0, cy + prof.call(u0) * 0.9)]), Pal.heat(0.08 + 0.1 * u0, 1.0))
	for k in 4:
		var sy := y0 + 0.5 + k * 0.6
		p.line(Vector2(2.0 - 0.6 - k * 0.3, sy), Vector2(2.0, sy + 0.1), Color(0.02, 0.02, 0.02, 0.65), 0.12)


# an industrial pusher tug, side on, nose (+x) to the right: the hull on two landing skids, the
# cockpit, the push plate with its fenders, the tow winch, the RCS quads; its aft pod is separate
func _tug(p) -> void:
	var edge := _ink(0.82)
	var hull := PackedVector2Array([Vector2(-5.6, -0.6), Vector2(5.0, -0.6), Vector2(5.9, -1.5), Vector2(5.9, -3.1), Vector2(4.6, -4.5), Vector2(-3.0, -4.5), Vector2(-5.6, -3.7)])
	for sx in [-3.4, 3.2]:
		p.line(Vector2(sx, -0.6), Vector2(sx - 0.3, -0.08), _ink(0.6), 0.14)
		p.line(Vector2(sx, -0.6), Vector2(sx + 0.3, -0.08), _ink(0.6), 0.14)
		p.rect(Rect2(sx - 0.6, -0.12, 1.2, 0.12), _ink(0.55))
	p.poly(hull, Color(0.1, 0.106, 0.118))
	p.rect(Rect2(-5.2, -4.2, 9.6, 0.5), Color(0.14, 0.148, 0.16))
	p.rect(Rect2(-5.4, -1.4, 10.6, 0.7), Color(0.07, 0.074, 0.082))
	for sx in [-2.6, 0.0, 2.6]:
		p.line(Vector2(sx, -4.45), Vector2(sx, -0.65), _ink(0.22), 0.04)
	p.hatch(Rect2(-5.0, -1.35, 9.8, 0.55), Pal.heat(0.5, 1.0), 0.09, 0.55)
	# the cockpit glazing, its frames
	var gl := PackedVector2Array([Vector2(3.4, -4.25), Vector2(4.5, -4.25), Vector2(5.55, -3.05), Vector2(5.55, -2.2), Vector2(3.4, -2.2)])
	p.poly(gl, Pal.tint(Pal.AIR, 0.38, 1.1))
	p.polyline(gl, _ink(0.7), 0.06, true)
	p.line(Vector2(4.45, -4.25), Vector2(4.45, -2.2), _ink(0.6), 0.05)
	# the hatch and the access ladder rungs
	p.rect(Rect2(0.6, -3.7, 1.1, 2.0), Color(0.13, 0.14, 0.15))
	p.rect(Rect2(0.6, -3.7, 1.1, 2.0), _ink(0.55), false, 0.04)
	# the push plate with its fenders
	p.rect(Rect2(5.9, -3.9, 0.35, 3.0), FACE2)
	for k in 3:
		p.rect(Rect2(6.25, -3.7 + k * 0.95, 0.3, 0.7), Color(0.03, 0.03, 0.035))
	# the tow winch on top, its boom
	p.rect(Rect2(-2.4, -5.0, 1.8, 0.5), FACE2)
	p.circle(Vector2(-1.5, -5.1), 0.42, Color(0.1, 0.1, 0.11), 14)
	p.ring(Vector2(-1.5, -5.1), 0.42, _ink(0.65), 0.05, 14)
	p.line(Vector2(-0.6, -4.9), Vector2(1.6, -5.6), _ink(0.6), 0.1)
	# RCS quads at the corners
	for c in [Vector2(-4.6, -4.6), Vector2(4.0, -4.6), Vector2(-4.8, -0.55), Vector2(4.3, -0.55)]:
		p.rect(Rect2(c - Vector2(0.35, 0.18), Vector2(0.7, 0.36)), Color(0.15, 0.16, 0.17))
		p.line(c + Vector2(-0.35, 0.0), c + Vector2(-0.6, 0.0), _ink(0.55), 0.07)
		p.line(c + Vector2(0.35, 0.0), c + Vector2(0.6, 0.0), _ink(0.55), 0.07)
	# the aft pod's mount, the ports the deck's arm and umbilical take
	p.rect(Rect2(-5.9, -3.0, 0.5, 1.5), FACE2)
	p.rect(Rect2(2.6, -1.6, 0.4, 0.4), Pal.heat(0.75, 1.0))
	p.rect(Rect2(4.2, -1.65, 0.4, 0.4), Pal.tint(Pal.AIR, 0.75, 1.0))
	p.polyline(hull, edge, 0.09, true)


# the lift's platform (origin: where the pod's lifting point would be on it)
func _platform(p) -> void:
	var y := 2.0 * W.POD_K
	p.rect(Rect2(-1.5, y, 3.0, 0.32), FACE2)
	p.hatch(Rect2(-1.45, y + 0.04, 2.9, 0.24), Pal.heat(0.5, 1.0), 0.07, 0.3)
	p.rect(Rect2(-1.5, y, 3.0, 0.32), _ink(0.7), false, 0.04)
	for sx in [-1.55, 1.55]:
		p.rect(Rect2(sx - 0.12, y - 0.3, 0.24, 0.7), _ink(0.55))


# ================================================================== the moving parts
func moving(ci: CanvasItem, t: float, on: bool, lod: int) -> void:
	var edge := _ink(0.7)
	_mouth(ci, t, on)
	_deck_moving(ci, t, on)
	_table_moving(ci, t, on)
	_tank_moving(ci, t, on)
	# the plates (under the gantry's ropes and hook)
	plate(ci, PLATES.gantry[0], PLATES.gantry[1], w("龙门吊", "GANTRY"), W.gantry_state(), t)
	plate(ci, PLATES.mouth[0], PLATES.mouth[1], w("船坞口", "MOUTH"), W.mouth_state(), t)
	plate(ci, PLATES.t01[0], PLATES.t01[1], "T-01", W.berth_state(0), t)
	plate(ci, PLATES.t02[0], PLATES.t02[1], "T-02", W.berth_state(1), t)
	plate(ci, PLATES.table[0], PLATES.table[1], w("检修台", "SERVICE"), W.table_state(), t)
	plate(ci, PLATES.tank[0], PLATES.tank[1], w("推进剂", "MMH"), W.tank_state(), t)
	_gantry_moving(ci, t, on)


# the mouth: its doors, the hulk's clamp arms, the drain hose
func _mouth(ci: CanvasItem, t: float, on: bool) -> void:
	var mo: Vector2 = W.MOUTH
	var open := smoothstep(0.0, 1.0, W.mouth_door)
	var half := (mo.y - mo.x) * 0.5
	var leaf := half * (1.0 - open)
	if leaf > 0.02:
		for k in 2:
			var y0 := mo.x if k == 0 else mo.y - leaf
			ci.draw_rect(Rect2(_p(Vector2(-0.3, y0)), Vector2(0.95, leaf) * m), Color(0.12, 0.125, 0.135))
			var ln := PackedVector2Array()
			var yy := y0 + 0.5
			while yy < y0 + leaf - 0.1:
				ln.append_array([_p(Vector2(-0.3, yy)), _p(Vector2(0.65, yy))])
				yy += 0.5
			if not ln.is_empty():
				ci.draw_multiline(ln, _ink(0.3), _lw(0.03))
			var edge_y := y0 + leaf if k == 0 else y0
			ci.draw_line(_p(Vector2(-0.3, edge_y)), _p(Vector2(0.65, edge_y)), Pal.heat(0.75, 1.0), _lw(0.1))
	# the push frame on its stand
	if W.frame_on == "stand":
		_put(ci, _mesh("frame", _frame), Vector2(W.FRAME_STAND.x, W.FRAME_STAND.y - 0.5 - W.FRAME_H))
	# the hulk's stern in the mouth: its outline from its ship file, cut at the wall (outside,
	# the port draws the rest), lit along its top by the hall
	if not W.hulk.is_empty() and bool(W.hulk.inside):
		_put(ci, _hulk_mesh(str(W.hulk.ship), W.stern_x()), Vector2.ZERO)
		_text(ci, Vector2(1.6, W.hull_top() + 1.1), str(W.hulk.id), 0.6, _ink(0.55))
	# the beacon on the pier: amber while the doors move or a hulk is worked
	var busy := absf(W.mouth_door - (1.0 if not W.hulk.is_empty() and bool(W.hulk.inside) else 0.0)) > 0.01 or not W.prep_steps.is_empty()
	FastDraw.circle(ci, _p(Vector2(1.05, W.GATE.y + 0.95)), 0.22 * m, Pal.heat(0.35 + 0.65 * absf(sin(t * 6.0)), 1.6) if busy else (Pal.tint(Pal.FLUID, 0.85, 1.3) if on else _ink(0.2)))
	if W.hulk.is_empty() and W.arms <= 0.001:
		return
	# the clamp arms: from the mouth's top and bottom frame onto the hull near the stern
	var sx := W.stern_x()
	var ax := clampf(sx - 2.2, -1.2, 5.0)
	var k := smoothstep(0.0, 1.0, W.arms)
	var top := W.hull_top() if not W.hulk.is_empty() else mo.x + 2.0
	var bot := W.hull_bot() if not W.hulk.is_empty() else mo.y - 2.0
	for s in [-1.0, 1.0]:
		var base := Vector2(0.9, mo.x + 0.35 if s < 0.0 else mo.y - 0.35)
		var reach := Vector2(ax, top - 0.25 if s < 0.0 else bot + 0.25)
		var tip := base.lerp(reach, k) if k > 0.0 else base
		var elbow := (base + tip) * 0.5 + Vector2(0.9, 0.0) * (1.0 - absf(k - 0.5) * 2.0)
		ci.draw_line(_p(base), _p(elbow), Color(0.15, 0.158, 0.172), _lw(0.42))
		ci.draw_line(_p(base), _p(elbow), _ink(0.6), _lw(0.06))
		ci.draw_line(_p(elbow), _p(tip), _ink(0.75), _lw(0.16))
		var pad := Vector2(0.75, 0.0)
		ci.draw_line(_p(tip - pad), _p(tip + pad), Color(0.03, 0.03, 0.035) if k < 0.99 else Pal.tint(Pal.FLUID, 0.8, 1.1), _lw(0.22))
		FastDraw.circle(ci, _p(base), 0.22 * m, Pal.heat(0.6, 1.0))
	# the drain hose: off the reel, sagging, to the hulk's drain port low on its stern
	if W.hose > 0.01 and not W.hulk.is_empty():
		var port := Vector2(sx - 0.8, W.hull_bot() - 1.2)
		var from := REEL + Vector2(0.0, 0.95)
		var end := from.lerp(port, smoothstep(0.0, 1.0, W.hose))
		var pts := PackedVector2Array()
		var n := 14
		var sag := 2.2 * W.hose
		for i in n + 1:
			var u := float(i) / n
			pts.append(_p(from.lerp(end, u) + Vector2(0.0, sag * 4.0 * u * (1.0 - u))))
		FastDraw.polyline(ci, pts, Color(0.02, 0.022, 0.026), _lw(0.3))
		FastDraw.polyline(ci, pts, Pal.heat(0.55, 1.0), _lw(0.18))
		if W.hose > 0.98:
			FastDraw.circle(ci, _p(end), 0.22 * m, _ink(0.75))
			if W.drain < 1.0 and on:
				# the propellant running in: pulses along the hose from the hulk to the reel
				var dots := PackedVector2Array()
				for j in 5:
					var u := 1.0 - fmod(t * 0.45 + j * 0.2, 1.0)
					var q := from.lerp(end, u) + Vector2(0.0, sag * 4.0 * u * (1.0 - u))
					dots.append_array([_p(q), _p(q + Vector2(0.3, 0.0))])
				ci.draw_multiline(dots, Pal.heat(1.0, 1.6), _lw(0.16))
	# the frame on the stern
	if W.frame_on == "hulk" and not W.hulk.is_empty():
		_put(ci, _mesh("frame", _frame), Vector2(sx + 1.2, float(W.hulk.cy) - W.FRAME_H * 0.5))


# a hulk's outline as it lies in the mouth (box-local m), cut at the wall's inner face
const TowTraffic = preload("res://scripts/tow_traffic.gd")
func _hulk_mesh(ship: String, stern: float) -> ArrayMesh:
	return _mesh("hulk/%s/%.2f" % [ship, stern], func(p):
		var polys: Array = []
		var x1 := -INF
		var y0 := INF
		var y1 := -INF
		for pd in Ship.load_data(ship).get("pieces", []):
			var pts := PackedVector2Array()
			for q in pd.get("poly", []):
				var v := Vector2(float(q[0]), float(q[1]))
				pts.append(v)
				x1 = maxf(x1, v.x)
				y0 = minf(y0, v.y)
				y1 = maxf(y1, v.y)
			if pts.size() >= 3:
				polys.append(pts)
		var off := Vector2(stern - x1, (W.MOUTH.x + W.MOUTH.y) * 0.5 - (y0 + y1) * 0.5)
		var clip := PackedVector2Array([Vector2(0.75, 0.0), Vector2(60.0, 0.0), Vector2(60.0, 28.0), Vector2(0.75, 28.0)])
		for sil in TowTraffic._silhouette(polys):
			var moved := PackedVector2Array()
			for v in sil:
				moved.append(v + off)
			for part in Geometry2D.intersect_polygons(moved, clip):
				if Geometry2D.is_polygon_clockwise(part):
					continue
				p.poly(part, Color(0.07, 0.075, 0.085))
				# the hall's lights along its top edge, its outline
				var top := PackedVector2Array()
				for v in part:
					if v.y < (W.MOUTH.x + W.MOUTH.y) * 0.5 and v.x > 0.8:
						top.append(v)
				p.polyline(part, _ink(0.62), 0.08, true)
				for i in range(1, top.size()):
					if top[i].distance_to(top[i - 1]) < 6.0:
						p.line(top[i - 1] + Vector2(0, 0.12), top[i] + Vector2(0, 0.12), Pal.tint(Pal.AIR, 0.22, 1.0), 0.1)
		# the drain port low on the stern, the stencil band
		p.rect(Rect2(stern - 1.2, (W.MOUTH.x + W.MOUTH.y) * 0.5 + (y1 - y0) * 0.5 - 1.5, 0.8, 0.6), Pal.heat(0.6, 1.0))
	)


# the tug deck: the gate, the tugs coming and going and on their berths, the arms and
# umbilicals, the hatches, the lifts
func _deck_moving(ci: CanvasItem, t: float, on: bool) -> void:
	var g: Vector2 = W.GATE
	# the gate: a single leaf rolled up into the lintel
	var leaf := (g.y - g.x) * (1.0 - smoothstep(0.0, 1.0, W.gate))
	if leaf > 0.02:
		ci.draw_rect(Rect2(_p(Vector2(-0.3, g.x)), Vector2(0.95, leaf) * m), Color(0.13, 0.135, 0.145))
		ci.draw_line(_p(Vector2(-0.3, g.x + leaf)), _p(Vector2(0.65, g.x + leaf)), Pal.heat(0.75, 1.0), _lw(0.1))
	var gate_busy := W.gate > 0.01 and W.gate < 0.99
	FastDraw.circle(ci, _p(Vector2(1.05, g.x - 0.45)), 0.18 * m, Pal.heat(0.35 + 0.65 * absf(sin(t * 7.0)), 1.6) if gate_busy or W.gate > 0.99 else _ink(0.2))
	# the hatches: two leaves sliding apart
	for i in 2:
		var lx := W.lift_x(i)
		var o := smoothstep(0.0, 1.0, float(W.hatch[i]))
		for s in [-1.0, 1.0]:
			var x0: float = lx + s * 1.6 * o - (1.6 if s < 0.0 else 0.0)
			ci.draw_rect(Rect2(_p(Vector2(x0, W.DECK_Y)), Vector2(1.6, 0.18) * m), Color(0.2, 0.21, 0.225))
		if o < 0.02:
			ci.draw_line(_p(Vector2(lx, W.DECK_Y)), _p(Vector2(lx, W.DECK_Y + 0.18)), Pal.heat(0.6, 1.0), _lw(0.05))
		# the lift's platform and what is on it
		var ly: float = W.lift[i]
		ci.draw_line(_p(Vector2(lx, ly + 2.0 * W.POD_K + 0.3)), _p(Vector2(lx, TABLE_TOP + 0.2)), _ink(0.35), _lw(0.12))
		_put(ci, _mesh("platform", _platform), Vector2(lx, ly))
		if str(W.lift_pod[i]) != "":
			_pod_at(ci, Vector2(lx, ly), str(W.lift_pod[i]), 1.0)
	# the tugs: the far lane first (T-02, dimmer and a touch higher), then the near
	for i in [1, 0]:
		if i >= W.count_now and float(W.dock[i]) <= 0.001:
			continue
		var at := W.tug_at(i)
		if at.x < -12.0:
			continue
		var far: bool = i == 1
		var mod := Color(0.78, 0.78, 0.8) if far else Color.WHITE
		var off := Vector2(0.0, -0.25) if far else Vector2.ZERO
		var fade := smoothstep(-12.0, -6.0, at.x)
		mod.a = fade
		var flying := float(W.dock[i]) > 0.001 and float(W.dock[i]) < 0.999
		var hover := 0.0
		if flying:
			hover = -0.35 * sin(clampf(float(W.dock[i]), 0.0, 1.0) * PI)
		var tp := at + off + Vector2(0.0, hover)
		if flying:
			# the main drive's plume aft while it moves in, the retro forward as it brakes in
			var k := float(W.dock[i])
			var dir := 1.0 if bool(W.home_now[i]) else -1.0
			var braking := dir > 0.0 and k > 0.6
			var f := 0.6 + 0.4 * sin(t * 40.0 + i)
			if not braking:
				ci.draw_line(_p(tp + Vector2(-6.2 - 1.2, -2.3)), _p(tp + Vector2(-6.2 - 1.2 - 2.4 * f, -2.3)), Pal.heat(0.85, 1.8), _lw(0.5))
				ci.draw_line(_p(tp + Vector2(-6.2 - 1.2, -2.3)), _p(tp + Vector2(-6.2 - 1.2 - 1.2 * f, -2.3)), Color(1.0, 0.95, 0.85, 0.9), _lw(0.22))
			else:
				for c in [Vector2(4.0, -4.6), Vector2(4.3, -0.55)]:
					ci.draw_line(_p(tp + c + Vector2(0.6, 0.0)), _p(tp + c + Vector2(0.6 + 1.1 * f, 0.0)), Pal.tint(Pal.AIR, 0.9, 1.6), _lw(0.16))
		_put(ci, _mesh("tug", _tug), tp, 0.0, mod)
		if bool(W.tug_pod[i]):
			_pod_at(ci, Vector2(tp.x - W.AFT, W.POD_ON_TUG + off.y + hover), "spare", mod.a, mod)
		# its name, its nav lights (red port aft, green bow), the cockpit's glow
		_text(ci, tp + Vector2(-1.8, -2.15), TugFleet.NAMES[i], 0.62, Pal.ink(0.85 * mod.a))
		var blink := 0.5 + 0.5 * sin(t * 3.0 + i * 1.7)
		FastDraw.circle(ci, _p(tp + Vector2(-5.5, -4.0)), 0.13 * m, Color(1.0, 0.25, 0.2, blink * mod.a))
		FastDraw.circle(ci, _p(tp + Vector2(5.6, -3.4)), 0.13 * m, Color(0.3, 1.0, 0.45, blink * mod.a))
		# berthed: the propellant arm and the charging umbilical from its post
		var post := Vector2(float(W.BERTH_X[i]) + 6.6, W.DECK_Y)
		if float(W.arm[i]) > 0.01:
			var to := at + Vector2(2.8, -1.4)
			var piv := post + Vector2(0.0, -3.2)
			var tip := piv.lerp(to, smoothstep(0.0, 1.0, float(W.arm[i])))
			var el := (piv + tip) * 0.5 + Vector2(0.0, -1.0)
			ci.draw_line(_p(piv), _p(el), _ink(0.7), _lw(0.16))
			ci.draw_line(_p(el), _p(tip), Pal.heat(0.75, 1.0), _lw(0.14))
			if float(W.arm[i]) > 0.98 and W.fuel_tug == i:
				var u := fmod(t * 1.2, 1.0)
				FastDraw.circle(ci, _p(el.lerp(tip, u)), 0.12 * m, Pal.heat(1.0, 1.7))
		if float(W.umb[i]) > 0.01:
			var to2 := at + Vector2(4.4, -1.45)
			var from := post + Vector2(0.0, -1.2)
			var end := from.lerp(to2, smoothstep(0.0, 1.0, float(W.umb[i])))
			var pts := PackedVector2Array()
			for j in 9:
				var u := j / 8.0
				pts.append(_p(from.lerp(end, u) + Vector2(0.0, 0.8 * 4.0 * u * (1.0 - u))))
			FastDraw.polyline(ci, pts, Pal.tint(Pal.AIR, 0.6, 1.1), _lw(0.1))
			if float(W.umb[i]) > 0.98 and on:
				var u2 := fmod(t * 0.9 + i * 0.3, 1.0)
				FastDraw.circle(ci, _p(from.lerp(end, u2) + Vector2(0.0, 0.8 * 4.0 * u2 * (1.0 - u2))), 0.11 * m, Pal.tint(Pal.AIR, 1.0, 1.8))


# a pod at the tugs' size, the bell aft (left); worn: its soot faded as the overhaul goes
func _pod_at(ci: CanvasItem, at: Vector2, kind: String, a := 1.0, mod := Color.WHITE) -> void:
	var c := Color(mod.r, mod.g, mod.b, a)
	_put(ci, _mesh("pod", func(p): _pod(p, false)), at, 0.0, c, W.POD_K, true)
	if kind == "worn" or kind == "soot":
		_put(ci, _mesh("soot", _soot), at, 0.0, Color(1, 1, 1, a), W.POD_K, true)


func _table_moving(ci: CanvasItem, t: float, on: bool) -> void:
	var y: float = W.TABLE_Y
	if str(W.slot.A) != "":
		_pod_at(ci, Vector2(W.SLOT_A, y), str(W.slot.A))
	if str(W.slot.B) != "":
		var worn := str(W.slot.B) == "worn"
		_put(ci, _mesh("pod", func(p): _pod(p, false)), Vector2(W.SLOT_B, y), 0.0, Color.WHITE, W.POD_K, true)
		if worn and W.wear > 0.0:
			_put(ci, _mesh("soot", _soot), Vector2(W.SLOT_B, y), 0.0, Color(1, 1, 1, W.wear), W.POD_K, true)
	# the transfer slide's carriage under whatever it carries
	ci.draw_rect(Rect2(_p(Vector2(W.tx - 1.2, TABLE_TOP - 0.05)), Vector2(2.4, 0.25) * m), Pal.heat(0.7, 1.0))
	if W.t_pod != "":
		_pod_at(ci, Vector2(W.tx, y - 0.25), W.t_pod)
	# the NDT probe on its rail under the deck: parked, or scanning the bell on saddle B
	var overhaul := str(W.slot.B) == "worn" and on
	var bell_x := W.SLOT_B - (2.5 + 1.4 * (0.5 + 0.5 * sin(t * 0.6))) * W.POD_K
	var hx := bell_x if overhaul else PROBE_RAIL.y - 0.4
	var head := Vector2(hx, W.DECK_Y + 2.1)
	ci.draw_rect(Rect2(_p(head - Vector2(0.3, 0.0)), Vector2(0.6, 0.45) * m), FACE2)
	ci.draw_rect(Rect2(_p(head - Vector2(0.3, 0.0)), Vector2(0.6, 0.45) * m), _ink(0.6), false, _lw(0.04))
	var cy := y + 2.7 * W.POD_K
	var hit := Vector2(hx, cy - 0.65 * W.POD_K * 1.6) if overhaul else head + Vector2(0, 1.2)
	ci.draw_line(_p(head + Vector2(0, 0.45)), _p(Vector2(hx, (hit.y if overhaul else head.y + 1.0) - 0.6)), _ink(0.55), _lw(0.05))
	FastDraw.circle(ci, _p(Vector2(hx, (hit.y if overhaul else head.y + 1.0) - 0.6)), 0.1 * m, Pal.tint(Pal.AIR, 0.95, 1.4) if overhaul else _ink(0.35))
	if overhaul:
		var tip := Vector2(hx, hit.y - 0.6)
		ci.draw_line(_p(tip), _p(hit), Pal.tint(Pal.AIR, 0.55, 1.3), _lw(0.04))
		ci.draw_line(_p(tip), _p(hit + Vector2(-0.3, 0.2)), Pal.tint(Pal.AIR, 0.25, 1.3), _lw(0.03))
		ci.draw_line(_p(tip), _p(hit + Vector2(0.3, 0.2)), Pal.tint(Pal.AIR, 0.25, 1.3), _lw(0.03))
	# the table's screen: the overhaul's progress
	var st := W.table_state()
	if str(W.slot.B) == "worn" and on:
		var bar := Rect2(_p(Vector2(W.SLOT_B - 1.6, TABLE_TOP + 1.25)), Vector2(3.2, 0.2) * m)
		ci.draw_rect(bar, _ink(0.15))
		ci.draw_rect(Rect2(bar.position, Vector2(bar.size.x * (1.0 - W.wear), bar.size.y)), lamp_col(str(st[1]), t))


func _tank_moving(ci: CanvasItem, t: float, on: bool) -> void:
	var x0 := TANK.position.x
	var x1 := TANK.end.x
	var rx := (x1 - x0) * 0.5
	var top := TANK.position.y + rx
	var bot := TANK.end.y - 1.6 - rx
	var f := clampf(W.tank_show / TugYard.TANK_M3, 0.0, 1.0)
	# the liquid in the shell (the heads counted as straight: a hair of a difference)
	var span := (bot + rx) - (top - rx)
	var ly := (bot + rx) - span * f
	if f > 0.002:
		var y0 := maxf(ly, top)
		ci.draw_rect(Rect2(_p(Vector2(x0 + 0.06, y0)), Vector2(x1 - x0 - 0.12, bot - y0) * m), Pal.heat(0.16, 1.0))
		var surf := PackedVector2Array()
		for i in 9:
			var u := i / 8.0
			surf.append(_p(Vector2(lerpf(x0 + 0.1, x1 - 0.1, u), y0 + 0.06 * sin(t * 2.2 + u * 6.0) * W.pump)))
		FastDraw.polyline(ci, surf, Pal.heat(0.75, 1.2), _lw(0.06))
	# the sight glass's level and its float
	var gy := lerpf(bot - 0.4, top + 0.4, f)
	ci.draw_rect(Rect2(_p(Vector2(x1 + 0.18, gy)), Vector2(0.22, bot - 0.4 - gy) * m), Pal.heat(0.55, 1.2))
	ci.draw_line(_p(Vector2(x1 + 0.1, gy)), _p(Vector2(x1 + 0.5, gy)), _ink(0.9), _lw(0.06))
	# the pump's impeller turning as hard as it works
	var c := PUMP_AT + Vector2(0.55, 0.05)
	var marks := PackedVector2Array()
	for k in 3:
		var a := t * 14.0 * W.pump + TAU * k / 3.0
		marks.append_array([_p(c), _p(c + Vector2.from_angle(a) * 0.4)])
	ci.draw_multiline(marks, Pal.heat(0.4 + 0.5 * W.pump, 1.2) if on else _ink(0.4), _lw(0.06))
	# the batteries on the rack: their charge lamps breathing
	for k in (8 if Port.stage("tug") >= 2 else 5):
		var lp := Vector2(RACK.position.x + 0.5 + k * 1.45 + 0.32, RACK.position.y + 3.7 - 0.31)
		FastDraw.circle(ci, _p(lp), 0.07 * m, Pal.tint(Pal.FLUID, 0.5 + 0.5 * sin(t * 1.4 + k), 1.3) if on else _ink(0.2))


# the gantry: the festoon, the trolley and its scanner, the ropes, the hook block and the frame
func _gantry_moving(ci: CanvasItem, t: float, on: bool) -> void:
	var tx := W.x
	var n := 5
	var span := maxf(0.4, (tx - 1.9) - 2.6) / n
	var sag := clampf(1.2 - span * 0.35, 0.12, 1.0)
	var fl := PackedVector2Array()
	var fy := GIRDER.y + 0.24
	for i in n:
		var xa := 2.6 + i * span
		var xb := xa + span
		var prev := Vector2(xa, fy + 0.12)
		for j in range(1, 7):
			var u := j / 6.0
			var q := Vector2(lerpf(xa, xb, u), fy + 0.12 + sag * 4.0 * u * (1.0 - u))
			fl.append_array([_p(prev), _p(q)])
			prev = q
		ci.draw_rect(Rect2(_p(Vector2(xb - 0.13, fy - 0.07)), Vector2(0.26, 0.22) * m), _ink(0.55))
	ci.draw_multiline(fl, Pal.tint(Pal.AIR, 0.45, 1.0), _lw(0.045))
	_put(ci, _mesh("trolley", _trolley), Vector2(tx, W.PIVOT_Y))
	var marks := PackedVector2Array()
	for k in 3:
		var a := W.drum + TAU * k / 3.0
		marks.append_array([_p(Vector2(tx, W.PIVOT_Y - 0.4)), _p(Vector2(tx, W.PIVOT_Y - 0.4) + Vector2.from_angle(a) * 0.34)])
	for wx in [tx - 1.3, tx + 1.3]:
		for k in 2:
			var a := W.wheel + PI * k
			marks.append_array([_p(Vector2(wx, GIRDER.y - 0.05)), _p(Vector2(wx, GIRDER.y - 0.05) + Vector2.from_angle(a) * 0.13)])
	ci.draw_multiline(marks, _ink(0.75), _lw(0.04))
	var running := absf(W.vx) > 0.01 or absf(W.vh) > 0.01
	FastDraw.circle(ci, _p(Vector2(tx + 1.55, GIRDER.y + 0.28)), 0.12 * m, Pal.heat(0.35 + 0.65 * absf(sin(t * 8.0)), 1.6) if running else (_ink(0.3) if on else _ink(0.12)))
	# the scanner's fan sweeping the hull top
	if W.scan > 0.02 and not W.hulk.is_empty():
		var sh := Vector2(tx + 1.07, W.PIVOT_Y - 1.1 + 1.65)
		var ht := W.hull_top()
		var sw := sin(t * 5.0) * 1.2
		var a := Pal.tint(Pal.AIR, 0.45 * W.scan, 1.4)
		ci.draw_line(_p(sh), _p(Vector2(sh.x - 1.4 + sw, ht)), a, _lw(0.03))
		ci.draw_line(_p(sh), _p(Vector2(sh.x + 1.4 + sw, ht)), a, _lw(0.03))
		ci.draw_line(_p(Vector2(sh.x - 1.4 + sw, ht)), _p(Vector2(sh.x + 1.4 + sw, ht)), Pal.tint(Pal.AIR, 0.9 * W.scan, 1.6), _lw(0.08))
	var piv := Vector2(tx, W.PIVOT_Y)
	var dir := Vector2(sin(W.sway), cos(W.sway))
	var hk := piv + dir * (W.hook - W.PIVOT_Y)
	var rot := -W.sway
	var xf := Transform2D(rot, hk)
	for s in [-0.3, 0.3]:
		ci.draw_line(_p(piv + Vector2(s * 0.75, 0.0)), _p(xf * Vector2(s, -1.6)), _ink(0.62), _lw(0.05))
	_put(ci, _mesh("hook", _hook_block), hk, rot)
	if W.on_hook == "frame":
		_put(ci, _mesh("frame", _frame), hk + Vector2(0.25, 0.2), rot)


# ================================================================== the hover cards (Q3 B)
# what each machine is, what it is doing, what the player can do with it (scripts/facility_card.gd)
func hover_items() -> Array:
	var st := Port.stage("tug")
	var share := int(round(TugYard.drain_share() * 100.0))
	var out: Array = []
	var add := func(id: String, rects: Array, title: String, use: String, now: Array, can: String) -> void:
		for rr in rects:
			out.append({"rect": Rect2(_p((rr as Rect2).position), (rr as Rect2).size * m), "title": title, "use": use, "now": str(now[0]), "can": can, "lamp": str(now[1])})
	var pr := func(id: String) -> Rect2: return Rect2(PLATES[id][0], Vector2(PLATES[id][1], 0.9))
	add.call("mouth", [pr.call("mouth"), Rect2(0.0, W.MOUTH.x, TugYard.DOCK_IN, W.MOUTH.y - W.MOUTH.x)], w("船坞口", "THE MOUTH"),
		w("拖回来的船先停进这里：高不过 %.0f m 的船尾伸进站内，系泊臂夹住，软管抽走一部分推进剂，装上推船夹具，扫描船体。更高的船停在外面露天泊位。" % (TugYard.mouth_h() - 1.0),
			"Hulks towed home lie here first: one under %.0f m tall goes in stern first, is clamped, drawn off, fitted with the push frame and scanned. Taller ones wait outside." % (TugYard.mouth_h() - 1.0)),
		W.mouth_state(),
		w("不用操作，自动处理。拖船站等级越高抽得越多（现在 %d%%）：拆的时候船里推进剂更少、更不容易起火，抽出的推进剂进储罐。接单开工就把它推去船坞。" % share,
			"Nothing to do: it runs by itself. A better station draws off more (now %d%%): less propellant aboard to burn when you cut, and the tank fills. Start the job and it is pushed to the berth." % share))
	add.call("gantry", [pr.call("gantry"), Rect2(1.2, GIRDER.x, 21.6, 3.2)], w("龙门吊", "GANTRY"),
		w("跨在船坞口上方的 40 吨龙门吊：给废船船尾装推船夹具（拖船推它进船坞时顶的就是这个），小车上的激光头扫描船体。", "The 40 t gantry over the mouth: sets the push frame on a hulk's stern (what the tug bears on to push it in) and its trolley's lidar scans the hull."),
		W.gantry_state(), w("不用操作。看它在做什么就知道船处理到哪一步了。", "Nothing to do; what it does tells you how far the hulk is."))
	for i in 2:
		var bx: float = W.BERTH_X[i]
		add.call("t0%d" % (i + 1), [pr.call("t0%d" % (i + 1)), Rect2(bx - 6.2, W.DECK_Y - 5.6, 12.6, 5.6)], "T-0%d · %s" % [i + 1, TugFleet.NAMES[i] if i < TugFleet.count() else w("空", "FREE")],
			w("自家拖船的泊位：从左墙上部的拖船门飞进来，接上加注臂补推进剂、接上充电线充电，尾部吊舱经甲板舱口换下去检修。", "A company tug's berth: in through the tug gate, the arm refuels it, the umbilical charges it, its aft pod is swapped through the deck hatch."),
			W.berth_state(i),
			w("自家拖船满电待命时，买船拖运只收一半钱，也能接包机单（贸易港或终端）。" if i < TugFleet.count() else "扩建拖船站（终端 → 成长与建设）多一艘拖船。",
				"A charged company tug tows your hulks at half the fee and flies charters." if i < TugFleet.count() else "Build on the tug station (terminal → growth) for another tug."))
	add.call("table", [pr.call("table"), Rect2(TABLE.x, TABLE_TOP - 2.6, TABLE.y - TABLE.x, 3.4)], w("吊舱检修台", "POD SERVICE TABLE"),
		w("拖船回港时升降台把它的旧推进器吊舱换下来放到这里，探头沿喷管扫描检修，修好变成下一次的备用吊舱。", "When a tug comes home the lift swaps its worn thruster pod onto this table; the probe overhauls it into the next spare."),
		W.table_state(), w("不用操作；没有备用吊舱时下一艘回港的拖船要等它修完。", "Nothing to do; with no spare ready the next tug home waits for the overhaul."))
	add.call("tank", [pr.call("tank"), TANK], w("推进剂储罐（MMH）", "PROPELLANT TANK (MMH)"),
		w("存放从废船抽出来的甲基肼，给回港的拖船加注。剧毒易燃。", "Holds the monomethylhydrazine drawn off the hulks and refuels the tugs home. Toxic, flammable."),
		W.tank_state(), w("接包机单时推进剂先从这里扣（每 m³ 抵 %s），不够再花钱。" % Pal.money(TugYard.PROP_PRICE), "A charter's propellant comes out of it first (%s a m³), cash only for the rest." % Pal.money(TugYard.PROP_PRICE)))
	add.call("rack", [RACK], w("备件架", "SPARES RACK"),
		w("拖船换下来的易损件：喷管、缆绳、电池模块、阀件。", "What a tug wears out: nozzle bells, cable, battery modules, valve blocks."),
		[w("电池模块 %d 块 · 喷管 %d 个" % [8 if st >= 2 else 5, 2 if st >= 2 else 1], "%d BATTERY MODULES · %d NOZZLES" % [8 if st >= 2 else 5, 2 if st >= 2 else 1]), "ok" if st >= 1 else "off"],
		w("扩建拖船站后备件更多。", "Building on stocks more."))
	add.call("bins", [BINS], w("零件箱", "PARTS BINS"), w("检修用的小件：阀件、密封圈、紧固件、线束。", "Small parts for the overhauls: valves, seals, bolts, looms."),
		[w("够用", "STOCKED"), "ok" if st >= 1 else "off"], w("不用操作。", "Nothing to do."))
	return out
