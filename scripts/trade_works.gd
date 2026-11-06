extends RefCounted
# 98 号 (user 2026-10-28: "贸易站也做得一样详细，超级详细的精细化，硬核"; Q1 C, Q2 B, Q3 A, Q4,
# Q5 C, Q7 A, Q8 A, Q9, Q10 A): what the trade port's machines are doing now, run from the real
# exchange (its local trades, the visitors, the book) — nothing about the trading changes (Q8 A).
# Two floors, like the tug station:
#   upper: the hall. The three companies' counters on the north wall under the quote board; each
#     counter's pneumatic tube sends a capsule up to the ceiling duct when its business changes;
#     at a counter the glass lights with the company's representative on a video link (Q5 C).
#     Visitors' ships berth at the two airlocks in the east wall; a gangway runs out to the hatch
#     and a shuttle cart brings the visitor along the hall floor to wait by the business console.
#   lower: the hand-over dock. A trade with one of the port's companies is seen done: selling, the
#     crates come out of the warehouse intake in the west wall, run east on the belt, stop on the
#     weighbridge (its reading the trade's real tonnes) and under the sealer, and the dock crane
#     swings them into the client lighter berthed in the east port; buying, the lighter comes in
#     loaded and they go the other way into the intake. Then the lighter leaves.
# Every machine chases its target — accelerating, braking in time. Box-local metres (60 × 28,
# floor at 26.8). Nothing here is saved but the price history (Q9, Career.data.exchange.hist).

const FLOOR := 26.8
const SLAB := Vector2(15.8, 16.4)       # the hall floor (a slab over the dock), top and bottom
const SLAB_X := 14.0
const BELT_Y := 24.3                    # the belt's top
const INTAKE_X := 13.4                  # the warehouse intake in the dock's west end
const WEIGH := Vector2(27.0, 31.0)      # the weighbridge's span on the belt
const SEAL_X := 38.6
const BELT_END := 49.4
const HOLD_X := 55.6                    # where the crane sets a crate down in the lighter
const LIGHTER_Y := 22.0                 # the lighter's deck line in the east port
const CRANE_Y := 17.2                   # the crane's girder (under the slab)
const PORT := Vector2(18.4, 26.4)       # the east port (lighter), top and bottom
const LOCKS := [Vector2(2.6, 7.4), Vector2(8.6, 13.4)]   # the two visitor airlocks in the east wall
const WAIT_X := 16.2                    # where a visitor's cart stops, by the business console
const CRATE := Vector2(1.6, 1.3)
const V_BELT := 1.5
const HIST_EVERY := 60.0                # s of game between two points of a goods' price history
const HIST_N := 60

static var lighter_k := 0.0             # 0 away … 1 alongside
static var lighter_for := ""
static var lighter_hide := false        # 128 号 第 2 段: an order's client freighter lies in the port (scripts/client_ships.gd)
static var job := {}                    # {id, sell, n, made, done, crates: [...]} the trade being handed over
static var crates: Array = []           # {x, y, at: "belt"/"hook"/"hold", wait, weighed, sealed}
static var hold := 0                    # crates in the lighter's hold
static var weigh_show := 0.0            # the weighbridge's reading (t), shown smoothly
static var weigh_to := 0.0
static var seal_t := 0.0                # the sealer's stamp, 1 at the bottom of its stroke
static var belt_run := 0.0              # how far the belt has run (its marks)
static var belt_v := 0.0
static var intake := 0.0                # the intake's door 0 shut … 1 open
static var cx := 52.0                   # the dock crane's trolley, its hook
static var cvx := 0.0
static var cx_to := 52.0
static var ch := 19.0
static var cvh := 0.0
static var ch_to := 19.0
static var on_hook := false
static var crane_step := ""
static var linger := 0.0
static var visitors := {}               # id -> {k (ship in), g (gangway), c (cart 0 lock … 1 waiting), lock, leaving}
static var tubes: Array = []            # capsules: {i (counter), u (0 … 1 along its run)}
static var _sig := {}                   # per company, what its book looked like (a change sends a capsule)
static var near_k := [0.0, 0.0, 0.0]    # the video link at each counter
static var _hist_t := 0.0
static var t := 0.0
static var handed := 0                  # tests: trades handed over at the dock
static var events: Array = []           # [sound, box-local m]: the real-recording one-shots, drained by the hall
static var _crane_was := false


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


static func reset() -> void:
	lighter_k = 0.0; lighter_for = ""; job = {}; crates = []; hold = 0
	weigh_show = 0.0; weigh_to = 0.0; seal_t = 0.0; belt_run = 0.0; belt_v = 0.0; intake = 0.0
	cx = 52.0; cvx = 0.0; cx_to = 52.0; ch = 19.0; cvh = 0.0; ch_to = 19.0; on_hook = false; crane_step = ""
	# 128 号 第 3 段: not mended, the crane is found where it stopped
	if Port.stage("trade") < 1:
		cx = 36.0; cx_to = 36.0; ch = 22.6; ch_to = 22.6
	linger = 0.0; visitors = {}; tubes = []; _sig = {}; near_k = [0.0, 0.0, 0.0]; _hist_t = 0.0; t = 0.0; handed = 0
	events = []; _crane_was = false


static func open() -> bool:
	return Port.stage("trade") >= 1


static func _drive(cur: float, vel: float, to: float, vmax: float, acc: float, dt: float) -> Array:
	var d := to - cur
	var want := clampf(sqrt(2.0 * acc * absf(d)) * signf(d), -vmax, vmax)
	vel = move_toward(vel, want, acc * 2.0 * dt)
	var nxt := cur + vel * dt
	if signf(to - nxt) != signf(d) or absf(to - nxt) < 0.002:
		return [to, 0.0]
	return [nxt, vel]


# the local trade being handed over (the trade hall's own lookup), the company at the counter
static func tick(dt: float, trade: Dictionary, near: String, companies: Array) -> void:
	t += dt
	_dock(dt, trade)
	_visitors(dt)
	_tubes(dt, companies)
	for i in 3:
		near_k[i] = move_toward(float(near_k[i]), 1.0 if near == str(companies[i]) else 0.0, dt * 3.0)
	_history(dt)


# ---------------------------------------------------------------- the hand-over dock
static func _dock(dt: float, trade: Dictionary) -> void:
	var live := not trade.is_empty() and str(trade.get("state", "")) in ["awaiting_dispatch", "loading", "in_transit"]
	if live and (job.is_empty() or str(job.id) != str(trade.id)) and (job.is_empty() or bool(job.done)):
		var sell: bool = str(trade.get("seller", "")) == preload("res://scripts/industrial_exchange.gd").PLAYER
		var q := float(trade.get("quantity", 0.5))
		var n := clampi(int(ceil(q / 0.5)), 1, 6)
		job = {"id": str(trade.id), "sell": sell, "n": n, "made": 0 if sell else n, "done": false, "q": q, "spawn": 0.0, "weighed": 0}
		lighter_for = Shipping.other(trade)
		hold = 0 if sell else n
		crates = []
		weigh_to = 0.0
	var working := not job.is_empty() and not bool(job.done)
	if working:
		linger = 4.0
	elif not live:
		linger = maxf(0.0, linger - dt)
	var want := 1.0 if working or live or linger > 0.0 else 0.0
	lighter_k = move_toward(lighter_k, want, dt / 2.5)
	intake = move_toward(intake, 1.0 if working else 0.0, dt * 0.8)
	# the crates: made at the intake (selling) or swung out of the hold (buying)
	if working and lighter_k >= 1.0:
		var sell: bool = job.sell
		if sell:
			job.spawn = float(job.spawn) - dt
			if int(job.made) < int(job.n) and float(job.spawn) <= 0.0 and intake > 0.9 and _clear_at(INTAKE_X + 1.0):
				crates.append({"x": INTAKE_X + 0.2, "at": "belt", "wait": 0.0, "weighed": false, "sealed": false})
				job.made = int(job.made) + 1
				job.spawn = 1.3
		_belt(dt, sell)
		_crane(dt, sell)
		if int(job.made) >= int(job.n) and crates.is_empty() and not on_hook and (not sell or hold >= int(job.n)) and (sell or hold <= 0):
			job.done = true
			handed += 1
	else:
		belt_v = move_toward(belt_v, 0.0, dt * 2.0)
		cx_to = 52.0
		ch_to = 19.0
		# 128 号 第 3 段: not mended, the dock crane hangs where it stopped; mended, it goes home when
		# its turn comes in the lighting-up (scripts/district_revive.gd)
		if Port.stage("trade") < 1 or not preload("res://scripts/district_revive.gd").started("trade", "crane"):
			cx_to = 36.0
			ch_to = 22.6
	var r := _drive(cx, cvx, cx_to, 2.0, 1.4, dt)
	cx = r[0]; cvx = r[1]
	r = _drive(ch, cvh, ch_to, 1.8, 1.6, dt)
	ch = r[0]; cvh = r[1]
	var crane_moving := cvx != 0.0 or cvh != 0.0
	if _crane_was and not crane_moving:
		events.append(["winch_brake", Vector2(cx, ch)])
	_crane_was = crane_moving
	belt_run += belt_v * dt
	seal_t = maxf(0.0, seal_t - dt * 1.6)
	weigh_show = lerpf(weigh_show, weigh_to, 1.0 - exp(-dt * 4.0))


static func _clear_at(x: float) -> bool:
	for c in crates:
		if str(c.at) == "belt" and absf(float(c.x) - x) < CRATE.x + 0.3:
			return false
	return true


# each crate on the belt moves on unless it waits at a station or the one ahead is too close
static func _belt(dt: float, sell: bool) -> void:
	var dir := 1.0 if sell else -1.0
	var moving := false
	crates.sort_custom(func(a, b): return float(a.x) * dir > float(b.x) * dir)
	var ahead := INF if sell else -INF
	for c in crates:
		if str(c.at) != "belt":
			continue
		var x := float(c.x)
		if float(c.wait) > 0.0:
			c.wait = float(c.wait) - dt
			ahead = x
			continue
		var stop := INF if sell else -INF
		var mid := (WEIGH.x + WEIGH.y) * 0.5
		if not bool(c.weighed) and (x - mid) * dir < 0.0:
			stop = mid
		elif not bool(c.sealed) and (x - SEAL_X) * dir < 0.0:
			stop = SEAL_X
		else:
			stop = BELT_END if sell else INTAKE_X - 0.6
		var limit := ahead - dir * (CRATE.x + 0.4)
		var target := minf(stop, limit) if sell else maxf(stop, limit)
		var nx := move_toward(x, target, V_BELT * dt)
		if absf(nx - x) > 1e-4:
			moving = true
		c.x = nx
		if is_equal_approx(nx, mid) and not bool(c.weighed):
			c.weighed = true
			c.wait = 0.8
			job.weighed = int(job.weighed) + 1
			events.append(["scale_beep", Vector2(WEIGH.y + 1.2, BELT_Y - 4.8)])
			weigh_to = float(job.q) * float(job.weighed) / float(job.n)
		elif is_equal_approx(nx, SEAL_X) and not bool(c.sealed):
			c.sealed = true
			c.wait = 0.6
			seal_t = 1.0
			events.append(["stamp", Vector2(SEAL_X, BELT_Y - 2.0)])
		ahead = float(c.x)
	belt_v = move_toward(belt_v, V_BELT if moving else 0.0, dt * 3.0)
	# buying: a crate reaching the intake goes into the warehouse
	if not sell:
		crates = crates.filter(func(c): return not (str(c.at) == "belt" and float(c.x) <= INTAKE_X - 0.5))


# the dock crane: selling, from the belt's end into the hold; buying, out of the hold onto it
static func _crane(dt: float, sell: bool) -> void:
	var settled := cx == cx_to and cvx == 0.0 and ch == ch_to and cvh == 0.0
	var top := BELT_Y - CRATE.y            # a crate's top on the belt
	match crane_step:
		"":
			if sell:
				for c in crates:
					if str(c.at) == "belt" and is_equal_approx(float(c.x), BELT_END):
						crane_step = "to_belt"
						break
			elif hold > 0 and _clear_at(BELT_END):
				crane_step = "to_hold"
		"to_belt":
			cx_to = BELT_END
			ch_to = top
			if settled:
				for c in crates:
					if str(c.at) == "belt" and is_equal_approx(float(c.x), BELT_END):
						c.at = "hook"
						on_hook = true
						break
				crane_step = "lift_belt"
		"lift_belt":
			ch_to = 19.0
			if settled:
				crane_step = "over_hold" if sell else "down_belt"
		"over_hold":
			cx_to = HOLD_X
			if settled:
				crane_step = "down_hold"
		"down_hold":
			ch_to = LIGHTER_Y - CRATE.y
			if settled:
				if sell:
					crates = crates.filter(func(c): return str(c.at) != "hook")
					on_hook = false
					hold += 1
					crane_step = "up_hold"
				else:
					hold -= 1
					crates.append({"x": HOLD_X, "at": "hook", "wait": 0.0, "weighed": false, "sealed": false})
					on_hook = true
					crane_step = "up_hold"
		"up_hold":
			ch_to = 19.0
			if settled:
				crane_step = "" if sell else "to_end"
		"to_hold":
			cx_to = HOLD_X
			ch_to = 19.0
			if settled:
				crane_step = "down_hold"
		"to_end":
			cx_to = BELT_END
			if settled:
				crane_step = "down_belt"
		"down_belt":
			ch_to = top
			if settled:
				for c in crates:
					if str(c.at) == "hook":
						c.at = "belt"
						c.x = BELT_END
				on_hook = false
				crane_step = "back_up"
		"back_up":
			ch_to = 19.0
			if settled:
				crane_step = ""


# where the crate on the hook is
static func hook_at() -> Vector2:
	return Vector2(cx, ch)


# how hard the dock's motors run, 0 … 1 (the motor loop's level)
static func motor() -> float:
	return clampf(maxf(maxf(absf(cvx) / 2.0, absf(cvh) / 1.8), belt_v / V_BELT * 0.6), 0.0, 1.0)


# ---------------------------------------------------------------- the visitors (Q3 A)
static func _visitors(dt: float) -> void:
	var here: Array = TradePeople.here() if TradePeople.open() else []
	var ids := {}
	for i in here.size():
		var v: Dictionary = here[i]
		var id := str(v.id)
		ids[id] = true
		if not visitors.has(id):
			var used := {}
			for o in visitors.values():
				used[int(o.lock)] = true
			var lock := 0 if not used.has(0) else 1
			visitors[id] = {"k": 0.0, "g": 0.0, "c": 0.0, "lock": lock, "leaving": false, "v": v}
		var e: Dictionary = visitors[id]
		e.v = v
		e.leaving = false
		# in: the ship berths, the gangway runs out, the cart brings the visitor across
		e.k = move_toward(float(e.k), 1.0, dt / TradePeople.ARRIVE_S)
		if float(e.k) >= 1.0:
			if float(e.g) <= 0.0:
				events.append(["hiss", Vector2(59.5, (LOCKS[int(e.lock)].x + LOCKS[int(e.lock)].y) * 0.5)])
			e.g = move_toward(float(e.g), 1.0, dt * 0.6)
		if float(e.g) >= 1.0:
			e.c = move_toward(float(e.c), 1.0, dt * 0.12)
	for id in visitors.keys():
		if ids.has(id):
			continue
		var e: Dictionary = visitors[id]
		e.leaving = true
		# out again, the other way round
		if float(e.c) > 0.0:
			e.c = move_toward(float(e.c), 0.0, dt * 0.18)
		elif float(e.g) > 0.0:
			e.g = move_toward(float(e.g), 0.0, dt * 0.8)
		else:
			e.k = move_toward(float(e.k), 0.0, dt / 4.0)
			if float(e.k) <= 0.0:
				visitors.erase(id)


# ---------------------------------------------------------------- the counters' tubes
static func _tubes(dt: float, companies: Array) -> void:
	var st: Dictionary = Career.data.get("exchange", {})
	for i in companies.size():
		var who := str(companies[i])
		var n := 0
		for o in st.get("orders", []):
			if str(o.owner) == who and str(o.state) == "open":
				n += 1
		var m := 0
		for tr in st.get("trades", []):
			if str(tr.buyer) == who or str(tr.seller) == who:
				m += 1
		var sig := "%d/%d" % [n, m]
		if _sig.has(who) and str(_sig[who]) != sig and tubes.size() < 6:
			tubes.append({"i": i, "u": 0.0})
			events.append(["receipt", Vector2(22.9 + i * 12.0, 8.6)])
			events.append(["tube", Vector2(28.4 + i * 12.0, 7.4)])
		_sig[who] = sig
	for c in tubes:
		c.u = float(c.u) + dt / 2.4
	tubes = tubes.filter(func(c): return float(c.u) < 1.0)


# ---------------------------------------------------------------- the price history (Q9)
static func _history(dt: float) -> void:
	_hist_t += dt
	if _hist_t < HIST_EVERY and _hist_t > 0.0:
		return
	_hist_t = 0.0
	record()


# one point a goods: its best bid and best ask now (0 for none)
static func record() -> void:
	if not Career.usable() or Career.data.is_empty() or not Career.data.has("exchange"):
		return
	var ex: Dictionary = Career.data.exchange
	if not ex.has("hist"):
		ex.hist = {}
	for row in preload("res://scripts/trade_hall.gd").board():
		var key := str(row.key)
		var h: Array = ex.hist.get(key, [])
		h.append([snappedf(float(row.bid), 1.0), snappedf(float(row.ask) if float(row.ask) < INF else 0.0, 1.0)])
		if h.size() > HIST_N:
			h = h.slice(h.size() - HIST_N)
		ex.hist[key] = h


static func history(key: String) -> Array:
	return Career.data.get("exchange", {}).get("hist", {}).get(key, [])


# ---------------------------------------------------------------- what each machine says
static func dock_state() -> Array:
	if not open():
		return [w("没开 · 贸易港未修复", "CLOSED · NOT MENDED"), "off"]
	if job.is_empty() or bool(job.done):
		return [w("空闲 · 和港内公司成交后在这里交货", "IDLE · DEALS WITH THE PORT'S COMPANIES ARE HANDED OVER HERE"), "ok"]
	var verb := w("装船", "LOADING") if bool(job.sell) else w("卸货进仓", "UNLOADING")
	return [w("%s · %.2f t · 已过磅 %d / %d 箱", "%s · %.2f t · %d / %d WEIGHED") % [verb, float(job.q), int(job.get("weighed", 0)), int(job.n)], "work"]


static func lighter_state(name: String) -> Array:
	if lighter_k <= 0.0:
		return [w("不在 · 成交后来接货送货", "AWAY · COMES WITH A DEAL"), "off"]
	if lighter_k < 1.0:
		return [w("%s 的驳船%s", "%s'S LIGHTER %s") % [name, w("靠泊中", "BERTHING") if not job.is_empty() and not bool(job.done) else w("离港", "LEAVING")], "work"]
	return [w("%s 的驳船靠泊 · 舱内 %d 箱", "%s'S LIGHTER · %d IN THE HOLD") % [name, hold], "work"]


static func visitor_state(e: Dictionary) -> Array:
	var v: Dictionary = e.v
	if bool(e.leaving):
		return [w("离开", "LEAVING"), "off"]
	if float(e.c) < 1.0:
		return [w("进厅中", "COMING IN"), "work"]
	return [TradePeople.card_text(v), "warn" if str(v.temper) == "hurry" else "ok"]
