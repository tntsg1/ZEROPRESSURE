extends RefCounted
# 102 号 (user 2026-10-28: "继续做仓库"): what the cargo district's machines are doing now, run from
# the warehouse's real jobs (scripts/warehouse.gd) and the stacker's real lifts (district_interiors
# haul) — nothing new saved (as scripts/tug_works.gd, process_works.gd). Each forklift is a reach
# truck on the floor: it drives from the hatch to under its row, its mast telescopes the forks up
# to the shelf, it reaches in, sets down or picks, lowers and backs home — every axis an actuator
# chasing its target, speeding up and braking in time. The stacker crane overhead chases the pose
# the district gives it, its load swinging. The hatch's lift rises with the goods whenever a truck
# hands over at it. Drawing: scripts/cargo_art.gd. Box-local metres (60 × 28, floor at 26.8).

const FLOOR := 26.8
const HATCH_X := 30.0
const PARK := [25.5, 34.5]    # where each forklift waits, either side of the hatch
const BEAM_DROP := 0.2        # the forks this far under the beam's top to pick or set
const V_DRIVE := 4.0          # m/s a truck drives, m/s² it speeds up (× the warehouse's speed and power)
const A_DRIVE := 2.2
const V_LIFT := 4.2           # the mast
const A_LIFT := 3.2
const V_CRANE := 3.6
const A_CRANE := 1.4
const V_HOOK := 2.6
const A_HOOK := 2.4
const FORK_REST := FLOOR - 0.25   # the forks down on the floor

# each truck: {x, vx, fork (fork height, y), vf, reach 0 … 1, face ±1, load key, job id, wheel, beacon}
static var trucks: Array = []
# the overhead stacker crane
static var cx := 9.0
static var vcx := 0.0
static var hook := 3.4
static var vhook := 0.0
static var sway := 0.0
static var vsway := 0.0
static var crane_load := ""
# the hatch's lift: 0 down below the floor … 1 up level with it
static var lift := 0.0
static var vlift := 0.0
static var doors := 0.0       # 0 shut … 1 open
static var vdoors := 0.0
static var rollers := 0.0
static var t := 0.0
static var busy_rows := {}    # row -> true while a truck is at it (its lamp)
static var events: Array = []


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


static func reset() -> void:
	trucks.clear()
	cx = 9.0
	vcx = 0.0
	hook = 3.4
	vhook = 0.0
	sway = 0.0
	vsway = 0.0
	crane_load = ""
	lift = 0.0
	doors = 0.0
	events.clear()


static func _drive(cur: float, vel: float, to: float, vmax: float, acc: float, dt: float) -> Array:
	var d := to - cur
	var want := clampf(sqrt(2.0 * acc * absf(d)) * signf(d), -vmax, vmax)
	vel = move_toward(vel, want, acc * 2.0 * dt)
	var nxt := cur + vel * dt
	if signf(to - nxt) != signf(d) or absf(to - nxt) < 0.002:
		return [to, 0.0]
	return [nxt, vel]


# where a row's goods are set: under its slot, the forks at the beam
static func slot_x(row: int, fi: int) -> float:
	var at: Vector2 = Warehouse.ROW_AT[row]
	# the forks reach towards the rack's middle: a left bank's truck stands right of its slot
	return at.x + (5.2 if row < 4 else 0.8) + fi * 3.0


static func beam_y(row: int) -> float:
	return float((Warehouse.ROW_AT[row] as Vector2).y)


# what a truck should be doing at this point of its job: [x, fork y, reach, loaded]
static func _pose(j: Dictionary, fi: int) -> Array:
	var row := int(j.row)
	var total := maxf(0.01, float(j.total))
	var pr := clampf(1.0 - float(j.left) / total, 0.0, 1.0)
	var home := HATCH_X + (-1.5 if fi == 0 else 1.5)
	var sx := slot_x(row, fi)
	var top := beam_y(row) - BEAM_DROP
	var carry_in := str(j.dir) in ["in", "store"]
	# out, lift, reach and set or pick, lower, back
	if pr < 0.3:
		return [home if pr < 0.04 else sx, FORK_REST, 0.0, carry_in]
	if pr < 0.47:
		return [sx, top, 0.0, carry_in]
	if pr < 0.55:
		var k := (pr - 0.47) / 0.08
		var reach := sin(k * PI)
		return [sx, top - (0.15 if (k > 0.5) != carry_in else 0.0), reach, carry_in if k < 0.5 else not carry_in]
	if pr < 0.72:
		return [sx, FORK_REST, 0.0, not carry_in]
	return [home, FORK_REST, 0.0, not carry_in]


static var _k := 1.0
static var _k_t := 0.0


static func tick(game, dt: float, crane_target: Dictionary) -> void:
	t += dt
	# what the grid gives the trucks: asked twice a second (it walks the whole grid)
	_k_t -= dt
	if _k_t <= 0.0:
		_k_t = 0.5
		_k = Warehouse.k(game) if game != null else 1.0
	var jobs: Array = Warehouse.data().jobs if not Career.data.is_empty() else []
	var n := Warehouse.forklifts() if not Career.data.is_empty() else 1
	while trucks.size() < n:
		var i := trucks.size()
		trucks.append({"x": PARK[i % 2], "vx": 0.0, "fork": FORK_REST, "vf": 0.0, "reach": 0.0, "face": -1.0 if i % 2 == 0 else 1.0, "load": "", "job": "", "wheel": 0.0, "beacon": 0.0})
	if trucks.size() > n:
		trucks.resize(n)
	busy_rows = {}
	var at_hatch := false
	for i in trucks.size():
		var tr: Dictionary = trucks[i]
		var target_x: float = PARK[i % 2]
		var target_f := FORK_REST
		var reach := 0.0
		var load := ""
		if i < jobs.size():
			var j: Dictionary = jobs[i]
			var p := _pose(j, i)
			# the mast stays down until the truck stands under the row, and the truck stays until it is down
			target_x = p[0]
			target_f = p[1]
			reach = p[2]
			load = str(j.key) if bool(p[3]) else ""
			tr.job = str(j.id)
			tr.face = signf(slot_x(int(j.row), i) - HATCH_X)
			if absf(float(tr.x) - slot_x(int(j.row), i)) < 0.3:
				busy_rows[int(j.row)] = true
			if absf(float(tr.x) - (HATCH_X + (-1.5 if i == 0 else 1.5))) < 1.2:
				at_hatch = true
		else:
			tr.job = ""
		if absf(float(tr.fork) - FORK_REST) > 0.05 and absf(float(tr.x) - target_x) > 0.01:
			target_x = float(tr.x)
		if absf(float(tr.x) - target_x) > 0.05:
			target_f = FORK_REST
		var pace := Warehouse.speed() / Warehouse.SPEED * _k
		var r := _drive(float(tr.x), float(tr.vx), target_x, V_DRIVE * pace, A_DRIVE, dt)
		tr.x = r[0]
		tr.vx = r[1]
		var r2 := _drive(float(tr.fork), float(tr.vf), target_f, V_LIFT * pace, A_LIFT, dt)
		tr.fork = r2[0]
		tr.vf = r2[1]
		tr.reach = move_toward(float(tr.reach), reach, dt * 3.0)
		if str(tr.load) != load and load == "":
			events.append(["clamp", Vector2(float(tr.x), float(tr.fork))])
		tr.load = load
		tr.wheel = float(tr.wheel) + float(tr.vx) * dt / 0.3
		if absf(float(tr.vx)) > 0.05 or absf(float(tr.vf)) > 0.05:
			tr.beacon = float(tr.beacon) + dt * 6.0
	# the hatch's lift comes up when a truck stands at it
	var dr := _drive(doors, vdoors, 1.0 if at_hatch else (0.0 if lift < 0.05 else 1.0), 2.5, 8.0, dt)
	doors = dr[0]
	vdoors = dr[1]
	var lr := _drive(lift, vlift, 1.0 if at_hatch and doors > 0.95 else 0.0, 1.3, 2.6, dt)
	lift = lr[0]
	vlift = lr[1]
	# the stacker crane chases the pose the district gives it
	var was := vcx
	var rc := _drive(cx, vcx, float(crane_target.get("x", 9.0)), V_CRANE, A_CRANE, dt)
	cx = rc[0]
	vcx = rc[1]
	var rh := _drive(hook, vhook, float(crane_target.get("hook", 3.4)), V_HOOK, A_HOOK, dt)
	hook = rh[0]
	vhook = rh[1]
	crane_load = str(crane_target.get("key", "")) if bool(crane_target.get("load", false)) else ""
	var ax := (vcx - was) / maxf(dt, 1e-4)
	var length := maxf(0.8, hook - 2.2)
	vsway += (-9.8 / length * sin(sway) - ax / length * cos(sway) - 0.9 * vsway) * dt
	sway = clampf(sway + vsway * dt, -0.12, 0.12)
	var moving := not jobs.is_empty() or crane_load != ""
	rollers += (4.0 if moving else 0.0) * dt


static func truck_state(i: int) -> Array:
	if i >= trucks.size():
		return [w("未配备", "none"), ""]
	var jobs: Array = Warehouse.data().jobs
	if i >= jobs.size():
		return [w("待命", "standing by"), "ok"]
	var j: Dictionary = jobs[i]
	var verb := w("取出", "picking") if str(j.dir) in ["out", "pick"] else w("上架", "putting away")
	return [w("%s %s · %s · 剩 %d 秒", "%s %s · %s · %d s") % [verb, Warehouse.ROWS[int(j.row)], Ops.item_name(str(j.key)), ceili(float(j.left))], "work"]
