class_name BerthView
extends RefCounted
# 91 号（用户 2026-10-27 选“船坞与当前船”）: the terminal's home shows the berth and the ship in
# it as it is right now — a live side section: what is still on the hull (solid), what has gone
# (the ship file's outline, faint), where it is dangerous (orange, breathing), where the money
# is (cyan, the three dearest named down the right). A scan line runs across it; the pointer
# over a marked part names it. Between jobs it shows the next ship coming, or the berth empty.
# Built once when the home screen opens (the game is paused under the terminal), drawn from
# kept arrays every frame.
const FastDraw = preload("res://scripts/fast_draw.gd")   # 60 FPS: the cheap circle / arc / polyline

const LIGHT := Vector2(-0.45, -0.89)

var ok := false
var mode := "empty"            # live | next | empty
var title := ""
var sub := ""
var rate := -1.0
var left := 0                  # pieces still on the hull
var bounds := Rect2()
var tris := PackedVector2Array()
var tri_c := PackedColorArray()
var segs := PackedVector2Array()
var seg_c := PackedColorArray()
var ghost := PackedVector2Array()
var marks: Array = []          # {kind: value|hazard, at: Vector2, poly: PackedVector2Array, name, value}
var hazards := 0
var valuables := 0
var value_sum := 0.0
var _xf := Transform2D.IDENTITY
var hover := -1


func build(game, next_job: Dictionary) -> void:
	ok = true
	tris.clear(); tri_c.clear(); segs.clear(); seg_c.clear(); ghost.clear(); marks.clear()
	hazards = 0
	valuables = 0
	value_sum = 0.0
	var w = game.world if game != null else null
	if w != null and not w.order.is_empty() and not game.belt:
		_build_live(game)
		return
	var ship_id := str(next_job.get("ship", ""))
	if ship_id != "":
		mode = "next"
		var data := Ship.load_data(ship_id)
		title = Ops.w("下一艘：%s", "NEXT: %s") % str(data.get("name", ship_id))
		sub = Ops.w("合同已接，船还没进坞。", "Signed for; not in the berth yet.")
		var b := Rect2()
		var first := true
		for pd in data.get("pieces", []):
			var pts := PackedVector2Array()
			for q in pd.poly:
				pts.append(Vector2(q[0], q[1]) * Geom.M)
			if pts.size() < 3:
				continue
			_outline(ghost, pts)
			var pb := Geom.bbox(pts)
			b = pb if first else b.merge(pb)
			first = false
		bounds = b
		return
	mode = "empty"
	title = Ops.w("船坞空着", "THE BERTH IS EMPTY")
	sub = Ops.w("去「找船」，派拖船拖一艘回来。", "Find a ship and send a tug for it.")
	if Career.usable() and not Career.data.is_empty():
		_build_empty()


func _build_live(game) -> void:
	mode = "live"
	var w = game.world
	title = str(game.ship_title()) if game.has_method("ship_title") else str(game.ship_id)
	rate = float(game.recovery_rate()) if game.has_method("recovery_rate") else -1.0
	var b := Rect2()
	var first := true
	# the ship as it came in, faint: what has gone shows as outline only
	var base := Ship.load_data(str(game.ship_id))
	var wx: Transform2D = w.global_transform
	for pd in base.get("pieces", []):
		var pts := PackedVector2Array()
		for q in pd.poly:
			pts.append(wx * (Vector2(q[0], q[1]) * Geom.M))
		if pts.size() >= 3:
			_outline(ghost, pts)
			var pb := Geom.bbox(pts)
			b = pb if first else b.merge(pb)
			first = false
	var dear: Array = []
	for id in w.order:
		var p = w.pieces[id]
		if p.gone or p.body != null:
			continue
		left += 1
		var poly: PackedVector2Array = w.frame(p) * p.poly
		if poly.size() < 3:
			continue
		var pb := Geom.bbox(poly)
		b = pb if first else b.merge(pb)
		first = false
		var haz: bool = game.sys != null and game.sys.dest_of(p) == "hazard"
		var eq: bool = p.cls == "equip" and p.intact
		var tri := Geometry2D.triangulate_polygon(poly)
		var cc := pb.get_center()
		var rr := maxf(maxf(pb.size.x, pb.size.y) * 0.5, 1.0)
		var f0 := Color(0.11, 0.115, 0.13)
		if eq:
			f0 = Color(0.06, 0.11, 0.135)
		if haz:
			f0 = Color(0.16, 0.085, 0.05)
		for k in tri:
			var lk := clampf((poly[k] - cc).dot(LIGHT) / rr, -1.0, 1.0)
			var g := 1.0 + 0.45 * lk
			tris.append(poly[k])
			tri_c.append(Color(f0.r * g, f0.g * g, f0.b * g))
		var lc := Pal.ink(0.42)
		if eq:
			lc = Color(UiSkin.DATA, 0.85)
		if haz:
			lc = Color(UiSkin.ACCENT, 0.9)
		_outline(segs, poly, seg_c, lc)
		if haz:
			hazards += 1
			marks.append({"kind": "hazard", "at": cc, "poly": poly, "name": Txt.piece_name(p), "value": 0.0})
		elif eq:
			valuables += 1
			var v := float(p.value)
			value_sum += v
			dear.append({"kind": "value", "at": cc, "poly": poly, "name": Txt.piece_name(p), "value": v})
	dear.sort_custom(func(a, c): return a.value > c.value)
	for i in mini(3, dear.size()):
		dear[i]["top"] = i
	marks.append_array(dear)
	bounds = b
	sub = Ops.w("船上还剩 %d 件 · 危险 %d 处 · 值钱的设备 %d 件，共 %s", "%d parts left · %d hazards · %d whole units worth %s") % [left, hazards, valuables, Pal.money(value_sum)]


static func _outline(out: PackedVector2Array, poly: PackedVector2Array, cols = null, c: Color = Color.WHITE) -> void:
	var n := poly.size()
	for i in n:
		out.append(poly[i])
		out.append(poly[(i + 1) % n])
		if cols != null:
			cols.append(c)


# r: where it goes; t: the terminal's clock; a: its fade-in; m: the pointer
func draw(ci: CanvasItem, r: Rect2, t: float, a: float, m: Vector2, font: Font, font_b: Font, font_s: Font) -> void:
	if not ok or a <= 0.0:
		return
	# the panel: a sunk screen with the berth's floor line and its frame
	ci.draw_style_box(UiSkin.box("sunk", a), r)
	var head := Rect2(r.position + Vector2(24, 18), Vector2(r.size.x - 48, 54))
	ci.draw_string(font_s, head.position + Vector2(0, 22), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Pal.ink(0.95 * a))
	ci.draw_string(font, head.position + Vector2(0, 48), sub, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 360, 14, Pal.ink(0.55 * a))
	if rate >= 0.0:
		var bw := 240.0
		var br := Rect2(head.end.x - bw, head.position.y + 34, bw, 4)
		ci.draw_rect(br, Pal.ink(0.08 * a))
		ci.draw_rect(Rect2(br.position, Vector2(bw * clampf(rate, 0.0, 1.0), 4)), Color(UiSkin.ACCENT, 0.95 * a))
		var rs := Ops.w("回收率 %.1f%%", "RECOVERED %.1f%%") % (rate * 100.0)
		var rw := font_b.get_string_size(rs, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		ci.draw_string(font_b, Vector2(head.end.x - rw, head.position.y + 24), rs, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Pal.ink(0.85 * a))
	var view := Rect2(r.position.x + 24, r.position.y + 86, r.size.x - 48 - (230 if mode == "live" else 0), r.size.y - 110)
	# the berth: deck line under the ship, two clamp towers
	var floor_y := view.end.y - 6.0
	if bounds.size.x > 0.0:
		ci.draw_line(Vector2(view.position.x, floor_y), Vector2(view.end.x, floor_y), Pal.ink(0.22 * a), 2.0)
		for k in 28:
			var x := view.position.x + view.size.x * (k + 0.5) / 28.0
			ci.draw_line(Vector2(x, floor_y), Vector2(x - 6, floor_y + 6), Pal.ink(0.1 * a), 1.0)
	if bounds.size.x <= 0.0:
		if mode == "empty" and not facilities.is_empty():
			_draw_empty(ci, view, t, a, font, font_b)
		else:
			ci.draw_string(font, view.get_center() + Vector2(0, 8), Ops.w("— 没有船 —", "— NO SHIP —"), HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Pal.ink(0.3 * a))
		return
	var sc := minf((view.size.x - 20.0) / bounds.size.x, (view.size.y - 30.0) / bounds.size.y)
	var off := Vector2(view.get_center().x, floor_y - 14.0 - bounds.size.y * sc * 0.5) - bounds.get_center() * sc
	_xf = Transform2D(0.0, Vector2(sc, sc), 0.0, off)
	# fades in from the left, like a scan being drawn
	var reveal := clampf(a, 0.0, 1.0)
	ci.draw_set_transform_matrix(_xf)
	var gc := PackedColorArray()
	gc.resize(ghost.size() / 2)
	gc.fill(Pal.ink((0.07 if mode == "live" else 0.4) * reveal))
	if not ghost.is_empty():
		ci.draw_multiline_colors(ghost, gc, -1.0)
	if not tris.is_empty():
		var tc := tri_c
		if reveal < 1.0:
			tc = PackedColorArray()
			for c in tri_c:
				tc.append(Color(c.r, c.g, c.b, reveal))
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), PackedInt32Array(), tris, tc)
	if not segs.is_empty():
		ci.draw_multiline_colors(segs, seg_c, -1.0)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	# the scan line sweeping across
	var sx := view.position.x + view.size.x * fposmod(t / 4.2, 1.0)
	ci.draw_rect(Rect2(sx - 40, view.position.y, 40, view.size.y - 8), Color(UiSkin.DATA, 0.035 * a))
	ci.draw_line(Vector2(sx, view.position.y), Vector2(sx, floor_y - 2), Color(UiSkin.DATA, 0.35 * a), 1.0)
	# the hazards breathe; the dearest units are named down the right
	var mw := _xf.affine_inverse() * m
	hover = -1
	for i in marks.size():
		var mk: Dictionary = marks[i]
		if Geometry2D.is_point_in_polygon(mw, mk.poly):
			hover = i
	var pulse := 0.5 + 0.5 * sin(t * 3.4)
	var col_x := view.end.x + 40.0
	var row := 0
	for i in marks.size():
		var mk: Dictionary = marks[i]
		var p: Vector2 = _xf * mk.at
		if mk.kind == "hazard":
			FastDraw.circle(ci, p, 3.0 + 5.0 * pulse, Color(UiSkin.ACCENT, 0.22 * a * (1.0 - pulse)))
			FastDraw.circle(ci, p, 2.4, Color(UiSkin.ACCENT, 0.95 * a))
		elif mk.has("top"):
			var y := view.position.y + 18.0 + row * 64.0
			row += 1
			# a numbered tag on the unit, the same number by its price in the list
			var num := str(int(mk.top) + 1)
			var ring := 9.0 + 2.0 * sin(t * 2.0 + mk.top)
			FastDraw.circle(ci, p, ring, Color(UiSkin.DATA, 0.12 * a))
			FastDraw.arc(ci, p, ring, 0.0, TAU, 24, Color(UiSkin.DATA, 0.8 * a), 1.2, true)
			ci.draw_string(font_b, p + Vector2(-4, 5), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(UiSkin.DATA, a))
			FastDraw.arc(ci, Vector2(col_x - 14, y - 2), 9.0, 0.0, TAU, 24, Color(UiSkin.DATA, 0.8 * a), 1.2, true)
			ci.draw_string(font_b, Vector2(col_x - 18, y + 3), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(UiSkin.DATA, a))
			ci.draw_string(font_b, Vector2(col_x + 4, y + 4), Pal.money(float(mk.value)), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(UiSkin.DATA, 0.95 * a))
			ci.draw_string(font, Vector2(col_x + 4, y + 26), str(mk.name), HORIZONTAL_ALIGNMENT_LEFT, 196, 13, Pal.ink(0.7 * a))
	if mode == "live" and hazards > 0:
		var y2 := view.position.y + 18.0 + row * 64.0
		FastDraw.circle(ci, Vector2(col_x + 4, y2 - 2), 3.0, Color(UiSkin.ACCENT, 0.95 * a))
		ci.draw_string(font_b, Vector2(col_x + 16, y2 + 4), Ops.w("危险 %d 处", "%d HAZARDS") % hazards, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(UiSkin.ACCENT, 0.95 * a))
		ci.draw_string(font, Vector2(col_x, y2 + 26), Ops.w("先处理，再切", "Make safe before cutting"), HORIZONTAL_ALIGNMENT_LEFT, 200, 13, Pal.ink(0.55 * a))
	if hover >= 0:
		var mk: Dictionary = marks[hover]
		var hi := PackedVector2Array()
		for q in (mk.poly as PackedVector2Array):
			hi.append(_xf * q)
		hi.append(hi[0])
		var hc := Color(UiSkin.ACCENT, a) if mk.kind == "hazard" else Color(UiSkin.DATA, a)
		FastDraw.polyline(ci, hi, hc, 2.0, true)
		var label := str(mk.name) + ("  ·  " + Pal.money(float(mk.value)) if mk.kind == "value" else "  ·  " + Ops.w("危险", "HAZARD"))
		var tw := font_b.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 24.0
		var tr := Rect2(m + Vector2(16, 14), Vector2(tw, 32))
		ci.draw_style_box(UiSkin.box("tag", 0.9 * a), tr)
		ci.draw_string(font_b, tr.position + Vector2(12, 21), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.ink(0.95 * a))


# ---------------------------------------------------------------- the empty berth

# user 2026-10-27 (the home screen with "— 没有船 —" over an empty box): the berth itself, as it
# stands — its floor, boom, tower, floodlights and mouths; what is broken and what is fixed of it;
# and what is waiting in the tug yard or on its way home
var facilities: Array = []      # [name, done, where (m) or Vector2.INF]
var yard: Array = []            # [name, state words, hot]


func _build_empty() -> void:
	facilities.clear()
	yard.clear()
	var where := {"lights": Vector2(Dock.FLOODS[0], Dock.RAIL_Y), "net_fix": Dock.NET, "furnace_main": Dock.zpos("metal") / Geom.M}
	for it in Repair.ITEMS:
		var id: String = it[0]
		if id.begins_with("berth") or id in ["gas_line", "lox_tank"]:
			continue
		facilities.append([Repair.name_of(id), Repair.done(id), where.get(id, Vector2.INF)])
	for a in TugYard.taken():
		var ship := str(a.get("listing", {}).get("offer", {}).get("ship", ""))
		var nm: String = Scan.type_name(ship) if ship != "" else str(a.get("id", ""))
		var st := str(a.get("state", ""))
		var words: String = {"towing": Ops.w("拖运途中", "UNDER TOW"), "arrived": Ops.w("已到港 · 可以开拆", "HOME · READY"), "held": Ops.w("港务扣留", "HELD")}.get(st, st)
		yard.append([nm, words, st == "arrived"])
	var fixed := facilities.filter(func(f): return f[1]).size()
	sub = Ops.w("船坞设施已修 %d / %d · 拖船区 %d 艘", "BERTH %d / %d FIXED · %d IN THE YARD") % [fixed, facilities.size(), yard.size()]


func _draw_empty(ci: CanvasItem, view: Rect2, t: float, a: float, font: Font, font_b: Font) -> void:
	# 107 号 (user 2026-10-29: "优化美工精度"): the berth drawn to scale on a plotting grid — lattice
	# tower and boom, the rail and its trolley, floodlights, the floor slab and trough, the net, the
	# three mouths named; the yard and the facility list in a wider column on the right
	var col_w := 380.0
	var draw_r := Rect2(view.position + Vector2(0, 6), Vector2(view.size.x - col_w - 40.0, view.size.y - 30.0))
	var b := Rect2(Vector2(Dock.TOWER_X - 2.0, Dock.RAIL_Y - 4.0), Vector2(Dock.FLOOR_X1 - Dock.TOWER_X + 4.0, Dock.FLOOR_Y - Dock.RAIL_Y + 7.0))
	var sc := minf(draw_r.size.x / b.size.x, draw_r.size.y / b.size.y)
	var off := draw_r.get_center() - b.get_center() * sc
	var P := func(m: Vector2) -> Vector2: return off + m * sc
	var ink := Pal.ink(0.6 * a)
	var faint := Pal.ink(0.2 * a)
	var lit: bool = Repair.done("lights")
	# the plotting grid, 5 m squares, and the bay's number behind it all
	var g0: Vector2 = P.call(b.position)
	var g1: Vector2 = P.call(b.end)
	var gx := ceilf(b.position.x / 5.0) * 5.0
	while gx < b.end.x:
		var x: float = P.call(Vector2(gx, 0)).x
		ci.draw_line(Vector2(x, g0.y), Vector2(x, g1.y), Pal.ink(0.04 * a), 1.0)
		gx += 5.0
	var gy := ceilf(b.position.y / 5.0) * 5.0
	while gy < b.end.y:
		var y0: float = P.call(Vector2(0, gy)).y
		ci.draw_line(Vector2(g0.x, y0), Vector2(g1.x, y0), Pal.ink(0.04 * a), 1.0)
		gy += 5.0
	var big := (Dock.FLOOR_Y - Dock.RAIL_Y) * sc * 0.7
	var mid: Vector2 = P.call(Vector2((Dock.TOWER_X + Dock.FLOOR_X1) * 0.5, Dock.FLOOR_Y - 2.0))
	ci.draw_string(font_b, mid + Vector2(-big * 0.55, 0), "07", HORIZONTAL_ALIGNMENT_LEFT, -1, int(big), Pal.ink(0.03 * a))
	# the tower: two chords and their lattice
	var top := Dock.RAIL_Y - 3.0
	var tw := 1.4
	for cx0 in [Dock.TOWER_X - tw, Dock.TOWER_X]:
		ci.draw_line(P.call(Vector2(cx0, top)), P.call(Vector2(cx0, Dock.FLOOR_Y)), ink, 2.0)
	var yy := top
	var flip := false
	while yy < Dock.FLOOR_Y - 0.5:
		var y2 := minf(yy + tw, Dock.FLOOR_Y)
		ci.draw_line(P.call(Vector2(Dock.TOWER_X - tw if flip else Dock.TOWER_X, yy)), P.call(Vector2(Dock.TOWER_X if flip else Dock.TOWER_X - tw, y2)), Pal.ink(0.32 * a), 1.0)
		flip = not flip
		yy = y2
	# the boom: a truss girder along the top, the rail hung under it
	var b0 := Dock.RAIL_Y - 3.0
	var b1 := Dock.RAIL_Y - 1.6
	ci.draw_line(P.call(Vector2(Dock.TOWER_X, b0)), P.call(Vector2(Dock.FLOOR_X1, b0)), ink, 2.0)
	ci.draw_line(P.call(Vector2(Dock.TOWER_X, b1)), P.call(Vector2(Dock.FLOOR_X1, b1)), ink, 1.6)
	var bx := Dock.TOWER_X
	flip = false
	while bx < Dock.FLOOR_X1 - 0.5:
		var bx2 := minf(bx + 1.6, Dock.FLOOR_X1)
		ci.draw_line(P.call(Vector2(bx, b1 if flip else b0)), P.call(Vector2(bx2, b0 if flip else b1)), Pal.ink(0.3 * a), 1.0)
		flip = not flip
		bx = bx2
	ci.draw_line(P.call(Vector2(Dock.TOWER_X, Dock.RAIL_Y)), P.call(Vector2(Dock.FLOOR_X1, Dock.RAIL_Y)), Pal.ink(0.45 * a), 1.5)
	var hx := Dock.TOWER_X + 2.0
	while hx < Dock.FLOOR_X1:
		ci.draw_line(P.call(Vector2(hx, b1)), P.call(Vector2(hx, Dock.RAIL_Y)), faint, 1.0)
		hx += 4.0
	# the trolley, parked, its hook block on a short fall
	var tp: Vector2 = P.call(Vector2(Dock.TOWER_X + 6.0, Dock.RAIL_Y))
	ci.draw_rect(Rect2(tp - Vector2(10, 2), Vector2(20, 7)), Pal.ink(0.5 * a))
	ci.draw_line(tp + Vector2(0, 5), tp + Vector2(0, 26), faint, 1.0)
	ci.draw_rect(Rect2(tp + Vector2(-4, 26), Vector2(8, 6)), Pal.ink(0.45 * a))
	# the floodlights: a housing each, a cone if the lighting is fixed, one weak flicker if not
	for i in Dock.FLOODS.size():
		var hp: Vector2 = P.call(Vector2(Dock.FLOODS[i], Dock.RAIL_Y))
		var on := lit or i == 0
		var k := 1.0 if lit else (0.35 + 0.15 * sin(t * 23.0)) * (1.0 if i == 0 else 0.0)
		if on:
			var w := 46.0
			var dh := (Dock.FLOOR_Y - Dock.RAIL_Y) * sc
			ci.draw_polygon(PackedVector2Array([hp + Vector2(-5, 4), hp + Vector2(5, 4), hp + Vector2(w, dh), hp + Vector2(-w, dh)]),
				PackedColorArray([Pal.ink(0.16 * k * a), Pal.ink(0.16 * k * a), Pal.ink(0.0), Pal.ink(0.0)]))
			ci.draw_rect(Rect2(hp + Vector2(-w, dh - 3.0), Vector2(w * 2.0, 3.0)), Pal.ink(0.08 * k * a))
		ci.draw_rect(Rect2(hp - Vector2(7, 1), Vector2(14, 6)), Pal.ink(0.55 * a))
		ci.draw_rect(Rect2(hp + Vector2(-5, 4), Vector2(10, 2)), Pal.ink((0.9 * k + 0.1) * a))
	# the floor: a slab, its hatched section, the trough's basin and the net over the floor's middle
	var f0: Vector2 = P.call(Vector2(Dock.TOWER_X, Dock.FLOOR_Y))
	var f1: Vector2 = P.call(Vector2(Dock.FLOOR_X1, Dock.FLOOR_Y + 1.2))
	var slab := Rect2(f0, f1 - f0)
	ci.draw_rect(slab, Pal.ink(0.07 * a))
	ci.draw_line(slab.position, Vector2(slab.end.x, slab.position.y), ink, 2.5)
	var hx0 := slab.position.x + 4.0
	while hx0 < slab.end.x:
		ci.draw_line(Vector2(hx0, slab.end.y), Vector2(minf(hx0 + slab.size.y, slab.end.x), slab.position.y + 2.0), Pal.ink(0.12 * a), 1.0)
		hx0 += 7.0
	var tr0: Vector2 = P.call(Vector2(Dock.TOWER_X + 2.0, Dock.TROUGH_Y))
	var tr1: Vector2 = P.call(Vector2(Dock.TROUGH_X1, Dock.FLOOR_Y))
	ci.draw_rect(Rect2(tr0, tr1 - tr0), Color(UiSkin.DATA, 0.04 * a))
	ci.draw_line(tr0, Vector2(tr1.x, tr0.y), Color(UiSkin.DATA, 0.25 * a), 1.0)
	var np: Vector2 = P.call(Dock.NET)
	var nr := Rect2(np - Vector2(5.0, 1.0) * sc, Vector2(10.0, 1.0) * sc)
	for q in int(nr.size.x / 6.0):
		ci.draw_line(Vector2(nr.position.x + q * 6.0, nr.position.y), Vector2(nr.position.x + q * 6.0 + 6.0, nr.end.y), Pal.ink(0.25 * a), 1.0)
		ci.draw_line(Vector2(nr.position.x + q * 6.0 + 6.0, nr.position.y), Vector2(nr.position.x + q * 6.0, nr.end.y), Pal.ink(0.25 * a), 1.0)
	# the mouths along the floor, named under the slab
	var mouth_names := {"equip": Ops.w("设备口", "EQUIP"), "metal": Ops.w("金属口", "METAL"), "hazard": Ops.w("危险品口", "HAZARD")}
	for id in ["equip", "metal", "hazard"]:
		var mp: Vector2 = P.call(Dock.zpos(id) / Geom.M)
		var mc := Color(UiSkin.ACCENT) if id == "hazard" else Color(UiSkin.DATA)
		ci.draw_rect(Rect2(mp - Vector2(15, 4), Vector2(30, 8)), Color(mc, 0.22 * a))
		ci.draw_rect(Rect2(mp - Vector2(15, 4), Vector2(30, 8)), Color(mc, 0.85 * a), false, 1.0)
		ci.draw_line(mp + Vector2(-9, 0), mp + Vector2(9, 0), Color(mc, (0.4 + 0.3 * sin(t * 2.0 + mp.x)) * a), 2.0)
		ci.draw_string(font_b, Vector2(mp.x - 40, slab.end.y + 16), str(mouth_names[id]), HORIZONTAL_ALIGNMENT_CENTER, 80, 12, Color(mc, 0.8 * a))
	# the facilities: a tag on the berth where it is, broken in the accent (breathing), fixed in ink
	var listed := 0
	for f in facilities:
		var at: Vector2 = f[2]
		if at == Vector2.INF:
			continue
		var p: Vector2 = P.call(at)
		var col := Pal.ink(0.85 * a) if f[1] else Color(UiSkin.ACCENT, (0.75 + 0.25 * sin(t * 4.0 + listed)) * a)
		if not f[1]:
			FastDraw.circle(ci, p, 6.0 + 3.0 * (0.5 + 0.5 * sin(t * 3.0 + listed)), Color(UiSkin.ACCENT, 0.18 * a))
		FastDraw.circle(ci, p, 3.5, col)
		var lab := str(f[0]) + ("  ✓" if f[1] else "  " + Ops.w("待修", "BROKEN"))
		var lw := font_b.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 16.0
		var lp := p + Vector2(20, -30 - listed * 4.0)
		ci.draw_line(p, lp + Vector2(0, 10), Color(col.r, col.g, col.b, 0.6 * a), 1.0)
		ci.draw_rect(Rect2(lp, Vector2(lw, 20)), Color(0.03, 0.035, 0.04, 0.9 * a))
		ci.draw_rect(Rect2(lp, Vector2(2, 20)), col)
		ci.draw_string(font_b, lp + Vector2(9, 15), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)
		listed += 1
	# the scan line
	var sx := draw_r.position.x + draw_r.size.x * fposmod(t / 4.2, 1.0)
	ci.draw_rect(Rect2(sx - 40, draw_r.position.y, 40, draw_r.size.y), Color(UiSkin.DATA, 0.03 * a))
	ci.draw_line(Vector2(sx, draw_r.position.y), Vector2(sx, draw_r.end.y), Color(UiSkin.DATA, 0.25 * a), 1.0)
	# the right column: what waits in the tug yard, then the berth's list in two columns
	var cx := view.end.x - col_w
	ci.draw_line(Vector2(cx - 24, view.position.y), Vector2(cx - 24, view.end.y - 6), Pal.ink(0.08 * a), 1.0)
	var y := view.position.y + 16.0
	ci.draw_string(font_b, Vector2(cx, y), Ops.w("拖船区", "TUG YARD"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.ink(0.55 * a))
	y += 28.0
	if yard.is_empty():
		ci.draw_string(font, Vector2(cx, y), Ops.w("空着——去「找船」派拖船", "EMPTY — FIND A SHIP"), HORIZONTAL_ALIGNMENT_LEFT, col_w, 17, Pal.ink(0.75 * a))
		y += 30.0
	for e in yard:
		var ex := cx + (16.0 if e[2] else 0.0)
		if e[2]:
			FastDraw.circle(ci, Vector2(cx + 5, y - 6), 4.0, Color(UiSkin.ACCENT, (0.7 + 0.3 * sin(t * 4.0)) * a))
		ci.draw_string(font_b, Vector2(ex, y), str(e[0]), HORIZONTAL_ALIGNMENT_LEFT, col_w, 20, Pal.ink(0.95 * a))
		ci.draw_string(font, Vector2(ex, y + 22.0), str(e[1]), HORIZONTAL_ALIGNMENT_LEFT, col_w, 15, Color(UiSkin.ACCENT, a) if e[2] else Pal.ink(0.55 * a))
		y += 52.0
	y += 8.0
	var fixed := facilities.filter(func(f): return f[1]).size()
	ci.draw_string(font_b, Vector2(cx, y), Ops.w("船坞设施 · 已修 %d / %d", "BERTH · %d / %d FIXED") % [fixed, facilities.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.ink(0.55 * a))
	y += 8.0
	var bar := Rect2(cx, y, col_w - 20.0, 3.0)
	ci.draw_rect(bar, Pal.ink(0.1 * a))
	ci.draw_rect(Rect2(bar.position, Vector2(bar.size.x * fixed / maxf(1.0, facilities.size()), 3.0)), Color(UiSkin.DATA, 0.8 * a))
	y += 26.0
	var half := (col_w - 20.0) * 0.5
	var rows := int(ceil(facilities.size() / 2.0))
	var lh := clampf((view.end.y - 8.0 - y) / maxf(1.0, rows), 18.0, 26.0)
	for i in facilities.size():
		var f: Array = facilities[i]
		var fy := y + (i % rows) * lh
		if fy > view.end.y - 4.0:
			continue
		var fx := cx + (i / rows) * half
		var c2 := Pal.ink(0.72 * a) if f[1] else Color(UiSkin.ACCENT, 0.92 * a)
		ci.draw_string(font, Vector2(fx, fy), ("✓ " if f[1] else "· ") + str(f[0]), HORIZONTAL_ALIGNMENT_LEFT, half - 8.0, 15, c2)
