extends RefCounted
# 130 号 (design/130_货运火车经中央环_定案.md; user 2026-11-04: "让火车把设备啊，金属啊，通过中央环转运，
# 这样看的繁忙一点，机械臂也有用"): freight trains on the shuttle's rails. Each is a locomotive and two
# roller-bed flat wagons, a crate a wagon. They load at a freight stop in a district's corridor (short of
# the passenger stop), run up to the central ring, stand on the loop by that spoke's hatch, lock, and the
# wagon's rollers push the crate across the apron onto the lowered lift; the arm takes it to the
# carousel (scripts/hub_works.gd). At the far spoke the arm sets it on the lift, the lift goes down, a
# train stands by, its rollers take it aboard, and it runs it down that corridor to unload. While the
# ring is dead the trains run straight from district to district.
# The rails are shared with the passenger shuttle (scripts/tram.gd), which comes first: every train,
# the shuttle too, claims the whole of its route (the track as 1 m cells) before it sets off and frees
# it behind itself; a shuttle wanting a route nobody may take it from it, and freight standing in its
# way leaves for somewhere out of it. Freight never runs over the hub stop's stretch of the loop.
# What they carry is what really moves in the warehouse (scripts/store_book.gd, read only): put-aways,
# sales to the recycling station, steel ordered from the furnace, billets out of it; between those, a
# base service by the port's size, with things the warehouse really holds. Static, as hub_works: the
# headless tests run it without a scene. World pixels throughout (as Tram).
const W = preload("res://scripts/hub_works.gd")
const TramArt = preload("res://scripts/tram_art.gd")

const ZONES := ["cargo", "trade", "process", "tug", "salvage"]
# 130 号: with the ring running each train works one corridor, between that district's stop and the
# same spoke's hatch (the carousel carries the crates across): the busiest first. The districts no
# train serves yet still lift their crates up from below, as before the trains.
const HOMES := ["cargo", "salvage", "process", "trade", "tug"]
# 130 号 (user's choice E): a district's freight stop is inside its gate, behind the passenger stop: the
# line runs on EXT m past the stop into the building to a buffer, so the shuttle never has to pass a
# freight train standing at its stop. The berth's is still up its corridor (past its gate is the berth).
const EXT := 20.0
const EXT_ZONES := ["cargo", "process", "trade", "tug"]
# 130 号 (user's choice A for the berth): the berth's corridor is wider (PortStructure.HALF_SALVAGE) and
# its freight stop is a siding beside the line: it leaves the line SIDING_TOE m out from the hub's
# centre, swings SIDING_OFF m across over SIDING_BEND m and runs on to a buffer at SIDING_END. The
# shuttle runs straight past a train standing there.
const SIDING_TOE := 37.0
const SIDING_BEND := 8.0
const SIDING_OFF := 3.2
const SIDING_END := 59.5
# 130 号 (user's choice A for the traffic): a passing loop on the ring — a second track inside it on the
# free stretch of deck between the power and trade spokes, from PASS_A to PASS_B: a train runs either
# way round on the main track or the inner one, so two can pass. Switches p1:a and p1:b.
const PASS_A := -80.0 * PI / 180.0
const PASS_B := -12.0 * PI / 180.0
const PASS_R := 18.0
const PASS_SWING := 12.0 * PI / 180.0   # rad of loop each end's swing in and out takes
const V_MAX := 32.0            # m/s (130 号 review: 18, "火车慢悠悠的": ×1.8, with the pull, brake and jerk)
const A_MAX := 4.6             # m/s² speeding up and braking at most
const A_BRAKE := 3.5          # m/s² the braking curve is laid out for (the rest is margin for the jerk)
const JERK := 9.0              # m/s³: how fast the pull or the brake comes on and off
const A_LAT := 2.6             # m/s² sideways a curve allows
const CREEP := 1.6             # /s: the last metres to a stop taken slower and slower
const LOCO_L := 3.4            # m
const WAGON_L := 4.0
const WIDTH := 3.0
# car centres behind the head car's, m: [loco leading: loco, wagon 0, wagon 1], [wagons leading: wagon 1, wagon 0, loco]
const OFF := [0.0, 4.2, 8.7]
const OFF_R := [0.0, 4.5, 8.7]
const D_HEAD := 10.0            # m from a district's passenger stop back to a freight train's head
const BAN := 15.0 * PI / 180.0 # rad either side of the hub's passenger stop no freight runs over
const LOCK_T := 0.3
const LOAD_T := 0.7
const SELL_T := 4.0           # s the recycling station's crane takes to lift a sale off and drop it in
const HOLD := 0.6              # s a reversal stands: the driver changes ends
const WAIT_MAX := 6.0          # s a train waits for a route before trying another
const HUB_WAIT := 25.0         # s it waits by a hatch that will not take its crate
const CELL := 1.0              # m
# 130 号 (block signalling): a train holds the track it stands on and the next blocks ahead only —
# BLOCK m each, as far as it could brake plus AUTH_AHEAD — and takes the next block as it comes to it
# if nobody holds it (a signal at clear); otherwise it stops at the end of what it holds (at danger).
# Two trains each waiting more than DEADLOCK_T s on what the other holds: the one nearer the passing
# loop backs away the way it came.
const BLOCK := 15.0
const AUTH_AHEAD := 25.0
const DEADLOCK_T := 3.0
static var show_blocks := false   # draw who holds which track (scripts/freight_view.gd)
const REVERSE_COST := 25.0
const PASSENGER := -1

static var on := false
static var debug := false
static var trains: Array = []
static var claims := {}        # Vector2i cell -> owner (a train's id, PASSENGER)
static var pending := {}       # the shuttle's wanted route, waiting: cell -> true
# the shuttle following a freight train down its route: the cells of it the train still held when the
# shuttle set off, the shuttle's as the train leaves them (nobody else's)
static var follow := {}
static var why := -9   # tests: the train the shuttle last waited for
static var prof := {}  # tests: the slowest µs seen in each part of a step
static var _p_pts: Array = []
static var _pending_t := 0.0
static var queue: Array = []   # shipments waiting for a train: {from, to, key, use, name, look}
static var tram = null         # the shuttle (it works the switches), null in headless tests
static var tram_clear := false # a freight train is held up by the shuttle standing idle at its stop
static var sw := {}            # the switches when there is no shuttle
static var t := 0.0
static var _scan := 0.0
static var _base := 8.0
static var _seen := {}
static var _seen_ok := false
static var _pq := -1
static var _demo_t := 0.0
static var _demo_i := 0
static var _geo := {}
static var _banned := {}
static var _planned_frame := -1
static var _ticks := 0
static var _routes := {}       # candidate routes from a district stop, by (from, to, which end leads, wagons)
# tests
static var delivered := 0      # crates unloaded at a district
static var pushed := 0         # crates pushed into a hatch
static var taken := 0          # crates taken off a hatch
static var yields := 0
static var max_wait := 0.0     # s the shuttle waited longest for freight
static var wait_now := 0.0
static var base_runs := 0
static var pushed_up := 0      # crates lifted from below at hatches no train serves
static var time_in := {}       # tests: s spent per kind of step ("route" waiting for one, "run", "hub", "load", "idle", "hold")
static var real_runs := 0


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


static func M() -> float:
	return Geom.M


static func reset() -> void:
	trains = []
	claims = {}
	pending = {}
	queue = []
	sw = {}
	tram_clear = false
	t = 0.0
	_scan = 0.0
	_base = 8.0
	_seen = {}
	_seen_ok = false
	_pq = -1
	_demo_t = 0.0
	_demo_u_t = 0.0
	_geo = {}
	_banned = {}
	_routes = {}
	delivered = 0
	pushed = 0
	taken = 0
	yields = 0
	max_wait = 0.0
	wait_now = 0.0
	base_runs = 0
	pushed_up = 0
	real_runs = 0
	time_in = {}
	order_in = {}


# ------------------------------------------------------------------ the network's fixed places
static func centre() -> Vector2:
	return Backdrop.port_centre_px()


# the berth's siding, world px, from its toe on the line to its buffer
static func siding_pts() -> Array:
	var c := centre()
	var ax := Vector2.from_angle(float(W.spokes().get("salvage", PI * 0.5)))
	var nn := ax.orthogonal()
	var at := func(al: float, sd: float) -> Vector2: return c + (ax * al + nn * sd) * M()
	var out: Array = []
	for k in 13:
		var q := float(k) / 12.0
		var e := q * q * (3.0 - 2.0 * q)
		out.append(at.call(SIDING_TOE + SIDING_BEND * q, SIDING_OFF * e))
	out.append(at.call(SIDING_END, SIDING_OFF))
	return out


# the passing loop's inner track, world px, from its toe at PASS_A round to its toe at PASS_B
static var _pass_pts: Array = []
static func pass_pts() -> Array:
	if not _pass_pts.is_empty():
		return _pass_pts.duplicate()
	_pass_pts = _pass_pts_make()
	return _pass_pts.duplicate()


static func _pass_pts_make() -> Array:
	var c := centre()
	var out: Array = []
	var n := 40
	for k in n + 1:
		var a := lerpf(PASS_A, PASS_B, float(k) / n)
		var r := PASS_R
		if a < PASS_A + PASS_SWING:
			var q := (a - PASS_A) / PASS_SWING
			r = lerpf(Tram.LOOP_R, PASS_R, q * q * (3.0 - 2.0 * q))
		elif a > PASS_B - PASS_SWING:
			var q2 := (PASS_B - a) / PASS_SWING
			r = lerpf(Tram.LOOP_R, PASS_R, q2 * q2 * (3.0 - 2.0 * q2))
		out.append(c + Vector2.from_angle(a) * r * M())
	return out


# a run round the loop from a0 the way s for span rad: [pts, switches], on the main track or, where it
# covers the whole passing loop, by way of its inner track
static func _arc2(a0: float, s: float, span: float, inner: bool) -> Array:
	var sw := {}
	var lo := PASS_A if s > 0.0 else PASS_B
	var hi := PASS_B if s > 0.0 else PASS_A
	var dlo := Tram._span(a0, lo, s)
	var dhi := Tram._span(a0, hi, s)
	var covers := dlo > 0.001 and dlo < span and dhi > dlo and dhi < span
	if not inner or not covers:
		if covers or (dlo < span) or (dhi < span):
			# the passing loop's toes run over straight
			if dlo > 0.001 and dlo < span - 0.001:
				sw["p1:a" if s > 0.0 else "p1:b"] = 0.0
			if dhi > 0.001 and dhi < span - 0.001:
				sw["p1:b" if s > 0.0 else "p1:a"] = 0.0
		return [Tram._arc(a0, s, span), sw]
	var pts: Array = Tram._arc(a0, s, dlo)
	var ip := pass_pts()
	if s < 0.0:
		ip.reverse()
	pts.append_array(ip.slice(1))
	pts.append_array(Tram._arc(hi, s, span - dhi))
	sw["p1:a"] = 1.0
	sw["p1:b"] = 1.0
	return [pts, sw]


# the line itself past the siding's toe, a few metres (the switch's straight blade)
static func siding_main() -> Array:
	var c := centre()
	var ax := Vector2.from_angle(float(W.spokes().get("salvage", PI * 0.5)))
	return [c + ax * SIDING_TOE * M(), c + ax * (SIDING_TOE + SIDING_BEND) * M()]


# the far end of a district's freight line, inside its gate (world px)
static func ext_end(z: String) -> Vector2:
	return Tram.station_at(z) - Tram.station_dir(z) * EXT * M()


# a district's freight stop: the head's place, standing towards the dead end, and its line out to the
# rim from there [pts]
static func _dstop(z: String) -> Dictionary:
	var k := "d:" + z
	if not _geo.has(k) and z in EXT_ZONES:
		# (1.6 m short of the line's end: the front bogie stands on the rails, not past them)
		var head := Tram.station_at(z) - Tram.station_dir(z) * (EXT - 1.6) * M()
		_geo[k] = {"head": head, "line": [head] + Tram._leg(z), "dir": -Tram.station_dir(z)}
	if not _geo.has(k) and z == "salvage":
		# the siding, back from its buffer to the toe, then up the line to the rim
		var sp := siding_pts()
		var ax := Vector2.from_angle(float(W.spokes().get("salvage", PI * 0.5)))
		var head: Vector2 = (sp[-1] as Vector2) - ax * 1.6 * M()
		var back: Array = [head]
		for i in range(sp.size() - 2, -1, -1):
			back.append(sp[i])
		back.append(Tram._leg("salvage")[-1])
		_geo[k] = {"head": head, "line": back, "dir": ax}
	if not _geo.has(k):
		var leg: Array = Tram._leg(z)
		var d := D_HEAD * M()
		var out: Array = []
		var acc := 0.0
		var placed := false
		for i in range(1, leg.size()):
			var a: Vector2 = leg[i - 1]
			var b: Vector2 = leg[i]
			var seg := a.distance_to(b)
			if not placed and acc + seg >= d:
				out.append(a.lerp(b, (d - acc) / maxf(seg, 0.001)))
				placed = true
			if placed:
				out.append(b)
			acc += seg
		var head: Vector2 = out[0]
		_geo[k] = {"head": head, "line": out, "dir": ((leg[0] as Vector2) - head).normalized()}
	return _geo[k]


static func hub_angle(z: String) -> float:
	return float(W.spokes().get(z, 0.0))


static func R() -> float:
	return Tram.LOOP_R * M()


static func angle_of(p: Vector2) -> float:
	return (p - centre()).angle()


static func on_loop(p: Vector2) -> bool:
	return absf(p.distance_to(centre()) - R()) < 0.6 * M()


static func _key(p: Vector2) -> Vector2i:
	var s := CELL * M()
	return Vector2i(floori(p.x / s), floori(p.y / s))


# the cells a run of points covers (with its width), with how far along each comes: [[s, key], …]
static func cells(pts: Array, s0 := 0.0, half := 1.1) -> Array:
	var out: Array = []
	var cs := CELL * M()
	var recent := PackedVector2Array()
	recent.resize(18)
	recent.fill(Vector2(INF, INF))
	var ri := 0
	var s := s0
	var step := 0.5 * M()
	for i in range(1, pts.size()):
		var a: Vector2 = pts[i - 1]
		var b: Vector2 = pts[i]
		var seg := a.distance_to(b)
		if seg < 0.001:
			continue
		var d := (b - a) / seg
		var n := d.orthogonal() * half * M()
		var x := 0.0
		while x < seg:
			var q := a + d * x
			var sx := s + x
			# a cell just listed (the samples are closer than a cell) is listed once; the last 18
			# samples (3 m of track) are remembered, so a cell run over again later, after a change
			# of ends, is listed again then
			for qq: Vector2 in [q, q + n, q - n]:
				var k := Vector2i(floori(qq.x / cs), floori(qq.y / cs))
				var kv := Vector2(k)
				if recent.find(kv) < 0:
					out.append([sx, k])
				recent[ri] = kv
				ri = (ri + 1) % 18
			x += step
		s += seg
	if not pts.is_empty():
		var e: Vector2 = pts[-1]
		out.append([s, _key(e)])
	return out


static func banned() -> Dictionary:
	if _banned.is_empty():
		var pts: Array = []
		var a0 := Tram.RING_A - BAN
		for k in 41:
			pts.append(Tram._loop_pt(a0 + 2.0 * BAN * k / 40.0))
		for c in cells(pts, 0.0, 1.6):
			_banned[c[1]] = true
	return _banned


# ------------------------------------------------------------------ a train
static func _new_train(id: int, home: String) -> Dictionary:
	var st := _dstop(home)
	var head: Vector2 = st.head
	var line: Array = st.line
	var tr := {"id": id, "home": home, "place": "d:" + home, "pos": head, "heading": (st.dir as Vector2).angle(), "trail": [],
		"path": [], "limits": [], "legs": [], "leg_sw": {}, "hold": 0.0, "speed": 0.0, "acc": 0.0, "lf": true,
		"wag": [null, null], "anim": [{}, {}], "steps": [], "step": {}, "status": w("待命", "STANDING BY"), "lock": 1.0,
		"route": [], "wait": 0.0, "from": "", "to": "", "moving": false, "roll": 0.0, "s_run": 0.0, "work": "", "hub": ""}
	# the cars standing behind the head along the line to the rim
	var trail: Array = []
	var prev := head
	var acc := 0.0
	for i in range(1, line.size()):
		var a: Vector2 = line[i - 1]
		var b: Vector2 = line[i]
		var seg := a.distance_to(b)
		var x := 0.25 * M() - fmod(acc, 0.25 * M())
		while x <= seg and trail.size() < 70:
			trail.append(a.lerp(b, x / seg))
			x += 0.25 * M()
		acc += seg
	tr.trail = trail
	return tr


# the car centres behind the head (m), by which end leads
static func offs(tr: Dictionary) -> Array:
	return OFF if bool(tr.lf) else OFF_R


# which car (0 loco, 1 wagon 0, 2 wagon 1) stands at each place from the head
static func order(tr: Dictionary) -> Array:
	return [0, 1, 2] if bool(tr.lf) else [2, 1, 0]


# a wagon's (0, 1) distance behind the head, m
static func wagon_off(tr: Dictionary, wi: int) -> float:
	var o := order(tr)
	var of := offs(tr)
	for k in 3:
		if int(o[k]) == wi + 1:
			return float(of[k])
	return 0.0


static func body_back(tr: Dictionary) -> float:
	return 8.7 + (LOCO_L if not bool(tr.lf) else WAGON_L) * 0.5


static func body_front(tr: Dictionary) -> float:
	return (LOCO_L if bool(tr.lf) else WAGON_L) * 0.5


static func ahead(tr: Dictionary, dist: float) -> Vector2:
	var left := dist
	var prev: Vector2 = tr.pos
	for wp in tr.path:
		var seg: float = prev.distance_to(wp)
		if seg >= left:
			return prev.lerp(wp, left / maxf(seg, 0.001))
		left -= seg
		prev = wp
	return prev + Vector2.from_angle(float(tr.heading)) * left


static func behind(tr: Dictionary, back: float) -> Vector2:
	var left := back
	var prev: Vector2 = tr.pos
	for p in tr.trail:
		var seg: float = prev.distance_to(p)
		if seg >= left:
			return prev.lerp(p, left / maxf(seg, 0.001))
		left -= seg
		prev = p
	return prev - Vector2.from_angle(float(tr.heading)) * left


static func along(tr: Dictionary, s: float) -> Vector2:
	return ahead(tr, s) if s >= 0.0 else behind(tr, -s)


# each car: [centre px, angle, length m, kind "loco" | "wagon", wagon index or -1]
static func cars(tr: Dictionary) -> Array:
	var out: Array = []
	var o := order(tr)
	var of := offs(tr)
	for k in 3:
		var s := -float(of[k]) * M()
		var c := along(tr, s)
		var tg := along(tr, s + 1.0 * M()) - along(tr, s - 1.0 * M())
		var ang: float = tg.angle() if tg.length() > 0.01 else float(tr.heading)
		var ci := int(o[k])
		out.append([c, ang, LOCO_L if ci == 0 else WAGON_L, "loco" if ci == 0 else "wagon", ci - 1])
	return out


# the cells under the train standing (from just ahead of its front to just behind its tail)
static func body_cells(tr: Dictionary) -> Array:
	var pts: Array = []
	var f := (body_front(tr) + 0.6) * M()
	var b := (body_back(tr) + 0.6) * M()
	var x := -b
	while x <= f:
		pts.append(along(tr, x))
		x += 0.5 * M()
	pts.append(along(tr, f))
	return cells(pts, -b - f, 1.1)


# ------------------------------------------------------------------ routes
# the switches: through the shuttle when there is one
static func _sw_set(id: String, v: float) -> void:
	if tram != null and is_instance_valid(tram):
		if float(tram.sw_to.get(id, 0.0)) != v or not tram.sw_to.has(id):
			tram.sw_to[id] = v
			tram._points_dirty = true
	else:
		sw[id] = v


static func _sw_ready(m: Dictionary) -> bool:
	if tram == null or not is_instance_valid(tram):
		return true
	for id in m:
		if absf(float(tram.sw_pos.get(id, 0.0)) - float(m[id])) > 0.001:
			return false
	return true


static func _dir_on_loop(tr: Dictionary) -> float:
	var p: Vector2 = tr.pos
	var tg := Vector2.from_angle(angle_of(p) + PI * 0.5)
	return 1.0 if Vector2.from_angle(float(tr.heading)).dot(tg) >= 0.0 else -1.0


# the ways out of where the train stands: [{pts, a (loop angle reached), s (way round), sw, rev (changes ends first)}]
static func _starts(tr: Dictionary) -> Array:
	var out: Array = []
	var place := str(tr.place)
	if place.begins_with("d:"):
		var z := place.substr(2)
		var st := _dstop(z)
		for s: float in [1.0, -1.0]:
			var pts: Array = [tr.pos] + (st.line as Array).slice(1) + Tram._turnout(z, s).slice(1)
			var m := {}
			m[z + ":f"] = 1.0 if s > 0.0 else 0.0
			m[z + (":+" if s > 0.0 else ":-")] = 1.0
			if z == "salvage":
				m["salvage:s"] = 1.0
			out.append({"pts": pts, "a": Tram._angle(z) + s * Tram._turn(z), "s": s, "sw": m, "rev": true})
	else:
		var th := angle_of(tr.pos)
		var d := _dir_on_loop(tr)
		for s: float in [1.0, -1.0]:
			out.append({"pts": [tr.pos], "a": th, "s": s, "sw": {}, "rev": s != d})
	return out


# the ways into a place: [{tail pts, a (loop angle left), s, sw, hub (stands on the loop)}]
static func _ends(place: String) -> Array:
	var out: Array = []
	var z := place.substr(2)
	for s: float in [1.0, -1.0]:
		if place.begins_with("d:"):
			var back := Tram._turnout(z, -s)
			back.reverse()
			var line: Array = (_dstop(z).line as Array).duplicate()
			line.reverse()
			var m := {}
			m[z + (":+" if -s > 0.0 else ":-")] = 1.0
			m[z + ":f"] = 1.0 if -s > 0.0 else 0.0
			if z == "salvage":
				m["salvage:s"] = 1.0
			out.append({"tail": back.slice(1) + line.slice(1), "a": Tram._angle(z) - s * Tram._turn(z), "s": s, "sw": m, "hub": false})
		else:
			out.append({"tail": [], "a": hub_angle(z), "s": s, "sw": {}, "hub": true})
	return out


# candidate routes from where the train stands to `place`: [{legs: [{pts, sw}], cells, cost, lf, s}]
# `ext` m of loop past a hub stop the train will creep along to line its wagons up
static func routes(tr: Dictionary, place: String, wagons: Array = []) -> Array:
	# from a district stop the train always stands at the same place: the candidates keep
	if str(tr.place).begins_with("d:") and (tr.pos as Vector2).distance_to(_dstop(str(tr.place).substr(2)).head) < 0.05 * M():
		var key := "%s|%s|%s|%s" % [tr.place, place, tr.lf, str(wagons)]
		if not _routes.has(key):
			_routes[key] = _routes_from(tr, place, wagons)
		return _routes[key]
	# elsewhere (a hatch stop, a stop on the loop) by where it stands to 5 cm, and which way it faces
	var g := Vector2i(((tr.pos as Vector2) / (0.05 * M())).round())
	var key2 := "%s|%s|%s|%s|%s|%d" % [tr.place, g, place, tr.lf, str(wagons), _dir_on_loop(tr) if on_loop(tr.pos) else 0]
	if not _routes.has(key2):
		if _routes.size() > 600:
			_routes.clear()
		_routes[key2] = _routes_from(tr, place, wagons)
	return _routes[key2]


static func _routes_from(tr: Dictionary, place: String, wagons: Array = []) -> Array:
	var out: Array = []
	var clear := (body_back(tr) + body_front(tr) + 1.5) * M() / R()
	for st in _starts(tr):
		for en in _ends(place):
			var s1: float = st.s
			var s2: float = en.s
			for combo in ((["direct"] if s1 == s2 else ["b", "a"]).map(func(o): return [o, false]) + (["direct"] if s1 == s2 else ["b", "a"]).map(func(o): return [o, true])):
				var opt: String = combo[0]
				var inner: bool = combo[1]
				var lf := bool(tr.lf) != bool(st.rev)
				var legs: Array = []
				var revs := 1 if st.rev else 0
				if opt == "direct":
					var span := Tram._span(float(st.a), float(en.a), s1)
					var m: Dictionary = (st.sw as Dictionary).duplicate()
					m.merge(en.sw)
					Tram._passed(float(st.a), s1, span, m)
					var ar := _arc2(float(st.a), s1, span, inner)
					if inner and not (ar[1] as Dictionary).has("p1:a") or inner and float(ar[1].get("p1:a", 0.0)) == 0.0:
						continue
					m.merge(ar[1], true)
					legs.append({"pts": (st.pts as Array) + (ar[0] as Array) + (en.tail as Array), "sw": m})
				else:
					# change ends once on the loop: just past the start ("b") or just past where it is going ("a")
					var span1 := clear if opt == "b" else Tram._span(float(st.a), float(en.a), s1) + clear
					var r: float = float(st.a) + s1 * span1
					var m1: Dictionary = (st.sw as Dictionary).duplicate()
					Tram._passed(float(st.a), s1, span1, m1)
					var ar1 := _arc2(float(st.a), s1, span1, inner)
					m1.merge(ar1[1], true)
					legs.append({"pts": (st.pts as Array) + (ar1[0] as Array), "sw": m1})
					var span2 := Tram._span(r, float(en.a), s2)
					var m2: Dictionary = (en.sw as Dictionary).duplicate()
					Tram._passed(r, s2, span2, m2)
					var ar2 := _arc2(r, s2, span2, inner)
					if inner and float(ar1[1].get("p1:a", 0.0)) == 0.0 and float(ar2[1].get("p1:a", 0.0)) == 0.0:
						continue
					m2.merge(ar2[1], true)
					legs.append({"pts": [Tram._loop_pt(r)] + (ar2[0] as Array) + (en.tail as Array), "sw": m2})
					revs += 1
					lf = not lf
				# a degenerate leg (standing where it is going)
				var length := 0.0
				for l in legs:
					length += TramArt.length(l.pts)
				# (the cells it runs over are worked out only for the candidates looked at: rc_of)
				# at a hub stop: the stretch it creeps along to bring each wagon to the hatch
				var need := 0.0
				var xp: Array = []
				if en.hub:
					var probe := {"lf": lf}
					for wi in wagons:
						need = maxf(need, wagon_off(probe, int(wi)))
					var ext := (need + (LOCO_L if lf else WAGON_L) * 0.5 + 1.0) * M() / R()
					var a_end: float = en.a
					xp = [Tram._loop_pt(a_end)] + Tram._arc(a_end, s2, ext)
				# never standing on the hub stop's stretch (running past it is fine: the shuttle standing
				# there holds its own cells)
				if en.hub:
					var bad := false
					var ban := banned()
					var tail: Array = _tail_pts(legs[-1].pts, (need + 14.0) * M()) + xp.slice(1)
					for c in cells(tail):
						if ban.has(c[1]):
							bad = true
							break
					if bad:
						if debug:
							print("        route %s s1=%d s2=%d inner=%s -> %s banned" % [opt, s1, s2, inner, place])
						continue
				if debug:
					print("        route %s s1=%d s2=%d inner=%s -> %s cost %.0f" % [opt, s1, s2, inner, place, length / M() + REVERSE_COST * revs])
				out.append({"legs": legs, "xp": xp, "cost": length / M() + REVERSE_COST * revs + (3.0 if inner else 0.0), "lf": lf, "s": s2, "place": place, "need": need})
	out.sort_custom(func(a, b): return float(a.cost) < float(b.cost))
	return out


# a candidate's cells by distance along it, worked out the first time they are wanted (kept with it)
static func rc_of(rt: Dictionary) -> Array:
	if not rt.has("cells"):
		var cl: Array = []
		var s0 := 0.0
		for l in rt.legs:
			cl.append_array(cells(l.pts, s0))
			s0 += TramArt.length(l.pts)
		if not (rt.xp as Array).is_empty():
			cl.append_array(cells(rt.xp, s0))
		rt.cells = cl
	return rt.cells


# the last `length` px of a polyline
static func _tail_pts(pts: Array, length: float) -> Array:
	var out: Array = [pts[-1]]
	var acc := 0.0
	for i in range(pts.size() - 1, 0, -1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i - 1]
		var d := a.distance_to(b)
		if acc + d >= length:
			out.push_front(a.lerp(b, (length - acc) / maxf(d, 0.001)))
			return out
		out.push_front(b)
		acc += d
	return out


static func _free(tr_id: int, cl: Array, body: Array, mind_pending := true) -> bool:
	for c in cl:
		var k: Vector2i = c[1]
		if mind_pending and pending.has(k) and tr_id != PASSENGER:
			return false
		var o = claims.get(k)
		if o != null and int(o) != tr_id:
			return false
	for c in body:
		var o2 = claims.get(c[1])
		if o2 != null and int(o2) != tr_id:
			return false
	return true


static func _release(id: int) -> void:
	for k in claims.keys():
		if int(claims[k]) == id:
			claims.erase(k)


static func _claim(id: int, cl: Array) -> void:
	for c in cl:
		if not claims.has(c[1]):
			claims[c[1]] = id


# ------------------------------------------------------------------ the shuttle's side (scripts/tram.gd)
static func _tram_body(tr) -> Array:
	var pts: Array = []
	var p: Vector2 = tr.position_px
	var h := Vector2.from_angle(float(tr.heading))
	pts.append(p + h * 2.4 * M())
	pts.append(p)
	var back: Vector2 = tr._behind(Tram.COUPLE * Geom.M) if not (tr.trail as Array).is_empty() else p - h * Tram.COUPLE * M()
	pts.append(back)
	pts.append(back - (p - back).normalized() * 2.4 * M())
	return cells(pts, 0.0, 1.0)


# the shuttle is to run these legs: it waits until no freight holds any of it, freight giving way
static func passenger_request(tr, legs: Array) -> void:
	if not on:
		return
	pending = {}
	follow = {}
	_p_pts = []
	var s0 := 0.0
	for l in legs:
		for c in cells(l.pts, s0, 1.0):
			pending[c[1]] = true
		s0 += TramArt.length(l.pts)
		_p_pts.append_array(l.pts)
	for c in _tram_body(tr):
		pending[c[1]] = true
	_pending_t = t


# true when the shuttle may go (its route claimed)
static func passenger_go(tr) -> bool:
	if not on or pending.is_empty():
		return true
	var ahead := {}
	for k in pending:
		var o = claims.get(k)
		if o != null and int(o) != PASSENGER:
			# a freight train going the same way ahead of it, out of its way by the time it gets
			# there: the shuttle follows it (block by block behind it, see `follow`)
			if ahead.has(int(o)) or (int(o) < trains.size() and _runs_ahead(trains[int(o)])):
				ahead[int(o)] = true
				continue
			wait_now = t - _pending_t
			max_wait = maxf(max_wait, wait_now)
			why = int(o)
			return false
	why = -9
	_release(PASSENGER)
	follow = {}
	for k in pending:
		if claims.has(k):
			follow[k] = true
		else:
			claims[k] = PASSENGER
	wait_now = t - _pending_t
	max_wait = maxf(max_wait, wait_now)
	pending = {}
	return true


static func passenger_arrived(tr) -> void:
	if not on:
		return
	follow = {}
	_release(PASSENGER)
	_claim(PASSENGER, _tram_body(tr))


# ------------------------------------------------------------------ moving
static func _set_path(tr: Dictionary, points: Array) -> void:
	var sm := Tram.smooth(points)
	var k := sqrt(A_LAT / (Tram.A_LAT / Geom.M))
	var pts: Array = sm[0]
	var lim: Array = []
	for v in sm[1]:
		lim.append(minf(float(v) * k, V_MAX * M()))
	if not pts.is_empty() and (pts[0] as Vector2).distance_to(tr.pos) < 1.0:
		pts.pop_front()
		lim.pop_front()
	tr.path = pts
	tr.limits = lim
	if not pts.is_empty():
		var d := ((pts[0] as Vector2) - (tr.pos as Vector2)).normalized()
		if d.dot(Vector2.from_angle(float(tr.heading))) < -0.5:
			_reverse(tr)


# push-pull: the driver changes ends, the far car becomes the head
static func _reverse(tr: Dictionary) -> void:
	var back := 8.7 * M()
	var rear := behind(tr, back)
	var seg: Array = [tr.pos]
	var left := back
	var prev: Vector2 = tr.pos
	for p in tr.trail:
		var d: float = prev.distance_to(p)
		if d >= left:
			break
		seg.append(p)
		left -= d
		prev = p
	var fwd := Vector2.from_angle(float(tr.heading))
	var nt: Array = []
	for i in range(seg.size() - 1, -1, -1):
		nt.append(seg[i])
	for k in range(1, 17):
		nt.append((tr.pos as Vector2) + fwd * k * 0.25 * M())
	tr.trail = nt
	tr.pos = rear
	tr.heading = (-fwd).angle()
	tr.lf = not bool(tr.lf)
	tr.hold = maxf(float(tr.hold), HOLD)
	var path: Array = tr.path
	while not path.is_empty() and ((path[0] as Vector2) - (tr.pos as Vector2)).dot(-fwd) <= 0.0:
		path.pop_front()
		if not (tr.limits as Array).is_empty():
			(tr.limits as Array).pop_front()


# along the rails: true once at the end of the path. Speeds up and brakes gently (jerk-limited),
# creeping the last metres
static func _advance(tr: Dictionary, dt: float) -> bool:
	var path: Array = tr.path
	if path.is_empty():
		tr.moving = false
		return true
	# the leg's switches set before it sets off (once under way, those behind it are others' to throw)
	if float(tr.hold) > 0.0 or (not bool(tr.get("sw_done", false)) and not _sw_ready(tr.leg_sw)):
		tr.hold = float(tr.hold) - dt
		tr.speed = 0.0
		tr.acc = 0.0
		tr.moving = false
		return false
	tr.sw_done = true
	var Mx := M()
	var cap := V_MAX * Mx
	var dist := 0.0
	var prev: Vector2 = tr.pos
	var lim: Array = tr.limits
	for i in path.size():
		dist += prev.distance_to(path[i])
		prev = path[i]
		var l: float = lim[i] if i < lim.size() else 0.0
		if i == path.size() - 1:
			l = 0.0
		var c := sqrt(l * l + 2.0 * A_BRAKE * Mx * dist)
		if i == path.size() - 1:
			c = minf(c, CREEP * dist + 0.12 * Mx)
		cap = minf(cap, c)
		if dist > (V_MAX * V_MAX / (2.0 * A_BRAKE) + 2.0) * Mx:
			break
	var auth := float(tr.get("auth_left", INF))
	if auth < INF:
		var room := maxf(0.0, auth - 0.5 * Mx)
		cap = minf(cap, minf(sqrt(2.0 * A_BRAKE * Mx * room), CREEP * room + (0.02 * Mx if room > 0.05 * Mx else 0.0)))
	var v: float = tr.speed
	var a_want := clampf((cap - v) * 1.6, -A_MAX * Mx, A_MAX * Mx)
	var a := move_toward(float(tr.acc), a_want, JERK * Mx * dt)
	v = clampf(v + a * dt, 0.0, cap + 0.02 * Mx)
	if v > cap:
		v = cap
	tr.acc = a
	tr.speed = v
	tr.moving = v > 0.001
	var step := v * dt
	tr.s_run = float(tr.s_run) + step
	while step > 0.0 and not path.is_empty():
		var wp: Vector2 = path[0]
		var d := wp - (tr.pos as Vector2)
		if d.length() <= step:
			step -= d.length()
			tr.pos = wp
			path.pop_front()
			if not lim.is_empty():
				lim.pop_front()
		else:
			tr.pos = (tr.pos as Vector2) + d.normalized() * step
			step = 0.0
	var hb := ahead(tr, 1.0 * Mx) - behind(tr, 1.0 * Mx)
	if hb.length() > 0.01:
		tr.heading = hb.angle()
	var trail: Array = tr.trail
	if trail.is_empty() or (trail[0] as Vector2).distance_to(tr.pos) > 0.25 * Mx:
		trail.push_front(tr.pos)
		if trail.size() > 70:
			trail.pop_back()
	# the path's end reached at a crawl: stand
	if path.is_empty() or ((path.size() == 1) and (tr.pos as Vector2).distance_to(path[0]) < 0.01 * Mx and v < 0.05 * Mx):
		if not path.is_empty():
			tr.pos = path[0]
			path.clear()
		tr.speed = 0.0
		tr.acc = 0.0
		tr.moving = false
		return true
	return false


# moving into the shuttle's wanted route: stop on the loop a little before it (if it can brake in time),
# drop the rest of the route and claims; it plans again from there when it stands
static func _cut_short(tr: Dictionary, st: Dictionary) -> void:
	if bool(st.get("cut", false)) or _leaving_pending(tr):
		return
	var path: Array = tr.path
	var Mx := M()
	var brake := float(tr.speed) * float(tr.speed) / (2.0 * A_BRAKE * Mx) + 2.5 * Mx
	var dist := 0.0
	var prev: Vector2 = tr.pos
	var hit := -1
	var pts: Array = [prev]
	for i in path.size():
		var q: Vector2 = path[i]
		var seg := prev.distance_to(q)
		# sample the segment for the shuttle's cells
		var n := maxi(1, int(seg / (0.5 * Mx)))
		var found := false
		for k in range(1, n + 1):
			var r := prev.lerp(q, float(k) / n)
			if pending.has(_key(r)):
				found = true
				break
		if found:
			hit = i
			break
		dist += seg
		pts.append(q)
		prev = q
	var later_hit := false
	if hit < 0:
		# the next legs (after a change of ends) may cross it: then stop at this leg's end
		for lg in tr.legs:
			for c in cells(lg.pts, 0.0, 1.0):
				if pending.has(c[1]):
					later_hit = true
					break
			if later_hit:
				break
		if not later_hit:
			return
		if (tr.path as Array).is_empty() or not on_loop((tr.path as Array)[-1]):
			_retreat(tr, st)
			return
	else:
		# stand a couple of metres short of it, if there is room to brake and that is on the loop
		# already in it or too close to stop short: stop as soon as it can (then it slides clear)
		var stop_at := maxf(dist - 2.0 * Mx, brake)
		var cut: Array = []
		var acc := 0.0
		var pv: Vector2 = tr.pos
		for q in pts.slice(1):
			var sg: float = pv.distance_to(q)
			if acc + sg >= stop_at:
				cut.append(pv.lerp(q, (stop_at - acc) / maxf(sg, 0.001)))
				break
			cut.append(q)
			acc += sg
			pv = q
		if cut.is_empty() or not on_loop(cut[-1]):
			_retreat(tr, st)
			return
		var lim: Array = []
		for i in cut.size():
			lim.append(float(tr.limits[i]) if i < (tr.limits as Array).size() else V_MAX * Mx)
		lim[-1] = 0.0
		tr.path = cut
		tr.limits = lim
	tr.legs = []
	st.cut = true
	tr.auth_full = true
	tr.auth_left = INF
	# its claims: what it stands on and the stretch still to run
	_release(int(tr.id))
	var cl: Array = body_cells(tr)
	cl.append_array(cells([tr.pos] + (tr.path as Array)))
	_claim(int(tr.id), cl)
	_set_route(tr, cl)
	tr.status = w("让接驳车先过", "LETTING THE SHUTTLE BY")


# off the loop and in the shuttle's way: back the way it came to the stop it set off from
static func _retreat(tr: Dictionary, st: Dictionary) -> void:
	var from := str(tr.get("route_from", ""))
	var rp: Array = tr.get("route_pts", [])
	if not from.begins_with("d:") or rp.size() < 2:
		return
	# past a change of ends: back only to it (retracing the whole way would take far longer)
	if int(tr.get("leg_i", 0)) > 0:
		_back_off(tr)
		return
	var best := _route_index(tr, rp)
	var back: Array = [tr.pos]
	for i in range(best, -1, -1):
		back.append(rp[i])
	var body := body_cells(tr)
	var cl := cells(back)
	if not _free(int(tr.id), cl, body, false):
		return
	yields += 1
	_release(int(tr.id))
	cl.append_array(body)
	_claim(int(tr.id), cl)
	_set_route(tr, cl)
	tr.s_run = 0.0
	tr.legs = _split_legs(back)
	tr.auth_full = true
	tr.auth_left = INF
	tr.leg_s = []
	_next_leg(tr)
	tr.steps.push_front(st.duplicate())
	(tr.steps[0] as Dictionary).erase("routed")
	(tr.steps[0] as Dictionary).erase("cut")
	tr.step = {"do": "go", "place": from, "routed": true, "must": true, "t": 0.0, "say": w("退回让接驳车先过", "BACKING UP FOR THE SHUTTLE")}
	tr.status = w("退回让接驳车先过", "BACKING UP FOR THE SHUTTLE")


# where along its route the train is: the last route point it has passed, by the distance it has run
# (a reversing route passes the same place twice, so the nearest point will not do)
static func _route_index(tr: Dictionary, rp: Array) -> int:
	var sr := float(tr.get("s_run", 0.0))
	var acc := 0.0
	var best := 0
	for i in range(1, rp.size()):
		acc += (rp[i - 1] as Vector2).distance_to(rp[i])
		if acc > sr + 0.05 * M():
			break
		best = i
	return best


# a hand-made way back cut into legs where it turns back on itself (each reversal its own leg)
static func _split_legs(pts: Array) -> Array:
	var legs: Array = []
	var cur: Array = [pts[0]]
	var d0 := Vector2.ZERO
	for i in range(1, pts.size()):
		var p: Vector2 = pts[i]
		var q: Vector2 = cur[-1]
		if p.distance_to(q) < 0.001:
			continue
		var d := (p - q).normalized()
		if d0 != Vector2.ZERO and d.dot(d0) < -0.3 and cur.size() > 1:
			legs.append({"pts": cur, "sw": {}})
			cur = [q]
		cur.append(p)
		d0 = d
	legs.append({"pts": cur, "sw": {}})
	return legs


# a cell of the main loop's track (not the passing loop's inner track, not a corridor), worked out once
static var _ring_cells := {}
static func _ring_cell(k: Vector2i) -> bool:
	if not _ring_cells.has(k):
		var p := (Vector2(k) + Vector2(0.5, 0.5)) * CELL * M()
		var r := (p - centre()).length() / M()
		_ring_cells[k] = absf(r - Tram.LOOP_R) < 1.6
	return _ring_cells[k]


# per route cell: 1 where the route runs on the main loop (any cell within 1.5 m along it is the loop's)
static var ring_section := true   # tests: false cuts the loop into BLOCK m blocks like the corridors
static func _ring_flags(rc: Array) -> PackedByteArray:
	var n := rc.size()
	if not ring_section:
		var z := PackedByteArray()
		z.resize(n)
		return z
	var raw := PackedByteArray()
	raw.resize(n)
	for i in n:
		raw[i] = 1 if _ring_cell(rc[i][1]) else 0
	var out := PackedByteArray()
	out.resize(n)
	var w := 1.5 * M()
	var lo := 0
	var hi := 0
	var cnt := 0
	for i in n:
		var si := float(rc[i][0])
		while hi < n and float(rc[hi][0]) <= si + w:
			cnt += raw[hi]
			hi += 1
		while lo < n and float(rc[lo][0]) < si - w:
			cnt -= raw[lo]
			lo += 1
		out[i] = 1 if cnt > 0 else 0
	return out


# in the shuttle's wanted route now, on a way that ends out of it
static func _leaving_pending(tr: Dictionary) -> bool:
	if pending.is_empty() or not tr.has("rcells") or (tr.rcells as Array).is_empty():
		return false
	var inside := false
	for c in body_cells(tr):
		if pending.has(c[1]):
			inside = true
			break
	if not inside:
		return false
	# out of it soon: the last of its way still in the shuttle's route is close ahead
	var rc: Array = tr.rcells
	var sr := float(tr.s_run)
	var last := -INF
	for c in rc:
		if float(c[0]) >= sr and pending.has(c[1]):
			last = float(c[0])
	if last == -INF:
		return true
	if last - sr > 25.0 * M():
		return false
	# and where it stops, none of it in the shuttle's route
	var s_end := float(rc[-1][0])
	var body := (body_back(tr) + body_front(tr) + 1.0) * M()
	return last < s_end - body


# the shuttle may set off behind this train: it runs the shuttle's way ahead of it, holds its track
# right to its stop, will stand clear of the shuttle's route there, and stays far enough ahead
static func _runs_ahead(tr: Dictionary) -> bool:
	if _p_pts.size() < 2 or not tr.has("rcells") or int(tr.rc_i) < (tr.rcells as Array).size():
		return false
	if not bool(tr.step.get("routed", false)) or str(tr.step.get("do", "")) != "go":
		return false
	var rc: Array = tr.rcells
	var Mx := M()
	# where it will stand: none of it on the shuttle's route
	var s_end := float(rc[-1][0])
	var body := (body_back(tr) + body_front(tr) + 2.0) * Mx
	for k in range(rc.size() - 1, -1, -1):
		if float(rc[k][0]) < s_end - body:
			break
		if pending.has(rc[k][1]):
			return false
	# going the shuttle's way: its head further along the shuttle's route than its tail
	var acc: Array = [0.0]
	for i in range(1, _p_pts.size()):
		acc.append(float(acc[-1]) + (_p_pts[i - 1] as Vector2).distance_to(_p_pts[i]))
	var near := func(p: Vector2) -> int:
		var bi := 0
		var bd := INF
		for i in _p_pts.size():
			var d: float = (_p_pts[i] as Vector2).distance_to(p)
			if d < bd:
				bd = d
				bi = i
		return bi
	var ih: int = near.call(tr.pos)
	var it: int = near.call(behind(tr, body_back(tr) * Mx))
	if ih <= it:
		return false
	# far enough ahead: the shuttle (from standing, 6 m/s² up to 20 m/s) does not reach its tail in
	# the time it takes to run on to its stop
	var left := s_end - float(tr.s_run)
	var tf := left / maxf(float(tr.speed), 6.0 * Mx) + 2.0
	var reach := minf(0.5 * Tram.ACCEL * tf * tf, Tram.SPEED * tf)
	return float(acc[it]) - 4.0 * Mx > reach


# train `o` runs ahead of this one the same way (it can be followed block by block)
static func _same_way_ahead(tr: Dictionary, o: int) -> bool:
	if o < 0 or o >= trains.size():
		return false
	var b: Dictionary = trains[o]
	if not b.moving or not bool(b.step.get("routed", false)):
		return false
	var h := Vector2.from_angle(float(tr.heading))
	var hb := Vector2.from_angle(float(b.heading))
	return h.dot(hb) > 0.5 and ((b.pos as Vector2) - (tr.pos as Vector2)).dot(h) > 0.0


static func _hard_blocked(id: int, cl: Array, mind_pending: bool) -> bool:
	var parked := {}
	for c in cl:
		var k: Vector2i = c[1]
		var o = claims.get(k)
		if o != null and (int(o) == PASSENGER or parked.has(int(o))):
			return true
		if mind_pending and pending.has(k):
			return true
	return false


static func _deadlocks() -> void:
	var mid := Tram._loop_pt((PASS_A + PASS_B) * 0.5)
	for a in trains:
		if float(a.get("blocked_t", 0.0)) < DEADLOCK_T or a.get("blocker") == null or int(a.blocker) < 0:
			continue
		var bi := int(a.blocker)
		if bi >= trains.size():
			continue
		var b: Dictionary = trains[bi]
		var b_waits := float(b.get("blocked_t", 0.0)) >= DEADLOCK_T and b.get("blocker") != null and int(b.blocker) == int(a.id)
		# held by one that stands at a stop waiting for its own route: it also counts (it will not move)
		var b_stuck: bool = not b.moving and str(b.step.get("do", "")) == "go" and not bool(b.step.get("routed", false)) and float(b.get("wait", 0.0)) > DEADLOCK_T
		if not b_waits and not b_stuck:
			continue
		var da: float = (a.pos as Vector2).distance_to(mid)
		var db: float = (b.pos as Vector2).distance_to(mid)
		var first: Dictionary = a if (da <= db or b_stuck) else b
		var other: Dictionary = b if first == a else a
		if not _back_off(first):
			_back_off(other)
		a.blocked_t = 0.0
		b.blocked_t = 0.0


# back the way it came to where it set off from (or as far as it is clear), then think again
static func _back_off(tr: Dictionary) -> bool:
	var rp: Array = tr.get("route_pts", [])
	if rp.size() < 2:
		return false
	var best := _route_index(tr, rp)
	# back along the leg it is on only: to where it set off, or to the last place it changed ends
	var pi: Array = tr.get("leg_pi", [0])
	var li := clampi(int(tr.get("leg_i", 0)), 0, pi.size() - 1)
	var lo: int = pi[li]
	if best <= lo:
		return false
	var back: Array = [tr.pos]
	for i in range(best, lo - 1, -1):
		back.append(rp[i])
	var body := body_cells(tr)
	var cl := cells(back)
	if not _free(int(tr.id), cl, body, false):
		return false
	if debug:
		print("back_off #%d from=%s best=%d/%d back=%s" % [int(tr.id), tr.get("route_from"), best, rp.size(), back.map(func(v): return ((v as Vector2) - centre()) / M())])
	yields += 1
	var st: Dictionary = tr.step
	_release(int(tr.id))
	cl.append_array(body)
	_claim(int(tr.id), cl)
	_set_route(tr, cl)
	tr.auth_full = true
	tr.auth_left = INF
	tr.blocked_t = 0.0
	tr.s_run = 0.0
	tr.legs = _split_legs(back)
	tr.leg_s = []
	_next_leg(tr)
	var again := st.duplicate()
	again.erase("routed")
	again.erase("cut")
	tr.steps.push_front(again)
	var from := str(tr.get("route_from", "")) if li == 0 else ""
	tr.step = {"do": "go", "place": from if from != "" else ":slide", "routed": true, "must": true, "cut": from == "", "t": 0.0, "say": w("退回让对向车先过", "BACKING OFF FOR THE TRAIN COMING")}
	tr.status = w("退回让对向车先过", "BACKING OFF FOR THE TRAIN COMING")
	return true


# the route's cells by the furthest along each comes (released once the train is past it)
static func _set_route(tr: Dictionary, cl: Array) -> void:
	var km := {}
	for c in cl:
		var k: Vector2i = c[1]
		km[k] = maxf(float(km.get(k, -INF)), float(c[0]))
	tr.kmax = km


# free the cells the train has left behind it
static func _free_behind(tr: Dictionary) -> void:
	var km: Dictionary = tr.get("kmax", {})
	if km.is_empty():
		return
	var keep := {}
	for c in body_cells(tr):
		keep[c[1]] = true
	var lim := float(tr.s_run) - 0.5 * M()
	for k in km.keys():
		if float(km[k]) < lim and not keep.has(k):
			km.erase(k)
			if claims.get(k) == tr.id:
				claims.erase(k)


# ------------------------------------------------------------------ the steps of a job
# go to a place: claim a route, run it, stand and lock. true when there
static func _go(tr: Dictionary, st: Dictionary, dt: float) -> bool:
	if str(tr.place) == str(st.place):
		return true
	if not bool(st.get("routed", false)):
		tr.wait = float(tr.wait) + dt
		tr.status = st.get("say", tr.status)
		# a route looked for a couple of times a second, not every frame
		st.retry = float(st.get("retry", 0.0)) - dt
		if float(st.retry) > 0.0:
			if float(tr.wait) > WAIT_MAX and not bool(st.get("must", false)):
				st.failed = true
			return false
		st.retry = 0.4
		# one train looks for a route a frame (a search walks every candidate's cells: no hitches)
		if _planned_frame == _ticks:
			st.retry = 0.0
			return false
		_planned_frame = _ticks
		var body := body_cells(tr)
		var ok: Dictionary = {}
		# at a hub stop room to bring both wagons to the hatch if the loop allows, else the ones it needs
		var _pt0 := Time.get_ticks_usec()
		var cands := routes(tr, str(st.place), [0, 1]) if str(st.place).begins_with("h:") else []
		var only: Array = st.get("wagons", [])
		if cands.is_empty():
			cands = routes(tr, str(st.place), only)
		else:
			# the ones it needs, too: their shorter creep may miss what the longer one runs into (to
			# take a crate off, any one empty wagon will do)
			var more: Array = []
			if only.size() < 2:
				more = routes(tr, str(st.place), only)
			elif not (tr.steps as Array).is_empty() and str(tr.steps[0].get("do", "")) == "take":
				for wi in _empty(tr):
					more += routes(tr, str(st.place), [wi])
			if not more.is_empty():
				cands = cands + more
				cands.sort_custom(func(a, b): return float(a.cost) < float(b.cost))
		var mind := not bool(st.get("must", false))
		var best_c := INF
		var built := float(Time.get_ticks_usec() - _pt0)
		prof.routes = maxf(float(prof.get("routes", 0.0)), built)
		# just worked out (not kept from before): choose among them next frame
		if built > 1500.0:
			st.retry = 0.0
			return false
		_pt0 = Time.get_ticks_usec()
		var lim_first := AUTH_AHEAD * M()
		var ok_red := false
		var me := int(tr.id)
		var body_ok := true
		for c in body:
			var ob = claims.get(c[1])
			if ob != null and int(ob) != me:
				body_ok = false
		var out_of_time := false
		for rt in (cands if body_ok else []):
			# sorted by cost: a dearer one can't win once one is found (the penalty only adds)
			if float(rt.cost) >= best_c:
				break
			# a frame's share spent (each candidate's cells are kept with it): on next frame
			if Time.get_ticks_usec() - _pt0 > 2000 and not rt.has("cells"):
				out_of_time = true
				break
			# one pass: the first stretch must be clear now (the rest is taken block by block on the
			# way); the shuttle's track (where it stands, where it wants to go) is no signal to wait at,
			# the whole way must miss it; a way another train is on costs more (the passing loop's
			# inner track then wins)
			var others := 0
			var seen := -2
			var bad := false
			var at_red := false
			for c in rc_of(rt):
				var k: Vector2i = c[1]
				if (mind and pending.has(k)) or follow.has(k):
					bad = true
					break
				var o = claims.get(k)
				if o == null:
					continue
				var oi := int(o)
				if oi == me:
					continue
				# the shuttle standing still is no signal to wait at; the shuttle about to leave (its
				# route asked for) is: where it stands will be clear
				if oi == PASSENGER and pending.is_empty():
					bad = true
					break
				if float(c[0]) <= lim_first:
					at_red = true
				if oi != seen:
					seen = oi
					others += 1
			if debug:
				print("      #%d cand %.0f legs=%d bad=%s red=%s others=%d" % [me, float(rt.cost), (rt.legs as Array).size(), bad, at_red, others])
			if bad:
				continue
			var cst := float(rt.cost) + 40.0 * mini(others, 2)
			if cst < best_c:
				best_c = cst
				ok = rt
				ok_red = at_red
		# the best way's first block is held: wait at the signal for it (a real train doesn't go the
		# long way round because the short way is busy for a moment)
		if ok_red:
			ok = {}
		if out_of_time:
			ok = {}
			st.retry = 0.0
		prof.choose = maxf(float(prof.get("choose", 0.0)), float(Time.get_ticks_usec() - _pt0))
		if ok.is_empty():
			# held up by the shuttle standing idle: ask it to go back to the hub (scripts/tram.gd)
			if tram != null and is_instance_valid(tram) and str(tram.phase) == "" and str(tram.at) != "ring":
				for rt in cands:
					for c in rc_of(rt):
						if claims.get(c[1]) == PASSENGER:
							tram_clear = true
							break
					if tram_clear:
						break
			if debug:
				var who := {}
				for rt in cands:
					for c in rc_of(rt):
						var o = claims.get(c[1])
						if o != null and int(o) != int(tr.id):
							who[int(o)] = true
				print("    [freight] #%d no route %s -> %s: %d candidates, blocked by %s" % [tr.id, tr.place, st.place, cands.size(), who.keys()])
				for rt in cands:
					var bl := {}
					for c in rc_of(rt):
						var o = claims.get(c[1])
						if o != null and int(o) != int(tr.id):
							var an := int(rad_to_deg(((Vector2(c[1]) + Vector2(0.5, 0.5)) * CELL * M() - centre()).angle()))
							var r := int(((Vector2(c[1]) + Vector2(0.5, 0.5)) * CELL * M() - centre()).length() / M())
							bl["%d@%d°r%d" % [int(o), an, r]] = true
					print("      cand cost %.0f: %s" % [float(rt.cost), bl.keys().slice(0, 6)])
			if float(tr.wait) > WAIT_MAX and not bool(st.get("must", false)):
				st.failed = true
			return false
		tr.wait = 0.0
		# the cells it stands on stay its own until its tail has left them
		_release(int(tr.id))
		var cl: Array = []
		for c in body:
			cl.append([float(c[0]), c[1]])
		_claim(int(tr.id), cl)
		_set_route(tr, cl + (rc_of(ok) as Array))
		tr.rcells = rc_of(ok)
		tr.rflag = _ring_flags(rc_of(ok))
		tr.rc_i = 0
		tr.auth_full = false
		tr.blocked_t = 0.0
		tr.blocker = null
		var ls: Array = []
		var acc := 0.0
		for lg in ok.legs:
			ls.append(acc)
			acc += TramArt.length(lg.pts)
		tr.leg_s = ls
		tr.leg_i = -1
		tr.need = float(ok.get("need", 0.0))
		tr.s_run = 0.0
		tr.legs = (ok.legs as Array).duplicate()
		_extend(tr, mind)
		tr.route_from = str(tr.place)
		var rp: Array = []
		var pi: Array = []
		for lg in ok.legs:
			pi.append(rp.size())
			rp.append_array(lg.pts)
		tr.route_pts = rp
		tr.leg_pi = pi
		st.routed = true
		st.lf = ok.lf
		tr.place = ""
		_next_leg(tr)
		return false
	_extend(tr, not bool(st.get("must", false)), dt)
	var done := _advance(tr, dt)
	if tr.moving or float(tr.hold) <= 0.0:
		_free_behind(tr)
	if not done:
		return false
	if not (tr.legs as Array).is_empty():
		_next_leg(tr)
		tr.hold = HOLD
		return false
	if bool(st.get("cut", false)):
		# stopped short for the shuttle: where it stands is no stop; plan again from here
		tr.place = ""
		_stand(tr)
		if str(st.place) == ":slide":
			# a slide out of the way: done; its job is thought out again
			return true
		st.cut = false
		st.routed = false
		st.retry = 0.5
		return false
	tr.place = str(st.place)
	_stand(tr)
	return true


# standing: only the cells under it stay its own (and, at a hub stop, the stretch it creeps along)
static func _stand(tr: Dictionary) -> void:
	var keep: Array = body_cells(tr)
	if str(tr.place).begins_with("h:"):
		var d := _dir_on_loop(tr)
		var a := angle_of(tr.pos)
		var ext := (float(tr.get("need", 0.0)) + (LOCO_L if bool(tr.lf) else WAGON_L) * 0.5 + 1.0) * M() / R()
		keep.append_array(cells([Tram._loop_pt(a)] + Tram._arc(a, d, ext)))
	_release(int(tr.id))
	_claim(int(tr.id), keep)
	tr.kmax = {}


# the next blocks ahead, as far as it could brake and AUTH_AHEAD beyond, each taken whole if nobody
# holds any of it (nor, mind_pending, the shuttle wants it): auth_left is how far it may run
static func _extend(tr: Dictionary, mind_pending: bool, dt := 0.0) -> void:
	if bool(tr.get("auth_full", true)) or not tr.has("rcells"):
		tr.auth_left = INF
		return
	var Mx := M()
	var id := int(tr.id)
	var rc: Array = tr.rcells
	var i: int = tr.rc_i
	# already standing in the shuttle's way, and going somewhere out of it: go on out (the shuttle
	# waits for it either way; stopping here would keep both waiting)
	if mind_pending and _leaving_pending(tr):
		mind_pending = false
	var want := float(tr.s_run) + float(tr.speed) * float(tr.speed) / (2.0 * A_BRAKE * Mx) + AUTH_AHEAD * Mx
	var held_up := false
	while i < rc.size() and float(rc[i][0]) <= want:
		var bend := float(rc[i][0]) + BLOCK * Mx
		# the main loop is single track with no place to pass but the passing loop: the whole stretch
		# of it a train is to run (out, round and back) is one section, taken whole or not at all;
		# the corridors are cut into BLOCK m blocks, so trains follow one another down them
		var rf: PackedByteArray = tr.rflag
		var ring := rf[i] == 1
		# a corridor is single track too: taken whole while nobody is in it; with a train in it going
		# the same way ahead, the corridor's blocks are taken one by one behind it (following); one
		# coming the other way or standing in it: wait
		var whole := false
		if not ring:
			var jc := i
			var follow_ok := true
			var anyone := false
			while jc < rc.size() and rf[jc] == 0:
				var oc = claims.get(rc[jc][1])
				if oc != null and int(oc) != id:
					anyone = true
					if not _same_way_ahead(tr, int(oc)):
						follow_ok = false
						tr.blocker = int(oc)
						break
				jc += 1
			if anyone and not follow_ok:
				held_up = true
				break
			whole = not anyone
		# into the loop's section only with the way out of it at the far end as well (a train must not
		# stand on the loop waiting for a corridor one in the corridor waits to bring onto the loop)
		if ring:
			var je := i
			while je < rc.size() and rf[je] == 1:
				je += 1
			var exit_ok := true
			var jx := je
			while jx < rc.size() and rf[jx] == 0:
				var ox = claims.get(rc[jx][1])
				if ox != null and int(ox) != id and not _same_way_ahead(tr, int(ox)):
					exit_ok = false
					tr.blocker = int(ox)
					break
				jx += 1
			if not exit_ok:
				held_up = true
				break
		var j := i
		var clear := true
		while j < rc.size() and ((rf[j] == 1) if (ring or whole) else (float(rc[j][0]) <= bend and rf[j] == 0)):
			var k: Vector2i = rc[j][1]
			var o = claims.get(k)
			if o != null and int(o) != id:
				clear = false
				tr.blocker = int(o)
				break
			if (mind_pending and pending.has(k)) or follow.has(k):
				clear = false
				tr.blocker = PASSENGER
				break
			j += 1
		if not clear:
			held_up = true
			break
		if j == i:
			j = i + 1
		for x in range(i, j):
			if not claims.has(rc[x][1]):
				claims[rc[x][1]] = id
		i = j
	tr.rc_i = i
	if i >= rc.size():
		tr.auth_left = INF
	else:
		var auth_s: float = float(rc[i - 1][0]) if i > 0 else 0.0
		tr.auth_left = auth_s - float(tr.s_run)
	# at danger: standing at the end of what it holds
	if held_up and float(tr.auth_left) < 1.5 * Mx and float(tr.speed) < 0.1 * Mx:
		tr.blocked_t = float(tr.get("blocked_t", 0.0)) + dt
		tr.status = w("信号停车：前方区段有车", "HELD AT A SIGNAL: THE BLOCK AHEAD IS OCCUPIED")
	else:
		tr.blocked_t = 0.0
		if not held_up:
			tr.blocker = null


static func _next_leg(tr: Dictionary) -> void:
	var lg: Dictionary = (tr.legs as Array).pop_front()
	tr.leg_sw = lg.sw
	tr.sw_done = false
	tr.leg_i = int(tr.get("leg_i", -1)) + 1
	for id in lg.sw:
		_sw_set(str(id), float(lg.sw[id]))
	_set_path(tr, lg.pts)
	var ls: Array = tr.get("leg_s", [])
	if int(tr.leg_i) < ls.size() and not (lg.pts as Array).is_empty():
		tr.s_run = float(ls[int(tr.leg_i)]) + ((lg.pts as Array)[0] as Vector2).distance_to(tr.pos)


# creep along the loop so wagon `wi` stands at the hatch of `z`. true when it does
static func _align(tr: Dictionary, z: String, wi: int, dt: float) -> bool:
	if (tr.path as Array).is_empty() and not bool(tr.get("creeping", false)):
		var d := _dir_on_loop(tr)
		var want := hub_angle(z) + d * wagon_off(tr, wi) * M() / R()
		var now := angle_of(tr.pos)
		var span := wrapf(d * (want - now), -PI, PI)
		if span * R() < 0.03 * M():
			return true
		tr.creeping = true
		tr.leg_sw = {}
		var pts: Array = [tr.pos] + Tram._arc(now, d, span)
		_set_path(tr, pts)
		return false
	var done := _advance(tr, dt)
	if done:
		tr.creeping = false
	return false


# ------------------------------------------------------------------ the dispatcher
static func want_count() -> int:
	if W.demo:
		return 3
	if Career.data.is_empty():
		return 1
	var ring := Port.stage("ring")
	var one := 0
	var two := 0
	for z in ["power", "salvage", "process", "tug", "trade", "cargo"]:
		if Port.stage(z) >= 1:
			one += 1
		if Port.stage(z) >= 2:
			two += 1
	if ring >= 2 and two >= 4:
		return 3
	if ring >= 1 and one >= 3:
		return 2
	return 1


static func ring_alive() -> bool:
	return W.stage >= 1


static func _targeted(place: String, me: int) -> bool:
	for tr in trains:
		if int(tr.id) == me:
			continue
		for s in tr.steps:
			if str(s.get("place", "")) == place:
				return true
		if str(tr.step.get("place", "")) == place or str(tr.place) == place:
			return true
	return false


static func _cargo(tr: Dictionary) -> Array:
	var out: Array = []
	for i in 2:
		if tr.wag[i] != null:
			out.append(i)
	return out


static func _empty(tr: Dictionary) -> Array:
	var out: Array = []
	for i in 2:
		if tr.wag[i] == null:
			out.append(i)
	return out


static func name_of(z: String) -> String:
	return Port.name_of(z)


# a stop is taken: another train stands there, or is on its way (or, both waiting, has the lower number)
static func _occupied(place: String, me: int) -> bool:
	for o in trains:
		if int(o.id) == me:
			continue
		if str(o.place) == place:
			return true
		var os: Dictionary = o.step
		if str(os.get("do", "")) == "go" and str(os.get("place", "")) == place and (bool(os.get("routed", false)) or int(o.id) < me):
			return true
	return false


# the train at `there` wants `here`
static func _swap(there: String, here: String, me: int) -> bool:
	for o in trains:
		if int(o.id) == me or str(o.place) != there:
			continue
		var want := str(o.step.get("place", "")) if str(o.step.get("do", "")) == "go" else ""
		if want == "" and not (o.steps as Array).is_empty():
			want = str(o.steps[0].get("place", ""))
		if want == here:
			return true
	return false


# a stop on the loop to wait at, nobody's
static func _holding(tr: Dictionary) -> String:
	var best := ""
	var bd := INF
	for z in ZONES:
		var p: String = "h:" + str(z)
		if _occupied(p, int(tr.id)) or _targeted(p, int(tr.id)):
			continue
		var d: float = (tr.pos as Vector2).distance_to(Tram._loop_pt(hub_angle(z)))
		if d < bd:
			bd = d
			best = p
	return best


# a district stop nobody stands at or is heading for, its home first
static func _free_district(tr: Dictionary, not_this := "") -> String:
	var order_z: Array = [str(tr.home)] + HOMES + ZONES
	for z in order_z:
		var p: String = "d:" + str(z)
		if p == str(tr.place) or p == not_this:
			continue
		if not _occupied(p, int(tr.id)) and not _targeted(p, int(tr.id)):
			return p
	return ""


static func _place_name(p: String) -> String:
	return (w("中央环%s舱口", "THE RING'S %s HATCH") % name_of(p.substr(2))) if p.begins_with("h:") else name_of(p.substr(2))


# what this train does next
static func _assign(tr: Dictionary) -> void:
	if ring_alive():
		_assign_corridor(tr)
		return
	var id := int(tr.id)
	var held := _cargo(tr)
	tr.from = ""
	tr.to = ""
	if not held.is_empty():
		var c: Dictionary = tr.wag[held[0]]
		if str(c.leg) == "in" and ring_alive():
			var z := str(c.from)
			tr.from = z
			tr.to = str(c.to)
			# off to the hatch only once it will take a crate (standing on the loop blocks it)
			if not W.hatch_takes(z):
				tr.status = w("等%s舱口空出", "WAITING FOR THE %s HATCH") % name_of(z)
				tr.backoff = 0.5
				return
			tr.steps = [{"do": "go", "place": "h:" + z, "wagons": held, "say": w("开往中央环 · %s舱口", "TO THE RING · %s HATCH") % name_of(z)},
				{"do": "push", "z": z}]
			tr.hub = z
			W.reserved[z] = int(tr.id)
		else:
			# a crate to bring down to its district (or straight there while the ring is dead)
			var to := str(c.to)
			tr.from = str(c.from)
			tr.to = to
			tr.steps = [{"do": "go", "place": "d:" + to, "say": w("开往%s", "TO %s") % name_of(to)}, {"do": "unload"}]
		return
	# a crate waiting at a hatch (or about to be)
	if ring_alive():
		for z in _near_first(tr):
			if W.hatch_out(z) != null and not _targeted("h:" + z, id) and not _free_at("d:" + z, id):
				tr.from = "ring"
				tr.to = z
				tr.hub = z
				tr.steps = [{"do": "go", "place": "h:" + z, "wagons": [_empty(tr)[0]], "say": w("去中央环取货 · %s舱口", "TO THE RING FOR A CRATE · %s") % name_of(z)},
					{"do": "take", "z": z}]
				return
	# a shipment
	var pick := -1
	for i in queue.size():
		var f := "d:" + str(queue[i].from)
		if f == str(tr.place):
			pick = i
			break
		if pick < 0 and not _free_at(f, id) and not _targeted(f, id):
			pick = i
	if pick >= 0:
		var sh: Dictionary = queue[pick]
		queue.remove_at(pick)
		var items: Array = [sh]
		for o in queue.duplicate():
			if items.size() >= 2:
				break
			if str(o.from) == str(sh.from) and (not ring_alive() and str(o.to) == str(sh.to) or ring_alive()):
				items.append(o)
				queue.erase(o)
		var leg := "in" if ring_alive() else "out"
		for it in items:
			it.leg = leg
		tr.from = str(sh.from)
		tr.to = str(sh.to)
		tr.steps = [{"do": "go", "place": "d:" + str(sh.from), "say": w("开往%s装货", "TO %s TO LOAD") % name_of(str(sh.from))}, {"do": "load", "items": items}]
		return
	# nothing to do: it stays in the corridor it is in (130 号: every lap of the loop is a lap the
	# shuttle may wait on); one left on the loop goes back down the nearest corridor
	if str(tr.place).begins_with("h:") or str(tr.place) == "":
		var back := "d:" + str(tr.place).substr(2) if str(tr.place).begins_with("h:") else _free_district(tr)
		if _occupied(back, id) or _targeted(back, id):
			back = _free_district(tr)
		if back != "":
			tr.steps = [{"do": "go", "place": back, "say": w("回%s走廊待命", "BACK INTO THE %s CORRIDOR") % name_of(back.substr(2))}]
			return
	tr.status = w("待命", "STANDING BY")


# the ring running: this train's own corridor and hatch
static func _assign_corridor(tr: Dictionary) -> void:
	var z := str(tr.home)
	var held := _cargo(tr)
	# a sale: the cargo district's train runs it out to the trade port itself, first of all
	if z == "cargo" and held.is_empty():
		for it in queue:
			if bool(it.get("sell", false)):
				queue.erase(it)
				it.leg = "in"
				tr.from = "cargo"
				tr.to = "trade"
				tr.steps = [{"do": "go", "place": "d:cargo", "say": w("回货运区装上卖出的货", "BACK TO THE CARGO DISTRICT FOR A SALE")}, {"do": "load", "items": [it]},
					{"do": "go", "place": "d:trade", "say": w("送卖出的货去贸易港回收站", "TAKING A SALE TO THE TRADE PORT'S RECYCLING STATION")}, {"do": "unload"}]
				return
	if z == "cargo" and not held.is_empty() and bool(tr.wag[held[0]].get("sell", false)):
		tr.steps = [{"do": "go", "place": "d:trade", "say": w("送卖出的货去贸易港回收站", "TAKING A SALE TO THE TRADE PORT'S RECYCLING STATION")}, {"do": "unload"}]
		return
	tr.from = ""
	tr.to = ""
	tr.hub = z
	if not held.is_empty():
		# a crate for the hatch first, then the one taken off it down to the district
		var hi: int = held[0]
		for i in held:
			if str(tr.wag[i].leg) == "in":
				hi = i
		var c: Dictionary = tr.wag[hi]
		if str(c.leg) == "in":
			tr.from = z
			tr.to = str(c.to)
			if not W.hatch_takes(z):
				tr.status = w("等%s舱口空出", "WAITING FOR THE %s HATCH") % name_of(z)
				tr.backoff = 0.5
				# meanwhile a crate waiting there: fetch it (the hatch is full until it goes)
				if W.hatch_out(z) != null and not _empty(tr).is_empty():
					tr.steps = [{"do": "go", "place": "h:" + z, "wagons": [0, 1], "say": w("去中央环取货 · %s舱口", "TO THE RING FOR A CRATE · %s") % name_of(z)}, {"do": "take", "z": z}]
				elif W.hatch_out(z) != null and str(tr.place) == "d:" + z:
					# both wagons full and a crate waiting on the hatch: one goes back on the dock for later
					for i in held:
						if str(tr.wag[i].leg) == "in" and i != hi:
							queue.push_front(tr.wag[i])
							tr.wag[i] = null
							break
				return
			# a crate on its way down to the hatch and no wagon free for it: one goes back on the dock
			# for later, so the trip pushes one and takes that one
			if W.outbound(z) and _empty(tr).is_empty() and str(tr.place) == "d:" + z:
				for i in held:
					if str(tr.wag[i].leg) == "in" and i != hi:
						queue.push_front(tr.wag[i])
						tr.wag[i] = null
						break
				held = _cargo(tr)
			tr.steps = [{"do": "go", "place": "h:" + z, "wagons": held, "say": w("开往中央环 · %s舱口", "TO THE RING · %s HATCH") % name_of(z)}, {"do": "push", "z": z}]
		else:
			tr.from = "ring"
			tr.to = z
			tr.steps = [{"do": "go", "place": "d:" + z, "say": w("开往%s", "TO %s") % name_of(z)}, {"do": "unload"}]
		return
	if W.hatch_out(z) != null:
		tr.from = "ring"
		tr.to = z
		tr.steps = [{"do": "go", "place": "h:" + z, "wagons": [0, 1], "say": w("去中央环取货 · %s舱口", "TO THE RING FOR A CRATE · %s") % name_of(z)}, {"do": "take", "z": z}]
		return
	var items: Array = []
	# two crates a trip when the hatch is clear; one when a crate is on its way down to it (the other
	# wagon stays free to take that one: push one, take one)
	var room := 1 if W.outbound(z) or W.hatch_out(z) != null else 2
	for it in queue.duplicate():
		if str(it.from) == z and items.size() < room:
			items.append(it)
			queue.erase(it)
	if not items.is_empty():
		for it in items:
			it.leg = "in"
		tr.from = z
		tr.to = str(items[0].to)
		tr.steps = [{"do": "go", "place": "d:" + z, "say": w("回%s装货", "BACK TO %s TO LOAD") % name_of(z)}, {"do": "load", "items": items}]
		return
	if str(tr.place) != "d:" + z:
		tr.steps = [{"do": "go", "place": "d:" + z, "say": w("回%s走廊待命", "BACK INTO THE %s CORRIDOR") % name_of(z)}]
		return
	tr.status = w("待命", "STANDING BY")


# the ring running: crates from districts no train serves come up their hatch from below
static func _lift_unserved() -> void:
	var served := {}
	for tr in trains:
		served[str(tr.home)] = true
	W.served = served
	if not ring_alive():
		return
	for it in queue.duplicate():
		var z := str(it.from)
		if served.has(z) or not W.hatch_takes(z):
			continue
		# room kept on the carousel for what the trains bring (else a lift from below fills it and
		# the trains stand at their hatches waiting)
		if W.parcels.size() >= W.MAX_PARCELS - 3:
			break
		queue.erase(it)
		W.lift_in(z, {"key": str(it.key), "use": str(it.use), "from": z, "to": str(it.to), "at": "hatch", "slot": -1, "name": str(it.get("name", "")), "look": it.get("look", {}), "order": str(it.get("order", ""))})
		pushed_up += 1


# a train with nothing to do stands at this place (it would take the job there)
static func _free_at(place: String, me: int) -> bool:
	for o in trains:
		if int(o.id) != me and str(o.place) == place and (o.step as Dictionary).is_empty() and (o.steps as Array).is_empty() and _cargo(o).is_empty():
			return true
	return false


# the spokes, the one this train stands at first
static func _near_first(tr: Dictionary) -> Array:
	var here := str(tr.place).substr(2)
	var out: Array = []
	if here in ZONES:
		out.append(here)
	for z in ZONES:
		if z != here:
			out.append(z)
	return out


# a train in the shuttle's way leaves for somewhere out of it
static func _yield(tr: Dictionary, allow_cross := false) -> bool:
	# on the loop: slide along it the short way, just clear of the shuttle's route
	if on_loop(tr.pos) and _slide_clear(tr):
		return true
	# still at the corridor stop it was setting off from (out of the shuttle's way): it just stays
	var from := str(tr.get("route_from", ""))
	if str(tr.place) == "" and from.begins_with("d:") and int(tr.get("leg_i", 0)) == 0 and float(tr.s_run) < 0.5 * M():
		var inside := false
		for c in body_cells(tr):
			if pending.has(c[1]):
				inside = true
				break
		if not inside:
			yields += 1
			var st: Dictionary = tr.step
			tr.legs = []
			tr.path = []
			tr.speed = 0.0
			tr.acc = 0.0
			tr.moving = false
			tr.place = from
			_stand(tr)
			st.erase("routed")
			st.retry = 1.0
			tr.auth_full = true
			tr.status = w("让接驳车先过", "LETTING THE SHUTTLE BY")
			return true
	# under way (standing a moment at a switch or a signal): stop short of the shuttle's route along its
	# own way, as a running train would (the end of this leg, a change of ends out of the way)
	if str(tr.place) == "" and str(tr.step.get("do", "")) == "go" and bool(tr.step.get("routed", false)) and not bool(tr.step.get("cut", false)) and float(tr.s_run) >= 0.5 * M():
		var st0: Dictionary = tr.step
		_cut_short(tr, st0)
		if bool(st0.get("cut", false)) or tr.step != st0:
			yields += 1
			return true
	# stopped part way along a corridor (held at a signal): back the way it came, to where it set off
	if str(tr.place) == "" and not on_loop(tr.pos) and str(tr.step.get("do", "")) == "go" and bool(tr.step.get("routed", false)):
		if _back_off(tr):
			return true
	if str(tr.place) == "":
		tr.place = _where(tr)
	var z := str(tr.place).substr(2)
	var body := body_cells(tr)
	# only within its own spoke: its corridor stop or its hatch on the loop, whichever the shuttle
	# does not want (else whichever it can reach); none: it stays and the shuttle goes the other way
	var best: Dictionary = {}
	var crossing := true
	for place in ["d:" + z, "h:" + z]:
		if place == str(tr.place) or _occupied(place, int(tr.id)) or _targeted(place, int(tr.id)):
			continue
		for rt in routes(tr, place, [0, 1] if place.begins_with("h:") else []):
			if not _free(int(tr.id), rc_of(rt), body, false):
				continue
			var hits := false
			for c in rc_of(rt):
				if pending.has(c[1]):
					hits = true
					break
			if best.is_empty() or (crossing and not hits):
				best = rt
				crossing = hits
			break
	if best.is_empty() or (crossing and not allow_cross):
		return false
	yields += 1
	for zz in W.reserved.keys():
		_unreserve(tr, str(zz))
	tr.legs = []
	tr.path = []
	tr.creeping = false
	tr.wait = 0.0
	tr.pushing = {}
	_release(int(tr.id))
	_claim(int(tr.id), body)
	_set_route(tr, [])
	tr.step = {}
	tr.steps = [{"do": "go", "place": str(best.place), "say": w("给接驳车让路", "MAKING WAY FOR THE SHUTTLE"), "must": true}]
	tr.status = w("给接驳车让路", "MAKING WAY FOR THE SHUTTLE")
	return true


# along the loop either way to the nearest stretch, a train long, that the shuttle does not want and
# nobody else holds; the train runs there and stands (it plans again from there afterwards)
static func _slide_clear(tr: Dictionary) -> bool:
	var Mx := M()
	var th := angle_of(tr.pos)
	var L := (body_back(tr) + body_front(tr) + 1.5) * Mx
	var step := 0.5 * Mx
	var best_x := INF
	var best_s := 0.0
	for sd: float in [1.0, -1.0]:
		var run := 0.0
		var x := step
		while x < 60.0 * Mx:
			var k := _key(Tram._loop_pt(th + sd * x / R()))
			var o = claims.get(k)
			if o != null and int(o) != int(tr.id):
				break
			if pending.has(k):
				run = 0.0
			else:
				run += step
				if run >= L:
					if x < best_x:
						best_x = x
						best_s = sd
					break
			x += step
	if best_x == INF:
		return false
	var span := best_x / R()
	var sw := {}
	Tram._passed(th, best_s, span, sw)
	yields += 1
	for zz in W.reserved.keys():
		_unreserve(tr, str(zz))
	tr.pushing = {}
	tr.creeping = false
	_release(int(tr.id))
	var leg := {"pts": [tr.pos] + Tram._arc(th, best_s, span), "sw": sw}
	var cl: Array = body_cells(tr)
	cl.append_array(cells(leg.pts))
	_claim(int(tr.id), cl)
	_set_route(tr, cl)
	tr.s_run = 0.0
	tr.legs = [leg]
	tr.place = ""
	tr.auth_full = true
	tr.auth_left = INF
	tr.leg_s = []
	_next_leg(tr)
	tr.steps = []
	tr.step = {"do": "go", "place": ":slide", "routed": true, "cut": true, "must": true, "t": 0.0, "say": w("给接驳车让路", "MAKING WAY FOR THE SHUTTLE")}
	tr.status = w("给接驳车让路", "MAKING WAY FOR THE SHUTTLE")
	return true


# where a train stands now as a place (after a yield or an abort)
static func _where(tr: Dictionary) -> String:
	if on_loop(tr.pos):
		var best := ""
		var bd := INF
		for z in ZONES:
			var d := absf(angle_difference(angle_of(tr.pos), hub_angle(z)))
			if d < bd:
				bd = d
				best = z
		return "h:" + best
	var best2 := ""
	var bd2 := INF
	for z in ZONES:
		var d2: float = (tr.pos as Vector2).distance_to(_dstop(z).head)
		if d2 < bd2:
			bd2 = d2
			best2 = z
	return "d:" + best2


# ------------------------------------------------------------------ what moves: the warehouse
static func _item_of(u: Dictionary, from: String, to: String) -> Dictionary:
	var cat := str(u.get("cat", ""))
	if cat == "raw" or cat == "steel":
		var key := str(u.get("key", "ferrous_scrap:0"))
		return {"from": from, "to": to, "key": key, "use": W._use(key), "name": str(u.get("name", key)), "look": {}}
	var src: Dictionary = u.get("good", u.get("part", {}))
	var nk := str(src.get("nk", ""))
	return {"from": from, "to": to, "key": "equip", "use": "equip", "name": str(u.get("name", "")),
		"look": {"ship": str(u.get("ship", "")), "tag": str(u.get("tag", "")), "nk": nk}}


# 130 号 (user): a sale to the recycling station goes by train — from the cargo district (the
# warehouse) by way of the ring to the trade port, where the recycling station's crane lifts it off the
# wagon. Seen only: the sale is paid the moment it is made. Sales come first, before the base service.
static var sold_runs := 0     # tests: sold crates lifted away at the trade port
static func sell(cat: String, _cells: int, label := "") -> void:
	if not on or not _open("cargo") or not _open("trade"):
		return
	var key := "equip"
	match cat:
		"raw":
			key = "ferrous_scrap:1"
		"steel":
			key = "steel_billet:1"
		"tank":
			key = "equip"
	var it := {"from": "cargo", "to": "trade", "key": key, "use": W._use(key) if key != "equip" else "equip",
		"name": label if label != "" else w("卖给回收站", "SOLD FOR RECYCLING"), "look": {}, "sell": true}
	var n := 0
	for q in queue:
		if bool(q.get("sell", false)):
			n += 1
	if n >= 6:
		return
	# ahead of everything that is not a sale
	var at := 0
	while at < queue.size() and bool(queue[at].get("sell", false)):
		at += 1
	queue.insert(at, it)
	if queue.size() > 14:
		queue.pop_back()


# 128 号 第 2 段 (user: "货运火车把货送到贸易港"): an order made up in the warehouse goes as `n` crates from
# the cargo district by way of the ring to the trade port, where they are unloaded for the client's
# ship. Ahead of everything but the sales. false: no trains (the board then sends it on at once).
static var order_in := {}     # order id -> crates unloaded at the trade port
static func ship_order(oid: String, n: int, label: String) -> bool:
	if not on or not _open("trade"):
		return false
	# the main stores are in the cargo district; till it is mended they are the berth's counter
	var from := "cargo" if _open("cargo") else "salvage"
	order_in[oid] = 0
	var at := 0
	while at < queue.size() and bool(queue[at].get("sell", false)):
		at += 1
	for i in n:
		queue.insert(at, {"from": from, "to": "trade", "key": "equip", "use": "equip", "name": w("订单交付 · %s", "ORDER · %s") % label, "look": {}, "order": oid})
	if queue.size() > 16:
		queue.pop_back()
	return true


static func order_arrived(oid: String) -> int:
	return int(order_in.get(oid, 0))


static func order_done(oid: String) -> void:
	order_in.erase(oid)
	queue = queue.filter(func(q): return str(q.get("order", "")) != oid)


static func _ship(it: Dictionary) -> void:
	if queue.size() < 12:
		queue.append(it)


static func _units() -> Array:
	if Career.data.is_empty() or not StoreBook.live():
		return []
	return StoreBook.units()


static func _open(z: String) -> bool:
	return z == "salvage" or (not Career.data.is_empty() and Port.stage(z) >= 1)


# once a second: what came into the warehouse and what left it
static func _watch() -> void:
	var us := _units()
	var cur := {}
	for u in us:
		cur[str(u.id)] = u
	var pq := ProcessQueue.entries().size() if not Career.data.is_empty() else 0
	if not _seen_ok:
		_seen = cur
		_seen_ok = true
		_pq = pq
		return
	var n := 0
	for id in cur:
		if not _seen.has(id) and n < 3:
			var u: Dictionary = cur[id]
			var billet := str(u.get("key", "")).begins_with("steel_billet")
			_ship(_item_of(u, "process" if billet else "salvage", "cargo"))
			n += 1
			real_runs += 1
	for id in _seen:
		if not cur.has(id) and n < 3:
			_ship(_item_of(_seen[id], "cargo", "process" if pq > _pq else "trade"))
			n += 1
			real_runs += 1
	_seen = cur
	_pq = pq


# between the real ones, a service by the port's size with what the warehouse really holds
static func _base_service(dt: float) -> void:
	var open := 0
	for z in ZONES:
		if _open(z):
			open += 1
	_base -= dt
	if _base > 0.0:
		return
	_base = lerpf(40.0, 15.0, clampf((open - 1) / 4.0, 0.0, 1.0))
	if not queue.is_empty() or not _open("cargo"):
		return
	var us := _units()
	if us.is_empty():
		return
	var u: Dictionary = us[randi() % us.size()]
	var pairs: Array = []
	if str(u.get("cat", "")) == "raw":
		pairs = [["cargo", "process"], ["process", "cargo"], ["cargo", "trade"]]
	else:
		pairs = [["salvage", "cargo"], ["tug", "cargo"], ["cargo", "trade"]]
	pairs = pairs.filter(func(p): return _open(p[0]) and _open(p[1]))
	if pairs.is_empty():
		return
	var p: Array = pairs[randi() % pairs.size()]
	_ship(_item_of(u, p[0], p[1]))
	base_runs += 1


# the demo's own stream between two spokes no train serves (up from below, round the carousel, down
# again): those arms keep working while the trains bring and take the rest
const DEMO_SIDE := [["tug", "trade", "steel_section:1"], ["trade", "tug", "nonferrous_mix:1"]]
static var _demo_u_t := 0.0
static func _demo_unserved(dt: float) -> void:
	_demo_u_t -= dt
	if _demo_u_t > 0.0 or not ring_alive():
		return
	_demo_u_t = 3.0
	for k in DEMO_SIDE.size():
		var f: Array = DEMO_SIDE[(_demo_i + k) % DEMO_SIDE.size()]
		var z: String = f[0]
		if W.served.has(z) or W.served.has(str(f[1])) or not _open(z) or not _open(str(f[1])):
			continue
		# (only while the carousel has plenty of room: the trains' crates come first)
		if not W.hatch_takes(z) or W.parcels.size() >= W.MAX_PARCELS - 5:
			continue
		W.lift_in(z, {"key": str(f[2]), "use": W._use(str(f[2])), "from": z, "to": str(f[1]), "at": "hatch", "slot": -1, "name": Ops.item_name(str(f[2])), "look": {}})
		pushed_up += 1
		return


static func _demo(dt: float) -> void:
	_demo_unserved(dt)
	_demo_t -= dt
	# the trains' own districts' shipments kept to a few; the spokes no train serves lift theirs up
	# at once (they do not wait behind the trains')
	var waiting := 0
	for q in queue:
		if W.served.has(str(q.from)):
			waiting += 1
	if _demo_t > 0.0:
		return
	_demo_t = 5.0
	var f: Array = W.DEMO_FLOWS[_demo_i % W.DEMO_FLOWS.size()]
	for k in W.DEMO_FLOWS.size():
		f = W.DEMO_FLOWS[_demo_i % W.DEMO_FLOWS.size()]
		_demo_i += 1
		if not (W.served.has(str(f[0])) and waiting >= 4):
			break
	if W.served.has(str(f[0])) and waiting >= 4:
		return
	var it := {"from": f[0], "to": f[1], "key": f[2], "use": W._use(f[2]), "name": Ops.item_name(f[2]), "look": {}}
	_ship(it)
	# and a second for the same wagon pair: a machine the warehouse holds, when it holds any
	var it2 := it.duplicate()
	for u in _units():
		if str(u.get("cat", "")) != "raw":
			it2 = _item_of(u, f[0], f[1])
			break
	_ship(it2)


# ------------------------------------------------------------------ the step
static func tick(dt: float) -> void:
	if not on:
		return
	t += dt
	_ticks += 1
	# trains by the port's size
	var want := want_count()
	while trains.size() < want:
		var home: String = HOMES[trains.size() % HOMES.size()]
		var tr := _new_train(trains.size(), home)
		var body := body_cells(tr)
		if not _free(int(tr.id), body, []):
			break
		_claim(int(tr.id), body)
		trains.append(tr)
	while trains.size() > want and (trains[-1].step as Dictionary).is_empty() and _cargo(trains[-1]).is_empty():
		_release(int(trains[-1].id))
		trains.pop_back()
	_scan -= dt
	if _scan <= 0.0:
		_scan = 1.0
		if W.demo:
			pass
		else:
			_watch()
	if W.demo:
		_demo(dt)
	else:
		_base_service(dt)
	_lift_unserved()
	# the shuttle waiting on freight: whatever stands in its way leaves, and a train on its way into
	# the shuttle's route stops short of it (on the loop) and goes on once the shuttle has passed
	if not pending.is_empty():
		for tr in trains:
			if tr.moving and not bool(tr.step.get("must", false)) and str(tr.step.get("do", "")) == "go":
				_cut_short(tr, tr.step)
		for tr in trains:
			# creeping up to a signal the shuttle's route holds at danger: as good as standing
			if tr.moving and ((tr.get("blocker") != null and int(tr.blocker) == PASSENGER) or bool(tr.step.get("cut", false))) and float(tr.speed) < 0.3 * M() and str(tr.step.get("place", "")) != ":slide":
				tr.speed = 0.0
				tr.acc = 0.0
				tr.moving = false
			if tr.moving or str(tr.step.get("ph", "")) == "pushing":
				continue
			# a train sent somewhere it must go is left to it, unless it can't get going
			if bool(tr.step.get("must", false)) and (bool(tr.step.get("routed", false)) or float(tr.wait) < 2.0):
				continue
			var hit := false
			for k in claims:
				if int(claims[k]) == int(tr.id) and pending.has(k):
					hit = true
					if debug:
						var inb := false
						for bc in body_cells(tr):
							if bc[1] == k:
								inb = true
						print("    yield-hit #%d place=%s step=%s cell=%s rel=%s in_body=%s pos=%s lf=%s head=%s" % [tr.id, tr.place, tr.step.get("do", ""), k, ((Vector2(k) + Vector2(0.5, 0.5)) * CELL * M() - centre()) / M(), inb, ((tr.pos as Vector2) - centre()) / M(), tr.lf, Vector2.from_angle(float(tr.heading))])
					break
			if hit and (float(tr.get("yield_t", 0.0)) <= 0.0 or float(tr.get("blocked_t", 0.0)) > 0.0):
				# a clean way out of the shuttle's route at once; across it only once the shuttle has
				# waited a while with no other way round
				if _yield(tr, t - _pending_t > 3.0):
					tr.yield_t = 1.5
					tr.blocked_t = 0.0
	for tr in trains:
		var _s0 := Time.get_ticks_usec()
		_step(tr, dt)
		prof.step = maxf(float(prof.get("step", 0.0)), float(Time.get_ticks_usec() - _s0))
	var _d0 := Time.get_ticks_usec()
	if not follow.is_empty():
		for k in follow.keys():
			if not claims.has(k):
				claims[k] = PASSENGER
				follow.erase(k)
	# two trains each held at a signal by the other: the one nearer the passing loop backs off
	_deadlocks()
	prof.after = maxf(float(prof.get("after", 0.0)), float(Time.get_ticks_usec() - _d0))
	# a hatch stays kept only for a train that still means to push a crate onto it
	for z in W.reserved.keys():
		var keep := false
		for tr in trains:
			if int(tr.id) != int(W.reserved[z]):
				continue
			if str(tr.step.get("do", "")) == "push" and str(tr.step.get("z", "")) == str(z):
				keep = true
			for s2 in tr.steps:
				if str(s2.get("do", "")) == "push" and str(s2.get("z", "")) == str(z):
					keep = true
		if not keep:
			W.reserved.erase(z)


static func _step(tr: Dictionary, dt: float) -> void:
	tr.yield_t = float(tr.get("yield_t", 0.0)) - dt
	tr.lock = move_toward(float(tr.lock), 1.0 if tr.step.get("do", "") in ["push", "take", "load", "unload", ""] and not tr.moving else 0.0, dt / LOCK_T)
	for i in 2:
		var an: Dictionary = tr.anim[i]
		if not an.is_empty():
			an.t = minf(1.0, float(an.t) + dt / (SELL_T if str(an.get("dir", "")) == "sell" else LOAD_T))
	if (tr.step as Dictionary).is_empty():
		tr.backoff = float(tr.get("backoff", 0.0)) - dt
		if float(tr.backoff) > 0.0:
			return
		if (tr.steps as Array).is_empty():
			_assign(tr)
		if (tr.steps as Array).is_empty():
			return
		tr.step = (tr.steps as Array).pop_front()
		tr.step.t = 0.0
	var st: Dictionary = tr.step
	st.t = float(st.t) + dt
	var kind := str(st.do)
	if kind == "go":
		kind = "run" if bool(st.get("routed", false)) else ("hold" if bool(st.get("hold", false)) else "route")
	elif kind in ["push", "take"]:
		kind = "hub"
	elif kind in ["load", "unload"]:
		kind = "load"
	time_in[kind] = float(time_in.get(kind, 0.0)) + dt
	match str(st.do):
		"go":
			# a stop another train stands at or is on its way to: wait for it, out of the way
			if not bool(st.get("routed", false)) and str(tr.place) != str(st.place) and _occupied(str(st.place), int(tr.id)):
				tr.status = w("等%s空出", "WAITING FOR %s TO CLEAR") % _place_name(str(st.place))
				# step aside only when the one in the way waits for this very stop (else both would wait for ever)
				st.occ = float(st.get("occ", 0.0)) + dt
				# step aside when the one in the way waits for this stop, or after a while (a longer ring of
				# trains each waiting for the next one's stop)
				if str(tr.place).begins_with("d:") and not bool(st.get("must", false)) and (_swap(str(st.place), str(tr.place), int(tr.id)) or float(st.occ) > 4.0 + int(tr.id)):
					var h := _free_district(tr, str(st.place))
					if h != "":
						tr.steps.push_front(st)
						tr.step = {"do": "go", "place": h, "say": w("让开站台，去%s等候", "MAKING ROOM: WAITING AT %s") % name_of(h.substr(2)), "t": 0.0, "hold": true}
				# never wait on the loop (it blocks everyone): wait in a corridor instead, home first
				elif str(tr.place).begins_with("h:"):
					var d := _free_district(tr, str(st.place))
					if d != "":
						tr.steps.push_front(st)
						tr.step = {"do": "go", "place": d, "say": w("回走廊等候", "INTO A CORRIDOR TO WAIT"), "t": 0.0, "hold": true}
				return
			if _go(tr, st, dt):
				tr.step = {}
				tr.lock = 0.0
			elif bool(st.get("failed", false)):
				# no way there for now: think again in a moment (perhaps somewhere else)
				tr.step = {}
				tr.steps = []
				tr.wait = 0.0
				tr.backoff = 0.8 + randf() * 0.8
				if str(tr.place) == "":
					tr.place = _where(tr)
		"load":
			tr.status = w("在%s装货", "LOADING AT %s") % name_of(str(tr.place).substr(2))
			if float(tr.lock) < 1.0:
				return
			var items: Array = st.items
			var busy := false
			for i in 2:
				if not (tr.anim[i] as Dictionary).is_empty() and float(tr.anim[i].t) < 1.0:
					busy = true
			if busy:
				return
			for i in 2:
				tr.anim[i] = {}
			if items.is_empty():
				tr.step = {}
				return
			var e := _empty(tr)
			if e.is_empty():
				# no room: the rest go back to the queue
				for it in items:
					queue.push_front(it)
				tr.step = {}
				return
			tr.wag[e[0]] = items.pop_front()
			tr.anim[e[0]] = {"t": 0.0, "dir": "up"}
		"unload":
			tr.status = w("在%s卸货", "UNLOADING AT %s") % name_of(str(tr.place).substr(2))
			if float(tr.lock) < 1.0:
				return
			for i in 2:
				var an: Dictionary = tr.anim[i]
				if not an.is_empty() and float(an.t) < 1.0:
					return
				if not an.is_empty() and str(an.dir) in ["down", "sell"]:
					if str(an.dir) == "sell":
						sold_runs += 1
					var oid := str((tr.wag[i] as Dictionary).get("order", "")) if tr.wag[i] is Dictionary else ""
					if oid != "" and str(tr.place) == "d:trade" and order_in.has(oid):
						order_in[oid] = int(order_in[oid]) + 1
					tr.wag[i] = null
					tr.anim[i] = {}
					delivered += 1
			var c := _cargo(tr)
			if c.is_empty():
				tr.step = {}
				return
			var sale: bool = bool(tr.wag[c[0]].get("sell", false)) and str(tr.place) == "d:trade"
			tr.status = w("回收站吊走卖出的货", "THE RECYCLING STATION LIFTS THE SALE AWAY") if sale else tr.status
			tr.anim[c[0]] = {"t": 0.0, "dir": "sell" if sale else "down"}
		"push":
			_push(tr, st, dt)
		"take":
			_take(tr, st, dt)


# stand by a hatch and push each crate across onto its lift, one at a time
static func _push(tr: Dictionary, st: Dictionary, dt: float) -> void:
	var z := str(st.z)
	if str(st.get("ph", "")) == "pushing":
		tr.status = w("推货进%s舱口", "PUSHING INTO THE %s HATCH") % name_of(z)
		tr.roll = float(tr.roll) + dt * 3.0
		if W.pushing(z).is_empty():
			pushed += 1
			tr.pushing = {}
			st.ph = "align"
		return
	var c := _cargo(tr)
	var need := float(tr.get("need", 99.0)) + 0.05
	var mine: Array = c.filter(func(i): return str(tr.wag[i].leg) == "in" and str(tr.wag[i].from) == z and wagon_off(tr, i) <= need)
	if mine.is_empty() or not ring_alive():
		_unreserve(tr, z)
		tr.step = {}
		# a crate waiting on this hatch (or coming down to it): take it with the wagon just emptied
		if ring_alive() and not _empty(tr).is_empty() and (W.hatch_out(z) != null or W.outbound(z)) and str(tr.place) == "h:" + z:
			tr.from = "ring"
			tr.to = z
			tr.step = {"do": "take", "z": z, "t": 0.0}
		return
	# the nearest wagon to the head first: the train creeps on to the next
	mine.sort_custom(func(a, b): return wagon_off(tr, a) < wagon_off(tr, b))
	var wi: int = mine[0]
	var ph := str(st.get("ph", "align"))
	W.reserved[z] = int(tr.id)
	if ph != "pushing" and W.hatch_out(z) != null and not _empty(tr).is_empty() and float(tr.lock) >= 1.0:
		# a crate waiting on the hatch: aboard first, then the push
		st.ph = "align"
		tr.steps.push_front(st)
		tr.step = {"do": "take", "z": z, "t": 0.0, "then_push": true}
		return
	match ph:
		"align":
			tr.status = w("对准%s舱口", "LINING UP AT THE %s HATCH") % name_of(z)
			if _align(tr, z, wi, dt):
				st.ph = "lock"
				st.wait = 0.0
		"lock":
			tr.status = w("锁车 · 等%s舱口", "LOCKED · WAITING FOR THE %s HATCH") % name_of(z)
			st.wait = float(st.get("wait", 0.0)) + dt
			if float(tr.lock) >= 1.0 and W.hatch_takes(z):
				var p: Dictionary = tr.wag[wi]
				var parcel := {"key": str(p.key), "use": str(p.use), "from": z, "to": str(p.to), "at": "push", "slot": -1, "name": str(p.get("name", "")), "look": p.get("look", {}), "order": str(p.get("order", ""))}
				tr.wag[wi] = null
				tr.pushing = {"wi": wi, "z": z}
				W.push_in(z, parcel)
				st.ph = "pushing"
			elif float(st.wait) > HUB_WAIT:
				# the hatch will not take it: take it back down to where it came from
				for i in mine:
					tr.wag[i].leg = "out"
					tr.wag[i].to = tr.wag[i].from
				_unreserve(tr, z)
				tr.step = {}
				tr.pushing = {}
		"pushing":
			tr.status = w("推货进%s舱口", "PUSHING INTO THE %s HATCH") % name_of(z)
			tr.roll = float(tr.roll) + dt * 3.0
			if W.pushing(z).is_empty():
				pushed += 1
				tr.pushing = {}
				st.ph = "align"


# a crate on the carousel (or in the arm's hands) bound for this hatch
static func _cradle_for(z: String) -> bool:
	for p in W.cradles:
		if p != null and str(p.to) == z:
			return true
	var a: Dictionary = W.arms.get(z, {})
	return not a.is_empty() and str(a.task) == "unload"


static func _has_in(tr: Dictionary, z: String) -> bool:
	for i in 2:
		if tr.wag[i] != null and str(tr.wag[i].leg) == "in" and str(tr.wag[i].from) == z:
			return true
	return false


static func _unreserve(tr: Dictionary, z: String) -> void:
	if int(W.reserved.get(z, -1)) == int(tr.id):
		W.reserved.erase(z)


# stand by a hatch, take the crate waiting on its lift aboard (and a second if one comes down soon)
static func _take(tr: Dictionary, st: Dictionary, dt: float) -> void:
	var z := str(st.z)
	var need := float(tr.get("need", 99.0)) + 0.05
	var e := _empty(tr).filter(func(i): return wagon_off(tr, i) <= need)
	var ph := str(st.get("ph", "align"))
	if e.is_empty() and ph != "pushing":
		tr.step = {}
		return
	e.sort_custom(func(a, b): return wagon_off(tr, a) < wagon_off(tr, b))
	match ph:
		"align":
			tr.status = w("对准%s舱口", "LINING UP AT THE %s HATCH") % name_of(z)
			if _align(tr, z, e[0], dt):
				st.ph = "lock"
				st.wait = 0.0
		"lock":
			tr.status = w("锁车 · 等%s舱口出货", "LOCKED · WAITING FOR THE %s HATCH") % name_of(z)
			st.wait = float(st.get("wait", 0.0)) + dt
			if float(tr.lock) >= 1.0 and W.hatch_out(z) != null:
				W.push_out(z)
				tr.pushing = {"wi": e[0], "z": z}
				st.ph = "pushing"
			elif float(st.wait) > _hatch_patience(tr, ((4.0 if _cradle_for(z) else 2.0) if _cargo(tr).size() > 0 else (6.0 if W.outbound(z) else 2.0))):
				tr.step = {}
				tr.pushing = {}
				if not _cargo(tr).is_empty():
					var c: Dictionary = tr.wag[_cargo(tr)[0]]
					tr.steps = [{"do": "go", "place": "d:" + str(c.to), "say": w("开往%s", "TO %s") % name_of(str(c.to))}, {"do": "unload"}]
		"pushing":
			tr.status = w("从%s舱口取货", "TAKING A CRATE OFF THE %s HATCH") % name_of(z)
			tr.roll = float(tr.roll) + dt * 3.0
			var p = W.handed(z)
			if p != null:
				tr.wag[int(tr.pushing.wi)] = {"key": str(p.key), "use": str(p.use), "from": str(p.from), "to": z, "leg": "out", "name": str(p.get("name", "")), "look": p.get("look", {}), "order": str(p.get("order", ""))}
				tr.pushing = {}
				taken += 1
				st.ph = "align"
				if bool(st.get("then_push", false)):
					tr.step = {}
					return
				# another coming down here soon: wait for it with the other wagon
				if _empty(tr).is_empty() or not W.outbound(z):
					tr.step = {}
					tr.steps = [{"do": "go", "place": "d:" + z, "say": w("开往%s", "TO %s") % name_of(z)}, {"do": "unload"}]


# how long a train standing on the loop at a hatch waits for a crate to come up: not long at all when
# another train is held at a signal by it
static func _hatch_patience(tr: Dictionary, t_max: float) -> float:
	for o in trains:
		if int(o.id) != int(tr.id) and o.get("blocker") != null and int(o.blocker) == int(tr.id) and float(o.get("blocked_t", 0.0)) > 0.0:
			return minf(t_max, 3.0)
	return t_max


# ------------------------------------------------------------------ for the drawing and the cards
# the crate on its way between a wagon and a hatch: [hub px start, wagon px, eased 0 … 1 towards the wagon, parcel] or []
static func push_at(tr: Dictionary) -> Array:
	var pu: Dictionary = tr.get("pushing", {})
	if pu.is_empty():
		return []
	var z := str(pu.z)
	var ps := W.pushing(z)
	if ps.is_empty():
		return []
	var hp := centre() + W.hatch_at(z) * PortStructure.M()
	var wp: Vector2 = cars(tr)[order(tr).find(int(pu.wi) + 1)][0]
	var e := float(ps.t)
	e = e * e * (3.0 - 2.0 * e)
	return [hp, wp, e if str(ps.dir) == "out" else 1.0 - e, ps.p]


static func says(tr: Dictionary) -> Dictionary:
	var goods: Array = []
	for i in 2:
		if tr.wag[i] != null:
			goods.append(str(tr.wag[i].get("name", "")))
	var route := ""
	if str(tr.from) != "" and str(tr.to) != "":
		route = w("%s → %s", "%s → %s") % [name_of(str(tr.from)) if str(tr.from) != "ring" else w("中央环", "THE RING"), name_of(str(tr.to))]
	return {"goods": goods, "route": route, "status": str(tr.status)}


# the shuttle choosing its way: a ride over freight standing still costs more (it would wait for it)
static func avoid_cost(lg: Array) -> float:
	if not on or claims.is_empty():
		return 0.0
	# each freight train holding any of this way costs it (one standing still more: it has to move off)
	var hit := {}
	var s0 := 0.0
	for l in lg:
		for c in cells(l.pts, s0, 1.0):
			var o = claims.get(c[1])
			if o != null and int(o) != PASSENGER:
				hit[int(o)] = true
		s0 += TramArt.length(l.pts)
	var cost := 0.0
	for tr in trains:
		if hit.has(int(tr.id)):
			cost += 120.0 if tr.moving else 200.0
	return cost
