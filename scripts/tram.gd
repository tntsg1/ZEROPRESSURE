extends Node2D
# The port's rail shuttle (design/成长版本/G5-G7_工业港成长重设计_2026-10-22/21; 02 号
# "固定站点接驳"): one car on rails along every corridor and through the hub. A station
# inside each district's door and one in the hub. At a station the drone presses E,
# picks a district it has already discovered, and rides: the car comes to the station
# if it is elsewhere, the drone rides in it (hidden) along the corridor, through the hub
# and down the other corridor, and steps off at the far station. Seen, not teleported;
# a ride across the port takes about ten seconds.
# 97 号 (user 2026-10-28): a stop in the berth's port gate too, known from the start — out of
# the berth and straight on; a ride that cannot take a turnout the way it faces (the hub's stop
# sits between the berth line's two) runs past the switch, stops, changes ends and backs onto
# it; the switches throw before the train comes; the train is two cars on bogies with sprung
# bodies and doors (drawing: scripts/tram_art.gd). No overhead line (user 2026-10-28: "那个供电线不用画").
class_name Tram
const Art = preload("res://scripts/tram_art.gd")
const FastDraw = preload("res://scripts/fast_draw.gd")
# 130 号: freight trains share the rails (scripts/freight_works.gd); the shuttle comes first, but it
# sets off only with its whole route clear of them, and throws its switches only then
const FW = preload("res://scripts/freight_works.gd")
static var avoid := Callable()   # extra cost of a candidate ride (freight standing on it)

var game
var t := 0.0
var at := "ring"               # the station the car is at ("" under way)
var path: Array = []           # world px waypoints
var riding := false            # the drone is in the car
var dest := ""
var position_px := Vector2.ZERO
var heading := 0.0
# the ride, in phases: "" idle | "fetch" coming to the caller | "board" doors open, the
# drone slides in | "ride" | "alight" doors open, the drone slides out
var phase := ""
var dwell := 0.0
var speed := 0.0
var slide_from := Vector2.ZERO
const SPEED := 36.0 * 48.0     # px/s (35 号: was 12 m/s; 130 号 review: 20 ×1.8)
const ACCEL := 10.8 * 48.0      # px/s²
const A_LAT := 5.0 * 48.0      # px/s²: what a curve allows sideways
const CURVE_R := 6.0           # m: the rails' curve radius at a corner, at most
const COUPLE := 3.6            # m between the two cars' centres
var limits: Array = []         # px/s: the speed allowed at each point of `path`
var trail: Array = []          # where the front car has been, newest first (the second car follows it)
var track_lines: Array = []    # tests: every track's centre line, world px (built with the rails)
const DWELL := 1.3            # s at the boarding stop: doors open, the drone in, doors shut
const ALIGHT := 0.76           # s at the far stop before the drone is free (the doors shut after)
const REACH := 4.5             # m: the drone calls the car from this close
# 130 号: the hub's stop stands on the loop at RING_A (it was at the bottom, 90°, right behind the
# berth spoke's hatch, where the freight trains now stand to hand crates over) — between the berth
# line's and the processing line's switches, the business console beside it
const RING_A := 140.0 * PI / 180.0
const RING_SIGN := 1.6          # m along the hub stop from its middle to its sign's post
const BUFFER_AT := 2.35         # m past a dead-end stop's point to its buffer (scripts/tram_art.gd)
const STATION_IN := 2.5        # m inside the door
const BERTH_STOP := 3.6        # m above the berth's gate rail: where the head car stands (97 号)
# 97 号: a ride's legs (the train stops and changes ends between them) and the switches
var legs: Array = []           # [{pts, sw: {switch id: 0 | 1}}] still to run after this one
var _leg_sw: Dictionary = {}   # the running leg's switches: it waits for them to be set
var _hold := 0.0               # s still to stand before the leg sets off
const HOLD := 0.6              # s a reversal stands: the driver changes ends
const CLEAR := 7.0             # m past a switch the head car runs so the whole train clears it
const REVERSE_COST := 30.0     # m a reversal is worth when choosing the way
var sw_pos := {}               # switch id -> 0 (branch a) … 1 (branch b)
var sw_vel := {}
var sw_to := {}
const SW_V := 2.4              # /s the points travel at most, /s² they speed up and brake
const SW_A := 9.0
var lead := 0                  # which car (0 the inverter car, 1 the air-conditioned one) leads
var stop := ""                 # the stop the train stands at with its doors (for their side)
var door := [0.0, 0.0]         # each car's doors: 0 shut … 1 open
var door_v := [0.0, 0.0]
var lean := [Vector2.ZERO, Vector2.ZERO]   # m each body sits off its bogies on its springs
var lean_v := [Vector2.ZERO, Vector2.ZERO]
const K_LAT := 0.025           # m of lean a m/s² sideways, m of pitch a m/s² along
const K_LONG := 0.008
const SPRING_W := 9.0          # rad/s and damping ratio of the body on its springs
const SPRING_Z := 0.45


func active() -> bool:
	return game != null and game.in_berth() and game.career()


static func _gate_x() -> float:
	return clampf(Dock.centre().x, Dock.TOWER_X + 3.0, Dock.ARM_X1 - 3.0)


static func station_at(zone: String) -> Vector2:
	if zone == "ring":
		# on the hub's loop (35 号: at its bottom; 130 号: at RING_A)
		return Backdrop.port_centre_px() + Vector2.from_angle(RING_A) * LOOP_R * PortStructure.M()
	if zone == "salvage":
		# 97 号: just inside the berth's port gate (scripts/dock.gd port_gate), facing up the corridor
		return Vector2(_gate_x(), Dock.RAIL_Y - BERTH_STOP) * Geom.M
	# straight in at the door (where the consoles beside it leave room for it)
	var d: Array = PortStructure.door(zone)
	return d[0] + d[1] * STATION_IN * PortStructure.M()


static func stations() -> Array:
	var out: Array = ["ring"]
	for z in PortArt.ANGLE:
		out.append(z)
	return out


# the stations the drone may ride to: the hub and the berth's always, a district once the drone
# has been in it
static func found() -> Array:
	var f: Array = Career.data.get("tram_found", []).duplicate() if not Career.data.is_empty() else []
	for z in ["ring", "salvage"]:
		if z not in f:
			f.append(z)
	return f


static func discover(zone: String) -> void:
	if Career.data.is_empty() or zone == "" or zone == "salvage":
		return
	var f: Array = Career.data.get("tram_found", [])
	if zone not in f:
		f.append(zone)
		Career.data.tram_found = f


# along the track at a stop, away from its dead end
static func station_dir(zone: String) -> Vector2:
	if zone == "ring":
		return Vector2.from_angle(RING_A - PI * 0.5)
	var lg := _leg(zone)
	return ((lg[1] as Vector2) - (lg[0] as Vector2)).normalized()


# the platform's side of the track: the hub's inside the loop; a level line's upper side, an
# upright one's right
static func platform_side(zone: String) -> Vector2:
	if zone == "ring":
		return -Vector2.from_angle(RING_A)
	var d := station_dir(zone)
	var n := d.orthogonal()
	if absf(d.x) > absf(d.y):
		return n if n.y < 0.0 else -n
	return n if n.x > 0.0 else -n


# where the drone steps off: the platform's middle
static func alight_at(zone: String) -> Vector2:
	return station_at(zone) + platform_side(zone) * 1.55 * Geom.M


var rails: Node2D
var points: Node2D
var _rails_z := -1.0
var rails_draws := 0         # tests: how often the still rails were drawn
static var lines_mat: ShaderMaterial
var _geo := Vector2.INF      # the berth stop in the port's frame the meshes were built for
var _track: Array = []       # the still track's meshes, in drawing order (empty until first built)
var _job                     # the track being built a slice a frame (scripts/tram_art.gd TrackJob)
const BUILD_SLICE := 1500    # µs of a frame the build may take
var _switches: Array = []    # [{id, a, b, side}] branches from the toe, port frame
var _toes := {}              # switch id -> its toe, port frame
var _points_dirty := true
var _points_mesh: ArrayMesh
var _bob := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]   # bogies: car 0 cab, inner; car 1 cab, inner
var _bob_p := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
var _boa := [0.0, 0.0, 0.0, 0.0]
var _boa_p := [0.0, 0.0, 0.0, 0.0]
var _th := [INF, INF]        # each car's direction of travel at the last step (lean)


func _ready() -> void:
	z_index = 4
	z_as_relative = false
	position_px = station_at(at)
	_settle(at)
	if lines_mat == null:
		lines_mat = ShaderMaterial.new()
		lines_mat.shader = preload("res://scripts/port_lines.gdshader")
	# the rails stand still: built once in the port's frame, drawn with one mesh (97 号)
	rails = Node2D.new()
	rails.show_behind_parent = true
	rails.material = lines_mat
	rails.draw.connect(_draw_rails)
	add_child(rails)
	points = Node2D.new()
	points.show_behind_parent = true
	points.material = lines_mat
	points.draw.connect(_draw_points)
	add_child(points)
	_poses()
	_poses()
	_mesh = {"shadow": Art.shadow_mesh(), "side": Art.side_mesh(false), "side_lit": Art.side_mesh(true), "roof": [Art.roof_mesh(0), Art.roof_mesh(1)],
		"bogie": [Art.bogie_mesh(true), Art.bogie_mesh(false)], "leaf": Art.leaf_mesh()}


func near_station() -> String:
	if not active() or game.drone == null or not game.drone.alive:
		return ""
	for s in stations():
		var sp: Vector2 = _stop_px(s)
		if game.drone.global_position.distance_to(sp) <= REACH * Geom.M:
			# the berth's stop is outside the berth: not called from inside it
			if s == "salvage" and game.drone.global_position.y > (Dock.RAIL_Y - 0.4) * Geom.M:
				continue
			return s
	return ""


# a stop's place, from the cache while the meshes stand (station_at asks the port's geometry)
func _stop_px(zone: String) -> Vector2:
	for st in _stops:
		if st.z == zone:
			return (st.p as Vector2) + Backdrop.port_centre_px()
	return station_at(zone)


# the rails (35 号): each district's line runs station -> door -> the hub's rim, and joins a
# loop round the hub on a turnout curve; the car runs round the loop the short way and leaves
# on the other district's turnout. No corner sharper than the turnouts.
const LOOP_R := 21.5           # m: the loop's radius inside the hub (just inside its rim)
const TURNOUT := 0.8           # rad along the loop a turnout takes to join it (a long, easy curve)
const TURNOUT_BERTH := 0.5     # 97 号: the berth line's (0.8 put its points on the processing line's)
const TURN_IN := 6.0           # m up the corridor from the rim where a turnout begins


static func _turn(zone: String) -> float:
	return TURNOUT_BERTH if zone == "salvage" else TURNOUT


static func _angle(zone: String) -> float:
	if zone == "ring":
		return RING_A
	return ((PortStructure.door(zone)[0] as Vector2) - Backdrop.port_centre_px()).angle()


static func _loop_pt(a: float) -> Vector2:
	return Backdrop.port_centre_px() + Vector2.from_angle(a) * LOOP_R * PortStructure.M()


# a district's line out to the rim: [station, door, rim] (the berth's: [station, rim], straight up)
static func _leg(zone: String) -> Array:
	if zone == "ring":
		return [station_at("ring")]
	var c := Backdrop.port_centre_px()
	if zone == "salvage":
		var s := station_at("salvage")
		return [s, c + (s - c).normalized() * (PortArt.HUB_R + TURN_IN) * PortStructure.M()]
	var d: Array = PortStructure.door(zone)
	var p: Vector2 = d[0]
	# the line ends a few metres up the corridor, where its turnouts begin to bend
	return [station_at(zone), p, c + (p - c).normalized() * (PortArt.HUB_R + TURN_IN) * PortStructure.M()]


# the turnout from a district's rim onto the loop at angle `a + s·TURNOUT`: a cubic that leaves
# the rim along the line and meets the loop along its tangent, so there is no kink to slow for
static func _turnout(zone: String, s: float) -> Array:
	var a := _angle(zone)
	var rim: Vector2 = _leg(zone)[-1]
	var end := _loop_pt(a + s * _turn(zone))
	var inward := -Vector2.from_angle(a)
	var tangent := Vector2.from_angle(a + s * _turn(zone) + s * PI * 0.5)
	var reach := rim.distance_to(end) * 0.45
	var c1 := rim + inward * reach
	var c2 := end - tangent * reach
	var out: Array = []
	for k in 13:
		var q := float(k) / 12.0
		var u := 1.0 - q
		out.append(rim * u * u * u + c1 * 3.0 * u * u * q + c2 * 3.0 * u * q * q + end * q * q * q)
	return out


# the loop from angle a0 the way s for `span` rad (a0 itself left out)
static func _arc(a0: float, s: float, span: float) -> Array:
	var out: Array = []
	var n := maxi(1, int(ceil(span / 0.08)))
	if span <= 0.0001:
		return out
	for k in range(1, n + 1):
		out.append(_loop_pt(a0 + s * span * float(k) / n))
	return out


static func _span(a0: float, a1: float, s: float) -> float:
	return wrapf(s * (a1 - a0), 0.0, TAU)


# every switch on the loop the arc runs over (not at its ends) lies straight
static func _passed(a0: float, s: float, span: float, sw: Dictionary) -> void:
	for z in stations():
		if z == "ring":
			continue
		for side: float in [1.0, -1.0]:
			var id: String = z + (":+" if side > 0.0 else ":-")
			var x := _span(a0, _angle(z) + side * _turn(z), s)
			if x > 0.01 and x < span - 0.01 and not sw.has(id):
				sw[id] = 0.0
	for pid in [["p1:a", FW.PASS_A], ["p1:b", FW.PASS_B]]:
		var xp := _span(a0, float(pid[1]), s)
		if xp > 0.01 and xp < span - 0.01 and not sw.has(pid[0]):
			sw[pid[0]] = 0.0


# one way to run it: leave `from` heading s1 round the loop, reach `to` heading s2; heading the
# other way, reverse once — past `to`'s switch ("a") or just past `from`'s ("b")
static func _plan(from: String, to: String, s1: float, s2: float, opt: String) -> Array:
	var clear := CLEAR / LOOP_R
	var a0 := RING_A
	var head: Array = [station_at("ring")]
	var sw0 := {}
	if from == "salvage":
		sw0["salvage:s"] = 0.0
	if from != "ring":
		a0 = _angle(from) + s1 * _turn(from)
		head = _leg(from) + _turnout(from, s1).slice(1)
		sw0[from + ":f"] = 1.0 if s1 > 0.0 else 0.0
		sw0[from + (":+" if s1 > 0.0 else ":-")] = 1.0
	var b := RING_A
	var tail: Array = []
	var swt := {}
	if to == "salvage":
		swt["salvage:s"] = 0.0
	if to != "ring":
		b = _angle(to) - s2 * _turn(to)
		var back := _turnout(to, -s2)
		back.reverse()
		tail.append_array(back.slice(1))
		var lg := _leg(to)
		lg.reverse()
		tail.append_array(lg.slice(1))
		swt[to + (":+" if -s2 > 0.0 else ":-")] = 1.0
		swt[to + ":f"] = 1.0 if -s2 > 0.0 else 0.0
	if s1 == s2:
		var span := _span(a0, b, s1)
		var sw := sw0.duplicate()
		sw.merge(swt)
		_passed(a0, s1, span, sw)
		return [{"pts": head + _arc(a0, s1, span) + tail, "sw": sw}]
	var span1: float = _span(a0, b, s1) + clear if opt == "a" else clear
	var r := a0 + s1 * span1
	var sw1 := sw0.duplicate()
	_passed(a0, s1, span1, sw1)
	var span2 := _span(r, b, s2)
	var sw2 := swt.duplicate()
	_passed(r, s2, span2, sw2)
	return [{"pts": head + _arc(a0, s1, span1), "sw": sw1}, {"pts": [_loop_pt(r)] + _arc(r, s2, span2) + tail, "sw": sw2}]


# the ride from one stop to another as legs, the shortest way counting a reversal as 30 m
static func plan(from: String, to: String, live := false) -> Array:
	var best: Array = []
	var best_cost := INF
	for s1: float in [1.0, -1.0]:
		for s2: float in [1.0, -1.0]:
			var opts: Array = ["a"] if s1 == s2 or from == "ring" else ["a", "b"]
			for opt in opts:
				var lg := _plan(from, to, s1, s2, opt)
				var cost := REVERSE_COST * (lg.size() - 1)
				for l in lg:
					cost += Art.length(l.pts) / Geom.M
				if live and avoid.is_valid():
					cost += float(avoid.call(lg))
				if cost < best_cost - 0.01:
					best = lg
					best_cost = cost
	return best


static func route(from: String, to: String) -> Array:
	var out: Array = []
	for l in plan(from, to):
		out.append_array(l.pts if out.is_empty() else (l.pts as Array).slice(1))
	return out


# the drone at station `here` wants `to`: if the car is already here it opens its doors
# at once; otherwise it comes to this station first, then goes on
func call_to(here: String, to: String) -> bool:
	# 130 号: on its way back to the hub out of the freight's way: the call waits for it to get there
	if active() and phase == "return" and to != here and to in stations():
		_queued = [here, to]
		return true
	if not active() or phase != "" or to == here or to not in stations():
		return false
	dest = to
	_wait_here = here
	speed = 0.0
	if at == here or position_px.distance_to(station_at(here)) < 1.0 * Geom.M:
		position_px = station_at(here)
		_ride_from = here
		legs = plan(here, to, true)
		FW.passenger_request(self, legs)
		_next_leg()
		stop = here
		_begin_board()
	else:
		_from = at
		legs = plan(at, here, true)
		FW.passenger_request(self, legs)
		_next_leg()
		stop = ""
		phase = "fetch"
	at = ""
	return true


# 130 号: still at its stop and waiting on freight: every second, the way round the other side if it is
# clearer now (the freight standing in the way counts against a way: Tram.avoid)
var _queued: Array = []        # a call made while it was going back to the hub: [here, to]
const CLEAR_R := 25.0          # m: no drone this close to its stop, it may go back to the hub for freight


# 130 号: standing idle at a district's stop with a freight train held up behind it and no drone
# about: back to the hub's stop, out of the way
func _maybe_clear() -> void:
	if not FW.tram_clear:
		return
	FW.tram_clear = false
	if phase != "" or at == "" or at == "ring":
		return
	var d = game.drone if game != null else null
	if d != null and d.alive and (d.global_position as Vector2).distance_to(station_at(at)) < CLEAR_R * Geom.M:
		return
	legs = plan(at, "ring", true)
	if legs.is_empty():
		return
	FW.passenger_request(self, legs)
	_next_leg()
	stop = ""
	at = ""
	speed = 0.0
	phase = "return"


var _replan_t := 0.0
var _from := ""
var _ride_from := ""
func _replan(dt: float) -> void:
	_replan_t += dt
	if _replan_t < 1.0:
		return
	_replan_t = 0.0
	var start := ""
	var to := ""
	if phase == "fetch":
		start = _from
		to = _wait_here
	elif phase == "ride":
		start = _ride_from
		to = dest
	if start == "" or to == "" or start == to or position_px.distance_to(station_at(start)) > 0.5 * Geom.M:
		return
	var lg := plan(start, to, true)
	if lg.is_empty():
		return
	legs = lg
	FW.passenger_request(self, legs)
	_next_leg()


func _next_leg() -> void:
	var lg: Dictionary = legs.pop_front()
	_set_path(lg.pts)
	_leg_sw = lg.sw
	if FW.on:
		return
	for id in _leg_sw:
		sw_to[id] = float(_leg_sw[id])
		_points_dirty = true


# the switches the running leg needs, all set
func _set_ready() -> bool:
	for id in _leg_sw:
		if absf(float(sw_pos.get(id, 0.0)) - float(_leg_sw[id])) > 0.001:
			return false
	return true


# the rails round every corner on an arc (35 号): the points, each with the speed its curve allows
static func smooth(points: Array) -> Array:
	var M := Geom.M
	var pts: Array = []
	var lim: Array = []
	if points.size() < 2:
		return [points.duplicate(), points.map(func(_p): return SPEED)]
	pts.append(points[0])
	lim.append(SPEED)
	for i in range(1, points.size() - 1):
		var a: Vector2 = points[i - 1]
		var b: Vector2 = points[i]
		var c: Vector2 = points[i + 1]
		var d1 := (b - a).normalized()
		var d2 := (c - b).normalized()
		var turn := absf(d1.angle_to(d2))
		# a point on a drawn curve (the loop, a turnout) bends a little: its own radius rules it below
		if turn < 0.3:
			pts.append(b)
			lim.append(SPEED)
			continue
		var r := CURVE_R * M
		var tl := r * tan(turn * 0.5)
		var room := minf(a.distance_to(b), b.distance_to(c)) * 0.45
		if tl > room:
			tl = room
			r = tl / tan(turn * 0.5)
		var p0 := b - d1 * tl
		var p1 := b + d2 * tl
		var v := minf(SPEED, sqrt(A_LAT * maxf(r, 1.0)))
		# the arc from p0 to p1: a quadratic through the corner is close enough at these angles
		for k in 17:
			var s := float(k) / 16.0
			pts.append(p0.lerp(b, s).lerp(b.lerp(p1, s), s))
			lim.append(v)
	pts.append(points[points.size() - 1])
	lim.append(0.0)
	# a densely drawn curve (the loop, a turnout): each point's own radius limits it too
	for i in range(1, pts.size() - 1):
		var pa: Vector2 = pts[i - 1]
		var pb: Vector2 = pts[i]
		var pc: Vector2 = pts[i + 1]
		var cross := absf((pb - pa).cross(pc - pa))
		if cross > 0.001:
			var rr := pa.distance_to(pb) * pb.distance_to(pc) * pc.distance_to(pa) / (2.0 * cross)
			lim[i] = minf(float(lim[i]), sqrt(A_LAT * rr))
	return [pts, lim]


func _set_path(points: Array) -> void:
	var sm := smooth(points)
	path = sm[0]
	limits = sm[1]
	if not path.is_empty() and (path[0] as Vector2).distance_to(position_px) < 1.0:
		path.pop_front()
		limits.pop_front()
	# a station is a dead end: the push-pull train runs back the way it came with its rear car
	# leading (it used to swing round on the spot, the second car jumping to the other side)
	if not path.is_empty() and trail.is_empty():
		# standing where it was left (a fresh scene): the second car on the rails behind it, the
		# station's dead end ahead
		var back := ((path[0] as Vector2) - position_px).normalized()
		heading = (-back).angle()
		for k in range(1, 13):
			trail.append(position_px + back * k * 0.5 * Geom.M)
	if not path.is_empty() and not trail.is_empty():
		var dir := ((path[0] as Vector2) - position_px).normalized()
		if dir.dot(Vector2.from_angle(heading)) < -0.5:
			_reverse()


func _reverse() -> void:
	var M := Geom.M
	var rear := _rear_now()
	# where the cars stand, head first: the head, the trail back to the rear car
	var seg: Array = [position_px]
	var left := COUPLE * M
	var prev := position_px
	for p in trail:
		var d: float = prev.distance_to(p)
		if d >= left:
			break
		seg.append(p)
		left -= d
		prev = p
	# the new lead's trail: back to where the head stands, and on past it the way the head faced
	var fwd := Vector2.from_angle(heading)
	var nt: Array = []
	for i in range(seg.size() - 1, -1, -1):
		nt.append(seg[i])
	for k in range(1, 9):
		nt.append(position_px + fwd * k * 0.5 * M)
	trail = nt
	position_px = rear
	heading = (-fwd).angle()
	lead = 1 - lead
	_th = [INF, INF]
	# the rails the new lead already stands past
	while not path.is_empty() and ((path[0] as Vector2) - position_px).dot(-fwd) <= 0.0:
		path.pop_front()
		if not limits.is_empty():
			limits.pop_front()


func _begin_board() -> void:
	phase = "board"
	dwell = 0.0
	riding = true
	slide_from = game.drone.global_position
	var d = game.drone
	d.collision_layer = 0
	d.collision_mask = 0
	d.linear_velocity = Vector2.ZERO


func _remaining() -> float:
	var total := 0.0
	var prev := position_px
	for wp in path:
		total += prev.distance_to(wp)
		prev = wp
	return total


var _wait_here := ""


func _finish_alight() -> void:
	riding = false
	phase = ""
	dest = ""
	var d = game.drone
	d.global_position = alight_at(at) if at != "" else position_px + Vector2(0, -2.4 * Geom.M)
	d.linear_velocity = Vector2.ZERO
	d.collision_layer = 2
	d.collision_mask = 1 | 4 | World.STATIC_LAYER
	d.visible = true


# follow the rails (35 号): speed up at 6 m/s² to 20 m/s, slow before each curve to what
# 4 m/s² sideways allows on its radius, brake into the stop
func _advance(dt: float) -> bool:
	if path.is_empty():
		return true
	# 130 号: freight on the route: wait (it is giving way), then throw this leg's switches
	if FW.on:
		if not FW.passenger_go(self):
			accel_now = -speed / maxf(dt, 1e-4)
			speed = 0.0
			_replan(dt)
			return false
		for id in _leg_sw:
			if float(sw_to.get(id, -1.0)) != float(_leg_sw[id]):
				sw_to[id] = float(_leg_sw[id])
				_points_dirty = true
	# 97 号: standing while the driver changes ends or the switches ahead are still moving
	if _hold > 0.0 or not _set_ready():
		_hold -= dt
		accel_now = -speed / maxf(dt, 1e-4)
		speed = 0.0
		return false
	var cap := SPEED
	var dist := 0.0
	var prev := position_px
	for i in path.size():
		dist += prev.distance_to(path[i])
		prev = path[i]
		var lim: float = limits[i] if i < limits.size() else SPEED
		cap = minf(cap, sqrt(lim * lim + 2.0 * ACCEL * dist))
		if dist > SPEED * SPEED / (2.0 * ACCEL):
			break
	var was := speed
	speed = clampf(cap, 0.0, speed + ACCEL * dt)
	accel_now = (speed - was) / maxf(dt, 1e-4)
	var step := speed * dt
	while step > 0.0 and not path.is_empty():
		var wp: Vector2 = path[0]
		var d := wp - position_px
		if d.length() <= step:
			step -= d.length()
			position_px = wp
			path.pop_front()
			if not limits.is_empty():
				limits.pop_front()
		else:
			position_px += d.normalized() * step
			step = 0.0
	# the car's heading: from its rear bogie to its front one, both on the rails — it turns
	# continuously through a curve (taking the next segment's direction made it jump at each point)
	var hb := _ahead(BOGIE * Geom.M) - _behind(BOGIE * Geom.M)
	if hb.length() > 0.01:
		heading = hb.angle()
	if trail.is_empty() or (trail[0] as Vector2).distance_to(position_px) > 0.25 * Geom.M:
		trail.push_front(position_px)
		if trail.size() > 80:
			trail.pop_back()
	return path.is_empty()


# run the legs: true when the last one has stopped at its stop
func _run(dt: float) -> bool:
	if not _advance(dt):
		return false
	if legs.is_empty():
		return true
	# a reversal: stop clear of the switch, change ends, the switch throws, back out over it
	_next_leg()
	_hold = HOLD
	return false


var accel_now := 0.0
const BOGIE := 1.0             # m from a car's centre to each bogie


# the point a given distance ahead along the rails still to run
func _ahead(dist: float) -> Vector2:
	var left := dist
	var prev := position_px
	for wp in path:
		var seg: float = prev.distance_to(wp)
		if seg >= left:
			return prev.lerp(wp, left / maxf(seg, 0.001))
		left -= seg
		prev = wp
	return prev + Vector2.from_angle(heading) * left


func _rear_now() -> Vector2:
	return _behind(COUPLE * Geom.M) if not trail.is_empty() else position_px - Vector2.from_angle(heading) * COUPLE * Geom.M


# the point a given distance back along where the front car has been
func _behind(back: float) -> Vector2:
	var left := back
	var prev := position_px
	for p in trail:
		var seg: float = prev.distance_to(p)
		if seg >= left:
			return prev.lerp(p, left / maxf(seg, 0.001))
		left -= seg
		prev = p
	return prev - Vector2.from_angle(heading) * left


# standing at a stop with no track behind it yet (a fresh scene, a save loaded): the cab faces the
# stop's dead end (on the hub's loop, along the loop) and the second car stands behind it on the rails
# — the trail laid along the track itself, not a straight line (on the loop's curve, or any heading,
# a straight one stood the second car off the rails)
func _settle(zone: String) -> void:
	if zone not in stations():
		return
	var M := Geom.M
	trail = []
	if zone == "ring":
		var step := 0.5 / LOOP_R
		for k in range(1, 25):
			trail.append(_loop_pt(RING_A - k * step))
		heading = (RING_A + PI * 0.5)
		return
	var pts: Array = smooth(_leg(zone))[0]
	var acc := 0.0
	var want := 0.5 * M
	var prev: Vector2 = pts[0]
	for i in range(1, pts.size()):
		var q: Vector2 = pts[i]
		var seg := prev.distance_to(q)
		while acc + seg >= want and trail.size() < 24:
			trail.append(prev.lerp(q, (want - acc) / maxf(seg, 0.001)))
			want += 0.5 * M
		acc += seg
		prev = q
	heading = ((pts[0] as Vector2) - (pts[1] as Vector2)).angle()


# a point s along the train from the head car's centre (ahead +, behind −)
func _along(s: float) -> Vector2:
	return _ahead(s) if s >= 0.0 else _behind(-s)


# the four bogies on the rails, each turned along them, and the bodies on their springs
func _poses() -> void:
	var M := Geom.M
	_bob_p = _bob.duplicate()
	_boa_p = _boa.duplicate()
	# the lead car's cab end leads; the other car's cab is at the far end of the train
	var s_of := {lead * 2: BOGIE, lead * 2 + 1: -BOGIE, (1 - lead) * 2: -COUPLE - BOGIE, (1 - lead) * 2 + 1: -COUPLE + BOGIE}
	for i in 4:
		var s: float = s_of[i] * M
		_bob[i] = _along(s)
		var tg: Vector2 = _along(s + 0.3 * M) - _along(s - 0.3 * M)
		_boa[i] = tg.angle() if tg.length() > 0.01 else heading
	if _bob_p[0] == Vector2.ZERO:
		_bob_p = _bob.duplicate()
		_boa_p = _boa.duplicate()


func _springs(dt: float) -> void:
	var M := Geom.M
	for c in 2:
		var axis: Vector2 = (_bob[c * 2] as Vector2) - (_bob[c * 2 + 1] as Vector2)
		if axis.length() < 0.01:
			continue
		# the way the car travels: the lead car cab first, the other inner end first
		var dir: Vector2 = axis.normalized() * (1.0 if c == lead else -1.0)
		var th := dir.angle()
		var w: float = 0.0 if _th[c] == INF else angle_difference(float(_th[c]), th) / maxf(dt, 1e-4)
		_th[c] = th
		var a_lat := speed / M * w
		var a_long := accel_now / M
		var target := -(dir * a_long * K_LONG + dir.rotated(PI * 0.5) * a_lat * K_LAT)
		var lv: Vector2 = lean_v[c]
		lv += ((target - (lean[c] as Vector2)) * SPRING_W * SPRING_W - lv * 2.0 * SPRING_Z * SPRING_W) * dt
		lean_v[c] = lv
		lean[c] = ((lean[c] as Vector2) + lv * dt).limit_length(0.16)


func _sound(name: String, at_px: Vector2, vol: float) -> void:
	var sfx = game.get("sfx") if game != null else null
	if sfx != null and is_instance_valid(sfx):
		sfx.play(name, at_px, vol)


# an actuator to its target: speeding up, braking in time to stop on it (as scripts/tug_works.gd)
static func _drive(cur: float, vel: float, to: float, vmax: float, acc: float, dt: float) -> Array:
	var d := to - cur
	var want := clampf(sqrt(2.0 * acc * absf(d)) * signf(d), -vmax, vmax)
	vel = move_toward(vel, want, acc * 2.0 * dt)
	var nxt := cur + vel * dt
	if signf(to - nxt) != signf(d) or absf(to - nxt) < 0.002:
		return [to, 0.0]
	return [nxt, vel]


func _machines(dt: float) -> void:
	for id in sw_to:
		var p := float(sw_pos.get(id, 0.0))
		var to := float(sw_to[id])
		if p != to:
			var r := _drive(p, float(sw_vel.get(id, 0.0)), to, SW_V, SW_A, dt)
			sw_pos[id] = r[0]
			sw_vel[id] = r[1]
			_points_dirty = true
			# the points home and lock: the machine's thunk (a real recording, assets/audio/points.ogg)
			if float(r[0]) == to and _toes.has(id):
				_sound("points", (_toes[id] as Vector2) + Backdrop.port_centre_px(), 0.55)
	# the doors: open while the drone boards or steps off, shut before the train moves
	for c in 2:
		var want := 0.0
		if phase == "board" and dwell > 0.08 and dwell < 0.84:
			want = 1.0
		elif phase == "alight" and dwell > 0.06:
			want = 1.0
		if c == 0 and want > 0.5 and float(door[c]) == 0.0 and float(door_v[c]) == 0.0:
			_sound("door", position_px, 0.45)
		var r2 := _drive(float(door[c]), float(door_v[c]), want, 4.0, 22.0, dt)
		door[c] = r2[0]
		door_v[c] = r2[1]


func _physics_process(dt: float) -> void:
	t += dt
	if not active():
		return
	var t0 := Time.get_ticks_usec()
	var d = game.drone
	match phase:
		"":
			_maybe_clear()
		"return":
			if _run(dt):
				speed = 0.0
				accel_now = 0.0
				at = "ring"
				stop = ""
				phase = ""
				FW.passenger_arrived(self)
				if not _queued.is_empty():
					var q: Array = _queued
					_queued = []
					call_to(q[0], q[1])
		"fetch":
			if _run(dt):
				# at the caller's station: doors open
				speed = 0.0
				accel_now = 0.0
				position_px = station_at(_wait_here)
				FW.passenger_arrived(self)
				_ride_from = _wait_here
				legs = plan(_wait_here, dest, true)
				FW.passenger_request(self, legs)
				_next_leg()
				speed = 0.0
				stop = _wait_here
				_begin_board()
		"board":
			dwell += dt
			var k := clampf((dwell - 0.38) / 0.42, 0.0, 1.0)
			k = k * k * (3.0 - 2.0 * k)
			if d != null:
				d.global_position = slide_from.lerp(position_px, k)
				d.linear_velocity = Vector2.ZERO
				d.visible = k < 0.999
			if dwell >= DWELL:
				_wait_here = ""
				stop = ""
				phase = "ride"
				speed = 0.0
		"ride":
			if d != null:
				d.global_position = position_px
				d.linear_velocity = Vector2.ZERO
				d.visible = false
			if _run(dt):
				speed = 0.0
				accel_now = 0.0
				at = dest
				stop = dest
				FW.passenger_arrived(self)
				phase = "alight"
				dwell = 0.0
				slide_from = position_px
		"alight":
			dwell += dt
			var k := clampf((dwell - 0.32) / 0.4, 0.0, 1.0)
			k = k * k * (3.0 - 2.0 * k)
			if d != null:
				d.visible = dwell > 0.32
				d.global_position = slide_from.lerp(alight_at(at), k)
				d.linear_velocity = Vector2.ZERO
			if dwell >= ALIGHT:
				_finish_alight()
	_machines(dt)
	_poses()
	_springs(dt)
	step_us = lerpf(step_us, float(Time.get_ticks_usec() - t0), 0.05)


func _process(_dt: float) -> void:
	visible = active()
	if not visible:
		return
	queue_redraw()
	# the meshes are in the port's frame, their layers placed at the port's centre: the layer's place,
	# not a transform on the draw (a mesh drawn with one is culled by its own untransformed bounds,
	# around the world's origin — user 2026-10-28: the rails vanished out by the power district)
	var pc := Backdrop.port_centre_px()
	rails.position = pc
	points.position = pc
	# only the berth's lift (its stop) changes them
	var geo := station_at("salvage") - pc
	if geo.distance_to(_geo) > 0.5:
		_geo = geo
		_build()
	# the track built a slice a frame from the next one on; the old one stays drawn until the
	# new is whole
	elif _job != null and _job.step(BUILD_SLICE):
		_track = _job.meshes
		build_us = _job.total_us
		build_slice_us = _job.slowest_us
		build_job_us = _job.slowest_job_us
		build_cut_us = _job.slowest_cut_us
		_job = null
		rails.queue_redraw()
	if game.cam != null and absf(game.cam_zoom() - _rails_z) > 0.0005:
		_rails_z = game.cam_zoom()
		lines_mat.set_shader_parameter("zoom", maxf(_rails_z, 0.02))
	if _points_dirty:
		_points_dirty = false
		points.queue_redraw()
	else:
		for id in sw_to:
			if float(sw_pos.get(id, 0.0)) != float(sw_to[id]):
				points.queue_redraw()
				break


# ---------------------------------------------------------------- the still parts (97 号)

func _build() -> void:
	var t0 := Time.get_ticks_usec()
	var c := Backdrop.port_centre_px()
	var M := Geom.M
	var rel := func(pts: Array) -> Array: return pts.map(func(p): return (p as Vector2) - c)
	var lines: Array = []
	var loop: Array = []
	for k in 121:
		loop.append(_loop_pt(TAU * k / 120.0))
	lines.append({"pts": rel.call(loop)})
	var toes: Array = []
	var stops: Array = []
	_switches = []
	_stops = []
	for zone in stations():
		var n := platform_side(zone)
		var sd := station_dir(zone)
		var sp := station_at(zone)
		# 129 号: the hub stop's sign stands past the berth arm's turret (over the platform's middle it
		# stood under the arm's hatch, the arm and its crates over it)
		var post := sp + n * 2.25 * M + sd * (RING_SIGN if zone == "ring" else 1.6) * M
		var sign := Rect2(post + n * 0.5 * M - Vector2(0.55, 0.28) * M, Vector2(1.1, 0.56) * M)
		_stops.append({"z": zone, "p": sp - c, "n": n, "d": sd, "sign": Rect2(sign.position - c, sign.size)})
		# 130 号: where the freight line runs on past the stop into the district, no buffer at the stop
		var ext: bool = zone in FW.EXT_ZONES
		stops.append({"at": sp - c, "d": sd, "n": n, "end": zone != "ring" and not ext, "post": post - c, "sign": Rect2(sign.position - c, sign.size)})
		if ext:
			lines.append({"pts": rel.call([sp, FW.ext_end(zone)])})
		if zone == "salvage":
			# 130 号: the freight siding beside the berth's line, and its switch
			var sid: Array = FW.siding_pts()
			lines.append({"pts": rel.call(sid), "skip_a": 2.5})
			var ax := ((sid[1] as Vector2) - (sid[0] as Vector2)).normalized()
			_switches.append({"id": "salvage:s", "a": _blade(rel.call(FW.siding_main())), "b": _blade(rel.call(sid)), "side": -ax.orthogonal()})
		if zone == "ring":
			continue
		var leg: Array = smooth(_leg(zone))[0]
		var ld := ((leg[1] as Vector2) - (leg[0] as Vector2)).normalized()
		# at a dead end the rails run on past the stop to the buffer (the cab's bogie stands a metre
		# past the stop's point)
		if not ext:
			leg = [sp - sd * BUFFER_AT * M] + leg
		lines.append({"pts": rel.call(leg)})
		for s: float in [1.0, -1.0]:
			lines.append({"pts": rel.call(_turnout(zone, s)), "skip_a": 2.5, "skip_b": 3.2})
		# the fork at the line's end and the two points where its turnouts meet the loop
		var rim: Vector2 = _leg(zone)[-1]
		var a := _angle(zone)
		var fa := _turnout(zone, -1.0)
		var fb := _turnout(zone, 1.0)
		_switches.append({"id": zone + ":f", "a": _blade(rel.call(fa)), "b": _blade(rel.call(fb)), "side": -ld.orthogonal() * signf(n.dot(ld.orthogonal()) + 0.01)})
		toes.append(rim - c)
		for side: float in [1.0, -1.0]:
			var ja: float = a + side * _turn(zone)
			var straight: Array = []
			for k in 9:
				straight.append(_loop_pt(ja - side * k * 0.03))
			var turn := _turnout(zone, side)
			turn.reverse()
			_switches.append({"id": zone + (":+" if side > 0.0 else ":-"), "a": _blade(rel.call(straight)), "b": _blade(rel.call(turn)), "side": -Vector2.from_angle(ja)})
			toes.append(_loop_pt(ja) - c)
	# 130 号: the passing loop inside the ring and its two switches (scripts/freight_works.gd)
	var pp: Array = FW.pass_pts()
	lines.append({"pts": rel.call(pp), "skip_a": 2.5, "skip_b": 2.5})
	var main_a: Array = []
	var main_b: Array = []
	for k in 9:
		main_a.append(_loop_pt(FW.PASS_A + k * 0.03))
		main_b.append(_loop_pt(FW.PASS_B - k * 0.03))
	var pb: Array = pp.duplicate()
	pb.reverse()
	_switches.append({"id": "p1:a", "a": _blade(rel.call(main_a)), "b": _blade(rel.call(pp)), "side": Vector2.from_angle(FW.PASS_A)})
	_switches.append({"id": "p1:b", "a": _blade(rel.call(main_b)), "b": _blade(rel.call(pb)), "side": Vector2.from_angle(FW.PASS_B)})
	_toes = {}
	for sw in _switches:
		_toes[sw.id] = sw.a[0]
	track_lines = lines.map(func(l): return (l.pts as Array).map(func(q): return (q as Vector2) + c))
	_job = Art.track_job(lines, toes, stops, M)
	plan_us = Time.get_ticks_usec() - t0
	_points_dirty = true


var build_us := 0            # tests: what building the still track took in all, its longest slice of a
var build_slice_us := 0      # frame, and the lines and switches worked out before it (one frame)
var plan_us := 0
var build_job_us := 0
var build_cut_us := 0
var _stops: Array = []       # [{z, p, n, d, sign}] each stop, the port's frame (built with the meshes)
var _mesh := {}              # the train's parts (scripts/tram_art.gd), built once
var draw_us := 0.0           # tests: the train and the stops' drawing a frame, physics a step (µs, smoothed)
var step_us := 0.0


# a switch's branch from its toe, BLADE metres of it at seven even points
static func _blade(pts: Array) -> Array:
	var out: Array = []
	for k in 7:
		out.append(Art.at_len(pts, Art.BLADE * Geom.M * k / 6.0)[0])
	return out


func _draw_rails() -> void:
	if not active() or _track.is_empty():
		return
	rails_draws += 1
	for mesh in _track:
		rails.draw_mesh(mesh, null)


func _draw_points() -> void:
	if not active() or _switches.is_empty():
		return
	var pen := Art.Pen.new()
	pen.m = Geom.M
	for sw in _switches:
		var id: String = sw.id
		var p := float(sw_pos.get(id, 0.0))
		Art.draw_switch(pen, sw, p, p != float(sw_to.get(id, p)), t, Geom.M)
	# kept: the canvas holds only the mesh's RID, and a mesh freed after this call left the
	# renderer reading a dead one every frame ("Parameter mesh is null")
	_points_mesh = pen.mesh()
	points.draw_mesh(_points_mesh, null)


# ---------------------------------------------------------------- every frame

func _draw() -> void:
	if not active():
		return
	var t0 := Time.get_ticks_usec()
	var M := Geom.M
	var z: float = maxf(game.cam_zoom(), 0.02)
	var lw := 1.0 / z
	var font := Fonts.get_font("Medium")
	# stations: the sign on its post stands in the still mesh; here the lit sign of the stop the
	# drone is at, the names of the stops in view (at screen size), the call hint
	var near := near_station()
	var view := (get_canvas_transform().affine_inverse() * get_viewport_rect()).grow(4.0 * M)
	var show_names := z >= 0.15
	var pc := Backdrop.port_centre_px()
	for st in _stops:
		var on: bool = st.z == near
		if not (on or (show_names and view.has_point((st.p as Vector2) + pc))):
			continue
		var col: Color = Pal.tint(Pal.FLUID, 0.95 if on else 0.5, 1.2)
		var sign := Rect2((st.sign as Rect2).position + pc, (st.sign as Rect2).size)
		if on:
			draw_rect(Rect2(sign.position, Vector2(sign.size.x, 0.14 * M)), col)
			draw_rect(sign, col, false, 1.2 * lw)
		draw_set_transform(sign.get_center(), 0, Vector2.ONE / z)
		var below := 0.28 * M * z + 16.0
		if st.z == "ring":
			# 130 号: the hub stop's name beside its sign, on the deck inside the loop (under it, it lay
			# across the rails the freight trains run on)
			draw_string(font, Vector2(0.55 * M * z + 6.0, 4.0), Txt.t("tram_station") + " · " + Port.name_of(st.z), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
		else:
			draw_string(font, Vector2(-90, below), Txt.t("tram_station") + " · " + Port.name_of(st.z), HORIZONTAL_ALIGNMENT_CENTER, 180, 12, col)
		if on and not riding:
			draw_string(font, Vector2(-110, -0.28 * M * z - 10.0), Txt.t("tram_call") % Keys.label("use"), HORIZONTAL_ALIGNMENT_CENTER, 220, 15, Pal.ink(0.95))
		draw_set_transform(Vector2.ZERO)
	# the train, when it is in view
	if view.grow(8.0 * M).has_point(position_px):
		_draw_train(M, z, lw, font)
	draw_us = lerpf(draw_us, float(Time.get_ticks_usec() - t0), 0.05)


func _draw_train(M: float, z: float, lw: float, font: Font) -> void:
	var v := speed / SPEED
	var f := Engine.get_physics_interpolation_fraction()
	var pos: Array = []
	var ang: Array = []
	var bp: Array = []
	for i in 4:
		bp.append((_bob_p[i] as Vector2).lerp(_bob[i], f))
	for c in 2:
		var cab: Vector2 = bp[c * 2]
		var inner: Vector2 = bp[c * 2 + 1]
		pos.append((cab + inner) * 0.5)
		ang.append((cab - inner).angle())
	var sc := Vector2(M, M)
	# shadows, the bodies' sides on the bogies, the roofs where the springs have swung them
	for c in 2:
		draw_mesh(_mesh.shadow, null, Transform2D(ang[c], sc, 0.0, pos[c] + ((lean[c] as Vector2) + Vector2(0.18, 0.28)) * M))
	for c in 2:
		draw_mesh((_mesh.side_lit if riding else _mesh.side), null, Transform2D(ang[c], sc, 0.0, pos[c]))
	# the gangway's bellows between the inner ends
	var ends: Array = []
	for c in 2:
		var xf := Transform2D(ang[c], sc, 0.0, pos[c] + (lean[c] as Vector2) * M)
		ends.append([xf * Vector2(-Art.CAR_L * 0.5, -0.6), xf * Vector2(-Art.CAR_L * 0.5, 0.6)])
	var e0: Array = ends[0]
	var e1: Array = ends[1]
	draw_primitive(PackedVector2Array([e0[0], e0[1], e1[0], e1[1]]), PackedColorArray([Art.DARK, Art.DARK, Art.DARK, Art.DARK]), PackedVector2Array())
	var pleats := PackedVector2Array()
	for k in 5:
		var q := (k + 0.5) / 5.0
		pleats.append_array([(e0[0] as Vector2).lerp(e1[1], q), (e0[1] as Vector2).lerp(e1[0], q)])
	draw_multiline(pleats, Pal.ink(0.28), lw)
	for c in 2:
		var xf := Transform2D(ang[c], sc, 0.0, pos[c] + (lean[c] as Vector2) * M)
		draw_mesh(_mesh.roof[c], null, xf)
		if door[c] > 0.002:
			_doors(c, xf, M, lw)
	# the bogies, seen through the roof as hidden lines
	for i in 4:
		draw_mesh(_mesh.bogie[0 if i < 2 else 1], null, Transform2D(lerp_angle(_boa_p[i], _boa[i], f), sc, 0.0, bp[i]), Color(1, 1, 1, 0.13))
	# the lights: the lead cab's headlamps and the beam ahead, the far cab's tail lamps
	for c in 2:
		var xf := Transform2D(ang[c], sc, 0.0, pos[c] + (lean[c] as Vector2) * M)
		var front: bool = c == lead
		for y: float in [-0.36, 0.36]:
			var lp: Vector2 = xf * Vector2(Art.CAR_L * 0.5 - 0.02, y)
			if front:
				FastDraw.circle(self, lp, 0.1 * M, Pal.ink(0.95, 1.7 if phase != "" else 1.1))
			else:
				FastDraw.circle(self, lp, 0.09 * M, Pal.heat(0.95, 1.6))
		if front:
			var fwd := Vector2.from_angle(ang[c])
			var nose: Vector2 = xf * Vector2(Art.CAR_L * 0.5, 0.0)
			var cone := Color(0.75, 0.9, 1.0, (0.1 + 0.06 * v) if phase != "" else 0.04)
			var clear := Color(cone, 0.0)
			draw_primitive(PackedVector2Array([nose, nose + fwd * 9.0 * M + fwd.orthogonal() * 2.4 * M, nose + fwd * 9.0 * M - fwd.orthogonal() * 2.4 * M]), PackedColorArray([cone, clear, clear]), PackedVector2Array())
	# its number by the lead cab, screen size
	var tag: Vector2 = pos[lead] + Vector2(0, -1.4 * M)
	draw_set_transform(tag, 0, Vector2.ONE / z)
	draw_string(font, Vector2(-10, 0), "T-1", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Pal.ink(0.5))
	draw_set_transform(Vector2.ZERO)


# a car's doors on the platform's side: the leaves step out and slide apart, the lit doorway
# between them throws its light across the platform, the lamp over each blinks while they move
func _doors(c: int, xf: Transform2D, M: float, lw: float) -> void:
	var k := float(door[c])
	var n: Vector2 = platform_side(stop) if stop != "" else Vector2.UP
	var side: float = 1.0 if (xf.y.normalized()).dot(n) >= 0.0 else -1.0
	var w := Art.CAR_W * 0.5
	var lit := Pal.tint(Pal.AIR, 0.9, 1.5)
	for x: float in Art.DOORS:
		var out := side * (w + 0.04 + 0.05 * k)
		var gap := Art.DOOR_W * k
		var a: Vector2 = xf * Vector2(x - gap * 0.5, side * w)
		var b: Vector2 = xf * Vector2(x + gap * 0.5, side * w)
		var a2: Vector2 = xf * Vector2(x - gap * 0.5 - 0.12, side * (w + 0.9))
		var b2: Vector2 = xf * Vector2(x + gap * 0.5 + 0.12, side * (w + 0.9))
		var spill := Color(lit, 0.2 * k)
		draw_primitive(PackedVector2Array([a, b, b2, a2]), PackedColorArray([spill, spill, Color(lit, 0.0), Color(lit, 0.0)]), PackedVector2Array())
		draw_line(a, b, lit, 2.0 * lw)
		var leaf: ArrayMesh = _mesh.leaf
		var rot: float = xf.get_rotation()
		draw_mesh(leaf, null, Transform2D(rot, Vector2(M, M), 0.0, xf * Vector2(x - 0.25 - 0.25 * k, out)))
		draw_mesh(leaf, null, Transform2D(rot, Vector2(M, M), 0.0, xf * Vector2(x + 0.25 * k, out)))
		if absf(float(door_v[c])) > 0.05 and fmod(t, 0.36) < 0.18:
			FastDraw.circle(self, xf * Vector2(x, side * (w - 0.12)), 0.07 * M, Pal.heat(1.0, 1.6))
