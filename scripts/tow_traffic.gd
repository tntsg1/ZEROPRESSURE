extends Node2D
# Tugs at the port (design/…/63_主线重整第3批, 60 号 Q3; player 2026-10-25: "I want to see the tug
# bring it in"). In the empty berth: a hulk that has come home is brought in on camera — the tug
# pushing it in from open space below the port to the waiting berth beside the dock, where it
# stays, drawn from its own ship file, until it is started (the contract's own opening then
# pushes it from that very spot into the dock); a tug sent out is seen leaving. Esc / Space /
# Enter / a click skips the bringing-in; a hulk that came home while the terminal was open is
# brought in the next time the operator is free in the berth.

# user 2026-10-28 ("拖船还是太慢了"): 18 → 8 s in, 10 → 6 s out
const IN_T := 8.0               # s: the bringing-in, out of open space to its berth in the tug yard
const OUT_T := 6.0              # s: a tug leaving
const FROM := Vector2(-200.0, -170.0)  # m: where the tug and its hulk come from, off the tug yard (72 号)
const VIA := Vector2(-70.0, -40.0)     # m: the turn in towards the yard

var game
var arrival := {}               # the one being brought in: {id, polys, stern, t}
var departures: Array = []      # tugs going out: {t, from (px)}
var _parked: Array = []         # [{id, polys, stern}] home and waiting, nearest first
var _scan := 0.0
var _shapes := {}               # ship -> [polys (m), stern (m)]
var font: Font
var _sig := "-"


func _ready() -> void:
	font = Fonts.get_font("Regular")
	z_index = -1


# where a hulk lies in the tug yard (px, the ship's own origin): its stern on the berth's mark
# (72 号: no more waiting beside the dock; the contract's opening pushes it from here)
func moor(slot: int = 0, stern: Vector2 = Vector2.ZERO, ship: String = "") -> Vector2:
	return TugYard.slot_px(slot, ship) - stern * Geom.M


func _shape(ship: String) -> Array:
	if not _shapes.has(ship):
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
		_shapes[ship] = [_silhouette(polys), Vector2(x1, (y0 + y1) * 0.5) if x1 > -INF else Vector2(40.0, 0.0)]
	return _shapes[ship]


# user 2026-10-27 ("拖过来的时候，我都已经知道里面是什么样子了。用黑色的东西把它里面遮住"): a hulk
# not yet opened shows only its outside — the pieces merged into one outline (each grown a hair so
# touching plates join), its rooms and machines unseen. Worked out once a ship type.
const GAP := 0.6                # m: plates this close count as one hull
static func _silhouette(polys: Array) -> Array:
	var outer: Array = []
	for pts in polys:
		var grown: Array = Geometry2D.offset_polygon(pts, GAP)
		for g in grown:
			if Geometry2D.is_polygon_clockwise(g):
				continue
			var merged: Array = [g]
			var rest: Array = []
			for o in outer:
				var u: Array = Geometry2D.merge_polygons(merged[0], o)
				var solids := u.filter(func(q): return not Geometry2D.is_polygon_clockwise(q))
				if solids.size() == 1:
					merged[0] = solids[0]
				else:
					rest.append(o)
			rest.append(merged[0])
			outer = rest
	# shrunk back by most of what it grew: the gaps between plates stay closed, the hull its size
	var out: Array = []
	for o in outer:
		for q in Geometry2D.offset_polygon(o, -GAP * 0.8):
			if not Geometry2D.is_polygon_clockwise(q):
				out.append(q)
	return out


# the hulks home and not started: the bringing-in seen, nearest first
func _refresh() -> void:
	_parked = []
	if not Career.data.has("ship_market") or not Career.usable():
		return
	for a in ShipMarket.data().assets:
		# 96 号: a contract taken but not started (the berth empty) still lies in the yard
		var in_hand: bool = str(a.state) == "stripping" and game != null and game.in_berth()
		if (str(a.state) == "arrived" or in_hand) and a.get("seen_in", false) and str(arrival.get("id", "")) != str(a.id):
			var sh := _shape(str(a.listing.offer.ship))
			_parked.append({"id": str(a.id), "polys": sh[0], "stern": sh[1], "slot": TugYard.assign(a), "ship": str(a.listing.offer.ship)})


# the next hulk to bring in on camera (home, not yet seen), or {}
static func due() -> Dictionary:
	if not Career.data.has("ship_market") or not Career.usable():
		return {}
	var active := str(Career.data.get("active", {}).get("id", ""))
	for a in ShipMarket.data().assets:
		# never the hulk being stripped (user 2026-10-26: started at once, it was brought in again
		# inside its own job and the camera stayed on the tug's path)
		if str(a.state) == "arrived" and not a.get("seen_in", false) and str(a.id) != active:
			return a
	return {}


func _process(dt: float) -> void:
	if game == null:
		return
	_scan -= dt
	if _scan <= 0.0:
		_scan = 0.5
		_refresh()
		# a tug sent since the last look: seen leaving
		if Career.data.has("ship_market") and Career.usable():
			for a in ShipMarket.data().assets:
				if str(a.state) == "towing" and not a.get("seen_out", false):
					a.seen_out = true
					departures.append({"t": 0.0, "from": PortStructure.box("tug").position + Vector2(-6.0, 10.0) * Geom.M})
		# a hulk home: brought in on camera when the operator is free in the berth
		# the bringing-in was cut short by something else taking the game out of it: end it, give the
		# camera back
		if not arrival.is_empty() and game.state != "towin":
			finish()
		# 84 号: the port on foot comes first, once, in the empty berth (83 号's cards stay in the menu)
		if game.walk_on():
			return
		# 128 号: the warehouse's first visit comes first (one voice at a time)
		if game.store_guide_on():
			return
		# 108 号 Q13: the core walk after the first ship, then each district's when it is first of use
		if game.state == "play" and game.in_berth() and game.console_ui == null and not game.menu_open and not game.port_view and arrival.is_empty() and not game.testing:
			var part: String = preload("res://scripts/port_walk.gd").due_part(game)
			if part != "":
				game.start_port_walk(true, part)
				return
		# brought in only over the empty berth, never in the middle of a job
		if arrival.is_empty() and game.state == "play" and game.in_berth() and game.console_ui == null and not game.menu_open and not game.port_view:
			var a := due()
			if not a.is_empty():
				start(a)
	for d in departures.duplicate():
		d.t += dt
		if float(d.t) >= OUT_T:
			departures.erase(d)
	# redraw only while something moves, or when the hulks waiting change
	var sig := str(_parked.map(func(p): return p.id))
	if not arrival.is_empty() or not departures.is_empty() or sig != _sig:
		_sig = sig
		queue_redraw()


func start(a: Dictionary) -> void:
	var sh := _shape(str(a.listing.offer.ship))
	arrival = {"id": str(a.id), "polys": sh[0], "stern": sh[1], "t": 0.0, "slot": TugYard.assign(a), "ship": str(a.listing.offer.ship)}
	game.state = "towin"
	game.state_t = 0.0
	game.tools.release_grab(false)
	if game.hud != null:
		game.hud.show_hint(Ops.w("拖船把 %s 拖回来了，停进拖船站外的泊位。按 Esc 跳过。", "The tug is bringing %s in to the tug yard. Esc skips.") % str(a.id))


# where the hulk is, 0..1 through the bringing-in (px)
func path_at(k: float) -> Vector2:
	var e := Pal.ease_io(clampf(k, 0.0, 1.0))
	var p2 := moor(int(arrival.get("slot", 0)), arrival.get("stern", Vector2.ZERO), str(arrival.get("ship", "")))
	var p0 := p2 + FROM * Geom.M
	var p1 := p2 + VIA * Geom.M
	return p0.lerp(p1, e).lerp(p1.lerp(p2, e), e)


# one frame of the bringing-in, while the game is in "towin": the camera on the tug
func step_cine(dt: float) -> void:
	if arrival.is_empty():
		game.end_towin()
		return
	arrival.t = float(arrival.t) + dt
	var k: float = float(arrival.t) / IN_T
	var at := path_at(k)
	# led by its speed, so the camera's spring does not leave it behind (game.CAM_LAG)
	var v := (path_at(k + 1.0 / (60.0 * IN_T)) - at) * 60.0
	game.cam_override = at + Vector2(float(arrival.stern.x) * 0.5, float(arrival.stern.y)) * Geom.M + v * game.CAM_LAG
	game.zoom_override = 0.32 if k < 0.6 else lerpf(0.32, 0.5, (k - 0.6) / 0.4)
	if k >= 1.0:
		finish()


# the bringing-in done (or skipped): the hulk at the waiting berth, seen for good
func finish() -> void:
	if arrival.is_empty():
		return
	var id := str(arrival.id)
	arrival = {}
	var a := ShipMarket.asset(id)
	if not a.is_empty():
		a.seen_in = true
		Career.save()
	if game.radio != null:
		Copy.say(game.radio, "L_tow_in")
	game.end_towin()
	# whatever state the game is in now, the camera is not the tug's any more
	game.cam_override = null
	game.zoom_override = -1.0
	_refresh()


func _draw() -> void:
	var M := Geom.M
	for p in _parked:
		_hulk(p.polys, moor(int(p.slot), p.stern, str(p.ship)), p.stern, false, _cut(int(p.slot), str(p.ship)))
		if int(p.slot) > 0:
			_berth_mark(int(p.slot), str(p.id))
	if not arrival.is_empty():
		_hulk(arrival.polys, path_at(float(arrival.t) / IN_T), arrival.stern, true, _cut(int(arrival.get("slot", 1)), str(arrival.get("ship", ""))))
	for d in departures:
		var e := Pal.ease_in(clampf(float(d.t) / OUT_T, 0.0, 1.0))
		var p: Vector2 = (d.from as Vector2).lerp((d.from as Vector2) + FROM * M, e)
		game.dock._tug(p, self)


# 96 号: a hulk going into the tug station's mouth is drawn only up to the wall; inside, the
# station draws its stern (scripts/tug_station_art.gd)
func _cut(slot: int, ship: String) -> Rect2:
	if slot != 0 or TugYard.dock_in(ship) <= 0.0:
		return Rect2()
	var b := PortStructure.box("tug")
	return Rect2(b.position + Vector2(0.75 * Geom.M, 0.0), b.size)


# a hulk drawn from its ship file, and its tug at the stern
func _hulk(polys: Array, at: Vector2, stern: Vector2, tug: bool, cut := Rect2()) -> void:
	var M := Geom.M
	# the outline only, filled dark: nothing inside shows until it is opened in the berth
	var all: Array = []
	for pts in polys:
		var w := PackedVector2Array()
		for v in pts:
			w.append(at + v * M)
		if cut.has_area():
			var box := PackedVector2Array([cut.position, Vector2(cut.end.x, cut.position.y), cut.end, Vector2(cut.position.x, cut.end.y)])
			for part in Geometry2D.clip_polygons(w, box):
				if not Geometry2D.is_polygon_clockwise(part):
					all.append(part)
		else:
			all.append(w)
	for w: PackedVector2Array in all:
		draw_colored_polygon(w, Color(0.045, 0.048, 0.055))
		var ol := w.duplicate()
		ol.append(w[0])
		# a steady line on screen whatever the zoom (a hair of a world line breaks up from afar)
		draw_polyline(ol, Pal.ink(0.55), 1.4 / maxf(game.cam_zoom(), 0.05), true)
	if tug:
		game.dock._tug(at + stern * M, self)


# a yard berth's mark: the bollard frame the stern lies against and its number
func _berth_mark(slot: int, id: String) -> void:
	var M := Geom.M
	var at := TugYard.slot_px(slot)
	draw_rect(Rect2(at + Vector2(0.5, -6.0) * M, Vector2(3.0, 12.0) * M), Color(0.07, 0.075, 0.085))
	draw_rect(Rect2(at + Vector2(0.5, -6.0) * M, Vector2(3.0, 12.0) * M), Pal.ink(0.45), false, 1.2)
	draw_string(font, at + Vector2(4.5, -1.0) * M, Ops.w("拖船站泊位 %d · %s", "YARD %d · %s") % [slot + 1, id], HORIZONTAL_ALIGNMENT_LEFT, -1, 64, Pal.ink(0.6))
