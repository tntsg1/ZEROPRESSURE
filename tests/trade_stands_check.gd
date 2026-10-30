extends "res://tests/guide_check.gd"
# 49 号: each company's stand in the trade hall reads its real business off the book — the
# feed company's sample cabinet holds one cell per goods it sells, the logistics company's
# docket board lists its open deliveries with the company and its weighbridge reads the last
# load, the workshop's bench shows what it buys; a company with nothing on the book is dark;
# a rush lights the buyer's stand. Shots. Own test saves only.
#   tools/run_test.sh tests/trade_stands_check.gd --fixed-fps 60
const Ex = preload("res://scripts/industrial_exchange.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_trade_stands_career.json"
	SaveGame.path = "user://zp_test_trade_stands_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 300000.0
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "power": 1, "cargo": 1}
	Career.data.drill = {"granted": true, "done": true}
	Career.save()
	await _spawn()
	await _frames(10)
	check(Ex.command("view").ok, "the exchange is open")
	var th = g.trade_hall
	var st: Dictionary = Career.data.exchange
	# the feed company: one cell per goods it sells
	var kinds := {}
	for o in st.orders:
		if str(o.owner) == "merchant_00" and str(o.side) == "sell" and str(o.state) == "open":
			kinds[Ex.lot_key(str(o.item), int(o.grade))] = true
	var s0: Dictionary = th.scene_of("merchant_00")
	check(s0.sells.size() == kinds.size() and s0.lit, "恒岳工业 reads what it sells off the book (%d goods)" % kinds.size())
	# 52 号: its screen shows one line — its biggest open order
	var biggest := 0.0
	for o in st.orders:
		if str(o.owner) == "merchant_00" and str(o.state) == "open":
			biggest = maxf(biggest, float(o.remaining))
	var deal: Dictionary = th.main_deal("merchant_00")
	check(not deal.is_empty() and float(deal.t) >= biggest - 0.001, "its screen: its biggest order (%s %.1f t)" % [str(deal.get("key", "")), float(deal.get("t", 0.0))])
	# a delivery with the logistics company: on its docket board, weighed
	var sell := {}
	for o in st.orders:
		if str(o.owner) == "merchant_00" and str(o.side) == "sell" and str(o.state) == "open" and float(o.remaining) >= 0.5:
			sell = o
	var bid := {}
	for o in st.orders:
		if str(o.owner) == "merchant_01" and str(o.side) == "buy" and str(o.state) == "open":
			bid = o
	var s1: Dictionary = th.scene_of("merchant_01")
	check(s1.lit == (not bid.is_empty() or s1.sells.size() > 0), "天衡物流's stand is lit by what it has on the book")
	# sell it billets: a docket, and the weighbridge reads that load
	var lid := "TEST-BIL"
	st.actors.company.lots[lid] = {"id": lid, "key": "steel_billet:1", "available": 0.5, "total": 0.5, "origin": "manufactured"}
	st.actors.company.stock["steel_billet:1"] = float(st.actors.company.stock.get("steel_billet:1", 0.0)) + 0.5
	Career.save()
	check(Ex.command("post", {"side": "sell", "item": "steel_billet", "grade": 1, "quantity": 0.5, "price": 1100.0}).ok, "billets listed to the clients")
	var who := ""
	for tr in Career.data.exchange.trades:
		if str(tr.seller) == "company" and str(tr.item) == "steel_billet":
			who = str(tr.buyer)
	var sc: Dictionary = th.scene_of(who)
	check(who in ["merchant_01", "merchant_02"] and sc.dockets.size() >= 1 and is_equal_approx(float(sc.weighed), 0.5), "the buyer's stand: a docket for it, the last load weighed 0.5 t (%s)" % who)
	# a company with nothing on the book is dark
	var quiet := true
	for o in Career.data.exchange.orders:
		if str(o.owner) == "merchant_02" and str(o.state) == "open":
			quiet = false
	if quiet:
		check(not th.scene_of("merchant_02").lit, "nothing on the book: the stand is dark")
	else:
		check(th.scene_of("merchant_02").lit, "on the book: the stand is lit")
	# a rush lights the buyer's stand
	Career.data.exchange.rush_next = float(Career.data.exchange.clock)
	var rush := {}
	for i in 120:
		await _frames(1)
		rush = Ex.rush_order(Career.data.exchange)
		if not rush.is_empty():
			break
	check(not rush.is_empty() and not th.scene_of(str(rush.owner)).rush.is_empty(), "a rush shows on its buyer's stand")
	# shots
	var view: Vector2 = th.counter_rect(1).get_center() + Vector2(0, 7) * Geom.M
	g.drone.global_position = th.counter_spot(1)
	g.cam_override = view
	g.cam_pos = view
	g.zoom_override = 0.42
	g.zoom_now = 0.42
	await _frames(80)
	Cap.save(root, "res://tests/out/trade_stands_zh.png")
	g.zoom_override = 0.8
	g.zoom_now = 0.8
	g.cam_override = th.counter_rect(1).get_center() + Vector2(0, 9) * Geom.M
	await _frames(40)
	Cap.save(root, "res://tests/out/trade_stand_close_zh.png")
	g.cam_override = null
	g.zoom_override = -1.0
	g.queue_free()
	await _frames(4)
	print("TRADE STANDS %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
