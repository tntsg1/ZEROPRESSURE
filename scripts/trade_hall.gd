extends Node2D
# The trade district's hall (design/…/38 号, G5.2; 13 号 Q11/Q16, 23 号 Q15): the three big
# companies' counters along the north wall — a desk behind glass, the company's plate and a small
# screen with what it is buying and selling now; the quote board on the south wall with the
# whole port's best bid / best ask / last price, the port's counters marked near and the belt's
# merchants far; and, at the warehouse yard, the client lighter that comes for what the companies
# bought from you (and brings what you bought from them). E at a counter opens the exchange at
# that company. Drawn in world units (the text scales with the camera; redrawn once a second).

const Exchange = preload("res://scripts/industrial_exchange.gd")
const CanvasBatch = preload("res://scripts/canvas_batch.gd")
const COMPANIES := ["merchant_00", "merchant_01", "merchant_02"]
const COUNTER_W := 9.0         # m
const REACH := 3.0             # m: close enough to a counter to be served
const TradeWorks = preload("res://scripts/trade_works.gd")
const TradeArt = preload("res://scripts/trade_hall_art.gd")

var game
var walls: StaticBody2D
var font: Font
var font_b: Font
var _t := 9.0                 # draws on its first frame
var draws := 0                # tests: how often it was drawn
var lighter_k := 0.0           # 0 away … 1 alongside (98 号: in the hall's own east port, TradeWorks)
var lighter_for := ""          # the company whose lighter it is
var art                        # 98 号: the hall as the place it is (scripts/trade_hall_art.gd)
var moving: Node2D             # what moves, drawn every frame
var card                       # the facility card (scripts/facility_card.gd)
var tick_us := 0.0             # 98 号: what it costs a frame (µs, smoothed): its machines' step, its moving drawing
var draw_us := 0.0


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


func active() -> bool:
	return game != null and game.in_berth() and game.career() and Career.usable()


# a counter's desk, world px rect
static func counter_rect(i: int) -> Rect2:
	var b := PortStructure.box("trade")
	var m := PortStructure.M()
	# 98 号: under the quote board, the dock below the hall floor
	return Rect2(b.position + Vector2(20.0 + i * 12.0, 7.6) * m, Vector2(COUNTER_W, 2.4) * m)


# where the operator stands to be served: in front of the desk
static func counter_spot(i: int) -> Vector2:
	var r := counter_rect(i)
	return Vector2(r.get_center().x, r.end.y + 2.0 * PortStructure.M())


static func board_rect() -> Rect2:
	var b := PortStructure.box("trade")
	var m := PortStructure.M()
	return Rect2(b.position + Vector2(18.0, 0.5) * m, Vector2(36.0, 5.9) * m)


func _ready() -> void:
	z_index = 3
	z_as_relative = false
	font = Fonts.get_font("Regular")
	font_b = Fonts.get_font("Medium")
	TradeWorks.reset()
	art = TradeArt.new()
	art.font = font
	art.font_b = font_b
	moving = Node2D.new()
	moving.draw.connect(_draw_moving)
	add_child(moving)
	card = preload("res://scripts/facility_card.gd").new()
	card.items = func() -> Array: return art.hover_items(_names()) if visible and PortArt.inside == "trade" else []
	add_child(card)
	walls = StaticBody2D.new()
	walls.collision_layer = 4
	walls.collision_mask = 0
	add_child(walls)
	for i in COMPANIES.size():
		var r := counter_rect(i)
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(r.size.x, r.size.y * 0.5)
		cs.shape = sh
		cs.position = r.get_center() + Vector2(0, r.size.y * 0.25)
		walls.add_child(cs)


func near_counter() -> String:
	if not active() or game.drone == null or not game.drone.alive or Port.stage("trade") < 1:
		return ""
	for i in COMPANIES.size():
		if game.drone.global_position.distance_to(counter_spot(i)) <= REACH * Geom.M:
			return COMPANIES[i]
	return ""


# a company trade with one of the port's counters, under way: the lighter's
func _local_trade() -> Dictionary:
	# 128 号 第 2 段: an order's client freighter alongside — the dock's crane loads its crates
	for o in HallMarket.orders():
		if str(o.state) == "ship" and str(HallMarket.ship_phase(o)[0]) == "load" and not bool(o.get("loaded", false)):
			return {"id": "hall:" + str(o.id), "state": "loading", "seller": Exchange.PLAYER, "buyer": "hall_client", "quantity": 0.5 * int(o.get("crates", 1))}
	for t in Career.data.get("exchange", {}).get("trades", []):
		if str(t.state) in ["awaiting_dispatch", "loading", "in_transit"] and not Shipping.orbital(t) and Shipping.other(t) in COMPANIES:
			return t
	return {}


func _process(dt: float) -> void:
	visible = active()
	walls.process_mode = Node.PROCESS_MODE_INHERIT if visible else Node.PROCESS_MODE_DISABLED
	if card != null:
		card.game = game
	if not visible:
		return
	var t0 := Time.get_ticks_usec()
	TradeWorks.tick(dt, _local_trade(), near_counter(), COMPANIES)
	tick_us = lerpf(tick_us, float(Time.get_ticks_usec() - t0), 0.05)
	# its one-shots, heard only near it
	if not TradeWorks.events.is_empty():
		var nk := near_k()
		for e in TradeWorks.events:
			if nk > 0.0 and game.get("sfx") != null:
				game.sfx.play(str(e[0]), PortStructure.box("trade").position + (e[1] as Vector2) * PortStructure.M(), 0.7 * nk)
		TradeWorks.events.clear()
	lighter_k = TradeWorks.lighter_k
	lighter_for = TradeWorks.lighter_for
	_t += dt
	if _t > 1.0:
		_t = 0.0
		queue_redraw()
	# 108 号 帧率: only while its part of the port is in view (scripts/view_cull.gd)
	if ViewCull.sees_zone(game, "trade", 30.0):
		moving.queue_redraw()


# 1 with the drone in the trade port, 0.5 within 30 m of it, else 0
func near_k() -> float:
	if game == null or game.get("drone") == null:
		return 0.0
	var b := PortStructure.box("trade")
	var p: Vector2 = game.drone.global_position
	if b.has_point(p):
		return 1.0
	return 0.5 if b.grow(30.0 * PortStructure.M()).has_point(p) else 0.0


func _names() -> Dictionary:
	return Career.data.get("exchange", {}).get("actors", {})


# how much to draw: 1 (every bolt) when a metre is big enough on screen
func lod() -> int:
	var z := get_viewport().get_canvas_transform().get_scale().x if is_inside_tree() else 1.0
	return 1 if PortStructure.M() * z >= 14.0 else 0


func _inside_view() -> bool:
	return PortArt.inside == "trade" or game.cam_zoom() >= 0.3


func _draw_moving() -> void:
	if not active():
		return
	art.r = PortStructure.box("trade")
	art.m = PortStructure.M()
	var t0 := Time.get_ticks_usec()
	var inside := _inside_view()
	art.moving(moving, TradeWorks.t, Port.stage("trade") >= 1, inside, _names())
	if inside:
		art.ticker(moving, TradeWorks.t)
	draw_us = lerpf(draw_us, float(Time.get_ticks_usec() - t0), 0.05)


# the book: best bid, best ask and last price per goods, and who is quoting
static func board() -> Array:
	var st: Dictionary = Career.data.get("exchange", {})
	var rows: Array = []
	for item in Exchange.CATALOG:
		for grade in Exchange.CATALOG[item].grades:
			var bid := 0.0
			var ask := INF
			var near := false
			var far := false
			var rush := false
			for o in st.get("orders", []):
				if str(o.state) != "open" or str(o.item) != item or int(o.grade) != int(grade) or str(o.owner) == Exchange.PLAYER:
					continue
				rush = rush or o.get("rush", false)
				if str(o.side) == "buy":
					bid = maxf(bid, float(o.price))
				else:
					ask = minf(ask, float(o.price))
				if str(o.owner) in COMPANIES:
					near = true
				else:
					far = true
			var bid_t := 0.0
			var ask_t := 0.0
			for o in st.get("orders", []):
				if str(o.state) == "open" and str(o.item) == item and int(o.grade) == int(grade) and str(o.owner) != Exchange.PLAYER:
					if str(o.side) == "buy":
						bid_t += float(o.remaining)
					else:
						ask_t += float(o.remaining)
			var last := 0.0
			for tr in st.get("trades", []):
				if str(tr.item) == item and int(tr.grade) == int(grade):
					last = float(tr.unit_price)
			if bid > 0.0 or ask < INF:
				rows.append({"name": Ops.item_name(Exchange.lot_key(item, int(grade))), "key": Exchange.lot_key(item, int(grade)), "bid": bid, "ask": ask, "last": last,
					"near": near, "far": far, "rush": rush, "bid_t": bid_t, "ask_t": ask_t})
	return rows


# 49 号 (player 2026-10-25: "it just says property, logistics, works — the trade port looks
# fake"): what each company is really doing, read off the book — for its stand in front of its
# counter: what it sells (sample cabinet), what it buys, its last deals (ledger), its open
# deliveries with the company (dockets), the last load weighed; dark with no business
static func scene_of(who: String) -> Dictionary:
	var st: Dictionary = Career.data.get("exchange", {})
	var sells := {}
	var buys: Array = []
	for o in st.get("orders", []):
		if str(o.owner) != who or str(o.state) != "open":
			continue
		var k := Exchange.lot_key(str(o.item), int(o.grade))
		if str(o.side) == "sell":
			if not sells.has(k):
				sells[k] = {"key": k, "price": float(o.price), "t": 0.0}
			sells[k].price = minf(float(sells[k].price), float(o.price))
			sells[k].t += float(o.remaining)
		else:
			buys.append({"key": k, "price": float(o.price), "t": float(o.remaining), "rush": o.get("rush", false)})
	var ledger: Array = []
	var dockets: Array = []
	var weighed := 0.0
	for tr in st.get("trades", []):
		if str(tr.buyer) != who and str(tr.seller) != who:
			continue
		ledger.append({"key": Exchange.lot_key(str(tr.item), int(tr.grade)), "t": float(tr.quantity), "price": float(tr.unit_price)})
		weighed = float(tr.quantity)
		var mine: bool = str(tr.buyer) == Exchange.PLAYER or str(tr.seller) == Exchange.PLAYER
		if mine and str(tr.state) != "delivered":
			dockets.append({"id": str(tr.id), "key": Exchange.lot_key(str(tr.item), int(tr.grade)), "t": float(tr.quantity), "state": str(tr.state)})
	var rush := Exchange.rush_order(st)
	return {"sells": sells.values(), "buys": buys, "ledger": ledger.slice(maxi(0, ledger.size() - 3)), "dockets": dockets, "weighed": weighed,
		"rush": rush if not rush.is_empty() and str(rush.owner) == who else {}, "lit": not sells.is_empty() or not buys.is_empty()}


static func quotes_of(owner: String) -> Array:
	var out: Array = []
	for o in Career.data.get("exchange", {}).get("orders", []):
		if str(o.owner) == owner and str(o.state) == "open":
			out.append(o)
	return out


# the company's main business: its biggest open order (what it buys or sells most of now)
static func main_deal(who: String) -> Dictionary:
	var sc := scene_of(who)
	var best := {}
	for b in sc.buys:
		if best.is_empty() or float(b.t) > float(best.t):
			best = {"side": "buy", "key": str(b.key), "price": float(b.price), "t": float(b.t)}
	for s in sc.sells:
		if best.is_empty() or float(s.t) > float(best.t):
			best = {"side": "sell", "key": str(s.key), "price": float(s.price), "t": float(s.t)}
	return best


func _draw() -> void:
	if not active() or not _inside_view():
		return
	draws += 1
	art.r = PortStructure.box("trade")
	art.m = PortStructure.M()
	var on := Port.stage("trade") >= 1
	art.still(self, on, lod())
	art.board(self, board())
	art.signs(self, _names(), near_counter())
