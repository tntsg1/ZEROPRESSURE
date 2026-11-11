extends Node2D
const TugRig = preload("res://scripts/tug_rig.gd")
const W = preload("res://scripts/tug_works.gd")
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
	# a new scene: the deck has every tug home on its berth again (TugWorks primes it)
	W.held = {}


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
		_shapes[ship] = [_silhouette(polys), Vector2(x1, (y0 + y1) * 0.5) if x1 > -INF else Vector2(40.0, 0.0), y1 - y0 if x1 > -INF else 12.0]
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
					# the company's tug that flies it (a hired one never was at the station)
					var ti := TugFleet.NAMES.find(str(a.get("tug", "")))
					if ti >= 0:
						departures.append({"t": 0.0, "i": ti})
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
	_depart(dt)
	_fly(dt)
	# redraw only while something moves, or when the hulks waiting change
	var sig := str(_parked.map(func(p): return p.id))
	if not arrival.is_empty() or not departures.is_empty() or not flights.is_empty() or sig != _sig:
		_sig = sig
		queue_redraw()


func start(a: Dictionary) -> void:
	var ship := str(a.listing.offer.ship)
	var sh := _shape(ship)
	var slot := TugYard.assign(a)
	arrival = {"id": str(a.id), "polys": sh[0], "stern": sh[1], "h": float(sh[2]), "t": 0.0, "slot": slot, "ship": ship}
	_plan(arrival, str(a.get("tug", "")))
	game.state = "towin"
	game.state_t = 0.0
	game.tools.release_grab(false)
	if game.hud != null:
		game.hud.show_hint(Ops.w("拖船把 %s 拖回来了，停进拖船站外的泊位。按 Esc 跳过。", "The tug is bringing %s in to the tug yard. Esc skips.") % str(a.id))


# ---------------------------------------------------------------- the tow, planned
# user 2026-11-05: the company's own tug that flew it (asset.tug) brings it in, stern first. Jev C
# 0.62: the long haul on the tow line — taut while the tug's main drive speeds the two of them up,
# loose while they coast and the winch reels it in — then the tow arm locks on the stern and the
# tug's bow retros brake the hulk (a line can only pull). Outside berths the tug brings it to rest
# itself, casts off and flies to the tug gate; into the station's mouth it brings it to rest off the
# wall with the tug at the gate's own height, casts off there (the deck takes it in,
# scripts/tug_works.gd), and the mouth's winch hauls the hulk the last way in onto its clamp arms.
# A long ship with both tugs home is towed by the two, one on each half of its stern.
const LINE_M := 24.0            # m of tow line out on the long haul
const LONG := 60.0              # m: a ship this long gets both tugs
const PHASES := [2.8, 1.0, 3.2, 1.0]        # s: haul, reel in, brake, cast off (outside berths)
const PHASES_MOUTH := [2.6, 1.0, 2.4, 2.0]  # … haul, reel in, brake, the winch takes it in

func _plan(arr: Dictionary, tug_name: String) -> void:
	var M := Geom.M
	var slot := int(arr.slot)
	var ship := str(arr.ship)
	var mouth: bool = slot == 0 and TugYard.dock_in(ship) > 0.0
	var h := float(arr.h)
	var p2 := TugYard.slot_px(slot, ship)
	var p0 := p2 + FROM * M
	# out of open space, the last of it level, straight at the berth (the stern into the mouth square on)
	var c1 := p0 + Vector2(70.0, 80.0) * M
	var c2 := p2 + Vector2(-70.0, 0.0) * M
	var tab := PackedFloat32Array([0.0])
	var prev := p0
	for i in range(1, 97):
		var q := _bez(p0, c1, c2, p2, i / 96.0)
		tab.append(tab[i - 1] + q.distance_to(prev))
		prev = q
	arr.bez = [p0, c1, c2, p2]
	arr.tab = tab
	arr.mouth = mouth
	var ph: Array = PHASES_MOUTH if mouth else PHASES
	arr.ph = ph
	var L: float = tab[tab.size() - 1]
	# the mouth: brought to rest with the tug at the gate, then winched the rest of the way in
	var d_in := 0.0
	var lock_mouth := Vector2.ZERO
	if mouth:
		var gate_skid := PortStructure.box("tug").position + W.gate_spot() * M
		var stop_x := gate_skid.x - 13.0 * M
		d_in = maxf(p2.x - stop_x, 4.0 * M)
		lock_mouth = gate_skid - (p2 - Vector2(d_in, 0.0))
	arr.d_in = d_in
	var s_stop := L - d_in
	arr.vmax = s_stop / (float(ph[0]) * 0.5 + float(ph[1]) + float(ph[2]) * 0.5)
	# who tows
	var tugs: Array = []
	var main := TugFleet.NAMES.find(tug_name)
	if main < 0 or main >= TugFleet.count():
		tugs.append({"i": -1, "name": Ops.w("租用拖船", "HIRED TUG"), "hire": true})
	else:
		tugs.append({"i": main, "name": tug_name, "hire": false})
		var other := 1 - main
		var long_ship := float(Market.type_of(ship).get("length", 0.0)) >= LONG or h >= 16.0
		if long_ship and not mouth and other < TugFleet.count() and TugFleet.home(other) and not W.held.has(other):
			tugs.append({"i": other, "name": TugFleet.NAMES[other], "hire": false})
	for k in tugs.size():
		var tg: Dictionary = tugs[k]
		if tugs.size() == 1:
			tg.dy = 0.0
		else:
			tg.dy = (-1.0 if k == 0 else 1.0) * h * 0.26
		tg.seed = float(k) * 2.3
		# the arm locked: outside, the tug's thrust line level with its shackle, the arm 9 m off the
		# drum; into the mouth, the tug up at the gate
		tg.lock = lock_mouth if mouth else Vector2(10.9, -TugRig.AXIS) * M
		if int(tg.i) >= 0:
			W.hold(int(tg.i))
	arr.tugs = tugs


static func _bez(p0: Vector2, c1: Vector2, c2: Vector2, p3: Vector2, u: float) -> Vector2:
	var v := 1.0 - u
	return p0 * v * v * v + c1 * 3.0 * v * v * u + c2 * 3.0 * v * u * u + p3 * u * u * u


# a point (px) on the hulk stern's way in, s px along it (past its end: on along the last, level leg)
func _along(s: float) -> Vector2:
	var b: Array = arrival.bez
	var tab: PackedFloat32Array = arrival.tab
	var L: float = tab[tab.size() - 1]
	if s >= L:
		return (b[3] as Vector2) + Vector2(s - L, 0.0)
	if s <= 0.0:
		return b[0]
	var i := clampi(tab.bsearch(s), 1, tab.size() - 1)
	var u := (float(i - 1) + (s - tab[i - 1]) / maxf(tab[i] - tab[i - 1], 0.001)) / 96.0
	return _bez(b[0], b[1], b[2], b[3], u)


# how far along its way the stern is t s in (px), from the burns: sped up on the line, coasting
# while it is reeled in, braked on the arm to rest, then winched in or lying still
func _s_at(t: float) -> float:
	var ph: Array = arrival.ph
	var v := float(arrival.vmax)
	var t0 := float(ph[0])
	var t1 := t0 + float(ph[1])
	var t2 := t1 + float(ph[2])
	if t <= 0.0:
		return 0.0
	if t < t0:
		return 0.5 * v / t0 * t * t
	var s := 0.5 * v * t0
	if t < t1:
		return s + v * (t - t0)
	s += v * float(ph[1])
	if t < t2:
		var u := t - t1
		return s + v * u - 0.5 * v / float(ph[2]) * u * u
	s += v * float(ph[2]) * 0.5
	if bool(arrival.mouth):
		return s + float(arrival.d_in) * Pal.ease_io(clampf((t - t2) / float(ph[3]), 0.0, 1.0))
	return s


func _phase(t: float) -> int:
	var ph: Array = arrival.ph
	var acc := 0.0
	for i in ph.size():
		acc += float(ph[i])
		if t < acc:
			return i
	return ph.size()


# where the hulk is, 0..1 through the bringing-in (px, its own origin)
func path_at(k: float) -> Vector2:
	if arrival.is_empty() or not arrival.has("tab"):
		return Vector2.ZERO
	return _along(_s_at(clampf(k, 0.0, 1.0) * IN_T)) - (arrival.stern as Vector2) * Geom.M


# tug k's shackle on the stern t s in (px)
func _shackle(k: int, t: float) -> Vector2:
	return _along(_s_at(t)) + Vector2(0.0, float(arrival.tugs[k].dy)) * Geom.M


# tug k's skids t s in (px): ahead on the line, then drawn in to the arm and locked there
func _tug_px(k: int, t: float) -> Vector2:
	var M := Geom.M
	var tg: Dictionary = arrival.tugs[k]
	var ph: Array = arrival.ph
	var sh := _shackle(k, t)
	var s := _s_at(t)
	var on_line := _along(s + LINE_M * M) + Vector2(-TugRig.HITCH.x, float(tg.dy) - TugRig.AXIS) * M - sh
	var t0 := float(ph[0])
	var t1 := t0 + float(ph[1])
	var off: Vector2 = on_line
	if t >= t1:
		off = tg.lock
	elif t > t0:
		off = on_line.lerp(tg.lock, Pal.ease_io((t - t0) / float(ph[1])))
	return sh + off


# the tug's acceleration t s in (m/s²), from how it moves
func _tug_acc(k: int, t: float) -> Vector2:
	var h := 1.0 / 60.0
	return (_tug_px(k, t + h) - 2.0 * _tug_px(k, t) + _tug_px(k, t - h)) / (h * h) / Geom.M


func _cast_t() -> float:
	return float(arrival.ph[0]) + float(arrival.ph[1]) + float(arrival.ph[2])


# one frame of the bringing-in, while the game is in "towin": the camera on the hulk
var shot := {}                  # tests: {cam (px), zoom}: the bringing-in held still under that camera
func step_cine(dt: float) -> void:
	if arrival.is_empty():
		game.end_towin()
		return
	if not shot.is_empty():
		game.cam_override = shot.cam
		game.zoom_override = float(shot.zoom)
		return
	var before := float(arrival.t)
	arrival.t = before + dt
	var tt := float(arrival.t)
	var k: float = tt / IN_T
	var at := path_at(k)
	# led by its speed, so the camera's spring does not leave it behind (game.CAM_LAG)
	var v := (path_at(k + 1.0 / (60.0 * IN_T)) - at) * 60.0
	game.cam_override = at + Vector2(float(arrival.stern.x) * 0.5, float(arrival.stern.y)) * Geom.M + v * game.CAM_LAG
	game.zoom_override = 0.32 if k < 0.6 else lerpf(0.32, 0.5, (k - 0.6) / 0.4)
	if before < _cast_t() and tt >= _cast_t():
		_let_go()
	if k >= 1.0:
		finish()


# the tugs cast off, at rest where the arm held them; each flies home to the gate (a hired one away)
func _let_go() -> void:
	if arrival.get("cast", false) or not arrival.has("tugs"):
		return
	arrival.cast = true
	for k in arrival.tugs.size():
		var tg: Dictionary = arrival.tugs[k]
		var p := _tug_px(k, _cast_t())
		if bool(tg.hire):
			flights.append({"i": -1, "p": p, "v": Vector2.ZERO, "face": 1.0, "to_face": -1.0, "away": true, "t": 0.0, "hire": true, "name": tg.name, "seed": tg.seed})
		elif bool(arrival.mouth):
			# it is at the gate already: the deck takes it in
			W.release(int(tg.i))
		else:
			flights.append({"i": int(tg.i), "p": p, "v": Vector2.ZERO, "face": 1.0, "to_face": 1.0, "away": false, "t": 0.0, "hire": false, "name": tg.name, "seed": tg.seed})


# the bringing-in done (or skipped): the hulk at the waiting berth, seen for good, its tugs cast off
# where the arm would have left them and on their way home
func finish() -> void:
	if arrival.is_empty():
		return
	_let_go()
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


# ---------------------------------------------------------------- tugs on their own: home or away
# A flight is one tug flying itself: to the tug gate (holding a tug's length off it while another
# goes in), handed to the deck there (TugWorks.release); or away into open space (a tug sent out, a
# hired tug done). Each axis burns and brakes in time like the station's machines; the tug yaws
# round before it flies nose first.
var flights: Array = []
const FLY_V := 34.0             # m/s
const FLY_A := 11.0             # m/s²
const YAW_S := 0.9              # s to turn round


func _gate_px() -> Vector2:
	return PortStructure.box("tug").position + W.gate_spot() * Geom.M


# another tug in the gate, or nearer it than this one on the way home: this one holds off
func _gate_busy(me: Dictionary) -> bool:
	for j in W.dock.size():
		if j != int(me.i) and j < TugFleet.count() and not W.held.has(j) and bool(W.home_now[j]) and float(W.dock[j]) < 0.3:
			return true
	for f in flights:
		if f != me and int(f.i) >= 0 and not bool(f.away) and float(f.get("near", 99.0)) < float(me.get("near", 99.0)):
			return true
	return false


func _fly(dt: float) -> void:
	var M := Geom.M
	var call := false
	for f in flights:
		if not bool(f.away) and float(f.get("near", 99.0)) < 25.0:
			call = true
	W.gate_call = call
	for f in flights.duplicate():
		f.t = float(f.t) + dt
		# turning round first, drifting
		if float(f.face) != float(f.to_face):
			f.face = move_toward(float(f.face), float(f.to_face), dt * 2.0 / YAW_S)
			f.p = (f.p as Vector2) + (f.v as Vector2) * dt
			f.acc = Vector2.ZERO
			continue
		if not f.has("from"):
			f.from = f.p
		var to: Vector2
		if bool(f.away):
			to = (f.from as Vector2) + Vector2(-230.0, -190.0) * M
		else:
			to = _gate_px()
			f.near = (f.p as Vector2).distance_to(to) / M
			# another tug going in first: this one holds above the gate, in the clear lane between the
			# yard's column of sterns and the station's wall, a tug's height and a margin off it
			if _gate_busy(f):
				to += Vector2(0.0, -8.5) * M
		var p: Vector2 = (f.p as Vector2) / M
		var v: Vector2 = (f.v as Vector2) / M
		var goal := to / M
		var rx: Array = W._drive(p.x, v.x, goal.x, FLY_V, FLY_A, dt)
		var ry: Array = W._drive(p.y, v.y, goal.y, FLY_V, FLY_A, dt)
		var nv := Vector2(float(rx[1]), float(ry[1]))
		f.acc = (f.get("acc", Vector2.ZERO) as Vector2).lerp((nv - v) / maxf(dt, 1e-4), 0.4)
		f.p = Vector2(float(rx[0]), float(ry[0])) * M
		f.v = nv * M
		if bool(f.away):
			if float(f.t) > OUT_T + YAW_S or (f.p as Vector2).distance_to(f.from) > 220.0 * M:
				flights.erase(f)
		elif (f.p as Vector2).distance_to(_gate_px()) < 0.05 * M and nv.length() < 0.05:
			W.release(int(f.i))
			flights.erase(f)


# a tug sent out: once the deck has backed it out through the gate, it turns and flies away
func _depart(dt: float) -> void:
	for d in departures.duplicate():
		d.t = float(d.t) + dt
		var i := int(d.i)
		if i < 0 or i >= W.dock.size() or float(d.t) > 20.0:
			departures.erase(d)
			continue
		if float(W.dock[i]) <= 0.001:
			departures.erase(d)
			flights.append({"i": i, "p": _gate_px(), "v": Vector2.ZERO, "face": 1.0, "to_face": -1.0, "away": true, "t": 0.0, "hire": false, "name": TugFleet.NAMES[i], "seed": float(i) * 2.3})


func _draw() -> void:
	var M := Geom.M
	for p in _parked:
		_hulk(p.polys, moor(int(p.slot), p.stern, str(p.ship)), p.stern, false, _cut(int(p.slot), str(p.ship)))
		if int(p.slot) > 0:
			_berth_mark(int(p.slot), str(p.id))
	if not arrival.is_empty():
		_hulk(arrival.polys, path_at(float(arrival.t) / IN_T), arrival.stern, false, _cut(int(arrival.get("slot", 1)), str(arrival.get("ship", ""))))
		_draw_tow()
	for f in flights:
		TugRig.draw(self, f.p, float(f.face), M, f.get("acc", Vector2.ZERO), _now(), {"hire": f.hire, "seed": f.seed, "name": f.name, "font": font})


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


# the tugs on the tow and what holds them to the hulk
func _draw_tow() -> void:
	var M := Geom.M
	var t := float(arrival.t)
	var zoom: float = maxf(game.cam_zoom(), 0.05)
	var ph := _phase(t)
	var ph_t: Array = arrival.ph
	var t0 := float(ph_t[0])
	# the mouth's winch line, from the lip of the mouth to the stern, while it hauls the hulk in
	if bool(arrival.mouth) and ph == 3:
		var lip := PortStructure.box("tug").position + Vector2(0.4, W.MOUTH.x + 0.7) * M
		var sh0 := _shackle(0, t)
		if sh0.x < lip.x:
			TugRig.cable(self, lip, sh0, 0.0, M, zoom, _now())
	if arrival.get("cast", false):
		return
	for k in arrival.tugs.size():
		var tg: Dictionary = arrival.tugs[k]
		var at := _tug_px(k, t)
		var drum := TugRig.pt(at, 1.0, M, TugRig.HITCH)
		var sh := _shackle(k, t)
		if ph == 0:
			TugRig.cable(self, drum, sh, 0.0, M, zoom, _now() + k)
		elif ph == 1:
			var u := (t - t0) / float(ph_t[1])
			# coasting, the winch reeling in: the line goes loose, then the arm runs out and locks
			if u < 0.7:
				TugRig.cable(self, drum, sh, sin(u / 0.7 * PI) * 0.9, M, zoom, _now() + k)
			else:
				TugRig.arm(self, drum, sh, M, zoom)
		else:
			TugRig.arm(self, drum, sh, M, zoom)
		TugRig.draw(self, at, 1.0, M, _tug_acc(k, t), _now(), {"hire": tg.hire, "seed": tg.seed, "name": tg.name, "font": font})


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
		if Pal.solid:
			# 工业剖面: the closed hull as solid plating lit from the berth's light, its edges
			# toward the light paler, the far ones in shadow — still nothing of the inside
			var bb := Geom.bbox(w)
			var cc := bb.get_center()
			var rr := maxf(maxf(bb.size.x, bb.size.y) * 0.5, 1.0)
			var cs := PackedColorArray()
			for v in w:
				var g := lerpf(0.55, 1.5, clampf((v - cc).dot(Look.LIGHT_DIR) / rr, -1.0, 1.0) * 0.5 + 0.5)
				cs.append(Color(0.045 * g, 0.048 * g, 0.055 * g))
			draw_polygon(w, cs)
			Cutaway._edge_bands(self, w, 1.0)
		else:
			draw_colored_polygon(w, Color(0.045, 0.048, 0.055))
		var ol := w.duplicate()
		ol.append(w[0])
		# a steady line on screen whatever the zoom (a hair of a world line breaks up from afar)
		draw_polyline(ol, Pal.ink(0.55), 1.4 / maxf(game.cam_zoom(), 0.05), true)


# a yard berth's mark: the bollard frame the stern lies against and its number
func _berth_mark(slot: int, id: String) -> void:
	var M := Geom.M
	var at := TugYard.slot_px(slot)
	draw_rect(Rect2(at + Vector2(0.5, -6.0) * M, Vector2(3.0, 12.0) * M), Color(0.07, 0.075, 0.085))
	draw_rect(Rect2(at + Vector2(0.5, -6.0) * M, Vector2(3.0, 12.0) * M), Pal.ink(0.45), false, 1.2)
	draw_string(font, at + Vector2(4.5, -1.0) * M, Ops.w("拖船站泊位 %d · %s", "YARD %d · %s") % [slot + 1, id], HORIZONTAL_ALIGNMENT_LEFT, -1, 64, Pal.ink(0.6))
