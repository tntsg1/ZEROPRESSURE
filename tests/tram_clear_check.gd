extends SceneTree
# 接驳站穿模修复 (user 2026-11-09: “拖船站还有些许穿模”; “贸易港这很多铁轨……属于穿模”): inside every district
# the shuttle's and the freight's track, the stop's platform, its sign on its post, the trains standing
# at their stops (and the trade port's recycling crane) keep clear of the district's machines and its
# business console, and the stop's name never meets the console's name plate at any zoom the two are
# drawn at. Box-local metres, a margin of MARGIN m. Static geometry: no scene. Own test saves only.
#   tools/run_test.sh tests/tram_clear_check.gd --headless [-- list=1]
const MARGIN := 0.25
const ZOOMS := [0.15, 0.2, 0.25, 0.3, 0.4, 0.5, 0.75, 1.0, 1.5, 2.0]
const FW = preload("res://scripts/freight_works.gd")
const FV = preload("res://scripts/freight_view.gd")
const PS = preload("res://scripts/port_solids.gd")
const DI = preload("res://scripts/district_interiors.gd")
const TA = preload("res://scripts/tug_station_art.gd")
const TW = preload("res://scripts/trade_works.gd")
const TramArt = preload("res://scripts/tram_art.gd")
const ConsoleArt = preload("res://scripts/console_art.gd")
# known and left to the owner (design/…: cargo bank A's rows A2/A3 and its forklifts' masts stand in the
# freight line's bay by design, 130 号 choice E) — listed, not counted
const KNOWN := ["cargo|rack bank A uprights", "cargo|rack A2 goods", "cargo|solid 0", "cargo|rack A1 plate"]

var fails := 0
var known := 0
var listing := false


func _initialize() -> void:
	Career.path = "user://zp_test_tramclear_check_career.json"
	SaveGame.path = "user://zp_test_tramclear_check_save.json"
	SaveGame.allow_test = true
	listing = "list=1" in OS.get_cmdline_user_args()
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.port = {"salvage": 2, "trade": 2, "process": 2, "power": 2, "tug": 2, "cargo": 2, "ring": 2}
	var zones := ["power", "tug", "process", "trade", "cargo"]
	for z in zones:
		_zone(z)
	_labels(zones)
	print("tram_clear_check: %s — %d overlaps, %d known (left to the owner)" % ["PASS" if fails == 0 else "FAIL", fails, known])
	quit(1 if fails > 0 else 0)


func _loc(zone: String, p: Vector2) -> Vector2:
	return (p - PortStructure.box(zone).position) / PortStructure.M()


# a straight piece of track (or what stands on it) from a to b, `half` either side of it
func _seg_rect(a: Vector2, b: Vector2, half: float) -> Rect2:
	var r := Rect2(a, Vector2.ZERO).expand(b)
	if absf(b.x - a.x) >= absf(b.y - a.y):
		return r.grow_individual(0.0, half, 0.0, half)
	return r.grow_individual(half, 0.0, half, 0.0)


func _wr(zone: String, r: Rect2) -> Rect2:
	return Rect2(_loc(zone, r.position), r.size / PortStructure.M())


# the rail side: [name, box-local rect]
func _rail(zone: String) -> Array:
	var M := PortStructure.M()
	var out: Array = []
	var sp := Tram.station_at(zone)
	var d := Tram.station_dir(zone)
	var n := Tram.platform_side(zone)
	var door: Vector2 = PortStructure.door(zone)[0]
	var ext: bool = zone in FW.EXT_ZONES
	# the track's bed (2.1 m) out to its end: the freight's buffer (its struts 0.9 m on) or the shuttle's
	var end: Vector2 = FW.ext_end(zone) - d * 0.95 * M if ext else sp - d * (Tram.BUFFER_AT + 0.95) * M
	out.append(["track", _wr(zone, _seg_rect(end, door, 1.05 * M))])
	# the trains standing at their stops: the shuttle (two 3.2 m cars, 1.6 m wide) and the freight (3 m wide)
	out.append(["shuttle at its stop", _wr(zone, _seg_rect(sp - d * 1.6 * M, sp + d * (Tram.COUPLE + 1.6) * M, 0.8 * M))])
	if ext:
		var head := sp - d * (FW.ext(zone) - 1.6) * M
		out.append(["freight at its stop", _wr(zone, _seg_rect(head - d * 1.7 * M, head + d * (8.7 + 2.0) * M, FW.WIDTH * 0.5 * M))])
	# the platform and its edge, the sign on its post
	var pl := sp + d * float(Tram.PLATFORM_SHIFT.get(zone, 0.0)) * M
	var e0 := pl + n * 1.0 * M - d * 2.0 * M
	var e1 := pl + n * 2.1 * M + d * 2.4 * M
	var plr := _wr(zone, Rect2(e0, Vector2.ZERO).expand(e1))
	if not Rect2(0, 0, 60, 28).encloses(plr):
		fails += 1
		print("  OUTSIDE %s: the platform %s reaches out of the district" % [zone, _f(plr)])
	out.append(["platform", plr])
	var post := Tram.sign_post(zone)
	out.append(["sign post", _wr(zone, _seg_rect(post, post + n * 0.5 * M, 0.06 * M))])
	out.append(["sign", _wr(zone, Tram.sign_rect(zone))])
	if zone == "trade":
		var names := ["recycling runway", "recycling chute", "recycling jib's reach"]
		var rs: Array = FV.recycle_rects()
		for i in rs.size():
			out.append([names[i], _wr(zone, rs[i])])
	return out


# the district's side: [name, box-local rect]
func _things(zone: String) -> Array:
	var out: Array = []
	var k := 0
	for r: Rect2 in PS.rects(zone):
		out.append(["solid %d" % k, r])
		k += 1
	for mc in PortStructure.MACHINES.get(zone, []):
		out.append([str(mc[0]), Rect2(mc[1], mc[2])])
	for s in DI.SOLIDS.get(zone, []):
		out.append([str(s[0]), Rect2(s[1], s[2])])
	# the business console: its body and its column down to the floor
	var M := PortStructure.M()
	var c := PortStructure.console_spot(zone)
	var foot := (PortStructure.box(zone).end.y - 1.2 * M - c.y) / M
	if not (zone == "process" and preload("res://scripts/process_gallery.gd").on()):
		var ex := ConsoleArt.extent("console", clampf(foot, 1.2, 14.0))
		out.append(["business console", Rect2(_loc(zone, c) + ex.position, ex.size)])
	match zone:
		"tug":
			out.append(["propellant tank", Rect2(TA.TANK.position.x - 0.6, TA.TANK.position.y - 0.85, TA.TANK.size.x + 0.6, TA.TANK.size.y + 0.85)])
			out.append(["parts bins", TA.BINS])
			for i in 2:
				var lx := preload("res://scripts/tug_works.gd").lift_x(i)
				out.append(["pod lift %d shaft" % i, Rect2(lx - 1.6, 11.5, 3.2, TA.TABLE_TOP - 11.5)])
			out.append(["deck hanger", Rect2(TA.HANGER_X - 0.45, 0.2, 0.9, 11.4)])
		"trade":
			# a visitor's cart where it stops, its name plate over it; the counters
			out.append(["visitor's cart", Rect2(TW.WAIT_X - 1.3, TW.SLAB.x - 0.12 - 1.7, 2.6, 1.7)])
			out.append(["visitor's plate", Rect2(TW.WAIT_X - 0.5, TW.SLAB.x - 0.12 - 3.3, 14.0, 0.9)])
		"cargo":
			var CA := preload("res://scripts/cargo_art.gd")
			var x0: float = CA.BAYS[0]
			out.append(["rack bank A uprights", Rect2(x0 - 0.13, CA.RACK_TOP, 10.26, CA.FLOOR - CA.RACK_TOP)])
			out.append(["rack A2 goods", Rect2(x0, float(CA.BEAMS[1]) - 3.0, 10.0, 3.26)])
			for lv in 4:
				out.append(["rack A2 goods" if lv == 1 else "rack A%d plate" % (lv + 1), Rect2(x0 - 1.65, float(CA.BEAMS[lv]), 1.45, 0.62)])
	return out


func _zone(zone: String) -> void:
	var rail := _rail(zone)
	var things := _things(zone)
	var n := 0
	for r in rail:
		for th in things:
			var a: Rect2 = r[1]
			var b: Rect2 = th[1]
			if not a.grow(MARGIN).intersects(b):
				continue
			var key := "%s|%s" % [zone, th[0]]
			if key in KNOWN:
				known += 1
				if listing:
					print("  known  %s: %s ↔ %s" % [zone, r[0], th[0]])
				continue
			fails += 1
			n += 1
			print("  OVERLAP %s: %s %s ↔ %s %s" % [zone, r[0], _f(a), th[0], _f(b)])
	# the business console keeps off the district's things too (it stood over cargo rack A's row plates)
	var cons: Array = things.filter(func(t): return t[0] == "business console")
	for cn in cons:
		for th in things:
			if th[0] == "business console" or str(th[0]).begins_with("solid") or th[0] in ["deck", "table", "rack"]:
				continue
			if (cn[1] as Rect2).grow(0.1).intersects(th[1]):
				fails += 1
				n += 1
				print("  OVERLAP %s: business console %s ↔ %s %s" % [zone, _f(cn[1]), th[0], _f(th[1])])
	print("%s: %d rail parts × %d things, %d overlaps" % [zone, rail.size(), things.size(), n])
	if listing:
		for r in rail:
			print("    rail  %-24s %s" % [r[0], _f(r[1])])


func _f(r: Rect2) -> String:
	return "[%.2f–%.2f × %.2f–%.2f]" % [r.position.x, r.end.x, r.position.y, r.end.y]


# the stop's name (scripts/tram.gd name_box) and the console's plate (scripts/console_art.gd _name_plate),
# screen px at each zoom both are drawn at
func _labels(zones: Array) -> void:
	var font := Fonts.get_font("Medium")
	var M := Geom.M
	for z in zones:
		var c := PortStructure.console_spot(z)
		var title: String = Txt.t("pt_console_business") + " · " + Port.name_of(z)
		var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var size := Vector2(tw + 30.0, 22.0)
		var worst := INF
		for zoom: float in ZOOMS:
			var nb: Rect2 = Tram.name_box(z, zoom, font)
			var nb_px := Rect2(nb.position * zoom, nb.size * zoom)
			var anchor := (c + Vector2(0.0, -1.9) * PortStructure.M()) * zoom
			var plate := Rect2(anchor - Vector2(size.x * 0.5, size.y + 4.0), size)
			var gap := _gap(nb_px, plate)
			worst = minf(worst, gap)
			if gap < 4.0:
				fails += 1
				print("  LABELS %s at zoom %.2f: the stop's name %s meets the console's plate %s (gap %.1f px)" % [z, zoom, _f(nb_px), _f(plate), gap])
		print("%s: labels' least gap %.1f px over zooms %s" % [z, worst, str(ZOOMS)])
	var _m := M


# the distance between two rects (negative: they overlap)
func _gap(a: Rect2, b: Rect2) -> float:
	var dx := maxf(b.position.x - a.end.x, a.position.x - b.end.x)
	var dy := maxf(b.position.y - a.end.y, a.position.y - b.end.y)
	if dx < 0.0 and dy < 0.0:
		return maxf(dx, dy)
	return maxf(dx, dy)
