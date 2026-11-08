class_name ProcessLine
# 128 号 第 4 段 加工 (design/成长版本/…/128_港区从头设计_仓库交易加工动力_2026-11-04.md §六, §十, the seams
# from 《熔流》 and 《深空压机》, and the 2026-11-07 第 4 段问答定案). What the processing district does once
# the first heat has been made by hand at the furnace desk: one key everywhere after that.
#   炼钢: a warehouse ingot bundle → "炼成钢坯" → a batch in the processing queue (scripts/process_queue.gd,
#     its use written on it: an order, to sell, to keep; its mould), and the furnace takes the batches in
#     turn by itself (scripts/industrial_heat.gd). No assay any more; the sorting runs inside the batch.
#   浇铸与换模: the heat is bottom-poured into a multi-cavity mould block seated under the tap hole — the
#     metal runs down the trumpet and rises in all the cavities at once, cools under the sprays, and the
#     pieces are pushed out onto the roller line. Three blocks: 方坯 (two 1 t billets), 板坯 (one 2 t slab),
#     小锭 (eight 0.25 t ingots); an order names the one it wants. A batch for another mould waits while the
#     hall crane lifts the block out of its seat onto the wall rack and sets the other one in (about 10 s,
#     scripts/process_works.gd) — the same mould heat after heat needs no change.
#   打包压块机: a vertical baler on the floor under the mill deck. A loose bundle or a whole machine from the
#     warehouse rides the feed belt in, the lid shuts, the platen comes down and crushes it into a block,
#     the block is strapped and pushed out, and goes back to the warehouse: fewer cells, a little dearer.
#     A pressure vessel with gas or liquid still in it is caught by the press's pressure probe and sent
#     back — it never bursts in there; empty it while salvaging (the fluid tool) and it can be pressed.
# State: Career.data.casting {line, rack: [3 slots, "" empty], change {to, t}} and Career.data.press
# {jobs [], cur {}, t, n}. Static, as StoreBook / HallMarket: the headless tests run it without a scene.

const Exchange = preload("res://scripts/industrial_exchange.gd")
const MOULDS := ["billet", "slab", "small"]
# t: one cavity's piece; n: cavities; the item it casts
const SPEC := {
	"billet": {"t": 1.0, "n": 2, "item": "steel_billet"},
	"slab": {"t": 2.0, "n": 1, "item": "steel_slab"},
	"small": {"t": 0.25, "n": 8, "item": "steel_small"},
}
const CHANGE_S := 9.0           # s the furnace stands for a mould change (the crane's own run sets it; < 10 s)
const CHANGE_MAX := 9.5         # s: the change is done by then whatever the crane is doing (no works seen)
const BALE_K := 1.08            # a bale fetches this much more than what went into it (draft)
const BALE_T := 2.0             # t a 1×1 cell of bales holds
const PRESS_S := {"feed": 2.6, "close": 0.6, "press": 2.8, "tie": 1.0, "eject": 2.0, "approach": 1.6, "probe": 1.6, "reject": 2.4}
const LOOSE := ["mixed_metal:0", "nonferrous_mix:0", "ferrous_scrap:0"]
const GAS_MAX_KPA := 20.0       # a vessel holding more than this is not empty (vacuum outside)
const LIQ_MAX_M3 := 0.01
static var LEGACY_DESKS := false # old tests: the sorting desk and the assay bench back (before 第 4 段)
static var crane_done := false  # scripts/process_works.gd: the crane has set the new block in its seat
static var events: Array = []   # [{text, bad}] drained by the game into the HUD's hint line


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


static func mould_name(m: String) -> String:
	match m:
		"slab": return w("板坯", "SLAB")
		"small": return w("小锭", "SMALL INGOT")
	return w("方坯", "BILLET")


static func mould_note(m: String) -> String:
	match m:
		"slab": return w("板坯模：一腔 2 t，扁宽，轧板最好用", "Slab mould: one 2 t cavity, flat and wide")
		"small": return w("小锭模：八腔各 0.25 t，小件好搬", "Small-ingot mould: eight 0.25 t cavities")
	return w("方坯模：两腔各 1 t，最常用", "Billet mould: two 1 t cavities, the usual one")


static func item_of(m: String) -> String:
	return str(SPEC.get(m, SPEC.billet).item)


static func product_key(m: String, grade := 1) -> String:
	return Exchange.lot_key(item_of(m), grade)


# the mould an item key is cast in ("" for anything that is not a cast product)
static func mould_of_key(key: String) -> String:
	var item := key.split(":")[0]
	for m in MOULDS:
		if str(SPEC[m].item) == item:
			return m
	return ""


# ---------------------------------------------------------------- the moulds

static func casting() -> Dictionary:
	if Career.data.is_empty():
		return {"line": "billet", "rack": ["slab", "small", ""], "change": {}}
	if not Career.data.has("casting"):
		Career.data.casting = {"line": "billet", "rack": ["slab", "small", ""], "change": {}}
	return Career.data.casting


static func line_mould() -> String:
	return str(casting().get("line", "billet"))


static func changing() -> bool:
	return not casting().get("change", {}).is_empty()


static func change_to() -> String:
	return str(casting().get("change", {}).get("to", ""))


static func change_left() -> float:
	var c: Dictionary = casting().get("change", {})
	return maxf(0.0, CHANGE_S - float(c.get("t", 0.0))) if not c.is_empty() else 0.0


# the hall crane is sent to change the block in the seat for `to`
static func start_change(to: String) -> bool:
	if not to in MOULDS or to == line_mould() or changing():
		return false
	casting().change = {"to": to, "from": line_mould(), "t": 0.0}
	crane_done = false
	events.append({"text": w("换模：吊车把%s模换成%s模，炉子停约 %d 秒", "MOULD CHANGE: THE CRANE SWAPS THE %s MOULD FOR THE %s, ABOUT %d s") % [mould_name(line_mould()), mould_name(to), int(CHANGE_S)], "bad": false})
	return true


# the change's real time; done when the crane has set the new block (or, unseen, after CHANGE_MAX)
static func tick_change(dt: float) -> void:
	var c: Dictionary = casting().get("change", {})
	if c.is_empty():
		return
	c.t = float(c.get("t", 0.0)) + dt
	if crane_done or float(c.t) >= CHANGE_MAX:
		finish_change()


static func finish_change() -> void:
	var cs := casting()
	var c: Dictionary = cs.get("change", {})
	if c.is_empty():
		return
	var to := str(c.to)
	var rack: Array = cs.get("rack", ["", "", ""])
	var old := str(cs.get("line", "billet"))
	# the old block goes into the empty slot, the new one leaves its own
	var k := rack.find(to)
	var e := rack.find("")
	if e >= 0:
		rack[e] = old
	if k >= 0:
		rack[k] = ""
	cs.rack = rack
	cs.line = to
	cs.change = {}
	crane_done = false
	var n := int(Career.data.get("mould_changes", 0)) + 1
	Career.data.mould_changes = n
	events.append({"text": w("换模完成：现在是%s模", "MOULD CHANGED: THE %s MOULD IS IN") % mould_name(to), "bad": false})


# ---------------------------------------------------------------- the queue (scripts/process_queue.gd)

static func first_done() -> bool:
	return int(Career.data.get("heat_count", 0)) >= 1


# tonnes of a raw key already waiting in the queue to be melted
static func queued_t(key: String) -> float:
	var s := 0.0
	for e in ProcessQueue.entries():
		if str(e.get("key", Exchange.INGOT)) == key:
			s += maxf(0.0, float(e.t) - float(e.melted))
	return s


# the best guess at what a batch is for: the open order the moulds' products are short of, else keep
static func guess_use(t: float) -> Dictionary:
	for o in HallMarket.orders():
		if str(o.cat) != "raw" or not str(o.state) in ["open", "taken"]:
			continue
		var m := mould_of_key(str(o.kind))
		if m == "":
			continue
		var lack := float(o.n) - float(o.get("got", 0.0)) - for_order_t(str(o.id))
		if lack > 0.05:
			return {"use": {"kind": "order", "oid": str(o.id)}, "mould": m}
	return {"use": {"kind": "keep"}, "mould": line_mould()}


static func for_order_t(oid: String) -> float:
	var s := 0.0
	for e in ProcessQueue.entries():
		if str(e.get("use", {}).get("oid", "")) == oid and not ProcessQueue.finished(e):
			s += maxf(0.0, float(e.t) - float(e.get("billet", 0.0)))
	return s


# "炼成钢坯" from the warehouse: t of ingot into the queue (the store's bundles stay where they are till
# the trolley fetches them). -> {ok, reason, entry, place}
static func queue_ingots(t: float, use := {}, mould := "") -> Dictionary:
	if Port.stage("process") < 1:
		return {"ok": false, "reason": w("加工区还没修好", "THE PROCESSING DISTRICT IS NOT MENDED")}
	if not first_done():
		return {"ok": false, "reason": w("第一炉要在加工区炉台亲手炼一次，之后才能一键排产", "THE FIRST HEAT IS MADE BY HAND AT THE FURNACE DESK")}
	var have := float(StoreBook.raw_stock().get(Exchange.INGOT, 0.0)) - queued_t(Exchange.INGOT)
	t = minf(t, have)
	if t < ProcessQueue.HEAT_MIN:
		return {"ok": false, "reason": w("仓库里没有没排上的钢锭了", "NO INGOTS LEFT THAT ARE NOT QUEUED")}
	var g := guess_use(t)
	if use.is_empty():
		use = g.use
	if mould == "":
		mould = str(g.mould)
	var e := ProcessQueue.add_job(Exchange.INGOT, snappedf(t, 0.001), use, mould)
	if bool(casting().get("auto", false)):
		auto_sort()
	var place := ProcessQueue.open_entries().find(e) + 1
	if not Career.save():
		return {"ok": false, "reason": w("保存失败", "SAVE FAILED")}
	return {"ok": true, "entry": e, "place": place}


# 订单卡“为这单排产”: a batch for what the order still lacks, put first
static func plan_for_order(oid: String) -> Dictionary:
	var o := HallMarket.order(oid)
	if o.is_empty() or str(o.cat) != "raw" or mould_of_key(str(o.kind)) == "":
		return {"ok": false, "reason": w("这张订单不要钢坯", "THIS ORDER WANTS NO CAST STEEL")}
	var lack := float(o.n) - float(o.get("got", 0.0)) - float(StoreBook.raw_stock().get(str(o.kind), 0.0)) - for_order_t(oid)
	if lack <= 0.05:
		return {"ok": false, "reason": w("这单要的已经在仓库或队列里了", "WHAT IT WANTS IS IN STORE OR QUEUED ALREADY")}
	var r := queue_ingots(lack, {"kind": "order", "oid": oid}, mould_of_key(str(o.kind)))
	if not r.ok:
		return r
	ProcessQueue.move_to(str(r.entry.lot), 0)
	Career.save()
	r.place = 1
	return r


static func use_text(e: Dictionary) -> String:
	var u: Dictionary = e.get("use", {})
	match str(u.get("kind", "keep")):
		"order":
			var o := HallMarket.order(str(u.get("oid", "")))
			if o.is_empty() or not str(o.state) in ["open", "taken", "rail", "ship"]:
				return w("订单已结束 · 留着", "ORDER GONE · KEEP")
			return w("订单 · %s · %d 分钟后截止", "ORDER · %s · DUE IN %d MIN") % [str(o.client), HallMarket.mins_left(o)]
		"sell":
			return w("炼好挂到交易行卖", "TO SELL ON THE EXCHANGE")
	return w("留在仓库", "KEEP IN STORE")


# the batch's deadline (s of the hall clock): an order's due, else none (INF)
static func due_of(e: Dictionary) -> float:
	var u: Dictionary = e.get("use", {})
	if str(u.get("kind", "")) == "order":
		var o := HallMarket.order(str(u.get("oid", "")))
		if not o.is_empty() and str(o.state) in ["open", "taken"]:
			return float(o.due)
	return INF


# 按订单截止时间自动排: orders by their due, the rest after in the order they were put; among batches
# with no deadline the same mould is kept together (no needless changes)
static func auto_sort() -> void:
	var q: Array = Career.data.get("process_queue", [])
	var done: Array = q.filter(func(e): return ProcessQueue.finished(e))
	var open: Array = q.filter(func(e): return not ProcessQueue.finished(e))
	# the batch on the furnace now stays first
	var cur := str(Career.data.get("industrial_heat", {}).get("queue", ""))
	var head: Array = open.filter(func(e): return str(e.lot) == cur and float(e.melted) > 0.0 and float(e.t) - float(e.melted) >= ProcessQueue.HEAT_MIN)
	var rest: Array = open.filter(func(e): return not head.has(e))
	var line := line_mould()
	rest.sort_custom(func(a, b):
		var da := due_of(a)
		var db := due_of(b)
		if da != db:
			return da < db
		var ma := 0 if str(a.get("mould", "billet")) == line else 1
		var mb := 0 if str(b.get("mould", "billet")) == line else 1
		if ma != mb:
			return ma < mb
		return float(a.get("added", 0.0)) < float(b.get("added", 0.0)))
	Career.data.process_queue = done + head + rest


static func set_auto(on: bool) -> void:
	casting().auto = on
	if on:
		auto_sort()
	Career.save()


static func auto_on() -> bool:
	return bool(casting().get("auto", false))


# s the queue still needs, roughly: each heat's run and each mould change on the way
static func eta(e: Dictionary) -> float:
	var s := 0.0
	var m := line_mould()
	for x in ProcessQueue.open_entries():
		var left := maxf(0.0, float(x.t) - float(x.melted))
		var mx := str(x.get("mould", "billet"))
		if mx != m:
			s += CHANGE_S
			m = mx
		s += ceil(left / ProcessQueue.HEAT_T) * heat_s()
		if x == e:
			break
	return s


# s a 2 t heat takes from the trolley's run to the billets home (measured, scripts/process_line.gd tests)
static func heat_s() -> float:
	return 42.0


# ---------------------------------------------------------------- the press

static func press() -> Dictionary:
	if Career.data.is_empty():
		return {}
	if not Career.data.has("press"):
		Career.data.press = {"jobs": [], "cur": {}, "t": 0.0, "n": 0}
	return Career.data.press


# what the warehouse unit is in a pressure vessel's terms: {vessel, gas_kpa, liq_m3, what}
static func vessel_of(u: Dictionary) -> Dictionary:
	var src: Dictionary = u.get("good", u.get("part", {}))
	var gas := float(src.get("gas_kpa", 0.0))
	var liq := float(src.get("liq_m3", 0.0))
	return {"vessel": bool(src.get("vessel", false)), "gas_kpa": gas, "liq_m3": liq, "what": str(src.get("held", ""))}


static func charged(u: Dictionary) -> bool:
	var v := vessel_of(u)
	return v.vessel and (float(v.gas_kpa) > GAS_MAX_KPA or float(v.liq_m3) > LIQ_MAX_M3)


static func charged_text(u: Dictionary) -> String:
	var v := vessel_of(u)
	var bits: Array = []
	if float(v.gas_kpa) > GAS_MAX_KPA:
		bits.append(w("气体 %d kPa", "GAS %d kPa") % int(v.gas_kpa))
	if float(v.liq_m3) > LIQ_MAX_M3:
		bits.append(w("液体 %.2f m³", "LIQUID %.2f m³") % float(v.liq_m3))
	return " · ".join(bits)


# can it go to the press? {ok, why} — why is said in plain words on the greyed key
static func pressable(u: Dictionary) -> Dictionary:
	if u.is_empty():
		return {"ok": false, "why": ""}
	if Port.stage("process") < 1:
		return {"ok": false, "why": w("加工区修好后才能用压块机", "THE PRESS IS IN THE PROCESSING DISTRICT: MEND IT FIRST")}
	if u.get("inbox", false) or u.get("steel", false):
		return {"ok": false, "why": w("先放进仓库", "PUT IT AWAY FIRST")}
	var id := str(u.get("id", ""))
	if id.begins_with("r:"):
		if str(u.get("key", "")) in LOOSE:
			return {"ok": true, "why": ""}
		return {"ok": false, "why": w("钢锭、钢坯本来就是实心的，不用压", "INGOTS AND BILLETS ARE SOLID ALREADY")}
	if id.begins_with("s:"):
		return {"ok": false, "why": w("小零件不用压", "SMALL SPARES ARE NOT PRESSED")}
	if id.begins_with("p:") and u.part.has("listed"):
		return {"ok": false, "why": w("挂牌中，先撤下来", "LISTED: WITHDRAW IT FIRST")}
	if id.begins_with("g:"):
		if u.good.get("bale", false):
			return {"ok": false, "why": w("已经是压块了", "IT IS A BALE ALREADY")}
		if str(u.good.get("fluid", "")) != "":
			return {"ok": false, "why": w("罐里是回收的气体液体，只能卖", "RECOVERED GAS OR LIQUID: IT ONLY SELLS")}
		if u.good.get("rejected", false) and charged(u):
			return {"ok": false, "why": w("压机拒收过：里面还有%s。拆船时先用气液回收（5）抽干净再拆下来", "THE PRESS SENT IT BACK: %s INSIDE. EMPTY IT WITH THE FLUID TOOL (5) BEFORE YOU CUT IT FREE") % charged_text(u)}
	if id.begins_with("p:") and u.part.get("rejected", false) and charged(u):
		return {"ok": false, "why": w("压机拒收过：里面还有%s。拆船时先用气液回收（5）抽干净再拆下来", "THE PRESS SENT IT BACK: %s INSIDE. EMPTY IT WITH THE FLUID TOOL (5) BEFORE YOU CUT IT FREE") % charged_text(u)}
	if not (id.begins_with("g:") or id.begins_with("p:")):
		return {"ok": false, "why": w("这件不能压", "NOT FOR THE PRESS")}
	return {"ok": true, "why": ""}


static func bale_value(u: Dictionary) -> float:
	return snappedf(float(u.get("market", 0.0)) * BALE_K, 1.0)


static func bale_cells(mass: float) -> Vector2i:
	return Vector2i(1, 1 if mass <= BALE_T + 0.001 else 2)


static func mass_of(u: Dictionary) -> float:
	if str(u.get("id", "")).begins_with("r:"):
		return float(u.get("t", 0.0))
	var src: Dictionary = u.get("good", u.get("part", {}))
	return maxf(0.05, float(src.get("mass", 0.5)))


# 压块: take it out of the warehouse onto the press's feed belt. -> {ok, reason, place}
static func send_to_press(id: String) -> Dictionary:
	var u := HallMarket._unit(id)
	var ok := pressable(u)
	if not ok.ok:
		return {"ok": false, "reason": str(ok.why)}
	var before := Career.data
	Career.data = before.duplicate(true)
	u = HallMarket._unit(id)
	var pl := HallMarket._take(u)
	if pl.is_empty():
		Career.data = before
		return {"ok": false, "reason": w("这件现在取不出来", "IT CANNOT BE TAKEN OUT NOW")}
	var src: Dictionary = u.get("good", u.get("part", {}))
	var pr := press()
	pr.n = int(pr.get("n", 0)) + 1
	var job := {"id": "B%d" % int(pr.n), "pl": pl, "name": str(u.name), "mass": mass_of(u), "value": bale_value(u), "cells": int(u.get("cells", 1)),
		"look": {"cat": str(u.cat), "ship": str(u.get("ship", "")), "tag": str(u.get("tag", "")), "nk": str(src.get("nk", "")), "key": str(u.get("key", "")), "w": int(u.w), "h": int(u.h)},
		"charged": charged(u), "held": charged_text(u), "ship": str(u.get("ship", ""))}
	var jobs: Array = pr.get("jobs", [])
	jobs.append(job)
	pr.jobs = jobs
	if not Career.save():
		Career.data = before
		return {"ok": false, "reason": w("保存失败", "SAVE FAILED")}
	return {"ok": true, "place": jobs.size() + (0 if pr.get("cur", {}).is_empty() else 1), "name": str(u.name)}


# the job on the press now and where it is: [phase, 0 … 1 through it]
static func press_phase() -> Array:
	var pr := press()
	var cur: Dictionary = pr.get("cur", {})
	if cur.is_empty():
		return ["idle", 0.0]
	var t := float(pr.get("t", 0.0))
	var seq := ["approach", "probe", "reject"] if cur.get("charged", false) else ["feed", "close", "press", "tie", "eject"]
	for ph in seq:
		var d := float(PRESS_S[ph])
		if t < d:
			return [ph, t / d]
		t -= d
	return ["done", 1.0]


static func press_total(cur: Dictionary) -> float:
	var seq := ["approach", "probe", "reject"] if cur.get("charged", false) else ["feed", "close", "press", "tie", "eject"]
	var s := 0.0
	for ph in seq:
		s += float(PRESS_S[ph])
	return s


# real time: the press works its jobs one after another, seen or not
static func tick_press(dt: float) -> void:
	if Career.data.is_empty() or not Career.data.has("press"):
		return
	var pr := press()
	var cur: Dictionary = pr.get("cur", {})
	if cur.is_empty():
		var jobs: Array = pr.get("jobs", [])
		if jobs.is_empty():
			return
		pr.cur = jobs.pop_front()
		pr.jobs = jobs
		pr.t = 0.0
		return
	pr.t = float(pr.get("t", 0.0)) + dt
	if float(pr.t) >= press_total(cur):
		_press_done(cur)
		pr.cur = {}
		pr.t = 0.0
		Career.save()


static func _press_done(cur: Dictionary) -> void:
	if cur.get("charged", false):
		# back to the warehouse as it was, marked: the press sent it back
		var pl: Dictionary = cur.pl.duplicate(true)
		if pl.has("goods"):
			for gd in pl.goods:
				gd.rejected = true
		if pl.has("part"):
			pl.part.rejected = true
		HallMarket._give(pl, "press_back")
		events.append({"text": w("压机拒收：%s 里面还有%s，已退回仓库。拆船时先用气液回收（5）抽干净再拆下来，就能压块", "THE PRESS SENT BACK %s: %s INSIDE. EMPTY IT WITH THE FLUID TOOL (5) BEFORE CUTTING IT FREE") % [str(cur.name), str(cur.held)], "bad": true})
		return
	var mass := float(cur.mass)
	var c := bale_cells(mass)
	var gd := {"uid": "bale:%s" % str(cur.id), "cat": "raw", "bale": true, "nk": "bale", "name": w("压块 · %s", "BALE · %s") % str(cur.name), "from": str(cur.name),
		"value": float(cur.value), "mass": snappedf(mass, 0.01), "ship": str(cur.get("ship", "")), "day": snappedf(Shipping.day(), 0.01), "w": c.x, "h": c.y}
	var us := StoreBook.units()
	var lay := StoreBook.layout(us)
	var occ := StoreBook._occ_of(lay, us)
	var spot := StoreBook._first(occ, {"w": c.x, "h": c.y})
	if spot.is_empty():
		var ib: Array = Career.data.get("inbox", [])
		ib.append({"uid": str(gd.uid), "src": "goods", "good": gd, "job": "press"})
		Career.data.inbox = ib
	else:
		var gs: Array = Career.data.get("goods", [])
		gs.append(gd)
		Career.data.goods = gs
		var pos: Dictionary = Career.data.get("store_pos", {})
		pos["g:" + str(gd.uid)] = [int(spot[0]), int(spot[1]), int(spot[2])]
		Career.data.store_pos = pos
	var saved := int(cur.get("cells", 1)) - c.x * c.y
	events.append({"text": w("压块完成：%s → 压块 %.1f t，回到仓库%s · 约 %s", "BALED: %s → %.1f t BALE, BACK IN STORE%s · ~%s") % [str(cur.name), mass, (w("，省出 %d 格", ", %d CELLS FREED") % saved) if saved > 0 else "", Pal.money(float(cur.value))], "bad": false})
