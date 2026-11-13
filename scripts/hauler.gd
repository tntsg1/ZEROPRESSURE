class_name Hauler
extends Node2D
# The basic hauling drone (berth upgrade, design/体验打磨定案.md §6): mark a
# floating piece (the "mark" key with the pointer on it) and it fetches it —
# up to 1.5 t, whatever it is — and lets it go at the mouth it belongs in:
# hazards to the hazard bay, whole equipment to the equipment bay, the rest
# to the furnace. One load at a time, round the ship, slower than you; what
# it delivers is the machine's work, not yours. The 200,000 second drone is
# the advanced version of this.
# With nothing marked it fetches loose plain scrap by itself (whatever the arm
# is not taking). Like the arm it waits its turn over a mouth, holds back for
# the operator's drone, and the automation key stops it (what it holds is let
# go there). A second hauler (roadmap 4.4) is another of these: it works the
# same list of marks and never goes for what the first already has. Neither
# goes into a keep-out zone the operator has set (game.keepout).

const MAX_T := 1.5
# 2026-11-12 (user: "增加到最多 5 个无人机" — then "干脆把最高的能够加的无人机数量变成7"): up to seven;
# (first ask: "增加到最多 5 个无人机，每个无人机都长得完全不一样。都可以做成升级"): up to five,
# each its own upgrade (each needs the one before) and its own airframe (scripts/hauler_art.gd)
const IDS := ["hauler", "hauler2", "hauler3", "hauler4", "hauler5", "hauler6", "hauler7"]
# where each waits by the boom (m, from Dock.BAY): two rows over the berth
const HOMES := [Vector2(0.6, -1.6), Vector2(2.2, -1.6), Vector2(3.8, -1.6), Vector2(1.4, -3.0), Vector2(3.0, -3.0), Vector2(5.4, -1.6), Vector2(4.6, -3.0)]
const HArt = preload("res://scripts/hauler_art.gd")
# airframes: the first two as they were (drone_art.gd), the third to the seventh hauler_art.gd's five
const OLD_ART := ["coreclaw", "tripod"]
# It flies like the operator's drone (player 2026-10-18: "the same rhythm,
# the same inertia"): its top speed and acceleration, slowing for what it
# carries, braking into where it is going; it keeps off the ship's walls on the
# berth's navigation grid (scripts/nav.gd) and eases round loose pieces, the
# other hauler and the operator.
const VMAX := 430.0 * 0.92   # the hauler keeps its own pace (the drone was sped up 2026-11-05)
#   # px/s empty
const ACCEL := Drone.ACCEL * 2.0  # px/s² empty (the operator's assisted drone: ~2.3x)
const LOAD_V := 0.62              # top speed with a full 1.5 t load, as a share
const ARRIVE := 10.0              # px: there
const REPLAN := 1.2               # s between fresh paths
const AVOID_R := 1.6 * 48.0       # px: loose pieces and drones nearer than this are eased round
const R := 12.0
const CLEAR := 2.5 * 48.0        # px it keeps from the operator's drone
const PUSH_SPEED := 48.0         # px/s sideways: clear a lane without flinging scrap
const PUSH_ACCEL := 150.0        # px/s², capped thruster force for heavy obstructions
const PUSH_MASS := 1.5           # t: the force budget stops scaling above this mass

var game: Game
var who := "hauler"              # its name over a mouth and on a claim (IDS)
var idx := 0                     # which of the seven (its airframe: OLD_ART, then hauler_art.gd)
var home_off := Vector2(0.6, -1.6)
var queue: Array = []            # marked bodies, in order (shared by both haulers)
var body = null
var path: Array = []
var pos := Vector2.ZERO
var state := "idle"              # idle reach carry release
var zone := "metal"
var off := Vector2.ZERO
var hold_t := 0.0
var t := 0.0
var carried := 0
var auto_pickup := false         # unasked scrap may yield before gripping
var wait_t := 0.0               # s spent holding back for the drone
# its airframe (2026-10-17): every drone in the berth looks different; drawn
# smaller and in air-blue, turned the way it travels
const Art = preload("res://scripts/drone_art.gd")
const LoadMotion = preload("res://scripts/load_motion.gd")
const Crew = preload("res://scripts/crew.gd")
var wait_reason := ""
var heading := -PI / 2.0
var vel := Vector2.ZERO
var route := PackedVector2Array()
var _goal := Vector2.INF
var _replan_t := 0.0
var _clear := 0.0
var _avoid_skip: Array = []      # bodies it does not ease round (what it goes for, what it carries)
var _last_pos := Vector2.ZERO
var _move := Vector2.ZERO
var _rescue_id := 0
var _rescue_state := ""
var _rescue_best := INF
var _rescue_t := 0.0
# what its jets are doing: its real acceleration (player 2026-10-18: speeding
# up blows backwards, slowing down is a reverse burn — strictly)
var _acc := Vector2.ZERO
var _vel0 := Vector2.ZERO
var _grip := 0.0                 # the grip drawn shutting / opening (0..1)
var _reach := 0.0                # and reaching out
var _scan_t := 0.0               # s to the next look round the berth for unasked scrap (idle)
var _seen_n := -1                # bodies in the berth at the last look
const SCAN := 0.3                # s between those looks (2026-11-12: five of them, every frame, was waste)


func _init() -> void:
	z_index = 6
	z_as_relative = false


# the idx-th hauler of the berth, working the shared list of marks
func setup(i: int, shared_queue: Array) -> void:
	idx = i
	who = IDS[i]
	home_off = HOMES[i]
	queue = shared_queue
	# the idle look-round for unasked scrap is spread over the frames, one hauler at a time
	_scan_t = 0.06 * i


func home() -> Vector2:
	return (Dock.BAY + home_off) * Geom.M


func can_take(b) -> bool:
	if not is_instance_valid(b) or b.capture != null or b.pieces.is_empty() or b.total_mass() > MAX_T or game.tools.held_body == b:
		return false
	# the works crew's parts and wreck: theirs (2026-11-12, scripts/crew.gd owns)
	if Crew.owns(b):
		return false
	# another machine (the other hauler, the arm, the crane) is already after it
	return not b.get_meta("arm", false) or b.get_meta("arm_by", "") == who


# set off for it: from now on the other machines leave it alone
func _claim(b) -> void:
	b.set_meta("arm", true)
	b.set_meta("arm_by", who)


func _unclaim(b) -> void:
	if b != null and is_instance_valid(b) and b.get_meta("arm_by", "") == who:
		b.set_meta("arm", false)
		b.remove_meta("arm_by")


# what it fetches unasked: a loose body of plain scrap (no whole equipment, no
# hazard) that nobody holds and no other machine is after. Anything of value,
# or anything it cannot be sure of, waits for the operator (or a mark).
func auto_takes(b) -> bool:
	if game.manual_only():
		return false
	if is_instance_valid(b) and b.get_meta("arm_parked",false): return false
	if game.plan != null and game.plan.reserves_body(b): return false
	if not can_take(b) or b.get_meta("arm", false) or b == body:
		return false
	if t < float(b.get_meta("no_way_till", -1.0)):
		return false
	if t - float(b.get_meta("arm_drop", -99.0)) < 5.0:
		return false
	# 2026-11-10 ("明明能捡的，还在那傻站了"): it used to leave anything the arm *could* take to the
	# arm, which carries one at a time and slowly: with the arm fitted the haulers stood by a heap of
	# scrap. Now only the one the arm is about to reach for is left to it (what it is after is claimed).
	if game.arm != null and (game.arm.body == b or game.arm.next_pick() == b):
		return false
	if _other_has(b) or game.dock.in_buffer(b):
		return false
	# 2026-11-11 (user, MY-48: "我明明都用螺丝盘螺下来了，无人机还是不来弄…不管鼠标有没有点无人机，都把所有这些
	# 飘在空中的全部放到回收站里面去"): with the machines on, every loose body goes to its own mouth
	# unasked — whole equipment to the equipment mouth, hazards to the hazard mouth, scrap to the
	# furnace; a mark only puts it first. (A training course or an exam keeps the old rule: scrap only.)
	if game.training or game.exam != null:
		return game.dock.is_scrap(b)
	return Dock.for_load(_zone_for(b), b) != ""


# the other hauler is already after it
func _other_has(b) -> bool:
	for h in game.haulers():
		if h != self and h.body == b:
			return true
	return false


# the mark key: on a floating piece it goes on the list (or comes off it)
func toggle(b) -> String:
	if b == null or not is_instance_valid(b):
		return ""
	if queue.has(b):
		queue.erase(b)
		return "hauler_unmarked"
	if b.total_mass() > MAX_T:
		return "hauler_heavy"
	# 78 号 P0-1: whole equipment no equipment mouth can take, however it is turned
	if _zone_for(b) == "equip" and Dock.for_load("equip", b) == "":
		return "hauler_no_mouth"
	b.remove_meta("no_way_till")
	queue.append(b)
	return "hauler_marked"


# 2026-11-10 ("明明能捡的，还在那傻站了" — and when it truly cannot, say so on site): why no hauling
# drone will ever take this loose body, as the mark key's own words ("" when one can). Only what no
# waiting mends: too heavy, or no mouth takes it whole.
func refuse_reason(b) -> String:
	if not is_instance_valid(b) or b.capture != null or b.pieces.is_empty():
		return ""
	if b.total_mass() > MAX_T:
		# the crane comes for it by itself (Crane.auto_pick): nothing to say
		if game.crane != null and b.total_mass() <= Methods.crane_t() and not game.manual_only() and not b.get_meta("crane_skip", false) and game.crane._zone_for(b) != "":
			return ""
		return "crane_heavy" if game.crane != null and b.total_mass() > Methods.crane_t() else "hauler_heavy"
	if Dock.for_load(_zone_for(b), b) == "":
		return "hauler_no_mouth"
	return ""


# the words for refuse_reason, by the pointer: how heavy it is and what would take it
func refuse_text(b) -> String:
	var why := refuse_reason(b)
	if why == "hauler_heavy":
		return game.txt("hauler_heavy_n") % ("%.1f" % b.total_mass())
	return game.txt(why) if why != "" else ""


# the loose bodies the haulers will not take, drawn with a small "no" sign (no words on the work)
func _draw_refused() -> void:
	if game == null or game.world == null or game.cam == null:
		return
	var z: float = maxf(0.05, game.cam_zoom())
	var view := get_viewport_rect().size / z
	var vr := Rect2(game.cam.position - view * 0.5, view)
	var col := Pal.heat(0.75, 1.1)
	for b in game.world.bodies:
		if not is_instance_valid(b) or b.freeze or b.capture != null or b.linear_velocity.length() > 40.0:
			continue
		if b == game.tools.held_body or b.get_meta("arm", false):
			continue
		var c: Vector2 = b.global_transform * b.center_of_mass
		if not vr.has_point(c):
			continue
		var why := refuse_reason(b)
		if why == "":
			continue
		var r := 7.0 / z
		var at := c + Vector2(0, -12.0 / z)
		draw_arc(at, r, 0.0, TAU, 20, col, 1.4 / z, true)
		draw_line(at + Vector2(-r, r).rotated(0.0) * 0.7, at + Vector2(r, -r) * 0.7, col, 1.4 / z, true)
		# what sort of no: a weight under it (too heavy) or a mouth too narrow
		if why in ["hauler_heavy", "crane_heavy"]:
			draw_colored_polygon(PackedVector2Array([at + Vector2(-4, 11) / z, at + Vector2(4, 11) / z, at + Vector2(5.5, 16) / z, at + Vector2(-5.5, 16) / z]), col)
		else:
			draw_polyline(PackedVector2Array([at + Vector2(-6, 10) / z, at + Vector2(-6, 15) / z, at + Vector2(6, 15) / z, at + Vector2(6, 10) / z]), col, 1.4 / z, true)


func _zone_for(b) -> String:
	var planned: String = str(b.get_meta("plan_zone", ""))
	if planned in ["metal", "equip", "hazard"]:
		return planned
	# 认真拆有奖励: harmless leftovers go to the equipment mouth's drain rack, not the hazard mouth
	if game.clean != null and game.clean.active() and game.clean.body_residual(b) != "":
		return "equip"
	for p in b.pieces:
		if game.sys.dest_of(p) == "hazard":
			return "hazard"
	if game.dock.is_scrap(b):
		return "metal"
	return "equip"


func _drop_point(z: String) -> Vector2:
	# face points out into the berth. A target behind the metal lip lies below
	# the solid floor, so full-payload navigation correctly found no route.
	# Approach from the working side, within the receiver's physical catch.
	return Dock.zpos(z) + Dock.ZONES[z].face * 0.4 * Geom.M


# what the haulers cost a frame, all of them together (µs, read by tests/haulers5_perf.gd)
static var prof_us := 0


func _physics_process(dt: float) -> void:
	var t0 := Time.get_ticks_usec()
	_step(dt)
	prof_us += Time.get_ticks_usec() - t0


func _step(dt: float) -> void:
	if game == null or game.paused_sim or game.state != "play":
		return
	t += dt
	_acc = _acc.lerp((vel - _vel0) / maxf(dt, 0.001), 1.0 - exp(-14.0 * dt))
	_vel0 = vel
	if pos == Vector2.ZERO:
		pos = home()
	game.nav_grid().step(dt)
	for b in queue.duplicate():
		if not is_instance_valid(b) or b.capture != null:
			queue.erase(b)
	# A deliberate operator/package command takes precedence over an unasked
	# pickup. Only yield before gripping; an actual carried load finishes first.
	# 2026-11-11 (user: "我右边刚拆下来一个零件，这无人机无动于衷"): marking the very piece it was already
	# after made it drop that piece and put it off for 6 s — both haulers stood by. Now a mark on what
	# it is after just makes it a marked job; it yields only for a marked piece it can take now, and
	# puts nothing off (the other hauler may take what it leaves).
	if state == "reach" and auto_pickup:
		if queue.has(body):
			queue.erase(body)
			auto_pickup = false
		elif _queued_takeable() != null:
			_done()
	if game.auto_paused:
		if body != null:
			halt()
		_fly(home(), dt)
		return
	# the operator took hold of what it carries: theirs now
	if body != null and is_instance_valid(body) and game.tools.held_body == body:
		halt()
		return
	# A projected grid endpoint can appear reachable while the actual pickup
	# or loaded motion remains blocked. Explicit operator work must not sit
	# there forever: hand the same physical load to the clipping rail arm.
	if state in ["reach","carry"] and is_instance_valid(body) and body.capture == null and body.get_meta("manual_mark",false) and not body.get_meta("plan_dispatch",false):
		var distance: float = pos.distance_to(body.global_transform*body.center_of_mass if state == "reach" else _drop_point(zone))
		if _rescue_id != body.get_instance_id() or _rescue_state != state or distance < _rescue_best-4.0:
			_rescue_id = body.get_instance_id()
			_rescue_state = state
			_rescue_best = distance
			_rescue_t = 0.0
		else:
			_rescue_t += dt
		if _rescue_t >= 4.0 and game.arm_extract(body,_zone_for(body),false):
			_rescue_t = 0.0
			return
	else:
		_rescue_id = 0
		_rescue_t = 0.0
	if state in ["carry","release"] and is_instance_valid(body) and body.capture == null:
		# Physics recovery may move a contacted load after our previous callback.
		# The gripper follows that real pose; its virtual position must never run
		# ahead and announce arrival while the cargo remains inside the ship.
		pos = body.global_position-off
	var hold := false
	if state in ["reach", "carry"] and game.keepout_blocks(pos, _heading()):
		hold = true
	if state in ["reach", "carry"] and game.drone_near(pos, CLEAR, _heading()):
		wait_t += dt
		if wait_t < 1.0:
			hold = true
	else:
		wait_t = 0.0
	# and out of the arm's way while that carries (unless it already has the mouth: then the arm waits)
	if state == "carry" and game.mouths.get(zone, "") != who and game.arm != null and game.arm.state == "carry" and game.arm.claw.distance_to(pos) < 2.0 * Geom.M:
		hold = true
	if hold:
		_brake(dt)
		return
	match state:
		"idle":
			for b in queue.duplicate():
				if can_take(b) and _reachable(b):
					_set_off(b)
					queue.erase(b)
					break
			# nothing marked it can take now: loose scrap that is plainly scrap, the arm's or not
			# (2026-11-11: a marked piece it cannot take yet — the other hauler's, put off — no longer
			# keeps both haulers off every other piece in the berth)
			_scan_t -= dt
			# a fresh piece in the berth (a cut, a drop) is looked at at once — one hauler a frame or
			# three apart, so five never all scan and plan their ways in the same frame
			if game.world.bodies.size() != _seen_n:
				_seen_n = game.world.bodies.size()
				_scan_t = minf(_scan_t, 0.05 * idx)
			if state == "idle" and _scan_t <= 0.0:
				_scan_t = SCAN
				for b in game.world.bodies:
					if auto_takes(b) and _reachable(b) and _delivery_reachable(b):
						_set_off(b,true)
						break
			if state == "idle":
				_fly(home(), dt)
		"reach":
			if not can_take(body):
				_done()
				return
			if Dock.for_load(_zone_for(body), body) == "":
				# 78 号 P0-1: no mouth takes it whole — leave it for the operator to cut
				queue.erase(body)
				wait_reason = ""
				_done()
				return
			var target: Vector2 = body.global_transform * body.center_of_mass
			var bv: Vector2 = body.linear_velocity
			# a drifting load is caught by matching its speed first (strict inertia:
			# no knock as it grips), then the two move as one
			var met := _fly(target, dt, 6.0, bv) or pos.distance_to(target) < 6.0
			if met and (vel - bv).length() < 8.0:
				if not LoadMotion.grip(body):
					wait_reason = "load_pickup_blocked"
					return
				wait_reason = ""
				off = body.global_position - pos
				zone = Dock.for_load(_zone_for(body), body)
				route = PackedVector2Array()
				state = "carry"
				game.sfx.play("grab", pos, 0.5)
		"carry":
			if not is_instance_valid(body) or body.capture != null:
				# the mouth took it out of the claw on the way down: delivered all the same
				carried += 1
				_done()
				return
			LoadMotion.line_up(body, zone, 0.9, dt)
			var drop := _drop_point(zone)
			if Dock.kind(zone) == "equip": drop = LoadMotion.intake_point(body, zone, pos)
			# the last stretch waits its turn at the mouth
			if pos.distance_to(drop) < 3.0 * Geom.M and not game.mouth_take(zone, who):
				_brake(dt)
			elif _fly(drop, dt):
				state = "release"
				hold_t = 0.0
		"release":
			hold_t += dt
			_brake(dt)
			if not is_instance_valid(body) or body.capture != null:
				carried += 1
				_done()
			elif hold_t > 0.25:
				LoadMotion.let_go(body)
				body.linear_velocity = Dock.ZONES[zone].face * -60.0 + vel
				body.set_meta("arm", false)
				body.remove_meta("arm_by")
				body.set_meta("arm_drop", t)
				carried += 1
				game.on_arm_drop(body)
				_done()


# the first marked piece this hauler can set off for now (null when none)
func _queued_takeable():
	for b in queue:
		if is_instance_valid(b) and b.capture == null and can_take(b) and _reachable(b) and not _other_has(b):
			return b
	return null


# off after b: claimed for this hauler, a fresh way planned
func _set_off(b, automatic: bool = false) -> void:
	body = b
	auto_pickup = automatic
	_claim(b)
	state = "reach"
	route = PackedVector2Array()


# can it get there at all (a piece shut in a room nobody has opened is not for it);
# one it can't reach is left alone for a while
func _reachable(b) -> bool:
	# user 2026-11-08: the hauler passes through structure (no way in is no reason to leave it)
	return t >= float(b.get_meta("no_way_till", -1.0))


# Unasked scrap must not monopolize the machine while a deliberately marked
# job waits. A native join sweep rejects grid projections through a closed
# shell. Marked jobs keep their explicit wait-and-clear behavior.
func _delivery_reachable(b) -> bool:
	# (2026-11-10: a body still easing out of the ship is taken as it is: gripped, it collides with
	# nothing anyway (FreeBody.hold_begin); waiting 2 s for it to come clear only left the hauler idle)
	var center: Vector2 = b.global_transform*b.center_of_mass
	var to_zone := Dock.for_load(_zone_for(b),b)
	if to_zone == "":
		b.set_meta("no_way_till",t+6.0)
		return false
	# user 2026-11-08: carried, it passes through structure: any mouth that takes it is reachable
	return true


# how much it carries now (0 empty, 1 a full 1.5 t load)
func _load() -> float:
	if state in ["carry", "release"] and is_instance_valid(body):
		return clampf(body.total_mass() / MAX_T, 0.0, 1.0)
	return 0.0


# fly toward `to` along the navigation grid like the operator's drone: speed
# up, keep to the path, brake in to arrive. true once there and slow.
# tv: the velocity to arrive with (a drifting load is met at its own speed)
func _fly(to: Vector2, dt: float, arrive: float = ARRIVE, tv: Vector2 = Vector2.ZERO) -> bool:
	var Nav = preload("res://scripts/nav.gd")
	var ld := _load()
	var loaded: bool = state in ["carry", "release"] and is_instance_valid(body) and body.capture == null
	var clear: float = Nav.LOAD_CLEAR if ld > 0.0 else Nav.EMPTY_CLEAR
	_replan_t -= dt
	if loaded:
		# user 2026-11-08: loaded, it goes straight for the mouth through whatever is in the way
		route = PackedVector2Array([to])
		_goal = to
		_clear = clear
	elif route.is_empty() or _replan_t <= 0.0 or _goal.distance_to(to) > 24.0 or clear != _clear:
		# empty it keeps to the grid where there is a way, and flies straight where there is none
		route = game.nav_grid().path(pos, to, clear)
		if route.is_empty():
			route = PackedVector2Array([to])
		_goal = to
		_clear = clear
		_replan_t = REPLAN
	if route.is_empty():
		_brake(dt)
		return false
	# the next point, skipping ahead when the one after is in clear sight
	while route.size() > 1 and (pos.distance_to(route[0]) < 28.0 or game.nav_grid().sight(pos, route[1], clear * 0.8)):
		route.remove_at(0)
	var nxt: Vector2 = route[0]
	var left := pos.distance_to(nxt)
	for i in range(1, route.size()):
		left += route[i - 1].distance_to(route[i])
	var vmax := VMAX * lerpf(1.0, LOAD_V, ld)
	var acc := ACCEL / (1.0 + 1.4 * ld)
	# brake in: the speed it can still stop from over what is left
	var speed := minf(vmax, sqrt(2.0 * acc * 0.75 * maxf(0.0, left - arrive * 0.5)))
	var dir := (nxt - pos).normalized() if left > 0.5 else Vector2.ZERO
	var avoidance := _avoid(dir, left, clear)
	if loaded:
		# Retain a bounded way around loose bodies when they cannot be pushed
		# straight out. Never cancel forward rendezvous thrust; every resulting
		# displacement still sweeps the actual compound load below.
		var side := Vector2(-dir.y,dir.x)
		avoidance = side*avoidance.dot(side)
	var want := dir * speed + tv + avoidance * vmax * (0.35 if loaded else 0.5)
	if left < arrive and (vel - tv).length() < 50.0:
		vel = vel.move_toward(tv, acc * dt)
		return _advance(vel * dt)
	vel += (want - vel).limit_length(acc * dt)
	_advance(vel * dt)
	return false


func _brake(dt: float) -> void:
	vel = vel.move_toward(Vector2.ZERO, ACCEL / (1.0 + 1.4 * _load()) * dt)
	_advance(vel * dt)


func _advance(delta: Vector2) -> bool:
	if state in ["carry", "release"] and is_instance_valid(body) and body.capture == null:
		LoadMotion.move(body, delta)
	pos += delta
	if delta.length_squared() > 0.00001: wait_reason = ""
	return true


# a push away from what is near: loose pieces (not its own), the other hauler, the operator
func _avoid(dir: Vector2 = Vector2.ZERO, remaining: float = INF, clearance: float = R) -> Vector2:
	var push := Vector2.ZERO
	var half := Vector2(R,R)
	if state == "carry" and is_instance_valid(body): half = LoadMotion.half_extents(body)
	var radius := AVOID_R+maxf(0.0,half.length()-R*sqrt(2.0))
	var side := Vector2(-dir.y,dir.x)
	var lane := maxf(clearance,absf(side.x)*half.x+absf(side.y)*half.y)
	var rear := maxf(R,absf(dir.x)*half.x+absf(dir.y)*half.y)
	for b in game.world.bodies:
		if not is_instance_valid(b) or b == body or b.capture != null:
			continue
		var c: Vector2 = b.global_transform * b.center_of_mass
		# Work from the footprint, not just its centre: the corner of a long
		# plate can obstruct the approach even with its centre far away.
		var near := _obstacle_point(b,radius)
		if not near.is_finite(): continue
		var d := pos - near
		var distance := d.length()
		if distance >= radius: continue
		var away := d.normalized() * (1.0 - distance / radius) if distance > 0.1 else (pos - c).normalized()
		if dir != Vector2.ZERO and state in ["reach", "carry"] and _can_clear(b, c) and _clear_obstacle(b, c, near, dir, lane, rear):
			# Movable scrap must not cancel the final rendezvous thrust. Keep a
			# lateral separation cue, fading it as the gripper meets its target.
			away -= dir * minf(0.0, away.dot(dir))
			away *= clampf(remaining / AVOID_R, 0.0, 1.0)
		push += away
	for h in game.haulers():
		if h != self:
			var d2: Vector2 = pos - h.pos
			if d2.length() < AVOID_R and d2.length() > 0.1:
				push += d2.normalized() * 1.5 * (1.0 - d2.length() / AVOID_R)
	if game.drone != null and game.drone.alive:
		var d3: Vector2 = pos - game.drone.global_position
		if d3.length() < AVOID_R and d3.length() > 0.1:
			push += d3.normalized() * 1.2 * (1.0 - d3.length() / AVOID_R)
	return push.limit_length(1.0)


func _obstacle_point(b, radius: float = AVOID_R) -> Vector2:
	var local: Vector2 = b.global_transform.affine_inverse() * pos
	var box: Rect2 = b.clearance_bounds
	if local.distance_to(local.clamp(box.position,box.end)) >= radius: return Vector2.INF
	var point := Vector2.INF
	var closest := radius * radius
	for piece in b.pieces:
		if piece.gone: continue
		var bounds := Geom.bbox(piece.poly)
		if not bounds.grow(radius).has_point(local): continue
		if Geometry2D.is_point_in_polygon(local,piece.poly): return pos
		for i in piece.poly.size():
			var edge := Geometry2D.get_closest_point_to_segment(local,piece.poly[i],piece.poly[(i + 1) % piece.poly.size()])
			var distance := local.distance_squared_to(edge)
			if distance < closest:
				closest = distance
				point = edge
	return b.global_transform * point if point.is_finite() else Vector2.INF


func _can_clear(b, center: Vector2) -> bool:
	if b.freeze or b.tethered or b.get_meta("arm", false) or b == game.tools.held_body or Crew.owns(b):
		return false
	for area in game.keepout:
		if area.has_point(center): return false
	if game.dock.in_buffer(b) or game.keepout_blocks(pos, center): return false
	return game.drone == null or not game.drone.alive or center.distance_to(game.drone.global_position) > CLEAR


func _clear_obstacle(b, center: Vector2, near: Vector2, dir: Vector2, clearance: float, rear: float = R) -> bool:
	var offset := near - pos
	if offset.dot(dir) < -rear: return false # behind the entire load, not merely behind its gripper
	var side := Vector2(-dir.y, dir.x)
	var lateral := (center - pos).dot(side)
	if lateral < -0.5 or absf(lateral) <= 0.5 and b.get_instance_id() % 2 == 0: side = -side
	var gap := absf(offset.dot(side))
	var lane := maxf(R * 2.0, clearance)
	if gap >= lane + R: return false
	# Don't push into fixed hull, forbidden zones or the operator. Try the
	# opposite side if necessary; the existing navigation still routes walls.
	var destination := near + side * (lane + R)
	if not _clear_side(near, destination):
		side = -side
		destination = near + side * (lane + R)
		if not _clear_side(near, destination): return false
	var strength := clampf(1.0 - gap / (lane + R), 0.15, 1.0)
	var along: float = b.linear_velocity.dot(side)
	var acceleration := clampf((PUSH_SPEED * strength - along) * 5.0, 0.0, PUSH_ACCEL)
	b.sleeping = false
	b.apply_central_force(side * acceleration * minf(b.mass, PUSH_MASS))
	return true


func _clear_side(from: Vector2, to: Vector2) -> bool:
	if game.keepout_blocks(from, to) or not game.nav_grid().sight(from, to, R): return false
	return game.drone == null or not game.drone.alive or Geom.dist_to_segment(game.drone.global_position, from, to) > Drone.R + R


# where it is making for now
func _heading() -> Vector2:
	if not route.is_empty():
		return route[0]
	if state == "reach" and is_instance_valid(body):
		return body.global_transform * body.center_of_mass
	return pos


func halt() -> void:
	if body != null and is_instance_valid(body):
		if state in ["carry", "release"]:
			LoadMotion.let_go(body)
			body.linear_velocity = vel
		_unclaim(body)
	_done()


func _done() -> void:
	wait_reason = ""
	_scan_t = 0.0
	auto_pickup = false
	game.mouth_release(zone, who)
	_unclaim(body)
	body = null
	route = PackedVector2Array()
	state = "idle"


func _process(dt: float) -> void:
	var v := (pos - _last_pos) / maxf(dt, 0.001)
	_last_pos = pos
	_move = _move.lerp(v, 1.0 - exp(-8.0 * dt))
	var want := heading
	if _move.length() > 20.0:
		want = _move.angle()
	elif body != null and is_instance_valid(body):
		want = (body.global_transform * body.center_of_mass - pos).angle()
	heading = lerp_angle(heading, want, 1.0 - exp(-6.0 * dt))
	queue_redraw()


func _draw() -> void:
	var t0 := Time.get_ticks_usec()
	_paint()
	prof_us += Time.get_ticks_usec() - t0


func _paint() -> void:
	if idx == 0:
		_draw_refused()
	# marks on the queued pieces (the list is shared: the first hauler draws them)
	for i in (queue.size() if idx == 0 else 0):
		var b = queue[i]
		if not is_instance_valid(b):
			continue
		var c: Vector2 = b.global_transform * b.center_of_mass
		var s := 9.0 + 2.0 * sin(t * 5.0 + i)
		draw_polyline(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0), c + Vector2(0, -s)]), Pal.tint(Pal.AIR, 0.9, 1.3), 1.6, true)
		draw_string(Fonts.get_font("Medium"), c + Vector2(s + 4, 4), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.tint(Pal.AIR, 0.9, 1.2))
	# the drone itself, and its line to the load
	if wait_reason != "":
		draw_string(Fonts.get_font("Medium"), pos + Vector2(18, 28), LoadMotion.wait_line(body,wait_reason), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.heat(0.95, 1.2))
	if body != null and is_instance_valid(body) and state in ["carry", "release"]:
		draw_line(pos, body.global_transform * body.center_of_mass, Pal.tint(Pal.AIR, 0.5, 1.2), 1.2, true)
	var sc := R / 20.0
	# off the screen it isn't drawn at all
	if game != null and game.cam != null:
		var z: float = game.cam_zoom()
		var view := get_viewport_rect().size / z
		if not Rect2(game.cam.position - view * 0.5, view).grow(80.0).has_point(pos):
			return
		Art.set_scale(sc * z)
	var xf := Transform2D(0.0, Vector2(sc, sc), 0.0, pos)
	draw_set_transform_matrix(xf)
	var push := (_acc / ACCEL).limit_length(1.0) if Txt.anim_level() > 0 else Vector2.ZERO
	Art.tint = Color(Pal.AIR.r * 1.05, Pal.AIR.g * 1.05, Pal.AIR.b * 1.05)
	if idx < OLD_ART.size():
		# the first two keep their airframes (user 2026-11-12)
		var busy := state != "idle"
		Art.draw(self, OLD_ART[idx], {"heading": heading, "tool": 3 if busy else 0, "open": 1.0 if state in ["carry", "release"] else (0.4 if busy else 0.0),
			"t": t, "thrust": push, "dash": false, "design": "", "base_xf": xf})
	else:
		var dt := get_process_delta_time()
		_grip = move_toward(_grip, 1.0 if state in ["carry", "release"] else 0.0, dt * 4.0)
		_reach = move_toward(_reach, 1.0 if state == "reach" else (0.6 if _grip > 0.5 else 0.0), dt * 2.5)
		HArt.draw(self, idx - OLD_ART.size(), {"heading": heading, "t": t, "thrust": push, "reach": _reach, "grip": _grip, "base_xf": xf})
	Art.tint = Color(1, 1, 1)
	Art.lite = false
	draw_set_transform_matrix(Transform2D.IDENTITY)
