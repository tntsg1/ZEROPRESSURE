extends RefCounted
# 96 号 (user 2026-10-28: the tug station as fine as the drone, smooth, every machine reading as
# what it is and what it is doing; then "既然叫拖船站，为什么船在外面？" — Q10 A + the company's
# tugs come in too, Q11 B, Q12 B, Q13 A): what the tug station's machines are doing now, run from
# the real state (TugFleet home / away, TugYard's charge, the hulk in the mouth, the stage). Every
# machine is an actuator chasing a target — accelerating, braking in time, the hook's load swinging
# as the trolley starts and stops — and each job is a list of steps that set targets and wait for
# them (Jev A 0.99). Two floors, both through the left wall:
#   upper: the tug deck. A tug home flies in through the tug gate to its berth (T-01 the far one,
#     in the near lane; T-02 nearer, in the far lane); its aft thruster pod is swapped through the
#     deck hatch under it: the lift takes the worn pod down to the service table, the overhauled
#     spare goes up and is fitted, the worn one is overhauled on the table while the tug charges.
#   lower: the mouth. The hulk in yard berth 1 lies stern first under the gantry: the clamp arms
#     close on it, the hose draws off its propellant into the tank (a share by stage, real:
#     TugYard.prepped), the gantry sets the push frame on its stern and its trolley's scanner
#     sweeps the hull. Then it waits there to be pushed to the berth.
# Nothing here is saved but what TugYard keeps; the drawing is scripts/tug_station_art.gd. Box-local
# metres (the district's 60 × 28, floor at 26.8).

# ---------------------------------------------------------------- the gantry over the mouth
const LEGS := Vector2(2.0, 22.0)
const PIVOT_Y := 2.7          # where the hoist ropes leave the drum
const PARK_X := 20.6
const HOOK_PARK := 4.4        # the hook parked high: the tugs pass under it
const FRAME_STAND := Vector2(21.0, 26.8)   # the push frame's stand, on the floor right of the stern
const FRAME_H := 5.0          # the push frame: its lifting lug to its foot
const V_X := 3.0
const A_X := 1.3
const V_H := 2.4
const A_H := 2.0
# ---------------------------------------------------------------- the tug deck
const DECK_Y := 10.8          # the deck's top
const DECK_X := Vector2(22.6, 51.8)
const BERTH_X := [45.0, 31.0]  # T-01 (near lane, far in), T-02 (far lane)
const GATE := Vector2(5.0, 10.6)   # the tug gate in the left wall, top and bottom
# where a tug waits outside the gate, handed over to or from the flights outside (scripts/tow_traffic.gd).
# 2026-11-05: -18 put its aft pod against the sterns of the yard's berths (their sterns at -26): now it
# stands just clear of the wall (its nose 2.9 m off), 9 m clear of the yard's column
const OUT_X := -9.5
const AFT := 5.2              # m from a tug's middle to its aft pod's lifting point
const POD_K := 0.5            # a tug's pod at half the drawing's size
const POD_ON_TUG := 7.15      # the pod's lifting point fitted (its bottom at the tug's belly line)
const TABLE_Y := 21.28        # … lying on the service table (its saddles 22.28, the top 22.6)
const SLOT_A := 30.5          # the table: the spare's saddle, the overhaul saddle
const SLOT_B := 35.2
const OVERHAUL_S := 45.0
const V_L := 2.2              # the lifts
const A_L := 1.6
const V_T := 1.4              # the table's transfer slide
const A_T := 1.2
# ---------------------------------------------------------------- the mouth
const MOUTH := Vector2(12.6, 26.6)
const DRAIN_S := 18.0         # s for the hose to draw off its share
const REFUEL := 0.25          # m³ of propellant a tug takes after a tow

# the gantry
static var x := PARK_X
static var vx := 0.0
static var x_to := PARK_X
static var hook := HOOK_PARK
static var vh := 0.0
static var hook_to := HOOK_PARK
static var sway := 0.0
static var vsway := 0.0
static var drum := 0.0
static var wheel := 0.0
static var on_hook := ""      # "" / "frame"
static var frame_on := "stand" # where the push frame is: "stand", "hook", "hulk"
static var scan := 0.0        # the trolley's scanner, 0 off … 1 sweeping
# the mouth
static var hulk := {}         # the hulk in the mouth: {id, ship, stern (x m, box-local), cy, h, len, inside, done}
static var arms := 0.0        # the clamp arms 0 open … 1 on the hull
static var hose := 0.0        # the drain hose 0 reeled … 1 on the hulk's port
static var drain := 0.0       # how far the draw-off is, 0 … 1
static var mouth_door := 0.0  # 0 shut … 1 open
static var prep_steps: Array = []
static var prep_id := ""
# the tugs
static var dock: Array = [0.0, 0.0]        # per tug, 0 out beyond the wall … 1 on its berth
static var gate := 0.0                     # the tug gate 0 shut … 1 open
static var tug_pod: Array = [true, true]   # its aft pod fitted
static var hatch: Array = [0.0, 0.0]
static var lift: Array = [TABLE_Y, TABLE_Y]   # the lift's platform: where a pod's lifting point would be
static var vlift: Array = [0.0, 0.0]
static var lift_to: Array = [TABLE_Y, TABLE_Y]
static var lift_pod: Array = ["", ""]
static var slot := {"A": "spare", "B": ""}   # on the table's saddles
static var tx := SLOT_A        # the transfer slide, and what rides on it
static var vt := 0.0
static var tx_to := SLOT_A
static var t_pod := ""
static var wear := 0.0         # the pod on saddle B: 1 just off a tug … 0 overhauled
static var arm: Array = [0.0, 0.0]   # the propellant arm on a berthed tug
static var umb: Array = [0.0, 0.0]   # the charging umbilical
static var steps: Array = []
static var job_tug := -1
static var queue: Array = []
static var wait := 0.0
static var wait2 := 0.0
# the tank (shown smoothly; the real m³ is TugYard.tank())
static var tank_show := 0.0
static var pump := 0.0
static var fuel_left := 0.0    # m³ still to go out to the tug being refuelled
static var fuel_tug := -1
static var t := 0.0
static var lifts := 0          # tests: swaps done
static var preps := 0          # tests: hulks pre-processed
static var _home := {}
static var _primed := false
static var home_now: Array = [false, false]   # this frame's TugFleet.home (asked once a frame, it walks the saves)
static var count_now := 0
static var _look := 0.0        # s to the next look at the yard's berth 1
static var _docked := {}
static var events: Array = []  # [sound, box-local m] for the machines' real-recording one-shots, drained by the drawer
static var _was := {}
# tugs out on a tow, a push or a flight home seen on camera (scripts/tow_traffic.gd draws them):
# not on the deck, not flown in, until they are let go at the gate (then they fly in as any tug home)
static var held := {}
static var gate_call := false   # a tug flying home is near: the gate opens before it gets there


static func hold(i: int) -> void:
	if i < 0 or i >= dock.size():
		return
	held[i] = true
	dock[i] = 0.0


static func release(i: int) -> void:
	held.erase(i)


# where a tug waits outside the tug gate (box-local m, its skids): where it is handed over
static func gate_spot() -> Vector2:
	return Vector2(OUT_X, DECK_Y)


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


static func reset() -> void:
	x = PARK_X; vx = 0.0; x_to = PARK_X; hook = HOOK_PARK; vh = 0.0; hook_to = HOOK_PARK
	sway = 0.0; vsway = 0.0; drum = 0.0; wheel = 0.0; on_hook = ""; frame_on = "stand"; scan = 0.0
	hulk = {}; arms = 0.0; hose = 0.0; drain = 0.0; mouth_door = 0.0; prep_steps = []; prep_id = ""
	dock = [0.0, 0.0]; gate = 0.0; tug_pod = [true, true]; hatch = [0.0, 0.0]
	lift = [TABLE_Y, TABLE_Y]; vlift = [0.0, 0.0]; lift_to = [TABLE_Y, TABLE_Y]; lift_pod = ["", ""]
	slot = {"A": "spare", "B": ""}; tx = SLOT_A; vt = 0.0; tx_to = SLOT_A; t_pod = ""; wear = 0.0
	arm = [0.0, 0.0]; umb = [0.0, 0.0]; steps = []; job_tug = -1; queue = []; wait = 0.0; wait2 = 0.0
	tank_show = TugYard.tank(); pump = 0.0; fuel_left = 0.0; fuel_tug = -1
	t = 0.0; lifts = 0; preps = 0; _home = {}; _primed = false; events = []; _was = {}
	home_now = [false, false]; count_now = 0; _look = 0.0; _docked = {}; held = {}; gate_call = false


static func powered() -> bool:
	return Port.stage("tug") >= 1


static func busy() -> bool:
	return job_tug >= 0


static func lift_x(i: int) -> float:
	return float(BERTH_X[i]) - AFT


# where tug i is now (box-local m, its middle on the deck line) and how far it is in
static func tug_at(i: int) -> Vector2:
	var k := Pal.ease_io(clampf(float(dock[i]), 0.0, 1.0))
	return Vector2(lerpf(OUT_X, float(BERTH_X[i]), k), DECK_Y)


# a tug home: one pod swap queued, its refuel from the tank
static func homecoming(i: int) -> void:
	if not queue.has(i) and job_tug != i:
		queue.append(i)
	if powered():
		fuel_tug = i
		fuel_left += REFUEL


# accelerate toward a target and brake in time to stop on it: [position, velocity]
static func _drive(cur: float, vel: float, to: float, vmax: float, acc: float, dt: float) -> Array:
	var d := to - cur
	var want := clampf(sqrt(2.0 * acc * absf(d)) * signf(d), -vmax, vmax)
	vel = move_toward(vel, want, acc * 2.0 * dt)
	var nxt := cur + vel * dt
	if signf(to - nxt) != signf(d) or absf(to - nxt) < 0.002:
		return [to, 0.0]
	return [nxt, vel]


static func tick(dt: float) -> void:
	t += dt
	var on := powered()
	count_now = TugFleet.count()
	var away := TugFleet.away()
	for i in 2:
		home_now[i] = i < count_now and not away.has(i)
	_look -= dt
	if _look <= 0.0:
		_look = 0.25
		_docked = TugYard.docked(true)
	_watch_hulk(dt)
	# the tugs: in through the gate, out again, a swap for each one home
	var moving_tug := false
	for i in dock.size():
		var exists := i < count_now
		var home: bool = home_now[i] and not held.has(i)
		if _primed and home and not bool(_home.get(i, true)):
			homecoming(i)
		if not _primed:
			dock[i] = 1.0 if home else 0.0
		_home[i] = home
		var want := 1.0 if home else 0.0
		# a tug only moves with the gate open
		if absf(float(dock[i]) - want) > 0.001:
			moving_tug = true
			if gate > 0.98:
				dock[i] = move_toward(float(dock[i]), want, dt * 0.16)
		var name: String = TugFleet.NAMES[i]
		var berthed := float(dock[i]) > 0.999
		var fueling := fuel_tug == i and fuel_left > 0.0 and berthed and on
		arm[i] = move_toward(float(arm[i]), 1.0 if fueling else 0.0, dt * 0.6)
		umb[i] = move_toward(float(umb[i]), 1.0 if berthed and exists and TugYard.charge(name) < 1.0 else 0.0, dt * 0.8)
	gate = move_toward(gate, 1.0 if moving_tug or gate_call else 0.0, dt * 0.5)
	_primed = true
	# the deck's swaps
	if steps.is_empty() and not queue.is_empty() and on:
		var nxt: int = queue.pop_front()
		if bool(home_now[nxt]) and float(dock[nxt]) > 0.999 and slot.A == "spare" and slot.B == "":
			_swap(nxt)
		elif bool(home_now[nxt]):
			queue.push_front(nxt)
	_run(steps, dt, true)
	if prep_steps.is_empty() and not hulk.is_empty() and on and prep_id != str(hulk.id) and not bool(hulk.get("done", false)):
		_prep()
	_run(prep_steps, dt, false)
	# the machines
	var px := x
	var r := _drive(x, vx, x_to, V_X, A_X, dt)
	var acc := (float(r[1]) - vx) / maxf(dt, 1e-4)
	x = r[0]; vx = r[1]
	wheel += (x - px) / 0.3
	var ph := hook
	r = _drive(hook, vh, hook_to, V_H, A_H, dt)
	hook = r[0]; vh = r[1]
	drum += (hook - ph) / 0.4
	var length := maxf(1.2, hook - PIVOT_Y)
	vsway += clampf(-9.8 / length * sin(sway) - acc / length * 0.3 - vsway * 1.1, -8.0, 8.0) * dt
	sway = clampf(sway + vsway * dt, -0.07, 0.07)
	for i in 2:
		r = _drive(float(lift[i]), float(vlift[i]), float(lift_to[i]), V_L, A_L, dt)
		lift[i] = r[0]; vlift[i] = r[1]
	r = _drive(tx, vt, tx_to, V_T, A_T, dt)
	tx = r[0]; vt = r[1]
	# the overhaul on saddle B; overhauled, it slides back to A as the spare
	if slot.B == "worn" and on:
		wear = maxf(0.0, wear - dt / OVERHAUL_S)
		if wear <= 0.0 and t_pod == "" and steps.is_empty():
			slot.B = "spare"
			steps = [["tx", SLOT_B], ["take", "B"], ["tx", SLOT_A], ["put", "A"]]
	# the mouth: the door open while a hulk lies in it
	mouth_door = move_toward(mouth_door, 1.0 if not hulk.is_empty() and bool(hulk.inside) else 0.0, dt * 0.35)
	# the tank: the hulk's draw-off in, a tug's refuel out
	var feeding := fuel_tug >= 0 and fuel_left > 0.0 and float(arm[fuel_tug]) > 0.98 and on
	if feeding:
		var q := minf(fuel_left, dt * 0.02)
		fuel_left -= q
		TugYard.set_tank(TugYard.tank() - q)
		if fuel_left <= 0.0:
			fuel_left = 0.0
			fuel_tug = -1
	var drawing := hose > 0.98 and drain < 1.0 and on and not hulk.is_empty() and not bool(hulk.get("done", false))
	# the draw-off runs from the moment the hose is on, alongside the frame and the scan
	if drawing:
		drain = move_toward(drain, 1.0, dt / DRAIN_S)
	pump = move_toward(pump, 1.0 if feeding or drawing else 0.0, dt * 0.8)
	tank_show = lerpf(tank_show, TugYard.tank() + (_drain_m3() * drain if drawing else 0.0), 1.0 - exp(-dt * 1.5))
	_sounds()


# the moments a machine makes its sound: the hoist's brake as it stops, the clamps landing, the
# hose coupling, a hatch starting to open, a door or the gate closing home
static func _sounds() -> void:
	var now := {"hook": vh != 0.0, "arms": arms > 0.999, "hose": hose > 0.999, "hatch0": float(hatch[0]) > 0.01, "hatch1": float(hatch[1]) > 0.01,
		"gate": gate > 0.999 or gate < 0.001, "door": mouth_door > 0.999 or mouth_door < 0.001, "lift0": float(vlift[0]) != 0.0, "lift1": float(vlift[1]) != 0.0}
	if not _was.is_empty():
		if bool(_was.hook) and not now.hook:
			events.append(["winch_brake", Vector2(x, hook)])
		if now.arms and not bool(_was.arms):
			events.append(["clamp", Vector2(2.0, MOUTH.x + 1.0)])
		if now.hose and not bool(_was.hose):
			events.append(["hose_on", Vector2(stern_x(), hull_bot())])
		for i in 2:
			if bool(now["hatch%d" % i]) and not bool(_was["hatch%d" % i]):
				events.append(["hatch", Vector2(lift_x(i), DECK_Y)])
			if bool(_was["lift%d" % i]) and not bool(now["lift%d" % i]):
				events.append(["winch_brake", Vector2(lift_x(i), float(lift[i]))])
		if now.gate and not bool(_was.gate):
			events.append(["roll_lock", Vector2(0.5, GATE.y)])
		if now.door and not bool(_was.door):
			events.append(["roll_lock", Vector2(0.5, MOUTH.y)])
	_was = now
	if events.size() > 16:
		events = events.slice(events.size() - 16)


# how hard the station's motors run now, 0 … 1 (the crane loop's level)
static func motor() -> float:
	var k := maxf(absf(vx) / V_X, absf(vh) / V_H * 0.8)
	for i in 2:
		k = maxf(k, absf(float(vlift[i])) / V_L * 0.7)
	return clampf(maxf(k, absf(vt) / V_T * 0.5), 0.0, 1.0)


# what the hose is drawing off the hulk in all (shown rising in the tank as it goes)
static func _drain_m3() -> float:
	return float(hulk.get("fuel", 0.0)) * TugYard.drain_share() if not hulk.is_empty() else 0.0


# the hulk in the mouth, from the yard's berth 1
static func _watch_hulk(dt: float) -> void:
	var a: Dictionary = _docked
	# still being brought in on camera: not in the mouth yet
	if not a.is_empty() and not bool(a.get("seen_in", true)):
		a = {}
	if a.is_empty():
		if not hulk.is_empty():
			# pushed out to the berth: the frame went with it, a new one stands ready
			hulk = {}
			prep_steps = []
			prep_id = ""
			if on_hook == "":
				frame_on = "stand"
		arms = move_toward(arms, 0.0, dt * 0.5)
		hose = move_toward(hose, 0.0, dt * 0.5)
		drain = 0.0
		return
	if not hulk.is_empty() and str(hulk.id) == str(a.id):
		hulk.in_hand = str(a.get("state", "")) == "stripping"
		return
	var ship := TugYard.ship_of(a)
	var d := Ship.load_data(ship)
	var bb := Rect2()
	var first := true
	for pd in d.get("pieces", []):
		for q in pd.get("poly", []):
			var v := Vector2(float(q[0]), float(q[1]))
			if first:
				bb = Rect2(v, Vector2.ZERO)
				first = false
			else:
				bb = bb.expand(v)
	var depth := TugYard.dock_in(ship)
	hulk = {"id": str(a.id), "ship": ship, "stern": depth, "cy": (MOUTH.x + MOUTH.y) * 0.5, "h": bb.size.y,
		"len": bb.size.x, "inside": depth > 0.0, "done": a.has("prep"), "fuel": TugYard.fuel_of(ship),
		"in_hand": str(a.get("state", "")) == "stripping"}
	if a.has("prep"):
		# pre-processed before (a game loaded): it lies as it was left
		arms = 1.0
		drain = 1.0
		prep_id = str(a.id)
		frame_on = "hulk" if depth > 0.0 else "stand"


static func stern_x() -> float:
	return float(hulk.get("stern", 0.0))


static func hull_top() -> float:
	return float(hulk.get("cy", 19.6)) - float(hulk.get("h", 10.0)) * 0.5


static func hull_bot() -> float:
	return float(hulk.get("cy", 19.6)) + float(hulk.get("h", 10.0)) * 0.5


# Q12 B: moored, drawn off, the push frame on its stern, the hull scanned
static func _prep() -> void:
	prep_id = str(hulk.id)
	var sx := stern_x()
	var inside := bool(hulk.inside)
	var carry := minf(hull_top() - FRAME_H - 0.8, 8.4)
	prep_steps = [["wait", 1.2], ["arms", 1.0], ["hose", 1.0]]
	if inside:
		prep_steps += [
			["x", FRAME_STAND.x], ["hook", FRAME_STAND.y - FRAME_H], ["wait", 0.5], ["pick_frame", 0],
			["hook", carry], ["x", sx + 1.2], ["hook", float(hulk.cy) - FRAME_H * 0.5], ["wait", 0.6], ["set_frame", 0],
			["hook", HOOK_PARK], ["scan", 1.0], ["x", maxf(LEGS.x + 1.4, sx - float(hulk.len) + 1.0)], ["x", sx - 0.5], ["scan", 0.0],
		]
	else:
		prep_steps += [["scan", 1.0], ["x", LEGS.x + 1.6], ["wait", 2.5], ["scan", 0.0]]
	prep_steps += [["drain", 1.0], ["drained", 0], ["hose", 0.0], ["x", PARK_X], ["prep_done", 0]]


# the steps of one pod swap for tug i: the lift up through the hatch under its aft pod, the worn
# pod down to the table and slid to the overhaul saddle, the spare slid onto the lift and up
static func _swap(i: int) -> void:
	job_tug = i
	var lx := lift_x(i)
	steps = [
		["hatch", i, 1.0], ["lift", i, POD_ON_TUG], ["wait", 0.6], ["unfit", i], ["lift", i, TABLE_Y],
		["tx", lx], ["take_lift", i], ["tx", SLOT_B], ["put", "B"],
		["tx", SLOT_A], ["take", "A"], ["tx", lx], ["put_lift", i],
		["lift", i, POD_ON_TUG], ["wait", 0.6], ["fit", i], ["lift", i, TABLE_Y], ["hatch", i, 0.0],
		["tx", SLOT_A], ["done", 0],
	]


static func _run(list: Array, dt: float, deck: bool) -> void:
	var guard := 0
	while not list.is_empty() and guard < 10:
		guard += 1
		var s: Array = list[0]
		var k: String = s[0]
		var go := k.begins_with("~")
		var a := k.trim_prefix("~")
		var hold := false
		match a:
			"x": x_to = float(s[1])
			"hook": hook_to = float(s[1])
			"tx": tx_to = float(s[1])
			"lift": lift_to[int(s[1])] = float(s[2])
			"hatch":
				hatch[int(s[1])] = move_toward(float(hatch[int(s[1])]), float(s[2]), dt * 0.8)
				hold = absf(float(hatch[int(s[1])]) - float(s[2])) > 0.001
			"arms":
				arms = move_toward(arms, float(s[1]), dt * 0.5)
				hold = absf(arms - float(s[1])) > 0.001
			"hose":
				hose = move_toward(hose, float(s[1]), dt * 0.45)
				hold = absf(hose - float(s[1])) > 0.001
			"drain":
				hold = drain < 1.0
			"scan":
				scan = move_toward(scan, float(s[1]), dt * 2.0)
				hold = absf(scan - float(s[1])) > 0.001
			"wait":
				var wv := wait if deck else wait2
				if wv <= 0.0:
					wv = float(s[1])
				wv -= dt
				if deck:
					wait = maxf(wv, 0.0)
				else:
					wait2 = maxf(wv, 0.0)
				if wv > 0.0:
					return
			"unfit":
				tug_pod[int(s[1])] = false
				lift_pod[int(s[1])] = "worn"
			"fit":
				tug_pod[int(s[1])] = true
				lift_pod[int(s[1])] = ""
			"take_lift":
				t_pod = str(lift_pod[int(s[1])])
				lift_pod[int(s[1])] = ""
			"put_lift":
				lift_pod[int(s[1])] = t_pod
				t_pod = ""
			"take":
				t_pod = str(slot[str(s[1])])
				slot[str(s[1])] = ""
			"put":
				slot[str(s[1])] = t_pod
				if str(s[1]) == "B" and t_pod == "worn":
					wear = 1.0
				t_pod = ""
			"done":
				job_tug = -1
				lifts += 1
			"pick_frame":
				on_hook = "frame"
				frame_on = "hook"
			"set_frame":
				on_hook = ""
				frame_on = "hulk"
			"drained":
				var asset := ShipMarket.asset(str(hulk.get("id", "")))
				TugYard.prepped(asset, TugYard.drain_share())
				Career.save()
			"prep_done":
				hulk.done = true
				preps += 1
		if hold or (not go and not _reached(a, s)):
			return
		list.pop_front()


static func _reached(a: String, s: Array) -> bool:
	match a:
		"x": return x == x_to and vx == 0.0
		"hook": return hook == hook_to and vh == 0.0
		"tx": return tx == tx_to and vt == 0.0
		"lift": return float(lift[int(s[1])]) == float(lift_to[int(s[1])]) and float(vlift[int(s[1])]) == 0.0
	return true


# ---------------------------------------------------------------- what each machine says it is doing
# [state line, lamp: "ok" / "work" / "off" / "warn"]
static func gantry_state() -> Array:
	if not powered():
		return [w("断电 · 拖船站未修复", "NO POWER · STATION NOT MENDED"), "off"]
	if on_hook == "frame":
		return [w("吊运推船夹具", "CARRYING THE PUSH FRAME"), "work"]
	if scan > 0.5:
		return [w("扫描船体", "SCANNING THE HULL"), "work"]
	if not prep_steps.is_empty():
		return [w("进港处理中", "PRE-PROCESSING"), "work"]
	return [w("待命", "STANDBY"), "ok"]


static func mouth_state() -> Array:
	if hulk.is_empty():
		return [w("空 · 下一艘拖回来的船停这里", "EMPTY · THE NEXT HULK LIES HERE"), "off" if not powered() else "ok"]
	var n := str(hulk.id)
	if not powered():
		return [w("%s · 没电，不能处理", "%s · NO POWER") % n, "warn"]
	if bool(hulk.get("done", false)) or bool(hulk.get("in_hand", false)):
		if bool(hulk.get("in_hand", false)):
			return [w("%s · 已接单 · 按 B 打开终端开工", "%s · TAKEN · B, THEN START IT") % n, "work"]
		return [w("%s · 已处理 · 开工就推去船坞", "%s · READY · START IT TO PUSH IT IN") % n, "ok"]
	if hose > 0.98 and drain < 1.0:
		return [w("%s · 抽推进剂 %d%%", "%s · DRAWING OFF %d%%") % [n, int(drain * 100.0)], "work"]
	return [w("%s · 系泊、装夹具、扫描", "%s · MOORING, FRAME, SCAN") % n, "work"]


static func table_state() -> Array:
	if slot.B == "worn":
		if not powered():
			return [w("旧吊舱待检修 · 没电", "WORN POD · NO POWER"), "warn"]
		return [w("检修旧吊舱 %d%%", "OVERHAUL %d%%") % int(round((1.0 - wear) * 100.0)), "work"]
	if job_tug >= 0:
		return [w("给 %s 换吊舱", "SWAPPING %s'S POD") % TugFleet.NAMES[job_tug], "work"]
	if slot.A == "spare":
		return [w("备用吊舱 · 就绪", "SPARE POD · READY"), "ok"]
	return [w("没有备用吊舱", "NO SPARE POD"), "warn"]


static func tank_state() -> Array:
	var s := "%.2f / %.0f m³" % [tank_show, TugYard.TANK_M3]
	if not powered():
		return [w("%s · 泵停", "%s · PUMP OFF") % s, "off"]
	if hose > 0.98 and drain < 1.0 and not hulk.is_empty():
		return [w("%s · 从废船抽料", "%s · FROM THE HULK") % s, "work"]
	if fuel_tug >= 0 and fuel_left > 0.0:
		return [w("%s · 加注 %s", "%s · FUELLING %s") % [s, TugFleet.NAMES[fuel_tug]], "work"]
	if TugYard.tank() <= 0.01:
		return [w("空 · 拖回的船进港时抽料", "EMPTY · FILLED FROM THE HULKS"), "warn"]
	return [s, "ok"]


static func berth_state(i: int) -> Array:
	if i >= count_now:
		return [w("空泊位 · 扩建拖船站加一艘拖船", "FREE · BUILD ON FOR ANOTHER TUG"), "off"]
	var n: String = TugFleet.NAMES[i]
	if not bool(home_now[i]):
		return [w("%s 出航中", "%s AWAY") % n, "off"]
	if float(dock[i]) < 0.999:
		return [w("%s 进站中", "%s COMING IN") % n, "work"]
	if job_tug == i:
		return [w("%s 换推进器吊舱", "%s POD SWAP") % n, "work"]
	var c := TugYard.charge(n)
	if c < 1.0:
		return [w("%s 充电 %d%%", "%s CHARGING %d%%") % [n, int(c * 100.0)], "work"]
	return [w("%s 待命 · 满电", "%s READY") % n, "ok"]
