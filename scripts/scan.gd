class_name Scan
# Finding hulks on the star map (68 号 §5): pick a belt sector, sweep it (~15 s), get 2–5 bare
# signals — some of them only rock or debris — then analyse one signal's EM signature (~10 s)
# to learn what it is. A hulk that is recognised goes on the found list (Career.data.offers,
# `find`), where the tug is sent for it exactly as before (ShipMarket.tow_find). The reach grows
# with the tug station and the trade district. A swept sector has nothing new for a while.
#
# Career.data.scan = {n, sectors: {"<station>": {at, sigs: [...]}}, job: {kind, sector, sig, left, total}}
# a signal: {id, sector, off: [x, y] AU from the station, strength, kind ship|rock|debris,
#            known, offer (ship only, hidden until known), what (rock/debris words)}

static var ON := true                  # legacy tests switch it off to get the old auto finds
# user 2026-10-26: "时间太长了" — the waits cut to what still reads as a sweep and an analysis
const SWEEP_S := 6.0
const ANALYZE_S := 4.0
const COOLDOWN_S := 90.0               # a swept sector has nothing new for this long
const SHIP_P := 0.45


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


static func data() -> Dictionary:
	if not Career.data.has("scan"):
		Career.data.scan = {"n": 0, "sectors": {}, "job": {}, "clock": 0.0}
	return Career.data.scan


# the belt stations from the nearest to the port outwards (by their orbits' size)
static func order() -> Array:
	var idx: Array = range(Orbits.STATIONS.size())
	var pa := float(Orbits.PORT[3])
	idx.sort_custom(func(a, b): return absf(float(Orbits.STATIONS[a][3]) - pa) < absf(float(Orbits.STATIONS[b][3]) - pa))
	return idx


# how many sectors the port can reach: three at the start, more with the tug station's
# stages, all of them once the trade district is open
static func reach() -> int:
	var port: Dictionary = Career.data.get("port", {})
	var n := 3 + 2 * mini(2, int(port.get("tug", 0)))
	if int(port.get("trade", 0)) >= 1:
		n += 3
	return mini(n, Orbits.STATIONS.size())


static func in_reach(sector: int) -> bool:
	return order().find(sector) in range(reach())


static func busy() -> bool:
	return not data().job.is_empty()


static func sector(i: int) -> Dictionary:
	return data().sectors.get(str(i), {})


static func signals(i: int) -> Array:
	return sector(i).get("sigs", [])


static func sig_of(id: String) -> Dictionary:
	for k in data().sectors:
		for s in data().sectors[k].sigs:
			if str(s.id) == id:
				return s
	return {}


# seconds before a sector has something new (0 = sweep now)
static func cooldown(i: int) -> float:
	var s := sector(i)
	if s.is_empty():
		return 0.0
	return maxf(0.0, float(s.at) + COOLDOWN_S - float(data().clock))


# why a sweep cannot start ("" = it can)
static func sweep_block(i: int) -> String:
	if busy():
		return w("正在%s，等它完成", "BUSY: %s") % job_text()
	if not in_reach(i):
		return w("太远了：修好拖船站或贸易区能扫得更远", "OUT OF REACH: MEND THE TUG STATION OR THE TRADE DISTRICT")
	var cd := cooldown(i)
	if cd > 0.0:
		return w("刚扫过，约 %d 秒后才会有新漂来的东西", "JUST SWEPT: SOMETHING NEW IN ABOUT %d s") % ceili(cd)
	return ""


static func sweep(i: int) -> Dictionary:
	var why := sweep_block(i)
	if why != "":
		return {"ok": false, "reason": why}
	data().job = {"kind": "sweep", "sector": i, "sig": "", "left": SWEEP_S, "total": SWEEP_S}
	Career.save()
	return {"ok": true}


static func analyze_block(id: String) -> String:
	var s := sig_of(id)
	if s.is_empty():
		return w("这个信号已经没了", "THAT SIGNAL IS GONE")
	if s.get("known", false):
		return w("已经分析过了", "ALREADY ANALYSED")
	if busy():
		return w("正在%s，等它完成", "BUSY: %s") % job_text()
	return ""


static func analyze(id: String) -> Dictionary:
	var why := analyze_block(id)
	if why != "":
		return {"ok": false, "reason": why}
	var s := sig_of(id)
	data().job = {"kind": "analyze", "sector": int(s.sector), "sig": id, "left": ANALYZE_S, "total": ANALYZE_S}
	Career.save()
	return {"ok": true}


static func job_text() -> String:
	var j: Dictionary = data().job
	if j.is_empty():
		return ""
	if str(j.kind) == "sweep":
		return w("扫描%s附近", "SWEEPING NEAR %s") % Orbits.name_of(Orbits.station(int(j.sector)))
	return w("分析信号 %s", "ANALYSING %s") % str(j.sig)


static func progress() -> float:
	var j: Dictionary = data().job
	if j.is_empty():
		return 0.0
	return clampf(1.0 - float(j.left) / maxf(0.01, float(j.total)), 0.0, 1.0)


# the clock runs while the game is played; returns what finished ({} when nothing did)
static func advance(dt: float) -> Dictionary:
	if not Career.usable() or Career.data.is_empty():
		return {}
	var d := data()
	d.clock = float(d.get("clock", 0.0)) + dt
	var j: Dictionary = d.job
	if j.is_empty():
		return {}
	j.left = float(j.left) - dt
	if float(j.left) > 0.0:
		return {}
	return finish()


# the running job done now (also the tests' way past the wait)
static func finish() -> Dictionary:
	var d := data()
	var j: Dictionary = d.job
	if j.is_empty():
		return {}
	d.job = {}
	var out := {"kind": str(j.kind), "sector": int(j.sector)}
	if str(j.kind) == "sweep":
		out.sigs = _sweep(int(j.sector))
	else:
		out.sig = _analyze(str(j.sig))
	Career.save()
	return out


static func _rng(salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([int(Career.data.get("seed", 0)), int(data().n), salt])
	return r


static func _sweep(i: int) -> Array:
	var d := data()
	var rng := _rng(i)
	var first: bool = d.sectors.is_empty()
	# the hulks already found keep their place; what was never analysed drifts on
	var sigs: Array = []
	var n := rng.randi_range(2, 5)
	var used := {}
	for o in Career.data.get("offers", []):
		used[str(o.get("ship", ""))] = true
	var ships := 0
	for k in n:
		d.n = int(d.n) + 1
		var s := {"id": "S-%03d" % int(d.n), "sector": i, "known": false,
			"off": [0.0, 0.0],
			"strength": snappedf(rng.randf_range(0.2, 1.0), 0.01)}
		# spread round the station so each can be told apart
		var v := Vector2.from_angle(TAU * (k + rng.randf_range(0.15, 0.85)) / n) * rng.randf_range(0.05, 0.12)
		s.off = [snappedf(v.x, 0.0001), snappedf(v.y, 0.0001)]
		var ship := rng.randf() < SHIP_P or (first and k == n - 1 and ships == 0)
		if ship:
			var o := Market.valid_offer(rng, Career.data, 1 if ships == 0 else Market.roll_stars(rng, Market.max_stars(int(Career.data.get("rep", 0))), Port.star_weight_of(Career.data)), used, "full", "salvage")
			if o.is_empty():
				ship = false
			else:
				used[str(o.ship)] = true
				o.find = true
				o.station = i
				s.offer = o
				ships += 1
		s.kind = "ship" if ship else ("rock" if rng.randf() < 0.6 else "debris")
		if not ship:
			s.what = _what(str(s.kind), rng)
		sigs.append(s)
	d.sectors[str(i)] = {"at": float(d.clock), "sigs": sigs}
	return sigs


static func _what(kind: String, rng: RandomNumberGenerator) -> String:
	if kind == "rock":
		var m := rng.randi_range(8, 60)
		return w("一块约 %d 米的镍铁小行星，不是船", "A NICKEL-IRON ROCK ABOUT %d m ACROSS, NOT A SHIP") % m if rng.randf() < 0.5 else w("一块约 %d 米的碳质小行星，不是船", "A CARBON ROCK ABOUT %d m ACROSS, NOT A SHIP") % m
	var bits := [w("一片旧太阳能板碎片", "A SHRED OF OLD SOLAR PANEL"), w("一截断掉的天线桁架", "A BROKEN ANTENNA TRUSS"), w("一个空推进剂罐，太小拖不回来", "AN EMPTY PROPELLANT TANK, TOO SMALL TO TOW")]
	return bits[rng.randi_range(0, bits.size() - 1)]


# the signature read: a hulk joins the found list with its tow quoted
static func _analyze(id: String) -> Dictionary:
	var s := sig_of(id)
	if s.is_empty():
		return {}
	s.known = true
	if str(s.kind) == "ship" and s.has("offer"):
		var o: Dictionary = s.offer.duplicate(true)
		o.scan_sig = id
		var q := ShipMarket.find_quote(o)
		o.fee = float(q.fee)
		o.tow_days = float(q.run.get("tof", 0.0)) if not q.run.is_empty() else 0.0
		var offers: Array = Career.data.get("offers", [])
		offers.append(o)
		Career.data.offers = offers
	return s


# what an analysed signal is, in a line
static func verdict(s: Dictionary) -> String:
	if not s.get("known", false):
		return w("未知信号 · 强度 %d%%", "UNKNOWN SIGNAL · STRENGTH %d%%") % int(float(s.strength) * 100.0)
	if str(s.kind) != "ship":
		return str(s.get("what", ""))
	var o: Dictionary = s.offer
	var ty := Market.type_of(str(o.ship))
	return w("是船：%s · %.0f m · 漂了 %d 年", "A HULK: %s · %.0f m · ADRIFT %d YEARS") % [type_name(str(o.ship)), float(ty.get("length", 0.0)), int(o.get("drift_years", 0))]


static func type_name(ship: String) -> String:
	var ty := Market.type_of(ship)
	return (ty.name[0] if Txt.zh else ty.name[1]) if ty.has("name") else ship


# the found hulks not yet sent for (indices into Career.data.offers)
static func found() -> Array:
	var out: Array = []
	var offers: Array = Career.data.get("offers", [])
	for i in offers.size():
		if offers[i].get("find", false):
			out.append(i)
	return out


# the line shown when a job finishes
static func done_text(r: Dictionary) -> String:
	if str(r.get("kind", "")) == "sweep":
		return w("扫描完成：%s附近收到 %d 个信号。打开星图（G）选一个分析。", "SWEEP DONE: %d SIGNALS NEAR %s. OPEN THE STAR MAP (G) TO ANALYSE ONE.") % ([Orbits.name_of(Orbits.station(int(r.sector))), r.get("sigs", []).size()] if Txt.zh else [r.get("sigs", []).size(), Orbits.name_of(Orbits.station(int(r.sector)))])
	var s: Dictionary = r.get("sig", {})
	if str(s.get("kind", "")) == "ship":
		return w("分析完成：%s。它那一行变成了“派拖船去拖”按钮。", "ANALYSED: %s. ITS ROW IS NOW THE TUG BUTTON.") % verdict(s)
	return w("分析完成：%s。", "ANALYSED: %s.") % verdict(s)
