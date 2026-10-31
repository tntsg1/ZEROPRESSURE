class_name ShipMarket
# The hulk market (design/…/01 §5–6, 33 号; G5.2). A third way to material besides taking a
# client's job or a hulk the tug found: buy a scrapped ship. Eight listings that stay until
# bought or expired. Each is a real ship whose true condition is fixed when it is listed — its
# traps (scripts/traps.gd), the very ones it will have in the berth. What the buyer sees:
#   the seller's statement, by category — accurate, played down, left out, or (now and then)
#     plainly false; sellers talk their ship up as a rule, not as a rare trick
#   a 1–10 rating with its agency, date and coverage — one agency is lenient and sometimes paid
#   two paid inspections, each reading one category truly (structure: what is seen and
#     measured on the hull; systems: what the records and the panels say)
#   the tow home on a Lambert transfer (scripts/orbits.gd), its Δv, days and fee
# Bought, the price and the tow are paid at once; the hulk is towed in and waits as an own-ship
# card on the contracts page (no fee, no client's goal, all its material the company's). After
# it is stripped, a plainly false statement about a category that did carry a trap can be
# claimed once, up to a cap.
# 41 号, the second version: resale (list an own hulk at a price; a buyer takes it at or under
# its fixed reservation price and pays at once), one counter-offer and a held quote per listing,
# and each agency's public record from the company's own stripped hulks (with a report to the
# survey registry when a rating proved false).

const LISTINGS := 8
const STRUCTURE := ["welded_hatch", "hidden_damage", "hidden_tank", "explosive_cargo", "gate_jam", "jacket_loss", "bio_breach"]
const AGENCIES := {
	"bsi": {"name": ["环带船检所 BSI", "BELT SURVEY INSTITUTE"], "covers": ["structure", "systems"], "bias": 0.0},
	"yx": {"name": ["远岫评估", "FAR PEAK APPRAISAL"], "covers": ["structure"], "bias": 0.5},
	"qr": {"name": ["快评社", "QUICKRATE"], "covers": ["systems"], "bias": 2.0},
}
const CLAIM_SHARE := 0.3
const CLAIM_CAP := 20000.0
const LIFE := Vector2(900.0, 1800.0)    # orbit days a listing stays (~10–20 min of play)
const HAGGLE_MIN := 0.8                  # a counter-offer is at least this share of the ask
const HOLD_SHARE := 0.02                 # the deposit that holds a quote
const HOLD_DAYS := 450.0                 # ~5 minutes of play
const RESALE_FEE := 0.03
const RESALE_WAIT := Vector2(90.0, 270.0)   # orbit days for a buyer to take it (1–3 minutes)
# 57 号: title defects, fixed when the listing is drawn
const TITLE_COST := 800.0                # the title search
const LIEN_SHARE := Vector2(0.08, 0.16)  # a yard's lien, a share of the ask
const WASTE_PER_M := 120.0               # hazardous-waste disposal, $ per metre of hull
const TITLE_ADMIT_CUT := 0.92            # a seller who says so takes this much off
const LOG_KEEP := 40                     # the agencies' public record: the last results kept


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


static func data() -> Dictionary:
	if not Career.data.has("ship_market"):
		Career.data.ship_market = {"seed": 1, "next": 1, "listings": [], "assets": []}
	return Career.data.ship_market


static func open() -> bool:
	return Career.data.get("market", false) and Port.stage("trade") >= 1


static func category(trap: String) -> String:
	return "structure" if trap in STRUCTURE else "systems"


static func trap_name(trap: String) -> String:
	return Txt.t("dt_" + trap)


# ---------------------------------------------------------------- listings

# keep eight: expired ones go, new ones are drawn from the market's own seed
static func refresh() -> bool:
	if not open():
		return false
	var d := data()
	var now := Shipping.day()
	var before: int = d.listings.size()
	# a held quote keeps its listing until the hold runs out; then the deposit is the seller's
	for l in d.listings:
		if l.has("hold") and float(l.hold.until) <= now:
			l.erase("hold")
			before = -1
	for l in d.listings:
		if float(l.expires) <= now and not l.has("hold") and not l.has("showcase"):
			_publish(l)
	# 108 号: a showcase stays until it is bought
	d.listings = d.listings.filter(func(l): return float(l.expires) > now or l.has("hold") or l.has("showcase"))
	var changed: bool = d.listings.size() != before
	var due := Methods.showcase_due()
	if due != "":
		var sl := _showcase(due)
		if not sl.is_empty():
			d.listings.push_front(sl)
			var sh: Dictionary = Career.data.get("showcases", {})
			sh[due] = "listed"
			Career.data.showcases = sh
			changed = true
	var tries := 0
	while d.listings.size() < LISTINGS and tries < 20:
		tries += 1
		var l := _make(int(d.seed))
		d.seed = int(d.seed) + 1
		if not l.is_empty():
			d.listings.append(l)
			changed = true
	return changed


# 108 号 Q14 A: a ship laid out for a method just learned — its borrow job's arrangement, the
# seller straight about it, a fair price; it stays listed until bought
static func _showcase(id: String) -> Dictionary:
	var ship := Methods.showcase_ship(id)
	if not Ship.available(ship):
		return {}
	var spec: Dictionary = Methods.SPEC.get(id, {})
	var o := Career.fixed_offer(ship, int(spec.get("seed", 990001)) + 7, spec.get("traps", null))
	if o.is_empty():
		return {}
	var d := data()
	o.id = "SM-%03d" % int(d.next)
	d.next = int(d.next) + 1
	o.bought = true
	o.drift_years = 0
	o.fee = 0.0
	o.showcase = id
	var ord := Scan.order()
	var station: int = int(ord[0]) if not ord.is_empty() else 0
	var traps: Array = o.get("traps", [])
	var statements: Array = []
	for cat in ["structure", "systems"]:
		var here: Array = traps.filter(func(t): return category(t) == cat)
		statements.append({"cat": cat, "how": "admitted" if not here.is_empty() else "clean", "traps": here})
	var now := Shipping.day()
	var price := snappedf(float(o.value) * 0.42, 500.0)
	return {"id": str(o.id), "offer": o, "station": station, "price": price, "statements": statements, "title": {"kind": ""},
		"rating": {"score": 9, "agency": "bsi", "day": now - 30.0, "paid": false}, "inspected": {}, "listed": now,
		"expires": now + 1.0e9, "floor": snappedf(price * 0.95, 100.0), "showcase": id}


static func _make(seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 7919 + 13
	var career := Career.data
	var stars := rng.randi_range(1, Market.max_stars(int(career.get("rep", 0))))
	var o := Market.valid_offer(rng, career, stars, {}, "full", "salvage")
	if o.is_empty():
		return {}
	var d := data()
	var id := "SM-%03d" % int(d.next)
	d.next = int(d.next) + 1
	o.id = id
	o.bought = true
	o.drift_years = 0
	o.fee = 0.0
	var station := rng.randi_range(0, Orbits.STATIONS.size() - 1)
	var traps: Array = o.get("traps", [])
	# what the seller says, category by category
	var statements: Array = []
	var false_said := false
	for cat in ["structure", "systems"]:
		var here: Array = traps.filter(func(t): return category(t) == cat)
		var how := "clean"
		if not here.is_empty():
			var r := rng.randf()
			how = "admitted" if r < 0.1 else ("downplayed" if r < 0.6 else ("omitted" if r < 0.85 else "false"))
		if how == "false":
			false_said = true
		statements.append({"cat": cat, "how": how, "traps": here})
	# the rating: the truth, an agency's bias, and its blind spots; the lenient one is sometimes paid
	var ag: String = ["bsi", "yx", "qr"][rng.randi_range(0, 2)]
	if false_said and rng.randf() < 0.5:
		ag = "qr"
	var seen := 0
	for t in traps:
		if category(t) in AGENCIES[ag].covers:
			seen += 1
	var score := clampi(int(round(9.0 - 2.0 * seen - 0.5 * (traps.size() - seen) + float(AGENCIES[ag].bias) + rng.randf_range(-0.8, 0.8))), 2, 10)
	var value := float(o.value)
	# what it costs: under the broker's value by how far it lies and how it is said to be
	var price := snappedf(value * rng.randf_range(0.42, 0.62) * (1.0 + 0.04 * (score - 6)), 500.0)
	var now := Shipping.day()
	# 57 号: a yard's lien or the waste liability, said or not (its own draw, the rest unchanged)
	var trng := RandomNumberGenerator.new()
	trng.seed = seed * 104729 + 31
	var title := {"kind": ""}
	var tr := trng.randf()
	if tr < 0.35:
		var kind := "lien" if tr < 0.2 else "waste"
		var length := float(Market.type_of(str(o.ship)).get("length", 30.0))
		var amount := snappedf(price * trng.randf_range(LIEN_SHARE.x, LIEN_SHARE.y), 100.0) if kind == "lien" else snappedf(length * WASTE_PER_M, 100.0)
		var how := "admitted" if trng.randf() < 0.4 else "omitted"
		if how == "admitted":
			price = snappedf(price * TITLE_ADMIT_CUT, 500.0)
		title = {"kind": kind, "amount": amount, "how": how}
	return {"id": id, "offer": o, "station": station, "price": price, "statements": statements, "title": title,
		"rating": {"score": score, "agency": ag, "day": now - rng.randf_range(20.0, 400.0), "paid": ag == "qr" and false_said},
		"inspected": {}, "listed": now, "expires": now + rng.randf_range(LIFE.x, LIFE.y),
		"floor": snappedf(price * rng.randf_range(0.82, 0.97), 100.0)}


# ---------------------------------------------------------------- the belt's finds (62 号)

# an unowned hulk found in the belt, as a listing the tow and the asset records understand
static func find_listing(o: Dictionary) -> Dictionary:
	var off := o.duplicate(true)
	off.bought = true
	off.found = true          # found in the belt, not bought: its card says so
	off.fee = 0.0
	off.erase("find")
	return {"id": str(o.id), "offer": off, "station": int(o.get("station", 0)), "price": 0.0, "statements": [],
		"title": {"kind": ""}, "rating": {"score": 0, "agency": "", "day": Shipping.day(), "paid": false},
		"inspected": {}, "found": true}


static func find_quote(o: Dictionary) -> Dictionary:
	return tow_quote(find_listing(o))


# 72 号: what sending for a find costs now — the quote, or half of it with a company tug charged
static func find_fee(o: Dictionary) -> float:
	var fee := float(o.get("fee", 0.0))
	return snappedf(fee * TugYard.OWN_FEE, 100.0) if TugYard.ready_tug() != "" else fee


# 80 号 Q2/Q4: a tow is never a dead end. The first one is on Liang (free); after that, short of
# cash, it goes on credit — taken out of the next settlement — one hulk on credit at a time.
#   {pay: what leaves the cash now, owe: what goes on credit, free: the first tow, ok, text}
static func tow_terms(o: Dictionary) -> Dictionary:
	var fee := find_fee(o)
	var d := Career.data
	if not d.get("seen", {}).get("first_tow", false):
		return {"ok": true, "pay": 0.0, "owe": 0.0, "free": true, "fee": fee,
			"text": w("首趟拖运：免费", "FIRST TOW: FREE")}
	if float(d.get("money", 0.0)) >= fee:
		return {"ok": true, "pay": fee, "owe": 0.0, "free": false, "fee": fee, "text": w("拖运费 %s", "TOW %s") % Pal.money(fee)}
	if float(d.get("tow_owed", 0.0)) > 0.0:
		return {"ok": false, "pay": 0.0, "owe": 0.0, "free": false, "fee": fee,
			"text": w("钱不够，上一艘的拖运费 %s 还赊着：拆完上一艘结算就还上", "SHORT OF CASH, AND THE LAST TOW (%s) IS STILL ON CREDIT: IT CLEARS AT THE NEXT SETTLEMENT") % Pal.money(float(d.tow_owed))}
	return {"ok": true, "pay": 0.0, "owe": fee, "free": false, "fee": fee,
		"text": w("先赊着：拖运费 %s 从下次结算里扣", "ON CREDIT: THE %s TOW COMES OUT OF THE NEXT SETTLEMENT") % Pal.money(fee)}


# send a tug for a find on the market page (offer index): the tow paid, the card gone, the hulk
# on its way home as an asset like any bought hulk (one transaction)
static func tow_find(i: int) -> Dictionary:
	var offers: Array = Career.data.get("offers", [])
	if i < 0 or i >= offers.size() or not offers[i].get("find", false):
		return {"ok": false, "reason": w("这艘船已经不在了", "THAT HULK IS GONE")}
	var o: Dictionary = offers[i]
	if not Market.fits(str(o.ship), Career.data):
		return {"ok": false, "reason": w("船坞放不下这艘船", "THE BERTH CANNOT TAKE IT")}
	# 72 号: a place in the tug yard, and a tug that can tow it
	var yb := TugYard.block(str(o.ship))
	if yb != "":
		return {"ok": false, "reason": yb}
	var l := find_listing(o)
	var q := tow_quote(l)
	# the fee the card quoted holds; the arc is flown from today; a company tug, charged, for half
	var tug := TugYard.ready_tug()
	var terms := tow_terms(o)
	if not terms.ok:
		return {"ok": false, "reason": str(terms.text)}
	# the first tow (the guide's) home in at most FIRST_S of play (user 2026-10-26: "时间太长了")
	# (the arc keeps its true flight for the drawing; the asset carries the shorter span)
	var span := minf(fast_days(float(q.run.tof)), FIRST_S * Orbits.DAYS_PER_S) if terms.free else fast_days(float(q.run.tof))
	q.fee = float(terms.pay)
	var before := Career.data
	Career.data = before.duplicate(true)
	var d := data()
	Career.data.money = float(Career.data.money) - float(terms.pay)
	if float(terms.owe) > 0.0:
		Career.data.tow_owed = float(terms.owe)
	var seen: Dictionary = Career.data.get("seen", {})
	seen["first_tow"] = true
	Career.data.seen = seen
	if Career.data.get("exchange", {}).has("actors"):
		Career.data.exchange.actors.company.cash = float(Career.data.money)
	Career.data.offers = Career.data.offers.filter(func(x): return str(x.get("id", "")) != str(o.id))
	d.assets.append({"id": str(o.id), "listing": l, "state": "towing", "run": q.run, "span": span, "tow": float(q.fee), "price": 0.0, "claimed": false, "mind": reservation(l), "found": true, "tug": tug})
	if not Career.save():
		Career.data = before
		return {"ok": false, "reason": w("保存失败，没扣钱", "SAVE FAILED")}
	return {"ok": true, "fee": float(q.fee), "days": span, "owe": float(terms.owe), "free": terms.free}


# the hulks on their way home: [{id, ship, left_s}], soonest first
static func on_the_way() -> Array:
	var out: Array = []
	if not Career.data.has("ship_market"):
		return out
	var now := Shipping.day()
	for a in data().assets:
		if str(a.state) == "towing":
			var left := maxf(0.0, float(a.run.depart) + tow_span(a) - now)
			out.append({"id": str(a.id), "ship": str(a.listing.offer.ship), "left_s": left / Orbits.DAYS_PER_S})
	out.sort_custom(func(x, y): return float(x.left_s) < float(y.left_s))
	return out


static func listing(id: String) -> Dictionary:
	for l in data().listings:
		if str(l.id) == id:
			return l
	return {}


# the seller's line for a category, in the market's words
static func statement_text(s: Dictionary) -> String:
	var cat: String = s.cat
	var head := w("结构：", "STRUCTURE: ") if cat == "structure" else w("系统：", "SYSTEMS: ")
	match str(s.how):
		"clean", "false":
			return head + (w("船体完整，无已知隐患。", "Hull sound, nothing known.") if cat == "structure" else w("正常停机，各系统已安全断开。", "Shut down properly, all systems safely isolated."))
		"admitted":
			var names: Array = []
			for t in s.traps:
				names.append(trap_name(t))
			return head + w("已知问题：%s。", "KNOWN: %s.") % "、".join(names)
		"downplayed":
			return head + (w("个别部位有维护痕迹，不影响拆解。", "Some maintenance marks; no bearing on stripping.") if cat == "structure" else w("停机前做过少量维护，个别回路未复核。", "Minor maintenance before shutdown; a few circuits not rechecked."))
	return head + w("（卖家未提）", "(NOT MENTIONED)")


# the paid inspection of a category: its price (by the hull's size) and what it finds
static func inspect_cost(l: Dictionary, cat: String) -> float:
	if cat == "title":
		return TITLE_COST
	var length := float(Market.type_of(str(l.offer.ship)).get("length", 30.0))
	return snappedf(length * (70.0 if cat == "structure" else 95.0), 100.0)


static func inspect(id: String, cat: String) -> Dictionary:
	var l := listing(id)
	if l.is_empty() or l.inspected.has(cat):
		return {"ok": false, "reason": w("没有这条挂牌", "NO SUCH LISTING")}
	var cost := inspect_cost(l, cat)
	if float(Career.data.money) < cost:
		return {"ok": false, "reason": w("检验费 %s，资金不足", "INSPECTION %s: NOT ENOUGH CASH") % Pal.money(cost)}
	var before := Career.data
	Career.data = before.duplicate(true)
	l = listing(id)
	Career.data.money = float(Career.data.money) - cost
	if cat == "title":
		l.inspected[cat] = [title_of(l).kind] if str(title_of(l).kind) != "" else []
	else:
		l.inspected[cat] = l.offer.traps.filter(func(t): return category(t) == cat)
	if not Career.save():
		Career.data = before
		return {"ok": false, "reason": w("保存失败，未扣款", "SAVE FAILED")}
	return {"ok": true, "found": l.inspected[cat]}


# the tow home: from the station on a Lambert arc; the contractor's fee by hull and Δv
static func tow_quote(l: Dictionary) -> Dictionary:
	if l.has("hold"):
		return {"run": l.hold.run, "fee": float(l.hold.fee)}
	var run := Orbits.transfer(Orbits.station(int(l.station)), Orbits.PORT, Shipping.day())
	var length := float(Market.type_of(str(l.offer.ship)).get("length", 30.0))
	var fee := snappedf(1500.0 + length * 30.0 + (float(run.dv1) + float(run.dv2)) * length * 1.5, 100.0)
	return {"run": run, "fee": fee}


static func fits(l: Dictionary) -> bool:
	return Market.fits(str(l.offer.ship), Career.data)


# bought: the price and the tow paid together, the listing closed, the tow under way
# (at the asking price, or at an accepted counter-offer; a held quote's deposit counts toward it)
static func buy(id: String, at_price := -1.0) -> Dictionary:
	var l := listing(id)
	if l.is_empty():
		return {"ok": false, "reason": w("挂牌已撤", "LISTING GONE")}
	if not fits(l):
		return {"ok": false, "reason": w("船坞放不下这艘船", "THE BERTH CANNOT TAKE IT")}
	var yb := TugYard.block(str(l.offer.ship))
	if yb != "":
		return {"ok": false, "reason": yb}
	var q := tow_quote(l)
	var tug := TugYard.ready_tug()
	if tug != "" and not l.has("hold"):
		q.fee = snappedf(float(q.fee) * TugYard.OWN_FEE, 100.0)
	var price := float(l.price) if at_price < 0.0 else at_price
	var deposit := float(l.hold.deposit) if l.has("hold") else 0.0
	var total := price + float(q.fee) - deposit
	if float(Career.data.money) < total:
		return {"ok": false, "reason": w("船款加拖运 %s，资金不足", "PRICE AND TOW %s: NOT ENOUGH CASH") % Pal.money(total)}
	var before := Career.data
	Career.data = before.duplicate(true)
	var d := data()
	l = listing(id)
	Career.data.money = float(Career.data.money) - total
	d.listings = d.listings.filter(func(x): return str(x.id) != id)
	d.assets.append({"id": id, "listing": l.duplicate(true), "state": "towing", "run": q.run, "tow": q.fee, "price": price, "claimed": false, "mind": reservation(l), "tug": tug})
	if not Career.save():
		Career.data = before
		return {"ok": false, "reason": w("保存失败，未扣款", "SAVE FAILED")}
	return {"ok": true, "total": total}


# one counter-offer per listing: at or over the seller's floor it is bought at that price
static func haggle(id: String, offer: float) -> Dictionary:
	var l := listing(id)
	if l.is_empty():
		return {"ok": false, "reason": w("挂牌已撤", "LISTING GONE")}
	if l.get("haggled", false):
		return {"ok": false, "reason": w("卖家已经拒绝过，不再谈", "THE SELLER HAS SAID NO")}
	if not is_finite(offer) or offer < float(l.price) * HAGGLE_MIN:
		return {"ok": false, "reason": w("还价不能低于标价的 %d%%", "NO LOWER THAN %d%% OF THE ASK") % int(HAGGLE_MIN * 100.0)}
	if offer >= float(l.price):
		return buy(id)
	if offer >= float(l.get("floor", float(l.price) * 0.9)):
		var r := buy(id, offer)
		if r.ok:
			r.accepted = true
		return r
	var before := Career.data
	Career.data = before.duplicate(true)
	listing(id).haggled = true
	if not Career.save():
		Career.data = before
		return {"ok": false, "reason": w("保存失败", "SAVE FAILED")}
	return {"ok": true, "accepted": false}


# a deposit holds the listing and its tow quote for a while; it counts toward the price
static func hold(id: String) -> Dictionary:
	var l := listing(id)
	if l.is_empty() or l.has("hold"):
		return {"ok": false, "reason": w("已经保留了", "ALREADY HELD")}
	var deposit := snappedf(float(l.price) * HOLD_SHARE, 10.0)
	if float(Career.data.money) < deposit:
		return {"ok": false, "reason": w("定金 %s，资金不足", "DEPOSIT %s: NOT ENOUGH CASH") % Pal.money(deposit)}
	var q := tow_quote(l)
	var before := Career.data
	Career.data = before.duplicate(true)
	l = listing(id)
	Career.data.money = float(Career.data.money) - deposit
	l.hold = {"deposit": deposit, "until": Shipping.day() + HOLD_DAYS, "run": q.run, "fee": float(q.fee)}
	if not Career.save():
		Career.data = before
		return {"ok": false, "reason": w("保存失败，未扣款", "SAVE FAILED")}
	return {"ok": true, "deposit": deposit}


# ---------------------------------------------------------------- resale (41 号)

# what a buyer would pay at most, fixed when the hulk is bought from what is known of it then
static func reservation(l: Dictionary) -> float:
	var k := 0.55
	for cat in ["structure", "systems"]:
		if l.inspected.has(cat):
			k += 0.08 - 0.06 * (l.inspected[cat] as Array).size()
		else:
			k -= 0.10
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(l.id)) + 4111
	k += rng.randf_range(-0.05, 0.05)
	return snappedf(float(l.offer.value) * maxf(0.15, k), 100.0)


# the buyer's mind for an own hulk now: in port is worth a little more (no tow for them)
static func mind(a: Dictionary) -> float:
	var base := float(a.get("mind", reservation(a.listing)))
	return base + (float(a.listing.offer.value) * 0.05 if str(a.state) == "arrived" else 0.0)


# the wide hint the market gives of what buyers might pay
static func interest(a: Dictionary) -> Array:
	var m := mind(a)
	return [snappedf(m * 0.8, 1000.0), snappedf(m * 1.15, 1000.0)]


static func can_resell(a: Dictionary) -> bool:
	return str(a.get("state", "")) in ["towing", "arrived"] and str(Career.data.get("active", {}).get("id", "")) != str(a.id)


static func resell(id: String, price: float) -> Dictionary:
	var a := asset(id)
	if a.is_empty() or not can_resell(a):
		return {"ok": false, "reason": w("这艘船现在不能挂牌", "IT CANNOT BE LISTED NOW")}
	if not is_finite(price) or price <= 0.0:
		return {"ok": false, "reason": w("价格不对", "BAD PRICE")}
	var before := Career.data
	Career.data = before.duplicate(true)
	a = asset(id)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id) + int(Shipping.day())
	a.resale = {"price": snappedf(price, 100.0), "due": Shipping.day() + rng.randf_range(RESALE_WAIT.x, RESALE_WAIT.y)}
	if not Career.save():
		Career.data = before
		return {"ok": false, "reason": w("保存失败", "SAVE FAILED")}
	return {"ok": true}


static func unlist(id: String) -> Dictionary:
	var a := asset(id)
	if a.is_empty() or not a.has("resale"):
		return {"ok": false, "reason": w("没有挂牌", "NOT LISTED")}
	var before := Career.data
	Career.data = before.duplicate(true)
	asset(id).erase("resale")
	if not Career.save():
		Career.data = before
		return {"ok": false, "reason": w("保存失败", "SAVE FAILED")}
	return {"ok": true}


# a listed hulk at or under the buyer's mind is taken when its buyer comes: paid at once
static func _sell(a: Dictionary) -> bool:
	if not a.has("resale") or not can_resell(a) or Shipping.day() < float(a.resale.due):
		return false
	if float(a.resale.price) > mind(a):
		return false
	var p := float(a.resale.price)
	Career.data.money = float(Career.data.money) + p * (1.0 - RESALE_FEE)
	if Career.data.get("exchange", {}).has("actors"):
		Career.data.exchange.actors.company.cash = float(Career.data.money)
	a.state = "sold"
	a.sold = {"price": p, "fee": p * RESALE_FEE, "day": Shipping.day()}
	a.erase("resale")
	Career.data.offers = Career.data.get("offers", []).filter(func(o): return str(o.get("id", "")) != str(a.id))
	return true


# ---------------------------------------------------------------- the agencies' records (41 号)

# 57 号: a listing that ran out went to another buyer; half the time their strip is published
static func _publish(l: Dictionary) -> void:
	if hash(str(l.id)) % 2 != 0:
		return
	var d := data()
	if not d.has("agency_log"):
		d.agency_log = []
	var r: Dictionary = l.rating
	d.agency_log.append({"ag": str(r.agency), "id": str(l.id), "score": int(r.score), "traps": l.offer.get("traps", []).size(), "paid": bool(r.get("paid", false)), "day": Shipping.day()})
	if d.agency_log.size() > LOG_KEEP:
		d.agency_log = d.agency_log.slice(d.agency_log.size() - LOG_KEEP)


# the score a fair agency covering everything would have given
static func fair_score(traps: int) -> int:
	return clampi(9 - 2 * traps, 2, 10)


# the agency's public results: how many, how many rated high, by how much on average, paid ones
static func public_record(ag: String) -> Dictionary:
	var out := {"n": 0, "over": 0, "by": 0.0, "paid": 0}
	var sum := 0.0
	for e in data().get("agency_log", []):
		if str(e.ag) != ag:
			continue
		out.n += 1
		var over := int(e.score) - fair_score(int(e.traps))
		if over >= 2:
			out.over += 1
			sum += over
		if e.get("paid", false):
			out.paid += 1
	out.by = sum / maxf(1.0, float(out.over))
	return out


static func public_text(ag: String) -> String:
	var r := public_record(ag)
	if int(r.n) == 0:
		return w("公开记录：还没有公开的拆解结果", "PUBLIC RECORD: NO RESULTS PUBLISHED YET")
	var s := w("公开记录：近 %d 份拆解结果，评高了 %d 份", "PUBLIC RECORD: %d RESULTS, %d RATED HIGH") % [int(r.n), int(r.over)]
	if int(r.over) > 0:
		s += w("（平均高 %.1f 分）", " (BY %.1f ON AVERAGE)") % float(r.by)
	if int(r.paid) > 0:
		s += w(" · 证实买来的评级 %d 份", " · %d PAID RATINGS PROVED") % int(r.paid)
	return s


# the player's own hulks it rated: each one's score against what was found
static func own_lines(ag: String) -> Array:
	var out: Array = []
	for a in data().assets:
		if str(a.listing.rating.agency) != ag or str(a.state) != "stripped":
			continue
		out.append(w("%s 评 %d/10 · 实际 %d 项隐患", "%s RATED %d/10 · %d HAZARDS FOUND") % [str(a.id), int(a.listing.rating.score), a.listing.offer.get("traps", []).size()])
	return out

# a rating that proved false on stripping: rated 7 or more while a side it covers carried a trap
static func misrated(a: Dictionary) -> bool:
	if str(a.get("state", "")) != "stripped":
		return false
	var r: Dictionary = a.listing.rating
	if int(r.score) < 7:
		return false
	for t in a.listing.offer.get("traps", []):
		if category(t) in AGENCIES[str(r.agency)].covers:
			return true
	return false


static func record(ag: String) -> Dictionary:
	var out := {"stripped": 0, "misrated": 0, "paid": 0}
	for a in data().assets:
		if str(a.listing.rating.agency) != ag or str(a.state) != "stripped":
			continue
		out.stripped += 1
		if a.get("reported", false):
			out.misrated += 1
			if a.listing.rating.get("paid", false):
				out.paid += 1
	return out


static func record_text(ag: String) -> String:
	var r := record(ag)
	var s := w("你拆过它评的船 %d 艘 · 举报证实失实 %d 份", "%d OF ITS HULKS STRIPPED · %d PROVED FALSE") % [int(r.stripped), int(r.misrated)]
	if int(r.paid) > 0:
		s += w(" · 利益关联已证实 %d 次", " · PAID RATINGS PROVED %d") % int(r.paid)
	return s


static func report(id: String) -> Dictionary:
	var a := asset(id)
	if a.is_empty() or not misrated(a) or a.get("reported", false):
		return {"ok": false, "reason": w("没有可举报的失实评级", "NOTHING TO REPORT")}
	var before := Career.data
	Career.data = before.duplicate(true)
	a = asset(id)
	a.reported = true
	if not Career.save():
		Career.data = before
		return {"ok": false, "reason": w("保存失败", "SAVE FAILED")}
	return {"ok": true, "paid": bool(a.listing.rating.get("paid", false))}


static func asset(id: String) -> Dictionary:
	for a in data().assets:
		if str(a.id) == id:
			return a
	return {}


# the clock: towed hulks arrive and become cards; stripped ones are marked from the history
# a find's tow time as its card says it (s of play): the first one is the short one
static func quote_s(o: Dictionary) -> int:
	var days := fast_days(float(o.get("tow_days", 0.0)))
	if tow_terms(o).free:
		days = minf(days, FIRST_S * Orbits.DAYS_PER_S)
	return int(days / Orbits.DAYS_PER_S)


# user 2026-10-28 ("拖船还是太慢了"): the orbital flights took 67–333 s of play; a tow now takes
# 15–45 s, the far ones still the longer (the arc as flown is only drawn faster)
const TOW_MIN_S := 15.0
const TOW_MAX_S := 45.0
const FIRST_S := 15.0                  # the guide's first tow
static func fast_days(tof: float) -> float:
	if tof <= 0.0:
		return 0.0
	var k := clampf((tof - 100.0) / 400.0, 0.0, 1.0)
	return minf(tof, lerpf(TOW_MIN_S, TOW_MAX_S, k) * Orbits.DAYS_PER_S)


# how long a tow takes (days): its orbital flight sped up, or the guide's shorter first tow
# (a tow already under way from an older save comes home on the faster time too)
static func tow_span(a: Dictionary) -> float:
	var tof := float(a.get("run", {}).get("tof", 0.0))
	return minf(float(a.get("span", tof)), fast_days(tof))


static func tick() -> bool:
	if not Career.data.has("ship_market"):
		return false
	var changed := false
	var now := Shipping.day()
	for a in data().assets:
		if _sell(a):
			changed = true
			continue
		if str(a.state) == "towing" and now >= float(a.run.depart) + tow_span(a):
			# 57 号: a lien or the waste bill holds it at the port until paid
			a.state = "held" if str(title_of(a.listing).kind) != "" else "arrived"
			# 72 号: it lies in the tug yard; the company tug that brought it charges
			TugYard.assign(a)
			TugYard.came_home(a)
			changed = true
		if str(a.state) in ["arrived", "stripping"]:
			for h in Career.data.get("history", []):
				if str(h.get("id", "")) == str(a.id):
					a.state = "stripped"
					changed = true
			if str(Career.data.get("active", {}).get("id", "")) == str(a.id) and str(a.state) == "arrived":
				a.state = "stripping"
				changed = true
	if cards():
		changed = true
	return changed


# an arrived hulk waits on the contracts page as its own card (while no job is in hand)
static func cards() -> bool:
	if not Career.active().is_empty():
		return false
	var offers: Array = Career.data.get("offers", [])
	var changed := false
	for a in data().assets:
		if str(a.state) != "arrived":
			continue
		if offers.any(func(o): return str(o.get("id", "")) == str(a.id)):
			continue
		var o: Dictionary = a.listing.offer.duplicate(true)
		o.paid = float(a.price) + float(a.tow)
		offers.push_front(o)
		changed = true
	if changed:
		Career.data.offers = offers
	return changed


# a plainly false statement about a category that did carry a trap, once the hulk was stripped
static func claimable(a: Dictionary) -> float:
	if str(a.state) != "stripped" or a.get("claimed", false):
		return 0.0
	for s in a.listing.statements:
		if str(s.how) == "false" and not s.traps.is_empty():
			return minf(CLAIM_CAP, float(a.price) * CLAIM_SHARE)
	return 0.0


# ---------------------------------------------------------------- title defects (57 号)

static func title_of(l: Dictionary) -> Dictionary:
	return l.get("title", {"kind": ""})


static func title_name(kind: String) -> String:
	match kind:
		"lien": return w("船坞欠款扣押", "YARD LIEN")
		"waste": return w("危险废物处置责任", "WASTE LIABILITY")
	return w("产权清楚", "CLEAR TITLE")


# the seller's line on the title
static func title_text(l: Dictionary) -> String:
	var t := title_of(l)
	if str(t.kind) != "" and str(t.how) == "admitted":
		return w("产权：%s %s，已在要价里让过。", "TITLE: %s %s, ALLOWED FOR IN THE ASK.") % [title_name(str(t.kind)), Pal.money(float(t.amount))]
	return w("产权：（卖家未提）", "TITLE: (NOT MENTIONED)")


# what holds a hulk at the port, in words
static func held_text(a: Dictionary) -> String:
	var t := title_of(a.listing)
	if str(t.kind) == "lien":
		return w("被前船坞扣押 · 欠款 %s，付清才放船", "HELD BY A YARD'S LIEN · %s TO RELEASE") % Pal.money(float(t.amount))
	return w("港务局开出危废处置费 %s，付清才能开工", "WASTE DISPOSAL BILLED %s · PAY TO START") % Pal.money(float(t.amount))


# pay what holds it: the money goes, the hulk is free (one transaction)
static func pay_title(id: String) -> Dictionary:
	var a := asset(id)
	if a.is_empty() or str(a.state) != "held":
		return {"ok": false, "reason": w("这艘船没有被扣着", "NOTHING HOLDS IT")}
	var due := float(title_of(a.listing).amount)
	if float(Career.data.money) < due:
		return {"ok": false, "reason": w("要付 %s，资金不足", "%s DUE: NOT ENOUGH CASH") % Pal.money(due)}
	var before := Career.data
	Career.data = before.duplicate(true)
	a = asset(id)
	Career.data.money = float(Career.data.money) - due
	if Career.data.get("exchange", {}).has("actors"):
		Career.data.exchange.actors.company.cash = float(Career.data.money)
	a.state = "arrived"
	a.title_paid = due
	if not Career.save():
		Career.data = before
		return {"ok": false, "reason": w("保存失败，未扣款", "SAVE FAILED")}
	cards()
	return {"ok": true, "paid": due}


# an unsaid defect, paid: claimable once, the amount paid, under the cap
static func title_claimable(a: Dictionary) -> float:
	if a.get("title_claimed", false) or float(a.get("title_paid", 0.0)) <= 0.0:
		return 0.0
	if str(title_of(a.listing).get("how", "")) != "omitted":
		return 0.0
	return minf(CLAIM_CAP, float(a.title_paid))


static func claim_title(id: String) -> Dictionary:
	var a := asset(id)
	var amount := title_claimable(a)
	if amount <= 0.0:
		return {"ok": false, "reason": w("没有可索赔的未披露产权问题", "NOTHING TO CLAIM")}
	var before := Career.data
	Career.data = before.duplicate(true)
	a = asset(id)
	a.title_claimed = true
	a.title_claim_paid = amount
	Career.data.money = float(Career.data.money) + amount
	if not Career.save():
		Career.data = before
		return {"ok": false, "reason": w("保存失败", "SAVE FAILED")}
	return {"ok": true, "amount": amount}


static func claim(id: String) -> Dictionary:
	var a := asset(id)
	var amount := claimable(a)
	if amount <= 0.0:
		return {"ok": false, "reason": w("没有可索赔的明确虚假声明", "NOTHING TO CLAIM")}
	var before := Career.data
	Career.data = before.duplicate(true)
	a = asset(id)
	a.claimed = true
	a.claim_paid = amount
	Career.data.money = float(Career.data.money) + amount
	if not Career.save():
		Career.data = before
		return {"ok": false, "reason": w("保存失败", "SAVE FAILED")}
	return {"ok": true, "amount": amount}
