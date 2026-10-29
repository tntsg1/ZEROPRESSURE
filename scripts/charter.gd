class_name Charter
# Tug charter (77 号, G6.4; 02 号 §6 "拖船业务"): other firms hire the company's own tug to
# move a load between belt stations (or to the port). The demand is finite — at most three
# offers, a new one every four minutes, each withdrawn after five — and a charter takes a real
# tug: away for the whole round trip (port → pick-up → delivery → port, real transfer orbits),
# not free for the company's own tows, flat when it is back (it charges on the grid, 72 号).
# Costs: propellant (by the mass moved and the Δv), the charge, and wear — every third charter
# the tug stands a minute in the shop. The card says what is left after costs.
#   Career.data.charter = {offers, jobs, t, n, wear, service, auto, earned, spent}

const EVERY := 240.0
const MAX_OPEN := 3
const EXPIRE := 300.0
const TUG_T := 40.0                 # t: the tug itself, pushed with the load
const PROP_K := 2.5                 # $ per tonne per km/s of Δv
const WEAR_LIMIT := 3
const SERVICE_S := 60.0
const SERVICE_FEE := 2500.0


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


static func data() -> Dictionary:
	if not Career.data.has("charter") or Career.data.charter.is_empty():
		Career.data.charter = {"offers": [], "jobs": [], "t": 0.0, "n": 0, "wear": {}, "service": {},
			"auto": {"on": false, "min_net": 2000.0, "keep_one": true, "max_jobs": 1, "stop_new": false}, "earned": 0.0, "spent": 0.0}
	return Career.data.charter


static func open() -> bool:
	return Career.usable() and not Career.data.is_empty() and TugFleet.count() >= 1


static func _cash(delta: float) -> void:
	var d := data()
	if delta >= 0.0:
		d.earned = float(d.earned) + delta
	else:
		d.spent = float(d.spent) - delta
	Career.data.money = float(Career.data.get("money", 0.0)) + delta
	if Career.data.get("exchange", {}).get("actors", {}).has("company"):
		Career.data.exchange.actors.company.cash = float(Career.data.money)


static func _rng(salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([int(Career.data.get("seed", 0)), "charter", salt])
	return r


# the round trip, flown on today's orbits: [seconds, Δv km/s]
static func trip(from: int, to: int) -> Array:
	var day := Shipping.day()
	var port := Orbits.PORT
	var a := Orbits.station(from)
	var b := Orbits.station(to) if to >= 0 else port
	var legs := [Orbits.transfer(port, a, day), Orbits.transfer(a, b, day), Orbits.transfer(b, port, day)] if to >= 0 else [Orbits.transfer(port, a, day), Orbits.transfer(a, port, day)]
	var days := 0.0
	var dv := 0.0
	for l in legs:
		days += float(l.get("tof", 0.0))
		dv += float(l.get("dv1", 0.0)) + float(l.get("dv2", 0.0))
	return [days / Orbits.DAYS_PER_S, dv]


static func prop_cost(o: Dictionary) -> float:
	return snappedf((float(o.t) + TUG_T) * float(o.dv) * PROP_K, 10.0)


# 96 号: what the tug station's own tank (drawn off the hulks it pre-processed) pays of it, and
# what is left for cash
static func prop_from_tank(o: Dictionary) -> float:
	return minf(prop_cost(o), TugYard.tank() * TugYard.PROP_PRICE)


static func prop_cash(o: Dictionary) -> float:
	return prop_cost(o) - prop_from_tank(o)


static func net(o: Dictionary) -> float:
	return float(o.fee) - prop_cost(o) - SERVICE_FEE / float(WEAR_LIMIT)


static func new_offer() -> Dictionary:
	var d := data()
	d.n = int(d.n) + 1
	var rng := _rng(int(d.n))
	var from := rng.randi_range(0, Orbits.STATIONS.size() - 1)
	var to := rng.randi_range(-1, Orbits.STATIONS.size() - 1)
	if to == from:
		to = -1
	var t := snappedf(rng.randf_range(20.0, 120.0), 5.0)
	var tr := trip(from, to)
	var o := {"id": "CH-%03d" % int(d.n), "client": ["恒岳工业", "天衡物流", "远岫工场", "独立商户"][rng.randi_range(0, 3)], "from": from, "to": to, "t": t, "dv": float(tr[1]),
		"secs": float(tr[0]), "age": 0.0}
	# what the client pays: the costs and a margin — now and then a job that does not pay
	o.fee = snappedf((prop_cost(o) + SERVICE_FEE / float(WEAR_LIMIT)) * rng.randf_range(0.85, 1.8) + 1500.0, 100.0)
	d.offers.append(o)
	return o


static func where(i: int) -> String:
	return Orbits.name_of(Orbits.station(i)) if i >= 0 else Orbits.name_of(Orbits.PORT)


# the company's tugs: on charter, in the shop
static func away_tugs() -> Dictionary:
	var out := {}
	if not Career.usable() or Career.data.is_empty() or not Career.data.has("charter"):
		return out
	for j in data().jobs:
		out[str(j.tug)] = str(j.id)
	return out


static func in_service(tug: String) -> bool:
	return Career.usable() and not Career.data.is_empty() and Career.data.has("charter") and float(data().service.get(tug, 0.0)) > 0.0


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
	var tug := TugYard.ready_tug()
	if tug == "":
		return w("没有待命且充满电的自家拖船", "NO COMPANY TUG READY AND CHARGED")
	if by_auto and bool(d.auto.keep_one) and TugFleet.count() >= 2:
		var ready := 0
		for i in TugFleet.count():
			var n: String = TugFleet.NAMES[i]
			if TugFleet.home(i) and TugYard.charge(n) >= 1.0 and not in_service(n):
				ready += 1
		if ready < 2:
			return w("留一艘拖船给自己用", "ONE TUG KEPT FOR OUR OWN TOWS")
	if float(Career.data.get("money", 0.0)) < prop_cash(o):
		return w("推进剂要 %s，钱不够", "PROPELLANT %s: NOT ENOUGH CASH") % Pal.money(prop_cash(o))
	return ""


# taken: the propellant paid now, the tug away for the round trip
static func accept(id: String, by_auto := false) -> Dictionary:
	var why := accept_block(id, by_auto)
	if why != "":
		return {"ok": false, "reason": why}
	var d := data()
	var o := {}
	for x in d.offers:
		if str(x.id) == id:
			o = x
	var tug := TugYard.ready_tug()
	var by_tank := prop_from_tank(o)
	TugYard.set_tank(TugYard.tank() - by_tank / TugYard.PROP_PRICE)
	_cash(-prop_cash(o))
	d.offers.erase(o)
	var j := o.duplicate()
	j.tug = tug
	j.left = float(o.secs)
	d.jobs.append(j)
	Career.save()
	return {"ok": true, "tug": tug}


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
	if float(d.t) >= EVERY:
		d.t = 0.0
		if d.offers.size() < MAX_OPEN:
			var o := new_offer()
			said.append(w("%s 想租拖船：%s → %s，%.0f t，运费 %s", "%s WANTS A TUG: %s → %s, %.0f t, %s") % [str(o.client), where(int(o.from)), where(int(o.to)), float(o.t), Pal.money(float(o.fee))])
	for o in d.offers.duplicate():
		o.age = float(o.age) + dt
		if float(o.age) >= EXPIRE:
			d.offers.erase(o)
	for tug in d.service:
		if float(d.service[tug]) > 0.0:
			d.service[tug] = maxf(0.0, float(d.service[tug]) - dt)
	for j in d.jobs.duplicate():
		j.left = float(j.left) - dt
		if float(j.left) <= 0.0:
			d.jobs.erase(j)
			_cash(float(j.fee))
			var tug := str(j.tug)
			var c: Dictionary = Career.data.get("tug_charge", {})
			c[tug] = 0.0
			Career.data.tug_charge = c
			var last: Dictionary = Career.data.get("tug_last", {})
			last[tug] = "charter"
			Career.data.tug_last = last
			d.wear[tug] = int(d.wear.get(tug, 0)) + 1
			said.append(w("%s 跑完外运 %s 回港：收运费 %s", "%s BACK FROM %s: %s") % [tug, str(j.id), Pal.money(float(j.fee))])
			if int(d.wear[tug]) >= WEAR_LIMIT:
				d.wear[tug] = 0
				d.service[tug] = SERVICE_S
				_cash(-SERVICE_FEE)
				said.append(w("%s 跑满 %d 趟，进厂检修 %d 秒（%s）", "%s INTO THE SHOP FOR %d s") % ([tug, WEAR_LIMIT, int(SERVICE_S), Pal.money(SERVICE_FEE)] if Txt.zh else [tug, int(SERVICE_S)]))
	# within the player's bounds
	var a: Dictionary = d.auto
	if bool(a.on) and not bool(a.stop_new) and d.jobs.size() < int(a.max_jobs):
		for o in d.offers.duplicate():
			if net(o) >= float(a.min_net) and accept_block(str(o.id), true) == "":
				accept(str(o.id), true)
				said.append(w("自动接了外运 %s（预计净赚 %s）", "TOOK CHARTER %s (NET ~%s)") % [str(o.id), Pal.money(net(o))])
				break
	if not said.is_empty():
		Career.save()
	return said


static func status() -> String:
	var d := data()
	var parts: Array = [w("外运进行中 %d 单", "%d CHARTERS RUNNING") % d.jobs.size(), w("累计收入 %s · 成本 %s", "EARNED %s · SPENT %s") % [Pal.money(float(d.earned)), Pal.money(float(d.spent))]]
	for tug in d.service:
		if float(d.service[tug]) > 0.0:
			parts.append(w("%s 检修还剩 %d 秒", "%s IN THE SHOP %d s") % [tug, ceili(float(d.service[tug]))])
	return " · ".join(parts)
