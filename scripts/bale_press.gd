extends RefCounted
# 128 号 第 4 段 打包压块机 (缝自《深空压机》; 2026-11-07 问答定案 ③④): a vertical downstroke baler on the
# processing district's floor under the baghouse (方案 A 改). What the warehouse sends comes down the drop
# pipe from the freight spur's deck onto the feed belt; the pressure probe on its swing arm touches every piece before the
# chute — a vessel still holding gas or liquid lights the red lamp and the belt runs it back out (never
# into the box); anything else drops down the chute into the box, the feed door shuts, the platen comes
# down on its cylinder and crushes it — the thing's own lines squeezed flat, buckling as it goes — the
# straps go round, the discharge door lifts, the ejector pushes the bale out onto the rollers and down
# the hatch to the warehouse. Runs from ProcessLine.press_phase() (real time, seen or not); drawn in the
# district's front layer (scripts/process_art.gd). Box-local metres, floor at 26.8.

const FLOOR := 26.8
const COL_L := 32.15              # the frame's columns
const COL_R := 36.05
const HEAD := Rect2(31.8, 19.9, 4.6, 0.6)     # the crosshead, under the baghouse
const CYL := Rect2(33.4, 20.5, 1.4, 1.6)      # the main cylinder
const BOX := Rect2(32.7, 23.0, 2.8, 3.4)      # the box (chamber), inside
const PLATEN_UP := 22.6                       # the platen's face, up
const BELT_Y := 22.6                          # the feed belt's top at its tail, by the chute
const BELT := Vector2(36.6, 39.5)             # its tail at the chute, its head under the drop pipe
const HEAD_Y := 20.9                          # the belt's top at its head (it runs down to the chute)
const PORT := Rect2(39.05, 16.25, 0.9, 4.15)  # the drop pipe from the freight spur's deck
const PROBE := Vector2(37.3, 19.0)            # the probe arm's pivot, hung from the spur's deck
const ROLL := Vector2(35.8, 38.4)             # the bale's roller table
const ROLL_Y := 26.25
const HATCH_X := 38.6                         # the hatch down to the warehouse's line
const IRON := Color(0.105, 0.108, 0.118)
const IRON_HI := Color(0.15, 0.152, 0.162)
const DARK := Color(0.06, 0.064, 0.072)
const YEL := Color(0.85, 0.62, 0.2)

static var belt_run := 0.0       # m the belt has run (its cleats), + toward its head (east)
static var belt_v := 0.0         # m/s its surface moves now, + east (tests: tests/belt_direction_check.gd)
static var _bx := NAN            # the bale's x on the belt last step
static var platen := 0.0         # 0 up … 1 at the bale
static var _seed_parts := {}     # job id -> crumple seeds


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


# the belt's top at x: it climbs from the port up to the chute
static func belt_y(x: float) -> float:
	return lerpf(BELT_Y, HEAD_Y, clampf((x - BELT.x) / (BELT.y - BELT.x), 0.0, 1.0))


static func belt_ang() -> float:
	return atan2(BELT_Y - HEAD_Y, BELT.x - BELT.y) + PI


const PROBE_X := 38.0                         # where on the belt the probe touches


static func e_io(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 4.0 * x * x * x if x < 0.5 else 1.0 - pow(-2.0 * x + 2.0, 3.0) / 2.0


# the bale's height in the box: the more it weighs, the taller (draft)
static func bale_h(mass: float) -> float:
	return clampf(0.55 + mass * 0.22, 0.6, 1.3)


# the thing's look as it lies on the belt: [size m, lk] (lk {} for loose raw goods)
static func _look(cur: Dictionary) -> Array:
	var lk: Dictionary = cur.get("look", {})
	if str(lk.get("cat", "")) == "raw" or str(lk.get("key", "")) != "":
		return [Vector2(1.8, 0.8), {}]
	var l := StoreBook.look_any(str(lk.get("ship", "")), str(lk.get("tag", "")), str(lk.get("nk", "")))
	if l.is_empty():
		var s := clampf(0.6 + float(cur.get("mass", 0.5)) * 0.5, 0.8, 2.2)
		return [Vector2(s, s * 0.8), {}]
	var sz: Vector2 = l.size
	var k := minf(1.9 / maxf(sz.x, 0.1), 1.9 / maxf(sz.y, 0.1))
	return [sz * clampf(k, 0.2, 1.4), l]


# where the thing is and how it is squeezed now: {at (bottom-centre, m), size, sx, sy, rot, shown}
static func _pose(cur: Dictionary, ph: String, u: float) -> Dictionary:
	var lk := _look(cur)
	var sz: Vector2 = lk[0]
	var out := {"size": sz, "sx": 1.0, "sy": 1.0, "rot": belt_ang(), "shown": true, "at": Vector2(BELT.y - 1.0, belt_y(BELT.y - 1.0)), "crush": 0.0}
	var chute_x := BELT.x + 0.4
	match ph:
		"feed":
			# along the belt (the probe passes it), then over the end and down the chute into the box
			var a := clampf(u / 0.72, 0.0, 1.0)
			if u < 0.72:
				var bx := lerpf(BELT.y - sz.x * 0.5 - 0.2, chute_x + sz.x * 0.3, e_io(a))
				out.at = Vector2(bx, belt_y(bx))
			else:
				var f := (u - 0.72) / 0.28
				var drop := f * f
				out.at = Vector2(lerpf(chute_x + sz.x * 0.3, BOX.get_center().x, f), lerpf(BELT_Y, BOX.end.y, drop))
				out.rot = lerpf(belt_ang(), 0.0, f) - 0.5 * sin(f * PI)
		"approach":
			var ax := lerpf(BELT.y - sz.x * 0.5 - 0.2, PROBE_X, e_io(u))
			out.at = Vector2(ax, belt_y(ax))
		"probe":
			out.at = Vector2(PROBE_X, belt_y(PROBE_X))
		"reject":
			var rx := lerpf(PROBE_X, BELT.y + sz.x * 0.6, e_io(u))
			out.at = Vector2(rx, belt_y(rx))
			out.shown = u < 0.96
		"close":
			out.at = Vector2(BOX.get_center().x, BOX.end.y)
			out.rot = 0.0
		"press", "tie", "eject":
			out.at = Vector2(BOX.get_center().x, BOX.end.y)
			out.rot = 0.0
			var hb := bale_h(float(cur.mass))
			var c := 1.0 if ph != "press" else clampf((u - 0.1) / 0.85, 0.0, 1.0)
			out.crush = c
			# fitted to the box's width, flattened to the bale's height
			var fit_x := (BOX.size.x - 0.08) / maxf(sz.x, 0.1)
			out.sx = lerpf(minf(1.0, fit_x), fit_x, c)
			out.sy = lerpf(1.0, hb / maxf(sz.y, 0.1), c)
			if ph == "eject":
				var p := clampf((u - 0.3) / 0.7, 0.0, 1.0)
				out.at = Vector2(lerpf(BOX.get_center().x, HATCH_X + 0.6, e_io(p)), ROLL_Y if p > 0.15 else lerpf(BOX.end.y, ROLL_Y, p / 0.15))
				out.shown = p < 0.97
	return out


static func tick(dt: float) -> void:
	var ph: Array = ProcessLine.press_phase()
	var st := str(ph[0])
	var u := float(ph[1])
	# 传送带方向 (user 2026-11-10): the belt carried the bale down to the chute (−x) while its cleats ran up
	# (+x), and the other way round on a reject. Now the belt's surface moves exactly as the bale on it
	# does: the same way, the same distance, no sliding (the cleats are spaced along x: draw)
	var pr := ProcessLine.press()
	var cur: Dictionary = pr.get("cur", {}) if not pr.is_empty() else {}
	var on_belt: bool = not cur.is_empty() and ((st == "feed" and u < 0.72) or st == "approach" or st == "reject")
	belt_v = 0.0
	if on_belt:
		var x := float((_pose(cur, st, u).at as Vector2).x)
		if not is_nan(_bx):
			belt_run += x - _bx
			belt_v = (x - _bx) / maxf(dt, 1e-4)
		_bx = x
	else:
		_bx = NAN
	var want := 0.0
	match st:
		"press": want = clampf((u - 0.05) / 0.85, 0.0, 1.0)
		"tie": want = 1.0
		"eject": want = 1.0 - clampf(u / 0.3, 0.0, 1.0)
	platen = move_toward(platen, want, dt * 1.6)


# ================================================================== drawing
static func draw(ci: CanvasItem, a, t: float, lod: int) -> void:
	var m: float = a.m
	var lw := maxf(1.0, 0.035 * m)
	var P := func(v: Vector2) -> Vector2: return a._p(v)
	var pr := ProcessLine.press()
	var cur: Dictionary = pr.get("cur", {}) if not pr.is_empty() else {}
	var ph: Array = ProcessLine.press_phase() if not pr.is_empty() else ["idle", 0.0]
	var st := str(ph[0])
	var u := float(ph[1])
	var ink := Pal.ink(0.6)
	# ---- the hydraulic power unit: tank, motor, pump, accumulator; its hoses up to the cylinder
	# the power unit is in the basement: its two hoses come up through a floor gland to the cylinder
	var hose := Color(0.12, 0.12, 0.13)
	for k in 2:
		var pts := PackedVector2Array()
		var from := Vector2(COL_L - 0.6 + k * 0.22, FLOOR)
		var to := Vector2(CYL.position.x, CYL.position.y + 0.4 + k * 0.8)
		for q in 9:
			var f := q / 8.0
			pts.append(P.call(from.lerp(to, f) + Vector2(-0.35 * sin(f * PI), 0.0)))
		ci.draw_polyline(pts, hose, maxf(1.0, 0.09 * m))
	_box(ci, P, m, Rect2(COL_L - 0.85, FLOOR - 0.18, 0.7, 0.18), DARK, lw)
	var gauge := Vector2(COL_L - 0.5, FLOOR - 0.75)
	ci.draw_circle(P.call(gauge), 0.16 * m, Color(0.03, 0.035, 0.04))
	ci.draw_arc(P.call(gauge), 0.16 * m, 0.0, TAU, 12, ink, lw)
	var load := 0.9 if st == "press" else (0.4 if st in ["close", "tie", "eject"] else 0.08)
	ci.draw_line(P.call(gauge), P.call(gauge + Vector2.from_angle(PI * 0.75 + PI * 1.5 * load) * 0.13), Pal.heat(0.9, 1.3), lw)
	# ---- the box: its back plate, behind the platen and the content (a cut-away inspection side)
	ci.draw_rect(Rect2(P.call(BOX.position), BOX.size * m), Color(0.035, 0.037, 0.042))
	var y := BOX.position.y + 0.6
	while y < BOX.end.y:
		ci.draw_line(P.call(Vector2(BOX.position.x, y)), P.call(Vector2(BOX.end.x, y)), Pal.ink(0.06), lw)
		y += 0.6
	# ---- the frame: columns, crosshead, the main cylinder and its rod, the platen on its guides
	for cx in [COL_L, COL_R]:
		_box(ci, P, m, Rect2(cx - 0.18, HEAD.end.y, 0.36, FLOOR - HEAD.end.y), IRON_HI, lw)
		ci.draw_line(P.call(Vector2(cx, HEAD.end.y + 0.2)), P.call(Vector2(cx, FLOOR - 0.2)), Pal.ink(0.12), lw)
	_box(ci, P, m, HEAD, IRON_HI, lw)
	for bx in [HEAD.position.x + 0.25, HEAD.end.x - 0.25]:
		ci.draw_circle(P.call(Vector2(bx, HEAD.get_center().y)), 0.07 * m, Pal.ink(0.5))
	_box(ci, P, m, CYL, Color(0.18, 0.19, 0.21), lw)
	ci.draw_rect(Rect2(P.call(CYL.position + Vector2(0.1, 0.0)), Vector2(0.18, CYL.size.y) * m), Color(1, 1, 1, 0.06))
	var hb := bale_h(float(cur.get("mass", 1.0))) if not cur.is_empty() else 1.0
	var face := lerpf(PLATEN_UP, BOX.end.y - hb, platen)
	ci.draw_rect(Rect2(P.call(Vector2(CYL.get_center().x - 0.28, CYL.end.y)), Vector2(0.56, face - 0.5 - CYL.end.y) * m), Color(0.7, 0.72, 0.76))
	ci.draw_line(P.call(Vector2(CYL.get_center().x - 0.16, CYL.end.y)), P.call(Vector2(CYL.get_center().x - 0.16, face - 0.5)), Color(1, 1, 1, 0.5), lw)
	var plat := Rect2(Vector2(BOX.position.x + 0.04, face - 0.5), Vector2(BOX.size.x - 0.08, 0.5))
	_box(ci, P, m, plat, YEL, lw)
	ci.draw_line(P.call(plat.position + Vector2(0.0, 0.12)), P.call(plat.position + Vector2(plat.size.x, 0.12)), Color(0.1, 0.1, 0.1, 0.5), lw)
	# the thing being pressed (or riding the belt)
	if not cur.is_empty() and st != "idle":
		_thing(ci, a, cur, st, u, t, lw)
	# the box's walls, the feed door on the right, the discharge door at the bottom right
	for wx in [BOX.position.x - 0.18, BOX.end.x]:
		_box(ci, P, m, Rect2(wx, BOX.position.y, 0.18, BOX.size.y), IRON, lw)
	_box(ci, P, m, Rect2(BOX.position.x - 0.18, BOX.end.y, BOX.size.x + 0.36, 0.4), IRON, lw)
	for k in 5:
		var ry := BOX.position.y + 0.5 + k * 1.1
		for wx2 in [BOX.position.x - 0.26, BOX.end.x + 0.08]:
			ci.draw_rect(Rect2(P.call(Vector2(wx2, ry)), Vector2(0.18, 0.26) * m), IRON_HI)
	var feed_open := 1.0
	match st:
		"close": feed_open = 1.0 - u
		"press", "tie": feed_open = 0.0
		"eject": feed_open = clampf((u - 0.8) / 0.2, 0.0, 1.0)
	var door := Rect2(Vector2(BOX.end.x + 0.18, BOX.position.y + 0.1 + 1.3 * (1.0 - feed_open)), Vector2(0.14, 1.3))
	_box(ci, P, m, Rect2(door.position.x, BOX.position.y - 1.5, 0.14, door.position.y - BOX.position.y + 1.5), DARK, lw)
	_box(ci, P, m, door, YEL if feed_open < 0.99 else IRON_HI, lw)
	var dis := 0.0
	if st == "eject":
		dis = clampf(u / 0.25, 0.0, 1.0) * (1.0 - clampf((u - 0.85) / 0.15, 0.0, 1.0))
	_box(ci, P, m, Rect2(Vector2(BOX.end.x - 0.02, BOX.end.y - 1.5 - 1.4 * dis), Vector2(0.24, 1.5)), YEL, lw)
	# the ejector's cylinder on the left, its plate pushing the bale out
	var ej := 0.0
	if st == "eject":
		ej = clampf((u - 0.25) / 0.45, 0.0, 1.0) * (1.0 - clampf((u - 0.75) / 0.25, 0.0, 1.0))
	_box(ci, P, m, Rect2(BOX.position.x - 1.8, BOX.end.y - 0.85, 1.3, 0.6), Color(0.18, 0.19, 0.21), lw)
	ci.draw_rect(Rect2(P.call(Vector2(BOX.position.x - 0.5, BOX.end.y - 0.65)), Vector2(0.4 + 2.6 * ej, 0.2) * m), Color(0.7, 0.72, 0.76))
	_box(ci, P, m, Rect2(Vector2(BOX.position.x - 0.1 + 2.6 * ej, BOX.end.y - 1.2), Vector2(0.14, 1.15)), YEL, lw)
	# the plate on the box (its words only where the machines carry names)
	if Pal.labels:
		_box(ci, P, m, Rect2(BOX.position.x + 0.4, BOX.position.y - 1.1, 2.0, 0.5), DARK, lw)
		a._text(ci, Vector2(BOX.position.x + 0.5, BOX.position.y - 0.72), w("打包压块机 BP-1", "BALER BP-1"), 0.26, Pal.ink(0.6))
	# ---- the feed belt from the wall port: frame, legs, the belt's cleats, the chute
	# the drop pipe: a square duct down from the spur's deck, its flanges, the slide gate, a lit mouth
	_box(ci, P, m, PORT, IRON, lw)
	ci.draw_rect(Rect2(P.call(PORT.position + Vector2(0.18, 0.0)), Vector2(PORT.size.x - 0.36, PORT.size.y) * m), Color(0.02, 0.022, 0.026))
	var fy := PORT.position.y + 0.8
	while fy < PORT.end.y - 0.3:
		_box(ci, P, m, Rect2(PORT.position.x - 0.08, fy, PORT.size.x + 0.16, 0.14), IRON_HI, lw)
		fy += 1.2
	var gate := 1.0 if st in ["feed", "approach"] and u < 0.3 else 0.0
	_box(ci, P, m, Rect2(PORT.position.x - 0.35 + 0.3 * gate, PORT.end.y - 0.3, PORT.size.x + 0.1, 0.12), YEL, lw)
	ci.draw_rect(Rect2(P.call(Vector2(PORT.position.x, PORT.end.y - 0.08)), Vector2(PORT.size.x, 0.08) * m), Pal.heat(0.6, 0.9))
	if Pal.labels and lod > 0:
		a._text(ci, PORT.position + Vector2(1.1, 0.8), w("仓库来料", "FROM STORES"), 0.3, Pal.ink(0.55))
	# an inclined belt: its side frame, the return strand, the cleats, the legs, the drums
	var t0 := Vector2(BELT.x, BELT_Y)
	var t1 := Vector2(BELT.y, HEAD_Y)
	var band := PackedVector2Array([P.call(t0), P.call(t1), P.call(t1 + Vector2(0, 0.42)), P.call(t0 + Vector2(0, 0.42))])
	ci.draw_colored_polygon(band, Color(0.09, 0.094, 0.104))
	ci.draw_line(P.call(t0), P.call(t1), Pal.ink(0.6), lw)
	ci.draw_line(P.call(t0 + Vector2(0, 0.42)), P.call(t1 + Vector2(0, 0.42)), Pal.ink(0.3), lw)
	var cx2 := BELT.x + fposmod(belt_run, 0.7)
	while cx2 < BELT.y:
		ci.draw_line(P.call(Vector2(cx2, belt_y(cx2))), P.call(Vector2(cx2, belt_y(cx2) - 0.12)), Pal.ink(0.45), lw)
		ci.draw_line(P.call(Vector2(cx2, belt_y(cx2) + 0.08)), P.call(Vector2(cx2, belt_y(cx2) + 0.34)), Pal.ink(0.12), lw)
		cx2 += 0.7
	for lx in [37.4, 39.0]:
		ci.draw_line(P.call(Vector2(lx, belt_y(lx) + 0.42)), P.call(Vector2(lx, ROLL_Y - 0.05)), Pal.ink(0.3), maxf(1.0, 0.07 * m))
	for ex in [BELT.x + 0.2, BELT.y - 0.2]:
		var dc := Vector2(ex, belt_y(ex) + 0.21)
		ci.draw_circle(P.call(dc), 0.2 * m, IRON_HI)
		ci.draw_arc(P.call(dc), 0.2 * m, 0.0, TAU, 12, ink, lw)
		ci.draw_line(P.call(dc), P.call(dc + Vector2.from_angle(belt_run / 0.2) * 0.18), ink, lw)
	# the belt's drive at the head: a geared motor
	_box(ci, P, m, Rect2(BELT.y - 0.75, HEAD_Y + 0.55, 0.7, 0.5), Color(0.2, 0.22, 0.26), lw)
	var chute := PackedVector2Array([P.call(Vector2(BELT.x + 0.3, BELT_Y - 0.05)), P.call(Vector2(BELT.x + 0.3, BELT_Y + 0.4)), P.call(Vector2(BOX.end.x + 0.32, BOX.position.y + 0.6)), P.call(Vector2(BOX.end.x + 0.32, BOX.position.y + 0.2))])
	ci.draw_colored_polygon(chute, DARK)
	chute.append(chute[0])
	ci.draw_polyline(chute, ink, lw)
	# ---- the pressure probe: a swing arm with a needle tip, a lamp and a small screen
	var arm := 0.0
	if st == "feed" and u > 0.25 and u < 0.45:
		arm = sin((u - 0.25) / 0.2 * PI)
	elif st == "approach":
		arm = clampf((u - 0.75) / 0.25, 0.0, 1.0)
	elif st == "probe":
		arm = 1.0
	elif st == "reject":
		arm = 1.0 - clampf(u / 0.2, 0.0, 1.0)
	var touch := Vector2(PROBE_X, belt_y(PROBE_X) - 0.75)
	var reach := PROBE.distance_to(touch)
	var tip := PROBE + Vector2.from_angle(lerpf(-0.6, (touch - PROBE).angle(), arm)) * reach
	_box(ci, P, m, Rect2(PROBE - Vector2(0.4, 0.4), Vector2(0.8, 0.8)), IRON_HI, lw)
	ci.draw_line(P.call(PROBE), P.call(tip), Color(0.62, 0.64, 0.68), maxf(1.0, 0.09 * m))
	ci.draw_circle(P.call(tip), 0.08 * m, Pal.ink(0.8))
	var bad: bool = st in ["probe", "reject"] and cur.get("charged", false)
	var lamp := PROBE + Vector2(0.75, 0.15)
	ci.draw_circle(P.call(lamp), 0.2 * m, Color(1.0, 0.25, 0.2, 0.9 if fmod(t, 0.5) < 0.3 else 0.35) if bad else (Pal.tint(Pal.FLUID, 0.9, 1.3) if st == "feed" and arm > 0.5 else Pal.ink(0.2)))
	ci.draw_line(P.call(PROBE + Vector2(0.0, -0.4)), P.call(Vector2(PROBE.x, 16.25)), Pal.ink(0.3), maxf(1.0, 0.06 * m))
	var scr := Rect2(PROBE + Vector2(-0.55, -2.25), Vector2(2.2, 1.35))
	_box(ci, P, m, scr, Color(0.04, 0.12, 0.13), lw)
	var line1 := w("压力探头", "PRESSURE PROBE")
	var line2 := w("待料", "IDLE")
	if bad:
		line1 = w("有压力 · 拒收", "PRESSURE · REJECTED")
		line2 = str(cur.get("held", ""))
	elif st == "feed" and arm > 0.2:
		line2 = w("0 kPa · 放行", "0 kPa · CLEAR")
	elif st in ["close", "press", "tie", "eject"]:
		line2 = w("压制中", "PRESSING") if st == "press" else w("放行", "CLEAR")
	if bad:
		ci.draw_rect(Rect2(P.call(scr.position), scr.size * m), Color(0.6, 0.08, 0.05, 0.35 + 0.2 * sin(t * 9.0)))
	a._text(ci, scr.position + Vector2(0.12, 0.52), line1, 0.3, Color(1.0, 0.45, 0.4) if bad else Pal.tint(Pal.AIR, 0.85, 1.3))
	a._text(ci, scr.position + Vector2(0.12, 1.1), line2, 0.28, Color(1.0, 0.6, 0.55) if bad else Pal.tint(Pal.AIR, 0.7, 1.2))
	# ---- the roller table and the hatch to the warehouse's line
	ci.draw_rect(Rect2(P.call(Vector2(ROLL.x, ROLL_Y)), Vector2(ROLL.y - ROLL.x, 0.25) * m), Color(0.08, 0.083, 0.094))
	var rx := ROLL.x + 0.2
	while rx < ROLL.y:
		ci.draw_circle(P.call(Vector2(rx, ROLL_Y + 0.12)), 0.1 * m, IRON_HI)
		ci.draw_arc(P.call(Vector2(rx, ROLL_Y + 0.12)), 0.1 * m, 0.0, TAU, 8, Pal.ink(0.4), lw)
		rx += 0.4
	_box(ci, P, m, Rect2(HATCH_X - 0.1, ROLL_Y - 0.1, 1.4, 0.65), DARK, lw)
	ci.draw_rect(Rect2(P.call(Vector2(HATCH_X, ROLL_Y + 0.1)), Vector2(1.2, 0.08) * m), Pal.heat(0.6, 0.9))
	if Pal.labels and lod > 0:
		a._text(ci, Vector2(HATCH_X - 0.05, ROLL_Y + 0.5), w("→ 回仓库", "→ TO STORES"), 0.24, Pal.ink(0.45))


static func _box(ci: CanvasItem, P: Callable, m: float, r: Rect2, fill: Color, lw: float) -> void:
	ci.draw_rect(Rect2(P.call(r.position), r.size * m), fill)
	ci.draw_rect(Rect2(P.call(r.position), r.size * m), Pal.ink(0.5), false, lw)


# the thing: its own outline and lines, squeezed; the crumple's creases and the straps over it
static func _thing(ci: CanvasItem, a, cur: Dictionary, st: String, u: float, t: float, lw: float) -> void:
	var m: float = a.m
	var pose := _pose(cur, st, u)
	if not pose.shown:
		return
	var lk := _look(cur)
	var sz: Vector2 = pose.size
	var sx := float(pose.sx)
	var sy := float(pose.sy)
	var crush := float(pose.crush)
	var at: Vector2 = pose.at
	# local: the thing's top-left at (-w/2, -h), scaled about its bottom-centre
	var xf := Transform2D(float(pose.rot), Vector2(sx * m, sy * m), 0.0, a._p(at))
	ci.draw_set_transform_matrix(xf)
	var l: Dictionary = lk[1]
	var col := Color(0.14, 0.145, 0.16)
	if l.is_empty():
		# loose goods: a heap of scrap bits
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(str(cur.get("id", "")))
		var pts := PackedVector2Array([Vector2(-sz.x * 0.5, 0.0)])
		for k in 11:
			pts.append(Vector2(-sz.x * 0.5 + sz.x * (k + 0.5) / 11.0, -sz.y * rng.randf_range(0.55, 1.0)))
		pts.append(Vector2(sz.x * 0.5, 0.0))
		ci.draw_colored_polygon(pts, Color(0.26, 0.25, 0.23))
		for k in 10:
			var p0 := Vector2(rng.randf_range(-0.45, 0.45) * sz.x, -rng.randf_range(0.1, 0.7) * sz.y)
			ci.draw_line(p0, p0 + Vector2.from_angle(rng.randf_range(0.0, TAU)) * 0.35, Color(0.45, 0.43, 0.4), 0.05)
	else:
		var asz: Vector2 = l.size
		var k2 := sz.x / maxf(asz.x, 0.01)
		# the outline buckles: each vertex pushed in or out a little more as it crushes
		var poly: PackedVector2Array = l.poly
		var pts2 := PackedVector2Array()
		var i := 0
		for q in poly:
			var v: Vector2 = q * k2 - Vector2(sz.x * 0.5, sz.y)
			v += Vector2(sin(i * 2.7) * 0.12, cos(i * 1.9) * 0.08) * crush
			pts2.append(v)
			i += 1
		if pts2.size() >= 3:
			ci.draw_colored_polygon(pts2, col)
			pts2.append(pts2[0])
			ci.draw_polyline(pts2, Pal.ink(0.75), 0.04 / maxf(sx, 0.2))
		if str(l.art) != "":
			ci.draw_set_transform_matrix(xf * Transform2D(0.0, Vector2(k2 / Geom.M, k2 / Geom.M), 0.0, -Vector2(sz.x * 0.5, sz.y)))
			Art.draw(ci, str(l.art), asz * Geom.M, null, Fonts.get_font("Regular"))
			ci.draw_set_transform_matrix(xf)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	if crush > 0.05:
		# the crushed block: dense creases where the metal folded, the edges ragged
		var hb := sz.y * sy
		var wb := sz.x * sx
		var r := Rect2(a._p(at - Vector2(wb * 0.5, hb)), Vector2(wb, hb) * m)
		ci.draw_rect(r, Color(0.2, 0.2, 0.21, 0.4 * crush * crush))
		var rng2 := RandomNumberGenerator.new()
		rng2.seed = hash(str(cur.get("id", ""))) + 3
		for k in int(10 + 22 * crush):
			var p1 := r.position + Vector2(rng2.randf() * r.size.x, rng2.randf() * r.size.y)
			var d := Vector2.from_angle(rng2.randf_range(-0.6, 0.6)) * rng2.randf_range(0.2, 0.7) * m
			ci.draw_line(p1, p1 + d, Pal.ink(0.32 * crush), lw)
		ci.draw_rect(r, Pal.ink(0.6 * crush), false, lw)
		# the straps: three bands going round once it is pressed
		var strap := 0.0
		if st == "tie":
			strap = u
		elif st == "eject":
			strap = 1.0
		for k in 3:
			var sxk := r.position.x + r.size.x * (0.2 + 0.3 * k)
			var len := clampf(strap * 3.0 - k, 0.0, 1.0)
			if len > 0.0:
				ci.draw_line(Vector2(sxk, r.position.y), Vector2(sxk, r.position.y + r.size.y * len), Color(0.75, 0.75, 0.8), maxf(1.0, 0.05 * m))
	# the dust and the sparks of the crush
	if st == "press" and crush > 0.05 and crush < 0.98:
		var base: Vector2 = a._p(at)
		for k in 6:
			var ph := fposmod(t * 2.3 + k * 0.17, 1.0)
			var side := -1.0 if k % 2 == 0 else 1.0
			var p2 := base + Vector2(side * (BOX.size.x * 0.45 + ph * 0.8) * m, -(0.3 + ph * 0.9) * m)
			ci.draw_circle(p2, (0.06 + 0.12 * ph) * m, Color(0.45, 0.43, 0.4, 0.35 * (1.0 - ph)))
		if fmod(t, 0.31) < 0.12:
			for k in 4:
				var sp: Vector2 = a._p(at + Vector2(randf_range(-1.2, 1.2), -sz.y * sy))
				ci.draw_line(sp, sp + Vector2(randf_range(-0.3, 0.3), randf_range(-0.4, -0.1)) * m, Pal.heat(1.0, 1.6), lw)
