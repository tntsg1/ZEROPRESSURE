class_name TugYard
# The tug station's yard (72 号; 69 号 Q4 C, Q5 A, Q13 C): every hulk towed home waits on an
# open-air berth outside the tug station — 1 / 2 / 4 of them by the station's stage — until the
# berth is free and it is pushed in; with the yard full no tug is sent. How long a ship the tugs
# can tow is the station's stage, not the grid; the grid sets how fast the company's own tugs
# charge between tows. A company tug that is charged tows for half the fee (fuel and wear
# only); otherwise the contractor's tug goes, at the full quote.
#   Career.data.tug_charge = {"TG-1": 0..1, …}; asset.yard = its berth in the yard; asset.tug = who towed it

const SLOTS := [1, 2, 4]
const MAX_LEN := [44.0, 88.0, 10000.0]   # m a stage's tugs can tow (stage 0: the rented tug)
const CHARGE_S := 60.0                   # s to charge a tug from flat at its full 3 MW
const OWN_FEE := 0.5                     # a company tug's share of the quote


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


static func stage() -> int:
	return clampi(Port.stage("tug"), 0, 2) if Career.usable() and not Career.data.is_empty() else 0


static func slots() -> int:
	return SLOTS[stage()]


static func max_len() -> float:
	return MAX_LEN[stage()]


static func can_tow(ship: String) -> bool:
	return float(Market.type_of(ship).get("length", 0.0)) <= max_len()


# the hulks that hold a place in the yard: on their way, home, or held at the port
static func taken() -> Array:
	if not Career.usable() or Career.data.is_empty() or not Career.data.has("ship_market"):
		return []
	return Career.data.ship_market.get("assets", []).filter(func(a): return str(a.get("state", "")) in ["towing", "arrived", "held"])


static func full() -> bool:
	return taken().size() >= slots()


# why nothing can be sent for this ship now ("" = it can)
static func block(ship: String) -> String:
	if full():
		return w("拖船站泊位满了（%d / %d）：先拆掉一艘，或扩建拖船站", "THE TUG YARD IS FULL (%d / %d): STRIP ONE, OR BUILD ON THE TUG STATION") % [taken().size(), slots()]
	if not can_tow(ship):
		return w("拖船拖不动 %.0f m 的船（现在最长 %.0f m）：先修拖船站", "THE TUGS CANNOT TOW %.0f m (UP TO %.0f m NOW): MEND THE TUG STATION") % [float(Market.type_of(ship).get("length", 0.0)), max_len()]
	return ""


# the yard's berth for a hulk that has come home: the lowest free one
static func assign(a: Dictionary) -> int:
	if a.has("yard"):
		return int(a.yard)
	var used := {}
	for b in taken():
		if b.has("yard") and str(b.id) != str(a.id):
			used[int(b.yard)] = true
	var i := 0
	while used.has(i):
		i += 1
	a.yard = i
	return i


# where a yard berth lies (px): open space past the tug station, outward from the hub, one
# above the other; a hulk's stern sits on the berth's mark. 96 号 (user 2026-10-28: "既然叫拖船站，
# 为什么船在外面？…伸一半进来，先固定，然后再运到拆船站", Q10 A): berth 1 is the station's own
# mouth in its left wall — a hulk low enough goes in stern first, up to DOCK_IN, under the gantry,
# to be moored, drained and fitted with the push frame (scripts/tug_works.gd); a taller one waits
# outside as before (it would not fit; nothing is drawn off it), like the hulks in berths 2–4.
const MOUTH := Vector2(12.6, 26.6)       # box-local m: the mouth's top and bottom
const DOCK_IN := 19.5                    # m: how far a stern goes in at most

static func mouth_h() -> float:
	return MOUTH.y - MOUTH.x


# how far this ship's stern goes into the station (m; below 0: it stays outside the wall)
static func dock_in(ship: String) -> float:
	if ship == "" or stage() < 1:
		return -0.6
	var d := Ship.load_data(ship)
	var y0 := INF
	var y1 := -INF
	var x0 := INF
	var x1 := -INF
	for pd in d.get("pieces", []):
		for q in pd.get("poly", []):
			x0 = minf(x0, float(q[0]))
			x1 = maxf(x1, float(q[0]))
			y0 = minf(y0, float(q[1]))
			y1 = maxf(y1, float(q[1]))
	if y1 - y0 > mouth_h() - 1.0 or x1 <= x0:
		return -0.6
	return minf(DOCK_IN, (x1 - x0) * 0.5)


static func slot_px(i: int, ship: String = "") -> Vector2:
	var box := PortStructure.box("tug")
	var M := Geom.M
	if i == 0 and dock_in(ship) > 0.0:
		return box.position + Vector2(dock_in(ship), (MOUTH.x + MOUTH.y) * 0.5) * M
	# a hulk too tall for the mouth (or a station not yet mended) waits outside as before
	return Vector2(box.position.x - 26.0 * M, box.position.y - 6.0 * M - float(i) * 34.0 * M)


# the hulk lying in the mouth now (its asset), or {}. in_hand: the game is in the empty berth, so a
# contract taken but not started (its loadout page closed) still lies here, waiting for its start
static func docked(in_hand := false) -> Dictionary:
	if not Career.usable() or Career.data.is_empty() or not Career.data.has("ship_market"):
		return {}
	for a in Career.data.ship_market.get("assets", []):
		var st := str(a.get("state", ""))
		if int(a.get("yard", -1)) == 0 and (st in ["arrived", "held"] or (in_hand and st == "stripping")) and dock_in(ship_of(a)) > 0.0:
			return a
	return {}


static func ship_of(a: Dictionary) -> String:
	return str(a.get("ship", a.get("listing", {}).get("offer", {}).get("ship", "")))


# ---------------------------------------------------------------- the company's tugs charging

static func charge(name: String) -> float:
	return float(Career.data.get("tug_charge", {}).get(name, 1.0)) if Career.usable() and not Career.data.is_empty() else 1.0


static func charging() -> Array:
	var out: Array = []
	for i in TugFleet.count():
		var n: String = TugFleet.NAMES[i]
		if charge(n) < 1.0 and TugFleet.home(i):
			out.append(n)
	return out


# a company tug, home and charged, for the next tow ("" = the contractor goes)
static func ready_tug() -> String:
	for i in TugFleet.count():
		var n: String = TugFleet.NAMES[i]
		if TugFleet.home(i) and charge(n) >= 1.0:
			return n
	return ""


# a tow done: the tug that flew it is flat
static func came_home(a: Dictionary) -> void:
	var n := str(a.get("tug", ""))
	if n == "":
		return
	var c: Dictionary = Career.data.get("tug_charge", {})
	c[n] = 0.0
	Career.data.tug_charge = c
	var last: Dictionary = Career.data.get("tug_last", {})
	last[n] = "own"
	Career.data.tug_last = last


# the grid's charge (Grid.demands asks for 3 MW a tug on charge); true when one became full
static func advance(game, dt: float) -> bool:
	var done := false
	var c: Dictionary = Career.data.get("tug_charge", {})
	for n in charging():
		var k := Grid.k(game, "tug_" + n)
		c[n] = minf(1.0, float(c.get(n, 0.0)) + dt * k / CHARGE_S)
		# 77 号: the charge is paid for
		if game != null and is_instance_valid(game):
			Grid.bill(game, "tug_" + n, dt)
		if float(c[n]) >= 1.0:
			done = true
	Career.data.tug_charge = c
	return done


# the line for the tug station and the star map: the yard and the tugs
static func status() -> String:
	var parts: Array = [w("拖船泊位 %d/%d", "YARD %d/%d") % [taken().size(), slots()], w("最大拖带船长 %s", "TOWS UP TO %s") % ("%.0f m" % max_len() if max_len() < 1000.0 else w("不限", "ANY LENGTH"))]
	for i in TugFleet.count():
		var n: String = TugFleet.NAMES[i]
		if not TugFleet.home(i):
			parts.append(w("%s 出航中", "%s AWAY") % n)
		elif charge(n) < 1.0:
			parts.append(w("%s 充电 %d%%", "%s CHARGING %d%%") % [n, int(charge(n) * 100.0)])
		else:
			parts.append(w("%s 待命", "%s READY") % n)
	return " · ".join(parts)


# ---------------------------------------------------------------- 96 号: the mouth's pre-processing
# Q11 B: the station draws off a share of a docked hulk's propellant by its stage — the rest is
# still the operator's to deal with in the berth — into the station's own tank (m³), which fuels
# the company's tugs.
const DRAIN := [0.0, 0.4, 0.7]
const TANK_M3 := 8.0
const PROP_PRICE := 4000.0               # $ a m³ of propellant, what the tank saves


static func drain_share() -> float:
	return DRAIN[stage()]


# m³ of propellant a ship carries
static func fuel_of(ship: String) -> float:
	var v := 0.0
	var vols: Dictionary = Ship.load_data(ship).get("fluids", {}).get("volumes", {}) if ship != "" else {}
	for k in vols:
		if str(vols[k].get("fluid", "")) == "fuel":
			v += float(vols[k].get("amount", 0.0))
	return v


static func tank() -> float:
	return float(Career.data.get("tug_prop", 0.0)) if Career.usable() and not Career.data.is_empty() else 0.0


static func set_tank(v: float) -> void:
	if Career.usable() and not Career.data.is_empty():
		Career.data.tug_prop = clampf(v, 0.0, TANK_M3)


# the pre-processing finished for a hulk: what was drawn off it goes into the tank
static func prepped(a: Dictionary, share: float) -> void:
	if a.is_empty() or a.has("prep"):
		return
	var got := fuel_of(ship_of(a)) * share
	a.prep = {"drained": share, "m3": got}
	set_tank(tank() + got)


# the share drawn off the hulk this game is stripping (0 for anything not brought in through the mouth)
static func drained_of(g) -> float:
	if g == null or not is_instance_valid(g) or g.get("job") == null or not Career.usable() or Career.data.is_empty() or not Career.data.has("ship_market"):
		return 0.0
	var a := ShipMarket.asset(str(g.job.get("id", "")))
	return float(a.get("prep", {}).get("drained", 0.0)) if not a.is_empty() else 0.0
