extends RefCounted
# 100 号 (user 2026-10-28: "动力区做一下", like the tug station and the trade port; Q1 C, Q2 C, Q3 A,
# Q4 A, Q5 B, Q6 A+C): what the power district's plant is doing now, run from the real grid (its
# loads, own generation and the shore line) — nothing about the grid's rules changes (Q3 A). The
# plant as three real loops, each machine with its own inertia:
#   primary:   the reactor → hot leg → steam generator → main coolant pump → cold leg; the
#              pressuriser holds the pressure. The rods step out as the load asks.
#   secondary: steam from the generators → the header → stop and governor valves → HP and LP
#              casings → the condenser → the feed pumps (two duty, one standby) → back.
#   heat:      the condenser's heat → the radiator pumps (duty and standby) → the radiators out on
#              the booms (in vacuum the only way out) → back.
# The turbine-generator's speed is a real swing: a load put on drops the frequency until the
# governor valve opens enough; the electricity out is what the loads take at once (Q6 A). Each
# feeder's breaker really closes when its district starts drawing; the shore line's umbilical
# swings out and plugs in on the roof while the port takes shore power (Q6 C). Stage 0: the
# reactors cold, the emergency fuel-cell set gives the 6 MW (Q4 A). Stage 2: the third unit (Q5 B).
# Now and then a duty pump is changed over or the governor valve sticks for a moment: shown and
# put right by the automatics, nothing about the grid changes (Q2 C). Box-local metres (60 × 28,
# floor at 26.8). Nothing here is saved.

const FLOOR := 26.8
const BAY_X := [1.2, 11.8, 22.4]        # the three reactor bays' left edges
const BAY_W := 10.0
const BAY_Y := Vector2(3.2, 17.6)       # the bays' top and bottom
const FEEDERS := ["gen", "shore", "base", "salvage", "process", "cargo", "tug"]
const GROUPS := ["base", "salvage", "process", "cargo", "tug"]
const ETA := 0.33                       # electricity out of the heat a reactor makes
const H := 5.0                          # s: the turbine-generator's inertia constant
const VALVE_RATE := 0.35                # the governor valve's stroke a second
const ROD_RATE := 0.035                 # rod travel a second (stepping drives)
const BREAKER_S := 0.14                 # a breaker's closing stroke
const HOLD_S := 3.0                     # a feeder stays closed this long after its last draw
const UMB_S := 6.0                      # the shore umbilical's swing out (or in)
const FAULT_EVERY := Vector2(150.0, 330.0)

static var stage := 0
static var cap := 6.0
static var own := 0.0                   # MW from the plant now (what the loads take of it)
static var shore := 0.0                 # MW over the shore line
static var groups := {}                 # group → MW now (for the feeders and the hub's cables)
static var units := 0                   # reactor units running (0 at stage 0)
static var hz := 0.0                    # the generator's frequency (rpm = 60 × hz)
static var valve := 0.0                 # governor valve 0 shut … 1 wide
static var p_mech := 0.0
static var rods := [0.0, 0.0, 0.0]      # withdrawn 0 … 1
static var q_th := [0.0, 0.0, 0.0]      # MWt each unit makes now
static var t_hot := [40.0, 40.0, 40.0]  # °C hot leg
static var t_cold := [40.0, 40.0, 40.0]
static var pzr := [0.0, 0.0, 0.0]       # pressuriser heaters 0 … 1 (they glow)
static var mcp := [0.0, 0.0, 0.0]       # main coolant pump speed 0 … 1
static var fw := [0.0, 0.0, 0.0]        # feed pumps' speed
static var fw_duty := [0, 1]            # which two feed pumps run
static var rp := [0.0, 0.0]             # radiator pumps' speed
static var rp_duty := 0
static var vib := [0.0, 0.0, 0.0]       # a feed pump shaking (a changeover on its way)
static var rp_vib := [0.0, 0.0]
static var t_cond := 30.0               # °C condenser
static var rad_t := 20.0                # °C the radiators (their glow outside)
static var fc := 0.0                    # the fuel-cell set's output MW
static var fc_fan := 0.0
static var breaker := {}                # feeder → 0 open … 1 closed (its stroke)
static var _want := {}                  # feeder → closed wanted
static var _last_draw := {}             # feeder → s since its last draw
static var umb := 0.0                   # the shore umbilical 0 stowed … 1 plugged in
static var _shore_t := 0.0              # s the shore line has drawn (or not)
static var fault := {}                  # {kind, t, unit, text} the changeover being shown
static var log: Array = []              # [[game s, text]] the last few
static var changeovers := 0             # tests: changeovers shown since the start
static var _fault_in := 90.0
static var _stick := 0.0
static var spin := 0.0                  # the shaft's angle (its marks)
static var flow := [0.0, 0.0, 0.0]      # the three loops' running (their dots)
static var t := 0.0
static var events: Array = []           # [sound, box-local m]
static var _rng := RandomNumberGenerator.new()
static var _init := false


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


static func reset() -> void:
	stage = 0; cap = 6.0; own = 0.0; shore = 0.0; groups = {}; units = 0; hz = 0.0; valve = 0.0; p_mech = 0.0
	rods = [0.0, 0.0, 0.0]; q_th = [0.0, 0.0, 0.0]; t_hot = [40.0, 40.0, 40.0]; t_cold = [40.0, 40.0, 40.0]
	pzr = [0.0, 0.0, 0.0]; mcp = [0.0, 0.0, 0.0]; fw = [0.0, 0.0, 0.0]; fw_duty = [0, 1]; rp = [0.0, 0.0]; rp_duty = 0
	vib = [0.0, 0.0, 0.0]; rp_vib = [0.0, 0.0]; t_cond = 30.0; rad_t = 20.0; fc = 0.0; fc_fan = 0.0
	breaker = {}; _want = {}; _last_draw = {}; umb = 0.0; _shore_t = 0.0; fault = {}; log = []; changeovers = 0; _fault_in = 90.0; _stick = 0.0
	spin = 0.0; flow = [0.0, 0.0, 0.0]; t = 0.0; events = []; _rng.seed = 100; _init = false


# what the grid carries now, read from it (the caller reads a few times a second)
static func read(game) -> Dictionary:
	var g := {}
	for k in GROUPS:
		g[k] = 0.0
	var total := 0.0
	for l in Grid.loads(game):
		var mw := float(l.mw)
		if l.get("free", false):
			continue
		total += mw
		var gr := str(l.group)
		g[gr if g.has(gr) else "base"] = float(g.get(gr if g.has(gr) else "base", 0.0)) + mw
	var sh := minf(Grid.shore_mw(game), total)
	return {"stage": Port.stage("power"), "cap": Grid.capacity(), "own": maxf(0.0, total - sh), "shore": sh, "groups": g}


static func unit_count(st: int) -> int:
	return 0 if st < 1 else (2 if st == 1 else 3)


static func frac() -> float:
	return clampf(own / maxf(1.0, cap), 0.0, 1.0)


static func _approach(v: float, to: float, tau: float, dt: float) -> float:
	return to + (v - to) * exp(-dt / maxf(0.001, tau))


static func tick(dt: float, rd: Dictionary) -> void:
	t += dt
	if not rd.is_empty():
		stage = int(rd.stage)
		cap = float(rd.cap)
		own = float(rd.own)
		shore = float(rd.shore)
		groups = rd.groups
	units = unit_count(stage)
	if not _init:
		_init = true
		_settle()
	var f := frac()
	# --- the turbine-generator: the electricity is what the loads take; the steam is what the
	# valve lets through; the difference speeds or slows the shaft
	if units > 0:
		var p_e := own
		var to := clampf(p_e / cap + (50.0 - hz) * 0.25, 0.0, 1.0)
		if _stick <= 0.0:
			valve = move_toward(valve, to, VALVE_RATE * dt)
		else:
			_stick -= dt
		p_mech = valve * cap
		if hz < 1.0:
			# run up from standstill on the barring gear and the valve
			hz = move_toward(hz, 50.0, 1.6 * dt)
		else:
			hz += 50.0 * (p_mech - p_e) / (2.0 * H * cap) * dt
			hz = clampf(hz, 45.0, 52.0)
	else:
		valve = move_toward(valve, 0.0, VALVE_RATE * dt)
		p_mech = 0.0
		hz = move_toward(hz, 0.0, 1.2 * dt)
	spin = fmod(spin + hz * dt * 0.08, TAU)
	# --- the reactors: each unit's heat follows the steam drawn off it; its rods step out with it
	for i in 3:
		var live := i < units
		var uf := clampf(p_mech / maxf(1.0, cap), 0.0, 1.0) if live else 0.0
		var q_to := (cap / maxf(1, units)) * uf / ETA if live else 0.0
		q_th[i] = _approach(q_th[i], q_to, 3.0, dt)
		var rod_to := (0.5 + 0.42 * uf) if live else 0.0
		rods[i] = move_toward(rods[i], rod_to, ROD_RATE * dt * (1.0 if live else 3.0))
		mcp[i] = move_toward(mcp[i], 1.0 if live else 0.0, dt * 0.25)
		var hot := (288.0 + 36.0 * uf) if live else 40.0
		var cold := (288.0 + 2.0 * uf) if live else 40.0
		t_hot[i] = _approach(t_hot[i], hot, 5.0 if live else 60.0, dt)
		t_cold[i] = _approach(t_cold[i], cold, 6.0 if live else 60.0, dt)
		# the pressuriser's heaters: on while the leg cools (pressure would sag), off as it warms
		var heat_to := clampf(0.3 + (hot - t_hot[i]) * 0.08, 0.0, 1.0) if live else 0.0
		pzr[i] = _approach(pzr[i], heat_to, 1.2, dt)
	# --- the feed pumps (two duty) and the radiator pumps (one duty)
	var run_sec := units > 0
	for i in 3:
		var on: bool = run_sec and i in fw_duty
		fw[i] = move_toward(fw[i], (0.55 + 0.45 * f) if on else 0.0, dt * (0.5 if on else 0.18))
		vib[i] = maxf(0.0, vib[i] - dt * 0.25)
	for i in 2:
		var on2: bool = (units > 0 or stage == 0) and i == rp_duty
		rp[i] = move_toward(rp[i], 1.0 if on2 else 0.0, dt * (0.5 if on2 else 0.2))
		rp_vib[i] = maxf(0.0, rp_vib[i] - dt * 0.25)
	var q_all := 0.0
	for i in 3:
		q_all += q_th[i]
	var rej := maxf(0.0, q_all - p_mech)
	var rej_f := clampf(rej / maxf(1.0, cap / ETA * (1.0 - ETA)), 0.0, 1.0)
	t_cond = _approach(t_cond, (36.0 + 22.0 * rej_f) if units > 0 else 25.0, 8.0, dt)
	# the fuel-cell set: the 6 MW of stage 0; standby (cool) once the reactors carry the port
	var fc_to := own if units == 0 else 0.0
	fc = _approach(fc, fc_to, 0.6, dt)
	fc_fan = move_toward(fc_fan, (0.25 + 0.75 * clampf(fc / 6.0, 0.0, 1.0)) if fc_to > 0.0 else 0.0, dt * 0.4)
	var fc_rej := fc * 0.8
	rad_t = _approach(rad_t, 20.0 + 95.0 * rej_f + 6.0 * fc_rej / 6.0 * (1.0 if units == 0 else 0.0), 25.0, dt)
	var rate := [maxf(mcp[0], maxf(mcp[1], mcp[2])) * 0.8, (0.3 + 0.7 * f) if units > 0 else 0.0, maxf(rp[0], rp[1]) * 0.6]
	for i in 3:
		flow[i] += float(rate[i]) * dt
	_feeders(dt)
	_umbilical(dt)
	_faults(dt)


# the plant as it would be after running a while (a save loaded, the game started): no run-up
static func _settle() -> void:
	units = unit_count(stage)
	var f := frac()
	hz = 50.0 if units > 0 else 0.0
	valve = f if units > 0 else 0.0
	p_mech = own if units > 0 else 0.0
	for i in 3:
		var live := i < units
		q_th[i] = (cap / maxf(1, units)) * f / ETA if live else 0.0
		rods[i] = (0.5 + 0.42 * f) if live else 0.0
		mcp[i] = 1.0 if live else 0.0
		t_hot[i] = (288.0 + 36.0 * f) if live else 40.0
		t_cold[i] = (288.0 + 2.0 * f) if live else 40.0
		pzr[i] = 0.3 if live else 0.0
		fw[i] = (0.55 + 0.45 * f) if live and i in fw_duty else 0.0
	rp[rp_duty] = 1.0
	t_cond = 36.0 + 22.0 * f if units > 0 else 25.0
	rad_t = 20.0 + 95.0 * f if units > 0 else 26.0
	fc = own if units == 0 else 0.0
	fc_fan = 0.25 + 0.75 * clampf(fc / 6.0, 0.0, 1.0) if units == 0 else 0.0
	for k in FEEDERS:
		var on := _draws(k)
		breaker[k] = 1.0 if on else 0.0
		_want[k] = on
		_last_draw[k] = 0.0 if on else HOLD_S
	umb = 1.0 if shore > 0.05 else 0.0


static func feeder_mw(k: String) -> float:
	match k:
		"gen":
			return own
		"shore":
			return shore
	return float(groups.get(k, 0.0))


static func _draws(k: String) -> bool:
	if k == "gen":
		return own > 0.005
	if k == "shore":
		return shore > 0.05
	return feeder_mw(k) > 0.005


# each breaker: closes when its feeder starts drawing (the base always), opens a while after it
# stops; the shore incomer only once the umbilical is plugged in
static func _feeders(dt: float) -> void:
	for i in FEEDERS.size():
		var k: String = FEEDERS[i]
		var d := _draws(k)
		_last_draw[k] = 0.0 if d else float(_last_draw.get(k, HOLD_S)) + dt
		var want: bool = float(_last_draw[k]) < HOLD_S
		if k == "shore":
			want = want and umb >= 1.0
		if k == "base":
			want = true
		if want != bool(_want.get(k, false)):
			_want[k] = want
			events.append(["breaker", Vector2(39.7 + i * 2.15, 21.0)])
		breaker[k] = move_toward(float(breaker.get(k, 0.0)), 1.0 if want else 0.0, dt / BREAKER_S)


# the shore line's umbilical: swings out and plugs in once the port has drawn on it a moment,
# stows a while after
static func _umbilical(dt: float) -> void:
	var drawing := shore > 0.05
	if drawing:
		_shore_t = maxf(0.0, _shore_t) + dt
	else:
		_shore_t = minf(0.0, _shore_t) - dt
	var to := 1.0 if (_shore_t > 1.0 or (umb > 0.0 and _shore_t > -20.0)) else 0.0
	var was := umb
	umb = move_toward(umb, to, dt / UMB_S)
	if was < 1.0 and umb >= 1.0:
		events.append(["clamp", Vector2(52.0, 0.0)])
	if was > 0.0 and umb <= 0.0:
		events.append(["clamp_off", Vector2(52.0, 0.0)])


static func moving_umb() -> float:
	var drawing := shore > 0.05
	var to := 1.0 if (_shore_t > 1.0 or (umb > 0.0 and _shore_t > -20.0)) else 0.0
	return 1.0 if absf(umb - to) > 0.001 and (drawing or umb > 0.0) else 0.0


# the motors running now (the shared motor loop's level), 0 … 1
static func motor() -> float:
	return moving_umb()


# --- now and then a changeover, put right by the automatics (Q2 C); nothing on the grid changes
static func _faults(dt: float) -> void:
	if not fault.is_empty():
		fault.t = float(fault.t) + dt
		_fault_step()
		if float(fault.t) > 14.0:
			fault = {}
		return
	if units <= 0:
		return
	_fault_in -= dt
	if _fault_in > 0.0:
		return
	_fault_in = _rng.randf_range(FAULT_EVERY.x, FAULT_EVERY.y)
	var kinds := ["feed", "valve", "rad"]
	start_fault(kinds[_rng.randi() % kinds.size()])


static func start_fault(kind: String) -> void:
	match kind:
		"feed":
			var p: int = fw_duty[_rng.randi() % 2]
			var spare := 3 - int(fw_duty[0]) - int(fw_duty[1])
			fault = {"kind": "feed", "t": 0.0, "unit": p, "spare": spare, "done": false}
		"valve":
			fault = {"kind": "valve", "t": 0.0, "unit": 0, "done": false}
		"rad":
			fault = {"kind": "rad", "t": 0.0, "unit": rp_duty, "spare": 1 - rp_duty, "done": false}
	events.append(["scale_beep", fault_at() if str(fault.kind) != "rad" else Vector2(56.7, 20.0)])


static func _fault_step() -> void:
	var ft := float(fault.t)
	match str(fault.kind):
		"feed":
			var p := int(fault.unit)
			if ft < 3.0:
				vib[p] = 1.0
			elif not fault.done:
				# the standby is started, then the shaking one is stopped
				fault.done = true
				fw_duty = [int(fault.spare), int(fw_duty[0]) if int(fw_duty[1]) == p else int(fw_duty[1])]
				events.append(["clank", Vector2(11.6 + int(fault.spare) * 3.4, 24.8)])
		"valve":
			if ft < 0.1 and not fault.done:
				fault.done = true
				_stick = 1.4
				valve = maxf(0.0, valve - 0.05)
			if ft > 1.4 and ft < 1.5:
				events.append(["winch_brake", Vector2(37.4, 4.5)])
		"rad":
			var p2 := int(fault.unit)
			if ft < 3.0:
				rp_vib[p2] = 1.0
			elif not fault.done:
				fault.done = true
				rp_duty = int(fault.spare)
				rad_t += 3.0
				events.append(["clank", Vector2(56.6, 24.0)])
	if ft >= 4.0 and not fault.get("logged", false):
		fault.logged = true
		changeovers += 1
		log.append([t, fault_text(true)])
		if log.size() > 3:
			log.pop_front()


# where its plate goes (box-local m, the plate's top-left; "rad" is right-aligned to it)
static func fault_at() -> Vector2:
	match str(fault.get("kind", "")):
		"feed": return Vector2(10.0, 22.25)
		"valve": return Vector2(37.8, 3.45)
		"rad": return Vector2(59.6, 14.2)
	return Vector2(30, 14)


static func fault_text(done_text := false) -> String:
	var names := ["FW-1", "FW-2", "FW-3"]
	match str(fault.get("kind", "")):
		"feed":
			var p := int(fault.unit)
			if float(fault.t) < 3.0 and not done_text:
				return w("给水泵 %s 振动偏高 · 自动启动备用泵 %s" % [names[p], names[int(fault.spare)]], "FEED PUMP %s VIBRATING · STANDBY %s STARTING" % [names[p], names[int(fault.spare)]])
			return w("给水泵 %s → %s 切换完成 · 供电不受影响" % [names[p], names[int(fault.spare)]], "FEED PUMP %s → %s CHANGED OVER · SUPPLY UNAFFECTED" % [names[p], names[int(fault.spare)]])
		"valve":
			if float(fault.t) < 1.4 and not done_text:
				return w("调节阀卡涩 · 频率下跌", "GOVERNOR VALVE STICKING · FREQUENCY FALLING")
			return w("调节阀卡涩 1.4 s 后自动冲开 · 频率已恢复", "GOVERNOR VALVE FREED AFTER 1.4 s · FREQUENCY BACK")
		"rad":
			var rn := ["RP-1", "RP-2"]
			if float(fault.t) < 3.0 and not done_text:
				return w("散热泵 %s 振动偏高 · 自动切到 %s" % [rn[int(fault.unit)], rn[int(fault.spare)]], "RADIATOR PUMP %s VIBRATING · TO %s" % [rn[int(fault.unit)], rn[int(fault.spare)]])
			return w("散热泵 %s → %s 切换完成 · 散热板温度短暂升高" % [rn[int(fault.unit)], rn[int(fault.spare)]], "RADIATOR PUMP %s → %s CHANGED OVER · RADIATORS BRIEFLY WARMER" % [rn[int(fault.unit)], rn[int(fault.spare)]])
	return ""


# ---------------------------------------------------------------- what each machine says (plates, cards)
static func unit_state(i: int) -> Array:
	if i >= units:
		if i == 2 and stage < 2:
			return [w("空机位 · 第 2 期装第 3 套", "EMPTY BAY · UNIT 3 AT STAGE 2"), "off"]
		return [w("停堆 · 冷态", "SHUT DOWN · COLD"), "warn" if stage < 1 else "off"]
	return [w("%.0f MWt · 棒位 %d%% · %.0f / %.0f °C" % [q_th[i], int(rods[i] * 100.0), t_hot[i], t_cold[i]], "%.0f MWt · RODS %d%% · %.0f / %.0f °C" % [q_th[i], int(rods[i] * 100.0), t_hot[i], t_cold[i]]), "ok" if absf(rods[i] - (0.5 + 0.42 * clampf(p_mech / maxf(1.0, cap), 0.0, 1.0))) < 0.02 else "work"]


static func turbine_state() -> Array:
	if units <= 0:
		return [w("停机 · 0 rpm", "STOPPED · 0 rpm"), "off"]
	var lamp := "warn" if str(fault.get("kind", "")) == "valve" and float(fault.t) < 3.0 else ("ok" if absf(hz - 50.0) < 0.1 else "work")
	return [w("%d rpm · %.2f Hz · 阀位 %d%% · %.1f MW" % [int(hz * 60.0), hz, int(valve * 100.0), own], "%d rpm · %.2f Hz · VALVE %d%% · %.1f MW" % [int(hz * 60.0), hz, int(valve * 100.0), own]), lamp]


static func fc_state() -> Array:
	if units > 0:
		return [w("备用 · 主机组带载", "STANDBY · THE UNITS CARRY THE PORT"), "off"]
	return [w("应急供电 %.1f / 6 MW" % fc, "EMERGENCY SUPPLY %.1f / 6 MW" % fc), "work" if fc > 0.05 else "ok"]


static func feed_state() -> Array:
	if units <= 0:
		return [w("停 · 没有蒸汽", "STOPPED · NO STEAM"), "off"]
	var names := ["FW-1", "FW-2", "FW-3"]
	var st := "warn" if str(fault.get("kind", "")) == "feed" and float(fault.t) < 3.0 else "ok"
	return [w("运行 %s + %s · 备用 %s · %.0f kg/s" % [names[fw_duty[0]], names[fw_duty[1]], names[3 - fw_duty[0] - fw_duty[1]], steam_kgs()], "RUN %s + %s · STANDBY %s · %.0f kg/s" % [names[fw_duty[0]], names[fw_duty[1]], names[3 - fw_duty[0] - fw_duty[1]], steam_kgs()]), st]


static func rad_state() -> Array:
	var rn := ["RP-1", "RP-2"]
	var st := "warn" if str(fault.get("kind", "")) == "rad" and float(fault.t) < 3.0 else "ok"
	return [w("运行 %s · 散热板 %.0f °C · 排热 %.0f MW" % [rn[rp_duty], rad_t, rejected()], "RUN %s · RADIATORS %.0f °C · %.0f MW OUT" % [rn[rp_duty], rad_t, rejected()]), st]


static func steam_kgs() -> float:
	var q := 0.0
	for i in 3:
		q += q_th[i]
	return q * 0.55


static func rejected() -> float:
	var q := 0.0
	for i in 3:
		q += q_th[i]
	return maxf(0.0, q - p_mech) + (fc * 0.8 if units == 0 else 0.0)


static func shore_state() -> Array:
	if umb <= 0.0 and shore <= 0.05:
		return [w("收起 · 没买外购电", "STOWED · NO BOUGHT POWER"), "off"]
	if umb < 1.0:
		return [w("外购电接头伸出中 %d%%" % int(umb * 100.0), "UMBILICAL SWINGING OUT %d%%" % int(umb * 100.0)), "work"]
	return [w("已接上 · 外购电 %.1f 兆瓦" % shore, "PLUGGED IN · %.1f MW SHORE ($%d/MWh)" % [shore, int(Grid.SHORE_PRICE)]), "work" if shore > 0.05 else "ok"]
