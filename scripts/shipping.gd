class_name Shipping
# Orbital shipping (design/…/23 Q7–Q18 Q22 Q23 Q27 Q30, 31 号). The independent merchants keep
# their stock at belt stations (scripts/orbits.gd); a trade between them and the company is
# carried by a real freighter on a Lambert transfer, docks at the cargo district's pier, and
# the goods are real bodies the operator hauls into the warehouse (or into the hold, selling).
# The three big companies keep their counters in the port's trade district and stay on the
# local freight (scripts/exchange_logistics.gd). This file is the record and its rules; the
# pier, the hulls and the bodies are scripts/freight_pier.gd; the map is scripts/star_map.gd.
#
# A ship: {id, trade, dir ("in": goods to the port / "out": the buyer's hull comes for them),
#   station, length, state, slot, run (Orbits.transfer), pieces: [{key, mass, where}], ...}
# states: "inbound" (flying to the port) → "queued" (waiting off the pier) → "docked" →
#   "leaving" (flying home: empty, or with the goods for a buyer) → "gone"
# a piece's where: "hold" | "apron" (crew put it on the pier to free the berth: not stock yet)
#   | "deck" (selling: brought out of the warehouse to the pier) | "received" | "loaded"

const Exchange = preload("res://scripts/industrial_exchange.gd")
const PIECE_T := 2.0          # t: goods travel in bales / pallets of at most this much
const FIXED := 3              # merchant_00..02: the big three, local counters
const AUTO_MAX_T := 3.0       # Q10: the cargo district's crane takes pieces up to this
const NAMES := ["Kestrel", "Halden", "Marrow", "Tamsin", "Orrery", "Calder", "Sable", "Vigil", "Brenna", "Quill", "Ardent", "Lumen"]


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


static func data() -> Dictionary:
	if not Career.data.has("shipping"):
		Career.data.shipping = {"day": 0.0, "ships": [], "next": 1}
	return Career.data.shipping


static func day() -> float:
	return float(Career.data.get("shipping", {}).get("day", 0.0))


# the party across the trade from the company, "" when the company is not in it
static func other(trade: Dictionary) -> String:
	if str(trade.get("buyer", "")) == Exchange.PLAYER:
		return str(trade.get("seller", ""))
	if str(trade.get("seller", "")) == Exchange.PLAYER:
		return str(trade.get("buyer", ""))
	return ""


static func merchant_index(actor: String) -> int:
	if not actor.begins_with("merchant_"):
		return -1
	return int(actor.substr(9))


# a company trade with an independent merchant goes by freighter
static func orbital(trade: Dictionary) -> bool:
	return merchant_index(other(trade)) >= FIXED


static func station_of(actor: String) -> int:
	return posmod(merchant_index(actor) - FIXED, Orbits.STATIONS.size())


# the pier's berths (Q23): one to begin with, two and three with the cargo district's stages
static func slots() -> int:
	return clampi(1 + Port.stage("cargo"), 1, 3)


# the trade's freighter (gone ones too: goods it left on the apron are still its)
static func ship_for(trade_id: String) -> Dictionary:
	for s in data().ships:
		if str(s.trade) == trade_id:
			return s
	return {}


static func _pending(s: Dictionary) -> bool:
	return s.pieces.any(func(p): return str(p.where) in ["hold", "apron", "deck"])


static func trade_of(s: Dictionary) -> Dictionary:
	for t in Career.data.get("exchange", {}).get("trades", []):
		if str(t.id) == str(s.trade):
			return t
	return {}


static func live() -> Array:
	return data().ships.filter(func(s): return str(s.state) != "gone")


static func at_pier() -> Array:
	return live().filter(func(s): return str(s.state) == "docked")


# true days and the play time they take
static func eta_text(s: Dictionary) -> String:
	var run: Dictionary = s.get("run", {})
	if run.is_empty():
		return ""
	var left := maxf(0.0, float(run.depart) + float(run.tof) - day())
	var secs := int(ceil(left / Orbits.DAYS_PER_S))
	return w("还有 %d 天（约 %d:%02d）", "%d DAYS LEFT (~%d:%02d)") % [int(ceil(left)), secs / 60, secs % 60]


static func _pieces(trade: Dictionary, where: String) -> Array:
	var out: Array = []
	var q := float(trade.quantity)
	var n := int(ceil(q / PIECE_T - 1e-9))
	for k in n:
		var m := minf(PIECE_T, q - PIECE_T * k)
		out.append({"key": "SHIP:%s:%d" % [str(trade.id), k + 1], "mass": m, "where": where})
	return out


static func hull_length(quantity: float) -> float:
	# 40–80 m by the load (23 号 细节)
	return clampf(40.0 + quantity * 4.0, 40.0, 80.0)


# one step of the clock and the rules; `live_pier` false where no pier is built in this scene
# (a contract): ships still fly, dock and queue (Q25), nothing is hauled. Returns true when
# the record changed in a way worth saving.
static func tick(dt: float) -> bool:
	if not Career.data.get("market", false):
		return false
	# the calendar runs whether or not the exchange was ever opened: a tug sent from the star
	# map flies on it (user 2026-10-26: a new career's tug "never got any further")
	var d := data()
	d.day = float(d.day) + dt * Orbits.DAYS_PER_S
	if Career.data.get("exchange", {}).is_empty():
		return false
	var changed := _dispatch()
	var now := float(d.day)
	for s in d.ships:
		match str(s.state):
			"inbound":
				if now >= float(s.run.depart) + float(s.run.tof):
					s.state = "queued"
					s.arrived = now
					changed = true
			"leaving":
				if now >= float(s.run.depart) + float(s.run.tof):
					changed = true
					if str(s.dir) == "out":
						var r := Exchange.commit_delivery(str(s.trade), {"receiver": "orbital:" + str(Orbits.station(int(s.station))[0]), "mass_t": float(trade_of(s).get("quantity", 0.0))})
						if not r.ok:
							s.issue = str(r.get("reason", ""))
							continue
						# the commit replaced the career's record: mark the ship in the new one
						var fresh := ship_for(str(s.trade))
						fresh.state = "gone"
						Career.save()
						return true
					s.state = "gone"
	changed = _berth() or changed
	# keep the record short: the last 24 gone (never one with goods still on the apron)
	var gone: Array = d.ships.filter(func(s): return str(s.state) == "gone" and not _pending(s))
	if gone.size() > 24:
		d.ships = d.ships.filter(func(s): return not gone.has(s) or gone.find(s) >= gone.size() - 24)
	return changed


# new company trades with the belt: a freighter leaves the merchant's station now
static func _dispatch() -> bool:
	var changed := false
	var d := data()
	for t in Career.data.exchange.trades:
		if str(t.state) != "awaiting_dispatch" or not orbital(t) or not ship_for(str(t.id)).is_empty():
			continue
		var st := station_of(other(t))
		var run := Orbits.transfer(Orbits.station(st), Orbits.PORT, float(d.day))
		var id := "FV-%04d" % int(d.next)
		d.next = int(d.next) + 1
		var dir := "in" if str(t.buyer) == Exchange.PLAYER else "out"
		var ship := {"id": id, "name": NAMES[(int(d.next) * 7) % NAMES.size()], "trade": str(t.id), "dir": dir, "station": st,
			"length": hull_length(float(t.quantity)), "state": "inbound", "slot": -1, "run": run, "item": str(t.item), "grade": int(t.grade),
			"quantity": float(t.quantity), "pieces": _pieces(t, "hold" if dir == "in" else "deck")}
		d.ships.append(ship)
		t.cargo_key = "SHIP:" + str(t.id)
		t.transport = {"scope": "orbital", "ship": id}
		t.state = "in_transit" if dir == "in" else "loading"
		changed = true
	return changed


static func _free_slot() -> int:
	var used := {}
	for s in live():
		if str(s.state) == "docked":
			used[int(s.slot)] = true
	for k in slots():
		if not used.has(k):
			return k
	return -1


# the pier: queued ships take free berths in arrival order; a ship still holding goods
# the operator has not collected is unloaded onto the pier's apron by its crew only when
# the next ship needs the berth (Q22/Q27)
static func _berth() -> bool:
	var changed := false
	var queued: Array = live().filter(func(s): return str(s.state) == "queued")
	queued.sort_custom(func(a, b): return float(a.arrived) < float(b.arrived))
	for q in queued:
		var k := _free_slot()
		if k < 0:
			# the oldest inbound hull at the pier makes room
			var docked: Array = at_pier().filter(func(s): return str(s.dir) == "in")
			if docked.is_empty():
				break
			docked.sort_custom(func(a, b): return float(a.arrived) < float(b.arrived))
			var old: Dictionary = docked[0]
			for p in old.pieces:
				if str(p.where) == "hold":
					p.where = "apron"
			_leave(old)
			k = _free_slot()
			if k < 0:
				break
		q.state = "docked"
		q.slot = k
		q.docked_day = day()
		changed = true
	return changed


static func _leave(s: Dictionary) -> void:
	s.state = "leaving"
	s.slot = -1
	s.run = Orbits.transfer(Orbits.PORT, Orbits.station(int(s.station)), day())


# a piece reached the warehouse's receiver (in) or the hull's hold (out): the trade completes
# on the last one — at once for goods in, on the hull's arrival home for goods out (Q30)
static func piece_done(s: Dictionary, key: String) -> Dictionary:
	var before := Career.data
	Career.data = before.duplicate(true)
	var ship := ship_for(str(s.trade))
	var done := true
	for p in ship.pieces:
		if str(p.key) == key:
			p.where = "received" if str(ship.dir) == "in" else "loaded"
		if str(p.where) not in ["received", "loaded"]:
			done = false
	var result := {"ok": true, "complete": false}
	if done:
		if str(ship.dir) == "in":
			var r := Exchange.commit_delivery(str(ship.trade), {"receiver": "Warehouse", "mass_t": float(ship.quantity), "pieces": ship.pieces.size()})
			if not r.ok:
				Career.data = before
				return r
			result.proceeds = r.get("proceeds", 0.0)
			# the commit replaced the career's record: the ship is the new one's
			ship = ship_for(str(ship.trade))
			if str(ship.state) == "docked":
				_leave(ship)
			result.complete = true
		else:
			var t := trade_of(ship)
			t.state = "in_transit"
			_leave(ship)
			result.complete = true
	if not Career.save():
		Career.data = before
		return {"ok": false, "reason": "save_failed"}
	return result


# what's on the way and at the pier, for the ops screen and the guide
static func counts() -> Dictionary:
	var c := {"inbound": 0, "queued": 0, "docked": 0, "leaving": 0, "apron": 0, "to_haul": 0}
	for s in live():
		c[str(s.state)] = int(c.get(str(s.state), 0)) + 1
		for p in s.pieces:
			if str(p.where) == "apron":
				c.apron += 1
			# only goods coming in want hands; what was sold the buyer's crew loads (37 号)
			if str(s.state) == "docked" and str(p.where) == "hold":
				c.to_haul += 1
	return c
