extends Node2D
# The port's rail shuttle (design/成长版本/G5-G7_工业港成长重设计_2026-10-22/21; 02 号
# "固定站点接驳"): one car on rails along every corridor and through the hub. A station
# inside each district's door and one in the hub. At a station the drone presses E,
# picks a district it has already discovered, and rides: the car comes to the station
# if it is elsewhere, the drone rides in it (hidden) along the corridor, through the hub
# and down the other corridor, and steps off at the far station. Seen, not teleported;
# a ride across the port takes about ten seconds.
# 97 号 test only: the shuttle as it was before 97 号, timed (tests/tram_shots.gd old=1)
const CanvasBatch = preload("res://scripts/canvas_batch.gd")

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
const SPEED := 20.0 * 48.0     # px/s (35 号: was 12 m/s)
const ACCEL := 6.0 * 48.0      # px/s²
const A_LAT := 4.0 * 48.0      # px/s²: what a curve allows sideways
const CURVE_R := 6.0           # m: the rails' curve radius at a corner, at most
const COUPLE := 3.6            # m between the two cars' centres
var limits: Array = []         # px/s: the speed allowed at each point of `path`
var trail: Array = []          # where the front car has been, newest first (the second car follows it)
const DWELL := 0.7             # s with the doors open
const REACH := 4.5             # m: the drone calls the car from this close
const STATION_IN := 2.5        # m inside the door


func active() -> bool:
	return game != null and game.in_berth() and game.career()


static func station_at(zone: String) -> Vector2:
	if zone == "ring":
		# on the hub's loop, at its bottom by the berth's spoke (35 号)
		return Backdrop.port_centre_px() + Vector2(0, LOOP_R) * PortStructure.M()
	# straight in at the door (where the consoles beside it leave room for it)
	var d: Array = PortStructure.door(zone)
	return d[0] + d[1] * STATION_IN * PortStructure.M()


static func stations() -> Array:
	var out: Array = ["ring"]
	for z in PortArt.ANGLE:
		if z != "salvage":
			out.append(z)
	return out


# the stations the drone may ride to: the hub always, a district once the drone has been in it
static func found() -> Array:
	var f: Array = Career.data.get("tram_found", []).duplicate() if not Career.data.is_empty() else []
	if "ring" not in f:
		f.append("ring")
	return f


static func discover(zone: String) -> void:
	if Career.data.is_empty() or zone == "" or zone == "salvage":
		return
	var f: Array = Career.data.get("tram_found", [])
	if zone not in f:
		f.append(zone)
		Career.data.tram_found = f


var rails: Node2D
var _rails_z := -1.0
var rails_draws := 0         # tests: how often the still rails were drawn
var draw_us := 0.0
var step_us := 0.0


func _ready() -> void:
	z_index = 4
	z_as_relative = false
	position_px = station_at(at)
	# the rails stand still: drawn once, again only when the zoom moves (35 号; ~5 ms a frame)
	rails = Node2D.new()
	rails.show_behind_parent = true
	rails.draw.connect(_draw_rails)
	add_child(rails)


func near_station() -> String:
	if not active() or game.drone == null or not game.drone.alive:
		return ""
	for s in stations():
		if game.drone.global_position.distance_to(station_at(s)) <= REACH * Geom.M:
			return s
	return ""


# the rails (35 号): each district's line runs station -> door -> the hub's rim, and joins a
# loop round the hub on a turnout curve; the car runs round the loop the short way and leaves
# on the other district's turnout. No corner sharper than the turnouts.
const LOOP_R := 21.5           # m: the loop's radius inside the hub (just inside its rim)
const TURNOUT := 0.8           # rad along the loop a turnout takes to join it (a long, easy curve)
const TURN_IN := 6.0           # m up the corridor from the rim where a turnout begins


static func _angle(zone: String) -> float:
	if zone == "ring":
		return PI * 0.5
	return ((PortStructure.door(zone)[0] as Vector2) - Backdrop.port_centre_px()).angle()


static func _loop_pt(a: float) -> Vector2:
	return Backdrop.port_centre_px() + Vector2.from_angle(a) * LOOP_R * PortStructure.M()


# a district's line out to the rim: [station, door, rim]
static func _leg(zone: String) -> Array:
	if zone == "ring":
		return [station_at("ring")]
	var c := Backdrop.port_centre_px()
	var d: Array = PortStructure.door(zone)
	var p: Vector2 = d[0]
	# the line ends a few metres up the corridor, where its turnouts begin to bend
	return [station_at(zone), p, c + (p - c).normalized() * (PortArt.HUB_R + TURN_IN) * PortStructure.M()]


# the turnout from a district's rim onto the loop at angle `a + s·TURNOUT`: a cubic that leaves
# the rim along the line and meets the loop along its tangent, so there is no kink to slow for
static func _turnout(zone: String, s: float) -> Array:
	var a := _angle(zone)
	var m := PortStructure.M()
	var rim: Vector2 = _leg(zone)[2]
	var end := _loop_pt(a + s * TURNOUT)
	var inward := -Vector2.from_angle(a)
	var tangent := Vector2.from_angle(a + s * TURNOUT + s * PI * 0.5)
	var reach := rim.distance_to(end) * 0.45
	var c1 := rim + inward * reach
	var c2 := end - tangent * reach
	var out: Array = []
	for k in 13:
		var q := float(k) / 12.0
		var u := 1.0 - q
		out.append(rim * u * u * u + c1 * 3.0 * u * u * q + c2 * 3.0 * u * q * q + end * q * q * q)
	return out


static func route(from: String, to: String) -> Array:
	var a0 := _angle(from)
	var a1 := _angle(to)
	var d := wrapf(a1 - a0, -PI, PI)
	var s := signf(d) if absf(d) > 0.001 else 1.0
	var out: Array = []
	var start_a := a0
	if from == "ring":
		out.append(station_at("ring"))
	else:
		out.append_array(_leg(from))
		out.append_array(_turnout(from, s).slice(1))
		start_a = a0 + s * TURNOUT
	var end_a := a1 - s * TURNOUT if to != "ring" else a1
	var span := wrapf(end_a - start_a, -PI, PI)
	if signf(span) != s and absf(span) > 0.001:
		span += s * TAU
	var n := maxi(1, int(absf(span) / 0.08))
	for k in range(1, n + 1):
		out.append(_loop_pt(start_a + span * float(k) / n))
	if to != "ring":
		var back := _turnout(to, -s)
		back.reverse()
		out.append_array(back.slice(1))
		var leg := _leg(to)
		leg.reverse()
		out.append_array(leg.slice(1))
	return out


# the drone at station `here` wants to go to `to`: the car comes here first if needed
# the drone at station `here` wants `to`: if the car is already here it opens its doors
# at once; otherwise it comes to this station first, then goes on
func call_to(here: String, to: String) -> bool:
	if not active() or phase != "" or to == here or to not in stations():
		return false
	dest = to
	_wait_here = here
	speed = 0.0
	if at == here or position_px.distance_to(station_at(here)) < 1.0 * Geom.M:
		position_px = station_at(here)
		_set_path(route(here, to))
		_begin_board()
	else:
		_set_path(route(at, here))
		phase = "fetch"
	at = ""
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
	# the rails the new lead already stands past
	while not path.is_empty() and ((path[0] as Vector2) - position_px).dot(-fwd) <= 0.0:
		path.pop_front()
		if not limits.is_empty():
			limits.pop_front()
	_pp = position_px
	_ph = heading
	_cr = _rear_now()
	_pr = _cr


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
	var d = game.drone
	d.global_position = position_px + Vector2(0, -2.4 * Geom.M)
	d.linear_velocity = Vector2.ZERO
	d.collision_layer = 2
	d.collision_mask = 1 | 4 | World.STATIC_LAYER
	d.visible = true


# follow the rails (35 号): speed up at 6 m/s² to 20 m/s, slow before each curve to what
# 4 m/s² sideways allows on its radius, brake into the stop
func _advance(dt: float) -> bool:
	if path.is_empty():
		return true
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


var accel_now := 0.0
const BOGIE := 1.0             # m from a car's centre to each bogie
# the pose at the last two physics steps (120 Hz): drawn in between them every frame, as the
# camera is (it follows the interpolated drone; user 2026-10-27, the train went in jerks)
var _pp := Vector2.ZERO
var _ph := 0.0
var _pr := Vector2.ZERO
var _cr := Vector2.ZERO


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


func _physics_process(dt: float) -> void:
	t += dt
	if not active():
		return
	var t0 := Time.get_ticks_usec()
	_pp = position_px
	_ph = heading
	_pr = _cr
	var d = game.drone
	match phase:
		"fetch":
			if _advance(dt):
				# at the caller's station: doors open
				position_px = station_at(_wait_here)
				_set_path(route(_wait_here, dest))
				speed = 0.0
				_begin_board()
		"board":
			dwell += dt
			var k := clampf(dwell / 0.45, 0.0, 1.0)
			k = k * k * (3.0 - 2.0 * k)
			if d != null:
				d.global_position = slide_from.lerp(position_px, k)
				d.linear_velocity = Vector2.ZERO
				d.visible = k < 0.999
			if dwell >= DWELL:
				_wait_here = ""
				phase = "ride"
				speed = 0.0
		"ride":
			if d != null:
				d.global_position = position_px
				d.linear_velocity = Vector2.ZERO
				d.visible = false
			if _advance(dt):
				at = dest
				dest = ""
				phase = "alight"
				dwell = 0.0
				slide_from = position_px
		"alight":
			dwell += dt
			var k := clampf(dwell / 0.45, 0.0, 1.0)
			k = k * k * (3.0 - 2.0 * k)
			if d != null:
				d.visible = true
				d.global_position = slide_from.lerp(position_px + Vector2(0, -2.4 * Geom.M), k)
				d.linear_velocity = Vector2.ZERO
			if dwell >= 0.5:
				_finish_alight()
	_cr = _rear_now()
	step_us = lerpf(step_us, float(Time.get_ticks_usec() - t0), 0.05)


func _process(_dt: float) -> void:
	visible = active()
	if visible:
		queue_redraw()
	if visible and game.cam != null and absf(game.cam_zoom() - _rails_z) > 0.0005:
		_rails_z = game.cam_zoom()
		rails.queue_redraw()


func _draw_rails() -> void:
	if not active():
		return
	rails_draws += 1
	var M := Geom.M
	var z: float = maxf(game.cam_zoom(), 0.02)
	var lw := 1.0 / z
	# one mesh for the lot: thousands of separate line commands cost ~2 ms a frame to replay
	var cb = CanvasBatch.new(rails)
	# 35 号: the rails — two running rails on ties, the cyan conductor rail between them,
	# a lamp every 12 m, arcs at every corner
	var lines: Array = []
	var loop: Array = []
	for k in 91:
		loop.append(_loop_pt(TAU * k / 90.0))
	lines.append(loop)
	for zone in stations():
		if zone == "ring":
			continue
		lines.append(smooth(_leg(zone))[0])
		lines.append(_turnout(zone, 1.0))
		lines.append(_turnout(zone, -1.0))
	for pts in lines:
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var seg := a.distance_to(b)
			if seg < 0.01:
				continue
			var dir := (b - a) / seg
			var side := dir.orthogonal() * 0.55 * M
			cb.draw_line(a + side, b + side, Pal.ink(0.34), 1.6 * lw)
			cb.draw_line(a - side, b - side, Pal.ink(0.34), 1.6 * lw)
			cb.draw_line(a, b, Pal.tint(Pal.FLUID, 0.28, 1.2), lw)
			var n := int(seg / (1.6 * M))
			for k in n:
				var q := a + dir * (k + 0.5) * 1.6 * M
				cb.draw_line(q + side * 1.35, q - side * 1.35, Pal.ink(0.13), lw)
		var run := 0.0
		for i in pts.size() - 1:
			var a2: Vector2 = pts[i]
			var b2: Vector2 = pts[i + 1]
			run += a2.distance_to(b2)
			if run > 12.0 * M:
				run = 0.0
				var o := (b2 - a2).normalized().orthogonal() * 1.1 * M
				cb.draw_circle(b2 + o, 0.14 * M, Pal.tint(Pal.AIR, 0.7, 1.4))
	cb.flush()


func _draw() -> void:
	if not active():
		return
	var t0 := Time.get_ticks_usec()
	var M := Geom.M
	var z: float = maxf(game.cam_zoom(), 0.02)
	var lw := 1.0 / z
	var font := Fonts.get_font("Medium")
	# stations: a platform with a hazard edge, a sign
	var near := near_station()
	for s in stations():
		var p := station_at(s)
		var on: bool = s == near
		var col := Pal.tint(Pal.FLUID, 0.95 if on else 0.5, 1.2)
		var plat := Rect2(p - Vector2(2.2, 0.35) * M, Vector2(4.4, 0.7) * M)
		draw_rect(plat, Color(0.04, 0.045, 0.05))
		draw_rect(plat, col, false, 1.4 * lw)
		var hx := plat.position.x
		while hx < plat.end.x - 0.3 * M:
			draw_line(Vector2(hx, plat.end.y), Vector2(hx + 0.3 * M, plat.position.y + 0.35 * M), Pal.heat(0.4, 1.0), lw)
			hx += 0.7 * M
		draw_line(p + Vector2(1.9, -0.35) * M, p + Vector2(1.9, -1.6) * M, Pal.ink(0.5), 1.4 * lw)
		draw_rect(Rect2(p + Vector2(1.35, -2.1) * M, Vector2(1.1, 0.55) * M), col)
		if z >= 0.15 or on:
			draw_set_transform(p, 0, Vector2.ONE / z)
			draw_string(font, Vector2(-30, 26), Txt.t("tram_station"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
			if on and not riding:
				draw_string(font, Vector2(-70, -24), Txt.t("tram_call") % Keys.label("use"), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.ink(0.95))
			draw_set_transform(Vector2.ZERO)
	# the train: two cars on a coupling; the second follows the first's path
	var v := speed / SPEED
	# between the last two physics steps
	var f := Engine.get_physics_interpolation_fraction()
	var at_px := _pp.lerp(position_px, f) if _pp != Vector2.ZERO else position_px
	var h := lerp_angle(_ph, heading, f)
	var rear := _pr.lerp(_cr, f) if _pr != Vector2.ZERO else _rear_now()
	var rear_h := (at_px - rear).angle() if at_px.distance_to(rear) > 1.0 else h
	# speed: faint streaks behind, the headlight's cone ahead
	if v > 0.25:
		var back := Vector2.from_angle(rear_h + PI)
		for k in 4:
			var off := back.orthogonal() * (k - 1.5) * 0.35 * M
			draw_line(rear + off + back * 1.6 * M, rear + off + back * (1.6 + 5.0 * v) * M, Pal.tint(Pal.FLUID, 0.12 * v, 1.2), lw)
	var fwd := Vector2.from_angle(h)
	var nose := at_px + fwd * 1.8 * M
	draw_colored_polygon(PackedVector2Array([nose, nose + fwd * 9.0 * M + fwd.orthogonal() * 2.2 * M, nose + fwd * 9.0 * M - fwd.orthogonal() * 2.2 * M]), Color(0.75, 0.9, 1.0, 0.07 + 0.05 * v))
	for car in [[rear, rear_h, false], [at_px, h, true]]:
		_car(car[0], car[1], car[2], M, lw)
	# the shoe on the conductor rail sparks as it pulls hard
	if accel_now > 3.0 * M and fmod(t, 0.18) < 0.06:
		var sp := at_px - fwd * 0.6 * M
		for k in 3:
			var dv := Vector2.from_angle(h + PI + randf_range(-0.7, 0.7)) * randf_range(0.3, 0.9) * M
			draw_line(sp, sp + dv, Pal.heat(1.0, 1.8), lw)
	draw_string(font, at_px + Vector2(-1.2 * M, -1.3 * M), "T-1", HORIZONTAL_ALIGNMENT_LEFT, -1, int(10.0 / z), Pal.ink(0.5))
	draw_us = lerpf(draw_us, float(Time.get_ticks_usec() - t0), 0.05)


func _car(at: Vector2, h: float, front: bool, M: float, lw: float) -> void:
	draw_set_transform(at, h, Vector2.ONE)
	var L := 3.2 * M
	var W := 1.6 * M
	var nose := 0.5 * M if front else 0.0
	var body := PackedVector2Array([Vector2(-L * 0.5, -W * 0.5), Vector2(L * 0.5 - nose, -W * 0.5), Vector2(L * 0.5, -W * 0.25), Vector2(L * 0.5, W * 0.25), Vector2(L * 0.5 - nose, W * 0.5), Vector2(-L * 0.5, W * 0.5)])
	draw_colored_polygon(body, Color(0.055, 0.06, 0.068))
	body.append(body[0])
	draw_polyline(body, Pal.ink(0.8), 1.4 * lw)
	# windows down the side, a roof stripe
	for k in 4:
		draw_rect(Rect2(Vector2(-L * 0.42 + k * L * 0.2, -W * 0.32), Vector2(L * 0.14, W * 0.26)), Pal.tint(Pal.FLUID, 0.35 if riding else 0.18, 1.2))
	draw_line(Vector2(-L * 0.45, W * 0.18), Vector2(L * 0.4, W * 0.18), Pal.heat(0.4, 1.0), lw)
	if phase in ["board", "alight"] and front:
		var k2 := clampf(dwell / 0.3, 0.0, 1.0)
		draw_rect(Rect2(Vector2(-0.3 * M + k2 * 0.5 * M, -W * 0.5 - 0.06 * M), Vector2(0.6 * M, 0.12 * M)), Pal.ink(0.9))
		draw_circle(Vector2(0, -W * 0.5 - 0.5 * M), 0.2 * M, Pal.tint(Pal.FLUID, 0.9 if fmod(t, 0.5) < 0.25 else 0.3, 1.4))
	if front:
		draw_circle(Vector2(L * 0.5, -W * 0.2), 0.12 * M, Pal.ink(0.95, 1.6))
		draw_circle(Vector2(L * 0.5, W * 0.2), 0.12 * M, Pal.ink(0.95, 1.6))
	else:
		draw_circle(Vector2(-L * 0.5, 0), 0.14 * M, Pal.heat(0.9, 1.6))
	# the coupling
	if not front:
		draw_line(Vector2(L * 0.5, 0), Vector2(L * 0.5 + 0.4 * M, 0), Pal.ink(0.6), 2.0 * lw)
	draw_set_transform(Vector2.ZERO)
