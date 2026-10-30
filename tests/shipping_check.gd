extends "res://tests/guide_check.gd"
# 31 号: orbital shipping. A buy from a belt merchant sends a real freighter on a Lambert arc;
# it moors at the pier, its goods are bodies in the hold, they count as stock only inside the
# warehouse receiver; a second ship waiting makes the crew put the first's goods on the apron;
# the cargo district's crane hauls on its own; selling is the same the other way round, paid
# when the buyer's hull is home. The big three stay on the local freight. Own test saves only.
#   tools/run_test.sh tests/shipping_check.gd --fixed-fps 60
const Ex = preload("res://scripts/industrial_exchange.gd")


func _initialize() -> void:
	# 64 号: these check buying and its freight / lighter delivery from merchants' sell orders;
	# merchants no longer offer scrap in play, so they run on the older rules
	Career.INGOTS = false
	preload("res://scripts/industrial_exchange.gd").INGOTS = false
	Career.path = "user://zp_test_shipping_career.json"
	SaveGame.path = "user://zp_test_shipping_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _sell_order(item: String, min_index: int, max_index: int) -> Dictionary:
	for o in Career.data.exchange.orders:
		if str(o.side) == "sell" and str(o.state) == "open" and str(o.item) == item and float(o.remaining) >= 1.0:
			var k := Shipping.merchant_index(str(o.owner))
			if k >= min_index and k <= max_index:
				return o
	return {}


func _buy_from(min_index: int, max_index: int, q: float) -> Dictionary:
	var o := _sell_order("mixed_metal", min_index, max_index)
	if o.is_empty():
		return {}
	var r := Ex.command("buy_quote", {"order_id": str(o.id), "quantity": minf(q, float(o.remaining)), "price": float(o.price)})
	if not r.ok:
		print("buy refused: ", r)
		return {}
	var trades: Array = Career.data.exchange.trades
	return trades[trades.size() - 1]


func _stock(key: String) -> float:
	return float(Career.data.exchange.actors.company.stock.get(key, 0.0))


func _arrive(s: Dictionary) -> void:
	Shipping.data().day = float(s.run.depart) + float(s.run.tof) + 0.01
	await _frames(3)
	if g.freight_pier.hulls.has(str(s.id)):
		g.freight_pier.hulls[str(s.id)].t = 99.0
	await _frames(4)


func _into(b, area_pos: Vector2) -> void:
	b.global_position = area_pos
	b.linear_velocity = Vector2.ZERO
	await _frames(3)


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 500000.0
	Career.data.port = {"salvage": 1, "trade": 1}
	Career.data.drill = {"granted": true, "done": true}
	Career.save()
	await _spawn()
	await _frames(10)
	check(Ex.command("view").ok, "the exchange opens")
	check(g.freight_pier != null and g.freight_pier.visible, "the freight pier stands off the warehouse yard")
	# --- buying from the belt
	var t := _buy_from(3, 23, 3.0)
	check(not t.is_empty() and Shipping.orbital(t), "a buy from an independent merchant is orbital freight")
	await _frames(3)
	var s := Shipping.ship_for(str(t.get("id", "")))
	check(not s.is_empty() and str(s.state) == "inbound", "a freighter leaves the merchant's station (%s)" % str(s.get("id", "")))
	if s.is_empty():
		_end()
		return
	var run: Dictionary = s.run
	check(float(run.tof) >= 45.0 and float(run.tof) <= Orbits.STRETCH_MAX + 0.01 and float(run.dv1) > 0.0 and float(run.dv2) > 0.0, "it flies a Lambert arc: %d days, Δv %.1f + %.1f km/s" % [int(run.tof), float(run.dv1), float(run.dv2)])
	check(Orbits.on_transfer(run, 1.0).distance_to(Orbits.pos(Orbits.PORT, float(run.depart) + float(run.tof))) < 1e-3, "the arc ends where the port will be")
	check(g.exchange_logistics.active != str(t.id), "the local freight leaves it alone")
	check(s.pieces.size() == int(ceil(float(t.quantity) / 2.0 - 1e-9)), "%.2f t travel as %d bales of at most 2 t" % [float(t.quantity), s.pieces.size()])
	var before := _stock("mixed_metal:0")
	Shipping.data().day = float(run.depart) + float(run.tof) * 0.45
	g.open_star_map()
	await _frames(6)
	g.console_ui.chosen = str(s.id)
	await _frames(40)
	Cap.save(root, "res://tests/out/shipping_map_zh.png")
	g.console_ui.close()
	await _frames(4)
	await _arrive(s)
	s = Shipping.ship_for(str(t.id))
	check(str(s.state) == "docked" and int(s.slot) == 0, "on arrival it takes berth 1")
	await _frames(6)
	var bodies: Array = []
	for p in s.pieces:
		if g.freight_pier.bodies.has(str(p.key)):
			bodies.append(g.freight_pier.bodies[str(p.key)])
	check(bodies.size() == s.pieces.size(), "its goods are bodies in the hold")
	check(is_equal_approx(_stock("mixed_metal:0"), before), "nothing is stock while it sits in the hold")
	g.drone.global_position = g.freight_pier._px(Vector2(30, 0))
	g.drone.linear_velocity = Vector2.ZERO
	await _frames(40)
	Cap.save(root, "res://tests/out/shipping_pier_zh.png")
	g.cam_override = g.freight_pier._px(Vector2(55, 0))
	g.zoom_override = 0.16
	await _frames(60)
	Cap.save(root, "res://tests/out/shipping_pier_far_zh.png")
	g.cam_override = null
	g.zoom_override = -1.0
	# the operator hauls the first bale in
	g.guide.begin("collect")
	await _frames(12)
	check(str(g.guide.step.get("title", "")).find("船位") >= 0, "the collect guide sends the operator to the berth (%s)" % g.guide.step.get("title", ""))
	for k in bodies.size():
		await _into(bodies[k], g.exchange_logistics.warehouse.global_position)
		if k == 0 and bodies.size() > 1:
			check(is_equal_approx(_stock("mixed_metal:0"), before) and str(_trade(str(t.id)).state) != "delivered", "one bale in: the trade waits for the rest")
	await _frames(4)
	var tr := _trade(str(t.id))
	check(str(tr.state) == "delivered" and is_equal_approx(_stock("mixed_metal:0"), before + float(t.quantity)), "all in: %.2f t in stock" % _stock("mixed_metal:0"))
	check(str(Shipping.ship_for(str(t.id)).state) == "leaving", "the empty hull heads home")
	await _frames(12)
	check(not g.guide.active() or str(g.guide.note).find("搬完") >= 0, "the collect guide ends when the pier is clear")
	# --- two ships, one berth: the crew puts the first's goods on the apron
	var t1 := _buy_from(3, 12, 2.0)
	var t2 := _buy_from(13, 23, 2.0)
	await _frames(3)
	var s1 := Shipping.ship_for(str(t1.get("id", "")))
	var s2 := Shipping.ship_for(str(t2.get("id", "")))
	if not s1.is_empty() and not s2.is_empty():
		await _arrive(s1)
		s1 = Shipping.ship_for(str(t1.id))
		check(str(s1.state) == "docked", "the first takes the only berth")
		await _arrive(s2)
		s1 = Shipping.ship_for(str(t1.id))
		s2 = Shipping.ship_for(str(t2.id))
		check(str(s2.state) == "docked" and str(s1.state) == "leaving" and str(s1.pieces[0].where) == "apron", "the second needs it: the first's goods go on the apron, the first leaves")
		await _frames(8)
		var ab = g.freight_pier.bodies.get(str(s1.pieces[0].key))
		check(ab != null and is_instance_valid(ab), "the apron bale is a body on the pier")
		check(str(_trade(str(t1.id)).state) != "delivered", "goods on the apron are not stock")
		# --- the cargo district mended: the crane hauls
		Career.data.port["cargo"] = 1
		var ok := false
		for i in 3600:
			await _frames(1)
			if str(_trade(str(t1.id)).state) == "delivered" and str(_trade(str(t2.id)).state) == "delivered":
				ok = true
				break
		check(ok, "the pier crane takes both into the warehouse on its own")
		check(Shipping.slots() == 2, "the cargo district's first stage opens a second berth")
	else:
		check(false, "two more belt buys")
	# --- selling to the belt: paid on the sale (37 号), the buyer's hull comes and its crew loads
	Career.data.port.erase("cargo")
	# nonferrous mix: only the company has any (its own sorting), so the bid can meet only its ask
	var st: Dictionary = Career.data.exchange
	st.actors.company.lots["TEST-NF"] = {"id": "TEST-NF", "key": "nonferrous_mix:0", "available": 1.0, "total": 1.0, "origin": "receiver"}
	st.actors.company.stock["nonferrous_mix:0"] = float(st.actors.company.stock.get("nonferrous_mix:0", 0.0)) + 1.0
	Career.save()
	var cash0 := float(Career.data.money)
	var r := Ex.command("post", {"side": "sell", "item": "nonferrous_mix", "grade": 0, "quantity": 1.0, "price": 5000.0})
	print("sell: ", r)
	Ex.post(Career.data.exchange, "merchant_07", "buy", "nonferrous_mix", 0, 1.0, 5000.0)
	# a bid posted straight on the book (the game's own NPC turns sync this themselves)
	Career.data.money = float(Career.data.exchange.actors.company.cash)
	Career.save()
	check(r.ok, "a sell to a belt merchant's bid")
	await _frames(3)
	var out := {}
	for tt in Career.data.exchange.trades:
		if str(tt.seller) == Ex.PLAYER and str(tt.buyer) == "merchant_07":
			out = tt
	var so := Shipping.ship_for(str(out.get("id", "")))
	check(not so.is_empty() and str(so.dir) == "out", "the buyer sends a hull for it")
	if not so.is_empty():
		await _arrive(so)
		await _frames(6)
		so = Shipping.ship_for(str(out.id))
		var pb = g.freight_pier.bodies.get(str(so.pieces[0].key))
		check(pb != null and str(so.state) == "docked", "the goods come out on the loading table")
		# 37 号: the buyer's crew loads it; the company was paid when it sold
		check(float(Career.data.money) > cash0, "paid when the listing sold (+$%.0f)" % (float(Career.data.money) - cash0))
		var cash1 := float(Career.data.money)
		var loaded := false
		for i in 3600:
			await _frames(1)
			so = Shipping.ship_for(str(out.id))
			if str(so.state) == "leaving":
				loaded = true
				break
		check(loaded, "the buyer's crew loads it and it sails, no hands needed")
		if loaded:
			Shipping.data().day = float(so.run.depart) + float(so.run.tof) + 0.01
			await _frames(4)
			check(str(_trade(str(out.id)).state) == "delivered" and is_equal_approx(float(Career.data.money), cash1), "home: delivered, and not paid twice")
	# --- the big three stay local
	var tl := _buy_from(0, 2, 1.0)
	await _frames(3)
	check(tl.is_empty() or (not Shipping.orbital(tl) and Shipping.ship_for(str(tl.id)).is_empty()), "a buy from the port's own counters stays on the local freight")
	_end()


func _trade(id: String) -> Dictionary:
	for t in Career.data.exchange.trades:
		if str(t.id) == id:
			return t
	return {}


func _end() -> void:
	g.queue_free()
	await _frames(4)
	print("SHIPPING %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
