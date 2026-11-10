class_name HallMarket
# 128 号 第 2 段 交易行与订单板 (design/成长版本/…/128_港区从头设计_仓库交易加工动力_2026-11-04.md §四 and
# “2026-11-05 第 2 段问答定案”). The exchange and the order board the trade port opens once mended
# (StoreBook.exchange_open()). The order book is hidden: the one action is 挂单.
#   卖 (listing): a thing leaves the warehouse and is offered at a price — the suggested one is the
#     market now, one key; who knows better sets their own on the price curve ("now above / below the
#     average"). It sells in real time, the nearer the market the sooner (fill_secs), less FEE.
#     Prices drift within ±DRIFT on their own, smoothly, a kind at a time (drift()).
#   买: other companies' machines and repair steel at a premium (BUY_K) over what one's own salvage is
#     worth. The one-key mending buys what it is short of here once the exchange is open.
#   订单: at most MAX_ORDERS at once, each wanting a kind of machine or a raw good and a quantity, at
#     ORDER_K of market (more with the reputation), due in real time (LIFE), no penalty when one
#     lapses. Taken, it is made up from the warehouse by itself (as goods come in, too); made up, the
#     freight trains carry it to the trade port (FreightWorks.order) and the client's small ship comes
#     for it (scripts/client_ships.gd). Done: paid, and the reputation grows; a higher one brings
#     bigger orders at better prices, the card shows its level.
# The state is Career.data.hall (saved with the career); `clock` is real seconds played since it opened.
# Static, as StoreBook: the headless tests run it without a scene.

const Exchange = preload("res://scripts/industrial_exchange.gd")
const RepairBill = preload("res://scripts/repair_bill.gd")
const FreightWorks = preload("res://scripts/freight_works.gd")
const ClientShips = preload("res://scripts/client_ships.gd")
const FEE := 0.05
const DRIFT := 0.10
const ORDER_K := 1.3
const BUY_K := 1.35
const MAX_ORDERS := 8
const FIRST_ORDERS := 3
const ORDER_GAP := Vector2(70.0, 140.0)    # s between two new orders (draft)
const LIFE := Vector2(600.0, 1200.0)       # s an order stands (10–20 min)
const FILL_T := 50.0                       # s a listing at the market takes to sell (draft)
const PRICE_MIN := 0.6                     # a listing's price, of the market now
const PRICE_MAX := 1.5
const RAIL_MAX := 45.0                     # s at most the trains take to bring an order to the port
const SHIP_IN := 9.0                       # s the client's ship takes in, alongside, out (client_ships.gd)
const SHIP_LOAD := 7.0
const SHIP_OUT := 8.0
const REP_AT := [0, 3, 8, 15, 25]          # reputation points for each level (draft)
const HIST_S := 1800.0                     # the price curve: the last half hour
# the kinds the board asks for and the exchange sells: what the one-key mending names, the raw goods
const KINDS := ["p_battery", "p_nav", "p_generator", "p_swb", "p_pump", "p_radiator", "p_compressor", "p_winch", "p_engine", "p_rcs", "p_fueltank"]
const RAWS := ["ferrous_scrap:1", "steel_billet:1", "steel_slab:1", "steel_small:1"]
const STEEL := "repair_steel"
static var ON := true          # tests of the older exchange switch it off
static var events: Array = []  # [{kind: "sold"/"done"/"new"/"gone", text}] drained by the HUD
static var _next_save := 0.0


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


static func open() -> bool:
	return ON and StoreBook.live() and StoreBook.exchange_open()


static func data() -> Dictionary:
	if Career.data.is_empty():
		return {}
	if not Career.data.has("hall"):
		Career.data.hall = {"v": 1, "clock": 0.0, "seq": 0, "listings": [], "orders": [], "rep": 0, "next_order": 0.0, "sold": [], "bought": [], "done_n": 0}
	return Career.data.hall


static func clock() -> float:
	return float(data().get("clock", 0.0))


static func _id(prefix: String) -> String:
	var h := data()
	h.seq = int(h.get("seq", 0)) + 1
	return "%s%d" % [prefix, int(h.seq)]


# ---------------------------------------------------------------- the prices

static func kind_of(u: Dictionary) -> String:
	if str(u.get("cat", "")) == "raw":
		return str(u.get("key", ""))
	if u.has("part"):
		return str(u.part.get("nk", ""))
	if u.has("good"):
		var gd: Dictionary = u.good
		return str(gd.get("nk", "")) if str(gd.get("fluid", "")) == "" else "fluid:" + str(gd.fluid)
	if u.has("stack"):
		return str(u.stack[0].get("nk", ""))
	return str(u.get("key", u.get("name", "")))


# a kind's price against its average, at a time (s of the hall's clock): two slow waves, ±DRIFT
static func drift(kind: String, at := NAN) -> float:
	if is_nan(at):
		at = clock()
	var h := float(hash(kind) % 100000) / 100000.0
	var a := 0.65 * sin(TAU * at / 900.0 + h * TAU) + 0.35 * sin(TAU * at / 360.0 + h * 17.0)
	return 1.0 + DRIFT * clampf(a, -1.0, 1.0)


# the curve the sell page draws: [[s ago, factor], …] oldest first
static func curve(kind: String, n := 61) -> Array:
	var out: Array = []
	var now := clock()
	for i in n:
		var ago := HIST_S * (1.0 - float(i) / float(n - 1))
		out.append([ago, drift(kind, now - ago)])
	return out


# what a warehouse unit fetches at market now (its average worth times the kind's drift)
static func market_now(u: Dictionary) -> float:
	return snappedf(float(u.get("market", 0.0)) * drift(kind_of(u)), 1.0)


static func suggest(u: Dictionary) -> float:
	return market_now(u)


static func net(price: float) -> float:
	return snappedf(price * (1.0 - FEE), 1.0)


# "现在比平均高 4%" / "低 3%" / "和平均差不多"
static func vs_avg_text(kind: String) -> String:
	var d := roundi((drift(kind) - 1.0) * 100.0)
	if d >= 1:
		return w("当前价格比平均价格高 %d%%", "%d%% ABOVE AVERAGE NOW") % d
	if d <= -1:
		return w("当前价格比平均价格低 %d%%", "%d%% BELOW AVERAGE NOW") % -d
	return w("当前价格接近平均价格", "ABOUT AVERAGE NOW")


# s a listing at `price` takes to sell against a market of `mkt`: the nearer, the sooner
static func fill_secs(price: float, mkt: float) -> float:
	if mkt <= 0.0:
		return INF
	var r := price / mkt
	if r <= 1.0:
		return maxf(8.0, FILL_T * exp(6.0 * (r - 1.0)))
	return FILL_T * exp(10.0 * (r - 1.0))


static func eta_text(secs: float) -> String:
	if secs < 60.0:
		return w("预计 %d 秒左右成交", "SELLS IN ~%d s") % maxi(5, int(round(secs / 5.0)) * 5)
	if secs < 3600.0:
		return w("预计 %d 分钟左右成交", "SELLS IN ~%d MIN") % maxi(1, int(round(secs / 60.0)))
	return w("当前价格下很难成交", "UNLIKELY TO SELL")


# ---------------------------------------------------------------- the warehouse: taking and giving back

static func _unit(id: String) -> Dictionary:
	for u in StoreBook.units():
		if str(u.id) == id:
			return u
	return {}


# take a warehouse unit out: -> payload {raw, t} / {part} / {goods: [...]}, or {} when it cannot be
static func _take(u: Dictionary) -> Dictionary:
	var id := str(u.id)
	var pos: Dictionary = Career.data.get("store_pos", {})
	match id.substr(0, 2):
		"r:":
			var got := StoreBook._take_raw(str(u.key), float(u.t))
			if got <= StoreBook.EPS:
				return {}
			StoreBook._close_up("r:" + str(u.key) + ":", int(id.get_slice(":", id.get_slice_count(":") - 1)))
			return {"raw": str(u.key), "t": got}
		"p:":
			if u.part.has("listed"):
				return {}
			Career.data.parts = Career.data.get("parts", []).filter(func(p): return str(p.uid) != str(u.part.uid))
			pos.erase(id)
			return {"part": u.part}
		"g:":
			Career.data.goods = StoreBook.goods().filter(func(gd): return str(gd.uid) != str(u.good.uid))
			pos.erase(id)
			return {"goods": [u.good]}
		"s:":
			var uids: Array = u.stack.map(func(gd): return str(gd.uid))
			Career.data.goods = StoreBook.goods().filter(func(gd): return not str(gd.uid) in uids)
			StoreBook._close_up("s:" + str(u.stack[0].get("nk", "")) + ":", int(id.get_slice(":", id.get_slice_count(":") - 1)))
			return {"goods": u.stack}
	return {}


static func _raw_in(key: String, t: float) -> void:
	if t <= 0.0005:
		return
	if key == Exchange.INGOT:
		StoreBook._add_raw(key, t, "hall", "")
		return
	var ex := StoreBook._ex()
	if ex.is_empty():
		ex = Exchange.fresh(float(Career.data.get("money", 0.0)))
		Career.data.exchange = ex
	var actor: Dictionary = ex.actors[Exchange.PLAYER]
	var st: Dictionary = actor.get("stock", {})
	st[key] = float(st.get(key, 0.0)) + t
	actor.stock = st
	var lots: Dictionary = actor.get("lots", {})
	var lid := _id("hall_lot:")
	lots[lid] = {"id": lid, "key": key, "available": t, "total": t, "origin": "hall_return"}
	actor.lots = lots


# a payload back into the warehouse: put away where it fits, else into 待入库
static func _give(pl: Dictionary, why := "hall") -> void:
	var items: Array = []
	if pl.has("raw"):
		items.append({"uid": _id("hr:"), "src": "raw", "key": str(pl.raw), "t": float(pl.t), "job": why, "ship": ""})
	if pl.has("part"):
		items.append({"uid": str(pl.part.uid), "src": "part", "part": pl.part, "job": why})
	for gd in pl.get("goods", []):
		items.append({"uid": str(gd.uid), "src": "goods", "good": gd, "job": why})
	for it in items:
		if str(it.src) == "raw" and str(it.key) != Exchange.INGOT:
			_raw_in(str(it.key), float(it.t))
			continue
		if not StoreBook._admit(it):
			var ib: Array = Career.data.get("inbox", [])
			ib.append(it)
			Career.data.inbox = ib


# ---------------------------------------------------------------- 卖: listings

static func listings() -> Array:
	return data().get("listings", [])


# list a warehouse unit (or an inbox item "i:…") at `price` (< 0: the suggested one). One save.
# -> {ok, name, price, net, secs, reason}
static func list(id: String, price := -1.0) -> Dictionary:
	if not open():
		return {"ok": false, "reason": StoreBook.exchange_closed_text()}
	var before := Career.data
	Career.data = before.duplicate(true)
	var result := _list_unit(id, price)
	if not result.ok or not Career.save():
		Career.data = before
		return result if not result.ok else {"ok": false, "reason": w("保存失败，请重新尝试", "SAVE FAILED")}
	return result


# One transaction for the quantity slider. It keeps one listing per bundle.
static func list_raw_bundles(ids: Array) -> Dictionary:
	if not open():
		return {"ok": false, "reason": StoreBook.exchange_closed_text()}
	var before := Career.data
	Career.data = before.duplicate(true)
	var by_id := {}
	for unit in StoreBook.units():
		if str(unit.id).begins_with("r:"):
			by_id[str(unit.id)] = unit
	var total := 0.0
	var tonnes := 0.0
	for id in ids:
		var unit: Dictionary = by_id.get(id, {})
		if unit.is_empty():
			Career.data = before
			return {"ok": false, "reason": w("这件物品目前无法挂单出售", "THIS CANNOT BE LISTED NOW")}
		by_id.erase(id)
		var result := _list_unit(str(id), -1.0, unit)
		if not result.ok:
			Career.data = before
			return result
		total += float(result.net)
		tonnes += float(result.tonnes)
	if not Career.save():
		Career.data = before
		return {"ok": false, "reason": w("保存失败，请重新尝试", "SAVE FAILED")}
	return {"ok": true, "net": total, "tonnes": tonnes}


static func _list_unit(id: String, price: float, known_raw: Dictionary = {}) -> Dictionary:
	var u := known_raw
	var pl := {}
	if id.begins_with("i:"):
		var ib: Array = Career.data.get("inbox", [])
		for it in ib.duplicate():
			if "i:" + str(it.uid) == id:
				u = StoreBook.inbox_entry(it)
				match str(it.src):
					"raw": pl = {"raw": str(it.key), "t": float(it.t)}
					"part": pl = {"part": it.part}
					_: pl = {"goods": [it.good]}
				ib.erase(it)
		Career.data.inbox = ib
	else:
		if u.is_empty():
			u = _unit(id)
		if not u.is_empty():
			pl = _take(u)
	if u.is_empty() or pl.is_empty() or float(u.get("market", 0.0)) <= 0.0:
		return {"ok": false, "reason": w("这件物品目前无法挂单出售", "THIS CANNOT BE LISTED NOW")}
	var mkt := market_now(u)
	if price < 0.0:
		price = mkt
	price = clampf(snappedf(price, 1.0), mkt * PRICE_MIN, mkt * PRICE_MAX)
	var lst := {"id": _id("L"), "name": str(u.name), "cat": str(u.cat), "kind": kind_of(u), "base": float(u.market), "price": price,
		"at": clock(), "prog": 0.0, "pl": pl, "qty": str(u.get("qty", "")), "ship": str(u.get("ship", "")), "tag": str(u.get("tag", "")),
		"nk": str(u.get("part", u.get("good", {})).get("nk", "")) if (u.has("part") or u.has("good")) else ""}
	var ls: Array = data().listings
	ls.append(lst)
	data().listings = ls
	return {"ok": true, "name": str(u.name), "price": price, "net": net(price), "secs": fill_secs(price, mkt), "id": str(lst.id), "tonnes": float(pl.get("t", 0.0))}


# what a listing's thing is worth at market now
static func listing_market(l: Dictionary) -> float:
	return snappedf(float(l.base) * drift(str(l.kind)), 1.0)


static func listing_left(l: Dictionary) -> float:
	var s := fill_secs(float(l.price), listing_market(l))
	return maxf(0.0, (1.0 - float(l.prog)) * s)


# withdraw a listing: the thing comes back to the warehouse (or 待入库 when there is no room)
static func cancel(lid: String) -> Dictionary:
	var before := Career.data
	Career.data = before.duplicate(true)
	var ls: Array = listings()
	for l in ls.duplicate():
		if str(l.id) == lid:
			ls.erase(l)
			data().listings = ls
			_give(l.pl)
			if not Career.save():
				Career.data = before
				return {"ok": false, "reason": w("保存失败，请重新尝试", "SAVE FAILED")}
			return {"ok": true, "name": str(l.name)}
	Career.data = before
	return {"ok": false, "reason": w("找不到这笔挂单", "NO SUCH LISTING")}


static func _fill(l: Dictionary) -> void:
	var cash := net(float(l.price))
	Career.data.money = float(Career.data.get("money", 0.0)) + cash
	if Career.data.get("exchange", {}).get("actors", {}).has(Exchange.PLAYER):
		Career.data.exchange.actors[Exchange.PLAYER].cash = float(Career.data.money)
	var sold: Array = data().get("sold", [])
	sold.append({"name": str(l.name), "price": float(l.price), "fee": float(l.price) - cash, "cash": cash, "at": clock()})
	if sold.size() > 30:
		sold = sold.slice(sold.size() - 30)
	data().sold = sold
	events.append({"kind": "sold", "text": w("交易行成交：%s 已出售 %s，扣除 5%% 手续费后，实际到账 %s", "SOLD ON THE EXCHANGE: %s FOR %s, LESS 5%%, %s PAID") % [str(l.name), Pal.money(float(l.price)), Pal.money(cash)]})
	FreightWorks.sell(str(l.cat), 1, w("交易行成交成功", "SOLD ON THE EXCHANGE"))


# ---------------------------------------------------------------- 买: other companies' goods

static var _rep_cache := {}
# a ship file's piece of a kind (for its picture and cells): [ship, tag, mass]
static func rep_piece(nk: String) -> Array:
	if _rep_cache.has(nk):
		return _rep_cache[nk]
	var out := ["", "", 0.5]
	for f in DirAccess.get_files_at(Ship.DIR):
		var base := f.get_basename()
		if not f.ends_with(".json") or base.begins_with("sp_") or base in ["arktest", "belt", "berth"] or base.ends_with("_course"):
			continue
		if FileAccess.get_file_as_string(Ship.DIR + f).find("\"" + nk + "\"") < 0:
			continue
		for pd in Ship.load_data(base).get("pieces", []):
			if str(pd.get("name_key", "")) == nk and str(pd.get("art", "")) != "" and str(pd.get("tag", "")) != "":
				out = [base, str(pd.tag), float(pd.get("mass", 0.5))]
				break
		if str(out[0]) != "":
			break
	_rep_cache[nk] = out
	return out


# the price on the buy page of one of a kind (machines: each; repair steel: a tonne)
static func buy_each(kind: String) -> float:
	if kind == STEEL:
		return snappedf(RepairBill.STEEL_PRICE * drift(STEEL), 10.0)
	return snappedf(RepairBill.kind_price(kind) * BUY_K * drift(kind), 10.0)


# what the buy page offers: [{kind, name, each, unit, seller, cat}]
static func offers() -> Array:
	var out: Array = []
	var sellers := sellers_list()
	for i in KINDS.size():
		var nk := str(KINDS[i])
		out.append({"kind": nk, "name": RepairBill.kind_name(nk), "each": buy_each(nk), "unit": w("台", "PC"), "seller": str(sellers[i % sellers.size()]), "cat": "equip"})
	out.append({"kind": STEEL, "name": w("修缮所需钢材", "REPAIR STEEL"), "each": buy_each(STEEL), "unit": "t", "seller": str(sellers[2]), "cat": "steel", "step": 5.0})
	return out


static func sellers_list() -> Array:
	return [w("恒岳工业", "HENGYUE INDUSTRIES"), w("天衡物流", "TIANHENG LOGISTICS"), w("远岫工场", "YUANXIU WORKS"), w("北辰船务", "BEICHEN SHIPPING")]


# a bought machine as a warehouse good (worth its market price there, not what was paid)
static func _new_machine(nk: String) -> Dictionary:
	var rp := rep_piece(nk)
	return {"uid": _id("buy:"), "cat": "equip", "nk": nk, "name": RepairBill.kind_name(nk), "value": RepairBill.kind_price(nk),
		"ship": str(rp[0]), "tag": str(rp[1]), "mass": float(rp[2]), "day": snappedf(Shipping.day(), 0.01), "bought": true}


# buy n of a kind (machines) or n t (repair steel): paid at once, into the warehouse. One save.
static func buy(kind: String, n: float) -> Dictionary:
	if not open():
		return {"ok": false, "reason": StoreBook.exchange_closed_text()}
	var each := buy_each(kind)
	var cash := snappedf(each * n, 1.0)
	if float(Career.data.get("money", 0.0)) + 0.5 < cash:
		return {"ok": false, "reason": w("现金不足，还需要 %s", "NOT ENOUGH CASH: %s SHORT") % Pal.money(cash - float(Career.data.get("money", 0.0)))}
	var before := Career.data
	Career.data = before.duplicate(true)
	var where := ""
	# 货船穿模 (user 2026-11-10: "货凭空冒出来了"): paid now, at this price, as before — but the goods come
	# on the seller's freighter to the trade port's east berth, and are in the stores once the dock's crane
	# has swung their crates out of its hold and the belt has run them into the intake (_land)
	var goods: Array = []
	if kind != STEEL:
		for i in int(n):
			goods.append(_new_machine(kind))
	var cs := clients()
	var dv := {"id": _id("D"), "seller": str(cs[(int(data().get("seq", 0)) * 5 + int(n)) % cs.size()]), "kind": kind, "n": n, "goods": goods,
		"steel": n if kind == STEEL else 0.0, "crates": clampi(int(ceil(n / 2.0)) if kind == STEEL else int(n), 1, 6), "at": clock(), "state": "wait"}
	var dl: Array = data().get("deliveries", [])
	dl.append(dv)
	data().deliveries = dl
	where = w("卖方货船送到贸易港东码头，卸下后入库", "ON THE SELLER'S FREIGHTER TO THE TRADE PORT, STORED ONCE UNLOADED")
	_pay(cash, kind, n)
	if not Career.save():
		Career.data = before
		return {"ok": false, "reason": w("保存失败，请重新尝试", "SAVE FAILED")}
	var name := w("修缮钢材：%.0f 吨", "%.0f t REPAIR STEEL") % n if kind == STEEL else "%s × %d" % [RepairBill.kind_name(kind), int(n)]
	return {"ok": true, "cash": cash, "name": name, "where": where}


static func _pay(cash: float, kind: String, n: float) -> void:
	Career.data.money = float(Career.data.get("money", 0.0)) - cash
	if Career.data.get("exchange", {}).get("actors", {}).has(Exchange.PLAYER):
		Career.data.exchange.actors[Exchange.PLAYER].cash = float(Career.data.money)
	var log: Array = data().get("bought", [])
	log.append({"kind": kind, "n": n, "cash": cash, "at": clock()})
	if log.size() > 30:
		log = log.slice(log.size() - 30)
	data().bought = log


# the one-key mending, once the exchange is open: what it was short of is bought here (the mending
# takes the cash; this only books the buys). No save.
static func log_repair_buys(rows: Array, steel_t: float) -> void:
	var log: Array = data().get("bought", [])
	for row in rows:
		if int(row.buy) > 0:
			log.append({"kind": str(row.nk), "n": int(row.buy), "cash": float(row.each) * int(row.buy), "at": clock(), "for": "repair"})
	if steel_t > 0.05:
		log.append({"kind": STEEL, "n": steel_t, "cash": buy_each(STEEL) * steel_t, "at": clock(), "for": "repair"})
	data().bought = log


# ---------------------------------------------------------------- 订单: the order board

static func orders() -> Array:
	return data().get("orders", [])


static func rep() -> int:
	return int(data().get("rep", 0))


static func level(pts := -1) -> int:
	if pts < 0:
		pts = rep()
	var lv := 1
	for i in REP_AT.size():
		if pts >= int(REP_AT[i]):
			lv = i + 1
	return lv


static func level_name(lv: int) -> String:
	return [w("新客户", "NEW"), w("老客户", "KNOWN"), w("信誉良好", "RELIABLE"), w("优质客户", "PREFERRED"), w("金牌客户", "GOLD")][clampi(lv - 1, 0, 4)]


static func level_text(lv := -1) -> String:
	if lv < 0:
		lv = level()
	return w("信誉等级：%d 级 · %s", "REPUTATION %d · %s") % [lv, level_name(lv)]


# points to the next level ("" at the top)
static func next_level_text() -> String:
	var lv := level()
	if lv >= REP_AT.size():
		return w("已经达到最高信誉等级", "AT THE TOP")
	return w("再完成 %d 张订单，就能升到 %d 级", "%d MORE ORDERS TO LEVEL %d") % [int(REP_AT[lv]) - rep(), lv + 1]


# an order pays its kind's average market price (no drift) times this, by the reputation level it
# was posted at: 1 级 130 %, each level 4 % more
static func order_k(lv: int) -> float:
	return ORDER_K + 0.04 * (lv - 1)


# what to do when the stores do not hold what an open order wants: two plain lines
static func short_ways(o: Dictionary) -> Array:
	var kind := str(o.kind)
	if str(o.cat) == "raw":
		if kind == Exchange.INGOT:
			return [w("钢锭数量不足。拆船时可以用熔炉把碎料炼成钢锭，带回来的钢锭会直接存入仓库。", "SHORT OF INGOTS: THE BERTH'S FURNACE CASTS THEM FROM THE SCRAP"), w("交易行没有钢锭出售，需要自己熔炼获得。", "THE EXCHANGE SELLS NONE: YOUR OWN ONLY")]
		return [w("%s数量不足。可以在订单卡上点击「为这单排产」，也可以打开仓库，选择钢锭并点击「炼成钢坯」。", "SHORT: PRESS 'PLAN FOR THIS ORDER' ON THE CARD, OR CAST INGOTS IN THE STORES") % StoreBook.raw_name(kind), w("交易行没有出售这种材料，只能自己加工获得。", "THE EXCHANGE SELLS NONE: YOUR OWN ONLY")]
	var lack := maxi(1, int(round(float(o.n) - have_of("equip", kind))))
	var each := buy_each(kind)
	var gain := float(o.price) / maxf(float(o.n), 1.0) - each
	var l2 := w("也可以在「购买」页面购买 %d 台（每台 %s，", "OR BUY %d ON THE BUY PAGE (%s EACH, ") % [lack, Pal.money(each)]
	l2 += (w("完成订单后，每台还能赚取 %s）", "%s MORE EACH ON DELIVERY)") % Pal.money(gain)) if gain >= 0.0 else (w("购买后用于交付订单，每台会亏损 %s）", "%s LOST EACH)") % Pal.money(-gain))
	return [w("找一艘装有%s的船进行拆解，只要完整拆下设备，就会自动存入仓库。", "SALVAGE A HULK WITH A %s: WHOLE ONES GO TO THE STORES") % RepairBill.kind_name(kind), l2]


static func clients() -> Array:
	return [w("港务维修队", "PORT MAINTENANCE"), w("远岫工场", "YUANXIU WORKS"), w("恒岳工业", "HENGYUE INDUSTRIES"), w("北辰船务", "BEICHEN SHIPPING"),
		w("青石矿业", "QINGSHI MINING"), w("天衡物流", "TIANHENG LOGISTICS"), w("环带拖船队", "BELT TUG FLEET"), w("星港建设", "STARPORT BUILDERS")]


static func want_name(o: Dictionary) -> String:
	if str(o.cat) == "raw":
		return "%s %.0f t" % [StoreBook.raw_name(str(o.kind)), float(o.n)]
	return "%s × %d" % [RepairBill.kind_name(str(o.kind)), int(o.n)]


# one unit of what an order wants, at market (its average worth)
static func want_base(cat: String, kind: String) -> float:
	return StoreBook.raw_price(kind) if cat == "raw" else RepairBill.kind_price(kind)


# what the warehouse holds of an order's kind: t (raw) or machines
static func have_of(cat: String, kind: String) -> float:
	if cat == "raw":
		return float(StoreBook.raw_stock().get(kind, 0.0))
	return float(RepairBill.own_of(kind).size())


static func _rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash("%s|%d" % [str(Career.data.get("seed", "zp")), int(data().get("seq", 0))])
	return r


# a new order: half the time a kind the warehouse holds (so one can be met at once), else any
static func _new_order() -> Dictionary:
	var r := _rng()
	var lv := level()
	var cat := "equip"
	var kind := ""
	var held: Array = []
	for k in KINDS:
		if have_of("equip", k) >= 1.0:
			held.append(["equip", k])
	for k in RAWS:
		if have_of("raw", k) >= 2.0:
			held.append(["raw", k])
	if not held.is_empty() and r.randf() < 0.55:
		var pick: Array = held[r.randi() % held.size()]
		cat = str(pick[0])
		kind = str(pick[1])
	elif r.randf() < 0.3:
		cat = "raw"
		kind = str(RAWS[r.randi() % RAWS.size()])
	else:
		kind = str(KINDS[r.randi() % KINDS.size()])
	var n := 0.0
	if cat == "raw":
		n = 2.0 * (1 + r.randi() % (1 + lv))
	else:
		n = float(1 + r.randi() % (1 + (lv - 1) / 2))
	var k := order_k(lv)
	var cs := clients()
	var o := {"id": _id("O"), "client": str(cs[r.randi() % cs.size()]), "cat": cat, "kind": kind, "n": n, "lv": lv,
		"price": snappedf(want_base(cat, kind) * n * k, 10.0), "k": k, "at": clock(),
		"due": clock() + r.randf_range(LIFE.x, LIFE.y), "state": "open", "got": 0.0, "held": []}
	return o


static func live_orders() -> Array:
	return orders().filter(func(o): return str(o.state) in ["open", "taken", "rail", "ship"])


static func order(oid: String) -> Dictionary:
	for o in orders():
		if str(o.id) == oid:
			return o
	return {}


# take an order: from then on it is made up from the warehouse by itself. One save.
static func take(oid: String) -> Dictionary:
	if not open():
		return {"ok": false, "reason": StoreBook.exchange_closed_text()}
	var before := Career.data
	Career.data = before.duplicate(true)
	var o := order(oid)
	if o.is_empty() or str(o.state) != "open":
		Career.data = before
		return {"ok": false, "reason": w("这笔订单已经不存在了", "THIS ORDER IS GONE")}
	o.state = "taken"
	o.taken_at = clock()
	_make_up(o)
	if not Career.save():
		Career.data = before
		return {"ok": false, "reason": w("保存失败，请重新尝试", "SAVE FAILED")}
	return {"ok": true, "client": str(o.client), "got": float(o.got), "n": float(o.n), "state": str(o.state)}


# give an order back (before it is on its way): what was put aside returns to the warehouse
static func drop(oid: String) -> Dictionary:
	var before := Career.data
	Career.data = before.duplicate(true)
	var o := order(oid)
	if o.is_empty() or not str(o.state) in ["open", "taken"]:
		Career.data = before
		return {"ok": false, "reason": w("订单已经开始配送，无法取消", "ALREADY ON ITS WAY")}
	for pl in o.held:
		_give(pl, "order_back")
	o.held = []
	o.got = 0.0
	o.state = "open" if clock() < float(o.due) else "gone"
	if not Career.save():
		Career.data = before
		return {"ok": false, "reason": w("保存失败，请重新尝试", "SAVE FAILED")}
	return {"ok": true}


# 备货: put aside from the warehouse what a taken order still lacks; all there, it goes by train
static func _make_up(o: Dictionary) -> bool:
	if str(o.state) != "taken":
		return false
	var lack := float(o.n) - float(o.got)
	var moved := false
	if str(o.cat) == "raw":
		var got := StoreBook._take_raw(str(o.kind), lack)
		if got > 0.0005:
			o.held.append({"raw": str(o.kind), "t": got})
			o.got = float(o.got) + got
			moved = true
	else:
		var mine: Array = RepairBill.own_of(str(o.kind)).slice(0, int(round(lack)))
		for m in mine:
			var id := str(m.id)
			var u := _unit(id)
			if u.is_empty():
				continue
			var pl := _take(u)
			if not pl.is_empty():
				o.held.append(pl)
				o.got = float(o.got) + 1.0
				moved = true
	if float(o.got) >= float(o.n) - 0.0005:
		o.state = "rail"
		o.rail_at = clock()
		o.crates = clampi(int(ceil(float(o.n) / (2.0 if str(o.cat) == "raw" else 1.0))), 1, 2)
		o.sent = FreightWorks.ship_order(str(o.id), int(o.crates), want_name(o))
	return moved


static func _settle(o: Dictionary) -> void:
	FreightWorks.order_done(str(o.id))
	o.state = "done"
	o.done_at = clock()
	o.held = []
	var cash := float(o.price)
	Career.data.money = float(Career.data.get("money", 0.0)) + cash
	if Career.data.get("exchange", {}).get("actors", {}).has(Exchange.PLAYER):
		Career.data.exchange.actors[Exchange.PLAYER].cash = float(Career.data.money)
	var lv0 := level()
	data().rep = rep() + 1
	data().done_n = int(data().get("done_n", 0)) + 1
	var up := level() > lv0
	var s := w("订单完成：%s 已收取 %s，收到货款 %s，信誉 +1", "ORDER DONE: %s TOOK %s, %s PAID · REPUTATION +1") % [str(o.client), want_name(o), Pal.money(cash)]
	if up:
		s += w(" · 信誉提升至 %d 级，可以接到数量更多、收购价格更高的订单", " · NOW LEVEL %d: BIGGER ORDERS, BETTER PRICES") % level()
	events.append({"kind": "done", "text": s})


# where a pick-up stands: ["in" / "load" / "out", 0 … 1] (the client ship's timeline). Alongside it
# waits for the dock's crane to load it while someone is there to see it (watched), else SHIP_LOAD.
static var watched := false
const LOAD_MAX := 30.0
static func ship_phase(o: Dictionary) -> Array:
	var s := clock() - float(o.get("ship_at", clock()))
	if s < SHIP_IN:
		return ["in", s / SHIP_IN]
	if not o.has("out_at"):
		return ["load", clampf((s - SHIP_IN) / SHIP_LOAD, 0.0, 1.0)]
	return ["out", clampf((clock() - float(o.out_at)) / SHIP_OUT, 0.0, 1.0)]


# the dock's crane has the order's crates aboard
static func mark_loaded(oid: String) -> void:
	var o := order(oid)
	if not o.is_empty():
		o.loaded = true


# ---------------------------------------------------------------- the east berth (货船穿模 2026-11-10)
# One ship alongside at a time, pick-ups and deliveries alike; the next one starts in only once the last
# is out past FAR (client_ships.gd), so two never meet on the approach. Leaving, a ship is drawn till then
# too — the order is paid half-way out as before, but the ship is not taken off the screen with it.
static func deliveries() -> Array:
	return data().get("deliveries", [])


static func delivery(id: String) -> Dictionary:
	for d in deliveries():
		if str(d.id) == id:
			return d
	return {}


# s from its out_at a ship takes to be out past FAR (its leaving burn runs on, client_ships._leave)
static func leave_secs() -> float:
	return ClientShips.leave_secs()


static func _on_berth(e: Dictionary) -> bool:
	if not e.has("ship_at"):
		return false
	return not e.has("out_at") or clock() - float(e.out_at) < leave_secs()


static func berth_busy() -> bool:
	return orders().any(func(o): return str(o.state) in ["ship", "done"] and _on_berth(o)) or deliveries().any(func(d): return str(d.state) == "ship" and _on_berth(d))


# the dock may let a ship go: its crane is home and its boom in (or nobody is in the port to work it)
static func dock_clear(job_id: String) -> bool:
	if not watched:
		return true
	var TW = ClientShips.TW
	if float(TW.boom) > 0.0:
		return false
	if TW.job.is_empty() or str(TW.job.get("id", "")) != job_id:
		return true
	return bool(TW.job.get("done", true)) or bool(TW.job.get("ship_free", false))


# the dock's crane has finished with this ship (its crates in, or out on the belt)
static func dock_done(job_id: String) -> bool:
	var TW = ClientShips.TW
	return not TW.job.is_empty() and str(TW.job.get("id", "")) == job_id and (bool(TW.job.get("done", false)) or bool(TW.job.get("ship_free", false)))


# the crates are through the intake: the delivery's goods are in the stores now
static func mark_unloaded(id: String) -> void:
	var d := delivery(id)
	if not d.is_empty() and not bool(d.get("landed", false)):
		_land(d)


static func _land(d: Dictionary) -> void:
	d.landed = true
	d.landed_at = clock()
	var inbox_n := 0
	if str(d.kind) == STEEL:
		Career.data.structure_t = float(Career.data.get("structure_t", 0.0)) + float(d.steel)
	else:
		for gd in d.goods:
			var it := {"uid": str(gd.uid), "src": "goods", "good": gd, "job": "hall_buy"}
			if not StoreBook._admit(it):
				var ib: Array = Career.data.get("inbox", [])
				ib.append(it)
				Career.data.inbox = ib
				inbox_n += 1
	var where := w("存入修缮钢材区", "INTO THE REPAIR STEEL") if str(d.kind) == STEEL else (w("存入仓库", "INTO THE STORES") if inbox_n == 0 else w("仓库空间不足，%d 件暂存在待入库区", "NO ROOM: %d WAITING TO BE STORED") % inbox_n)
	events.append({"kind": "landed", "text": w("到货：%s 已从 %s 的货船卸下，%s", "DELIVERED: %s OFF %s'S FREIGHTER, %s") % [_dv_name(d), str(d.seller), where]})
	Career.save()


static func _dv_name(d: Dictionary) -> String:
	return w("修缮钢材 %.0f 吨", "%.0f t REPAIR STEEL") % float(d.steel) if str(d.kind) == STEEL else "%s × %d" % [RepairBill.kind_name(str(d.kind)), int(d.n)]


static func delivery_state_text(d: Dictionary) -> String:
	match str(d.state):
		"wait":
			return w("货船排队，等东码头空出来", "WAITING FOR THE BERTH")
		"ship":
			if d.has("out_at"):
				return w("已卸完，货船离港", "UNLOADED · LEAVING")
			if clock() - float(d.ship_at) < SHIP_IN:
				return w("货船正在进港", "COMING IN")
			return w("靠泊卸货中 · 卸完入库", "ALONGSIDE · UNLOADING INTO THE STORES")
	return w("已入库", "STORED")


static func order_state_text(o: Dictionary) -> String:
	match str(o.state):
		"open":
			return w("可以接取订单", "OPEN")
		"taken":
			var lack := float(o.n) - float(o.got)
			if str(o.cat) == "raw":
				return w("正在备货：还缺少 %.1f 吨，材料入库后会自动补齐", "MAKING UP: %.1f t SHORT, ADDED AS IT COMES IN") % lack
			return w("正在备货：还缺少 %d 台设备，设备入库后会自动补齐", "MAKING UP: %d SHORT, ADDED AS THEY COME IN") % int(round(lack))
		"rail":
			if FreightWorks.order_arrived(str(o.id)) >= int(o.get("crates", 1)) or clock() - float(o.get("rail_at", clock())) >= RAIL_MAX:
				return w("货物已抵达贸易港，正在等待客户飞船靠泊", "AT THE TRADE PORT, WAITING FOR THE CLIENT'S SHIP")
			return w("货运列车正在将货物运往贸易港", "ON THE FREIGHT TRAIN TO THE TRADE PORT")
		"ship":
			match str(ship_phase(o)[0]):
				"in": return w("客户飞船正在进港", "THE CLIENT'S SHIP COMING IN")
				"load": return w("正在装载货物", "LOADING")
			return w("客户飞船已经离港", "THE CLIENT'S SHIP LEAVING")
		"done":
			return w("已完成", "DONE")
	return w("已过期", "LAPSED")


static func mins_left(o: Dictionary) -> int:
	return maxi(0, int(ceil((float(o.due) - clock()) / 60.0)))


# ---------------------------------------------------------------- time

static func tick(dt: float) -> void:
	if not open():
		return
	var h := data()
	if not bool(h.get("opened", false)):
		_open_up()
	h.clock = float(h.clock) + dt
	var dirty := false
	# listings fill in real time (the market drifts under them)
	var ls: Array = h.listings
	for l in ls.duplicate():
		var s := fill_secs(float(l.price), listing_market(l))
		l.prog = float(l.prog) + dt / maxf(s, 1.0)
		if float(l.prog) >= 1.0:
			ls.erase(l)
			_fill(l)
			dirty = true
	# new orders, up to MAX_ORDERS
	if live_orders().size() < MAX_ORDERS and float(h.clock) >= float(h.get("next_order", 0.0)):
		var o := _new_order()
		var os: Array = h.orders
		os.append(o)
		h.orders = os
		var r := _rng()
		h.next_order = float(h.clock) + r.randf_range(ORDER_GAP.x, ORDER_GAP.y)
		ClientShips.visit(str(o.id), str(o.client), want_name(o))
		events.append({"kind": "new", "text": w("新订单：%s 要 %s，给 %s", "NEW ORDER: %s WANTS %s FOR %s") % [str(o.client), want_name(o), Pal.money(float(o.price))]})
		dirty = true
	for o in orders():
		match str(o.state):
			"open":
				if float(h.clock) >= float(o.due):
					o.state = "gone"
					dirty = true
			"taken":
				if float(h.clock) >= float(o.due):
					for pl in o.held:
						_give(pl, "order_back")
					o.held = []
					o.state = "gone"
					events.append({"kind": "gone", "text": w("订单过期：%s 的单没备齐，货已放回仓库", "ORDER LAPSED: %s's — THE GOODS ARE BACK IN STORE, NO PENALTY") % str(o.client)})
					dirty = true
				elif int(float(h.clock) * 2.0) != int((float(h.clock) - dt) * 2.0):
					# twice a second: anything new in the warehouse goes to it
					if _make_up(o):
						dirty = true
			"rail":
				var arrived: bool = FreightWorks.order_arrived(str(o.id)) >= int(o.get("crates", 1))
				# one client freighter alongside at a time: the next waits at the port
				if (arrived or not bool(o.get("sent", false)) or float(h.clock) - float(o.rail_at) >= RAIL_MAX) and not berth_busy():
					o.state = "ship"
					o.ship_at = float(h.clock)
					# 货车不进站: the train's count stays until the order is settled — the dock's intake lets
					# through only the crates a train has really unloaded at the port (TradeWorks job.avail);
					# what is still to come keeps its place in the freight queue
					events.append({"kind": "ship", "text": w("%s 的货船正在进港，靠贸易港东码头取货", "%s'S FREIGHTER COMING IN TO THE TRADE PORT'S EAST BERTH") % str(o.client)})
					dirty = true
			"ship":
				var s := float(h.clock) - float(o.ship_at)
				if not o.has("out_at"):
					if s >= SHIP_IN and not bool(o.get("berthed", false)):
						o.berthed = true
						events.append({"kind": "berth", "text": w("%s 的货船已靠上贸易港东码头，吊车开始装货", "%s'S FREIGHTER ALONGSIDE AT THE TRADE PORT: THE CRANE IS LOADING") % str(o.client)})
					if s >= SHIP_IN and dock_done("hall:" + str(o.id)):
						o.loaded = true
					if s >= SHIP_IN and (bool(o.get("loaded", false)) or (not watched and s >= SHIP_IN + SHIP_LOAD) or s >= SHIP_IN + LOAD_MAX) and dock_clear("hall:" + str(o.id)):
						o.out_at = float(h.clock)
				elif float(h.clock) - float(o.out_at) >= SHIP_OUT * 0.5:
					_settle(o)
					dirty = true
	# the deliveries of what was bought: in, alongside till the crates are through the intake, out
	for d in deliveries():
		match str(d.state):
			"wait":
				if not berth_busy():
					d.state = "ship"
					d.ship_at = float(h.clock)
					events.append({"kind": "ship", "text": w("%s 的货船正在进港，送来 %s", "%s'S FREIGHTER COMING IN WITH %s") % [str(d.seller), _dv_name(d)]})
					dirty = true
			"ship":
				var s := float(h.clock) - float(d.ship_at)
				if not d.has("out_at"):
					if s >= SHIP_IN and not bool(d.get("berthed", false)):
						d.berthed = true
						d.berthed_at = float(h.clock)
						events.append({"kind": "berth", "text": w("%s 的货船已靠上贸易港东码头，吊车开始卸货", "%s'S FREIGHTER ALONGSIDE AT THE TRADE PORT: THE CRANE IS UNLOADING") % str(d.seller)})
					if s >= SHIP_IN and not watched and s >= SHIP_IN + SHIP_LOAD and not bool(d.get("landed", false)):
						_land(d)
					if (bool(d.get("landed", false)) or dock_done("hallbuy:" + str(d.id))) and dock_clear("hallbuy:" + str(d.id)):
						d.out_at = float(h.clock)
						dirty = true
				elif float(h.clock) - float(d.out_at) >= leave_secs():
					d.state = "done"
					d.done_at = float(h.clock)
					dirty = true
	h.deliveries = deliveries().filter(func(d): return str(d.state) != "done" or not bool(d.get("landed", false)) or float(h.clock) - float(d.get("done_at", 0.0)) < 30.0)
	# what is done or lapsed leaves the board after a while (the board keeps the last ones)
	var keep: Array = []
	for o in orders():
		if str(o.state) in ["done", "gone"] and float(h.clock) - float(o.get("done_at", o.due)) > 30.0:
			continue
		keep.append(o)
	h.orders = keep
	_next_save -= dt
	if dirty or _next_save <= 0.0:
		_next_save = 20.0
		Career.save()


# the first time it opens: the old exchange's listings come back (copied aside first), and the board
# starts with a few orders
static func _open_up() -> void:
	var h := data()
	h.opened = true
	migrate()
	var os: Array = h.orders
	for i in FIRST_ORDERS:
		os.append(_new_order())
		h.orders = os
	h.next_order = float(h.clock) + ORDER_GAP.x
	Career.save()


# 旧存档平滑迁移 (once, logged in Career.data.migrations): the old exchange's open company orders are
# withdrawn (their goods and cash come back) and the old parts' listings taken down. Copied to
# G:\zeropower_save_backup\ first (a test's to user://).
static func migrate() -> int:
	if Career.data.get("migrations", []).any(func(m): return str(m.get("id", "")) == "128_hall"):
		return 0
	var n := 0
	var listed: int = Career.data.get("parts", []).filter(func(p): return p.has("listed")).size()
	var ids := StoreBook._open_orders()
	if (not ids.is_empty() or listed > 0) and not StoreBook._backup("128_hall"):
		return 0
	if not ids.is_empty():
		n += StoreBook.withdraw("")
	for p in Career.data.get("parts", []):
		if p.has("listed"):
			p.erase("listed")
			n += 1
	var log: Array = Career.data.get("migrations", [])
	log.append({"id": "128_hall", "withdrawn": n})
	Career.data.migrations = log
	return n
