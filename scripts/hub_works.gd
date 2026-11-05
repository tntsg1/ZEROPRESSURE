extends RefCounted
# 109 号 (user 2026-10-29: "优化中央转运区，变得更酷炫一点…按之前那些标准制作"): what the central
# transfer ring's machines are doing now, run from the port's real state — nothing new saved (as
# scripts/cargo_works.gd, process_works.gd). The carousel — twelve cradles on a slewing ring — indexes
# a pitch at a time (30°), its four drives speeding it up and braking it in time; at each stop the
# lock pins go in and the transfer arm at each spoke may load the cradle in front of it from its hatch
# or unload one that has come round for it. What the cradles carry is what really moves between the
# districts now: the warehouse's jobs (put-aways from the berth, picks for the trade port or the
# furnace), the heats queued for the processing district, the trades being loaded. The carousel waits
# for any arm that has a cradle in its hands (an interlock), never the other way about.
#   stage 0: the ring is dead — the carousel stalled off its index, one cradle's crate knocked askew,
#            two of the four drives gone from their mounts, the emergency beacons turning;
#   stage 1: powered — the two drives left turn it slowly, things start to move;
#   stage 2: all four drives and the coolers: it runs at speed.
# Drawing: scripts/hub_art.gd. Hub-local metres (the station's centre at 0, y down), as PortArt.

const PITCH := TAU / 12.0
const SLOTS := 12
const R_CRADLE := 11.5         # m: the cradles' centre on the carousel
# 129 号 (user 2026-11-04: "不要让机械臂挡住了其他的台子，让它显得乱糟糟的"): each spoke's hatch,
# turret and resting spreader keep to the service deck inside the shuttle's loop (it runs at R 21.5,
# the stop's platform from R 19.4): the hatch was at 18.4 and the arms rested outside it, over the
# loop's rails, the berth spoke's over the stop. An idle arm now rests over its own hatch, folded
# towards the carousel, so the hatch, its turret and its arm read as one unit at the ring's edge.
# tests/hub_clear_check.gd sweeps them against the console, the stop and the loop.
const R_HATCH := 17.0          # m: the hatch at each spoke (was 18.4)
const R_BASE := 17.0           # m: an arm's turret, level with its hatch (was 17.8)
const BASE_SIDE := 3.4         # m: the turret beside the hatch, towards the arm's cradle (was 3.3)
const L1 := 4.3                # m: the arm's links
const L2 := 3.7
const STALL := 0.16            # rad: where the carousel stopped when the ring died
const ASKEW := 4               # the cradle whose crate was knocked askew
# per stage: [carousel rad/s, rad/s², dwell s, s between parcels of a flow, arm rad/s]
const RUN := [[0.0, 0.0, 0.0, 0.0, 0.0], [0.11, 0.06, 4.2, 22.0, 1.0], [0.26, 0.16, 2.6, 9.0, 1.7]]
const A_ARM := 3.2
# 129 号: an arm moves its spreader in a straight line between hatch and cradle (both joints together,
# as a real arm's controller does): its sweep is the narrow strip between them, not the arcs the two
# joints made each driven on its own. m/s at full speed per arm rad/s of the stage, m/s²
const V_TIP := 3.4
const A_TIP := 9.0
const V_LIFT := 1.6            # /s the spreader lifts (0 down … 1 up), and the hatch's lift
const MAX_PARCELS := 11
# an arm's phases: where its spreader is, and which hold it down on what it grips or sets
const AT_HATCH := ["to_hatch", "lower_hatch", "grip_hatch", "lift_hatch", "set_hatch", "free_hatch", "hold"]
const AT_CRADLE := ["to_cradle", "lower_cradle", "grip_cradle", "lift_cradle", "set_cradle", "free_cradle"]
const DOWN := ["lower_hatch", "grip_hatch", "set_hatch", "lower_cradle", "grip_cradle", "set_cradle"]
const HATCH_UP := ["to_hatch", "lower_hatch", "set_hatch", "free_hatch"]

static var stage := 0
static var theta := STALL      # the carousel's angle (cradle k sits at theta + k·PITCH)
static var omega := 0.0
static var target := STALL
static var dwell := 0.0        # s stood at this index
static var pins := 0.0         # the lock pins: 0 out … 1 in
static var leaving := false    # the dwell is over: the pins coming out, then the next pitch
static var cradles: Array = [] # per slot: a parcel or null
static var parcels: Array = []
static var arms := {}          # spoke zone -> arm
static var hatch := {}         # spoke zone -> {lift 0 … 1, vlift, doors 0 … 1, parcel}
static var flows: Array = []   # [from, to, key] what moves through the hub now
static var _flow_t := {}       # flow -> s until its next parcel
static var _flow_scan := 0.0
static var t := 0.0
static var events: Array = []  # [sound, hub-local metres]
static var moved := 0          # parcels delivered (tests)
static var _pin_was := 0.0
# developer workbench "转运环演示货流": every spoke's arm gets goods to move, whatever the port is doing
static var demo := false
# 130 号: the freight trains bring the crates to the hatches and take them away (scripts/freight_works.gd):
# a train stands on the loop by a hatch, locks, and its wagon's rollers push a crate across the apron
# onto the lift (down), or take one off it. While they do (trains_feed), nothing appears on a hatch by
# itself and a crate handed down waits on its lowered lift ("out") for a train. Without them (the
# headless tests that run this alone) the old way: crates come up the hatches from below.
static var trains_feed := false
static var served := {}        # spokes a freight train serves (the rest still lift their crates from below)
static var reserved := {}      # spoke -> a train on its way to push a crate onto that hatch: its arm hands none down meanwhile
const OUT_WAIT := 8.0          # s a handed-down crate waits for a train before it goes on underground
const OUT_WAIT_TRAIN := 30.0   # … where a train serves the spoke (it comes round to the hatch about this often)
static var went_down := 0      # tests: crates that went underground for want of a train
const PUSH_T := 1.0            # s the rollers take to move a crate between a wagon and a lift
const DEMO_FLOWS := [["salvage", "cargo", "steel_plate:1"], ["cargo", "process", "ferrous_scrap:1"],
	["process", "cargo", "steel_billet:1"], ["cargo", "trade", "steel_section:1"], ["tug", "process", "nonferrous_mix:1"], ["trade", "salvage", "steel_parts:1"]]


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


static func reset() -> void:
	theta = STALL
	omega = 0.0
	target = STALL
	dwell = 0.0
	pins = 0.0
	leaving = false
	cradles = []
	cradles.resize(SLOTS)
	parcels = []
	arms = {}
	hatch = {}
	flows = []
	_flow_t = {}
	events = []
	moved = 0
	reserved = {}
	served = {}


static func _drive(cur: float, vel: float, to: float, vmax: float, acc: float, dt: float) -> Array:
	var d := to - cur
	var want := clampf(sqrt(2.0 * acc * absf(d)) * signf(d), -vmax, vmax)
	vel = move_toward(vel, want, acc * 2.0 * dt)
	var nxt := cur + vel * dt
	if signf(to - nxt) != signf(d) or absf(to - nxt) < 0.0005:
		return [to, 0.0]
	return [nxt, vel]


# the spokes the hub serves: zone -> its direction (the power spoke brings the feeder bridge instead)
static var _sp := {}
static func spokes() -> Dictionary:
	if _sp.is_empty():
		var c := PortStructure.centre()
		for z in ["tug", "process", "trade", "cargo", "salvage", "power"]:
			_sp[z] = ((PortStructure.door(z)[0] as Vector2) - c).angle()
	return _sp


# across a spoke, towards the larger angle (clockwise on screen)
static func across(a: float) -> Vector2:
	return Vector2.from_angle(a + PI * 0.5)


# which way round from its spoke an arm's cradle stands: +1 clockwise, -1 the other way
# a spoke's fixed places, worked out once: its direction, its arm's index and side, hatch, turret, rest
static var _geo := {}
static func _g(zone: String) -> Dictionary:
	if not _geo.has(zone):
		var a := float(spokes().get(zone, 0.0))
		var u := Vector2.from_angle(a)
		# the carousel's angle a spoke's arm works at: the index nearest its spoke
		var slot := roundf(a / PITCH) * PITCH
		var side := 1.0 if wrapf(slot - a, -PI, PI) >= 0.0 else -1.0
		# the turret stands on the side of the hatch its cradle lies to
		var base := u * R_BASE + across(a) * BASE_SIDE * side
		var hatch_p := u * R_HATCH
		# at rest: over its own hatch (129 号; was out past it, over the shuttle's rails)
		_geo[zone] = {"u": u, "slot": slot, "side": side, "hatch": hatch_p, "base": base, "park": hatch_p}
	return _geo[zone]


static func side_of(zone: String) -> float:
	return float(_g(zone).side)


static func dir_of(zone: String) -> Vector2:
	return _g(zone).u


static func slot_angle(zone: String) -> float:
	return float(_g(zone).slot)


static func hatch_at(zone: String) -> Vector2:
	return _g(zone).hatch


static func base_at(zone: String) -> Vector2:
	return _g(zone).base


static func cradle_at(slot: int, th := INF) -> Vector2:
	return Vector2.from_angle((theta if th == INF else th) + slot * PITCH) * R_CRADLE


# the slot standing at a spoke's arm now (-1 while the carousel is between indexes)
static func slot_at(zone: String) -> int:
	if not settled():
		return -1
	var k := roundi(wrapf(slot_angle(zone) - theta, 0.0, TAU) / PITCH) % SLOTS
	return k


static func settled() -> bool:
	return stage >= 1 and not leaving and absf(omega) < 1e-4 and absf(theta - target) < 1e-4 and pins > 0.98


static func _arm(zone: String) -> Dictionary:
	if not arms.has(zone):
		var b := base_at(zone)
		var park := _park(zone)
		var ik := solve(b, park, _elbow(zone))
		arms[zone] = {"q1": ik[0], "q2": ik[1], "v1": 0.0, "v2": 0.0, "tip": park, "vt": 0.0, "yaw": float(spokes()[zone]) + PI * 0.5, "vy": 0.0, "h": 1.0, "vh": 0.0,
			"phase": "park", "task": "", "parcel": null, "slot": -1, "wait": 0.0, "beacon": 0.0, "grip": 0.0}
	return arms[zone]


static func _hatch(zone: String) -> Dictionary:
	if not hatch.has(zone):
		hatch[zone] = {"lift": 0.0, "vlift": 0.0, "doors": 0.0, "vdoors": 0.0, "parcel": null, "lamp": 0.0, "push": {}, "handed": null}
	return hatch[zone]


static func _park(zone: String) -> Vector2:
	return _g(zone).park


# the elbow bends away from the carousel's centre line: +1 or -1
static func _elbow(zone: String) -> float:
	return -side_of(zone)


# a two-link arm from b reaching p: [shoulder angle, forearm angle] (both absolute)
static func solve(b: Vector2, p: Vector2, elbow: float) -> Array:
	var d := clampf(b.distance_to(p), absf(L1 - L2) + 0.05, L1 + L2 - 0.02)
	var a := (b.direction_to(p)).angle()
	var cos_s := clampf((L1 * L1 + d * d - L2 * L2) / (2.0 * L1 * d), -1.0, 1.0)
	var q1 := a + acos(cos_s) * elbow
	var e := b + Vector2.from_angle(q1) * L1
	var q2 := (e.direction_to(b + Vector2.from_angle(a) * d)).angle()
	return [q1, q2]


static func wrist(zone: String) -> Vector2:
	var a := _arm(zone)
	return base_at(zone) + Vector2.from_angle(float(a.q1)) * L1 + Vector2.from_angle(float(a.q2)) * L2


static func elbow_at(zone: String) -> Vector2:
	return base_at(zone) + Vector2.from_angle(float(_arm(zone).q1)) * L1


# ------------------------------------------------------------------ what moves through the hub
static func _use(key: String) -> String:
	return Warehouse.use_of(key)


static func scan_flows() -> Array:
	var out: Array = []
	if demo:
		return DEMO_FLOWS.duplicate(true)
	if Career.data.is_empty():
		return out
	for j in Warehouse.data().get("jobs", []):
		var key := str(j.get("key", ""))
		var d := str(j.get("dir", ""))
		if d in ["in", "store"]:
			out.append(["salvage", "cargo", key])
		elif _use(key) in ["scrap", "ingot", "nonferrous"] and d == "pick":
			out.append(["cargo", "process", key])
		else:
			out.append(["cargo", "trade", key])
	var heats := 0
	for e in ProcessQueue.entries():
		if float(e.get("t", 0.0)) - float(e.get("melted", 0.0)) > 0.05 and heats < 2:
			heats += 1
			out.append(["cargo", "process", "ferrous_scrap:1"])
	for tr in Career.data.get("exchange", {}).get("trades", []):
		if str(tr.get("state", "")) in ["awaiting_dispatch", "loading"]:
			out.append(["cargo", "trade", "%s:%d" % [str(tr.get("item", "")), int(tr.get("grade", 0))]])
	# one flow a route and goods
	var seen := {}
	var uniq: Array = []
	for f in out:
		var k := "%s>%s>%s" % f
		if not seen.has(k) and uniq.size() < 6:
			seen[k] = true
			uniq.append(f)
	return uniq


static func loaded() -> int:
	var n := 0
	for p in cradles:
		if p != null:
			n += 1
	return n


# ------------------------------------------------------------------ the step
static func tick(dt: float) -> void:
	t += dt
	if cradles.size() != SLOTS:
		cradles.resize(SLOTS)
	var st := Port.stage("ring") if not Career.data.is_empty() else 0
	if st != stage:
		stage = st
		if stage >= 1 and target == STALL:
			# the ring comes back: from where it stalled to the next index (it turns anticlockwise: the
			# berth's goods reach the cargo spoke a pitch on, the cargo spoke's the trade port two on)
			target = floorf((theta - 0.01) / PITCH) * PITCH
	var run: Array = RUN[clampi(stage, 0, 2)]
	if stage == 0:
		for z in arms:
			arms[z].beacon = 0.0
		return
	# what moves through the hub: looked for twice a second
	_flow_scan -= dt
	if _flow_scan <= 0.0:
		_flow_scan = 0.5
		flows = scan_flows()
	_spawn(dt, float(run[3]))
	_carousel(dt, run)
	for z in spokes():
		if z == "power":
			continue
		_hatch_step(z, dt)
		_arm_step(z, dt, float(run[4]))


static func _carousel(dt: float, run: Array) -> void:
	var at_index := absf(theta - target) < 1e-4 and absf(omega) < 1e-4
	if at_index and not leaving:
		pins = move_toward(pins, 1.0, dt * 2.5)
		if pins > 0.98 and _pin_was <= 0.98:
			events.append(["points", Vector2.from_angle(0.0) * 7.6])
		dwell += dt if pins > 0.98 else 0.0
		# go on once the dwell is up and no arm has a cradle in its hands
		if dwell >= float(run[2]) and not _arms_on_cradles():
			leaving = true
	elif leaving:
		pins = move_toward(pins, 0.0, dt * 2.5)
		if pins <= 0.0:
			leaving = false
			target -= PITCH
			dwell = 0.0
	else:
		pins = move_toward(pins, 0.0, dt * 2.5)
		if pins <= 0.0:
			var r := _drive(theta, omega, target, float(run[0]), float(run[1]), dt)
			theta = r[0]
			omega = r[1]
	_pin_was = pins
	# keep the angle small (the cradles' places don't care)
	if theta < -TAU * 4.0:
		theta += TAU * 4.0
		target += TAU * 4.0


static func _arms_on_cradles() -> bool:
	for z in arms:
		if str(arms[z].phase) in AT_CRADLE:
			return true
		# an arm that will do something with the cradle in front of it holds the carousel too
		if _wants_cradle(z):
			return true
	return false


# this arm has something to do with the cradle now in front of it
static func _wants_cradle(z: String) -> bool:
	var k := slot_at(z)
	if k < 0:
		return false
	var a: Dictionary = arms[z]
	if str(a.phase) in ["hold"] and a.parcel != null and cradles[k] == null:
		return true
	var p = cradles[k]
	if p != null and str(p.to) == z and a.parcel == null and str(a.phase) == "park" and _hatch(z).parcel == null and (_hatch(z).push as Dictionary).is_empty() and not reserved.has(z):
		return true
	return false


static func _spawn(dt: float, every: float) -> void:
	if trains_feed:
		return
	for f in flows:
		var k := "%s>%s>%s" % f
		_flow_t[k] = float(_flow_t.get(k, every * 0.3)) - dt
		if float(_flow_t[k]) > 0.0:
			continue
		var from: String = f[0]
		# a flow keeps two crates in the hub at most
		var alive := 0
		for p in parcels:
			if str(p.from) == from and str(p.to) == str(f[1]) and str(p.key) == str(f[2]):
				alive += 1
		if alive >= 2:
			continue
		var hz := _hatch(from)
		if hz.parcel != null or _arm(from).parcel != null or parcels.size() >= MAX_PARCELS:
			continue
		_flow_t[k] = every
		var p := {"key": str(f[2]), "use": _use(str(f[2])), "from": from, "to": str(f[1]), "at": "hatch", "slot": -1}
		parcels.append(p)
		hz.parcel = p
	# a flow that has ended forgets its clock
	for k in _flow_t.keys():
		var live := false
		for f in flows:
			if "%s>%s>%s" % f == k:
				live = true
		if not live:
			_flow_t.erase(k)


static func _hatch_step(z: String, dt: float) -> void:
	var hz := _hatch(z)
	var a := _arm(z)
	# up with a parcel to hand over or one being handed down; down and shut otherwise
	var want_up: bool = hz.parcel != null or str(a.phase) in HATCH_UP or (str(a.task) == "unload" and a.parcel != null)
	if hz.parcel != null and str(hz.parcel.at) in ["gone", "out"]:
		want_up = false
	var push: Dictionary = hz.push
	if not push.is_empty():
		want_up = false
	# 130 号: the rollers move a crate between a wagon and the lift (down, the doors open)
	if not push.is_empty() and float(hz.lift) < 0.02 and float(hz.doors) > 0.98:
		push.t = minf(1.0, float(push.t) + dt / PUSH_T)
		hz.lamp = float(hz.lamp) + dt * 5.0
		if float(push.t) >= 1.0:
			var pp: Dictionary = push.p
			if str(push.dir) == "in":
				pp.at = "hatch"
				parcels.append(pp)
				hz.parcel = pp
			else:
				parcels.erase(pp)
				hz.handed = pp
			hz.push = {}
			events.append(["clamp", hatch_at(z)])
	var dr := _drive(float(hz.doors), float(hz.vdoors), 1.0 if want_up or float(hz.lift) > 0.05 or not push.is_empty() else 0.0, 2.2, 9.0, dt)
	hz.doors = dr[0]
	hz.vdoors = dr[1]
	var lr := _drive(float(hz.lift), float(hz.vlift), 1.0 if want_up and float(hz.doors) > 0.95 else 0.0, 1.4, 4.0, dt)
	hz.lift = lr[0]
	hz.vlift = lr[1]
	hz.lamp = float(hz.lamp) + dt * 5.0 if absf(float(hz.vlift)) > 0.01 or absf(float(hz.vdoors)) > 0.01 else 0.0
	# 130 号: a crate waiting on a lowered lift that no train has come for in OUT_WAIT goes on down, under
	# the deck, as before the trains (the hub keeps turning)
	if hz.parcel != null and str(hz.parcel.at) == "out" and (hz.push as Dictionary).is_empty():
		hz.parcel.waited = float(hz.parcel.get("waited", 0.0)) + dt
		if float(hz.parcel.waited) > (OUT_WAIT_TRAIN if served.has(z) else OUT_WAIT):
			parcels.erase(hz.parcel)
			hz.parcel = null
			went_down += 1
	# a parcel handed down goes once the lift is down (130 号: with the trains it waits there for one)
	if hz.parcel != null and str(hz.parcel.at) == "gone" and float(hz.lift) < 0.02:
		moved += 1
		if trains_feed and served.has(z):
			hz.parcel.at = "out"
		else:
			parcels.erase(hz.parcel)
			hz.parcel = null


static func _arm_step(z: String, dt: float, vmax: float) -> void:
	var a := _arm(z)
	var hz := _hatch(z)
	var ph := str(a.phase)
	var k := slot_at(z)
	# parked with nothing to do: nothing to work out
	if ph == "park" and bool(a.get("rest", false)) and not (a.parcel == null and hz.parcel != null) and not (k >= 0 and cradles[k] != null):
		return
	a.rest = false
	var to := _park(z)
	var yaw := float(spokes()[z]) + PI * 0.5
	var h := 1.0
	match ph:
		"park":
			if a.parcel == null and hz.parcel != null and str(hz.parcel.at) == "hatch" and float(hz.lift) > 0.98:
				a.task = "load"
				ph = "to_hatch"
			elif k >= 0 and cradles[k] != null and str(cradles[k].to) == z and hz.parcel == null and (hz.push as Dictionary).is_empty() and not reserved.has(z):
				a.task = "unload"
				a.slot = k
				ph = "to_cradle"
		"hold":
			# a parcel picked from the hatch, held over it until an empty cradle stands in front
			to = hatch_at(z)
			if k >= 0 and cradles[k] == null:
				a.slot = k
				ph = "to_cradle"
	# where this phase takes the spreader
	var at_hatch := ph in AT_HATCH
	var at_cradle := ph in AT_CRADLE
	if at_hatch:
		to = hatch_at(z)
	elif at_cradle:
		to = cradle_at(int(a.slot), target)
		yaw = target + int(a.slot) * PITCH + PI * 0.5
	if ph in DOWN:
		h = 0.0
	# the spreader along the straight line to where it is going, the joints following it (129 号)
	var tip: Vector2 = a.tip
	var gap := to - tip
	var left := gap.length()
	var vt := float(a.vt)
	if left < 0.0005:
		tip = to
		vt = 0.0
	else:
		vt = move_toward(vt, minf(vmax * V_TIP, sqrt(2.0 * A_TIP * left)), A_TIP * 2.0 * dt)
		tip += gap / left * minf(vt * dt, left)
	a.tip = tip
	a.vt = vt
	var ik := solve(base_at(z), tip, _elbow(z))
	var r1 := [float(ik[0]), (wrapf(float(ik[0]) - float(a.q1), -PI, PI)) / maxf(dt, 1e-6)]
	var r2 := [float(ik[1]), (wrapf(float(ik[1]) - float(a.q2), -PI, PI)) / maxf(dt, 1e-6)]
	# the spreader turns the short way: a crate is the same either way round
	var dy := wrapf(yaw - float(a.yaw), -PI * 0.5, PI * 0.5)
	var ry := _drive(float(a.yaw), float(a.vy), float(a.yaw) + dy, 1.4, 4.0, dt)
	a.q1 = r1[0]
	a.v1 = r1[1]
	a.q2 = r2[0]
	a.v2 = r2[1]
	a.yaw = ry[0]
	a.vy = ry[1]
	var still := absf(float(a.v1)) < 1e-3 and absf(float(a.v2)) < 1e-3 and absf(float(a.vy)) < 1e-3
	# only lift or lower once there, never move with the spreader down
	var rh := _drive(float(a.h), float(a.vh), h if still or h > float(a.h) else float(a.h), V_LIFT, 5.0, dt)
	a.h = rh[0]
	a.vh = rh[1]
	var moving := not still or absf(float(a.vh)) > 1e-3
	a.beacon = float(a.beacon) + dt * 6.0 if moving else float(a.beacon)
	if ph == "park" and still and float(a.h) > 0.99:
		a.rest = true
	var down := float(a.h) < 0.01 and still
	var up := float(a.h) > 0.99 and still
	a.wait = float(a.wait) + dt
	match ph:
		"to_hatch":
			if up:
				ph = "lower_hatch"
		"lower_hatch":
			if down:
				ph = "grip_hatch" if a.parcel == null else "set_hatch"
				a.wait = 0.0
		"grip_hatch":
			a.grip = minf(1.0, float(a.grip) + dt * 4.0)
			if a.wait > 0.35:
				a.parcel = hz.parcel
				hz.parcel = null
				a.parcel.at = "arm"
				events.append(["clamp", hatch_at(z)])
				ph = "lift_hatch"
		"lift_hatch":
			if up:
				ph = "hold"
		"set_hatch":
			a.grip = maxf(0.0, float(a.grip) - dt * 4.0)
			if a.wait > 0.35:
				hz.parcel = a.parcel
				a.parcel = null
				hz.parcel.at = "gone"
				events.append(["clamp", hatch_at(z)])
				ph = "free_hatch"
		"free_hatch":
			if up:
				ph = "park"
				a.task = ""
		"to_cradle":
			if up and settled():
				ph = "lower_cradle"
		"lower_cradle":
			if down:
				ph = "set_cradle" if a.parcel != null else "grip_cradle"
				a.wait = 0.0
		"grip_cradle":
			a.grip = minf(1.0, float(a.grip) + dt * 4.0)
			if a.wait > 0.35:
				a.parcel = cradles[int(a.slot)]
				cradles[int(a.slot)] = null
				if a.parcel != null:
					a.parcel.at = "arm"
				events.append(["clamp", cradle_at(int(a.slot))])
				ph = "lift_cradle"
		"lift_cradle":
			if up:
				ph = "to_hatch" if a.parcel != null else "park"
		"set_cradle":
			a.grip = maxf(0.0, float(a.grip) - dt * 4.0)
			if a.wait > 0.35:
				cradles[int(a.slot)] = a.parcel
				a.parcel.at = "cradle"
				a.parcel.slot = int(a.slot)
				a.parcel = null
				events.append(["clamp", cradle_at(int(a.slot))])
				ph = "free_cradle"
		"free_cradle":
			if up:
				ph = "park"
				a.task = ""
	a.phase = ph


# [what it does now, lamp] for a spoke's arm
static func arm_state(z: String) -> Array:
	if stage == 0:
		return [w("断电 · 停用", "NO POWER"), "off"]
	var a := _arm(z)
	if a.parcel != null:
		return [w("搬运 %s → %s", "CARRYING %s → %s") % [Ops.item_name(str(a.parcel.key)), Port.name_of(str(a.parcel.to))], "work"]
	if str(a.phase) != "park":
		return [w("去取货", "GOING FOR A LOAD"), "work"]
	return [w("待命", "STANDING BY"), "ok"]


# ------------------------------------------------------------------ 130 号: the trains' side of a hatch
# a crate may be pushed onto this hatch's lift now: the ring running, the lift down and empty, its arm
# not bringing one down to it
static func hatch_takes(z: String) -> bool:
	if stage < 1 or z == "power" or not spokes().has(z):
		return false
	var hz := _hatch(z)
	var a := _arm(z)
	return hz.parcel == null and (hz.push as Dictionary).is_empty() and hz.handed == null and float(hz.lift) < 0.02 		and not (str(a.task) == "unload") and parcels.size() < MAX_PARCELS


# a crate up the lift from below (a spoke no freight train serves)
static func lift_in(z: String, p: Dictionary) -> void:
	p.at = "hatch"
	p.slot = -1
	parcels.append(p)
	_hatch(z).parcel = p


static func push_in(z: String, p: Dictionary) -> void:
	p.at = "push"
	p.slot = -1
	_hatch(z).push = {"p": p, "t": 0.0, "dir": "in"}


# the crate waiting on this hatch's lowered lift for a train (null if none)
static func hatch_out(z: String):
	if not hatch.has(z):
		return null
	var hz: Dictionary = hatch[z]
	if hz.parcel != null and str(hz.parcel.at) == "out" and (hz.push as Dictionary).is_empty():
		return hz.parcel
	return null


static func push_out(z: String) -> void:
	var hz := _hatch(z)
	var p: Dictionary = hz.parcel
	p.at = "push"
	hz.parcel = null
	hz.push = {"p": p, "t": 0.0, "dir": "out"}


# the crate the rollers have just put on a wagon (taken once), or null
static func handed(z: String):
	var hz := _hatch(z)
	var p = hz.handed
	hz.handed = null
	return p


# a push under way at this hatch: {p, t 0 … 1, dir} or {}
static func pushing(z: String) -> Dictionary:
	return _hatch(z).push if hatch.has(z) else {}


# a crate on its way down to this hatch (an arm bringing it, or one waiting there already)
static func outbound(z: String) -> bool:
	if hatch_out(z) != null:
		return true
	var a: Dictionary = arms.get(z, {})
	if not a.is_empty() and str(a.task) == "unload":
		return true
	for p in cradles:
		if p != null and str(p.to) == z:
			return true
	return false
