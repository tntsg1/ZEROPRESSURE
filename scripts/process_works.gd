extends RefCounted
# 101 号 (user 2026-10-28: "用拖船区、拆船区，还有无人机那种极高精度的，把加工区给做完了……很惊艳"):
# what the processing district's machines are doing now, run from the real state — the arc
# furnace's bunker, power, phase and electrodes (scripts/arc_furnace.gd), the rolling mill's pass
# (scripts/rolling_mill.gd) — nothing new saved (as scripts/tug_works.gd). Every machine is an
# actuator chasing a target: speeding up, braking in time, the crane's load swinging as it starts
# and stops. The hall crane brings the charging basket from its stand to the furnace's side chute
# while scrap waits in the bunker and takes it back empty; the reheating furnace holds the next
# billet and pushes it out onto the feed table as a pass begins; the descaler sprays the head;
# the transformer's fans and the baghouse's pulses follow the furnace's power. The sparks, smoke
# and steam are particles here. Drawing: scripts/process_art.gd. Box-local metres (60 × 28).

const FLOOR := 26.8
const RAIL_Y := 2.6           # the crane's ropes leave the trolley here
const STAND_X := 4.2          # the basket's stand, on the platform over the transformer
const STAND_LUG := 5.05       # the basket's lugs when it sits on the stand
const CHUTE_X := 19.0         # the furnace's side charging chute
const CHUTE_LUG := 9.55
const PARK_X := 9.5            # 128 号 第 4 段: parked over the gap between the basket's stand and the mast
# 128 号 第 4 段 (方案 A 改): the hall re-laid under the observation gallery. The furnace bay (the furnace,
# its line, the crane on its runway, the basket's stand, the mould rack) keeps its own metres and stands
# BAY_DY lower in the hall; the mill keeps its own and stands MILL_OFF over, under the freight spur.
# Everything here (the crane, the particles) is in the bay's own metres except the mill's (in its own).
const BAY_DY := 7.0
const MILL_OFF := Vector2(4.0, 13.0)
const HOOK_UP := 4.0          # the hook drawn up, empty
const CARRY := 4.6            # … carrying (the basket's bottom clears the line at 8 m)
const BASKET_H := 2.35        # m from the lugs to the basket's bottom
const V_X := 4.5              # m/s the crane travels, m/s² it accelerates
const A_X := 1.4
const V_H := 2.4
const A_H := 2.2
const DOOR_V := 1.6           # the reheating furnace's door, /s and /s²
const DOOR_A := 6.0

# 128 号 第 4 段 换模: the mould blocks (scripts/process_line.gd, scripts/cast_art.gd) — one in the seat under
# the tap hole, the others on the wall rack right of the line; the crane swaps them on a short spreader
const SEAT := Vector2(18.95, 16.15)      # the seated block's top-left
const SEAT_HOOK := 15.4                  # the hook over it (the spreader and slings take 0.75 m)
const RACK_X := [21.6, 23.9, 26.2]       # the rack's three slots, each block's left
const RACK_TOP := 12.9                   # a racked block's top
const RACK_HOOK := 12.15
const CARRY_M := 11.3                    # the hook while a block is carried over the others
const CLEAR_M := 11.9                    # the bare spreader over the racked blocks' lugs
const V_XM := 11.0                       # m/s, m/s² the crane travels and hoists on a mould change (≤ 10 s in all)
const A_XM := 10.0
const V_HM := 10.0
const A_HM := 13.0
static var seat_m := "billet"            # what is in the seat, on the hook, in each rack slot (drawn)
static var hook_m := ""
static var rack_m: Array = ["slab", "small", ""]
static var _m_from := -1                 # the rack slot the new block comes from
static var _m_into := -1                 # the empty slot the old one goes into
# the crane
static var x := PARK_X
static var vx := 0.0
static var x_to := PARK_X
static var hook := HOOK_UP
static var vh := 0.0
static var hook_to := HOOK_UP
static var sway := 0.0        # rad, the load's swing
static var vsway := 0.0
static var drum := 0.0        # rad, the hoist drum
static var wheel := 0.0       # rad, the end carriage's wheels
static var basket := "stand"  # "stand" on its stand, "hook" on the crane
static var basket_fill := 0.0 # what the basket holds, 0 … 1
static var step := "park"     # the crane's job step
static var step_t := 0.0
# the reheating furnace and the mill
static var door := 0.0        # 0 shut … 1 up
static var vdoor := 0.0
static var push := 0.0        # the pusher's ram, 0 back … 1 out
static var vpush := 0.0
static var spray := 0.0       # the descaler's sprays, 0 off … 1 full
static var rollers := 0.0     # rad, the table rollers
static var roll_v := 0.0      # rad/s now
# the furnace's helpers
static var fans := 0.0        # rad, the transformer's cooling fans
static var fan_v := 0.0
static var pulse := 0.0       # s into the baghouse's pulse cycle
static var valve := 0.0       # rad, the dust hopper's rotary valve
static var flick := 0.0       # the arcs' flicker now (the hall's light), 0 … 1
static var arc_k := 0.0       # how hard the arcs burn, 0 … 1
static var t := 0.0
# particles: [pos (box m), vel (m/s), life left (s), life (s), kind]
static var sparks: Array = []
static var smoke: Array = []
static var steam: Array = []
static var bits: Array = []   # scrap falling from the basket into the chute
static var events: Array = [] # [sound, box m] one-shots for the district to play
static var _spark_acc := 0.0
static var _smoke_acc := 0.0
static var _steam_acc := 0.0
static var _bit_acc := 0.0
static var _job_was := ""
static var rng := RandomNumberGenerator.new()


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


static func reset() -> void:
	x = PARK_X
	vx = 0.0
	x_to = PARK_X
	hook = HOOK_UP
	vh = 0.0
	hook_to = HOOK_UP
	sway = 0.0
	vsway = 0.0
	basket = "stand"
	basket_fill = 0.0
	step = "park"
	step_t = 0.0
	door = 0.0
	push = 0.0
	spray = 0.0
	sparks.clear()
	smoke.clear()
	steam.clear()
	bits.clear()
	events.clear()
	_job_was = ""
	rng.seed = 98


# the district's furnace (null outside a career's berth)
static func furnace(game):
	var p = game.get("plant") if game != null else null
	return p.smelter if p != null and is_instance_valid(p) else null


# box-local metres of the furnace's axis and its line's floor
static func furnace_x(game) -> float:
	var p = game.get("plant") if game != null else null
	return float(p.X) - PortStructure.box("process").position.x / Geom.M if p != null else 16.0


static func line_y(game) -> float:
	var p = game.get("plant") if game != null else null
	return float(p.F) - PortStructure.box("process").position.y / Geom.M - BAY_DY if p != null else 8.0


static func _drive(cur: float, vel: float, to: float, vmax: float, acc: float, dt: float) -> Array:
	var d := to - cur
	var want := clampf(sqrt(2.0 * acc * absf(d)) * signf(d), -vmax, vmax)
	vel = move_toward(vel, want, acc * 2.0 * dt)
	var nxt := cur + vel * dt
	if signf(to - nxt) != signf(d) or absf(to - nxt) < 0.002:
		return [to, 0.0]
	return [nxt, vel]


static func _at() -> bool:
	return x == x_to and hook == hook_to and vx == 0.0 and vh == 0.0


static func _go(s: String) -> void:
	step = s
	step_t = 0.0


# the crane's job: a list of steps, each setting targets and waiting for them
static func mould_step() -> bool:
	return step.begins_with("m_")


static func _crane(game, dt: float) -> void:
	var f = furnace(game)
	var want: bool = f != null and float(f.bunker) > 0.02 and Port.stage("process") >= 1
	step_t += dt
	if not mould_step() and not Career.data.is_empty():
		# between changes the blocks are where the books say
		seat_m = ProcessLine.line_mould()
		rack_m = ProcessLine.casting().get("rack", ["slab", "small", ""]).duplicate()
		hook_m = ""
	match step:
		"park":
			x_to = PARK_X
			hook_to = HOOK_UP
			if not want and ProcessLine.changing() and not Career.data.is_empty():
				_m_into = rack_m.find("")
				_m_from = rack_m.find(ProcessLine.change_to())
				if _m_into >= 0 and _m_from >= 0:
					_go("m_go_seat")
			elif want and _at():
				_go("to_stand")
		# ---- 换模: seat → empty slot, the wanted block → seat
		"m_go_seat":
			x_to = SEAT.x + 1.1
			hook_to = CARRY_M
			if absf(x - x_to) < 0.3:
				_go("m_down_seat")
		"m_down_seat":
			hook_to = SEAT_HOOK
			if _at():
				_go("m_latch_seat")
		"m_latch_seat":
			if step_t > 0.25:
				hook_m = seat_m
				seat_m = ""
				events.append(["clamp", Vector2(SEAT.x + 1.1, SEAT.y) + Vector2(0.0, BAY_DY)])
				_go("m_up1")
		"m_up1":
			hook_to = CARRY_M
			if hook < CARRY_M + 1.2:
				x_to = float(RACK_X[_m_into]) + 1.1
			if _at():
				_go("m_down_rack")
		"m_down_rack":
			hook_to = RACK_HOOK
			if _at():
				_go("m_rel1")
		"m_rel1":
			if step_t > 0.2:
				rack_m[_m_into] = hook_m
				hook_m = ""
				events.append(["clank", Vector2(float(RACK_X[_m_into]) + 1.1, RACK_TOP + 0.8) + Vector2(0.0, BAY_DY)])
				_go("m_up2")
		"m_up2":
			hook_to = CLEAR_M
			if hook < CLEAR_M + 0.3:
				x_to = float(RACK_X[_m_from]) + 1.1
			if _at():
				_go("m_down_new")
		"m_down_new":
			hook_to = RACK_HOOK
			if _at():
				_go("m_latch_new")
		"m_latch_new":
			if step_t > 0.25:
				hook_m = str(rack_m[_m_from])
				rack_m[_m_from] = ""
				events.append(["clamp", Vector2(float(RACK_X[_m_from]) + 1.1, RACK_TOP) + Vector2(0.0, BAY_DY)])
				_go("m_up3")
		"m_up3":
			hook_to = CARRY_M
			if hook < CARRY_M + 1.2:
				x_to = SEAT.x + 1.1
			if _at():
				_go("m_down_seat2")
		"m_down_seat2":
			hook_to = SEAT_HOOK
			if _at():
				_go("m_rel2")
		"m_rel2":
			if step_t > 0.2:
				seat_m = hook_m
				hook_m = ""
				events.append(["clank", Vector2(SEAT.x + 1.1, SEAT.y + 0.8) + Vector2(0.0, BAY_DY)])
				ProcessLine.crane_done = true
				_go("m_home")
		"m_home":
			hook_to = HOOK_UP
			if hook < CARRY_M:
				x_to = PARK_X
			if _at():
				_go("park")
		"to_stand":
			hook_to = HOOK_UP
			if hook == HOOK_UP:
				x_to = STAND_X
			if _at():
				_go("pick")
		"pick":
			hook_to = STAND_LUG
			if _at():
				_go("latch")
		"latch":
			if step_t > 0.6:
				basket = "hook"
				basket_fill = 1.0
				events.append(["clamp", Vector2(STAND_X, STAND_LUG) + Vector2(0.0, BAY_DY)])
				_go("lift")
		"lift":
			hook_to = CARRY
			if _at():
				_go("to_chute")
		"to_chute":
			x_to = CHUTE_X
			if _at():
				_go("lower")
		"lower":
			hook_to = CHUTE_LUG
			if _at():
				_go("charge")
		"charge":
			# the basket empties as the bunker does (what is left in it is what still waits)
			if f != null:
				basket_fill = clampf(float(f.fill()) * 2.5, 0.0, 1.0) if want else 0.0
			if not want and step_t > 1.0:
				basket_fill = 0.0
				_go("raise")
		"raise":
			hook_to = CARRY
			if _at():
				_go("back")
		"back":
			x_to = STAND_X
			if _at():
				_go("set")
		"set":
			hook_to = STAND_LUG
			if _at():
				_go("release")
		"release":
			if step_t > 0.5:
				basket = "stand"
				events.append(["clank", Vector2(STAND_X, STAND_LUG + BASKET_H) + Vector2(0.0, BAY_DY)])
				_go("home")
		"home":
			hook_to = HOOK_UP
			if hook == HOOK_UP:
				x_to = PARK_X
			if _at():
				_go("park")
	var was := vx
	var fast := mould_step()
	var r := _drive(x, vx, x_to, V_XM if fast else V_X, A_XM if fast else A_X, dt)
	x = r[0]
	vx = r[1]
	var r2 := _drive(hook, vh, hook_to, V_HM if fast else V_H, A_HM if fast else A_H, dt)
	hook = r2[0]
	vh = r2[1]
	wheel += vx * dt / 0.35
	drum += vh * dt / 0.45
	# the load on its ropes: a damped pendulum the trolley's acceleration swings
	var ax := (vx - was) / maxf(dt, 1e-4)
	var length := maxf(0.8, hook - RAIL_Y + (1.2 if basket == "hook" or hook_m != "" else 0.4))
	vsway += (-9.8 / length * sin(sway) - ax / length * cos(sway) - 0.9 * vsway) * dt
	sway = clampf(sway + vsway * dt, -0.12, 0.12)


static func tick(game, dt: float) -> void:
	t += dt
	var f = furnace(game)
	_crane(game, dt)
	preload("res://scripts/bale_press.gd").tick(dt)
	# the furnace's arcs and its helpers
	var on: bool = Port.stage("process") >= 1
	var arcs: bool = f != null and float(f.power) > 0.5 and str(f.phase) not in ["tilt", "pour", "back"]
	arc_k = move_toward(arc_k, clampf(float(f.power) / 24.0, 0.0, 1.0) if arcs else 0.0, dt * 3.0)
	flick = clampf(0.55 + 0.45 * sin(t * 37.0) * sin(t * 13.0 + 1.0) + rng.randf_range(-0.15, 0.15), 0.0, 1.0)
	fan_v = move_toward(fan_v, (4.0 + 18.0 * arc_k) if on else 0.0, dt * 6.0)
	fans += fan_v * dt
	if arc_k > 0.05:
		pulse += dt
	valve += (1.2 if arc_k > 0.05 else 0.0) * dt
	var fx := furnace_x(game)
	var ly := line_y(game)
	if f != null:
		# sparks blown out of the electrode ports with the arcs, smoke rising to the hood
		_spark_acc += dt * 70.0 * arc_k
		while _spark_acc >= 1.0:
			_spark_acc -= 1.0
			var ex := fx - 0.7 + 0.7 * rng.randi_range(0, 2)
			var at := Vector2(ex + rng.randf_range(-0.25, 0.25), ly + 2.65 + 3.4)
			sparks.append([at, Vector2(rng.randf_range(-3.5, 3.5), rng.randf_range(-6.5, -2.0)), rng.randf_range(0.4, 1.0), 1.0, 0])
		_smoke_acc += dt * 9.0 * arc_k
		while _smoke_acc >= 1.0:
			_smoke_acc -= 1.0
			smoke.append([Vector2(fx + rng.randf_range(-1.8, 1.8), ly + 2.65 + 3.2), Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-2.2, -1.4)), 3.0, 3.0, rng.randf_range(0.5, 1.0)])
		# the tap: sparks off the stream where it lands
		if str(f.phase) == "pour" and float(f.gate) > 0.2:
			for k in 2:
				var land := Vector2(fx + 2.65, ly + 2.65 + 5.5)
				sparks.append([land, Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-4.5, -1.5)), rng.randf_range(0.3, 0.7), 0.7, 1])
		# scrap falling from the basket into the chute while it charges
		if step == "charge" and float(f.feed) > 0.0005:
			_bit_acc += dt * 6.0
			while _bit_acc >= 1.0:
				_bit_acc -= 1.0
				bits.append([Vector2(CHUTE_X + rng.randf_range(-0.6, 0.6), CHUTE_LUG + BASKET_H), Vector2(rng.randf_range(-0.3, 0.3), 1.0), 0.8, 0.8, rng.randf_range(0.0, TAU)])
	# the mill: the reheating furnace's door and pusher, the descaler, the tables' rollers
	var j := Mill.job()
	var state := str(j.get("state", "")) if not j.is_empty() else ""
	var p := Mill.progress()
	var door_to := 0.0
	var push_to := 0.0
	if state == "roll" and p < 0.12:
		door_to = 1.0
		push_to = 1.0 if door > 0.85 else 0.0
	if state == "roll" and _job_was != "roll":
		events.append(["door", Vector2(41.0, 9.0) + MILL_OFF])
	_job_was = state
	var rd := _drive(door, vdoor, door_to, DOOR_V, DOOR_A, dt)
	door = rd[0]
	vdoor = rd[1]
	var rp := _drive(push, vpush, push_to if push_to > 0.0 or door > 0.2 else 0.0, 1.4, 4.0, dt)
	push = rp[0]
	vpush = rp[1]
	var mk := Mill.k(game) if state == "roll" else 0.0
	roll_v = move_toward(roll_v, 7.0 * mk, dt * 8.0)
	rollers += roll_v * dt
	# the descaler sprays as the head comes up to the stand, steam off the hot steel
	var head := lerpf(43.4 + 2.4, 55.4 - 0.3, p)
	var spray_to := 1.0 if state == "roll" and head > 45.6 and head < 48.6 else 0.0
	if spray_to > 0.5 and spray < 0.5:
		events.append(["hiss", Vector2(46.9, 9.4) + MILL_OFF])
	spray = move_toward(spray, spray_to, dt * 5.0)
	_steam_acc += dt * (22.0 * spray + (3.0 if state == "roll" else 0.0))
	while _steam_acc >= 1.0:
		_steam_acc -= 1.0
		var sx := 46.9 + rng.randf_range(-0.5, 0.5) if spray > 0.1 else clampf(head - rng.randf_range(0.0, 3.0), 47.6, 55.0)
		steam.append([Vector2(sx, 9.2), Vector2(rng.randf_range(-0.4, 0.4), rng.randf_range(-1.8, -0.8)), 1.6, 1.6, rng.randf_range(0.5, 1.0)])
	_particles(sparks, dt, 9.8, 0.0)
	_particles(smoke, dt, -0.4, 0.4)
	_particles(steam, dt, -0.3, 0.8)
	_particles(bits, dt, 9.8, 0.0)
	# the bits stop at the chute's mouth
	for b in bits:
		if (b[0] as Vector2).y > CHUTE_LUG + BASKET_H + 1.4:
			b[2] = 0.0


static func _particles(list: Array, dt: float, g: float, drag: float) -> void:
	var i := list.size() - 1
	while i >= 0:
		var pt: Array = list[i]
		pt[2] = float(pt[2]) - dt
		if float(pt[2]) <= 0.0:
			list.remove_at(i)
		else:
			var v: Vector2 = pt[1]
			v.y += g * dt
			v *= 1.0 - drag * dt
			pt[1] = v
			pt[0] = (pt[0] as Vector2) + v * dt
		i -= 1
	if list.size() > 260:
		list.resize(260)


# ---------------------------------------------------------------- what each machine is doing (plates, cards)
static func crane_state() -> Array:
	if mould_step():
		return [w("换模中", "changing the mould"), "work"]
	match step:
		"park": return [w("停车位待命", "parked"), "ok"]
		"to_stand", "pick", "latch": return [w("去取料篮", "fetching the basket"), "work"]
		"lift", "to_chute", "lower": return [w("吊料篮去电弧炉", "basket to the furnace"), "work"]
		"charge": return [w("加料中 %d%%" % int(basket_fill * 100.0), "charging %d%%" % int(basket_fill * 100.0)), "work"]
		_: return [w("送回空料篮", "basket back"), "work"]


static func furnace_state(game) -> Array:
	var f = furnace(game)
	if f == null or Port.stage("process") < 1:
		return [w("未通电", "no power"), ""]
	match str(f.phase):
		"tilt": return [w("倾炉出钢", "tilting to tap"), "work"]
		"pour": return [w("出钢 %d °C" % int(f.T), "tapping %d °C" % int(f.T)), "work"]
		"back": return [w("回位", "back level"), "work"]
		"heat": return [w("升温 %d °C" % int(f.T), "heating %d °C" % int(f.T)), "work"]
	if float(f.power) > 0.5:
		return [w("通电熔化 %.0f MW" % float(f.power), "melting %.0f MW" % float(f.power)), "work"]
	# 125 号 (user: "画面显示空炉时，引导不能让我以为炉里有料"): the label says what is in it
	if float(f.m_s) + float(f.bunker) > 0.001:
		if float(f.manual_power) < 0.5:
			return [w("有料 · 等按『通电熔化』", "CHARGED · PRESS STRIKE THE ARCS"), "warn"]
		return [w("有料未加热 %d °C · 没分到电", "CHARGED, NOT HEATING %d °C · NO POWER") % int(f.T), "warn"]
	if float(f.m_l) > 0.05:
		return [w("保温 %d °C", "holding %d °C") % int(f.T), "ok"]
	for ig in f.ingots:
		if float(ig[1]) > 200.0:
			return [w("空炉 · 钢坯冷却中", "EMPTY · BILLETS COOLING"), "ok"]
	return [w("空炉", "empty"), "ok"]


static func mill_state() -> Array:
	var j := Mill.job()
	if j.is_empty():
		return [w("待料", "waiting"), "ok"] if Port.stage("process") >= 1 else [w("未通电", "no power"), ""]
	if str(j.state) == "fetch":
		return [w("钢坯在加热炉", "billet heating"), "work"]
	return [w("轧制 %d%%" % int(Mill.progress() * 100.0), "rolling %d%%" % int(Mill.progress() * 100.0)), "work"]
