extends RefCounted
# Single-player order book. Quantities are tonnes; prices are credits/tonne.
# Matching reserves a real consignment, NOT delivered usable player inventory.
# Career owns persistence and the game clock; no UI timer owns this state.

const PLAYER := "company"
const FEE := 0.02 # provisional balance value, charged to proceeds on delivery
const EPS := 0.000001
# 64 号 (60 号 Q5 A): the berth furnace's ingots are the grade-1 ferrous feed (ready to remelt),
# called ingots everywhere; raw scrap is no longer offered for sale
static var INGOTS := true   # tests of the older feed chain switch it off
const RAW_HIDDEN := ["mixed_metal:0", "ferrous_scrap:0", "nonferrous_mix:0"]
const INGOT := "ferrous_scrap:1"
# 108 号 第 5 件 (user "C 折中"): the structure's scrap is $150 a tonne (scripts/ship.gd), the furnace's
# ingots $300 (cast, the slag gone), grade-1 billet $550 — melted, a tonne of ingot pays about 1.6
# times its direct sale after the power; plate and sections on from the billet
const INGOT_PRICE := 300.0
const BILLET_PRICE := 550.0
const CATALOG := {
	"mixed_metal":{"name":"未分选金属", "grades":[0]},
	"ferrous_scrap":{"name":"钢锭", "grades":[1,0]},
	"nonferrous_mix":{"name":"混合有色金属", "grades":[0]},
	"steel_billet":{"name":"结构钢坯", "grades":[0,1,2]},
	# 128 号 第 4 段: the other two moulds' products (scripts/process_line.gd)
	"steel_slab":{"name":"板坯", "grades":[0,1,2]},
	"steel_small":{"name":"小锭", "grades":[0,1,2]},
	# 74 号: the rolling mill's products, also sold by merchants
	"steel_plate":{"name":"钢板", "grades":[1]},
	"steel_section":{"name":"型材", "grades":[1]},
}
const CUSTOMER_OFFERS := {
	"PORT-STEEL-01":{"name":"港务维修队要钢坯做支架","buyer":"merchant_01","item":"steel_billet","grade":1,"quantity":1.0,"price":BILLET_PRICE},
	"SHOP-STEEL-01":{"name":"远岫工场要钢坯修零件","buyer":"merchant_02","item":"steel_billet","grade":1,"quantity":0.5,"price":BILLET_PRICE - 25.0},
}

static func lot_key(item: String, grade: int) -> String:
	return "%s:%d" % [item,grade]

static func fresh(money: float) -> Dictionary:
	var actors := {PLAYER:{"name":"本公司", "cash":money, "stock":{}, "lots":{}, "fixed":true}}
	for i in 24:
		var stock := {}
		stock[lot_key("mixed_metal",0)] = 3.0+float(i%7)*2.0 if i%2 == 0 else 0.0
		stock[lot_key("steel_billet",1)] = 1.0+float(i%5) if i%3 == 0 else 0.0
		if i%4 == 0: stock[lot_key("ferrous_scrap",1)] = 6.0
		# 74 号: plate and sections from the belt's merchants (shipped by freighter), not the port's counters
		if i >= 3 and i%6 == 4: stock[lot_key("steel_plate",1)] = 8.0
		if i >= 3 and i%6 == 5: stock[lot_key("steel_section",1)] = 8.0
		var owner := "merchant_%02d" % i
		var lots := {}
		for key in stock:
			var identity := "opening:%s:%s" % [owner,key]
			lots[identity] = {"id":identity,"key":key,"available":float(stock[key]),"total":float(stock[key]),"origin":"external_opening_inventory"}
			if key == lot_key("mixed_metal",0): lots[identity].material_profile = {"version":1,"nonmagnetic_share":0.14+float(i%5)*0.08,"basis":"authored_opening_material"}
		actors[owner] = {"name":(["恒岳工业","天衡物流","远岫工场"][i] if i < 3 else "独立商户 %03d" % (i+1)), "cash":15000.0+float(i%8)*5000.0, "stock":stock, "lots":lots, "fixed":i < 3}
	return {"version":2,"catalog_revision":1,"clock":0.0,"next":1,"actors":actors,"orders":[],"trades":[],"sources":{},"revision":0,"npc_turn":0}

static func _reserve_lots(actor: Dictionary, key: String, quantity: float,described_only: bool = false) -> Array:
	var available := 0.0
	for lot in actor.get("lots",{}).values():
		if described_only and not source_profile(actor,[{"source_id":lot.id,"quantity":float(lot.available)}],float(lot.available)).ok: continue
		if lot.key == key: available += float(lot.available)
	if available+1e-12 < quantity: return []
	var result: Array = []
	var remaining := quantity
	for lot in actor.get("lots",{}).values():
		if described_only and not source_profile(actor,[{"source_id":lot.id,"quantity":float(lot.available)}],float(lot.available)).ok: continue
		if lot.key != key or float(lot.available) <= 0.0: continue
		var taken := minf(remaining,float(lot.available))
		result.append({"source_id":str(lot.id),"quantity":taken})
		lot.available = maxf(0.0,float(lot.available)-taken)
		remaining = maxf(0.0,remaining-taken)
		if remaining <= 0.0: break
	return result

static func _take_slices(slices: Array, quantity: float) -> Array:
	var result: Array = []
	var remaining := quantity
	for slice in slices:
		if float(slice.quantity) <= 0.0: continue
		var taken := minf(remaining,float(slice.quantity))
		result.append({"source_id":str(slice.source_id),"quantity":taken})
		slice.quantity = maxf(0.0,float(slice.quantity)-taken)
		remaining = maxf(0.0,remaining-taken)
		if remaining <= 0.0: break
	return result

# Upgrade the initial aggregate-only development schema without deleting orders,
# changing escrow or inventing player source receipts. Build on a copy first.
static func migrate(state: Dictionary) -> Dictionary:
	if int(state.get("version",1)) == 2: return {"ok":true}
	if int(state.get("version",1)) != 1: return {"ok":false,"reason":"exchange_version"}
	var work := state.duplicate(true)
	for owner in work.actors:
		var actor: Dictionary = work.actors[owner]
		actor.lots = {}
		if owner == PLAYER:
			for identity in work.sources:
				var source: Dictionary = work.sources[identity]
				actor.lots[identity] = {"id":identity,"key":lot_key(str(source.item),int(source.grade)),"available":float(source.quantity),"total":float(source.quantity),"origin":"receiver"}
		else:
			var totals: Dictionary = actor.stock.duplicate()
			for order in work.orders:
				if order.owner == owner and order.side == "sell" and order.state == "open":
					var key := lot_key(str(order.item),int(order.grade))
					totals[key] = float(totals.get(key,0.0))+float(order.remaining)
			for trade in work.trades:
				if trade.seller == owner:
					var key := lot_key(str(trade.item),int(trade.grade))
					totals[key] = float(totals.get(key,0.0))+float(trade.quantity)
			for key in totals:
				var identity := "opening:%s:%s" % [owner,key]
				actor.lots[identity] = {"id":identity,"key":key,"available":float(totals[key]),"total":float(totals[key]),"origin":"external_opening_inventory"}
	for order in work.orders:
		order.source_lots = []
		if order.side == "sell" and order.state == "open" and float(order.remaining) > 0.0:
			order.source_lots = _reserve_lots(work.actors[order.owner],lot_key(str(order.item),int(order.grade)),float(order.remaining))
			if order.source_lots.is_empty(): return {"ok":false,"reason":"source_mismatch"}
	for trade in work.trades:
		trade.source_lots = _reserve_lots(work.actors[trade.seller],lot_key(str(trade.item),int(trade.grade)),float(trade.quantity))
		if trade.source_lots.is_empty(): return {"ok":false,"reason":"source_mismatch"}
	work.version = 2
	state.clear()
	state.merge(work,true)
	return {"ok":true}

static func _id(state: Dictionary, prefix: String) -> String:
	var value := "%s-%08d" % [prefix,int(state.next)]
	state.next = int(state.next)+1
	return value

static func _valid(item: String, grade: int, quantity: float, price: float) -> bool:
	return CATALOG.has(item) and CATALOG[item].grades.has(grade) and is_finite(quantity) and quantity > EPS and is_finite(price) and price > 0.0 and is_finite(quantity*price)

static func post(state: Dictionary, owner: String, side: String, item: String, grade: int, quantity: float, price: float, terms: Dictionary = {}) -> Dictionary:
	if not state.actors.has(owner) or side not in ["buy","sell"] or not _valid(item,grade,quantity,price):
		return {"ok":false,"reason":"invalid_order"}
	var actor: Dictionary = state.actors[owner]
	var key := lot_key(item,grade)
	var reserved := quantity*price if side == "buy" else 0.0
	var source_lots: Array = []
	if side == "buy":
		if float(actor.cash) < reserved: return {"ok":false,"reason":"insufficient_funds"}
		actor.cash = float(actor.cash)-reserved
	else:
		if float(actor.stock.get(key,0.0)) < quantity: return {"ok":false,"reason":"insufficient_stock"}
		source_lots = _reserve_lots(actor,key,quantity)
		if source_lots.is_empty(): return {"ok":false,"reason":"source_mismatch"}
		actor.stock[key] = float(actor.stock.get(key,0.0))-quantity
	var order := {"id":_id(state,"ORDER"),"owner":owner,"side":side,"item":item,"grade":grade,"price":price,
		"quantity":quantity,"remaining":quantity,"cash_reserved":reserved,"source_lots":source_lots,"created":float(state.clock),"state":"open"}
	for field in ["exclusive_seller","contract_id","target_order"]:
		if terms.has(field): order[field] = str(terms[field])
	state.orders.append(order)
	state.revision = int(state.revision)+1
	_match(state,order)
	return {"ok":true,"order_id":str(order.id)}

static func _match(state: Dictionary, incoming: Dictionary) -> void:
	var choices: Array = []
	for other in state.orders:
		if other.state != "open" or other.owner == incoming.owner or other.side == incoming.side or other.item != incoming.item or int(other.grade) != int(incoming.grade): continue
		if incoming.side == "buy" and float(other.price) > float(incoming.price): continue
		if incoming.side == "sell" and float(other.price) < float(incoming.price): continue
		choices.append(other)
	choices.sort_custom(func(a,b):
		if float(a.price) != float(b.price): return float(a.price) < float(b.price) if incoming.side == "buy" else float(a.price) > float(b.price)
		return str(a.id) < str(b.id))
	for other in choices:
		if float(incoming.remaining) <= EPS: break
		var buy: Dictionary = incoming if incoming.side == "buy" else other
		var sell: Dictionary = other if incoming.side == "buy" else incoming
		# Accepted customer budgets belong to this company's explicit delivery,
		# not an NPC or an unrelated open-market sale. Ordinary orders keep the
		# existing matching rules unchanged.
		if buy.get("exclusive_seller",sell.owner) != sell.owner: continue
		if buy.has("target_order") and buy.target_order != sell.id: continue
		# 37 号: a client's budget buys the company's ordinary listing directly (no accepting,
		# no separate shipping order); it still buys from nobody else
		if sell.has("target_order") and sell.target_order != buy.id: continue
		var quantity := minf(float(incoming.remaining),float(other.remaining))
		var price := float(other.price) # resting price, best compatible price first
		var total := quantity*price
		var source_lots := _take_slices(sell.source_lots,quantity)
		buy.cash_reserved = maxf(0.0,float(buy.cash_reserved)-quantity*float(buy.price))
		var buyer: Dictionary = state.actors[buy.owner]
		buyer.cash = float(buyer.cash)+quantity*(float(buy.price)-price)
		incoming.remaining = maxf(0.0,float(incoming.remaining)-quantity)
		other.remaining = maxf(0.0,float(other.remaining)-quantity)
		# Tiny positive tails stay open and cancellable; never lock their reserve
		# by labelling a merely approximately empty order as fully filled.
		if float(incoming.remaining) == 0.0: incoming.state = "filled"
		if float(other.remaining) == 0.0: other.state = "filled"
		var trade := {"id":_id(state,"TRADE"),"buy_order":buy.id,"sell_order":sell.id,
			"buyer":buy.owner,"seller":sell.owner,"item":buy.item,"grade":buy.grade,"quantity":quantity,
			"unit_price":price,"escrow":total,"fee":total*FEE,"source_lots":source_lots,"matched":float(state.clock),"state":"awaiting_dispatch"}
		# 37 号 (player 2026-10-25: "list it at a price, someone buys, that's it"): the company is
		# paid when its listing sells; the goods go out on their own afterwards
		if sell.owner == PLAYER:
			var seller: Dictionary = state.actors[PLAYER]
			seller.cash = float(seller.cash)+total-total*FEE
			state.fees_collected = float(state.get("fees_collected",0.0))+total*FEE
			trade.escrow = 0.0
			trade.paid = true
		state.trades.append(trade)

static func buy_quote(state: Dictionary, identity: String, quantity: float, expected_price: float) -> Dictionary:
	# A quoted purchase is all-or-nothing against this exact sell order. Never
	# sweep another seller or leave a standing bid when the quote has changed.
	for order in state.orders:
		if order.id != identity: continue
		if order.owner == PLAYER or order.side != "sell" or order.state != "open" or order.has("target_order"):
			return {"ok":false,"reason":"quote_unavailable"}
		if not is_finite(expected_price) or expected_price != float(order.price):
			return {"ok":false,"reason":"quote_changed"}
		if not is_finite(quantity) or quantity <= EPS or quantity > float(order.remaining):
			return {"ok":false,"reason":"quote_quantity"}
		return post(state,PLAYER,"buy",str(order.item),int(order.grade),quantity,expected_price,{"target_order":identity})
	return {"ok":false,"reason":"quote_unavailable"}

static func cancel(state: Dictionary, owner: String, identity: String) -> Dictionary:
	for order in state.orders:
		if order.id != identity: continue
		if order.owner != owner: return {"ok":false,"reason":"not_owner"}
		if order.state != "open": return {"ok":false,"reason":"not_open"}
		var actor: Dictionary = state.actors[owner]
		if order.side == "buy":
			actor.cash = float(actor.cash)+float(order.cash_reserved)
			order.cash_reserved = 0.0
		else:
			var key := lot_key(str(order.item),int(order.grade))
			for slice in order.source_lots:
				var lot: Dictionary = actor.lots[slice.source_id]
				lot.available = float(lot.available)+float(slice.quantity)
			order.source_lots = []
			actor.stock[key] = float(actor.stock.get(key,0.0))+float(order.remaining)
		order.state = "cancelled"
		state.revision = int(state.revision)+1
		return {"ok":true}
	return {"ok":false,"reason":"unknown_order"}

static func book(state: Dictionary, item: String, grade: int, side: String) -> Array:
	var rows: Array = []
	for order in state.orders:
		if order.state == "open" and not order.has("contract_id") and order.item == item and int(order.grade) == grade and order.side == side: rows.append(order.duplicate(true))
	rows.sort_custom(func(a,b):
		if float(a.price) != float(b.price): return float(a.price) < float(b.price) if side == "sell" else float(a.price) > float(b.price)
		return str(a.id) < str(b.id))
	return rows

static func customer_status(state: Dictionary, identity: String) -> Dictionary:
	if not CUSTOMER_OFFERS.has(identity): return {"ok":false,"reason":"unknown_customer_offer"}
	var offer: Dictionary = CUSTOMER_OFFERS[identity]
	var found: Array = state.orders.filter(func(row):return row.get("contract_id","") == identity)
	if found.is_empty(): return {"ok":true,"state":"available","delivered":0.0,"matched":0.0,"remaining":float(offer.quantity),"order_id":""}
	var order: Dictionary = found[0]
	var delivered := 0.0
	var pending := false
	for trade in state.trades:
		if trade.buy_order != order.id: continue
		if trade.state == "delivered": delivered += float(trade.quantity)
		else: pending = true
	# A tiny positive uncommitted tail remains cancellable. Tolerance cannot
	# label a still-open budget as completed or hide an unpaid shipment.
	var status := "complete" if order.state == "filled" and not pending and delivered > EPS else ("cancelled" if order.state == "cancelled" else "active")
	return {"ok":true,"state":status,"delivered":delivered,"matched":float(order.quantity)-float(order.remaining),"remaining":float(order.remaining) if order.state == "open" else 0.0,"order_id":str(order.id)}

static func customer_command(state: Dictionary, action: String, identity: String, quantity: float = 0.0) -> Dictionary:
	var status := customer_status(state,identity)
	if not status.ok: return status
	var offer: Dictionary = CUSTOMER_OFFERS[identity]
	if action == "customer_accept":
		# 37 号: a client's budget is on the book by itself; accepting is no longer a step
		if status.state == "active": return {"ok":true,"order_id":str(status.order_id)}
		if status.state != "available": return {"ok":false,"reason":"customer_already_accepted"}
		return post(state,str(offer.buyer),"buy",str(offer.item),int(offer.grade),float(offer.quantity),float(offer.price),{"exclusive_seller":PLAYER,"contract_id":identity})
	if status.state != "active": return {"ok":false,"reason":"customer_not_active"}
	if action == "customer_cancel": return cancel(state,str(offer.buyer),str(status.order_id))
	if action == "customer_ship":
		if not is_finite(quantity) or quantity <= EPS or quantity > float(status.remaining): return {"ok":false,"reason":"customer_quantity"}
		return post(state,PLAYER,"sell",str(offer.item),int(offer.grade),quantity,float(offer.price),{"target_order":str(status.order_id)})
	return {"ok":false,"reason":"unknown_command"}

# Import an actual settled receiver batch once. Opening NPC holdings are external
# inventory; they never become player goods merely by opening the market.
# 64 号: the berth's cast ingots into the company's stock, once per job
static func import_ingots(state: Dictionary, batches: Array) -> void:
	var actor: Dictionary = state.actors[PLAYER]
	for batch in batches:
		var identity := str(batch.get("id", ""))
		var quantity := float(batch.get("mass_t", 0.0))
		if identity == "" or state.sources.has(identity) or not is_finite(quantity) or quantity <= EPS: continue
		state.sources[identity] = {"quantity": quantity, "item": "ferrous_scrap", "grade": 1}
		actor.lots[identity] = {"id": identity, "key": INGOT, "available": quantity, "total": quantity, "origin": "berth_furnace", "ship": str(batch.get("ship", ""))}
		actor.stock[INGOT] = float(actor.stock.get(INGOT, 0.0)) + quantity


# goods a buyer is offered (raw scrap hidden once the berth casts ingots)
static func buyable(key: String) -> bool:
	return not (INGOTS and key in RAW_HIDDEN)


static func import_received(state: Dictionary, batches: Array) -> void:
	var actor: Dictionary = state.actors[PLAYER]
	var key := lot_key("mixed_metal",0)
	for batch in batches:
		if batch.get("state","") != "raw_received" or batch.get("material","") != "ungraded_scrap": continue
		var identity := str(batch.get("id",""))
		var quantity := float(batch.get("mass_t",0.0))
		if identity == "" or state.sources.has(identity) or not is_finite(quantity) or quantity <= EPS: continue
		state.sources[identity] = {"quantity":quantity,"item":"mixed_metal","grade":0}
		actor.lots[identity] = {"id":identity,"key":key,"available":quantity,"total":quantity,"origin":"receiver"}
		# own salvage carries what its part was made of (G5.1); old receipts have no record
		var profile = batch.get("material_profile",{})
		if profile is Dictionary and int(profile.get("version",0)) == 1 and (profile.get("nonmagnetic_share",null) is float or profile.get("nonmagnetic_share",null) is int):
			actor.lots[identity].material_profile = profile.duplicate(true)
		actor.stock[key] = float(actor.stock.get(key,0.0))+quantity

static func advance(state: Dictionary, dt: float) -> void:
	if not is_finite(dt) or dt <= 0.0: return
	state.clock = float(state.clock)+dt
	_rush(state)
	# No expiration: neither player nor company orders are erased by a refresh.
	# NPC commands spend their actual opening budget/inventory, with bounded work
	# per update. Delivery is a separate physical/logistics integration gate.
	if float(state.clock) < float(state.get("npc_due",0.0)): return
	state.npc_due = float(state.clock)+10.0
	var turn := int(state.npc_turn)
	state.npc_turn = turn+1
	_npc_quote(state,turn)

# 39 号 (Q23; player 2026-10-25: "just a high bid with a time limit"): now and then one of the
# port's industrial clients bids high for grade 1 billet, from the company only, for ten minutes;
# list at or under it in time and it buys, or it lapses — no penalty either way
const RUSH_LIFE := 600.0
const RUSH_GAP := Vector2(360.0, 720.0)
const RUSH_K := Vector2(1.4, 1.8)
const RUSH_BUYERS := ["merchant_01", "merchant_02"]
static func rush_order(state: Dictionary) -> Dictionary:
	for o in state.get("orders",[]):
		if o.get("rush",false) and str(o.state) == "open": return o
	return {}
static func rush_minutes(state: Dictionary) -> int:
	var o := rush_order(state)
	return 0 if o.is_empty() else int(ceil(maxf(0.0,float(o.expires)-float(state.clock))/60.0))

# 45 号 (player 2026-10-25, the Delta Force exchange: "a recycle price and a market price side by
# side"): the port authority takes any stock at 70 % of the goods' usual price, paid at once; the
# goods still leave by the courier like any sale
const PORT_AUTHORITY := "port_authority"
const BUYBACK_K := 0.7
const REF_PRICE := {"mixed_metal:0": 140.0, "ferrous_scrap:0": 150.0, "ferrous_scrap:1": INGOT_PRICE, "nonferrous_mix:0": 700.0,
	"steel_billet:0": 400.0, "steel_billet:1": BILLET_PRICE, "steel_billet:2": 650.0,
	"steel_plate:1": 750.0, "steel_section:1": 720.0,
	"steel_slab:0": 420.0, "steel_slab:1": BILLET_PRICE + 30.0, "steel_slab:2": 680.0,
	"steel_small:0": 430.0, "steel_small:1": BILLET_PRICE + 50.0, "steel_small:2": 700.0}
static func ref_price(key: String) -> float:
	return float(REF_PRICE.get(key, 300.0))
static func buyback_price(key: String) -> float:
	return snappedf(ref_price(key) * BUYBACK_K, 10.0)
static func buyback(state: Dictionary, item: String, grade: int, quantity: float) -> Dictionary:
	var key := lot_key(item, grade)
	var have := float(state.actors[PLAYER].stock.get(key, 0.0))
	if not is_finite(quantity) or quantity <= EPS or quantity > have + EPS:
		return {"ok": false, "reason": "insufficient_stock"}
	quantity = minf(quantity, have)
	if not state.actors.has(PORT_AUTHORITY):
		state.actors[PORT_AUTHORITY] = {"name": "港务回收", "cash": 1.0e9, "stock": {}, "lots": {}, "fixed": true}
	var p := buyback_price(key)
	var r := post(state, PORT_AUTHORITY, "buy", item, grade, quantity, p, {"exclusive_seller": PLAYER})
	if not r.ok:
		return r
	var sold := post(state, PLAYER, "sell", item, grade, quantity, p, {"target_order": str(r.order_id)})
	if not sold.ok:
		cancel(state, PORT_AUTHORITY, str(r.order_id))
	return sold

# what an immediate sale of this goods fetches: the best bid the company may sell into
static func best_bid(state: Dictionary, item: String, grade: int) -> Dictionary:
	var best := {}
	for o in state.get("orders", []):
		if str(o.state) != "open" or str(o.side) != "buy" or str(o.item) != item or int(o.grade) != grade or str(o.owner) == PLAYER:
			continue
		if o.get("exclusive_seller", PLAYER) != PLAYER or o.has("target_order") or str(o.owner) == PORT_AUTHORITY:
			continue
		if best.is_empty() or float(o.price) > float(best.price):
			best = o
	return best

# list against the open rush at its price: as much as it still wants and the company has
static func rush_sell(state: Dictionary, quantity := -1.0) -> Dictionary:
	var o := rush_order(state)
	if o.is_empty(): return {"ok":false,"reason":"no_rush"}
	var have := float(state.actors[PLAYER].stock.get(lot_key("steel_billet",1),0.0))
	var q := minf(float(o.remaining),have) if quantity <= 0.0 else quantity
	if q <= EPS: return {"ok":false,"reason":"insufficient_stock"}
	return post(state,PLAYER,"sell","steel_billet",1,q,float(o.price),{"target_order":str(o.id)})

static func _rush(state: Dictionary) -> void:
	var now := float(state.clock)
	for o in state.get("orders",[]):
		if o.get("rush",false) and str(o.state) == "open" and now >= float(o.expires):
			cancel(state,str(o.owner),str(o.id))
	if not rush_order(state).is_empty(): return
	if not state.has("rush_next"):
		state.rush_next = now+120.0
		return
	if now < float(state.rush_next) or Career.data.is_empty() or Port.stage("trade") < 1: return
	var n := int(state.get("rush_count",0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 9173 + n * 31
	var who: String = RUSH_BUYERS[n % RUSH_BUYERS.size()]
	var q := 0.5 * float(rng.randi_range(1, 3))
	var price := snappedf(BILLET_PRICE * rng.randf_range(RUSH_K.x, RUSH_K.y), 10.0)
	state.rush_count = n+1
	state.rush_next = now+RUSH_LIFE+rng.randf_range(RUSH_GAP.x, RUSH_GAP.y)
	var r := post(state,who,"buy","steel_billet",1,q,price,{"exclusive_seller":PLAYER})
	if not r.ok: return
	for o in state.orders:
		if str(o.id) == str(r.order_id):
			o.rush = true
			o.expires = now+RUSH_LIFE

static func _npc_quote(state: Dictionary, turn: int) -> void:
	var owner := "merchant_%02d" % (turn%24)
	# a fixture of the local-freight checks (31 号): the belt's merchants kept off the book
	if state.get("belt_quiet",false) and turn%24 >= 3: return
	for order in state.orders:
		if order.owner == owner and order.state == "open": return
	var actor: Dictionary = state.actors[owner]
	if INGOTS:
		# 64 号: the belt's merchants buy the port's ingots
		var bid := INGOT_PRICE - 20.0 + float(turn % 5) * 10.0
		var want := minf(10.0 + float(turn % 4) * 5.0, float(actor.cash) / bid)
		if want > EPS: post(state, owner, "buy", "ferrous_scrap", 1, want, bid)
		return
	var available := float(actor.stock.get(lot_key("mixed_metal",0),0.0))
	var side := "sell" if available > 1.0 else "buy"
	var price := 300.0+float(turn%7)*12.0 if side == "sell" else 290.0+float(turn%5)*18.0
	var quantity := minf(2.0,available) if side == "sell" else minf(2.0,float(actor.cash)/price)
	if quantity > EPS: post(state,owner,side,"mixed_metal",0,quantity,price)

static func seed_book(state: Dictionary) -> void:
	if INGOTS and not state.get("ingot_seeded", false):
		# 64 号: the three port companies stand ready to buy ingots; no raw scrap is offered
		state.sorting_seeded = true
		state.offspec_seeded = true
		state.catalog_revision = maxi(1, int(state.get("catalog_revision", 0)))
		state.industrial_seeded = true
		post(state, "merchant_00", "buy", "ferrous_scrap", 1, 30.0, INGOT_PRICE)
		post(state, "merchant_02", "buy", "ferrous_scrap", 1, 15.0, INGOT_PRICE - 10.0)
		post(state, "merchant_01", "buy", "steel_billet", 1, 2.0, BILLET_PRICE)
		state.ingot_seeded = true
	if not state.get("sorting_seeded",false):
		# A new finite external supplier also gives older aggregate-only careers
		# a source with actual authored material data. Never assign invented
		# composition to existing owned lots or replenish this opening stock.
		var identity := "opening:sort_supplier:mixed_metal:0"
		state.actors.sort_supplier = {"name":"中衡再生","cash":12000.0,"fixed":true,"stock":{"mixed_metal:0":2.0},"lots":{identity:{"id":identity,"key":"mixed_metal:0","available":2.0,"total":2.0,"origin":"external_opening_inventory","material_profile":{"version":1,"nonmagnetic_share":0.28,"basis":"authored_opening_material"}}}}
		post(state,"sort_supplier","sell","mixed_metal",0,2.0,420.0)
		post(state,"merchant_02","buy","ferrous_scrap",0,2.0,350.0)
		post(state,"merchant_03","buy","nonferrous_mix",0,2.0,700.0)
		state.sorting_seeded = true
	if not state.get("offspec_seeded",false):
		post(state,"merchant_02","buy","steel_billet",0,2.0,250.0)
		state.offspec_seeded = true
	# One declared external opening consignment for careers predating the new
	# feedstock category. This is finite merchant stock, never player inventory.
	if int(state.get("catalog_revision",0)) < 1:
		var actor: Dictionary = state.actors["merchant_00"]
		var key := lot_key("ferrous_scrap",1)
		var identity := "opening:merchant_00:"+key
		if not actor.lots.has(identity):
			actor.lots[identity] = {"id":identity,"key":key,"available":6.0,"total":6.0,"origin":"external_opening_inventory"}
			actor.stock[key] = float(actor.stock.get(key,0.0))+6.0
		state.catalog_revision = 1
	if not state.get("industrial_seeded",false):
		post(state,"merchant_00","sell","ferrous_scrap",1,2.0,450.0)
		post(state,"merchant_01","buy","steel_billet",1,2.0,BILLET_PRICE)
		state.industrial_seeded = true
	if state.get("seeded",false): return
	for i in 24: _npc_quote(state,i)
	state.seeded = true
	state.npc_turn = 24

static func sync_batches(data: Dictionary, state: Dictionary) -> void:
	var lots: Dictionary = state.actors[PLAYER].lots
	for batch in data.get("material_batches",[]):
		if not lots.has(str(batch.get("id",""))): continue
		var lot: Dictionary = lots[str(batch.id)]
		batch.storage = "exchange"
		batch.available_t = float(lot.available)
		batch.consumed_t = float(lot.get("consumed",0.0))
		batch.reserved_t = maxf(0.0,float(lot.total)-float(lot.available)-float(lot.get("consumed",0.0)))

# This production boundary requires the actual colliding cargo and actual
# monitoring receiver, not a UI "delivered" button or a supplied boolean.
static func confirm_local_receipt(identity: String, body: FreeBody, receiver: Area2D) -> Dictionary:
	var existing: Dictionary = Career.data.get("exchange",{})
	if existing.is_empty(): return {"ok":false,"reason":"unknown_trade"}
	var found: Array = existing.trades.filter(func(trade):return trade.id == identity)
	if found.is_empty(): return {"ok":false,"reason":"unknown_trade"}
	if found[0].state == "delivered": return {"ok":true,"already_delivered":true}
	if not is_instance_valid(body) or not is_instance_valid(receiver) or not receiver.get_meta("exchange_receiver",false) or not receiver.overlaps_body(body):
		return {"ok":false,"reason":"delivery_geometry"}
	var shape_node := receiver.get_node_or_null("Shape") as CollisionShape2D
	if shape_node == null or not shape_node.shape is RectangleShape2D: return {"ok":false,"reason":"delivery_geometry"}
	var shape := shape_node.shape as RectangleShape2D
	var region := Rect2(receiver.global_position-shape.size*0.5,shape.size)
	if body.collision_mask != FreeBody.MASK or body.get_meta("exchange_trade","") != identity or not region.encloses(preload("res://scripts/load_motion.gd").bounds(body)):
		return {"ok":false,"reason":"delivery_geometry"}
	var current: Dictionary = found[0]
	var expected_side := "warehouse" if current.buyer == PLAYER else "client"
	if current.state not in ["loading","in_transit"] or receiver.get_meta("exchange_side","") != expected_side:
		return {"ok":false,"reason":"delivery_receiver"}
	if body.pieces.size() != 1 or body.pieces[0].key != str(current.get("cargo_key","")) or absf(body.total_mass()-float(current.quantity)) > 0.000001:
		return {"ok":false,"reason":"delivery_cargo"}
	return commit_delivery(identity,{"key":str(body.pieces[0].key),"mass_t":body.total_mass(),"at":[body.global_position.x,body.global_position.y],"receiver":str(receiver.name)})

# The custody change itself, once the goods have actually arrived: at a local receiver above,
# or for orbital freight (scripts/shipping.gd) when the last bale is in the warehouse or the
# buyer's hull is home. The caller has checked the physical evidence.
static func commit_delivery(identity: String, receipt: Dictionary) -> Dictionary:
	var existing: Dictionary = Career.data.get("exchange",{})
	if existing.is_empty(): return {"ok":false,"reason":"unknown_trade"}
	var found: Array = existing.trades.filter(func(trade):return trade.id == identity)
	if found.is_empty(): return {"ok":false,"reason":"unknown_trade"}
	if found[0].state == "delivered": return {"ok":true,"already_delivered":true}
	if found[0].state not in ["loading","in_transit"]: return {"ok":false,"reason":"delivery_receiver"}
	var before := Career.data
	Career.data = before.duplicate(true)
	var state: Dictionary = Career.data.exchange
	state.actors[PLAYER].cash = float(Career.data.money)
	var trade: Dictionary = state.trades.filter(func(row):return row.id == identity)[0]
	var seller: Dictionary = state.actors[trade.seller]
	var buyer: Dictionary = state.actors[trade.buyer]
	var source_mass := 0.0
	for slice in trade.source_lots:
		var source: Dictionary = seller.lots.get(str(slice.source_id),{})
		if source.is_empty() or float(source.get("consumed",0.0))+float(slice.quantity) > float(source.total)+EPS:
			Career.data = before
			return {"ok":false,"reason":"delivery_source"}
		source_mass += float(slice.quantity)
	if absf(source_mass-float(trade.quantity)) > 0.000001:
		Career.data = before
		return {"ok":false,"reason":"delivery_source"}
	for slice in trade.source_lots:
		var source: Dictionary = seller.lots[str(slice.source_id)]
		source.consumed = float(source.get("consumed",0.0))+float(slice.quantity)
	var batch_id := "DELIVERED:"+identity
	var key := lot_key(str(trade.item),int(trade.grade))
	buyer.stock[key] = float(buyer.stock.get(key,0.0))+float(trade.quantity)
	buyer.lots[batch_id] = {"id":batch_id,"key":key,"available":float(trade.quantity),"total":float(trade.quantity),"origin":"physical_delivery","parents":trade.source_lots.duplicate(true)}
	# Carry the real source's material description through custody; missing
	# old descriptions stay unknown. This is not a chemical quality assay.
	var profile := source_profile(seller,trade.source_lots,float(trade.quantity))
	if profile.ok: buyer.lots[batch_id].material_profile = profile.profile
	if trade.buyer == PLAYER:
		state.sources[batch_id] = {"quantity":float(trade.quantity),"item":str(trade.item),"grade":int(trade.grade)}
		var batches: Array = Career.data.get("material_batches",[])
		batches.append({"id":batch_id,"mass_t":float(trade.quantity),"grade":int(trade.grade),"material":"ungraded_scrap" if trade.item == "mixed_metal" else str(trade.item),"state":"raw_received" if trade.item in ["mixed_metal","ferrous_scrap"] else "product_received","trade_id":identity,"source_lots":trade.source_lots.duplicate(true),"recovery_value":0.0,"storage":"exchange"})
		Career.data.material_batches = batches
	# a company sale was paid when it sold (37 号): delivery only moves the goods
	var proceeds := 0.0 if trade.get("paid",false) else float(trade.escrow)-float(trade.fee)
	seller.cash = float(seller.cash)+proceeds
	if not trade.get("paid",false): state.fees_collected = float(state.get("fees_collected",0.0))+float(trade.fee)
	trade.escrow = 0.0
	trade.state = "delivered"
	trade.delivered_at = float(state.clock)
	trade.receipt = receipt.duplicate(true)
	state.revision = int(state.revision)+1
	Career.data.money = float(state.actors[PLAYER].cash)
	sync_batches(Career.data,state)
	if not Career.save():
		Career.data = before
		return {"ok":false,"reason":"save_failed"}
	return {"ok":true,"trade_id":identity,"proceeds":proceeds,"batch_id":batch_id}

static func source_profile(actor: Dictionary,slices: Array,quantity: float) -> Dictionary:
	if not is_finite(quantity) or quantity <= EPS: return {"ok":false}
	var total := 0.0
	var nonmagnetic := 0.0
	var seen := {}
	for slice in slices:
		if not slice is Dictionary or not (slice.get("quantity",null) is float or slice.get("quantity",null) is int): return {"ok":false}
		var identity := str(slice.get("source_id",""))
		if seen.has(identity): return {"ok":false}
		seen[identity] = true
		var lot = actor.get("lots",{}).get(identity,{})
		if not lot is Dictionary: return {"ok":false}
		var profile = lot.get("material_profile",{})
		if not profile is Dictionary: return {"ok":false}
		if int(profile.get("version",0)) != 1 or not (profile.get("nonmagnetic_share",null) is float or profile.get("nonmagnetic_share",null) is int): return {"ok":false}
		var share := float(profile.nonmagnetic_share)
		var amount := float(slice.quantity)
		if not is_finite(amount) or amount <= 0.0 or not is_finite(share) or share < 0.0 or share > 1.0: return {"ok":false}
		total += amount
		nonmagnetic += share*amount
	if absf(total-quantity) > EPS: return {"ok":false}
	return {"ok":true,"profile":{"version":1,"nonmagnetic_share":nonmagnetic/quantity,"basis":"source_custody"}}

# Called by the active scene owner only. Overlay panels never advance time.
static func advance_career(dt: float) -> void:
	if Career.data.get("exchange",{}).is_empty(): return
	var state: Dictionary = Career.data.exchange
	if not migrate(state).ok: return
	state.actors[PLAYER].cash = float(Career.data.money)
	advance(state,dt)
	Career.data.money = float(state.actors[PLAYER].cash)

# Atomic production adapter. Viewing creates persistent company identities once;
# trading is gated by actual repaired trade stage, not a new purchase flag.
static func command(action: String, args: Dictionary = {}) -> Dictionary:
	if not Career.usable(): return {"ok":false,"reason":"career_unavailable"}
	if not Career.data.get("market",false): return {"ok":false,"reason":"market_not_open"}
	if action != "view" and Port.stage("trade") < 1: return {"ok":false,"reason":"trade_repair_required"}
	# 128 号 返工: no new listing of any kind while the exchange is shut (withdrawing stays open)
	if action not in ["view", "cancel"] and not StoreBook.exchange_usable(): return {"ok":false,"reason":"exchange_closed"}
	var before := Career.data
	Career.data = before.duplicate(true)
	var state: Dictionary = Career.data.get("exchange",{})
	if state.is_empty(): state = fresh(float(Career.data.money))
	var migration := migrate(state)
	if not migration.ok:
		Career.data = before
		return migration
	seed_book(state)
	state.actors[PLAYER].cash = float(Career.data.money)
	# 37 号: the industrial clients' budgets stand on the book on their own, buying the company's listings
	if Port.stage("trade") >= 1 and StoreBook.exchange_usable():
		for identity in CUSTOMER_OFFERS:
			if customer_status(state,identity).get("state","") == "available":
				customer_command(state,"customer_accept",identity)
	import_received(state,Career.data.get("material_batches",[]))
	import_ingots(state, Career.data.get("ingot_batches", []))
	var result := {"ok":true}
	match action:
		"view": pass
		"post": result = post(state,PLAYER,str(args.get("side","")),str(args.get("item","")),int(args.get("grade",0)),float(args.get("quantity",0.0)),float(args.get("price",0.0)))
		"buy_quote": result = buy_quote(state,str(args.get("order_id","")),float(args.get("quantity",0.0)),float(args.get("price",0.0)))
		"cancel": result = cancel(state,PLAYER,str(args.get("order_id","")))
		"rush_sell": result = rush_sell(state,float(args.get("quantity",-1.0)))
		"buyback": result = buyback(state,str(args.get("item","")),int(args.get("grade",0)),float(args.get("quantity",0.0)))
		"customer_accept","customer_ship","customer_cancel": result = customer_command(state,action,str(args.get("offer_id","")),float(args.get("quantity",0.0)))
		_: result = {"ok":false,"reason":"unknown_command"}
	if not result.ok:
		Career.data = before
		return result
	Career.data.exchange = state
	Career.data.money = float(state.actors[PLAYER].cash)
	sync_batches(Career.data,state)
	if not Career.save():
		Career.data = before
		return {"ok":false,"reason":"save_failed"}
	return result
