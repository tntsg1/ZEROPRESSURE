class_name TradePeople
# The trade port's people (75 号; 69 号 Q7 A, Q12 A). Individuals: independent merchants and
# owner-operators who come in their own small ships, one card each — who, what temper, buying or
# selling what, at what price — and are taken, haggled with (5 / 12 / 25 %) or sent away; a
# shrewd one may meet you halfway once, a hurried one leaves after a minute; whoever is refused
# or turned down leaves for good. Organisations: the three companies at the hall's counters each
# offer a standing contract — so many tonnes every ten minutes, so many times — delivered from
# the warehouse when due; reputation rises with each delivery, falls with each one missed, and
# the next contract pays more for it.
#   Career.data.visitors = {t, n, list: [...]}; Career.data.orgs = {who: {rep, offer, contract}}

const Exchange = preload("res://scripts/industrial_exchange.gd")
const TradeHall = preload("res://scripts/trade_hall.gd")
const EVERY := 120.0                  # s between arrivals (game time)
const MAX_HERE := 2
const ARRIVE_S := 8.0                 # s from the hall's approach to the pier
const HURRY_S := 60.0
const CUTS := {"small": 0.05, "medium": 0.12, "hard": 0.25}
const ACCEPT := {"frank": [0.9, 0.7, 0.35], "shrewd": [0.6, 0.35, 0.1], "hurry": [0.85, 0.6, 0.25]}
const BUY_GOODS := ["steel_billet:1", "steel_plate:1", "steel_section:1", "ferrous_scrap:1", "nonferrous_mix:0"]
const SELL_GOODS := ["ferrous_scrap:1", "steel_billet:1", "nonferrous_mix:0"]
const ORG_GOODS := ["steel_billet:1", "steel_plate:1", "steel_section:1"]
const PERIOD := 600.0                 # s between a contract's deliveries
const REP_K := 0.03
const REP_MIN := -3
static var lines: Array = []          # the author's lines due (data/台词.txt ids), said by the game


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


static func open() -> bool:
	return Career.usable() and not Career.data.is_empty() and Port.stage("trade") >= 1


static func vis() -> Dictionary:
	if not Career.data.has("visitors"):
		Career.data.visitors = {"t": 0.0, "n": 0, "list": []}
	return Career.data.visitors


static func here() -> Array:
	return vis().list.filter(func(v): return str(v.state) in ["arriving", "waiting", "countered"])


static func visitor(id: String) -> Dictionary:
	for v in vis().list:
		if str(v.id) == id:
			return v
	return {}


static func temper_name(t: String) -> String:
	return {"frank": w("爽快", "EASY-GOING"), "shrewd": w("精明", "SHREWD"), "hurry": w("急着要货", "IN A HURRY")}.get(t, t)


static func _rng(salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([int(Career.data.get("seed", 0)), salt])
	return r


static func _stock() -> Dictionary:
	return Career.data.get("exchange", {}).get("actors", {}).get("company", {}).get("stock", {})


static func _cash(delta: float) -> void:
	Career.data.money = float(Career.data.get("money", 0.0)) + delta
	if Career.data.get("exchange", {}).get("actors", {}).has("company"):
		Career.data.exchange.actors.company.cash = float(Career.data.money)


# someone new at the pier
static func arrive() -> Dictionary:
	var d := vis()
	d.n = int(d.n) + 1
	var rng := _rng(int(d.n) * 7919)
	var kind := "merchant" if rng.randf() < 0.55 else "owner"
	var temper: String = ["frank", "shrewd", "hurry"][rng.randi_range(0, 2)]
	var buys := rng.randf() < 0.6
	var key: String = (BUY_GOODS if buys else SELL_GOODS)[rng.randi_range(0, (BUY_GOODS if buys else SELL_GOODS).size() - 1)]
	var ref := Exchange.ref_price(key)
	var price := snappedf(ref * (rng.randf_range(0.95, 1.15) if buys else rng.randf_range(0.85, 1.05)), 10.0)
	var v := {"id": "V-%03d" % int(d.n), "kind": kind, "temper": temper, "want": "buy" if buys else "sell", "key": key,
		"qty": snappedf(rng.randf_range(0.5, 3.0), 0.5), "price": price, "state": "arriving", "t": 0.0, "left": HURRY_S, "salt": int(d.n)}
	d.list.append(v)
	# the pier remembers only the last few who came
	if d.list.size() > 12:
		d.list = d.list.slice(d.list.size() - 12)
	return v


static func card_name(v: Dictionary) -> String:
	return (w("独立商人 %s", "MERCHANT %s") if str(v.kind) == "merchant" else w("个体船主 %s", "OWNER-OPERATOR %s")) % str(v.id)


static func card_text(v: Dictionary) -> String:
	var what := w("想买 %s %.1f t，出 %s/t", "BUYS %s %.1f t AT %s/t") if str(v.want) == "buy" else w("想卖 %s %.1f t，要 %s/t", "SELLS %s %.1f t AT %s/t")
	var s := what % [Ops.item_name(str(v.key)), float(v.qty), Pal.money(float(v.price))]
	if str(v.temper) == "hurry":
		s += w(" · 还等 %d 秒", " · %d s LEFT") % ceili(float(v.left))
	if str(v.state) == "countered":
		s += w(" · 他回了个中间价", " · HE MET YOU HALFWAY")
	return s


# why a deal at this price cannot go through ("" = it can)
static func _short(v: Dictionary, price: float) -> String:
	if str(v.want) == "buy" and float(_stock().get(str(v.key), 0.0)) < float(v.qty) - 0.0001:
		return w("仓库里%s不够 %.1f t", "NOT %.1f t OF %s IN STOCK") % ([Ops.item_name(str(v.key)), float(v.qty)] if Txt.zh else [float(v.qty), Ops.item_name(str(v.key))])
	if str(v.want) == "sell" and float(Career.data.get("money", 0.0)) < price * float(v.qty):
		return w("钱不够 %s", "SHORT OF %s") % Pal.money(price * float(v.qty))
	return ""


static func _deal(v: Dictionary, price: float) -> Dictionary:
	var why := _short(v, price)
	if why != "":
		return {"ok": false, "reason": why}
	var st := _stock()
	var q := float(v.qty)
	if str(v.want) == "buy":
		st[str(v.key)] = float(st.get(str(v.key), 0.0)) - q
		_cash(price * q)
		Warehouse.ask_out("VIS:" + str(v.id), str(v.key), q, true)
	else:
		st[str(v.key)] = float(st.get(str(v.key), 0.0)) + q
		_cash(-price * q)
	v.state = "done"
	v.final = price
	Career.save()
	return {"ok": true, "price": price, "total": price * q}


static func accept(id: String) -> Dictionary:
	var v := visitor(id)
	if v.is_empty() or not str(v.state) in ["waiting", "countered"]:
		return {"ok": false, "reason": w("这位客人不在了", "GONE")}
	return _deal(v, float(v.price))


# a counter-offer: higher when he buys, lower when he sells; by his temper, taken, met halfway
# (shrewd, once) or he leaves
static func haggle(id: String, cut: String) -> Dictionary:
	var v := visitor(id)
	if v.is_empty() or str(v.state) != "waiting" or not CUTS.has(cut):
		return {"ok": false, "reason": w("现在不能还价", "CANNOT HAGGLE NOW")}
	var k: float = CUTS[cut]
	var asked := snappedf(float(v.price) * ((1.0 + k) if str(v.want) == "buy" else (1.0 - k)), 10.0)
	var why := _short(v, asked)
	if why != "":
		return {"ok": false, "reason": why}
	var rng := _rng(int(v.salt) * 31 + int(k * 100.0))
	var p: float = ACCEPT[str(v.temper)][["small", "medium", "hard"].find(cut)]
	if rng.randf() < p:
		var r := _deal(v, asked)
		r.said = "yes"
		if r.ok:
			lines.append("L_visit_deal")
		return r
	if str(v.temper) == "shrewd" and rng.randf() < 0.7:
		v.price = snappedf((float(v.price) + asked) * 0.5, 10.0)
		v.state = "countered"
		lines.append("L_visit_halfway")
		Career.save()
		return {"ok": true, "said": "halfway", "price": float(v.price)}
	v.state = "gone"
	lines.append("L_visit_leave")
	Career.save()
	return {"ok": true, "said": "no"}


static func refuse(id: String) -> Dictionary:
	var v := visitor(id)
	if v.is_empty() or str(v.state) in ["done", "gone"]:
		return {"ok": false, "reason": w("这位客人不在了", "GONE")}
	v.state = "gone"
	Career.save()
	return {"ok": true}


# ---------------------------------------------------------------- the companies

static func orgs() -> Dictionary:
	if not Career.data.has("orgs"):
		Career.data.orgs = {}
	for who in TradeHall.COMPANIES:
		if not Career.data.orgs.has(who):
			Career.data.orgs[who] = {"rep": 0, "offer": {}, "contract": {}, "n": 0}
	return Career.data.orgs


static func org_name(who: String) -> String:
	return str(Career.data.get("exchange", {}).get("actors", {}).get(who, {}).get("name", who))


static func _offer_for(who: String) -> Dictionary:
	var o: Dictionary = orgs()[who]
	if int(o.rep) < REP_MIN:
		return {}
	o.n = int(o.n) + 1
	var rng := _rng(hash(who) + int(o.n) * 104729)
	var key: String = ORG_GOODS[rng.randi_range(0, ORG_GOODS.size() - 1)]
	var k := clampf(1.0 + REP_K * float(o.rep), 0.8, 1.3)
	return {"key": key, "qty": snappedf(rng.randf_range(1.0, 2.0), 0.5), "price": snappedf(Exchange.ref_price(key) * k, 10.0), "times": 3}


static func take_contract(who: String) -> Dictionary:
	var o: Dictionary = orgs().get(who, {})
	if o.is_empty() or o.offer.is_empty() or not o.contract.is_empty():
		return {"ok": false, "reason": w("这家现在没有合同可接", "NO CONTRACT TO TAKE")}
	o.contract = o.offer.duplicate()
	o.contract.done = 0
	o.contract.next_in = PERIOD
	o.offer = {}
	Career.save()
	return {"ok": true}


# before the first delivery a contract can be handed back at no cost
static func drop_contract(who: String) -> Dictionary:
	var o: Dictionary = orgs().get(who, {})
	if o.is_empty() or o.contract.is_empty() or int(o.contract.done) > 0:
		return {"ok": false, "reason": w("已经开始交货，不能退", "DELIVERIES HAVE STARTED")}
	o.contract = {}
	Career.save()
	return {"ok": true}


# a delivery due: from the racks if there is enough; the reputation follows
static func _deliver(who: String) -> String:
	var o: Dictionary = orgs()[who]
	var c: Dictionary = o.contract
	var st := _stock()
	var key := str(c.key)
	c.done = int(c.done) + 1
	c.next_in = PERIOD
	var said := ""
	if float(st.get(key, 0.0)) >= float(c.qty) - 0.0001:
		st[key] = float(st.get(key, 0.0)) - float(c.qty)
		_cash(float(c.qty) * float(c.price))
		Warehouse.ask_out("ORG:%s:%d" % [who, int(c.done)], key, float(c.qty), true)
		o.rep = int(o.rep) + 1
		lines.append("L_org_deliver")
		said = w("按时给%s交了 %.1f t %s，信誉 +1。", "DELIVERED %.1f t TO %s: REPUTATION +1.") % ([org_name(who), float(c.qty), Ops.item_name(key)] if Txt.zh else [float(c.qty), org_name(who)])
	else:
		o.rep = int(o.rep) - 1
		lines.append("L_org_missed")
		said = w("没能按时给%s交货（%s不够），信誉 −1。", "MISSED A DELIVERY TO %s: REPUTATION −1.") % ([org_name(who), Ops.item_name(key)] if Txt.zh else [org_name(who)])
	if int(c.done) >= int(c.times):
		o.contract = {}
	return said


# ---------------------------------------------------------------- the clock

# returns the lines worth telling (arrivals, deals timed out, deliveries)
static func advance(dt: float) -> Array:
	var said: Array = []
	if not open():
		return said
	var d := vis()
	d.t = float(d.t) + dt
	if float(d.t) >= EVERY:
		d.t = 0.0
		if here().size() < MAX_HERE:
			var v := arrive()
			lines.append("L_visit_" + str(v.temper))
			said.append(w("%s开船来了（%s）。到贸易区业务终端看看他要什么。", "%s HAS COME IN (%s).") % [card_name(v), temper_name(str(v.temper))])
	for v in d.list:
		if str(v.state) == "arriving":
			v.t = float(v.t) + dt
			if float(v.t) >= ARRIVE_S:
				v.state = "waiting"
		elif str(v.state) in ["waiting", "countered"] and str(v.temper) == "hurry":
			v.left = float(v.left) - dt
			if float(v.left) <= 0.0:
				v.state = "gone"
				said.append(w("%s等不及，开船走了。", "%s COULD NOT WAIT AND LEFT.") % card_name(v))
	for who in orgs():
		var o: Dictionary = orgs()[who]
		if o.contract.is_empty():
			if o.offer.is_empty():
				o.offer = _offer_for(who)
			continue
		o.contract.next_in = float(o.contract.next_in) - dt
		if float(o.contract.next_in) <= 0.0:
			said.append(_deliver(who))
	if not said.is_empty():
		Career.save()
	return said
