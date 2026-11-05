class_name Depot
# Third-party storage (77 号, G6.4; 02 号 §6 "仓储与装卸业务"): other firms leave goods in the
# company's warehouse and pay by the period. Only rows the player gave to clients' goods take
# them, 20 t a row; the goods come in and go out by the real forklifts (73 号) and are never the
# company's — not on its stock, not for sale, not for the furnace. Finite demand: at most three
# offers, a new one every five minutes. The handling fee is paid when they leave.
#   Career.data.depot = {offers, lots, t, n, auto, earned, spent}
# 85 号 (user 2026-10-26: "怎么直接收东西？……我应该搬左边的箱"): taken goods come up the hatch as
# crates (5 t at most each) onto the receiving counter; the drone carries each to the lot's rack
# (scripts/cargo_floor.gd) and the rent starts once they are all up. "Forklift carries" in the
# console's automation hands it back to the forklifts.
#   lot.state: "dock" (crates on the counter) | "in" (forklift) | "stored" | "due"; lot.crates = [{t, at}]

const ROW_CAP := 20.0
const EVERY := 300.0
const MAX_OPEN := 3
const EXPIRE := 360.0
const PERIOD := 300.0
const GOODS := ["steel_billet:1", "nonferrous_mix:0", "steel_plate:1", "mixed_metal:0"]
const CRATE_T := 5.0
const NAG := 360.0                      # s on the counter before the client asks after them
# 128 号 (user 2026-11-04: "我平常也没有第三方存储，直接去了，这只作为我自己的仓库"): no clients' goods
# any more — no offers, no auto-taking; lots an old save already holds run out and leave as before
static func on() -> bool:
	return not StoreBook.ON


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


static func data() -> Dictionary:
	if not Career.data.has("depot") or Career.data.depot.is_empty():
		Career.data.depot = {"offers": [], "lots": [], "t": 0.0, "n": 0,
			"auto": {"on": false, "min_fee": 300.0, "keep_free": 0.0, "max_lots": 3, "stop_new": false}, "earned": 0.0, "spent": 0.0}
	return Career.data.depot


# the forklifts carry clients' goods in (the old way) instead of the drone
static func fork_in() -> bool:
	return bool(data().auto.get("fork", false))


static func set_fork_in(on: bool) -> void:
	data().auto.fork = on
	Career.save()


# every crate on the counter now: [lot id, crate index, tonnes, client, row]
static func dock_crates() -> Array:
	var out: Array = []
	for l in data().lots:
		if str(l.state) != "dock":
			continue
		var cs: Array = l.get("crates", [])
		for i in cs.size():
			if str(cs[i].at) == "dock":
				out.append([str(l.id), i, float(cs[i].t), str(l.client), int(l.row)])
	return out


static func lot(id: String) -> Dictionary:
	for l in data().lots:
		if str(l.id) == id:
			return l
	return {}


# a crate set on its rack; the lot is stored (its rent clock starts) once the last is up
static func put(id: String, i: int) -> Dictionary:
	var l := lot(id)
	if l.is_empty() or str(l.state) != "dock" or i < 0 or i >= l.get("crates", []).size():
		return {"ok": false, "reason": w("这箱货不在收货台", "NOT ON THE COUNTER")}
	l.crates[i].at = "row"
	var left := 0
	for c in l.crates:
		if str(c.at) != "row":
			left += 1
	if left == 0:
		l.state = "stored"
		l.clock = 0.0
	Career.save()
	return {"ok": true, "left": left, "row": int(l.row)}


# the crates a stored lot has on its rack (for the drawing)
static func row_crates(row: int) -> Array:
	var out: Array = []
	for l in data().lots:
		if int(l.row) != row or str(l.state) == "gone":
			continue
		for c in l.get("crates", []):
			if str(c.at) == "row" or str(l.state) in ["stored", "due"]:
				out.append([float(c.t), str(l.client)])
		if l.get("crates", []).is_empty() and str(l.state) in ["stored", "due"]:
			out.append([float(l.t), str(l.client)])
	return out


static func open() -> bool:
	return Career.usable() and not Career.data.is_empty() and Port.stage("cargo") >= 1


static func _cash(delta: float) -> void:
	var d := data()
	if delta >= 0.0:
		d.earned = float(d.earned) + delta
	else:
		d.spent = float(d.spent) - delta
	Career.data.money = float(Career.data.get("money", 0.0)) + delta
	if Career.data.get("exchange", {}).get("actors", {}).has("company"):
		Career.data.exchange.actors.company.cash = float(Career.data.money)


static func client_rows() -> Array:
	var out: Array = []
	var r := Warehouse.rows()
	for i in r.size():
		if str(r[i]) == "client":
			out.append(i)
	return out


static func used(row: int) -> float:
	var u := 0.0
	for l in data().lots:
		if int(l.row) == row and str(l.state) != "gone":
			u += float(l.t)
	return u


static func free_t() -> float:
	var f := 0.0
	for row in client_rows():
		f += maxf(0.0, ROW_CAP - used(row))
	return f


static func row_with(t: float) -> int:
	for row in client_rows():
		if ROW_CAP - used(row) >= t - 0.001:
			return row
	return -1


static func _rng(salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([int(Career.data.get("seed", 0)), "depot", salt])
	return r


static func new_offer() -> Dictionary:
	var d := data()
	d.n = int(d.n) + 1
	var rng := _rng(int(d.n))
	var o := {"id": "DP-%03d" % int(d.n), "client": ["恒岳工业", "天衡物流", "远岫工场", "独立商户"][rng.randi_range(0, 3)], "key": GOODS[rng.randi_range(0, GOODS.size() - 1)],
		"t": snappedf(rng.randf_range(4.0, 14.0), 1.0), "periods": rng.randi_range(2, 5), "age": 0.0}
	o.fee = snappedf(float(o.t) * rng.randf_range(35.0, 70.0), 10.0)
	o.handling = snappedf(float(o.t) * 40.0, 10.0)
	d.offers.append(o)
	return o


static func income(o: Dictionary) -> float:
	return float(o.fee) * int(o.periods) + float(o.handling)


static func accept_block(id: String, by_auto := false) -> String:
	var d := data()
	var o := {}
	for x in d.offers:
		if str(x.id) == id:
			o = x
	if o.is_empty():
		return w("这张单不在了", "GONE")
	if bool(d.auto.stop_new):
		return w("已设为停止接新单", "NOT TAKING NEW WORK")
	if client_rows().is_empty():
		return w("先在货运区把一排货架改成“客户货”", "GIVE A ROW TO CLIENTS' GOODS FIRST")
	if row_with(float(o.t)) < 0:
		return w("客户货排放不下 %.0f t（每排 %.0f t，还空 %.1f t）", "NO ROOM FOR %.0f t") % ([float(o.t), ROW_CAP, free_t()] if Txt.zh else [float(o.t)])
	if by_auto and free_t() - float(o.t) < float(d.auto.keep_free):
		return w("要留 %.0f t 空位", "%.0f t KEPT FREE") % float(d.auto.keep_free)
	return ""


# taken: the goods arrive and the forklift puts them away (a real move, 73 号)
static func accept(id: String, by_auto := false) -> Dictionary:
	var why := accept_block(id, by_auto)
	if why != "":
		return {"ok": false, "reason": why}
	var d := data()
	var o := {}
	for x in d.offers:
		if str(x.id) == id:
			o = x
	d.offers.erase(o)
	var row := row_with(float(o.t))
	var l := o.duplicate()
	l.row = row
	l.left = int(o.periods)
	l.clock = 0.0
	# 85 号: crates up the hatch onto the counter, for the drone to carry; or the forklift as before
	var crates: Array = []
	var rest := float(o.t)
	while rest > 0.001:
		crates.append({"t": minf(CRATE_T, rest), "at": "dock"})
		rest -= CRATE_T
	l.crates = crates
	l.wait = 0.0
	# what the automation takes the forklifts put away (hands off); the drone carries what is taken by hand
	var by_fork := fork_in() or by_auto
	l.state = "in" if by_fork else "dock"
	d.lots.append(l)
	if by_fork:
		for c in crates:
			c.at = "row"
		var wd := Warehouse.data()
		wd.jobs.append({"id": "DEPOT-IN:" + str(o.id), "key": str(o.key), "qty": float(o.t), "row": row, "dir": "store", "left": Warehouse.trip(row), "total": Warehouse.trip(row)})
	Career.save()
	return {"ok": true, "row": row, "crates": crates.size()}


static func decline(id: String) -> void:
	var d := data()
	d.offers = d.offers.filter(func(x): return str(x.id) != id)
	Career.save()


static func advance(dt: float) -> Array:
	var said: Array = []
	if not open():
		return said
	var d := data()
	d.t = float(d.t) + dt
	if not on():
		d.offers = []
	if float(d.t) >= EVERY and on():
		d.t = 0.0
		if d.offers.size() < MAX_OPEN:
			var o := new_offer()
			said.append(w("%s 想寄存 %.0f t %s，%d 期，每期 %s", "%s WANTS TO STORE %.0f t, %d PERIODS AT %s") % ([str(o.client), float(o.t), Ops.item_name(str(o.key)), int(o.periods), Pal.money(float(o.fee))] if Txt.zh else [str(o.client), float(o.t), int(o.periods), Pal.money(float(o.fee))]))
	for o in d.offers.duplicate():
		o.age = float(o.age) + dt
		if float(o.age) >= EXPIRE:
			d.offers.erase(o)
	for l in d.lots.duplicate():
		match str(l.state):
			"dock":
				var was := float(l.get("wait", 0.0))
				l.wait = was + dt
				if was < NAG and float(l.wait) >= NAG:
					said.append(w("%s 问：货怎么还在收货台上？（货运区收货台，按 E 吊起搬上 %s 排）", "%s ASKS WHY THEIR GOODS ARE STILL ON THE COUNTER") % [str(l.client), Warehouse.ROWS[int(l.row)]])
			"in":
				if Warehouse.job("DEPOT-IN:" + str(l.id)).is_empty():
					l.state = "stored"
			"stored":
				l.clock = float(l.clock) + dt
				if float(l.clock) >= PERIOD:
					l.clock = 0.0
					l.left = int(l.left) - 1
					_cash(float(l.fee))
					if int(l.left) <= 0:
						l.state = "due"
						Warehouse.ask_out("DEPOT:" + str(l.id), str(l.key), float(l.t))
						said.append(w("%s 的寄存到期，叉车去取货", "%s'S GOODS ARE DUE OUT") % str(l.client))
			"due":
				if Warehouse.ready("DEPOT:" + str(l.id)):
					Warehouse.consume("DEPOT:" + str(l.id))
					_cash(float(l.handling))
					d.lots.erase(l)
					said.append(w("%s 提走了 %.0f t，收装卸费 %s", "%s COLLECTED %.0f t: HANDLING %s") % [str(l.client), float(l.t), Pal.money(float(l.handling))])
	var a: Dictionary = d.auto
	if on() and bool(a.on) and not bool(a.stop_new) and d.lots.size() < int(a.max_lots):
		for o in d.offers.duplicate():
			if float(o.fee) >= float(a.min_fee) and accept_block(str(o.id), true) == "":
				accept(str(o.id), true)
				said.append(w("自动接了寄存 %s", "TOOK STORAGE %s") % str(o.id))
				break
	if not said.is_empty():
		Career.save()
	return said


static func status() -> String:
	var d := data()
	var s := w("客户货 %d 批 · 客户货排空位 %.0f t · 累计收入 %s", "%d CLIENT LOTS · %.0f t FREE · EARNED %s") % [d.lots.size(), free_t(), Pal.money(float(d.earned))]
	var n := dock_crates().size()
	if n > 0:
		s += w(" · 收货台上 %d 箱等你搬", " · %d CRATES ON THE COUNTER") % n
	return s
