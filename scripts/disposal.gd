class_name Disposal
# 106 号 (10-27 Q6, 10-29 问答 Q4 A / Q5 A): where a contract's recovered goods go, chosen on the
# settlement's second page (scripts/disposal_panel.gd) — the ingots the berth's furnace cast, as one
# batch: sold now at the furnace's price, or kept to be processed (they go to the processing
# district and are melted and rolled there, scripts/process_queue.gd); the whole equipment the
# drone brought to the equipment bay, piece by piece: sold now, or kept on the parts rack for the
# berth's repairs. Career.settle puts everything on the shelf and in the warehouse as before and
# writes what can still be decided into Career.data.disposal; nothing is sold until the page is
# confirmed (a game left on the page keeps everything, as it always did).
#   Career.data.disposal = {job, ship, lot, ingot_t, ingot_cash, uids: [part uids], open}
#   Career.data.disposal_metal = "keep" | "sell"   (the last choice: the next page's default)

const Exchange = preload("res://scripts/industrial_exchange.gd")
const Smelter = preload("res://scripts/smelter.gd")
const BILLET := "steel_billet:1"
const YIELD := 0.93                 # t of billet a tonne of ingot makes (slag, scale, the heel kept)


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


# Career.settle: what this contract left to decide (the parts are already on the shelf)
static func open_for(job_id: String, ship: String, ingot_t: float, ingot_cash: float, parts: Array) -> void:
	var uids: Array = []
	for p in parts:
		uids.append(str(p.get("uid", "")))
	if ingot_t <= 0.0005 and uids.is_empty():
		Career.data.erase("disposal")
		return
	Career.data.disposal = {"job": job_id, "ship": ship, "lot": "ingot:" + job_id, "ingot_t": snappedf(ingot_t, 0.001),
		"ingot_cash": snappedf(ingot_cash, 1.0), "uids": uids, "open": true}


static func pending() -> Dictionary:
	if Career.data.is_empty():
		return {}
	var d: Dictionary = Career.data.get("disposal", {})
	return d if d.get("open", false) else {}


static func metal_default() -> String:
	return str(Career.data.get("disposal_metal", "keep"))


# the parts of this contract still on the shelf (one may have gone to a repair since)
static func parts() -> Array:
	var d := pending()
	var out: Array = []
	for part in Career.data.get("parts", []):
		if str(part.uid) in d.get("uids", []) and not part.has("listed"):
			out.append(part)
	return out


# ---------------------------------------------------------------- the two choices' consequences

# the ingots, sold now: their tonnes at the ingot's price (108 号: $300 a tonne, twice the raw
# structure's scrap — the furnace has taken the slag out)
static func sell_cash(d: Dictionary) -> float:
	return snappedf(float(d.get("ingot_t", 0.0)) * Exchange.INGOT_PRICE, 1.0)


# the ingots, kept: melted into billet in the arc furnace — what that billet is worth today, and
# the power it takes (the heat balance of scripts/smelter.gd, at the grid's own price)
static func keep_value(d: Dictionary) -> Dictionary:
	var t := float(d.get("ingot_t", 0.0))
	var billet_t := t * YIELD
	var price := float(Exchange.REF_PRICE.get(BILLET, Exchange.BILLET_PRICE))
	var j_per_kg := Smelter.C_S * (Smelter.T_LIQ - 20.0) + Smelter.L_FUS + Smelter.C_L * (Smelter.T_TAP - Smelter.T_LIQ)
	var mwh := t * 1000.0 * j_per_kg / Smelter.ETA / 3.6e9
	var power := mwh * Grid.OWN_PRICE
	return {"billet_t": billet_t, "value": snappedf(billet_t * price, 1.0), "mwh": mwh, "power": snappedf(power, 1.0)}


# which shelved parts the berth's unfinished repairs would use: for every class, as many of the
# best-kept parts on the shelf as the repairs not yet done still need. -> {uid: [repair id, saving]}
static func wanted() -> Dictionary:
	var need := {}          # class -> [[repair id, saving a part], ...] one entry a part needed
	for it in Repair.ITEMS:
		var id: String = it[0]
		if Repair.done(id) or not Repair.found(id):
			continue
		var n := 0
		for cls in it[2]:
			if cls in ["power", "thermal", "drive"]:
				n += int(it[2][cls])
		if n == 0:
			continue
		var save_each: float = float(it[3]) * (1.0 - Repair.PARTS_SHARE) / float(n)
		for cls in it[2]:
			if cls in ["power", "thermal", "drive"]:
				if not need.has(cls):
					need[cls] = []
				for i in int(it[2][cls]):
					need[cls].append([id, save_each])
	var shelf: Array = Career.data.get("parts", []).duplicate()
	shelf.sort_custom(func(a, b): return float(a.cond) > float(b.cond))
	var used := {}
	var out := {}
	for part in shelf:
		var cls := str(part.cls)
		if not need.has(cls) or float(part.cond) < Repair.COND_MIN or part.has("listed"):
			continue
		var k := int(used.get(cls, 0))
		if k < need[cls].size():
			out[str(part.uid)] = need[cls][k]
			used[cls] = k + 1
	return out


# the page's starting choice for a part: kept when a repair would use it; a light-sail roll is kept
# too (listed for the sail-makers it fetches more than a sale here); the rest sold
static func part_default(part: Dictionary, want: Dictionary) -> String:
	if want.has(str(part.uid)) or str(part.cls) == "sail":
		return "keep"
	return "sell"


# why a part is kept or sold, in a line
static func part_note(part: Dictionary, want: Dictionary, short := false) -> String:
	if want.has(str(part.uid)):
		var u: Array = want[str(part.uid)]
		if short:
			return w("修「%s」用得上", "%s needs it") % Repair.name_of(str(u[0]))
		return w("修「%s」用得上：留着省约 %s", "%s needs it: keeping it saves about %s") % [Repair.name_of(str(u[0])), Pal.money(float(u[1]))]
	if str(part.cls) == "sail":
		return w("可在货架挂给光帆厂，比直接卖高 8%", "list it for the sail-makers: 8 % over a sale")
	if float(part.cond) < Repair.COND_MIN:
		return w("成色不到 %d%%，修缮用不上" % int(Repair.COND_MIN * 100.0), "under %d %% condition: no use for repairs" % int(Repair.COND_MIN * 100.0))
	return w("待修项目已经不缺这一类", "no repair still needs this class")


# ---------------------------------------------------------------- confirming the page

# metal: "sell" | "keep"; sell: the uids sold. One save; on a failed save nothing changes.
static func apply(metal: String, sell: Array) -> Dictionary:
	var d := pending()
	if d.is_empty():
		return {"ok": false, "reason": "none"}
	var before := Career.data
	Career.data = before.duplicate(true)
	var cash := 0.0
	var sold_t := 0.0
	var kept_t := 0.0
	if float(d.ingot_t) > 0.0005:
		if metal == "sell":
			sold_t = _take_ingots(str(d.lot))
			if float(d.ingot_t) > 0.0:
				cash += sell_cash(d) * sold_t / float(d.ingot_t)
		else:
			kept_t = float(d.ingot_t)
			ProcessQueue.add(str(d.lot), str(d.ship), str(d.job), kept_t)
		Career.data.disposal_metal = metal
	var sold: Array = []
	var shelf: Array = Career.data.get("parts", [])
	for i in range(shelf.size() - 1, -1, -1):
		var part: Dictionary = shelf[i]
		if str(part.uid) in sell and str(part.uid) in d.uids and not part.has("listed"):
			cash += Repair.part_worth(part)
			sold.append(str(part.uid))
			shelf.remove_at(i)
	Career.data.parts = shelf
	Career.data.money = float(Career.data.money) + snappedf(cash, 1.0)
	var dd: Dictionary = Career.data.disposal
	dd.open = false
	dd.result = {"metal": metal, "sold_t": sold_t, "kept_t": kept_t, "sold": sold, "cash": snappedf(cash, 1.0)}
	Career.data.disposal = dd
	if not Career.save():
		Career.data = before
		return {"ok": false, "reason": "save"}
	return {"ok": true, "cash": snappedf(cash, 1.0), "sold": sold, "sold_t": sold_t, "kept_t": kept_t}


# the batch out of the warehouse's books (and the exchange's, when it has them): t taken
static func _take_ingots(lot: String) -> float:
	var t := 0.0
	var ib: Array = Career.data.get("ingot_batches", [])
	for i in range(ib.size() - 1, -1, -1):
		if str(ib[i].get("id", "")) == lot:
			t = float(ib[i].get("mass_t", 0.0))
			ib.remove_at(i)
	Career.data.ingot_batches = ib
	var ex: Dictionary = Career.data.get("exchange", {})
	if ex.is_empty() or not ex.get("actors", {}).has(Exchange.PLAYER):
		return t
	var actor: Dictionary = ex.actors[Exchange.PLAYER]
	var l: Dictionary = actor.get("lots", {}).get(lot, {})
	if l.is_empty():
		return t
	# only what is still there (nothing has had time to go, but a lot is never sold twice)
	var avail := float(l.get("available", 0.0))
	actor.stock[Exchange.INGOT] = maxf(0.0, float(actor.stock.get(Exchange.INGOT, 0.0)) - avail)
	actor.lots.erase(lot)
	return minf(t, avail) if t > 0.0 else avail
