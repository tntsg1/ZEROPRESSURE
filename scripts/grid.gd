class_name Grid
# The port's grid (design/…/34 号, G5.3; player 2026-10-25: own generation first, dear shore
# power when short; every load at its real rating; new batches queue for power; running ones
# are never cut; a contract's berth furnace comes before company production).
#   own generation by the power district's stage; the base load (lights, life support,
#   terminals, comms) always first; big loads (≥ 1 MW) are admitted against the headroom and
#   keep their share until they are done; small ones simply run.
# The record of an admitted batch is on the batch itself: batch.grid = {own, shore, free}.
# 70 号 (69 号 Q1 C / Q2 B / Q9 A / Q10 A): no more waiting in a queue — every load runs on what
# the dispatch gives it (speed = given / rated). The base first, then four groups in the order
# the operator keeps (default: salvage, cargo, process, tug), each group shared out by demand.

const CAPACITY := [6.0, 30.0, 80.0]    # MW own generation at power-district stage 0 / 1 / 2
const BASE_MW := 2.0
const GROUPS := ["salvage", "cargo", "process", "tug"]
const TUG_MW := 3.0                    # a tug on charge (72 号)
const LASER_MW := 1.5                  # 71 号: the drone's laser while it fires
const MOUTH_MW := 0.8                  # 71 号: the trough's conveyor and suction
static var BOTS := false               # bots work at full power unless a test turns this on


# 71 号: the berth's machines run on the grid in a career's contract (not in the training
# course, the exam, or a bot's run unless asked)
static func applies(game) -> bool:
	if game == null or not is_instance_valid(game) or not Career.usable() or Career.data.is_empty():
		return false
	if not game.career() or game.get("training") or game.get("exam") != null or game.in_berth():
		return false
	return game.get("bot") == null or BOTS


# 71 号: the first ship (TUG-001, the one taught step by step) rides the port authority's
# subsidised line, like the training heat: the lesson is not slowed by the ruined grid
static func first_ship(game) -> bool:
	return game != null and str(game.get("job").get("id", "")) == "TUG-001" if game != null and game.get("job") != null else false


# a berth machine's speed: what it is given, never below its own reserve
static func salvage_k(game, id: String, floor_k: float) -> float:
	if not applies(game):
		return 1.0
	return maxf(floor_k, k(game, id))
const SHORE_MAX := 12.0                # MW the shore line can carry
const OWN_PRICE := 60.0                # $/MWh: fuel for the port's own sets
const SHORE_PRICE := 300.0             # $/MWh: the shore line
const FURNACE_MW := 24.0
const SORT_MW := 0.24
const TROLLEY_MW := 0.4
const CRANE_MW := 0.6
const TRAM_MW := 1.2


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


static func capacity() -> float:
	return CAPACITY[clampi(Port.stage("power"), 0, 2)]


# ---------------------------------------------------------------- the operator's hand (48 号, Q38)
# the automatic dispatch runs on these and never changes them by itself
const CAP_MIN := 6.0
const LINES := ["auto", "own_only", "auto_shore"]
static func ctl() -> Dictionary:
	var c: Dictionary = Career.data.get("grid_ctl", {}) if not Career.data.is_empty() else {}
	return {"furnace_cap": clampf(float(c.get("furnace_cap", FURNACE_MW)), CAP_MIN, FURNACE_MW), "defer": bool(c.get("defer", false)),
		"priority": str(c.get("priority", "contract")), "line": str(c.get("line", "auto")), "order": _order_of(c)}


# the groups' order: kept, or (an older save) read from its two-way priority
static func _order_of(c: Dictionary) -> Array:
	var o: Array = c.get("order", [])
	if o.size() == GROUPS.size() and GROUPS.all(func(g): return g in o):
		return o.duplicate()
	if str(c.get("priority", "contract")) == "company":
		return ["process", "salvage", "cargo", "tug"]
	return GROUPS.duplicate()


static func order() -> Array:
	return ctl().order


static func group_name(g: String) -> String:
	return Port.name_of(g) if g != "base" else w("基础用电", "BASE")


# one group a place up (-1) or down (+1) in the order
static func moved(g: String, dir: int) -> Array:
	var o := order()
	var i := o.find(g)
	var j := clampi(i + dir, 0, o.size() - 1)
	if i < 0 or i == j:
		return o
	o[i] = o[j]
	o[j] = g
	return o


static func furnace_cap() -> float:
	return float(ctl().furnace_cap)


# set one of the four; what it does to a heat already running is said in the note
static func set_ctl(key: String, value) -> Dictionary:
	var c := ctl()
	if not c.has(key):
		return {"ok": false, "reason": w("没有这项设置", "NO SUCH SETTING")}
	var note := ""
	var heat: Dictionary = Career.data.get("industrial_heat", {})
	var running: bool = str(heat.get("state", "")) == "processing" and not heat.get("grid", {}).is_empty()
	match key:
		"furnace_cap":
			value = clampf(float(value), CAP_MIN, FURNACE_MW)
			if running:
				var share := float(heat.grid.get("own", 0.0)) + float(heat.grid.get("shore", 0.0))
				if float(value) > share + 0.01:
					note = w("正在跑的炉子已批 %.0f MW，上调只对下一炉生效", "THE RUNNING HEAT HAS %.0f MW; MORE APPLIES FROM THE NEXT") % share
				else:
					note = w("正在跑的炉子立即降到 %.0f MW", "THE RUNNING HEAT DROPS TO %.0f MW NOW") % float(value)
		"defer":
			value = bool(value)
			# 2026-11-04 (user): paused, the heat in the furnace stops too and waits for power (as demands() does)
			note = w("正在炼的这炉也停下等电，电先给别的区", "THE HEAT IN THE FURNACE STOPS TOO AND WAITS; THE POWER GOES TO THE REST") if value else w("正在炼的这炉继续升温", "THE HEAT IN THE FURNACE WARMS UP AGAIN")
		"priority":
			if str(value) not in ["contract", "company"]:
				return {"ok": false, "reason": w("优先级只有两种", "TWO PRIORITIES ONLY")}
			# the two-way choice is an order now
			key = "order"
			value = ["process", "salvage", "cargo", "tug"] if str(value) == "company" else GROUPS.duplicate()
		"order":
			var o: Array = value
			if o.size() != GROUPS.size() or not GROUPS.all(func(g): return g in o):
				return {"ok": false, "reason": w("顺序里要有这四组，各一次", "ALL FOUR GROUPS, ONCE EACH")}
			value = o.duplicate()
			note = w("现在的顺序：%s", "NOW: %s") % " → ".join(o.map(func(g): return group_name(str(g))))
		"line":
			if str(value) not in LINES:
				return {"ok": false, "reason": w("没有这条线路", "NO SUCH LINE")}
			if running:
				note = w("正在跑的炉子按原线路走完，从下一炉起按新线路", "THE RUNNING HEAT KEEPS ITS LINE; THE NEXT TAKES THE NEW ONE")
	var before := Career.data
	Career.data = before.duplicate(true)
	var g: Dictionary = Career.data.get("grid_ctl", {})
	g[key] = value
	Career.data.grid_ctl = g
	if not Career.save():
		Career.data = before
		return {"ok": false, "reason": w("保存失败", "SAVE FAILED")}
	return {"ok": true, "note": note}


# the load history for the control screen's trend: one sample a second, five minutes
static var history: Array = []
static var _sample_t := 0.0
static func sample(game, dt: float) -> void:
	_sample_t += dt
	if _sample_t < 1.0:
		return
	_sample_t = 0.0
	var mw := 0.0
	for l in loads(game):
		mw += float(l.mw)
	history.append(mw)
	if history.size() > 300:
		history = history.slice(history.size() - 300)


static func _plant(game):
	if game == null or not is_instance_valid(game):
		return null
	var p = game.get("plant")
	return p if p != null and is_instance_valid(p) else null


# what each load asks for now: [{id, name, group, rated, demand, mw_now (its own meter, or -1),
# free (the subsidised line), state}]. state: "base" | "run" | "idle"
static func demands(game) -> Array:
	var out: Array = [{"id": "base", "name": w("基础用电", "BASE LOAD"), "group": "base", "rated": BASE_MW, "demand": BASE_MW, "mw_now": -1.0, "state": "base"}]
	var heat: Dictionary = Career.data.get("industrial_heat", {}) if not Career.data.is_empty() else {}
	var plant = _plant(game)
	if not heat.is_empty() and str(heat.get("state", "")) not in ["complete", "cancelled", "written_off"]:
		var g: Dictionary = heat.get("grid", {})
		var processing := str(heat.get("state", "")) == "processing"
		var free: bool = g.get("free", false) or heat.get("drill", false)
		var asks: bool = processing and not free and not ctl().defer and float(heat.get("energy_debt", 0.0)) <= 0.000001
		out.append({"id": "heat", "name": (w("电弧炉 %s", "ARC FURNACE %s") if plant != null else w("感应炉 %s", "FURNACE %s")) % str(heat.get("id", "")), "group": "process",
			"rated": FURNACE_MW, "demand": furnace_cap() if asks else 0.0, "mw_now": float(plant.smelter.power) if plant != null else -1.0,
			"free": free and processing, "state": "run" if processing else "idle"})
	if plant != null and bool(plant.scrapline.company_powered):
		out.append({"id": "sort", "name": w("分选线", "SORTING LINE"), "group": "process", "rated": SORT_MW, "demand": SORT_MW, "mw_now": -1.0, "state": "run"})
	if game != null and is_instance_valid(game):
		for svc in [game.get("industrial_heat"), game.get("industrial_sort")]:
			if svc != null and is_instance_valid(svc) and svc.robot != null and svc.robot.visible:
				out.append({"id": "trolley", "name": w("吊轨车", "RAIL TROLLEY"), "group": "process", "rated": TROLLEY_MW, "demand": TROLLEY_MW, "mw_now": -1.0, "state": "run"})
		var pier = game.get("freight_pier")
		if pier != null and is_instance_valid(pier) and not pier.crane.is_empty():
			out.append({"id": "crane", "name": w("码头吊车", "PIER CRANE"), "group": "cargo", "rated": CRANE_MW, "demand": CRANE_MW, "mw_now": -1.0, "state": "run"})
		var tram = game.get("tram")
		if tram != null and is_instance_valid(tram) and bool(tram.get("riding")):
			out.append({"id": "tram", "name": w("接驳车", "SHUTTLE"), "group": "base", "rated": TRAM_MW, "demand": TRAM_MW, "mw_now": -1.0, "state": "run"})
		# a contract's berth furnace (only in a contract: the empty berth's stands cold); 71 号: the
		# laser while it fires and the trough's conveyor with it
		var dock = game.get("dock")
		if dock != null and not game.in_berth() and game.career() and not game.get("training"):
			var tl = game.get("tools")
			var firing: bool = tl != null and bool(tl.cutting) and int(tl.tool) == 2
			var sub := first_ship(game)
			out.append({"id": "laser", "name": w("激光切割", "LASER"), "group": "salvage", "rated": LASER_MW, "demand": LASER_MW if firing else 0.0, "mw_now": -1.0, "state": "run" if firing else "idle", "free": sub})
			out.append({"id": "mouth", "name": w("回收口传送带", "TROUGH CONVEYOR"), "group": "salvage", "rated": MOUTH_MW, "demand": MOUTH_MW, "mw_now": -1.0, "state": "run", "free": sub})
			var sm = dock.smelter
			var melting: bool = float(sm.bunker) > 0.01 or float(sm.m_s) > 0.001 or str(sm.phase) == "heat"
			var hold: float = clampf((sm.q_wall() + sm.q_rad()) / sm.ETA + 1.0, 0.5, FURNACE_MW)
			out.append({"id": "berth_furnace", "name": w("船坞熔炉", "BERTH FURNACE"), "group": "salvage", "rated": FURNACE_MW, "demand": FURNACE_MW if melting else hold, "mw_now": float(sm.power),
				"state": "run", "free": first_ship(game)})
		# 73 号: the warehouse's forklifts while they drive; 74 号: the rolling mill
		out.append_array(Warehouse.grid_loads())
		out.append_array(Mill.grid_loads())
		# 76 号: the gas line, the LOX tank's cold box, the supply arm
		out.append_array(GasLine.grid_loads())
		# 72 号: the company's tugs on charge at the tug station
		if Career.usable() and not Career.data.is_empty():
			for n in TugYard.charging():
				out.append({"id": "tug_" + n, "name": w("%s 充电", "%s CHARGING") % n, "group": "tug", "rated": TUG_MW, "demand": TUG_MW, "mw_now": -1.0, "state": "run"})
		for extra in extra_loads:
			if is_instance_valid(extra) and extra.has_method("grid_loads"):
				out.append_array(extra.grid_loads())
	return out


# other machines put themselves on the bus (71–75 号: the laser, the mouth, the tugs, the forklifts)
static var extra_loads: Array = []
static func add_load_source(n) -> void:
	extra_loads = extra_loads.filter(func(x): return is_instance_valid(x))
	if not n in extra_loads:
		extra_loads.append(n)


# the shore line, for whom: "auto_shore" everyone; "auto" only a heat that asked at its desk
static func shore_for(group: String) -> bool:
	var line := str(ctl().line)
	if line == "auto_shore":
		return true
	if line == "own_only":
		return false
	return group == "process" and Career.data.get("industrial_heat", {}).get("shore_asked", false)


# the dispatch: {load id: {own, shore, k}} — the base first, then the groups in order, each
# group shared out by demand, own generation before the shore line. Worked out once a frame.
static var _cache := {}
static var _cache_frame := -1
static var _cache_sig := ""
static func dispatch(game) -> Dictionary:
	var f := Engine.get_process_frames()
	var ds := demands(game)
	var sig := "%d|%s|%s|%s" % [f, str(ds.map(func(d): return [d.id, d.demand])), str(ctl()), str(capacity())]
	if sig == _cache_sig:
		return _cache
	var out := {}
	var own_left := capacity()
	var shore_left := SHORE_MAX
	var groups := ["base"] + order()
	for g in groups:
		var list: Array = ds.filter(func(d): return str(d.group) == g and not d.get("free", false))
		var want := 0.0
		for d in list:
			want += float(d.demand)
		var own := minf(want, own_left)
		own_left -= own
		var sh := 0.0
		if want - own > 0.0001 and g != "base" and shore_for(g):
			sh = minf(want - own, shore_left)
			shore_left -= sh
		# 71 号 (Jev B 0.79): inside a group everything shares by demand — while the berth furnace
		# melts, the laser and the belt slow with it
		for d in list:
			var part := float(d.demand) / want if want > 0.0 else 0.0
			var o := own * part
			var s2 := sh * part
			var kk := clampf((o + s2) / maxf(0.0001, float(d.rated)), 0.0, 1.0)
			if float(d.demand) <= 0.0:
				# idle (the laser not firing): the speed it would have the moment it starts
				var pool := own + sh + own_left
				kk = clampf(pool * float(d.rated) / (want + float(d.rated)) / maxf(0.0001, float(d.rated)), 0.0, 1.0)
			out[str(d.id)] = {"own": o, "shore": s2, "k": kk}
	for d in ds:
		if d.get("free", false):
			out[str(d.id)] = {"own": 0.0, "shore": float(d.rated), "k": 1.0, "free": true}
	_cache = out
	_cache_sig = sig
	return out


static func alloc(game, id: String) -> Dictionary:
	return dispatch(game).get(id, {"own": 0.0, "shore": 0.0, "k": 0.0})


# 77 号: what a load's power costs over dt (own sets at fuel cost, the shore line dear), taken
# from the company's cash; the heat bills itself (industrial_heat), the rest bill here
static func bill(game, id: String, dt: float) -> float:
	var a := alloc(game, id)
	if a.get("free", false):
		return 0.0
	var cost := (float(a.get("own", 0.0)) * OWN_PRICE + float(a.get("shore", 0.0)) * SHORE_PRICE) * dt / 3600.0
	if cost > 0.0 and Career.usable() and not Career.data.is_empty():
		Career.data.money = float(Career.data.get("money", 0.0)) - cost
		if Career.data.get("exchange", {}).get("actors", {}).has("company"):
			Career.data.exchange.actors.company.cash = float(Career.data.money)
	return cost


# the speed a load runs at now (1 = full)
static func k(game, id: String) -> float:
	return float(alloc(game, id).get("k", 0.0))


# what each group is given now: {group: {want, own, shore}}
static func groups_now(game) -> Dictionary:
	var out := {}
	var al := dispatch(game)
	for d in demands(game):
		var g := str(d.group)
		if not out.has(g):
			out[g] = {"want": 0.0, "own": 0.0, "shore": 0.0}
		if d.get("free", false):
			continue
		out[g].want = float(out[g].want) + float(d.demand)
		var a: Dictionary = al.get(str(d.id), {})
		if not a.get("free", false):
			out[g].own = float(out[g].own) + float(a.get("own", 0.0))
			out[g].shore = float(out[g].shore) + float(a.get("shore", 0.0))
	return out


# every load on the bus now: [{id, name, group, rated, mw (drawing now), own, shore, k, state}]
# state: "base" | "run" | "short" (given less than half of what it asks) | "idle"
static func loads(game) -> Array:
	var al := dispatch(game)
	var out: Array = []
	for d in demands(game):
		var a: Dictionary = al.get(str(d.id), {"own": 0.0, "shore": 0.0, "k": 0.0})
		var given := float(a.get("own", 0.0)) + float(a.get("shore", 0.0))
		var mw := float(d.mw_now) if float(d.mw_now) >= 0.0 else given
		var st := str(d.state)
		if st == "run" and str(d.id) == "heat" and float(d.demand) <= 0.0 and not a.get("free", false):
			st = "idle"
		elif st == "run" and float(d.demand) > 0.0 and given < float(d.demand) * 0.5 and not a.get("free", false):
			st = "short"
		out.append({"id": str(d.id), "name": str(d.name), "group": str(d.group), "rated": float(d.rated), "mw": mw, "own": float(a.get("own", 0.0)),
			"shore": float(a.get("shore", 0.0)), "k": float(a.get("k", 0.0)), "free": a.get("free", false), "state": st})
	return out


# own generation given out (the base, every load), except one
static func reserved(game, except: String = "") -> float:
	var r := 0.0
	var al := dispatch(game)
	for id in al:
		if id == except:
			continue
		r += float(al[id].get("own", 0.0))
	return r


static func headroom(game, except: String = "") -> float:
	return maxf(0.0, capacity() - reserved(game, except))


static func shore_mw(game) -> float:
	var s := 0.0
	var al := dispatch(game)
	for id in al:
		if not al[id].get("free", false):
			s += float(al[id].get("shore", 0.0))
	return s


# a heat whose feed is in is on the bus at once (70 号: no queue): the subsidised line for the
# training run, nothing while new heats are deferred; what it draws is the dispatch's
static func admit_heat(game, batch: Dictionary) -> Dictionary:
	if not batch.get("grid", {}).is_empty():
		return batch.grid
	if batch.get("drill", false):
		return {"own": 0.0, "shore": FURNACE_MW, "free": true}
	if ctl().defer:
		return {}
	return {"own": 0.0, "shore": 0.0, "dyn": true}


# the heat's power now: its share of the dispatch, never above the cap
static func heat_supply(game, batch: Dictionary) -> float:
	var g: Dictionary = batch.get("grid", {})
	if g.get("free", false):
		return minf(FURNACE_MW, furnace_cap())
	var a := alloc(game, "heat")
	g.own = float(a.get("own", 0.0))
	g.shore = float(a.get("shore", 0.0))
	return minf(float(g.own) + float(g.shore), furnace_cap())


# what an admitted heat is billed per MWh: its own share at fuel cost, the shore share dear
static func price(batch: Dictionary) -> float:
	var g: Dictionary = batch.get("grid", {})
	if batch.get("drill", false) or g.get("free", false):
		return 0.0
	var own := float(g.get("own", 0.0))
	var shore := float(g.get("shore", 0.0))
	if own + shore <= 0.0:
		return OWN_PRICE
	return (own * OWN_PRICE + shore * SHORE_PRICE) / (own + shore)


# while a contract ran (the catch-up): the berth furnace took its 24 MW first if salvage comes
# before processing in the order
static func contract_supply(batch: Dictionary) -> float:
	var g: Dictionary = batch.get("grid", {})
	if g.is_empty():
		return 0.0
	if g.get("free", false):
		return FURNACE_MW
	var o := order()
	var own := capacity() - BASE_MW
	if o.find("salvage") < o.find("process"):
		own -= FURNACE_MW
	var shore := SHORE_MAX if shore_for("process") else 0.0
	return minf(maxf(0.0, own) + shore, furnace_cap())


# why the furnace runs slow ("" when it has at least half of what it asks)
# 106 号 (10-29 问答 Q3 A): why a machine runs slow, at the machine: "供电 45%：动力区只发 6 MW，
# 排在拆船区之后" ("" while it has 98 % or more). Group: the load's group (the order it is behind).
static func short_text(game, id: String, group: String = "process") -> String:
	if game == null or not is_instance_valid(game):
		return ""
	var kk := k(game, id)
	if kk >= 0.98:
		return ""
	var o := order()
	var gn := groups_now(game)
	var ahead: Array = []
	for g in o.slice(0, maxi(0, o.find(group))):
		if float(gn.get(g, {}).get("own", 0.0)) + float(gn.get(g, {}).get("shore", 0.0)) > 0.05:
			ahead.append(group_name(g))
	var why := w("供电 %d%%：动力区只发 %.0f MW", "POWER %d%%: THE PLANT MAKES %.0f MW") % [int(kk * 100.0), capacity()]
	if not ahead.is_empty():
		why += w("，排在%s之后", ", AFTER %s") % "、".join(ahead)
	return why


# 127 号 (user 2026-11-04: "岸电、自发这些术语应该关掉"): the power page says in plain words
# whether there is enough and what it costs the work; the figures go under "details"
static func verdict(game) -> Dictionary:
	var short: Array = []
	for l in loads(game):
		# by district, the way the player sees the port (not by machine)
		if str(l.state) == "short":
			var gname := group_name(str(l.group))
			if not short.any(func(s): return s[0] == gname):
				short.append([gname, int(float(l.k) * 100.0)])
	if not short.is_empty():
		var who := PackedStringArray()
		for s in short:
			who.append(w("%s只拿到 %d%%", "%s gets %d%%") % s)
		return {"ok": false, "t": w("电不够：", "SHORT OF POWER: ") + "、".join(who) + w("，干活变慢", ", working slower"), "how": short_fix()}
	if headroom(game) < 1.0:
		return {"ok": true, "t": w("电刚好够用：再开大设备就不够了", "JUST ENOUGH: ONE MORE BIG MACHINE AND IT RUNS SHORT"), "how": ""}
	return {"ok": true, "t": w("电够用：在用 %.1f，自家能发 %.0f 兆瓦", "ENOUGH POWER: %.1f IN USE OF %.0f MW") % [reserved(game) + shore_mw(game), capacity()], "how": ""}


# how much dearer bought power is than our own
static func bought_x() -> float:
	return SHORE_PRICE / maxf(1.0, OWN_PRICE)


# what can be done about it, in a line (the control screen's own three ways)
static func short_fix() -> String:
	return w("修动力区，或在动力控制屏把加工区往前调、买外购电", "Mend the power district, or move processing up / take shore power at the power control screen")


static func wait_text(game) -> String:
	var heat: Dictionary = Career.data.get("industrial_heat", {})
	if str(heat.get("state", "")) != "processing" or heat.get("grid", {}).get("free", false):
		return ""
	if ctl().defer:
		return w("电弧炉已在供电屏暂停：正在炼的这炉停下等电", "THE FURNACE IS PAUSED AT THE POWER SCREEN: THE HEAT WAITS")

	# not on the bus yet, or stopped for the power bill: that is said elsewhere
	if heat.get("grid", {}).is_empty() or float(heat.get("energy_debt", 0.0)) > 0.000001:
		return ""
	var a := alloc(game, "heat")
	var given := float(a.get("own", 0.0)) + float(a.get("shore", 0.0))
	if given >= furnace_cap() * 0.5:
		return ""
	var o := order()
	var gn := groups_now(game)
	var ahead: Array = []
	for g in o.slice(0, o.find("process")):
		if float(gn.get(g, {}).get("own", 0.0)) > 0.05:
			ahead.append(group_name(g))
	var why := w("电不够：电弧炉只分到 %.1f / %.0f MW", "SHORT OF POWER: THE FURNACE GETS %.1f / %.0f MW") % [given, furnace_cap()]
	if not ahead.is_empty():
		why += w("，排在%s之后", ", AFTER %s") % "、".join(ahead)
	why += w("。修动力区、在控制屏把加工区往前调，或买外购电。", ". MEND THE POWER DISTRICT, MOVE PROCESSING UP, OR TAKE SHORE POWER.")
	return why
